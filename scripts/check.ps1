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

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$pythonArgs = @()
if (-not $pythonCommand) {
    $pythonCommand = Get-Command py -ErrorAction SilentlyContinue
    $pythonArgs = @("-3")
}
if (-not $pythonCommand) {
    throw "python or py was not found. Install Python 3, then retry this command."
}

forge build
forge test -vvv
forge build --sizes --via-ir --skip test --skip script --force
& $pythonCommand.Source @pythonArgs "scripts\test_release_artifacts.py"
& $pythonCommand.Source @pythonArgs "scripts\generate_release_artifacts.py" "--check"
& $pythonCommand.Source @pythonArgs "scripts\test_abi_compatibility.py"
& $pythonCommand.Source @pythonArgs "scripts\check_abi_compatibility.py" "--check"
& $pythonCommand.Source @pythonArgs "scripts\test_deployment_manifest.py"
& $pythonCommand.Source @pythonArgs "scripts\generate_deployment_manifest.py" "--check"
& $pythonCommand.Source @pythonArgs "scripts\test_address_books.py"
& $pythonCommand.Source @pythonArgs "scripts\generate_address_books.py" "--check"
& $pythonCommand.Source @pythonArgs "scripts\test_release_checksums.py"
& $pythonCommand.Source @pythonArgs "scripts\generate_release_checksums.py" "--check"
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
