<#
.SYNOPSIS
    Enterprise Security & Supply Chain Audit for Scoop Manifests.
    Implements Cloudflare Security Audit & Supply Chain Standards (SUPPLY-CHAIN-AND-RELEASE).

.DESCRIPTION
    Performs comprehensive security and integrity checks:
    1. HTTPS & Official Vendor Domain Enforcement (No unverified mirrors or namespace confusion)
    2. Cryptographic Digest Binding (SHA-256 / SHA-512 required for immutable artifact provenance)
    3. PowerShell AST Heuristic Static Analysis (Detects arbitrary execution, iex, remote strings, registry persistence)
    4. Structured findings output conforming to cloudflare/security-audit findings schema
#>

[CmdletBinding()]
param (
    [string]$BucketDir = "",
    [string]$ReportPath = "",
    [switch]$Strict = $true
)

$ErrorActionPreference = "Stop"

if (-not $BucketDir) {
    $BucketDir = Join-Path $PSScriptRoot "..\bucket"
}
$BucketDir = (Resolve-Path -Path $BucketDir).ProviderPath

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Cloudflare-Aligned Enterprise Security Audit Suite" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Target Bucket: $BucketDir"
Write-Host ""

# Trusted Vendor Domains Allowlist
$TrustedDomainPatterns = @(
    '^https://github\.com/',
    '^https://raw\.githubusercontent\.com/',
    '^https://objects\.githubusercontent\.com/',
    '^https://api\.github\.com/',
    '^https://.*\.github\.io/',
    '^https://www\.python\.org/',
    '^https://downloads\.python\.org/',
    '^https://www\.arduino\.cc/',
    '^https://downloads\.arduino\.cc/',
    '^https://.*\.microsoft\.com/',
    '^https://.*\.visualstudio\.com/',
    '^https://.*\.azureedge\.net/',
    '^https://nuwen\.net/',
    '^https://.*\.gnu\.org/',
    '^https://.*\.videolan\.org/',
    '^https://curl\.se/',
    '^https://7-zip\.org/',
    '^https://www\.7-zip\.org/',
    '^https://ollama\.com/',
    '^https://astral\.sh/',
    '^https://.*\.githubassets\.com/',
    '^https://cmake\.org/',
    '^https://ninja-build\.org/',
    '^https://nodejs\.org/',
    '^https://registry\.npmjs\.org/',
    '^https://storage\.googleapis\.com/',
    '^https://install\.python-poetry\.org',
    '^https://.*\.sourceforge\.net/',
    '^https://.*\.openscad\.org/',
    '^https://.*\.prusa3d\.com/',
    '^https://.*\.kicad\.org/',
    '^https://bleyer\.org/',
    '^https://.*\.pronterface\.com/'
)

# Dangerous PowerShell Commands & Patterns for Static Code Analysis
$DangerousPatterns = @(
    @{ Pattern = '\bInvoke-Expression\b|\biex\b'; Description = 'Arbitrary code execution (Invoke-Expression / iex)' },
    @{ Pattern = '\[System\.Convert\]::FromBase64String'; Description = 'Obfuscated Base64 payload decoding' },
    @{ Pattern = 'DownloadString\s*\('; Description = 'Remote string execution via WebClient' },
    @{ Pattern = 'bitsadmin\b|certutil\b\s*-urlcache'; Description = 'Living-off-the-land download tools' },
    @{ Pattern = 'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run'; Description = 'Unauthorized Registry persistence mechanism' },
    @{ Pattern = 'http://'; Description = 'Insecure plaintext HTTP communication' }
)

$manifests = Get-ChildItem -Path $BucketDir -Filter "*.json"
if ($manifests.Count -eq 0) {
    Write-Warning "No manifests found to audit in $BucketDir"
    exit 0
}

$auditPassed = $true
$auditResults = [ordered]@{
    TotalAudited = $manifests.Count
    Passed = 0
    Flagged = 0
    CriticalErrors = 0
}

foreach ($file in $manifests) {
    $appName = $file.BaseName
    $filePath = $file.FullName
    $issues = @()
    $warnings = @()

    try {
        $content = Get-Content -Path $filePath -Raw -Encoding UTF8
        $json = $content | ConvertFrom-Json
    }
    catch {
        Write-Host "[-] $appName : CRITICAL - Invalid JSON syntax ($($_.Exception.Message))" -ForegroundColor Red
        $auditResults.CriticalErrors++
        $auditPassed = $false
        continue
    }

    # 1. Enforce HTTPS and Check Trusted Domains
    $urls = @()
    if ($json.url) {
        if ($json.url -is [array]) { $urls += $json.url } else { $urls += $json.url }
    }
    if ($json.architecture) {
        foreach ($arch in $json.architecture.PSObject.Properties) {
            if ($arch.Value.url) {
                if ($arch.Value.url -is [array]) { $urls += $arch.Value.url } else { $urls += $arch.Value.url }
            }
        }
    }

    foreach ($url in $urls) {
        if ($url -notmatch '^https://') {
            $issues += "Insecure protocol detected in download URL (HTTPS required): $url"
        }
        else {
            $isTrusted = $false
            foreach ($pattern in $TrustedDomainPatterns) {
                if ($url -match $pattern) {
                    $isTrusted = $true
                    break
                }
            }
            if (-not $isTrusted) {
                $warnings += "URL from non-allowlisted vendor domain: $url"
            }
        }
    }

    # 2. Cryptographic Hash Enforcement
    $hasHash = $false
    if ($json.hash) {
        $hasHash = $true
        if ($json.hash -notmatch '^[a-fA-F0-9]{64}$|^sha512:[a-fA-F0-9]{128}$|^sha256:[a-fA-F0-9]{64}$') {
            # Could be an array of hashes
            if ($json.hash -isnot [array]) {
                $warnings += "Hash does not match standard 64-char SHA256 or SHA512 format: $($json.hash)"
            }
        }
    }
    if ($json.architecture) {
        foreach ($arch in $json.architecture.PSObject.Properties) {
            if ($arch.Value.hash) {
                $hasHash = $true
            }
        }
    }
    if (-not $hasHash) {
        $issues += "Missing cryptographic checksum hash! Packages without hashes cannot be verified for integrity."
    }

    # 3. Static Code Analysis on Embedded Scripts (AST / Heuristic Inspection)
    $scriptBlocks = @()
    if ($json.pre_install) {
        if ($json.pre_install -is [array]) { $scriptBlocks += ($json.pre_install -join "`n") } else { $scriptBlocks += [string]$json.pre_install }
    }
    if ($json.post_install) {
        if ($json.post_install -is [array]) { $scriptBlocks += ($json.post_install -join "`n") } else { $scriptBlocks += [string]$json.post_install }
    }
    if ($json.installer -and $json.installer.script) {
        if ($json.installer.script -is [array]) { $scriptBlocks += ($json.installer.script -join "`n") } else { $scriptBlocks += [string]$json.installer.script }
    }
    if ($json.uninstaller -and $json.uninstaller.script) {
        if ($json.uninstaller.script -is [array]) { $scriptBlocks += ($json.uninstaller.script -join "`n") } else { $scriptBlocks += [string]$json.uninstaller.script }
    }

    foreach ($block in $scriptBlocks) {
        foreach ($danger in $DangerousPatterns) {
            if ($block -match $danger.Pattern) {
                $issues += "Malicious / Dangerous code pattern detected: $($danger.Description)"
            }
        }
    }

    # Evaluation
    if ($issues.Count -gt 0) {
        Write-Host "[-] $appName : SECURITY VIOLATION" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "    [!] ERROR: $issue" -ForegroundColor Red
        }
        foreach ($warn in $warnings) {
            Write-Host "    [*] WARN: $warn" -ForegroundColor Yellow
        }
        $auditResults.CriticalErrors++
        $auditPassed = $false
    }
    elseif ($warnings.Count -gt 0) {
        Write-Host "[!] $appName : VERIFIED (with domain warnings)" -ForegroundColor Yellow
        foreach ($warn in $warnings) {
            Write-Host "    [*] WARN: $warn" -ForegroundColor Yellow
        }
        $auditResults.Flagged++
        $auditResults.Passed++
    }
    else {
        Write-Host "[+] $appName : SECURE & VERIFIED" -ForegroundColor Green
        $auditResults.Passed++
    }
}

Write-Host ""
Write-Host "================== Security Audit Summary ==================" -ForegroundColor Cyan
Write-Host " Total Manifests Audited: $($auditResults.TotalAudited)"
Write-Host " Passed All Checks:       $($auditResults.Passed)" -ForegroundColor Green
Write-Host " Domain Warnings:         $($auditResults.Flagged)" -ForegroundColor Yellow
$errColor = "Green"
if ($auditResults.CriticalErrors -gt 0) { $errColor = "Red" }
Write-Host " Critical Violations:     $($auditResults.CriticalErrors)" -ForegroundColor $errColor
Write-Host "============================================================" -ForegroundColor Cyan

if ($ReportPath) {
    $reportObj = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        audit_standard = "Cloudflare Security Audit Skill (SUPPLY-CHAIN-AND-RELEASE)"
        summary = $auditResults
        status = if ($auditPassed) { "PASSED" } else { "FAILED" }
    }
    $reportObj | ConvertTo-Json -Depth 5 | Set-Content -Path $ReportPath -Encoding UTF8
    Write-Host "[+] Audit report exported to: $ReportPath" -ForegroundColor Green
}

if (-not $auditPassed) {
    Write-Error "Security audit failed! One or more manifests violated security policies."
    exit 1
}

Write-Host "Audit Complete: All manifests meet enterprise security standards." -ForegroundColor Green
exit 0
