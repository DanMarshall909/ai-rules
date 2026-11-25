---
name: behavior-first-tdd
description: Use when changing maintained system behavior or revising tests. Owns the behavior-first TDD cycle and test design; use coverage-and-mutation for evidence interpretation.
---

# Behavior-First TDD

Use this skill for authorized behavior changes and test revisions. A review-only
request can use its test-quality criteria without authorizing implementation.

## Core Rule

Every new behavior must be specified by a test before implementation. Work one
observable acceptance criterion at a time through
`RED → GREEN → COVERAGE → REFACTOR`; do not begin the next RED until both
production and test refactoring have been considered.

Tests should describe what happens from an outside perspective: inputs, commands, files, public APIs, observable outputs, diagnostics, state transitions, rendered artifacts, or errors. Do not test implementation minutia such as private fields, helper algorithms, storage layout, or incidental constructors unless that API is itself a public contract.

## Choose the Test Level from the Behaviour

Observable behaviour is relative to the owning component's public boundary; it
does not require driving the whole application. Choose the smallest scope that
clearly and faithfully proves the current acceptance criterion. Never trade test
clarity or business protection for speed, fewer tests or a higher score.
Parameter tables and helpers must preserve readable scenarios and distinct
failure identities. Before writing the test, select its level:

- Unit or component tests prove local rules such as formatting, validation,
  calculations and local state transitions through real production logic.
- Add integration tests only when required to prove an interface between two
  systems, such as producer/consumer compatibility or error propagation across
  that interface.
- End-to-end tests prove outcomes whose correctness depends on the complete
  application path. Name what that path uniquely proves before paying its cost.

Before adding an integration test, name the two systems, their interface contract
and the concrete interface failure the test must detect. Its assertions must
fail when that contract breaks. Merely involving multiple systems, components
or processes is insufficient. If the asserted behaviour is owned by one system
and can be proved without crossing the interface, write a unit test through that
system's public boundary instead. For example, a serializer's local formatting
rules belong in unit tests; compatibility between its output and another
system's consumer can require an integration test. Apply this decision regardless
of how fast the proposed integration test runs.

Keep local edge cases and data variants in the owning fast tests, preferably
parameterized when they share a contract. Retain representative integration
cases for distinct boundary risks; do not repeat every local case through an
expensive integration or end-to-end fixture. Do not mock away the behaviour being
proved or replace outcome assertions with incidental interaction assertions.

Select regression scope from affected behaviour and dependencies. A frontend
change needs backend tests when backend behaviour, shared code or its boundary
contract is affected; sharing a repository is insufficient. Honour enforced
gates, but report unrelated tests run by a hook as incidental gate execution,
not evidence for the changed behaviour.

## Keep Business Rules Visible

Make each current acceptance criterion easy to follow through its scenario and
relevant conditions to an observable assertion and the meaningful violation it
detects. Use existing specs and readable tests; add a separate mapping only when
needed or required by the project. A name, mapping entry or coverage score alone
is not proof. If the link is unclear, rethink the test.

BDD scenarios can live at unit level. When a scenario spans systems, retain
evidence of their cooperation; passing tests for separate parts do not prove it.

Requirements and tests evolve together. New or revised behaviour needs a test
that rejects the previous behaviour where it differs; demonstrate that RED when
feasible and disclose an unavoidable gap. Retire superseded expectations because
the accepted requirement changed, never merely to match production output.
Behaviour-preserving refactors should stay green, and compatible additions may
leave existing tests green. Investigate unexplained green results after a
nontrivial change and failures in unaffected contracts. Seek a minimal but
significant set of failures that identifies affected guarantees without incidental
coupling; do not force failures for internal edits or pursue a target count.

## Change Test Level Without Losing Meaning

When replacing an integration or end-to-end test with unit tests, preserve its
business rule, relevant conditions and meaningful fault detection through real
production logic. Keep any necessary interface or complete-path evidence;
replacing dependencies with mocks does not establish equivalence. Run the
replacement before removing the original, and use a representative fault if its
protection is uncertain. If the business story becomes harder to follow, improve
the decomposition or retain the clearer test.

Inspect related tests sharing a confirmed weakness, such as the same fixture,
interface or responsibility. Assess their guarantees individually and keep edits
within authorized scope. Use `test-suite-review` when a comparative review helps.

## Before Changing Behavior

Inspect nearby tests and briefly explain the accepted behaviour change, the test
that will prove it and the expected failure. Reuse an existing table or fixture
when it keeps the scenario clear. Existing specs, tests and the normal work update
usually suffice; resolve unclear requirements before changing their behaviour.

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
7. Run the relevant tests through the project's normal driver before beginning
   another criterion. Include material refactoring decisions in the normal handoff;
   do not create a separate record for every phase.

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

## Keep Routine TDD Feedback Fast

Maintain named fast and slow selections for every maintained suite, including
suites whose slow selection is currently empty. On each ordinary run inspect
test and setup/teardown timings for candidates to move in either direction.
Confirm candidates with comparable non-mutated reruns before editing membership;
a single timing spike is not grounds for moving a test. Use the lane protocol
in `coverage-and-mutation` for repeat evidence, selection reconciliation and
per-lane coverage. Ordinary fast feedback does not require repeating the entire
slow suite; reuse valid retained timings and verify selected candidates.

Set a project-specific wall-clock budget for the regular TDD suite, aiming for
the entire routine suite to finish in a few seconds on representative hardware.
Measure each test's median elapsed time, including setup and teardown, over
comparable runs. Compare peers in the same test tier; question a test when its
median exceeds 1.5 times that tier's median. This triggers investigation, not
automatic failure or exclusion. Ignore trivial timing noise, and investigate
suite-level slowness even when every test has similar duration.

For a slow integration test, ask whether its business scenario can be proved
at unit level with real production logic and deterministic inputs. Follow
"Change Test Level Without Losing Meaning" before changing it;
retain any required boundary evidence. If a real boundary is essential, improve
fixture/setup cost or document its value and place the test in a named slower
verification lane. Never obscure the scenario or mock away its behaviour to
meet a timing target. Run affected slow contracts at required
checkpoints and before final publication; retain enforced gates and do not defer
the sole oracle for the current criterion beyond that criterion's completion.

## Calibrate Test Abstractions Against Real Boundaries

When a fixture, fake, stub, recording or in-memory adapter stands in for an
external tool or system, establish the subset of its behavior on which fast
tests rely. Reuse existing integration contract coverage; add a focused test
only where needed to prove the relied-on interface. This evidence must exercise
the real boundary, independently observe representative successful and material
failure outcomes, and check that the stand-in preserves the contract-bearing
inputs, outputs and relationships. Do not use the production parser or the
stand-in itself as the sole oracle; two matching mistakes are not calibration.
Keep malformed and edge-case variants in fast tests, but do not claim a stand-in
models external behavior it has not been checked against.

Run this calibration in the boundary lane at required checkpoints and whenever
the tool version or boundary contract changes. The fast suite may then use the
calibrated stand-in within that established scope; it does not replace the
real-boundary test. Prefer reusing an existing real-boundary run over duplicating
an expensive setup solely for calibration.

## Make Oracles Independent and Falsifiable

For serialization, compilation, mapping, reconstruction, and other multi-stage
transformations, derive expected values from the original authoritative inputs
and contract, not from another output of the production mapper. Assert the
result after the final consumer or authority boundary. A round trip can prove
compatibility while still hiding the same swapped, omitted, or defaulted field
on both sides.

Use distinguishable non-default values for mechanically distinct required
fields so a swap, omission, duplication, or wrong default makes the test fail.
Assert the contract's required outcomes rather than mirroring every incidental
property of the current object shape.

For diagnostic contracts, assert stable structured identities such as rule,
requirement, task, source, path, category, or position instead of pinning prose.
First prove the fixture produces nonempty, heterogeneous diagnostics. To test
ordering or determinism, permute inputs whose failures have distinct identities
and assert the resulting identity sequence. Empty results, identical failures,
or fixtures that pass under the wrong permutation are vacuous oracles.

For retry loops, polling and asynchronous calls that can stall under a fault, an
assertion after the call returns may never execute. When a test owns a fake
collaborator, make it fail promptly at the contract's finite invocation or
attempt bound, with an expected count independent of the observed result. Keep
the post-return assertions of public behavior as well. Verify the guard with a
direct repeated-call fault; a broad elapsed-time timeout alone is a weak oracle.

## Coverage Review Workflow

Read `coverage-and-mutation` before interpreting uncovered code or mutants. It
owns classification, harness calibration and test/code retention decisions.
Bring those findings back into this criterion's coverage and refactor phases;
do not add tests merely to increase a score.

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

Isolated spikes, prototypes, and genuinely one-off scripts may use proportionate
smoke, syntax or output evidence. Production, maintained, reused and recurring
operational code follows the ordinary workflow; the label "utility" is not an
exemption. Follow explicit task and scoped project rules within the host's
instruction hierarchy.

## Communication

When explaining the work, teach the why as well as the what. Identify the
behaviour contract, the regression risk, the test that specifies it, what
coverage revealed, and the resulting production/test refactor decision.
