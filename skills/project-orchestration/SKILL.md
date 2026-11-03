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

## Orient and bound the next action

Read the objective, applicable instructions, current handoff, authoritative plans
and enough relevant evidence to ask bounded questions before dispatching work.
Keep facts, assumptions and unknowns distinct. Share material scope and choices
with the owner before dependent execution; reuse accepted decisions and authority.
Recommendations do not authorize implementation, and silence is not consent.
Preserve planning-only and orchestration-only limits.

Read [objective and investigation](references/objective-and-investigation.md)
when establishing scope or coordinating rolling read-only discovery. Resolve
only uncertainties material to the next action, combine findings before choosing
direction, and keep later scope provisional. Read
[discovery and decisions](references/discovery-and-decisions.md) when domain,
UI, architecture, specialist decisions or uncertain external capabilities could
invalidate a slice. Qualify risky dependencies at the smallest useful real
boundary with bounded experiments and explicit decisions, not open-ended retries.

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

## Prepare and coordinate ready slices

Require a clear outcome, observable criteria, dependencies, decision authority
and execution owner before implementation. Hold dependent work that unresolved
questions could invalidate; continue independent ready work.

Read [work packages and resume](references/work-packages-and-resume.md) when
assigning execution, transferring ownership or recovering a session. Keep scope,
criterion-based capability/proof, repair authority, retries, owned resources,
evidence and completion rules in the existing assignment or task record.
Use one writer per shared mutable scope and retain ownership through dependent
repairs where practical. Separate worktrees do not isolate shared resources.
Silence or interruption does not release ownership: require explicit handback
and recipient acknowledgment before another executor writes.

Read-only workers use identified snapshots, flag drift and need separate execution
authority before mutating outputs, Git, trackers or services. If delegation is
unavailable, disclose it; an orchestration-only lead prepares assignments and
recovery rather than silently implementing. Otherwise use one authorized executor.

Route accepted implementation to `agentic-delivery`, behaviour/test changes to
`behavior-first-tdd`, and independent review to delivery's completion-review
reference. Discover the applicable packages; if missing, disclose the gap and
leave unmet evidence/review gates outstanding. Do not load unrelated procedures.

## Validate and hand back

Read [checkpoint and stop](references/checkpoint-and-stop.md) when assembling,
partially integrating or handing back work. Validate the combined candidate;
separately passing branches do not prove it. Preserve mandatory gates, independent
review and exact candidate identity. Track engineering, publication, hosted and
business acceptance as distinct evidence and authority states; AI review cannot
replace accountable owner acceptance.

Update only authorized records with changed facts. Before unfinished work stops,
context loss or transfer, preserve recovery and active-command ownership there.
On resume, revalidate affected state and replan only what changed. Do not create
parallel status documents or schedule recurring work without a request.

At the agreed stopping condition, report outcomes, candidate/tracker references,
evidence, outstanding acceptance and retained resources. Hand over active work
explicitly and explain the next action and last working state. Distinguish
technical completion from confirmed owner understanding; stop rather than
starting another objective because future ideas remain.
