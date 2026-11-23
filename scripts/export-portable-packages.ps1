<#
.SYNOPSIS
    Package All Installed Scoop Apps into Standalone Portable Archives for Cloud Backup.
#>

param(
    [string]$TargetDir = "D:\Antigravity\portable-packages",
    [string]$ScoopAppsDir = "$env:USERPROFILE\scoop\apps"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Exporting Installed Scoop Apps to Portable Archives   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

if (-not (Test-Path $ScoopAppsDir)) {
    throw "Scoop apps directory not found at $ScoopAppsDir"
}

$apps = Get-ChildItem -Path $ScoopAppsDir -Directory | Where-Object { $_.Name -ne "scoop" }

Write-Host "Found $($apps.Count) installed Scoop applications." -ForegroundColor Gray

foreach ($app in $apps) {
    $appName = $app.Name
    $currentPath = Join-Path $app.FullName "current"
    if (-not (Test-Path $currentPath)) { continue }

    $targetZip = Join-Path $TargetDir "$appName-portable.zip"
    if (Test-Path $targetZip) {
        Write-Host "  -> [$appName] Already packaged at: $targetZip" -ForegroundColor DarkGray
        continue
    }

    Write-Host "  -> Packaging [$appName] into portable zip..." -ForegroundColor Yellow
    7z a -tzip $targetZip "$currentPath\*" -mx=5 | Out-Null
    $zipItem = Get-Item $targetZip
    $mb = [math]::Round($zipItem.Length / 1MB, 2)
    Write-Host "     [+] Saved $targetZip ($mb MB)" -ForegroundColor Green
}

Write-Host ""
Write-Host "All installed Scoop apps have been exported to: $TargetDir" -ForegroundColor Green
