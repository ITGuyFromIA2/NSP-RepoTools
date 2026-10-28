<#
.SYNOPSIS
    Pre-push check for NSP.RepoTools. Exits non-zero on any failure.

.DESCRIPTION
    1. Client-reference sweep (this module's own Find-NSPClientReference) over tracked and
       untracked files.
    2. Parser check over every script.
    3. Module import under Windows PowerShell 5.1 (the floor).
    4. PSScriptAnalyzer over module source.
    5. Pester 5+ over Tests\.

    Missing PSScriptAnalyzer or Pester prints the install command and exits 2; nothing is
    installed silently. -InstallDeps installs them for the current user via NSP.Bootstrap.

.EXAMPLE
    .\tools\Test-Repo.ps1
#>
[CmdletBinding()]
param(
    [switch]$InstallDeps
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'NSP.RepoTools.psd1'
$failed = $false

function Get-ModuleSourceFile {
    # Windows PowerShell 5.1 does not reliably honor -Include with -LiteralPath.
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
        Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' -and $_.FullName -notmatch '[\\/]\.git[\\/]' }
}

Write-Host "`n=== Client-reference sweep ===" -ForegroundColor Cyan
# Locations and rules only, never the matched text.
Import-Module $manifestPath -Force
$hits = @(Find-NSPClientReference -Path $repoRoot -IncludeUntracked -WarningAction SilentlyContinue)
if ($hits.Count) {
    $hits | ForEach-Object { Write-Host "  $($_.File):$($_.Line) [$($_.Rule)]" -ForegroundColor Red }
    Write-Host '  Review with: Find-NSPClientReference -Path . -IncludeUntracked' -ForegroundColor Red
    $failed = $true
} else {
    Write-Host 'clean' -ForegroundColor Green
}

Write-Host "`n=== Parser ===" -ForegroundColor Cyan
$parseFailures = foreach ($file in Get-ModuleSourceFile) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors) | Out-Null
    foreach ($e in $errors) { "$($file.Name):$($e.Extent.StartLineNumber) $($e.Message)" }
}
if (@($parseFailures).Count) {
    $parseFailures | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    $failed = $true
} else {
    Write-Host 'clean' -ForegroundColor Green
}

Write-Host "`n=== Windows PowerShell 5.1 import ===" -ForegroundColor Cyan
$windowsPowerShell = Get-Command 'powershell.exe' -ErrorAction SilentlyContinue
if ($windowsPowerShell) {
    $importCheck = "`$ErrorActionPreference='Stop'; Import-Module '$manifestPath' -Force; 'PowerShell ' + `$PSVersionTable.PSVersion + ': import ok'"
    & $windowsPowerShell.Source -NoLogo -NoProfile -ExecutionPolicy Bypass -Command $importCheck
    if ($LASTEXITCODE -ne 0) { $failed = $true }
} else {
    Write-Warning 'Windows PowerShell 5.1 is unavailable on this host; its import check was skipped.'
}

function Test-Dependency {
    param([string]$Name, [version]$Min)
    Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -ge $Min } | Select-Object -First 1
}
$needAnalyzer = -not (Test-Dependency -Name 'PSScriptAnalyzer' -Min ([version]'1.21.0'))
$needPester = -not (Test-Dependency -Name 'Pester' -Min ([version]'5.5.0'))
if ($needAnalyzer -or $needPester) {
    if ($InstallDeps) {
        Import-Module NSP.Bootstrap -ErrorAction Stop
        if ($needAnalyzer) { Install-NSPModule -Name PSScriptAnalyzer -MinimumVersion 1.21.0 }
        if ($needPester) { Install-NSPModule -Name Pester -MinimumVersion 5.5.0 -SkipPublisherCheck }
    } else {
        Write-Host "`nMissing PSScriptAnalyzer 1.21+ or Pester 5.5+. Re-run with -InstallDeps (requires NSP.Bootstrap)." -ForegroundColor Yellow
        exit 2
    }
}

Write-Host "`n=== PSScriptAnalyzer ===" -ForegroundColor Cyan
Import-Module PSScriptAnalyzer -Force
$settings = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$analysis = foreach ($file in Get-ModuleSourceFile) {
    Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settings
}
if (@($analysis).Count) {
    $analysis | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message
    $failed = $true
} else {
    Write-Host 'clean' -ForegroundColor Green
}

Write-Host "`n=== Pester ===" -ForegroundColor Cyan
Import-Module Pester -MinimumVersion 5.5.0 -Force
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = Join-Path $repoRoot 'Tests'
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $pesterConfig
if ($result.FailedCount -gt 0) { $failed = $true }

if ($failed) {
    Write-Host "`nRESULT: FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "`nRESULT: PASS" -ForegroundColor Green
exit 0
