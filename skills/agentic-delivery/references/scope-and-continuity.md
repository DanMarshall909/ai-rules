# Scope and continuity

Read when establishing or adjusting shared implementation scope, making criteria
test-actionable, or handing an authorized goal across sessions. Reuse accepted
decisions; this procedure does not require a new planning conversation.

## Establish authority and a bounded goal

Before selecting or expanding work:

- Read the repository instructions and discover its release plan, canonical
  specification or issue system, current branch, status, and unfinished work.
- Name the current product or release outcome, the specific exit condition this
  work advances, and the first dependency-ready task that owns it.
- Treat owner-accepted requirements, plans and tasks as authority. Unaccepted
  proposals, existing code, prototypes, review comments and generated artifacts
  are evidence or inputs; they do not silently authorize scope.
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
