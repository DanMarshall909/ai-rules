# Tool Repo Rules

For repos whose product is a tool an agent drives.

This set extends [ai-rules.md](ai-rules.md) rather than replacing it. Read both.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: rule-sets/tool-repos.set and the rules/ files it lists
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->

---

## The Output Is An API

The users of a tool an agent drives are programs. Whatever the tool prints is
parsed by something that cannot ask what was meant, so the output is an
interface, and changing it is a breaking change — even when it reads better.

- **Results on stdout, everything else on stderr.** Progress, warnings and
  timings mixed into stdout corrupt the payload of every caller that pipes it.
- **Failure is the exit code.** An error printed while exiting 0 is invisible to
  the only check a script reliably makes. Never report a failure by wording
  alone.
- **Deterministic by default.** Ordering, timestamps, absolute paths and
  parallel interleaving are the usual sources of output that differs run to run;
  a caller diffing two runs cannot tell that noise from a real change.
- **Non-interactive by default.** A prompt in an automated run is a hang, and a
  hang is the most expensive failure there is: nothing reports it.
- **Structured output is a mode, not a debug flag.** If agents are expected to
  parse it, it is specified and tested like an API.

The reason this needs stating: the tool is developed by watching it in a
terminal, where all five read as cosmetic preferences. They are only visibly
load-bearing from inside the caller, and the caller is not in the room.

### Changing it

Know who reads the output before changing it. Inside the repo that is the
callers you can grep for; past a release it is callers you cannot see, and the
change needs a flag or a version. Renaming a field "while we are in here" is the
same act as renaming a public method, minus the compiler.

A test that parses the tool's output with a hand-rolled reader will not catch
any of this: the reader is written to match what the code emits today, so it
agrees with whatever the code does next. Parse with the reader the real consumer
uses; apply the `coverage-and-mutation` skill to check the strength of that evidence.

---

## Thin Hosts Over One Service Layer

A tool that agents drive grows more than one front door: a CLI, an MCP server,
an editor plug-in, a scheduled job. Each of those is a **host adapter** — it
parses its own kind of input, calls one service, renders the result, and holds
no logic of its own.

- The service layer takes request objects and returns results. It knows nothing
  about argument parsing, consoles, transports or exit codes.
- A capability lives in one place and every host reaches it. A feature that
  exists only in the CLI is a feature agents on the other host do not have, and
  nobody notices, because each host looks complete from inside itself.
- Adapters stay boring enough that nobody argues about whether to test them: the
  behaviour worth asserting is in the service.

The failure this prevents is duplication that reads as convenience. A validation
rule written into the CLI handler because that is where the bug was reported now
exists in one host and not the others, and the copies drift in the direction of
whoever last touched them.

Presentation — colour, table widths, a progress spinner — belongs to the host.
Everything that decides *what the answer is* belongs to the service.

### The tell

If adding a capability to the second host means copying anything beyond argument
wiring, the service does not yet own what it should. Move the decision down
rather than writing it twice; an assertion that needed a whole host stood up
becomes trivial once the rule lives in a small object of its own
(use the `coverage-and-mutation` skill to assess the evidence).

---

## Assume Parallel Invocation

A tool an agent drives is run by several agents at once — separate worktrees,
separate sessions, the same machine and often the same second. Anything the tool
writes outside its own process is shared state, and shared state written by two
runs at once is corrupt state.

Treat as shared until proved otherwise: caches, indexes, build intermediates,
log and report files, lock files, temporary directories on a fixed path,
anything appended to, and anything named after the tool rather than the run.

Two ways to be safe, in order of preference:

1. **Scope it to the invocation.** A path that includes the run's own identity
   cannot be contended. This is almost always cheaper than coordinating.
2. **Make the write atomic.** Write to a temporary file and rename, or append a
   whole record in one call. Read-modify-write of a shared file is the shape
   that loses data, and it loses it silently.

The reason this is worth a rule: concurrency bugs here do not fail loudly. Two
runs interleave into one truncated log, or one clobbers the other's output, and
what the agent reads back is plausible — just wrong. It reproduces only under
load, which is exactly when nobody is watching.

### Testing it

Assert the property, not the timing: run the operation from several processes
at once and check every record survives. A test that runs the tool twice in
sequence proves nothing about the case that breaks.

---

## Use The Tool On Itself

Work in this repo with the tool this repo builds. It is the only place where the
people changing it are also the people it fails.

- When a task in this repo is easier *without* the tool, that is a defect
  report, not a workaround. Write it down before reaching for the manual route,
  because the reason will be gone in ten minutes.
- The awkwardness worth recording is rarely a missing feature. It is usually an
  answer that needed three commands, an error that did not say what to do next,
  or output that had to be re-read by hand.
- A tool nobody drives from inside its own repo is specified entirely by its
  authors' imagination of a user.

### The command reference is generated

Agents need a description of the tool's surface to use it without exploring, and
it must come **from the tool** — its own help or schema output — never from a
hand-maintained copy.

A hand-written reference is wrong from the first flag that changes, and it is
wrong invisibly: the agent obeys the document, the tool rejects the call, and
the failure looks like the agent's mistake. Generate it, and regenerate it in
the same change that alters the surface.

The same goes for anything else describing the tool to a caller: examples in the
README, skill files, MCP tool descriptions. Whatever cannot be generated has to
be checked by something that runs — a test that the documented commands still
exist is cheap, and it is the only thing standing between a rename and a fleet
of agents calling a flag that is gone. Apply the shared Guardrails rule: wire the
check into the pipeline and verify it fails for the named contract violation.
