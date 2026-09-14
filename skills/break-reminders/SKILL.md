---
name: break-reminders
description: Pace a requested working session with short breaks and goal check-ins using the host's available scheduling or in-session tools. Does not create reminders merely because coding work starts.
---

# Break Reminders

Use when the user requests reminders or a paced session. Installing or discovering
this skill does not authorize creating jobs.

## Establish the session

Use the user's stated cadence, time zone, working window and end condition. If
unspecified, propose short breaks every 30 minutes and a longer break plus goal
check every 2 hours during 9am–5pm local time for this session. Resolve missing
time zone or end time before creating an external schedule; do not invent them.
Cadences are elapsed session time, not a hard-coded clock schedule. Suppress the
short reminder when it coincides with the longer one.

Read only context relevant to the current requested session. A break reminder
does not authorize scanning other projects, private memories or plan directories.

## Select an available mechanism

Inspect the host's actual tool surface and scheduling instructions. Determine:

- whether reminders can recur or only fire once;
- whether time zones, end times and cancellation are supported;
- whether they run only while this session is active or persist outside it; and
- how to inspect existing jobs, confirm creation and cancel them.

Use supported tools and arguments. Do not assume a vendor's cron tool exists,
invent API calls, install a scheduler, or create an OS background task as a
fallback. If the mechanism cannot honor the requested window and lifetime, say
so and offer an in-session alternative. Without background scheduling, explicitly
state that no scheduled reminder is active and timing depends on the session
remaining active.

## Create and verify only the requested reminders

Check for existing reminders for this same session and purpose when listing is
available. Reuse a matching job rather than duplicate it. If existing state
cannot be established, resolve duplicate risk before adding a recurring job.

Create only the authorized cadence, window and lifetime. Read back the returned
job identity and schedule before saying it is active. A partial failure is a
partial result: report which reminder exists, which failed and how to cancel the
successful one. Do not retry blindly and accumulate jobs.

Report the actual time zone, next firing time, expiry/session lifetime and
cancellation method. Do not claim a universal expiry period. Cancel task-owned
reminders when requested or at the agreed session end; never cancel unrelated
jobs. Do not claim automatic cancellation unless the mechanism enforces it.

## Reminder content

For a short break, suggest briefly standing up or resting the eyes. For the
longer break, summarize progress against the current goal and ask one concise
question about the next focus. Use the host's supported question tool when
appropriate, or ordinary conversation; no named questionnaire API is required.

A check-in does not authorize switching tasks, committing, publishing, or
expanding a backlog. Continue within the user's existing scope.
