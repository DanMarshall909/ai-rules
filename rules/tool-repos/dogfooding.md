# Use The Tool On Itself

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

## The command reference is generated

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
