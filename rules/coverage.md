# Coverage & Dead Code

Aim for 100% coverage of core code through behaviour-driven tests that drive real
code paths and assert observable output.

## Code must justify itself

- Code that cannot be justified is removed, not covered. Code that exists only to
  be exercised by its own tests — no production callers — is not justified by
  those tests.
- Before deleting dead or unreferenced code, decide whether it is useful
  functionality that should be *wired up* rather than deleted (e.g. a correct
  primitive with no caller yet). Assess its value and propose wiring it up. Only
  delete genuine leftovers and duplicates. Never delete useful code to raise a
  coverage number.

## Compatibility code needs a real past

Migrations, upcasters, versioned shapes, deprecation shims, and fallback paths
are justified by something that *actually exists* depending on the old shape: a
released version, data already written, a caller you do not control. Absent
that, there is no old shape — only the current one, arrived at by editing.

Before writing any of it, establish what depends on the old shape. If nothing
does, change the shape in place and delete the old one.

Pre-release is the common case: nothing is deployed, no data was ever written,
so every schema is version 1 no matter how many times it changed on the way
here. Ask whether the project has shipped; do not assume it has because the code
looks mature.

This one is hard to catch from the inside, because writing the upcaster *feels*
like diligence rather than waste. The tell is noticing "nothing depends on this
yet" and building it anyway — if you can say the cost is currently zero, you
have already proved the code is currently pointless.

## Read the gap before you close it

An uncovered line means **that behaviour has never once executed**. It is a
statement about the code, not about the tests.

- If one half of a pair is covered and the other is not, the untested half is
  load-bearing code nobody has ever run. Symmetry gaps are the richest.
- Assert the behaviour the gap reveals, not the line.
- Assert what you believe, then let a failure correct the belief. Never weaken an
  assertion to match observed output without first understanding why it differs.

## Never call a branch unreachable

An unreachable branch means the type does not carry what you already know. Before
you write "unreachable", "defensive", or "justified but uncoverable" in a
comment, work this list in order:

1. **Carry the value forward.** An earlier step proved the lookup succeeds, then
   threw the result away. Keep it instead of looking it up twice.
2. **Remove the impossible variant.** An `Option`/`Result` that no path returns
   is a lie. Change the return type.
3. **Make a silent skip a loud failure.** A lookup that quietly does nothing when
   it misses will emit a *wrong answer* if the invariant ever breaks.
   `.expect("why this holds")` is strictly better: it fails loudly, and costs no
   coverage because the panic lives in the standard library.
4. **Re-derive reachability from the public API.** You are usually wrong.
   Boundary lookups, `?`-paths on public methods, and "obviously valid" inputs
   are typically reachable and merely untested.

Only when all four fail is code genuinely uncoverable. Then keep it, exclude it
from the coverage target, and state the reason inline. Exclusion is a last
resort, not a permission.
