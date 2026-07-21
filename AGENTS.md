# AI Rules

Lean, agent-agnostic rules for any coding assistant.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: rules/*.md
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->

---

## Break Reminders

Remind the user to take a short break every 30 minutes during working hours (9am–5pm).

Every 2 hours, pause and run this check-in:

1. Ask: *"How is the session tracking against the goal?"*
   - On track
   - Slightly off — recoverable
   - Need to pivot

2. Ask: *"What's the focus after the break?"*
   - Continue current work
   - Start a new task
   - Review open issues
   - End session

3. Before the check-in, briefly scan all project memory/context files to surface anything relevant from other active work.

> Claude Code users: run `/break-reminders` at session start to automate this.

---

## TDD Protocol

**Tidy → Red → Green → Refactor → Coverage**

- Never write production code before a failing test exists
- Work one acceptance criterion at a time — no batching
- Commit at each phase: `test(red)`, `feat(...)`, `refactor(...)`
- After implementation: check coverage, run mutation testing if available
- End of session: offer to squash TDD commits into one

> Claude Code users: use the `/tdd` skill.

---

## Coverage & Dead Code

Aim for 100% coverage of core code through behaviour-driven tests that drive real
code paths and assert observable output.

### Code must justify itself

- Code that cannot be justified is removed, not covered. Code that exists only to
  be exercised by its own tests — no production callers — is not justified by
  those tests.
- Before deleting dead or unreferenced code, decide whether it is useful
  functionality that should be *wired up* rather than deleted (e.g. a correct
  primitive with no caller yet). Assess its value and propose wiring it up. Only
  delete genuine leftovers and duplicates. Never delete useful code to raise a
  coverage number.

### Compatibility code needs a real past

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

### Read the gap before you close it

An uncovered line means **that behaviour has never once executed**. It is a
statement about the code, not about the tests.

- If one half of a pair is covered and the other is not, the untested half is
  load-bearing code nobody has ever run. Symmetry gaps are the richest.
- Assert the behaviour the gap reveals, not the line.
- Assert what you believe, then let a failure correct the belief. Never weaken an
  assertion to match observed output without first understanding why it differs.

### Covered is not checked

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

### A surviving mutant may be the code talking

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

### Never call a branch unreachable

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

---

## Guardrails

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

### A guardrail must be able to fail

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

---

## Git Workflow

- `git pull --rebase` before every push — **except when pushing a merge commit**:
  plain `--rebase` silently discards merges, replaying their commits and throwing
  the merge (and its message) away. The push still succeeds, so the loss is
  invisible unless you look. Integrate *before* merging, or use
  `git pull --rebase=merges`, and verify with `git log --graph` before pushing
- Before force-push: create `backup/<branch>-<timestamp>` first
- Never commit without reviewing the staged diff first
- Commit messages: present tense, imperative, explain *why* not *what*
- Never skip hooks (`--no-verify`) unless explicitly asked

### Trunk-Based Development

Trunk is the single source of truth, and it is always releasable. Work merges
back within roughly a day — a branch that outlives that is the problem, not the
merge that follows it.

- Branch from trunk, keep it short-lived, merge back as soon as it is green
- Merge small vertical increments — a coherent, green, releasable slice beats a
  finished feature that sat unmerged for a week
- Never let a branch accumulate work that could have landed already; long-lived
  branches turn into merge risk and hide work from everyone else
- Unfinished-but-safe belongs on trunk behind a flag or simply unwired, in
  preference to a branch nobody can see
- Trunk stays green: if a merge breaks it, fixing trunk outranks whatever came
  next

Merging an increment does not mean the task is done. When a slice lands with
work still outstanding, say what is still missing rather than letting the merge
imply completion.

---

## Issue & Finding Tracking

All issues and security findings are documented as markdown files.

**Folder structure:**
```
docs/issues/
  open/[area]/[ticket-id]-[slug].md
  resolved/[area]/[ticket-id]-[slug].md
```

- `area` = business domain (api, auth, payments, pii, booking, database, …)
- Discover existing areas from the folder structure — don't hardcode them
- On resolution: update `status: Resolved`, add decision log entry, move to `resolved/[area]/`

> Claude Code users: use `/issue` and `/security-finding` skills.

---

## Reflection

When finished with a piece of work — tests green, commit landed — capture any
durable lesson before the context is lost. Writing nothing is the common,
correct outcome; most tasks teach nothing worth keeping.

A lesson is worth keeping only if it is **transferable** (about judgment, not
about this file), **non-obvious** (not what you'd have done anyway), and
**load-bearing** (knowing it at the start would have changed what you did).

Lessons hide in user corrections — especially corrections phrased as a question,
which mean you had already talked yourself into something — and in any moment you
defended code rather than fixing it.

Route each lesson to the scope it pertains to:

| | Any project | This repo only |
|---|---|---|
| **Must obey** | global rules file | repo `AGENTS.md` / `CLAUDE.md` |
| **Should recall** | global skill | project memory |

Do not leave a globally useful lesson in a project's memory just because that is
where you learned it. If an existing rule is what let you go wrong, amend that
rule rather than adding a contradictory one beside it.

> Claude Code users: use the `/reflect` skill.
