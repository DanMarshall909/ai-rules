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

## Scope and ownership

Establish the authoritative accepted outcome, observable criteria, stopping
condition, allowed side effects, proof and cut line before implementation.
Reuse accepted decisions; reconcile material disagreements before dependent work.
Investigate discoverable facts and hold only work depending on unresolved owner
choices. Routine reversible decisions inside accepted scope need no new approval.
Agree scope changes; do not silently expand work or redefine an easier subset.

Read [scope and continuity](references/scope-and-continuity.md) when establishing
or adjusting scope, refining criteria or carrying a goal across sessions.
Read [agent assignment](references/agent-assignment.md) before delegation or
selecting a higher-cost implementation agent: use same-criterion landed proof,
isolate novel boundaries as tracers and use qualified low-cost followups.
Project capability requirements and independent review still apply.

Read-only exploration needs no implementation workflow. Isolated spikes,
prototypes and genuinely one-off scripts use proportionate evidence; maintained,
reused or recurring executable behaviour retains normal gates. Documentation-only
maintenance does not automatically require independent feature review; apply the
project's stricter requirements.

## Establish sole ownership of the workspace

Inspect status and branches before editing. Preserve unrelated changes and stage
only task-owned paths.

Use a short-lived branch or project-approved trunk workflow. Parallel tasks need
separate worktrees and explicit ownership of files and mutable resources. If
tasks share specifications, build configuration, schemas, generated corpora,
ports, databases, caches, or unmerged APIs, serialize them. Passing separately
does not prove the combined result.

## Select applicable procedures

Before choosing build, test, coverage or mutation commands, read the
[environment index](references/environments/index.md) and modules matching the
changed production areas. Load all applicable modules in a polyglot repository;
keep their evidence separate until an intentional integration gate. Local drivers
and instructions override portable modules; do not substitute another tool's flags.

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

Read `coverage-and-mutation` for coverage gaps, survivor classification, harness
calibration and pruning decisions. It owns evidence interpretation; this skill
owns when to widen validation and assemble the completion evidence.

## Long commands, review and closeout

For long commands, read [mechanical waiting](references/long-running-commands.md).
Retain identity, complete output, timing and terminal status outside model context.
Silence, partial artifacts and expired observation remain pending. Use finite,
interruptible observation; preserve the producer unless cancellation is authorized.

Before declaring a non-trivial feature, vertical slice, migration or behaviour
change complete, read [completion review](references/completion-review.md).
It owns upstream integration, exact candidate identity, independent PASS/FAIL/
BLOCKED review, repair rounds and the finite post-PASS publication envelope.
Never self-approve, weaken required review capability or mutate the reviewed
candidate outside that envelope. Publication still needs task authority.

Use `storage-budget` before heavy output-producing operations. At closeout,
read [resources and handover](references/closeout-and-handover.md): preserve
active/unrelated/uncertain work, verify task-owned disposable cleanup after
workers stop, and obtain direction before deleting reusable state.

Report demonstrated user behaviour, important changes and reasons, evidence and
limits, next bounded action and recovery point. Distinguish technical completion
from owner understanding; an unanswered handover does not reopen engineering.
Consolidate material `reflect` findings at handoff; do not expand scope to apply
new standing guidance without authority. Stop when the agreed outcome and all
required verification, review and authorized delivery conditions are satisfied.
