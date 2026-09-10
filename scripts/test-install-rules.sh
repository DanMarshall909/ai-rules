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

fails_with() {
  local label="$1" pattern="$2"; shift 2
  local out status
  out="$("$@" 2>&1)"
  status=$?
  if [[ ${status} -eq 0 ]]; then
    no "${label}" "expected non-zero exit, got 0"
  elif ! grep -qF "${pattern}" <<<"${out}"; then
    no "${label}" "message did not mention '${pattern}': ${out}"
  else
    ok "${label}"
  fi
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

# --- base AGENTS.md into a profile -----------------------------------------

echo "AGENTS.md"
sandbox
"${INSTALL}" --agent codex >/dev/null 2>&1
links_to "codex links AGENTS.md into its profile" \
  "${HOME}/.codex/AGENTS.md" "${REPO}/AGENTS.md"
links_to "codex links the rule set beside AGENTS.md" \
  "${HOME}/.codex/rule-sets/ai-rules.md" "${REPO}/rule-sets/ai-rules.md"
absent "codex leaves the project's AGENTS.md alone" "${PWD}/AGENTS.md"

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
links_to "installs independently of the current directory" \
  "${HOME}/.codex/AGENTS.md" "${REPO}/AGENTS.md"
absent "does not treat the current directory as a profile" "${project}/AGENTS.md"

# A link means an edit to rules/ reaches the project as soon as generated rule
# files are regenerated. A copy would not, which is the whole point.
sandbox
"${INSTALL}" --agent codex >/dev/null 2>&1
if [[ -L "${HOME}/.codex/AGENTS.md" ]]; then
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

sandbox
mkdir -p "${HOME}/.claude"
printf '# disabled: %s\n' "$(import_line)" > "${HOME}/.claude/CLAUDE.md"
"${INSTALL}" --agent claude >/dev/null 2>&1
count="$(grep -cxF "$(import_line)" "${HOME}/.claude/CLAUDE.md" 2>/dev/null || true)"
if [[ "${count}" == "1" ]]; then
  ok "does not mistake a commented import for an active one"
else
  no "does not mistake a commented import for an active one" \
    "found ${count} active imports"
fi

sandbox
mkdir -p "${HOME}/.claude/CLAUDE.md"
fails_with "fails when the import cannot be written" "could not write" \
  "${INSTALL}" --agent claude

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

# --- a layered rule set into a project -------------------------------------
# A layered set is an addition for one kind of repo, so it installs into that
# repo rather than into the profile — and into a repo that already has its own
# AGENTS.md and CLAUDE.md, written by someone else, which it must not replace.

set_import_line() { # <set>
  if command -v cygpath >/dev/null 2>&1; then
    printf '@%s/rule-sets/%s.md' "$(cygpath -m "${REPO}")" "$1"
  else
    printf '@%s/rule-sets/%s.md' "${REPO}" "$1"
  fi
}

count_of() { grep -cF "$2" "$1" 2>/dev/null || printf '0'; }

echo "a layered set"
sandbox
"${INSTALL}" --rule-set tool-repos --agent claude >/dev/null 2>&1
if grep -qF "$(set_import_line tool-repos)" "${PWD}/CLAUDE.md" 2>/dev/null; then
  ok "imports the set from the project's own CLAUDE.md"
else
  no "imports the set from the project's own CLAUDE.md" \
     "got: $(cat "${PWD}/CLAUDE.md" 2>&1 | head -3)"
fi
absent "leaves the machine-wide Claude config alone" "${HOME}/.claude/CLAUDE.md"

# The base set is the one that belongs to the profile; asking for a layered set
# must not quietly install the base as well.
if grep -qF "rule-sets/ai-rules.md" "${PWD}/CLAUDE.md" 2>/dev/null; then
  no "installs only the set asked for" "the base set's import was written too"
else
  ok "installs only the set asked for"
fi

sandbox
printf '# Our project\n\nOur own guidance.\n' > "${PWD}/AGENTS.md"
printf '# Our project\n\n@AGENTS.md\n' > "${PWD}/CLAUDE.md"
"${INSTALL}" --rule-set tool-repos --agent codex >/dev/null 2>&1
links_to "links the set beside the project's AGENTS.md" \
  "${PWD}/rule-sets/tool-repos.md" "${REPO}/rule-sets/tool-repos.md"
if grep -q "Our own guidance." "${PWD}/AGENTS.md"; then
  ok "keeps the project's own AGENTS.md"
else
  no "keeps the project's own AGENTS.md" "$(cat "${PWD}/AGENTS.md")"
fi
if grep -qF "rule-sets/tool-repos.md" "${PWD}/AGENTS.md"; then
  ok "points the project's AGENTS.md at the set"
else
  no "points the project's AGENTS.md at the set" "$(cat "${PWD}/AGENTS.md")"
fi

# Installing twice is how anyone re-runs this after a rule changes. A second
# pointer line would be invisible in an editor and duplicated in the agent's
# context every session after.
sandbox
"${INSTALL}" --rule-set tool-repos --agent codex >/dev/null 2>&1
"${INSTALL}" --rule-set tool-repos --agent codex >/dev/null 2>&1
n="$(count_of "${PWD}/AGENTS.md" "rule-sets/tool-repos.md")"
if [[ "${n}" == "1" ]]; then
  ok "does not point at the set twice"
else
  no "does not point at the set twice" "found ${n} pointers"
fi

sandbox
"${INSTALL}" --rule-set tool-repos --agent cursor >/dev/null 2>&1
links_to "cursor gets the set as its own rule file" \
  "${PWD}/.cursor/rules/tool-repos.mdc" "${REPO}/rule-sets/tool-repos.md"

sandbox
"${INSTALL}" --rule-set tool-repos --agent cline >/dev/null 2>&1
links_to "cline gets the set as its own rule file" \
  "${PWD}/.clinerules/tool-repos.md" "${REPO}/rule-sets/tool-repos.md"

# The skills a set claims are part of the set: installing one without them
# leaves the rules referring to a skill the project does not have.
sandbox
"${INSTALL}" --rule-set tool-repos --agent claude >/dev/null 2>&1
links_to "installs the set's skills into the project" \
  "${PWD}/.claude/skills/refresh-tool-surface" "${REPO}/skills/refresh-tool-surface"
absent "installs no skill into the profile" "${HOME}/.claude/skills/refresh-tool-surface"

# --- --project --------------------------------------------------------------

echo "--project"
sandbox
mkdir -p "${SANDBOX}/elsewhere"
"${INSTALL}" --rule-set tool-repos --project "${SANDBOX}/elsewhere" --agent codex >/dev/null 2>&1
links_to "installs into the named directory" \
  "${SANDBOX}/elsewhere/rule-sets/tool-repos.md" "${REPO}/rule-sets/tool-repos.md"
absent "leaves the working directory alone" "${PWD}/rule-sets/tool-repos.md"

sandbox
exits_nonzero "refuses a project directory that does not exist" \
  "${INSTALL}" --rule-set tool-repos --project "${SANDBOX}/nowhere" --agent codex

# --- naming a set that does not exist ---------------------------------------

echo "bad rule set"
sandbox
out="$("${INSTALL}" --rule-set nosuchset --agent codex 2>&1)"
if [[ $? -eq 0 ]]; then
  no "refuses an unknown rule set" "expected non-zero exit"
elif grep -qF "nosuchset" <<<"${out}"; then
  ok "refuses an unknown rule set"
else
  no "refuses an unknown rule set" "message did not name it: ${out}"
fi
absent "installs nothing for an unknown set" "${PWD}/AGENTS.md"

# --- listing ---------------------------------------------------------------

echo "--list"
sandbox
out="$("${INSTALL}" --list 2>&1)"
if [[ $? -eq 0 ]]; then ok "exits 0"; else no "exits 0" "${out}"; fi
if grep -q "claude" <<<"${out}"; then ok "names the agents"; else no "names the agents"; fi

# A set nobody can discover is one nobody installs, so --list is where the
# second set has to show up.
if grep -q "tool-repos" <<<"${out}"; then
  ok "names the sets available"
else
  no "names the sets available" "${out}"
fi

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
links_to "installs for the agent that is present" \
  "${HOME}/.codex/AGENTS.md" "${REPO}/AGENTS.md"
absent "skips the agent that is absent" "${HOME}/.claude/CLAUDE.md"

sandbox
exits_nonzero "fails when no agent is detected" "${INSTALL}"

# --- never clobber ---------------------------------------------------------

echo "existing files"
sandbox
mkdir -p "${HOME}/.codex"
echo "my own Codex defaults" > "${HOME}/.codex/AGENTS.md"
exits_nonzero "refuses to replace a real AGENTS.md" "${INSTALL}" --agent codex
if [[ "$(cat "${HOME}/.codex/AGENTS.md")" == "my own Codex defaults" ]]; then
  ok "leaves the real file untouched"
else
  no "leaves the real file untouched" "contents changed"
fi
absent "does not half-install the rule set" \
  "${HOME}/.codex/rule-sets/ai-rules.md"

sandbox
mkdir -p "${HOME}/.codex"
echo "my own Codex defaults" > "${HOME}/.codex/AGENTS.md"
"${INSTALL}" --force --agent codex >/dev/null 2>&1
links_to "--force replaces it" "${HOME}/.codex/AGENTS.md" "${REPO}/AGENTS.md"

sandbox
echo "a project's own AGENTS.md" > "${PWD}/AGENTS.md"
"${INSTALL}" --agent codex >/dev/null 2>&1
if [[ "$(cat "${PWD}/AGENTS.md")" == "a project's own AGENTS.md" ]]; then
  ok "never replaces a project's root AGENTS.md"
else
  no "never replaces a project's root AGENTS.md" "contents changed"
fi
links_to "still installs the profile defaults" \
  "${HOME}/.codex/AGENTS.md" "${REPO}/AGENTS.md"

# --- dry run ---------------------------------------------------------------

echo "--dry-run"
sandbox
mkdir -p "${HOME}/.codex" "${HOME}/.claude"
"${INSTALL}" --dry-run >/dev/null 2>&1
absent "links nothing" "${HOME}/.codex/AGENTS.md"
absent "links no rule set" "${HOME}/.codex/rule-sets/ai-rules.md"
absent "writes no import" "${HOME}/.claude/CLAUDE.md"

# --- bad input -------------------------------------------------------------

echo "bad input"
sandbox
exits_nonzero "rejects an unknown agent" "${INSTALL}" --agent nosuchagent

echo ""
echo "${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
