# Repository resource configuration

Add a tracked `.ai-rules.json` when working in a repository that needs a measured
resource reservation. Use [the versioned schema](../schemas/ai-rules.schema.json).
Do not create a guessed reservation merely to fill the file; omit `resources.memory`
until a representative workload has been measured.

```json
{
  "schemaVersion": 1,
  "resources": {
    "memory": {
      "reserveMiBPerActiveWorktree": 6144,
      "observedPeakMiB": 4999,
      "measurement": {
        "workload": "scoped mutation run",
        "date": "2026-09-29",
        "evidence": "path to retained run receipt"
      }
    }
  }
}
```

The reservation is an admission-planning allowance for a worktree running a
build, test, mutation or other heavy producer. An idle worktree does not consume
it. Measure the peak task/process-group memory of a representative successful
run, round the reservation upward to allow headroom, and record the exact
workload, date and durable evidence path. A stopped run gives a lower bound,
not a peak measurement. Refresh the value when the workload or toolchain changes.

Sum reservations for simultaneously active worktrees when planning concurrency.
Check current available memory immediately before launch and retain live memory
and swap guards for heavy work. The repository value is advisory; it neither
guarantees headroom nor overrides a task's stricter resource limits. Avoid a
fixed quiet-time requirement when an immediate sample and live guard suffice.

The `resources` object can gain other measured resource categories in later
schema versions. Keep units in field names and keep machine-specific transient
state in run receipts, not in this tracked file.
