---
name: track-github-work
description: Inspect and maintain project work in GitHub Issues and optional GitHub Projects using evidence-backed, concurrency-safe updates. Use independently or as the GitHub tracker adapter for project-orchestration.
---

# Track GitHub Work

Use the declared GitHub repository and its actual conventions. This skill owns
tracking mechanics, not implementation, publication or stakeholder outreach.

## Discover authority and capability

Read project instructions and the requested scope. Confirm repository identity,
issue/Project authority, completion rules and existing update authorization.
Do not infer a repository from a similarly named search result.

Discover available authenticated tools and their read/write permissions.
Inspect issue templates, labels, milestones, assignments, dependency conventions,
Project membership and native fields/status options where used.
GitHub Projects is optional; do not introduce it because Issues are present.
Discover supported APIs and concurrency controls rather than inventing fields.

Fetch the relevant issue and linked criteria, dependencies and evidence.
Paginate complete intended collections, including Project items or fields when
needed. Record query scope, source revision/timestamp and incomplete coverage.
Unavailable access is not proof of no items, passing checks or completed work.

## Keep one authority per live fact

Follow the declared tracker. For hybrids, state which system owns priority,
assignment, workflow status and completion, and which holds design/evidence.
Link durable repository material by stable issue URL/number and criterion IDs.
Do not mirror live status into another independently maintained checklist.
OpenSpec can hold design and acceptance detail without becoming a competing
workflow tracker. Preserve the project's existing division of responsibility.

## Reconcile evidence to work

Use stable issue identities and existing criterion IDs; introduce criterion IDs
only within authorized changes when absent. Keep dependency and source/evidence
links durable. Distinguish accepted requirement, implementation, validation and
remaining business/hosted acceptance.

Map each claimed outcome to source-bound evidence. Existing code and a green
unrelated workflow do not close a criterion. Record a blocker narrowly, naming
its affected dependency; avoid marking the whole project blocked by default.

A PR link, commit, merged state, CI pass, deployment and owner acceptance are
different facts. Close an issue only when the project's completion rule is met.
Update optional Project status consistently with its declared native workflow;
do not assume a field value such as "Done" exists.

## Mutate narrowly and verify

An authorized task to maintain these records permits its routine in-scope
updates; do not ask again at each edit. Review-only requests remain read-only.
Sending messages or unrelated mentions/outreach needs separate authority.

Immediately before writing, reread the current issue/Project record. Preserve
concurrent body edits, labels, assignees and fields outside the intended change.
Use supported conditional writes/version controls when available. If unsupported,
minimize the patch, compare fresh state, and stop conflicting changes for
reconciliation rather than replacing the entire record from a stale copy.

Apply only evidence-supported field/body/comment changes. Avoid duplicate
progress comments; update the established record when appropriate. For creation,
check for an existing matching item and use a supported retry/idempotency
mechanism when available; uncertain outcomes require lookup before retry.

Read back the affected record and relationships after writing. Report exact
item links, confirmed changes, evidence and any unverified outcome.
If access fails, retain a clearly labeled unsynchronized proposed update in an
authorized checkpoint, with target ID and last observed version. It is a draft,
not remote truth or a new live tracker. Reconcile on restored access before
applying; never report a drafted, timed-out or rejected update as saved.
