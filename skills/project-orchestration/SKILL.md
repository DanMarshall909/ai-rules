---
name: project-orchestration
description: Coordinate a large software project across discovery, rolling plans, delegated work packages and session handoffs. Use when the objective needs refinement before implementation or several slices need coordination; use agentic-delivery for an already bounded implementation task.
---

# Project Orchestration

Turn the software objective into evidence-backed, dependency-ready slices and
coordinate their delivery with minimal routine user input. Start rough, refine
where uncertainty matters, and stop at the agreed outcome. This workflow owns
project coordination; it does not replace delivery, testing or tracker owners.
For an ordinary slice, use one owner, the existing task record, a checkpoint
revision, test results and independent review where required. Add records only
for a specific review, recovery or project requirement.

## Establish the objective before delegating

The lead first reads the user's objective, applicable instructions, existing
plans and decisions, declared sources of truth, and enough current source or
product evidence to formulate bounded investigation questions. Do not dispatch
agents to "work out and build the project" before this orientation.

Record a compact objective brief, reusing an existing artifact when suitable:

- users, their pain and the desired software outcome;
- observable success measures and stopping condition;
- non-goals, constraints, allowed side effects and existing authority;
- authoritative sources with revision/date and known precedence;
- confirmed facts, assumptions and unknowns, kept distinct.

Identify disagreements between requirements, tracker and current behaviour.
Existing implementation is evidence, not automatic requirement authority.
Resolve only disagreements material to the next action. Ask for required
inputs or material decisions with context and a recommendation; reuse accepted
decisions and permissions. Silence is not consent.

Keep recommendations separate from execution authority: a request to identify
next work does not itself authorize implementation. Respect planning-only and
orchestration-only limits. Within an already authorized objective, routine
refinement and execution do not need separate approval at each phase.

Make that scope shared with the owner before dependent execution. Surface material
assumptions and choices about behaviour, architecture, persistent data and cost;
investigate facts before asking and reuse accepted decisions. A detailed internal
brief does not prove the planning conversation established shared understanding.
Use the shared-scope procedure in `agentic-delivery` for an implementation goal.

## Investigate and refine in rolling waves

Once bounded questions are clear, run independent read-only investigations in
parallel when supported and useful. Give each reader its question, exclusions,
source snapshot, evidence expected and uncertainty to resolve. Readers must
separate observed facts from inference, and return source references and gaps.
Read-only authority permits inspecting sources and retained evidence; it excludes
edits, generators/builds/tests that mutate outputs, Git/tracker mutations and
service changes unless execution authority is separately assigned.

Combine findings before selecting implementation direction. Keep detailed
outcomes, criteria, dependencies and risks for the next ready slice; keep later
scope provisional. Refine through as many useful passes as needed, including
across sessions, without completing all discovery before any delivery.
A discovery result may narrow scope or create another bounded question.

Read [references/discovery-and-decisions.md](references/discovery-and-decisions.md)
when clarifying domain terms, UI, architecture, specialist decisions or uncertain
external capabilities. Qualify a dependency that could invalidate the approach
at the smallest useful real boundary before expanding dependent implementation.
Use a bounded experiment with a decision at its end, not open-ended retries. Reuse
accepted direction; do not recreate mockups or ADRs merely to satisfy a phase.
Once direction is accepted, execute the next ready slice. Reopen delivery choices
when new evidence or a user correction changes the next action; name that reason
briefly rather than repeating general planning.
Maintain enough shared vocabulary and design direction to prevent incompatible
work packages, and prepare specialist decision requests early.

## Select the tracker

Use the project's declared tracker and discover its real capabilities:

- `track-github-work`: GitHub Issues, optionally GitHub Projects;
- `track-repository-work`: repository Markdown records;
- `track-external-work-items`: another work-item system.

These are discoverable package names; load the matching installed skill.
Each adapter also works independently. If missing, disclose that and follow
declared conventions with available tools without claiming the adapter loaded.

Keep one authority per live fact. Hybrid arrangements must assign distinct
ownership, such as external workflow state and repository design/evidence.
OpenSpec or similar specifications describe accepted design and evidence;
they do not become a competing live workflow tracker.
Do not create a local shadow tracker when remote access fails.

## Make the next slice ready

Before implementation, require a clear outcome, observable acceptance criteria,
dependencies, decision authority and execution owner. Unresolved questions must
not be able to invalidate this slice's accepted behaviour or constraints.
Restrict or defer dependent work; continue unrelated ready engineering.

Read [references/work-packages-and-resume.md](references/work-packages-and-resume.md)
when preparing assignments, transferring execution or resuming a session.
For every work package, record:

- stable item/criterion IDs, outcome, exclusions, dependencies and order;
- agent role, available model/effort choice and criterion-based reason;
- delegated decision/repair authority, retry and escalation boundaries, and owned
  source, tests, contracts, schemas, generated files and mutable resources;
- independently accepted proof for the SAME criterion, with revision and review;
- the smallest novel boundary needing a tracer, when existing proof is absent;
- tests, evidence, independent review, handoff, integration and completion rules.

Put these facts in the assignment or existing task record. The same record can
serve ownership, handback and recovery; do not create copies for each purpose.

Code existence, shared libraries and neighbouring tests are not same-criterion
proof. Carve the smallest coherent tracer out of mixed work, then use the least
resource-intensive actually available qualified agents for proven followups.
Use stronger capability for a named unproved boundary or required review,
rather than ticket size, importance or a timeless hardcoded model list.

## Delegate and coordinate execution

Delegate implementation with explicit execution ownership and bounded scope.
Follow project worktree, branch, PR and shared-resource policies.
Default to one writer/execution owner per shared mutable scope. Retain that
owner through dependent implementation, tests and repairs unless availability,
independence or a concrete benefit calls for transfer. Separate worktrees do
not isolate shared schemas, Git operations, outputs, caches,
ports, services or databases; serialize overlapping operations.

Read-only agents use identified snapshots and must flag drift. Before readers
become writers, explicitly assign ownership. An interruption, silence or partial
result does not release a writer's scope. Require an explicit handback and
recipient acknowledgment before another executor takes over.

If delegation tools are unavailable, report that limit. Preserve a user's
orchestration-only constraint: prepare assignments and a resume packet; do not
silently implement as the lead. Otherwise use one executor within authority.

Route accepted slice delivery to `agentic-delivery`, behaviour/test changes to
`behavior-first-tdd`, and independent completion review to the completion-review
reference inside `agentic-delivery`. Discover and read these packages rather
than assuming they loaded. If unavailable, state the gap, use applicable project
procedures, and leave unmet review or evidence gates outstanding.

## Validate, checkpoint and stop

Validate the assembled candidate against the objective and slice criteria.
Individually passing branches do not prove their combined behaviour.
Retain independent review and exact candidate identity using the delivery owner.
Link evidence to the inputs and boundaries it qualifies; use affected dependencies
to decide what to revalidate while retaining every mandatory gate.

Track local checks, review, commit, push, PR, CI, merge, deployment, hosted
verification and business/SME acceptance as separate evidence states.
Authority for each action is separate from evidence that it succeeded.
Engineering or synthetic review does not stand in for accountable owner acceptance.
An explicitly authorized partial integration follows the project's applicable
integration/publication gates. Do not impose completion-only gates as though
completion were claimed, or waive gates that also apply to unfinished work.
Record its isolation or exposure, open criteria and next action. Merge never
supplies missing acceptance or qualifies a dependency that requires completion.

Update the authorized tracker when its live status, decision, owner or next
dependency changes. Use the existing record for a handback. Add recovery details
before stopping with unfinished work, an impending compaction, or transfer to
an executor without usable context. On resume, revalidate affected state and
replan only what changed. Do not create parallel status documents.
Do not schedule recurring work unless requested.

At the agreed stopping condition, report delivered outcomes, candidate and
tracker references, evidence levels, outstanding acceptance and released or
retained resources. Hand over active work explicitly; do not start another
objective merely because future ideas remain.

Use the owner-handover procedure in `agentic-delivery`: explain demonstrated
behaviour, important changes and reasons, uncertainty, next action and recovery
point; check understanding through a concrete consequence. Keep technical delivery
and owner handover distinct. Reuse the existing record so the next session can
recover this picture without reconstructing conversations.
