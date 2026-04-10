# ai-rules

Two-file global AI rules for Claude Code. Clone into any project or reference from `~/.claude/CLAUDE.md`.

## What's here

- **`CLAUDE.md`** — the rules (session start, work tracking, TDD, git)

## Usage

Add to your project's `CLAUDE.md`:

```markdown
See global rules: https://github.com/DanMarshall909/ai-rules
```

Or copy `CLAUDE.md` contents into your project's `CLAUDE.md` directly.

## Rules summary

- `/break-reminders` at session start — 30-min + 2-hour break reminders, 9am–5pm
- `/issue` and `/security-finding` for structured issue docs
- `/tdd` for all new code
- `git pull --rebase`, backup before force-push
