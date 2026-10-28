---
name: agentic-delivery
description: 'Use when autonomously delivering a non-trivial feature or multi-step code change from accepted scope through tested, independently reviewed, safely published completion.'
---

# Agentic Delivery

Deliver the accepted outcome all the way from authoritative scope to
tested, independently reviewed, published completion within the requested scope.
Explicit task and scoped project instructions refine shared defaults within the
host's hierarchy. Do not introduce a competing tracker, specification format,
test runner, or Git policy. Reviews and diagnoses do not activate implementation.

This skill coordinates the work. Use `behavior-first-tdd` for test design,
`coverage-and-mutation` for evidence strength and code pruning, and `reflect`
quietly throughout execution, consolidating findings at the normal handoff.

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

Calibrate the amount of work with the owner in both directions. Recommend a
larger coherent goal when shared scope, settled decisions and recent handovers
support more work the owner can understand and steer. Recommend a smaller outcome
or earlier checkpoint when unfamiliar changes, unresolved choices or understanding
gaps accumulate. Use owner feedback and demonstrated understanding to judge
capacity; code volume, test counts and agent speed do not establish it. Agree
scope adjustments with the owner; do not silently expand a goal or redefine it
around an easier subset.

Proceed autonomously through routine, reversible decisions inside that boundary.
Ask before changing accepted scope, spending money, taking licence or privacy
risk, publishing externally without prior authority, or making an expensive-to-
reverse architecture or data decision.

### Establish shared scope before execution

Make the planning conversation detailed enough for the owner to understand the
change: intended user behaviour, included and excluded scope, affected boundaries,
material design/data choices, required proof and a safe stopping point. Walk
through a representative outcome and a relevant refusal or failure case when
that reveals a consequential ambiguity. Reuse decisions already accepted.

Separate verified facts, routine implementation choices and material assumptions.
Investigate uncertainty that tools or existing records can resolve; ask the owner
about decisions that could materially change behaviour, scope, architecture,
persistent data, cost or reversibility. Do not silently choose a direction or
treat an agent's detailed plan as evidence that the owner agreed. An authorized
goal may include bounded discovery with an explicit decision point; hold dependent
implementation until that point is resolved. Scale planning to the actual risk.

For work spanning sessions, maintain a short orientation in the existing
authorized project/task record: current outcome, demonstrated working behaviour,
important changes and reasons, unknown/broken behaviour, and next bounded action
with the last working checkpoint. Link authoritative status and revision-bound
evidence; keep one live-fact owner. Update at meaningful handoffs and read it on
resume. No new diary, per-tool record or second tracker is required.

## Assign agent capability from criterion evidence

When the host supports delegation or model selection, choose from evidence
rather than task prestige or apparent code size. Before assigning a higher-cost
or highest-capability implementation agent, map every delegated acceptance
criterion using these fields:

| Field | Required evidence |
|---|---|
| Criterion | The exact observable outcome or invariant being assigned. |
| Landed proof | Independently accepted behaviour, code, tests, revision and review that prove the same criterion. |
| Novel boundary | Any unproved decision, state transition, persistence shape, authority boundary, interface or foundational primitive. |
| Assignment | `Tracer` for a named novel boundary; otherwise `Followup` with the lowest-cost qualified agent. |

Apply the map as follows:

- A criterion with an unproved boundary is a tracer even when its code looks
  small. Assign a sufficiently capable agent and make that smallest coherent
  end-to-end slice the reference implementation.
- A criterion fully mapped to landed proof is a followup. Use the least
  resource-intensive available agent that has the required reasoning ability,
  tools, context and permissions; do not repeat the tracer merely because the
  feature is important, broad, on the critical path or crosses layers.
- For mixed work, carve out the smallest tracer that proves the novel boundary
  and leave every fully mapped criterion as a separately bounded followup.
- Dependency or code reuse alone does not prove followup status. If the mapping
  is uncertain, investigate first; unresolved novelty remains a tracer rather
  than an assumed followup.

Project policy may name concrete models, require a stronger tier or prohibit
delegation. Independent completion review retains the capability and separation
requirements in `references/completion-review.md`; this assignment rule does not
lower them.

## Make the change test-actionable

Before changing product behaviour, require an owning task and an acceptance
criterion that states an observable outcome or verifiable invariant. Give
requirements and criteria stable identities when the project's system supports
them, and make the task reference the criteria it claims to satisfy.

Keep implementation instructions, packages, filenames, and commands in the
design or task plan rather than disguising them as acceptance criteria. When
implementation reveals missing behaviour, update the accepted contract before
writing that behaviour.

Read-only exploration needs no implementation workflow. A spike needs one bounded
question, a cost or time limit, success and failure thresholds, a fallback, and
an explicit adopt/revise/defer/stop result. Isolated spikes, prototypes, and
genuinely one-off scripts may use output or measurement evidence instead of
production TDD. Maintained, reused or recurring operational scripts follow the
normal gates even when they are called utilities.

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

For each behaviour criterion, read and follow `behavior-first-tdd`, the owner of
test design and the complete RED → GREEN → COVERAGE → REFACTOR cycle. Retain its
criterion evidence and production/test refactor decisions before the next RED.
Use the repository's managed driver and machine-readable evidence when supplied.

## Build evidence in widening rings

Use the narrowest owning test during the inner loop, then widen proportionately:

1. criterion-owning tests;
2. feature or package tests;
3. the fast unit suite;
4. the complete suite;
5. owning-package coverage;
6. applicable build, architecture, specification, generated-data, security,
   rendering, performance, or manual-use gates.

Do not narrow a completion gate to make it pass. If tooling requires composite
runs, preserve the full intended scope and disclose the split. After a repair,
rerun affected checks and required combined gates. Reuse prior results only when
the relevant inputs remain unchanged and the result is still reliable. Rerun
cheap checks when establishing safe reuse would cost more; do not build custom
dependency manifests or logging wrappers merely to avoid a fast test.

Mutation analysis of changed core production areas begins after the whole
coding session, against its final immutable source snapshot. It does not hold
up a verified ticket, integration, or publication. Report a queued or running
job as pending, never as passing evidence; use the result-review and follow-up
rules in `coverage-and-mutation` when it completes.

For long commands, retain the exact command, working directory, complete output,
duration, and exit status. Reuse the runner's log or receipt when it has these
facts; create one named log only when it does not. Show concise progress and
actionable failures. Silence, a partial artifact, or a coverage percentage is
not proof of success.

Read `coverage-and-mutation` for coverage gaps, survivor classification, harness
calibration and pruning decisions. It owns evidence interpretation; this skill
owns when to widen validation and assemble the completion evidence.

## Review and publish the exact candidate

Before declaring a non-trivial feature, vertical slice, migration, or product-
behaviour change complete, read and follow
[references/completion-review.md](references/completion-review.md).

That reference is the procedural owner of upstream integration, candidate
identity, independent PASS/FAIL/BLOCKED review, repair rounds,
and the finite post-PASS publication envelope. Do not self-approve or mutate the
reviewed candidate outside that envelope. Publication still needs task authority.

Use `storage-budget` before heavy output-producing operations. Check output and
temporary volumes, accounting for known competing jobs, against the declared
workload estimate and reserve; pause only a producer that cannot fit. For
managed disposable output, retain a compact receipt outside the run directory
and verify cleanup after success, failure or cancellation once workers stop.
Cleanup failure is a separate reported outcome, even when the command passed.

At handoff, inspect task-owned worktrees, processes and retained output. Keep
source preservation and generated-output retention separate: a preserved branch
does not require keeping every build or report copy. Review reusable builds,
dependencies, caches and evidence against their retention budget with measured
size, purpose and rebuild cost. Get explicit direction before deleting reusable
state. Retain active, unrelated, unmerged, unpushed or uncertain work; report its
next disposition without inventing permission to remove it. Use the existing
task record and storage receipt rather than a second retention ledger.

Consolidate the observations gathered through `reflect` when control returns to
the user. Keep material findings and proposed guidance changes in the completion
report, after the outcome and evidence. Do not create a separate interruption or
expand the task to implement a new lesson. Changes to standing guidance still
need owner agreement unless already requested.

## Completion report

Lead with a handover the owner can reason about:

- what now works for the user, tied to the agreed goal;
- the few behavioural or architectural changes that matter and why;
- a concrete demonstration or example connecting input, system decision, result
  and persistence/replay where relevant, with evidence for the claimed revision;
- what remains uncertain, broken or outside the demonstrated scope; and
- the next bounded action and the last working state available for recovery.

Keep the engineering detail accessible through existing records: release/product
criterion, tasks and acceptance criteria satisfied, tests/coverage/mutation/manual
evidence, independent verdict and candidate identity, commit/publication state,
cleanup and retained ambiguity, material findings and guidance dispositions.
Test totals and agent agreement alone do not explain the delivered behaviour.
Do not start another goal merely because the next dependency is ready.

### Confirm the owner's handover

After presenting the outcome, use a brief conversational check about a concrete
consequence, boundary or decision to establish whether the owner understands the
change. Avoid a generic "does that make sense?", a formal quiz or a demand to
review implementation detail. Invite correction and questions. When a reply
reveals a gap, explain or demonstrate that part and check again proportionately.

Distinguish technical delivery complete from owner handover confirmed. If there
is no reply, record understanding as unconfirmed in the existing handover; do
not invent acceptance or reopen completed engineering gates. Preserve the agreed
goal and ordinary autonomy. A comprehension gap calls for explanation, not more
features, tests or unsolicited work.

## Notes

- Documentation-only maintenance and experiments making no readiness claim do
  not automatically need the independent feature review. Apply proportionate
  checks and the project's stricter rules.
- Exact tools are adapters. OpenSpec, Jira, GitHub, xUnit, pytest, Stryker, and
  particular agent models are not requirements of this workflow.
- Autonomy does not expand authority. Finishing, babysitting, or “do not stop”
  changes persistence, not permission.
