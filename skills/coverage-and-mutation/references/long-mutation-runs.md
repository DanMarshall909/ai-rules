# Long mutation runs

## Keep waiting cheap

Respect the user's separate priorities for runtime, agent tokens, memory and
disk. A local mutation process consumes compute; model calls to supervise and
analyse it consume tokens. Long elapsed time alone does not warrant cancelling
a useful run or reducing its required scope.

Prefer the repository driver with logs captured outside model context and a
completion notification or blocking tool wait. Use tools to wait within the
host's limits. Where a host wait wakes on new user input, use that capability to
keep unattended waiting responsive without frequent model round trips.
When repeated short waits would require new model turns, prefer
an existing background runner that records terminal results for later collection.
Where notifications are unavailable, use infrequent lightweight status checks. Each
check should answer a concrete question and return a compact delta. Do useful
independent work or leave agents idle; do not recruit agents solely to watch a
running process.

Set monitoring thresholds from user constraints and repository evidence. Act on
a failed baseline, disk or memory pressure, a process failure, or credible lack
of progress. CPU activity proves liveness, not completed mutants. When progress
is unavailable, disclose that limit and avoid inventing an ETA.

## Read results once, then inspect findings

Parse reports with deterministic tools. Start with scope, outcome counts, test
attribution and survivor clusters, retaining links to all raw findings. Open
specific source or report details when a finding requires judgment. Full report
review still covers the required scope; compact summaries must not hide cases.

Reuse inspection results while their source, tests, configuration, tool and
artifact bindings remain valid. Repeated unchanged status or duplicate stop
hooks do not require rebuilding the same analysis. Changed evidence requires
the affected checks again.

Record runtime, scope, tool/configuration identity, actual completed counts and
resource observations in existing run evidence. Attribute token cost only when
usage records support it; aggregate goal tokens cannot establish a mutation
share or monetary cost.

Measure the whole controller separately from the native process: include outer
tool waits, automatic goal continuations, commentary and context supplied again
on each model round trip. Label nested launch/collection call and response-byte
counts with their narrower scope. Small native output does not establish low
agent token use. Preserve host usage-counter snapshots and accounting timestamps;
their difference is an observation until accounting boundaries and concurrent
agent activity support attribution to the measured interval.

## Preserve evidence before cancellation

Check the pinned runner's interrupt and partial-report behaviour. Preserve logs,
configuration, source/test bindings, process identity and available reports;
reference existing large artifacts instead of duplicating them under disk
pressure. Warn when results held only in memory may be lost.

Use the runner's supported graceful stop within existing authority. Keep the
driver able to record the exit, confirm owned workers have stopped and verify
source state. Bound shutdown waits using the runner's known behaviour; escalate
only against identified owned processes within authority. Retain instrumented
outputs needed for diagnosis, then restore or
rebuild from source before using binaries for verification.

Label interrupted runs and pending or unknown outcomes explicitly. An
interrupted run does not satisfy a required full gate. Accept reuse or resume
only when the pinned tool's calibrated invalidation contract supports it;
neither a log snapshot nor a successful prior run is proof of resumability.

## Diagnose a slow run before repeating it

Use a bounded diagnostic window before an authorized stop. Verify supervisor and
worker identities, retain effective configuration/logs, and capture a short trace
supported by the installed profiler or actual test-duration evidence. Record
current test activity and CPU, memory and disk observations. Cancel through the
owned supervisor, verify its workers exit, and label absent outcomes incomplete;
a partial artifact does not establish resumability.

Separate build, initial tests, coverage collection and mutation execution. Check
static-initializer test expansion against the pinned runner's implementation,
fixture/workspace setup, actual test selection, timeout/restart evidence and
temporary-file cleanup. Distinguish measured causes from hypotheses: waiting
threads are not proof of inactivity, directory counts are not ownership proof,
and sampled thread time is not CPU time or a whole-run profile.

Optimize the measured hot path first. Repeated construction of expensive reusable
inputs can dominate tests; retain instance inputs when safe, while re-driving and
asserting the behavior for each mutant. Never cache the system's answers. Verify
thread safety, culture/options, finite cache keys and mutation activation.

Compare compact representative pilots with whole-owner mutation scope and frozen
independent assertions. Retain raw reports, mutant identities, survivors and phase
timings outside model context. Disclose startup overhead and concurrent workloads;
measure concurrency only after the bottleneck is understood. Present measured
results and a defensible runtime estimate before repeating an expensive full run.
Pilot results cannot replace its required full gate or justify weaker thresholds
or missing controls.
