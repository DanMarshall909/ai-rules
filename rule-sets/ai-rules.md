# AI Rules

Lean, agent-agnostic rules for any coding assistant.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: rule-sets/ai-rules.set and the rules/ files it lists
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->

---

## Authority and Scope

Explicit task and project instructions refine these defaults. Skills supply
procedures, never authority. Name unresolved conflicts and pause only affected
actions.

- **Read-only vs. write**: Review, explanation, and diagnosis authorize
  read-only checks only, not edits or publication.
- **Preserve unrelated work**: Never overwrite, hide, or destroy unrelated
  changes. Apply the Git startup gate before new independent work.
- **Deletion authority**: Automatically delete only verified task-owned
  disposable run output after workers stop. Never delete retained builds,
  dependencies, caches, or unknown files without reporting measured size and
  rebuild cost and getting explicit direction.
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

---

## Rules and Skills Sync

Before the first substantive repository task in a session (when online), run
the installed `upgrade-global-skills` preflight. It is silent when clean and
synced; surface any advisory without mutating the checkout.

---

## Break Reminders

Use the `break-reminders` skill only when the user requests a paced session or
scheduled reminders (suggested cadence: 30m break, 2h goal check). Ordinary
coding does not authorize scheduling; report unsupported host scheduling
honestly.

---

## Agentic TDD Protocol

For maintained behavior changes, use the `behavior-first-tdd` skill:
**Tidy → RED → GREEN → COVERAGE → REFACTOR**, one observable criterion at a
time.

- Choose the smallest test scope that proves the criterion: unit tests for
  single-system behavior, integration tests only for a named cross-system
  interface failure, E2E only when full-path behavior is what's being proved.
- Never mock away the rule under test or trade business clarity for speed.
- Keep fast and slow lanes explicit; calibrate boundary stand-ins against real
  contract tests. Never break shared trunk.

---

## Coverage & Dead Code

Use the `coverage-and-mutation` skill for coverage, mutation, compatibility, or
dead-code decisions.

- Aim for 100% coverage of core code via externally observable behavior.
- Coverage proves execution, not assertion; remove unjustified code rather than
  covering it.
- Establish coverage before mutation. Run mutation post-session on the final
  snapshot (one active job per repo; never block tickets). Exclude E2E and
  slow-lane tests, use isolated CoW sandboxes, and clean up owned disposable
  output after completion or cancellation.

---

## Guardrails

When a harmful mistake can recur unnoticed, prefer a build-time or local test
check covering the whole convention over pinning one instance. Build it if in
scope; otherwise propose it.

- Name unavailable checks explicitly as skips or blockers, never clean passes.
- Wire checks into normal local verification.
- Verify every guardrail by injecting a fault and asserting the diagnostic
  names the broken rule—not merely a nonzero exit.

---

## Security by Design

For encryption, signing, token handling, secrets, sensitive domain types, or a
security review, use the `security-by-design` skill.

- Concentrate security decisions behind one narrow, intent-named boundary.
- Expose permitted outcomes, not configurable cryptographic primitives.
- Give sensitive values validated immutable types and minimize plaintext
  lifetime.
- Use established cryptography, reject insecure input, and release no partial
  plaintext after authentication failure.

---

## Git Workflow

- **Sync first**: Before changes, fetch and fast-forward-pull the tracked
  branch. If dirty, detached, diverged, offline, or unable to fast-forward,
  preserve state and report—never stash, reset, rebase, or force to pass.
- **Unfinished work gate**: Before new independent work or a new worktree,
  inventory local branches, worktrees, and active feature branches after
  fetching. Unintegrated work blocks new independent work unless explicitly
  parked or designated as a spike in this session or the tracker.
- **Cleanup & storage**: Use `worktree-cleanup-audit` for merged-worktree
  cleanup (never force-remove). Maintain `.ai-rules.json` with `storage-budget`
  and check headroom before heavy builds/restores/tests; insufficient headroom
  blocks only that operation.
- **Integration & push**: Integrate upstream preserving merge history before
  final verification and completion review. Push authorized verified commits
  promptly; if completion review applies, require `PASS` on the exact unchanged
  head and upstream before pushing.
- **History & commits**: Force-push requires explicit authority and a
  `backup/<branch>-<timestamp>` first. Review staged diffs, write imperative
  "why" commit messages, and never skip hooks unless asked. Keep trunk
  releasable with short-lived branches.

---

## Issue & Finding Tracking

Follow the repository's declared tracker (GitHub Issues/Projects, repo
Markdown, external tracker, or hybrid) with one authority per live fact. Use
`track-github-work`, `track-repository-work`, or `track-external-work-items`
for mechanics and fallback layouts.

- Preserve declared schemas and never introduce a shadow tracker.
- Report unavailable tracker access honestly; label unsynchronized drafts.
- Close work only under the project's completion rule with recorded evidence.

---

## Reflection

Use the `reflect` skill quietly during work (on corrections, surprises,
fallbacks, or completed slices) and aggregate material findings at handoff.
Keep lessons at their narrowest owner; change memory or standing guidance only
with explicit owner approval.
