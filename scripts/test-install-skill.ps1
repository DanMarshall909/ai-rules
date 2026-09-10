<#
.SYNOPSIS
  Behaviour tests for install-skill.ps1.

.DESCRIPTION
  Runs the real script against a throwaway profile and project directory, then
  asserts on what actually landed on disk. Mirrors test-install-skill.sh: the
  two implementations must agree on the contract, so the test names are kept
  deliberately parallel.

    scripts\test-install-skill.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$repo = Split-Path -Parent $PSScriptRoot
$install = Join-Path $PSScriptRoot 'install-skill.ps1'

$script:pass = 0
$script:fail = 0
$script:sandboxes = @()

function Ok($label) { $script:pass++; Write-Host "  ok   $label" }
function No($label, $detail) {
  $script:fail++
  Write-Host "  FAIL $label" -ForegroundColor Red
  if ($detail) { Write-Host "       $detail" -ForegroundColor Red }
}

# Fresh isolated profile + project cwd, so a test can never touch the real machine.
function New-Sandbox {
  $s = Join-Path ([System.IO.Path]::GetTempPath()) ("iskill-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Force -Path "$s\home", "$s\project" | Out-Null
  $script:sandboxes += $s
  $env:USERPROFILE = "$s\home"
  $env:XDG_CONFIG_HOME = "$s\home\.config"
  Set-Location "$s\project"
  return $s
}

function Get-Link($path) {
  try {
    $i = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    if ($i.LinkType) { return $i.LinkTarget }
  } catch { }
  return $null
}

function Assert-LinksTo($label, $path, $want) {
  $got = Get-Link $path
  if (-not $got) {
    if (Test-Path -LiteralPath $path) { No $label "exists but is not a link: $path" }
    else { No $label "missing: $path" }
    return
  }
  # Compare resolved paths: 8.3 short names (DANMAR~1) are the same file.
  $a = [System.IO.Path]::GetFullPath($got)
  $b = [System.IO.Path]::GetFullPath($want)
  if ((Get-Item -LiteralPath $a -Force).FullName -ne (Get-Item -LiteralPath $b -Force).FullName) {
    No $label "points at $got, expected $want"
    return
  }
  Ok $label
}

function Assert-Absent($label, $path) {
  if (Test-Path -LiteralPath $path) { No $label "should not exist: $path" } else { Ok $label }
}

# Runs the script in a child process so a failing exit code cannot kill this one.
function Invoke-Install {
  $out = & pwsh -NoProfile -File $install @args 2>&1
  return @{ Code = $LASTEXITCODE; Out = ($out | Out-String) }
}

function Assert-Fails($label) {
  $r = Invoke-Install @args
  if ($r.Code -eq 0) { No $label "expected non-zero exit, got 0" } else { Ok $label }
}

$origProfile = $env:USERPROFILE
$origXdg = $env:XDG_CONFIG_HOME
$origLocation = (Get-Location).Path

try {
  Write-Host "install-skill.ps1"

  # --- discovery -----------------------------------------------------------
  Write-Host "-List"
  New-Sandbox | Out-Null
  $r = Invoke-Install -List
  if ($r.Code -eq 0) { Ok "exits 0" } else { No "exits 0" $r.Out }
  foreach ($s in 'break-reminders', 'reflect', 'behavior-first-tdd') {
    if ($r.Out -match [regex]::Escape($s)) { Ok "lists $s" } else { No "lists $s" "not in output" }
  }

  # --- per-agent targets ---------------------------------------------------
  Write-Host "per-agent targets"
  $s = New-Sandbox
  Invoke-Install -Agent claude reflect | Out-Null
  Assert-LinksTo "claude installs the canonical skill package" "$s\home\.agents\skills\reflect" "$repo\skills\reflect"
  Assert-LinksTo "claude installs a skill directory" "$s\home\.claude\skills\reflect" "$repo\skills\reflect"

  $s = New-Sandbox
  Invoke-Install -Agent codex reflect | Out-Null
  Assert-LinksTo "codex installs a discoverable skill directory" "$s\home\.agents\skills\reflect" "$repo\skills\reflect"
  Assert-Absent "codex does not create a vendor-specific skill link" "$s\home\.codex\skills\reflect"

  $s = New-Sandbox
  Invoke-Install -Agent opencode reflect | Out-Null
  Assert-LinksTo "opencode installs a discoverable skill directory" "$s\home\.agents\skills\reflect" "$repo\skills\reflect"
  Assert-Absent "opencode does not create a command-file adapter" "$s\home\.config\opencode\command\reflect.md"

  $s = New-Sandbox
  Invoke-Install -Agent cursor reflect | Out-Null
  Assert-LinksTo "cursor installs SKILL.md as an .mdc rule" "$s\project\.cursor\rules\reflect.mdc" "$repo\skills\reflect\SKILL.md"

  $s = New-Sandbox
  Invoke-Install -Agent cline reflect | Out-Null
  Assert-LinksTo "cline installs SKILL.md as a .clinerules file" "$s\project\.clinerules\reflect.md" "$repo\skills\reflect\SKILL.md"

  # --- scope ---------------------------------------------------------------
  Write-Host "scope"
  $s = New-Sandbox
  Invoke-Install -Agent cursor reflect | Out-Null
  Assert-LinksTo "project agent installs under cwd" "$s\project\.cursor\rules\reflect.mdc" "$repo\skills\reflect\SKILL.md"
  Assert-Absent "project agent does not touch the profile" "$s\home\.cursor"

  # --- -Project ------------------------------------------------------------
  # A skill shipped by a rule set for one kind of repo belongs in that repo,
  # not in every session on the machine. Names kept parallel with the bash
  # suite: the two installers must agree about where -Project puts things.
  Write-Host "-Project"
  $s = New-Sandbox
  Invoke-Install -Project "$s\project" -Agent claude reflect | Out-Null
  Assert-LinksTo "claude installs the canonical project skill package" `
    "$s\project\.agents\skills\reflect" "$repo\skills\reflect"
  Assert-LinksTo "claude reads a skills directory inside the project" `
    "$s\project\.claude\skills\reflect" "$repo\skills\reflect"
  Assert-Absent "installs nothing into the profile" "$s\home\.claude\skills\reflect"

  $s = New-Sandbox
  Invoke-Install -Project "$s\project" -Agent codex reflect | Out-Null
  Assert-LinksTo "codex gets the skill under .agents" `
    "$s\project\.agents\skills\reflect" "$repo\skills\reflect"
  Assert-Absent "leaves the codex profile alone" "$s\home\.codex\skills\reflect"

  $s = New-Sandbox
  Invoke-Install -Project "$s\project" -Agent opencode reflect | Out-Null
  Assert-LinksTo "opencode gets the skill package under .agents" `
    "$s\project\.agents\skills\reflect" "$repo\skills\reflect"
  Assert-Absent "leaves the OpenCode profile alone" "$s\home\.config\opencode\command\reflect.md"

  $s = New-Sandbox
  New-Item -ItemType Directory -Force -Path "$s\elsewhere" | Out-Null
  Invoke-Install -Project "$s\elsewhere" -Agent cursor reflect | Out-Null
  Assert-LinksTo "a project agent follows -Project too" `
    "$s\elsewhere\.cursor\rules\reflect.mdc" "$repo\skills\reflect\SKILL.md"
  Assert-Absent "leaves the working directory alone" "$s\project\.cursor\rules\reflect.mdc"

  $s = New-Sandbox
  Assert-Fails "refuses a project directory that does not exist" `
    -Project "$s\nowhere" -Agent claude reflect

  # --- all / autodetect ----------------------------------------------------
  Write-Host "-Agent all"
  $s = New-Sandbox
  Invoke-Install -Agent all reflect | Out-Null
  Assert-LinksTo "all: claude"   "$s\home\.claude\skills\reflect"              "$repo\skills\reflect"
  Assert-LinksTo "all: codex"    "$s\home\.agents\skills\reflect"              "$repo\skills\reflect"
  Assert-LinksTo "all: opencode" "$s\home\.agents\skills\reflect"              "$repo\skills\reflect"
  Assert-Absent "all: no OpenCode command adapter" "$s\home\.config\opencode\command\reflect.md"
  Assert-LinksTo "all: cursor"   "$s\project\.cursor\rules\reflect.mdc"        "$repo\skills\reflect\SKILL.md"
  Assert-LinksTo "all: cline"    "$s\project\.clinerules\reflect.md"           "$repo\skills\reflect\SKILL.md"

  Write-Host "autodetect"
  $s = New-Sandbox
  New-Item -ItemType Directory -Force -Path "$s\home\.codex" | Out-Null
  Invoke-Install reflect | Out-Null
  Assert-LinksTo "installs for the agent that is present" "$s\home\.agents\skills\reflect" "$repo\skills\reflect"
  Assert-Absent "skips the agent that is absent" "$s\home\.claude\skills\reflect"

  New-Sandbox | Out-Null
  Assert-Fails "fails when no agent is detected" reflect

  # --- repeat runs ---------------------------------------------------------
  Write-Host "idempotence"
  $s = New-Sandbox
  Invoke-Install -Agent claude reflect | Out-Null
  $r = Invoke-Install -Agent claude reflect
  if ($r.Code -eq 0) { Ok "second run exits 0" } else { No "second run exits 0" $r.Out }
  Assert-LinksTo "second run leaves the link intact" "$s\home\.claude\skills\reflect" "$repo\skills\reflect"
  Assert-LinksTo "second run leaves the canonical link intact" "$s\home\.agents\skills\reflect" "$repo\skills\reflect"

  # --- never clobber -------------------------------------------------------
  Write-Host "existing files"
  $s = New-Sandbox
  New-Item -ItemType Directory -Force -Path "$s\home\.agents\skills\reflect" | Out-Null
  Set-Content "$s\home\.agents\skills\reflect\notes.md" "hand written"
  Assert-Fails "refuses to replace a real file" -Agent codex reflect
  if ((Get-Content "$s\home\.agents\skills\reflect\notes.md" -Raw).Trim() -eq "hand written") {
    Ok "leaves the real file untouched"
  } else { No "leaves the real file untouched" "contents changed" }

  $s = New-Sandbox
  New-Item -ItemType Directory -Force -Path "$s\home\.agents\skills\reflect" | Out-Null
  Set-Content "$s\home\.agents\skills\reflect\notes.md" "hand written"
  Invoke-Install -Force -Agent codex reflect | Out-Null
  Assert-LinksTo "-Force replaces a real file" "$s\home\.agents\skills\reflect" "$repo\skills\reflect"

  $s = New-Sandbox
  New-Item -ItemType Directory -Force -Path "$s\home\.agents\skills" | Out-Null
  New-Item -ItemType SymbolicLink -Path "$s\home\.agents\skills\reflect" `
           -Target (Join-Path $repo 'skills\break-reminders') | Out-Null
  Invoke-Install -Agent codex reflect | Out-Null
  Assert-LinksTo "repoints a stale link without -Force" "$s\home\.agents\skills\reflect" "$repo\skills\reflect"

  # --- bad input -----------------------------------------------------------
  Write-Host "bad input"
  $s = New-Sandbox
  Assert-Fails "rejects an unknown skill" -Agent claude no-such-skill
  Assert-Absent "creates nothing for an unknown skill" "$s\home\.claude\skills\no-such-skill"

  New-Sandbox | Out-Null
  Assert-Fails "rejects an unknown agent" -Agent nosuchagent reflect

  New-Sandbox | Out-Null
  Assert-Fails "rejects no skill argument" -Agent claude

  # ..\skills\reflect resolves to a SKILL.md that really exists, so only the
  # name guard can reject it. A name that fails both checks would pass with the
  # guard deleted.
  $s = New-Sandbox
  Assert-Fails "rejects a path traversal skill name" -Agent claude ..\skills\reflect
  Assert-Absent "creates nothing outside the skills root" "$s\home\.claude\skills\..\skills"

  # --- dry run -------------------------------------------------------------
  Write-Host "-DryRun"
  $s = New-Sandbox
  New-Item -ItemType Directory -Force -Path "$s\home\.claude" | Out-Null
  Invoke-Install -DryRun -Agent claude reflect | Out-Null
  Assert-Absent "creates no canonical link" "$s\home\.agents\skills\reflect"
  Assert-Absent "creates nothing" "$s\home\.claude\skills\reflect"

  # --- several skills ------------------------------------------------------
  Write-Host "multiple skills"
  $s = New-Sandbox
  Invoke-Install -Agent claude reflect break-reminders | Out-Null
  Assert-LinksTo "installs the first canonically" "$s\home\.agents\skills\reflect" "$repo\skills\reflect"
  Assert-LinksTo "installs the second canonically" "$s\home\.agents\skills\break-reminders" "$repo\skills\break-reminders"
  Assert-LinksTo "installs the first"  "$s\home\.claude\skills\reflect"         "$repo\skills\reflect"
  Assert-LinksTo "installs the second" "$s\home\.claude\skills\break-reminders" "$repo\skills\break-reminders"

} finally {
  Set-Location $origLocation
  $env:USERPROFILE = $origProfile
  $env:XDG_CONFIG_HOME = $origXdg
  foreach ($s in $script:sandboxes) {
    Remove-Item -Recurse -Force $s -ErrorAction SilentlyContinue
  }
}

Write-Host ""
Write-Host "$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
