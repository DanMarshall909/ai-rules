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
  Set-Content -LiteralPath (Join-Path $script:seed 'content.txt') -Value 'one'
  & git -C $script:seed add content.txt
  & git -C $script:seed commit -qm initial
  & git -C $script:seed branch -M main
  & git -C $script:seed remote add origin $script:remote
  & git -C $script:seed push -qu origin main
  & git clone -q $script:remote $script:repo
  & git -C $script:repo config user.name Test
  & git -C $script:repo config user.email test@example.invalid
  $script:check = Join-Path $script:repo 'skills\upgrade-global-skills\scripts\check-rules-sync.ps1'
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:check) | Out-Null
  Copy-Item -LiteralPath $source -Destination $script:check
}

function Invoke-Check {
  $result = & pwsh -NoProfile -File $script:check 2>&1
  $script:code = $LASTEXITCODE
  $script:output = ($result | Out-String).Trim()
}

try {
  Write-Host 'rules sync preflight (PowerShell)'

  New-Fixture
  Invoke-Check
  if ($code -eq 0 -and -not $output) { Ok 'exact sync is silent' } else { No 'exact sync is silent' "code=$code output=$output" }

  New-Fixture
  Add-Content -LiteralPath (Join-Path $seed 'content.txt') -Value 'two'
  & git -C $seed commit -qam remote-change
  & git -C $seed push -q
  Invoke-Check
  if ($code -ne 0 -and $output -match 'remote') { Ok 'remote movement alerts' } else { No 'remote movement alerts' "code=$code output=$output" }

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
