#!/usr/bin/env bash
# End-to-end contracts spanning rule and skill installation.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d)"
cleanup() { rm -rf "${fixture}"; }
trap cleanup EXIT
mkdir -p "${fixture}/home" "${fixture}/invoker" "${fixture}/target"
cd "${fixture}/invoker"

run_install() {
  env HOME="${fixture}/home" XDG_CONFIG_HOME="${fixture}/home/.config" \
    "${REPO}/scripts/install-rules.sh" "$@"
}

echo "explicit project keeps rules and project skills together"
run_install --agent cursor,cline,codex --project "${fixture}/target" >/dev/null
for path in .cursor/rules/agentic-delivery.mdc .clinerules/agentic-delivery.md; do
  [[ -f "${fixture}/target/${path}" ]] || {
    echo "FAIL: bundled skill missing from explicit project: ${path}" >&2; exit 1;
  }
done
[[ ! -e .cursor && ! -e .clinerules && ! -e .agents ]] || {
  echo "FAIL: installation wrote into the invoking directory" >&2; exit 1;
}
[[ -f "${fixture}/home/.agents/skills/agentic-delivery/SKILL.md" ]] || {
  echo "FAIL: a user-scoped agent lost its profile skill" >&2; exit 1;
}
echo "PASS: explicit project and profile scopes"

echo "a standalone set installs the selected policy"
mkdir -p "${fixture}/source" "${fixture}/standalone" "${fixture}/standalone-home"
cp -R "${REPO}/scripts" "${REPO}/rules" "${REPO}/rule-sets" \
  "${REPO}/skills" "${REPO}/README.md" "${REPO}/AGENTS.md" "${REPO}/CLAUDE.md" \
  "${fixture}/source/"
"${fixture}/source/scripts/new-rule-set.sh" --title "Standalone Contract" \
  --blurb "A deliberately independent policy." standalone >/dev/null
printf 'skill: reflect\n' >> "${fixture}/source/rule-sets/standalone.set"
standalone_install() {
  env HOME="${fixture}/standalone-home" XDG_CONFIG_HOME="${fixture}/standalone-home/.config" \
    "${fixture}/source/scripts/install-rules.sh" --rule-set standalone \
    --project "${fixture}/standalone" "$@"
}
standalone_install --agent all >/dev/null
for path in .codex/AGENTS.md .config/opencode/AGENTS.md .copilot/copilot-instructions.md; do
  grep -qF '# Standalone Contract' "${fixture}/standalone-home/${path}" || {
    echo "FAIL: native entrypoint does not contain the selected standalone policy: ${path}" >&2; exit 1;
  }
done
grep -qF '/rule-sets/standalone.md' "${fixture}/standalone-home/.claude/CLAUDE.md" || {
  echo "FAIL: Claude does not import the selected standalone policy" >&2; exit 1;
}
for path in .cursor/rules/standalone.mdc .clinerules/standalone.md; do
  grep -qF '# Standalone Contract' "${fixture}/standalone/${path}" || {
    echo "FAIL: project adapter does not contain the selected standalone policy: ${path}" >&2; exit 1;
  }
done
[[ -f "${fixture}/standalone-home/.agents/skills/reflect/SKILL.md" ]] || {
  echo "FAIL: standalone set omitted its declared skill" >&2; exit 1;
}
standalone_install --list > "${fixture}/listing"
grep -qF 'installed: standalone' "${fixture}/listing" || {
  echo "FAIL: listing does not identify the installed standalone policy" >&2; exit 1;
}
echo "PASS: standalone policy selection"
