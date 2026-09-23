# Stryker.NET Persistent Fast Feedback

Use this reference when a .NET repository needs faster recurring mutation
feedback, persistent local baselines, changed-test handling, or lower CI compute.
Read the parent [.NET module](dotnet.md) and `coverage-and-mutation` first.

The objective is maximum behavioural confidence per unit of mutation compute and
developer waiting time. Reusable mutation knowledge is persistent evidence, not
disposable build output.

## Keep Stryker responsible for mutation testing

Prefer this architecture:

```text
repository state
      |
      v
Stryker.NET
  - Git diff
  - prior mutation evidence
  - per-test coverage
  - affected mutants
      |
      v
persistent local state outside the checkout
```

Stryker should still generate mutants, capture coverage, select covering tests,
mix compatible mutants, bail after a kill and enforce thresholds. A repository
wrapper may validate state and choose a Stryker invocation; it should not become
a second mutation engine, infer call graphs, merge outcomes into a fabricated
full score, or decide that a possibly relevant test is irrelevant.

## Inspect and measure before changing configuration

Establish all of these from repository evidence:

- solution/project graph, production boundaries and mutation targets;
- test projects, frameworks, runners and actual report membership;
- pinned SDK, Stryker.NET and test-platform versions;
- Stryker configuration, wrappers, reports and any existing baseline;
- CI jobs, hooks, `.gitignore` and artifact retention;
- generated, vendored, migration, DTO, startup and serialization surfaces; and
- initial-run, coverage-capture and mutant-execution timing.

Do not assume a configured test-project hint proves effective test scope. Use the
machine report's test catalog and mutant links. Do not narrow discovery until the
report proves which test layers kill the target's mutants.

Record a full baseline before optimizing, including generated, executable,
killed, survived, timed-out, no-coverage, ignored and compile-error counts. Retain
the machine-readable report and raw terminal output; discrepancies are evidence,
not numbers to reconcile by assumption.

## Configure Stryker's execution controls explicitly

Verify each option against the pinned version. For current Stryker.NET:

- `coverage-analysis: perTest` runs only tests attributed to a mutant and reports
  uncovered mutants as `NoCoverage`;
- `disable-bail: false` stops a mutant run after the first killing failure;
- `disable-mix-mutants: false` allows VSTest to combine mutants with disjoint
  covering tests; Microsoft Test Platform may ignore this option; and
- concurrency should be measured on the actual machine because more workers can
  lose to CPU, memory, process-startup or I/O contention.

State intended values even when they match current defaults so a tool upgrade
cannot silently change the repository's execution policy. Investigate incorrect
coverage attribution before switching to a mode that runs the entire suite for
every mutant.

Keep exclusions narrow and contractual. Generated or external code may be out of
scope; owned calculation, branching, validation, state changes, persistence,
security and business rules are not low-value merely because their mutants live.
Never add an exclusion only to raise the score.

## Try the supported disk baseline first

Stryker.NET's baseline feature is experimental. It reuses unaffected results and
is mutually exclusive with explicit `since` mode. Its default provider is Disk,
with branch or project version identity and a configurable fallback version.

Start with Disk, not a service. Before accepting it as the default workflow,
calibrate the exact pinned version and configuration:

1. **No baseline:** verify the run executes a complete trustworthy baseline and
   writes it under the intended project identity.
2. **No changes:** verify the saved report is loaded, known outcomes are present,
   and unaffected mutants are actually reused rather than omitted or executed.
3. **Small source change:** verify changed mutants rerun and unchanged outcomes
   remain represented.
4. **Test-only change:** verify mutants covered before or after the edit rerun.
5. **Fallback branch/version:** verify a missing feature-branch baseline selects
   the intended fallback rather than a same-named baseline from another target.
6. **Multiple targets:** verify Domain/Application or equivalent projects cannot
   overwrite or read one another's baseline.

Inspect JSON outcomes and terminal diagnostics in every scenario. A successful
exit, a zero-mutant report, or the existence of a baseline file does not prove
reuse. Plant one representative fault when attribution remains uncertain.

If the calibrated provider is correct but keeps required data beneath disposable
`StrykerOutput`, a small wrapper may restore only the required baseline data from
a stable cache before Stryker and copy it back after a successful run. Do not
commit generated reports merely to survive `clean`, `bin`/`obj` deletion or a
reclone.

## Use a validated-state wrapper only when justified

A wrapper is justified when measurements show that the pinned provider:

- loses its baseline during normal repository cleanup;
- collides across mutation targets;
- emits incomplete or ambiguous reuse evidence;
- reruns mutants it claims to reuse; or
- fails to invalidate source or test changes conservatively.

Keep the fallback small. It should offer a stable command surface such as:

```text
mutation                    # fast, persistent, fail-closed default
mutation --full             # full verification; do not change state
mutation --full --update-baseline
mutation --show-baseline
mutation --reset-baseline
```

Missing, corrupt or incompatible state should fail quickly with the seed command
rather than silently launching a long full run. Reset must resolve and validate
the exact repository cache key before removing anything.

## Persistent-state contract

Use the platform's durable per-user cache:

```text
Windows: %LOCALAPPDATA%\MutationBaselines\<repository-key>\...
Unix:    ${XDG_CACHE_HOME:-$HOME/.cache}/MutationBaselines/<repository-key>/...
```

Allow an explicit environment override for isolated tests and self-hosted
runners. Derive the repository key from a stable name plus a hash of the origin
URL or another non-secret stable identity. Separate configuration fingerprints,
mutation targets and branches. Never embed a machine-specific absolute path in
repository configuration.

A successful full seed should retain, per target:

- exact source commit and branch/version identity;
- a content hash that includes dirty and untracked relevant files;
- configuration fingerprint;
- authoritative anchor/latest report and terminal evidence location;
- established mutant count and full score; and
- schema version, update time and last run mode.

The configuration fingerprint should cover at least:

- wrapper and pinned Stryker tool manifest;
- Stryker configuration and mutation target;
- SDK, target framework, compiler and central build settings;
- project graph, package versions and relevant runner/adapter versions;
- shared test infrastructure and non-code test inputs;
- source generators and their schema/corpus inputs; and
- any option that changes mutant generation, coverage, filtering or thresholds.

A fingerprint change requires a new full seed. Do not copy an old report into a
new fingerprint merely because the change looked harmless; either keep the
fingerprint owner narrower by design or pay the one-time verification cost.

## Conservative fast-mode decision table

Use the exact recorded commit and content, not a moving branch name, as the diff
anchor. The rules are cumulative: a run with both source and test changes must
apply the changed-test protection as well as the source decision.

| Current state | Required action |
|---|---|
| Content hash identical | Launch no Stryker process; report the established outcomes as reused. |
| Source changed inside the mutation target | Run Stryker `since` the recorded commit and report a changed subset, not a new full score. |
| Production dependency changed outside the target | Refresh that target in full unless the repository proves a narrower safe dependency contract. |
| Test file changed | Probe current coverage, then retest the union of source files covered by that test before and after the edit. |
| Shared test helper cannot be attributed to tests | Refresh the target in full. |
| Tool/config/framework/project/dependency/generator/input changed | Reject the old fingerprint and require a full seed. |
| State is missing, corrupt or names an unreachable commit | Fail with recovery instructions. |

Update persistent state only after a successful, readable Stryker result that
passes the repository threshold. A dirty working tree may be cached by content,
but later diffs still use the recorded immutable commit and therefore rerun
conservatively.

### Changed-test fallback

Current documentation says `since` treats mutants covered by a changed test file
as changed. Calibrate this claim against the pinned version; do not assume it from
the option name.

When a changed-test probe under-selects or returns ambiguous zero outcomes:

1. Normalize each changed test path and find its test IDs independently in the
   previous and current reports.
2. In each report, find source files whose mutants' `coveredBy` entries contain
   those IDs.
3. Retest the union of those source files through Stryker's own mutation filters
   and per-test execution.
4. Include previous coverage for deleted or redirected tests and current coverage
   for added or expanded tests.
5. If any changed C# test/helper has no attributable IDs, no trustworthy source
   mapping, or otherwise uncertain relevance, refresh the target in full rather
   than declaring it irrelevant.

Prefer exact source patterns. An overinclusive pattern is slower but safe; an
underinclusive pattern can preserve a stale killed result. This fallback chooses
source scope only—Stryker still decides mutants and covering tests.

## Validate reports and expose lifecycle

A maintained wrapper needs isolated regression tests with a fake Stryker process
and realistic report fixtures. Exercise at least:

- missing baseline failure;
- full run without update and full seed with update;
- unchanged zero-execution reuse;
- source-change incremental invocation;
- changed-test targeted fallback and unknown-attribution full fallback;
- corrupt/unreachable state;
- show and narrowly scoped reset; and
- threshold failure that does not advance state.

Require exactly one new machine-readable report per invocation. Validate the
expected schema, tested outcomes and links between `testFiles`, `coveredBy` and
`killedBy`; retain terminal output beside it. Treat JSON as authoritative while
reporting any terminal disagreement. A changed-state zero-execution run needs an
explicitly proven reason—it is not equivalent to the identical-state cache hit.

`--show-baseline` should distinguish the active fingerprint from superseded
state. `--reset-baseline` should remove only the current repository key, never a
broad cache root or unrelated user data.

## Git and CI hygiene

Commit configuration, wrapper, regression tests and documentation. Ignore
generated HTML/JSON reports, temporary working directories and local cache data.

Keep ordinary automated tests in normal CI. Prefer developer machines or
self-hosted runners for mutation testing. If hosted CI adds mutation:

- run affected mutation scope rather than an unconditional full run;
- restore a validated persistent baseline;
- avoid duplicate local/hosted work and large artifacts; and
- schedule full verification less frequently.

Do not add Dashboard, Azure, S3 or MinIO merely because Stryker supports it. A
shared store is justified only by measured multi-clone, multi-runner or
cross-machine reuse that outweighs credentials, availability, lifecycle and
maintenance costs.

## Measure the workflow, not only the score

Measure at least these scenarios on representative hardware:

| Scenario | What it proves |
|---|---|
| Full, no reusable state | Baseline cost and complete outcome counts. |
| Valid baseline, no changes | True reuse with zero mutation execution. |
| Small production edit | Changed-code scope and dependency invalidation. |
| Test-only edit | Changed-test invalidation and coverage fallback. |
| Typical feature branch | Real cross-layer cost rather than a toy best case. |

Report executed and reused mutants separately, total wall time, analysis/build,
coverage and execution phases where available, plus killed, survived, timeout,
no-coverage, ignored and compile-error counts. If individual test-invocation
counts are unavailable, say so rather than inventing them. Keep multiple full
samples when runtime or timeout results vary materially.

Review representative survivors and classify them as missing behavioural test,
equivalent mutant, low-value mutation, attribution issue, timeout,
infrastructure issue or potential production defect. Improve tests, source or
configuration from that evidence; do not suppress survivors as a cleanup step.

Only after this measured workflow remains a bottleneck should a repository
consider custom static test-impact analysis. Any such analysis must follow:

```text
definitely irrelevant -> skip
possibly relevant     -> retain
definitely relevant   -> prioritise
```

Official references:

- <https://stryker-mutator.io/docs/stryker-net/configuration/>
- <https://stryker-mutator.io/docs/stryker-net/stryker-in-pipeline/>
