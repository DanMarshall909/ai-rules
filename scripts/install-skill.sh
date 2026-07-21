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

# Ask the Git Bash runtime for real NTFS symlinks rather than its copy fallback.
# Harmless everywhere else.
export MSYS="${MSYS:-} winsymlinks:nativestrict"

# --- where this checkout lives ---------------------------------------------
# Resolved through symlinks, so the script still finds skills/ when it is itself
# invoked via a link on $PATH.
self="${BASH_SOURCE[0]}"
while [[ -L "${self}" ]]; do
  self_dir="$(cd -P "$(dirname "${self}")" && pwd)"
  self="$(readlink "${self}")"
  [[ "${self}" != /* ]] && self="${self_dir}/${self}"
done
REPO="$(cd -P "$(dirname "${self}")/.." && pwd)"
SKILLS_DIR="${REPO}/skills"

# --- agent table ------------------------------------------------------------
# One line per agent per column. These are each agent's documented convention at
# time of writing; if one moves, this table is the only thing to change.
#
#   root   — presence of this path means the agent is installed (autodetect)
#   target — where the skill has to appear for that agent to see it
#   source — what gets linked: Claude reads a skill directory, the rest read a
#            single markdown file, so they link SKILL.md directly
#
# Agents differ in scope: claude/codex/opencode are per-user, cursor/cline are
# per-project and install relative to the current directory.
KNOWN_AGENTS="claude codex opencode cursor cline"

config_home() { printf '%s' "${XDG_CONFIG_HOME:-${HOME}/.config}"; }

agent_root() {
  case "$1" in
    claude)   printf '%s' "${HOME}/.claude" ;;
    codex)    printf '%s' "${HOME}/.codex" ;;
    opencode) printf '%s' "$(config_home)/opencode" ;;
    cursor)   printf '%s' "${PWD}/.cursor" ;;
    cline)    printf '%s' "${PWD}/.clinerules" ;;
  esac
}

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

agent_scope() {
  case "$1" in
    cursor|cline) printf 'project' ;;
    *)            printf 'user' ;;
  esac
}

# --- helpers ----------------------------------------------------------------

err() { printf 'error: %s\n' "$*" >&2; }

known_agent() {
  case " ${KNOWN_AGENTS} " in *" $1 "*) return 0 ;; *) return 1 ;; esac
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

detected_agents() {
  local a
  for a in ${KNOWN_AGENTS}; do
    [[ -d "$(agent_root "${a}")" ]] && printf '%s\n' "${a}"
  done
}

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

failures=0

link_to() { # <source> <target> <label>
  local src="$1" dst="$2" label="$3"

  if [[ -L "${dst}" ]]; then
    if [[ "$(readlink "${dst}")" == "${src}" ]]; then
      printf '  = %s (already linked)\n' "${label}"
      return 0
    fi
    # A symlink is ours to repoint; only real files are somebody's work.
    [[ ${DRY_RUN} -eq 1 ]] || rm -f "${dst}"
  elif [[ -e "${dst}" ]]; then
    if [[ ${FORCE} -ne 1 ]]; then
      err "${label}: ${dst} already exists and is not a symlink"
      err "  inspect it, then pass --force to replace it"
      failures=$((failures + 1))
      return 1
    fi
    [[ ${DRY_RUN} -eq 1 ]] || rm -rf "${dst}"
  fi

  if [[ ${DRY_RUN} -eq 1 ]]; then
    printf '  + %s -> %s (dry run)\n' "${dst}" "${src}"
    return 0
  fi

  mkdir -p "$(dirname "${dst}")"
  if ! ln -s "${src}" "${dst}" 2>/dev/null; then
    err "${label}: could not create symlink ${dst}"
    err "  on Windows, run scripts/install-skill.ps1, or enable Developer Mode"
    failures=$((failures + 1))
    return 1
  fi

  # Git Bash without native symlink support answers `ln -s` with a deep copy and
  # exits 0. A copy silently stops tracking this checkout, so refuse it outright
  # rather than leave a fork behind.
  if [[ ! -L "${dst}" ]]; then
    rm -rf "${dst}"
    err "${label}: the shell copied instead of linking ${dst}"
    err "  run scripts/install-skill.ps1, or enable Windows Developer Mode"
    failures=$((failures + 1))
    return 1
  fi

  printf '  + %s\n' "${label}"
}

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
