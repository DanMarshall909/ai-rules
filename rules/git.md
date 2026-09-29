# Git Workflow

- Before work that may change a repository, fetch its remote and fast-forward-pull the checked-out tracked branch.
  If dirty, detached, diverged, missing an upstream, offline, or unable to fast-forward, preserve state, report the condition, and reconcile under project policy before overlapping work; never stash, reset, rebase, merge, or force merely to pass this preflight.
- Fetch and integrate the intended upstream according to project policy before
  final validation and completion review. Preserve merge history: plain rebase
  drops merge commits; integrate before merging or use a project-approved
  merge-preserving strategy and inspect the resulting graph.
- When work is complete and verified, ask the user for push approval and keep it explicitly unpublished until granted. After completion-review PASS and approval, fetch without pull/rebase/merge and require the recorded upstream object. Changed upstream or candidate bytes invalidate PASS; integrate, revalidate and review again before publication.
- Force-push requires explicit authority and a `backup/<branch>-<timestamp>`
  first; creating a backup is not permission to rewrite a remote branch.
- Review the staged diff before committing. Use present-tense, imperative commit
  messages explaining why. Never skip hooks unless explicitly asked.

## Trunk-Based Development

Keep trunk releasable and branches short-lived. Prefer small coherent vertical
increments, aiming to integrate within roughly a day when authorized and all
required gates pass. A time target or green build is not merge authorization.

Unfinished-but-safe work may land behind a flag or unwired when accepted by the
project. If an integration breaks trunk, restoring trunk outranks new work.
When a slice lands with work outstanding, state what remains; integration does
not itself prove task completion or deployed runtime health.
