# Cross-Agent Rules and Skills

Status: design recommendation

Last verified: 2026-09-10

## Decision

Keep one authored source for shared guidance, but distribute it through each
agent's native instruction and skill locations.

- `rules/` owns concise guidance that must apply throughout every task.
- `skills/<name>/SKILL.md` owns detailed procedures and reference material that
  are useful only for particular work.
- Generated or installed adapter files expose those sources in the locations
  each agent actually discovers.
- A repository's own `AGENTS.md` remains project-owned. Installing global rules
  must not replace it.
- Project instructions may deliberately refine a global default. Global rules
  must say this explicitly because not every agent implements override
  semantics.

The existing generated base rule set is 628 lines and 32.4 KiB. Loading that
beside a substantial project `AGENTS.md` spends context on procedures that are
irrelevant to most tasks and can cross instruction-size limits. The base policy
should become short; detailed TDD, coverage, mutation, security-review,
reflection, and similar workflows should be skills.

## Canonical layout

This repository remains the source of truth:

```text
rules/                          concise, always-on policy fragments
skills/<name>/SKILL.md          portable, task-specific workflows
rule-sets/                      generated policy bundles where still needed
```

For portable personal skills, standardize installation on:

```text
~/.agents/skills/<name>/SKILL.md
```

Codex, OpenCode, and GitHub Copilot discover that location. Claude Code does
not, so its per-skill entries under `~/.claude/skills/` should link to the same
canonical skill directories. At project scope, use `.agents/skills/` and link
the corresponding Claude entries from `.claude/skills/`.

Do not maintain hand-edited copies. Where a product cannot consume a symlink or
an import, generate the adapter and provide a drift check.

## Vendor adapters

### Anthropic Claude Code

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. Anthropic recommends a project
`CLAUDE.md` containing:

```markdown
@AGENTS.md
```

Keep the global import in `~/.claude/CLAUDE.md`, and install shared skills under
`~/.claude/skills/` as links to this repository's skill directories.

Useful native tools:

- `/context` confirms which instruction files loaded.
- `/memory` displays and edits memory sources.
- `/init` creates or proposes improvements to project instructions.
- `claude import --dry-run codex` previews a one-time migration from Codex.
  Import is useful for migration, not synchronization, because it appends a
  copy.

Anthropic recommends keeping each always-loaded instruction file under roughly
200 lines and moving multi-step procedures into skills or path-scoped rules.

### OpenAI Codex

Codex reads global defaults from `~/.codex/AGENTS.md`, then repository
`AGENTS.md` files from the root toward the working directory. Later,
more-specific project guidance overrides earlier guidance.

Install a concise generated global policy at `~/.codex/AGENTS.md`. Do not point
the installer at a repository's existing root `AGENTS.md`.

Codex discovers personal skills in `~/.agents/skills` and repository skills in
`.agents/skills`. It supports symlinked skill directories.

Useful native tools:

- `/skills` or `$skill-name` discovers and invokes skills.
- `$skill-creator` creates or updates a skill.
- `$skill-installer` installs reusable skills.
- `codex --ask-for-approval never "List the instruction sources you loaded."`
  audits instruction discovery.

Codex stops adding project instruction files at `project_doc_max_bytes`, which
defaults to 32 KiB. This is another reason not to inject the full rule set into
every session.

### OpenCode

OpenCode V2 loads `~/.config/opencode/AGENTS.md`, then discovered project
`AGENTS.md` files. It combines them and does not resolve conflicts. Therefore:

- install broad defaults globally;
- leave project `AGENTS.md` files project-owned;
- state in the global policy that explicit scoped project rules refine global
  defaults;
- remove genuine contradictions instead of relying on load order.

The V2 `instructions` configuration array is currently parsed but is not
resolved into model instructions. Use `AGENTS.md` for active guidance.

OpenCode discovers both personal and project skills from `.agents/skills`, so
it can consume the shared standard directly. `opencode debug config`,
`opencode debug skill`, and `opencode debug paths` are the relevant local
diagnostic commands.

### GitHub Copilot

Copilot CLI loads repository instructions such as `AGENTS.md` and
`.github/copilot-instructions.md`, plus personal CLI instructions from
`~/.copilot/copilot-instructions.md`.

`AGENTS.md` is not supported by every Copilot feature. Repositories that need
consistent behavior across Copilot surfaces should also carry a concise,
generated `.github/copilot-instructions.md`. That file has higher precedence
than `AGENTS.md`, so it must not contradict it.

Copilot discovers personal and repository skills from `.agents/skills`.
`gh skill` can search, preview, install, update, and publish skills with GitHub
CLI 2.90.0 or newer. Preview third-party skills before installation.

## Existing portable rule tools

This repository is not the only project solving rule distribution. The main
active candidates are:

| Tool | Source model | Coverage | Relevant trade-off |
|---|---|---|---|
| [Rulesync](https://github.com/dyoshikawa/rulesync) | `.rulesync/` authored sources, generated native outputs | Rules, skills, MCP, commands, subagents, hooks, permissions; includes Claude Code, Codex, OpenCode, Copilot, and Copilot CLI | Closest mature superset. It generates files rather than providing live symlinks, but has `--dry-run`, CI `--check`, `doctor`, import, conversion, watch mode, and an MIT license. Its global-mode page and support matrix currently disagree about Codex global rules, so that path must be proven in a spike. |
| [Ruler](https://github.com/intellectronica/ruler) | `.ruler/` Markdown and TOML, generated native outputs | Rules, nested rules, MCP, skills, and experimental subagents across all four target agents | Simpler rule-first design with global fallback, dry-run, backups, and revert. It is still labelled a beta research preview; skills and subagents are experimental, and it copies generated files. |
| [AgentSync](https://github.com/dallay/agentsync) | `.agents/` canonical files with destination symlinks | Instructions, skills, commands, and MCP for Claude, Codex, OpenCode, Copilot, and others | Best match for this repository's live-link philosophy. Its documented Codex and OpenCode skill destinations do not use the shared `.agents/skills` path, and Copilot skill support is incomplete in its feature table, so adapters would still need verification. |
| [AI Rules Sync](https://github.com/lbb00/ai-rules-sync) | Rule repositories cloned into a cache and symlinked into projects | Rules, skills, commands, and subagents, with project and user configuration | Also close to the current design and supports live updates. It is substantially smaller and less established than Rulesync or Ruler. |
| [AgentSync (`agent_sync`)](https://github.com/yelmuratoff/agent_sync) | `.ai/src/` transformed into native files | Thirteen tools, path-scoped rules, skills, commands, agents, MCP, snapshots, rollback, and checks | Broad and deliberately cross-platform, but newer, lightly adopted, and GPL-3.0-only. |

The portable standards underneath these tools are more important than any one
generator:

- [`AGENTS.md`](https://agents.md/) is the common project-instruction
  convention, with vendor adapters where a product requires another filename.
- [Agent Skills](https://agentskills.io/) standardizes a `SKILL.md` package of
  instructions and optional resources. Claude Code, Codex, OpenCode, and
  Copilot all support the format, although their discovery directories differ.

### Replacement spike results

A contained Linux spike ran on 2026-09-10 against Rulesync 16.26.1, Ruler
0.3.44, and AgentSync 1.45.2. Each candidate used throwaway project and home
trees. The global Rulesync run was additionally isolated with a filesystem
sandbox because its global mode ignored `--output-roots` and resolved the real
home directory.

Rulesync proved broad generation and the best generated-file drift workflow:
project and user-scope outputs covered Claude Code, Codex, OpenCode, repository
Copilot, and Copilot CLI; repeated generation was content-idempotent; and
`--dry-run` and `--check` correctly reported changes without writing. It failed
the ownership and removal boundaries, however. Project generation replaced an
existing root `AGENTS.md` even with `delete: false`, and `--delete` removed
unowned skill directories from every managed destination. Its global mode also
ignored an explicit output root, and its global-mode guide understated the
Codex support the CLI actually provided.

Ruler did not provide user-scope agent outputs: its global configuration is a
fallback source for project generation. The first project apply backed up and
included an existing root `AGENTS.md`, but a second apply dropped that content
from the generated files. `revert` restored the root backup yet left generated
skills, nested outputs and backups, and a generated `CLAUDE.md` after repeated
applies. Nested generation worked, but remained experimental, and the released
CLI rejected the documented `revert --nested` option.

AgentSync was the only candidate that could express the intended ownership
model. A custom configuration kept the repository's root `AGENTS.md` as a
regular project-owned file, linked Claude and Copilot adapters to it, kept
`.agents/skills` canonical, and created per-skill Claude compatibility links
without disturbing an unowned skill. Treating a throwaway home as the project
root also produced the required personal Claude, Codex, OpenCode, and Copilot
paths. Applies were idempotent, source edits propagated immediately, and
`status` detected and `apply` repaired a deliberately broken global link.

AgentSync still fell short of selection. `status` reported a false missing path
for a working `nested-glob` target, `clean` removed managed links but did not
restore displaced files from their `.bak` files, and user-scope use required an
undocumented custom-project configuration. Its default GNU/Linux binary also
required GLIBC 2.38/2.39 and would not start on this GLIBC 2.35 host; the
checksummed musl build worked. Native Windows execution remains unproven by
this spike.

### Recommendation

Do not adopt any candidate as the distribution engine yet. Rulesync and Ruler
violate hard ownership or idempotence requirements. AgentSync is a useful
reference implementation for symlink behavior, but adopting it would still
require wrappers for personal scope, nested drift checks, backup restoration,
and platform-specific binary selection.

Proceed with the installer modernization below, retaining `rules/` and
`skills/` as the authored sources. Re-evaluate AgentSync if its native global
mode, nested status, and backup-restoring cleanup mature. The implementation
must still prove Windows behavior in CI before release.

## Installer changes implied by this decision

If the spike rejects the existing tools, the current installers should be
modernized. They predate these vendor conventions. A follow-up change should:

1. Install the short base policy to user-level native instruction locations:
   - Claude: `~/.claude/CLAUDE.md`
   - Codex: `~/.codex/AGENTS.md`
   - OpenCode: `~/.config/opencode/AGENTS.md`
   - Copilot CLI: `~/.copilot/copilot-instructions.md`
2. Never replace a project's root `AGENTS.md` while installing global rules.
3. Standardize portable skills on `~/.agents/skills` and `.agents/skills`.
4. Create only the Claude compatibility links required under
   `.claude/skills`.
5. Add Copilot detection and installation support.
6. Test discovery paths, idempotence, existing-file preservation, symlink
   behavior, and generated-adapter drift on Linux and Windows.

## DnDan compatibility audit

DnDan's root `CLAUDE.md` already uses the Anthropic-recommended `@AGENTS.md`
adapter. Its root `AGENTS.md` is recognized by Codex, OpenCode, and Copilot
agent features.

The remaining incompatibilities are:

- The personal Claude instructions require FluentAssertions, while DnDan
  requires Shouldly. Framework-specific assertion guidance belongs in the
  repository, not the global file.
- DnDan says `git pull --rebase` before every push without the shared rule's
  merge-commit exception.
- DnDan's technology table calls OpenSpec the issue tracker, while its later
  workflow correctly makes GitHub Project authoritative for priority and
  status and keeps OpenSpec responsible for specifications.
- DnDan's project skills live only in `.claude/skills`, so Codex, OpenCode, and
  Copilot cannot discover them. Portable skills should move to
  `.agents/skills`, with Claude compatibility links.
- The combined global and project instruction payload is too large. The
  project file should retain project architecture, commands, and hard
  constraints while reusable procedures move into skills.

These should be fixed only after the shared installer and precedence contract
are corrected, so DnDan consumes the supported mechanism rather than another
one-off arrangement.

## References

- Anthropic: [Claude Code memory and instruction files](https://code.claude.com/docs/en/memory)
- Anthropic: [Claude Code skills](https://code.claude.com/docs/en/slash-commands)
- OpenAI: [Codex `AGENTS.md` discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- OpenAI: [Building Codex skills](https://learn.chatgpt.com/docs/build-skills)
- OpenCode: [Instruction discovery](https://opencode.ai/v2/docs/instructions)
- OpenCode: [Skills](https://opencode.ai/v2/docs/skills)
- GitHub: [Copilot response customization](https://docs.github.com/en/copilot/concepts/prompting/response-customization)
- GitHub: [Copilot agent skills](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
- GitHub: [Copilot CLI customization features](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/comparing-cli-features)
- Ecosystem: [Rulesync](https://github.com/dyoshikawa/rulesync)
- Ecosystem: [Ruler](https://github.com/intellectronica/ruler)
- Ecosystem: [AgentSync](https://github.com/dallay/agentsync)
- Standard: [Agent Skills](https://agentskills.io/)
