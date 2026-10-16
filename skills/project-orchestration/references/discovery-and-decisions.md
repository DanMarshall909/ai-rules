# Discovery and decisions

Read this when domain meaning, UI, architecture or specialist decisions could
change the next slice. Keep these records proportionate and in the project's
existing design/decision artifacts; this is not a mandatory document hierarchy.

## Shared vocabulary

Create a lightweight glossary early, or refine the existing one. Capture terms
that affect requirements, interfaces, calculations or user language:

| Field | Use |
|---|---|
| Canonical term and aliases | Connect stakeholder, UI and code vocabulary. |
| Meaning and distinctions | Define it and distinguish easily confused concepts. |
| Example, units or states | Add only what resolves ambiguity, including transitions when relevant. |
| Source or accountable role | Identify where the meaning comes from and who can settle it. |
| Confidence | Confirmed, provisional or disputed, with the unresolved question. |

Do not turn an agent's convenient label into an authoritative domain concept.
Use glossary identities in criteria and interface designs. When a definition
changes, inspect affected criteria, UI wording, contracts and calculations;
do not silently revise an already accepted meaning.

## UI and interaction direction

For UI work, describe the user's journey and roles before dividing screens
among implementers. Start with rough sketches, annotated mockups or a small
prototype where they expose uncertainty faster than prose. Label provisional
behaviour and distinguish illustrative visuals from accepted product contracts.

Maintain a concise UI/interaction guide, reusing the existing design system:

- journey entry/exit, role permissions and consequential user actions;
- navigation, information hierarchy, terminology and interaction patterns;
- empty, loading, error, validation and access-denied states;
- responsive behaviour, keyboard/focus use and relevant accessibility needs;
- links from accepted journey outcomes to slice criteria and visual references.

Validate high-risk interactions early through available user evidence.
A prototype is not permission to ship its data handling or bypass production
quality gates. Defer polish that does not affect the next slice's correctness.

## Architecture direction

Inspect current runtime and contracts before relying on historical diagrams.
Reuse accepted architecture when it meets the objective. For a material new
decision, compare credible alternatives against actual constraints, including:

- system/component boundaries, responsibilities and dependency direction;
- interfaces, contracts, domain data, persistence and migrations;
- security, privacy, authorization and failure/concurrency behaviour;
- non-functional requirements such as performance, resilience and operability;
- tooling, deployment, compute, shared resources and delivery cost.

Record the chosen direction, alternatives, tradeoffs, assumptions and validation
needed. Use a proportional ADR for consequential or expensive-to-reverse choices;
a short decision note may suffice for reversible local choices.
Use bounded spikes to answer concrete unknowns, with a question, budget,
success/failure threshold and adopt/revise/defer result. Validate the assumption
at the smallest useful real boundary. Do not treat a diagram or fake as runtime
proof. Keep speculative future architecture provisional.

## SME decisions and early heads-up

Surface specialist dependencies as soon as they are visible, before their slice
is scheduled for implementation. Identify the accountable role; do not invent
contacts or assume availability.

Maintain a compact decision register:

| Field | Required content |
|---|---|
| Decision ID and role | Stable reference and accountable domain/owner role. |
| Exact question | Context, options and a recommended answer if justified. |
| Consequence | What depends on it and what could be wrong without it. |
| Needed by | Dependent slice or date/time, with timezone when relevant. |
| Interim handling | Safe provisional fallback or explicit restriction; who may authorize it. |
| State and evidence | Pending/answered/disputed, source, decision and affected criteria. |

Prepare a short read-ahead with objective, glossary terms, examples, options and
the decision needed. Preparation is permitted within scope; sending messages,
meeting invitations or outreach requires human authorization. Existing explicit
outreach authority can be reused within its scope.

If the SME is unavailable, pause only decisions or slices whose correctness or
authority depends on their answer. Continue independent engineering, tooling or
evidence preparation. Escalate the needed decision with its practical impact
when user input becomes necessary. Never claim an AI, proxy or internal review
satisfies required stakeholder or business-owner acceptance.
