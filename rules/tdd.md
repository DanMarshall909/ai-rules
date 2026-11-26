# Agentic TDD Protocol

For maintained behavior changes, use the `behavior-first-tdd` skill:
**Tidy → RED → GREEN → COVERAGE → REFACTOR**, one observable criterion at a
time.

- Choose the smallest test scope that proves the criterion: unit tests for
  single-system behavior, integration tests only for a named cross-system
  interface failure, E2E only when full-path behavior is what's being proved.
- Never mock away the rule under test or trade business clarity for speed.
- Keep fast and slow lanes explicit; calibrate boundary stand-ins against real
  contract tests. Never break shared trunk.
