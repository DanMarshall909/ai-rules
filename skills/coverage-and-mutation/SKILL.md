---
name: coverage-and-mutation
description: Use when reviewing coverage, mutation-test results, dead code, compatibility paths, or the strength and uniqueness of tests. Separates executed code from asserted behavior and treats surviving mutants as design evidence.
---

# Coverage & Mutation Analysis

Aim for 100% coverage of core code through behaviour-driven tests that drive real
code paths and assert observable output.

For review-only requests, report evidence and propose changes; do not implement
deletions or tests without authority. Scores never expand the accepted scope.

When this skill is used through `agentic-delivery`, first read its matching
environment modules. Mutation implementations are not flag-compatible:
Stryker.NET `--since` produces a changed-mutant subset, while StrykerJS
`--incremental` reuses an incremental report and still produces a full report.
Prefer repository-local drivers and verify options against the installed
version.

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

An uncovered line did not execute in the measured run, assuming the collector
and source mapping are sound. It says nothing about all past tests or runtime
use. Record the run's scope and exclusions before interpreting the gap.

- If one half of a pair is covered and the other is not, the untested half is
  a candidate gap in that run. Investigate the missing behavior and test scope.
- Assert the behaviour the gap reveals, not the line.
- Assert what you believe, then let a failure correct the belief. Never weaken an
  assertion to match observed output without first understanding why it differs.

Classify each uncovered block:

- Useful behavior or a meaningful failure mode: protect it through an observable
  contract, including boundary and error cases.
- Unused API or convenience code: check real callers, released contracts and
  accepted near-term consumers before proposing removal.
- Generated, vendored or external boundary code: apply the project's declared
  exclusions, but do not exclude owned decisions merely because they live at an
  entrypoint or adapter boundary.
- Defensive or apparently unreachable code: establish its invariant and public
  reachability before simplifying or documenting an exclusion.

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

Read the **status breakdown, not the score**. A large "no coverage" bucket can
mean genuinely unreached code, mismatched run scope, or broken attribution.
Distinguish those using baseline coverage and a hand-injected fault in the same
scope. A contradiction with direct observation warrants investigating the
instrumentation and run configuration, not automatically adding tests.

Where supported, running the full suite per mutant can diagnose attribution
failures. It does not fix genuinely unexecuted code. Verify the installed tool's
mode and cost before launching a potentially much slower run.

**Coverage first, then mutation.** They answer questions in order — coverage asks
whether a line ran in scope, mutation asks whether tests detect changed behavior.
Separate unreached code from executed-but-unchecked behavior. Establish coverage,
and confirm the mutation tool can kill a fault you planted yourself, before reading
any score it produces. Hand-injection is not the crude approximation of mutation
testing; it is what calibrates it.

That ordering is between the two *questions*, not a schedule. It does not mean
mutation belongs at the end, after the feature is finished and the design has set.
Run it as soon as a slice is green and its lines are covered — the report's design
signal is worth the most while the design is still soft enough to act on. See
"Read the whole report early" below.

Which cuts both ways. Everything above is a false *survivor* — a test that never
ran. But a reported *kill* can be as hollow: a test that failed without checking the
mutated behaviour — a timeout or a crash the tool scores as a kill — or a runner
that cannot say which test did the killing and attributes it anyway. Hand-injection
is the ground truth the tool only approximates, so a `Killed` is a claim until you
have watched a named test go red for that fault — reproduce the kills you rely on,
not only the survivors. The false kill is the worse one: a green survivor sends you
to look, while a green kill tells you to stop.

## Mutation overlap is evidence, not test identity

Two tests can kill the same generated mutants while protecting different input
classes, failure modes, contracts or integration boundaries. A finite operator
set cannot enumerate every regression. No unique mutant is not proof that a test
is redundant.

Use the four test-quality criteria in `behavior-first-tdd`. For each proposed
consolidation, identify the observable protection and layer each test contributes.
Retain distinct boundary, regression and cross-system evidence. Parameterize
cases sharing one contract when that improves clarity; do not combine unrelated
promises merely to reduce test count.

Confirm a claimed unique kill with a fault that reaches the owning code and
makes the named test fail for the intended reason. Remove a test only when its
useful protection is demonstrably retained elsewhere, without weakening the
oracle or hiding which case failed.

## A surviving mutant may be the code talking

A survivor is not automatically a missing test. Before writing one — and *well*
before excluding a mutant class in config — ask whether it is pointing at surface
that decides nothing:

- An **equivalent** mutant cannot change observable behavior over the valid
  input domain. That does not prove the original code is unnecessary: a mutation
  can preserve behavior in essential code. Establish equivalence and separately
  assess whether a simpler implementation preserves all relevant contracts.
- A comparison that **cannot** change the answer is dead. Comparing fields that
  the type fixes to constants is a comparison of two things that are always equal.
- Surface beyond the contract invites survivors. For a hash implementation,
  inspect equality, distribution, performance and any persisted-format contract
  before simplifying it. Merely preserving "equal objects hash alike" does not
  make a constant hash a good implementation.

Delete or consolidate only when that contract analysis justifies it. A documented
equivalent-mutant exclusion is legitimate when useful code remains; an exclusion
must not conceal an untested observable difference.

A survivor that decides nothing is one reading; a survivor that decides something
**unspecified** is the other. When a boundary mutant lives (`>` → `>=` holds), find
where the rule came from before pinning it: `> 10` versus `>= 10` may be an
assumption nobody made, and a test that freezes it encodes the accident as law. The
fix may be to correct the boundary, name the rule as its own policy, or delete a
decision another module already owns — not to add an assertion. And when killing one
boundary needs half the application stood up, investigate a **misplaced
responsibility** as well as a missing integration test. Extract a policy when it
has one source of change; retain cross-boundary tests for genuinely integrated
behavior.

The score is a diagnostic, not the target. Chasing 100% with ever-narrower
assertions buys a suite welded to today's implementation that says little about what
the system must do. Killing a mutant is the by-product of pinning a real rule,
deleting dead surface, or moving a misplaced one — never the goal in itself.

Excluding a mutant class is legitimate only where killing it would assert
something you have decided not to own: the wording of an exception message, or a
guard whose behaviour belongs to the standard library. Say so where the exclusion
lives, or the next reader will read it as a lowered bar.

## Read the whole report early — it is a design review

Run mutation analysis early in a green, coverage-understood slice, rather than
only at the final release gate. Its most valuable output is not the score: it maps
which code nothing can distinguish — and that is a finding about the design, worth
having while the design is still cheap to change. A report read after the feature is
finished can still improve the design, but earlier feedback is cheaper to use.

**Read it by clustering survivors across files, not file by file.** One survivor is a
question about one test. The *same survivor shape* in seven types is a question about
the code. That cluster is invisible if you only inspect the survivors your own diff
introduced, which is the natural and the wrong way to read a report.

Three things a cluster means, each with a different fix:

- **Repeated surface beyond the contract.** Similar survivor patterns across
  hand-written equality or hashing implementations may suggest a shared primitive.
  Confirm that contracts and reasons to change align before consolidating; similar
  mutation reports alone do not prove the implementations are interchangeable.
- **Genuinely equivalent.** Separate an equivalent mutation from redundant
  production logic; branch agreement at one boundary does not prove the whole
  branch is dead. Simplify only after checking the full valid input domain.
- **Not executed in this run.** Check instrumentation, run scope and the accepted
  behavior before deciding whether the gap needs a test, wiring or removal.
  Lack of execution evidence is not proof that the feature never worked.

**A survivor can lie about which bucket it is in**, and it lies toward "equivalent",
the bucket easiest to dismiss. A mutant that flips *both* sides of the
comparison a test makes leaves the two still agreeing: the test stays green, the
mutant looks like it cannot change the answer, and nothing is pinned. Symmetry
assertions are the usual shape — `f(a, b)` equals `f(b, a)` holds just as well when
the operands are swapped inside. Before filing a survivor as equivalent, ask what
downstream depends on the value the test declined to name: a persisted format, a
serialised order, an on-the-wire shape. Equivalence requires unchanged relevant
observable behavior over the valid input domain, not merely tests that still agree.

That last one is "Covered is not checked" arriving by a different road — consistency
among outputs is not correctness — found by reading the report rather than by reading
the test.

## Establish reachability before excluding a branch

An apparently unreachable branch may signal an invariant that the type does not
carry. Before writing "unreachable", "defensive", or "justified but uncoverable",
investigate these simplifications and the actual public input domain:

1. **Carry the value forward.** An earlier step proved the lookup succeeds, then
   threw the result away. Keep it instead of looking it up twice.
2. **Remove the impossible variant.** An `Option`/`Result` that no path returns
   may be unnecessary. Change the return type only if owned callers and public
   contracts permit it.
3. **Make a silent skip a loud failure.** A lookup that quietly does nothing when
   it misses will emit a *wrong answer* if the invariant ever breaks.
   Prefer an explicit invariant failure or domain error appropriate to the
   boundary. Moving a panic into a library is not a reason to avoid testing the
   required failure behavior.
4. **Re-derive reachability from the public API.** Challenge the assumption.
   Boundary lookups, `?`-paths on public methods, and "obviously valid" inputs
   are typically reachable and merely untested.

If the branch remains necessary but cannot be exercised in the supported test
environment, document the invariant, measurement limit and remaining risk. Use
only project-approved exclusions; lack of a convenient test does not itself
prove unreachability.
