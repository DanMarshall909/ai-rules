"""Behavior tests for the local skill metrics CLI; no real profile data is used."""
import argparse
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import subprocess
import sys
import sqlite3
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills" / "skill-metrics" / "scripts" / "skill_metrics.py"
spec = importlib.util.spec_from_file_location("skill_metrics", SCRIPT)
metrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metrics)

class MetricsCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.db = self.root / "data" / "metrics.sqlite3"
        self.rules = self.root / "rules-source"
        (self.rules / "rule-sets").mkdir(parents=True)
        (self.rules / "rule-sets" / "ai-rules.md").write_text("# Policy\nPreserve work.\n", encoding="utf-8")
        for name in ("alpha", "beta"):
            path = self.rules / "skills" / name
            path.mkdir(parents=True)
            (path / "SKILL.md").write_text(f"---\nname: {name}\ndescription: A fixture\n---\nDo useful work.\n", encoding="utf-8")

    def call(self, *args, code=0):
        if args[0] == "finish" and "--rules-root" not in args:
            args = (*args, "--rules-root", str(self.rules))
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            actual = metrics.main(["--db", str(self.db), *args])
        self.assertEqual(code, actual, err.getvalue())
        if code:
            self.assertEqual("", out.getvalue())
            return err.getvalue()
        self.assertEqual("", err.getvalue())
        return json.loads(out.getvalue())

    def start(self, run="r1", *extra):
        return self.call("start", "--run-id", run, "--project", "fixture", "--rules-root", str(self.rules), "--skill", "alpha", *extra)

    def trial(self, run, revision, pair, *, finish=True, outcome="completed", safety="0", quality="0", seconds="10", model="model-v1", design="matched", cohort="trial1", storage_threshold=None):
        (self.rules / "rule-sets" / "ai-rules.md").write_text("# Policy " + revision, encoding="utf-8")
        options = ["--design", design, "--task-class", "repair", "--scenario", "dirty-tree", "--scenario-version", "v1", "--model", model, "--environment", "windows-python", "--cohort", cohort]
        if design == "matched":
            options += ["--pair", pair]
        if storage_threshold is not None:
            options += ["--storage-threshold-bytes", str(storage_threshold)]
        identity = self.start(run, *options)["run"]["source"]["digest"]
        if finish:
            options = ["--metrics-source", "fixture:v1", "--assessment", "test", "--evidence-ref", "receipt:" + run, "--elapsed-seconds", seconds]
            if safety is not None:
                options += ["--safety-violations", safety]
            if quality is not None:
                options += ["--quality-failures", quality]
            self.call("finish", "--run-id", run, "--outcome", outcome, "--rules-root", str(self.rules), *options)
        return identity


    def receipt(self, **changes):
        value = {"schema_version": 1, "scope": "task-output-v1", "workload": "build-v1", "method": "logical-v1",
                 "provenance": "storage:v1", "cache_state": "warm", "before_bytes": 100, "after_bytes": 150,
                 "peak_bytes": 200, "sample_complete": True, "cleanup_failures": 0, "rebuild_seconds": None,
                 "volume_free": [{"volume": "output", "before_bytes": 10000, "after_bytes": 9000, "minimum_bytes": 8000}]}
        value.update(changes)
        path = self.root / "storage-receipt.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return str(path)


    def storage_trial(self, run, revision, *, seconds="10", outcome="completed", threshold=10, receipt=True, **changes):
        identity = self.trial(run, revision, "one", finish=False, storage_threshold=threshold)
        options = [] if not receipt else ["--storage-receipt", self.receipt(**changes)]
        self.call("finish", "--run-id", run, "--outcome", outcome, "--assessment", "test", "--evidence-ref", "receipt:" + run,
                  "--metrics-source", "fixture:v1", "--elapsed-seconds", seconds, "--safety-violations", "0", "--quality-failures", "0", *options)
        return identity


class FastTests(MetricsCase):
    def test_unknown_dirty_metadata_requires_digest_selection_without_rewriting_records(self):
        with patch.object(metrics, "git_identity", return_value=("a" * 40, False)):
            baseline = self.trial("b", "base", "one", seconds="10")
        with patch.object(metrics, "git_identity", return_value=("b" * 40, None)):
            candidate = self.trial("c", "candidate", "one", seconds="5")
        before = self.db.read_bytes()
        error = self.call("compare", "--baseline", "a" * 40, "--candidate", "b" * 40, "--min-pairs", "1", code=2)
        self.assertIn("exact digest", error)
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("improved", result["verdict"])
        self.assertEqual(1, result["matched_pairs"])
        self.assertEqual(2, self.call("report")["runs"]["total"])
        self.assertEqual(before, self.db.read_bytes())

    def test_exact_fractional_threshold_is_unchanged(self):
        baseline = self.trial("b", "base", "one", seconds="0.1")
        candidate = self.trial("c", "candidate", "one", seconds="0.095")
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1", "--time-threshold", "0.05")
        self.assertEqual("unchanged", result["verdict"])
        self.assertEqual(-0.05, result["deltas"]["elapsed_seconds"]["relative_delta"])

    def test_records_declared_use_and_finished_outcome_without_inventing_metrics(self):
        started = self.start()
        self.assertEqual("active", started["run"]["state"])
        self.assertEqual("declared", started["run"]["usage_provenance"])
        self.assertTrue(started["run"]["source"]["digest"].startswith("sha256:"))
        self.call("use", "--run-id", "r1", "--rules-root", str(self.rules), "--skill", "beta")
        ended = self.call("finish", "--run-id", "r1", "--outcome", "completed", "--evidence-ref", "receipt:one")
        self.assertEqual("completed", ended["run"]["state"])
        self.assertIsNone(ended["run"]["metrics"]["input_tokens"])
        self.assertIsNone(ended["run"]["metrics"]["safety_violations"])
        report = self.call("report")
        self.assertEqual(1, report["runs"]["total"])
        self.assertEqual(1, report["runs"]["completed"])
        self.assertEqual(1, report["runs"]["co_used"])
        self.assertEqual(["alpha", "beta"], [row["skill"] for row in report["skills"]])
        self.assertEqual(0, report["metrics"]["input_tokens"]["known"])
        self.assertIsNone(report["metrics"]["input_tokens"]["mean"])

    def test_retries_are_idempotent_and_conflicts_preserve_first_result(self):
        first = self.start()
        repeated = self.start()
        self.assertFalse(repeated["created"])
        self.assertEqual(first["run"]["started_at"], repeated["run"]["started_at"])
        for _ in range(2):
            self.call("use", "--run-id", "r1", "--rules-root", str(self.rules), "--skill", "alpha")
        completed = self.call("finish", "--run-id", "r1", "--outcome", "completed")
        self.assertEqual(completed, self.call("finish", "--run-id", "r1", "--outcome", "completed"))
        self.assertIn("conflicts", self.call("finish", "--run-id", "r1", "--outcome", "failed", code=2))
        self.assertIn("finished", self.call("use", "--run-id", "r1", "--rules-root", str(self.rules), "--skill", "beta", code=2))
        report = self.call("report")
        self.assertEqual(1, report["runs"]["total"])
        self.assertEqual(1, report["runs"]["completed"])
        self.assertEqual(1, len(report["skills"]))

    def test_rejected_inputs_leave_no_data_and_reporting_is_read_only(self):
        self.assertEqual(0, self.call("report")["runs"]["total"])
        self.assertFalse(self.db.exists())
        self.assertIn("unknown", self.call("start", "--run-id", "r1", "--project", "test", "--rules-root", str(self.rules), "--skill", "missing", code=2))
        self.assertFalse(self.db.exists())
        self.call("start", "--run-id", "r1", "--project", "C:/private/path", code=2)
        self.call("start", "--run-id", "r1", "--project", "test", "--task-ref", "https://example.invalid/?token=secret", code=2)
        self.assertFalse(self.db.exists())
        self.start()
        for value in ("-1", "nan", "inf"):
            self.call("finish", "--run-id", "r1", "--outcome", "completed", "--cost-usd", value, code=2)
        self.assertIn("provenance", self.call("finish", "--run-id", "r1", "--outcome", "completed", "--input-tokens", "4", code=2))
        self.assertEqual(1, self.call("report")["runs"]["active"])
        self.assertNotIn(str(self.root).encode(), self.db.read_bytes())

    def test_source_change_is_detected_without_fabricated_git_revision(self):
        before = self.start()["run"]["source"]
        self.assertIsNone(before["revision"])
        (self.rules / "skills" / "alpha" / "reference.txt").write_text("new behaviour", encoding="utf-8")
        self.assertIn("source changed", self.call("use", "--run-id", "r1", "--rules-root", str(self.rules), "--skill", "beta", code=2))
        after = self.start("r2")["run"]["source"]
        self.assertNotEqual(before["digest"], after["digest"])
        self.assertEqual(2, len(self.call("report")["skills"]))


    def test_matched_comparison_reports_exact_deltas_and_configured_floor(self):
        for pair in ("one", "two"):
            baseline = self.trial("b-" + pair, "base", pair, seconds="10")
            candidate = self.trial("c-" + pair, "candidate", pair, seconds="8")
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "2", "--time-threshold", "0.1")
        self.assertEqual("improved", result["verdict"])
        self.assertEqual(2, result["matched_pairs"])
        self.assertEqual(2, result["baseline"]["runs"]["total"])
        self.assertEqual(-2, result["deltas"]["elapsed_seconds"]["mean_delta"])
        self.assertEqual(0, result["deltas"]["safety_violations"]["mean_delta"])
        self.assertEqual(0, result["deltas"]["cost_usd"]["known_pairs"])
        self.assertEqual(1, len(result["strata"]))
        self.assertEqual("insufficient", self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "3")["verdict"])

    def test_source_change_during_run_is_visible_at_finish(self):
        self.start()
        (self.rules / "rule-sets" / "ai-rules.md").write_text("changed policy", encoding="utf-8")
        ended = self.call("finish", "--run-id", "r1", "--outcome", "completed", "--rules-root", str(self.rules))
        self.assertEqual("changed", ended["run"]["source_integrity"])
        self.assertNotEqual(ended["run"]["source"]["digest"], ended["run"]["end_source"]["digest"])


    def test_quality_and_safety_regression_cannot_be_hidden_by_faster_execution(self):
        baseline = self.trial("b", "base", "one", seconds="20")
        candidate = self.trial("c", "candidate", "one", outcome="failed", safety="1", quality="2", seconds="1")
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("worsened", result["verdict"])
        self.assertEqual({"completion", "safety_violations", "quality_failures"}, {item["metric"] for item in result["hard_regressions"]})
        self.assertEqual(-1, result["deltas"]["completion"]["mean_delta"])

    def test_strata_opposing_costs_and_observational_runs_remain_explicit(self):
        baseline = self.trial("b1", "base", "one", seconds="10", cohort="first")
        candidate = self.trial("c1", "candidate", "one", seconds="5", cohort="first")
        self.trial("b2", "base", "one", seconds="10", cohort="second")
        self.trial("c2", "candidate", "one", seconds="20", cohort="second")
        self.trial("observe", "candidate", "unused", design="observational")
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "2")
        self.assertEqual("mixed", result["verdict"])
        self.assertEqual(2, len(result["strata"]))
        self.assertEqual([{"run_id": "observe", "reason": "observational"}], result["excluded"])

    def test_unavailable_or_changed_end_source_is_not_clean_matched_evidence(self):
        baseline = self.trial("b", "base", "one")
        candidate = self.trial("c", "candidate", "one", finish=False)
        (self.rules / "rule-sets" / "ai-rules.md").write_text("interrupted change", encoding="utf-8")
        self.call("finish", "--run-id", "c", "--outcome", "completed", "--assessment", "test", "--evidence-ref", "receipt:c", "--metrics-source", "fixture:v1", "--safety-violations", "0", "--quality-failures", "0")
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("insufficient", result["verdict"])
        self.assertEqual({"source-not-verified"}, {item["reason"] for item in result["excluded"]})

    def test_unknown_schema_is_not_overwritten(self):
        self.db.parent.mkdir()
        with contextlib.closing(sqlite3.connect(self.db)) as connection:
            connection.execute("PRAGMA user_version=99")
        before = self.db.read_bytes()
        self.assertIn("schema", self.call("report", code=2))
        self.assertIn("schema", self.call("start", "--run-id", "r", "--project", "test", "--rules-root", str(self.rules), code=2))
        self.assertEqual(before, self.db.read_bytes())

    def test_metrics_cannot_be_written_into_the_rules_source(self):
        self.db = self.rules / "metrics.sqlite3"
        self.assertIn("outside", self.call("start", "--run-id", "r", "--project", "test", "--rules-root", str(self.rules), code=2))
        self.assertFalse(self.db.exists())

    def test_entrypoint_changes_and_mid_read_drift_cannot_keep_old_identity(self):
        first = self.start()["run"]["source"]["digest"]
        (self.rules / "AGENTS.md").write_text("Read additional policy.", encoding="utf-8")
        second = self.start("r2")["run"]["source"]["digest"]
        self.assertNotEqual(first, second)
        original = Path.read_bytes
        changed = False
        def read_with_change(path):
            nonlocal changed
            value = original(path)
            if path.name == "ai-rules.md" and not changed:
                changed = True
                path.write_text("changed during read", encoding="utf-8")
            return value
        with patch.object(Path, "read_bytes", read_with_change):
            self.assertIn("during fingerprint", self.call("start", "--run-id", "r3", "--project", "fixture", "--rules-root", str(self.rules), code=2))
        self.assertEqual(2, self.call("report")["runs"]["total"])

    def test_measured_zero_and_missing_cost_are_distinct_and_cost_can_oppose_time(self):
        baseline = self.trial("b", "base", "one", finish=False)
        self.call("finish", "--run-id", "b", "--outcome", "completed", "--assessment", "test", "--evidence-ref", "receipt:b", "--metrics-source", "fixture:v1", "--elapsed-seconds", "10", "--cost-usd", "1", "--input-tokens", "0", "--safety-violations", "0", "--quality-failures", "0")
        candidate = self.trial("c", "candidate", "one", finish=False)
        self.call("finish", "--run-id", "c", "--outcome", "completed", "--assessment", "test", "--evidence-ref", "receipt:c", "--metrics-source", "fixture:v1", "--elapsed-seconds", "5", "--cost-usd", "2", "--safety-violations", "0", "--quality-failures", "0")
        comparison = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("mixed", comparison["verdict"])
        self.assertEqual(1, comparison["deltas"]["cost_usd"]["mean_delta"])
        observed = self.call("report")["metrics"]["input_tokens"]
        self.assertEqual({"known": 1, "missing": 1, "mean": 0, "median": 0}, observed)
        tolerated = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1", "--time-threshold", "0.5", "--cost-threshold", "1")
        self.assertEqual("unchanged", tolerated["verdict"])

    def test_failed_batch_add_and_conflicting_start_do_not_alter_existing_run(self):
        self.start()
        self.call("use", "--run-id", "r1", "--rules-root", str(self.rules), "--skill", "beta", "--skill", "missing", code=2)
        self.assertIn("conflicts", self.call("start", "--run-id", "r1", "--project", "another", "--rules-root", str(self.rules), "--skill", "alpha", code=2))
        report = self.call("report")
        self.assertEqual(1, report["runs"]["total"])
        self.assertEqual(["alpha"], [row["skill"] for row in report["skills"]])


    def test_storage_receipt_records_scoped_growth_without_attributing_host_free_space(self):
        started = self.start("r1", "--storage-threshold-bytes", "10")
        self.assertEqual(10, started["run"]["storage_threshold_bytes"])
        receipt = self.receipt()
        args = ("finish", "--run-id", "r1", "--outcome", "completed", "--metrics-source", "fixture:v1", "--storage-receipt", receipt)
        ended = self.call(*args)
        self.assertEqual(50, ended["run"]["metrics"]["retained_growth_bytes"])
        self.assertEqual(100, ended["run"]["metrics"]["peak_additional_bytes"])
        self.assertEqual(0, ended["run"]["metrics"]["cleanup_failures"])
        self.assertEqual("logical-v1", ended["run"]["storage"]["method"])
        self.assertEqual(ended, self.call(*args))
        self.assertNotIn(str(self.root).encode(), self.db.read_bytes())
        report = self.call("report")
        self.assertEqual(50, report["metrics"]["retained_growth_bytes"]["mean"])
        self.assertEqual(100, report["metrics"]["peak_additional_bytes"]["mean"])
        self.assertEqual(0, report["metrics"]["rebuild_seconds"]["known"])

    def test_storage_receipt_rejects_invalid_values_without_finishing_the_run(self):
        self.start()
        bad = ({"before_bytes": True}, {"after_bytes": -1}, {"peak_bytes": 99}, {"peak_bytes": 149},
               {"cleanup_failures": 1.5}, {"sample_complete": "true"}, {"rebuild_seconds": float("nan")},
               {"schema_version": 2}, {"scope": "C:/private"}, {"raw_path": "C:/secret"},
               {"volume_free": [{"volume": "C:/private", "before_bytes": 1}]})
        for changes in bad:
            with self.subTest(changes=changes):
                error = self.call("finish", "--run-id", "r1", "--outcome", "completed", "--metrics-source", "fixture:v1", "--storage-receipt", self.receipt(**changes), code=2)
                self.assertIn("storage", error)
        self.assertEqual(1, self.call("report")["runs"]["active"])
        missing = self.receipt(before_bytes=None, peak_bytes=None, after_bytes=None, cleanup_failures=None, sample_complete=False)
        ended = self.call("finish", "--run-id", "r1", "--outcome", "partial", "--metrics-source", "fixture:v1", "--storage-receipt", missing)
        self.assertIsNone(ended["run"]["metrics"]["retained_growth_bytes"])
        self.assertIsNone(ended["run"]["metrics"]["peak_additional_bytes"])

    def test_pre_storage_database_records_remain_readable_and_retriable(self):
        self.start()
        self.call("finish", "--run-id", "r1", "--outcome", "completed")
        # The actual preceding recorder stored these JSON shapes without storage fields.
        with contextlib.closing(sqlite3.connect(self.db)) as connection:
            start_json, finish_json = connection.execute("SELECT start_json,finish_json FROM runs WHERE id='r1'").fetchone()
            start, finish = json.loads(start_json), json.loads(finish_json)
            start.pop("storage_threshold_bytes", None)
            finish["request"].pop("storage", None)
            for name in ("retained_growth_bytes", "peak_additional_bytes", "cleanup_failures", "rebuild_seconds"):
                finish["metrics"].pop(name, None)
            connection.execute("UPDATE runs SET start_json=?,finish_json=? WHERE id='r1'", (json.dumps(start,sort_keys=True,separators=(",", ":")), json.dumps(finish)))
            connection.commit()
        self.assertFalse(self.start()["created"])
        result = self.call("finish", "--run-id", "r1", "--outcome", "completed")
        self.assertIsNone(result["run"]["storage"])
        self.assertIsNone(result["run"]["metrics"]["retained_growth_bytes"])
        self.assertEqual(1, self.call("report")["metrics"]["retained_growth_bytes"]["missing"])


    def test_unplanned_storage_receipt_cannot_create_an_unqualified_improvement(self):
        baseline = self.storage_trial("b", "base", threshold=None)
        candidate = self.storage_trial("c", "candidate", threshold=None, seconds="1", after_bytes=250, peak_bytes=300)
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("insufficient", result["verdict"])
        self.assertEqual({"storage-plan-missing"}, {item["reason"] for item in result["excluded"]})

    def test_unrelated_host_space_changes_do_not_change_attributed_storage_verdict(self):
        baseline = self.storage_trial("b", "base", after_bytes=50)
        candidate = self.storage_trial("c", "candidate", after_bytes=50,
                                       volume_free=[{"volume": "output", "before_bytes": 900000, "after_bytes": 1000, "minimum_bytes": 500}])
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("unchanged", result["verdict"])
        self.assertEqual(-50, result["candidate"]["metrics"]["retained_growth_bytes"]["mean"])
        self.assertEqual(0, result["deltas"]["retained_growth_bytes"]["mean_delta"])

    def test_cleanup_failure_and_disk_failed_run_remain_regressions(self):
        for index, changes in enumerate(({"cleanup_failures": 1}, {"outcome": "failed"})):
            with self.subTest(changes=changes):
                self.db = self.root / ("storage-failure-" + str(index) + ".sqlite3")
                baseline = self.storage_trial("b", "base")
                candidate = self.storage_trial("c", "candidate", seconds="1", **changes)
                result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
                self.assertEqual("worsened", result["verdict"])
                self.assertEqual(1, result["candidate"]["runs"]["total"])
                self.assertTrue(result["hard_regressions"])
                if "outcome" in changes:
                    self.assertEqual(1, result["candidate"]["runs"]["failed"])

    def test_incomplete_storage_retains_observed_failed_outcome_as_a_hard_regression(self):
        baseline = self.storage_trial("b", "base")
        candidate = self.storage_trial("c", "candidate", outcome="failed", peak_bytes=None, sample_complete=False)
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("insufficient", result["verdict"])
        self.assertEqual(1, result["candidate"]["runs"]["failed"])
        self.assertIn("completion", {item["metric"] for item in result["hard_regressions"]})

class SlowTests(MetricsCase):
    def test_fractional_thresholds_are_exact_in_both_directions(self):
        cases = (("0.095", "unchanged", -0.05), ("0.105", "unchanged", 0.05),
                 ("0.0949999999999", "improved", None), ("0.1050000000001", "worsened", None))
        for metric in ("cost_usd", "elapsed_seconds"):
            for index, (value, expected, relative) in enumerate(cases):
                with self.subTest(metric=metric, candidate=value):
                    self.db = self.root / (metric + str(index) + ".sqlite3")
                    for pair in ("one",):
                        for side, measured in (("base", "0.1"), ("candidate", value)):
                            run = side + "-" + pair
                            identity = self.trial(run, side, pair, finish=False)
                            if side == "base":
                                baseline = identity
                            else:
                                candidate = identity
                            options = ["--elapsed-seconds", "100", "--cost-usd", "1"]
                            options[options.index("--" + metric.replace("_", "-")) + 1] = measured
                            self.call("finish", "--run-id", run, "--outcome", "completed", "--assessment", "test", "--evidence-ref", "receipt:" + run, "--metrics-source", "fixture:v1", "--safety-violations", "0", "--quality-failures", "0", *options)
                    result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1", "--cost-threshold", "0.05", "--time-threshold", "0.05")
                    self.assertEqual(expected, result["verdict"])
                    if relative is not None:
                        self.assertEqual(relative, result["deltas"][metric]["relative_delta"])


    def test_partial_duplicate_and_unknown_pairs_cannot_create_a_false_improvement(self):
        baseline = self.trial("b-good", "base", "good", seconds="10")
        candidate = self.trial("c-good", "candidate", "good", seconds="1")
        self.trial("b-active", "base", "active")
        self.trial("c-active", "candidate", "active", finish=False)
        self.trial("b-unknown", "base", "unknown")
        self.trial("c-unknown", "candidate", "unknown", safety=None, seconds="1")
        self.trial("b-duplicate", "base", "duplicate")
        self.trial("c-duplicate1", "candidate", "duplicate")
        self.trial("c-duplicate2", "candidate", "duplicate")
        self.trial("b-only", "base", "only")
        self.trial("b-model", "base", "model")
        self.trial("c-model", "candidate", "model", model="different")
        result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("insufficient", result["verdict"])
        self.assertEqual(1, result["matched_pairs"])
        self.assertEqual(6, result["baseline"]["runs"]["total"])
        self.assertEqual(6, result["candidate"]["runs"]["total"])
        self.assertEqual({"incomplete-run", "missing-safety-or-quality", "duplicate-pair", "unmatched-pair", "incomparable-context"}, {item["reason"] for item in result["excluded"]})


    def test_storage_directions_account_for_retained_peak_and_rebuild_tradeoffs(self):
        cases = (
            ({"seconds": "5", "after_bytes": 250, "peak_bytes": 300}, "mixed", 100, 100),
            ({"after_bytes": 120}, "improved", -30, 0),
            ({"after_bytes": 140}, "unchanged", -10, 0),
            ({"after_bytes": 139}, "improved", -11, 0),
            ({"after_bytes": 161}, "worsened", 11, 0),
            ({"peak_bytes": 211}, "worsened", 0, 11),
            ({"after_bytes": 120, "rebuild_seconds": 20}, "mixed", -30, 0),
        )
        for index, (changes, verdict, retained, peak) in enumerate(cases):
            with self.subTest(changes=changes):
                self.db = self.root / ("storage-direction-" + str(index) + ".sqlite3")
                baseline = self.storage_trial("b", "base", rebuild_seconds=1)
                candidate = self.storage_trial("c", "candidate", **({"rebuild_seconds": 1} | changes))
                result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
                self.assertEqual(verdict, result["verdict"])
                self.assertEqual(retained, result["deltas"]["retained_growth_bytes"]["mean_delta"])
                self.assertEqual(peak, result["deltas"]["peak_additional_bytes"]["mean_delta"])
                self.assertEqual(10, result["strata"][0]["context"]["storage_threshold_bytes"])


    def test_storage_missing_or_incomparable_evidence_cannot_be_ignored(self):
        cases = ({"receipt": False}, {"peak_bytes": None}, {"sample_complete": False}, {"cleanup_failures": None},
                 {"cache_state": "cold"}, {"cache_state": "unknown"}, {"method": "allocated-v1"}, {"scope": "other-scope"},
                 {"workload": "other-workload"}, {"provenance": "other-collector"}, {"threshold": 20},
                 {"rebuild_seconds": 1})
        for index, changes in enumerate(cases):
            with self.subTest(changes=changes):
                self.db = self.root / ("storage-incomparable-" + str(index) + ".sqlite3")
                baseline = self.storage_trial("b", "base")
                candidate = self.storage_trial("c", "candidate", seconds="1", **changes)
                result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
                self.assertEqual("insufficient", result["verdict"])
                self.assertTrue(result["excluded"])
                self.assertEqual(1, result["candidate"]["runs"]["total"])


    def command(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), "--db", str(self.db), *args], capture_output=True, text=True, timeout=20)

    def test_concurrent_retries_preserve_one_run_and_one_terminal_outcome(self):
        arguments = ("start", "--run-id", "shared", "--project", "fixture", "--rules-root", str(self.rules), "--skill", "alpha")
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: self.command(*arguments), range(4)))
        self.assertTrue(all(result.returncode == 0 for result in results), [result.stderr for result in results])
        self.assertEqual(1, sum(json.loads(result.stdout)["created"] for result in results))
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda outcome: self.command("finish", "--run-id", "shared", "--outcome", outcome, "--rules-root", str(self.rules)), ("completed", "failed")))
        self.assertEqual([0, 2], sorted(result.returncode for result in results))
        result = self.command("report")
        self.assertEqual(0, result.returncode, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(1, report["runs"]["total"])
        self.assertEqual(1, report["runs"]["finished"])

    def test_resolves_real_git_revision_and_detects_dirty_source(self):
        def git(*args):
            return subprocess.run(["git", "-C", str(self.rules), *args], check=True, capture_output=True, text=True).stdout.strip()
        git("init", "--initial-branch=main")
        git("config", "user.name", "Metrics Test")
        git("config", "user.email", "metrics@example.invalid")
        git("add", ".")
        git("commit", "-m", "fixture")
        result = self.command("start", "--run-id", "clean", "--project", "fixture", "--rules-root", str(self.rules), "--skill", "alpha")
        self.assertEqual(0, result.returncode, result.stderr)
        clean = json.loads(result.stdout)["run"]["source"]
        self.assertEqual(git("rev-parse", "HEAD"), clean["revision"])
        self.assertFalse(clean["dirty"])
        (self.rules / "skills" / "alpha" / "SKILL.md").write_text("changed", encoding="utf-8")
        result = self.command("start", "--run-id", "dirty", "--project", "fixture", "--rules-root", str(self.rules), "--skill", "alpha")
        self.assertEqual(0, result.returncode, result.stderr)
        changed = json.loads(result.stdout)["run"]["source"]
        self.assertEqual(clean["revision"], changed["revision"])
        self.assertNotEqual(clean["digest"], changed["digest"])
        self.assertTrue(changed["dirty"])
        result = self.command("compare", "--baseline", clean["revision"], "--candidate", changed["digest"])
        self.assertEqual(2, result.returncode)
        self.assertIn("multiple content", result.stderr)

    def test_lone_dirty_git_cohort_requires_digest_but_clean_commit_selection_works(self):
        def git(*args):
            return subprocess.run(["git", "-C", str(self.rules), *args], check=True, capture_output=True, text=True).stdout.strip()
        policy = self.rules / "rule-sets" / "ai-rules.md"
        policy.write_text("# Policy base", encoding="utf-8")
        git("init", "--initial-branch=main")
        git("config", "user.name", "Metrics Test")
        git("config", "user.email", "metrics@example.invalid")
        git("add", ".")
        git("commit", "-m", "baseline fixture")
        baseline_commit = git("rev-parse", "HEAD")
        baseline = self.trial("b", "base", "one", seconds="10")
        policy.write_text("# Policy committed-candidate-base", encoding="utf-8")
        git("add", ".")
        git("commit", "-m", "candidate base fixture")
        candidate_commit = git("rev-parse", "HEAD")
        candidate = self.trial("c", "candidate", "one", seconds="5")
        sources = self.call("report")["sources"]
        self.assertEqual([False], [source["dirty"] for source in sources if source["revision"] == baseline_commit])
        self.assertEqual([True], [source["dirty"] for source in sources if source["revision"] == candidate_commit])
        error = self.call("compare", "--baseline", baseline_commit, "--candidate", candidate_commit, "--min-pairs", "1", code=2)
        self.assertIn("exact digest", error)
        digest_result = self.call("compare", "--baseline", baseline, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("improved", digest_result["verdict"])
        clean_result = self.call("compare", "--baseline", baseline_commit, "--candidate", candidate, "--min-pairs", "1")
        self.assertEqual("improved", clean_result["verdict"])
        self.assertEqual(1, clean_result["matched_pairs"])

class TimedResult(unittest.TextTestResult):
    def startTest(self, test):
        self.started = time.perf_counter()
        super().startTest(test)
    def stopTest(self, test):
        self.stream.writeln(f"  duration {test.id()}: {time.perf_counter() - self.started:.3f}s")
        super().stopTest(test)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--lane", choices=("fast", "slow", "combined"), default="combined")
    args = parser.parse_args()
    suite = unittest.TestSuite()
    if args.lane in ("fast", "combined"):
        suite.addTests(unittest.defaultTestLoader.loadTestsFromTestCase(FastTests))
    if args.lane in ("slow", "combined"):
        suite.addTests(unittest.defaultTestLoader.loadTestsFromTestCase(SlowTests))
    runner = unittest.TextTestRunner(verbosity=2, resultclass=TimedResult)
    raise SystemExit(0 if runner.run(suite).wasSuccessful() else 1)