# Thin Hosts Over One Service Layer

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

## The tell

If adding a capability to the second host means copying anything beyond argument
wiring, the service does not yet own what it should. Move the decision down
rather than writing it twice; an assertion that needed a whole host stood up
becomes trivial once the rule lives in a small object of its own
(use the `coverage-and-mutation` skill to assess the evidence).
