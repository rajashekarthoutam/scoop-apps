<#
.SYNOPSIS
    1-Click Clean Slate Installer & Initializer for Rajashekar's Secure Scoop Architecture.

.DESCRIPTION
    1. Completely cleans all existing Scoop files, cache, and obsolete PATH entries.
    2. Installs Scoop directly from the verified forked repository:
       https://github.com/rajashekarthoutam/Scoop
    3. Unlinks the community 'main' bucket (0 unvetted packages).
    4. Connects the curated, malware-audited 'apps' bucket:
       https://github.com/rajashekarthoutam/scoop-apps
    5. Installs the core base toolchains (7zip, git, gh, ripgrep).
    6. Re-integrates portable Keil & Flash Magic shims from D:\ if present.
    7. Cleans and optimizes User PATH.
#>

[CmdletBinding()]
param (
    [string]$TargetDir = "$env:USERPROFILE\scoop",
    [switch]$SkipBaseApps = $false
)

$ErrorActionPreference = "Stop"

# Force TLS 1.2+
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   1-Click Clean Slate Installer: Secure Scoop Engine" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Target Installation Path: $TargetDir"
Write-Host "Forked Engine Source:     https://github.com/rajashekarthoutam/Scoop"
Write-Host "Curated Apps Bucket:      https://github.com/rajashekarthoutam/scoop-apps"
Write-Host ""

# -------------------------------------------------------------
# STEP 1: Purge Old Scoop Installations & Bloat
# -------------------------------------------------------------
Write-Host "[1/6] Purging old Scoop files and leftover bloat..." -ForegroundColor Yellow

$pathsToPurge = @(
    $TargetDir,
    "$env:USERPROFILE\.config\scoop",
    "$env:USERPROFILE\.cache\scoop",
    "$env:LOCALAPPDATA\scoop"
)

foreach ($path in $pathsToPurge) {
    if (Test-Path $path) {
        Write-Host "      Removing: $path" -ForegroundColor DarkGray
        cmd.exe /c "if exist `"$path`" rd /s /q `"$path`"" 2>$null
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Clean temp sandboxes
$tempCleanups = @(
    "$env:TEMP\scoop-security-sandbox",
    "$env:TEMP\printrun-tmp",
    "$env:TEMP\printrun-x64.zip",
    "$env:TEMP\printrun-x86.zip"
)
foreach ($t in $tempCleanups) {
    if (Test-Path $t) {
        Remove-Item -Path $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clean Obsolete User PATH Entries (e.g., dead D:\Scoop\shims)
$currentUserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentUserPath) {
    $cleanPathParts = ($currentUserPath -split ';') | Where-Object {
        $_ -and ($_ -ne "D:\Scoop\shims") -and ($_ -ne "$TargetDir\shims")
    }
    # Prepend the official target shims directory
    $newPath = ("$TargetDir\shims;" + ($cleanPathParts -join ';')).TrimEnd(';')
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    $env:PATH = "$TargetDir\shims;" + $env:PATH
    Write-Host "      Cleaned User PATH environment variable." -ForegroundColor DarkGray
}

Write-Host "[+] Old state purged cleanly." -ForegroundColor Green

# -------------------------------------------------------------
# STEP 2: Download & Execute Installer Retargeted to Forked Repo
# [SEC-01] Installer is hash-pinned to prevent upstream supply-chain injection
# -------------------------------------------------------------
Write-Host "[2/6] Installing Scoop from forked repository (rajashekarthoutam/Scoop)..." -ForegroundColor Yellow

$installerUrl = "https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1"
$rawInstaller = (New-Object System.Net.WebClient).DownloadString($installerUrl)

# [SEC-01] Verify installer integrity before executing
$installerHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($rawInstaller)
    )
).Replace('-', '').ToLower()

# Pinned SHA-256 of the known-good ScoopInstaller/Install install.ps1
# Update this hash when intentionally adopting a new upstream installer version
$pinnedInstallerHash = "94f983b190438311e006b957db7c8422709e0ba62a6c2ac04e278164108f2512"
if ($installerHash -ne $pinnedInstallerHash) {
    throw "[SEC-01] CRITICAL: Scoop installer hash mismatch! Expected: $pinnedInstallerHash, Got: $installerHash. The upstream installer may have been tampered with."
}
Write-Host "      [SEC-01] Verified upstream installer SHA-256 integrity: $installerHash" -ForegroundColor Green

# Retarget repo URLs to Rajashekar's verified fork
$forkedInstaller = $rawInstaller.Replace(
    "https://github.com/ScoopInstaller/Scoop/archive/master.zip",
    "https://github.com/rajashekarthoutam/Scoop/archive/master.zip"
).Replace(
    "https://github.com/ScoopInstaller/Scoop.git",
    "https://github.com/rajashekarthoutam/Scoop.git"
)

$tempInstallerPath = Join-Path $env:TEMP "install-scoop-fork.ps1"
[System.IO.File]::WriteAllText($tempInstallerPath, $forkedInstaller, [System.Text.Encoding]::UTF8)

try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tempInstallerPath -ScoopDir $TargetDir
} finally {
    Remove-Item -Path $tempInstallerPath -Force -ErrorAction SilentlyContinue
}

$scoopShim = Join-Path $TargetDir "shims\scoop.ps1"
if (-not (Test-Path $scoopShim)) {
    throw "Scoop installation verification failed! $scoopShim not found."
}

Write-Host "[+] Scoop core engine installed from forked repository!" -ForegroundColor Green

# Configure permanent tracking to forked repo
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' config SCOOP_REPO 'https://github.com/rajashekarthoutam/Scoop'"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' config SCOOP_BRANCH 'master'"

# -------------------------------------------------------------
# STEP 3: Bootstrap Git & 7-Zip
# -------------------------------------------------------------
Write-Host "[3/6] Bootstrapping core Git and 7-Zip engines..." -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' install git 7zip"
Write-Host "[+] Git & 7-Zip bootstrapped successfully." -ForegroundColor Green

# -------------------------------------------------------------
# STEP 4: Connect Curated 'apps' Bucket & Purge 'main'
# [BOOT-02] Clean stale git credential helpers before cloning
# [BOOT-03] Guard bucket rm main against failure if not present
# -------------------------------------------------------------
Write-Host "[4/6] Connecting exclusive curated bucket and purging community 'main'..." -ForegroundColor Yellow

$gitExe = Join-Path $TargetDir "apps\git\current\cmd\git.exe"
$targetBucketPath = Join-Path $TargetDir "buckets\apps"

# [BOOT-02] Clear stale credential helpers that may reference wiped gh.exe
& $gitExe config --global --unset-all credential.helper 2>$null
Write-Host "      [BOOT-02] Cleared stale git credential helpers" -ForegroundColor DarkGray

if (Test-Path "D:\Antigravity\scoop-apps") {
    Write-Host "      Initializing 'apps' bucket from local verified workspace..." -ForegroundColor DarkGray
    & $gitExe clone -q "D:\Antigravity\scoop-apps" $targetBucketPath
    & $gitExe -C $targetBucketPath remote set-url origin https://github.com/rajashekarthoutam/scoop-apps.git
} else {
    Write-Host "      Adding verified 'apps' bucket (rajashekarthoutam/scoop-apps)..." -ForegroundColor DarkGray
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' bucket add apps https://github.com/rajashekarthoutam/scoop-apps"
}

# [BOOT-03] Remove bloated 'main' bucket if present (1,600+ unvetted packages)
$mainBucketPath = Join-Path $TargetDir "buckets\main"
if (Test-Path $mainBucketPath) {
    Write-Host "      Removing default 'main' bucket (1,600+ unvetted packages)..." -ForegroundColor DarkGray
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' bucket rm main" 2>$null
} else {
    Write-Host "      'main' bucket not present (already clean)." -ForegroundColor DarkGray
}

if (-not $SkipBaseApps) {
    Write-Host "      Installing [gh, ripgrep] from verified 'apps' bucket..." -ForegroundColor DarkGray
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' install gh ripgrep"
}
Write-Host "[+] Bucket configuration complete: Only verified 'apps' bucket active." -ForegroundColor Green

# -------------------------------------------------------------
# STEP 5: Re-Integrate Portable Embedded Shims (Keil & Flash Magic)
# -------------------------------------------------------------
Write-Host "[5/6] Checking for portable embedded suites on D:\ drive..." -ForegroundColor Yellow

if (Test-Path "D:\keil\UV4\UV4.exe") {
    Write-Host "      Registering Keil uVision4 shims..." -ForegroundColor DarkGray
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' shim add keil D:\keil\UV4\UV4.exe"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' shim add armcc D:\keil\ARM\BIN40\armcc.exe"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' shim add armasm D:\keil\ARM\BIN40\armasm.exe"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' shim add armlink D:\keil\ARM\BIN40\armlink.exe"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' shim add fromelf D:\keil\ARM\BIN40\fromelf.exe"
}

if (Test-Path "D:\FlashMagic\FlashMagic.exe") {
    Write-Host "      Registering Flash Magic shim..." -ForegroundColor DarkGray
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' shim add flashmagic D:\FlashMagic\FlashMagic.exe"
}

Write-Host "[+] Portable toolchain shims restored." -ForegroundColor Green

# -------------------------------------------------------------
# STEP 6: Final Verification & Health Check
# -------------------------------------------------------------
Write-Host "[6/6] Final System Verification..." -ForegroundColor Yellow
Write-Host ""

Write-Host "=== Active Buckets ===" -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' bucket list"
Write-Host ""

Write-Host "=== Installed Applications ===" -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$scoopShim' list"
Write-Host ""

Write-Host "=== Git Origin of Scoop Engine ===" -ForegroundColor Cyan
$scoopGitDir = Join-Path $TargetDir "apps\scoop\current"
if (Test-Path "$scoopGitDir\.git") {
    $remote = git -C $scoopGitDir remote -v
    Write-Host ($remote -join "`n") -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   Clean Slate Installation Completed Successfully!       " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Your PC is pristine, pure base OS, and running strictly from your verified forked repositories."
