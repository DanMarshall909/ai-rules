#!/usr/bin/env bash
# new-skill.sh
# Scaffolds a new skill in skills/.
#
#   scripts/new-skill.sh my-skill
#   scripts/new-skill.sh --description "Use when ..." my-skill
#
# The frontmatter is the point. An agent finds a skill by its YAML name and
# description, so a SKILL.md without them installs cleanly and never loads —
# which is exactly what check-conventions.sh now refuses to let happen. This
# script is the other half of that: the convention is easy to follow, so nobody
# has to remember it.

set -uo pipefail

cd "$(dirname "$0")/.."

DESCRIPTION=""
NAME=""

usage() {
  cat <<'EOF'
usage: new-skill.sh [--description "..."] <name>

  <name>          kebab-case; becomes both the directory and the frontmatter name
  --description   one line telling an agent when to reach for this skill
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --description)   DESCRIPTION="${2:-}"; shift 2 || { echo "error: --description needs a value" >&2; exit 2; } ;;
    --description=*) DESCRIPTION="${1#*=}"; shift ;;
    -h|--help)       usage; exit 0 ;;
    -*)              echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [[ -n "${NAME}" ]]; then
        echo "error: one skill at a time (got '${NAME}' and '$1')" >&2
        exit 2
      fi
      NAME="$1"; shift ;;
  esac
done

if [[ -z "${NAME}" ]]; then
  echo "error: no skill name given" >&2
  usage >&2
  exit 2
fi

# Same shape install-skill.sh accepts, so a skill cannot be created under a name
# the installer would later refuse — and nothing can escape skills/.
if [[ ! "${NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "error: not a valid skill name: ${NAME}" >&2
  echo "       use lower-case kebab-case, e.g. my-skill" >&2
  exit 2
fi

DIR="skills/${NAME}"
FILE="${DIR}/SKILL.md"

if [[ -e "${DIR}" ]]; then
  echo "error: ${DIR} already exists" >&2
  exit 1
fi

if [[ -z "${DESCRIPTION}" ]]; then
  DESCRIPTION="TODO: say when an agent should reach for ${NAME}, in one line."
fi

# Quote the description so a colon or a quote mark in it cannot break the YAML.
# Single quotes are the safe container; the only escape YAML needs inside them
# is a doubled single quote.
escaped="${DESCRIPTION//\'/\'\'}"

mkdir -p "${DIR}"
cat > "${FILE}" <<EOF
---
name: ${NAME}
description: '${escaped}'
---

# ${NAME}

TODO: one paragraph on what invoking this skill does, and what the user gets
back at the end.

---

## Step 1 — ...

TODO: skills are instructions to an agent, not documentation for a human. Write
them as steps to carry out, and say what to do when a step cannot be completed.

---

## Notes

- TODO: anything the agent should know but not do
EOF

echo "Created ${FILE}"
echo ""
echo "Next:"
echo "  1. write the steps, and replace the description in the frontmatter"
echo "  2. scripts/check-conventions.sh      confirm it is discoverable"
echo "  3. scripts/install-skill.sh ${NAME}  link it into your agents"
