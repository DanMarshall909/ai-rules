<#
.SYNOPSIS
  Behaviour tests for get-worktree-summary.ps1.

.DESCRIPTION
  Builds real temporary Git repositories and checks the audit report's
  observable classifications. These tests cover the helper, not whether an AI
  understands or follows the policy the helper supports.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'get-worktree-summary.ps1'
$sandboxes = [System.Collections.Generic.List[string]]::new()
$passed = 0
$failed = 0

function Ok([string]$Label) {
    $script:passed++
    Write-Host "  ok   $Label"
}

function No([string]$Label, [string]$Detail) {
    $script:failed++
    Write-Host "  FAIL $Label" -ForegroundColor Red
    if ($Detail) {
        Write-Host "       $Detail" -ForegroundColor Red
    }
}

function Assert-True([string]$Label, [bool]$Condition, [string]$Detail = '') {
    if ($Condition) { Ok $Label } else { No $Label $Detail }
}

function Invoke-Git([string]$Repository, [string[]]$Arguments) {
    & git -C $Repository @Arguments 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $Repository"
    }
}

function New-TestRepository([string]$Name) {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) (
        "worktree-summary-$Name-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $root | Out-Null
    $script:sandboxes.Add($root)

    Invoke-Git $root @('init', '-b', 'main')
    Invoke-Git $root @('config', 'user.name', 'Audit Test')
    Invoke-Git $root @('config', 'user.email', 'audit@example.invalid')
    Set-Content -LiteralPath (Join-Path $root 'tracked.txt') -Value 'base'
    Invoke-Git $root @('add', 'tracked.txt')
    Invoke-Git $root @('commit', '-m', 'base')
    return $root
}

function Read-Report([string]$Root) {
    $json = & pwsh -NoProfile -File $scriptPath -Root $Root -Format Json -DoubleCheckDelaySeconds 0
    if ($LASTEXITCODE -ne 0) {
        throw "summary failed: $($json | Out-String)"
    }
    return (($json | Out-String) | ConvertFrom-Json)
}

Write-Host 'get-worktree-summary.ps1'

try {
    $clean = New-TestRepository 'clean'
    $report = Read-Report $clean
    Assert-True 'finds one repository' ($report.Summary.RepositoryCount -eq 1)
    Assert-True 'finds the primary worktree' ($report.Summary.WorktreeCount -eq 1)
    Assert-True 'does not invent empty stash entries' ($report.Summary.StashCount -eq 0)
    Assert-True 'reports a clean repository as clear' (-not $report.Summary.Blocked)

    $active = New-TestRepository 'active'
    $linked = "$active-linked"
    $script:sandboxes.Add($linked)
    Invoke-Git $active @('worktree', 'add', '-b', 'feature/active', $linked)
    Set-Content -LiteralPath (Join-Path $linked 'tracked.txt') -Value 'changed'
    Set-Content -LiteralPath (Join-Path $linked 'untracked.txt') -Value 'new'

    $common = (& git -C $active rev-parse --path-format=absolute --git-common-dir).Trim()
    $ledger = Join-Path $common 'agent-work/deferred-work.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $ledger) -Force | Out-Null
    @'
# Deferred work

## fixture-active

- Status: OPEN
- Next action: preserve the feature
'@ | Set-Content -LiteralPath $ledger

    $report = Read-Report $active
    Assert-True 'finds linked worktrees' ($report.Summary.WorktreeCount -eq 2)
    Assert-True 'counts dirty worktrees' ($report.Summary.DirtyWorktreeCount -eq 1)
    Assert-True 'counts staged, unstaged, and untracked state' (
        $report.Repositories[0].Worktrees[1].UnstagedCount -eq 1 -and
        $report.Repositories[0].Worktrees[1].UntrackedCount -eq 1)
    Assert-True 'reads the shared deferred-work ledger' (
        $report.Summary.OpenDeferralCount -eq 1)
    Assert-True 'blocks when active work exists' ($report.Summary.Blocked)

    & pwsh -NoProfile -File $scriptPath -Root $active -Format Json -DoubleCheckDelaySeconds 0 -FailOnBlockers *> $null
    Assert-True 'can fail closed for automation' ($LASTEXITCODE -eq 2) "expected exit 2, got $LASTEXITCODE"
}
catch {
    No 'test run completes' $_.Exception.Message
}
finally {
    foreach ($path in $sandboxes) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ''
Write-Host "$passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
exit 0
