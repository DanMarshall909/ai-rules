# Git Workflow

- Before work that may change a repository, fetch its remote and fast-forward-pull the checked-out tracked branch.
  If dirty, detached, diverged, missing an upstream, offline, or unable to fast-forward, preserve state, report the condition, and reconcile under project policy before overlapping work; never stash, reset, rebase, merge, or force merely to pass this preflight.
- Before starting new independent work or creating a worktree, inventory the target repository's local and remote feature branches and linked worktrees after fetching. Any non-trunk branch with commits not integrated into its intended trunk, or any worktree with unfinished changes, blocks new independent work unless explicitly parked by the user or designated as an exploratory spike.
  Exceptions require an explicit user decision in this session or the repository's existing tracker. Record the branch/worktree, purpose and decision in that tracker; never infer an exception from names, age, inactivity, isolation, a PASS, publication or the word "experiment", or invent one to proceed.
  Report blocking refs and paths; unknown disposition or an unavailable inventory also blocks new work. Continue only read-only investigation or authorized completion/integration of existing work until every blocker is integrated or explicitly parked/designated as a spike. The gate does not itself authorize merging, deleting or parking work.
- Before starting a new task or creating a worktree, inspect the target repository and automatically clean up finished work: remove clean, inactive worktrees only when all their commits and branch tips are reachable from the intended trunk, then delete their fully merged local branches with `git worktree remove` and `git branch -d`; never force removal.
  Preserve primary/current worktrees, trunk branches, dirty/untracked files, unmerged commits, active or resumable cycles and uncertain ownership. Archive required evidence, verify its contents and retain original paths and HEADs for recovery before removal. Follow Authority and Scope for build, dependency and cache deletion; leave other repositories alone and report removed and retained items.
- Maintain tracked `.ai-rules.json` during authorized repository changes: `schemaVersion: 1` remains valid with `resources.memory`, a positive `reserveMiBPerActiveWorktree`, and `basis: estimated` plus `estimateReason`, or `basis: measured` plus `observedPeakMiB` and dated workload/evidence in `measurement`. Version 2 retains memory and adds `resources.disk.workloads`; use `storage-budget` for disk fields and validation. Replace estimates after representative measurement; the source checkout documents the full format in `docs/repo-config.md`.
- Before a heavy build, restore, test or other output-producing operation, use `storage-budget` to check its actual output and temporary volumes against the workload growth estimate and free-space reserve. Missing or insufficient headroom blocks that operation, not unrelated work. Preserve shared caches and existing output; storage measurements do not authorize removal.
- Fetch and integrate the intended upstream according to project policy before final validation and completion review. Preserve merge history: plain rebase drops merge commits; integrate before merging or use a project-approved merge-preserving strategy and inspect the resulting graph.
- Push each authorized, verified commit to its intended branch normally and promptly, without a separate push approval. Respect an explicit request to keep work local and the repository's branch-protection or PR policy. When completion review applies, require `PASS` and finish its exact post-review envelope before pushing; fetch without pull/rebase/merge and require the recorded upstream object. Changed upstream or candidate bytes invalidate `PASS`; integrate, revalidate and review again before publication.
- Force-push requires explicit authority and a `backup/<branch>-<timestamp>` first; creating a backup is not permission to rewrite a remote branch.
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
