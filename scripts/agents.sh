# agents.sh — shared by install-skill.sh and install-rules.sh.
#
# Sourced, not run. Everything an installer needs to know about where agents
# keep their files, and how to link into them safely.
#
# This is one table rather than two because the two installers were otherwise
# free to disagree about what an agent is. install-skill.ps1 keeps its own copy
# for want of a shell it can source; check-conventions.sh compares them.

# Ask the Git Bash runtime for real NTFS symlinks rather than its copy fallback.
# Harmless everywhere else.
export MSYS="${MSYS:-} winsymlinks:nativestrict"

KNOWN_AGENTS="claude codex opencode cursor cline"

config_home() { printf '%s' "${XDG_CONFIG_HOME:-${HOME}/.config}"; }

# Presence of this path means the agent is installed, and is what --agent-less
# runs autodetect against. Project-scoped agents are looked for under $PWD.
agent_root() {
  case "$1" in
    claude)   printf '%s' "${HOME}/.claude" ;;
    codex)    printf '%s' "${HOME}/.codex" ;;
    opencode) printf '%s' "$(config_home)/opencode" ;;
    cursor)   printf '%s' "${PWD}/.cursor" ;;
    cline)    printf '%s' "${PWD}/.clinerules" ;;
  esac
}

agent_scope() {
  case "$1" in
    cursor|cline) printf 'project' ;;
    *)            printf 'user' ;;
  esac
}

known_agent() {
  case " ${KNOWN_AGENTS} " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

detected_agents() {
  local a
  for a in ${KNOWN_AGENTS}; do
    [[ -d "$(agent_root "${a}")" ]] && printf '%s\n' "${a}"
  done
}

# Resolve a script's own checkout, following symlinks, so it still finds the
# repo when invoked through a link on $PATH.
repo_root() { # <path to the script, normally ${BASH_SOURCE[0]} of the caller>
  local self="$1" dir
  while [[ -L "${self}" ]]; do
    dir="$(cd -P "$(dirname "${self}")" && pwd)"
    self="$(readlink "${self}")"
    [[ "${self}" != /* ]] && self="${dir}/${self}"
  done
  (cd -P "$(dirname "${self}")/.." && pwd)
}

# The path an agent has to be given on this platform. Git Bash resolves the
# repo to /d/code/..., which Claude Code on Windows cannot open, so anything
# written *into a config file* rather than passed to ln needs converting.
native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}

err() { printf 'error: %s\n' "$*" >&2; }

# link_to <source> <target> <label>
# Callers set FORCE, DRY_RUN and failures; this increments failures on refusal.
link_to() {
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
    err "  on Windows, enable Developer Mode or run an elevated shell"
    failures=$((failures + 1))
    return 1
  fi

  # Git Bash without native symlink support answers `ln -s` with a deep copy and
  # exits 0. A copy silently stops tracking this checkout, so refuse it outright
  # rather than leave a fork behind.
  if [[ ! -L "${dst}" ]]; then
    rm -rf "${dst}"
    err "${label}: the shell copied instead of linking ${dst}"
    err "  enable Windows Developer Mode, or use the PowerShell installer"
    failures=$((failures + 1))
    return 1
  fi

  printf '  + %s\n' "${label}"
}
