# Agentic TDD Protocol

For behaviour changes use the `behavior-first-tdd` skill:
**Tidy → RED → GREEN → COVERAGE → REFACTOR → next RED**, one observable acceptance
criterion at a time. GREEN alone does not complete the criterion.

Preserve the intended RED through the project's driver or a separate commit
when permitted; never break shared trunk merely to manufacture evidence.
Use `agentic-delivery` to coordinate non-trivial implementation, not to impose
implementation steps on read-only reviews or genuine one-off experiments.
