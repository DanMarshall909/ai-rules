[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills\upgrade-global-skills\scripts\check-rules-sync.ps1'
$sandboxes = @()
$pass = 0
$fail = 0

function Ok([string]$Label) { $script:pass++; Write-Host "  ok   $Label" }
function No([string]$Label, [string]$Detail) { $script:fail++; Write-Host "  FAIL $Label"; Write-Host "       $Detail" }

function New-Fixture {
  $script:root = Join-Path ([System.IO.Path]::GetTempPath()) ("rules-sync-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
  $script:sandboxes += $script:root
  $script:remote = Join-Path $script:root 'remote.git'
  $script:seed = Join-Path $script:root 'seed'
  $script:repo = Join-Path $script:root 'repo'
  & git init --bare -q $script:remote
  & git -C $script:remote symbolic-ref HEAD refs/heads/main
  & git init -q $script:seed
  & git -C $script:seed config user.name Test
  & git -C $script:seed config user.email test@example.invalid
  & git -C $script:seed config core.autocrlf false
  Set-Content -LiteralPath (Join-Path $script:seed 'content.txt') -Value 'one'
  $seedCheck = Join-Path $script:seed 'skills\upgrade-global-skills\scripts\check-rules-sync.ps1'
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $seedCheck) | Out-Null
  Copy-Item -LiteralPath $source -Destination $seedCheck
  & git -C $script:seed add content.txt skills/upgrade-global-skills/scripts/check-rules-sync.ps1
  & git -C $script:seed commit -qm initial
  & git -C $script:seed branch -M main
  & git -C $script:seed remote add origin $script:remote
  & git -C $script:seed push -qu origin main
  & git -c core.autocrlf=false clone -q $script:remote $script:repo
  & git -C $script:repo config user.name Test
  & git -C $script:repo config user.email test@example.invalid
  & git -C $script:repo config core.autocrlf false
  $script:check = Join-Path $script:repo 'skills\upgrade-global-skills\scripts\check-rules-sync.ps1'
}

function Invoke-Check {
  $result = & pwsh -NoProfile -File $script:check 2>&1
  $script:code = $LASTEXITCODE
  $script:output = ($result | Out-String).Trim()
}

function Get-FetchState {
  $fetchHead = (& git -C $repo rev-parse --git-path FETCH_HEAD).Trim()
  if (Test-Path -LiteralPath $fetchHead) { return (& git hash-object --no-filters $fetchHead).Trim() }
  return 'absent'
}

try {
  Write-Host 'rules sync preflight (PowerShell)'

  New-Fixture
  Invoke-Check
  if ($code -eq 0 -and -not $output) { Ok 'exact sync is silent' } else { No 'exact sync is silent' "code=$code output=$output" }

  New-Fixture
  $installed = Join-Path $root 'installed-skill'
  New-Item -ItemType Junction -Path $installed -Target (Join-Path $repo 'skills\upgrade-global-skills') | Out-Null
  $script:check = Join-Path $installed 'scripts\check-rules-sync.ps1'
  Invoke-Check
  if ($code -eq 0 -and -not $output) { Ok 'installed junction resolves silently' } else { No 'installed junction resolves silently' "code=$code output=$output" }

  New-Fixture
  $fetchBefore = Get-FetchState
  & git -C $repo fetch -q origin HEAD
  $fetchAfter = Get-FetchState
  if ($fetchAfter -ne $fetchBefore) { Ok 'FETCH_HEAD oracle rejects a fetch fault' } else { No 'FETCH_HEAD oracle rejects a fetch fault' "FETCH_HEAD stayed $fetchBefore" }

  New-Fixture
  $trackingBefore = (& git -C $repo rev-parse refs/remotes/origin/main).Trim()
  $fetchBefore = Get-FetchState
  Add-Content -LiteralPath (Join-Path $seed 'content.txt') -Value 'two'
  & git -C $seed commit -qam remote-change
  & git -C $seed push -q
  Invoke-Check
  if ($code -ne 0 -and $output -match 'remote') { Ok 'remote movement alerts' } else { No 'remote movement alerts' "code=$code output=$output" }
  $trackingAfter = (& git -C $repo rev-parse refs/remotes/origin/main).Trim()
  $fetchAfter = Get-FetchState
  if ($trackingAfter -eq $trackingBefore -and $fetchAfter -eq $fetchBefore) { Ok 'remote check changes no refs or FETCH_HEAD' } else { No 'remote check changes no refs or FETCH_HEAD' "tracking=$trackingBefore->$trackingAfter FETCH_HEAD=$fetchBefore->$fetchAfter" }

  New-Fixture
  Add-Content -LiteralPath (Join-Path $repo 'content.txt') -Value 'local'
  & git -C $repo commit -qam local-change
  Invoke-Check
  if ($code -ne 0 -and $output -match 'not pushed') { Ok 'unpushed commits alert' } else { No 'unpushed commits alert' "code=$code output=$output" }

  New-Fixture
  Add-Content -LiteralPath (Join-Path $repo 'content.txt') -Value 'dirty'
  Invoke-Check
  if ($code -ne 0 -and $output -match 'not committed') { Ok 'uncommitted work alerts' } else { No 'uncommitted work alerts' "code=$code output=$output" }

  New-Fixture
  Set-Content -LiteralPath (Join-Path $repo '.git\index') -Value 'invalid index'
  Invoke-Check
  if ($code -ne 0 -and $output -match 'could not inspect') { Ok 'failed status inspection alerts' } else { No 'failed status inspection alerts' "code=$code output=$output" }

  New-Fixture
  & git -C $repo remote set-url origin (Join-Path $root 'missing.git')
  Invoke-Check
  if ($code -ne 0 -and $output -match 'could not query') { Ok 'unverifiable remote alerts' } else { No 'unverifiable remote alerts' "code=$code output=$output" }
}
finally {
  foreach ($path in $sandboxes) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "$pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
