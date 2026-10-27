"""Storage behavior checks; fast logic/fixtures and slow process/Git boundaries."""
import argparse
import importlib.util
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "skills/storage-budget/scripts/storage_budget.py"
sys.path.insert(0,str(SCRIPT.parent))
import process_group
spec=importlib.util.spec_from_file_location("storage_budget",SCRIPT)
storage=importlib.util.module_from_spec(spec);spec.loader.exec_module(storage)

class StorageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="ai-rules-storage-test-");self.root=Path(self.temp.name)
    def tearDown(self):
        self.temp.cleanup()
    def test_inventory_counts_categories_without_granting_cleanup(self):
        for name,data in {"bin/app":b"123", "node_modules/x":b"12345", "artifacts/report":b"1234567", "unrecognized":b"123456789"}.items():
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
        result=storage.inventory([self.root])
        self.assertTrue(result["complete"])
        row=result["roots"][0]
        self.assertEqual(24,row["logical_bytes"])
        self.assertEqual({"source":0,"build":3,"dependencies":5,"evidence":7,"unknown":9,"git":0},row["categories"])
        self.assertIsNone(row["reclaimable_bytes"])
        self.assertFalse(row["cleanup_authorized"])
    def test_inventory_marks_limits_missing_and_shared_files(self):
        (self.root/"a").write_bytes(b"hello")
        os.link(self.root/"a",self.root/"b")
        row=storage.inventory([self.root])["roots"][0]
        self.assertEqual(5,row["logical_bytes"])
        self.assertGreater(row["shared_entries"],0)
        (self.root/"nested").mkdir();(self.root/"nested"/"file").write_bytes(b"large")
        bounded=storage.inventory([self.root],max_depth=0)
        self.assertFalse(bounded["complete"])
        self.assertIn("depth-limit",bounded["roots"][0]["diagnostics"])
        missing=storage.inventory([self.root/"missing"])
        self.assertFalse(missing["complete"])
        self.assertIsNone(missing["roots"][0]["logical_bytes"])

    def config(self):
        return {"schemaVersion":2,"resources":{"memory":{"reserveMiBPerActiveWorktree":1024,"basis":"estimated","estimateReason":"fixture"},"disk":{"workloads":{"build":{"reserveMiB":2,"outputGrowthMiB":3,"tempGrowthMiB":5,"retainedBudgetMiB":4,"basis":"estimated","estimateReason":"fixture workload"}}}}}
    def test_admission_sums_growth_once_per_actual_volume(self):
        observed=lambda path:{"id":"same","free_bytes":9*1024**2,"path":str(path)}
        result=storage.admit(self.config(),"build",self.root,self.root,observe=observed)
        self.assertFalse(result["admitted"])
        self.assertEqual(10*1024**2,result["volumes"][0]["required_bytes"])
        self.assertEqual(1024**2,result["volumes"][0]["shortfall_bytes"])
        enough=lambda path:{"id":"same","free_bytes":10*1024**2,"path":str(path)}
        self.assertTrue(storage.admit(self.config(),"build",self.root,self.root,observe=enough)["admitted"])
    def test_admission_checks_output_and_temp_independently(self):
        output=self.root/"output";temporary=self.root/"temp";output.mkdir();temporary.mkdir()
        observed=lambda path:{"id":Path(path).name,"free_bytes":(8 if Path(path).name=="output" else 6)*1024**2,"path":str(path)}
        result=storage.admit(self.config(),"build",output,temporary,observe=observed)
        self.assertFalse(result["admitted"])
        self.assertEqual([0,1024**2],sorted(v["shortfall_bytes"] for v in result["volumes"]))
        old=self.config();old["schemaVersion"]=1;old["resources"].pop("disk")
        with self.assertRaisesRegex(storage.StorageError,"disk-budget-unavailable"):
            storage.admit(old,"build",output,temporary)
        invalid=self.config();invalid["resources"]["disk"]["workloads"]["build"]["tempGrowthMiB"]=-1
        with self.assertRaisesRegex(storage.StorageError,"invalid-disk-budget"):
            storage.admit(invalid,"build",output,temporary)

    def test_missing_executable_cleans_owned_run_directories(self):
        receipt=self.root/"launch-failure.json"
        missing=self.root/"missing-executable"
        result=storage.run_managed(self.config(),"build",self.root,self.root,receipt,
            [str(missing)],scope="launch-failure",cache_state="cold",timeout=3,sample_seconds=.05)
        self.assertEqual("execution-error",result["reason"])
        self.assertTrue(result["workers_stopped"])
        self.assertEqual(0,result["receipt"]["cleanup_failures"])
        self.assertEqual(0,result["receipt"]["after_bytes"])
        self.assertEqual([],result["retained_paths"])
        self.assertFalse(any(self.root.glob("ai-rules-run-*")))

    def test_unconfirmed_launch_failure_preserves_owned_run_directories(self):
        receipt=self.root/"unconfirmed-launch.json"
        failure=process_group.LaunchError("worker state is unknown",workers_stopped=False)
        with patch("process_group.launch",side_effect=failure):
            result=storage.run_managed(self.config(),"build",self.root,self.root,receipt,
                [sys.executable,"-c","pass"],scope="unconfirmed-launch",cache_state="cold")
        self.assertEqual("execution-error",result["reason"])
        self.assertFalse(result["workers_stopped"])
        self.assertEqual(2,result["receipt"]["cleanup_failures"])
        self.assertGreater(result["receipt"]["after_bytes"],0)
        self.assertEqual(2,len(result["retained_paths"]))
        self.assertTrue(all(Path(path).is_dir() for path in result["retained_paths"]))

    def test_inventory_does_not_follow_linked_ancestors_or_unbounded_nesting(self):
        target=self.root/"target";target.mkdir();(target/"valuable").write_bytes(b"123456789")
        link=self.root/"link"
        try: link.symlink_to(target,target_is_directory=True)
        except OSError: self.skipTest("native symlink creation unavailable")
        result=storage.inventory([link])
        self.assertFalse(result["complete"]);self.assertIsNone(result["roots"][0]["logical_bytes"])
        self.assertTrue((target/"valuable").exists())


    def test_owned_cleanup_preserves_existing_unknown_and_active_state(self):
        existing=self.root/"valuable";existing.mkdir();(existing/"keep").write_text("source")
        owned=storage.OwnedDirectory(self.root)
        (owned.path/"output").write_text("generated")
        self.assertFalse(owned.cleanup(workers_stopped=False))
        self.assertTrue((owned.path/"output").exists())
        self.assertTrue(owned.cleanup(workers_stopped=True))
        self.assertFalse(owned.path.exists());self.assertTrue((existing/"keep").exists())
        unknown=storage.OwnedDirectory(self.root)
        unknown.marker.write_text("different owner")
        self.assertFalse(unknown.cleanup(workers_stopped=True));self.assertTrue(unknown.path.exists())
    def test_owned_cleanup_reports_failed_removal_and_parent_replacement(self):
        owned=storage.OwnedDirectory(self.root)
        with patch.object(storage,"remove_owned_tree",side_effect=PermissionError("locked")):
            self.assertFalse(owned.cleanup(workers_stopped=True))
        self.assertTrue(owned.path.exists())
        parent=self.root/"parent";parent.mkdir();swapped=storage.OwnedDirectory(parent)
        parent.rename(self.root/"moved");parent.mkdir()
        self.assertFalse(swapped.cleanup(workers_stopped=True))
        self.assertTrue((self.root/"moved"/swapped.path.name).exists())
    def test_slow_managed_success_and_failure_cleanup_receipts(self):
        for exit_code in (0,7):
            receipt=self.root/("receipt-"+str(exit_code)+".json")
            result=storage.run_managed(self.config(),"build",self.root,self.root,receipt,
                [sys.executable,"-c","import os,pathlib,time;pathlib.Path(os.environ['AI_RULES_RUN_DIR'],'output').write_bytes(b'x'*5000);time.sleep(.15);raise SystemExit("+str(exit_code)+")"],
                scope="fixture",cache_state="cold",timeout=3,sample_seconds=.05)
            self.assertEqual(exit_code,result["command_exit_code"])
            self.assertEqual(0,result["receipt"]["cleanup_failures"])
            self.assertEqual(0,result["receipt"]["after_bytes"])
            self.assertGreaterEqual(result["receipt"]["peak_bytes"],5000)
            self.assertEqual(result["receipt"],json.loads(receipt.read_text()))
            self.assertFalse(any(self.root.glob("ai-rules-run-*")))
    def test_slow_timeout_stops_descendants_before_cleanup(self):
        receipt=self.root/"cancel.json"
        result=storage.run_managed(self.config(),"build",self.root,self.root,receipt,
            [sys.executable,"-c","import subprocess,sys,time;child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)']);print(child.pid,flush=True);time.sleep(30)"],
            scope="cancel",cache_state="cold",timeout=.4,sample_seconds=.05)
        self.assertEqual("timeout",result["reason"])
        self.assertTrue(result["workers_stopped"])
        self.assertEqual(0,result["receipt"]["cleanup_failures"])
        child_pid=int(result["output_tail"].strip())
        if os.name=="nt":
            import ctypes
            from ctypes import wintypes
            kernel=ctypes.WinDLL("kernel32",use_last_error=True)
            kernel.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD];kernel.OpenProcess.restype=wintypes.HANDLE
            kernel.WaitForSingleObject.argtypes=[wintypes.HANDLE,wintypes.DWORD];kernel.WaitForSingleObject.restype=wintypes.DWORD
            kernel.CloseHandle.argtypes=[wintypes.HANDLE]
            handle=kernel.OpenProcess(0x100000,False,child_pid)
            if handle:
                try:self.assertEqual(0,kernel.WaitForSingleObject(handle,0))
                finally:kernel.CloseHandle(handle)
        else:
            stat_file=Path("/proc")/str(child_pid)/"stat"
            if stat_file.exists():self.assertEqual("Z",stat_file.read_text().rpartition(")")[2].split()[0])
        self.assertFalse(any(self.root.glob("ai-rules-run-*")))
    def test_run_rejects_nested_copy_outputs_and_existing_receipts(self):
        receipt=self.root/"existing.json";receipt.write_text("keep")
        with self.assertRaisesRegex(storage.StorageError,"receipt-already-exists"):
            storage.run_managed(self.config(),"build",self.root,self.root,receipt,[sys.executable,"-c","pass"],scope="fixture",cache_state="cold")
        output=self.root/"output";output.mkdir()
        with self.assertRaisesRegex(storage.StorageError,"output-inside-source"):
            storage.run_managed(self.config(),"build",output,self.root,self.root/"new.json",[sys.executable,"-c","pass"],scope="fixture",cache_state="cold",source=self.root)


    def test_inventory_entry_budget_and_io_failure_are_visible(self):
        for name in ("one","two","three"):(self.root/name).write_bytes(b"abc")
        bounded=storage.inventory([self.root],max_entries=1)
        self.assertFalse(bounded["complete"]);self.assertIn("entry-limit",bounded["roots"][0]["diagnostics"])
        with patch.object(storage.os,"scandir",side_effect=PermissionError("denied")):
            denied=storage.inventory([self.root])
        self.assertFalse(denied["complete"]);self.assertIn("unreadable-directory",denied["roots"][0]["diagnostics"])
    def test_slow_real_git_inventory_and_volume_observation(self):
        repo=self.root/"repository";repo.mkdir()
        subprocess.run(["git","-C",str(repo),"init","--quiet"],check=True,capture_output=True)
        (repo/"source.py").write_bytes(b"source")
        subprocess.run(["git","-C",str(repo),"add","source.py"],check=True,capture_output=True)
        roots,tracked,diagnostics=storage.registered_roots([repo])
        self.assertEqual([],diagnostics)
        report=storage.inventory(roots,tracked=tracked)
        self.assertEqual(6,report["roots"][0]["categories"]["source"])
        observed=storage.volume_info(repo)
        self.assertGreater(observed["free_bytes"],0)
        self.assertEqual(str(repo.stat().st_dev),observed["id"])
    def test_slow_live_guard_and_cleanup_failure_remain_observable(self):
        original=storage.volume_info
        def pressure(path):
            row=original(path);row["free_bytes"]=0;return row
        with patch.object(storage,"volume_info",side_effect=pressure):
            result=storage.run_managed(self.config(),"build",self.root,self.root,self.root/"pressure.json",
                [sys.executable,"-c","import time;time.sleep(30)"],scope="pressure",cache_state="cold",timeout=3,sample_seconds=.05)
        self.assertEqual("disk-reserve-crossed",result["reason"])
        self.assertTrue(result["workers_stopped"])
        with patch.object(storage,"remove_owned_tree",side_effect=PermissionError("busy")):
            failed=storage.run_managed(self.config(),"build",self.root,self.root,self.root/"failed-cleanup.json",
                [sys.executable,"-c","print('receipt')"],scope="failed",cache_state="cold",timeout=3,sample_seconds=.05)
        self.assertEqual(2,failed["receipt"]["cleanup_failures"])
        self.assertGreater(failed["receipt"]["after_bytes"],0)
        self.assertEqual(2,len(failed["retained_paths"]))
    def test_slow_cancellation_finishes_the_owned_lifecycle(self):
        with patch("process_group." + ("WindowsGroup" if os.name=="nt" else "PosixGroup") + ".poll",side_effect=KeyboardInterrupt()):
            result=storage.run_managed(self.config(),"build",self.root,self.root,self.root/"cancelled.json",
                [sys.executable,"-c","import time;time.sleep(30)"],scope="cancelled",cache_state="cold",timeout=3,sample_seconds=.05)
        self.assertEqual("cancelled",result["reason"])
        self.assertTrue(result["workers_stopped"])
        self.assertEqual(0,result["receipt"]["cleanup_failures"])


    @unittest.skipIf(os.name=="nt", "Windows ancestor rename is denied by held directory handles")
    def test_cleanup_refuses_a_parent_swapped_after_preflight(self):
        parent=self.root/"parent";parent.mkdir();owned=storage.OwnedDirectory(parent)
        original=storage.remove_owned_tree
        def swap(path,expected,parent_id):
            parent.rename(self.root/"saved")
            replacement=parent/path.name;replacement.mkdir(parents=True)
            (replacement/"valuable").write_text("keep")
            return original(path,expected,parent_id)
        with patch.object(storage,"remove_owned_tree",side_effect=swap):
            self.assertFalse(owned.cleanup(workers_stopped=True))
        self.assertEqual("keep",(owned.path/"valuable").read_text())
        self.assertTrue((self.root/"saved"/owned.path.name).exists())


    def cli(self,args):
        stdout,stderr=io.StringIO(),io.StringIO()
        with contextlib.redirect_stdout(stdout),contextlib.redirect_stderr(stderr):
            code=storage.main(args)
        return code,json.loads(stdout.getvalue()) if stdout.getvalue() else None,stderr.getvalue()
    def test_cli_retention_review_and_invalid_configuration(self):
        config=self.root/"config.json";config.write_text(json.dumps(self.config()))
        (self.root/"unknown").write_text("preserve")
        code,report,error=self.cli(["inventory","--root",str(self.root),"--config",str(config),"--workload","build"])
        self.assertEqual(0,code);self.assertTrue(report["retention"]["review_required"])
        self.assertFalse(report["retention"]["cleanup_authorized"])
        invalid,_,error=self.cli(["inventory","--root",str(self.root),"--config",str(config)])
        self.assertEqual(2,invalid);self.assertIn("both config and workload",error)
        bad=self.root/"invalid.json";bad.write_text("[]")
        code,_,error=self.cli(["check","--config",str(bad),"--workload","build","--output-parent",str(self.root),"--temp-parent",str(self.root)])
        self.assertEqual(2,code);self.assertIn("invalid-disk-budget",error)
    def test_cli_blocks_only_the_unaffordable_command(self):
        config=self.config();config["resources"]["disk"]["workloads"]["build"]["reserveMiB"]=2**32
        path=self.root/"config.json";path.write_text(json.dumps(config))
        prefix=["--config",str(path),"--workload","build","--output-parent",str(self.root),"--temp-parent",str(self.root)]
        code,check,_=self.cli(["check",*prefix]);self.assertEqual(3,code);self.assertFalse(check["admitted"])
        receipt=self.root/"blocked.json"
        code,result,_=self.cli(["run",*prefix,"--receipt",str(receipt),"--scope","blocked","--cache-state","cold","--",sys.executable,"-c","raise SystemExit(9)"])
        self.assertEqual(3,code);self.assertEqual("insufficient-disk",result["reason"])
        self.assertIsNone(result["command_exit_code"]);self.assertFalse(any(self.root.glob("ai-rules-run-*")))
        self.assertFalse(result["receipt"]["sample_complete"])
    def test_measured_budget_requires_dated_evidence(self):
        config=self.config();value=config["resources"]["disk"]["workloads"]["build"]
        value.pop("estimateReason");value.update(basis="measured",measurement={"date":"2026-10-26","workload":"fixture","evidence":"receipt-id"})
        self.assertEqual("measured",storage.admit(config,"build",self.root,self.root)["basis"])
        value["measurement"]["date"]="2026-99-99"
        with self.assertRaisesRegex(storage.StorageError,"invalid-disk-budget"):
            storage.admit(config,"build",self.root,self.root)


    def test_slow_final_free_space_sample_remains_importable(self):
        original_volume=storage.volume_info;original_cleanup=storage.OwnedDirectory.cleanup
        cleanup_started=[False]
        def observation(path):
            value=original_volume(path)
            value["free_bytes"]=(10 if cleanup_started[0] else 20)*1024**2
            return value
        def cleanup(instance,*,workers_stopped):
            cleanup_started[0]=True
            return original_cleanup(instance,workers_stopped=workers_stopped)
        receipt=self.root/"falling-free-space.json"
        with patch.object(storage,"volume_info",side_effect=observation),patch.object(storage.OwnedDirectory,"cleanup",cleanup):
            result=storage.run_managed(self.config(),"build",self.root,self.root,receipt,
                [sys.executable,"-c","pass"],scope="falling-free-space",cache_state="cold",timeout=3,sample_seconds=.05)
        self.assertEqual("completed",result["reason"])
        self.assertEqual(10*1024**2,result["receipt"]["volume_free"][0]["minimum_bytes"])
        self.assertEqual(10*1024**2,result["receipt"]["volume_free"][0]["after_bytes"])
        metrics_spec=importlib.util.spec_from_file_location("metrics_receipt_consumer",SCRIPT.parents[2]/"skill-metrics/scripts/skill_metrics.py")
        metrics=importlib.util.module_from_spec(metrics_spec);metrics_spec.loader.exec_module(metrics)
        self.assertEqual(result["receipt"],metrics.storage_receipt(receipt))


    def test_marker_write_failure_has_no_unreported_residue(self):
        original_write=Path.write_text
        def no_space(path,*args,**kwargs):
            if path.name==".ai-rules-owner":raise OSError(28,"fixture disk full")
            return original_write(path,*args,**kwargs)
        for cleanup_fails in (False,True):
            receipt=self.root/("marker-failure-"+str(cleanup_fails)+".json")
            with contextlib.ExitStack() as stack:
                stack.enter_context(patch.object(Path,"write_text",no_space))
                launch=stack.enter_context(patch("process_group.launch"))
                if cleanup_fails:stack.enter_context(patch.object(storage,"remove_owned_tree",side_effect=PermissionError("busy")))
                result=storage.run_managed(self.config(),"build",self.root,self.root,receipt,
                    [sys.executable,"-c","pass"],scope="setup-failure",cache_state="cold")
                launch.assert_not_called()
            self.assertEqual("execution-error",result["reason"])
            remaining=list(self.root.glob("ai-rules-run-*"))
            if remaining:
                self.assertGreater(result["receipt"]["cleanup_failures"],0)
                self.assertEqual({str(path) for path in remaining},set(result["retained_paths"]))
                self.assertIsNone(result["receipt"]["after_bytes"])
            else:
                self.assertEqual(0,result["receipt"]["cleanup_failures"])
                self.assertEqual(0,result["receipt"]["after_bytes"])
            self.assertFalse(result["receipt"]["sample_complete"])

if __name__ == "__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--lane",choices=["fast","slow","combined","all"],default="combined");args=parser.parse_args()
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(StorageTests)
    selected=unittest.TestSuite(t for t in suite if args.lane in ("all","combined") or ("_slow_" in t.id())==(args.lane=="slow"))
    raise SystemExit(not unittest.TextTestRunner(verbosity=2).run(selected).wasSuccessful())
