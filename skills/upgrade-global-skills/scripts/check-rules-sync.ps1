[CmdletBinding()]
param()

$env:GIT_TERMINAL_PROMPT = '0'
$script:alerted = $false

function Write-Alert([string]$Message) {
  Write-Output "AI rules sync attention: $Message"
  $script:alerted = $true
}

function Resolve-PhysicalPath([string]$Path) {
  $full = [System.IO.Path]::GetFullPath($Path)
  $root = [System.IO.Path]::GetPathRoot($full)
  $relative = $full.Substring($root.Length)
  $parts = $relative -split '[\\/]'
  $current = $root

  foreach ($part in $parts) {
    if (-not $part) { continue }
    $candidate = Join-Path $current $part
    $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
    $target = @($item.Target)[0]
    if ($item.LinkType -and $target) {
      if (-not [System.IO.Path]::IsPathRooted($target)) {
        $target = Join-Path (Split-Path -Parent $candidate) $target
      }
      $current = [System.IO.Path]::GetFullPath($target)
    } else {
      $current = $candidate
    }
  }

  return $current
}

function Invoke-GitRemoteProbe([string]$Repository, [string]$Remote, [int]$TimeoutSeconds) {
  $gitCommand = (Get-Command git -CommandType Application -ErrorAction Stop).Source
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $gitCommand
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in @('-C', $Repository, 'ls-remote', '--symref', $Remote, 'HEAD')) {
    [void]$startInfo.ArgumentList.Add($argument)
  }

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  try {
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      if (-not $process.HasExited) {
        try {
          $process.Kill($true)
        } catch {
          if (-not $process.HasExited) { throw }
        }
      }
      $process.WaitForExit()
      [void]$stdoutTask.GetAwaiter().GetResult()
      [void]$stderrTask.GetAwaiter().GetResult()
      return [pscustomobject]@{ TimedOut = $true; ExitCode = -1; Lines = @() }
    }

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    [void]$stderrTask.GetAwaiter().GetResult()
    $lines = @($stdout -split "`r?`n" | Where-Object { $_ })
    return [pscustomobject]@{ TimedOut = $false; ExitCode = $process.ExitCode; Lines = $lines }
  }
  finally {
    $process.Dispose()
  }
}

try {
  $physicalScript = Resolve-PhysicalPath $PSCommandPath
} catch {
  Write-Alert 'could not resolve the installed preflight script.'
  exit 1
}

$scriptDirectory = Split-Path -Parent $physicalScript
$repoLines = @(& git -C $scriptDirectory rev-parse --show-toplevel 2>$null)
$repoCode = $LASTEXITCODE
$repo = $repoLines | Select-Object -First 1
if ($repoCode -ne 0 -or -not $repo) {
  Write-Alert 'could not locate the durable ai-rules checkout.'
  exit 1
}
$repo = $repo.Trim()

$remote = 'origin'
& git -C $repo remote get-url $remote 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Alert "the durable checkout has no '$remote' remote."
  exit 1
}

$status = @(& git -C $repo status --porcelain --untracked-files=normal 2>$null)
if ($LASTEXITCODE -ne 0) {
  Write-Alert "could not inspect the durable checkout's status."
} elseif ($status.Count -gt 0) {
  Write-Alert 'the durable checkout has local changes that are not committed or pushed.'
}

$remoteTimeoutSeconds = 10
$requestedTimeout = 0
if ([int]::TryParse($env:AI_RULES_SYNC_TIMEOUT_SECONDS, [ref]$requestedTimeout) -and $requestedTimeout -ge 1 -and $requestedTimeout -le 60) {
  $remoteTimeoutSeconds = $requestedTimeout
}

try {
  $remoteProbe = Invoke-GitRemoteProbe -Repository $repo -Remote $remote -TimeoutSeconds $remoteTimeoutSeconds
} catch {
  Write-Alert "could not query the '$remote' remote; sync is unverified."
  exit 1
}
if ($remoteProbe.TimedOut) {
  Write-Alert "query of '$remote' timed out after $remoteTimeoutSeconds seconds; sync is unverified."
  exit 1
}
$remoteInfo = @($remoteProbe.Lines)
if ($remoteProbe.ExitCode -ne 0 -or $remoteInfo.Count -eq 0) {
  Write-Alert "could not query the '$remote' remote; sync is unverified."
  exit 1
}

$defaultRef = $null
$remoteSha = $null
foreach ($line in $remoteInfo) {
  if ($line -match '^ref:\s+(refs/heads/\S+)\s+HEAD$') { $defaultRef = $Matches[1] }
  elseif ($line -match '^([0-9a-fA-F]{40,64})\s+HEAD$') { $remoteSha = $Matches[1].ToLowerInvariant() }
}
if (-not $defaultRef -or -not $remoteSha) {
  Write-Alert "the '$remote' remote did not advertise a default branch; sync is unverified."
  exit 1
}

$defaultBranch = $defaultRef.Substring('refs/heads/'.Length)
$localLines = @(& git -C $repo rev-parse HEAD 2>$null)
$localCode = $LASTEXITCODE
$localSha = $localLines | Select-Object -First 1
if ($localCode -ne 0 -or -not $localSha) {
  Write-Alert "could not read the durable checkout's current commit."
  exit 1
}
$localSha = $localSha.Trim().ToLowerInvariant()

$branchLines = @(& git -C $repo branch --show-current 2>$null)
$branchCode = $LASTEXITCODE
$currentBranch = $branchLines | Select-Object -First 1
if ($branchCode -ne 0) { $currentBranch = $null }
if ($currentBranch -ne $defaultBranch) {
  $shownBranch = if ($currentBranch) { $currentBranch.Trim() } else { 'detached HEAD' }
  Write-Alert "the durable checkout is on '$shownBranch', while $remote/HEAD is '$defaultBranch'."
}

if ($localSha -ne $remoteSha) {
  & git -C $repo merge-base --is-ancestor $remoteSha $localSha 2>$null | Out-Null
  $remoteIsAncestor = $LASTEXITCODE -eq 0
  if ($remoteIsAncestor) {
    Write-Alert "local commits are not pushed to $remote/$defaultBranch."
  } else {
    & git -C $repo merge-base --is-ancestor $localSha $remoteSha 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Write-Alert "the remote $remote/$defaultBranch has newer commits."
    } else {
      Write-Alert "the local checkout and remote $remote/$defaultBranch differ; fetch and reconcile them."
    }
  }
}

if ($script:alerted) { exit 1 }
