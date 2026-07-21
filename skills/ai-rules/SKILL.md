---
name: ai-rules
description: 'Use when working on the ai-rules repo itself: editing rules/*.md, adding or changing a skill, or touching the scripts. Covers what is generated versus authored, which checks must pass before a commit, and where a new rule has to be registered.'
---

# ai-rules

This repo is the source of the rules its own agents obey, so a mistake here
propagates to every project that imports it. Everything below is about keeping
the generated copies honest and the conventions enforced by something other than
memory.

Run the checks at the end. They are fast, and most of them exist because
something silently broke.

---

## Step 1 — Know what is authored and what is generated

| Path | Status |
|------|--------|
| `rules/**/*.md` | **authored** — the rule fragments |
| `rule-sets/*.set` | **authored** — which set ships which fragments, in order |
| `skills/*/SKILL.md` | **authored** |
| `scripts/*` | **authored** |
| `rule-sets/*.md` | **generated** rule sets — never edit |
| `AGENTS.md` | **generated** minimal entrypoint — never edit |
| `CLAUDE.md` | authored, but should import the base rule set |

`AGENTS.md` exists because Codex, OpenCode, Cursor and Cline look for that
filename. It should stay small and point at `rule-sets/ai-rules.md`. `CLAUDE.md`
imports that same set. The sets are the policy; the agent files are entrypoints.

If asked to change a rule, change `rules/<...>.md` and regenerate. If you find
yourself editing `AGENTS.md` or a `rule-sets/*.md`, stop — the change will be
overwritten.

---

## Step 2 — A rule belongs to a set

`ai-rules` is the base set: rules for every project, kept at the top of
`rules/`. A **layered** set — `tool-repos` is the first — is rules for one kind
of repo, kept in `rules/<set>/`, and read alongside the base rather than
instead of it.

Choosing between them is the judgment call. A rule that would make a reader in
an unrelated project think "not my repo" belongs in a layered set; if it is
only true of *one* repo it is not a rule at all, and belongs in that repo's own
`AGENTS.md` (`rules/reflection.md` has the routing table).

Use the scaffolds — they write every place a rule has to be registered:

```bash
scripts/new-rule.sh --title "Caching" caching                 # base set
scripts/new-rule.sh --set tool-repos --title "..." some-rule  # layered set
scripts/new-rule-set.sh --title "..." --blurb "..." --layer ai-rules <name>
scripts/new-skill.sh --set tool-repos --description "..." <name>
```

By hand it is: the fragment, a `rule:` line in the manifest, a README row for a
base-set rule or a sets-table row for a whole set, then
`scripts/build-agents.sh`. Miss one and a check names it — the build refuses a
fragment no manifest lists, and `check-conventions.sh` guards the README. That
was not always true: `guardrails.md` was absent from the README table for its
whole life, which is why the check exists.

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

`scripts/agents.sh` holds the one agent table: roots, scopes, `link_to` (which
refuses to leave a copy where a symlink was meant) and `append_once` (for the
files a project owns and we may only add a line to). `scripts/rule-sets.sh`
holds the manifest layout. Both bash installers source both.
`install-skill.ps1` keeps its own copy for want of a shell it can source, so it
is the one that can drift.

Adding an agent means: the list and root in `agents.sh`, a target in each of
`user_target`, `project_target` (install-skill.sh), `rules_target` and
`set_target` (install-rules.sh), and the whole lot again in
`install-skill.ps1`. `check-conventions.sh` names whichever you forget — it
reads all of them.

Rules and skills install differently, and the difference is the point:

- **Skills** are symlinked, so an edit is live at once. `--project <dir>` puts
  one in a single repo (`.claude/skills/`, `.agents/skills/`) instead of the
  profile, which is how a set's skills travel with it.
- **Rules** reach Claude Code through an `@` import, also live at once — but
  reach every other agent through a symlinked rule-set file. An edit to
  `rules/` does not reach them until `build-agents.sh` runs. Enable the hook
  (`git config core.hooksPath scripts/hooks`) so a commit cannot leave it
  stale.
- **A layered set** installs into one repo:
  `install-rules.sh --rule-set <name> --project <dir>`. It appends to that
  repo's `AGENTS.md` and `CLAUDE.md` and replaces neither, because both are
  usually already written. Dry-run it first.

---

## Step 5 — Run the checks before committing

```bash
scripts/build-agents.sh --check    # every rule set matches its manifest
scripts/test-build-agents.sh       # the generator's behaviour
scripts/test-install-skill.sh      # the skill installer's behaviour
scripts/test-install-rules.sh      # the rules installer's behaviour
scripts/test-new-skill.sh          # the skill scaffold's behaviour
scripts/test-new-rule-set.sh       # the rule and rule-set scaffolds
scripts/test-check-conventions.sh  # the conventions check's own behaviour
scripts/check-conventions.sh       # skills load, installers agree, sets registered
```

On Windows, also:

```powershell
scripts\test-install-skill.ps1
```

All of them run in CI, and `check-conventions.sh` fails if a `scripts/test-*.sh`
is not named in `.github/workflows/` — so adding a suite means wiring it up in
the same commit.

`.gitattributes` does not force LF on everything, and the exception is a trap:
`.sh`, `.md` and the git hooks arrive LF everywhere, but `*.ps1` arrives
**CRLF** everywhere, Linux and CI included, because PowerShell is
Windows-native. A bash script reading `install-skill.ps1` therefore sees a
trailing `\r` on every line, and an end-anchored pattern matches nothing at all.
Strip the CR before parsing, not after.

If `build-agents.sh --check` reports a generated markdown file stale while
`git diff` says it is unchanged, that is the opposite failure — an `.sh` or `.md`
that arrived CRLF despite the rule. Report it rather than working around it.

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
- `rules/coverage.md` is the longest source rule and the most often relevant. If a task
  involves tests, coverage numbers, or a surviving mutant, read it before
  proposing a fix.
