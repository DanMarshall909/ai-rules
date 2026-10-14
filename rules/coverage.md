# Coverage & Dead Code

When reviewing coverage, mutation results, compatibility paths, or dead code, use the `coverage-and-mutation` skill.

- Aim for 100% coverage of core code through externally observable behavior.
- Coverage proves execution in the measured run with sound instrumentation, not a checked assertion; uncovered code did not execute in that run.
- Remove code with no useful caller or contract instead of covering it for its own sake.
- Establish coverage before mutation; calibrate with a fault a test rejects. After the whole session, run mutation on the final snapshot, one active job per repository; never block tickets or integration, and review and act on results later.
- Use copy-on-write sandboxes for mutation runs, with a pinned immutable source/tool/dependency base and an independent writable layer per attempt. Reuse prepared dependencies instead of downloading or copying full caches for each run. Use filesystem snapshots/reflinks or isolated overlays; symlinks and hardlinks to shared writable files do not provide isolation. Keep reports and recovery evidence outside disposable layers. Verify base identity, write isolation and owned-worker cleanup; if safe CoW storage is unavailable, report the blocker rather than silently falling back to full copies or shared writes.
- Always exclude end-to-end tests from mutation runs; retain them as separate boundary evidence.
- Exclude slow-lane tests from every mutation phase. Use source-bound coverage from both ordinary lanes to exclude only sections covered by slow tests but no fast tests; keep fast-covered sections eligible and genuinely uncovered sections visible. Missing or stale lane attribution is a disclosed pending scope, never an invented exclusion or passing score.
- Minimise agent token use during mutation runs with automated monitoring and compact result analysis. Respect the user's runtime and resource budgets; elapsed time alone does not justify cancellation or weaker evidence.
- Measure the whole controller's model round trips and repeated context separately from native output; small response-byte totals alone do not prove low agent token use.
- Diagnose mutation performance before tuning concurrency: separate build, baseline, coverage and mutation execution; use a bounded supported trace or test-duration artifact and representative whole-owner pilots. Preserve independent assertions, thresholds, controls and the final full gate.
- Complete mutation cleanup after success, failure and cancellation: verify owned workers stopped, retain compact evidence and reusable baselines, remove owned disposable sandboxes/instrumented copies/temp output, and record disk space reclaimed. Inspect uncertain ownership; never use broad deletion of worktrees, builds or shared caches to recover space.
