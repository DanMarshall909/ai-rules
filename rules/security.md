# Security by Design

For encryption, signing, token handling, secrets, sensitive domain types, or a
security review, use the `security-by-design` skill.

- Concentrate security decisions behind one narrow, intent-named boundary.
- Expose permitted outcomes, not configurable cryptographic primitives.
- Give sensitive values validated immutable types and minimize plaintext
  lifetime.
- Use established cryptography, reject insecure input, and release no partial
  plaintext after authentication failure.
