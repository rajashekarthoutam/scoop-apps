<#
.SYNOPSIS
    Linter and automated test suite for manifests in the bucket/ directory.
#>

[CmdletBinding()]
param (
    [string]$BucketDir = ""
)

$ErrorActionPreference = "Stop"

if (-not $BucketDir) {
    $BucketDir = Join-Path $PSScriptRoot "..\bucket"
}
if (Test-Path $BucketDir) {
    $BucketDir = (Resolve-Path -Path $BucketDir).ProviderPath
} else {
    Write-Error "Bucket directory not found at $BucketDir"
    exit 1
}


$manifests = Get-ChildItem -Path $BucketDir -Filter "*.json"
if ($manifests.Count -eq 0) {
    Write-Warning "No manifests found in $BucketDir"
    exit 0
}

Write-Host "Linting $($manifests.Count) manifests in $BucketDir..." -ForegroundColor Cyan

$hasErrors = $false

foreach ($file in $manifests) {
    $fileName = $file.Name
    $filePath = $file.FullName
    $errors = @()

    # 1. Check JSON syntax
    try {
        $content = Get-Content -Path $filePath -Raw
        $json = $content | ConvertFrom-Json
    }
    catch {
        $errors += "Invalid JSON: $($_.Exception.Message)"
    }

    if ($json) {
        # 2. Check required fields
        if (-not $json.version) {
            $errors += "Missing required field: 'version'"
        }
        if (-not $json.description -and -not $json.homepage) {
            $errors += "Manifest should have at least 'description' or 'homepage'"
        }

        # 3. Check download specification
        $hasUrl = $false
        if ($json.url) { $hasUrl = $true }
        if ($json.architecture) {
            foreach ($prop in $json.architecture.PSObject.Properties) {
                if ($prop.Value.url) { $hasUrl = $true }
            }
        }
        if (-not $hasUrl) {
            $errors += "Manifest missing binary download 'url' or 'architecture' section"
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "[-] $fileName : FAILED" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "    - $err" -ForegroundColor Red
        }
        $hasErrors = $true
    }
    else {
        Write-Host "[+] $fileName : OK ($($json.version))" -ForegroundColor Green
    }
}

if ($hasErrors) {
    Write-Error "Bucket linting failed with one or more errors."
    exit 1
}

Write-Host "All manifests passed lint checks successfully!" -ForegroundColor Green
exit 0
