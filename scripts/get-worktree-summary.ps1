<#
.SYNOPSIS
  Summarizes active Git work across one repository or a directory of repositories.

.DESCRIPTION
  Read-only. Discovers repositories, groups linked worktrees by Git common
  directory, takes two status snapshots, and reports worktrees, branch
  divergence, patch identity, stashes, deferred-work ledger entries, and
  optionally open pull requests.

  The report is evidence for a human decision. It never declares work safe to
  delete and never fetches, prunes, switches, stashes, or edits repository data.

.EXAMPLE
  ./scripts/get-worktree-summary.ps1 -Root D:\code

.EXAMPLE
  ./scripts/get-worktree-summary.ps1 -Root . -IncludePullRequests -Format Json

.EXAMPLE
  ./scripts/get-worktree-summary.ps1 -Root . -FailOnBlockers
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Root = (Get-Location).Path,

    [ValidateSet('Summary', 'Json')]
    [string]$Format = 'Summary',

    [ValidateRange(0, 30)]
    [int]$DoubleCheckDelaySeconds = 1,

    [ValidateRange(1, 12)]
    [int]$MaxDepth = 6,

    [ValidateRange(1, 100)]
    [int]$MaxBranchDetails = 20,

    [switch]$IncludePullRequests,
    [switch]$FailOnBlockers
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory)] [string]$WorkingDirectory,
        [Parameter(Mandatory)] [string[]]$Arguments
    )

    $output = @(& git -C $WorkingDirectory @Arguments 2>&1)
    $code = $LASTEXITCODE
    [pscustomobject]@{
        ExitCode = $code
        Output = @($output | ForEach-Object { $_.ToString() })
    }
}

function Invoke-Gh {
    param([Parameter(Mandatory)] [string[]]$Arguments)

    $output = @(& gh @Arguments 2>&1)
    $code = $LASTEXITCODE
    [pscustomobject]@{
        ExitCode = $code
        Output = @($output | ForEach-Object { $_.ToString() })
    }
}

function Get-NormalizedPath {
    param([Parameter(Mandatory)] [string]$Path)
    [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar)
}

function Get-RepositorySeeds {
    param(
        [Parameter(Mandatory)] [string]$SearchRoot,
        [Parameter(Mandatory)] [int]$DepthLimit
    )

    $rootProbe = Invoke-Git $SearchRoot @('rev-parse', '--show-toplevel')
    if ($rootProbe.ExitCode -eq 0) {
        return ,(Get-NormalizedPath $rootProbe.Output[0])
    }

    $excluded = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @(
        '.git', '.vs', '.venv', 'node_modules', 'bin', 'obj', 'packages',
        'artifacts', '.codex-artifacts')) {
        [void]$excluded.Add($name)
    }

    $queue = [System.Collections.Generic.Queue[object]]::new()
    $queue.Enqueue([pscustomobject]@{ Path = $SearchRoot; Depth = 0 })
    $seeds = [System.Collections.Generic.List[string]]::new()

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        $gitEntry = Join-Path $item.Path '.git'
        if (Test-Path -LiteralPath $gitEntry) {
            $seeds.Add((Get-NormalizedPath $item.Path))
            continue
        }

        if ($item.Depth -ge $DepthLimit) {
            continue
        }

        foreach ($child in @(Get-ChildItem -LiteralPath $item.Path -Directory -Force -ErrorAction SilentlyContinue)) {
            if (-not $excluded.Contains($child.Name)) {
                $queue.Enqueue([pscustomobject]@{
                    Path = $child.FullName
                    Depth = $item.Depth + 1
                })
            }
        }
    }

    return @($seeds)
}

function Get-WorktreeRegistrations {
    param([Parameter(Mandatory)] [string]$Repository)

    $result = Invoke-Git $Repository @('worktree', 'list', '--porcelain')
    if ($result.ExitCode -ne 0) {
        return @()
    }

    $records = [System.Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in @($result.Output) + '') {
        if ($line.StartsWith('worktree ')) {
            if ($null -ne $current) {
                $records.Add([pscustomobject]$current)
            }
            $current = [ordered]@{
                Path = $line.Substring(9)
                RegisteredHead = ''
                RegisteredBranch = ''
                Detached = $false
                Locked = $false
                Prunable = $false
            }
            continue
        }
        if ($null -eq $current) { continue }

        if ($line.StartsWith('HEAD ')) { $current.RegisteredHead = $line.Substring(5) }
        elseif ($line.StartsWith('branch refs/heads/')) { $current.RegisteredBranch = $line.Substring(18) }
        elseif ($line -eq 'detached') { $current.Detached = $true }
        elseif ($line.StartsWith('locked')) { $current.Locked = $true }
        elseif ($line.StartsWith('prunable')) { $current.Prunable = $true }
    }
    if ($null -ne $current) {
        $records.Add([pscustomobject]$current)
    }
    return @($records)
}

function Get-DefaultBase {
    param([Parameter(Mandatory)] [string]$Repository)

    $remoteHead = Invoke-Git $Repository @(
        'symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')
    if ($remoteHead.ExitCode -eq 0 -and $remoteHead.Output.Count -gt 0) {
        return $remoteHead.Output[0]
    }

    foreach ($candidate in @('origin/main', 'origin/master', 'main', 'master')) {
        $exists = Invoke-Git $Repository @('rev-parse', '--verify', '--quiet', $candidate)
        if ($exists.ExitCode -eq 0) { return $candidate }
    }
    return ''
}

function Get-Divergence {
    param(
        [Parameter(Mandatory)] [string]$Repository,
        [Parameter(Mandatory)] [string]$Left,
        [Parameter(Mandatory)] [string]$Right
    )

    $result = Invoke-Git $Repository @(
        'rev-list', '--left-right', '--count', "$Left...$Right")
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        return $null
    }
    $parts = $result.Output[0].Trim() -split '\s+'
    if ($parts.Count -ne 2) { return $null }
    [pscustomobject]@{ LeftOnly = [int]$parts[0]; RightOnly = [int]$parts[1] }
}

function Get-WorktreeState {
    param(
        [Parameter(Mandatory)] [object]$Registration,
        [Parameter(Mandatory)] [string]$Base
    )

    $path = $Registration.Path
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{
            Path = $path; Branch = $Registration.RegisteredBranch
            Head = $Registration.RegisteredHead; Upstream = ''
            AheadUpstream = $null; BehindUpstream = $null
            AheadBase = $null; BehindBase = $null; ContainedInBase = $false
            StagedCount = 0; UnstagedCount = 0; UntrackedCount = 0
            Dirty = $false; Accessible = $false; Detached = $Registration.Detached
            Locked = $Registration.Locked; Prunable = $Registration.Prunable
            Signature = "missing|$path"
        }
    }

    $status = Invoke-Git $path @('status', '--porcelain=v1', '-uall', '--branch')
    if ($status.ExitCode -ne 0) {
        return [pscustomobject]@{
            Path = $path; Branch = $Registration.RegisteredBranch
            Head = $Registration.RegisteredHead; Upstream = ''
            AheadUpstream = $null; BehindUpstream = $null
            AheadBase = $null; BehindBase = $null; ContainedInBase = $false
            StagedCount = 0; UnstagedCount = 0; UntrackedCount = 0
            Dirty = $false; Accessible = $false; Detached = $Registration.Detached
            Locked = $Registration.Locked; Prunable = $Registration.Prunable
            Signature = "inaccessible|$path"
        }
    }

    $headResult = Invoke-Git $path @('rev-parse', 'HEAD')
    $head = if ($headResult.ExitCode -eq 0) { $headResult.Output[0] } else { '' }
    $branchResult = Invoke-Git $path @('symbolic-ref', '--quiet', '--short', 'HEAD')
    $branch = if ($branchResult.ExitCode -eq 0) { $branchResult.Output[0] } else { '(detached)' }
    $upstreamResult = Invoke-Git $path @(
        'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
    $upstream = if ($upstreamResult.ExitCode -eq 0) { $upstreamResult.Output[0] } else { '' }

    $aheadUpstream = $null
    $behindUpstream = $null
    if ($upstream) {
        $upstreamDivergence = Get-Divergence $path 'HEAD' $upstream
        if ($null -ne $upstreamDivergence) {
            $aheadUpstream = $upstreamDivergence.LeftOnly
            $behindUpstream = $upstreamDivergence.RightOnly
        }
    }

    $aheadBase = $null
    $behindBase = $null
    $contained = $false
    if ($Base) {
        $baseDivergence = Get-Divergence $path $Base 'HEAD'
        if ($null -ne $baseDivergence) {
            $behindBase = $baseDivergence.LeftOnly
            $aheadBase = $baseDivergence.RightOnly
            $contained = ($aheadBase -eq 0)
        }
    }

    $changes = @($status.Output | Where-Object { -not $_.StartsWith('##') })
    $staged = @($changes | Where-Object {
        $_.Length -ge 2 -and $_[0] -notin @(' ', '?', '!')
    }).Count
    $unstaged = @($changes | Where-Object {
        $_.Length -ge 2 -and $_[1] -notin @(' ', '?', '!')
    }).Count
    $untracked = @($changes | Where-Object { $_.StartsWith('??') }).Count

    [pscustomobject]@{
        Path = $path
        Branch = $branch
        Head = $head
        Upstream = $upstream
        AheadUpstream = $aheadUpstream
        BehindUpstream = $behindUpstream
        AheadBase = $aheadBase
        BehindBase = $behindBase
        ContainedInBase = $contained
        StagedCount = $staged
        UnstagedCount = $unstaged
        UntrackedCount = $untracked
        Dirty = ($changes.Count -gt 0)
        Accessible = $true
        Detached = ($branch -eq '(detached)')
        Locked = $Registration.Locked
        Prunable = $Registration.Prunable
        Signature = (@($head, $branch, $upstream) + $status.Output -join "`n")
    }
}

function Get-BranchAudit {
    param(
        [Parameter(Mandatory)] [string]$Repository,
        [Parameter(Mandatory)] [string]$Base,
        [Parameter(Mandatory)] [object[]]$Worktrees
    )

    $worktreeByBranch = @{}
    foreach ($worktree in $Worktrees) {
        if ($worktree.Branch -and $worktree.Branch -ne '(detached)') {
            $worktreeByBranch[$worktree.Branch] = $worktree
        }
    }

    $refs = Invoke-Git $Repository @(
        'for-each-ref', 'refs/heads', '--sort=-committerdate',
        '--format=%(refname:short)%09%(objectname)%09%(upstream:short)%09%(upstream:track)%09%(committerdate:iso8601-strict)')
    if ($refs.ExitCode -ne 0) { return @() }

    $baseShort = $Base -replace '^origin/', ''
    $branches = [System.Collections.Generic.List[object]]::new()
    foreach ($line in $refs.Output) {
        $parts = $line -split "`t", 5
        if ($parts.Count -lt 5) { continue }
        $name = $parts[0]
        $aheadBase = $null
        $behindBase = $null
        $uniquePatches = $null
        $equivalentPatches = $null

        if ($Base) {
            $divergence = Get-Divergence $Repository $Base $name
            if ($null -ne $divergence) {
                $behindBase = $divergence.LeftOnly
                $aheadBase = $divergence.RightOnly
            }
            if ($aheadBase -gt 0) {
                $cherry = Invoke-Git $Repository @('cherry', $Base, $name)
                if ($cherry.ExitCode -eq 0) {
                    $uniquePatches = @($cherry.Output | Where-Object { $_.StartsWith('+') }).Count
                    $equivalentPatches = @($cherry.Output | Where-Object { $_.StartsWith('-') }).Count
                }
            }
        }

        $isBase = ($name -eq $baseShort)
        $hasWorktree = $worktreeByBranch.ContainsKey($name)
        $localOnly = (-not $isBase -and -not $parts[2])
        $gone = $parts[3] -match '\[gone\]'
        $needsAttention = (
            ($null -ne $aheadBase -and $aheadBase -gt 0) -or
            $localOnly -or $gone -or
            ($hasWorktree -and $worktreeByBranch[$name].Dirty))

        $branches.Add([pscustomobject]@{
            Name = $name
            Head = $parts[1]
            Upstream = $parts[2]
            UpstreamTrack = $parts[3]
            CommitDate = $parts[4]
            BehindBase = $behindBase
            AheadBase = $aheadBase
            UniquePatchCount = $uniquePatches
            EquivalentPatchCount = $equivalentPatches
            IsBase = $isBase
            HasWorktree = $hasWorktree
            LocalOnly = $localOnly
            UpstreamGone = $gone
            NeedsAttention = $needsAttention
        })
    }
    return @($branches)
}

function Get-RepositorySlug {
    param([string]$RemoteUrl)
    if (-not $RemoteUrl) { return '' }
    if ($RemoteUrl -match '^https?://[^/]+/([^/]+/[^/]+?)(?:\.git)?$') {
        return $Matches[1]
    }
    if ($RemoteUrl -match '^[^@]+@[^:]+:([^/]+/[^/]+?)(?:\.git)?$') {
        return $Matches[1]
    }
    return ''
}

function Get-PullRequests {
    param([string]$RemoteUrl)
    if (-not $IncludePullRequests) {
        return [pscustomobject]@{ Status = 'NotRequested'; Items = @(); Error = '' }
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{ Status = 'Unavailable'; Items = @(); Error = 'gh was not found' }
    }
    $slug = Get-RepositorySlug $RemoteUrl
    if (-not $slug) {
        return [pscustomobject]@{ Status = 'Unavailable'; Items = @(); Error = 'remote is not a supported repository URL' }
    }

    $result = Invoke-Gh @(
        'pr', 'list', '--repo', $slug, '--state', 'open', '--limit', '100',
        '--json', 'number,title,headRefName,baseRefName,isDraft,updatedAt,url')
    if ($result.ExitCode -ne 0) {
        return [pscustomobject]@{
            Status = 'Failed'; Items = @(); Error = ($result.Output -join "`n")
        }
    }
    try {
        $items = @(($result.Output -join "`n") | ConvertFrom-Json)
        return [pscustomobject]@{ Status = 'Current'; Items = $items; Error = '' }
    }
    catch {
        return [pscustomobject]@{
            Status = 'Failed'; Items = @(); Error = $_.Exception.Message
        }
    }
}

function Get-RepositoryAudit {
    param(
        [Parameter(Mandatory)] [string]$Repository,
        [Parameter(Mandatory)] [string]$CommonDirectory
    )

    $base = Get-DefaultBase $Repository
    $remoteResult = Invoke-Git $Repository @('remote', 'get-url', 'origin')
    $remote = if ($remoteResult.ExitCode -eq 0) { $remoteResult.Output[0] } else { '' }
    $registrations = @(Get-WorktreeRegistrations $Repository)
    $first = @($registrations | ForEach-Object { Get-WorktreeState $_ $base })

    if ($DoubleCheckDelaySeconds -gt 0) {
        Start-Sleep -Seconds $DoubleCheckDelaySeconds
    }

    $secondRegistrations = @(Get-WorktreeRegistrations $Repository)
    $second = @($secondRegistrations | ForEach-Object { Get-WorktreeState $_ $base })
    $firstByPath = @{}
    foreach ($item in $first) { $firstByPath[$item.Path] = $item }
    foreach ($item in $second) {
        $changed = (
            -not $firstByPath.ContainsKey($item.Path) -or
            $firstByPath[$item.Path].Signature -ne $item.Signature)
        Add-Member -InputObject $item -NotePropertyName ChangedDuringAudit -NotePropertyValue $changed
    }
    if ($first.Count -ne $second.Count) {
        foreach ($item in $second) {
            $item.ChangedDuringAudit = $true
        }
    }

    $branches = @(Get-BranchAudit $Repository $base $second)
    $stashResult = Invoke-Git $Repository @('stash', 'list', '--format=%gd|%h|%ci|%gs')
    $stashes = if ($stashResult.ExitCode -eq 0) { @($stashResult.Output) } else { @() }

    $ledgerPath = Join-Path $CommonDirectory 'agent-work/deferred-work.md'
    $openDeferrals = 0
    $ledgerReadable = $true
    if (Test-Path -LiteralPath $ledgerPath) {
        try {
            $ledgerContent = Get-Content -LiteralPath $ledgerPath -Raw
            $openDeferrals = ([regex]::Matches(
                $ledgerContent,
                '(?im)^\s*(?:-\s*)?status\s*:\s*OPEN\s*$')).Count
        }
        catch {
            $ledgerReadable = $false
        }
    }

    $pullRequests = Get-PullRequests $remote
    $blockers = [System.Collections.Generic.List[string]]::new()
    foreach ($worktree in $second) {
        if (-not $worktree.Accessible) { $blockers.Add("inaccessible worktree: $($worktree.Path)") }
        if ($worktree.Locked) { $blockers.Add("locked worktree: $($worktree.Path)") }
        if ($worktree.Prunable) { $blockers.Add("prunable registration requires review: $($worktree.Path)") }
        if ($worktree.Dirty) { $blockers.Add("dirty worktree: $($worktree.Path)") }
        if ($worktree.ChangedDuringAudit) { $blockers.Add("state changed during audit: $($worktree.Path)") }
        if ($worktree.Detached -and -not $worktree.ContainedInBase) {
            $blockers.Add("detached work not contained in base: $($worktree.Path)")
        }
    }
    foreach ($branch in $branches | Where-Object { $_.NeedsAttention }) {
        $blockers.Add("branch requires review: $($branch.Name)")
    }
    if ($stashes.Count -gt 0) { $blockers.Add("$($stashes.Count) stash entry or entries") }
    if (-not $ledgerReadable) { $blockers.Add("deferred-work ledger is unreadable: $ledgerPath") }
    if ($openDeferrals -gt 0) { $blockers.Add("$openDeferrals open deferred-work item or items") }
    if ($pullRequests.Status -eq 'Current' -and $pullRequests.Items.Count -gt 0) {
        $blockers.Add("$($pullRequests.Items.Count) open pull request or requests")
    }

    [pscustomobject]@{
        Name = Split-Path -Leaf $Repository
        Repository = $Repository
        CommonDirectory = $CommonDirectory
        Remote = $remote
        Base = $base
        Worktrees = [object[]]$second
        Branches = [object[]]$branches
        Stashes = [object[]]$stashes
        DeferredWork = [pscustomobject]@{
            Path = $ledgerPath
            Exists = (Test-Path -LiteralPath $ledgerPath)
            Readable = $ledgerReadable
            OpenCount = $openDeferrals
        }
        PullRequests = $pullRequests
        Blockers = [string[]]$blockers
        Blocked = ($blockers.Count -gt 0)
    }
}

function Write-Summary {
    param([Parameter(Mandatory)] [object]$Report)

    Write-Output 'Git worktree and branch summary'
    Write-Output "Generated: $($Report.GeneratedAt)"
    Write-Output "Root: $($Report.Root)"
    Write-Output (
        "Repositories: {0}  Worktrees: {1} ({2} dirty, {3} changing)  Branches: {4} ({5} needing review)" -f
        $Report.Summary.RepositoryCount,
        $Report.Summary.WorktreeCount,
        $Report.Summary.DirtyWorktreeCount,
        $Report.Summary.ChangingWorktreeCount,
        $Report.Summary.BranchCount,
        $Report.Summary.BranchAttentionCount)
    Write-Output (
        "Stashes: {0}  Open deferrals: {1}  Open pull requests: {2}" -f
        $Report.Summary.StashCount,
        $Report.Summary.OpenDeferralCount,
        $(if ($IncludePullRequests) { $Report.Summary.OpenPullRequestCount } else { 'not checked' }))
    Write-Output "Gate: $(if ($Report.Summary.Blocked) { 'BLOCKED' } else { 'CLEAR' })"

    foreach ($repo in $Report.Repositories) {
        Write-Output ''
        Write-Output "[$(if ($repo.Blocked) { 'BLOCKED' } else { 'CLEAR' })] $($repo.Name)"
        Write-Output "  repo: $($repo.Repository)"
        Write-Output "  common: $($repo.CommonDirectory)"
        Write-Output "  base: $(if ($repo.Base) { $repo.Base } else { '(unknown)' })"
        foreach ($worktree in $repo.Worktrees) {
            $state = if (-not $worktree.Accessible) { 'INACCESSIBLE' }
                elseif ($worktree.ChangedDuringAudit) { 'CHANGED' }
                elseif ($worktree.Dirty) { 'DIRTY' }
                else { 'clean' }
            $shortHead = if ($worktree.Head.Length -ge 10) {
                $worktree.Head.Substring(0, 10)
            } else { $worktree.Head }
            Write-Output (
                "  - {0,-12} {1}@{2} S:{3} M:{4} ?:{5} {6}" -f
                $state, $worktree.Branch, $shortHead,
                $worktree.StagedCount, $worktree.UnstagedCount,
                $worktree.UntrackedCount, $worktree.Path)
        }

        $attention = @($repo.Branches | Where-Object { $_.NeedsAttention } |
            Select-Object -First $MaxBranchDetails)
        if ($attention.Count -gt 0) {
            Write-Output '  branches needing review:'
            foreach ($branch in $attention) {
                Write-Output (
                    "    - {0}: base behind {1}, ahead {2}; upstream {3}; unique patches {4}" -f
                    $branch.Name,
                    $(if ($null -eq $branch.BehindBase) { '?' } else { $branch.BehindBase }),
                    $(if ($null -eq $branch.AheadBase) { '?' } else { $branch.AheadBase }),
                    $(if ($branch.Upstream) { $branch.Upstream } else { '(none)' }),
                    $(if ($null -eq $branch.UniquePatchCount) { '?' } else { $branch.UniquePatchCount }))
            }
            $remaining = @($repo.Branches | Where-Object { $_.NeedsAttention }).Count - $attention.Count
            if ($remaining -gt 0) {
                Write-Output "    ... $remaining more"
            }
        }
        foreach ($pr in $repo.PullRequests.Items) {
            Write-Output "  PR #$($pr.number): $($pr.title) [$($pr.headRefName) -> $($pr.baseRefName)]"
        }
        foreach ($blocker in $repo.Blockers) {
            Write-Output "  ! $blocker"
        }
        if ($repo.PullRequests.Status -eq 'Failed') {
            Write-Output "  warning: pull-request query failed: $($repo.PullRequests.Error)"
        }
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git was not found on PATH'
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Root directory does not exist: $Root"
}

$resolvedRoot = Get-NormalizedPath (Resolve-Path -LiteralPath $Root).Path
$seeds = @(Get-RepositorySeeds $resolvedRoot $MaxDepth)
$repoByCommon = @{}
foreach ($seed in $seeds) {
    $commonResult = Invoke-Git $seed @('rev-parse', '--path-format=absolute', '--git-common-dir')
    if ($commonResult.ExitCode -ne 0) { continue }
    $common = Get-NormalizedPath $commonResult.Output[0]
    $key = if ($IsWindows) { $common.ToUpperInvariant() } else { $common }
    if (-not $repoByCommon.ContainsKey($key)) {
        $topResult = Invoke-Git $seed @('rev-parse', '--show-toplevel')
        $repoByCommon[$key] = Get-NormalizedPath $topResult.Output[0]
    }
}

$repositories = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $repoByCommon.GetEnumerator() | Sort-Object Value) {
    $repositories.Add((Get-RepositoryAudit $entry.Value (Get-NormalizedPath $entry.Key)))
}

$allWorktrees = @($repositories | ForEach-Object { $_.Worktrees })
$allBranches = @($repositories | ForEach-Object { $_.Branches })
$openDeferralTotal = 0
foreach ($repositoryAudit in $repositories) {
    $openDeferralTotal += $repositoryAudit.DeferredWork.OpenCount
}

$summary = [pscustomobject]@{
    RepositoryCount = $repositories.Count
    WorktreeCount = $allWorktrees.Count
    DirtyWorktreeCount = @($allWorktrees | Where-Object { $_.Dirty }).Count
    ChangingWorktreeCount = @($allWorktrees | Where-Object { $_.ChangedDuringAudit }).Count
    BranchCount = $allBranches.Count
    BranchAttentionCount = @($allBranches | Where-Object { $_.NeedsAttention }).Count
    StashCount = @($repositories | ForEach-Object { $_.Stashes }).Count
    OpenDeferralCount = $openDeferralTotal
    OpenPullRequestCount = @($repositories | ForEach-Object { $_.PullRequests.Items }).Count
    Blocked = @($repositories | Where-Object { $_.Blocked }).Count -gt 0
}

$report = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Root = $resolvedRoot
    Summary = $summary
    Repositories = [object[]]$repositories
}

if ($Format -eq 'Json') {
    $report | ConvertTo-Json -Depth 8
}
else {
    Write-Summary $report
}

if ($FailOnBlockers -and $summary.Blocked) {
    exit 2
}
exit 0
