#!/usr/bin/env bash
# install-break-reminders.sh
# Installs the break-reminders skill for Claude Code.
# Works on macOS and Linux. Windows users: run install-break-reminders.ps1

set -e

SKILLS_DIR="${HOME}/.claude/skills/break-reminders"
SKILL_FILE="${SKILLS_DIR}/SKILL.md"
REPO_RAW="https://raw.githubusercontent.com/DanMarshall909/ai-rules/main"

echo "Installing break-reminders skill for Claude Code..."

mkdir -p "${SKILLS_DIR}"

if command -v curl &>/dev/null; then
  curl -fsSL "${REPO_RAW}/skills/break-reminders/SKILL.md" -o "${SKILL_FILE}"
elif command -v wget &>/dev/null; then
  wget -qO "${SKILL_FILE}" "${REPO_RAW}/skills/break-reminders/SKILL.md"
else
  echo "Error: curl or wget required." >&2
  exit 1
fi

echo "Done. Skill installed to: ${SKILL_FILE}"
echo ""
echo "Run /break-reminders at the start of any Claude Code session to activate."
