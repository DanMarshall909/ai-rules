---
name: worktree-cleanup-audit
description: Scan code and worktree roots, then report Git-merged cleanup candidates and repository state that needs investigation.
---

# Worktree Cleanup Audit

Produce a preservation-first Markdown report of repositories, linked worktrees,
and local branches. The report identifies Git-clean candidates and work that
needs investigation. Treat Git evidence as a candidate list; complete the
repository, remote, pull request, deferred-work, evidence, and active-use checks
before any removal.

---

## Run the report

1. Read the repository's `AGENTS.md` and cleanup policy. Choose explicit scan
   roots that cover the code and worktree folders in scope. On this Windows
   setup, that is commonly `D:\code` and `D:\worktrees`.
2. Run the report script from the AI Rules checkout:

   ```powershell
   .\scripts\report-worktree-cleanup.ps1 -Root 'D:\code','D:\worktrees'
   ```

   Add `-OutputPath <path>` to save the Markdown report. The script does not
   remove files, worktrees, or branches. It skips generated and dependency
   directories such as `.git`, `node_modules`, `bin`, and `obj`, and it does not
   follow directory links. Discovery stops at a Git root and uses registered
   worktrees. Parent discovery is capped by depth, directory count and elapsed
   time; incomplete discovery is explicit. Pass nested repositories explicitly.

   Add `-Storage` for bounded logical sizing of registered worktrees and
   `-OutputRoot <path>` for explicitly declared output directories. Python 3.10+
   is required only for this option; `-PythonCommand` selects its executable.
   The report separates source/build/dependency/evidence/unknown categories,
   reports shared entries and incomplete scans, and leaves reclaimable space
   unknown. It does not add any removal authority. `-StorageMaxDepth`,
   `-StorageMaxEntries` and `-StorageMaxSeconds` control the bounds. Follow the
   installed `storage-budget` skill for budget admission and fresh disposable
   output, not automatic deletion of these existing candidates.
3. Use `-Fetch` only when a fresh `origin` tracking ref is needed. It fetches
   from `origin` without pruning remote refs. If a fetch fails, or the report
   lists an incomplete inventory, preserve the affected items and report the
   gap.
4. Read the full report. A **Git cleanup candidate** is clean and has its
   worktree HEAD and local branch tip reachable from the locally recorded
   `origin` default-branch ref. A **Git-merged local branch** is not checked
   out and its tip is reachable from that ref. Dirty, detached, locked,
   deferred, unique, or unverifiable state is listed for investigation.
   `archived/*` worktrees and branches are listed under retained archived work
   and excluded from cleanup candidates.

---

## Verify candidates before removal

For each candidate, inspect it independently. Do not treat a report row as
permission to remove it or proof that every cleanup gate passed.

- Confirm the intended trunk from the freshly fetched remote default branch.
  Verify both the checked-out HEAD and the local branch tip are integrated.
  The script uses ancestry, so a squash-merged branch whose commits are not
  ancestors remains an investigation item until PR and patch-identity evidence
  proves integration.
- Check the common Git directory's `codex/deferred-work.md`. Any matching
  `OPEN` item must be resolved with its preservation requirements before
  cleanup. Leave unrelated entries alone.
- Check GitHub or the repository's declared PR system for open and draft PRs.
  A missing CLI, unavailable service, or unknown PR state is not evidence that
  no PR exists. Confirm required commits or patches are preserved remotely.
- Confirm the worktree is inactive and not the primary checkout or a trunk
  worktree. Check for tools or processes using its files.
- Inspect ignored files, generated artifacts, and evidence that Git status
  does not show. Archive meaningful recovery evidence with paths and hashes
  when required; preserve reusable builds, dependencies, and caches unless the
  user separately authorizes their removal.
- Apply the repository's own cleanup rules. Keep dirty, unique, unpushed,
  locked, active, deferred, or uncertain work.
- Preserve remotely reachable `archived/*` refs and their worktrees during
  routine cleanup. Review archived work only when a task explicitly targets it.

Only carry out removals when the user's request explicitly includes cleanup of
the exact verified targets. Use ordinary `git worktree remove` and
`git branch -d`; never force removal. Recheck shared Git state immediately
before cleanup and verify the resulting worktree and branch state afterward.

---

## Report

Give the report path or contents, scan roots, repository and candidate counts,
incomplete inventory, freshness of remote refs, and items needing investigation.
Separate Git-confirmed integration from PR, remote-preservation, active-use,
ignored-evidence, and owner-approval checks. State clearly whether any removal
was authorized and performed.
