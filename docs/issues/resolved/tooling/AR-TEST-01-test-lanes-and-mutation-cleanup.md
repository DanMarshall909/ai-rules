---
id: AR-TEST-01
type: Policy
status: Resolved
area: tooling
created: 2026-10-14
---

# Test lanes, coverage-aware mutation scope and cleanup

The user explicitly requested a global rule for every maintained test suite in
every repository: fast and slow lanes, slow tests excluded from mutation while
their ordinary coverage informs slow-only source exclusions, repeated timing
checks before moving tests in either direction, and required cleanup because
mutation output is exhausting disk space.

## Acceptance criteria

- L1: The base policy requires named fast/slow lanes, ordinary final-ticket slow
  verification and per-run candidate review with comparable anomaly checks.
- L2: The procedural owner distinguishes fast-only, shared, slow-only, genuinely
  uncovered and unknown source coverage. Slow tests never run in any mutation
  phase; only measured slow-only sections are excluded. Missing attribution is
  visible pending scope, not an invented exclusion or successful score.
- L3: Every terminal mutation path completes bounded owned-output cleanup while
  preserving compact reports, reusable baselines and unrelated work. Record
  remaining workers, removal failures and disk space reclaimed separately.
- L4: Generated policy and package checks pass, and scenario review covers lane
  anomalies, both-direction moves, coverage attribution limits and cleanup under
  success/failure/cancellation and disk pressure.

## Scope and decisions

This is an authorized policy/procedure update in the durable shared checkout,
not a claim that every consuming repository already implements a coverage adapter
or automated cleanup. Existing installed links consume the regenerated policy
and complete skill packages; client reload remains a separate boundary.

The RT-021 lane implementation remains a bounded test-selection slice. Its new
slow-only coverage adapter and disposable-output lifecycle work must stay
explicitly tracked in RT-021 until calibrated; ordinary verification does not
establish those mutation capabilities. No hours-long mutation run is needed to
validate this guidance change.

Authored owners are the TDD/coverage fragments, behavior-first TDD and
coverage-and-mutation procedures, and the .NET/JavaScript environment modules.
The linked lane/lifecycle reference keeps detailed mechanics out of always-loaded
rules. Mechanical generator/installation checks establish distribution, while
independent realistic scenario review establishes policy coherence.

Startup master and origin/master both identify
`a24fe19b527953ce7fc4b8f4d9dacd4ac9cca74b`. The two linked non-primary worktrees
are clean and integrated; they remain retained because current ownership/activity
is uncertain. No worktree, shared build cache or dependency cache is deleted by
this policy change.

## Resolution decision, 2026-10-14

Independent completion review returned PASS for the exact policy candidate and
this resolution mapping. All ten Bash generation, installation, scaffolding,
convention and resource-schema checks passed. Realistic scenario review covers
anomaly checks, both-direction moves, source coverage states, unavailable
attribution and terminal cleanup under disk pressure. The regenerated base
remains within its existing 199-line budget.

Publish this reviewed policy normally and retain the evidence at
`/tmp/ar-test-01-20261014-fxcdta6d/`. Existing installed package/policy links
resolve to the durable checkout; running clients may need refresh. No consuming
repository adapter, automation retrofit or new mutation score is claimed.
