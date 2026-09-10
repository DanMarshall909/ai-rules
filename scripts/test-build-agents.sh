#!/usr/bin/env bash
# test-build-agents.sh
# Behaviour tests for build-agents.sh.
#
#   scripts/test-build-agents.sh
#
# The generator had no suite of its own: `--check` compared its output against
# the file it had just written the same way, so the two agreed by construction
# and nothing said what the output must *contain*. That was survivable while a
# single hard-coded array named every rule. Once a rule set is a manifest — and
# there can be more than one — the failures worth catching are all silent ones:
# a set that generates nothing, a rule listed but never emitted, a rule file no
# set claims, a layered set that forgets to name its base.
#
# Each test runs the real script inside a throwaway copy of the repo, so no
# test can write a rule set into the checkout.

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

# A throwaway repo carrying the real scripts, rules and manifests.
sandbox() {
  local s
  s="$(mktemp -d)"
  SANDBOXES+=("${s}")
  mkdir -p "${s}/scripts" "${s}/rules" "${s}/rule-sets"
  cp "${REPO}"/scripts/*.sh "${s}/scripts/"
  cp -R "${REPO}"/rules/. "${s}/rules/"
  cp -R "${REPO}"/rule-sets/. "${s}/rule-sets/"
  cp "${REPO}/AGENTS.md" "${REPO}/CLAUDE.md" "${REPO}/README.md" "${s}/"
  cd "${s}"
  BUILD="${s}/scripts/build-agents.sh"
}

# A guardrail whose test asserts only the exit code lets any failure stand in
# for any other, so every negative case here names the thing it broke.
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

contains() { # <label> <file> <text>
  if [[ ! -f "$2" ]]; then
    no "$1" "missing file: $2"
  elif grep -qF "$3" "$2"; then
    ok "$1"
  else
    no "$1" "$2 does not contain '$3'"
  fi
}

# Line number of the first match, for order assertions.
line_of() { grep -nF -m1 "$2" "$1" | cut -d: -f1; }

echo "build-agents.sh"

# --- one generated markdown file per manifest -------------------------------

echo "generates every set"
sandbox
"${BUILD}" >/dev/null 2>&1
if [[ -f rule-sets/ai-rules.md ]]; then
  ok "writes the base set"
else
  no "writes the base set"
fi

sandbox
mkdir -p rules/extra
printf '# Extra Rule\n\nDo the extra thing.\n' > rules/extra/thing.md
printf 'title: Extra Rules\nblurb: For repos that need the extra thing.\nlayer: ai-rules\nrule: extra/thing\n' \
  > rule-sets/extra.set
"${BUILD}" >/dev/null 2>&1
if [[ -f rule-sets/extra.md ]]; then
  ok "writes a set added since the last build"
else
  no "writes a set added since the last build" "no rule-sets/extra.md"
fi
contains "carries the set's title" rule-sets/extra.md "# Extra Rules"
contains "carries the set's blurb" rule-sets/extra.md "For repos that need the extra thing."
contains "copies the rule body verbatim" rule-sets/extra.md "Do the extra thing."
contains "demotes the rule's own heading" rule-sets/extra.md "## Extra Rule"

# A layered set is only half a policy: an agent handed one must be told where
# the rest of it is, or it silently obeys the extras and none of the base.
contains "a layered set names the set it extends" rule-sets/extra.md "ai-rules.md"

# --- the base set's content is unchanged ------------------------------------
# The manifest replaced a hard-coded array. Nothing about which rules ship, or
# in what order, was meant to change with it.

echo "the base set still says what it said"
sandbox
"${BUILD}" >/dev/null 2>&1
for rule in breaks tdd coverage guardrails git issues reflection; do
  title="$(head -n 1 "rules/${rule}.md" | sed 's/^# //')"
  contains "ships ${rule}" rule-sets/ai-rules.md "## ${title}"
done
contains "the TDD rule names its supplied skill" rule-sets/ai-rules.md \
  "/behavior-first-tdd"

lines="$(wc -l < rule-sets/ai-rules.md)"
if [[ ${lines} -lt 200 ]]; then
  ok "keeps the always-loaded base policy below 200 lines"
else
  no "keeps the always-loaded base policy below 200 lines" \
    "generated ${lines} lines"
fi
for skill in behavior-first-tdd coverage-and-mutation security-by-design \
             break-reminders reflect; do
  contains "routes detailed work to ${skill}" rule-sets/ai-rules.md \
    "the \`${skill}\` skill"
done

# Reading order is policy: breaks and TDD frame everything after them, and
# reflection closes. A manifest that silently reordered would read as a rewrite.
first="$(line_of rule-sets/ai-rules.md "## Break Reminders")"
last="$(line_of rule-sets/ai-rules.md "## Reflection")"
if [[ -n "${first}" && -n "${last}" && ${first} -lt ${last} ]]; then
  ok "keeps the manifest's order"
else
  no "keeps the manifest's order" "breaks at ${first:-?}, reflection at ${last:-?}"
fi

contains "AGENTS.md still points at the base set" AGENTS.md "rule-sets/ai-rules.md"

# --- --check ----------------------------------------------------------------

echo "--check"
sandbox
"${BUILD}" >/dev/null 2>&1
if "${BUILD}" --check >/dev/null 2>&1; then
  ok "passes on a freshly built tree"
else
  no "passes on a freshly built tree" "$("${BUILD}" --check 2>&1 | tail -3)"
fi

sandbox
"${BUILD}" >/dev/null 2>&1
printf '\nan edit nobody regenerated\n' >> rule-sets/ai-rules.md
fails_with "names the stale set" "rule-sets/ai-rules.md" "${BUILD}" --check

# A second set is the case the old --check could not have caught: it compared
# one output against one file.
sandbox
mkdir -p rules/extra
printf '# Extra Rule\n\nDo the extra thing.\n' > rules/extra/thing.md
printf 'title: Extra Rules\nblurb: For repos that need the extra thing.\nrule: extra/thing\n' \
  > rule-sets/extra.set
"${BUILD}" >/dev/null 2>&1
printf '\nan edit nobody regenerated\n' >> rule-sets/extra.md
fails_with "names the stale set among several" "rule-sets/extra.md" "${BUILD}" --check

# The pre-commit hook guards the snapshot Git will commit, not whichever
# unstaged files happen to be in the working tree. Otherwise staging only a
# regenerated file while leaving its authored rule unstaged produces a commit
# that immediately fails --check, even though the hook passed before it.
echo "pre-commit"
sandbox
mkdir -p scripts/hooks skills .github
cp "${REPO}/scripts/hooks/pre-commit" scripts/hooks/
cp "${REPO}/scripts/install-skill.ps1" scripts/
cp -R "${REPO}"/skills/. skills/
cp -R "${REPO}"/.github/. .github/
git init -q
git config user.name "Build test"
git config user.email "build-test@example.invalid"
git add .
git commit -qm "baseline"
printf '\nan unstaged authored change\n' >> rules/breaks.md
"${BUILD}" >/dev/null 2>&1
git add rule-sets/ai-rules.md
fails_with "checks the staged snapshot" "generated rule files are stale" \
  scripts/hooks/pre-commit

# --- manifests that cannot be honoured --------------------------------------

echo "broken manifests"
sandbox
printf 'title: Extra Rules\nblurb: For repos that need the extra thing.\nrule: extra/missing\n' \
  > rule-sets/extra.set
fails_with "refuses a rule that does not exist" "rules/extra/missing.md" "${BUILD}"

# The failure this replaces: a rule file added to rules/ and left out of the
# array shipped nowhere, while the build, --check and the repo all looked fine.
sandbox
mkdir -p rules/extra
printf '# Orphan\n\nNobody ships this.\n' > rules/extra/orphan.md
fails_with "refuses a rule no set lists" "rules/extra/orphan.md" "${BUILD}"

sandbox
printf '# Orphan\n\nNobody ships this.\n' > rules/orphan.md
fails_with "refuses a top-level rule no set lists" "rules/orphan.md" "${BUILD}"

# A layer pointing at nothing generates a pointer to a file that will never
# exist, and the agent following it just reads no base rules at all.
sandbox
mkdir -p rules/extra
printf '# Extra Rule\n\nDo the extra thing.\n' > rules/extra/thing.md
printf 'title: Extra Rules\nblurb: b\nlayer: nosuchset\nrule: extra/thing\n' > rule-sets/extra.set
fails_with "refuses a layer that names no set" "nosuchset" "${BUILD}"

sandbox
mkdir -p rules/extra
printf '# Extra Rule\n\nDo the extra thing.\n' > rules/extra/thing.md
printf 'blurb: b\nrule: extra/thing\n' > rule-sets/extra.set
fails_with "refuses a set with no title" "extra.set" "${BUILD}"

echo ""
echo "${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
