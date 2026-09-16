---
name: loc-delivery-estimation
description: 'Estimate implementation and delivery time from Git changed-line throughput, explicit remaining churn, and non-coding overhead; use for repository completion forecasts, not effort commitments from raw LOC alone.'
---

# loc-delivery-estimation

Produce an evidence-backed range for remaining active delivery time. Measure
recent comparable work from Git, estimate remaining changed-line churn by scope,
and keep validation, review, queue and publication time separate. Return the
inputs, calculation, confidence and important uncertainty—not a false-precision
commitment.

Use [scripts/estimate_delivery.py](scripts/estimate_delivery.py) when Git history
contains suitable completed slices. It uses only Python's standard library and
invokes Git without a shell, so its behavior is the same on Windows and Linux.
Run it with an available Python 3 command (`python` or `python3`).

## Establish a comparable rate

- Use changed-line churn: additions plus deletions. Net LOC hides replacement and
  refactoring effort.
- Select at least two recently completed, non-overlapping slices from the same
  repository, stack and delivery standard. Three or more is better.
- Bound each sample from its first preserved work commit through its focused
  completion/review commit. Commit timestamps measure elapsed repository time,
  not uninterrupted human effort; disclose interruptions and work performed
  before the first commit.
- Include production code, tests, contracts and documentation when they are part
  of both historical and remaining work. Exclude generated or vendored paths
  only when the same exclusion applies to samples and forecasts.
- Reject a rate based on one tiny slice, overlapping samples, unrelated bulk
  generation, or work with materially different complexity.

The script calculates the weighted rate as:

```text
sum(sample additions + sample deletions) / sum(sample elapsed hours)
```

## Estimate remaining churn

List the unfinished scopes individually and give each a minimum and maximum
changed-LOC estimate based on analogous completed work. Do not derive remaining
LOC only from a subjective percentage. Keep known non-coding work—full suites,
CI queues, independent reviews, deployment observation and publication—as a
separate overhead range.

Example (one line works unchanged in PowerShell, cmd and POSIX shells):

```text
python skills/loc-delivery-estimation/scripts/estimate_delivery.py --repo . --sample P06 63f7ed0 6d13280 --sample P07 3d5c9c0 2e82a7e --base-ref origin/main --include-untracked --remaining P08 200 400 --remaining P09 800 1200 --overhead-hours 2 4
```

Use `python3` instead of `python` when that is the installed launcher. Use
`--json` for structured output and repeat `--exclude GLOB` only for justified,
consistent exclusions.

## Report the estimate

State:

- observed churn and elapsed hours for every sample;
- the weighted changed-LOC/hour rate;
- remaining LOC assumptions by scope;
- implementation hours and fixed overhead separately;
- the combined active-hours range and its confidence;
- whether the estimate excludes waiting, interruptions or unavailable services.

Treat the result as a planning forecast, not a deadline. Widen the range for
cross-cutting migrations, security work, unknown external dependencies or
review-until-clean loops. Recalculate when a completed slice materially changes
the observed rate or a review adds scope.

If comparable samples or credible remaining-LOC ranges do not exist, say that a
LOC forecast is unsupported and identify the evidence needed. Never manufacture
precision by substituting total repository size, commit count or tickets closed.
