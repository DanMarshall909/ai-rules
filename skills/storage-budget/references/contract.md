# Storage contract

## Configuration

Version 1 `.ai-rules.json` and its memory reservation remain valid. Version 2
retains `resources.memory` and requires `resources.disk.workloads`. Each workload
has `reserveMiB` (positive), `outputGrowthMiB`, `tempGrowthMiB`, and
`retainedBudgetMiB` (nonnegative integers), plus provenance. An `estimated` basis
requires `estimateReason`; a `measured` basis requires `measurement` containing
`workload`, ISO `date` and durable `evidence`. Estimates are admission allowances,
not observations. Configuration contains no absolute machine paths.

```json
{"schemaVersion":2,"resources":{"memory":{"reserveMiBPerActiveWorktree":1024,"basis":"estimated","estimateReason":"Lightweight checks"},"disk":{"workloads":{"checks":{"reserveMiB":512,"outputGrowthMiB":64,"tempGrowthMiB":256,"retainedBudgetMiB":64,"basis":"estimated","estimateReason":"Small fixture repositories pending representative measurements"}}}}}
```

`check` returns `admitted`, per-volume observed availability, summed growth,
reserve and shortfall, plus the retention budget. Output/temp parents must exist
and have no linked ancestors. Actual volume identity groups the two roles even
when their paths differ. This is an immediate check, not a cross-process lock or
reservation. Concurrent writers may cause a later live guard stop. Account for
other known heavy work when selecting estimates and concurrency.

`inventory` bounds every root to 64 levels, 100,000 entries and five seconds by
default; explicit flags permit up to 256 levels, one million entries and 60
seconds. At most 128 roots are accepted. Stop at registered worktrees instead of
recursively discovering repositories inside generated output. Shared file IDs
are counted once across roots. Shared extents, compression and sparse allocation
are not inferred: `allocated_bytes` and `reclaimable_bytes` stay null. Partial
scans return lower-bound observations and incomplete diagnostics, never zero.
Known category names are hints; non-output Git-tracked files are source; other
files remain unknown. Optional retention review never grants deletion authority.

## Execution and measurement

`run` launches the argument vector without a shell. Use an explicit interpreter
for scripts. Python 3.10+ and native platform process APIs are required; no
packages, background service, uploads or profile installation are involved.
The caller selects a new receipt path outside the newly created disposable
folders. Existing receipts are never overwritten. Runtime is bounded to at most
24 hours; samples default to one second. Command stdout/stderr live in owned
temporary storage; only the final 16 KiB are returned in the local report.

Fresh directory identities, ancestor identities and random owner markers establish
cleanup scope. A cleanup failure is visible even if the command succeeded.
Windows holds directory handles against rename during traversal; POSIX cleanup
is anchored to validated directory descriptors and does not follow links.
Cleanup refuses existing or changed targets and requires stopped owned workers.
Native hard termination, machine failure and commands that daemonize are outside
verified cleanup: preserve their residue and investigate explicitly.

Receipt fields are `schema_version: 1`, opaque `scope`, `workload`, `method`,
`provenance`, `cache_state`, `before_bytes`, `after_bytes`, `peak_bytes`,
`sample_complete`, `cleanup_failures`, `rebuild_seconds` and optional `volume_free`.
The measurement is scoped to the fresh disposable output/temp directories,
including command logs; it excludes source, reusable caches and arbitrary writes
elsewhere. `method` is `logical-v1`; `provenance` is `storage-budget-v1`.
Before is zero; after is retained logical footprint following attempted cleanup;
peak is the largest sampled footprint, a lower bound on the true peak. Any
incomplete sample marks the receipt incomplete. Failed cleanup conservatively
includes remaining owner markers. Unknown values remain null.

`volume_free` contains opaque volume labels and before/after/minimum free bytes.
Concurrent activity can change these independently of task footprint; do not
subtract them to claim task-attributed growth or reclaimed bytes. The method is
consistent logical footprint comparison, not physical space recovery evidence.
Actual future reclamation should be observed separately on the affected volume.

Use matching scope/workload/method/cache conditions and predeclared tolerances in
skill metrics. If evaluating cache removal, observe subsequent rebuild cost
separately: the managed runner does not delete reusable caches or invent that cost.
