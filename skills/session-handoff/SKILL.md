---
name: session-handoff
description: 'Use at root-session startup and substantive task completion or goal stop to read or replace the single archived project handoff; delegated agents hand back to their parent.'
---

# Session handoff

Keep one current recovery summary per project. The tracker remains authoritative
for live scope/status; the handoff records the verified snapshot and links it.
Use the installed `ai-handoff` command, or invoke this package's
[Bash entrypoint](scripts/ai-handoff.sh) through `bash` when PATH is unavailable.
Read [the command contract](references/command-contract.md) for failure recovery,
storage, role discovery or portability details.

## Establish your role first

The root coordinator is the top-level agent talking to the owner. A delegated
worker or nested coordinator remains delegated even when it manages children.
Follow the host's explicit assignment. Delegated agents use their assignment and
supplied context; return results, evidence, outstanding work and resource release
to their parent. Do not run project startup as a replacement for that assignment,
claim root ownership, or create/rotate the canonical handoff. Read it only when
relevant to your assigned work. The root incorporates useful handbacks.

Codex callers can inspect `ai-handoff role`: `root` exits 0, `delegated` exits 6,
and `unknown` exits 7. Writes check current-thread metadata automatically when
`CODEX_THREAD_ID` is set. Missing variables do not prove root status. Do not unset
the variable, supply someone else's identity or use offline metadata to bypass a
refusal. Outside Codex, `--owner <identity>` is an explicit assertion by the known
root/human; an agent of unknown role must obtain ownership from its coordinator.
Root classification does not grant project ownership or override an assignment.

## Fresh root-session startup

Before substantive work, run:

```bash
ai-handoff latest --project "$PWD"
```

Use the intended project path when starting elsewhere. Exit 3 means no current
handoff: consult relevant history/checkpoints and say that no canonical handoff
exists. Reads create no project state. Do not choose an archive as current.
Use `ai-handoff list --project "$PWD"` to inspect archive history when needed.

Give a short orientation: last relevant work and what was actually verified,
unfinished work/blockers, and one concrete recommended next goal with its reason
and completion condition. Revalidate mutable repository, tracker and process
facts. A recommendation does not start a new goal. Continue an already authorized
goal without repeating its scope approval. Do not reconstruct settled history.

## Root completion or goal stop

Write after completing a substantive task, stopping/suspending an active goal,
or transferring changed recovery context. Ordinary status replies and delegated
handbacks do not rotate the file. This narrow local metadata write is authorized
even during read-only work or a Git startup blocker; it grants no production,
tracker, branch-disposition or publication authority.

Prepare a compact Markdown file outside the managed state directory. Include:

- goal, accepted scope, why work stopped, and remaining authority;
- verified result and source candidate, with evidence links and explicit gaps;
- active checkout/worktree, branch, uncommitted work and authoritative tracker;
- unfinished work, blockers and decisions that remain with the owner;
- running commands/agents, recovery handles and resource ownership/release;
- one bounded next action, its prerequisites, and whether authorized or proposed.

Distinguish engineering completion, publication and owner acceptance. Unknown
checks remain unknown. Keep secrets, raw logs and large histories out of the
summary. Retain older detailed records as evidence rather than competing current
handoffs. Preserve task and evidence records under their existing ownership.

Read `latest` immediately before replacement and retain its revision. Then:

```bash
ai-handoff new --project "$PWD" --expect '<revision-from-latest>' --from /path/prepared.md
```

For initial creation use `--expect none`. Outside Codex, append
`--owner '<known-root-or-human-identity>'`. The tool archives the old bytes before
atomic replacement. `--from` accepts a completed file, avoiding partial pipeline
input. Never edit the current file or archives directly.

On a revision conflict, reread and reconcile changed context; never blindly retry
with a new token. A held lock needs verified owner/operation recovery, not an age
or missing-PID guess. Read back `latest`, verify the intended content and report
the current path. Retain prepared context and report a write failure explicitly.
