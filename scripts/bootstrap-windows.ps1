#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Version = $(if ($env:FOUNDRY_VERSION) { $env:FOUNDRY_VERSION } else { "v1.7.1" }),
    [string]$InstallDir = $(Join-Path $HOME ".foundry\bin"),
    [switch]$SkipPathUpdate
)

$ErrorActionPreference = "Stop"

if (-not $Version.StartsWith("v")) {
    $Version = "v$Version"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$assetName = "foundry_${Version}_win32_amd64.zip"
$checksumName = "foundry_${Version}_win32_amd64.sha256"
$releaseBase = "https://github.com/foundry-rs/foundry/releases/download/$Version"
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "6529stream-foundry-$Version"
$archivePath = Join-Path $tempDir $assetName
$checksumPath = Join-Path $tempDir $checksumName

New-Item -ItemType Directory -Force $tempDir | Out-Null
New-Item -ItemType Directory -Force $InstallDir | Out-Null

Write-Host "Downloading Foundry $Version..."
Invoke-WebRequest -Uri "$releaseBase/$assetName" -OutFile $archivePath
Invoke-WebRequest -Uri "$releaseBase/$checksumName" -OutFile $checksumPath

$expectedHash = ((Get-Content $checksumPath | Select-Object -First 1) -split "\s+")[0].Trim().ToLowerInvariant()
$actualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($expectedHash -ne $actualHash) {
    throw "SHA256 mismatch for $assetName. Expected $expectedHash, got $actualHash."
}

Expand-Archive -Force $archivePath $InstallDir

if (-not $SkipPathUpdate) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathParts = @()
    if ($userPath) {
        $pathParts = $userPath -split ";" | Where-Object { $_ -ne "" }
    }

    $normalizedInstallDir = $InstallDir.TrimEnd("\")
    $alreadyPresent = $pathParts | Where-Object { $_.TrimEnd("\") -ieq $normalizedInstallDir }
    if (-not $alreadyPresent) {
        [Environment]::SetEnvironmentVariable("Path", (($pathParts + $InstallDir) -join ";"), "User")
        Write-Host "Added $InstallDir to the user PATH. Open a new terminal to use it automatically."
    }
}

$env:Path = "$InstallDir;$env:Path"
& (Join-Path $InstallDir "forge.exe") --version

Set-Location $repoRoot
python -m venv .venv-tools
$toolPython = Join-Path $repoRoot ".venv-tools\Scripts\python.exe"
& $toolPython -m pip install --upgrade pip
& $toolPython -m pip install -r requirements-tools.txt
& (Join-Path $repoRoot ".venv-tools\Scripts\solc-select.exe") install 0.8.19
& (Join-Path $repoRoot ".venv-tools\Scripts\solc-select.exe") use 0.8.19

Write-Host ""
Write-Host "Bootstrap complete. This shell can now run:"
Write-Host "  forge build"
Write-Host "  forge test -vvv"
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\check.ps1"
