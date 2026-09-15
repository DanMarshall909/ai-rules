# Rules and Skills Sync

Before the first non-trivial repository task in a session, run the
`upgrade-global-skills` package's preflight script when it is installed and
network access is available. Use `check-rules-sync.ps1` on Windows and
`check-rules-sync.sh` on Linux or macOS.

The preflight is deliberately quiet when the durable rules checkout is clean and
matches its remote default branch. Surface any advisory it prints so the user
can choose when to upgrade. Do not update, stash, reset, clean, or rewrite the
checkout merely because the preflight found drift.
