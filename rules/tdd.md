# Agentic TDD Protocol

For behaviour changes use the `behavior-first-tdd` skill: **Tidy → RED → GREEN → COVERAGE → REFACTOR → next RED**; one observable criterion at a time. GREEN alone does not complete it.
Keep routine TDD feedback within a few seconds; question tests >1.5× peer median. Move slow integration assertions to real business-rule unit tests where possible; retain boundary evidence, never mock away the rule.

Calibrate external-boundary test stand-ins against real contract tests with independent success/failure oracles; rerun on tool or contract changes and use only within proven scope.

Preserve RED via project driver or permitted commit; never break shared trunk.
Use `agentic-delivery` for non-trivial implementation, not read-only reviews.
