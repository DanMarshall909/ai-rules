# ai-rules

Lean, agent-agnostic AI coding rules. Works with Claude Code, Codex, OpenCode,
GitHub Copilot, Cursor, and Cline.

The concise, always-loaded shared policy lives in:

rule-sets/ai-rules.md

`AGENTS.md` is intentionally minimal. It points agents at the rule set instead
of carrying the full policy itself.

The cross-agent distribution strategy, native discovery paths, and migration
work are documented in
[`docs/cross-agent-rules-and-skills.md`](docs/cross-agent-rules-and-skills.md).

## Rule sets

A rule set is a manifest (`rule-sets/<name>.set`) naming the rule fragments it
ships, and the markdown file generated from it. `ai-rules` is the base set every
project gets; a set that *layers* on it is an addition for one kind of repo,
read alongside the base rather than instead of it.

| Set | For | Layers on |
|-----|-----|-----------|
| `rule-sets/ai-rules.md` | every project | — |
| `rule-sets/tool-repos.md` | repos whose product is a tool an agent drives | `ai-rules` |

Making one:

```bash
scripts/new-rule-set.sh --title "Tool Repo Rules" \
  --blurb "For repos whose product is a tool an agent drives." \
  --layer ai-rules tool-repos       # manifest, first rule, README row, rebuild

scripts/new-rule.sh --set tool-repos --title "Agent Contract" agent-contract
scripts/new-rule.sh --title "Caching" caching     # into the base set

scripts/new-skill.sh --set tool-repos --description "Use when ..." my-skill
```

A skill a set claims travels with it. Base-set skills install into the profile;
layered-set skills install project-scoped, so repo-specific guidance does not
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
| `rules/breaks.md` | 30-min + 2-hour break reminders with cross-project check-in |
| `rules/tdd.md` | Red → Green → Refactor → Coverage, one AC at a time |
| `rules/coverage.md` | Code must justify itself; never call a branch unreachable |
| `rules/guardrails.md` | Turn a repeatable mistake into a test that fails at build time |
| `rules/security.md` | Concentrate security decisions behind one narrow, intent-named boundary |
| `rules/git.md` | pull --rebase, backup before force-push, staged diff review |
| `rules/issues.md` | GitHub and/or canonical `docs/issues/[open\|resolved]/[area]/` tracking |
| `rules/reflection.md` | Capture durable lessons when work lands; route them to the right scope |

## Install a skill

Clone the repo once, then install any skill into whichever agents you use:

```bash
git clone https://github.com/DanMarshall909/ai-rules ~/code/ai-rules
cd ~/code/ai-rules

scripts/install-skill.sh --list              # what's available, what's installed
scripts/install-skill.sh break-reminders     # every agent found on this machine
scripts/install-skill.sh --agent codex reflect
scripts/install-skill.sh --agent all reflect
```

Windows without Git Bash — same arguments, PowerShell spelling:

```powershell
scripts\install-skill.ps1 -List
scripts\install-skill.ps1 break-reminders
scripts\install-skill.ps1 -Agent codex reflect
```

| Agent | Skill lands at | Scope |
|-------|----------------|-------|
| `claude` | `~/.agents/skills/<skill>/`, plus `~/.claude/skills/<skill>/` | user |
| `codex`, `opencode`, `copilot` | `~/.agents/skills/<skill>/` | user |
| `cursor` | `.cursor/rules/<skill>.mdc` | project |
| `cline` | `.clinerules/<skill>.md` | project |

With no `--agent`, it installs for every agent it finds a config directory for
and skips the rest. `--force` is needed only to replace a file you wrote
yourself; an existing symlink is repointed without asking.

**Skills are symlinked, not copied.** Portable packages are canonical under
`~/.agents/skills`; Claude receives the one compatibility link it needs under
`~/.claude/skills`. Editing `skills/<name>/SKILL.md` in the checkout takes
effect everywhere at once. The installer refuses to leave a copy behind even
when the shell hands it one, so on Windows it needs Developer Mode or an
elevated shell; it names the setting when it can't link.

Then run `/break-reminders` at the start of any Claude Code session.

## Adopt the rules

Run the base installer from anywhere. User-scoped agents install into their
profiles; Cursor and Cline install adapters into the selected project:

```bash
~/code/ai-rules/scripts/install-rules.sh --list   # what each agent would get
~/code/ai-rules/scripts/install-rules.sh          # every agent detected here
~/code/ai-rules/scripts/install-rules.sh --agent claude,cursor
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
`scripts/build-agents.sh` has run. The links mean you never have to reinstall;
the hook below means you never forget to regenerate.

The base installation also links its detailed workflows into
`~/.agents/skills`, with Claude compatibility links under `~/.claude/skills`.
This keeps the always-loaded rule set concise without making its TDD, coverage,
security, break, or reflection procedures undiscoverable.

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

**Working on this repo?** Install the `ai-rules` skill and invoke it — it covers
what's generated vs authored, the four places a new rule has to be registered,
and the checks to run before committing:

```bash
scripts/install-skill.sh ai-rules
```

## Checks

```bash
scripts/build-agents.sh --check    # every rule set matches its manifest
scripts/test-build-agents.sh       # the generator's behaviour
scripts/test-install-skill.sh      # the skill installer's behaviour
scripts/test-install-rules.sh      # the rules installer's behaviour
scripts/test-new-skill.sh          # the skill scaffold's behaviour
scripts/test-new-rule-set.sh       # the rule and rule-set scaffolds
scripts/test-check-conventions.sh  # the conventions check's own behaviour
scripts/check-conventions.sh       # skills load, installers agree, rules registered
```
```powershell
scripts\test-install-skill.ps1
```

All of these run in CI. The tests install into a throwaway `HOME` and project
directory, so they never touch your real config.

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
  breaks.md  tdd.md  coverage.md  guardrails.md
  git.md  issues.md  reflection.md     ← fragments of the base set
  tool-repos/*.md                      ← fragments of the tool-repos set
skills/
  ai-rules/SKILL.md             ← how to work on this repo itself
  break-reminders/SKILL.md      ← auto-schedules break reminders
  behavior-first-tdd/SKILL.md   ← behaviour-first TDD
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
.gitattributes                   ← forces LF on *.sh; CRLF breaks them silently
```

## Use as your global rules (Claude Code)

Check the repo out once, then let every project inherit both the rules and the
skills:

```bash
git clone https://github.com/DanMarshall909/ai-rules ~/code/ai-rules
cd ~/code/ai-rules
scripts/install-rules.sh --agent claude    # @import into ~/.claude/CLAUDE.md
scripts/install-skill.sh --agent claude ai-rules reflect
```

Editing the rules then means editing this repo — a rule that only exists on one
machine is not a global rule.
