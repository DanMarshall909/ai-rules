# Guardrails

When a harmful mistake can recur unnoticed and a test could mechanically prevent
it, identify the invariant, the failure it catches and the cost. Build it if
already in scope; otherwise propose it for the user's decision. Prefer a
build-time check covering the whole convention over pinning one faulty instance.

## A guardrail must be able to fail

- Name unavailable checks explicitly. Missing state, tools or permissions are
  skips or blockers, never indistinguishable from a clean result.
- Wire the check into the normal pipeline; a local-only suite is not a CI gate.
- Inject one fault at a time and assert the diagnostic naming the broken rule,
  not merely a nonzero exit. Setup errors must not impersonate fault detection.

Use the `coverage-and-mutation` skill to assess that evidence. Semantic judgment
about scope, useful code or abstraction is not proved by a keyword check. Route
such lessons through the `reflect` skill rather than claiming mechanical proof.
