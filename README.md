# ai-rules

Lean, agent-agnostic AI coding rules. Works with Claude Code, Cursor, Windsurf, Cline, and any assistant that reads markdown rule files.

The complete shared rule set lives in:

rule-sets/ai-rules.md

`AGENTS.md` is intentionally minimal. It points agents at the rule set instead
of carrying the full policy itself.

## Rule sets

A rule set is a manifest (`rule-sets/<name>.set`) naming the rule fragments it
ships, and the markdown file generated from it. `ai-rules` is the base set every
project gets; a set that *layers* on it is an addition for one kind of repo,
read alongside the base rather than instead of it.

| Set | For | Layers on |
|-----|-----|-----------|
| `rule-sets/ai-rules.md` | every project | — |
| `rule-sets/tool-repos.md` | For repos whose product is a tool an agent drives. | ai-rules |

```bash
scripts/new-rule-set.sh --title "Tool Repo Rules" \
  --blurb "For repos whose product is a tool an agent drives." \
  --layer ai-rules tool-repos       # manifest, first rule, README row, rebuild

scripts/new-rule.sh --set tool-repos --title "Agent Contract" agent-contract
scripts/new-rule.sh --title "Caching" caching     # into the base set
```

## Rules

| Rule | What it does |
|------|-------------|
| `rules/breaks.md` | 30-min + 2-hour break reminders with cross-project check-in |
| `rules/tdd.md` | Red → Green → Refactor → Coverage, one AC at a time |
| `rules/coverage.md` | Code must justify itself; never call a branch unreachable |
| `rules/guardrails.md` | Turn a repeatable mistake into a test that fails at build time |
| `rules/security.md` | Concentrate security decisions behind one narrow, intent-named boundary |
| `rules/git.md` | pull --rebase, backup before force-push, staged diff review |
| `rules/issues.md` | `docs/issues/[open\|resolved]/[area]/` structured tracking |
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
| `claude` | `~/.claude/skills/<skill>/` | user |
| `codex` | `~/.codex/prompts/<skill>.md` | user |
| `opencode` | `~/.config/opencode/command/<skill>.md` | user |
| `cursor` | `.cursor/rules/<skill>.mdc` | project |
| `cline` | `.clinerules/<skill>.md` | project |

With no `--agent`, it installs for every agent it finds a config directory for
and skips the rest. `--force` is needed only to replace a file you wrote
yourself; an existing symlink is repointed without asking.

**Skills are symlinked, not copied.** Editing `skills/<name>/SKILL.md` in the
checkout takes effect everywhere at once — a copy under `~/.claude` stops
tracking this repo the moment either side changes, which is the whole failure
this repo exists to avoid. The installer refuses to leave a copy behind even
when the shell hands it one, so on Windows it needs Developer Mode or an
elevated shell; it names the setting when it can't link.

Then run `/break-reminders` at the start of any Claude Code session.

## Adopt the rules

From the project you want the rules in:

```bash
~/code/ai-rules/scripts/install-rules.sh --list   # what each agent would get
~/code/ai-rules/scripts/install-rules.sh          # every agent detected here
~/code/ai-rules/scripts/install-rules.sh --agent claude,cursor
```

| Agent | Gets | Where |
|-------|------|-------|
| `claude` | an `@` import of this repo's `CLAUDE.md` | `~/.claude/CLAUDE.md` (user) |
| `codex`, `opencode` | symlinks to `AGENTS.md` and `rule-sets/ai-rules.md` | `./AGENTS.md` and `./rule-sets/ai-rules.md` |
| `cursor` | symlinks to `AGENTS.md` and `rule-sets/ai-rules.md` | `.cursor/rules/ai-rules.mdc` and `.cursor/rules/rule-sets/ai-rules.md` |
| `cline` | symlinks to `AGENTS.md` and `rule-sets/ai-rules.md` | `.clinerules/ai-rules.md` and `.clinerules/rule-sets/ai-rules.md` |

Claude Code resolves `@` imports at read time, so it imports
`rule-sets/ai-rules.md`. Everyone else reads a small `AGENTS.md` entrypoint that
points at the same generated rule set. An edit to a rule reaches installed
projects once `scripts/build-agents.sh` has run. The links mean you never have
to reinstall; the hook below means you never forget to regenerate.

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

`rules/*.md` is the source used to build the complete rule set in
`rule-sets/ai-rules.md`. After changing one, regenerate:

```bash
scripts/build-agents.sh           # rewrite AGENTS.md and rule-sets/ai-rules.md
scripts/build-agents.sh --check   # fail if either generated file is stale
```

Never edit `AGENTS.md` or `rule-sets/ai-rules.md` by hand — they are
overwritten. CI rejects stale generated files.

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
scripts/build-agents.sh --check    # generated rule entrypoints match rules/
scripts/test-install-skill.sh      # the skill installer's behaviour
scripts/test-install-rules.sh      # the rules installer's behaviour
scripts/test-new-skill.sh          # the scaffold's behaviour
scripts/check-conventions.sh       # skills load, installers agree, rules registered
```
```powershell
scripts\test-install-skill.ps1
```

All of these run in CI. The tests install into a throwaway `HOME` and project
directory, so they never touch your real config.

## Structure

```
rules/*.md                       ← authored rule fragments
rule-sets/ai-rules.md            ← GENERATED: complete shared rule set
AGENTS.md                        ← GENERATED: minimal entrypoint
CLAUDE.md                        ← Claude Code entry point (@ imports the rule set)
rules/
  breaks.md
  tdd.md
  coverage.md
  guardrails.md
  git.md
  issues.md
  reflection.md
skills/
  ai-rules/SKILL.md             ← how to work on this repo itself
  break-reminders/SKILL.md      ← auto-schedules break reminders
  behavior-first-tdd/SKILL.md   ← behaviour-first TDD
  reflect/SKILL.md              ← capture lessons when work lands
scripts/
  build-agents.sh               ← regenerates AGENTS.md and the rule set
  new-skill.sh                  ← scaffolds skills/<name>/SKILL.md
  agents.sh                     ← shared agent table + linking (sourced)
  install-skill.sh              ← installs a skill into any agent
  install-skill.ps1             ← the same, for Windows PowerShell
  install-rules.sh              ← points an agent at these rules
  hooks/pre-commit              ← refuses stale generated rule files
  check-conventions.sh          ← skills load; installers agree; rules registered
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
