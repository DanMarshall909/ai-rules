# Git Workflow

- Before work that may change a repository, fetch its remote and fast-forward-pull the checked-out tracked branch.
  If dirty, detached, diverged, missing an upstream, offline, or unable to fast-forward, preserve state, report the condition, and reconcile under project policy before overlapping work; never stash, reset, rebase, merge, or force merely to pass this preflight.
- Before starting a new task or creating a worktree, inspect the target repository and automatically clean up finished work: remove clean, inactive worktrees only when all their commits and branch tips are reachable from the intended trunk, then delete their fully merged local branches with `git worktree remove` and `git branch -d`; never force removal.
  Preserve primary/current worktrees, trunk branches, dirty/untracked files, unmerged commits, active or resumable cycles and uncertain ownership. Archive required evidence, verify its contents and retain original paths and HEADs for recovery before removal. Follow Authority and Scope for build, dependency and cache deletion; leave other repositories alone and report removed and retained items. Unsafe or unavailable cleanup does not block unrelated new work.
- During authorized repository changes, maintain tracked `.ai-rules.json` with `schemaVersion: 1` and `resources.memory`: a positive `reserveMiBPerActiveWorktree` and `basis` of `measured` (requiring `observedPeakMiB` and `measurement` with workload, date and evidence) or `estimated` (requiring `estimateReason`). See `docs/repo-config.md` in the source checkout for the full format; replace an estimate when representative measurements arrive.
- Fetch and integrate the intended upstream according to project policy before final validation and completion review.
  Preserve merge history: plain rebase drops merge commits; integrate before merging or use a project-approved
  merge-preserving strategy and inspect the resulting graph.
- Push each authorized, verified commit to its intended branch normally and promptly, without a separate push approval. Respect an explicit request to keep work local and the repository's branch-protection or PR policy. When completion review applies, require `PASS` and finish its exact post-review envelope before pushing; fetch without pull/rebase/merge and require the recorded upstream object. Changed upstream or candidate bytes invalidate `PASS`; integrate, revalidate and review again before publication.
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
