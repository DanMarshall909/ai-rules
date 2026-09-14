#!/usr/bin/env bash
# install-rules.sh
# Points an agent at this repo's rules, so editing the rule set here reaches it.
#
#   scripts/install-rules.sh --list          what would be installed, and where
#   scripts/install-rules.sh                 every agent detected here
#   scripts/install-rules.sh --agent codex   one named agent
#   scripts/install-rules.sh --agent all
#   scripts/install-rules.sh --rule-set tool-repos --project ../some-tool
#
# Two mechanisms, because agents read rules two ways:
#
#   Claude Code resolves `@` imports at read time, so it gets a one-line import
#   written into a CLAUDE.md. Nothing is copied and nothing can go stale.
#
#   AGENTS-compatible agents get a minimal symlinked entrypoint at the native
#   filename they discover, plus the rule-set file it points at.
#   `build-agents.sh` still has to run after a rule changes. The pre-commit hook
#   in scripts/hooks catches that.
#
# And two kinds of rule set, which install to different places:
#
#   The **base** set is the policy for every project you work on. Agents with
#   user-level instructions get it in their profile; project-only adapters get
#   it in the selected project.
#
#   A **layered** set is rules for one kind of repo, so it goes into that repo:
#   a link to the set, a pointer added to files the project already owns, and
#   the skills the set ships installed project-scoped beside them. Nothing the
#   project wrote is replaced.
#
# Run from the project you want the rules in, or name it with --project.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/agents.sh"
source "$(dirname "${BASH_SOURCE[0]}")/rule-sets.sh"

REPO="$(repo_root "${BASH_SOURCE[0]}")"
AGENTS_MD="${REPO}/AGENTS.md"
RULE_SET="${REPO}/rule-sets/${BASE_SET}.md"

# Manifests are read out of the checkout, not out of whatever directory this
# was run from.
RULE_SET_DIR="${REPO}/rule-sets"

# The import Claude Code is given. A native path, because Git Bash resolves the
# repo to /d/code/... and Claude Code on Windows cannot open that.
CLAUDE_IMPORT="@$(native_path "${REPO}")/CLAUDE.md"
CLAUDE_CONFIG="${HOME}/.claude/CLAUDE.md"

# Where AGENTS.md has to appear for each agent to read it. Claude is absent by
# design: it takes the import instead, handled separately below.
rules_target() { # <agent>
  case "$1" in
    claude)            printf '%s' "${CLAUDE_CONFIG}" ;;
    codex)             printf '%s' "${HOME}/.codex/AGENTS.md" ;;
    opencode)          printf '%s' "$(config_home)/opencode/AGENTS.md" ;;
    copilot)           printf '%s' "${HOME}/.copilot/copilot-instructions.md" ;;
    cursor)            printf '%s' "${PROJECT}/.cursor/rules/${SET_NAME}.mdc" ;;
    cline)             printf '%s' "${PROJECT}/.clinerules/${SET_NAME}.md" ;;
  esac
}

rule_set_target() { # <agent>
  case "$1" in
    claude) printf '%s' "" ;;
    *)      printf '%s/rule-sets/%s.md' "$(dirname "$(rules_target "$1")")" "${SET_NAME}" ;;
  esac
}

# Where a *layered* set's markdown goes in the project that wants it. Claude is
# absent again: it is given an import of the set instead of a link to it.
set_target() { # <agent>
  case "$1" in
    claude)         printf '%s' "" ;;
    codex|opencode|copilot) printf '%s/rule-sets/%s.md' "${PROJECT}" "${SET_NAME}" ;;
    cursor)         printf '%s/.cursor/rules/%s.mdc' "${PROJECT}" "${SET_NAME}" ;;
    cline)          printf '%s/.clinerules/%s.md' "${PROJECT}" "${SET_NAME}" ;;
  esac
}

usage() {
  cat <<EOF
usage: install-rules.sh [options]

  --agent <a>[,<a>...]  install for these agents, or 'all'
                        (default: every agent detected on this machine)
  --rule-set <name>     which set to install (default: ${BASE_SET})
  --project <dir>       the repo to install a layered set into
                        (default: the current directory)
  --list                show what each agent would get, and what it has
  --force               replace a target that is a real file, not a symlink
  --dry-run             print what would happen, change nothing
  -h, --help            this message

  agents: ${KNOWN_AGENTS}
  sets:   $(set_names | tr '\n' ' ')

Project-scoped agents install into: ${PROJECT}
EOF
}

AGENT_ARG=""
FORCE=0
DRY_RUN=0
LIST=0
SET_NAME="${BASE_SET}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)      AGENT_ARG="${2:-}"; shift 2 || { err "--agent needs a value"; exit 2; } ;;
    --agent=*)    AGENT_ARG="${1#*=}"; shift ;;
    --rule-set)   SET_NAME="${2:-}"; shift 2 || { err "--rule-set needs a value"; exit 2; } ;;
    --rule-set=*) SET_NAME="${1#*=}"; shift ;;
    --project)    PROJECT="${2:-}"; shift 2 || { err "--project needs a value"; exit 2; } ;;
    --project=*)  PROJECT="${1#*=}"; shift ;;
    --list)       LIST=1; shift ;;
    --force)      FORCE=1; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

if ! known_set "${SET_NAME}"; then
  err "no such rule set: ${SET_NAME}"
  err "known sets: $(set_names | tr '\n' ' ')"
  exit 2
fi

if [[ ! -d "${PROJECT}" ]]; then
  err "no such project directory: ${PROJECT}"
  exit 2
fi

MANIFEST="$(manifest_of "${SET_NAME}")"
SET_FILE="$(generated_of "${SET_NAME}")"
LAYER="$(field_one "${MANIFEST}" layer)"
RULE_SET="${SET_FILE}"
ENTRYPOINT="${AGENTS_MD}"
if [[ "${SET_NAME}" != "${BASE_SET}" ]]; then
  # A standalone set is its own policy. The default AGENTS.md entrypoint
  # deliberately points at ai-rules and cannot represent another base set.
  ENTRYPOINT="${SET_FILE}"
  CLAUDE_IMPORT="@$(native_path "${REPO}")/rule-sets/${SET_NAME}.md"
fi
[[ -z "${LAYER}" ]] || CLAUDE_CONFIG="${PROJECT}/CLAUDE.md"

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
  [[ -f "${CLAUDE_CONFIG}" ]] && grep -qxF "${CLAUDE_IMPORT}" "${CLAUDE_CONFIG}"
}

if [[ ${LIST} -eq 1 ]]; then
  echo "rules from ${REPO}"
  echo ""
  echo "  sets:"
  for s in $(set_names); do
    layer="$(field_one "$(manifest_of "${s}")" layer)"
    if [[ -n "${layer}" ]]; then
      printf '    %-12s layers on %s — installs into a project\n' "${s}" "${layer}"
    else
      printf '    %-12s the base set — installs into your profile\n' "${s}"
    fi
  done
  echo ""
  for a in ${KNOWN_AGENTS}; do
    root="$(agent_root "${a}")"
    if [[ -d "${root}" ]]; then state="detected"; else state="not found"; fi
    if [[ -n "${LAYER}" && "${a}" != "claude" ]]; then
      t="$(set_target "${a}")"
    else
      t="$(rules_target "${a}")"
    fi
    printf '  %-9s %-10s %s\n' "${a}" "${state}" "${t}"

    if [[ "${a}" == "claude" ]]; then
      claude_imported && printf '              installed: %s (@import)\n' "${SET_NAME}"
    elif [[ -n "${LAYER}" ]]; then
      [[ -L "${t}" && "$(readlink "${t}")" == "${SET_FILE}" ]] &&
        printf '              installed: %s\n' "${SET_NAME}"
    else
      r="$(rule_set_target "${a}")"
      [[ -L "${t}" && "$(readlink "${t}")" == "${ENTRYPOINT}" &&
         -L "${r}" && "$(readlink "${r}")" == "${RULE_SET}" ]] &&
        printf '              installed: %s\n' "${SET_NAME}"
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

if [[ ! -f "${RULE_SET}" ]]; then
  err "${RULE_SET} does not exist — run scripts/build-agents.sh first"
  exit 1
fi

if [[ ! -f "${SET_FILE}" ]]; then
  err "${SET_FILE} does not exist — run scripts/build-agents.sh first"
  exit 1
fi

# --- installing -------------------------------------------------------------

failures=0

# Claude gets a line in a file it already owns, so this appends rather than
# links: the file is the user's, and may hold their own rules.
install_claude_import() {
  append_once "${CLAUDE_CONFIG}" "${CLAUDE_IMPORT}" "claude: ${CLAUDE_CONFIG}"
}

install_base_set() {
  local agent="$1" target rule_target
  if [[ "${agent}" == "claude" ]]; then
    install_claude_import
    return
  fi
  target="$(rules_target "${agent}")"
  if link_to "${ENTRYPOINT}" "${target}" "${agent}: ${target}"; then
    rule_target="$(rule_set_target "${agent}")"
    link_to "${RULE_SET}" "${rule_target}" "${agent}: ${rule_target}"
  fi
}

# A layered set goes into a repo that already has its own AGENTS.md and
# CLAUDE.md, written by somebody else. So it is linked in beside them and
# *pointed at* from them — never over them.
install_layered_set() {
  local agent="$1" target import pointer
  case "${agent}" in
    claude)
      import="@$(native_path "${REPO}")/rule-sets/${SET_NAME}.md"
      append_once "${PROJECT}/CLAUDE.md" "${import}" \
        "claude: ${PROJECT}/CLAUDE.md"
      ;;
    codex|opencode)
      target="$(set_target "${agent}")"
      if link_to "${SET_FILE}" "${target}" "${agent}: ${target}"; then
        # AGENTS.md has no import syntax, so the pointer is a sentence an agent
        # reading the file will follow.
        pointer="Read and follow the rules in [rule-sets/${SET_NAME}.md](rule-sets/${SET_NAME}.md)."
        append_once "${PROJECT}/AGENTS.md" "${pointer}" \
          "${agent}: ${PROJECT}/AGENTS.md"
      fi
      ;;
    copilot)
      target="$(set_target "${agent}")"
      if link_to "${SET_FILE}" "${target}" "${agent}: ${target}"; then
        pointer="Read and follow the rules in [rule-sets/${SET_NAME}.md](rule-sets/${SET_NAME}.md)."
        append_once "${PROJECT}/AGENTS.md" "${pointer}" \
          "${agent}: ${PROJECT}/AGENTS.md"
        pointer="Read and follow the project instructions in [../AGENTS.md](../AGENTS.md)."
        append_once "${PROJECT}/.github/copilot-instructions.md" "${pointer}" \
          "${agent}: ${PROJECT}/.github/copilot-instructions.md"
      fi
      ;;
    *)
      target="$(set_target "${agent}")"
      link_to "${SET_FILE}" "${target}" "${agent}: ${target}"
      ;;
  esac
}

# The skills a set claims are part of it: rules that name a skill the project
# does not have are rules an agent cannot follow. install-skill.sh does the
# linking, so there is one implementation of what a skill install *is*.
install_set_skills() {
  local skills=() args=() joined skill
  while IFS= read -r skill; do
    [[ -n "${skill}" ]] && skills+=("${skill}")
  done < <(field "${MANIFEST}" skill)
  [[ ${#skills[@]} -gt 0 ]] || return 0

  joined="$(printf '%s,' "${TARGET_AGENTS[@]}")"
  args=(--agent "${joined%,}")
  [[ -n "${LAYER}" ]] && args=(--project "${PROJECT}" "${args[@]}")
  [[ ${DRY_RUN} -eq 1 ]] && args+=(--dry-run)
  [[ ${FORCE} -eq 1 ]] && args+=(--force)

  echo ""
  echo "skills shipped with ${SET_NAME}"
  # PROJECT selects destinations for project-only agents without turning the
  # base set's user-scoped agents into project-scoped installations.
  PROJECT="${PROJECT}" "${REPO}/scripts/install-skill.sh" "${args[@]}" "${skills[@]}" ||
    failures=$((failures + 1))
}

echo "rules from ${REPO}"
if [[ -n "${LAYER}" ]]; then
  echo "  set: ${SET_NAME} (layers on ${LAYER}) -> ${PROJECT}"
fi
for agent in "${TARGET_AGENTS[@]}"; do
  if [[ -n "${LAYER}" ]]; then
    install_layered_set "${agent}"
  else
    install_base_set "${agent}"
  fi
done

install_set_skills

echo ""
if [[ ${failures} -gt 0 ]]; then
  err "${failures} target(s) failed"
  exit 1
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
  echo "dry run — nothing changed."
else
  echo "Done. Rule sets and the default AGENTS.md entrypoint are generated — run"
  echo "scripts/build-agents.sh after changing a rule, or install the hook:"
  echo "git config core.hooksPath scripts/hooks"
fi
