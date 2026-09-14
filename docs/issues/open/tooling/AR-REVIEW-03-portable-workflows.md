# AR-REVIEW-03 — Portable workflows and clear usage

Status: Open (proposed changes; PR review and merge remain outstanding).

Series: 03 of 03, dependent on PR #2 (`fix/policy-ownership`) at
`3e51f602507c91653d0fb8cf8acb790a321791c2`.

## Acceptance criteria

- AC1: Break reminders use available host capabilities, scoped session context
  and verified schedules; missing capabilities produce an honest fallback,
  not invented calls, private-directory scans or false activation claims.
- AC2: Reflection separates a proposed lesson from a saved one, discovers its
  actual storage/authoring source and respects explicit memory-write consent.
- AC3: Shipped rules route to available workflows without unsupported slash
  commands or unresolved wiki links. Maintainer guidance names the real owners.
- AC4: Users can distinguish installing a whole policy from one skill, project
  destination from profile scope, source edits from generated outputs, and
  current usage guidance from dated research.

## Semantic acceptance cases

| Context | Expected outcome |
|---|---|
| Ordinary coding request | No reminder jobs created merely because the skill is installed. |
| Requested paced session with no scheduler | Explain no scheduled reminder is active; offer a bounded in-session alternative. |
| Existing matching reminder | Reuse it, or establish duplicate risk before creating another. |
| One of two reminder creations fails | Report actual partial state and cancellation; do not claim both active. |
| Reminder fires | Refer only to scoped session context; no unrelated memory scan or task switch. |
| User asks what was learned, but not to save | Discuss/propose; memory and standing guidance remain unchanged. |
| Explicit memory update, host exposes append-only notes API | Use that API; do not invent a vendor file/index edit. |
| Language-specific testing lesson | Route to relevant module/skill, not an unrelated always-loaded rule. |
| Contributor changes a source rule | Register it in a set, regenerate, run checks; do not edit the generated bundle. |
| User adopts policy into another project | README identifies actual installer scope and bundled skills without requiring duplicate installation. |

## Decisions and verification

- Keep these as portable instructions, not new reminder services or memory code.
  No real schedules, profiles, memory or downstream repositories are changed.
- Use the repository suites for distribution and scaffold behavior, metadata
  validation for discoverability, local link checks for literal paths, and
  independent scenario review for meaning. Do not equate text matching with
  behavioral proof.
- Retain dated research and downstream audit claims as historical evidence,
  explicitly distinguished from the maintained installation contract.
