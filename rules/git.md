# Git Workflow

- `git pull --rebase` before every push
- Before force-push: create `backup/<branch>-<timestamp>` first
- Never commit without reviewing the staged diff first
- Commit messages: present tense, imperative, explain *why* not *what*
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
