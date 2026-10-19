# Issue & Finding Tracking

Follow the project's declared GitHub Issues/optional Projects, repository
Markdown, external tracker or hybrid. Preserve declared paths and schemas;
do not force migration or introduce a second authority to mirror status.

Keep one authority per live fact. In a hybrid, assign distinct jobs: the chosen
tracker owns live priority, assignment and status; repository files may hold
durable investigation, evidence, decisions or security findings. Link stable
item, criterion, dependency and evidence references without competing status
fields. OpenSpec design/evidence is not automatically a workflow tracker.

Use the discoverable skill packages `track-github-work`,
`track-repository-work` or `track-external-work-items` for mechanics.
Missing packages or access require honest capability reporting; use available
authorized tools without claiming a workflow loaded or synchronization succeeded.

Only if no tracker or repository layout is declared, use:
```text
docs/issues/
  open/[area]/[ticket-id]-[slug].md
  resolved/[area]/[ticket-id]-[slug].md
```
Discover existing business-domain areas. For authoritative fallback files,
resolution sets `status: Resolved`, records evidence in the decision log and
moves the file to `resolved/[area]/`. For linked evidence files, open/resolved
means investigation archival only; record that decision and link live status.
Close work only under the project's completion rule; update linked evidence
within the authorized change.

Reread before narrow updates, preserve concurrent edits, use supported
conditional writes and read back results. Unavailable access is not no work.
Label unsynchronized drafts; never create a shadow tracker. Existing task-update
authority covers routine in-scope maintenance; outreach needs separate authority.
For security findings, also use `security-by-design`.
