#!/usr/bin/env bash
# test-install-rules.sh
# Behaviour tests for install-rules.sh.
#
#   scripts/test-install-rules.sh
#
# Rules reach agents by two different mechanisms and the tests are split the
# same way: AGENTS.md is linked into a project, while Claude Code is given an
# `@` import line in a file it already owns. The second is the awkward one —
# it edits a file the user wrote, so most of these tests are about not
# damaging it.

set -uo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"
INSTALL="${REPO}/scripts/install-rules.sh"

pass=0
fail=0
SANDBOXES=()

ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
no() {
  fail=$((fail + 1))
  printf '  FAIL %s\n' "$1"
  if [[ $# -gt 1 ]]; then printf '       %s\n' "$2"; fi
}

cleanup() {
  cd "${REPO}"
  for s in "${SANDBOXES[@]:-}"; do
    [[ -n "${s}" ]] && rm -rf "${s}" 2>/dev/null
  done
}
trap cleanup EXIT

sandbox() {
  local s
  s="$(mktemp -d)"
  SANDBOXES+=("${s}")
  export HOME="${s}/home"
  export XDG_CONFIG_HOME="${s}/home/.config"
  mkdir -p "${HOME}" "${s}/project"
  cd "${s}/project"
  SANDBOX="${s}"
}

links_to() {
  local label="$1" path="$2" want="$3"
  if [[ ! -L "${path}" ]]; then
    if [[ -e "${path}" ]]; then no "${label}" "exists but is not a symlink: ${path}"
    else no "${label}" "missing: ${path}"; fi
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
  if [[ -e "${path}" || -L "${path}" ]]; then no "${label}" "should not exist: ${path}"
  else ok "${label}"; fi
}

exits_nonzero() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then no "${label}" "expected non-zero exit, got 0"
  else ok "${label}"; fi
}

# The line install-rules writes into a Claude config, in whatever path form
# this platform needs.
import_line() {
  if command -v cygpath >/dev/null 2>&1; then
    printf '@%s/CLAUDE.md' "$(cygpath -m "${REPO}")"
  else
    printf '@%s/CLAUDE.md' "${REPO}"
  fi
}

echo "install-rules.sh"

# --- AGENTS.md into a project ----------------------------------------------

echo "AGENTS.md"
sandbox
"${INSTALL}" --agent codex >/dev/null 2>&1
links_to "codex links AGENTS.md into the project" \
  "${PWD}/AGENTS.md" "${REPO}/AGENTS.md"

sandbox
"${INSTALL}" --agent cursor >/dev/null 2>&1
links_to "cursor links AGENTS.md as an .mdc rule" \
  "${PWD}/.cursor/rules/ai-rules.mdc" "${REPO}/AGENTS.md"

sandbox
"${INSTALL}" --agent cline >/dev/null 2>&1
links_to "cline links AGENTS.md into .clinerules" \
  "${PWD}/.clinerules/ai-rules.md" "${REPO}/AGENTS.md"

sandbox
project="${PWD}"
"${INSTALL}" --agent codex >/dev/null 2>&1
links_to "installs into the given directory" "${project}/AGENTS.md" "${REPO}/AGENTS.md"
absent "does not touch HOME for a project agent" "${HOME}/AGENTS.md"

# A link means an edit to rules/ reaches the project as soon as AGENTS.md is
# regenerated. A copy would not, which is the whole point.
sandbox
"${INSTALL}" --agent codex >/dev/null 2>&1
if [[ -L "${PWD}/AGENTS.md" ]]; then
  ok "AGENTS.md is a link, not a copy"
else
  no "AGENTS.md is a link, not a copy"
fi

# --- the Claude @ import ---------------------------------------------------

echo "claude @import"
sandbox
"${INSTALL}" --agent claude >/dev/null 2>&1
if grep -qF "$(import_line)" "${HOME}/.claude/CLAUDE.md" 2>/dev/null; then
  ok "writes the import into ~/.claude/CLAUDE.md"
else
  no "writes the import into ~/.claude/CLAUDE.md" \
     "got: $(cat "${HOME}/.claude/CLAUDE.md" 2>&1 | head -3)"
fi

sandbox
mkdir -p "${HOME}/.claude"
printf 'my own notes\nkeep these\n' > "${HOME}/.claude/CLAUDE.md"
"${INSTALL}" --agent claude >/dev/null 2>&1
if grep -q "my own notes" "${HOME}/.claude/CLAUDE.md" && \
   grep -q "keep these" "${HOME}/.claude/CLAUDE.md"; then
  ok "keeps what was already in the file"
else
  no "keeps what was already in the file" "$(cat "${HOME}/.claude/CLAUDE.md")"
fi
if grep -qF "$(import_line)" "${HOME}/.claude/CLAUDE.md"; then
  ok "appends the import to an existing file"
else
  no "appends the import to an existing file"
fi

sandbox
"${INSTALL}" --agent claude >/dev/null 2>&1
"${INSTALL}" --agent claude >/dev/null 2>&1
count="$(grep -cF "$(import_line)" "${HOME}/.claude/CLAUDE.md" 2>/dev/null)"
if [[ "${count}" == "1" ]]; then
  ok "does not add the import twice"
else
  no "does not add the import twice" "found ${count} copies"
fi

# Git Bash resolves the repo to /d/code/..., which Claude Code on Windows
# cannot open. Whatever goes into the config must be a path the agent can read.
sandbox
"${INSTALL}" --agent claude >/dev/null 2>&1
if grep -qE '^@/[a-z]/' "${HOME}/.claude/CLAUDE.md" 2>/dev/null; then
  no "writes a path the agent can open" "wrote a POSIX-style drive path"
else
  ok "writes a path the agent can open"
fi

# `cygpath -w` yields D:\code\ai-rules, which this script then appends
# /CLAUDE.md to — a path mixing both separators. It mostly works, and "mostly"
# is not a thing to leave in a config file nobody will look at again.
sandbox
"${INSTALL}" --agent claude >/dev/null 2>&1
line="$(grep '^@' "${HOME}/.claude/CLAUDE.md" 2>/dev/null)"
if [[ "${line}" == *'\'* && "${line}" == *'/'* ]]; then
  no "writes one separator style, not two" "got: ${line}"
else
  ok "writes one separator style, not two"
fi

# --- listing ---------------------------------------------------------------

echo "--list"
sandbox
out="$("${INSTALL}" --list 2>&1)"
if [[ $? -eq 0 ]]; then ok "exits 0"; else no "exits 0" "${out}"; fi
if grep -q "claude" <<<"${out}"; then ok "names the agents"; else no "names the agents"; fi

# Capture first, then match: `cmd | grep -q` closes the pipe on the first hit,
# and under `set -o pipefail` the producer's SIGPIPE fails the whole pipeline —
# so a successful match reads as a failed test.
sandbox
"${INSTALL}" --agent codex >/dev/null 2>&1
out="$("${INSTALL}" --list 2>&1)"
if grep -qi "installed" <<<"${out}"; then
  ok "reports what is already installed"
else
  no "reports what is already installed" "${out}"
fi

# --- autodetect ------------------------------------------------------------

echo "autodetect"
sandbox
mkdir -p "${HOME}/.codex"
"${INSTALL}" >/dev/null 2>&1
links_to "installs for the agent that is present" "${PWD}/AGENTS.md" "${REPO}/AGENTS.md"
absent "skips the agent that is absent" "${HOME}/.claude/CLAUDE.md"

sandbox
exits_nonzero "fails when no agent is detected" "${INSTALL}"

# --- never clobber ---------------------------------------------------------

echo "existing files"
sandbox
echo "a project's own AGENTS.md" > "${PWD}/AGENTS.md"
exits_nonzero "refuses to replace a real AGENTS.md" "${INSTALL}" --agent codex
if [[ "$(cat "${PWD}/AGENTS.md")" == "a project's own AGENTS.md" ]]; then
  ok "leaves the real file untouched"
else
  no "leaves the real file untouched" "contents changed"
fi

sandbox
echo "a project's own AGENTS.md" > "${PWD}/AGENTS.md"
"${INSTALL}" --force --agent codex >/dev/null 2>&1
links_to "--force replaces it" "${PWD}/AGENTS.md" "${REPO}/AGENTS.md"

# --- dry run ---------------------------------------------------------------

echo "--dry-run"
sandbox
mkdir -p "${HOME}/.codex" "${HOME}/.claude"
"${INSTALL}" --dry-run >/dev/null 2>&1
absent "links nothing" "${PWD}/AGENTS.md"
absent "writes no import" "${HOME}/.claude/CLAUDE.md"

# --- bad input -------------------------------------------------------------

echo "bad input"
sandbox
exits_nonzero "rejects an unknown agent" "${INSTALL}" --agent nosuchagent

echo ""
echo "${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
