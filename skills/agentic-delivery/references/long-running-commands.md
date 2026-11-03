# Long-running commands

Read when a command needs background observation or mechanical waiting, and
before changing an observation policy. Host limits and responsiveness apply.

### Wait without repeated orchestration

For long commands, retain the exact command, working directory, source and
runtime identity, complete output, timing and eventual exit status, including
failures and cancellations. Reuse the runner's log or receipt; add only missing
evidence. Prefer an established, tested supervisor over a per-ticket wrapper.
Requalify it when its implementation, execution contract or relevant environment
changes, or a failure calls its evidence into question; ordinary use needs no
fresh supervisor calibration. Silence and partial artifacts remain pending,
never success.

Prefer completion notifications or a background collector that wakes the
controller on meaningful output or termination. Where polling is necessary,
use interruptible capped exponential waits: 30, 60, 120, 240, then at most 300
seconds; reset on meaningful progress, not heartbeats or quiet polls. Keep
waiting and backoff in the tool or runner where supported. Avoid model turns,
duplicate watchers and status narration solely to restate an unchanged pending
state. Host limits and required responsiveness take precedence; report when
available controls cannot prevent repeated controller wakeups. A collector
alone does not prove that model invocations have stopped.

Give each fallback observation an explicit finite deadline. Reaching it returns
`pending` with the original process/task identity and evidence location; it does
not imply failure, cancel the producer or authorize restarting it. Cancellation
of the observer must interrupt its wait promptly and preserve the producer
unless cancelling that producer is separately authorized. Resume observation of
the same live handle or retained receipt. Only an identity-matched terminal
receipt with a valid numeric exit status proves completion; absent, malformed
or mismatched receipts remain unverified.

Qualify a changed observation policy with success, failure, quiet and
heartbeat-only output, a semantic progress transition, observation expiry and
observer cancellation. Demonstrate that expiry/cancellation preserves the live
producer and that a later observer collects its terminal result. Heartbeat
bytes or timestamps alone are not progress and must not reset backoff. Retain
the exercised policy, timing and terminal evidence; a capped delay alone does
not prove a bounded observation.
