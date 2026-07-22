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

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE."
    }
}

function Resolve-Python {
    $pythonCommand = Get-Command python -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notmatch "\\WindowsApps\\" } |
        Select-Object -First 1

    if ($pythonCommand) {
        return @{
            FilePath = $pythonCommand.Source
            Arguments = @()
        }
    }

    $pyLauncher = Get-Command py -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($pyLauncher) {
        return @{
            FilePath = $pyLauncher.Source
            Arguments = @("-3")
        }
    }

    throw "Python 3.8+ is required. Install Python from python.org or install the py launcher, then re-run this script."
}

New-Item -ItemType Directory -Force $tempDir | Out-Null
New-Item -ItemType Directory -Force $InstallDir | Out-Null

Write-Host "Downloading Foundry $Version..."
Invoke-WebRequest -UseBasicParsing -Uri "$releaseBase/$assetName" -OutFile $archivePath
Invoke-WebRequest -UseBasicParsing -Uri "$releaseBase/$checksumName" -OutFile $checksumPath

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
Invoke-Native -FilePath (Join-Path $InstallDir "forge.exe") -Arguments @("--version")

Set-Location $repoRoot
$python = Resolve-Python
Invoke-Native -FilePath $python.FilePath -Arguments ($python.Arguments + @("-m", "venv", ".venv-tools"))
$toolPython = Join-Path $repoRoot ".venv-tools\Scripts\python.exe"
if (-not (Test-Path $toolPython)) {
    throw "Python virtual environment was not created at $toolPython."
}
Invoke-Native -FilePath $toolPython -Arguments @("-m", "pip", "install", "--disable-pip-version-check", "-r", "requirements-tools.txt")
Invoke-Native -FilePath $toolPython -Arguments @("-m", "playwright", "install", "chromium")
Invoke-Native -FilePath (Join-Path $repoRoot ".venv-tools\Scripts\solc-select.exe") -Arguments @("install", "0.8.19")
Invoke-Native -FilePath (Join-Path $repoRoot ".venv-tools\Scripts\solc-select.exe") -Arguments @("use", "0.8.19")

Write-Host ""
Write-Host "Bootstrap complete. This shell can now run:"
Write-Host "  forge build"
Write-Host "  forge test -vvv"
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\check.ps1"
