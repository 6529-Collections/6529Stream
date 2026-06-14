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

$venvPython = Join-Path $repoRoot ".venv-tools\Scripts\python.exe"
$pythonPath = $null
$pythonArgs = @()
if (Test-Path $venvPython) {
    $pythonPath = (Resolve-Path $venvPython).Path
}
if (-not $pythonPath) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand) {
        $pythonPath = $pythonCommand.Source
    }
}
if (-not $pythonPath) {
    $pythonCommand = Get-Command py -ErrorAction SilentlyContinue
    $pythonArgs = @("-3")
    if ($pythonCommand) {
        $pythonPath = $pythonCommand.Source
    }
}
if (-not $pythonPath) {
    throw "python or py was not found. Install Python 3, then retry this command."
}

forge build
forge test -vvv
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
forge build --sizes --via-ir --skip test --skip script --force
& $pythonPath @pythonArgs "scripts\test_metadata_fixtures.py"
& $pythonPath @pythonArgs "scripts\check_metadata_fixtures.py"
& $pythonPath @pythonArgs "scripts\test_metadata_browser_sandbox.py"
& $pythonPath @pythonArgs "scripts\check_metadata_browser_sandbox.py"
& $pythonPath @pythonArgs "scripts\test_rehearsal_metadata_browser_sandbox.py"
& $pythonPath @pythonArgs "scripts\check_rehearsal_metadata_browser_sandbox.py"
& $pythonPath @pythonArgs "scripts\test_drop_authorization_payload_generator.py"
& $pythonPath @pythonArgs "scripts\generate_drop_authorization_payload.py" "--input" "test\fixtures\drop-authorization\payload-generator\fixed-price-input.json" "--output" "test\fixtures\drop-authorization\payload-generator\fixed-price-output.json" "--check"
& $pythonPath @pythonArgs "scripts\generate_drop_authorization_payload.py" "--input" "test\fixtures\drop-authorization\payload-generator\auction-input.json" "--output" "test\fixtures\drop-authorization\payload-generator\auction-output.json" "--check"
& $pythonPath @pythonArgs "scripts\test_drop_authorization_fixtures.py"
& $pythonPath @pythonArgs "scripts\check_drop_authorization_fixtures.py"
& $pythonPath @pythonArgs "scripts\test_drop_authorization_signing_evidence.py"
& $pythonPath @pythonArgs "scripts\check_drop_authorization_signing_evidence.py"
& $pythonPath @pythonArgs "scripts\test_signer_custody_readiness.py"
& $pythonPath @pythonArgs "scripts\check_signer_custody_readiness.py"
& $pythonPath @pythonArgs "scripts\test_release_artifacts.py"
& $pythonPath @pythonArgs "scripts\generate_release_artifacts.py" "--check"
& $pythonPath @pythonArgs "scripts\test_source_verification_inputs.py"
& $pythonPath @pythonArgs "scripts\generate_source_verification_inputs.py" "--check"
& $pythonPath @pythonArgs "scripts\test_dependency_artifact_manifest.py"
& $pythonPath @pythonArgs "scripts\generate_dependency_artifact_manifest.py" "--check"
& $pythonPath @pythonArgs "scripts\test_abi_compatibility.py"
& $pythonPath @pythonArgs "scripts\check_abi_compatibility.py" "--check"
& $pythonPath @pythonArgs "scripts\test_broadcast_manifest_input.py"
& $pythonPath @pythonArgs "scripts\generate_broadcast_manifest_input.py" "--check"
& $pythonPath @pythonArgs "scripts\test_deployment_manifest.py"
& $pythonPath @pythonArgs "scripts\generate_deployment_manifest.py" "--check"
& $pythonPath @pythonArgs "scripts\generate_deployment_manifest.py" "--config" "deployments\config\anvil-6529stream-v0.1.0-001-broadcast.json" "--check"
& $pythonPath @pythonArgs "scripts\test_address_books.py"
& $pythonPath @pythonArgs "scripts\generate_address_books.py" "--check"
& $pythonPath @pythonArgs "scripts\test_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\check_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\test_randomizer_operations.py"
& $pythonPath @pythonArgs "scripts\check_randomizer_operations.py"
& $pythonPath @pythonArgs "scripts\test_release_signatures.py"
& $pythonPath @pythonArgs "scripts\check_release_signatures.py"
& $pythonPath @pythonArgs "scripts\test_non_local_release_evidence_generator.py"
& $pythonPath @pythonArgs "scripts\test_non_local_release_evidence.py"
& $pythonPath @pythonArgs "scripts\check_non_local_release_evidence.py"
& $pythonPath @pythonArgs "scripts\test_public_beta_evidence.py"
& $pythonPath @pythonArgs "scripts\check_public_beta_evidence.py"
& $pythonPath @pythonArgs "scripts\test_public_beta_blocker_report.py"
& $pythonPath @pythonArgs "scripts\generate_public_beta_blocker_report.py" "--check"
& $pythonPath @pythonArgs "scripts\test_production_release_blocker_report.py"
& $pythonPath @pythonArgs "scripts\generate_production_release_blocker_report.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_evidence_packet_index.py"
& $pythonPath @pythonArgs "scripts\generate_release_evidence_packet_index.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_evidence_issue_backlog.py"
& $pythonPath @pythonArgs "scripts\generate_release_evidence_issue_backlog.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_evidence_issue_links.py"
& $pythonPath @pythonArgs "scripts\check_release_evidence_issue_links.py"
& $pythonPath @pythonArgs "scripts\test_release_evidence_issue_snapshot.py"
& $pythonPath @pythonArgs "scripts\test_release_evidence_issue_snapshot_audit.py"
& $pythonPath @pythonArgs "scripts\test_release_evidence_issue_labels.py"
& $pythonPath @pythonArgs "scripts\check_release_evidence_issue_labels.py"
& $pythonPath @pythonArgs "scripts\test_release_evidence_issue_body_sync.py"
& $pythonPath @pythonArgs "scripts\generate_release_evidence_issue_body_sync.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_evidence_issue_bodies.py"
& $pythonPath @pythonArgs "scripts\check_release_evidence_issue_bodies.py"
& $pythonPath @pythonArgs "scripts\test_release_evidence_issue_closure.py"
& $pythonPath @pythonArgs "scripts\check_release_evidence_issue_closure.py"
& $pythonPath @pythonArgs "scripts\test_release_evidence_live_audit_report.py"
& $pythonPath @pythonArgs "scripts\check_release_evidence_live_audit_report.py"
& $pythonPath @pythonArgs "scripts\test_release_evidence_live_audit_markdown.py"
& $pythonPath @pythonArgs "scripts\check_release_evidence_live_audit_markdown.py"
& $pythonPath @pythonArgs "scripts\test_release_evidence_live_audit_archive.py"
& $pythonPath @pythonArgs "scripts\generate_release_evidence_live_audit_archive.py" "--check"
& $pythonPath @pythonArgs "scripts\test_architecture_threat_model.py"
& $pythonPath @pythonArgs "scripts\check_architecture_threat_model.py"
& $pythonPath @pythonArgs "scripts\test_audit_package.py"
& $pythonPath @pythonArgs "scripts\check_audit_package.py"
& $pythonPath @pythonArgs "scripts\test_incident_response.py"
& $pythonPath @pythonArgs "scripts\check_incident_response.py"
& $pythonPath @pythonArgs "scripts\test_release_readiness.py"
& $pythonPath @pythonArgs "scripts\check_release_readiness.py"
& $pythonPath @pythonArgs "scripts\test_release_manifest.py"
& $pythonPath @pythonArgs "scripts\generate_release_manifest.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_checksums.py"
& $pythonPath @pythonArgs "scripts\generate_release_checksums.py" "--check"
& $pythonPath @pythonArgs "scripts\test_changelog_check.py"
& $pythonPath @pythonArgs "scripts\check_changelog.py"
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
