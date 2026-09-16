#!/usr/bin/env python3
"""Behaviour test for estimate_delivery.py using a temporary Git repository."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("estimate_delivery.py")


def run(command: list[str], cwd: Path, *, env: dict[str, str] | None = None) -> str:
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


class EstimateDeliveryTests(unittest.TestCase):
    def test_reports_weighted_churn_velocity_and_forecast(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = Path(temporary_directory)
            run(["git", "init"], repository)
            run(["git", "config", "user.name", "Test User"], repository)
            run(["git", "config", "user.email", "test@example.invalid"], repository)

            source = repository / "work.txt"
            source.write_text("base\n", encoding="utf-8", newline="\n")
            run(["git", "add", "work.txt"], repository)
            self._commit(repository, "base", "2026-01-01T00:00:00+00:00")
            base = run(["git", "rev-parse", "HEAD"], repository)

            source.write_text("base\nalpha\n", encoding="utf-8", newline="\n")
            run(["git", "add", "work.txt"], repository)
            self._commit(repository, "start", "2026-01-01T01:00:00+00:00")
            start = run(["git", "rev-parse", "HEAD"], repository)

            source.write_text("base\nbeta\ngamma\n", encoding="utf-8", newline="\n")
            run(["git", "add", "work.txt"], repository)
            self._commit(repository, "end", "2026-01-01T03:00:00+00:00")
            end = run(["git", "rev-parse", "HEAD"], repository)

            (repository / "notes.txt").write_text(
                "first\nsecond\n", encoding="utf-8", newline="\n"
            )

            output = run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--repo",
                    str(repository),
                    "--sample",
                    "reviewed-slice",
                    start,
                    end,
                    "--base-ref",
                    base,
                    "--include-untracked",
                    "--remaining",
                    "open-work",
                    "10",
                    "20",
                    "--overhead-hours",
                    "1",
                    "2",
                    "--json",
                ],
                repository,
            )
            report = json.loads(output)

            self.assertEqual(2, report["samples"][0]["churn"])
            self.assertEqual(2.0, report["samples"][0]["elapsed_hours"])
            self.assertEqual(1.0, report["observed_churn_per_hour"])
            self.assertEqual(2, report["current_change"]["tracked_churn"])
            self.assertEqual(2, report["current_change"]["untracked_lines"])
            self.assertEqual(4, report["current_change"]["total_churn"])
            self.assertEqual(10.0, report["forecast"]["implementation_hours_min"])
            self.assertEqual(20.0, report["forecast"]["implementation_hours_max"])
            self.assertEqual(11.0, report["forecast"]["total_hours_min"])
            self.assertEqual(22.0, report["forecast"]["total_hours_max"])

    @staticmethod
    def _commit(repository: Path, message: str, timestamp: str) -> None:
        environment = os.environ.copy()
        environment["GIT_AUTHOR_DATE"] = timestamp
        environment["GIT_COMMITTER_DATE"] = timestamp
        run(["git", "commit", "-m", message], repository, env=environment)


if __name__ == "__main__":
    unittest.main()
