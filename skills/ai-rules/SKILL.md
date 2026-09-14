---
name: ai-rules
description: 'Use when working on the ai-rules repository itself: authoring rule fragments or skills, changing installers or scaffolds, or checking generated distribution. Does not install into real agent profiles unless requested.'
---

# Maintain ai-rules

Changes here affect every checkout consuming the shared guidance. Inspect the
task worktree first and preserve unrelated work. Use this skill from the actual
ai-rules repository root; paths below are relative to that root, not an assumed
personal installation path.

## Authored sources and generated outputs

| Path | Owner |
|---|---|
| `rules/**/*.md` | Authored always-loaded policy fragments |
| `rule-sets/*.set` | Authored fragment order, layer and bundled skill selection |
| `skills/*/SKILL.md` and supporting resources | Authored task-specific procedures |
| `scripts/*` | Authored generation, scaffolding and installation mechanics |
| `rule-sets/*.md`, `AGENTS.md` | Generated; never edit by hand |
| `CLAUDE.md` | Authored entrypoint importing the shared base |

The rule set is policy, skills are procedures, and adapters expose the same
sources. Follow `rules/authority.md` for scope and precedence. Read
`skills/reflect/SKILL.md` when deciding where a new lesson belongs.

## Register a rule or set

The default `ai-rules` set serves every project. A layered set adds guidance
for one kind of repository; a standalone manifest without `layer:` does not
require a base. Selecting a set does not uninstall other named sets.
A rule unique to one downstream repository belongs in that
repository's authored instruction source, not this shared base.

Use the scaffolds:

```bash
scripts/new-rule.sh --title "Caching" caching
scripts/new-rule.sh --set tool-repos --title "Cache Contract" cache-contract
scripts/new-rule-set.sh --title "Tool Repo Rules" --blurb "For tool repos." --layer ai-rules my-tools
scripts/new-skill.sh --set tool-repos --description "Use when ..." my-skill
```

Scaffolds create the source and register the manifest and README rows required
by the conventions checks. Replace their placeholders. Manifest order is reading
order; reorder deliberately, not incidentally. Regenerate with
`scripts/build-agents.sh` after changing fragments or manifests.

A set's `skill:` entries travel with it. Standalone/default installations retain
each agent's normal profile or project scope; layered sets scope their skills to
the target project. See README installation sections for current destinations
and the differing meaning of the two installers' `--project` option.

## Author a complete skill package

For a new skill, run `scripts/new-skill.sh --description "Use when ..." <name>`.
For an existing skill, edit its owner; do not initialize a duplicate. Keep its
frontmatter name equal to its directory and its description narrow enough to
select the right work.

Write actionable instructions and an honest missing-capability fallback. Keep
shared decisions in the entrypoint and conditional detail in linked references.
Resolve resource links inside the installed package; a link to a checkout-only
sibling is not automatically portable. Inspect callers before moving resources.

For semantic policy edits, review realistic decisions and conflicts. Keyword
matches cannot prove that a skill preserves scope or makes sound judgments.
Tests of generators, manifests and installed resource reachability still apply.

## Change installation mechanics

`scripts/agents.sh` owns shared Bash agent identities, roots, scopes and link
helpers; both Bash installers source it. `scripts/rule-sets.sh` owns manifest
layout and reading for the rules installer and scaffolds. Skill/rule targets
remain in their owning installers; `install-skill.ps1` mirrors skill targets for
Windows. Do not introduce another independently maintained table.

For a new agent, update shared identity/detection, Bash user/project skill
targets, base/layered rule targets and PowerShell targets. Extend observable
installer tests and run conventions; merely listing an agent is not support.

Link complete skill directories, including references. Bash requires native
symlinks; PowerShell may fall back to directory junctions. Preserve project-owned
entrypoints and unowned files. Inspect actual destinations with a dry run before
an authorized real installation. Repository maintenance does not itself authorize
installing into a user profile.

## Validate and commit

Read README's `Checks` section from this repository and run that complete
checklist before committing, including the PowerShell suite on Windows. It is
the human-facing command list; `.github/workflows/check-agents-md.yml` owns CI
execution. New suites must be wired into CI. Retain command, output, duration
and exit status for long runs; runtime varies by platform.

For maintained executable behavior, follow `behavior-first-tdd`: preserve an
intended failing test before its implementation, using `test(red)` commits when
permitted by the project workflow. Semantic guidance changes use scenario review
and relevant mechanical checks rather than fabricated prose-keyword tests.
Apply the explicit prototype exceptions and the independent completion-review
gate when it covers the task.

Review the staged diff, use imperative messages explaining why, and commit with
hooks. Follow `rules/git.md` for integration before review and unchanged-candidate
publication afterward. Short-lived branches are a target, not automatic merge
authority.

## Windows checks that must remain real

`.gitattributes` and `.editorconfig` keep shell, Markdown, hooks and rule-set
manifests on LF while PowerShell remains CRLF. Manifest readers tolerate older
CRLF checkouts, but a CRLF test must prove its fixture bytes before exercising
the reader. Strip CR before Bash parses a PowerShell table. Preserve executable
Git index modes in fixtures; NTFS copies do not carry Unix modes. Fault tests
must fail for the named intended defect, not a setup failure.

If generated-file verification disagrees with Git's diff, inspect line endings
and the index; report the discrepancy rather than bypassing the check. Skills
and rule links are live, but source-rule edits reach consumers only after
regeneration. Actual client discovery is separate evidence from filesystem tests.
