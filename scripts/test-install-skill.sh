#!/usr/bin/env bash
# test-install-skill.sh
# Behaviour tests for install-skill.sh: runs the real script against a throwaway
# HOME and project directory, then asserts on what actually landed on disk.
#
#   scripts/test-install-skill.sh
#
# Every test drives the script through its command line and checks observable
# output — the links on disk and the exit status — never its internals.

set -uo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"
INSTALL="${REPO}/scripts/install-skill.sh"

pass=0
fail=0
SANDBOXES=()

ok() {
  pass=$((pass + 1))
  printf '  ok   %s\n' "$1"
}

no() {
  fail=$((fail + 1))
  printf '  FAIL %s\n' "$1"
  if [[ $# -gt 1 ]]; then printf '       %s\n' "$2"; fi
}

cleanup() {
  cd "${REPO}"
  for s in "${SANDBOXES[@]:-}"; do
    [[ -n "${s}" ]] && chmod -R u+w "${s}" 2>/dev/null
    [[ -n "${s}" ]] && rm -rf "${s}" 2>/dev/null
  done
}
trap cleanup EXIT

# Fresh isolated HOME + project cwd, so a test can never touch the real machine.
sandbox() {
  local s
  s="$(mktemp -d)"
  SANDBOXES+=("${s}")
  export HOME="${s}/home"
  export XDG_CONFIG_HOME="${s}/home/.config"
  mkdir -p "${HOME}" "${s}/project"
  cd "${s}/project"
}

# assert <label> <path> is a symlink pointing at <target>
links_to() {
  local label="$1" path="$2" want="$3"
  if [[ ! -L "${path}" ]]; then
    if [[ -e "${path}" ]]; then
      no "${label}" "exists but is not a symlink: ${path}"
    else
      no "${label}" "missing: ${path}"
    fi
    return
  fi
  local got
  got="$(readlink "${path}")"
  if [[ "${got}" != "${want}" ]]; then
    no "${label}" "points at ${got}, expected ${want}"
    return
  fi
  ok "${label}"
}

absent() {
  local label="$1" path="$2"
  if [[ -e "${path}" || -L "${path}" ]]; then
    no "${label}" "should not exist: ${path}"
  else
    ok "${label}"
  fi
}

exits_nonzero() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    no "${label}" "expected non-zero exit, got 0"
  else
    ok "${label}"
  fi
}

echo "install-skill.sh"

# --- discovery -------------------------------------------------------------

echo "--list"
sandbox
out="$("${INSTALL}" --list 2>&1)"
if [[ $? -eq 0 ]]; then ok "exits 0"; else no "exits 0" "${out}"; fi
for skill in break-reminders reflect behavior-first-tdd; do
  if grep -q "${skill}" <<<"${out}"; then
    ok "lists ${skill}"
  else
    no "lists ${skill}" "not in output"
  fi
done

# --- one agent at a time ---------------------------------------------------

echo "per-agent targets"
sandbox
"${INSTALL}" --agent claude reflect >/dev/null 2>&1
links_to "claude installs a skill directory" \
  "${HOME}/.claude/skills/reflect" "${REPO}/skills/reflect"

sandbox
"${INSTALL}" --agent codex reflect >/dev/null 2>&1
links_to "codex installs SKILL.md as a prompt" \
  "${HOME}/.codex/prompts/reflect.md" "${REPO}/skills/reflect/SKILL.md"

sandbox
"${INSTALL}" --agent opencode reflect >/dev/null 2>&1
links_to "opencode installs SKILL.md as a command" \
  "${XDG_CONFIG_HOME}/opencode/command/reflect.md" "${REPO}/skills/reflect/SKILL.md"

sandbox
"${INSTALL}" --agent cursor reflect >/dev/null 2>&1
links_to "cursor installs SKILL.md as an .mdc rule" \
  "${PWD}/.cursor/rules/reflect.mdc" "${REPO}/skills/reflect/SKILL.md"

sandbox
"${INSTALL}" --agent cline reflect >/dev/null 2>&1
links_to "cline installs SKILL.md as a .clinerules file" \
  "${PWD}/.clinerules/reflect.md" "${REPO}/skills/reflect/SKILL.md"

# --- scope -----------------------------------------------------------------

echo "scope"
sandbox
project="${PWD}"
"${INSTALL}" --agent cursor reflect >/dev/null 2>&1
links_to "project agent installs under cwd" \
  "${project}/.cursor/rules/reflect.mdc" "${REPO}/skills/reflect/SKILL.md"
absent "project agent does not touch HOME" "${HOME}/.cursor"

# --- all / autodetect ------------------------------------------------------

echo "--agent all"
sandbox
"${INSTALL}" --agent all reflect >/dev/null 2>&1
links_to "all: claude"   "${HOME}/.claude/skills/reflect"                 "${REPO}/skills/reflect"
links_to "all: codex"    "${HOME}/.codex/prompts/reflect.md"              "${REPO}/skills/reflect/SKILL.md"
links_to "all: opencode" "${XDG_CONFIG_HOME}/opencode/command/reflect.md" "${REPO}/skills/reflect/SKILL.md"
links_to "all: cursor"   "${PWD}/.cursor/rules/reflect.mdc"               "${REPO}/skills/reflect/SKILL.md"
links_to "all: cline"    "${PWD}/.clinerules/reflect.md"                  "${REPO}/skills/reflect/SKILL.md"

echo "autodetect"
sandbox
mkdir -p "${HOME}/.codex"
"${INSTALL}" reflect >/dev/null 2>&1
links_to "installs for the agent that is present" \
  "${HOME}/.codex/prompts/reflect.md" "${REPO}/skills/reflect/SKILL.md"
absent "skips the agent that is absent" "${HOME}/.claude/skills/reflect"

sandbox
exits_nonzero "fails when no agent is detected" "${INSTALL}" reflect

# --- repeat runs -----------------------------------------------------------

echo "idempotence"
sandbox
"${INSTALL}" --agent claude reflect >/dev/null 2>&1
"${INSTALL}" --agent claude reflect >/dev/null 2>&1
if [[ $? -eq 0 ]]; then ok "second run exits 0"; else no "second run exits 0"; fi
links_to "second run leaves the link intact" \
  "${HOME}/.claude/skills/reflect" "${REPO}/skills/reflect"

# --- never clobber ---------------------------------------------------------

echo "existing files"
sandbox
mkdir -p "${HOME}/.codex/prompts"
echo "hand written" > "${HOME}/.codex/prompts/reflect.md"
exits_nonzero "refuses to replace a real file" \
  "${INSTALL}" --agent codex reflect
if [[ "$(cat "${HOME}/.codex/prompts/reflect.md")" == "hand written" ]]; then
  ok "leaves the real file untouched"
else
  no "leaves the real file untouched" "contents changed"
fi

sandbox
mkdir -p "${HOME}/.codex/prompts"
echo "hand written" > "${HOME}/.codex/prompts/reflect.md"
"${INSTALL}" --force --agent codex reflect >/dev/null 2>&1
links_to "--force replaces a real file" \
  "${HOME}/.codex/prompts/reflect.md" "${REPO}/skills/reflect/SKILL.md"

sandbox
mkdir -p "${HOME}/.codex/prompts"
ln -s /nowhere/else.md "${HOME}/.codex/prompts/reflect.md" 2>/dev/null
"${INSTALL}" --agent codex reflect >/dev/null 2>&1
links_to "repoints a stale symlink without --force" \
  "${HOME}/.codex/prompts/reflect.md" "${REPO}/skills/reflect/SKILL.md"

# --- bad input -------------------------------------------------------------

echo "bad input"
sandbox
exits_nonzero "rejects an unknown skill" "${INSTALL}" --agent claude no-such-skill
absent "creates nothing for an unknown skill" "${HOME}/.claude/skills/no-such-skill"

sandbox
exits_nonzero "rejects an unknown agent" "${INSTALL}" --agent nosuchagent reflect

sandbox
exits_nonzero "rejects no skill argument" "${INSTALL}" --agent claude

# `../skills/reflect` is chosen deliberately: it resolves to a SKILL.md that
# really exists, so the "no such skill" check cannot reject it. Only the name
# guard can. A name that fails both checks would pass this test with the guard
# deleted.
sandbox
exits_nonzero "rejects a path traversal skill name" \
  "${INSTALL}" --agent claude ../skills/reflect
absent "creates nothing outside the skills root" "${HOME}/.claude/skills/../skills"

# --- a shell that cannot symlink -------------------------------------------
# Git Bash without Developer Mode answers `ln -s` with a deep copy and exits 0.
# A copy stops tracking this checkout the moment either side is edited, so the
# script has to notice and refuse. Stubbing `ln` reproduces that here regardless
# of what the host shell can actually do.
echo "shell that copies instead of linking"
sandbox
stub="${PWD}/stub-bin"
mkdir -p "${stub}"
cat > "${stub}/ln" <<'STUB'
#!/usr/bin/env bash
# stands in for a Git Bash `ln -s` that has no native symlink support
for arg in "$@"; do case "${arg}" in -*) ;; *) set -- "$@" ; esac; done
src="${@: -2:1}"; dst="${@: -1}"
cp -R "${src}" "${dst}"
STUB
chmod +x "${stub}/ln"
PATH="${stub}:${PATH}" "${INSTALL}" --agent claude reflect >/dev/null 2>&1
if [[ $? -ne 0 ]]; then ok "fails rather than leaving a copy"; else no "fails rather than leaving a copy"; fi
absent "removes the copy it was handed" "${HOME}/.claude/skills/reflect"

# --- dry run ---------------------------------------------------------------

echo "--dry-run"
sandbox
mkdir -p "${HOME}/.claude"
"${INSTALL}" --dry-run --agent claude reflect >/dev/null 2>&1
absent "creates nothing" "${HOME}/.claude/skills/reflect"

# --- several skills --------------------------------------------------------

echo "multiple skills"
sandbox
"${INSTALL}" --agent claude reflect break-reminders >/dev/null 2>&1
links_to "installs the first"  "${HOME}/.claude/skills/reflect"         "${REPO}/skills/reflect"
links_to "installs the second" "${HOME}/.claude/skills/break-reminders" "${REPO}/skills/break-reminders"

# --- report ----------------------------------------------------------------

echo ""
echo "${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
