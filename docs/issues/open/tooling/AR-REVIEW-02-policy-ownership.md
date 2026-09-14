# AR-REVIEW-02 — Policy ownership and precedence

Status: Open (proposed policy; PR review and merge remain outstanding).

Series: 02 of 03, dependent on PR #1 (`fix/installer-contracts`) at
`a1b2ede376f20dc6c608fad7f6dea670dec4adbb`. The older retained global-rules
worktree is not a source or target of this change.

## Acceptance criteria

- AC1: Installed shared policy states which instructions can refine its defaults,
  respects host instruction hierarchy, and does not infer write authority from
  review requests, persistence language, or skill selection.
- AC2: Read-only work and genuine prototypes receive proportionate treatment;
  maintained or recurring scripts are not accidentally exempt from normal tests.
- AC3: A reviewer-approved candidate cannot be changed by a mandatory pull/rebase
  immediately before publication. Upstream movement invalidates approval.
- AC4: Delivery, test design, evidence interpretation, and completion review each
  have one procedural owner. A missing unique mutant does not justify deleting
  a useful test, and uncovered code is described relative to the measured run.

## Design and semantic acceptance cases

No executable implementation is changed. Existing generator, installer, scaffold
and conventions checks validate distribution. Independent read-only scenario
review validates decisions; string-matching policy prose is not a behavior test.

| Request or evidence | Required decision |
|---|---|
| Review a dirty repository | Inspect and report; preserve work, no inferred edits. |
| A one-off exploratory script | Validate its risk with smoke/syntax/output evidence. |
| A repeatedly used operational script | Apply normal behavior-first testing. |
| Project chooses another assertion framework | Use the project framework without treating a portable adapter as veto. |
| Feature criterion is green | Complete evidence and production/test refactor assessment before next RED. |
| PASS candidate; fetched upstream unchanged | Commit/push only reviewed bytes within authorized envelope; no rebase. |
| PASS candidate; fetched upstream moved | Invalidate PASS, integrate, revalidate and review again. |
| Two tests kill the same generated mutants but protect different contracts | Retain useful independent protection; mutation overlap is not proof of redundancy. |
| A line is absent from one coverage report | Investigate run scope/instrumentation; do not claim nobody ever executed it. |
| Equivalent mutant or no-coverage bucket | Verify equivalence or measurement limits before deleting code or blaming the harness. |

## Decisions

- Ship authority first in the base bundle; adapters expose policy, not a new
  policy authority. Existing scoped worktree and preservation instructions stand.
- Keep the existing independent-review gate; remove competing copies of its
  packet and finalization procedure from the delivery coordinator.
- Retain behavior-first TDD's cycle and four test-quality criteria. Coverage and
  mutation interpretation belong only in `coverage-and-mutation`.
- Keep the always-loaded bundle below 200 lines by removing repeated explanation,
  not by removing preservation, validation, or approval boundaries.
