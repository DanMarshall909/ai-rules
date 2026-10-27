"""Bounded storage inventory, admission and managed disposable runs. Python 3.10+."""
import argparse
import json
from contextlib import ExitStack, contextmanager
import re
import signal
import tempfile
import uuid
import math
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time

class StorageError(ValueError):
    """A missing capability, invalid budget or unsafe target."""


def safe_path(path):
    """Reject linked ancestors before resolving any filesystem target."""
    path = Path(os.path.abspath(path))
    for part in reversed((path, *path.parents)):
        value = part.lstat()
        if stat.S_ISLNK(value.st_mode) or getattr(value, "st_file_attributes", 0) & 0x400:
            raise StorageError("linked-path")
    return path


def identity(path):
    value = path.lstat()
    return value.st_dev, value.st_ino


def category(parts, tracked):
    lowered = [part.lower() for part in parts]
    if ".git" in lowered:
        return "git"
    for label, names in (("dependencies", {"node_modules", ".venv", "venv", "packages"}),
                         ("build", {"bin", "obj", "target", "dist", "build"}),
                         ("evidence", {"artifacts", ".artifacts", "testresults", "coverage", "reports"})):
        if any(part in names for part in lowered):
            return label
    return "source" if "/".join(parts) in tracked else "unknown"


def inventory(roots, *, max_depth=64, max_entries=100000, max_seconds=5.0, tracked=None):
    if not 0 <= max_depth <= 256 or not 1 <= max_entries <= 1000000 or not 0 < max_seconds <= 60:
        raise StorageError("invalid-scan-bound")
    roots = list(roots)
    if not roots or len(roots) > 128:
        raise StorageError("inventory needs 1..128 explicit roots")
    visited_files, visited_dirs, rows = set(), set(), []
    for root in roots:
        row = {"root": str(Path(os.path.abspath(root))), "logical_bytes": None,
               "allocated_bytes": None, "reclaimable_bytes": None, "cleanup_authorized": False,
               "categories": dict.fromkeys(("source", "build", "dependencies", "evidence", "unknown", "git"), 0),
               "complete": True, "diagnostics": [], "files": 0, "shared_entries": 0}
        rows.append(row)
        def gap(reason):
            row["complete"] = False
            if reason not in row["diagnostics"]:
                row["diagnostics"].append(reason)
        try:
            path = safe_path(root)
            if path == Path(path.anchor) or not path.is_dir():
                raise StorageError("root-must-be-a-bounded-directory")
            row["logical_bytes"] = 0
            stack, count, started = [(path, (), 0)], 0, time.monotonic()
            while stack:
                if time.monotonic() - started >= max_seconds:
                    gap("time-limit"); break
                current, parts, depth = stack.pop()
                safe_path(current)
                directory_id = identity(current)
                if directory_id in visited_dirs:
                    row["shared_entries"] += 1; continue
                visited_dirs.add(directory_id)
                try:
                    with os.scandir(current) as entries:
                        for entry in entries:
                            count += 1
                            if count > max_entries:
                                gap("entry-limit"); stack.clear(); break
                            if time.monotonic() - started >= max_seconds:
                                gap("time-limit"); stack.clear(); break
                            try:
                                value = os.stat(entry.path, follow_symlinks=False)
                                if stat.S_ISLNK(value.st_mode) or getattr(value, "st_file_attributes", 0) & 0x400:
                                    gap("linked-entry"); continue
                                child_parts = (*parts, entry.name)
                                key = (value.st_dev, value.st_ino)
                                if stat.S_ISDIR(value.st_mode):
                                    if depth >= max_depth:
                                        gap("depth-limit")
                                    else:
                                        stack.append((Path(entry.path), child_parts, depth + 1))
                                elif stat.S_ISREG(value.st_mode):
                                    if key in visited_files:
                                        row["shared_entries"] += 1; continue
                                    visited_files.add(key)
                                    if value.st_nlink > 1:
                                        row["shared_entries"] += 1
                                    row["logical_bytes"] += value.st_size
                                    row["categories"][category(child_parts, (tracked or {}).get(str(path), set()))] += value.st_size
                                    row["files"] += 1
                                else:
                                    gap("non-regular-entry")
                            except OSError:
                                gap("unreadable-entry")
                except OSError:
                    gap("unreadable-directory")
        except (OSError, StorageError) as error:
            gap(str(error) if isinstance(error, StorageError) else "unavailable-root")
    return {"schema_version": 1, "method": "logical-v1", "roots": rows,
            "complete": all(row["complete"] for row in rows),
            "limitations": ["Category names are hints; tracked non-output files are source. Unknown files are preserved.",
                            "Logical sizes deduplicate file identities, not shared extents. Allocation and reclaimable bytes remain unknown.",
                            "A scan is a bounded observation, not a snapshot or deletion authority."]}


def registered_roots(repositories):
    roots, tracked, diagnostics = [], {}, []
    for repository in repositories:
        try:
            safe_path(repository)
            result = subprocess.run(["git", "-C", str(repository), "worktree", "list", "--porcelain", "-z"],
                                    capture_output=True, timeout=10, check=True)
            for record in result.stdout.decode("utf-8", "surrogateescape").split("\0"):
                if record.startswith("worktree "):
                    root = str(Path(os.path.abspath(record[9:])))
                    if root not in roots:
                        roots.append(root)
                        files = subprocess.run(["git", "-C", root, "ls-files", "-z"], capture_output=True, timeout=10)
                        if files.returncode:
                            diagnostics.append("tracked-files-unavailable")
                        else:
                            tracked[root] = set(files.stdout.decode("utf-8", "surrogateescape").split("\0"))
        except (OSError, StorageError, subprocess.SubprocessError):
            diagnostics.append("worktree-inventory-unavailable")
    return roots, tracked, diagnostics


def budget(config, workload):
    if not isinstance(config, dict):
        raise StorageError("invalid-disk-budget")
    if config.get("schemaVersion") == 1:
        raise StorageError("disk-budget-unavailable: version 1 remains readable but has no disk admission budget")
    try:
        if config["schemaVersion"] != 2:
            raise ValueError()
        value = config["resources"]["disk"]["workloads"][workload]
        keys = {"reserveMiB", "outputGrowthMiB", "tempGrowthMiB", "retainedBudgetMiB", "basis"}
        if not keys <= value.keys():
            raise ValueError()
        for name in ("reserveMiB", "outputGrowthMiB", "tempGrowthMiB", "retainedBudgetMiB"):
            if type(value[name]) is not int or not (1 if name == "reserveMiB" else 0) <= value[name] <= 2**32:
                raise ValueError()
        if value["basis"] == "estimated":
            if set(value) != keys | {"estimateReason"} or not isinstance(value["estimateReason"], str) or not value["estimateReason"].strip():
                raise ValueError()
        elif value["basis"] == "measured":
            evidence = value["measurement"]
            if set(value) != keys | {"measurement"} or set(evidence) != {"workload", "date", "evidence"}:
                raise ValueError()
            if not all(isinstance(evidence[key], str) and evidence[key].strip() for key in evidence):
                raise ValueError()
            from datetime import date
            date.fromisoformat(evidence["date"])
        else:
            raise ValueError()
        return value
    except (KeyError, TypeError, ValueError, AttributeError) as error:
        raise StorageError("invalid-disk-budget: named workload needs a complete version 2 budget with provenance") from error


def volume_info(path):
    path = safe_path(path)
    if not path.is_dir():
        raise StorageError("volume-target-not-directory")
    return {"id": str(path.stat().st_dev), "free_bytes": shutil.disk_usage(path).free, "path": str(path)}


def admit(config, workload, output_parent, temp_parent, *, observe=volume_info):
    value = budget(config, workload)
    volumes = {}
    for role, parent, field in (("output", output_parent, "outputGrowthMiB"), ("temp", temp_parent, "tempGrowthMiB")):
        path = safe_path(parent)
        observation = observe(path)
        if not isinstance(observation.get("id"), str) or type(observation.get("free_bytes")) is not int or observation["free_bytes"] < 0:
            raise StorageError("unavailable-volume-observation")
        row = volumes.setdefault(observation["id"], {"id": observation["id"], "roles": [], "paths": [],
                                 "free_bytes": observation["free_bytes"], "growth_bytes": 0,
                                 "reserve_bytes": value["reserveMiB"] * 1024**2})
        row["roles"].append(role); row["paths"].append(str(path))
        row["free_bytes"] = min(row["free_bytes"], observation["free_bytes"])
        row["growth_bytes"] += value[field] * 1024**2
    for row in volumes.values():
        row["required_bytes"] = row["growth_bytes"] + row["reserve_bytes"]
        row["shortfall_bytes"] = max(0, row["required_bytes"] - row["free_bytes"])
    return {"schema_version": 1, "admitted": all(row["shortfall_bytes"] == 0 for row in volumes.values()),
            "workload": workload, "basis": value["basis"], "volumes": list(volumes.values()),
            "retained_budget_bytes": value["retainedBudgetMiB"] * 1024**2,
            "limitation": "Admission is an immediate observation, not a reservation; competing jobs may consume space."}


@contextmanager
def locked_directory(path):
    """Windows denies directory rename while we traverse an owned tree."""
    if os.name != "nt":
        yield
        return
    import ctypes as c
    from ctypes import wintypes as w
    kernel = c.WinDLL("kernel32", use_last_error=True)
    create = kernel.CreateFileW
    create.argtypes = [w.LPCWSTR, w.DWORD, w.DWORD, c.c_void_p, w.DWORD, w.DWORD, w.HANDLE]
    create.restype = w.HANDLE
    close = kernel.CloseHandle; close.argtypes = [w.HANDLE]; close.restype = w.BOOL
    handle = create(str(path), 0x80, 3, None, 3, 0x02000000 | 0x00200000, None)
    if handle == c.c_void_p(-1).value:
        raise c.WinError(c.get_last_error())
    try:
        safe_path(path)
        yield
    finally:
        close(handle)


def remove_owned_tree(path, expected_identity, parent_identity):
    if os.name != "nt":
        # Resolve relative to a validated directory descriptor. A rename of any
        # pathname ancestor cannot redirect these operations into another tree.
        needed = (os.open, os.stat, os.unlink, os.rmdir)
        if not all(function in os.supports_dir_fd for function in needed) or not hasattr(os, "O_NOFOLLOW"):
            raise StorageError("safe-recursive-removal-unavailable")
        flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
        parent_fd = os.open(path.parent, flags)
        def file_id(value):
            return value.st_dev, value.st_ino
        def check_entry(parent, name, expected):
            if file_id(os.stat(name, dir_fd=parent, follow_symlinks=False)) != expected:
                raise StorageError("ownership-path-changed")
        def remove_at(parent, name, expected):
            check_entry(parent, name, expected)
            fd = os.open(name, flags, dir_fd=parent)
            try:
                if file_id(os.fstat(fd)) != expected:
                    raise StorageError("ownership-path-changed")
                names = os.listdir(fd)
                if len(names) > 100000:
                    raise StorageError("cleanup-entry-limit")
                for child in names:
                    check_entry(parent, name, expected)
                    value = os.stat(child, dir_fd=fd, follow_symlinks=False)
                    if stat.S_ISDIR(value.st_mode):
                        remove_at(fd, child, file_id(value))
                    elif stat.S_ISREG(value.st_mode):
                        os.unlink(child, dir_fd=fd)
                    else:
                        raise StorageError("unsafe-cleanup-entry")
                check_entry(parent, name, expected)
                os.rmdir(name, dir_fd=parent)
            finally:
                os.close(fd)
        try:
            if file_id(os.fstat(parent_fd)) != parent_identity:
                raise StorageError("ownership-parent-changed")
            remove_at(parent_fd, path.name, expected_identity)
        finally:
            os.close(parent_fd)
        return
    # Keep each traversed directory locked against rename. Never follow links,
    # including a link substituted between initial scan and deletion.
    with locked_directory(path):
        if identity(path) != expected_identity or identity(path.parent) != parent_identity:
            raise StorageError("ownership-path-changed")
        with os.scandir(path) as entries:
            names = [entry.name for entry in entries]
        for name in names:
            child = path / name
            safe_path(child)
            value = child.lstat()
            if stat.S_ISDIR(value.st_mode):
                remove_owned_tree(child, identity(child), identity(path))
            elif stat.S_ISREG(value.st_mode):
                child.unlink()
            else:
                raise StorageError("unsafe-cleanup-entry")
    path.rmdir()


class OwnedDirectory:
    """Only fresh directories created by this instance have cleanup authority."""
    def __init__(self, parent, *, registry=None):
        parent = safe_path(parent)
        self.ancestors = {item: identity(item) for item in (parent, *parent.parents)}
        self.directory_id = None
        self.marker_ready = False
        self.token = uuid.uuid4().hex
        self.path = Path(tempfile.mkdtemp(prefix="ai-rules-run-", dir=parent))
        # Register the fresh allocation before any further fallible filesystem
        # operation. A disk-full marker write must not make this path disappear
        # from the supervisor's ownership and cleanup accounting.
        if registry is not None:
            registry.append(self)
        self.marker = self.path / ".ai-rules-owner"
        try:
            self.directory_id = identity(self.path)
            self.marker.write_text(self.token, encoding="ascii")
            self.marker_ready = True
        except BaseException:
            if registry is None:
                self.cleanup(workers_stopped=True)
            raise
    def verify(self):
        safe_path(self.path)
        if identity(self.path) != self.directory_id or any(identity(path) != expected for path, expected in self.ancestors.items()):
            raise StorageError("ownership-path-changed")
        # Before initialization completes, the creator's retained directory ID
        # is the authority. No child is launched until both markers are ready.
        if self.marker_ready:
            safe_path(self.marker)
            if self.marker.lstat().st_size != len(self.token) or self.marker.read_text(encoding="ascii") != self.token:
                raise StorageError("ownership-marker-changed")
    def cleanup(self, *, workers_stopped):
        if not workers_stopped:
            return False
        try:
            with ExitStack() as locks:
                for ancestor in reversed(tuple(self.ancestors)):
                    locks.enter_context(locked_directory(ancestor))
                self.verify()
                inspected = inventory([self.path], max_seconds=5)
                if not inspected["complete"]:
                    return False
                self.verify()
                remove_owned_tree(self.path, self.directory_id, self.ancestors[self.path.parent])
                return not os.path.lexists(self.path)
        except (OSError, StorageError, UnicodeError):
            return False


def run_managed(config, workload, output_parent, temp_parent, receipt_path, command, *, scope,
                cache_state, timeout=3600, sample_seconds=1, source=None):
    import process_group
    if (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.:@+\-]{0,127}", scope)
            or not re.fullmatch(r"[a-z][a-z0-9-]{0,63}", workload)
            or cache_state not in ("cold", "warm", "mixed", "unknown")
            or not math.isfinite(timeout) or not 0 < timeout <= 86400
            or not math.isfinite(sample_seconds) or not .02 <= sample_seconds <= 60 or not command):
        raise StorageError("invalid-run-contract")
    receipt_path = Path(os.path.abspath(receipt_path))
    safe_path(receipt_path.parent)
    if os.path.lexists(receipt_path):
        raise StorageError("receipt-already-exists")
    if source:
        source = safe_path(source)
        if any(safe_path(parent).is_relative_to(source) for parent in (output_parent, temp_parent)):
            raise StorageError("output-inside-source: choose parents outside the copy source")
    decision = admit(config, workload, output_parent, temp_parent)
    receipt = {"schema_version": 1, "scope": scope, "workload": workload, "method": "logical-v1",
               "provenance": "storage-budget-v1", "cache_state": cache_state,
               "before_bytes": 0, "after_bytes": None, "peak_bytes": None,
               "sample_complete": False, "cleanup_failures": None, "rebuild_seconds": None,
               "volume_free": [{"volume": "volume-" + str(index + 1), "before_bytes": row["free_bytes"],
                                "after_bytes": None, "minimum_bytes": row["free_bytes"]}
                               for index, row in enumerate(decision["volumes"])]}
    result = {"admission": decision, "receipt": receipt, "command_exit_code": None,
              "workers_stopped": True, "reason": "insufficient-disk" if not decision["admitted"] else "completed",
              "retained_paths": [], "output_tail": ""}
    with receipt_path.open("x", encoding="utf-8") as receipt_file:
        if not decision["admitted"]:
            receipt.update(after_bytes=0, cleanup_failures=0)
            json.dump(receipt, receipt_file, sort_keys=True, allow_nan=False)
            return result
        owned, group, output, old_term = [], None, None, None
        peak, complete, started = None, True, time.monotonic()
        try:
            OwnedDirectory(output_parent, registry=owned)
            OwnedDirectory(temp_parent, registry=owned)
            environment = dict(os.environ, AI_RULES_RUN_DIR=str(owned[0].path), TEMP=str(owned[1].path), TMP=str(owned[1].path), TMPDIR=str(owned[1].path))
            output = (owned[1].path / "command-output.log").open("w+b")
            result["workers_stopped"] = False
            group = process_group.launch(command, environment, output)
            def cancelled(signum, frame):
                raise KeyboardInterrupt()
            old_term = signal.signal(signal.SIGTERM, cancelled)
            while True:
                measured = inventory([item.path for item in owned], max_entries=100000, max_seconds=min(1, sample_seconds))
                complete &= measured["complete"]
                if measured["complete"]:
                    peak = max(peak or 0, sum(row["logical_bytes"] for row in measured["roots"]) - sum(len(item.token) for item in owned))
                for index, row in enumerate(decision["volumes"]):
                    current = volume_info(row["paths"][0])
                    if current["id"] != row["id"]:
                        raise StorageError("volume-identity-changed")
                    receipt["volume_free"][index]["minimum_bytes"] = min(receipt["volume_free"][index]["minimum_bytes"], current["free_bytes"])
                    if current["free_bytes"] < row["reserve_bytes"]:
                        result["reason"] = "disk-reserve-crossed"
                exit_code = group.poll()
                if exit_code is not None:
                    result["command_exit_code"] = exit_code
                    if result["reason"] == "completed" and exit_code:
                        result["reason"] = "command-failed"
                    break
                if result["reason"] != "completed":
                    break
                if time.monotonic() - started >= timeout:
                    result["reason"] = "timeout"; break
                time.sleep(sample_seconds)
        except KeyboardInterrupt:
            result["reason"] = "cancelled"
        except (OSError, StorageError, subprocess.SubprocessError) as error:
            result["reason"] = "execution-error"
            result["error"] = str(error)
            if isinstance(error, process_group.LaunchError):
                result["workers_stopped"] = error.workers_stopped
            complete = False
        finally:
            if old_term is not None:
                signal.signal(signal.SIGTERM, old_term)
            if group:
                try:
                    result["workers_stopped"] = group.stop()
                except (OSError, subprocess.SubprocessError):
                    result["workers_stopped"] = False
                finally:
                    group.close()
            if output:
                try:
                    output.flush(); output.seek(0, 2); size = output.tell()
                    output.seek(max(0, size - 16384)); result["output_tail"] = output.read().decode("utf-8", "replace")
                finally:
                    output.close()
            if owned and result["workers_stopped"]:
                final_sample = inventory([item.path for item in owned])
                complete &= final_sample["complete"]
                if final_sample["complete"]:
                    peak = max(peak or 0, sum(row["logical_bytes"] for row in final_sample["roots"]) - sum(len(item.token) for item in owned))
            failures = 0
            for item in owned:
                if not item.cleanup(workers_stopped=result["workers_stopped"]):
                    failures += 1; result["retained_paths"].append(str(item.path))
            receipt["cleanup_failures"] = failures
            receipt["peak_bytes"] = max(0, peak) if peak is not None else None
            receipt["sample_complete"] = bool(complete and result["workers_stopped"] and len(owned) == 2)
            if failures:
                remaining_paths = [item.path for item in owned if os.path.lexists(item.path)]
                remaining = inventory(remaining_paths) if remaining_paths else None
                receipt["after_bytes"] = (sum(row["logical_bytes"] for row in remaining["roots"])
                                          if remaining and remaining["complete"] and len(remaining_paths) == failures
                                          and all(item.marker_ready for item in owned) else None)
                if receipt["after_bytes"] is None:
                    receipt["sample_complete"] = False
                if receipt["after_bytes"] is not None:
                    # After a cleanup failure, marker provenance may be lost;
                    # report the conservative whole remaining footprint.
                    receipt["peak_bytes"] = max(receipt["peak_bytes"] or 0, receipt["after_bytes"])
            else:
                receipt["after_bytes"] = 0
            for index, row in enumerate(decision["volumes"]):
                try:
                    current = volume_info(row["paths"][0])
                    if current["id"] == row["id"]:
                        receipt["volume_free"][index]["after_bytes"] = current["free_bytes"]
                        receipt["volume_free"][index]["minimum_bytes"] = min(receipt["volume_free"][index]["minimum_bytes"], current["free_bytes"])
                except (OSError, StorageError):
                    pass
            result["retention_review_required"] = receipt["after_bytes"] is None or receipt["after_bytes"] > decision["retained_budget_bytes"]
            json.dump(receipt, receipt_file, sort_keys=True, allow_nan=False)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    scan = commands.add_parser("inventory")
    scan.add_argument("--root", action="append", default=[])
    scan.add_argument("--repo", action="append", default=[])
    scan.add_argument("--config", type=Path)
    scan.add_argument("--workload")
    scan.add_argument("--max-depth", type=int, default=64)
    scan.add_argument("--max-entries", type=int, default=100000)
    scan.add_argument("--max-seconds", type=float, default=5)
    check = commands.add_parser("check")
    check.add_argument("--config", type=Path, default=Path(".ai-rules.json"))
    check.add_argument("--workload", required=True)
    check.add_argument("--output-parent", type=Path, required=True)
    check.add_argument("--temp-parent", type=Path, required=True)
    run = commands.add_parser("run")
    run.add_argument("--config", type=Path, default=Path(".ai-rules.json"))
    run.add_argument("--workload", required=True)
    run.add_argument("--output-parent", type=Path, required=True)
    run.add_argument("--temp-parent", type=Path, required=True)
    run.add_argument("--receipt", type=Path, required=True)
    run.add_argument("--scope", required=True)
    run.add_argument("--cache-state", choices=("cold", "warm", "mixed", "unknown"), required=True)
    run.add_argument("--source", type=Path)
    run.add_argument("--timeout-seconds", type=float, default=3600)
    run.add_argument("--sample-seconds", type=float, default=1)
    run.add_argument("child_command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    try:
        if args.command == "run":
            command = args.child_command[1:] if args.child_command[:1] == ["--"] else args.child_command
            result = run_managed(json.loads(args.config.read_text(encoding="utf-8")), args.workload, args.output_parent,
                                 args.temp_parent, args.receipt, command, scope=args.scope, cache_state=args.cache_state,
                                 timeout=args.timeout_seconds, sample_seconds=args.sample_seconds, source=args.source)
            print(json.dumps(result, sort_keys=True, allow_nan=False))
            return 0 if result["reason"] == "completed" and result["receipt"]["cleanup_failures"] == 0 else 3
        if args.command == "check":
            result = admit(json.loads(args.config.read_text(encoding="utf-8")), args.workload, args.output_parent, args.temp_parent)
            print(json.dumps(result, sort_keys=True, allow_nan=False))
            return 0 if result["admitted"] else 3
        roots, tracked, diagnostics = registered_roots(args.repo)
        result = inventory([*roots, *args.root], max_depth=args.max_depth, max_entries=args.max_entries,
                           max_seconds=args.max_seconds, tracked=tracked)
        if bool(args.config) != bool(args.workload):
            raise StorageError("inventory retention review needs both config and workload")
        if args.config:
            retention = budget(json.loads(args.config.read_text(encoding="utf-8")), args.workload)["retainedBudgetMiB"] * 1024**2
            known = sum(row["categories"][key] for row in result["roots"] for key in ("build", "dependencies", "evidence"))
            unknown = sum(row["categories"]["unknown"] for row in result["roots"])
            result["retention"] = {"budget_bytes": retention, "known_output_logical_bytes": known,
                                   "unknown_logical_bytes": unknown, "review_required": known > retention or unknown > 0 or not result["complete"] or bool(diagnostics),
                                   "cleanup_authorized": False}
        result["diagnostics"] = diagnostics
        result["complete"] &= not diagnostics
        print(json.dumps(result, sort_keys=True, allow_nan=False))
        return 0 if result["complete"] else 3
    except (StorageError, OSError, ValueError) as error:
        print("error: " + str(error), file=sys.stderr)
        return 2

if __name__ == "__main__":
    raise SystemExit(main())
