# rule-sets.sh — shared by build-agents.sh, the scaffolds and the installers.
#
# Sourced, not run. Everything that has to agree about what a rule set *is*:
# where manifests live, how their fields are read, and which set is the base.
#
# This is one file for the same reason agents.sh is: five scripts read these
# manifests, and a private copy of "how to find the rules in a set" in each of
# them is five chances to disagree about it silently.

RULE_SET_DIR="rule-sets"
RULES_DIR="rules"

# The set AGENTS.md points at, and the one a project gets when it asks for no
# set in particular. Every other set is an addition to this one.
BASE_SET="ai-rules"

manifest_of()  { printf '%s/%s.set' "${RULE_SET_DIR}" "$1"; }
generated_of() { printf '%s/%s.md' "${RULE_SET_DIR}" "$1"; }

# Manifests are line-based (`field: value`) so bash can read them without a
# YAML parser, and `#` comments fall out for free: nothing matches them.
field() { # <manifest> <field> -> every value, in file order
  sed -n "s/^$2: *//p" "$1"
}

# tail, not head: `head -n 1` closes the pipe, sed dies of SIGPIPE, and under
# `set -o pipefail` reading a field would fail its caller.
field_one() { field "$1" "$2" | tail -n 1; }

set_names() {
  local path
  for path in "${RULE_SET_DIR}"/*.set; do
    [[ -f "${path}" ]] || continue
    basename "${path}" .set
  done
}

known_set() { [[ -f "$(manifest_of "$1")" ]]; }

# Where a set's own rule fragments live. The base set keeps its rules at the
# top of rules/, because they were there first and every project reads them;
# every other set gets a directory named after it.
rules_dir_of() { # <set>
  if [[ "$1" == "${BASE_SET}" ]]; then
    printf '%s' "${RULES_DIR}"
  else
    printf '%s/%s' "${RULES_DIR}" "$1"
  fi
}

# The manifest entry for a rule: a path under rules/ without the extension.
rule_entry() { # <set> <rule>
  if [[ "$1" == "${BASE_SET}" ]]; then
    printf '%s' "$2"
  else
    printf '%s/%s' "$1" "$2"
  fi
}

# Same shape new-skill.sh accepts. Anything else could write outside rules/ or
# rule-sets/, and would be refused later by tools that assume this shape.
valid_slug() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }
