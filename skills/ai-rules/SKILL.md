---
name: ai-rules
description: 'Use when working on the ai-rules repo itself: editing rules/*.md, adding or changing a skill, or touching the scripts. Covers what is generated versus authored, which checks must pass before a commit, and where a new rule has to be registered.'
---

# ai-rules

This repo is the source of the rules its own agents obey, so a mistake here
propagates to every project that imports it. Everything below is about keeping
the generated copies honest and the conventions enforced by something other than
memory.

Run the checks at the end. They are fast, and three of the four exist because
something silently broke.

---

## Step 1 — Know what is authored and what is generated

| Path | Status |
|------|--------|
| `rules/*.md` | **authored** — the single source of truth |
| `skills/*/SKILL.md` | **authored** |
| `scripts/*` | **authored** |
| `AGENTS.md` | **generated** by `scripts/build-agents.sh` — never edit |
| `CLAUDE.md` | authored, but must stay in step with `rules/` |

`AGENTS.md` exists because Codex, OpenCode, Cursor and Cline have no `@` import
syntax and read one self-contained file. `CLAUDE.md` imports the same rules
instead. Both must describe the same set of rules, or the agents disagree about
what the rules are.

If asked to change a rule, change `rules/<name>.md` and regenerate. If you find
yourself editing `AGENTS.md`, stop — the change will be overwritten.

---

## Step 2 — Adding a rule touches four places

1. `rules/<name>.md` — write it
2. `RULES=(...)` in `scripts/build-agents.sh` — add it, in reading order
3. `@rules/<name>.md` in `CLAUDE.md` — same order
4. the rules table in `README.md`

Then run `scripts/build-agents.sh` to regenerate `AGENTS.md`, and commit the
regenerated file alongside the rule.

Miss any of them and a check will say so — `build-agents.sh` guards step 2,
`check-conventions.sh` guards steps 3 and 4. That was not always true:
`guardrails.md` was absent from the README table for its whole life, which is
why the check exists.

---

## Step 3 — Adding a skill

```bash
scripts/new-skill.sh --description "Use when ..." my-skill
```

This writes `skills/my-skill/SKILL.md` with the YAML frontmatter that makes a
skill discoverable. Do not hand-create the directory: an agent finds a skill by
its frontmatter `name` and `description`, so a SKILL.md without them installs
cleanly, reads correctly, and never loads.

Write skills as instructions to an agent — steps to carry out — not as
documentation for a human. Say what to do when a step cannot be completed.

To install a skill into the agents on this machine:

```bash
scripts/install-skill.sh --list          # what exists, what is already linked
scripts/install-skill.sh my-skill        # every agent detected here
scripts/install-skill.sh --agent all my-skill
```

Skills are **symlinked** out of the checkout, never copied. A copy stops
tracking the repo the moment either side is edited, which is the failure this
repo exists to prevent. On Windows this needs Developer Mode or an elevated
shell; `install-skill.ps1` names the setting when it cannot link.

---

## Step 4 — Changing the installers

`install-skill.sh` and `install-skill.ps1` are parallel implementations with
separate test suites, so one can drift ahead of the other while both stay green.
`check-conventions.sh` compares their agent tables — if you teach one about a
new agent, teach the other in the same commit.

Adding an agent means, in both scripts: the agent list, the root used for
autodetection, and the target path. The check names whichever you forget.

---

## Step 5 — Run the checks before committing

```bash
scripts/build-agents.sh --check    # AGENTS.md matches rules/
scripts/test-install-skill.sh      # the installer's behaviour
scripts/test-new-skill.sh          # the scaffold's behaviour
scripts/check-conventions.sh       # skills load, installers agree, rules registered
```

On Windows, also:

```powershell
scripts\test-install-skill.ps1
```

All four run in CI. If `build-agents.sh --check` reports `AGENTS.md` stale while
`git diff` says it is unchanged, the working copy has CRLF line endings —
`.gitattributes` should prevent that, so report it rather than working around
it.

---

## Step 6 — Commit

Follow `rules/git.md` and `rules/tdd.md`, which this repo obeys itself:

- a failing test before the code that satisfies it, committed as `test(red)`
- present tense, imperative, saying *why* rather than *what*
- review the staged diff before committing
- branch from trunk and merge back the same day

When a change is meant to prevent a class of mistake, verify the check actually
fires by injecting the fault it claims to catch. A guardrail that cannot fail is
worse than none, because it reads as coverage.

---

## Notes

- Rules are for *any* project consuming this repo. A lesson that applies to only
  one project belongs in that project's memory — `rules/reflection.md` has the
  routing table.
- The break-reminders skill schedules cron jobs that expire after 7 days;
  re-running `/break-reminders` each session is expected, not a bug.
- `rules/coverage.md` is the longest rule and the most often relevant. If a task
  involves tests, coverage numbers, or a surviving mutant, read it before
  proposing a fix.
