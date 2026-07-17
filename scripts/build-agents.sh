#!/usr/bin/env bash
# build-agents.sh
# Generates AGENTS.md by concatenating rules/*.md.
#
# AGENTS.md is the agent-agnostic entry point: Codex, OpenCode, Cursor, Cline and
# most other assistants read it as plain markdown and have no `@` import syntax.
# It must therefore be self-contained. CLAUDE.md, by contrast, is Claude Code
# specific and imports the same rule files with `@`.
#
# Source of truth is rules/*.md. Never edit AGENTS.md by hand.
#
#   scripts/build-agents.sh           regenerate AGENTS.md
#   scripts/build-agents.sh --check   fail if AGENTS.md is stale (for CI/hooks)

set -euo pipefail

cd "$(dirname "$0")/.."

# Order in which rules appear in AGENTS.md and CLAUDE.md. Keep the two in step.
RULES=(breaks tdd coverage guardrails git issues reflection)

OUTPUT="AGENTS.md"

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

build() {
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
  if ! build | diff -u "${OUTPUT}" - ; then
    echo "" >&2
    echo "error: ${OUTPUT} is stale. Run scripts/build-agents.sh" >&2
    exit 1
  fi
  echo "${OUTPUT} is up to date."
  exit 0
fi

build > "${OUTPUT}"
echo "Wrote ${OUTPUT} from ${#RULES[@]} rule files."
