# Issue & Finding Tracking

Projects may track work in GitHub Issues and Projects, in repository markdown,
or in both. Follow the repository's declared tracker; do not introduce a second
authority merely to mirror status.

When both are used, give them distinct jobs:

- GitHub owns live priority, assignment, and workflow status.
- Repository files hold durable investigation, evidence, decisions, or security
  findings that benefit from review and version history.
- Link the two records. Do not duplicate an issue body or maintain competing
  status fields in both places.

All file-backed issues and findings use this canonical folder structure:

```
docs/issues/
  open/[area]/[ticket-id]-[slug].md
  resolved/[area]/[ticket-id]-[slug].md
```

- `area` = business domain (api, auth, payments, pii, booking, database, …)
- Discover existing areas from the folder structure — don't hardcode them
- If a file is linked to a GitHub issue, include the issue URL and use one stable
  ticket identity in both records.
- On resolution of a file-backed record: update `status: Resolved`, add a
  decision-log entry, and move it to `resolved/[area]/`.
- On resolution of a GitHub-tracked item: follow the project's completion rules
  and update any linked durable file in the same change.

If the repository declares neither approach, use `docs/issues/` rather than
inventing another local folder.

> Claude Code users: use `/issue` and `/security-finding` skills.
