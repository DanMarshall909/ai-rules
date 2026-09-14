# Independent Completion Review and Publication

Read this reference when a non-trivial feature or product-behaviour change is
candidate-complete. Explicit task and scoped project review contracts refine these
defaults within the host's instruction hierarchy. Name any unresolved conflict
before the affected action; this procedure does not grant publication authority.

## Review boundary

Run review after implementation and proportionate verification, but before:

- declaring the feature complete;
- making the final completion commit or push;
- synchronizing proposed behaviour into implemented baseline specifications;
- archiving the owning change; or
- deleting the evidence needed to assess it.

Documentation-only maintenance and isolated experiments making no product-
readiness claim are outside this gate unless project instructions say otherwise.

## Integrate before freezing

Approval must cover the upstream state publication will extend. Immediately
before freezing the packet:

1. Record the current branch, full upstream ref, upstream object ID, and merge or
   integration base.
2. Pull/rebase or otherwise integrate using the repository's declared policy.
3. Resolve conflicts and rerun every affected check.
4. Freeze every in-scope path and build the candidate packet and manifest.

Do not pull, rebase, or merge after `PASS`. Publication uses an unchanged-
upstream fetch check instead.

## Candidate packet

Provide raw, falsifiable evidence rather than an argument for approval:

- feature identity and accepted scope;
- tasks, requirements, criteria, and status claims;
- base/current/upstream/integration object identities;
- complete changed-path content, including untracked in-scope files;
- test commands and results with revision, working directory, exit status, and
  retained output;
- coverage, mutation, architecture, security, generated-data, performance, and
  manual evidence that applies;
- explicit unrelated paths excluded from review;
- evidence gaps and unresolved decisions;
- prior findings and an accumulated lesson ledger on repair rounds; and
- the proposed post-`PASS` envelope.

The manifest must deterministically identify the candidate. At minimum, record
the base and current object IDs and, in bytewise path order, each path's change
and index/worktree status, canonical mode, content digest or deletion marker,
and staged object identity. Hash the serialized manifest itself. Treat unmerged
indexes, special files, or content that cannot be represented as evidence gaps.

## Reviewer independence

Use a separate high-capability agent or human reviewer. For an agent reviewer:

- start it without the implementer's conversational history when possible;
- give it read-only repository access;
- supply the packet and authoritative project instructions;
- do not supply the implementer's desired verdict or defensive reasoning;
- require independent reconstruction of the manifest and integration identity;
  and
- prohibit repository edits and delegated approval decisions.

Retain the same reviewer for repairs to the same bounded feature when its
context remains healthy. Replace it for another feature, materially changed
scope or integration context, unavailable or confused context, or an explicit
request for a fresh opinion. A replacement reassesses the whole candidate.

If no genuinely independent reviewer can run, report the gate as blocked. Do
not label self-review as independent review.

## Required review dimensions

The reviewer creates explicit task-to-implementation and criterion-to-test
matrices, then assesses:

1. **Task and specification completion.** Every claim is implemented, evidenced,
   neither premature nor silently broadened, and synchronized only after it is
   earned.
2. **Acceptance evidence.** Every criterion has executable evidence asserting
   its outcome or invariant at the appropriate layer, with genuine RED evidence
   where the workflow requires it.
3. **Test effectiveness.** Tests protect meaningful behaviour and satisfy
   regression protection, resistance to refactoring, fast feedback, and
   maintainability. Coverage and mutation scores do not substitute for this.
4. **Architecture and operational safety.** Dependency direction, authority,
   persistence, security, failure atomicity, and project-specific boundaries
   hold in the actual implementation, not only in architecture tests.
5. **Better alternatives.** A materially simpler, safer, clearer, more
   deterministic, or cheaper in-scope design is considered. Style preferences
   and speculative extensibility do not justify failure.
6. **Reusable lessons.** Systemic findings are recorded as candidates with
   evidence, a proposed owner, guidance change, downside, and disposition.
7. **Publication soundness.** The integration identity, manifest, evidence, and
   finite finalization/cleanup envelope are reproducible.

## Verdict contract

Return exactly one result:

- `PASS`: no in-scope correction remains and the exact candidate plus envelope
  is ready for publication;
- `FAIL`: at least one actionable in-scope correction is required; or
- `BLOCKED`: missing access, evidence, or authority prevents a defensible
  decision.

There is no “pass with required changes.” Each failing finding names the file or
symbol, requirement or task, evidence, consequence, and required outcome.

## Repair loop

After `FAIL` or `BLOCKED`:

1. Persist the packet, manifest, verdict, findings, lesson ledger, and a concise
   repair capsule outside conversational memory.
2. Preserve unrelated paths and maintain one writer for the candidate.
3. Correct findings through the ordinary specification, TDD, coverage,
   refactoring, and mutation workflow.
4. Rerun proportionate verification and rebuild the complete packet and
   fingerprint.
5. Return the whole candidate to the retained reviewer, not merely the patch for
   the last finding.

Compact or replace implementation context only when context length, noise, or
anchoring threatens reasoning. Reread the persisted repair bundle afterward.
There is no arbitrary review-round limit.

## Finite post-PASS envelope

The proposed envelope may contain only deterministic operations already
justified by the candidate:

- exact task, evidence, or one status update;
- exact specification synchronization and archive mappings;
- named validation commands;
- staging and committing the reviewed content;
- remote ref updates caused by fetch and a normal non-force push; and
- a bounded cleanup plan naming known task-owned targets and requiring
  inspection rather than deletion for unknown state.

Every content change needs exact paths and either an expected patch or resulting
mode and content hash. Semantic source, test, generated-data, or requirement
changes are never administrative.

After `PASS`:

1. Recompute and match the reviewed manifest.
2. Apply only the approved envelope.
3. Run every named validation and reject unexpected generated content.
4. Compare the complete final tree with the reviewed candidate plus approved
   transformations.
5. Commit with normal hooks.
6. Fetch without merging or rebasing and require the recorded upstream object.
7. Push normally, then execute only the bounded cleanup.

Any content drift, failed validation, upstream movement, push rejection, or
post-review integration invalidates `PASS`. Rebuild and review the new candidate
instead of stretching the old approval.
