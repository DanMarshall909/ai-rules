# Objective and rolling investigation

Read when establishing a project objective or organizing bounded investigations.
This does not activate implementation for a planning-only request.

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

Read [references/discovery-and-decisions.md](discovery-and-decisions.md)
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
