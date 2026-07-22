# TDD Protocol

**Tidy → Red → Green → Refactor → Coverage**

- Never write production code before a failing test exists
- Work one acceptance criterion at a time — no batching
- Commit at each phase: `test(red)`, `feat(...)`, `refactor(...)`
- After implementation: check coverage, run mutation testing if available
- End of session: offer to squash the *green* commits into one. Never fold a
  `test(red)` commit into the `feat` that makes it pass: the failing test
  standing alone is the evidence that the test can fail, and squashing it away
  destroys exactly that. A red commit that does not compile is expected. It is
  not a broken trunk, and git.md's "trunk stays green" does not override this.

> Claude Code users: use the `/tdd` skill.
