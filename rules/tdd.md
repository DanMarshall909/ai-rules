# Agentic TDD Protocol

**Tidy → RED → GREEN → COVERAGE → REFACTOR → next RED**

- Work one observable acceptance criterion at a time; do not batch behaviours.
- Review adjacent tests before RED; consolidate only when confidence survives.
- Preserve evidence that RED failed for the missing behaviour, then implement
  only enough for GREEN.
- Use COVERAGE to find unprotected behaviour and unearned code; percentages do
  not finish this phase.
- REFACTOR production code and tests, or record why each genuinely needs no
  improvement, before starting the next RED.
- Preserve RED through the project's driver or a separate commit when permitted;
  never break shared trunk merely to manufacture evidence.

For behaviour changes use the `behavior-first-tdd` skill (`/behavior-first-tdd`);
use `agentic-delivery` for non-trivial work.
