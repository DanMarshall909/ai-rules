# Guardrails

When a harmful mistake can recur unnoticed, prefer a build-time or local test
check covering the whole convention over pinning one instance. Build it if in
scope; otherwise propose it.

- Name unavailable checks explicitly as skips or blockers, never clean passes.
- Wire checks into normal local verification.
- Verify every guardrail by injecting a fault and asserting the diagnostic
  names the broken rule—not merely a nonzero exit.
