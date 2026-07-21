# ai-rules

Lean, agent-agnostic AI coding rules. Works with Claude Code, Cursor, Windsurf, Cline, and any assistant that reads markdown rule files.

## Rules

| Rule | What it does |
|------|-------------|
| `rules/breaks.md` | 30-min + 2-hour break reminders with cross-project check-in |
| `rules/tdd.md` | Red → Green → Refactor → Coverage, one AC at a time |
| `rules/coverage.md` | Code must justify itself; never call a branch unreachable |
| `rules/guardrails.md` | Turn a repeatable mistake into a test that fails at build time |
| `rules/git.md` | pull --rebase, backup before force-push, staged diff review |
| `rules/issues.md` | `docs/issues/[open\|resolved]/[area]/` structured tracking |
| `rules/reflection.md` | Capture durable lessons when work lands; route them to the right scope |

## Install a skill

Clone the repo once, then install any skill into whichever agents you use:

```bash
git clone https://github.com/DanMarshall909/ai-rules ~/code/ai-rules
cd ~/code/ai-rules

scripts/install-skill.sh --list              # what's available, what's installed
scripts/install-skill.sh break-reminders     # every agent found on this machine
scripts/install-skill.sh --agent codex reflect
scripts/install-skill.sh --agent all reflect
```

Windows without Git Bash — same arguments, PowerShell spelling:

```powershell
scripts\install-skill.ps1 -List
scripts\install-skill.ps1 break-reminders
scripts\install-skill.ps1 -Agent codex reflect
```

| Agent | Skill lands at | Scope |
|-------|----------------|-------|
| `claude` | `~/.claude/skills/<skill>/` | user |
| `codex` | `~/.codex/prompts/<skill>.md` | user |
| `opencode` | `~/.config/opencode/command/<skill>.md` | user |
| `cursor` | `.cursor/rules/<skill>.mdc` | project |
| `cline` | `.clinerules/<skill>.md` | project |

With no `--agent`, it installs for every agent it finds a config directory for
and skips the rest. `--force` is needed only to replace a file you wrote
yourself; an existing symlink is repointed without asking.

**Skills are symlinked, not copied.** Editing `skills/<name>/SKILL.md` in the
checkout takes effect everywhere at once — a copy under `~/.claude` stops
tracking this repo the moment either side changes, which is the whole failure
this repo exists to avoid. The installer refuses to leave a copy behind even
when the shell hands it one, so on Windows it needs Developer Mode or an
elevated shell; it names the setting when it can't link.

Then run `/break-reminders` at the start of any Claude Code session.

## Adopt the rules

`AGENTS.md` is generated from `rules/*.md` and is **fully self-contained** — no
imports, no placeholders. Agents that lack an import syntax (Codex, OpenCode,
Cursor, Cline) can read it as-is. `CLAUDE.md` is the Claude Code entry point and
`@`-imports the same rule files, because Claude resolves imports.

**Claude Code** — add to your project `CLAUDE.md`:
```
@~/code/ai-rules/CLAUDE.md
```

**Codex / OpenCode / any agent that reads AGENTS.md** — copy `AGENTS.md` into
your project root, or symlink it:
```bash
ln -s ~/code/ai-rules/AGENTS.md AGENTS.md
```

**Cursor** — copy `AGENTS.md` to `.cursor/rules/ai-rules.mdc`.

## Editing the rules

`rules/*.md` is the single source of truth. After changing one, regenerate:

```bash
scripts/build-agents.sh           # rewrite AGENTS.md
scripts/build-agents.sh --check   # fail if AGENTS.md is stale (runs in CI)
```

Never edit `AGENTS.md` by hand — it is overwritten. CI rejects a stale copy.

The installer has its own tests. Run them after touching either script:

```bash
scripts/test-install-skill.sh    # CI runs this one
```
```powershell
scripts\test-install-skill.ps1
```

They install into a throwaway `HOME` and project directory, so they never touch
your real config.

## Structure

```
rules/*.md                       ← single source of truth
AGENTS.md                        ← GENERATED: self-contained, for agents without @ imports
CLAUDE.md                        ← Claude Code entry point (@ imports rules/*.md)
rules/
  breaks.md
  tdd.md
  coverage.md
  guardrails.md
  git.md
  issues.md
  reflection.md
skills/
  break-reminders/SKILL.md      ← auto-schedules break reminders
  behavior-first-tdd/SKILL.md   ← behaviour-first TDD
  reflect/SKILL.md              ← capture lessons when work lands
scripts/
  build-agents.sh               ← regenerates AGENTS.md from rules/*.md
  install-skill.sh              ← installs a skill into any agent (macOS/Linux/Git Bash)
  install-skill.ps1             ← the same, for Windows PowerShell
  test-install-skill.sh         ← behaviour tests for the installer
  test-install-skill.ps1        ← behaviour tests for the PowerShell installer
.gitattributes                   ← forces LF on *.sh; CRLF breaks them silently
```

## Use as your global rules (Claude Code)

Check the repo out once, then `@`-import it from `~/.claude/CLAUDE.md` so every
project inherits the rules:

```bash
git clone https://github.com/DanMarshall909/ai-rules ~/code/ai-rules
~/code/ai-rules/scripts/install-skill.sh --agent all reflect
```

```
@~/code/ai-rules/CLAUDE.md
```

Editing the rules then means editing this repo — a rule that only exists on one
machine is not a global rule.
