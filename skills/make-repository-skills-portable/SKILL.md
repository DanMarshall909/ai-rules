---
name: make-repository-skills-portable
description: 'Use when making a repository''s own skills portable across agents while preserving project-owned guidance and unique packages.'
---

# Make repository skills portable

Make repository-owned skill packages discoverable across supported agents from
one canonical source. Preserve project-specific decisions, complete packages,
and unrelated agent configuration.

## Establish ownership and discovery roots

Inspect the repository instructions, complete Git status, and every project
skill discovery root in scope:

| Consumers | Project discovery root |
|---|---|
| Codex, OpenCode, GitHub Copilot | `.agents/skills/` |
| Claude Code | `.claude/skills/` |
| Cursor | `.cursor/skills/` |
| Cline | `.clinerules/skills/` |

Enumerate direct child packages in all existing roots, including broken links,
renamed packages, and names absent from this repository. For each apparent
overlap, compare the whole package: frontmatter, `SKILL.md`, references, scripts,
and assets. Classify it as the same package, an exact duplicate, a semantic
overlap, distinct, or stale/broken. Similar names or descriptions are not proof
that content is disposable.

## Choose the portable owner

Use `.agents/skills/<name>/` as the tracked canonical location for a portable
repository skill. Its directory name and frontmatter `name` must match, and its
description must say when the skill applies. Keep every referenced resource
inside the package or at another stable repository path that remains valid from
all compatibility locations.

Move an existing uniquely owned package only after its source and destination
are clear. Preserve history with the repository's normal Git move workflow.
When native copies differ, reconcile their meaningful decisions into the
canonical package before retiring anything. Do not promote private or
repository-specific guidance into global `ai-rules` during this task.

## Add compatibility without creating forks

Point required native discovery locations at the canonical package. Use relative
directory symlinks on Linux. On Windows, use directory symlinks when Developer
Mode permits them and directory junctions otherwise. Do not commit a copied
second package merely to accommodate an agent; copies drift silently.

Treat a real directory, file, or link with an unexpected target as
project-owned. Present the exact path, differences, proposed replacement, and
recovery method before changing or removing it. Never use a forced replacement
or delete a unique package under implied migration authority.

If compatibility links must be recreated after clone, add a small idempotent
repository setup command for both supported host families and document when to
run it. It must retain correct links, refuse real conflicting content, and name
every change. Keep generated link locations out of version control when the
repository cannot preserve their semantics cross-platform.

## Validate the result

Validate each canonical package's frontmatter and resolve every referenced
resource from the installed package. Run any executable helper's focused tests.
Then inspect each selected agent's project discovery output when its client or
CLI exposes one.

Report the canonical packages, compatibility links created or retained,
conflicts preserved, checks run, and any client refresh still needed. A valid
filesystem layout is not proof that every running client reloaded it.
