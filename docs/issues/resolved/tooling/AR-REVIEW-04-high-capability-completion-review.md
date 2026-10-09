---
id: AR-REVIEW-04
type: Maintenance
status: Resolved
area: tooling
created: 2026-10-09
---

# Use a powerful independent completion reviewer

The user requested that completion review use a powerful independent agent,
without requiring human review, and selected Astra for the current reviews.
Keep the existing independence, exact-candidate PASS and publication procedures.

## Acceptance criteria

- AC1: The canonical completion-review procedure requires a separate
  high-capability agent and honors an explicitly selected review model.
- AC2: Human review is optional and becomes required only on explicit user
  instruction. Self-review remains insufficient and missing independent review
  remains a blocker.
- AC3: Installed canonical skill links expose the updated source; generated
  policy and repository convention checks remain valid.

## Workspace decisions

On 2026-10-09 the user explicitly parked both clean, unmerged branches for this
rules update. Preserve their refs, worktrees and contents:

- `work/astro-site-skill`, HEAD
  `7f399865f8a07959c78a08a1f1fdb91a85034050`, worktree
  `/home/dan/code/.worktrees/ai-rules-astro-site`: reusable Astro site skill.
- `work/mutation-lessons-2026-09-28`, HEAD
  `8e2eb8166438bb7a9b3583c6e9d5d36bef5dd5b1`, worktree
  `/home/dan/code/ai-rules-mutation-lessons-2026-09-28`: mutation runtime/retry
  guidance.

Implementation owns only this tracker and
`skills/agentic-delivery/references/completion-review.md` in the durable master
checkout. Other retained worktrees, unrelated guidance and generated policy
are outside scope. Installed packages already link to the durable source;
no replacement, force installation or deletion is authorized or needed.

## Verification and completion boundary

Generated-policy verification and repository conventions pass. All nine base
skill packages were previewed and applied through the normal installer; every
destination was already linked to the canonical source, with no replacements
or added packages. The portable/Codex and Claude agentic-delivery packages
resolve directly to this durable checkout and expose the updated reference.

This is authored policy maintenance, with no production or installer behavior
change. The independent agent review assesses the instruction's meaning and
the exact candidate/envelope; keyword assertions would not prove that meaning.
After PASS, resolve this tracker, commit with normal hooks, require the unchanged
upstream and push normally. Preserve both explicitly parked branches and all
other worktrees; no cleanup deletion is part of this update.

## Resolution decision on 2026-10-09

Independent Astra review returned PASS for the exact policy candidate and finite
publication envelope. The canonical completion-review procedure now requires a
separate high-capability agent, honors the selected review model and makes human
review optional unless explicitly requested. Generated policy and conventions
remain valid; canonical installed links expose the updated source. Both named
branches remain explicitly parked for this update and all unrelated state is
preserved.
