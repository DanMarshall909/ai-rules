---
name: storage-budget
description: 'Use when measuring development storage, checking disk budgets before heavy operations, or running commands with verified disposable-output cleanup.'
---

# Storage Budget

Use the included Python 3.10+ CLI before a build, restore, large test run, export
or other heavy producer. It measures bounded scopes, checks the actual output
and temporary volumes, and can supervise a command whose new output is explicitly
disposable. It does not intercept commands launched elsewhere or grant cleanup
authority over existing files. Read [the contract](references/contract.md) for
configuration, execution limits, receipt interpretation and recovery.

## Inspect and admit

1. Read project instructions and identify the workload, output parent, temporary
   parent and any input tree being copied. Preserve active work and existing
   caches. Do not scan whole drives. Use registered Git worktrees or explicitly
   named output directories:

   ```text
   python <skill>/scripts/storage_budget.py inventory --repo <checkout> --root <declared-output>
   ```

   Inventory does not follow links, has depth/count/time bounds, deduplicates file
   identities and reports incomplete scans. Logical size is not allocated or
   reclaimable space. Category hints and Git integration do not establish value,
   ownership, inactivity or deletion permission.
2. Use the repository's version 2 `.ai-rules.json` named workload budget. Version
   1 remains valid for existing consumers, but cannot authorize a heavy managed
   run without a disk budget. Keep estimates labelled as estimates.

   ```text
   python <skill>/scripts/storage_budget.py check --config <repo>/.ai-rules.json --workload checks --output-parent <existing-dir> --temp-parent <existing-temp-dir>
   ```

   Insufficient space or missing observations block only this producer. Continue
   unrelated work that does not require the unavailable capacity. Do not delete
   caches to manufacture a passing check. Same-volume growth is summed; reserves
   apply once per volume. A passing sample is not a reservation against other jobs.
3. For retained storage review, add `--config <repo>/.ai-rules.json --workload
   checks` to inventory. Compare the logical build/dependency/evidence footprint
   with the retention budget, investigate unknown content, and explain rebuild
   costs before requesting deletion of reusable state. Keep source, shared caches,
   evidence and deferred work separate. No automatic cache eviction is provided.

## Run and verify disposable-output cleanup

Use `run` only for trusted foreground commands configured to write disposable
output into `AI_RULES_RUN_DIR` and temporary data into `TEMP`/`TMP`/`TMPDIR`.
The runner creates fresh directories; it never adopts an existing output tree.
Do not put durable evidence or reusable caches there. Route those to approved
locations separately and include their volumes in project planning.

```text
python <skill>/scripts/storage_budget.py run --config <repo>/.ai-rules.json --workload checks --output-parent <existing-dir> --temp-parent <existing-temp-dir> --receipt <new-receipt.json> --scope disposable-checks-v1 --cache-state cold --timeout-seconds 600 -- <executable> <arguments>
```

For copy/export commands, supply `--source <input-directory>`; output and temp
parents inside that source are rejected to prevent recursive self-copying. This
checks declared paths, not an arbitrary command's implementation. The command
must honor the output contract; other writes are neither intercepted nor measured.

The runner checks live free space, stops only its owned process tree on timeout,
cancellation or reserve exhaustion, and cleans verified disposable directories.
Windows uses a Job assigned before execution; POSIX uses an owned process group.
Daemonizing or escaping that group is unsupported. A forced supervisor kill or
machine loss may leave output; preserve it for explicit recovery, never infer
successful cleanup. Unknown ownership, linked paths, changed identities, incomplete
inspection or failure to prove workers stopped preserves affected output.

Inspect the exit status and JSON report. Nonzero means blocked/failed/cancelled
execution or cleanup failure; keep command outcome distinct from cleanup outcome.
The receipt file contains only the agreed measurement contract and is directly
accepted by `skill-metrics finish --storage-receipt <file>`. The stdout envelope
contains local admission details, retained paths and a bounded command-output tail.
Receipts are local files; do not publish private output automatically.

Record declared storage tolerance before either evaluation run. Match workload,
scope, method and cold/warm cache state. Sampled peak is a lower bound; missing
or incomplete observations are unknown. Host free space is context, not task
consumption. Include the next rebuild time when evaluating reusable-cache cleanup.
