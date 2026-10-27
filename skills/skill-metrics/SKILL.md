---
name: skill-metrics
description: Record local declared skill usage and compare outcomes for pinned rules revisions; use when the user requests skill metrics or a controlled policy comparison.
---

# Skill metrics

Use this optional local recorder when the user wants usage or effectiveness
measurement. It records declared exposure, not automatic client observation.
Reading or installing the skill does not start tracking.

## Record a task

Use Python 3.10 or later and this package's `scripts/skill_metrics.py`. It has no
third-party runtime dependencies. Choose a stable opaque run ID and project
alias; keep the ID for retries. Start recording before the work being measured:

```text
python <skill>/scripts/skill_metrics.py start --run-id task-11-a --project ai-rules --host codex --skill agentic-delivery --skill track-github-work
```

The source defaults to the checkout containing this package, including a pinned
project submodule. Pass `--rules-root <checkout>` consistently to `start`, `use`
and `finish` when measuring another explicit source. Start outputs its actual
Git revision when available and a digest of policy, skill and shared repository
script content. Per-skill digests identify their package files. A dirty or
unavailable Git identity is explicit; labels cannot impersonate revisions.

Batch newly selected skills with `use --run-id <id> --skill <name> ...`. Then
record the task outcome with `finish --run-id <id> --outcome completed` (or
`partial`, `failed`, `abandoned`). A recorded completion is a declared outcome,
not proof of user acceptance. `--assessment test|independent|user` requires a
safe evidence reference; that reference is recorded, not fetched or verified.
Identical retries are safe; conflicting final results are rejected.

Finish verifies the current source again. Changed or unavailable source identity
remains visible and cannot enter a clean matched comparison. The timer covers
only the recorded interval, including waits; never backfill an invented start.

```text
python <skill>/scripts/skill_metrics.py report
```

All commands emit one JSON result on stdout; errors use stderr and a nonzero
exit. `--db <file>` precedes the command. The default database is outside Git:
`%LOCALAPPDATA%/ai-rules/metrics.sqlite3` on Windows, or
`${XDG_STATE_HOME:-~/.local/state}/ai-rules/metrics.sqlite3` elsewhere. Reporting
a nonexistent database does not create it. Store databases outside the rules
source checkout and never commit or upload them.

## Include storage in the evaluation

Before starting a storage evaluation, select the workload, measurement scope,
cache state and absolute tolerance. Add `--storage-threshold-bytes <bytes>` to
`start` for each side; it cannot be retrofitted at finish. Import the producer's
explicit receipt with `finish --storage-receipt <json-file> --metrics-source
<opaque-id>` using the other normal outcome/assessment arguments.

Read [the receipt contract](references/measurement-contract.md#storage-observations)
for the required JSON fields. Record scoped before/after and sampled peak bytes,
cleanup failures and provenance; keep unknown measurements null. Host free space
is contextual and must not be substituted for task-attributed storage. Report
logical footprint as logical footprint, not physical space recoverable by
cleanup. Include a subsequent rebuild when evaluating cleanup productivity.

The comparison can report faster-but-larger work as mixed. Missing required
storage evidence, a changed cache state, or unplanned storage receipts makes
an overall comparison insufficient. Nothing in the recorder authorizes deleting
worktrees, caches or evidence.

## Compare a policy change

Read [the measurement contract](references/measurement-contract.md) before
planning an evaluation or interpreting `compare`. It defines enrollment,
comparable pairs, metrics, thresholds, exclusions and verdicts.

Preserve missing measurements as unknown. Record tokens, tool calls, cost and
quality/safety counts only with a named measurement source. Do not infer
zero incidents from no reported incidents, or skill effectiveness from a task
that happened to succeed. Several skills may contribute to one task.

Capture no prompts, source text, credentials, screenshots or host history. Use
only opaque labels and explicit evidence references without credentials/query
parameters. There is no background collector, upload, automatic rule editing or
cross-repository rollout. Compare pinned candidates, retain the evidence, and
use the repository's normal review before promoting a rules change.
