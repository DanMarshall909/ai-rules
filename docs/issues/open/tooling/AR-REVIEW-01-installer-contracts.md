# AR-REVIEW-01: Installer contracts

Status: Open

The repository review found that base-rule installation can send bundled skills
to the invoking directory, selecting a standalone set installs the default set,
and single-file skill adapters lose access to package references.

## Accepted outcomes

- AC1: An explicit project receives all project-scoped rules and skills; the
  invoking directory remains untouched and user-scoped agents retain profile scope.
- AC2: Installing a standalone rule set installs the selected policy and its
  declared skills, with truthful discovery output.
- AC3: Every supported agent can follow an installed skill's reference files;
  installation remains live, repeatable, dry-run safe, and preserves unowned files.
- AC4: The conventions test fixture preserves executable modes on Windows.

## Series

1. This PR repairs installation and its regression tests.
2. AR-REVIEW-02 consolidates policy authority, publication, TDD, and coverage.
3. AR-REVIEW-03 makes workflows portable and refreshes usage documentation.

The series starts from `f08ebbe`. Each later PR depends on the preceding PR.
The retained `feat/consolidate-global-rules` worktree is outside this scope.

## Decisions

- Keep the scaffold's standalone-set capability and honor explicit selection.
- Install complete native skill packages for Cursor and Cline, retaining their
  existing project scope. Do not generate a second copy of the skill body.
- Migrate only exact old flat links to this checkout, after the new package is
  successfully linked. Report and preserve any unowned legacy rule.
- Native paths are documented by [Cursor](https://cursor.com/docs/skills) and
  [Cline](https://docs.cline.bot/customization/skills); Cline enables discovered
  skills by default and manages them through its Skills tab.
  Filesystem tests establish package reachability, not an interactive client smoke test.

## Evidence

The initial review reproduced AC1 and AC2 in dry runs. The existing Windows
conventions suite reported 31 passed and 3 failed because its new Git index lost
the executable modes. Validation and publication evidence is recorded in the PR.
