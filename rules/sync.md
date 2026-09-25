# Rules and Skills Sync

Before the first non-trivial repository task in a session, run the installed `upgrade-global-skills` preflight when network access
is available: PowerShell on Windows, Bash on Linux or macOS. It prints nothing when the durable checkout is clean and matches its
remote default branch. Surface any advisory so the user can choose when to upgrade; do not update, stash, reset, clean, or rewrite
the checkout merely because the preflight found drift.
