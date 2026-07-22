#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

. (Join-Path $PSScriptRoot "windows-check-helpers.ps1")

$foundryBin = Join-Path $HOME ".foundry\bin"
if (Test-Path $foundryBin) {
    $env:Path = "$foundryBin;$env:Path"
}

$forgeCommand = Get-Command forge -CommandType Application -ErrorAction SilentlyContinue
if (-not $forgeCommand) {
    throw "forge was not found. Run scripts\bootstrap-windows.ps1, then retry this command."
}

$forgePath = $forgeCommand.Source

function forge {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    Invoke-CheckedNative -FilePath $script:forgePath -Arguments $Arguments
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

$pythonExecutable = $pythonPath
$pythonBaseArgs = $pythonArgs

function Invoke-CheckedPython {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )

    Invoke-CheckedNative -FilePath $script:pythonExecutable -Arguments ($script:pythonBaseArgs + $Arguments)
}

$pythonPath = "Invoke-CheckedPython"
$pythonArgs = @()

& (Join-Path $PSScriptRoot "test_windows_check_helpers.ps1")
forge build
forge test -vvv
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
& $pythonPath @pythonArgs "scripts\test_gas_envelopes.py"
& $pythonPath @pythonArgs "scripts\check_gas_envelopes.py"
& $pythonPath @pythonArgs "scripts\run_forge_size_log.py" "--log" "cache\forge-size.log"
& $pythonPath @pythonArgs "scripts\test_contract_size_budget.py"
& $pythonPath @pythonArgs "scripts\check_contract_size_budget.py"
& $pythonPath @pythonArgs "scripts\test_core_bytecode_spend_policy.py"
& $pythonPath @pythonArgs "scripts\check_core_bytecode_spend_policy.py"
& $pythonPath @pythonArgs "scripts\test_genesis_deployment_profile.py"
& $pythonPath @pythonArgs "scripts\check_genesis_deployment_profile.py"
& $pythonPath @pythonArgs "scripts\test_system_manifest_payload_vector.py"
& $pythonPath @pythonArgs "scripts\check_system_manifest_payload_vector.py"
& $pythonPath @pythonArgs "scripts\test_slither_baseline.py"
& $pythonPath @pythonArgs "scripts\check_slither_baseline.py" "--baseline-only"
& $pythonPath @pythonArgs "scripts\test_solidity_formatting.py"
& $pythonPath @pythonArgs "scripts\check_solidity_formatting.py"
& $pythonPath @pythonArgs "scripts\test_windows_check_wrapper.py"
& $pythonPath @pythonArgs "scripts\test_python_toolchain.py"
& $pythonPath @pythonArgs "scripts\check_python_toolchain.py"
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
& $pythonPath @pythonArgs "scripts\test_one_of_one_provenance_manifest.py"
& $pythonPath @pythonArgs "scripts\check_one_of_one_provenance_manifest.py"
& $pythonPath @pythonArgs "scripts\generate_one_of_one_provenance_manifest.py" "--check"
& $pythonPath @pythonArgs "scripts\test_admin_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\check_admin_ceremony_evidence.py"
forge build --force --via-ir --skip test script
& $pythonPath @pythonArgs "scripts\test_release_artifacts.py"
& $pythonPath @pythonArgs "scripts\generate_release_artifacts.py" "--check"
& $pythonPath @pythonArgs "scripts\test_protocol_surface_report.py"
& $pythonPath @pythonArgs "scripts\generate_protocol_surface_report.py" "--check"
& $pythonPath @pythonArgs "scripts\test_custom_error_catalog.py"
& $pythonPath @pythonArgs "scripts\generate_custom_error_catalog.py" "--check"
& $pythonPath @pythonArgs "scripts\test_natspec_coverage.py"
& $pythonPath @pythonArgs "scripts\check_natspec_coverage.py"
& $pythonPath @pythonArgs "scripts\test_source_verification_inputs.py"
& $pythonPath @pythonArgs "scripts\generate_source_verification_inputs.py" "--check"
& $pythonPath @pythonArgs "scripts\test_dependency_artifact_manifest.py"
& $pythonPath @pythonArgs "scripts\generate_dependency_artifact_manifest.py" "--check"
& $pythonPath @pythonArgs "scripts\test_dependency_provenance_attestation.py"
& $pythonPath @pythonArgs "scripts\generate_dependency_provenance_attestation.py" "--check"
& $pythonPath @pythonArgs "scripts\test_abi_compatibility.py"
& $pythonPath @pythonArgs "scripts\check_abi_compatibility.py" "--check"
& $pythonPath @pythonArgs "scripts\test_broadcast_manifest_input.py"
& $pythonPath @pythonArgs "scripts\generate_broadcast_manifest_input.py" "--check"
& $pythonPath @pythonArgs "scripts\generate_broadcast_manifest_input.py" "--template" "deployments\config\fork-mainnet-6529stream-v0.1.0-001.json" "--broadcast" "deployments\broadcasts\fork-mainnet-6529stream-v0.1.0-001-run-latest.json" "--output" "deployments\config\fork-mainnet-6529stream-v0.1.0-001-broadcast.json" "--manifest-output" "deployments\examples\fork-mainnet-6529stream-v0.1.0-001-broadcast.json" "--check"
& $pythonPath @pythonArgs "scripts\test_deployment_manifest.py"
& $pythonPath @pythonArgs "scripts\generate_deployment_manifest.py" "--check"
& $pythonPath @pythonArgs "scripts\generate_deployment_manifest.py" "--config" "deployments\config\fork-mainnet-6529stream-v0.1.0-001.json" "--check"
& $pythonPath @pythonArgs "scripts\generate_deployment_manifest.py" "--config" "deployments\config\anvil-6529stream-v0.1.0-001-broadcast.json" "--check"
& $pythonPath @pythonArgs "scripts\generate_deployment_manifest.py" "--config" "deployments\config\fork-mainnet-6529stream-v0.1.0-001-broadcast.json" "--check"
& $pythonPath @pythonArgs "scripts\test_address_books.py"
& $pythonPath @pythonArgs "scripts\generate_address_books.py" "--check"
& $pythonPath @pythonArgs "scripts\test_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\check_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\test_randomizer_operations.py"
& $pythonPath @pythonArgs "scripts\check_randomizer_operations.py"
& $pythonPath @pythonArgs "scripts\test_release_signatures.py"
& $pythonPath @pythonArgs "scripts\check_release_signatures.py"
& $pythonPath @pythonArgs "scripts\test_signed_release_tag.py"
& $pythonPath @pythonArgs "scripts\check_signed_release_tag.py"
& $pythonPath @pythonArgs "scripts\test_non_local_release_evidence_generator.py"
& $pythonPath @pythonArgs "scripts\test_non_local_release_evidence.py"
& $pythonPath @pythonArgs "scripts\check_non_local_release_evidence.py"
& $pythonPath @pythonArgs "scripts\test_external_audit_report_evidence.py"
& $pythonPath @pythonArgs "scripts\check_external_audit_report_evidence.py"
& $pythonPath @pythonArgs "scripts\test_post_audit_remediation_evidence.py"
& $pythonPath @pythonArgs "scripts\check_post_audit_remediation_evidence.py"
& $pythonPath @pythonArgs "scripts\test_live_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\check_live_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\test_live_randomizer_operations_evidence.py"
& $pythonPath @pythonArgs "scripts\check_live_randomizer_operations_evidence.py"
& $pythonPath @pythonArgs "scripts\test_fork_deployment_rehearsal_evidence.py"
& $pythonPath @pythonArgs "scripts\check_fork_deployment_rehearsal_evidence.py"
& $pythonPath @pythonArgs "scripts\test_testnet_deployment_rehearsal_evidence.py"
& $pythonPath @pythonArgs "scripts\check_testnet_deployment_rehearsal_evidence.py"
& $pythonPath @pythonArgs "scripts\test_sepolia_evidence_preflight.py"
& $pythonPath @pythonArgs "scripts\check_sepolia_evidence_preflight.py"
& $pythonPath @pythonArgs "scripts\test_public_beta_verified_addresses.py"
& $pythonPath @pythonArgs "scripts\check_public_beta_verified_addresses.py"
& $pythonPath @pythonArgs "scripts\test_production_broadcast_retention.py"
& $pythonPath @pythonArgs "scripts\check_production_broadcast_retention.py"
& $pythonPath @pythonArgs "scripts\test_live_deployment_manifest_evidence.py"
& $pythonPath @pythonArgs "scripts\check_live_deployment_manifest_evidence.py"
& $pythonPath @pythonArgs "scripts\test_production_verified_addresses.py"
& $pythonPath @pythonArgs "scripts\check_production_verified_addresses.py"
& $pythonPath @pythonArgs "scripts\test_production_release_signing_evidence.py"
& $pythonPath @pythonArgs "scripts\check_production_release_signing_evidence.py"
& $pythonPath @pythonArgs "scripts\test_generate_fork_metadata_browser_evidence_draft.py"
& $pythonPath @pythonArgs "scripts\test_fork_metadata_browser_evidence.py"
& $pythonPath @pythonArgs "scripts\check_fork_metadata_browser_evidence.py"
& $pythonPath @pythonArgs "scripts\test_fork_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\check_fork_ceremony_evidence.py"
& $pythonPath @pythonArgs "scripts\test_fork_randomizer_operations_evidence.py"
& $pythonPath @pythonArgs "scripts\check_fork_randomizer_operations_evidence.py"
& $pythonPath @pythonArgs "scripts\test_live_metadata_browser_evidence.py"
& $pythonPath @pythonArgs "scripts\check_live_metadata_browser_evidence.py"
& $pythonPath @pythonArgs "scripts\test_marketplace_indexer_evidence.py"
& $pythonPath @pythonArgs "scripts\check_marketplace_indexer_evidence.py"
& $pythonPath @pythonArgs "scripts\test_incident_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\check_incident_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\test_signer_compromise_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\check_signer_compromise_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\test_stuck_auction_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\check_stuck_auction_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\test_failed_randomness_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\check_failed_randomness_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\test_bad_metadata_dependency_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\check_bad_metadata_dependency_drill_evidence.py"
& $pythonPath @pythonArgs "scripts\test_public_beta_evidence.py"
& $pythonPath @pythonArgs "scripts\check_public_beta_evidence.py"
& $pythonPath @pythonArgs "scripts\test_risk_register.py"
& $pythonPath @pythonArgs "scripts\check_risk_register.py"
& $pythonPath @pythonArgs "scripts\generate_risk_register.py" "--check"
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
& $pythonPath @pythonArgs "scripts\test_mint_manager_domain_constants.py"
& $pythonPath @pythonArgs "scripts\check_mint_manager_domain_constants.py"
& $pythonPath @pythonArgs "scripts\test_audit_package.py"
& $pythonPath @pythonArgs "scripts\check_audit_package.py"
& $pythonPath @pythonArgs "scripts\test_audit_finding_workflow.py"
& $pythonPath @pythonArgs "scripts\check_audit_finding_workflow.py"
& $pythonPath @pythonArgs "scripts\test_incident_response.py"
& $pythonPath @pythonArgs "scripts\check_incident_response.py"
& $pythonPath @pythonArgs "scripts\test_readme.py"
& $pythonPath @pythonArgs "scripts\check_readme.py"
& $pythonPath @pythonArgs "scripts\test_first_30_minutes.py"
& $pythonPath @pythonArgs "scripts\check_first_30_minutes.py"
& $pythonPath @pythonArgs "scripts\test_issue_templates.py"
& $pythonPath @pythonArgs "scripts\check_issue_templates.py"
& $pythonPath @pythonArgs "scripts\test_pr_template.py"
& $pythonPath @pythonArgs "scripts\check_pr_template.py"
& $pythonPath @pythonArgs "scripts\test_autonomous_state.py"
& $pythonPath @pythonArgs "scripts\check_autonomous_state.py"
& $pythonPath @pythonArgs "scripts\test_markdown_links.py"
& $pythonPath @pythonArgs "scripts\check_markdown_links.py"
& $pythonPath @pythonArgs "scripts\test_integrations_readme.py"
& $pythonPath @pythonArgs "scripts\check_integrations_readme.py"
& $pythonPath @pythonArgs "scripts\test_contract_flows.py"
& $pythonPath @pythonArgs "scripts\check_contract_flows.py"
& $pythonPath @pythonArgs "scripts\test_auction_flows.py"
& $pythonPath @pythonArgs "scripts\check_auction_flows.py"
& $pythonPath @pythonArgs "scripts\test_curator_rewards_flow.py"
& $pythonPath @pythonArgs "scripts\check_curator_rewards_flow.py"
& $pythonPath @pythonArgs "scripts\test_withdrawals_credits_flow.py"
& $pythonPath @pythonArgs "scripts\check_withdrawals_credits_flow.py"
& $pythonPath @pythonArgs "scripts\test_wallet_signature_flows.py"
& $pythonPath @pythonArgs "scripts\check_wallet_signature_flows.py"
& $pythonPath @pythonArgs "scripts\test_events_and_indexing.py"
& $pythonPath @pythonArgs "scripts\check_events_and_indexing.py"
& $pythonPath @pythonArgs "scripts\test_metadata_rendering.py"
& $pythonPath @pythonArgs "scripts\check_metadata_rendering.py"
& $pythonPath @pythonArgs "scripts\test_react_next_reference.py"
& $pythonPath @pythonArgs "scripts\check_react_next_reference.py"
& $pythonPath @pythonArgs "scripts\test_typescript_artifact_chain_config.py"
& $pythonPath @pythonArgs "scripts\check_typescript_artifact_chain_config.py"
& $pythonPath @pythonArgs "scripts\test_typescript_eip712_drop_authorization.py"
& $pythonPath @pythonArgs "scripts\check_typescript_eip712_drop_authorization.py"
& $pythonPath @pythonArgs "scripts\test_typescript_event_decoding_indexer.py"
& $pythonPath @pythonArgs "scripts\check_typescript_event_decoding_indexer.py"
& $pythonPath @pythonArgs "scripts\test_integration_conformance_fixtures.py"
& $pythonPath @pythonArgs "scripts\check_integration_conformance_fixtures.py"
& $pythonPath @pythonArgs "scripts\test_mobile_walletconnect.py"
& $pythonPath @pythonArgs "scripts\check_mobile_walletconnect.py"
& $pythonPath @pythonArgs "scripts\test_electron_security_wallets.py"
& $pythonPath @pythonArgs "scripts\check_electron_security_wallets.py"
& $pythonPath @pythonArgs "scripts\test_operator_admin_ui.py"
& $pythonPath @pythonArgs "scripts\check_operator_admin_ui.py"
& $pythonPath @pythonArgs "scripts\test_operator_dashboard_query_model.py"
& $pythonPath @pythonArgs "scripts\check_operator_dashboard_query_model.py"
& $pythonPath @pythonArgs "scripts\test_monitoring_spec.py"
& $pythonPath @pythonArgs "scripts\check_monitoring_spec.py"
& $pythonPath @pythonArgs "scripts\test_royalty_policy.py"
& $pythonPath @pythonArgs "scripts\check_royalty_policy.py"
& $pythonPath @pythonArgs "scripts\test_warning_dispositions.py"
& $pythonPath @pythonArgs "scripts\check_warning_dispositions.py" "--solc-warnings-log" "cache\forge-size.log"
& $pythonPath @pythonArgs "scripts\test_one_of_one_permanence_package.py"
& $pythonPath @pythonArgs "scripts\check_one_of_one_permanence_package.py"
& $pythonPath @pythonArgs "scripts\generate_one_of_one_permanence_manifest.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_readiness.py"
& $pythonPath @pythonArgs "scripts\check_release_readiness.py"
& $pythonPath @pythonArgs "scripts\test_release_mode.py"
& $pythonPath @pythonArgs "scripts\test_release_notes.py"
& $pythonPath @pythonArgs "scripts\generate_release_notes.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_manifest.py"
& $pythonPath @pythonArgs "scripts\generate_release_manifest.py" "--check"
& $pythonPath @pythonArgs "scripts\test_bytecode_release_proof.py"
& $pythonPath @pythonArgs "scripts\generate_bytecode_release_proof.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_candidate_lockfile.py"
& $pythonPath @pythonArgs "scripts\generate_release_candidate_lockfile.py" "--check"
& $pythonPath @pythonArgs "scripts\test_release_checksums.py"
& $pythonPath @pythonArgs "scripts\generate_release_checksums.py" "--check"
& $pythonPath @pythonArgs "scripts\test_verify_release_artifacts.py"
& $pythonPath @pythonArgs "scripts\verify_release_artifacts.py"
& $pythonPath @pythonArgs "scripts\test_changelog_check.py"
& $pythonPath @pythonArgs "scripts\check_changelog.py"
& $pythonPath @pythonArgs "scripts\test_deployment_rehearsal_gate.py"
& $pythonPath @pythonArgs "scripts\check_deployment_rehearsal_gate.py"
forge script script/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
