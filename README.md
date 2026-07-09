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

**Claude Code** — add to your project `CLAUDE.md`:
```
@https://raw.githubusercontent.com/DanMarshall909/ai-rules/main/AGENTS.md
```

**Cursor** — add to `.cursor/rules/ai-rules.mdc`:
```
@ai-rules/AGENTS.md
```

**Any agent** — copy `AGENTS.md` into your project's AI rules file directly.

## Structure

```
AGENTS.md                        ← main rules file (@ imports + inline fallback)
CLAUDE.md                        ← Claude Code entry point
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
@~/code/ai-rules/AGENTS.md
```

Editing the rules then means editing this repo — a rule that only exists on one
machine is not a global rule.
