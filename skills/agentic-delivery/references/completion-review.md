# Independent Completion Review and Publication

Read this reference when a non-trivial feature or product-behaviour change is
candidate-complete. Explicit task and scoped project review contracts refine
these defaults. Publication authority comes from the task and Git workflow;
this procedure supplies the independent review gate.

## Review boundary

Run review after implementation and proportionate verification, before claiming
completion, publishing the completed candidate, synchronizing implemented
baseline specifications, archiving the change or deleting its review evidence.
Local checkpoint commits may precede review: they preserve work without claiming
approval or authorizing a push. Documentation-only maintenance and isolated
experiments making no product-readiness claim are outside this gate unless
project instructions say otherwise.

## Integrate and identify the candidate

Fetch and integrate the intended upstream using the repository's declared policy.
Resolve conflicts and rerun affected checks before freezing the candidate.
Record the branch, full upstream ref/object ID and integration base, plus the
publication remote/ref and its expected current object ID (or expected absence).

Prefer a local checkpoint commit containing every intended source, test and
configuration change, including previously untracked inputs. Record its full
commit and tree IDs. Confirm the tested inputs match that tree and that no
uncommitted in-scope input remains. Preserve unrelated work and exclude it from
the checkpoint; if it affects the checks, isolate it or disclose the evidence gap.
Git records the paths, contents, modes and deletions; a second source manifest is
unnecessary.

If repository policy prevents a checkpoint or the candidate must remain
uncommitted, use one deterministic manifest instead: base/current object IDs,
each in-scope path's change and index/worktree status, canonical mode, digest or
deletion marker, and staged object identity. Include untracked inputs, sort paths
bytewise and hash the manifest. Unresolved merges or unidentifiable inputs are
evidence gaps. Do not stage unrelated work merely to create a snapshot.

Identify relevant outputs outside Git separately, such as the exact packaged
binary when package behaviour is claimed. Reuse existing build receipts and
artifact hashes. Do not create per-agent or per-check source manifests.

## Candidate record

Use an existing task or review record as a short index to:

- accepted scope, tasks and criteria;
- candidate, upstream and integration identities, with access to the full diff;
- commands, tested revision/inputs, working directory, exit status and retained
  output, plus applicable coverage, architecture, security or manual evidence;
- relevant artifacts outside Git, excluded unrelated work and evidence gaps;
- prior findings and their disposition; and
- the proposed post-`PASS` envelope.

Link existing records and raw results once. The ownership, handback and recovery
record may be the same document; each live fact still has one authoritative
owner. Do not duplicate status or logs to satisfy different procedure names.

Post-session mutation may remain pending without blocking review or publication.
Record its intended snapshot and follow up through the mutation workflow; never
present a pending result as passing evidence.

## Reviewer independence

Use a separate high-capability agent. Human review is required only when the
user requests it. Honor the user's selected review model. The agent reviewer:

- starts without implementer conversation history when possible;
- has read-only repository access, the candidate record and project instructions;
- receives no desired verdict or defensive reasoning from the implementer;
- independently verifies candidate/integration identities, the actual changes
  and any relevant external artifact identities; and
- makes its own approval decision without editing or delegating approval.

Retain the reviewer for repairs while its context remains usable. Replace it
for unavailable/confused context, materially different scope or an explicit
request for a fresh opinion. A replacement assesses the whole candidate. If no
independent reviewer can run, report the gate as blocked; never self-approve.

## Required review dimensions

Map tasks and criteria to implementation and tests in one compact mapping or
linked existing records. Group related criteria and describe gaps without
reproducing source or logs. Assess:

1. **Completion.** Every claim is implemented and evidenced, with no premature
   synchronization or silent scope expansion.
2. **Acceptance evidence.** Criteria have executable evidence of their outcomes
   or invariants at the right layer, with genuine RED evidence where required.
3. **Test effectiveness.** Tests protect behaviour, resist incidental refactoring
   and provide maintainable, fast feedback. Coverage scores alone are insufficient.
4. **Architecture and safety.** Actual dependencies, authority, persistence,
   security, failure atomicity and project boundaries are sound.
5. **Alternatives.** Consider materially simpler, safer or cheaper in-scope
   designs; style preferences and speculative extensibility do not justify failure.
6. **Lessons.** Record supported systemic findings in the existing review record
   with evidence, proposed owner/change, downside and disposition.
7. **Publication.** Candidate/integration identity, evidence and the finite
   finalization envelope are reproducible.

## Verdict contract

Return exactly one result:

- `PASS`: no in-scope correction remains; the identified candidate and envelope
  are ready for authorized publication.
- `FAIL`: an actionable in-scope correction is required.
- `BLOCKED`: missing access, evidence or authority prevents a defensible decision.

There is no pass with required changes. Each failure names the file/symbol,
requirement, evidence, consequence and required outcome. A future guidance
proposal alone does not fail an otherwise compliant candidate.

## Repair and renewed review

1. Update the existing record with findings and the next action. Keep the same
   implementation owner for dependent repairs where practical.
2. Correct findings using the applicable specification and testing workflow.
   Rerun affected checks and required combined gates. Reuse sound evidence when
   its dependencies are clear; rerun cheap checks when proving reuse costs more.
3. Identify the new complete candidate and provide its delta from the last
   reviewed candidate, updated evidence and findings dispositions.
4. The retained reviewer examines the delta and affected interactions, carrying
   forward verified conclusions about unchanged areas. It renews the verdict
   for the whole current candidate. Reassess more broadly when the delta affects
   wider requirements or earlier conclusions cannot be trusted.

Upstream integration follows this same process. A changed base needs a renewed
verdict, but does not by itself require rereading every unchanged file. There is
no arbitrary review-round limit. Recover context from the existing record when
needed; create no extra repair capsule when that record already suffices.

## Finite post-PASS envelope

The envelope contains only deterministic operations justified by the candidate:
exact status/evidence updates, specification synchronization/archive mappings,
named validation commands, commits and normal pushes, and bounded cleanup of
known task-owned targets. Unknown cleanup state requires inspection.

Every content transformation needs exact paths and an expected patch or resulting
mode/content hash. Semantic source, test, generated-data and requirement changes
are never administrative. After `PASS`:

1. Verify source still matches the reviewed commit/tree or fallback manifest,
   and relevant external artifacts remain unchanged.
2. Apply only the approved envelope and run its named validations.
3. Commit remaining approved changes with normal hooks. If the checkpoint
   already contains the complete result, no extra commit is needed.
4. After hooks, compare the final committed tree and current in-scope inputs
   with the candidate plus approved transformations. Reject unexpected changes
   and require validation evidence that qualifies those final inputs.
5. Fetch without integrating; require the recorded upstream object and verify
   the destination ref still satisfies the recorded publication conditions.
6. Push normally, verify the remote outcome, then perform the bounded cleanup.

Candidate drift outside the envelope, failed validation or upstream movement
suspends publication. Resolve the change and obtain a renewed verdict through
the repair process. A transport failure or push rejection alone does not erase
review: inspect the outcome and local/remote identities, then retry only if the
candidate, upstream and destination ref still satisfy the approved conditions.
A changed destination ref must be reconciled; never force-push under this gate.
