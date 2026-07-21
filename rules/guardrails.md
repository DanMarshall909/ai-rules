# Guardrails

When a mistake is **repeatable** and **bad**, and a test could mechanically
prevent it, flag that test. Say what it would assert and what it would have
caught. Don't silently fix the instance and move on — the instance is one
sample of a class.

Repeatable means it can recur without anyone noticing: a convention that only
holds while people remember it, a layering rule enforced by habit, a constant
duplicated by hand, a shape every implementation must share. A one-off typo the
compiler already rejects is not repeatable.

Prefer the guardrail that fails at build time over the one that relies on
review. An architecture/convention test that sweeps *every* type is worth more
than a unit test pinning the one type that happened to break today — write the
test against the rule, not against the instance.

Flag it and let the user decide whether to build it now. Not every guardrail
earns its cost; that call is theirs.

## A guardrail must be able to fail

A guardrail earns trust by being ignored, so how it behaves when it stops
working matters more than how it behaves when it passes. Three ways one holds
nothing while still reporting success:

- **It cannot run, and does not say so.** A check reading state it might not
  have — an index, a lock file, a service — must announce the skip by name.
  Degrading to a clean result is the worst option available: the output becomes
  indistinguishable from the check having passed.
- **Nothing invokes it.** A suite missing from the pipeline still passes
  locally and is still counted on. Wiring it up is part of building it, not a
  follow-up.
- **Its own test asserts only the exit code.** Any failure then stands in for
  any other, so a guardrail that has begun reporting the *wrong* problem — or
  choking on its input before it reaches the check at all — still looks
  correct. Break one rule at a time and assert the message naming that rule.

The test to write for a guardrail is not "does it pass on good input" but "does
it fail on bad input, for the stated reason" (see [[coverage]]).

**Judgment is not mechanizable.** A rule about *when* code is worth writing at
all — speculative generality, wrong abstraction, premature migration paths —
cannot be a test. Don't propose one; route that lesson to a rules file instead
(see [[reflection]]).
