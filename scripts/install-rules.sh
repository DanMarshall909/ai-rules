#!/usr/bin/env bash
# install-rules.sh
# Points an agent at this repo's rules, so editing rules/*.md reaches it.
#
#   scripts/install-rules.sh --list          what would be installed, and where
#   scripts/install-rules.sh                 every agent detected here
#   scripts/install-rules.sh --agent codex   one named agent
#   scripts/install-rules.sh --agent all
#
# Two mechanisms, because agents read rules two ways:
#
#   Claude Code resolves `@` imports at read time, so it gets a one-line import
#   of this repo's CLAUDE.md written into ~/.claude/CLAUDE.md. Nothing is
#   copied and nothing can go stale.
#
#   Everyone else reads AGENTS.md, so they get a symlink to this repo's copy.
#   AGENTS.md is generated from rules/*.md, so the link is only half the job —
#   `build-agents.sh` still has to run after a rule changes. The pre-commit
#   hook in scripts/hooks exists to catch that.
#
# Run from the project you want the rules in; project-scoped agents install
# relative to the current directory.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/agents.sh"

REPO="$(repo_root "${BASH_SOURCE[0]}")"
AGENTS_MD="${REPO}/AGENTS.md"

# The import Claude Code is given. A native path, because Git Bash resolves the
# repo to /d/code/... and Claude Code on Windows cannot open that.
CLAUDE_IMPORT="@$(native_path "${REPO}")/CLAUDE.md"
CLAUDE_CONFIG="${HOME}/.claude/CLAUDE.md"

# Where AGENTS.md has to appear for each agent to read it. Claude is absent by
# design: it takes the import instead, handled separately below.
rules_target() { # <agent>
  case "$1" in
    claude)            printf '%s' "${CLAUDE_CONFIG}" ;;
    codex|opencode)    printf '%s' "${PWD}/AGENTS.md" ;;
    cursor)            printf '%s' "${PWD}/.cursor/rules/ai-rules.mdc" ;;
    cline)             printf '%s' "${PWD}/.clinerules/ai-rules.md" ;;
  esac
}

usage() {
  cat <<EOF
usage: install-rules.sh [options]

  --agent <a>[,<a>...]  install for these agents, or 'all'
                        (default: every agent detected on this machine)
  --list                show what each agent would get, and what it has
  --force               replace a target that is a real file, not a symlink
  --dry-run             print what would happen, change nothing
  -h, --help            this message

  agents: ${KNOWN_AGENTS}

Project-scoped agents install into the current directory: $(pwd)
EOF
}

AGENT_ARG=""
FORCE=0
DRY_RUN=0
LIST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)   AGENT_ARG="${2:-}"; shift 2 || { err "--agent needs a value"; exit 2; } ;;
    --agent=*) AGENT_ARG="${1#*=}"; shift ;;
    --list)    LIST=1; shift ;;
    --force)   FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         err "unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

# --- resolve agents ---------------------------------------------------------

TARGET_AGENTS=()
if [[ "${AGENT_ARG}" == "all" ]]; then
  for a in ${KNOWN_AGENTS}; do TARGET_AGENTS+=("${a}"); done
elif [[ -n "${AGENT_ARG}" ]]; then
  IFS=',' read -ra requested <<<"${AGENT_ARG}"
  for a in "${requested[@]}"; do
    if ! known_agent "${a}"; then
      err "unknown agent: ${a}"
      err "known agents: ${KNOWN_AGENTS}"
      exit 2
    fi
    TARGET_AGENTS+=("${a}")
  done
else
  while IFS= read -r a; do TARGET_AGENTS+=("${a}"); done < <(detected_agents)
fi

# --- --list -----------------------------------------------------------------

claude_imported() {
  [[ -f "${CLAUDE_CONFIG}" ]] && grep -qF "${CLAUDE_IMPORT}" "${CLAUDE_CONFIG}"
}

if [[ ${LIST} -eq 1 ]]; then
  echo "rules from ${REPO}"
  echo ""
  for a in ${KNOWN_AGENTS}; do
    root="$(agent_root "${a}")"
    if [[ -d "${root}" ]]; then state="detected"; else state="not found"; fi
    printf '  %-9s %-10s %s\n' "${a}" "${state}" "$(rules_target "${a}")"

    if [[ "${a}" == "claude" ]]; then
      claude_imported && printf '              installed: @import\n'
    else
      t="$(rules_target "${a}")"
      [[ -L "${t}" && "$(readlink "${t}")" == "${AGENTS_MD}" ]] &&
        printf '              installed: AGENTS.md\n'
    fi
  done
  exit 0
fi

# --- validate ---------------------------------------------------------------

if [[ ${#TARGET_AGENTS[@]} -eq 0 ]]; then
  err "no supported agent found on this machine"
  err "looked for: ${KNOWN_AGENTS}"
  err "name one explicitly with --agent <name>, or --agent all"
  exit 1
fi

if [[ ! -f "${AGENTS_MD}" ]]; then
  err "${AGENTS_MD} does not exist — run scripts/build-agents.sh first"
  exit 1
fi

# --- installing -------------------------------------------------------------

failures=0

# Claude gets a line in a file it already owns, so this appends rather than
# links: the file is the user's, and may hold their own rules.
install_claude_import() {
  if claude_imported; then
    printf '  = claude: %s (already imported)\n' "${CLAUDE_CONFIG}"
    return 0
  fi

  if [[ ${DRY_RUN} -eq 1 ]]; then
    printf '  + %s -> %s (dry run)\n' "${CLAUDE_CONFIG}" "${CLAUDE_IMPORT}"
    return 0
  fi

  mkdir -p "$(dirname "${CLAUDE_CONFIG}")"
  if [[ -s "${CLAUDE_CONFIG}" ]]; then
    # Keep whatever is there; a blank line so the import cannot join a paragraph.
    printf '\n%s\n' "${CLAUDE_IMPORT}" >> "${CLAUDE_CONFIG}"
  else
    printf '%s\n' "${CLAUDE_IMPORT}" > "${CLAUDE_CONFIG}"
  fi
  printf '  + claude: %s\n' "${CLAUDE_CONFIG}"
}

echo "rules from ${REPO}"
for agent in "${TARGET_AGENTS[@]}"; do
  if [[ "${agent}" == "claude" ]]; then
    install_claude_import
  else
    target="$(rules_target "${agent}")"
    link_to "${AGENTS_MD}" "${target}" "${agent}: ${target}"
  fi
done

echo ""
if [[ ${failures} -gt 0 ]]; then
  err "${failures} target(s) failed"
  exit 1
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
  echo "dry run — nothing changed."
else
  echo "Done. AGENTS.md is generated — run scripts/build-agents.sh after"
  echo "changing a rule, or install the hook: git config core.hooksPath scripts/hooks"
fi
