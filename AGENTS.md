# AI Rules

Lean, agent-agnostic rules for any coding assistant.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: rules/*.md
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->

---

## Break Reminders

Remind the user to take a short break every 30 minutes during working hours (9am–5pm).

Every 2 hours, pause and run this check-in:

1. Ask: *"How is the session tracking against the goal?"*
   - On track
   - Slightly off — recoverable
   - Need to pivot

2. Ask: *"What's the focus after the break?"*
   - Continue current work
   - Start a new task
   - Review open issues
   - End session

3. Before the check-in, briefly scan all project memory/context files to surface anything relevant from other active work.

> Claude Code users: run `/break-reminders` at session start to automate this.

---

## TDD Protocol

**Tidy → Red → Green → Refactor → Coverage**

- Never write production code before a failing test exists
- Work one acceptance criterion at a time — no batching
- Commit at each phase: `test(red)`, `feat(...)`, `refactor(...)`
- After implementation: check coverage, run mutation testing if available
- End of session: offer to squash TDD commits into one

> Claude Code users: use the `/tdd` skill.

---

## Coverage & Dead Code

Aim for 100% coverage of core code through behaviour-driven tests that drive real
code paths and assert observable output.

### Code must justify itself

- Code that cannot be justified is removed, not covered. Code that exists only to
  be exercised by its own tests — no production callers — is not justified by
  those tests.
- Before deleting dead or unreferenced code, decide whether it is useful
  functionality that should be *wired up* rather than deleted (e.g. a correct
  primitive with no caller yet). Assess its value and propose wiring it up. Only
  delete genuine leftovers and duplicates. Never delete useful code to raise a
  coverage number.

### Compatibility code needs a real past

Migrations, upcasters, versioned shapes, deprecation shims, and fallback paths
are justified by something that *actually exists* depending on the old shape: a
released version, data already written, a caller you do not control. Absent
that, there is no old shape — only the current one, arrived at by editing.

Before writing any of it, establish what depends on the old shape. If nothing
does, change the shape in place and delete the old one.

Pre-release is the common case: nothing is deployed, no data was ever written,
so every schema is version 1 no matter how many times it changed on the way
here. Ask whether the project has shipped; do not assume it has because the code
looks mature.

This one is hard to catch from the inside, because writing the upcaster *feels*
like diligence rather than waste. The tell is noticing "nothing depends on this
yet" and building it anyway — if you can say the cost is currently zero, you
have already proved the code is currently pointless.

### Read the gap before you close it

An uncovered line means **that behaviour has never once executed**. It is a
statement about the code, not about the tests.

- If one half of a pair is covered and the other is not, the untested half is
  load-bearing code nobody has ever run. Symmetry gaps are the richest.
- Assert the behaviour the gap reveals, not the line.
- Assert what you believe, then let a failure correct the belief. Never weaken an
  assertion to match observed output without first understanding why it differs.

### Never call a branch unreachable

An unreachable branch means the type does not carry what you already know. Before
you write "unreachable", "defensive", or "justified but uncoverable" in a
comment, work this list in order:

1. **Carry the value forward.** An earlier step proved the lookup succeeds, then
   threw the result away. Keep it instead of looking it up twice.
2. **Remove the impossible variant.** An `Option`/`Result` that no path returns
   is a lie. Change the return type.
3. **Make a silent skip a loud failure.** A lookup that quietly does nothing when
   it misses will emit a *wrong answer* if the invariant ever breaks.
   `.expect("why this holds")` is strictly better: it fails loudly, and costs no
   coverage because the panic lives in the standard library.
4. **Re-derive reachability from the public API.** You are usually wrong.
   Boundary lookups, `?`-paths on public methods, and "obviously valid" inputs
   are typically reachable and merely untested.

Only when all four fail is code genuinely uncoverable. Then keep it, exclude it
from the coverage target, and state the reason inline. Exclusion is a last
resort, not a permission.

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

**Judgment is not mechanizable.** A rule about *when* code is worth writing at
all — speculative generality, wrong abstraction, premature migration paths —
cannot be a test. Don't propose one; route that lesson to a rules file instead
(see [[reflection]]).

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

All issues and security findings are documented as markdown files.

**Folder structure:**
```
docs/issues/
  open/[area]/[ticket-id]-[slug].md
  resolved/[area]/[ticket-id]-[slug].md
```

- `area` = business domain (api, auth, payments, pii, booking, database, …)
- Discover existing areas from the folder structure — don't hardcode them
- On resolution: update `status: Resolved`, add decision log entry, move to `resolved/[area]/`

> Claude Code users: use `/issue` and `/security-finding` skills.

---

## Reflection

When finished with a piece of work — tests green, commit landed — capture any
durable lesson before the context is lost. Writing nothing is the common,
correct outcome; most tasks teach nothing worth keeping.

A lesson is worth keeping only if it is **transferable** (about judgment, not
about this file), **non-obvious** (not what you'd have done anyway), and
**load-bearing** (knowing it at the start would have changed what you did).

Lessons hide in user corrections — especially corrections phrased as a question,
which mean you had already talked yourself into something — and in any moment you
defended code rather than fixing it.

Route each lesson to the scope it pertains to:

| | Any project | This repo only |
|---|---|---|
| **Must obey** | global rules file | repo `AGENTS.md` / `CLAUDE.md` |
| **Should recall** | global skill | project memory |

Do not leave a globally useful lesson in a project's memory just because that is
where you learned it. If an existing rule is what let you go wrong, amend that
rule rather than adding a contradictory one beside it.

> Claude Code users: use the `/reflect` skill.
