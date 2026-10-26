# Work packages, ownership and resume

Read this when assigning execution, transferring mutable scope or recovering
work across agents or sessions. Reuse existing project records; the fields
below are a compact contract, not a requirement to create another tracker.

## Assignment contract

Give a worker enough context to execute a bounded accepted slice:

| Area | Assignment content |
|---|---|
| Identity | Work item and criterion IDs, objective/plan version, authoritative sources. |
| Scope | Observable outcome, exclusions, dependency order and ready inputs. |
| Evidence map | Independently accepted SAME-criterion proof, revision, tests and review; remaining uncertainty. |
| Novelty | Named unproved decision, transition, persistence shape, authority boundary, interface or primitive. |
| Capability | Role and qualified currently available model/effort, with reason tied to novelty/proof. |
| Ownership | Absolute checkout, branch/base, owned paths, tests, contracts, schemas, generated data and mutable resources. |
| Authority | Permitted edits, commands and side effects; decisions/repairs the worker may make; retry limits, stop/escalation triggers and decision owner. |
| Delivery | Required test/evidence/review, handoff, integration and completion conditions. |

Delegate routine in-scope repair decisions with the work, so workers need not ask
the lead about every reversible choice. Escalate when a named trigger is reached,
accepted behaviour or ownership would change, or required authority is absent.
Retry budgets authorize neither new external actions nor weakening acceptance.

Absence of known proof does not mean absence of implementation. Investigate
before classifying. A dependency that is already used elsewhere still needs
proof for the criterion being assigned. Record code existence separately from
independently accepted behaviour.

When a package mixes novelty and repetition, assign a smallest coherent tracer
to prove the novel boundary end to end, then bounded followups. A more capable
agent may be required for that tracer or independent review. Choose from actual
tools, permissions, context capacity and demonstrated qualification; do not
invent model availability or choose a stronger model because an item is large.

## Mutable-resource coordination

Record each shared mutable scope's owner, revision, active operation and release
condition in the existing assignment or task record. One record may serve
ownership, handback and recovery, with links to the authority for each live fact.
Keep the same owner through dependent implementation, tests and repairs when
practical. Readers identify the revision or content digest they inspected.

Serialize shared Git mutations, generated outputs, schemas/contracts, cache
writes, ports, services, data stores and integration when they overlap.
Isolation claims must reflect actual tool behaviour. Separate branches do not
make one shared service or build output safe for concurrent writers.

Assign an integration owner and order. That owner assembles accepted changes,
checks dependencies/contracts and runs the relevant combined validation.
A worker's PASS does not prove the assembled candidate or authorize publication.

## Evidence and communication cost

Retain raw evidence once and link a compact summary of result, claim, exact inputs
and known limits. Record which source/configuration, external contract and
execution environment each result depends on. After a change, invalidate affected
claims and run the required checks. Reuse evidence when the project permits it
and its dependencies are clear; rerun a cheap check when proving safe reuse would
cost more. Unknown dependencies are not an assumed pass. Required integration
and independent-review gates still apply.

Load the current task/recovery record and relevant references instead of replaying
full history.
Within the same context, reuse already-read instructions when their revision is
unchanged; after context loss, read applicable instructions and current decisions
again rather than assuming they are remembered. Recheck mutable facts before acting.
Ask workers for changed facts, decisions, blockers and evidence links, not repeated
chronologies or complete logs. Keep required raw records intact outside the summary.

When an actual handoff packet is needed, include readily available
orchestration cost evidence if it informs a decision. Separate agent effort from
native execution cost. Label estimates and proxies; unavailable usage is unknown,
not zero. Do not run telemetry or create a status record merely to fill fields.

For long commands, use completion notifications or bounded waits and the project's
inspection cadence. Check again on a meaningful event or planned checkpoint;
avoid frequent unchanged polls, duplicate watchers and narration of every poll.
Keep any host-required responsiveness and progress updates.

## Explicit handback

Before ownership changes, update or link the existing record as one compact
handback:

- checkout/ref and changed paths; a digest only when needed to identify
  uncommitted or generated content;
- outcomes, gaps and links to existing command logs or receipts;
- running commands and shared resources still owned;
- next action and explicit release or retention of mutable scope.

A checkpoint revision identifies committed source; hash additional content only
when needed. This handback can also be the recovery note. Do not create another
manifest, repeat history or copy authoritative tracker state.

The recipient acknowledges the exact snapshot and resources before taking
ownership. Silence, timeouts, interruption and an agent's final prose alone do
not establish release unless it explicitly hands back that scope.
If an executor disappears, verify pending command/process state and preserve its
work; resolve ownership under project policy before a replacement writes.

## Recovery at session boundaries

Before stopping with unfinished work, an impending compaction, or transfer to an
executor without usable context, add the missing recovery details to the existing
record. An ordinary handback with sufficient context needs no separate packet:

- objective and plan versions, accepted outcome, cut line and stopping condition;
- decisions, glossary/design authority, source revisions and unresolved questions;
- tracker IDs/URLs, live-fact ownership and unsynchronized drafts;
- repository, upstream/base, worktree, branch and candidate revision;
- execution owners, delegated packages, pending commands and reserved resources;
- criteria/evidence/review status, missing business or hosted acceptance;
- the next ready action, its prerequisites and any required authorization.

For a background operation intended to cross a session boundary, record its
handle, owner and recovery action at launch, then its terminal result. Capture
those details for any other command still running at handoff. Possible context
loss alone is not a reason for periodic copies of the record.

Lead with current status, blocker, owner and next action; link detailed history.
Update that summary in place rather than appending another full narrative. Preserve
superseded decisions and original evidence in their existing records, with links
when needed to explain the current state. Keep tracker authority unchanged.
Store references rather than duplicating sensitive inputs or complete logs.
Checkpointing does not authorize new repository files or remote writes beyond
the task's scope.

On resume, read this record before rediscovery. Revalidate drift in affected
sources, tracker state, upstream/candidate bytes, accepted decisions, command
results, resources and ownership. Treat unavailable state as unknown.
Replan only the affected scope; preserve settled direction and usable evidence.
Do not replay a pending command until its prior outcome is known or a safe retry
contract applies. Request only the material missing decision or permission.
