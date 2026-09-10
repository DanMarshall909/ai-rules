# AI Rules

Lean, agent-agnostic rules for any coding assistant.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: rule-sets/ai-rules.set and the rules/ files it lists
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->

---

## Break Reminders

During working hours (9am–5pm), remind the user to take a short break every 30
minutes. Every 2 hours, pause for a goal-and-focus check-in after briefly
scanning relevant project context.

Use the `break-reminders` skill when the user wants a working session paced or
scheduled reminders created.

---

## TDD Protocol

**Tidy → Red → Green → Refactor → Coverage**

- Never write production code before a failing test exists
- Work one acceptance criterion at a time — no batching
- Commit at each phase: `test(red)`, `feat(...)`, `refactor(...)`
- After implementation: check coverage, run mutation testing if available
- End of session: offer to squash the *green* commits into one. Never fold a
  `test(red)` commit into the `feat` that makes it pass: the failing test
  standing alone is the evidence that the test can fail, and squashing it away
  destroys exactly that. A red commit that does not compile is expected. It is
  not a broken trunk, and git.md's "trunk stays green" does not override this.

For any behavior change, use the `behavior-first-tdd` skill (Claude command:
`/behavior-first-tdd`).

---

## Coverage & Dead Code

When reviewing coverage, mutation results, compatibility paths, or dead code,
use the `coverage-and-mutation` skill.

- Aim for 100% coverage of core code through externally observable behavior.
- An uncovered line has never executed; a covered line has not necessarily been
  checked by an assertion.
- Remove code that has no useful caller or contract instead of covering it for
  its own sake.
- Establish coverage before mutation testing, and calibrate the mutation harness
  with a fault you have watched the relevant test reject.

---

## Guardrails

When a mistake is **repeatable** and **bad**, and a test could mechanically
prevent it, flag that test. Say what it would assert and what it would have
caught. Don't silently fix the instance and move on — the instance is one
sample of a class.

Repeatable means it can recur without anyone noticing: a convention that only
holds while people remember it, a layering rule enforced by habit, a constant
duplicated by hand, a shape every implementation must share. A one-off typo the
compiler already rejects is not repeatable.

Prefer the guardrail that fails at build time over the one that relies on
review. An architecture/convention test that sweeps *every* type is worth more
than a unit test pinning the one type that happened to break today — write the
test against the rule, not against the instance.

Flag it and let the user decide whether to build it now. Not every guardrail
earns its cost; that call is theirs.

### A guardrail must be able to fail

A guardrail earns trust by being ignored, so how it behaves when it stops
working matters more than how it behaves when it passes. Three ways one holds
nothing while still reporting success:

- **It cannot run, and does not say so.** A check reading state it might not
  have — an index, a lock file, a service — must announce the skip by name.
  Degrading to a clean result is the worst option available: the output becomes
  indistinguishable from the check having passed.
- **Nothing invokes it.** A suite missing from the pipeline still passes
  locally and is still counted on. Wiring it up is part of building it, not a
  follow-up.
- **Its own test asserts only the exit code.** Any failure then stands in for
  any other, so a guardrail that has begun reporting the *wrong* problem — or
  choking on its input before it reaches the check at all — still looks
  correct. Break one rule at a time and assert the message naming that rule.

The test to write for a guardrail is not "does it pass on good input" but "does
it fail on bad input, for the stated reason" (see [[coverage]]).

**Judgment is not mechanizable.** A rule about *when* code is worth writing at
all — speculative generality, wrong abstraction, premature migration paths —
cannot be a test. Don't propose one; route that lesson to a rules file instead
(see [[reflection]]).

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

- `git pull --rebase` before every push — **except when pushing a merge commit**:
  plain `--rebase` silently discards merges, replaying their commits and throwing
  the merge (and its message) away. The push still succeeds, so the loss is
  invisible unless you look. Integrate *before* merging, or use
  `git pull --rebase=merges`, and verify with `git log --graph` before pushing
- Before force-push: create `backup/<branch>-<timestamp>` first
- Never commit without reviewing the staged diff first
- Commit messages: present tense, imperative, explain *why* not *what*
- Never skip hooks (`--no-verify`) unless explicitly asked

### Trunk-Based Development

Trunk is the single source of truth, and it is always releasable. Work merges
back within roughly a day — a branch that outlives that is the problem, not the
merge that follows it.

- Branch from trunk, keep it short-lived, merge back as soon as it is green
- Merge small vertical increments — a coherent, green, releasable slice beats a
  finished feature that sat unmerged for a week
- Never let a branch accumulate work that could have landed already; long-lived
  branches turn into merge risk and hide work from everyone else
- Unfinished-but-safe belongs on trunk behind a flag or simply unwired, in
  preference to a branch nobody can see
- Trunk stays green: if a merge breaks it, fixing trunk outranks whatever came
  next

Merging an increment does not mean the task is done. When a slice lands with
work still outstanding, say what is still missing rather than letting the merge
imply completion.

---

## Issue & Finding Tracking

Projects may track work in GitHub Issues and Projects, in repository markdown,
or in both. Follow the repository's declared tracker; do not introduce a second
authority merely to mirror status.

When both are used, give them distinct jobs:

- GitHub owns live priority, assignment, and workflow status.
- Repository files hold durable investigation, evidence, decisions, or security
  findings that benefit from review and version history.
- Link the two records. Do not duplicate an issue body or maintain competing
  status fields in both places.

All file-backed issues and findings use this canonical folder structure:

```
docs/issues/
  open/[area]/[ticket-id]-[slug].md
  resolved/[area]/[ticket-id]-[slug].md
```

- `area` = business domain (api, auth, payments, pii, booking, database, …)
- Discover existing areas from the folder structure — don't hardcode them
- If a file is linked to a GitHub issue, include the issue URL and use one stable
  ticket identity in both records.
- On resolution of a file-backed record: update `status: Resolved`, add a
  decision-log entry, and move it to `resolved/[area]/`.
- On resolution of a GitHub-tracked item: follow the project's completion rules
  and update any linked durable file in the same change.

If the repository declares neither approach, use `docs/issues/` rather than
inventing another local folder.

> Claude Code users: use `/issue` and `/security-finding` skills.

---

## Reflection

After non-trivial work lands with tests green and its commit recorded,
use the `reflect` skill to capture any durable lesson before context is lost.
Writing nothing is the common, correct outcome.

Keep only transferable, non-obvious, load-bearing lessons, and store each at
the narrowest scope that reaches every task where it applies.
