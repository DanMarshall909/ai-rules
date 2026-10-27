$ErrorActionPreference = 'Stop'

$reportScript = Join-Path $PSScriptRoot 'report-worktree-cleanup.ps1'
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("worktree-cleanup-report-" + [guid]::NewGuid().ToString('N'))
$root = Join-Path $sandbox 'scan'
$repoRoot = Join-Path $root 'repo'
$origin = Join-Path $sandbox 'origin.git'
$merged = Join-Path $root 'worktrees\merged'
$dirty = Join-Path $root 'worktrees\dirty'
$unmerged = Join-Path $root 'worktrees\unmerged'
$archived = Join-Path $root 'worktrees\archived'
$locked = Join-Path $root 'worktrees\locked'
$detached = Join-Path $root 'worktrees\detached'

function Invoke-Git([string]$WorkingDirectory, [string[]]$Arguments) {
    $output = & git -C $WorkingDirectory @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $WorkingDirectory`: $($output -join "`n")"
    }
    return $output
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
    Invoke-Git $sandbox @('init', '--bare', $origin) | Out-Null
    Invoke-Git $repoRoot @('init', '--initial-branch=main') | Out-Null
    Invoke-Git $repoRoot @('config', 'user.name', 'Cleanup Report Test') | Out-Null
    Invoke-Git $repoRoot @('config', 'user.email', 'cleanup-report@example.invalid') | Out-Null
    Set-Content -LiteralPath (Join-Path $repoRoot 'tracked.txt') -Value 'base' -NoNewline
    Invoke-Git $repoRoot @('add', 'tracked.txt') | Out-Null
    Invoke-Git $repoRoot @('commit', '-m', 'create test repository') | Out-Null
    Invoke-Git $repoRoot @('remote', 'add', 'origin', $origin) | Out-Null
    Invoke-Git $repoRoot @('push', '-u', 'origin', 'main') | Out-Null
    Invoke-Git $repoRoot @('remote', 'set-head', 'origin', 'main') | Out-Null

    New-Item -ItemType Directory -Path (Split-Path -Parent $merged) -Force | Out-Null
    Invoke-Git $repoRoot @('worktree', 'add', '-b', 'feat/merged', $merged) | Out-Null
    Set-Content -LiteralPath (Join-Path $merged 'merged.txt') -Value 'merged' -NoNewline
    Invoke-Git $merged @('add', 'merged.txt') | Out-Null
    Invoke-Git $merged @('commit', '-m', 'add merged change') | Out-Null
    Invoke-Git $repoRoot @('merge', '--no-ff', 'feat/merged', '-m', 'merge test branch') | Out-Null
    Invoke-Git $repoRoot @('push', 'origin', 'main') | Out-Null
    Invoke-Git $repoRoot @('branch', 'feat/branch-only-merged', 'main') | Out-Null
    Invoke-Git $repoRoot @('branch', 'archived/keep-me', 'main') | Out-Null
    Invoke-Git $repoRoot @('branch', 'archived/branch-only', 'main') | Out-Null
    Invoke-Git $repoRoot @('branch', 'feat/branch-only-candidate', 'main') | Out-Null
    Invoke-Git $repoRoot @('worktree', 'add', $archived, 'archived/keep-me') | Out-Null
    Invoke-Git $repoRoot @('worktree', 'add', '-b', 'feat/locked', $locked, 'main') | Out-Null
    Invoke-Git $repoRoot @('worktree', 'lock', $locked) | Out-Null
    Invoke-Git $repoRoot @('worktree', 'add', '--detach', $detached, 'main') | Out-Null
    $common = (Invoke-Git $repoRoot @('rev-parse', '--path-format=absolute', '--git-common-dir') | Out-String).Trim()
    New-Item -ItemType Directory -Path (Join-Path $common 'codex') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $common 'codex\deferred-work.md') -Value "# Deferred Work`n`n## Item ABC`n- Status: OPEN`n- Branch: feat/branch-only-merged`n"

    Invoke-Git $repoRoot @('worktree', 'add', '-b', 'feat/dirty', $dirty) | Out-Null
    Set-Content -LiteralPath (Join-Path $dirty 'unmerged.txt') -Value 'unmerged' -NoNewline
    Invoke-Git $dirty @('add', 'unmerged.txt') | Out-Null
    Invoke-Git $dirty @('commit', '-m', 'add unmerged change') | Out-Null
    Add-Content -LiteralPath (Join-Path $dirty 'tracked.txt') -Value ' local edit'

    Invoke-Git $repoRoot @('worktree', 'add', '-b', 'feat/unmerged', $unmerged) | Out-Null
    Set-Content -LiteralPath (Join-Path $unmerged 'unique.txt') -Value 'unique' -NoNewline
    Invoke-Git $unmerged @('add', 'unique.txt') | Out-Null
    Invoke-Git $unmerged @('commit', '-m', 'add unique unmerged change') | Out-Null
    Invoke-Git $repoRoot @('worktree', 'remove', $unmerged) | Out-Null

    $report = (& $reportScript -Root $root | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "Report command failed with exit code $LASTEXITCODE" }
    if ($report -notmatch 'Git cleanup candidate') { throw 'Expected clean merged worktree to be reported as a Git cleanup candidate.' }
    if ($report -notmatch 'Git-merged local branches without a worktree') { throw 'Expected a separate report section for local branches without worktrees.' }
    if ($report -notmatch 'feat/branch-only-merged') { throw 'Expected the merged local branch to be reported.' }
    if ($report -notmatch 'staged, unstaged, or untracked changes are present') { throw 'Expected unmerged dirty worktree to be reported for investigation.' }
    if ($report -notmatch 'feat/unmerged') { throw 'Expected a unique local branch to be reported for investigation.' }
    if ($report -notmatch 'tracked.txt') { throw 'Expected changed file names in the investigation report.' }
    if ($report -notmatch 'open deferred-work entry matches this branch') { throw 'Expected deferred local branch to be reported for preservation.' }
    if ($report -notmatch 'Local branches requiring investigation') { throw 'Expected a section for deferred or unique local branches.' }
    $candidateSection = [regex]::Match($report, '(?ms)^## Git cleanup candidates\r?\n(.*?)(?=^## )').Groups[1].Value
    $branchCandidateSection = [regex]::Match($report, '(?ms)^## Git-merged local branches without a worktree\r?\n(.*?)(?=^## )').Groups[1].Value
    $investigationSection = [regex]::Match($report, '(?ms)^## Investigate or preserve\r?\n(.*?)(?=^## )').Groups[1].Value
    $branchInvestigationSection = [regex]::Match($report, '(?ms)^## Local branches requiring investigation\r?\n(.*?)(?=^## )').Groups[1].Value
    $archivedSection = [regex]::Match($report, '(?ms)^## Retained archived work\r?\n(.*?)(?=^## )').Groups[1].Value
    $normalizedCandidateSection = $candidateSection.Replace('/', '\')
    if ($normalizedCandidateSection -notmatch [regex]::Escape($merged) -or $normalizedCandidateSection -match [regex]::Escape($dirty)) { throw 'Expected only the clean merged worktree in the worktree candidate section.' }
    if ($branchCandidateSection -match 'feat/branch-only-merged') { throw 'Deferred branch must not appear among branch cleanup candidates.' }
    if ($branchInvestigationSection -notmatch 'feat/branch-only-merged' -or $branchInvestigationSection -notmatch 'feat/unmerged') { throw 'Expected deferred and unique branches in the branch investigation section.' }
    $normalizedArchivedSection = $archivedSection.Replace('/', '\')
    if ($normalizedArchivedSection -notmatch [regex]::Escape($archived) -or $normalizedCandidateSection -match [regex]::Escape($archived) -or $archivedSection -notmatch 'archived/branch-only') { throw 'Archived work must be retained outside candidate sections.' }
    if ($branchCandidateSection -notmatch 'feat/branch-only-candidate') { throw 'Expected an eligible branch-only candidate.' }
    if ($report -notmatch 'Git cleanup candidates: 2') { throw 'Expected one worktree candidate and one branch-only candidate.' }
    if ($investigationSection -notmatch 'worktree is locked' -or $investigationSection -notmatch 'detached HEAD') { throw 'Locked and detached worktrees must be investigated.' }
    $normalizedReport = $report.Replace('/', '\')
    if ($normalizedReport -notmatch [regex]::Escape($merged)) { throw 'Expected the merged worktree path in the report.' }
    if ($normalizedReport -notmatch [regex]::Escape($dirty)) { throw 'Expected the dirty worktree path in the report.' }
    if (!(Test-Path -LiteralPath $merged) -or !(Test-Path -LiteralPath $dirty) -or !(Test-Path -LiteralPath $archived) -or !(Test-Path -LiteralPath $locked) -or !(Test-Path -LiteralPath $detached)) {
        throw 'The report must not remove any worktree.'
    }

    Write-Output 'PASS: merged and dirty worktrees are reported without removal.'

    # Size observations never change the Git preservation classifications.
    $build = Join-Path $dirty 'bin'
    New-Item -ItemType Directory -Path $build | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $build 'generated.bin'), [byte[]](1,2,3,4,5))
    $storageReport = (& $reportScript -Root $root -Storage -StorageMaxEntries 10000 | Out-String)
    if ($storageReport -notmatch 'Storage observations' -or $storageReport -notmatch 'Logical bytes' -or
        $storageReport -notmatch 'Reclaimable bytes are unknown' -or $storageReport -notmatch 'staged, unstaged, or untracked changes are present') {
        throw 'Storage must add bounded observations without changing preservation evidence.'
    }
    if (!(Test-Path -LiteralPath (Join-Path $build 'generated.bin'))) { throw 'Storage reporting deleted generated data.' }
    $bounded = (& $reportScript -Root $root -DiscoveryMaxDirectories 1 | Out-String)
    if ($bounded -notmatch 'Discovery directory limit reached') { throw 'Bounded discovery must report incomplete inventory.' }
    Write-Output 'PASS: storage observations and bounded discovery preserve existing state.'
    # Wide parents must not enqueue every child before the next dequeue limit.
    $wide = Join-Path $sandbox 'wide'
    New-Item -ItemType Directory -Path $wide | Out-Null
    foreach ($index in 1..40) { New-Item -ItemType Directory -Path (Join-Path $wide ("child-{0:D2}" -f $index)) | Out-Null }
    $wideReport = (& $reportScript -Root $wide -DiscoveryMaxDirectories 3 | Out-String)
    $observed = [regex]::Match($wideReport, 'Discovery: scanned (?<scanned>\d+) directories; enqueued (?<enqueued>\d+); inspected (?<entries>\d+) child entries')
    if (!$observed.Success -or [int]$observed.Groups['scanned'].Value -gt 3 -or
        [int]$observed.Groups['enqueued'].Value -gt 3 -or [int]$observed.Groups['entries'].Value -gt 3 -or
        [int]$observed.Groups['enqueued'].Value -ne 3 -or $wideReport -notmatch 'Discovery directory limit reached') {
        throw 'Wide discovery must bound inspection and queue growth, with observed counts and an incomplete diagnostic.'
    }
    if (@([IO.Directory]::EnumerateDirectories($wide)).Count -ne 40) { throw 'Wide discovery changed its input directories.' }
    Write-Output 'PASS: wide discovery bounds inspected and enqueued directories.'




    # Simulate Git worktree-list failure while allowing every other Git command
    # through to the real executable. Checked-out branch state must stay unknown.
    $realGit = (Get-Command git -ErrorAction Stop).Source
    $gitShim = Join-Path $sandbox 'git-shim'
    New-Item -ItemType Directory -Path $gitShim | Out-Null
    $shimText = "@echo off`r`nif /i `"%~3`"==`"worktree`" if /i `"%~4`"==`"list`" exit /b 128`r`n`"$realGit`" %*`r`nexit /b %errorlevel%`r`n"
    Set-Content -LiteralPath (Join-Path $gitShim 'git.cmd') -Value $shimText -NoNewline
    $oldPath = $env:PATH
    try {
        $env:PATH = "$gitShim;$oldPath"
        $noWorktreeInventory = (& $reportScript -Root $root | Out-String)
    } finally {
        $env:PATH = $oldPath
    }
    $failedInventoryBranches = [regex]::Match($noWorktreeInventory, '(?ms)^## Local branches requiring investigation\r?\n(.*?)(?=^## )').Groups[1].Value
    if ($noWorktreeInventory -notmatch 'Worktree inventory unavailable' -or $noWorktreeInventory -notmatch 'Git cleanup candidates: 0' -or
        $failedInventoryBranches -notmatch 'feat/branch-only-candidate' -or $failedInventoryBranches -notmatch 'worktree inventory is unavailable') {
        throw 'Failed worktree inventory must withhold branch candidates and report checkout state as unknown.'
    }
    Write-Output 'PASS: failed worktree inventory withholds branch candidates.'

    # An unreadable/malformed ledger must fail closed for candidate classification.
    Remove-Item -LiteralPath (Join-Path $common 'codex\deferred-work.md')
    New-Item -ItemType Directory -Path (Join-Path $common 'codex\deferred-work.md') | Out-Null
    $failClosed = (& $reportScript -Root $root | Out-String)
    $failClosedWorktreeCandidates = [regex]::Match($failClosed, '(?ms)^## Git cleanup candidates\r?\n(.*?)(?=^## )').Groups[1].Value
    $failClosedBranchCandidates = [regex]::Match($failClosed, '(?ms)^## Git-merged local branches without a worktree\r?\n(.*?)(?=^## )').Groups[1].Value
    $failClosedInvestigations = [regex]::Match($failClosed, '(?ms)^## Investigate or preserve\r?\n(.*?)(?=^## )').Groups[1].Value.Replace('/', '\')
    $failClosedBranchInvestigations = [regex]::Match($failClosed, '(?ms)^## Local branches requiring investigation\r?\n(.*?)(?=^## )').Groups[1].Value
    if ($failClosed -notmatch 'Deferred-work ledger unavailable' -or $failClosed -notmatch 'Git cleanup candidates: 0' -or
        $failClosedWorktreeCandidates -notmatch '\| \(none\) \|' -or $failClosedBranchCandidates -notmatch '\| \(none\) \|' -or
        $failClosedWorktreeCandidates -match [regex]::Escape($merged) -or $failClosedWorktreeCandidates -match [regex]::Escape($merged.Replace('\', '/')) -or
        $failClosedInvestigations -notmatch [regex]::Escape($merged) -or $failClosedBranchInvestigations -notmatch 'feat/branch-only-candidate') {
        throw 'Unavailable ledger must be diagnosed, withhold all candidates, and preserve affected work in investigation sections.'
    }
    Write-Output 'PASS: unavailable ledger withholds candidates and preserves work in investigation.'

    Remove-Item -LiteralPath (Join-Path $common 'codex\deferred-work.md') -Recurse -Force
    Set-Content -LiteralPath (Join-Path $common 'codex\deferred-work.md') -Value 'unrecognized ledger content'
    $malformedLedger = (& $reportScript -Root $root | Out-String)
    if ($malformedLedger -notmatch 'Deferred-work ledger format is unrecognized' -or $malformedLedger -notmatch 'Git cleanup candidates: 0') {
        throw 'Malformed ledger must be diagnosed and withhold candidates.'
    }
    Write-Output 'PASS: malformed ledger blocks candidate classification.'
}
finally {
    if (Test-Path -LiteralPath $sandbox) {
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
