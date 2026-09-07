#!/usr/bin/env bash
# new-rule-set.sh
# Scaffolds a rule set: rules true of one kind of repo, not of every repo.
#
#   scripts/new-rule-set.sh --title "Tool Repo Rules" \
#     --blurb "For repos whose product is a tool an agent drives." \
#     --layer ai-rules tool-repos
#
# A set is registered in four places — the manifest, a rules/ directory, the
# README table, and the generated markdown — each guarded by a different check,
# or by none. This writes all four, so the convention is easier to follow than
# to break.
#
# `--layer` names the set this one adds to. Almost always ai-rules: a set that
# layers is read *alongside* its base, not instead of it, and the generated
# markdown says so at the top.

set -uo pipefail

source "$(dirname "$0")/rule-sets.sh"
source "$(dirname "$0")/readme.sh"

cd "$(dirname "$0")/.."

TITLE=""
BLURB=""
LAYER=""
FIRST_RULE="overview"
NAME=""

usage() {
  cat <<EOF
usage: new-rule-set.sh --title "..." [options] <name>

  <name>        kebab-case; names the manifest, the rules/ directory and the set
  --title       the set's heading, e.g. "Tool Repo Rules"
  --blurb       one line saying which repos it is for
  --layer <set> the set this one adds to (usually ${BASE_SET})
  --rule <name> the first rule fragment to scaffold (default: ${FIRST_RULE})

  sets: $(set_names | tr '\n' ' ')
EOF
}

die() { echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)   TITLE="${2:-}"; shift 2 || die "--title needs a value" ;;
    --title=*) TITLE="${1#*=}"; shift ;;
    --blurb)   BLURB="${2:-}"; shift 2 || die "--blurb needs a value" ;;
    --blurb=*) BLURB="${1#*=}"; shift ;;
    --layer)   LAYER="${2:-}"; shift 2 || die "--layer needs a value" ;;
    --layer=*) LAYER="${1#*=}"; shift ;;
    --rule)    FIRST_RULE="${2:-}"; shift 2 || die "--rule needs a value" ;;
    --rule=*)  FIRST_RULE="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)        echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      [[ -z "${NAME}" ]] || die "one rule set at a time (got '${NAME}' and '$1')"
      NAME="$1"; shift ;;
  esac
done

[[ -n "${NAME}" ]]  || { echo "error: no rule set name given" >&2; usage >&2; exit 2; }
[[ -n "${TITLE}" ]] || die "no --title given; the generated set would open with an empty heading"

valid_slug "${NAME}"       || die "not a valid rule set name: ${NAME} (use kebab-case, e.g. tool-repos)"
valid_slug "${FIRST_RULE}" || die "not a valid rule name: ${FIRST_RULE} (use kebab-case)"

! known_set "${NAME}" || die "rule set '${NAME}' already exists: $(manifest_of "${NAME}")"

if [[ -n "${LAYER}" ]]; then
  known_set "${LAYER}" || die "--layer names no rule set here: ${LAYER}"
fi

[[ -n "${BLURB}" ]] || BLURB="TODO: one line on which repos this set is for."

MANIFEST="$(manifest_of "${NAME}")"
RULES_SUBDIR="$(rules_dir_of "${NAME}")"
FRAGMENT="${RULES_SUBDIR}/${FIRST_RULE}.md"
README_ROW="| \`$(generated_of "${NAME}")\` | ${BLURB} | ${LAYER:-—} |"

[[ ! -e "${FRAGMENT}" ]] || die "${FRAGMENT} already exists"

# The set is not usable unless it is discoverable. Check the README target
# before creating either source file so a renamed table cannot leave a partial
# scaffold behind.
readme_require_section "${README_SETS_HEADING}" "${README_ROW}" || exit 1

# --- write it ---------------------------------------------------------------

{
  printf '# %s — rules for one kind of repo, layered on the base set.\n#\n' "${NAME}"
  printf '# Order is reading order. Every fragment listed here ships in\n'
  printf '# %s; one that is not listed ships nowhere, and the build says so.\n\n' "$(generated_of "${NAME}")"
  printf 'title: %s\n' "${TITLE}"
  printf 'blurb: %s\n' "${BLURB}"
  [[ -n "${LAYER}" ]] && printf 'layer: %s\n' "${LAYER}"
  printf '\nrule: %s\n' "$(rule_entry "${NAME}" "${FIRST_RULE}")"
} > "${MANIFEST}"

mkdir -p "${RULES_SUBDIR}"
cat > "${FRAGMENT}" <<EOF
# TODO: the rule's own title

TODO: state the rule, then say what goes wrong when it is not followed. A rule
that only asserts a preference is one an agent will trade away under pressure;
one that names the failure it prevents is not.

Rules here apply to every repo that installs the ${NAME} set, so keep project
specifics — paths, project names, command lines — out of them.
EOF

readme_add_row "${README_SETS_HEADING}" "${README_ROW}" ||
  die "the rule set was not registered in ${README}"

scripts/build-agents.sh >/dev/null || die "the scaffolded set does not build"

echo "Created ${MANIFEST}"
echo "Created ${FRAGMENT}"
echo "Updated README.md and $(generated_of "${NAME}")"
echo ""
echo "Next:"
echo "  1. write ${FRAGMENT}, replacing the TODOs"
echo "  2. scripts/new-rule.sh --set ${NAME} <name>   add the next rule"
echo "  3. scripts/check-conventions.sh               confirm it is registered"
echo "  4. scripts/install-rules.sh --rule-set ${NAME} --project <dir>"
