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

## Covered is not checked

The converse of the section above, and the more dangerous half. Coverage says a
line **ran**. It says nothing about whether anything **checked** it. A suite can
sit at 100% line coverage, all green, and pin nothing — and unlike a coverage
gap, this failure is invisible, because every signal you are looking at is the
colour you wanted.

Two ways a property-based test tests nothing while looking thorough:

- **It is written relative to the output.** If every property compares against
  `outcome.damage`, they all agree with each other about a damage figure that is
  wrong by a constant. Consistency among outputs is not correctness. At least one
  property must say what the value **must be**, derived from the inputs alone.
- **The generator fixes the input's shape.** Vary arity and collection size, not
  only values. With one element, `sum`, `max`, `first` and `last` are the same
  function — a whole class of operator error is unreachable by a generator that
  looked exhaustive because it ran ten thousand cases.

A third way, wherever a test parses what the code wrote: **the reader in the test
is more permissive than the real consumer.** A helper that strips optional quotes
before comparing reads quoted and unquoted output as the same string — so the
assertion holds whichever the code emits, and the format nobody re-reads is the
format nothing pins. The writer and the test agree with each other; the consumer
was never consulted. Parse with a reader at least as strict as the thing that
will actually load the output, and prefer the real parser to a hand-rolled one.

So: **before trusting a suite, break the code on purpose.** Injecting a fault is
the only cheap way to learn what the tests actually hold. If nothing goes red,
the suite does not test that, whatever the coverage report says. Mutation testing
is this, systematised — run it where it exists, and hand-inject where it does not.

**A memoized result is invisible to mutation testing.** If the suite computes the
system's output once — a `static Lazy`, a shared fixture, a cached scan — and every
test asserts against that one snapshot, the mutant activates but nothing re-runs the
mutated path: the snapshot was produced under the original code, so the survivor is
a false one and the score is a false floor. The tell is a survivor whose behaviour a
green test plainly asserts; confirm it by hand-injecting the mutant and watching that
test go red. Each assertion must **re-drive** the code under test, not read a cached
answer — the memoization that makes a slow suite fast is often the very thing that
makes it blind. Prefer pinning the inputs that reproduce a case (a known seed) over
caching the outputs it produced.

**A mutant that never applied is not a survivor.** Before reading a green suite
as evidence the tests are blind, confirm the fault actually reached the file: a
`sed` that matched nothing, a patch against a moved line, or quoting mangled on
its way through `eval` all leave the original code running and the suite
truthfully passing. The two failures look identical from the outside, and the
false one is the more expensive, because it sends you strengthening a test that
was already correct — or worse, "fixing" working code to make the phantom
reproduce. Diff the mutated file, or print the changed line, before you believe
the result.

**A mutant no test ran against is not a survivor either.** The mirror image of the
one above, and the one the rule above will not catch: the fault applies cleanly,
and the *tests* are what never arrive. Mutation tools map tests to mutants from an
instrumented baseline run so they can run only the covering subset; when that
mapping comes back empty — a runner the tool half-supports, a coverage collector
that failed to load, tests it discovered but could not attribute — every unmapped
mutant is filed "no coverage" and scored as unkilled without a single test being
run against it. Nothing errors. You get a plausible, terrible score.

Read the **status breakdown, not the score**. Killed-versus-survived is the number
that means something; a large "no coverage" bucket is a broken harness reporting
as a bare patch of code, and the two are indistinguishable from the headline
figure. The tell is a survivor in a file you have *watched* a hand-injected fault
die in. When the score contradicts something you observed directly, the score is
what is wrong.

Disabling per-test coverage mapping removes the failure by running the whole suite
against every mutant. Correct, and much slower — check what that costs before
launching it, especially where each run spawns a visible process.

**Coverage first, then mutation.** They answer questions in order — coverage asks
whether a line ever ran, mutation asks whether anything checked it — and the second
question is meaningless while the first is unanswered. A mutation score computed
over code the suite never reaches is measuring the harness. So establish coverage,
and confirm the mutation tool can kill a fault you planted yourself, before reading
any score it produces. Hand-injection is not the crude approximation of mutation
testing; it is what calibrates it.

Which cuts both ways. Everything above is a false *survivor* — a test that never
ran. But a reported *kill* can be as false: a test that never checked, credited to
the same mapping that elsewhere came back empty. Hand-injection is the ground truth
the tool only approximates, so a `Killed` is a claim until you have watched a named
test go red for that fault — reproduce the kills you rely on, not only the
survivors. The false kill is the worse one: a green survivor sends you to look,
while a green kill tells you to stop.

## Two tests that kill the same mutant are one test

Aim for **fewer tests, each closer to something a user actually does, covering
more.** Those three pull together rather than against each other: a test that
walks a real scenario crosses several decisions at once, so it kills more mutants
than the same effort spent on one narrow case per branch — and it is one thing to
update when the spec moves, not five.

So check it as you write, rather than assuming it and finding out at review. For
each test, ask which mutant it kills that nothing else kills — then confirm by
injecting that mutant and watching *this* test go red.

- None: it is duplication. Fold it into the scenario that already covers it.
- One, uniquely: keep the case, but prefer a `[Theory]`/parameterised case over a
  second test method. Two tests differing only in their input are one rule with
  two examples.
- Never delete on resemblance alone. Tests that read alike may drive different
  construction paths; the mutant question decides, appearance does not.

Beware the reverse failure. Collapsing tests by weakening what they assert also
drives the count down while coverage holds — and pins nothing. Fewer tests must
be the result of each one doing more, never of each one checking less.

This is "write the test against the rule, not the instance" applied while
writing.

## A surviving mutant may be the code talking

A survivor is not automatically a missing test. Before writing one — and *well*
before excluding a mutant class in config — ask whether it is pointing at surface
that decides nothing:

- An **equivalent** mutant (`x * 1` → `x / 1`) is dead arithmetic. It survives
  because it cannot change the answer, which is also why the code should not be
  there.
- A comparison that **cannot** change the answer is dead. Comparing fields that
  the type fixes to constants is a comparison of two things that are always equal.
- Surface beyond the contract invites survivors. A hand-written `GetHashCode`
  spraying every field through a hash has more moving parts than "equal objects
  hash alike" requires; the parts that no test can distinguish are the parts that
  earn nothing.

The exclusion hides it. The deletion fixes it — and the score rises because there
is less code, which is the better outcome twice over.

A survivor that decides nothing is one reading; a survivor that decides something
**unspecified** is the other. When a boundary mutant lives (`>` → `>=` holds), find
where the rule came from before pinning it: `> 10` versus `>= 10` may be an
assumption nobody made, and a test that freezes it encodes the accident as law. The
fix may be to correct the boundary, name the rule as its own policy, or delete a
decision another module already owns — not to add an assertion. And when killing one
boundary needs half the application stood up, the mutant is naming a **misplaced
responsibility**, not a missing test: extract the rule to a small object answerable
to one source of change, and the assertion that was impossible becomes trivial.

The score is a diagnostic, not the target. Chasing 100% with ever-narrower
assertions buys a suite welded to today's implementation that says little about what
the system must do. Killing a mutant is the by-product of pinning a real rule,
deleting dead surface, or moving a misplaced one — never the goal in itself.

Excluding a mutant class is legitimate only where killing it would assert
something you have decided not to own: the wording of an exception message, or a
guard whose behaviour belongs to the standard library. Say so where the exclusion
lives, or the next reader will read it as a lowered bar.

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
