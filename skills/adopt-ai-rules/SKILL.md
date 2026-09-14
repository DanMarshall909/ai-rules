---
name: adopt-ai-rules
description: 'Use when adopting or updating this repository''s rule sets in an existing project or agent environment, especially when reconciling overlapping instructions or duplicate skill packages.'
---

# Adopt AI Rules

Bring an existing project or agent environment onto a selected rule set without
discarding instructions or skills that still have a distinct owner. Use the
maintained installers from the durable `ai-rules` checkout; their links keep the
installation current as the checkout changes.

This skill may inventory and propose cleanup. It does not authorize deleting a
skill, replacing a real file with `--force`, or promoting a project's guidance
into `ai-rules`. Obtain confirmation for the exact mutation after showing the
evidence and recovery plan.

## Establish the adoption target

Identify and report:

- the durable `ai-rules` checkout and selected base or layered rule set;
- the target project, agent profiles and supported agents in scope;
- whether the request is an audit, an update of an existing installation, or a
  first adoption; and
- the target project's authoritative instructions, tracker and Git state.

Do not install from a temporary worktree that will be removed. Preserve dirty
or unrelated project files. A layered set is additional project guidance; it
does not replace the base policy. Read the maintained installation contract in
the checkout's `README.md` when destinations or scope are uncertain.

Follow every `layer:` declaration from the selected manifest to its standalone
base. Verify that each prerequisite set is already active for the same agents
and target. If one is missing, preview and install the chain from the base
outward before installing the selected layer. A layer-only installation is not
a complete first adoption.

## Inventory before changing anything

Use the repository's list and dry-run modes for the selected agents and target,
for example:

```bash
<ai-rules>/scripts/install-rules.sh --list --rule-set <set> --project <target>
<ai-rules>/scripts/install-rules.sh --rule-set <set> --agent <agents> --project <target> --dry-run
<ai-rules>/scripts/install-skill.sh --list
<ai-rules>/scripts/install-skill.sh --list --project <target>
```

Invoke the installers from their durable checkout. Skill inventory requires both
list commands: the unscoped command shows packages in profile destinations for
profile-scoped agents, while the command with `--project` shows packages in the
selected project's destinations. Do not use the unscoped Cursor or Cline results
as the project inventory; without `--project`, those paths describe the invoking
checkout and can miss the target's existing packages.

Treat installer listing as canonical-package status, not a complete inventory.
Separately enumerate the direct child entries in every in-scope profile and
project skill discovery directory named by the installation contract. Include
packages whose names do not exist in the `ai-rules` checkout, because copied,
renamed, independently owned, stale and broken packages are otherwise invisible
to `install-skill.sh --list`.

Inspect every reported instruction adapter and skill destination. Resolve links
to their sources and distinguish real directories, junctions, symlinks, broken
links and generated adapters. Include complete skill packages in the comparison:
frontmatter, `SKILL.md`, references, scripts and assets. Do not infer duplication
from a matching directory name or a similar description alone.

Classify each apparent overlap:

- **same package** — already points to the selected canonical package;
- **exact duplicate** — separately stored but byte-equivalent as a complete
  package;
- **semantic overlap** — serves a similar purpose but contains different
  decisions, procedures or resources;
- **distinct** — has a separate trigger, owner or outcome; or
- **stale or broken** — its source is missing, obsolete or incomplete.

Treat modified copies and uncertain ownership as distinct until their unique
content has been explained. Avoid exposing secrets found during inspection;
report paths, metadata and the minimum comparison evidence needed for a decision.

## Present the reconciliation plan

Before mutation, show:

1. the installer command and every destination it will add, retain or repoint;
2. any real file or directory that would require `--force`;
3. a duplicate table with exact path, classification, canonical owner,
   meaningful differences, proposed action and recovery method; and
4. unresolved instruction conflicts that installation alone cannot settle.

After the required base/layer chain is active, ordinary installation or
repointing of already-owned links may proceed when the user requested adoption
or update and the dry run matches that scope. Stop for confirmation before
`--force`, removal, replacement of project-owned content, or any cleanup whose
target was not explicitly confirmed.

Ask for confirmation against exact paths, not a category such as “old skills.”
If several targets share one proof and recovery plan, they may be confirmed as
one named set. A changed target invalidates the confirmation; inspect and present
it again.

## Apply only the confirmed cleanup

Immediately before each confirmed mutation, verify that the target, type,
content or link destination still matches the plan. Remove only the redundant
copy or link that was confirmed, never the selected canonical package.

Prefer a reversible move outside every agent's discovery roots when practical.
Record the backup location and restore action. If the user explicitly chooses
permanent deletion, name what will become unrecoverable. Do not treat semantic
overlap as deletion proof: retain unique behavior or migrate it through a
separately reviewed edit before removing its former owner.

After installation and any confirmed cleanup, rerun list or dry-run inspection
and verify:

- the selected adapters and complete skill packages resolve to the intended
  checkout;
- project-owned instruction content remains present;
- removed duplicates no longer load and no broken compatibility links remain;
- unrelated agents, profiles and projects are unchanged; and
- any client refresh or restart still needed for discovery is reported.

Filesystem verification does not prove that a running client reloaded its
instructions. Claim live discovery only when it was tested through that client.

## Flag possible upstream rules

Inspect authored project instructions and skills, not generated adapters, for
guidance that may belong in `ai-rules`. Flag a candidate only when it is:

- useful across projects or providers rather than tied to one repository;
- non-obvious and load-bearing enough to change a future decision;
- supported by repeated use or a high-consequence failure;
- compatible with an existing rule or procedural owner, or clearly justifies a
  new owner; and
- free of private paths, credentials, organization-only policy and accidental
  implementation detail.

For each candidate, report its source, evidence, proposed owner (`rules/`, an
existing skill, or a new skill), the behavior it would change, overlap with
current guidance and the cost or downside of making it global. Also report a
clear “none” when no candidate meets the threshold.

Do not copy, move or edit the candidate into `ai-rules` during adoption unless
the user separately authorizes that repository change. Until then, the target
project remains its authoritative owner.

## Handoff

Summarize the selected set and agents, destinations updated, duplicates removed
or retained, backups and restoration steps, verification performed, remaining
conflicts, live-discovery limits and any upstream-rule candidates awaiting a
decision.
