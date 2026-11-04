# Git Workflow

- `git pull --rebase` before every push — **except when pushing a merge commit**:
  plain `--rebase` silently discards merges, replaying their commits and throwing
  the merge (and its message) away. The push still succeeds, so the loss is
  invisible unless you look. Integrate *before* merging, or use
  `git pull --rebase=merges`, and verify with `git log --graph` before pushing
- Before force-push: create `backup/<branch>-<timestamp>` first
- Never commit without reviewing the staged diff first
- Commit messages use a short, specific, imperative subject and a body that
  records why the change was needed, what changed, how it was verified, and
  important constraints or follow-up. Do not create a subject-only commit
  unless the user explicitly requests one
- Never skip hooks (`--no-verify`) unless explicitly asked

## Trunk-Based Development

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

## Worktree Placement and Preservation Archives

On Windows, keep primary checkouts outside the shared worktree root. Place every
linked task worktree under exactly one owner namespace:

- personal repositories: `D:\worktrees\personal\<repository>\<task-slug>`;
- Rapid Circle repositories: `D:\worktrees\rc\<repository>\<task-slug>`.

Do not create linked worktrees beside a repository, inside a repository, under
artifacts or temporary directories, or under a second worktree root. Resolve
the absolute target path and confirm it is unused before creating a worktree.
Treat pre-existing worktrees elsewhere as legacy exceptions: inventory and
preserve them, then migrate or remove them only in an explicitly authorized
cleanup task. Do not bulk-relocate them merely to adopt this convention.

When the user decides that unintegrated work must be preserved rather than
merged, retain its exact tip under `archived/<original-branch-name>`. Record the
archive in the durable deferral ledger and verify that its commit is reachable
from the intended remote before treating preservation as complete. An archive
name alone does not resolve deferred work.

Routine cleanup must exclude remotely preserved `archived/*` refs and their
worktrees. They remain visible to the active-work gate and ledger review, but
are not deletion, rename, integration, or replay candidates unless the user
explicitly targets that archive.
