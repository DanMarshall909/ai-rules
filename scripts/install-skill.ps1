<#
.SYNOPSIS
  Installs a skill from skills/ into whichever coding agents you use.

.DESCRIPTION
  The Windows counterpart to install-skill.sh, with the same contract: skills are
  linked out of this checkout, never copied, so editing skills/<name>/SKILL.md
  takes effect everywhere at once.

  Creating a symlink on Windows needs Developer Mode or an elevated shell. Where
  that is unavailable this falls back to a directory junction, which needs
  neither and works across volumes. File-based agents have no such fallback that
  survives a repo on a different drive from your profile, so they fail loudly
  rather than leaving a copy that silently stops tracking the repo.

.EXAMPLE
  scripts\install-skill.ps1 -List
.EXAMPLE
  scripts\install-skill.ps1 reflect
.EXAMPLE
  scripts\install-skill.ps1 -Agent codex,claude reflect
.EXAMPLE
  scripts\install-skill.ps1 -Agent all reflect
#>
[CmdletBinding()]
param(
  # Position 0 belongs to the skill names, so `install-skill.ps1 reflect` reads
  # as a skill. Without an explicit position here PowerShell hands the first
  # bare argument to whichever parameter is declared first instead.
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Skill,
  [string[]]$Agent,
  [switch]$List,
  [switch]$Force,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$skillsDir = Join-Path $repo 'skills'

# --- agent table ------------------------------------------------------------
# Kept deliberately parallel to the case statements in install-skill.sh: if an
# agent's convention moves, both tables change together.
#
#   Root   presence means the agent is installed (used for autodetect)
#   Target where the skill has to appear for that agent to see it
#   Kind   Dir  = the agent reads a skill directory (Claude Code)
#          File = the agent reads a single markdown file
#   Scope  User = per profile;  Project = relative to the current directory
function Get-ConfigHome {
  if ($env:XDG_CONFIG_HOME) { return $env:XDG_CONFIG_HOME }
  return (Join-Path $env:USERPROFILE '.config')
}

function Get-AgentSpec {
  param([string]$Name, [string]$SkillName)

  $home_ = $env:USERPROFILE
  $cwd = (Get-Location).Path

  switch ($Name) {
    'claude' { @{
        Root   = Join-Path $home_ '.claude'
        Target = Join-Path $home_ (Join-Path '.claude\skills' $SkillName)
        Kind   = 'Dir'; Scope = 'User'
      } }
    'codex' { @{
        Root   = Join-Path $home_ '.codex'
        Target = Join-Path $home_ (Join-Path '.codex\prompts' "$SkillName.md")
        Kind   = 'File'; Scope = 'User'
      } }
    'opencode' { @{
        Root   = Join-Path (Get-ConfigHome) 'opencode'
        Target = Join-Path (Get-ConfigHome) (Join-Path 'opencode\command' "$SkillName.md")
        Kind   = 'File'; Scope = 'User'
      } }
    'cursor' { @{
        Root   = Join-Path $cwd '.cursor'
        Target = Join-Path $cwd (Join-Path '.cursor\rules' "$SkillName.mdc")
        Kind   = 'File'; Scope = 'Project'
      } }
    'cline' { @{
        Root   = Join-Path $cwd '.clinerules'
        Target = Join-Path $cwd (Join-Path '.clinerules' "$SkillName.md")
        Kind   = 'File'; Scope = 'Project'
      } }
    default { $null }
  }
}

$knownAgents = @('claude', 'codex', 'opencode', 'cursor', 'cline')

function Get-SourcePath {
  param([string]$AgentName, [string]$SkillName)
  $spec = Get-AgentSpec -Name $AgentName -SkillName $SkillName
  if ($spec.Kind -eq 'Dir') { return (Join-Path $skillsDir $SkillName) }
  return (Join-Path $skillsDir (Join-Path $SkillName 'SKILL.md'))
}

function Get-AvailableSkills {
  if (-not (Test-Path $skillsDir)) { return @() }
  Get-ChildItem -Directory $skillsDir |
    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
    Select-Object -ExpandProperty Name
}

function Get-LinkTarget {
  param([string]$Path)
  try {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.LinkType) { return $item.LinkTarget }
  } catch { }
  return $null
}

# --- listing ----------------------------------------------------------------

if ($List) {
  Write-Host "skills in ${skillsDir}:"
  foreach ($s in Get-AvailableSkills) { Write-Host "  $s" }
  Write-Host ""
  Write-Host "agents:"
  foreach ($a in $knownAgents) {
    $spec = Get-AgentSpec -Name $a -SkillName 'x'
    $state = if (Test-Path $spec.Root) { 'detected' } else { 'not found' }
    Write-Host ("  {0,-9} {1,-10} {2} ({3})" -f $a, $state, $spec.Root, $spec.Scope.ToLower())
    foreach ($s in Get-AvailableSkills) {
      $t = (Get-AgentSpec -Name $a -SkillName $s).Target
      if ((Get-LinkTarget $t) -eq (Get-SourcePath $a $s)) {
        Write-Host "              installed: $s"
      }
    }
  }
  exit 0
}

# --- resolve agents ---------------------------------------------------------

$targetAgents = @()
if ($Agent -and $Agent.Count -gt 0) {
  # -Agent claude,codex and -Agent "claude,codex" both work
  $requested = $Agent -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  if ($requested -contains 'all') {
    $targetAgents = $knownAgents
  } else {
    foreach ($a in $requested) {
      if ($knownAgents -notcontains $a) {
        Write-Error "unknown agent: $a`nknown agents: $($knownAgents -join ' ')"
        exit 2
      }
      $targetAgents += $a
    }
  }
} else {
  $targetAgents = $knownAgents | Where-Object {
    Test-Path (Get-AgentSpec -Name $_ -SkillName 'x').Root
  }
}

# --- validate ---------------------------------------------------------------

if (-not $Skill -or $Skill.Count -eq 0) {
  Write-Error "no skill named. Try -List to see what is available."
  exit 2
}

foreach ($s in $Skill) {
  # Reject anything that could escape skills/ before it reaches the filesystem.
  if ($s -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Write-Error "not a valid skill name: $s"
    exit 2
  }
  if (-not (Test-Path (Join-Path $skillsDir (Join-Path $s 'SKILL.md')))) {
    Write-Error "no such skill: $s`navailable: $((Get-AvailableSkills) -join ' ')"
    exit 2
  }
}

if ($targetAgents.Count -eq 0) {
  Write-Error ("no supported agent found on this machine`n" +
    "looked for: $($knownAgents -join ' ')`n" +
    "name one explicitly with -Agent <name>, or -Agent all")
  exit 1
}

# --- linking ----------------------------------------------------------------

$failures = 0

function Install-Link {
  param([string]$Source, [string]$Target, [string]$Kind, [string]$Label)

  $existingLink = Get-LinkTarget $Target
  if ($existingLink) {
    if ($existingLink -eq $Source) {
      Write-Host "  = $Label (already linked)"
      return $true
    }
    # A link is ours to repoint; only real files are somebody's work.
    if (-not $DryRun) { Remove-Item -LiteralPath $Target -Force -Recurse -Confirm:$false }
  } elseif (Test-Path -LiteralPath $Target) {
    if (-not $Force) {
      Write-Host "error: ${Label}: $Target already exists and is not a link" -ForegroundColor Red
      Write-Host "  inspect it, then pass -Force to replace it" -ForegroundColor Red
      $script:failures++
      return $false
    }
    if (-not $DryRun) { Remove-Item -LiteralPath $Target -Force -Recurse -Confirm:$false }
  }

  if ($DryRun) {
    Write-Host "  + $Target -> $Source (dry run)"
    return $true
  }

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null

  # Symlinks need Developer Mode or elevation. Junctions need neither and work
  # across volumes, so they are the fallback wherever a directory will do.
  try {
    New-Item -ItemType SymbolicLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
    Write-Host "  + $Label"
    return $true
  } catch {
    if ($Kind -eq 'Dir') {
      try {
        New-Item -ItemType Junction -Path $Target -Target $Source -ErrorAction Stop | Out-Null
        Write-Host "  + $Label (junction)"
        return $true
      } catch { }
    }
    Write-Host "error: ${Label}: could not link $Target" -ForegroundColor Red
    Write-Host "  enable Developer Mode (Settings > System > For developers)," -ForegroundColor Red
    Write-Host "  or run this shell as Administrator" -ForegroundColor Red
    $script:failures++
    return $false
  }
}

foreach ($s in $Skill) {
  Write-Host $s
  foreach ($a in $targetAgents) {
    $spec = Get-AgentSpec -Name $a -SkillName $s
    Install-Link -Source (Get-SourcePath $a $s) -Target $spec.Target `
                 -Kind $spec.Kind -Label "${a}: $($spec.Target)" | Out-Null
  }
}

Write-Host ""
if ($failures -gt 0) {
  Write-Error "$failures target(s) failed"
  exit 1
}
if ($DryRun) {
  Write-Host "dry run - nothing changed."
} else {
  Write-Host "Done. Restart your agent to pick up new skills."
}
