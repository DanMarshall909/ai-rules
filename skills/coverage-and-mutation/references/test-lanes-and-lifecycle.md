# Test lanes and mutation lifecycle

## Maintain two ordinary lanes in every suite

Every maintained test suite in every repository exposes named `fast`, `slow`
and combined selections through its canonical driver and CI. The slow lane may
be empty; do not invent an expensive test to fill it. Record exact test IDs and
parameterized rows. The combined selection must equal the discovered maintained
suite, with no overlap or loss. Account explicitly for skips, platform limits and
quarantine rather than treating unavailable checks as passes.

Fast is the normal development feedback lane. Slow retains expensive fixture,
process, real-system and end-to-end contracts, run once on the final candidate
before completing a ticket. Rerun affected slow contracts when later changes
invalidate that checkpoint. Do not postpone the sole oracle for the current
criterion, and retain earlier checkpoints required by project policy. Both lanes
remain required regression evidence; moving a test never removes its assertions.

On every ordinary run, capture available per-test elapsed time, setup/teardown
cost and suite wall time, and review candidates in both directions against the
project's feedback budget and peers at the same layer. Include expensive setup
shared across many otherwise cheap rows. Use valid retained slow timings during
fast runs instead of running the entire slow suite for classification.

Before moving a candidate, repeat it on unmodified production code at least twice
in addition to the triggering observation, under comparable runtime, hardware,
load, concurrency, inputs and cold/warm fixture conditions. Retain all samples,
median and range; investigate failures, contention and one-time initialization.
Do not use mutant executions or one unusually fast warm sample as classification
evidence. If it was an anomaly, keep its lane. If timings remain uncertain, leave
membership unchanged and record the investigation. Return a persistently cheap
slow test to fast when its contract fits ordinary feedback; end-to-end tests
remain excluded from mutation regardless of duration.

After an authorized membership change, re-run affected tests in their destination
lane, reconcile discovery with the combined selection, and update driver/CI
selectors and coverage identities together. Investigate an inexpensive owning
rule test or cheaper setup before moving the entire contract to slow. Never mock
away production behavior to meet a timing target.

## Use ordinary coverage to define mutation scope

Slow tests never execute inside mutation initial/baseline tests, coverage capture,
dry runs or mutant execution. Collect their coverage during ordinary verification,
preferably the existing final slow checkpoint. Collect fast coverage separately
or retain per-test attribution that can distinguish both lanes. Reuse only
evidence bound to identical relevant production/test bytes, lane membership,
build graph, dependencies, configuration, coverage tool and source mapping.

Let `F` be source sections executed by fast tests and `S` those executed by slow
tests. Derive the exclusion set `S ∖ F` at the finest trustworthy granularity the
collector and mutation runner support:

| Section coverage | Mutation treatment |
| --- | --- |
| Fast only | Eligible; execute mutation-eligible covering fast tests. |
| Both lanes | Eligible; execute mutation-eligible covering fast tests. |
| Slow only | Exclude explicitly; retain its ordinary regression evidence. |
| Neither lane | Keep visible as uncovered required behavior for investigation. |
| Unknown or stale mapping | Record affected scope as pending; derive no exclusion. |

`F` remains ordinary fast coverage, including any tests separately excluded from
mutation by their layer. If only excluded end-to-end/boundary tests cover an
eligible section, keep the missing mutation participation visible; never
reintroduce those tests or relabel the section as slow-only to hide the gap.

Coverage establishes execution, not a checked assertion. Slow-only exclusion is
a performance/scope decision, not a killed mutant, proof of adequacy or evidence
that code is dead. Report excluded sections and counts separately from eligible
mutants and the mutation score. Never suppress uncovered sections merely because
the mutation tests were filtered, or exclude a whole mixed file/class when only
some sections are slow-only. Preserve independent assertions and thresholds.

Calibrate the pinned producer/collector with representative fast-only, slow-only,
shared and uncovered sections. Verify the ordinary lane attribution, actual
mutation test catalogue and source exclusions, using a fault rejected by a named
fast test in eligible code. A passing run or syntactically valid config is
insufficient. Prefer native supported exclusions; build a small repository adapter
only when necessary and authorized. Do not invent tool flags or fabricate scores.

If the tool cannot establish the mapping or exclude at a trustworthy granularity,
record the affected mutation scope as pending and track the missing adapter. Do
not compensate by running slow tests in mutation, broad exclusions, guessing
from test names or pretending the new policy is implemented. Ordinary ticket
verification and publication can complete while post-session mutation remains
explicitly pending. Lane moves, test edits, changed source/maps and tool/config
changes invalidate affected exclusions and reusable mutation outcomes.

## Use copy-on-write mutation storage

Prepare one pinned immutable base for the selected source, tool and dependency
versions, then give each attempt an independent writable view using filesystem
snapshots/reflinks or an isolated overlay. A fresh empty package cache defeats
sharing: populate and verify reusable starting data once. Do not substitute
symlinks or hardlinks to a writable shared tree; a mutant or restore must never
alter another attempt or its base.

Record the base inventory and identity, storage backend, writable-layer paths,
attempt identity and owned processes. Check filesystem support and capacity
before large operations. Protect the base from writes within the run and
validate its retained identity before execution and after exact worker cleanup.
Calibrate with an actual isolated write and a named rejected assertion fault;
a successful mount or a passing test alone does not establish isolation.

Keep raw reports, logs, terminal outcomes and recovery descriptors outside
disposable layers. Retain the required base and changed layer when inspection
or recovery depends on them; seal their contents and relevant metadata before
admitting evidence. Remount inspection read-only without replaying mutation,
serialize reuse of writable layers, and fence interrupted ownership until
exact cleanup is proven. Controller death must not leave an unowned mount or
allow a second worker to reuse a live layer.

If safe CoW storage is unavailable, report the affected run as blocked or pending
and name the missing capability. Do not silently use full copies or shared
writes. A user-authorized fallback must state its isolation and disk cost and
retain the same verification and evidence requirements. Compare equivalent
verification before claiming storage or runtime savings.

## Cleanup is part of every mutation run

Before launch, record a run identity, owned process tree, output filesystem/free
space, disk budget and exact disposable paths. Separate sandboxes, instrumented
assembly/source copies, transient test profiles and temp/report output from
source checkouts, reusable dependencies/caches and durable baseline state. Plan
bounded retention; do not create extra full copies of large evidence trees.
Check competing jobs and guard disk headroom during long runs.

The supervisor must run cleanup on success, failure and cancellation, including
detached jobs after the agent leaves. In this order:

1. Record the original exit/cancellation and verify owned workers stopped.
   Restore/verify any instrumented source or binaries before ordinary reuse.
2. Preserve and verify compact evidence: source/test/config/tool identities,
   effective lane and section selections, raw machine reports, outcome counts,
   diagnostics, timing/resource observations and reusable baseline metadata.
   Publish baseline updates atomically only when admission checks pass. Retain
   enough input/revision information to reproduce the run and interpret findings.
3. Validate disposable targets against the run's ownership manifest and actual
   canonical paths; reject unexpected symlinks, shared roots and unknown files.
   Remove owned sandboxes, instrumented copies and transient profiles/output.
   Do not rely on a directory name, age, ignored status or `/tmp` location as
   ownership proof. Never use broad globs or delete dirty worktrees to free space.
4. Record removed/retained paths, bytes reclaimed, remaining free space and any
   failed removal or still-live worker. Cleanup incomplete is a separate visible
   operational failure, not a rewrite of valid or failed mutation outcomes.

Keep reusable mutation state outside disposable output and honor its explicit
invalidation/eviction contract. Retained evidence needs a documented size or
retention budget; archive or prune owned disposable material after verified
extraction. Deleting shared build/dependency caches, unknown output or historical
evidence still requires the authority and recovery plan those targets demand.
Disk pressure does not expand deletion authority.
