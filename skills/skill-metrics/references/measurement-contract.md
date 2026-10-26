# Measurement contract

The CLI records explicitly selected tasks. It cannot observe unrecorded work,
prove that a client loaded a skill, verify the supplied evidence, or establish
that a skill caused an outcome. Actual skill exposure and task success are
separate facts. Reports show associations; comparisons validate the declared
matching contract, not the experiment's execution or statistical significance.

## Identity and privacy

`start` fingerprints regular files under `rule-sets/`, `rules/` and `skills/`,
including package references/scripts, plus root AGENTS.md, CLAUDE.md and resource configuration when present. Python bytecode caches are excluded.
Nested links are rejected instead of following arbitrary external content.
Fingerprinting checks stable content and Git identity; `finish` samples again.
A change and revert between those samples cannot be detected. The declared
source must be the source actually used; the recorder does not inspect clients. Project/host instructions outside this source are not fingerprinted; include their version in the environment identity for a controlled comparison.

Actual checked-out Git revision and relevant dirty state are recorded when
available. A plain exported package can still be identified by content digest,
with Git identity unknown. A revision associated with several recorded digests
is ambiguous: select an exact digest for comparison. A Git revision selector
also requires every selected record to have known clean source state. Stable
uncommitted content, or unknown dirty state, must be selected by its exact
content digest; the checked-out commit does not identify those bytes. Historical
records and digest-based comparisons remain available without rewriting data.
No source contents or raw checkout paths are stored. This is local observational data, not an attestation.

Project, task-class, scenario/version, cohort, pair, model/environment, host and
session labels are short opaque IDs. Do not put personal information or secrets
in them. Evidence/task references accept an opaque ID or HTTPS URL without
credentials, query parameters or fragments. They are never fetched. The SQLite
database has ordinary local filesystem permissions; no encryption is claimed.

## Ordinary recording

Use `start --run-id <stable-id> --project <alias> --skill <name>` once and batch
all known selected skills. `use` can add more while the same source remains
active. One skill exposure per run and package revision is counted, not each
read or invocation. Repeated identical requests do not inflate counts. Changing
facts under an existing run ID or changing a finished outcome is an error.

`finish --outcome completed|partial|failed|abandoned` closes the interval. Leave
interrupted work active until its actual disposition is known; do not silently
mark it successful. In reports, active runs remain visible and do not enter the
finished-run completion denominator. Outcomes and cost belong to the whole task,
so summing per-skill cohorts would double-count tasks with multiple skills.

Optional finish measurements:

| Option | Meaning |
|---|---|
| `--elapsed-seconds` | Explicit measured task interval; otherwise recorded wall time, including waits. |
| `--input-tokens`, `--output-tokens` | Known token totals for the recorded scope. |
| `--tool-calls` | Known tool-call count for the recorded scope. |
| `--cost-usd` | Measured USD cost; no prices or currencies are inferred. |
| `--safety-violations` | Observed violations against the evaluation's stated safety oracle. |
| `--quality-failures` | Observed failures against the evaluation's stated quality oracle. |

Supplied measurements require `--metrics-source <opaque-id>`, identifying the
runner/receipt contract. Never enter estimates under a measured label. Omitted
values stay null and every aggregate shows known/missing counts. A supplied zero
is an explicit observation. For non-declared outcome assessment, use
`--assessment test|independent|user --evidence-ref <safe-reference>`.

## Storage observations

Declare an absolute byte tolerance before work begins with
`start --storage-threshold-bytes <nonnegative-integer>`. This immutable start
fact enables storage evaluation; using the same run ID with a changed tolerance
is a conflict. A zero tolerance is permitted. Both runs in a pair must declare
the same tolerance. Time/cost tolerances remain the evaluation's declared compare
settings. Byte comparisons use absolute differences, including negative retained
growth, rather than percentages of a zero or negative baseline.

Pass `finish --storage-receipt <json-file> --metrics-source <opaque-id>` to
import one bounded receipt from an explicit producer or measurement. The file
path is not retained. The receipt has this versioned shape (values below are
illustrative, not observations):

```json
{
  "schema_version": 1,
  "scope": "owned-output-v1",
  "workload": "build-v1",
  "method": "logical-v1",
  "provenance": "storage-runner-v1",
  "cache_state": "warm",
  "before_bytes": 100,
  "after_bytes": 150,
  "peak_bytes": 200,
  "sample_complete": true,
  "cleanup_failures": 0,
  "rebuild_seconds": null,
  "volume_free": [
    {"volume": "output", "before_bytes": 10000, "after_bytes": 9000, "minimum_bytes": 8000}
  ]
}
```

`scope`, `workload`, `method`, `provenance` and volume aliases are short opaque
identities, not paths. `cache_state` is `cold`, `warm`, `mixed` or `unknown`.
Byte counts and cleanup failures are nonnegative exact integers up to
9007199254740991, or null when unknown. Rebuild seconds is nonnegative and finite,
or null. A supplied zero is an observation. Unknown fields, duplicate JSON
fields, unsupported versions and receipts over 64 KiB are rejected before the
run is finalized. `volume_free` is optional and contains at most 64 uniquely
aliased volumes, each with the four fields shown; measurements may be null.

The derived measures are retained growth (`after_bytes - before_bytes`) and
sampled peak additional footprint (`peak_bytes - before_bytes`). After means
after the producer's cleanup. A sampled peak is a lower bound even when sampling
completed; missing samples, inaccessible paths and interrupted collection must
set `sample_complete` false. Two endpoint snapshots do not establish a sampled
peak. Name the same scope and measurement method on both sides. Logical file
bytes do not establish physical allocation or reclaimable space, especially
with hardlinks, clones or shared caches. Avoid double-counting shared storage.

Host free space is retained only as context: other work may change it and it
never changes attributed growth or the comparison verdict. The recorder does
not scan drives, verify producer declarations, or grant deletion authority.

When evaluating cleanup, include a subsequent representative rebuild and record
its duration on both sides, under equivalent cache conditions. Rebuild duration
is compared as its own lower-is-better dimension using the time tolerance; it
is never added to elapsed time, which may already include it. A rebuild receipt
on only one side is incomplete evidence. If both omit it, the report explicitly
leaves rebuild cost unknown; it cannot substantiate an end-to-end cleanup
productivity claim.

Historical rows remain readable and identically retriable. Their absent storage
fields remain null; there is no migration that invents zero consumption.

## Matched evaluation

Define the scenario, quality/safety oracles, environment, repeat count and
thresholds before running either version. Enroll every attempted run with
`start`; omitted failures cannot be recovered by this collector. Keep the task
inputs fixed, balance ordering where relevant, and use enough independent
repeats for the decision. A sample floor is a policy setting, not a confidence
interval or significance test.

In addition to ordinary start arguments, every matched run requires:

```text
--design matched --task-class repair --scenario dirty-tree --scenario-version v1 --model provider-model-version --environment windows-python-v1 --cohort trial-2026-10 --pair case-001
```

Run the same pair once against each actual source checkout. Pair IDs must be
unique within a cohort, including across scenarios. Use distinct run IDs.
Record the same project, host, task class, scenario/version, model, environment,
cohort, assessment and measurement provenance on both sides. Source content is
the intended difference; a branch nickname is not a source identity.

Finish every attempt with an honest outcome, measured safety/quality counts and
`test`, `independent` or `user` assessment with an evidence reference. Leave
unavailable values unknown. The model/environment labels and evidence remain
caller declarations, so a matching label cannot prove an actually fixed setup.

```text
python <skill>/scripts/skill_metrics.py compare --baseline <recorded-commit-or-sha256:digest> --candidate <recorded-commit-or-sha256:digest> --min-pairs 3 --time-threshold 0.05 --cost-threshold 0.05
```

Selectors are exact complete commits or `sha256:` digests from recorded output.
The result includes all selected baseline/candidate runs, active counts,
exclusions, matched pairs, per-context strata and paired deltas. Positive deltas
mean the candidate's numeric value increased. Completion is higher-is-better;
incident counts, elapsed time and cost are lower-is-better. Token/tool counts
are descriptive and do not determine the verdict.

## Verdict contract

The defaults are three complete pairs and a 5% relative time/cost threshold.
Thresholds are strict: an exactly 5% change is within the default tolerance.
Threshold decisions use exact fractions of recorded decimal values, without a
floating-point epsilon. Storage has the absolute byte tolerance declared at
start; a change exactly at that tolerance is unchanged. Safety, quality,
cleanup failures and a completed-to-unsuccessful outcome have zero tolerance.

- **insufficient:** fewer than the required pairs, or any recorded matched pair
  is duplicate, missing its partner, active, context-incompatible, source-changed,
  source-unverified, self-assessed only, or missing safety/quality observations.
  Storage receipts additionally require a predeclared byte tolerance, matching
  scope/workload/method/provenance, matching known cold or warm cache state,
  complete before/peak/after and cleanup-failure observations, and symmetric
  rebuild measurement. Mixed/unknown cache state, incomplete sampling or missing
  required storage evidence is insufficient. A receipt without a predeclared
  tolerance cannot be silently ignored to claim an overall improvement.
  Such attempts remain counted; fast surviving runs cannot erase them.
- **worsened:** sufficient complete evidence includes any paired safety/quality
  or cleanup-failure increase, or completed-to-unsuccessful outcome, regardless
  of speed savings; otherwise measured dimensions cross only worsening thresholds.
- **mixed:** measured dimensions or comparable strata move in opposing
  directions, without a hard quality/safety/cleanup regression. Faster but larger
  storage use, or less retained storage but a slower rebuild, is mixed.
- **improved:** sufficient evidence has at least one favorable measured change,
  no adverse measured change, and no paired quality/safety regression.
- **unchanged:** sufficient evidence shows no change beyond those tolerances.

Observed hard regressions in otherwise assessed pairs remain listed even when
incomplete storage makes the overall verdict insufficient. Missing optional cost/token observations stay visible; conclusions
cover only measured dimensions. Observational runs remain descriptive and are
excluded from matched evidence. A clean comparison is not permission to merge,
rewrite policy or update consumer pins. Use normal review and acceptance.