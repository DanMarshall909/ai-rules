# install-break-reminders.ps1
# Installs the break-reminders skill for Claude Code on Windows.

$skillsDir = Join-Path $env:USERPROFILE ".claude\skills\break-reminders"
$skillFile = Join-Path $skillsDir "SKILL.md"
$rawUrl = "https://raw.githubusercontent.com/DanMarshall909/ai-rules/main/skills/break-reminders/SKILL.md"

Write-Host "Installing break-reminders skill for Claude Code..."

New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
Invoke-WebRequest -Uri $rawUrl -OutFile $skillFile -UseBasicParsing

Write-Host "Done. Skill installed to: $skillFile"
Write-Host ""
Write-Host "Run /break-reminders at the start of any Claude Code session to activate."
