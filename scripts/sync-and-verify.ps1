<#
.SYNOPSIS
    Syncs and verifies Scoop manifests from upstream buckets for tracked apps.

.DESCRIPTION
    Reads config/apps.json, fetches the latest upstream manifests, performs JSON validation,
    optional download URL reachability checks, and updates the bucket/ folder only when verified.
#>

[CmdletBinding()]
param (
    [string]$ConfigPath = "",
    [string]$BucketDir = "",
    [string]$AppName = "",
    [switch]$Force = $false,
    [switch]$SkipUrlCheck = $false,
    [switch]$Strict = $false
)

$ErrorActionPreference = "Stop"

# Ensure TLS 1.2+ is used on Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Resolve Paths
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot "..\config\apps.json"
}
if (-not $BucketDir) {
    $BucketDir = Join-Path $PSScriptRoot "..\bucket"
}

$ConfigPath = (Resolve-Path -Path $ConfigPath -ErrorAction Stop).ProviderPath
if (-not (Test-Path $BucketDir)) {
    New-Item -ItemType Directory -Path $BucketDir -Force | Out-Null
}
$BucketDir = (Resolve-Path -Path $BucketDir -ErrorAction Stop).ProviderPath


if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found at: $ConfigPath"
    exit 1
}

if (-not (Test-Path $BucketDir)) {
    New-Item -ItemType Directory -Path $BucketDir -Force | Out-Null
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$upstreamBuckets = $config.upstream_buckets
$trackedApps = $config.tracked_apps

if ($AppName) {
    $trackedApps = $trackedApps | Where-Object { $_.name -eq $AppName }
    if (-not $trackedApps) {
        Write-Error "App '$AppName' not found in tracked_apps configuration."
        exit 1
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     Scoop Apps Bucket: Sync & Verification Pipeline" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Tracked apps to process: $($trackedApps.Count)"
Write-Host ""

$stats = [ordered]@{
    Updated   = @()
    UpToDate  = @()
    Failed    = @()
    Added     = @()
}

function Test-DownloadUrl {
    param ([string]$Url)
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = "HEAD"
        $request.Timeout = 10000
        $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Scoop-Sync/1.0"
        
        $response = $request.GetResponse()
        $statusCode = [int]$response.StatusCode
        $response.Close()
        
        return ($statusCode -ge 200 -and $statusCode -lt 400)
    }
    catch [System.Net.WebException] {
        # Some servers reject HEAD requests with 403/405, fallback to GET with byte range
        try {
            $request = [System.Net.WebRequest]::Create($Url)
            $request.Method = "GET"
            $request.Timeout = 10000
            $request.Headers.Add("Range", "bytes=0-10")
            $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Scoop-Sync/1.0"
            $response = $request.GetResponse()
            $statusCode = [int]$response.StatusCode
            $response.Close()
            return ($statusCode -ge 200 -and $statusCode -lt 400)
        }
        catch {
            Write-Warning "URL test failed for: $Url - $($_.Exception.Message)"
            return $false
        }
    }
    catch {
        Write-Warning "Unexpected error testing URL: $Url - $($_.Exception.Message)"
        return $false
    }
}

function Format-ScoopJson {
    param ([string]$RawJson)
    # Formats JSON according to Scoop standards (4 spaces indent, unix line breaks, sorted order preserved)
    # Using PowerShell ConvertFrom-Json / ConvertTo-Json
    $obj = $RawJson | ConvertFrom-Json
    return ($obj | ConvertTo-Json -Depth 20)
}

foreach ($app in $trackedApps) {
    $name = $app.name
    $sourceBucket = $app.source_bucket
    
    if ($sourceBucket -eq "custom") {
        Write-Host "CUSTOM (Locally maintained)" -ForegroundColor Cyan
        $stats.UpToDate += "$name (Custom)"
        continue
    }

    if (-not $upstreamBuckets.$sourceBucket) {
        Write-Host "[-] Unknown upstream bucket source '$sourceBucket' for app '$name'" -ForegroundColor Red
        $stats.Failed += "$name (Unknown bucket $sourceBucket)"
        continue
    }

    $baseUrl = $upstreamBuckets.$sourceBucket.TrimEnd('/')
    $upstreamUrl = "$baseUrl/$name.json"
    $targetPath = Join-Path $BucketDir "$name.json"
    $isNew = -not (Test-Path $targetPath)

    Write-Host -NoNewline "Processing [$name] from '$sourceBucket'... "

    # 1. Fetch upstream manifest
    $rawContent = $null
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Scoop-Apps-Sync/1.0")
        $rawContent = $wc.DownloadString($upstreamUrl)
    }
    catch {
        Write-Host "FAILED (Fetch error: $($_.Exception.Message))" -ForegroundColor Red
        $stats.Failed += "$name (Fetch failed)"
        continue
    }

    # 2. Parse and validate JSON
    $manifestObj = $null
    try {
        $manifestObj = $rawContent | ConvertFrom-Json
    }
    catch {
        Write-Host "FAILED (Invalid JSON)" -ForegroundColor Red
        $stats.Failed += "$name (Invalid JSON)"
        continue
    }

    # 3. Validate required schema fields
    if (-not $manifestObj.version) {
        Write-Host "FAILED (Missing 'version' field)" -ForegroundColor Red
        $stats.Failed += "$name (Missing version)"
        continue
    }

    $upstreamVersion = $manifestObj.version

    # Check if already up-to-date
    if (-not $isNew -and -not $Force) {
        try {
            $existingObj = Get-Content $targetPath -Raw | ConvertFrom-Json
            if ($existingObj.version -eq $upstreamVersion) {
                Write-Host "UP-TO-DATE ($upstreamVersion)" -ForegroundColor Gray
                $stats.UpToDate += "$name ($upstreamVersion)"
                continue
            }
        }
        catch {
            # Existing file corrupted, will overwrite
        }
    }

    # 4. Optional URL verification
    if (-not $SkipUrlCheck -and $config.settings.verify_urls) {
        $urlsToTest = @()
        if ($manifestObj.url) {
            if ($manifestObj.url -is [array]) { $urlsToTest += $manifestObj.url }
            else { $urlsToTest += $manifestObj.url }
        }
        if ($manifestObj.architecture) {
            foreach ($arch in $manifestObj.architecture.PSObject.Properties) {
                if ($arch.Value.url) {
                    if ($arch.Value.url -is [array]) { $urlsToTest += $arch.Value.url }
                    else { $urlsToTest += $arch.Value.url }
                }
            }
        }

        # Filter out variables like $version if any weren't interpolated
        $validUrls = @($urlsToTest | Where-Object { $_ -match "^https?://" -and $_ -notmatch '\$version' })
        if ($validUrls.Count -gt 0) {
            $firstUrl = [string]$validUrls[0]
            $urlOk = Test-DownloadUrl -Url $firstUrl
            if (-not $urlOk) {
                Write-Host "FAILED (Binary URL unreachable: $firstUrl)" -ForegroundColor Yellow
                $stats.Failed += "$name (URL unreachable)"
                continue
            }
        }
    }

    # 5. Format & Save to bucket
    try {
        $formattedJson = Format-ScoopJson -RawJson $rawContent
        [System.IO.File]::WriteAllText($targetPath, $formattedJson, [System.Text.Encoding]::UTF8)
        
        if ($isNew) {
            Write-Host "ADDED ($upstreamVersion)" -ForegroundColor Green
            $stats.Added += "$name ($upstreamVersion)"
        }
        else {
            Write-Host "UPDATED ($upstreamVersion)" -ForegroundColor Green
            $stats.Updated += "$name ($upstreamVersion)"
        }
    }
    catch {
        Write-Host "FAILED (Save error: $($_.Exception.Message))" -ForegroundColor Red
        $stats.Failed += "$name (File save failed)"
    }
}

Write-Host ""
Write-Host "================== Summary ==================" -ForegroundColor Cyan
Write-Host "Newly Added: $($stats.Added.Count)" -ForegroundColor Green
Write-Host "Updated:     $($stats.Updated.Count)" -ForegroundColor Green
Write-Host "Up to date:  $($stats.UpToDate.Count)" -ForegroundColor Gray
Write-Host "Failed:      $($stats.Failed.Count)" -ForegroundColor $(if ($stats.Failed.Count -gt 0) { "Red" } else { "Gray" })
Write-Host "=============================================" -ForegroundColor Cyan

# Output for GitHub Actions
if ($env:GITHUB_OUTPUT) {
    $hasChanges = ($stats.Added.Count -gt 0 -or $stats.Updated.Count -gt 0)
    "has_changes=$($hasChanges.ToString().ToLower())" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    $summary = ($stats.Added + $stats.Updated) -join ", "
    "updated_apps=$summary" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

if ($stats.Failed.Count -gt 0) {
    Write-Warning "Some apps failed verification: $($stats.Failed -join ', ')"
    if ($Strict) {
        Write-Error "Strict mode failure: $($stats.Failed.Count) application(s) failed verification."
        exit 1
    }
}
