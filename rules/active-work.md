# Active Work Gate

Fail closed before changing a repository. Read-only inspection needed to run
this gate is allowed; repository mutations are not.

The gate covers every worktree that shares the target repository's Git common
directory. A workspace-wide maintenance task covers every repository in its
stated scope.

## Inspect before mutation

1. Resolve the repository root, Git common directory, remotes, and intended
   base branch. Read `<git-common-dir>/agent-work/deferred-work.md` when it
   exists.
2. List every registered worktree. For each one, record its absolute path,
   branch or detached commit, upstream, and complete staged, unstaged, and
   untracked state. Also inspect local branches, tracking and divergence,
   stashes, ancestry and patch identity against a current base, and relevant
   open code reviews when available.
3. Repeat the worktree list and complete status snapshot immediately before
   the first mutation. If anything changed between snapshots, assume another
   user, agent, editor, hook, or process is active and stop.
4. Repeat the check before destructive actions, integration, publication, and
   handoff. A snapshot is evidence about one moment, not a lock.

Use `scripts/get-worktree-summary.ps1` when available to gather the mechanical
part of this evidence. Its report assists judgment; it does not decide whether
work is valuable or safe to discard.

## What blocks work

Treat all of the following as active or unresolved:

- staged, unstaged, or untracked files;
- commits not integrated or verified patch-equivalent to the intended base;
- ahead, divergent, local-only, or missing-upstream branches;
- open or draft code reviews;
- stashes;
- detached work not proven contained;
- locked, missing, or inaccessible worktrees;
- state that changes during inspection; and
- every open deferred-work ledger entry.

If any item exists, block unrelated implementation, new worktrees, branch
switching, integration, publication, and cleanup. While blocked, proceed only
with read-only investigation or actions the user explicitly authorizes to
preserve or resolve the identified item.

Report the exact path, branch or commit, dirty/divergence summary, owner or
session when known, and preservation risk. Never infer that generated files,
archives, old branches, or another session's work are disposable.

Work may continue only after the user explicitly chooses how each blocker is
addressed:

- finish and integrate it;
- preserve it with a commit and appropriate upstream or archive branch;
- discard it with explicit authorization; or
- defer it.

Silence, a generic cleanup request, an earlier handoff, or an archive-like name
is not authorization.

## Durable deferral ledger

Deferral does not resolve active work. Before proceeding after an explicit
deferral, create or update
`<git-common-dir>/agent-work/deferred-work.md`. Keeping the ledger under the Git
common directory makes it visible from every linked worktree without adding it
to a product repository.

Keep one durable entry per item containing:

- a stable identifier and `OPEN` or `RESOLVED` status;
- first-seen and last-reviewed timestamps;
- repository common directory and worktree path;
- branch or detached commit;
- staged, unstaged, and untracked summary;
- upstream, divergence, related review, and stash;
- known owner or session and preservation risk;
- the user's explicit decision and reason for deferral; and
- the exact next action required.

Never delete entries. Mark an item `RESOLVED` only after recording evidence
that it was integrated, pushed or otherwise durably preserved, or discarded
with explicit user authorization. An archive branch alone is not proof of
preservation; verify commit reachability and the intended remote state.

At the start of every later session, every `OPEN` item is a mandatory blocker
again. Reconcile it with current repository state and require an explicit user
decision to resolve it or continue the deferral. Continuing a deferral must
update its last-reviewed time, current evidence, and new explicit decision; it
must never roll forward silently.

If work is known or reported to have been deferred but its entry is missing,
unreadable, stale, inconsistent with repository state, or cannot be updated,
fail closed. A repository in which no deferral has ever been identified does
not need an empty ledger.
