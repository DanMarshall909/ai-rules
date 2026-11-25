# Agentic TDD Protocol

For behaviour changes use the `behavior-first-tdd` skill: **Tidy → RED → GREEN → COVERAGE → REFACTOR → next RED**; one observable criterion at a time. GREEN alone does not complete it. Choose the smallest test scope that clearly proves the current acceptance criterion. Never trade test clarity or business protection for execution speed, fewer tests or a higher score. Keep the criterion, scenario, assertion and detectable violation visibly connected; revisit them together when requirements change. Behaviour owned by one system belongs in unit tests. Add an integration test only when required to prove an interface between two systems; name that interface and the failure its assertions must detect. End-to-end tests prove outcomes that depend on the full path. Behaviour-first does not mean end-to-end-first.
Every maintained suite in every repository has explicit fast and slow lanes. Review timing/lane candidates on each ordinary run; move tests either way only after comparable reruns rule out an anomaly. Run the relevant slow contracts at the final ticket checkpoint; `coverage-and-mutation` owns the procedure. Select verification by affected behaviour, dependencies and contracts, not by everything in the repository. Keep routine feedback within a few seconds; question tests >1.5× peer median. Move local rule assertions to real unit or component tests; retain distinct boundary evidence, never mock away the rule.

Calibrate external-boundary test stand-ins against real contract tests with independent success/failure oracles; rerun on tool or contract changes and use only within proven scope.

Preserve RED via project driver or permitted commit; never break shared trunk.
Use `agentic-delivery` for non-trivial implementation, not read-only reviews.
