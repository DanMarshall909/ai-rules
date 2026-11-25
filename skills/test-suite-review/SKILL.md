---
name: test-suite-review
description: Review a focused test family or a whole suite for acceptance traceability, clarity, regression value and execution cost. Use for comparative test reviews, not routine test design.
---

# Test Suite Review

Find the smallest suite that gives trustworthy feedback about required behaviour.
Never sacrifice clarity or business protection for speed, fewer tests or scores.
`behavior-first-tdd` owns test design and safe changes of test level;
`coverage-and-mutation` owns interpretation of coverage, costs and mutants.
A review request authorizes findings and proposals, not test edits.

## Match evidence to the question

Review the named feature, test family or confirmed pattern. Audit the whole suite
only when requested. Say what was inspected and any material gaps; use existing
specs, readable tests and retained results rather than a new ledger.

For a whole-suite audit, account for all discovered tests, parameterized rows,
lanes and exclusions, including skipped and platform-specific tests. Reconcile
with the normal test driver or CI inventory so omissions remain visible. A focused
review needs only the inventory relevant to its question.

Use comparable timings when assessing performance, including fixture costs.
Reuse valid retained evidence and identify its revision and limits. Do not run
unrelated suites or launch a full mutation run merely to populate a report.

## Inspect what each test proves

Follow the current acceptance criterion through the scenario, relevant conditions
and observable assertion to a meaningful defect it would detect. Inspect the test;
a name, mapping entry or coverage percentage alone is insufficient. Check whether
the fixture reaches the claimed path, the oracle is independent, and broad errors
or timeouts could mask the intended failure.

Judge regression protection, resistance to harmless refactoring, speed and
maintainability together. Requirements and tests evolve; use `behavior-first-tdd`
to distinguish missing RED evidence from correctly green refactors and to retire
superseded expectations deliberately.

Compare overlap by contract, not shared lines or mutant kills. Preserve distinct
failure classes, boundaries and historical regressions. A unit and an integration
test can execute the same code while proving different things; keep real interface
tests when their cooperation is part of the guarantee.

Recommend retaining, parameterizing, sharing setup, moving level, consolidating,
removing or investigating a test. For removals, identify the retained protection
or the requirement deliberately retired. Seek obsolete, redundant or vacuous
tests, but do not invent removal candidates. Prefer clear scenarios and failure
identities over giant tables or fewer tests. Sharing setup need not merge scenarios.

When a weakness recurs, inspect related tests sharing its fixture, interface or
responsibility. Assess each guarantee independently; similar setup does not prove
that tests are redundant. Keep edits within authorized scope.

## Improve the demonstrated weakness

For slowness, distinguish test execution from setup, compilation, I/O, scheduling
and shared-resource costs. Verify claimed savings on comparable ordinary runs;
fewer tests alone do not prove faster feedback. For coverage gaps, identify weakly
asserted required behaviour before proposing tests at the smallest faithful scope.

When changes are authorized, follow `behavior-first-tdd` to preserve the business
scenario and necessary boundary evidence. Run replacements before removing old
tests; check a representative fault when protection is uncertain. Verify affected
contracts and project gates. If a faster decomposition obscures the business story,
improve it or retain the clearer test.

## Report proportionately

Give actionable findings with test identifiers, the business guarantee at stake,
the proposed change and supporting evidence. Include before/after measurements
when claiming a performance improvement, and distinguish execution from source
review or historical evidence. State material gaps and further findings without
turning a focused review into a whole-suite audit.
