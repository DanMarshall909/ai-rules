# Repository resource configuration

Add a tracked `.ai-rules.json` when work starts in a repository. Use
[the versioned schema](../schemas/ai-rules.schema.json). Prefer a measured
reservation; if there is no representative run yet, record a conservative
estimate with its reason and replace it when evidence becomes available.

```json
{
  "schemaVersion": 1,
  "resources": {
    "memory": {
      "reserveMiBPerActiveWorktree": 6144,
      "basis": "measured",
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

For an unmeasured repository, use `"basis": "estimated"` and replace
`observedPeakMiB` and `measurement` with an `estimateReason` explaining the
expected workload and allowance. Do not present an estimate as a measured peak.

The reservation is an admission-planning allowance for a worktree running a
build, test, mutation or other heavy producer. An idle worktree does not consume
it. Measure the peak task/process-group memory of a representative successful
run, round the reservation upward to allow headroom, and record the exact
workload, date and durable evidence path. A stopped run gives a lower bound,
not a peak measurement. Replace an estimate after the first representative run,
and refresh a measured value when the workload or toolchain changes.

For future run planning, a measured `measurement` may also record the completed
duration, task concurrency, minimum available system memory during the run and
peak task swap use. These are observations from that workload, not promises for
another machine or a later run.

Sum reservations for simultaneously active worktrees when planning concurrency.
Check current available memory immediately before launch and retain live memory
and swap guards for heavy work. The repository value is advisory; it neither
guarantees headroom nor overrides a task's stricter resource limits. Avoid a
fixed quiet-time requirement when an immediate sample and live guard suffice.

The `resources` object can gain other measured resource categories in later
schema versions. Keep units in field names and keep machine-specific transient
state in run receipts, not in this tracked file.
