---
name: security-by-design
description: Use when designing, implementing, or reviewing encryption, signing, token handling, secret management, sensitive domain types, security boundaries, or cryptographic payloads.
---

# Security by Design

Secure code is not a checklist of secure methods bolted onto an insecure shape.
It is a property of the design: **the fewer places that make a security decision,
the fewer places that can make it wrong.** Good primitives used badly are still a
breach. So the goal is to make the secure path the easy path — concentrate the
decisions, expose intent rather than machinery, and let the type system and the
module boundary carry the rules a reviewer would otherwise have to remember.

This is an API-design problem before it is a cryptography problem.

## Concentrate security decisions behind one boundary

Security-relevant behaviour — encryption, signing, token handling, secret
management — belongs in one small module with a clear responsibility and a narrow
API, not scattered across the call sites that happen to need it, and not dumped in
a miscellaneous `Security` grab-bag either.

Code outside that boundary asks for an **outcome**:

```
protected = protector.Protect(customerReference)
```

It must never assemble that outcome from primitives:

```
nonce = randomBytes(12); key = keys.get("customer"); ct = encrypt(pt, key, nonce); out = nonce + ct
```

The second shape lets every caller omit a step, pick the wrong key, reuse a nonce,
or invent an incompatible payload format — and there are as many chances to get it
wrong as there are call sites. One boundary gives a reviewer a single place to
inspect the policy, makes a dependency change visible, and lets the whole
operation be tested. This is the one place tight coupling is a feature.

## Expose intent, not primitives

Most of that module should be **private/internal** — the most underused
visibility in most languages. Cipher choices, key resolvers, nonce generators, and
serialisation helpers are machinery the rest of the system has no business
naming. The public surface should describe only the permitted operations, named
after what they *do*: `ProtectCustomerData`, `SignPaymentInstruction`,
`SealOcrText` — never a general `Encrypt(data, algorithm, mode, padding, key,
nonce)` that hands every caller authority over choices they should never make.

The operation owns its security policy: algorithm, key, nonce, content role,
payload version, associated data, and failure handling all live inside it, so the
implementation and the versioned format can change without editing a single
caller. Do not make a dangerous choice configurable merely because it can be.

Visibility here is a **design** boundary, not a barrier against malicious code in
the same process — reflection bypasses it. It reduces *accidental* misuse, which
is most misuse. Enforce it with the repository's guardrail guidance: a
build-time check
that sweeps the module's public surface and fails when it widens beyond the
intended operations catches the next well-meaning `public` before review does.

## Give sensitive values their own types

Primitive obsession — a bare `string`, `int`, or byte array standing in for a
specific concept — is a security flaw, not only a smell. A `string` can be a
customer reference, a password, an access token, or a ciphertext; a byte array can
be plaintext, ciphertext, a key, or a nonce. When an API accepts the primitive,
the compiler cannot stop a caller passing the wrong one.

Give each security-sensitive value an immutable type that validates its whole
state at construction and exposes only the operations consumers need. Then the API
that takes a `CustomerReference` and returns `ProtectedData` cannot be handed a
raw token that merely shares the same underlying representation.

- Validate the complete value in a constructor or factory before exposing it.
- Make it immutable: no public setters, no partial initialisation, no collection a
  caller can mutate after validation. A read-only *view* over a caller-owned
  collection is not immutable — copy the input at the ownership boundary.
- Seal it so a subclass cannot change its behaviour; accept a read-only span/view
  when you only need to read a caller's buffer.

The one deliberate exception is a mutable buffer holding a plaintext secret, kept
so it can be overwritten — see below. It stays locally owned and never becomes a
domain object.

## Keep secrets alive for as little time as possible

Decrypt as late as possible, use the plaintext for one purpose, discard it at
once. Keep plaintext out of logs, exceptions, tracing tags, long-lived objects,
caches, queues, events, temporary files, diagnostic snapshots, and strings made
only to format or convert it. Every one of those is a copy in memory, a crash
dump, or a telemetry pipeline you did not mean to write a secret to.

For binary secrets, prefer a short-lived mutable buffer and zero it in a `finally`
(or the language's equivalent guaranteed cleanup), rather than waiting for the
garbage collector — which may have copied it and cannot be told to erase it. This
does not prove a secret was never copied; it is strictly better than not trying.
Do not hand out a view over a live secret buffer or leave it in a pool with its
contents intact.

## Minimise dependencies, not proven safety

Every dependency inside the trust boundary is more code to understand, patch, and
monitor, and a door to a vulnerable transitive package or an unsafe default. Keep
that graph small; prefer the platform's own facilities where they meet the
requirement.

But "fewer libraries" is not "rewrite everything". Replacing a mature, maintained
library with a bespoke version usually *adds* risk — hand-rolled SQL invites
injection, and a home-grown cipher is the classic disaster. The question is
whether a dependency needs to exist inside the boundary, what it drags in, whether
it is maintained, and whether a smaller established API would do — not whether you
can achieve aesthetic purity by deleting it. Remove unnecessary **capability**,
never a well-tested safety mechanism.

## Do not build your own cryptography

Use established primitives and protocols. Your job is to *compose* them well:
centralise algorithm selection, key identifiers, payload versions, associated
data, rotation, and failure handling in the one boundary, and expose an operation
that makes none of those a caller's problem.

Two failure rules are absolute, and both echo the guardrail and coverage
guidance:

- **An authentication failure returns no partial plaintext.** Verify, then
  release — never the other way round.
- **Errors reveal nothing about validity.** Do not let a message, a status code,
  or a timing difference disclose whether a key, an account, or a field was valid.
- **Reject insecure input rather than silently recovering from it.** Silent
  recovery is the fail-open that reads as success — the same trap as a guardrail
  that cannot fail.

## Treat the module boundary as a review boundary

A cohesive security module earns its keep only if changes to it get the scrutiny
its blast radius deserves:

- test invalid, truncated, and tampered payloads — not just the happy path;
- confirm secrets never reach logs or telemetry;
- scan direct **and** transitive dependencies;
- record *why* an algorithm or protocol was chosen;
- version payload formats, so the on-disk shape can evolve without a caller edit;
- design and test key rotation *before* it is urgent;
- reject insecure defaults instead of quietly repairing them.

Test the permitted public operations, the way a real caller uses them. Internal
primitives may have their own focused tests, but the question that matters is
whether ordinary application code can use the boundary *safely* — and, per the
`coverage-and-mutation` skill, whether the tests would go red if it could not.

None of these is a complete boundary on its own. Together they shrink the number
of places a security decision is made, and make the ones that remain easy to find,
review, and get right.
