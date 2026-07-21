#!/usr/bin/env bash
# build-agents.sh
# Generates the shared rule set and a minimal AGENTS.md entrypoint.
#
# AGENTS.md is intentionally small. The substantive policy lives in
# rule-sets/ai-rules.md so the rule set has one markdown home and the agent
# entrypoint is only compatibility wiring.
#
# Source of truth is rules/*.md. Never edit generated rule files by hand.
#
#   scripts/build-agents.sh           regenerate AGENTS.md
#   scripts/build-agents.sh --check   fail if generated rule files are stale

set -euo pipefail

cd "$(dirname "$0")/.."

# Order in which rules appear in the shared rule set.
RULES=(breaks tdd coverage guardrails git issues reflection)

OUTPUT="AGENTS.md"
RULE_SET_OUTPUT="rule-sets/ai-rules.md"

# Demote every heading one level so the rule files' `#` titles nest under this
# document's single `# AI Rules`. Headings inside fenced code blocks are left
# alone.
demote_headings() {
  awk '
    /^```/ { fence = !fence; print; next }
    !fence && /^#/ { print "#" $0; next }
    { print }
  ' "$1"
}

build_rule_set() {
  cat <<'HEADER'
# AI Rules

Lean, agent-agnostic rules for any coding assistant.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: rules/*.md
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->
HEADER

  for rule in "${RULES[@]}"; do
    printf '\n---\n\n'
    demote_headings "rules/${rule}.md"
  done
}

build_agents() {
  cat <<'HEADER'
# AI Rules

Read and follow the shared rule set in [rule-sets/ai-rules.md](rule-sets/ai-rules.md).

This file is intentionally minimal. The rule set is the policy; AGENTS.md is
only the entrypoint for agents that look for this filename.

<!-- GENERATED FILE — do not edit by hand.
     Source of truth: rule-sets/ai-rules.md and rules/*.md
     Regenerate:      scripts/build-agents.sh
     Verify:          scripts/build-agents.sh --check -->
HEADER
}

for rule in "${RULES[@]}"; do
  if [[ ! -f "rules/${rule}.md" ]]; then
    echo "error: rules/${rule}.md does not exist" >&2
    exit 1
  fi
done

# Every rule file must appear in RULES. Without this, adding rules/foo.md and
# forgetting the list above silently drops it from AGENTS.md — the generator
# succeeds, --check passes (it compares against the same short list), and only
# non-Claude agents notice, by never seeing the rule.
for path in rules/*.md; do
  rule="$(basename "${path}" .md)"
  if [[ ! " ${RULES[*]} " == *" ${rule} "* ]]; then
    echo "error: rules/${rule}.md is not listed in RULES, so ${OUTPUT} would omit it." >&2
    echo "       Add '${rule}' to RULES in $0 (and an @import to CLAUDE.md)." >&2
    exit 1
  fi
done

if [[ "${1:-}" == "--check" ]]; then
  if ! build_agents | diff -u "${OUTPUT}" - ; then
    echo "" >&2
    echo "error: ${OUTPUT} is stale. Run scripts/build-agents.sh" >&2
    exit 1
  fi
  if ! build_rule_set | diff -u "${RULE_SET_OUTPUT}" - ; then
    echo "" >&2
    echo "error: ${RULE_SET_OUTPUT} is stale. Run scripts/build-agents.sh" >&2
    exit 1
  fi
  echo "${OUTPUT} and ${RULE_SET_OUTPUT} are up to date."
  exit 0
fi

mkdir -p "$(dirname "${RULE_SET_OUTPUT}")"
build_agents > "${OUTPUT}"
build_rule_set > "${RULE_SET_OUTPUT}"
echo "Wrote ${OUTPUT} and ${RULE_SET_OUTPUT} from ${#RULES[@]} rule files."
