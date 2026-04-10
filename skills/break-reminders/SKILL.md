# Break Reminders Skill

Sets up two recurring break reminders for working hours (9am–5pm). Invoke with `/break-reminders` at the start of a session.

---

## What this does

Schedules two cron jobs:

| Reminder | Cadence | Purpose |
|----------|---------|---------|
| Short break | Every 30 min, 9:00–4:30pm | Quick rest + cross-project memory scan |
| Longer break + goal wizard | 9:07, 11:07, 13:07, 15:07 | 10–15 min break + progress/goal check-in |

Both reminders scan **all Claude project memories** (not just the current project) before reporting back.

---

## Step 1 — Schedule the short break reminder

Call CronCreate with:
- `cron`: `*/30 9-16 * * *`
- `recurring`: `true`
- `prompt`:

```
Short break reminder — stand up and rest your eyes for a couple of minutes.

While paused, do a quick cross-project check:
1. Read C:\Users\DanMarshall\.claude\projects\ to see all project memory folders
2. For each project that has a MEMORY.md, skim the index
3. Note anything relevant or urgent across all projects

Then briefly tell the user: what's been covered this session, and whether anything from another project needs attention.
```

---

## Step 2 — Schedule the longer break + goal wizard

Call CronCreate with:
- `cron`: `7 9-15/2 * * *`
- `recurring`: `true`
- `prompt`:

```
Time for a longer break — step away for 10–15 minutes.

First, do a cross-project review:
1. Read C:\Users\DanMarshall\.claude\projects\ — list all project folders
2. For each project, read its MEMORY.md to pick up any open threads, pending beads, or flagged work
3. Also check C:\Users\DanMarshall\.claude\plans\ for any active plan files

Then use AskUserQuestion to run this wizard:

Q1 header: "Progress"
Question: "How is the session tracking against the goal?"
Options:
  - On track — everything going to plan
  - Slightly off track — minor detour but recoverable
  - Need to pivot — goal has shifted or something's blocking

Q2 header: "Next goal"
Question: "What's the focus after the break?"
Options:
  - Continue current work — same bead / task
  - Start a new bead — pick up something from the backlog
  - Review open issues — triage docs/issues/open/
  - End session — wrap up and commit

After the wizard, summarise: current status, next focus, any blockers, and anything flagged from other projects.
```

---

## Step 3 — Confirm

Tell the user both reminders are active and show this summary:

| Job | Cron | Fires at |
|-----|------|----------|
| Short break | `*/30 9-16 * * *` | Every 30 min, 9:00–4:30pm |
| Longer break | `7 9-15/2 * * *` | 9:07, 11:07, 13:07, 15:07 |

Remind them that cron jobs are session-only and auto-expire after 7 days — re-run `/break-reminders` at the start of each session to restore them.

---

## Notes

- To cancel early: `CronDelete <job-id>` (job IDs shown at scheduling time)
- To fire a short break immediately: ask Claude to "fire a short break now"
- Times are in local timezone
- Adjust `9-16` / `9-15` hour ranges if your working hours differ
