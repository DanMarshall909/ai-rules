#!/usr/bin/env bash
# test-new-skill.sh
# Behaviour tests for new-skill.sh.
#
#   scripts/test-new-skill.sh
#
# Each test runs the script inside a throwaway copy of scripts/ and skills/, so
# it never adds a skill to the real repo. Because the copy carries the real
# check-conventions.sh, the suite can assert the thing that actually matters:
# what the scaffold writes is what the repo's own checks demand.

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

# A throwaway repo: the real scripts, a copy of the real skills.
sandbox() {
  local s
  s="$(mktemp -d)"
  SANDBOXES+=("${s}")
  mkdir -p "${s}/scripts" "${s}/skills" "${s}/rules"
  cp "${REPO}"/scripts/*.sh "${REPO}"/scripts/*.ps1 "${s}/scripts/"
  cp -R "${REPO}"/skills/. "${s}/skills/"
  # check-conventions.sh also reads rules/, CLAUDE.md and README.md, so the
  # sandbox has to be a whole repo rather than just the parts under test.
  cp -R "${REPO}"/rules/. "${s}/rules/"
  cp "${REPO}/CLAUDE.md" "${REPO}/README.md" "${s}/"
  cd "${s}"
  NEW="${s}/scripts/new-skill.sh"
  CHECK="${s}/scripts/check-conventions.sh"
}

echo "new-skill.sh"

# --- what it creates -------------------------------------------------------

echo "creates a skill"
sandbox
out="$(bash "${NEW}" my-new-skill 2>&1)"
code=$?
if [[ ${code} -eq 0 ]]; then ok "exits 0"; else no "exits 0" "${out}"; fi

if [[ -f skills/my-new-skill/SKILL.md ]]; then
  ok "writes skills/<name>/SKILL.md"
else
  no "writes skills/<name>/SKILL.md" "not found"
fi

if grep -q '^name: my-new-skill$' skills/my-new-skill/SKILL.md 2>/dev/null; then
  ok "declares a name matching the directory"
else
  no "declares a name matching the directory"
fi

if grep -q '^description: .' skills/my-new-skill/SKILL.md 2>/dev/null; then
  ok "declares a description"
else
  no "declares a description"
fi

if grep -q 'my-new-skill' skills/my-new-skill/SKILL.md 2>/dev/null; then
  ok "names the skill in the body"
else
  no "names the skill in the body"
fi

# The assertion the whole script exists to satisfy: a fresh skill must not
# break the repo's own conventions check the moment it is created.
echo "the result satisfies the repo's checks"
sandbox
bash "${NEW}" another-skill >/dev/null 2>&1
if bash "${CHECK}" >/dev/null 2>&1; then
  ok "check-conventions.sh passes on a fresh skill"
else
  no "check-conventions.sh passes on a fresh skill" "$(bash "${CHECK}" 2>&1 >/dev/null | head -2)"
fi

# --- description -----------------------------------------------------------

echo "--description"
# Read the description the way a YAML parser would, not the way the writer
# wrote it. The distinction matters: a sed that simply strips optional quotes
# agrees with any output at all, so it cannot tell a quoted description from an
# unquoted one that has silently become a nested mapping. This refuses the
# latter, which is what makes the quoting testable.
yaml_description() {
  perl -ne '
    next unless s/^description:[ ]//;
    chomp;
    if (/^'"'"'(.*)'"'"'$/) {          # single quoted: '"'"''"'"' is a literal quote
      my $v = $1; $v =~ s/'"'"''"'"'/'"'"'/g; print $v; exit 0;
    }
    die "unquoted value contains \": \" - YAML reads this as a nested mapping\n"
      if / : | :$/ || /: /;
    print; exit 0;
  ' "$1"
}

sandbox
bash "${NEW}" --description "Does a specific thing when asked." described-skill >/dev/null 2>&1
got="$(yaml_description skills/described-skill/SKILL.md 2>/dev/null)"
if [[ "${got}" == "Does a specific thing when asked." ]]; then
  ok "uses the description given"
else
  no "uses the description given" "got: ${got}"
fi

sandbox
bash "${NEW}" --description "Use when: the user says \"go\"." punctuated >/dev/null 2>&1
got="$(yaml_description skills/punctuated/SKILL.md 2>/dev/null)"
if [[ "${got}" == 'Use when: the user says "go".' ]]; then
  ok "a description containing a colon survives intact"
else
  no "a description containing a colon survives intact" "got: ${got}"
fi

sandbox
bash "${NEW}" --description "Has: a colon, and \"quotes\"." tricky-skill >/dev/null 2>&1
if bash "${CHECK}" >/dev/null 2>&1; then
  ok "a description with YAML punctuation still parses"
else
  no "a description with YAML punctuation still parses" "$(bash "${CHECK}" 2>&1 >/dev/null | head -2)"
fi

# --- refusing --------------------------------------------------------------

echo "refuses to damage anything"
sandbox
before="$(cat skills/reflect/SKILL.md)"
if bash "${NEW}" reflect >/dev/null 2>&1; then
  no "refuses an existing skill" "expected non-zero exit"
else
  ok "refuses an existing skill"
fi
if [[ "$(cat skills/reflect/SKILL.md)" == "${before}" ]]; then
  ok "leaves the existing skill untouched"
else
  no "leaves the existing skill untouched" "contents changed"
fi

echo "rejects bad names"
for bad in "Upper-Case" "has space" "../escape" "-leading-dash" ""; do
  sandbox
  label="rejects '${bad}'"
  if bash "${NEW}" "${bad}" >/dev/null 2>&1; then
    no "${label}" "expected non-zero exit"
  else
    ok "${label}"
  fi
done

sandbox
bash "${NEW}" ../escape >/dev/null 2>&1
absent=1
[[ -e "${PWD}/../escape" ]] && absent=0
if [[ ${absent} -eq 1 ]]; then
  ok "creates nothing outside skills/"
else
  no "creates nothing outside skills/" "wrote outside the repo"
fi

# --- report ----------------------------------------------------------------

echo ""
echo "${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
