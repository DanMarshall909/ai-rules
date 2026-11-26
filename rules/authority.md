# Authority and Scope

Explicit task and project instructions refine these defaults. Skills supply
procedures, never authority. Name unresolved conflicts and pause only affected
actions.

- **Read-only vs. write**: Review, explanation, and diagnosis authorize
  read-only checks only, not edits or publication.
- **Preserve unrelated work**: Never overwrite, hide, or destroy unrelated
  changes. Apply the Git startup gate before new independent work.
- **Deletion authority**: Automatically delete verified task-owned
  disposable run output after workers stop, and compact task evidence at
  closeout (stripping raw coverage exports, build/snapshot copies, and
  test-result trees while keeping compact summaries, logs, and verdicts).
  Never delete retained builds, dependencies, caches, or unknown files
  without reporting measured size and rebuild cost and getting explicit
  direction.
- **Testing proportionality**: Prototypes, spikes, and one-off scripts need
  proportionate smoke/output checks; maintained or reused code keeps full TDD
  and verification gates.
- **Host rejections**: If the host rejects a tool call, recheck authority and
  preconditions before retrying once with evidence; never evade rejection.
- **Delivery gate (Dan's repos)**: Local verification against the exact
  candidate is the gate. Hosted CI is optional—never depend on paid CI,
  manually trigger/rerun jobs, or wait for green CI unless asked (still
  investigate real test failures and respect enforced branch protections).
- **Standing merge rule (Dan's repos)**: Accepted work may be merged once an
  independent high-capability completion review records `PASS` for the exact
  candidate, local checks and branch protections pass, head and base are
  unchanged, and no findings remain—unless told to keep local or review-only.
- **Session handoff**: At fresh root-session startup before substantive repo
  work (not pure Q&A), use `session-handoff` (`ai-handoff latest --project <p>`)
  and replace the canonical handoff at closeout. Delegated agents hand back to
  their parent only.
- **Workflow routing**: Use `agentic-delivery` for accepted non-trivial
  implementation (including handover verification) and `project-orchestration`
  for discovery or multi-slice coordination. An accepted instruction or plan
  authorizes its stated scope without re-confirmation; otherwise propose the
  outcome, first action, and proof first.
