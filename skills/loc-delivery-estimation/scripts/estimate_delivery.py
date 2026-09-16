#!/usr/bin/env python3
"""Estimate delivery time from comparable Git changed-line throughput."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime
import fnmatch
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Sequence


class EstimationError(RuntimeError):
    """An input or repository state cannot support the requested estimate."""


@dataclass(frozen=True)
class Churn:
    added: int
    deleted: int
    binary_files_ignored: int = 0

    @property
    def total(self) -> int:
        return self.added + self.deleted


def git(
    repository: Path,
    *arguments: str,
    input_text: str | None = None,
    text: bool = True,
) -> str | bytes:
    try:
        completed = subprocess.run(
            ["git", "-C", str(repository), *arguments],
            input=input_text,
            check=True,
            capture_output=True,
            text=text,
        )
    except FileNotFoundError as error:
        raise EstimationError("Git is not available on PATH.") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() if error.stderr else str(error)
        raise EstimationError(f"git {' '.join(arguments)} failed: {detail}") from error
    return completed.stdout.strip() if text else completed.stdout


def is_excluded(path: str, patterns: Sequence[str]) -> bool:
    normalized = path.replace("\\", "/")
    return any(fnmatch.fnmatch(normalized, pattern) for pattern in patterns)


def parse_numstat(output: str, exclusions: Sequence[str]) -> Churn:
    added = 0
    deleted = 0
    binary_files = 0
    for line in output.splitlines():
        parts = line.split("\t", 2)
        if len(parts) != 3 or is_excluded(parts[2], exclusions):
            continue
        if parts[0] == "-" or parts[1] == "-":
            binary_files += 1
            continue
        added += int(parts[0])
        deleted += int(parts[1])
    return Churn(added, deleted, binary_files)


def diff_churn(
    repository: Path,
    left: str,
    right: str | None,
    exclusions: Sequence[str],
) -> Churn:
    arguments = ["diff", "--numstat", "--no-renames", left]
    if right is not None:
        arguments.append(right)
    arguments.append("--")
    output = git(repository, *arguments)
    assert isinstance(output, str)
    return parse_numstat(output, exclusions)


def parent_of(repository: Path, revision: str) -> str:
    try:
        parent = git(repository, "rev-parse", "--verify", f"{revision}^")
    except EstimationError:
        parent = git(repository, "hash-object", "-t", "tree", "--stdin", input_text="")
    assert isinstance(parent, str)
    return parent


def commit_time(repository: Path, revision: str) -> datetime:
    value = git(repository, "show", "-s", "--format=%cI", revision)
    assert isinstance(value, str)
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def untracked_lines(
    repository: Path, exclusions: Sequence[str]
) -> tuple[int, int, int]:
    raw = git(
        repository,
        "ls-files",
        "--others",
        "--exclude-standard",
        "-z",
        text=False,
    )
    assert isinstance(raw, bytes)
    line_count = 0
    file_count = 0
    binary_files = 0
    for encoded_path in raw.split(b"\0"):
        if not encoded_path:
            continue
        relative_path = os.fsdecode(encoded_path)
        if is_excluded(relative_path, exclusions):
            continue
        data = (repository / relative_path).read_bytes()
        if b"\0" in data:
            binary_files += 1
            continue
        file_count += 1
        line_count += data.count(b"\n")
        if data and not data.endswith(b"\n"):
            line_count += 1
    return line_count, file_count, binary_files


def non_negative_range(values: Sequence[str], option: str) -> tuple[float, float]:
    try:
        minimum, maximum = (float(value) for value in values)
    except ValueError as error:
        raise EstimationError(f"{option} values must be numbers.") from error
    if minimum < 0 or maximum < 0 or minimum > maximum:
        raise EstimationError(
            f"{option} requires non-negative MIN MAX values with MIN <= MAX."
        )
    return minimum, maximum


def build_report(arguments: argparse.Namespace) -> dict[str, object]:
    requested_repository = Path(arguments.repo).expanduser().resolve()
    root_value = git(requested_repository, "rev-parse", "--show-toplevel")
    assert isinstance(root_value, str)
    repository = Path(root_value).resolve()
    exclusions: list[str] = arguments.exclude

    samples: list[dict[str, object]] = []
    total_churn = 0
    total_hours = 0.0
    warnings: list[str] = []

    for label, start, end in arguments.sample:
        elapsed_hours = (
            commit_time(repository, end) - commit_time(repository, start)
        ).total_seconds() / 3600
        if elapsed_hours <= 0:
            raise EstimationError(
                f"Sample '{label}' must end after it starts; commit timestamps give {elapsed_hours:.2f} hours."
            )
        churn = diff_churn(repository, parent_of(repository, start), end, exclusions)
        if churn.total == 0:
            raise EstimationError(f"Sample '{label}' has zero changed-line churn.")
        sample_rate = churn.total / elapsed_hours
        samples.append(
            {
                "label": label,
                "start": start,
                "end": end,
                "added": churn.added,
                "deleted": churn.deleted,
                "churn": churn.total,
                "elapsed_hours": round(elapsed_hours, 2),
                "churn_per_hour": round(sample_rate, 2),
                "binary_files_ignored": churn.binary_files_ignored,
            }
        )
        total_churn += churn.total
        total_hours += elapsed_hours
        if churn.binary_files_ignored:
            warnings.append(
                f"Sample '{label}' ignored {churn.binary_files_ignored} binary file(s)."
            )

    observed_rate = total_churn / total_hours

    current_change: dict[str, object] | None = None
    if arguments.base_ref:
        tracked = diff_churn(repository, arguments.base_ref, None, exclusions)
        untracked_count = 0
        untracked_file_count = 0
        untracked_binary_count = 0
        if arguments.include_untracked:
            untracked_count, untracked_file_count, untracked_binary_count = untracked_lines(
                repository, exclusions
            )
        current_change = {
            "base_ref": arguments.base_ref,
            "tracked_added": tracked.added,
            "tracked_deleted": tracked.deleted,
            "tracked_churn": tracked.total,
            "untracked_lines": untracked_count,
            "untracked_files": untracked_file_count,
            "total_churn": tracked.total + untracked_count,
            "binary_files_ignored": tracked.binary_files_ignored
            + untracked_binary_count,
        }
        if current_change["binary_files_ignored"]:
            warnings.append(
                f"Current change ignored {current_change['binary_files_ignored']} binary file(s)."
            )
    elif arguments.include_untracked:
        raise EstimationError("--include-untracked requires --base-ref.")

    remaining: list[dict[str, object]] = []
    remaining_minimum = 0.0
    remaining_maximum = 0.0
    for label, minimum_text, maximum_text in arguments.remaining or []:
        minimum, maximum = non_negative_range(
            [minimum_text, maximum_text], f"--remaining '{label}'"
        )
        remaining.append(
            {"label": label, "changed_loc_min": minimum, "changed_loc_max": maximum}
        )
        remaining_minimum += minimum
        remaining_maximum += maximum

    overhead_minimum, overhead_maximum = non_negative_range(
        arguments.overhead_hours, "--overhead-hours"
    )
    implementation_minimum = remaining_minimum / observed_rate
    implementation_maximum = remaining_maximum / observed_rate
    forecast = {
        "remaining_changed_loc_min": remaining_minimum,
        "remaining_changed_loc_max": remaining_maximum,
        "implementation_hours_min": round(implementation_minimum, 2),
        "implementation_hours_max": round(implementation_maximum, 2),
        "overhead_hours_min": overhead_minimum,
        "overhead_hours_max": overhead_maximum,
        "total_hours_min": round(implementation_minimum + overhead_minimum, 2),
        "total_hours_max": round(implementation_maximum + overhead_maximum, 2),
    }

    return {
        "repository": str(repository),
        "samples": samples,
        "observed_churn_per_hour": round(observed_rate, 2),
        "current_change": current_change,
        "remaining": remaining,
        "forecast": forecast,
        "warnings": warnings,
    }


def render(report: dict[str, object]) -> str:
    samples = report["samples"]
    assert isinstance(samples, list)
    lines = [
        f"Repository: {report['repository']}",
        "",
        "Observed changed-line velocity",
        "",
        "| Sample | Added | Deleted | Churn | Hours | LOC/hour |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for sample in samples:
        assert isinstance(sample, dict)
        lines.append(
            "| {label} | {added} | {deleted} | {churn} | {elapsed_hours:.2f} | {churn_per_hour:.2f} |".format(
                **sample
            )
        )
    lines.extend(["", f"Weighted velocity: {report['observed_churn_per_hour']:.2f} changed LOC/hour"])

    current = report["current_change"]
    if isinstance(current, dict):
        lines.extend(
            [
                "",
                f"Current change from {current['base_ref']}: {current['total_churn']} changed LOC "
                f"({current['tracked_churn']} tracked, {current['untracked_lines']} untracked)",
            ]
        )

    remaining = report["remaining"]
    assert isinstance(remaining, list)
    if remaining:
        lines.extend(
            [
                "",
                "Remaining churn assumptions",
                "",
                "| Scope | Minimum | Maximum |",
                "|---|---:|---:|",
            ]
        )
        for item in remaining:
            assert isinstance(item, dict)
            lines.append(
                f"| {item['label']} | {item['changed_loc_min']:.0f} | {item['changed_loc_max']:.0f} |"
            )

    forecast = report["forecast"]
    assert isinstance(forecast, dict)
    lines.extend(
        [
            "",
            "Forecast",
            "",
            f"- Implementation: {forecast['implementation_hours_min']:.2f}-{forecast['implementation_hours_max']:.2f} hours",
            f"- Fixed overhead: {forecast['overhead_hours_min']:.2f}-{forecast['overhead_hours_max']:.2f} hours",
            f"- Total: {forecast['total_hours_min']:.2f}-{forecast['total_hours_max']:.2f} active hours",
        ]
    )
    warnings = report["warnings"]
    assert isinstance(warnings, list)
    if warnings:
        lines.extend(["", "Warnings", ""])
        lines.extend(f"- {warning}" for warning in warnings)
    return "\n".join(lines)


def parser() -> argparse.ArgumentParser:
    command = argparse.ArgumentParser(
        description="Estimate active delivery hours from comparable Git changed-line throughput."
    )
    command.add_argument("--repo", default=".", help="Git repository path (default: current directory).")
    command.add_argument(
        "--sample",
        action="append",
        nargs=3,
        required=True,
        metavar=("LABEL", "START", "END"),
        help="Comparable completed slice, from its first work commit through reviewed completion.",
    )
    command.add_argument(
        "--remaining",
        action="append",
        nargs=3,
        metavar=("LABEL", "MIN_LOC", "MAX_LOC"),
        help="Estimated changed-LOC range for one remaining scope; repeat as needed.",
    )
    command.add_argument("--base-ref", help="Optional base ref for reporting current tracked churn.")
    command.add_argument(
        "--include-untracked",
        action="store_true",
        help="Count non-binary untracked physical lines in the current change.",
    )
    command.add_argument(
        "--overhead-hours",
        nargs=2,
        default=("0", "0"),
        metavar=("MIN", "MAX"),
        help="Non-coding validation, review, queue, and publication time.",
    )
    command.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="GLOB",
        help="Repository-relative glob to exclude consistently from samples and current churn.",
    )
    command.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    return command


def main(argv: Sequence[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    try:
        report = build_report(arguments)
    except EstimationError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    if arguments.json:
        print(json.dumps(report, indent=2))
    else:
        print(render(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
