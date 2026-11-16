---
id: AR-HANDOFF-01
type: Feature
status: Open
area: tooling
created: 2026-11-16
---

# Keep one recoverable project handoff

Dan requests one current handoff per project, written at substantive task
completion or goal stop, with the previous version archived by a portable Bash
command. Fresh root sessions read it before substantive work. Delegated agents,
including nested coordinators, return handbacks to their parent instead of
rotating the project handoff. Programmatic Codex role discovery should distinguish
root, delegated and unknown without guessing from missing environment variables.

## Acceptance criteria

- AC1: `ai-handoff latest` and `list` read the current handoff and archive history;
  absent state is explicit and reading creates no project metadata.
- AC2: `new --expect <revision-or-none> --from <prepared-file>` preserves exact
  prior bytes in a unique archive and atomically replaces the sole current file.
  Invalid input, conflicts and pre-commit write failures preserve the current
  handoff; post-commit receipt/cleanup failures are explicit recovery cases.
- AC3: Linked Git worktrees share `<git-common-dir>/handoff/HANDOFF.md`;
  unrelated projects remain separate. Non-Git use requires an explicit project.
- AC4: Writes require root ownership; delegated/unknown automatic callers cannot
  rotate state. Codex discovery binds metadata to the current thread and treats
  forks separately from subagent parentage. Read access remains available.
- AC5: Global guidance, skill, installation and startup/closeout instructions
  agree. Portable Bash core targets Bash 3.2/common POSIX utilities; platform or
  adapter dependencies and unverified native hosts are disclosed.
- AC6: Required local checks and independent Astra completion review cover the
  exact candidate. Install the command/skill globally without overwriting
  unmanaged files, then bootstrap the Flo and ai-rules canonical handoffs.

## Workspace decisions

On 2026-11-16 Dan explicitly accepted the recommendation to park both retained
branches and proceed with this task, after requesting and receiving their review.
Preserve these remote refs unchanged; repair, merge and deletion are outside scope:

- `origin/temp/device-return-2026-11-04/consolidate-global-rules`, tip
  `6b0d86ccbe5d56c4f5647ee411ab1c6830c7b849`: older consolidated policy/audit work.
- `origin/temp/device-return-2026-11-04/loc-delivery-estimation`, tip
  `ec79b7f3262c734ae082136c342e5a333f6f619c`: delivery forecast skill and script.

Review findings and exact-tip evidence are retained locally at
`.git/reviews/2026-11-16-retained-branches/review.md`. Neither is ready to merge
as-is. This parking decision applies to the handoff task and survives resume
through this record. No repeated parking confirmation is needed for that scope.

Implementation starts from clean master
`b12a2000a59480586f850ef3d69c5ec0e4448611`. Existing dated Flo recovery records
remain evidence; the completed tool will establish the canonical current file.

## Evidence

Implementation and retained evidence are indexed under
`.git/reviews/AR-HANDOFF-01/`. This ticket owns accepted scope/disposition;
the canonical handoff is a recovery summary, not a competing tracker.

- AC1–AC3: CLI tests cover absent/read-only state, exact-byte history, expected
  revisions, lock conflicts, failure preservation, concurrent readers/writers,
  linked worktrees, separate Git directories, non-Git projects and unsafe paths.
- AC4: Metadata cases and protocol fixtures cover root/delegated/unknown/fork
  distinctions, current-thread binding and refusal of supplied metadata overrides.
  Real host probes returned root/0 for the coordinator and delegated/6 for an
  actual Astra subagent. Missing capabilities remain explicit unknown outcomes.
- AC5: Guidance and installers route to the one package. Command installation
  tests prove dry-run safety, repeatability, discovery and unmanaged preservation.
  Generated policy remains 198 lines. Native macOS/Windows evidence is unavailable;
  the optional Codex adapter requires POSIX named pipes, Codex and jq.
- AC6: The local checklist passes with the unchanged storage suite run using
  an isolated Git 2.47.3 build. Host Git 2.34.1 lacks that suite's existing `-z`
  dependency; its original failure and successful supported-tool rerun are retained.
  Windows-only storage cases skip explicitly. No system Git installation changed.

RED receipts cover missing read, rotation, role, installer and recovery-list
behavior. The owning suite has 21 passing cases, with fast/slow lanes. Production
refactoring centralizes checked full-text capture and revision calculation,
removes an overbroad ancestor restriction, and computes the receipt before commit.
Tests share setup but keep distinct public outcome/fault oracles. Bash execution
traces are diagnostics, not a fabricated coverage percentage. Final runtime,
independent review, installation and publication evidence belongs in the local
review record and canonical handoff; model usage/cost is unavailable.
