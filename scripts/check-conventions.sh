#!/usr/bin/env bash
# check-conventions.sh
# Conventions this repo relies on that nothing else enforces.
#
#   scripts/check-conventions.sh
#
# Each check exists because the mistake it catches is silent: the repo still
# looks correct, the other tests still pass, and only a user discovers it.

set -uo pipefail

cd "$(dirname "$0")/.."

failures=0

fail() {
  printf 'error: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# --- every skill is discoverable -------------------------------------------
# An agent finds a skill by its YAML frontmatter, not by its directory. A
# SKILL.md without it is inert markdown: it installs, it reads correctly, and
# it never loads. break-reminders shipped that way and the README documented a
# /break-reminders command that could not have worked.
echo "skills declare themselves"
for dir in skills/*/; do
  name="$(basename "${dir}")"
  file="${dir}SKILL.md"

  if [[ ! -f "${file}" ]]; then
    fail "skills/${name}/ has no SKILL.md"
    continue
  fi

  if [[ "$(head -n 1 "${file}")" != "---" ]]; then
    fail "skills/${name}/SKILL.md does not open with YAML frontmatter"
    continue
  fi

  # Read only the frontmatter block, so a 'name:' in the body cannot satisfy it.
  front="$(awk 'NR>1 { if ($0 == "---") exit; print }' "${file}")"

  declared="$(printf '%s\n' "${front}" | sed -n 's/^name: *//p' | head -n 1)"
  if [[ -z "${declared}" ]]; then
    fail "skills/${name}/SKILL.md frontmatter has no 'name:'"
  elif [[ "${declared}" != "${name}" ]]; then
    fail "skills/${name}/SKILL.md declares name '${declared}', expected '${name}'"
  fi

  if ! printf '%s\n' "${front}" | grep -q '^description: *[^ ]'; then
    fail "skills/${name}/SKILL.md frontmatter has no 'description:'"
  fi

  printf '  %s\n' "${name}"
done

# --- the two installers describe the same world ----------------------------
# install-skill.sh and install-skill.ps1 each carry their own agent table. They
# have separate test suites, so one can gain an agent the other lacks and both
# suites stay green — the divergence only shows up as "works on my machine".
echo "installers agree on agents"
SH="scripts/agents.sh"
PS="scripts/install-skill.ps1"

sh_agents="$(sed -n 's/^KNOWN_AGENTS="\(.*\)"$/\1/p' "${SH}" | tr ' ' '\n' | sort)"
# .gitattributes checks .ps1 out with CRLF deliberately, on Linux as well as
# Windows, so every line here ends "\r\n". An end-anchored pattern then matches
# nothing and the comparison below reports the table as unreadable instead of
# comparing it. Drop the CR before parsing, not after.
ps_agents="$(tr -d '\r' <"${PS}" \
  | sed -n "s/^\\\$knownAgents = @(\(.*\))$/\1/p" \
  | tr -d "' " | tr ',' '\n' | sort)"

if [[ -z "${sh_agents}" ]]; then
  fail "could not read KNOWN_AGENTS from ${SH}"
elif [[ -z "${ps_agents}" ]]; then
  fail "could not read \$knownAgents from ${PS}"
elif [[ "${sh_agents}" != "${ps_agents}" ]]; then
  fail "the installers list different agents:"
  diff <(printf '%s\n' "${sh_agents}") <(printf '%s\n' "${ps_agents}") \
    | sed 's/^/       /' >&2
else
  # Listing an agent is not the same as knowing where its files go: a name added
  # to the list alone would install nothing, silently.
  # Every agent needs a root to be autodetected by, and a target in each
  # installer. They live in different files: the root is shared, the targets are
  # specific to what is being installed.
  TABLES="scripts/agents.sh:agent_root
scripts/install-skill.sh:agent_target
scripts/install-rules.sh:rules_target"

  while IFS= read -r agent; do
    [[ -z "${agent}" ]] && continue
    while IFS=: read -r file fn; do
      [[ -f "${file}" ]] || continue
      # Case labels may share a branch — `codex|opencode)` covers both — so
      # collect the labels and split them, rather than matching line starts.
      # A pattern that missed the second alternative would report a complete
      # table as broken, and a guardrail that cries wolf gets bypassed.
      labels="$(awk "/^${fn}\(\)/,/^}/" "${file}" \
        | sed -n 's/^ *\([a-z|]*\)).*/\1/p' | tr '|' '\n')"
      if ! grep -qx "${agent}" <<<"${labels}"; then
        fail "${file}: ${fn}() has no case for '${agent}'"
      fi
    done <<<"${TABLES}"
    if ! grep -qE "^ *'${agent}' \{" "${PS}"; then
      fail "${PS}: Get-AgentSpec has no branch for '${agent}'"
    fi
    printf '  %s\n' "${agent}"
  done <<<"${sh_agents}"
fi

# --- anything with a shebang is executable in the index --------------------
# git stores the executable bit, but Windows checkouts run with
# core.filemode=false, so `chmod +x` changes the working copy and records
# nothing. The script runs fine for its author and dies on Linux with
# "Permission denied" — visible only in CI, and only after a push. Sourced
# libraries have no shebang and are deliberately not executable.
echo "scripts are executable"
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  # test-new-skill.sh runs this script inside a plain copy of scripts/, which
  # has no index to read. Name the skip: a silent "0 executable" reads like a
  # result, and this check can only ever pass where it cannot run.
  printf '  skipped (not a git checkout)\n'
else
  executable=0
  while IFS= read -r entry; do
    mode="${entry%% *}"
    file="${entry#*$'\t'}"
    [[ -f "${file}" ]] || continue
    head -c 2 "${file}" | grep -q '#!' || continue

    if [[ "${mode}" != "100755" ]]; then
      fail "${file} starts with a shebang but is ${mode} in the index (needs 100755)"
      fail "  fix: git update-index --chmod=+x ${file}"
    else
      executable=$((executable + 1))
    fi
  done < <(git ls-files -s scripts/)
  printf '  %d executable\n' "${executable}"
fi

# --- every rule is registered everywhere it has to be ----------------------
# build-agents.sh already refuses to build when rules/ holds a file its RULES
# array omits, so AGENTS.md cannot silently lose a rule. The other two homes
# have no such check: guardrails.md was missing from the README table for its
# whole life, and a rule absent from CLAUDE.md is one Claude Code never loads
# while every other agent obeys it.
echo "rules are registered"
for path in rules/*.md; do
  name="$(basename "${path}" .md)"

  if ! grep -qF "@rules/${name}.md" CLAUDE.md; then
    fail "CLAUDE.md does not @import rules/${name}.md"
  fi

  if ! grep -qF "rules/${name}.md" README.md; then
    fail "README.md's rules table does not list rules/${name}.md"
  fi

  printf '  %s\n' "${name}"
done

echo ""
if [[ ${failures} -gt 0 ]]; then
  printf '%d convention(s) broken\n' "${failures}" >&2
  exit 1
fi
echo "conventions hold."
