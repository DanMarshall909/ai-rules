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
- When the file is the authoritative tracker, resolution updates
  `status: Resolved`, adds a decision-log entry and moves it to `resolved/[area]/`.
- When GitHub owns workflow status, a linked file's open/resolved location tracks
  only whether its investigation is archived. Do not add a duplicate task-status
  field; record the archive decision and link to live status.
- On resolution of a GitHub-tracked item: follow the project's completion rules
  and update any linked durable file in the same change.

If the repository declares neither approach, use `docs/issues/` rather than
inventing another local folder.

Use the repository's available tracking tools or edit the authorized record
directly. For a security finding, also use the `security-by-design` skill; this
repository does not supply separate issue or security-finding slash commands.
