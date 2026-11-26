# Coverage & Dead Code

Use the `coverage-and-mutation` skill for coverage, mutation, compatibility, or
dead-code decisions.

- Aim for 100% coverage of core code via externally observable behavior.
- Coverage proves execution, not assertion; remove unjustified code rather than
  covering it.
- Establish coverage before mutation. Run mutation post-session on the final
  snapshot (one active job per repo; never block tickets). Exclude E2E and
  slow-lane tests, use isolated CoW sandboxes, and clean up owned disposable
  output after completion or cancellation.
