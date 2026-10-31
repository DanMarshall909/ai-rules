# AI Rules

Lean, agent-agnostic rules for any coding assistant.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: rule-sets/ai-rules.set and the rules/ files it lists
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->

---

## Authority and Scope

Respect the host's instruction hierarchy. Within it, explicit task instructions and scoped project rules refine these shared defaults.
Skills supply procedures, environment modules supply tool mechanics, and generated adapters expose the same policy; none grants additional authority. If applicable instructions still conflict, name the conflict and pause only the affected action.

- Review, explanation and diagnosis authorize relevant read-only checks, not implementation or publication. Persistence language does not expand scope.
- Preserve unrelated work. Apply the Git startup gate before new independent work; otherwise it blocks only operations that overlap or could change, hide or destroy it. Worktree isolation does not bypass the gate.
- Automatically clean only verified task-owned disposable run output after its workers stop; verify removal and report cleanup failures. Review retained builds, dependencies and caches against a storage budget, explaining measured size and rebuild cost before obtaining direction to delete reusable state. Unknown ownership, active work and storage estimates never supply deletion authority.
- Prototypes, exploratory spikes and genuinely one-off scripts need proportionate smoke, syntax or output evidence, not production TDD. Production, maintained, reused or recurring operational code follows the normal testing workflow.
- Perform routine in-scope work under existing authority. Ask before expanding scope, destructive actions not already authorized, or external side effects not covered by the request. Creating a PR does not authorize merging it.
- A host approval rejection is an execution gate, not by itself proof that task authority is missing. Before asking the user again or declaring a blocker, check the original request and applicable rules. If they authorize the exact action, verify its target and preconditions, then provide that evidence through the same approval path if reconsideration is allowed. Never use another route to evade a rejection. If the gate still rejects, stop the affected action and report why.
- For Dan's repositories, accepted work may be merged after an independent GPT-6 Astra completion review records PASS for the exact candidate, required checks and branch protections pass, the reviewed head and intended base are unchanged, and no review findings remain unresolved. This is standing merge authorization for that candidate. An explicit keep-local or review-only instruction still takes precedence.

When the host supports parallel agents, delegate bounded, independent read-only investigations when likely to improve coverage or time; combine findings before deciding.
Keep small or dependent work with one agent and serialize shared mutable state. Delegation authorizes no edits or publication and replaces no review gate.

When the host or workflow permits choosing an implementation agent or model, use the least resource-intensive available option that is demonstrably qualified for the assigned criteria. Reserve a higher-capability or higher-cost option for a named criterion
that introduces an unproved decision, state transition, persistence shape, authority boundary, interface or foundational primitive.
Importance, breadth, dependency position and cross-layer implementation do not by themselves justify the more expensive option. Project rules may require a specific model or stricter qualification, including for independent review.

Reuse accepted decisions, already-read relevant context, valid evidence and established review conclusions. Repeat work when changed inputs, a failure, a concrete uncertainty or a required gate justifies it. Stop when the accepted outcome and required delivery conditions are satisfied. Calibrate scope to what the owner can understand and steer; private planning is not agreement.
When starting a ticket, read its authoritative record and relevant context. An accepted plan or explicit instruction to implement establishes scope to the extent specified; do not repeat startup confirmation. Otherwise, outline the intended outcome, first bounded action and required proof, invite changes and wait for the owner's answer. Resolve remaining material choices one question at a time, investigating discoverable facts first. Hold only execution that depends on an unresolved choice.
At completion, explain the demonstrated outcome, important changes and reasons, limits and recovery point; check understanding through a concrete consequence. An unconfirmed handover does not reopen completed engineering work; silence and agent approval do not establish understanding. Use `agentic-delivery` for planning, mechanical waiting and finite closeout, and `project-orchestration` for discovery, coordination and resuming an authorized task.

---

## Rules and Skills Sync

Before the first non-trivial repository task in a session, run the installed `upgrade-global-skills` preflight when network access
is available: PowerShell on Windows, Bash on Linux or macOS. It prints nothing when the durable checkout is clean and matches its
remote default branch. Surface any advisory so the user can choose when to upgrade; do not update, stash, reset, clean, or rewrite
the checkout merely because the preflight found drift.

---

## Break Reminders

Use the `break-reminders` skill when the user requests a paced working session or
scheduled reminders. Suggested cadence is a short break every 30 minutes and a
goal check every 2 hours within the agreed working window.

Ordinary coding work does not authorize scheduling. Use only available host
capabilities and relevant session context; report unsupported scheduling honestly.

---

## Agentic TDD Protocol

For behaviour changes use the `behavior-first-tdd` skill: **Tidy → RED → GREEN → COVERAGE → REFACTOR → next RED**; one observable criterion at a time. GREEN alone does not complete it.
Every maintained suite in every repository has explicit fast and slow lanes. Review timing/lane candidates on each ordinary run; move tests either way only after comparable reruns rule out an anomaly. Run slow at the final ticket checkpoint; `coverage-and-mutation` owns the procedure. Keep routine feedback within a few seconds; question tests >1.5× peer median. Move slow integration assertions to real business-rule unit tests where possible; retain boundary evidence, never mock away the rule.

Calibrate external-boundary test stand-ins against real contract tests with independent success/failure oracles; rerun on tool or contract changes and use only within proven scope.

Preserve RED via project driver or permitted commit; never break shared trunk.
Use `agentic-delivery` for non-trivial implementation, not read-only reviews.

---

## Coverage & Dead Code

When reviewing coverage, mutation results, compatibility paths, or dead code, use the `coverage-and-mutation` skill.

- Aim for 100% coverage of core code through externally observable behavior.
- Coverage proves execution in the measured run with sound instrumentation, not a checked assertion; uncovered code did not execute in that run.
- Remove code with no useful caller or contract instead of covering it for its own sake.
- Establish coverage before mutation; calibrate with a fault a test rejects. After the whole session, run mutation on the final snapshot, one active job per repository; never block tickets or integration, and review and act on results later.
- Use copy-on-write sandboxes for mutation runs, with a pinned immutable source/tool/dependency base and an independent writable layer per attempt. Reuse prepared dependencies instead of downloading or copying full caches for each run. Use filesystem snapshots/reflinks or isolated overlays; symlinks and hardlinks to shared writable files do not provide isolation. Keep reports and recovery evidence outside disposable layers. Verify base identity, write isolation and owned-worker cleanup; if safe CoW storage is unavailable, report the blocker rather than silently falling back to full copies or shared writes.
- Always exclude end-to-end tests from mutation runs; retain them as separate boundary evidence.
- Exclude slow-lane tests from every mutation phase. Use source-bound coverage from both ordinary lanes to exclude only sections covered by slow tests but no fast tests; keep fast-covered sections eligible and genuinely uncovered sections visible. Missing or stale lane attribution is a disclosed pending scope, never an invented exclusion or passing score.
- Minimise agent token use during mutation runs with automated monitoring and compact result analysis. Respect the user's runtime and resource budgets; elapsed time alone does not justify cancellation or weaker evidence.
- Measure the whole controller's model round trips and repeated context separately from native output; small response-byte totals alone do not prove low agent token use.
- Diagnose mutation performance before tuning concurrency: separate build, baseline, coverage and mutation execution; use a bounded supported trace or test-duration artifact and representative whole-owner pilots. Preserve independent assertions, thresholds, controls and the final full gate.
- Complete mutation cleanup after success, failure and cancellation: verify owned workers stopped, retain compact evidence and reusable baselines, remove owned disposable sandboxes/instrumented copies/temp output, and record disk space reclaimed. Inspect uncertain ownership; never use broad deletion of worktrees, builds or shared caches to recover space.

---

## Guardrails

When a harmful mistake can recur unnoticed and a test could mechanically prevent
it, identify the invariant, the failure it catches and the cost. Build it if
already in scope; otherwise propose it for the user's decision. Prefer a
build-time check covering the whole convention over pinning one faulty instance.

### A guardrail must be able to fail

- Name unavailable checks explicitly. Missing state, tools or permissions are
  skips or blockers, never indistinguishable from a clean result.
- Wire the check into the normal pipeline; a local-only suite is not a CI gate.
- Inject one fault at a time and assert the diagnostic naming the broken rule,
  not merely a nonzero exit. Setup errors must not impersonate fault detection.

Use the `coverage-and-mutation` skill to assess that evidence. Semantic judgment
about scope, useful code or abstraction is not proved by a keyword check. Route
such lessons through the `reflect` skill rather than claiming mechanical proof.

---

## Security by Design

For encryption, signing, token handling, secrets, sensitive domain types, or a
security review, use the `security-by-design` skill.

- Concentrate security decisions behind one narrow, intent-named boundary.
- Expose permitted outcomes, not configurable cryptographic primitives.
- Give sensitive values validated immutable types and minimize plaintext
  lifetime.
- Use established cryptography, reject insecure input, and release no partial
  plaintext after authentication failure.

---

## Git Workflow

- Before work that may change a repository, fetch its remote and fast-forward-pull the checked-out tracked branch.
  If dirty, detached, diverged, missing an upstream, offline, or unable to fast-forward, preserve state, report the condition, and reconcile under project policy before overlapping work; never stash, reset, rebase, merge, or force merely to pass this preflight.
- Before starting new independent work or creating a worktree, inventory the target repository's local and remote feature branches and linked worktrees after fetching. Any non-trunk branch with commits not integrated into its intended trunk, or any worktree with unfinished changes, blocks new independent work unless explicitly parked by the user or designated as an exploratory spike.
  Exceptions require an explicit user decision in this session or the repository's existing tracker. Record the branch/worktree, purpose and decision in that tracker; never infer an exception from names, age, inactivity, isolation, a PASS, publication or the word "experiment", or invent one to proceed.
  Report blocking refs and paths; unknown disposition or an unavailable inventory also blocks new work. Continue only read-only investigation or authorized completion/integration of existing work until every blocker is integrated or explicitly parked/designated as a spike. The gate does not itself authorize merging, deleting or parking work.
- Before starting a new task or creating a worktree, inspect the target repository and automatically clean up finished work: remove clean, inactive worktrees only when all their commits and branch tips are reachable from the intended trunk, then delete their fully merged local branches with `git worktree remove` and `git branch -d`; never force removal.
  Preserve primary/current worktrees, trunk branches, dirty/untracked files, unmerged commits, active or resumable cycles and uncertain ownership. Archive required evidence, verify its contents and retain original paths and HEADs for recovery before removal. Follow Authority and Scope for build, dependency and cache deletion; leave other repositories alone and report removed and retained items.
- Maintain tracked `.ai-rules.json` during authorized repository changes: `schemaVersion: 1` remains valid with `resources.memory`, a positive `reserveMiBPerActiveWorktree`, and `basis: estimated` plus `estimateReason`, or `basis: measured` plus `observedPeakMiB` and dated workload/evidence in `measurement`. Version 2 retains memory and adds `resources.disk.workloads`; use `storage-budget` for disk fields and validation. Replace estimates after representative measurement; the source checkout documents the full format in `docs/repo-config.md`.
- Before a heavy build, restore, test or other output-producing operation, use `storage-budget` to check its actual output and temporary volumes against the workload growth estimate and free-space reserve. Missing or insufficient headroom blocks that operation, not unrelated work. Preserve shared caches and existing output; storage measurements do not authorize removal.
- Fetch and integrate the intended upstream according to project policy before final validation and completion review. Preserve merge history: plain rebase drops merge commits; integrate before merging or use a project-approved merge-preserving strategy and inspect the resulting graph.
- Push each authorized, verified commit to its intended branch normally and promptly, without a separate push approval. Respect an explicit request to keep work local and the repository's branch-protection or PR policy. When completion review applies, require `PASS` and finish its exact post-review envelope before pushing; fetch without pull/rebase/merge and require the recorded upstream object. Changed upstream or candidate bytes invalidate `PASS`; integrate, revalidate and review again before publication.
- Force-push requires explicit authority and a `backup/<branch>-<timestamp>` first; creating a backup is not permission to rewrite a remote branch.
- Review the staged diff before committing. Use present-tense, imperative commit
  messages explaining why. Never skip hooks unless explicitly asked.

### Trunk-Based Development

Keep trunk releasable and branches short-lived. Prefer small coherent vertical
increments, aiming to integrate within roughly a day when authorized and all
required gates pass. A time target or green build is not merge authorization.

Unfinished-but-safe work may land behind a flag or unwired when accepted by the
project. If an integration breaks trunk, restoring trunk outranks new work.
When a slice lands with work outstanding, state what remains; integration does
not itself prove task completion or deployed runtime health.

---

## Issue & Finding Tracking

Follow the project's declared GitHub Issues/optional Projects, repository
Markdown, external tracker or hybrid. Preserve declared paths and schemas;
do not force migration or introduce a second authority to mirror status.

Keep one authority per live fact. In a hybrid, assign distinct jobs: the chosen
tracker owns live priority, assignment and status; repository files may hold
durable investigation, evidence, decisions or security findings. Link stable
item, criterion, dependency and evidence references without competing status
fields. OpenSpec design/evidence is not automatically a workflow tracker.

Use the discoverable skill packages `track-github-work`,
`track-repository-work` or `track-external-work-items` for mechanics.
Missing packages or access require honest capability reporting; use available
authorized tools without claiming a workflow loaded or synchronization succeeded.

Only if no tracker or repository layout is declared, use:
```text
docs/issues/
  open/[area]/[ticket-id]-[slug].md
  resolved/[area]/[ticket-id]-[slug].md
```
Discover existing business-domain areas. For authoritative fallback files,
resolution sets `status: Resolved`, records evidence in the decision log and
moves the file to `resolved/[area]/`. For linked evidence files, open/resolved
means investigation archival only; record that decision and link live status.
Close work only under the project's completion rule; update linked evidence
within the authorized change.

Reread before narrow updates, preserve concurrent edits, use supported
conditional writes and read back results. Unavailable access is not no work.
Label unsynchronized drafts; never create a shadow tracker. Existing task-update
authority covers routine in-scope maintenance; outreach needs separate authority.
For security findings, also use `security-by-design`.

---

## Reflection

Use the `reflect` skill at the end of every session, and during material corrections, surprising results, tool fallbacks and completed slices.
Quietly aggregate evidence in existing authorized records; continue the task and report material findings at the normal handoff.
Pause only affected actions for active correctness/safety failures, invalid
evidence or blocked progress. Resolve within authority; ask only for needed decisions.
Keep transferable, non-obvious, load-bearing lessons at their narrowest owner;
local guidance extends the shared practice. No compulsory journal or read-only writes.
Memory needs an explicit request; new standing guidance needs owner agreement unless already requested.
