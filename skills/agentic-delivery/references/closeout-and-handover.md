# Closeout and owner handover

Read before retaining or cleaning delivery resources and preparing the final
owner handover. Use existing records rather than another retention ledger.

Use `storage-budget` before heavy output-producing operations. Check output and
temporary volumes, accounting for known competing jobs, against the declared
workload estimate and reserve; pause only a producer that cannot fit. For
managed disposable output, retain a compact receipt outside the run directory
and verify cleanup after success, failure or cancellation once workers stop.
Cleanup failure is a separate reported outcome, even when the command passed.

At handoff, inspect task-owned worktrees, processes and retained output. Keep
source preservation and generated-output retention separate: a preserved branch
does not require keeping every build or report copy. Review reusable builds,
dependencies, caches and evidence against their retention budget with measured
size, purpose and rebuild cost. Get explicit direction before deleting reusable
state. Retain active, unrelated, unmerged, unpushed or uncertain work; report its
next disposition without inventing permission to remove it. Use the existing
task record and storage receipt rather than a second retention ledger.

Consolidate the observations gathered through `reflect` when control returns to
the user. Keep material findings and proposed guidance changes in the completion
report, after the outcome and evidence. Do not create a separate interruption or
expand the task to implement a new lesson. Changes to standing guidance still
need owner agreement unless already requested.

## Completion report

Lead with a handover the owner can reason about:

- what now works for the user, tied to the agreed goal;
- the few behavioural or architectural changes that matter and why;
- a concrete demonstration or example connecting input, system decision, result
  and persistence/replay where relevant, with evidence for the claimed revision;
- what remains uncertain, broken or outside the demonstrated scope; and
- the next bounded action and the last working state available for recovery.

Keep the engineering detail accessible through existing records: release/product
criterion, tasks and acceptance criteria satisfied, tests/coverage/mutation/manual
evidence, independent verdict and candidate identity, commit/publication state,
cleanup and retained ambiguity, material findings and guidance dispositions.
Test totals and agent agreement alone do not explain the delivered behaviour.
Once the accepted outcome, required verification, review and authorized delivery
conditions are satisfied, report the result and stop. Reopen work for a concrete
correction, invalidated evidence or an unmet requirement. Do not start another
goal merely because the next dependency is ready.

### Confirm the owner's handover

After presenting the outcome, use a brief conversational check about a concrete
consequence, boundary or decision to establish whether the owner understands the
change. Avoid a generic "does that make sense?", a formal quiz or a demand to
review implementation detail. Invite correction and questions. When a reply
reveals a gap, explain or demonstrate that part and check again proportionately.

Distinguish technical delivery complete from owner handover confirmed. If there
is no reply, record understanding as unconfirmed in the existing handover; do
not invent acceptance or reopen completed engineering gates. Preserve the agreed
goal and ordinary autonomy. An unanswered handover does not keep technical work
active or require another status commit. A comprehension gap calls for
explanation, not more features, tests or unsolicited work.

## Notes

- Documentation-only maintenance and experiments making no readiness claim do
  not automatically need the independent feature review. Apply proportionate
  checks and the project's stricter rules.
- Exact tools are adapters. OpenSpec, Jira, GitHub, xUnit, pytest, Stryker, and
  particular agent models are not requirements of this workflow.
- Autonomy does not expand authority. Finishing, babysitting, or “do not stop”
  changes persistence, not permission.
