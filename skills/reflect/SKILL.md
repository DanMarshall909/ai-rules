---
name: reflect
description: Capture durable lessons after finishing a piece of work. Run at the end of any non-trivial task — after the tests pass and the commit lands — to distil what would have changed the approach if it had been known at the start, and write it to memory. Also use when the user says "/reflect", "what did we learn", or asks to capture a lesson.
---

Finishing work is when the lesson is cheapest to see and most likely to be lost.
This skill turns a completed task into at most a couple of durable notes — and
usually into none at all.

**The bar is high on purpose.** Most tasks teach nothing worth keeping. A skill
that writes a memory every time produces a memory file nobody reads. Writing
nothing is the common, correct outcome. Say so plainly and move on.

## The test

A lesson is worth keeping only if it passes all three:

1. **Transferable.** It applies to work you haven't done yet, not just to this
   file. "The latency pass computes root latency from output sources" is a fact
   about the code. "A branch you believe is unreachable is a question about why
   the type doesn't know what you know" is a lesson.
2. **Non-obvious.** It would not have been your default. If you'd have done it
   that way anyway, it isn't a lesson.
3. **Load-bearing.** Knowing it at the start would have changed what you did.
   If it only explains what you did, it's a commit message, not a memory.

Ask directly: *if I'd known this before starting, what would I have done
differently?* If the answer is "nothing", there is no lesson.

## Where lessons come from

Look hardest at these, in order:

- **The user corrected you.** The strongest signal available. Especially when
  the correction was a *question* rather than an instruction — "if it's
  unreachable why is it there?" — because that means you had already talked
  yourself into something and needed to be stopped. Capture the correction and
  the reasoning error behind it, not just the fix.
- **You were wrong and the tooling proved it.** A test that failed the way you
  didn't predict. A coverage report that contradicted your reading. An
  assertion you had to weaken because the real behaviour was better than your
  guess. Record what you believed, and what was actually true.
- **You rationalized.** Any moment you defended a thing rather than fixing it —
  "justified but uncoverable", "defensive", "can't happen in practice". Those
  phrases are where lessons hide.
- **An invariant surfaced.** Something the code knew but the types didn't.

Do **not** mine: the diff, the architecture, the file layout, what a function
now does. Git records those, and they go stale. Memory is for judgment.

## Where it goes

Route on two axes: **must I obey it, or merely recall it?** and **does it bind
everywhere, or only here?** Memory is for judgment you should *remember*; a
rules file is for constraints you must *obey*. Answer both before writing.

| | Applies to any project | Applies to this repo only |
|---|---|---|
| **Must obey** | the global rules repo (`ai-rules/rules/*.md`) | repo `AGENTS.md` / `CLAUDE.md` |
| **Should recall** | a global skill under `ai-rules/skills/` | project memory directory |

The global rules and skills live in a checked-out repo (`~/code/ai-rules`),
included into `~/.claude/CLAUDE.md` by `@` import and symlinked into
`~/.claude/skills/`. Edit them there, and commit — a rule that only exists on
one machine is not a global rule.

A lesson about a *language or engineering habit* — how to treat an unreachable
branch, what a coverage gap means, when to reach for a type instead of a check —
is globally useful. Write it to the global rules. Do not leave it in a
project's memory just because that's where you learned it; the next project
needs it too, and memory is per-project.

A lesson about *this codebase's conventions*, its build, its domain constraints,
or the user's preferences for this work belongs in the repo rules file or
project memory.

**Sharpen before you append.** If an existing rule is what let you go wrong —
if you rationalized *within* its letter — amend that rule rather than adding a
contradictory one beside it. Two rules in tension teach nothing; the reader
obeys whichever they read last. Quote the old rule, show the amendment.

Editing global rules is a durable, cross-project change: propose it and get
agreement before writing, unless the user has already asked for it.

## Writing it

Check for an existing note or rule that already covers the ground — update it
rather than placing a duplicate beside it.

For memory: one fact per file, in the format already in use (`name`,
`description`, `metadata.type`, then body). For `feedback` and `project`, follow
the body with **Why:** and **How to apply:** lines. Link related notes with
`[[slug]]`. Then add the one-line pointer to `MEMORY.md`.

- `feedback` — how you should work; corrections and confirmed approaches
- `project` — goals or constraints not derivable from the code or git history
- `reference` — pointers to external resources
- `user` — who the user is

However it is stored, write the lesson so it **fires at the right moment**. Bad:
"be careful about unreachable code." Good: names the trigger ("when you're about
to write 'unreachable' in a comment") and the action ("ask why the type doesn't
carry the invariant"). A rule that doesn't say *when* it applies will never
apply. Prefer an ordered list of what to try to a statement of principle.

## Report

Tell the user what you kept and what you deliberately didn't, in a sentence or
two. If nothing met the bar, say that — it's information, not a failure.
