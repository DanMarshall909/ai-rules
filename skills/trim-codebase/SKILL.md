---
name: trim-codebase
description: 'Challenge the value of a codebase by interrogating the AI first, then the user, and propose removal of unjustified code and its tests. Use for deliberate codebase pruning or reducing product scope, not routine refactoring or coverage cleanup.'
---

# Trim the codebase

Find the smallest codebase that delivers the outcomes the owner actually values.
Challenge whole capabilities, including working features, demos, abstractions,
compatibility paths and developer tooling. Dead-code detection is only one input.
The result is an evidence-backed recommendation about what deserves to remain,
followed by concrete removal proposals for what does not.

Investigate first, cross-examine your own justification, then grill the user on
the remaining value choices. Be direct and persistent about weak reasons, while
respecting the owner's decisions. A pruning review authorizes investigation and
proposals; applying deletions requires implementation authority for that scope.
Reuse authority already given instead of asking for the same approval again.

## Establish the essential product

Read the project's purpose, accepted requirements, current work and actual
entrypoints. State the few outcomes that appear essential and whose needs they
serve. Label inferred priorities and ask the owner to correct them after your
investigation. Do not silently redefine the product to suit an easy deletion.

Map the scoped codebase by capability, with paths to its implementation, tests
and consumers. Account for runtime features, maintenance/recovery tools, build
and release support, examples and compatibility obligations. Group by useful
outcome rather than making the user defend every helper function. Name unexamined
areas; a sampled review is not a whole-codebase verdict.

Prioritize candidates by weak justification and avoidable maintenance burden.
Do not use a target percentage, line count, low coverage, age or an unfamiliar
directory name as a deletion rule. Rarely exercised safety, recovery and migration
paths can be essential; popularity is not the sole measure of value.

## Grill the AI first

For each capability, make a short, inspectable case for keeping it, then try to
disprove that case. Present evidence and conclusions, not a private reasoning
transcript. Answer:

- Who uses this, for which concrete outcome? Trace a real consumer or obligation
  to the code; internal calls within an otherwise unused subsystem prove little.
- If it disappeared, what would someone lose? Name the task, contract, supported
  data, failure protection or operational ability affected.
- Does that outcome belong in the essential product? Working and reachable code
  can still provide too little value to justify its continued ownership.
- Is this implementation necessary? Could an existing capability, a smaller
  implementation, a documented manual step or an external tool meet the need?
  Include the replacement's cost and limitations.
- What does retention cost in concepts, dependencies, public surface, tests,
  maintenance and feedback time? Separate measured costs from estimates.
- Would you choose to build and maintain it today? What evidence would change
  your recommendation?

Do not accept "it has tests", "it is reusable", "best practice", "we already
built it", or "we might need it" as sufficient justification. Trace those claims
to a real need. An accepted near-term consumer can justify unwired code; name
the accepted work and why retaining this implementation helps. Do not invent a
future feature or propose wiring code up just to save it from removal.

Check more than static references before declaring code unused: relevant public
APIs, plugins/reflection, configuration, command entrypoints, shipped versions,
persisted data and external callers. Bound searches and name inaccessible
evidence. No observed use is not proof of no use. Use existing coverage and
mutation reports within their measured scope; do not launch a costly suite or
mutation run merely to manufacture a value verdict.

Record each candidate's strongest justification, evidence against it, consequence
of removal, uncertainty and your recommendation. Make a judgment; do not pass an
unranked file inventory to the user and ask them to do the analysis.

## Then grill the user

Present the proposed essential core and the highest-impact disputed capability
first. Give the evidence, your recommendation and the concrete loss before
asking a focused question. Ask one material decision at a time, or a small group
when the decisions are inseparable. Investigate discoverable facts yourself.

Useful questions include:

- "Who needs this outcome, and what would they do without it?"
- "Which current commitment makes this worth maintaining?"
- "If we were starting today, would you spend time building this? Why?"
- "Would the simpler alternative meet the actual need? What would it miss?"
- "What specific use makes keeping this worth its ongoing cost?"

Follow vague answers with a concrete consequence or request for an example.
Challenge a contradiction once it becomes clear; do not turn the exchange into
repeated attempts to secure agreement. Learning, enjoyment, aesthetics and
demonstration can be legitimate product goals when the owner actually values
them. An explicit owner choice settles the value decision; record its reason
and any remaining factual risk without pretending the evidence changed.

Use four dispositions: **retain**, **simplify**, **remove**, or **unresolved**.
An unanswered question stays unresolved. Name the missing fact or owner decision
and the bounded next action that could settle it. If investigation and the
owner's answers yield no justification, recommend removal plainly. Do not default
to "keep for now", a speculative backlog item, an unwired copy or an archive
inside the maintained codebase. Recovery history does not create a promise to
revisit rejected work. If nothing merits removal, say so with the evidence.

## Propose complete removals

For each removal or simplification, specify a coherent, reviewable change:

- The capability and exact files/symbols to remove or reduce, the rationale,
  affected consumers and the observable behavior intentionally lost.
- Call sites, registrations, flags, exports, dependencies, build/package entries,
  documentation and examples that must change with it. Check shared ownership
  before declaring any dependency or fixture exclusive to the removed feature.
- The exact tests/cases to remove because their sole contract is being retired.
  For mixed tests, identify the obsolete assertions and the retained assertions
  to preserve or move. Name the tests that still protect shared behavior,
  boundaries and historical regressions. A retired contract needs no replacement
  test merely to maintain a test count; a retained contract still needs protection.
- An ordered set of small removal batches, any required consumer/data transition,
  and checks proving the remaining product works and obsolete wiring is gone.
  Test failures are evidence to investigate, not automatic deletion candidates.
- A recovery point and any limits of rollback, especially for deployed consumers
  or persisted data. Retiring source code does not authorize deleting user data.

Tests do not justify otherwise useless production code. Conversely, sharing code
coverage or killed mutants does not prove two tests protect the same contract.
When available, use `coverage-and-mutation` for interpreting that evidence; if
unavailable, retain these distinctions and disclose the limit. Do not lower
coverage thresholds or hide failures to make a removal look successful.

End with the essential core, a concise disposition table with evidence and owner
decisions, and prioritized removal plans. State expected benefits without
inventing measured savings. Distinguish proposals, approved changes and completed
changes. Use the existing tracker when a durable record is requested or required;
do not create a second backlog to avoid deciding.

If implementation is already authorized, apply only the settled scope through
the project's normal change, verification and publication workflow. Otherwise
present the concrete proposal for approval. Stop when the scoped capabilities
have evidence-backed dispositions and actionable proposals; leave unresolved
items visible without claiming the review settled them.
