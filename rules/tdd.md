# TDD Protocol

**Tidy → Red → Green → Refactor → Coverage**

- Never write production code before a failing test exists
- Work one acceptance criterion at a time — no batching
- Commit at each phase: `test(red)`, `feat(...)`, `refactor(...)`
- After implementation: check coverage, run mutation testing if available
- End of session: offer to squash TDD commits into one

> Claude Code users: use the `/tdd` skill.
