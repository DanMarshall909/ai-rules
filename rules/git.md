# Git Workflow

- **Sync first**: Before changes, fetch and fast-forward-pull the tracked
  branch. If dirty, detached, diverged, offline, or unable to fast-forward,
  preserve state and report—never stash, reset, rebase, or force to pass.
- **Unfinished work gate**: Before new independent work or a new worktree,
  inventory local branches, worktrees, and active feature branches after
  fetching. Unintegrated work blocks new independent work unless explicitly
  parked or designated as a spike in this session or the tracker.
- **Cleanup & storage**: Use `worktree-cleanup-audit` for merged-worktree
  cleanup (never force-remove). Maintain `.ai-rules.json` with `storage-budget`
  and check headroom before heavy builds/restores/tests; insufficient headroom
  blocks only that operation.
- **Integration & push**: Integrate upstream preserving merge history before
  final verification and completion review. Push authorized verified commits
  promptly; if completion review applies, require `PASS` on the exact unchanged
  head and upstream before pushing.
- **History & commits**: Force-push requires explicit authority and a
  `backup/<branch>-<timestamp>` first. Review staged diffs, write imperative
  "why" commit messages, and never skip hooks unless asked. Keep trunk
  releasable with short-lived branches.
