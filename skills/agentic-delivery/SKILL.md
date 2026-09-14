---
name: agentic-delivery
description: 'Use when autonomously delivering a non-trivial feature or multi-step code change from accepted scope through tested, independently reviewed, safely published completion.'
---

# Agentic Delivery

Deliver the smallest accepted outcome all the way from authoritative scope to
tested, independently reviewed, published completion. Project instructions may
make this workflow stricter or replace its adapters; do not weaken them or
introduce a competing tracker, specification format, test runner, or Git policy.

This skill coordinates the work. Use `behavior-first-tdd` for test design,
`coverage-and-mutation` for evidence strength and code pruning, and `reflect`
after the work lands.

## Establish authority and a bounded goal

Before selecting or expanding work:

- Read the repository instructions and discover its release plan, canonical
  specification or issue system, current branch, status, and unfinished work.
- Name the current product or release outcome, the specific exit condition this
  work advances, and the first dependency-ready task that owns it.
- Treat accepted requirements and tasks as authority. Existing code, chat,
  prototypes, review comments, and generated artifacts are evidence or inputs;
  they do not silently authorize scope.
- If the plan, specification, task list, and code disagree, reconcile the
  authoritative artifacts before implementation.
- State the goal's expected outcome, stopping condition, allowed side effects,
  required evidence, and cut line. Prefer one coherent feature or release gate
  to an unbounded “finish everything” goal.

Proceed autonomously through routine, reversible decisions inside that boundary.
Ask before changing accepted scope, spending money, taking licence or privacy
risk, publishing externally without prior authority, or making an expensive-to-
reverse architecture or data decision.

## Make the change test-actionable

Before changing product behaviour, require an owning task and an acceptance
criterion that states an observable outcome or verifiable invariant. Give
requirements and criteria stable identities when the project's system supports
them, and make the task reference the criteria it claims to satisfy.

Keep implementation instructions, packages, filenames, and commands in the
design or task plan rather than disguising them as acceptance criteria. When
implementation reveals missing behaviour, update the accepted contract before
writing that behaviour.

Exploration is read-only. A spike still needs an owning task, one bounded
question, a cost or time limit, success and failure thresholds, a fallback, and
an explicit adopt/revise/defer/stop result. Isolated spikes, prototypes, and
utility scripts may use output or measurement evidence instead of production
TDD; promotion into production activates the normal gates.

## Establish sole ownership of the workspace

Inspect status and branches before editing. Preserve unrelated changes and stage
only task-owned paths.

Use a short-lived branch or project-approved trunk workflow. Parallel tasks need
separate worktrees and explicit ownership of files and mutable resources. If
tasks share specifications, build configuration, schemas, generated corpora,
ports, databases, caches, or unmerged APIs, serialize them. Passing separately
does not prove the combined result.

## Select environment modules

Before choosing build, test, coverage, or mutation commands, read
[references/environments/index.md](references/environments/index.md) and every
module matching the changed production areas. In a polyglot repository, load
all applicable modules and keep their evidence separate until an intentional
integration gate combines it.

Repository-local drivers and instructions override the portable modules. Never
substitute a superficially similar flag from another implementation: Stryker.NET
and StrykerJS, for example, use different incremental and baseline models.

## Deliver one criterion through the complete TDD loop

For each behaviour criterion, read and follow `behavior-first-tdd`:

1. Inspect adjacent tests and decide whether the case can be consolidated
   without weakening regression protection, resistance to refactoring, fast
   feedback, or maintainability.
2. Declare the behaviour, observable result, intended production scope, and the
   exact tests that will prove it.
3. Produce RED and confirm the failure is the missing behaviour—not setup,
   compilation, spelling, or an unrelated defect.
4. Implement only enough to reach GREEN.
5. Run COVERAGE as a design diagnostic: identify unprotected boundaries,
   branches, failure paths, state transitions, invariants, and unearned code.
6. REFACTOR production code and tests. Simplify responsibilities, vocabulary,
   coupling, fixtures, and assertions; remove redundant tests and unjustified
   code. Record a concrete reason when either side genuinely needs no change.
7. Return to green through the project driver before starting the next RED.

Do not collapse the loop into RED → GREEN → next RED. Preserve machine-readable
evidence of the intended RED and final green state when the repository provides
a managed driver. Never bypass that driver merely because a direct test command
is shorter.

## Build evidence in widening rings

Use the narrowest owning test during the inner loop, then widen proportionately:

1. criterion-owning tests;
2. feature or package tests;
3. the fast unit suite;
4. the complete suite;
5. owning-package coverage;
6. mutation analysis for changed core production areas; and
7. applicable build, architecture, specification, generated-data, security,
   rendering, performance, or manual-use gates.

Do not narrow a completion gate to make it pass. If tooling requires composite
runs, preserve the full intended scope and disclose the split.

For long commands, retain the exact command, working directory, complete output,
duration, and exit status in a named log while showing concise progress and
actionable failures. Silence, a partial artifact, or a coverage percentage is
not proof of success.

Read `coverage-and-mutation` before interpreting uncovered code or mutants.
Coverage asks whether code ran; mutation asks whether an outcome was checked.
Classify survivors as missing behavioural protection, unnecessary or misplaced
code, equivalent mutants, or tool limitations. Prefer deleting or simplifying
unearned code to adding score-driven tests.

## Integrate, verify, and freeze the completion candidate

Before completion review, integrate the current upstream according to the
project's Git policy and rerun every affected gate. Then freeze in-scope paths;
do not let another writer change them during review.

Prepare a raw candidate packet containing:

- accepted tasks, requirements, and criteria;
- base, current revision, branch, full upstream identity, and integration base;
- every changed, staged, unstaged, or untracked in-scope path;
- exact automated and manual evidence, including mutation details where useful;
- unrelated user work explicitly excluded from the candidate;
- acknowledged evidence gaps and unresolved owner decisions; and
- a finite proposed finalization, publication, and cleanup envelope.

Bind the packet to a deterministic manifest of path bytes, status, file mode,
content hash, and staged object identity. If the project has no manifest tool,
create the smallest deterministic equivalent that lets another session prove it
reviewed the same bytes.

## Require independent completion review

Before declaring a non-trivial feature, vertical slice, migration, or product-
behaviour change complete, read and follow
[references/completion-review.md](references/completion-review.md).

The reviewer must be separate from the implementer, inspect the whole frozen
candidate, and return exactly `PASS`, `FAIL`, or `BLOCKED`. Correct findings and
return the complete revised candidate to the retained reviewer until `PASS`.
Do not negotiate findings away or approve your own work.

## Publish only the approved candidate

After `PASS`, recompute the candidate identity and require an exact match. Apply
only the reviewer's finite envelope, rerun its named checks, and verify every
other reviewed byte stayed unchanged. Commit with hooks enabled.

Fetch the recorded upstream without rebasing or merging. Push normally only if
the upstream object is still the reviewed one. Upstream movement, a rejected
push, a failed check, an unexpected generated edit, or any non-envelope content
change invalidates the verdict; reintegrate and review the new candidate.

After a successful push, inspect status, branches, worktrees, processes,
containers, ports, databases, logs, and caches. Remove only state proven task-
owned, completed, merged, pushed, and no longer needed as evidence. Report and
retain anything active, unrelated, unmerged, unpushed, or ambiguous.

Finally use `reflect`. Propose only transferable, non-obvious, load-bearing
lessons, including their evidence, target rule or skill, behavioural change, and
cost. Require owner confirmation before changing standing guidance.

## Completion report

Report the outcome and evidence, not merely activity:

- release or product criterion advanced;
- tasks and acceptance criteria satisfied;
- tests, coverage, mutation, and any manual evidence;
- independent verdict and candidate identity;
- commit and publication result;
- cleanup performed and ambiguous state retained;
- remaining risk; and
- the next dependency-ready task, without starting a new goal boundary.

## Notes

- Documentation-only maintenance and experiments making no readiness claim do
  not automatically need the independent feature review. Apply proportionate
  checks and the project's stricter rules.
- Exact tools are adapters. OpenSpec, Jira, GitHub, xUnit, pytest, Stryker, and
  particular agent models are not requirements of this workflow.
- Autonomy does not expand authority. Finishing, babysitting, or “do not stop”
  changes persistence, not permission.
