#!/usr/bin/env bash
# new-rule.sh
# Scaffolds a rule fragment and registers it with the set that ships it.
#
#   scripts/new-rule.sh --title "Never Trust The Cache" caching
#   scripts/new-rule.sh --set tool-repos --title "Agent Contract" agent-contract
#
# Writing the fragment is the easy half. Registering it is the half that gets
# forgotten, and an unregistered rule ships to nobody while looking authored —
# so this appends the manifest entry, adds the README row a base-set rule needs,
# and regenerates, in the same breath as creating the file.

set -uo pipefail

source "$(dirname "$0")/rule-sets.sh"
source "$(dirname "$0")/readme.sh"

cd "$(dirname "$0")/.."

SET="${BASE_SET}"
TITLE=""
NAME=""

usage() {
  cat <<EOF
usage: new-rule.sh [--set <set>] [--title "..."] <name>

  <name>     kebab-case; becomes rules/[<set>/]<name>.md
  --set      the rule set that ships it (default: ${BASE_SET})
  --title    the rule's heading

  sets: $(set_names | tr '\n' ' ')
EOF
}

die() { echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set)     SET="${2:-}"; shift 2 || die "--set needs a value" ;;
    --set=*)   SET="${1#*=}"; shift ;;
    --title)   TITLE="${2:-}"; shift 2 || die "--title needs a value" ;;
    --title=*) TITLE="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)        echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      [[ -z "${NAME}" ]] || die "one rule at a time (got '${NAME}' and '$1')"
      NAME="$1"; shift ;;
  esac
done

[[ -n "${NAME}" ]] || { echo "error: no rule name given" >&2; usage >&2; exit 2; }

valid_slug "${NAME}" || die "not a valid rule name: ${NAME} (use kebab-case, e.g. agent-contract)"
known_set "${SET}"   || die "no such rule set: ${SET} (known: $(set_names | tr '\n' ' '))"

[[ -n "${TITLE}" ]] || TITLE="TODO: the rule's own title"

FRAGMENT="$(rules_dir_of "${SET}")/${NAME}.md"
ENTRY="$(rule_entry "${SET}" "${NAME}")"
MANIFEST="$(manifest_of "${SET}")"

[[ ! -e "${FRAGMENT}" ]] || die "${FRAGMENT} already exists"

mkdir -p "$(dirname "${FRAGMENT}")"
cat > "${FRAGMENT}" <<EOF
# ${TITLE}

TODO: state the rule, then say what goes wrong when it is not followed. A rule
that only asserts a preference is one an agent will trade away under pressure;
one that names the failure it prevents is not.
EOF

# Appended, never inserted: manifest order is reading order, and a rule that
# quietly arrived first would reframe everything under it.
printf 'rule: %s\n' "${ENTRY}" >> "${MANIFEST}"

# Only the base set's rules have their own README row; a layered set is
# documented by its own row, which lists the set rather than each of its rules.
if [[ "${SET}" == "${BASE_SET}" ]]; then
  readme_add_row "${README_RULES_HEADING}" \
    "| \`${RULES_DIR}/${NAME}.md\` | TODO: one line on what it does |"
fi

scripts/build-agents.sh >/dev/null || die "the scaffolded rule does not build"

echo "Created ${FRAGMENT}"
echo "Registered it in ${MANIFEST}"
echo ""
echo "Next:"
echo "  1. write ${FRAGMENT}, replacing the TODOs"
if [[ "${SET}" == "${BASE_SET}" ]]; then
  echo "  2. replace the TODO in README.md's rules table"
  echo "  3. scripts/check-conventions.sh"
else
  echo "  2. scripts/check-conventions.sh"
fi
