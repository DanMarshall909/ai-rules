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

**Judgment is not mechanizable.** A rule about *when* code is worth writing at
all — speculative generality, wrong abstraction, premature migration paths —
cannot be a test. Don't propose one; route that lesson to a rules file instead
(see [[reflection]]).
