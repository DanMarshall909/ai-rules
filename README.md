# ai-rules

Lean, agent-agnostic AI coding rules. Works with Claude Code, Cursor, Windsurf, Cline, and any assistant that reads markdown rule files.

## Rules

| Rule | What it does |
|------|-------------|
| `rules/breaks.md` | 30-min + 2-hour break reminders with cross-project check-in |
| `rules/tdd.md` | Red → Green → Refactor → Coverage, one AC at a time |
| `rules/coverage.md` | Code must justify itself; never call a branch unreachable |
| `rules/git.md` | pull --rebase, backup before force-push, staged diff review |
| `rules/issues.md` | `docs/issues/[open\|resolved]/[area]/` structured tracking |
| `rules/reflection.md` | Capture durable lessons when work lands; route them to the right scope |

## Install the break-reminders skill (Claude Code)

The break-reminders skill automates the 30-min and 2-hour reminders so you don't have to think about them.

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/DanMarshall909/ai-rules/main/scripts/install-break-reminders.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/DanMarshall909/ai-rules/main/scripts/install-break-reminders.ps1 | iex
```

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

## Structure

```
rules/*.md                       ← single source of truth
AGENTS.md                        ← GENERATED: self-contained, for agents without @ imports
CLAUDE.md                        ← Claude Code entry point (@ imports rules/*.md)
rules/
  breaks.md
  tdd.md
  coverage.md
  git.md
  issues.md
  reflection.md
skills/
  break-reminders/SKILL.md      ← Claude Code skill (auto-schedules reminders)
  behavior-first-tdd/SKILL.md   ← Claude Code skill (behaviour-first TDD)
  reflect/SKILL.md              ← Claude Code skill (capture lessons when work lands)
scripts/
  build-agents.sh               ← regenerates AGENTS.md from rules/*.md
  install-break-reminders.sh    ← macOS/Linux installer
  install-break-reminders.ps1   ← Windows installer
```

## Use as your global rules (Claude Code)

Check the repo out once, then `@`-import it from `~/.claude/CLAUDE.md` so every
project inherits the rules:

```bash
git clone https://github.com/DanMarshall909/ai-rules ~/code/ai-rules
ln -s ~/code/ai-rules/skills/reflect ~/.claude/skills/reflect
```

```
@~/code/ai-rules/CLAUDE.md
```

Editing the rules then means editing this repo — a rule that only exists on one
machine is not a global rule.
