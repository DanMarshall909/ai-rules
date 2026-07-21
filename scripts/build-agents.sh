#!/usr/bin/env bash
# build-agents.sh
# Generates every rule set from its manifest, plus the AGENTS.md entrypoint.
#
# A rule set is `rule-sets/<name>.set` — a line-based manifest naming the rule
# fragments it ships, in order — and `rule-sets/<name>.md`, generated from it.
# `ai-rules` is the base set every project gets; a set with a `layer:` field is
# an addition for one kind of repo, read alongside the set it names.
#
# AGENTS.md is intentionally small. The substantive policy lives in the rule
# sets, so the policy has one markdown home and the agent entrypoint is only
# compatibility wiring.
#
# Source of truth is rules/*.md and the manifests. Never edit a generated file.
#
#   scripts/build-agents.sh           regenerate every rule set and AGENTS.md
#   scripts/build-agents.sh --check   fail if any generated file is stale

set -euo pipefail

# Manifest layout, field reading and which set is the base are shared with the
# scaffolds and the installers, so none of them can disagree about it.
source "$(dirname "$0")/rule-sets.sh"

cd "$(dirname "$0")/.."

OUTPUT="AGENTS.md"

# Demote every heading one level so the rule files' `#` titles nest under the
# set's single `# Title`. Headings inside fenced code blocks are left alone.
demote_headings() {
  awk '
    /^```/ { fence = !fence; print; next }
    !fence && /^#/ { print "#" $0; next }
    { print }
  ' "$1"
}

build_rule_set() { # <set name>
  local name="$1" manifest title blurb layer rule
  manifest="$(manifest_of "${name}")"
  title="$(field_one "${manifest}" title)"
  blurb="$(field_one "${manifest}" blurb)"
  layer="$(field_one "${manifest}" layer)"

  printf '# %s\n\n%s\n' "${title}" "${blurb}"

  # A layered set is half a policy. An agent handed one has to be told where
  # the rest of it is, or it obeys the additions and none of the base.
  if [[ -n "${layer}" ]]; then
    printf '\nThis set extends [%s.md](%s.md) rather than replacing it. Read both.\n' \
      "${layer}" "${layer}"
  fi

  cat <<EOF

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: ${manifest} and the rules/ files it lists
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->
EOF

  while IFS= read -r rule; do
    [[ -z "${rule}" ]] && continue
    printf '\n---\n\n'
    demote_headings "rules/${rule}.md"
  done < <(field "${manifest}" rule)
}

build_agents() {
  cat <<EOF
# AI Rules

Read and follow the shared rule set in [${RULE_SET_DIR}/${BASE_SET}.md](${RULE_SET_DIR}/${BASE_SET}.md).

This file is intentionally minimal. The rule set is the policy; AGENTS.md is
only the entrypoint for agents that look for this filename.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: ${RULE_SET_DIR}/${BASE_SET}.md and rules/*.md
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->
EOF
}

die() { echo "error: $*" >&2; exit 1; }

# --- validation -------------------------------------------------------------
# Everything below fails the build rather than generating something wrong,
# because every one of these mistakes is invisible in the output: the file is
# written, the check passes, and an agent somewhere reads a rule set missing a
# rule it was meant to obey.

[[ -f "$(manifest_of "${BASE_SET}")" ]] ||
  die "$(manifest_of "${BASE_SET}") does not exist — ${OUTPUT} points at the ${BASE_SET} set"

claimed=""
for name in $(set_names); do
  manifest="$(manifest_of "${name}")"

  [[ -n "$(field_one "${manifest}" title)" ]] ||
    die "${manifest} has no 'title:' — the generated set would open with an empty heading"

  layer="$(field_one "${manifest}" layer)"
  if [[ -n "${layer}" ]]; then
    [[ -f "$(manifest_of "${layer}")" ]] ||
      die "${manifest} layers on '${layer}', which is not a rule set here"
    [[ "${layer}" != "${name}" ]] ||
      die "${manifest} layers on itself"
  fi

  rules_in_set=0
  while IFS= read -r rule; do
    [[ -z "${rule}" ]] && continue
    [[ -f "rules/${rule}.md" ]] ||
      die "${manifest} lists '${rule}', but rules/${rule}.md does not exist"
    claimed+=" rules/${rule}.md"
    rules_in_set=$((rules_in_set + 1))
  done < <(field "${manifest}" rule)

  [[ ${rules_in_set} -gt 0 ]] ||
    die "${manifest} lists no rules — it would generate an empty rule set"
done

# The mistake this catches: a rule file written, never listed, and therefore
# shipped to nobody. The build succeeds, --check passes, the repo looks right,
# and only a reader of the rule set would ever notice it is not there.
while IFS= read -r path; do
  case " ${claimed} " in
    *" ${path} "*) ;;
    *) die "${path} is not listed by any ${RULE_SET_DIR}/*.set, so no rule set ships it" ;;
  esac
done < <(find rules -type f -name '*.md' | sort)

# --- generate or check ------------------------------------------------------

if [[ "${1:-}" == "--check" ]]; then
  if ! build_agents | diff -u "${OUTPUT}" - ; then
    echo "" >&2
    echo "error: ${OUTPUT} is stale. Run scripts/build-agents.sh" >&2
    exit 1
  fi
  for name in $(set_names); do
    out="$(generated_of "${name}")"
    if ! build_rule_set "${name}" | diff -u "${out}" - ; then
      echo "" >&2
      echo "error: ${out} is stale. Run scripts/build-agents.sh" >&2
      exit 1
    fi
  done
  echo "${OUTPUT} and $(set_names | wc -l | tr -d ' ') rule set(s) are up to date."
  exit 0
fi

mkdir -p "${RULE_SET_DIR}"
build_agents > "${OUTPUT}"
for name in $(set_names); do
  build_rule_set "${name}" > "$(generated_of "${name}")"
  echo "Wrote $(generated_of "${name}")"
done
echo "Wrote ${OUTPUT}"
