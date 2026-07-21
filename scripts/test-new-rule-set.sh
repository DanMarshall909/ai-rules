#!/usr/bin/env bash
# test-new-rule-set.sh
# Behaviour tests for new-rule-set.sh and new-rule.sh.
#
#   scripts/test-new-rule-set.sh
#
# Both scaffolds exist for the same reason new-skill.sh does: a rule set is
# registered in more places than anyone remembers — a manifest, a rules/
# directory, the README table, the generated markdown — and every one of those
# omissions is caught by a different check, or by none.
#
# So the assertion that matters here is not "it wrote a file" but "what it
# wrote satisfies this repo's own checks". Each test runs the real scripts in a
# throwaway copy of the repo, carrying the real build-agents.sh and
# check-conventions.sh, and asks them.

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

sandbox() {
  local s
  s="$(mktemp -d)"
  SANDBOXES+=("${s}")
  mkdir -p "${s}/scripts" "${s}/skills" "${s}/rules" "${s}/rule-sets"
  cp "${REPO}"/scripts/*.sh "${REPO}"/scripts/*.ps1 "${s}/scripts/"
  cp -R "${REPO}"/skills/. "${s}/skills/"
  cp -R "${REPO}"/rules/. "${s}/rules/"
  cp -R "${REPO}"/rule-sets/. "${s}/rule-sets/"
  cp "${REPO}/AGENTS.md" "${REPO}/CLAUDE.md" "${REPO}/README.md" "${s}/"
  cd "${s}"
  NEW_SET="${s}/scripts/new-rule-set.sh"
  NEW_RULE="${s}/scripts/new-rule.sh"
  BUILD="${s}/scripts/build-agents.sh"
  CHECK="${s}/scripts/check-conventions.sh"
}

contains() { # <label> <file> <text>
  if [[ ! -f "$2" ]]; then
    no "$1" "missing file: $2"
  elif grep -qF "$3" "$2"; then
    ok "$1"
  else
    no "$1" "$2 does not contain '$3'"
  fi
}

exists() {
  if [[ -e "$2" ]]; then ok "$1"; else no "$1" "missing: $2"; fi
}

fails_with() { # <label> <pattern> <command...>
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

passes() { # <label> <command...>
  local label="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then ok "${label}"; else no "${label}" "${out}"; fi
}

echo "new-rule-set.sh"

# --- what a scaffolded set is ----------------------------------------------

echo "scaffolds a usable set"
sandbox
"${NEW_SET}" --title "Widget Rules" --blurb "For widget repos." \
  --layer ai-rules widgets >/dev/null 2>&1
exists "writes the manifest" rule-sets/widgets.set
contains "records the title" rule-sets/widgets.set "title: Widget Rules"
contains "records the blurb" rule-sets/widgets.set "blurb: For widget repos."
contains "records the layer" rule-sets/widgets.set "layer: ai-rules"
contains "lists a first rule" rule-sets/widgets.set "rule: widgets/"

# A set with no rules fails the build, so a scaffold that wrote only a manifest
# would hand back a repo that cannot build — the opposite of what it is for.
if compgen -G "rules/widgets/*.md" >/dev/null; then
  ok "writes a first rule fragment"
else
  no "writes a first rule fragment" "nothing in rules/widgets/"
fi
exists "generates the set's markdown" rule-sets/widgets.md
contains "the generated set names its base" rule-sets/widgets.md "ai-rules.md"

# The whole point: what the scaffold leaves behind passes the repo's own
# checks, without anyone remembering the four places a set is registered.
passes "leaves the generated files up to date" "${BUILD}" --check
passes "leaves the conventions holding" "${CHECK}"

# --- a base set is the default shape ---------------------------------------

echo "layering is optional"
sandbox
"${NEW_SET}" --title "Widget Rules" --blurb "For widget repos." widgets >/dev/null 2>&1
if grep -q '^layer:' rule-sets/widgets.set; then
  no "omits layer: when none was asked for" "$(grep '^layer:' rule-sets/widgets.set)"
else
  ok "omits layer: when none was asked for"
fi
if grep -qF "ai-rules.md" rule-sets/widgets.md; then
  no "a base set points at no other set"
else
  ok "a base set points at no other set"
fi

# --- refusals ---------------------------------------------------------------

echo "refusals"
sandbox
fails_with "refuses a set that already exists" "ai-rules" \
  "${NEW_SET}" --title "Clash" --blurb "b" ai-rules

sandbox
fails_with "refuses a layer that names no set" "nosuchset" \
  "${NEW_SET}" --title "Widget Rules" --blurb "b" --layer nosuchset widgets

sandbox
fails_with "refuses a name that is not kebab-case" "Widgets" \
  "${NEW_SET}" --title "Widget Rules" --blurb "b" Widgets

# A name with a slash would write the manifest outside rule-sets/.
sandbox
fails_with "refuses a name that could escape rule-sets/" "../evil" \
  "${NEW_SET}" --title "Widget Rules" --blurb "b" ../evil
if [[ -e "../evil.set" ]]; then
  no "creates nothing outside rule-sets/" "wrote ../evil.set"
else
  ok "creates nothing outside rule-sets/"
fi

sandbox
fails_with "refuses a set with no title" "title" "${NEW_SET}" --blurb "b" widgets

echo ""
echo "new-rule.sh"

# --- adding a rule to a set -------------------------------------------------

echo "adds a rule to a set"
sandbox
"${NEW_SET}" --title "Widget Rules" --blurb "For widget repos." \
  --layer ai-rules widgets >/dev/null 2>&1
"${NEW_RULE}" --set widgets --title "Widget Naming" naming >/dev/null 2>&1
exists "writes the fragment inside the set's directory" rules/widgets/naming.md
contains "titles the fragment" rules/widgets/naming.md "# Widget Naming"
contains "registers it in the manifest" rule-sets/widgets.set "rule: widgets/naming"
contains "ships it in the generated set" rule-sets/widgets.md "## Widget Naming"
passes "leaves the generated files up to date" "${BUILD}" --check
passes "leaves the conventions holding" "${CHECK}"

# The rule lands after the ones already there: manifest order is reading order,
# and a scaffold that prepended would silently reorder the policy.
sandbox
"${NEW_SET}" --title "Widget Rules" --blurb "b" widgets >/dev/null 2>&1
"${NEW_RULE}" --set widgets --title "Second" second >/dev/null 2>&1
first_line="$(grep -n '^rule: widgets/' rule-sets/widgets.set | head -n 1 | cut -d: -f1)"
last_line="$(grep -n '^rule: widgets/second' rule-sets/widgets.set | cut -d: -f1)"
if [[ -n "${first_line}" && -n "${last_line}" && ${last_line} -gt ${first_line} ]]; then
  ok "appends rather than prepends"
else
  no "appends rather than prepends" "$(grep '^rule:' rule-sets/widgets.set)"
fi

# --- the base set is the default -------------------------------------------

echo "defaults to the base set"
sandbox
"${NEW_RULE}" --title "Naming" naming >/dev/null 2>&1
exists "writes a top-level fragment" rules/naming.md
contains "registers it in the base manifest" rule-sets/ai-rules.set "rule: naming"
contains "adds the README row the checks demand" README.md "rules/naming.md"
passes "leaves the conventions holding" "${CHECK}"

# --- refusals ---------------------------------------------------------------

echo "refusals"
sandbox
fails_with "refuses a rule that already exists" "rules/tdd.md" \
  "${NEW_RULE}" --title "Clash" tdd

sandbox
fails_with "refuses an unknown set" "nosuchset" \
  "${NEW_RULE}" --set nosuchset --title "Naming" naming

sandbox
fails_with "refuses a name that is not kebab-case" "Naming" \
  "${NEW_RULE}" --title "Naming" Naming

sandbox
fails_with "refuses a name that could escape rules/" "../evil" \
  "${NEW_RULE}" --title "Evil" ../evil
if [[ -e "../evil.md" ]]; then
  no "creates nothing outside rules/" "wrote ../evil.md"
else
  ok "creates nothing outside rules/"
fi

echo ""
echo "${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
