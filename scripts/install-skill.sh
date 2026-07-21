#!/usr/bin/env bash
# install-skill.sh
# Installs a skill from skills/ into whichever coding agents you use.
#
#   scripts/install-skill.sh --list                    what is available, what is installed
#   scripts/install-skill.sh reflect                   every agent detected on this machine
#   scripts/install-skill.sh --agent codex reflect     one named agent
#   scripts/install-skill.sh --agent all reflect       every agent this script knows
#
# Skills are symlinked, never copied: editing skills/<name>/SKILL.md in this
# checkout must take effect everywhere at once. A skill that only exists as a
# stale copy under ~/.claude is not a shared skill, it is a fork.
#
# Windows: use install-skill.ps1 instead unless Developer Mode is on — Git Bash
# silently deep-copies in place of `ln -s` when it cannot make a real link, which
# is the one outcome this script must never produce quietly. See link_to().

set -uo pipefail

# The agent table, link_to() and the repo/path helpers are shared with
# install-rules.sh so the two cannot disagree about where an agent keeps things.
source "$(dirname "${BASH_SOURCE[0]}")/agents.sh"

REPO="$(repo_root "${BASH_SOURCE[0]}")"
SKILLS_DIR="${REPO}/skills"

# Where a skill has to appear for each agent to see it. Claude Code reads a
# skill directory; the rest read a single markdown file, so they link SKILL.md
# directly. Roots and scopes live in agents.sh.
agent_target() { # <agent> <skill>
  case "$1" in
    claude)   printf '%s' "${HOME}/.claude/skills/$2" ;;
    codex)    printf '%s' "${HOME}/.codex/prompts/$2.md" ;;
    opencode) printf '%s' "$(config_home)/opencode/command/$2.md" ;;
    cursor)   printf '%s' "${PWD}/.cursor/rules/$2.mdc" ;;
    cline)    printf '%s' "${PWD}/.clinerules/$2.md" ;;
  esac
}

agent_source() { # <agent> <skill>
  case "$1" in
    claude) printf '%s' "${SKILLS_DIR}/$2" ;;
    *)      printf '%s' "${SKILLS_DIR}/$2/SKILL.md" ;;
  esac
}

available_skills() {
  local d
  for d in "${SKILLS_DIR}"/*/; do
    [[ -f "${d}SKILL.md" ]] && basename "${d}"
  done
}

usage() {
  cat <<EOF
usage: install-skill.sh [options] <skill>...

  --agent <a>[,<a>...]  install for these agents, or 'all'
                        (default: every agent detected on this machine)
  --list                show available skills and detected agents
  --force               replace a target that is a real file, not a symlink
  --dry-run             print what would happen, change nothing
  -h, --help            this message

  agents: ${KNOWN_AGENTS}
  skills: $(available_skills | tr '\n' ' ')
EOF
}

# --- argument parsing -------------------------------------------------------

AGENT_ARG=""
FORCE=0
DRY_RUN=0
LIST=0
SKILLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)   AGENT_ARG="${2:-}"; shift 2 || { err "--agent needs a value"; exit 2; } ;;
    --agent=*) AGENT_ARG="${1#*=}"; shift ;;
    --list)    LIST=1; shift ;;
    --force)   FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)        err "unknown option: $1"; usage >&2; exit 2 ;;
    *)         SKILLS+=("$1"); shift ;;
  esac
done

# --- resolve which agents to install for ------------------------------------

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

if [[ ${LIST} -eq 1 ]]; then
  echo "skills in ${SKILLS_DIR}:"
  while IFS= read -r s; do
    printf '  %s\n' "${s}"
  done < <(available_skills)
  echo ""
  echo "agents:"
  for a in ${KNOWN_AGENTS}; do
    root="$(agent_root "${a}")"
    if [[ -d "${root}" ]]; then state="detected"; else state="not found"; fi
    printf '  %-9s %-10s %s (%s)\n' "${a}" "${state}" "${root}" "$(agent_scope "${a}")"
    while IFS= read -r s; do
      t="$(agent_target "${a}" "${s}")"
      if [[ -L "${t}" && "$(readlink "${t}")" == "$(agent_source "${a}" "${s}")" ]]; then
        printf '              installed: %s\n' "${s}"
      fi
    done < <(available_skills)
  done
  exit 0
fi

# --- validate ---------------------------------------------------------------

if [[ ${#SKILLS[@]} -eq 0 ]]; then
  err "no skill named"
  usage >&2
  exit 2
fi

for skill in "${SKILLS[@]}"; do
  # Reject anything that could escape skills/ before it reaches the filesystem.
  if [[ ! "${skill}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    err "not a valid skill name: ${skill}"
    exit 2
  fi
  if [[ ! -f "${SKILLS_DIR}/${skill}/SKILL.md" ]]; then
    err "no such skill: ${skill}"
    err "available: $(available_skills | tr '\n' ' ')"
    exit 2
  fi
done

if [[ ${#TARGET_AGENTS[@]} -eq 0 ]]; then
  err "no supported agent found on this machine"
  err "looked for: ${KNOWN_AGENTS}"
  err "name one explicitly with --agent <name>, or --agent all"
  exit 1
fi

# --- linking ----------------------------------------------------------------

# link_to() comes from agents.sh and reads FORCE, DRY_RUN and failures.
failures=0

for skill in "${SKILLS[@]}"; do
  echo "${skill}"
  for agent in "${TARGET_AGENTS[@]}"; do
    link_to "$(agent_source "${agent}" "${skill}")" \
            "$(agent_target "${agent}" "${skill}")" \
            "${agent}: $(agent_target "${agent}" "${skill}")"
  done
done

echo ""
if [[ ${failures} -gt 0 ]]; then
  err "${failures} target(s) failed"
  exit 1
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
  echo "dry run — nothing changed."
else
  echo "Done. Restart your agent to pick up new skills."
fi
