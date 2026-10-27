# Repository resource configuration

Add a tracked `.ai-rules.json` when work starts in a repository. Version 1
requires a `resources.memory` reservation and accepts no other resource
categories. Version 2 retains that contract and adds required workload disk budgets. Use [the versioned schema](../schemas/ai-rules.schema.json). Prefer a measured
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
        "evidence": "path to retained run receipt",
        "completedRunDurationsSeconds": [735]
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
Use `completedRunDurationsSeconds` for every comparable finished run so the
observed time range is visible. Exclude stopped attempts from that list and
explain them in `notes` when they matter to planning.

Sum reservations for simultaneously active worktrees when planning concurrency.
Check current available memory immediately before launch and retain live memory
and swap guards for heavy work. The repository value is advisory; it neither
guarantees headroom nor overrides a task's stricter resource limits. Avoid a
fixed quiet-time requirement when an immediate sample and live guard suffice.

## Disk budgets (version 2)

Version 1 files remain valid; version 2 adds `resources.disk.workloads` without
migrating existing files silently. Each named workload declares `reserveMiB`,
`outputGrowthMiB`, `tempGrowthMiB`, `retainedBudgetMiB` and measured or estimated
provenance. The reserve is positive; other quantities are nonnegative integers.
Estimated records require `estimateReason`; measured records require
`measurement` with workload, ISO date and evidence. Keep runtime paths and free
space in local receipts rather than tracked configuration.

Use the [storage-budget skill](../skills/storage-budget/SKILL.md) and its
[configuration and receipt contract](../skills/storage-budget/references/contract.md).
Its `check` command sums estimated growth for output and temporary paths sharing
a volume, applies the reserve once per volume and blocks only the operation that
cannot fit. `run` adds live guards and verified cleanup of fresh, explicitly
disposable output. It does not intercept other commands or authorize deleting
existing builds and caches. Retention budgets trigger review, not eviction.

The repository's `checks` estimate preserves 512 MiB, allows 64 MiB output and
256 MiB temporary growth, and requests review of retained output over 64 MiB.
These are conservative lightweight-fixture allowances, not measured workload
peaks; replace them when representative receipts qualify a measured budget.
