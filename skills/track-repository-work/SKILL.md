---
name: track-repository-work
description: Inspect and maintain authoritative repository Markdown work items or linked investigation records while preserving declared schemas and live-fact ownership. Use independently or as the repository tracker adapter for project-orchestration.
---

# Track Repository Work

Follow the repository's declared file locations, schema, identities and workflow.
This skill does not require migration to a new layout.

## Discover the contract

Read project instructions, existing records, indexes and completion rules.
Confirm whether Markdown owns live workflow state or only durable evidence
linked to another tracker. Preserve the declared schema, status vocabulary,
dependency notation and decision-log conventions.

If no tracker or repository convention is declared, use this fallback:

```text
docs/issues/
  open/[area]/[ID]-[slug].md
  resolved/[area]/[ID]-[slug].md
```

Discover areas from existing domain organization; allocate stable IDs according
to project practice and check for collisions. If no allocator exists, choose
an unambiguous stable identity and document it. Do not force existing records
into this fallback, or create a shadow tracker during a remote outage.

Inspect available filesystem/Git capabilities and permissions. Read the complete
relevant item set or state the search scope and omissions. Unreadable paths or
missing access do not prove that no items exist. Identify the worktree and source
revision, including digests for relevant uncommitted records.

## Assign authority and reconcile

Maintain one authority per live fact. If Markdown owns workflow status, keep
its status, dependencies and completion evidence here. If GitHub or another
system owns that status, link its stable item URL/ID and keep Markdown focused on
investigation, decisions and evidence. Do not maintain competing status fields.
OpenSpec remains a design/evidence source unless explicitly declared otherwise.

Connect stable item and criterion IDs, dependencies and source/evidence refs.
Distinguish accepted outcomes, implementation and proof. Update only what the
evidence supports; code existence, local tests, CI, merge, hosted checks and
business acceptance are separate states. Close only under the project's
completion rule, leaving unproved criteria visible.

For the fallback layout when files are authoritative, resolution sets
`status: Resolved`, adds the evidence-backed decision-log entry and moves the
record to its matching `resolved/[area]/` path. When files are linked evidence,
open/resolved denotes investigation archival only; link to live workflow state
and record the archive decision. Follow declared repository conventions first.

## Write safely

A task authorizing tracker updates covers routine in-scope edits. Review-only
work authorizes no writes; outreach is separate. Follow repository worktree and
publication policy; saving a file does not imply committing or pushing it.

Inspect target status and reread the record immediately before editing. Compare
the current revision/digest with the one used for the proposed update.
Preserve concurrent/unrelated content; use a narrow patch and reconcile conflicts.
Respect existing file locks or conditional-write mechanisms where available.

For moves, verify source/destination and identity, preserve history using the
repository's supported workflow, and update affected links/indexes within scope.
Do not overwrite another item or mass-reformat neighbouring records.
Keep sensitive source data out of tracking evidence.

Read back changed files, links and index references; inspect the diff and report
the confirmed saved state, revision/digest and remaining publication steps.
If a write fails or scope is read-only, retain only an authorized draft checkpoint
labeled unsynchronized, with its intended path and observed source version.
A draft is not saved canonical state. Reconcile it against fresh files before
retrying; never claim inaccessible or uncommitted records are remotely published.
