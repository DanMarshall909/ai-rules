# AI Rules

Lean, agent-agnostic rules for any coding assistant.

<!-- Agents that support @ imports will load the modular rule files below.
     Agents that don't will read the inlined fallback content beneath. -->

@rules/breaks.md
@rules/tdd.md
@rules/coverage.md
@rules/git.md
@rules/issues.md
@rules/reflection.md

---

## Fallback — full rules inlined

> The section below is for agents that do not support `@` file imports.
> If your agent resolved the `@` imports above, you can ignore this section.

---

### Break Reminders

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

### TDD Protocol

**Tidy → Red → Green → Refactor → Coverage**

- Never write production code before a failing test exists
- Work one acceptance criterion at a time — no batching
- Commit at each phase: `test(red)`, `feat(...)`, `refactor(...)`
- After implementation: check coverage, run mutation testing if available
- End of session: offer to squash TDD commits into one

> Claude Code users: use the `/tdd` skill.

---

### Coverage & Dead Code

Aim for 100% coverage of core code through behaviour-driven tests that drive real
code paths and assert observable output.

**Code must justify itself.** Code that cannot be justified is removed, not
covered; code that exists only to be exercised by its own tests is not justified
by those tests. Before deleting dead code, decide whether it is useful
functionality that should be *wired up* instead — never delete useful code to
raise a coverage number.

**Read the gap before you close it.** An uncovered line means that behaviour has
never once executed. If one half of a pair is covered and the other is not, the
untested half is load-bearing code nobody has run. Assert the behaviour the gap
reveals, not the line. Assert what you believe and let a failure correct the
belief — never weaken an assertion to match observed output without
understanding why it differs.

**Never call a branch unreachable.** An unreachable branch means the type does
not carry what you already know. Before writing "unreachable" or "defensive" in a
comment, work this list in order:

1. **Carry the value forward** — an earlier step proved the lookup succeeds, then
   threw the result away.
2. **Remove the impossible variant** — an `Option`/`Result` no path returns is a
   lie; change the return type.
3. **Make a silent skip a loud failure** — a lookup that quietly does nothing on
   a miss emits a *wrong answer* if the invariant breaks. `.expect("why this
   holds")` fails loudly and costs no coverage.
4. **Re-derive reachability from the public API** — you are usually wrong.

Only when all four fail is code genuinely uncoverable. Keep it, exclude it, state
the reason inline. Exclusion is a last resort, not a permission.

---

### Git Workflow

- `git pull --rebase` before every push
- Before force-push: create `backup/<branch>-<timestamp>` first
- Never commit without reviewing the staged diff first
- Commit messages: present tense, imperative, explain *why* not *what*
- Never skip hooks (`--no-verify`) unless explicitly asked

---

### Issue & Finding Tracking

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

### Reflection

When finished with a piece of work — tests green, commit landed — capture any
durable lesson before the context is lost. Writing nothing is the common, correct
outcome; most tasks teach nothing worth keeping.

A lesson is worth keeping only if it is **transferable** (about judgment, not
about this file), **non-obvious** (not what you'd have done anyway), and
**load-bearing** (knowing it at the start would have changed what you did).
Lessons hide in user corrections — especially corrections phrased as a question,
which mean you had already talked yourself into something — and in any moment you
defended code rather than fixing it.

Route each lesson to the scope it pertains to: a rule you must *obey* goes in a
rules file, a lesson you should *recall* goes in memory or a skill; a rule that
binds everywhere goes global, one that binds one codebase stays local. Do not
leave a globally useful lesson in a project's memory just because that is where
you learned it. If an existing rule is what let you go wrong, amend that rule
rather than adding a contradictory one beside it.

> Claude Code users: use the `/reflect` skill.
