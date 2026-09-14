# ai-rules

Lean, agent-agnostic AI coding rules. Works with Claude Code, Codex, OpenCode,
GitHub Copilot, Cursor, and Cline.

The concise, always-loaded shared policy lives in
[`rule-sets/ai-rules.md`](rule-sets/ai-rules.md).

`AGENTS.md` is intentionally minimal. It points agents at the rule set instead
of carrying the full policy itself.

The distribution decisions and dated migration research are documented in
[`docs/cross-agent-rules-and-skills.md`](docs/cross-agent-rules-and-skills.md).
The installation sections below are the maintained usage contract.

## Start here

Choose one workflow:

- **Adopt the shared policy:** use `install-rules.sh`. It includes the skills
  declared by the selected set; no second skill-install step is required.
- **Reconcile an existing setup:** use `adopt-ai-rules` to inventory current
  instructions and skills, confirm duplicate cleanup, and flag portable local
  guidance without silently promoting it.
- **Use one workflow without adopting policy:** use `install-skill.sh`, or
  `install-skill.ps1` on Windows.
- **Contribute here:** read [the maintainer skill](skills/ai-rules/SKILL.md),
  edit authored sources, regenerate and run [Checks](#checks).

Clone to a durable location, then preview and install for the intended agent:

```bash
git clone https://github.com/DanMarshall909/ai-rules ai-rules
cd ai-rules
scripts/install-rules.sh --agent codex --dry-run
scripts/install-rules.sh --agent codex
```

Replace `codex` with your agent. For Cursor or Cline, add
`--project /path/to/existing-project`; otherwise their destination is the
invoking directory. Profile agents remain profile-scoped for a standalone/base
policy. Use Git Bash for rule installation on Windows; there is currently a
PowerShell skill installer, not a PowerShell rules installer.

Links remain live to this checkout. Keep it available; do not install from a
temporary worktree you intend to remove. Use the dry-run output to inspect every
destination before changing real instructions.

## Rule sets

A rule set is a manifest (`rule-sets/<name>.set`) naming the rule fragments it
ships, and the markdown file generated from it. `ai-rules` is the default base
set; a set that *layers* on it is an addition for one kind of repo,
read alongside the base rather than instead of it.

A manifest without `layer:` is standalone. Selecting it with `--rule-set`
installs that policy in the agent's native instruction location. Standalone sets
use profile scope where the agent supports it; `--project` selects the destination
for project-scoped agents. `--list --rule-set <name>` reports the selected set.
Selection is not uninstallation: other named set adapters may remain, especially
in Cursor/Cline rule directories. Inspect existing instructions when switching
standalone policies so conflicting always-loaded sets are not left active.

| Set | For | Layers on |
|-----|-----|-----------|
| `rule-sets/ai-rules.md` | every project | — |
| `rule-sets/tool-repos.md` | repos whose product is a tool an agent drives | `ai-rules` |

Making one:

```bash
scripts/new-rule-set.sh --title "Tool Repo Rules" \
  --blurb "For repos whose product is a tool an agent drives." \
  --layer ai-rules my-tools         # choose an unused name

scripts/new-rule.sh --set my-tools --title "Agent Contract" agent-contract
scripts/new-rule.sh --title "Caching" caching     # into the base set

scripts/new-skill.sh --set my-tools --description "Use when ..." my-skill
```

A skill a set claims travels with it. Base-set skills retain each agent's normal
profile or project scope; layered-set skills install project-scoped, so guidance does not
load in unrelated sessions. Installing a layered set into the repo that wants
it:

```bash
scripts/install-rules.sh --rule-set tool-repos --project ../some-tool --dry-run
scripts/install-rules.sh --rule-set tool-repos --project ../some-tool
```

| Agent | Gets |
|-------|------|
| `claude` | `@` import of the set appended to the project's `CLAUDE.md` |
| `codex`, `opencode` | `<project>/rule-sets/<set>.md`, plus one pointer line in the project's `AGENTS.md` |
| `copilot` | the same set and `AGENTS.md` pointer, plus a preserving `.github/copilot-instructions.md` adapter |
| `cursor` | `.cursor/rules/<set>.mdc` |
| `cline` | `.clinerules/<set>.md` |

The project's own `AGENTS.md` and `CLAUDE.md` are appended to, never replaced,
and never twice — a layered set arrives in repos that already have both.

## Rules

| Rule | What it does |
|------|-------------|
| `rules/breaks.md` | Requested session pacing with available host capabilities |
| `rules/tdd.md` | Criterion-led RED → GREEN → COVERAGE → REFACTOR |
| `rules/coverage.md` | Code must justify itself; establish reachability before excluding branches |
| `rules/guardrails.md` | Turn a repeatable mistake into a test that fails at build time |
| `rules/security.md` | Concentrate security decisions behind one narrow, intent-named boundary |
| `rules/git.md` | Integrate before review; preserve approved bytes and merge history |
| `rules/issues.md` | GitHub and/or canonical `docs/issues/[open\|resolved]/[area]/` tracking |
| `rules/reflection.md` | Capture durable lessons when work lands; route them to the right scope |
| `rules/authority.md` | Instruction precedence, task authority, and proportionate scope |

For non-trivial autonomous feature delivery, use `agentic-delivery`. It binds
accepted scope to criterion-led TDD, quality evidence, independent completion
review, exact publication, cleanup, and owner-confirmed workflow lessons. Its
environment modules keep the core portable while adapting test, coverage, and
mutation mechanics for .NET and JavaScript/TypeScript; repositories can provide
local modules for other stacks. Explicit task and scoped project instructions
refine shared defaults within the host's instruction hierarchy; skills and
adapters do not add authority.

## Workflow owners

| Decision | Procedural owner |
|---|---|
| Adopt or reconcile rule and skill installations | [adopt-ai-rules](skills/adopt-ai-rules/SKILL.md) |
| Deliver accepted implementation scope | [agentic-delivery](skills/agentic-delivery/SKILL.md) |
| Design tests and complete each TDD cycle | [behavior-first-tdd](skills/behavior-first-tdd/SKILL.md) |
| Interpret coverage, mutants and pruning evidence | [coverage-and-mutation](skills/coverage-and-mutation/SKILL.md) |
| Freeze, independently review and publish a candidate | [completion-review](skills/agentic-delivery/references/completion-review.md) |
| Select stack-specific commands | [environment modules](skills/agentic-delivery/references/environments/index.md) |
| Pace a requested session | [break-reminders](skills/break-reminders/SKILL.md) |
| Propose or save a lesson with authority | [reflect](skills/reflect/SKILL.md) |

Rules state boundaries and route to these owners; they do not repeat the full
procedures. A named skill is a package name, not a guarantee that every client
has an identically named slash command. Use the host's available invocation
mechanism. If a required package is missing, report it and use an authorized
installation path rather than pretending the workflow loaded.

## Install a skill

After cloning, install individual skills only when needed independently of a set:

```bash
scripts/install-skill.sh --list              # what's available, what's installed
scripts/install-skill.sh --agent codex reflect
scripts/install-skill.sh --agent codex --project ../some-tool refresh-tool-surface
```

Windows without Git Bash — same arguments, PowerShell spelling:

```powershell
scripts\install-skill.ps1 -List
scripts\install-skill.ps1 -Agent codex reflect
scripts\install-skill.ps1 -Agent 'cursor,cline' -Project ..\some-tool reflect
```

| Agent | Skill lands at | Scope |
|-------|----------------|-------|
| `claude` | `~/.agents/skills/<skill>/`, plus `~/.claude/skills/<skill>/` | user |
| `codex`, `opencode`, `copilot` | `~/.agents/skills/<skill>/` | user |
| `cursor` | `.cursor/skills/<skill>/` | project |
| `cline` | `.clinerules/skills/<skill>/` | project |

With no `--agent`, it selects agents detected from their config directories;
`--agent all` selects every supported adapter even if undetected. For this
skill-only installer, `--project` / `-Project` moves user-scoped skills into that
project too. This differs from a standalone/base rules installation.

Existing links are repointed. Real files/directories are preserved unless
`--force` / `-Force` is passed, which authorizes their replacement; inspect them
first. Dry-run before migration or force operations.

**Complete skill packages are linked.** Portable personal packages are canonical under
`~/.agents/skills`; Claude receives the one compatibility link it needs under
`~/.claude/skills`. Editing `skills/<name>/SKILL.md` in the checkout takes
effect everywhere at once, including changes to references and scripts. Git Bash
requires Windows Developer Mode or elevation to create native symlinks. The
PowerShell installer can fall back to directory junctions without either.

Cursor uses its native skill directory. Cline supports `.clinerules/skills`;
discovered skills are enabled by default and managed in its Skills tab.
Reinstallation retires old flat skill-rule links only when they point to the matching `SKILL.md` in this
checkout. It reports and preserves other links and user-authored rules; inspect
those manually if they duplicate the newly installed skill.

See the official [Cursor skill locations](https://cursor.com/docs/skills) and
[Cline skill locations and management](https://docs.cline.bot/customization/skills).

Ask for a paced session when you want break reminders. Scheduling depends on
available host tools; installing the skill does not create jobs.

## Adopt the rules

Run the base installer from anywhere. User-scoped agents install into their
profiles; Cursor and Cline install adapters into the selected project:

```bash
scripts/install-rules.sh --list
scripts/install-rules.sh --agent claude,cursor --project ../some-tool --dry-run
scripts/install-rules.sh --agent claude,cursor --project ../some-tool
```

| Agent | Gets | Where |
|-------|------|-------|
| `claude` | an `@` import of this repo's `CLAUDE.md` | `~/.claude/CLAUDE.md` (user) |
| `codex` | symlinks to `AGENTS.md` and `rule-sets/ai-rules.md` | `~/.codex/AGENTS.md` and `~/.codex/rule-sets/ai-rules.md` |
| `opencode` | symlinks to `AGENTS.md` and `rule-sets/ai-rules.md` | `~/.config/opencode/AGENTS.md` and `~/.config/opencode/rule-sets/ai-rules.md` |
| `copilot` | symlinks to `AGENTS.md` and `rule-sets/ai-rules.md` | `~/.copilot/copilot-instructions.md` and `~/.copilot/rule-sets/ai-rules.md` |
| `cursor` | symlinks to `AGENTS.md` and `rule-sets/ai-rules.md` | `.cursor/rules/ai-rules.mdc` and `.cursor/rules/rule-sets/ai-rules.md` |
| `cline` | symlinks to `AGENTS.md` and `rule-sets/ai-rules.md` | `.clinerules/ai-rules.md` and `.clinerules/rule-sets/ai-rules.md` |

Claude Code resolves `@` imports at read time, so it imports
`rule-sets/ai-rules.md`. Codex and OpenCode read a small `AGENTS.md` entrypoint;
Copilot receives that entrypoint through its native personal-instructions
filename. All three point at the same generated rule set. An edit to a rule
reaches installed profiles and project-only adapters once
`scripts/build-agents.sh` has run. Content edits do not require reinstallation;
changed adapter locations or newly bundled skills may require rerunning the
installer. Restart or refresh the client when discovery requires it. The hook
below catches stale generated policy.

The base installation also links its declared workflows to each selected agent's
skill destination above, with Claude compatibility links under `~/.claude/skills`.
This keeps the always-loaded rule set concise without making its adoption,
agentic delivery, TDD, coverage, security, break, or reflection procedures
undiscoverable.

For Claude the installer appends one line to `~/.claude/CLAUDE.md`, keeping
whatever is already there, and won't add it twice.

### Don't let AGENTS.md go stale

```bash
git config core.hooksPath scripts/hooks
```

Refuses a commit where `AGENTS.md` or `rule-sets/ai-rules.md` doesn't match
`rules/`, or a repo convention is broken. CI enforces the same thing, but by
then you've pushed.

## Editing the rules

`rules/*.md` holds the fragments; `rule-sets/*.set` says which set ships which
of them, in what order. After changing either, regenerate:

```bash
scripts/build-agents.sh           # rewrite AGENTS.md and every rule set
scripts/build-agents.sh --check   # fail if any generated file is stale
```

Never edit `AGENTS.md` or `rule-sets/*.md` by hand — they are overwritten. CI
rejects stale generated files, and the build refuses a rule fragment no manifest
lists, since that rule would otherwise ship to nobody.

## Writing a skill

```bash
scripts/new-skill.sh --description "Use when ..." my-skill
```

Writes `skills/my-skill/SKILL.md` with the YAML frontmatter that makes a skill
discoverable. Don't hand-create the directory — an agent finds a skill by its
frontmatter `name` and `description`, so a `SKILL.md` without them installs
cleanly, reads fine, and never loads.

**Working on this repo?** Read `skills/ai-rules/SKILL.md` directly from the
checkout. Optional installation makes it discoverable in your agent:

```bash
scripts/install-skill.sh ai-rules
```

## Checks

```bash
scripts/build-agents.sh --check    # every rule set matches its manifest
scripts/test-build-agents.sh       # the generator's behaviour
scripts/test-install-skill.sh      # the skill installer's behaviour
scripts/test-install-rules.sh      # the rules installer's behaviour
scripts/test-install-contracts.sh  # cross-installer destinations and packages
scripts/test-new-skill.sh          # the skill scaffold's behaviour
scripts/test-new-rule-set.sh       # the rule and rule-set scaffolds
scripts/test-check-conventions.sh  # the conventions check's own behaviour
scripts/check-conventions.sh       # skills load, installers agree, rules registered
```

```powershell
scripts\test-install-skill.ps1
```

All of these run in CI. Tests isolate home/profile and project destinations, so
they do not touch real agent config. Retain output and final exit status on slow
runs; Windows process-heavy suites can take several minutes.

These checks establish generation, installation and convention behavior, not
semantic policy correctness or live client discovery. Review realistic scenarios
for changed guidance, and use an independent completion review when required.

## Structure

```
AGENTS.md                        ← GENERATED: minimal entrypoint
CLAUDE.md                        ← Claude Code entry point (@ imports the base set)
rule-sets/
  ai-rules.set                  ← authored manifest: the base set
  ai-rules.md                   ← GENERATED from it
  tool-repos.set                ← authored manifest: layers on ai-rules
  tool-repos.md                 ← GENERATED from it
rules/
  authority.md  breaks.md  tdd.md  coverage.md  guardrails.md
  security.md  git.md  issues.md  reflection.md ← fragments of the base set
  tool-repos/*.md                      ← fragments of the tool-repos set
skills/
  ai-rules/SKILL.md             ← how to work on this repo itself
  adopt-ai-rules/SKILL.md       ← safe adoption and duplicate reconciliation
  agentic-delivery/SKILL.md     ← scope-to-publication delivery workflow
  break-reminders/SKILL.md      ← host-aware requested session pacing
  behavior-first-tdd/SKILL.md   ← behaviour-first TDD
  coverage-and-mutation/SKILL.md ← interpretation and pruning evidence
  security-by-design/SKILL.md   ← sensitive boundaries and secure design
  reflect/SKILL.md              ← capture lessons when work lands
  refresh-tool-surface/SKILL.md ← shipped with the tool-repos set
scripts/
  build-agents.sh               ← regenerates AGENTS.md and every rule set
  new-rule-set.sh               ← scaffolds a rule set and its first rule
  new-rule.sh                   ← scaffolds a rule and registers it
  new-skill.sh                  ← scaffolds skills/<name>/SKILL.md
  rule-sets.sh                  ← manifest layout + field reading (sourced)
  readme.sh                     ← README table editing (sourced)
  agents.sh                     ← shared agent table + linking (sourced)
  install-skill.sh              ← installs a skill into any agent
  install-skill.ps1             ← the same, for Windows PowerShell
  install-rules.sh              ← points an agent at a rule set
  hooks/pre-commit              ← refuses stale generated rule files
  check-conventions.sh          ← skills load; installers agree; sets registered
  test-*.sh / test-*.ps1        ← behaviour tests for the above
.gitattributes / .editorconfig   ← keep scripts, Markdown and manifests on intentional line endings
```
