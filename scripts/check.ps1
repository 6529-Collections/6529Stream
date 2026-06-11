#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$foundryBin = Join-Path $HOME ".foundry\bin"
if (Test-Path $foundryBin) {
    $env:Path = "$foundryBin;$env:Path"
}

if (-not (Get-Command forge -ErrorAction SilentlyContinue)) {
    throw "forge was not found. Run scripts\bootstrap-windows.ps1, then retry this command."
}

forge build
forge test -vvv
forge build --sizes --via-ir --skip test --skip script --force
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
