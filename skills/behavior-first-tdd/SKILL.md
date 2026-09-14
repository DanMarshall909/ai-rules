---
name: behavior-first-tdd
description: Use when changing system behavior, adding tests, reviewing coverage, or deciding whether uncovered code should be tested or pruned. Enforces behavior-first TDD with externally observable tests.
---

# Behavior-First TDD

Use this skill whenever a task may change system behavior, add new behavior,
revise tests, review coverage, or decide whether uncovered code should stay.

## Core Rule

Every new behavior must be specified by a test before implementation. Work one
observable acceptance criterion at a time through
`RED → GREEN → COVERAGE → REFACTOR`; do not begin the next RED until both
production and test refactoring have been considered.

Tests should describe what happens from an outside perspective: inputs, commands, files, public APIs, observable outputs, diagnostics, state transitions, rendered artifacts, or errors. Do not test implementation minutia such as private fields, helper algorithms, storage layout, or incidental constructors unless that API is itself a public contract.

## Before Changing Behavior

Inspect adjacent tests, then state briefly:

- what behaviour is changing and which accepted criterion authorizes it;
- which existing tests already protect nearby behaviour;
- whether an existing table, property, fixture, or scenario can absorb the case
  without losing test quality;
- which test will specify the behaviour and what observable outcome it asserts;
  and
- how that test fares on regression protection, resistance to refactoring, fast
  feedback, and maintainability.

If this cannot be stated clearly, pause and clarify before editing.

## TDD Workflow

1. Write or update the narrowest owning test that describes the externally
   observable behaviour.
2. Run it and confirm RED is the expected missing behaviour, not invalid setup,
   compilation, spelling, or an unrelated failure.
3. Implement the smallest production change that makes the test pass.
4. Run the owning test and confirm GREEN.
5. Run COVERAGE as a diagnostic. Map the criterion to assertions and inspect
   behaviours, boundaries, branches, failure paths, state transitions, and
   invariants. If code is uncovered, either protect useful behaviour or remove
   code that has no justified behaviour.
6. REFACTOR production code and tests while the suite is green. Simplify
   responsibilities, vocabulary, coupling, fixtures, and assertions; remove
   redundant tests and unjustified code.
7. Record the production and test improvements separately, or a concrete reason
   why each side genuinely needs no change.
8. Run the relevant tests through the project's normal driver before beginning
   another criterion.

Do not treat GREEN as completion. It proves the current example passes; COVERAGE
asks what remains unprotected or unearned, and REFACTOR prevents that design
debt from accumulating around the next behaviour.

## Judge Every Test by Four Pillars

A valuable test needs all four:

1. **Protection against regressions** — it fails for a meaningful defect in
   required behaviour, a boundary, transition, failure path, or invariant.
2. **Resistance to refactoring** — it observes stable public behaviour rather
   than private structure, incidental call sequences, or storage details.
3. **Fast feedback** — it runs at the cheapest owning layer that can prove the
   claim, without unnecessary process, network, or I/O cost.
4. **Maintainability** — its scenario, setup, action, and oracle are readable;
   duplication and fixture complexity earn their cost; failures identify useful
   causes.

A serious weakness in any pillar undermines the test; strength elsewhere does
not average it away. Keep a slower integration test only when it uniquely proves
an important cross-boundary outcome, then support it with faster owning-layer
laws instead of duplicating its complete setup.

The goal is the smallest sufficient trusted suite. Every retained test should
add distinct regression protection, a necessary layer-specific law, or uniquely
valuable cross-boundary evidence.

## Coverage Review Workflow

For uncovered code, classify each block:

- Boundary code: may be excluded if it only adapts external systems, process entrypoints, FFI, generated code, or vendored code.
- Useful behavior: add or improve an externally observable test.
- Unused convenience/API shape: prune it unless there is a concrete near-term consumer or public contract.
- Defensive branch: keep only if it protects a meaningful failure mode; otherwise simplify.

Do not add tests only to satisfy coverage. A coverage-increasing test must prove
useful behaviour or guard against harmful behaviour. Read
`coverage-and-mutation` before interpreting gaps or mutation results.

## Test Smells

Prefer rewriting tests that:

- Assert private fields or internal counters.
- Check getter/setter behavior with no user-facing outcome.
- Assert object construction shape instead of behavior through validation/rendering/commands.
- Test helper functions directly when public behavior covers the same rule.
- Depend on incidental ordering unless ordering is part of the contract.

## Good Test Shapes

Examples of behavior-level test names:

- `patch_with_missing_destination_port_is_rejected`
- `control_output_can_drive_control_input`
- `audio_output_cannot_drive_event_input`
- `validate_without_patch_path_returns_usage_error`
- `note_off_allows_active_note_to_finish`
- `rendering_the_same_patch_twice_is_deterministic`

These names describe product promises or useful safety checks rather than implementation details.

## Scope Boundary

Isolated spikes, prototypes, generated examples, and utility scripts do not need
a test suite solely to imitate production TDD. Verify their declared output or
measurement. Once code crosses the project's production boundary, apply the
ordinary workflow.

## Communication

When explaining the work, teach the why as well as the what. Identify the
behaviour contract, the regression risk, the test that specifies it, what
coverage revealed, and the resulting production/test refactor decision.
