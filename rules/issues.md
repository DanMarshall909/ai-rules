# Issue & Finding Tracking

All issues and security findings are documented as markdown files.

**Folder structure:**
```
docs/issues/
  open/[area]/[ticket-id]-[slug].md
  resolved/[area]/[ticket-id]-[slug].md
```

- `area` = business domain (api, auth, payments, pii, booking, database, …)
- Discover existing areas from the folder structure — don't hardcode them
- On resolution: update `status: Resolved`, add decision log entry, move to `resolved/[area]/`

> Claude Code users: use `/issue` and `/security-finding` skills.
