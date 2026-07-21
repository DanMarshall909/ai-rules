#!/usr/bin/env bash
# test-check-conventions.sh
# Behaviour tests for check-conventions.sh.
#
#   scripts/test-check-conventions.sh
#
# check-conventions.sh holds several conventions nothing else holds, and until
# now nothing held it. For a checker the dangerous failure is not a false
# alarm — someone chases that down within a minute — but going quietly blind:
# it still runs, still exits 0, and the convention it stopped enforcing looks
# enforced.
#
# So each test breaks exactly one convention in a throwaway copy of the repo
# and asserts the specific message naming it. Asserting only the exit code
# would let any complaint stand in for any other, which is how the CRLF bug
# hid: install-skill.ps1 checks out with CRLF everywhere, the agent-table
# comparison could not read it at all, and it reported "could not read" where
# "the installers list different agents" was the answer it owed.

set -uo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"

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

# A throwaway copy of the whole repo, carrying the real check-conventions.sh.
#
# cp, not `git archive`: install-skill.ps1 has to arrive with the CRLF endings
# .gitattributes gives it on every platform, because reading it through them is
# itself under test.
sandbox() {
  local s
  s="$(mktemp -d)"
  SANDBOXES+=("${s}")
  mkdir -p "${s}/scripts" "${s}/skills" "${s}/rules"
  cp "${REPO}"/scripts/*.sh "${REPO}"/scripts/*.ps1 "${s}/scripts/"
  cp -R "${REPO}"/skills/. "${s}/skills/"
  cp -R "${REPO}"/rules/. "${s}/rules/"
  cp "${REPO}/CLAUDE.md" "${REPO}/README.md" "${s}/"
  cp -R "${REPO}/.github" "${s}/.github"
  cd "${s}"
  CHECK="${s}/scripts/check-conventions.sh"
}

# The executable-bit check reads the git index, so the tests for it need a
# sandbox that has one.
sandbox_git() {
  sandbox
  git init -q . >/dev/null 2>&1
  git add -A >/dev/null 2>&1
}

run_check() {
  CHECK_OUT="$(bash "${CHECK}" 2>&1)"
  CHECK_CODE=$?
}

# Failed, and said which convention it was.
reports() {
  local label="$1" want="$2"
  if [[ ${CHECK_CODE} -eq 0 ]]; then
    no "${label}" "exited 0; expected a failure"
  elif ! grep -qF -- "${want}" <<<"${CHECK_OUT}"; then
    no "${label}" "no message containing: ${want}"
  else
    ok "${label}"
  fi
}

holds() {
  local label="$1"
  if [[ ${CHECK_CODE} -eq 0 ]]; then
    ok "${label}"
  else
    no "${label}" "$(grep '^error' <<<"${CHECK_OUT}" | head -n 2)"
  fi
}

mentions() {
  local label="$1" want="$2"
  if grep -qF -- "${want}" <<<"${CHECK_OUT}"; then
    ok "${label}"
  else
    no "${label}" "output contained no: ${want}"
  fi
}

matches() {
  local label="$1" want="$2"
  if grep -qE -- "${want}" <<<"${CHECK_OUT}"; then
    ok "${label}"
  else
    no "${label}" "output matched no: ${want}"
  fi
}

# For diagnoses that must *not* appear: naming the wrong problem costs as much
# as naming none, because it sends the reader somewhere else entirely.
says_nothing_about() {
  local label="$1" unwanted="$2"
  if grep -qF -- "${unwanted}" <<<"${CHECK_OUT}"; then
    no "${label}" "said: ${unwanted}"
  else
    ok "${label}"
  fi
}

echo "check-conventions.sh"

# --- the baseline ----------------------------------------------------------
# Every test below asserts that a broken copy fails. None of them means
# anything unless an unbroken copy passes.

echo "a clean checkout"
sandbox_git
run_check
holds "passes on the repo as it stands"
says_nothing_about "reads the CRLF PowerShell table" "could not read"
mentions "names the agents it compared" "  cline"

# --- the two agent tables --------------------------------------------------

echo "the two installers agree"
sandbox_git
perl -i -pe 's/^KNOWN_AGENTS="(.*)"$/KNOWN_AGENTS="$1 ghost"/' scripts/agents.sh
run_check
reports "catches an agent the PowerShell table lacks" \
  "the installers list different agents"

sandbox_git
perl -i -pe 's/knownAgents = \@\(/knownAgents = \@(\x27ghost\x27, /' \
  scripts/install-skill.ps1
run_check
reports "catches an agent the shell table lacks" \
  "the installers list different agents"
says_nothing_about "does not mistake a CRLF table for an unreadable one" \
  "could not read"

# Listing an agent in both tables is not implementing it. Each table lives in a
# different file, so an agent can be half-added four separate ways.
sandbox_git
perl -i -pe 's/^KNOWN_AGENTS="(.*)"$/KNOWN_AGENTS="$1 ghost"/' scripts/agents.sh
perl -i -pe 's/knownAgents = \@\(/knownAgents = \@(\x27ghost\x27, /' \
  scripts/install-skill.ps1
run_check
reports "catches an agent with no root" \
  "scripts/agents.sh: agent_root() has no case for 'ghost'"
reports "catches an agent with no skill target" \
  "scripts/install-skill.sh: agent_target() has no case for 'ghost'"
reports "catches an agent with no rules target" \
  "scripts/install-rules.sh: rules_target() has no case for 'ghost'"
reports "catches an agent with no PowerShell branch" \
  "scripts/install-skill.ps1: Get-AgentSpec has no branch for 'ghost'"

# --- skills declare themselves ---------------------------------------------

echo "skills declare themselves"
sandbox_git
mkdir -p skills/empty-skill
run_check
reports "catches a skill directory with no SKILL.md" \
  "skills/empty-skill/ has no SKILL.md"

sandbox_git
mkdir -p skills/inert
printf '# inert\n\nMarkdown with nothing to load it.\n' > skills/inert/SKILL.md
run_check
reports "catches a SKILL.md with no frontmatter" \
  "skills/inert/SKILL.md does not open with YAML frontmatter"

sandbox_git
mkdir -p skills/mismatched
printf -- '---\nname: other-name\ndescription: Something.\n---\n\nbody\n' \
  > skills/mismatched/SKILL.md
run_check
reports "catches a name that is not the directory" \
  "declares name 'other-name', expected 'mismatched'"

sandbox_git
mkdir -p skills/undescribed
printf -- '---\nname: undescribed\n---\n\nbody\n' \
  > skills/undescribed/SKILL.md
run_check
reports "catches a missing description" \
  "skills/undescribed/SKILL.md frontmatter has no 'description:'"

# The frontmatter is a block, not a grep target. A 'name:' in the body is not a
# declaration, and an agent will not read it as one — but a check that grepped
# the whole file would.
sandbox_git
mkdir -p skills/body-named
printf -- '---\ndescription: Something.\n---\n\nname: body-named\n' \
  > skills/body-named/SKILL.md
run_check
reports "does not accept a 'name:' from the body" \
  "skills/body-named/SKILL.md frontmatter has no 'name:'"

# --- rules are registered --------------------------------------------------

echo "rules are registered"
sandbox_git
printf '# Ghost\n' > rules/ghost.md
run_check
reports "catches a rule CLAUDE.md does not import" \
  "CLAUDE.md does not @import rules/ghost.md"
reports "catches a rule the README does not list" \
  "README.md's rules table does not list rules/ghost.md"

# The two homes are independent: satisfying one must not satisfy the other,
# which is the shape the original bug had — guardrails.md was imported and
# undocumented for its whole life.
sandbox_git
printf '# Ghost\n' > rules/ghost.md
printf '@rules/ghost.md\n' >> CLAUDE.md
run_check
says_nothing_about "stops reporting a rule once it is imported" \
  "CLAUDE.md does not @import rules/ghost.md"
reports "still reports it as undocumented" \
  "README.md's rules table does not list rules/ghost.md"

# --- the executable bit ----------------------------------------------------

echo "scripts are executable"
sandbox_git
run_check
matches "counts the executable scripts" '^  [1-9][0-9]* executable$'

sandbox_git
git update-index --chmod=-x scripts/new-skill.sh
run_check
reports "catches a shebang script left non-executable in the index" \
  "scripts/new-skill.sh starts with a shebang but is 100644 in the index"

# Outside a checkout there is no index to read, so the check cannot run. Saying
# so is the only honest option: a silent "0 executable" reads as a result, and
# would hide this whole section having gone missing.
sandbox
run_check
mentions "names the skip when there is no index" "skipped (not a git checkout)"
says_nothing_about "does not report a count it could not take" "0 executable"
holds "still passes without an index"

# --- test suites run in CI -------------------------------------------------

echo "test suites run in CI"
sandbox_git
printf '#!/usr/bin/env bash\nexit 0\n' > scripts/test-ghost.sh
run_check
reports "catches a suite no workflow runs" \
  "scripts/test-ghost.sh is not run by any workflow"

sandbox_git
rm -rf .github
run_check
mentions "names the skip when there are no workflows" \
  "skipped (no .github/workflows here)"
holds "still passes without workflows"

# --- report ----------------------------------------------------------------

echo ""
echo "${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
