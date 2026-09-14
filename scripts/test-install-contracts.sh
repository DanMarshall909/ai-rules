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
