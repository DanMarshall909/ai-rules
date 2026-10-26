[CmdletBinding()]
param(
    [string[]] $Root = @((Get-Location).Path),
    [string] $OutputPath,
    [switch] $Fetch,
    [switch] $Storage,
    [string[]] $OutputRoot = @(),
    [string] $PythonCommand = 'python',
    [ValidateRange(1, 100000)] [int] $DiscoveryMaxDirectories = 5000,
    [ValidateRange(0, 32)] [int] $DiscoveryMaxDepth = 8,
    [ValidateRange(1, 60)] [int] $DiscoveryMaxSeconds = 15,
    [ValidateRange(0, 256)] [int] $StorageMaxDepth = 64,
    [ValidateRange(1, 1000000)] [int] $StorageMaxEntries = 100000,
    [ValidateRange(1, 60)] [int] $StorageMaxSeconds = 5,
    [string[]] $ExcludeDirectoryName = @('.git', '.svn', '.codex-artifacts', 'node_modules', '.vs', 'bin', 'obj', 'target', 'packages', 'artifacts', 'build', 'dist', 'TestResults', 'coverage', '.venv', 'venv', '.terraform')
)

$ErrorActionPreference = 'Stop'

function Invoke-Git([string] $Path, [string[]] $Arguments) {
    $lines = @(& git -C $Path @Arguments 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($lines -join "`n").TrimEnd()
    }
}

function Get-AbsolutePath([string] $Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Length -gt $root.Length) {
        return $full.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    }
    return $full
}

function Find-GitWorktrees([string[]] $Roots, [System.Collections.Generic.List[string]] $Diagnostics) {
    $found = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
    $visited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $skipNames = $ExcludeDirectoryName
    $queue = [System.Collections.Generic.Queue[object]]::new()
    $scannedCount = 0
    $enqueuedCount = 0
    $inspectedEntryCount = 0
    $clock = [Diagnostics.Stopwatch]::StartNew()

    foreach ($item in $Roots) {
        if ($enqueuedCount -ge $DiscoveryMaxDirectories) { $Diagnostics.Add('Discovery directory limit reached while accepting roots; inventory is incomplete.'); break }
        if ($clock.Elapsed.TotalSeconds -ge $DiscoveryMaxSeconds) { $Diagnostics.Add('Discovery time limit reached while accepting roots; inventory is incomplete.'); break }
        try {
            if (!(Test-Path -LiteralPath $item -PathType Container -ErrorAction Stop)) {
                $Diagnostics.Add("Root unavailable: $item")
                continue
            }
            $absolute = Get-AbsolutePath $item
            $check = $absolute
            while ($check) {
                if (([IO.File]::GetAttributes($check) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Linked scan roots or ancestors are not followed.' }
                $parent = [IO.Directory]::GetParent($check)
                $check = if ($parent) { $parent.FullName } else { $null }
            }
            $queue.Enqueue([pscustomobject]@{ Path = $absolute; Depth = 0 })
            $enqueuedCount++
        } catch {
            $Diagnostics.Add("Root could not be resolved: $item ($($_.Exception.Message))")
        }
    }

    while ($queue.Count -gt 0) {
        if ($scannedCount -ge $DiscoveryMaxDirectories) { $Diagnostics.Add('Discovery directory limit reached; inventory is incomplete.'); break }
        if ($clock.Elapsed.TotalSeconds -ge $DiscoveryMaxSeconds) { $Diagnostics.Add('Discovery time limit reached; inventory is incomplete.'); break }
        $next = $queue.Dequeue()
        $directory = $next.Path
        if (!$visited.Add($directory)) { continue }
        $scannedCount++
        if (($scannedCount % 500) -eq 0) { Write-Verbose "Scanned $scannedCount directories; found $($found.Count) Git worktrees so far." }

        $marker = Join-Path $directory '.git'
        $isBareLayout = (Test-Path -LiteralPath (Join-Path $directory 'HEAD') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $directory 'objects') -PathType Container) -and
            (Test-Path -LiteralPath (Join-Path $directory 'refs') -PathType Container)
        if ((Test-Path -LiteralPath $marker) -or $isBareLayout) {
            $top = Invoke-Git $directory @('rev-parse', '--show-toplevel')
            if ($top.ExitCode -eq 0) {
                $found[(Get-AbsolutePath $top.Text)] = $directory
                continue
            } elseif ($isBareLayout -and (Invoke-Git $directory @('rev-parse', '--is-bare-repository')).Text -eq 'true') {
                $found[(Get-AbsolutePath $directory)] = $directory
                continue
            } else {
                $Diagnostics.Add("Git marker could not be resolved: $directory ($($top.Text))")
            }
        }

        try {
            foreach ($childPath in [IO.Directory]::EnumerateDirectories($directory)) {
                # Bound the producer of the queue, including skipped names;
                # checking only the next dequeue permits unbounded wide scans.
                if ($enqueuedCount -ge $DiscoveryMaxDirectories -or $inspectedEntryCount -ge $DiscoveryMaxDirectories) {
                    $Diagnostics.Add('Discovery directory limit reached during enumeration; inventory is incomplete.')
                    break
                }
                if ($clock.Elapsed.TotalSeconds -ge $DiscoveryMaxSeconds) {
                    $Diagnostics.Add('Discovery time limit reached during enumeration; inventory is incomplete.')
                    break
                }
                $inspectedEntryCount++
                $childName = [IO.Path]::GetFileName($childPath)
                if ($skipNames -contains $childName) { continue }
                try {
                    $attributes = [IO.File]::GetAttributes($childPath)
                    if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                    if ($next.Depth -ge $DiscoveryMaxDepth) { $Diagnostics.Add("Discovery depth limit reached: $directory"); break }
                    $queue.Enqueue([pscustomobject]@{ Path = $childPath; Depth = $next.Depth + 1 })
                    $enqueuedCount++
                } catch {
                    $Diagnostics.Add("Directory could not be inspected: $childPath ($($_.Exception.Message))")
                }
            }
        } catch {
            $Diagnostics.Add("Directory could not be scanned: $directory ($($_.Exception.Message))")
        }
    }

    return [pscustomobject]@{ Worktrees = $found; Scanned = $scannedCount; Enqueued = $enqueuedCount; InspectedEntries = $inspectedEntryCount }
}

function Get-WorktreeRecords([string] $Repository, [System.Collections.Generic.List[string]] $Diagnostics) {
    $result = Invoke-Git $Repository @('worktree', 'list', '--porcelain')
    if ($result.ExitCode -ne 0) {
        $Diagnostics.Add("Worktree inventory unavailable for $Repository ($($result.Text))")
        return [pscustomobject]@{ Available = $false; Records = @() }
    }

    $records = [System.Collections.Generic.List[object]]::new()
    $record = $null
    foreach ($line in ($result.Text -split "`r?`n")) {
        if ($line.StartsWith('worktree ')) {
            if ($null -ne $record) { $records.Add($record) }
            $record = [pscustomobject]@{ Path = $line.Substring(9); Head = ''; Branch = ''; Detached = $false; Locked = $false; Bare = $false }
        } elseif ($null -ne $record -and $line.StartsWith('HEAD ')) {
            $record.Head = $line.Substring(5)
        } elseif ($null -ne $record -and $line.StartsWith('branch refs/heads/')) {
            $record.Branch = $line.Substring('branch refs/heads/'.Length)
        } elseif ($null -ne $record -and $line -eq 'detached') {
            $record.Detached = $true
        } elseif ($null -ne $record -and $line.StartsWith('locked')) {
            $record.Locked = $true
        } elseif ($null -ne $record -and $line -eq 'bare') {
            $record.Bare = $true
        }
    }
    if ($null -ne $record) { $records.Add($record) }
    return [pscustomobject]@{ Available = $true; Records = $records.ToArray() }
}

function Test-Ancestor([string] $Repository, [string] $Commit, [string] $Ref) {
    if ([string]::IsNullOrWhiteSpace($Commit) -or [string]::IsNullOrWhiteSpace($Ref)) { return $false }
    $check = Invoke-Git $Repository @('merge-base', '--is-ancestor', $Commit, $Ref)
    return $check.ExitCode -eq 0
}

function Get-DeferredLedgerState([string] $CommonDirectory, [System.Collections.Generic.List[string]] $Diagnostics) {
    $ledger = Join-Path $CommonDirectory 'codex\deferred-work.md'
    $state = [pscustomobject]@{ Available = $true; Parsed = $true; OpenSections = [System.Collections.Generic.List[string]]::new() }
    try {
        $item = Get-Item -LiteralPath $ledger -ErrorAction Stop
        if ($item.PSIsContainer) { throw "deferred-work path is a directory, not a file: $ledger" }
        $text = Get-Content -LiteralPath $ledger -Raw -ErrorAction Stop
    } catch {
        if ($_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::ObjectNotFound) { return $state }
        $state.Available = $false
        $state.Parsed = $false
        $Diagnostics.Add("Deferred-work ledger unavailable: $ledger ($($_.Exception.Message))")
        return $state
    }

    if ([string]::IsNullOrWhiteSpace($text)) { return $state }
    $sections = [regex]::Matches($text, '(?ms)^##\s+.+?(?=^##\s+|\z)')
    if ($sections.Count -eq 0) {
        if ($text -match '(?im)^\s*(?:[-*]\s*)?status\s*:\s*OPEN\b') {
            $state.OpenSections.Add($text)
        } elseif ($text -match '(?m)^#\s+Deferred Work\s*$' -and $text -notmatch '(?m)^\s*[^\s#].+') {
            return $state
        } else {
            $state.Parsed = $false
            $Diagnostics.Add("Deferred-work ledger format is unrecognized: $ledger")
            return $state
        }
    } else {
        foreach ($match in $sections) {
            $section = $match.Value
            $heading = ([regex]::Match($section, '(?m)^##\s+(.+)$')).Groups[1].Value.Trim()
            $status = [regex]::Match($section, '(?im)^\s*(?:[-*]\s*)?status\s*:\s*(?<value>[A-Za-z_-]+)\s*$')
            $statusValue = if ($status.Success) { $status.Groups['value'].Value.ToUpperInvariant() } elseif ($heading -match '^(OPEN)\b') { 'OPEN' } elseif ($heading -match '^(RESOLVED|CLOSED)\b') { $Matches[1] } else { '' }
            if ($statusValue -eq 'OPEN') {
                $state.OpenSections.Add($section)
            } elseif ($statusValue -notin @('RESOLVED', 'CLOSED')) {
                $state.Parsed = $false
                $Diagnostics.Add("Deferred-work entry has no recognized status: $ledger ($heading)")
            }
        }
    }
    return $state
}

function Test-DeferredItem([object] $LedgerState, [string] $Path, [string] $Branch) {
    if (!$LedgerState.Available -or !$LedgerState.Parsed) { return $true }
    $normalizedPath = if ($Path) { $Path.Replace('\', '/') } else { '' }
    foreach ($section in $LedgerState.OpenSections) {
        $normalizedSection = $section.Replace('\', '/')
        if (($normalizedPath -and $normalizedSection -match [regex]::Escape($normalizedPath)) -or
            ($Branch -and $normalizedSection -match [regex]::Escape($Branch))) { return $true }
    }
    return $false
}

function Escape-Markdown([string] $Value) {
    if ($null -eq $Value) { return '' }
    return $Value.Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is required on PATH.' }

$diagnostics = [System.Collections.Generic.List[string]]::new()
$discovery = Find-GitWorktrees $Root $diagnostics
$discovered = $discovery.Worktrees
$repositories = [System.Collections.Generic.List[object]]::new()
$seenCommon = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($repoPath in $discovered.Keys) {
    $commonResult = Invoke-Git $repoPath @('rev-parse', '--path-format=absolute', '--git-common-dir')
    if ($commonResult.ExitCode -ne 0) {
        $diagnostics.Add("Common Git directory unavailable for $repoPath ($($commonResult.Text))")
        continue
    }
    $common = Get-AbsolutePath $commonResult.Text
    if (!$seenCommon.Add($common)) { continue }

    $fetchSucceeded = $true
    if ($Fetch) {
        $fetch = Invoke-Git $repoPath @('fetch', '--no-prune', 'origin')
        if ($fetch.ExitCode -ne 0) {
            $fetchSucceeded = $false
            $diagnostics.Add("Fetch failed for $repoPath ($($fetch.Text)); local refs may be stale")
        }
    }

    $originHead = Invoke-Git $repoPath @('symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD')
    $trunkRef = if ($originHead.ExitCode -eq 0) { $originHead.Text } else { '' }
    $trunkName = if ($trunkRef) { $trunkRef.Substring('refs/remotes/origin/'.Length) } else { '' }
    $trunkExists = $false
    if ($trunkRef) {
        $trunkExists = (Invoke-Git $repoPath @('show-ref', '--verify', '--quiet', $trunkRef)).ExitCode -eq 0
    }
    $ledgerState = Get-DeferredLedgerState $common $diagnostics
    $worktreeInventory = Get-WorktreeRecords $repoPath $diagnostics
    $resolvedWorktrees = [System.Collections.Generic.List[object]]::new()
    $checkedOutBranches = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($worktree in $worktreeInventory.Records) {
        if ($worktree.Bare) { continue }
        if ($worktree.Branch) { $null = $checkedOutBranches.Add($worktree.Branch) }
        $status = Invoke-Git $worktree.Path @('status', '--porcelain=v1', '--untracked-files=all')
        $isTrunk = $trunkName -and $worktree.Branch -eq $trunkName
        $branchRef = if ($worktree.Branch) { "refs/heads/$($worktree.Branch)" } else { '' }
        $branchTip = if ($branchRef) { Invoke-Git $repoPath @('rev-parse', '--verify', $branchRef) } else { $null }
        $headMerged = $trunkExists -and (Test-Ancestor $repoPath $worktree.Head $trunkRef)
        $tipMerged = $trunkExists -and $branchTip -and $branchTip.ExitCode -eq 0 -and (Test-Ancestor $repoPath $branchTip.Text $trunkRef)
        $dirty = $status.ExitCode -ne 0 -or ![string]::IsNullOrWhiteSpace($status.Text)
        $changeLines = @($status.Text -split "`r?`n" | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
        $changeSummary = if ($changeLines.Count -gt 0) { ($changeLines | ForEach-Object { $_.TrimEnd() }) -join '; ' } else { '(clean)' }
        $divergence = '(unknown)'
        if ($trunkExists -and $worktree.Head) {
            $counts = Invoke-Git $repoPath @('rev-list', '--left-right', '--count', "$trunkRef...$($worktree.Head)")
            if ($counts.ExitCode -eq 0) { $values = $counts.Text -split '\s+'; if ($values.Count -eq 2) { $divergence = "behind $($values[0]), ahead $($values[1])" } }
        }
        $deferred = Test-DeferredItem $ledgerState $worktree.Path $worktree.Branch
        $isArchived = $worktree.Branch -like 'archived/*'

        if ($status.ExitCode -ne 0) {
            $classification = 'Investigate / preserve'
            $reason = "status unavailable: $($status.Text)"
        } elseif ($deferred) {
            $classification = 'Investigate / preserve'
            $reason = 'an open deferred-work entry matches this worktree or branch'
        } elseif ($dirty) {
            $classification = 'Investigate / preserve'
            $reason = 'staged, unstaged, or untracked changes are present'
        } elseif ($worktree.Locked) {
            $classification = 'Investigate / preserve'
            $reason = 'worktree is locked'
        } elseif ($worktree.Detached) {
            $classification = 'Investigate / preserve'
            $reason = 'detached HEAD needs ownership and integration review'
        } elseif ($isTrunk) {
            $classification = 'Retain trunk worktree'
            $reason = 'this worktree is on the detected origin default branch'
        } elseif (!$trunkExists) {
            $classification = 'Investigate / preserve'
            $reason = 'origin default-branch ref is unavailable; integration cannot be established'
        } elseif (!$fetchSucceeded) {
            $classification = 'Investigate / preserve'
            $reason = 'fetch failed; local refs may be stale'
        } elseif ($isArchived) {
            $classification = 'Retain archived worktree'
            $reason = 'archived branches are retained for explicit scoped review'
        } elseif ($headMerged -and $tipMerged) {
            $classification = 'Git cleanup candidate'
            $reason = 'clean and both worktree HEAD and local branch tip are reachable from the local origin default-branch ref'
        } else {
            $classification = 'Investigate / preserve'
            $reason = 'worktree HEAD or branch tip is not reachable from the local origin default-branch ref'
        }

        $resolvedWorktrees.Add([pscustomobject]@{
            Path = $worktree.Path
            Branch = if ($worktree.Branch) { $worktree.Branch } elseif ($worktree.Detached) { '(detached)' } else { '(unknown)' }
            Head = $worktree.Head
            Changes = $changeSummary
            Divergence = $divergence
            Classification = $classification
            Reason = $reason
            IsTrunk = [bool]$isTrunk
        })
    }

    $branchResult = Invoke-Git $repoPath @('for-each-ref', '--format=%(refname:short)%09%(objectname)', 'refs/heads')
    $localBranches = [System.Collections.Generic.List[object]]::new()
    if ($branchResult.ExitCode -ne 0) {
        $diagnostics.Add("Local branch inventory unavailable for $repoPath ($($branchResult.Text))")
    } else {
        foreach ($line in ($branchResult.Text -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split "`t", 2
            if ($parts.Count -ne 2) { $diagnostics.Add("Could not parse local branch record in $repoPath ($line)"); continue }
            $name = $parts[0]
            if ($name -eq $trunkName -or $checkedOutBranches.Contains($name)) { continue }
            $isDeferred = Test-DeferredItem $ledgerState '' $name
            if ($isDeferred) {
                $classification = 'Investigate / preserve'
                $reason = 'an open deferred-work entry matches this branch'
            } elseif (!$worktreeInventory.Available) {
                $classification = 'Investigate / preserve'
                $reason = 'worktree inventory is unavailable; branch checkout state cannot be established'
            } elseif ($name -like 'archived/*') {
                $classification = 'Retain archived branch'
                $reason = 'archived branches are retained for explicit scoped review'
            } elseif (!$fetchSucceeded) {
                $classification = 'Investigate / preserve'
                $reason = 'fetch failed; local refs may be stale'
            } elseif ($trunkExists -and (Test-Ancestor $repoPath $parts[1] $trunkRef)) {
                $classification = 'Git cleanup candidate'
                $reason = 'local branch tip is reachable from the local origin default-branch ref; no worktree currently checks it out'
            } else {
                $classification = 'Investigate / preserve'
                $reason = 'local branch tip is not reachable from the local origin default-branch ref'
            }
            $divergence = '(unknown)'
            if ($trunkExists) {
                $counts = Invoke-Git $repoPath @('rev-list', '--left-right', '--count', "$trunkRef...$($parts[1])")
                if ($counts.ExitCode -eq 0) { $values = $counts.Text -split '\s+'; if ($values.Count -eq 2) { $divergence = "behind $($values[0]), ahead $($values[1])" } }
            }
            $localBranches.Add([pscustomobject]@{ Name = $name; Head = $parts[1]; Divergence = $divergence; Classification = $classification; Reason = $reason })
        }
    }

    $repositories.Add([pscustomobject]@{
        Path = $repoPath
        Common = $common
        Trunk = if ($trunkName) { "origin/$trunkName" } else { '(unknown)' }
        Worktrees = $resolvedWorktrees.ToArray()
        LocalBranches = $localBranches.ToArray()
        FetchSucceeded = $fetchSucceeded
    })
}

$candidateCount = @($repositories | ForEach-Object { $_.Worktrees } | Where-Object Classification -eq 'Git cleanup candidate').Count + @($repositories | ForEach-Object { $_.LocalBranches } | Where-Object Classification -eq 'Git cleanup candidate').Count
$investigationCount = @($repositories | ForEach-Object { $_.Worktrees } | Where-Object Classification -eq 'Investigate / preserve').Count
$branchInvestigationCount = @($repositories | ForEach-Object { $_.LocalBranches } | Where-Object Classification -eq 'Investigate / preserve').Count
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Git Repository and Worktree Cleanup Report')
$lines.Add('')
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')")
$lines.Add("Roots: $($Root -join ', ')")
$lines.Add("Discovery: scanned $($discovery.Scanned) directories; enqueued $($discovery.Enqueued); inspected $($discovery.InspectedEntries) child entries")
$lines.Add("Excluded directory names: $($ExcludeDirectoryName -join ', ')")
$lines.Add("Repositories: $($repositories.Count) | Git cleanup candidates: $candidateCount | Worktrees to investigate: $investigationCount | Local branches to investigate: $branchInvestigationCount")
$lines.Add('')
$lines.Add('## Git cleanup candidates')
$lines.Add('')
$lines.Add('These worktrees are clean and their checked-out HEAD and branch tip are reachable from the locally recorded `origin` default-branch ref. The local branches below are not checked out and their tips are reachable from that ref. This is Git evidence only; complete the checks in the skill before pruning.')
$lines.Add('')
$lines.Add('| Repository | Worktree | Branch | HEAD | Divergence | Evidence |')
$lines.Add('|---|---|---|---|---|---|')
$candidateRows = @($repositories | ForEach-Object { $repo = $_; $_.Worktrees | Where-Object Classification -eq 'Git cleanup candidate' | ForEach-Object { [pscustomobject]@{ Repo = $repo.Path; Worktree = $_.Path; Branch = $_.Branch; Head = $_.Head; Divergence = $_.Divergence; Reason = $_.Reason } } })
if ($candidateRows.Count -eq 0) { $lines.Add('| (none) | | | | | |') }
foreach ($row in $candidateRows) { $lines.Add("| $(Escape-Markdown $row.Repo) | $(Escape-Markdown $row.Worktree) | $(Escape-Markdown $row.Branch) | ``$($row.Head.Substring(0, [Math]::Min(12, $row.Head.Length)))`` | $(Escape-Markdown $row.Divergence) | $(Escape-Markdown $row.Reason) |") }
$lines.Add('')
$lines.Add('## Git-merged local branches without a worktree')
$lines.Add('')
$lines.Add('| Repository | Branch | HEAD | Divergence | Evidence |')
$lines.Add('|---|---|---|---|---|')
$branchCandidates = @($repositories | ForEach-Object { $repo = $_; $_.LocalBranches | Where-Object Classification -eq 'Git cleanup candidate' | ForEach-Object { [pscustomobject]@{ Repo = $repo.Path; Name = $_.Name; Head = $_.Head; Divergence = $_.Divergence; Reason = $_.Reason } } })
if ($branchCandidates.Count -eq 0) { $lines.Add('| (none) | | | | |') }
foreach ($row in $branchCandidates) { $lines.Add("| $(Escape-Markdown $row.Repo) | $(Escape-Markdown $row.Name) | ``$($row.Head.Substring(0, [Math]::Min(12, $row.Head.Length)))`` | $(Escape-Markdown $row.Divergence) | $(Escape-Markdown $row.Reason) |") }
$lines.Add('')
$lines.Add('## Investigate or preserve')
$lines.Add('')
$lines.Add('| Repository | Worktree | Branch | HEAD | Divergence | Changes | Reason |')
$lines.Add('|---|---|---|---|---|---|---|')
$investigationRows = @($repositories | ForEach-Object { $repo = $_; $_.Worktrees | Where-Object Classification -eq 'Investigate / preserve' | ForEach-Object { [pscustomobject]@{ Repo = $repo.Path; Worktree = $_.Path; Branch = $_.Branch; Head = $_.Head; Divergence = $_.Divergence; Changes = $_.Changes; Reason = $_.Reason } } })
if ($investigationRows.Count -eq 0) { $lines.Add('| (none) | | | | | | |') }
foreach ($row in $investigationRows) { $shortHead = if ($row.Head) { $row.Head.Substring(0, [Math]::Min(12, $row.Head.Length)) } else { '(unknown)' }; $lines.Add("| $(Escape-Markdown $row.Repo) | $(Escape-Markdown $row.Worktree) | $(Escape-Markdown $row.Branch) | ``$shortHead`` | $(Escape-Markdown $row.Divergence) | $(Escape-Markdown $row.Changes) | $(Escape-Markdown $row.Reason) |") }
$lines.Add('')
$lines.Add('## Local branches requiring investigation')
$lines.Add('')
$lines.Add('| Repository | Branch | HEAD | Divergence | Reason |')
$lines.Add('|---|---|---|---|---|')
$branchInvestigations = @($repositories | ForEach-Object { $repo = $_; $_.LocalBranches | Where-Object Classification -eq 'Investigate / preserve' | ForEach-Object { [pscustomobject]@{ Repo = $repo.Path; Name = $_.Name; Head = $_.Head; Divergence = $_.Divergence; Reason = $_.Reason } } })
if ($branchInvestigations.Count -eq 0) { $lines.Add('| (none) | | | | |') }
foreach ($row in $branchInvestigations) { $lines.Add("| $(Escape-Markdown $row.Repo) | $(Escape-Markdown $row.Name) | ``$($row.Head.Substring(0, [Math]::Min(12, $row.Head.Length)))`` | $(Escape-Markdown $row.Divergence) | $(Escape-Markdown $row.Reason) |") }
$lines.Add('')
$lines.Add('## Retained trunk worktrees')
$lines.Add('')
$lines.Add('| Repository | Worktree | Branch | HEAD |')
$lines.Add('|---|---|---|---|')
$trunkRows = @($repositories | ForEach-Object { $repo = $_; $_.Worktrees | Where-Object Classification -eq 'Retain trunk worktree' | ForEach-Object { [pscustomobject]@{ Repo = $repo.Path; Worktree = $_.Path; Branch = $_.Branch; Head = $_.Head } } })
if ($trunkRows.Count -eq 0) { $lines.Add('| (none) | | | |') }
foreach ($row in $trunkRows) { $lines.Add("| $(Escape-Markdown $row.Repo) | $(Escape-Markdown $row.Worktree) | $(Escape-Markdown $row.Branch) | ``$($row.Head.Substring(0, [Math]::Min(12, $row.Head.Length)))`` |") }
$lines.Add('')
$lines.Add('## Retained archived work')
$lines.Add('')
$lines.Add('| Repository | Worktree or branch | HEAD | Reason |')
$lines.Add('|---|---|---|---|')
$archivedRows = @($repositories | ForEach-Object { $repo = $_; $_.Worktrees | Where-Object Classification -eq 'Retain archived worktree' | ForEach-Object { [pscustomobject]@{ Repo = $repo.Path; Name = $_.Path; Head = $_.Head; Reason = $_.Reason } }; $_.LocalBranches | Where-Object Classification -eq 'Retain archived branch' | ForEach-Object { [pscustomobject]@{ Repo = $repo.Path; Name = $_.Name; Head = $_.Head; Reason = $_.Reason } } })
if ($archivedRows.Count -eq 0) { $lines.Add('| (none) | | | |') }
foreach ($row in $archivedRows) { $head = if ($row.Head) { $row.Head.Substring(0, [Math]::Min(12, $row.Head.Length)) } else { '(unknown)' }; $lines.Add("| $(Escape-Markdown $row.Repo) | $(Escape-Markdown $row.Name) | ``$head`` | $(Escape-Markdown $row.Reason) |") }
$lines.Add('')
if ($Storage) {
    $lines.Add('## Storage observations')
    $lines.Add('')
    $lines.Add('These are bounded logical file sizes, including ignored output. Reclaimable bytes are unknown; shared extents and reusable state prevent treating these totals as recovery estimates. Storage observations grant no cleanup authority.')
    $lines.Add('')
    $lines.Add('| Root | Logical bytes | Source | Builds | Dependencies | Evidence | Unknown | Complete | Shared entries |')
    $lines.Add('|---|---:|---:|---:|---:|---:|---:|---|---:|')
    $storageScript = Join-Path $PSScriptRoot '../skills/storage-budget/scripts/storage_budget.py'
    $arguments = @($storageScript, 'inventory', '--max-depth', "$StorageMaxDepth", '--max-entries', "$StorageMaxEntries", '--max-seconds', "$StorageMaxSeconds")
    foreach ($repository in $repositories) { $arguments += @('--repo', $repository.Path) }
    foreach ($explicitOutput in $OutputRoot) { $arguments += @('--root', $explicitOutput) }
    if ($repositories.Count -eq 0 -and $OutputRoot.Count -eq 0) {
        $diagnostics.Add('No registered repository or explicit output roots were available for storage sizing.')
    } else {
        try {
            $raw = @(& $PythonCommand @arguments 2>&1)
            if ($LASTEXITCODE -notin @(0,3)) { throw ($raw -join "`n") }
            $observation = ($raw -join "`n") | ConvertFrom-Json
            foreach ($row in $observation.roots) {
                $size = if ($null -eq $row.logical_bytes) { 'unknown' } else { "$($row.logical_bytes)" }
                $lines.Add("| $(Escape-Markdown $row.root) | $size | $($row.categories.source) | $($row.categories.build) | $($row.categories.dependencies) | $($row.categories.evidence) | $($row.categories.unknown) | $($row.complete) | $($row.shared_entries) |")
                foreach ($gap in $row.diagnostics) { $diagnostics.Add("Storage $gap`: $($row.root)") }
            }
            foreach ($gap in $observation.diagnostics) { $diagnostics.Add("Storage $gap") }
        } catch {
            $diagnostics.Add("Storage observations unavailable: $($_.Exception.Message)")
        }
    }
    $lines.Add('')
}
$lines.Add('## Limits and follow-up checks')
$lines.Add('')
$lines.Add('- Unless `-Fetch` was used successfully, integration is measured against local tracking refs that may be stale.')
$lines.Add('- This report does not check open or draft pull requests, remote preservation, active processes or ownership, recovery value of ignored files/build evidence, or repository-specific cleanup rules. Optional storage sizing does not establish those facts.')
$lines.Add('- A clean and merged worktree is a candidate for review, not authorization to remove it. Keep the primary checkout, trunk worktrees, deferred work, unique commits, and uncertain evidence.')
if ($diagnostics.Count -gt 0) {
    $lines.Add('')
    $lines.Add('## Incomplete inventory')
    $lines.Add('')
    foreach ($diagnostic in $diagnostics) { $lines.Add("- $(Escape-Markdown $diagnostic)") }
}

$global:LASTEXITCODE = 0
$report = $lines -join "`r`n"
if ($OutputPath) {
    $absoluteOutput = [IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path -Parent $absoluteOutput
    if ($parent -and !(Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Output directory does not exist: $parent"
    }
    [IO.File]::WriteAllText($absoluteOutput, $report + "`r`n", [Text.UTF8Encoding]::new($false))
} else {
    Write-Output $report
}
