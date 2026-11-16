# Command and recovery contract

## Storage and installation

Git projects use `<git-common-dir>/handoff/HANDOFF.md`; linked worktrees and
branches share it. Archives live beside it in `archive/`, with an increasing
eight-digit sequence and unique suffix. They are Markdown bytes even though
the unique filenames have no `.md` extension. Separate clones have independent
local state. It is not transferred by ordinary Git clone/push or backed up by
the command. Preserve it explicitly for a device move.

Non-Git use requires `--project PATH` and stores `.handoff/HANDOFF.md` and
`.handoff/archive/` there. The command prints the resolved current path and never
overwrites a pre-existing project-root HANDOFF.md. Managed symlinks or unexpected
file types are rejected. New directories/files use private permissions. There
is no automatic project discovery outside Git and no global project registry.

From a durable ai-rules checkout, preview and install:

```bash
scripts/install-handoff.sh --dry-run
scripts/install-handoff.sh
scripts/install-skill.sh --dry-run session-handoff
scripts/install-skill.sh session-handoff
command -v ai-handoff
```

The command is a live symlink in `$HOME/.local/bin` by default. Use
`--bin-dir /chosen/bin` for another location, and put it on PATH. Unmanaged
destinations are preserved. Git Bash needs native symlink support for this
installer; invoke `bash /durable/checkout/skills/session-handoff/scripts/ai-handoff.sh`
directly if unavailable. Base-rule installation also includes this skill, but
command installation is explicit. Do not replace project-owned profile files.
Filesystem installation does not prove a running client refreshed its skills.

## Output and exits

`latest` prints `Current:`, `Revision:`, a blank line, then exact document bytes.
The revision and document come from one captured read. `list` prints the current
path/revision followed by archive paths newest first. Absence is explicit; an
archive never becomes the current handoff implicitly. `new` prints the current
path/revision/owner only after replacement. Diagnostics go to stderr.

| Exit | Meaning |
|---|---|
| 0 | Successful read/list/write, or confirmed root role |
| 1 | I/O, installation or cleanup failure |
| 2 | Invalid arguments, prepared text, or unsafe managed paths |
| 3 | No current handoff |
| 4 | Lock held; no automatic lock breaking |
| 5 | Expected revision differs; reread and reconcile |
| 6 | Delegated caller or mismatched root identity; write refused |
| 7 | Role/ownership unknown; automatic write refused |

The opaque revision is POSIX `cksum` CRC plus byte count. It detects accidental
stale writers; it is not cryptographic identity or an authorization token.

## Atomicity and recovery

The source must be a readable, nonempty, non-whitespace regular text file without
NUL bytes. It is staged completely in the state directory. A short `mkdir` lock
serializes the revision check, independent archive copy and current replacement.
The archive is published with an exclusive hard link from its completed temporary
copy, then the new file replaces current by rename on the same filesystem.
Archive hard links must be supported on that filesystem. The archive and current
do not share file content storage identity; changing current cannot alter history.

Readers see complete old/new current bytes, with no normal rotation gap. A crash
or failed replacement after archive publication can leave a redundant archive of
the still-current handoff; preserve it. A crash after replacement can commit a
new current without returning a receipt; inspect `latest` before retrying.
The same applies to a receipt-output or lock-cleanup error after commit; do not
assume every nonzero exit means no state changed.
No power-loss/fsync durability or protection against a hostile filesystem actor
racing shell checks is claimed.

The lock's `owner` file records session identity and writer PID. On interruption,
verify the owning session and operation have actually stopped before manually
removing only that lock's known files/directory. Age or a missing PID alone is not
enough. Temporary files are private and operation-owned; normal exits clean them
and release only the acquired lock. Cleanup errors are reported.

## Codex adapter

The core targets Bash 3.2 with common POSIX utilities (`mktemp`, `cksum`, `cat`,
`sort`, `ln`, `mv` and ordinary file utilities); Git is required for
Git projects. It has no Python dependency. The optional Codex adapter additionally
requires `codex`, `jq` and POSIX named pipes. Native Windows adapter behavior is
unverified; unavailable named pipes produce `unknown`, never root.

The adapter starts an owned, short-lived App Server stdio reader in a private
empty directory. It requests only `initialize`, `initialized`, `thread/read` for
the exact current `CODEX_THREAD_ID`, then stops the reader and removes its private
temporary directory. No model turn or thread start/resume is requested. Discovery
has a five-second response deadline and bounded shutdown. No daemon configuration
or persistent API service is installed.

An explicit parent or subagent source means delegated. Explicit null parent with
a recognized non-subagent source means top-level; missing, mismatched, malformed
or unsupported metadata means unknown. `forkedFromId` is history lineage, not
delegation. The versioned [Codex Thread schema](https://github.com/openai/codex/blob/rust-v0.169.0/codex-rs/app-server-protocol/schema/typescript/v2/Thread.ts)
and [thread/read protocol](https://learn.chatgpt.com/docs/app-server#read-a-stored-thread-without-resuming)
describe these fields. Host assignments remain authoritative even for an external
agent invocation that Codex itself sees as a separate top-level thread.

`role --metadata RESPONSE.json --thread ID` classifies an offline response for
inspection/tests. This cannot authorize `new`: metadata/thread overrides are
rejected for writes, which query the actual current Codex thread. Outside Codex,
`--owner ID` records an explicit known root/human assertion, not detected identity
or a security boundary. Do not use it to upgrade an unknown/delegated agent.
