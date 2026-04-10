# AI Rules

Lean, agent-agnostic rules for any coding assistant.

<!-- Agents that support @ imports will load the modular rule files below.
     Agents that don't will read the inlined fallback content beneath. -->

@rules/breaks.md
@rules/tdd.md
@rules/git.md
@rules/issues.md

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
