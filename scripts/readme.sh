# readme.sh — README table editing, shared by the scaffolds.
#
# Sourced, not run. check-conventions.sh fails when a rule or a rule set is
# missing from the README, so a scaffold that wrote everything *except* the
# README row would hand back a repo its own checks reject. This adds the row.

README="README.md"
README_RULES_HEADING="## Rules"
README_SETS_HEADING="## Rule sets"

# readme_add_row <section heading> <row>
# Appends a row to the last table under the given heading. Idempotent: a row
# already present is left alone rather than duplicated.
readme_add_row() {
  local heading="$1" row="$2" tmp

  if [[ ! -f "${README}" ]]; then
    echo "error: ${README} does not exist, so '${row}' was not recorded" >&2
    return 1
  fi

  # A heading that is not there means the table was renamed. Say so: silently
  # appending the row at the end of the file would leave the README looking
  # edited and the table still missing its entry.
  if ! grep -qxF "${heading}" "${README}"; then
    echo "error: ${README} has no '${heading}' section, so '${row}' was not recorded" >&2
    return 1
  fi

  grep -qF "${row}" "${README}" && return 0

  tmp="$(mktemp)"
  awk -v heading="${heading}" -v row="${row}" '
    BEGIN { in_section = 0; in_table = 0; done = 0 }
    {
      if (!done) {
        if ($0 == heading) {
          in_section = 1
        } else if (in_section && $0 ~ /^\|/) {
          in_table = 1
        } else if (in_section && in_table) {
          # First line after the table ends: the row belongs above it.
          print row
          done = 1
        }
      }
      print
    }
    END { if (!done) print row }
  ' "${README}" > "${tmp}" && mv "${tmp}" "${README}"
}
