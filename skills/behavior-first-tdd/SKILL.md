---
name: behavior-first-tdd
description: Use when changing system behavior, adding tests, reviewing coverage, or deciding whether uncovered code should be tested or pruned. Enforces behavior-first TDD with externally observable tests.
---

# Behavior-First TDD

Use this skill whenever a task may change system behavior, add new behavior, revise tests, review coverage, or decide whether uncovered code should stay.

## Core Rule

Every new behavior must be specified by a test before implementation.

Tests should describe what happens from an outside perspective: inputs, commands, files, public APIs, observable outputs, diagnostics, state transitions, rendered artifacts, or errors. Do not test implementation minutia such as private fields, helper algorithms, storage layout, or incidental constructors unless that API is itself a public contract.

## Before Changing Behavior

State briefly:

- What behavior is changing.
- Why the behavior should change.
- Which test will specify the behavior.
- What externally observable outcome the test will assert.

If this cannot be stated clearly, pause and clarify before editing.

## TDD Workflow

1. Write or update a test that describes the externally observable behavior.
2. Run the test and confirm it fails for the expected reason when feasible.
3. Implement the smallest production change that makes the test pass.
4. Run the relevant tests.
5. Run coverage when the task is about test quality, coverage, or pruning.
6. If new code is uncovered, either add behavior-level coverage or remove the code if it has no useful behavior.

## Coverage Review Workflow

For uncovered code, classify each block:

- Boundary code: may be excluded if it only adapts external systems, process entrypoints, FFI, generated code, or vendored code.
- Useful behavior: add or improve an externally observable test.
- Unused convenience/API shape: prune it unless there is a concrete near-term consumer or public contract.
- Defensive branch: keep only if it protects a meaningful failure mode; otherwise simplify.

Do not add tests only to satisfy coverage. A coverage-increasing test must prove useful behavior or guard against harmful behavior.

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

## Communication

When explaining the work, teach the why as well as the what. Keep explanations brief: identify the behavior contract, the risk being guarded against, and the test that now specifies it.
