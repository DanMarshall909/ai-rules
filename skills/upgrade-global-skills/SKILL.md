---
name: upgrade-global-skills
description: 'Use when updating the shared AI rules checkout and its globally installed skills, or when a sync preflight reports drift.'
---

# Upgrade global skills

Bring the durable `ai-rules` checkout and its installed global skill packages to
the remote default branch without discarding local work. End with the checkout,
generated policy, and owned installation links verified. Keep client reload as
a separate boundary.

## Start with the quiet preflight

Run the script for the current platform from this package:

```bash
scripts/check-rules-sync.sh
```

```powershell
scripts\check-rules-sync.ps1
```

The script resolves the source checkout through an installed symlink or Windows
junction. No output and exit 0 means its default branch exactly matches the
remote default branch and the durable checkout has no local changes. Any output
is an advisory that needs attention. The check queries the remote without
fetching or changing refs.

## Upgrade the durable checkout

Resolve and report the physical checkout, remote, default branch, current
branch, complete status, upstream state, and registered worktrees. Fetch the
remote before deciding how to update.

- If the durable checkout has uncommitted work, local commits not on the remote,
  divergence, or a non-default checked-out branch, preserve it and stop the
  overlapping update. Do not stash, reset, force-push, or overwrite it.
- If it is clean and behind, update the default branch with a fast-forward only.
- If it already matches the remote, leave Git state unchanged.
- Do not clean old branches or worktrees as part of an upgrade.

Run `scripts/build-agents.sh --check` after the update. A stale generated policy
is an error in the fetched checkout; report it rather than regenerating and
silently changing the published commit.

## Reconcile globally installed packages

Read `rule-sets/ai-rules.set` and collect its `skill:` entries. Preview those
exact packages with the platform installer, then apply the preview to detected
profile agents:

```bash
scripts/install-skill.sh --dry-run <skill...>
scripts/install-skill.sh <skill...>
```

```powershell
scripts\install-skill.ps1 -DryRun <skill...>
scripts\install-skill.ps1 <skill...>
```

Existing canonical links may be retained or repointed under this requested
upgrade. A real file or directory is separately owned: never use `--force` or
`-Force` without presenting its exact path, differences, backup plan, and
obtaining confirmation. Inventory noncanonical profile skill directories when
an apparent duplicate or conflict is found; installer listing alone is not a
complete inventory.

Rerun the quiet preflight and installer listing. Report the checked-out commit,
packages added or repointed, preserved conflicts, validation, and which clients
must restart or refresh. Filesystem links do not prove a running client has
reloaded them.
