# AI Rules

Lean rules for Claude Code. Two files. No bloat.

## Session start

Run `/break-reminders` to enable:
- **30-min** short breaks with cross-project memory scan (9am–4:30pm)
- **2-hour** longer break + goal wizard (9:07, 11:07, 13:07, 15:07)

## Work tracking

| What | How |
|------|-----|
| Features / tasks | `bd` bead tracking |
| Bugs / issues | `/issue` → `docs/issues/open/[area]/` |
| Security findings | `/security-finding` → same structure |
| Resolving | Move file to `docs/issues/resolved/[area]/` |

## TDD

Use `/tdd` for all new code: **Tidy → Red → Green → Refactor → Coverage**

No production code before a failing test exists. Commit at each phase.

## Git

- `git pull --rebase` before every push
- Before force-push: `git checkout -b backup/<branch>-<timestamp>`
- Never commit without reviewing `git diff --staged --stat` first
