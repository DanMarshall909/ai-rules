---
name: track-external-work-items
description: Inspect and maintain project work in a declared external work-item system such as Azure DevOps, Jira or Linear, using its native schema and evidence-backed updates. Use independently or as the external tracker adapter for project-orchestration.
---

# Track External Work Items

Adapt to the declared work-item system through available tools. Vendor names
are examples, not promises that their connectors or APIs are available.

## Discover the native contract

Confirm the service, tenant/workspace/project, item identity and requested scope
from authoritative context. Discover authenticated tools, permissions, supported
operations and documented schema before constructing queries or mutations.
Do not invent endpoints, field names, workflow transitions or dependency types.

Inspect the project's native item types, status/transition rules, custom fields,
criterion format, relations, assignment conventions and completion policy.
For example, an Azure DevOps work item, Jira issue and Linear issue can have
different identity, hierarchy and revision semantics. Use the actual contract.

Read relevant items, linked requirements, dependencies and evidence. Paginate
the intended scope using the provider's real continuation mechanism.
Record source versions/timestamps, query scope, filters and omissions.
Unavailable connectivity or permission is unknown coverage, never zero items,
passing verification or successful synchronization.

## Preserve declared authority

Use the project's chosen tracker. State one owner for each live fact: priority,
assignment, workflow status, dependency and completion. For hybrid systems,
declare distinct ownership and stable cross-links. Repository material may own
design, investigations or evidence without mirroring external live status.
OpenSpec is not automatically a second workflow tracker.

Keep native item IDs/URLs stable; connect acceptance criterion IDs, dependencies,
decisions and source-bound evidence. Do not silently renumber or migrate items.
Reconcile conflicting sources under their declared precedence before making an
affected update; ask only for material unresolved authority decisions.

## Condition changes on evidence

Map completed claims to observable acceptance and the project's required proof.
Implementation, local tests, review, commit/push, PR, CI, merge, deployment,
hosted verification and business-owner acceptance remain separate facts.
Use native state transitions only when their preconditions and the project's
completion rule are met. A successful API response cannot prove acceptance.

Narrow blocker updates to the affected criterion or dependency and include the
needed decision/input and next action. Avoid guessed assignees or due dates.
A task authorizing work-item maintenance permits routine in-scope updates;
review-only requests remain read-only. Existing update authority does not
authorize outreach, invitations or unrelated notifications.

## Preserve concurrent changes and confirm

Immediately before mutation, reread the native record and relevant relations.
Use supported revision numbers, ETags, compare-and-set or other conditional-write
controls where available. On conflict, reread and reconcile rather than retrying
a stale overwrite. If no control exists, minimize writes and preserve fresh
unrelated fields; stop when a conflicting edit cannot be safely reconciled.

For creation, check for matching existing items. Use documented idempotency
support if available. After an uncertain response, look up the outcome before
retrying to avoid duplicates. Do not assume every vendor supports identical
concurrency, relation or retry features.

Read back changed fields, transitions and relationships. Report confirmed IDs,
links and changes separately from pending/failed actions.
When access is unavailable, keep a clearly labeled unsynchronized proposed
update only in an authorized checkpoint, including target ID, last observed
version and evidence. This is a draft, not external truth or a shadow tracker.
Reconcile fresh remote state when access returns before applying it.
