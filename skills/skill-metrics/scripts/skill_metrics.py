"""Local declared skill metrics. Python 3.10+; standard library only."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
from fractions import Fraction
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import statistics
import subprocess
import sys
from urllib.parse import urlsplit

SCHEMA_VERSION = 1
METRICS = ("elapsed_seconds", "input_tokens", "output_tokens", "tool_calls", "cost_usd", "safety_violations", "quality_failures")
STORAGE_METRICS = ("retained_growth_bytes", "peak_additional_bytes", "cleanup_failures", "rebuild_seconds")
ALL_METRICS = (*METRICS, *STORAGE_METRICS)
CONTEXT = ("task_class", "scenario", "scenario_version", "model", "environment", "cohort")
OUTCOMES = ("completed", "partial", "failed", "abandoned")
LABEL = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.:@+\-]{0,127}\Z")
SKILL = re.compile(r"[a-z0-9][a-z0-9-]{0,63}\Z")

class MetricsError(Exception):
    """An input or storage failure."""

class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise MetricsError(message)

def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="microseconds")

def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)

def label(value):
    if not LABEL.fullmatch(value):
        raise argparse.ArgumentTypeError("use a short opaque identifier, not a path or free text")
    return value

def evidence(value):
    if LABEL.fullmatch(value):
        return value
    parsed = urlsplit(value)
    if (len(value) <= 2048 and parsed.scheme == "https" and parsed.hostname and not parsed.username
            and not parsed.password and not parsed.query and not parsed.fragment and not any(c.isspace() for c in value)):
        return value
    raise argparse.ArgumentTypeError("evidence must be an opaque ID or HTTPS URL without credentials, query or fragment")

def nonnegative(value):
    try:
        number = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("expected a finite nonnegative number") from error
    if not math.isfinite(number) or number < 0:
        raise argparse.ArgumentTypeError("expected a finite nonnegative number")
    return number

def count(value):
    if not re.fullmatch(r"\d+", value) or int(value) > 2**53 - 1:
        raise argparse.ArgumentTypeError("expected a nonnegative integer within the exact numeric range")
    return int(value)

def storage_receipt(path):
    if path is None:
        return None
    def reject_constant(_):
        raise MetricsError("storage receipt contains a non-finite number")
    def unique_object(items):
        result = {}
        for key, value in items:
            if key in result:
                raise MetricsError("storage receipt contains a duplicate field")
            result[key] = value
        return result
    try:
        with path.open("rb") as stream:
            raw = stream.read(65537)
        if len(raw) > 65536:
            raise MetricsError("storage receipt exceeds 64 KiB")
        data = json.loads(raw.decode("utf-8-sig"), parse_constant=reject_constant, object_pairs_hook=unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise MetricsError("storage receipt could not be read as JSON") from error
    required = {"schema_version", "scope", "workload", "method", "provenance", "cache_state", "before_bytes",
                "after_bytes", "peak_bytes", "sample_complete", "cleanup_failures", "rebuild_seconds"}
    if not isinstance(data, dict) or required - data.keys() or data.keys() - required - {"volume_free"}:
        raise MetricsError("storage receipt has missing or unknown fields")
    if type(data["schema_version"]) is not int or data["schema_version"] != 1:
        raise MetricsError("unsupported storage receipt schema version")
    for name in ("scope", "workload", "method", "provenance"):
        if not isinstance(data[name], str) or not LABEL.fullmatch(data[name]):
            raise MetricsError("storage receipt identities must be opaque labels")
    if data["cache_state"] not in ("cold", "warm", "mixed", "unknown") or type(data["sample_complete"]) is not bool:
        raise MetricsError("storage receipt has invalid cache state or completeness")
    def number(value, integer=True):
        valid = value is None or (type(value) is int and 0 <= value <= 2**53 - 1)
        if not integer and type(value) is float:
            valid = math.isfinite(value) and value >= 0
        if not valid:
            raise MetricsError("storage observations must be finite nonnegative numbers or null")
    for name in ("before_bytes", "after_bytes", "peak_bytes", "cleanup_failures"):
        number(data[name])
    number(data["rebuild_seconds"], integer=False)
    if data["peak_bytes"] is not None and any(data[name] is not None and data["peak_bytes"] < data[name]
                                               for name in ("before_bytes", "after_bytes")):
        raise MetricsError("storage sampled peak cannot be below observed endpoints")
    observations = data.setdefault("volume_free", [])
    if not isinstance(observations, list) or len(observations) > 64:
        raise MetricsError("storage volume context must be a bounded list")
    seen = set()
    for volume in observations:
        if not isinstance(volume, dict) or set(volume) != {"volume", "before_bytes", "after_bytes", "minimum_bytes"}:
            raise MetricsError("storage volume context has missing or unknown fields")
        if not isinstance(volume["volume"], str) or not LABEL.fullmatch(volume["volume"]) or volume["volume"] in seen:
            raise MetricsError("storage volume identities must be unique opaque labels")
        seen.add(volume["volume"])
        for name in ("before_bytes", "after_bytes", "minimum_bytes"):
            number(volume[name])
        if volume["minimum_bytes"] is not None and any(volume[name] is not None and volume["minimum_bytes"] > volume[name]
                                                       for name in ("before_bytes", "after_bytes")):
            raise MetricsError("storage minimum free space cannot exceed observed endpoints")
    return data


def storage_values(receipt):
    result = dict.fromkeys(STORAGE_METRICS)
    if receipt is not None:
        before = receipt["before_bytes"]
        for target, source in (("retained_growth_bytes", "after_bytes"), ("peak_additional_bytes", "peak_bytes")):
            if before is not None and receipt[source] is not None:
                result[target] = receipt[source] - before
        result.update(cleanup_failures=receipt["cleanup_failures"], rebuild_seconds=receipt["rebuild_seconds"])
    return result


def default_db():
    if os.name == "nt":
        root = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    else:
        root = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    return root / "ai-rules" / "metrics.sqlite3"

def default_rules_root():
    return Path(__file__).resolve().parents[3]

def file_digest(entries):
    digest = hashlib.sha256()
    for name, content in sorted(entries):
        digest.update(name.encode("utf-8") + b"\0" + hashlib.sha256(content).digest())
    return "sha256:" + digest.hexdigest()

def git_identity(root):
    if not (root / ".git").exists():
        return None, None
    try:
        def git(*args):
            result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=10)
            if result.returncode:
                raise MetricsError("unavailable Git identity")
            return result.stdout.strip()
        if Path(git("rev-parse", "--show-toplevel")).resolve() != root:
            return None, None
        return git("rev-parse", "--verify", "HEAD"), bool(git("status", "--porcelain", "--untracked-files=all", "--", "rule-sets", "rules", "skills", "AGENTS.md", "CLAUDE.md", ".ai-rules.json"))
    except (OSError, subprocess.SubprocessError, MetricsError):
        return None, None

def source_entries(root):
    entries = []
    def reject_link(path):
        if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400:
            raise MetricsError("rules content contains a nested link; cannot fingerprint safely")
    def walk_error(error):
        raise error
    for directory in ("rule-sets", "rules", "skills"):
        base = root / directory
        if not base.exists():
            continue
        reject_link(base)
        for current, directories, files in os.walk(base, followlinks=False, onerror=walk_error):
            directories[:] = sorted(name for name in directories if name != "__pycache__")
            for name in directories:
                reject_link(Path(current) / name)
            for name in sorted(files):
                path = Path(current) / name
                if path.suffix in (".pyc", ".pyo"):
                    continue
                reject_link(path)
                entries.append((path.relative_to(root).as_posix(), path.read_bytes()))
    for name in ("AGENTS.md", "CLAUDE.md", ".ai-rules.json"):
        path = root / name
        if path.exists() or path.is_symlink():
            reject_link(path)
            entries.append((name, path.read_bytes()))
    return entries

def snapshot(root, skills):
    root = root.resolve()
    if not (root / "rule-sets").is_dir() or not (root / "skills").is_dir():
        raise MetricsError("rules root must contain rule-sets and skills directories")
    before = git_identity(root)
    entries = source_entries(root)
    packages = {}
    for name in sorted(set(skills)):
        if not SKILL.fullmatch(name) or not (root / "skills" / name / "SKILL.md").is_file():
            raise MetricsError("unknown or invalid skill name")
        prefix = "skills/" + name + "/"
        packages[name] = file_digest([(path[len(prefix):], data) for path, data in entries if path.startswith(prefix)])
    after = git_identity(root)
    digest = file_digest(entries)
    if before != after or digest != file_digest(source_entries(root)):
        raise MetricsError("rules source changed during fingerprint; retry when stable")
    return {"digest": digest, "revision": after[0], "dirty": after[1]}, packages

@contextmanager
def database(path, write=False, create=False):
    path = Path(path).expanduser().resolve()
    if not path.exists() and not create:
        raise MetricsError("metrics database does not exist")
    if create:
        path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(str(path) if write else path.as_uri() + "?mode=ro", uri=not write, timeout=5, isolation_level=None)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA foreign_keys=ON")
        if write:
            connection.execute("BEGIN IMMEDIATE")
        version = connection.execute("PRAGMA user_version").fetchone()[0]
        if version == 0 and create:
            if connection.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchone():
                raise MetricsError("refusing to initialize a nonempty unrelated database")
            connection.execute("CREATE TABLE runs (id TEXT PRIMARY KEY, started_at TEXT NOT NULL, start_json TEXT NOT NULL, finished_at TEXT, finish_json TEXT)")
            connection.execute("CREATE TABLE uses (run_id TEXT NOT NULL REFERENCES runs(id), skill TEXT NOT NULL, digest TEXT NOT NULL, recorded_at TEXT NOT NULL, PRIMARY KEY(run_id,skill))")
            connection.execute("PRAGMA user_version=1")
        elif version != SCHEMA_VERSION:
            raise MetricsError("unsupported metrics database schema version")
        yield connection
        if write:
            connection.commit()
    finally:
        if connection.in_transaction:
            connection.rollback()
        connection.close()

def existing(connection, run_id):
    row = connection.execute("SELECT * FROM runs WHERE id=?", (run_id,)).fetchone()
    if row is None:
        raise MetricsError("unknown run ID")
    return row

def view(connection, row):
    data = json.loads(row["start_json"])
    finished = json.loads(row["finish_json"]) if row["finish_json"] else None
    receipt = finished["request"].get("storage") if finished else None
    data.setdefault("storage_threshold_bytes", None)
    measurements = dict.fromkeys(ALL_METRICS)
    if finished:
        measurements.update(finished["metrics"])
    measurements.update(storage_values(receipt))
    data.update({"run_id": row["id"], "started_at": row["started_at"], "finished_at": row["finished_at"],
                 "state": finished["request"]["outcome"] if finished else "active", "usage_provenance": "declared",
                 "skills": [dict(item) for item in connection.execute("SELECT skill,digest FROM uses WHERE run_id=? ORDER BY skill", (row["id"],))],
                 "metrics": measurements, "storage": receipt,
                 "metrics_source": finished["request"]["metrics_source"] if finished else None,
                 "elapsed_source": finished["elapsed_source"] if finished else None,
                 "source_integrity": finished["source_integrity"] if finished else "pending",
                 "end_source": finished["end_source"] if finished else None,
                 "assessment": finished["request"]["assessment"] if finished else None,
                 "evidence_ref": finished["request"]["evidence_ref"] if finished else None})
    data.pop("initial_skills", None)
    return data

def add_uses(connection, run_id, packages):
    row = existing(connection, run_id)
    for name, digest in packages.items():
        old = connection.execute("SELECT digest FROM uses WHERE run_id=? AND skill=?", (run_id, name)).fetchone()
        if old:
            if old["digest"] != digest:
                raise MetricsError("skill identity conflicts with the recorded exposure")
        elif row["finished_at"]:
            raise MetricsError("cannot add skill use to a finished run")
        else:
            connection.execute("INSERT INTO uses VALUES (?,?,?,?)", (run_id, name, digest, utc_now()))

def start(args):
    if Path(args.db).expanduser().resolve().is_relative_to(args.rules_root.resolve()):
        raise MetricsError("store metrics outside the rules source checkout")
    source, packages = snapshot(args.rules_root, args.skill)
    data = {key: getattr(args, key) for key in (*CONTEXT, "project", "host", "task_ref", "session", "design", "pair")}
    data.update(source=source, initial_skills=sorted(packages))
    if args.storage_threshold_bytes is not None:
        data["storage_threshold_bytes"] = args.storage_threshold_bytes
    if args.design == "matched" and (not args.pair or any(data[key] is None for key in CONTEXT)):
        raise MetricsError("matched runs require pair, task-class, scenario, scenario-version, model, environment and cohort")
    if args.design != "matched" and args.pair:
        raise MetricsError("pair is only valid for matched runs")
    with database(args.db, write=True, create=True) as connection:
        row = connection.execute("SELECT * FROM runs WHERE id=?", (args.run_id,)).fetchone()
        created = row is None
        if row:
            if row["start_json"] != encoded(data):
                raise MetricsError("run ID conflicts with different start facts")
        else:
            connection.execute("INSERT INTO runs(id,started_at,start_json) VALUES (?,?,?)", (args.run_id, utc_now(), encoded(data)))
        add_uses(connection, args.run_id, packages)
        return {"created": created, "run": view(connection, existing(connection, args.run_id))}

def use(args):
    source, packages = snapshot(args.rules_root, args.skill)
    with database(args.db, write=True) as connection:
        if json.loads(existing(connection, args.run_id)["start_json"])["source"] != source:
            raise MetricsError("rules source changed since start; use a new run")
        add_uses(connection, args.run_id, packages)
        return {"run": view(connection, existing(connection, args.run_id))}

def finish(args):
    requested = {key: getattr(args, key) for key in (*METRICS, "outcome", "assessment", "evidence_ref", "metrics_source")}
    requested["storage"] = storage_receipt(args.storage_receipt)
    if (any(requested[key] is not None for key in METRICS) or requested["storage"] is not None) and not args.metrics_source:
        raise MetricsError("supplied measurements require metrics-source provenance")
    if args.assessment != "declared" and not args.evidence_ref:
        raise MetricsError("non-declared assessment requires an evidence reference")
    with database(args.db, write=True) as connection:
        row = existing(connection, args.run_id)
        if row["finish_json"]:
            previous = json.loads(row["finish_json"])["request"]
            previous.setdefault("storage", None)
            if previous != requested:
                raise MetricsError("finished run conflicts with different outcome facts")
        else:
            ended = utc_now()
            interval = (datetime.fromisoformat(ended) - datetime.fromisoformat(row["started_at"])).total_seconds()
            if interval < 0:
                raise MetricsError("clock moved backwards; cannot finalize the recorded interval")
            values = {key: requested[key] for key in METRICS}
            values["elapsed_seconds"] = interval if args.elapsed_seconds is None else args.elapsed_seconds
            try:
                end_source, _ = snapshot(args.rules_root, [])
                integrity = "verified" if end_source == json.loads(row["start_json"])["source"] else "changed"
            except (MetricsError, OSError):
                end_source, integrity = None, "unavailable"
            result = {"request": requested, "metrics": values, "end_source": end_source, "source_integrity": integrity,
                      "elapsed_source": args.metrics_source if args.elapsed_seconds is not None else "recorded-wall-clock"}
            connection.execute("UPDATE runs SET finished_at=?,finish_json=? WHERE id=?", (ended, encoded(result), args.run_id))
        return {"run": view(connection, existing(connection, args.run_id))}

def all_runs(path):
    if not Path(path).expanduser().exists():
        return []
    with database(path) as connection:
        return [view(connection, row) for row in connection.execute("SELECT * FROM runs ORDER BY id")]

def summarize(runs):
    completed = sum(run["state"] == "completed" for run in runs)
    finished = sum(run["state"] != "active" for run in runs)
    counts = {state: sum(run["state"] == state for run in runs) for state in (*OUTCOMES, "active")}
    counts.update(total=len(runs), finished=finished, co_used=sum(len(run["skills"]) > 1 for run in runs),
                  completion_rate=completed / finished if finished else None)
    measured = {}
    for name in ALL_METRICS:
        values = [run["metrics"][name] for run in runs if run["metrics"][name] is not None]
        measured[name] = {"known": len(values), "missing": len(runs) - len(values),
                          "mean": statistics.mean(values) if values else None,
                          "median": statistics.median(values) if values else None}
    return {"runs": counts, "metrics": measured}

def report(args):
    runs = all_runs(args.db)
    sources = sorted({encoded(run["source"]) for run in runs})
    identities = sorted({(skill["skill"], skill["digest"]) for run in runs for skill in run["skills"]})
    skills = []
    for name, digest in identities:
        selected = [run for run in runs if any(item["skill"] == name and item["digest"] == digest for item in run["skills"])]
        skills.append({"skill": name, "digest": digest, **summarize(selected)})
    return {"schema_version": SCHEMA_VERSION, "interpretation": "declared exposure and associated task outcomes; not causal effectiveness",
            **summarize(runs), "sources": [json.loads(value) for value in sources], "skills": skills}

def paired_deltas(pairs):
    result = {}
    for name in ("completion", *ALL_METRICS):
        values = []
        for baseline, candidate in pairs:
            left = int(baseline["state"] == "completed") if name == "completion" else baseline["metrics"][name]
            right = int(candidate["state"] == "completed") if name == "completion" else candidate["metrics"][name]
            if left is not None and right is not None:
                values.append((left, right))
        exact_values = [(Fraction(str(left)), Fraction(str(right))) for left, right in values]
        baseline_mean = sum(left for left, _ in exact_values) / len(values) if values else None
        candidate_mean = sum(right for _, right in exact_values) / len(values) if values else None
        delta = candidate_mean - baseline_mean if values else None
        result[name] = {"known_pairs": len(values), "missing_pairs": len(pairs) - len(values),
                        "baseline_mean": float(baseline_mean) if values else None,
                        "candidate_mean": float(candidate_mean) if values else None,
                        "mean_delta": float(delta) if values else None,
                        "median_delta": float(statistics.median(right - left for left, right in exact_values)) if values else None,
                        "relative_delta": float(delta / baseline_mean) if values and baseline_mean else None}
    return result

def measured_direction(pairs, name, threshold, relative=True):
    # Fractions of recorded decimal representations keep the strict boundary exact.
    values = [(Fraction(str(left["metrics"][name])), Fraction(str(right["metrics"][name])))
              for left, right in pairs if left["metrics"][name] is not None and right["metrics"][name] is not None]
    if not values:
        return None
    baseline = sum(left for left, _ in values)
    delta = sum(right - left for left, right in values)
    scale = baseline if relative else len(values)
    if abs(delta) > Fraction(str(threshold)) * scale:
        return "improved" if delta < 0 else "worsened"
    return None


def select_source(runs, selector):
    selected = [run for run in runs if selector in (run["source"]["digest"], run["source"]["revision"])]
    if len({run["source"]["digest"] for run in selected}) > 1:
        raise MetricsError("revision contains multiple content identities; select an exact digest")
    if any(selector == run["source"]["revision"] and run["source"].get("dirty") is not False for run in selected):
        raise MetricsError("revision includes dirty or unknown source state; select an exact digest")
    return selected

STORAGE_CONTEXT = ("scope", "workload", "method", "provenance", "cache_state")


def storage_pair_reason(first, second):
    planned = any(run["storage_threshold_bytes"] is not None for run in (first, second))
    if not planned and all(run["storage"] is None for run in (first, second)):
        return None
    if any(run["storage_threshold_bytes"] is None for run in (first, second)):
        return "storage-plan-missing"
    if first["storage_threshold_bytes"] != second["storage_threshold_bytes"]:
        return "storage-plan-mismatch"
    receipts = (first["storage"], second["storage"])
    if any(receipt is None for receipt in receipts):
        return "storage-evidence-missing"
    if any(not receipt["sample_complete"] or any(receipt[name] is None for name in
           ("before_bytes", "after_bytes", "peak_bytes", "cleanup_failures")) for receipt in receipts):
        return "storage-observation-incomplete"
    if any(receipt["cache_state"] not in ("cold", "warm") for receipt in receipts):
        return "storage-cache-state-unknown"
    if any(receipts[0][name] != receipts[1][name] for name in STORAGE_CONTEXT):
        return "storage-context-mismatch"
    if (receipts[0]["rebuild_seconds"] is None) != (receipts[1]["rebuild_seconds"] is None):
        return "storage-rebuild-incomplete"
    return None


def compare(args):
    if args.baseline == args.candidate:
        raise MetricsError("baseline and candidate must be distinct identities")
    if args.min_pairs < 1:
        raise MetricsError("min-pairs must be positive")
    runs = all_runs(args.db)
    baseline, candidate = (select_source(runs, selector) for selector in (args.baseline, args.candidate))
    if {run["source"]["digest"] for run in baseline} & {run["source"]["digest"] for run in candidate}:
        raise MetricsError("baseline and candidate resolve to the same content identity")
    groups, excluded, pairs, strata = {}, [], [], {}
    assessed_pairs = []
    blocking = False
    for side, selected in ((0, baseline), (1, candidate)):
        for run in selected:
            if run["design"] != "matched":
                excluded.append({"run_id": run["run_id"], "reason": "observational"})
                continue
            key = (run["cohort"], run["pair"])
            groups.setdefault(key, [[], []])[side].append(run)
    for key, (left, right) in sorted(groups.items()):
        reason = None
        if len(left) > 1 or len(right) > 1:
            reason = "duplicate-pair"
        elif not left or not right:
            reason = "unmatched-pair"
        else:
            first, second = left[0], right[0]
            dimensions = (*CONTEXT, "project", "host", "assessment", "metrics_source", "elapsed_source")
            if first["state"] == "active" or second["state"] == "active":
                reason = "incomplete-run"
            elif first["source_integrity"] != "verified" or second["source_integrity"] != "verified":
                reason = "source-not-verified"
            elif any(first[field] != second[field] for field in dimensions):
                reason = "incomparable-context"
            elif first["assessment"] == "declared":
                reason = "unverified-assessment"
            elif any(run["metrics"][field] is None for run in (first, second) for field in ("safety_violations", "quality_failures")):
                reason = "missing-safety-or-quality"
            else:
                assessed_pairs.append((first, second))
                reason = storage_pair_reason(first, second)
        if reason:
            blocking = True
            excluded.extend({"run_id": run["run_id"], "reason": reason} for run in (*left, *right))
        else:
            pairs.append((first, second))
            context = {field: first[field] for field in dimensions}
            context["storage_threshold_bytes"] = first["storage_threshold_bytes"]
            context["storage"] = {name: first["storage"][name] for name in STORAGE_CONTEXT} if first["storage"] else None
            stratum = strata.setdefault(encoded(context), {"context": context, "pairs": []})
            stratum["pairs"].append((first, second))
    deltas = paired_deltas(pairs)
    hard_regressions = []
    for first, second in assessed_pairs:
        if first["state"] == "completed" and second["state"] != "completed":
            hard_regressions.append({"pair": first["pair"], "cohort": first["cohort"], "metric": "completion"})
        for field in ("quality_failures", "safety_violations", "cleanup_failures"):
            if (first["metrics"][field] is not None and second["metrics"][field] is not None
                    and second["metrics"][field] > first["metrics"][field]):
                hard_regressions.append({"pair": first["pair"], "cohort": first["cohort"], "metric": field})
    directions = set()
    for stratum in strata.values():
        changes = paired_deltas(stratum["pairs"])
        if changes["completion"]["mean_delta"] > 0 or any(changes[name]["mean_delta"] < 0 for name in ("safety_violations", "quality_failures")):
            directions.add("improved")
        for name, threshold in (("elapsed_seconds", args.time_threshold), ("cost_usd", args.cost_threshold)):
            direction = measured_direction(stratum["pairs"], name, threshold)
            if direction:
                directions.add(direction)
        if stratum["context"]["storage_threshold_bytes"] is not None:
            for name in ("retained_growth_bytes", "peak_additional_bytes"):
                direction = measured_direction(stratum["pairs"], name, stratum["context"]["storage_threshold_bytes"], relative=False)
                if direction:
                    directions.add(direction)
            direction = measured_direction(stratum["pairs"], "rebuild_seconds", args.time_threshold)
            if direction:
                directions.add(direction)
            if changes["cleanup_failures"]["mean_delta"] < 0:
                directions.add("improved")
        stratum["matched_pairs"] = len(stratum.pop("pairs"))
        stratum["deltas"] = changes
    if blocking or len(pairs) < args.min_pairs:
        verdict = "insufficient"
    elif hard_regressions:
        verdict = "worsened"
    elif len(directions) > 1:
        verdict = "mixed"
    else:
        verdict = next(iter(directions), "unchanged")
    return {"schema_version": SCHEMA_VERSION, "verdict": verdict, "matched_pairs": len(pairs),
            "interpretation": "observed results in declared matched cohorts; not proof of causality or statistical significance",
            "settings": {"min_pairs": args.min_pairs, "time_threshold": args.time_threshold, "cost_threshold": args.cost_threshold,
                         "storage_tolerance": "absolute bytes declared at start for each matched stratum",
                         "safety_quality_cleanup_tolerance": 0, "safety_quality_tolerance": 0, "required_assessment": "test, independent or user with evidence reference"},
            "baseline": {"selector": args.baseline, **summarize(baseline)},
            "candidate": {"selector": args.candidate, **summarize(candidate)},
            "excluded": sorted(excluded, key=lambda item: item["run_id"]), "hard_regressions": hard_regressions,
            "deltas": deltas, "strata": [strata[key] for key in sorted(strata)],
            "limitations": ["Enrollment outside recorded runs is unknown.", "Missing optional cost/token data is not zero; directions describe measured dimensions only.",
                            "Storage peaks are sampled lower bounds in the named measurement scope; logical bytes are not reclaimable physical space.",
                            "Host volume free space is context only and never attributed to a task.",
                            "Rebuild duration is a separate dimension, never added to elapsed time; missing rebuild costs remain unknown."]}

def parser():
    root = Parser(description=__doc__)
    root.add_argument("--db", type=Path, default=default_db())
    commands = root.add_subparsers(dest="command", required=True)
    for name in ("start", "use"):
        command = commands.add_parser(name)
        command.add_argument("--run-id", type=label, required=True)
        command.add_argument("--rules-root", type=Path, default=default_rules_root())
        command.add_argument("--skill", action="append", default=[], required=name == "use")
        if name == "start":
            command.add_argument("--project", type=label, required=True)
            command.add_argument("--storage-threshold-bytes", type=count)
            for field in (*CONTEXT, "host", "session", "pair"):
                command.add_argument("--" + field.replace("_", "-"), type=label)
            command.add_argument("--task-ref", type=evidence)
            command.add_argument("--design", choices=("observational", "matched"), default="observational")
    command = commands.add_parser("finish")
    command.add_argument("--rules-root", type=Path, default=default_rules_root())
    command.add_argument("--run-id", type=label, required=True)
    command.add_argument("--outcome", choices=OUTCOMES, required=True)
    command.add_argument("--assessment", choices=("declared", "test", "independent", "user"), default="declared")
    command.add_argument("--evidence-ref", type=evidence)
    command.add_argument("--metrics-source", type=label)
    command.add_argument("--storage-receipt", type=Path)
    for name in METRICS:
        command.add_argument("--" + name.replace("_", "-"), type=nonnegative if name in ("elapsed_seconds", "cost_usd") else count)
    commands.add_parser("report")
    command = commands.add_parser("compare")
    command.add_argument("--baseline", required=True)
    command.add_argument("--candidate", required=True)
    command.add_argument("--min-pairs", type=count, default=3)
    command.add_argument("--time-threshold", type=nonnegative, default=0.05)
    command.add_argument("--cost-threshold", type=nonnegative, default=0.05)
    return root

def main(argv=None):
    try:
        args = parser().parse_args(argv)
        result = {"start": start, "use": use, "finish": finish, "report": report, "compare": compare}[args.command](args)
        print(json.dumps(result, sort_keys=True, allow_nan=False))
        return 0
    except (MetricsError, OSError, sqlite3.Error, ValueError) as error:
        print("error: " + str(error), file=sys.stderr)
        return 2

if __name__ == "__main__":
    raise SystemExit(main())