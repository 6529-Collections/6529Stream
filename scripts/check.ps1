#Requires -Version 5.1
[CmdletBinding()]
param([switch]$CurrentStack)

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
if ($CurrentStack) {
    $previousFoundryProfile = [Environment]::GetEnvironmentVariable("FOUNDRY_PROFILE")
    try {
        $env:FOUNDRY_PROFILE = "current"
        forge build
        forge test -vvv
        & $pythonPath @pythonArgs "-m" "tools.build.test_release_artifacts"
        & $pythonPath @pythonArgs "-m" "tools.deployment.test_current_stack_artifacts"
        & $pythonPath @pythonArgs "-m" "tools.deployment.test_prepare_current_stack_compilation"
        & $pythonPath @pythonArgs "-m" "tools.deployment.test_current_stack_deployment_verification"
        & $pythonPath @pythonArgs "-m" "tools.deployment.test_current_stack_observations"
        & $pythonPath @pythonArgs "-m" "tools.build.check_solidity_formatting"
        & $pythonPath @pythonArgs "-m" "tools.build.check_solidity_source_layout"
        & $pythonPath @pythonArgs "-m" "tools.build.check_abi_compatibility" "--target-only"
    }
    finally {
        [Environment]::SetEnvironmentVariable("FOUNDRY_PROFILE", $previousFoundryProfile)
    }
    return
}

forge build
forge test -vvv
forge snapshot --match-path test/gas/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
& $pythonPath @pythonArgs "-m" "tools.protocol.test_gas_envelopes"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_gas_envelopes"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_external_call_gas_inventory"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_external_call_gas_inventory"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_post_entropy_completion_gas"
& $pythonPath @pythonArgs "-m" "tools.protocol.generate_post_entropy_completion_gas" "--check"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_post_entropy_completion_gas"
forge test --via-ir --match-path test/gas/StreamPostEntropyCompletionGas.t.sol -vvv
forge snapshot --via-ir --match-path test/gas/StreamPostEntropyCompletionGas.t.sol --match-test testMeasureWorstCaseEoaPostCoordinatorTail --check release-artifacts/baselines/v0.1.0/post-entropy-completion-gas.snap
& $pythonPath @pythonArgs "-m" "tools.protocol.test_royalty_return_gas_buffer"
& $pythonPath @pythonArgs "-m" "tools.protocol.generate_royalty_return_gas_buffer" "--check"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_royalty_return_gas_buffer"
forge test --via-ir --match-path test/gas/StreamRoyaltyReturnGasBuffer.t.sol -vvv
forge snapshot --via-ir --match-path test/gas/StreamRoyaltyReturnGasBuffer.t.sol --match-test testMeasure --check release-artifacts/baselines/v0.1.0/royalty-return-gas-buffer.snap
& $pythonPath @pythonArgs "-m" "tools.build.run_forge_size_log" "--log" "cache\forge-size.log"
& $pythonPath @pythonArgs "-m" "tools.build.test_release_build_artifacts"
& $pythonPath @pythonArgs "-m" "tools.build.build_release_artifacts"
& $pythonPath @pythonArgs "-m" "tools.build.build_release_artifacts" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_canonical_deployment_candidate"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_canonical_deployment_candidate"
& $pythonExecutable @pythonBaseArgs "-m" "tools.deployment.check_canonical_deployment_candidate" "--require-complete"
$candidateStrictExit = $LASTEXITCODE
if ($candidateStrictExit -ne 1) {
    throw "expected incomplete canonical deployment candidate v2 to exit 1, got $candidateStrictExit"
}
& $pythonPath @pythonArgs "-m" "tools.deployment.test_materialize_canonical_deployment_plan"
& $pythonPath @pythonArgs "-m" "tools.deployment.materialize_canonical_deployment_plan" "--candidate" "deployments\config\canonical-deployment-candidate-non-production.json" "--output" "tmp\canonical-deployment-plan.json"
& $pythonPath @pythonArgs "-m" "tools.deployment.materialize_canonical_deployment_plan" "--candidate" "deployments\config\canonical-deployment-candidate-non-production.json" "--output" "tmp\canonical-deployment-plan.json" "--check"
& $pythonPath @pythonArgs "-m" "tools.build.test_contract_size_budget"
& $pythonPath @pythonArgs "-m" "tools.build.check_contract_size_budget"
& $pythonPath @pythonArgs "-m" "tools.build.test_core_bytecode_spend_policy"
& $pythonPath @pythonArgs "-m" "tools.build.check_core_bytecode_spend_policy"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_genesis_deployment_profile"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_genesis_deployment_profile"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_governed_parameter_identifiers"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_governed_parameter_identifiers"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_governed_parameter_inventory"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_governed_parameter_inventory"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_governance_action_policy"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_governance_action_policy"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_record_family_authorization"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_record_family_authorization"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_artist_semantic_owner_matrix"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_artist_semantic_owner_matrix"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_artist_record_event_reconstruction_correction"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_artist_record_event_reconstruction_correction"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_artist_owner_record_continuity"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_artist_owner_record_continuity"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_system_manifest_payload_vector"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_system_manifest_payload_vector"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_system_manifest_payload_vector_reference"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_system_manifest_payload_vector_reference"
& $pythonPath @pythonArgs "-m" "tools.security.test_slither_baseline"
& $pythonPath @pythonArgs "-m" "tools.security.check_slither_baseline" "--baseline-only"
& $pythonPath @pythonArgs "-m" "tools.build.test_solidity_formatting"
& $pythonPath @pythonArgs "-m" "tools.build.check_solidity_formatting"
& $pythonPath @pythonArgs "-m" "tools.build.test_solidity_source_layout"
& $pythonPath @pythonArgs "-m" "tools.build.check_solidity_source_layout"
& $pythonPath @pythonArgs "-m" "tools.build.test_solidity_layout_equivalence"
& $pythonPath @pythonArgs "-m" "tools.build.check_solidity_layout_equivalence" "--check-receipt"
& $pythonPath @pythonArgs "-m" "tools.development.check_legacy_snapshot"
& $pythonPath @pythonArgs "-m" "tools.development.test_windows_check_wrapper"
& $pythonPath @pythonArgs "-m" "tools.development.test_python_toolchain"
& $pythonPath @pythonArgs "-m" "tools.development.check_python_toolchain"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_metadata_fixtures"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_metadata_fixtures"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_metadata_browser_sandbox"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_metadata_browser_sandbox"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_rehearsal_metadata_browser_sandbox"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_rehearsal_metadata_browser_sandbox"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_drop_authorization_payload_generator"
& $pythonPath @pythonArgs "-m" "tools.protocol.generate_drop_authorization_payload" "--input" "test\fixtures\drop-authorization\payload-generator\fixed-price-input.json" "--output" "test\fixtures\drop-authorization\payload-generator\fixed-price-output.json" "--check"
& $pythonPath @pythonArgs "-m" "tools.protocol.generate_drop_authorization_payload" "--input" "test\fixtures\drop-authorization\payload-generator\auction-input.json" "--output" "test\fixtures\drop-authorization\payload-generator\auction-output.json" "--check"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_drop_authorization_fixtures"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_drop_authorization_fixtures"
& $pythonPath @pythonArgs "-m" "tools.release.test_drop_authorization_signing_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_drop_authorization_signing_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_signer_custody_readiness"
& $pythonPath @pythonArgs "-m" "tools.release.check_signer_custody_readiness"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_one_of_one_provenance_manifest"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_one_of_one_provenance_manifest"
& $pythonPath @pythonArgs "-m" "tools.protocol.generate_one_of_one_provenance_manifest" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_admin_ceremony_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_admin_ceremony_evidence"
& $pythonPath @pythonArgs "-m" "tools.build.test_release_artifacts"
& $pythonPath @pythonArgs "-m" "tools.build.generate_release_artifacts" "--check"
& $pythonPath @pythonArgs "-m" "tools.build.test_protocol_surface_report"
& $pythonPath @pythonArgs "-m" "tools.build.generate_protocol_surface_report" "--check"
& $pythonPath @pythonArgs "-m" "tools.build.test_custom_error_catalog"
& $pythonPath @pythonArgs "-m" "tools.build.generate_custom_error_catalog" "--check"
& $pythonPath @pythonArgs "-m" "tools.build.test_natspec_coverage"
& $pythonPath @pythonArgs "-m" "tools.build.check_natspec_coverage"
& $pythonPath @pythonArgs "-m" "tools.build.test_source_verification_inputs"
& $pythonPath @pythonArgs "-m" "tools.build.generate_source_verification_inputs" "--check"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_dependency_artifact_manifest"
& $pythonPath @pythonArgs "-m" "tools.protocol.generate_dependency_artifact_manifest" "--check"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_dependency_provenance_attestation"
& $pythonPath @pythonArgs "-m" "tools.protocol.generate_dependency_provenance_attestation" "--check"
& $pythonPath @pythonArgs "-m" "tools.build.test_abi_compatibility"
& $pythonPath @pythonArgs "-m" "tools.build.check_abi_compatibility" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_broadcast_manifest_input"
& $pythonPath @pythonArgs "-m" "tools.deployment.generate_broadcast_manifest_input" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.generate_broadcast_manifest_input" "--template" "deployments\config\fork-mainnet-6529stream-v0.1.0-001.json" "--broadcast" "deployments\broadcasts\fork-mainnet-6529stream-v0.1.0-001-run-latest.json" "--output" "deployments\config\fork-mainnet-6529stream-v0.1.0-001-broadcast.json" "--manifest-output" "deployments\examples\fork-mainnet-6529stream-v0.1.0-001-broadcast.json" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_deployment_manifest"
& $pythonPath @pythonArgs "-m" "tools.deployment.generate_deployment_manifest" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.generate_deployment_manifest" "--config" "deployments\config\fork-mainnet-6529stream-v0.1.0-001.json" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.generate_deployment_manifest" "--config" "deployments\config\anvil-6529stream-v0.1.0-001-broadcast.json" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.generate_deployment_manifest" "--config" "deployments\config\fork-mainnet-6529stream-v0.1.0-001-broadcast.json" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_address_books"
& $pythonPath @pythonArgs "-m" "tools.deployment.generate_address_books" "--check"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_ceremony_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_ceremony_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_randomizer_operations"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_randomizer_operations"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_signatures"
& $pythonPath @pythonArgs "-m" "tools.release.check_release_signatures"
& $pythonPath @pythonArgs "-m" "tools.release.test_signed_release_tag"
& $pythonPath @pythonArgs "-m" "tools.release.check_signed_release_tag"
& $pythonPath @pythonArgs "-m" "tools.release.test_non_local_release_evidence_generator"
& $pythonPath @pythonArgs "-m" "tools.release.test_non_local_release_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_non_local_release_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_external_audit_report_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_external_audit_report_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_post_audit_remediation_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_post_audit_remediation_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_live_ceremony_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_live_ceremony_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_live_randomizer_operations_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_live_randomizer_operations_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_fork_deployment_rehearsal_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_fork_deployment_rehearsal_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_testnet_deployment_rehearsal_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_testnet_deployment_rehearsal_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_sepolia_evidence_preflight"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_sepolia_evidence_preflight"
& $pythonPath @pythonArgs "-m" "tools.release.test_public_beta_verified_addresses"
& $pythonPath @pythonArgs "-m" "tools.release.check_public_beta_verified_addresses"
& $pythonPath @pythonArgs "-m" "tools.release.test_production_broadcast_retention"
& $pythonPath @pythonArgs "-m" "tools.release.check_production_broadcast_retention"
& $pythonPath @pythonArgs "-m" "tools.release.test_live_deployment_manifest_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_live_deployment_manifest_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_production_verified_addresses"
& $pythonPath @pythonArgs "-m" "tools.release.check_production_verified_addresses"
& $pythonPath @pythonArgs "-m" "tools.release.test_production_release_signing_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_production_release_signing_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_generate_fork_metadata_browser_evidence_draft"
& $pythonPath @pythonArgs "-m" "tools.release.test_fork_metadata_browser_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_fork_metadata_browser_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_fork_ceremony_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_fork_ceremony_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_fork_randomizer_operations_evidence"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_fork_randomizer_operations_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_live_metadata_browser_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_live_metadata_browser_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_marketplace_indexer_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_marketplace_indexer_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_incident_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_incident_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_signer_compromise_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_signer_compromise_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_stuck_auction_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_stuck_auction_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_failed_randomness_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_failed_randomness_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_bad_metadata_dependency_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_bad_metadata_dependency_drill_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.test_public_beta_evidence"
& $pythonPath @pythonArgs "-m" "tools.release.check_public_beta_evidence"
& $pythonPath @pythonArgs "-m" "tools.security.test_risk_register"
& $pythonPath @pythonArgs "-m" "tools.security.check_risk_register"
& $pythonPath @pythonArgs "-m" "tools.security.generate_risk_register" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_public_beta_blocker_report"
& $pythonPath @pythonArgs "-m" "tools.release.generate_public_beta_blocker_report" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_production_release_blocker_report"
& $pythonPath @pythonArgs "-m" "tools.release.generate_production_release_blocker_report" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_packet_index"
& $pythonPath @pythonArgs "-m" "tools.release.generate_release_evidence_packet_index" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_issue_backlog"
& $pythonPath @pythonArgs "-m" "tools.release.generate_release_evidence_issue_backlog" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_issue_links"
& $pythonPath @pythonArgs "-m" "tools.release.check_release_evidence_issue_links"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_issue_snapshot"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_issue_snapshot_audit"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_issue_labels"
& $pythonPath @pythonArgs "-m" "tools.release.check_release_evidence_issue_labels"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_issue_body_sync"
& $pythonPath @pythonArgs "-m" "tools.release.generate_release_evidence_issue_body_sync" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_issue_bodies"
& $pythonPath @pythonArgs "-m" "tools.release.check_release_evidence_issue_bodies"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_issue_closure"
& $pythonPath @pythonArgs "-m" "tools.release.check_release_evidence_issue_closure"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_live_audit_report"
& $pythonPath @pythonArgs "-m" "tools.release.check_release_evidence_live_audit_report"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_live_audit_markdown"
& $pythonPath @pythonArgs "-m" "tools.release.check_release_evidence_live_audit_markdown"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_evidence_live_audit_archive"
& $pythonPath @pythonArgs "-m" "tools.release.generate_release_evidence_live_audit_archive" "--check"
& $pythonPath @pythonArgs "-m" "tools.docs.test_architecture_threat_model"
& $pythonPath @pythonArgs "-m" "tools.docs.check_architecture_threat_model"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_mint_manager_domain_constants"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_mint_manager_domain_constants"
& $pythonPath @pythonArgs "-m" "tools.docs.test_audit_package"
& $pythonPath @pythonArgs "-m" "tools.docs.check_audit_package"
& $pythonPath @pythonArgs "-m" "tools.docs.test_audit_finding_workflow"
& $pythonPath @pythonArgs "-m" "tools.docs.check_audit_finding_workflow"
& $pythonPath @pythonArgs "-m" "tools.docs.test_incident_response"
& $pythonPath @pythonArgs "-m" "tools.docs.check_incident_response"
& $pythonPath @pythonArgs "-m" "tools.docs.test_readme"
& $pythonPath @pythonArgs "-m" "tools.docs.check_readme"
& $pythonPath @pythonArgs "-m" "tools.docs.test_first_30_minutes"
& $pythonPath @pythonArgs "-m" "tools.docs.check_first_30_minutes"
& $pythonPath @pythonArgs "-m" "tools.docs.test_issue_templates"
& $pythonPath @pythonArgs "-m" "tools.docs.check_issue_templates"
& $pythonPath @pythonArgs "-m" "tools.docs.test_pr_template"
& $pythonPath @pythonArgs "-m" "tools.docs.check_pr_template"
& $pythonPath @pythonArgs "-m" "tools.development.test_autonomous_state"
& $pythonPath @pythonArgs "-m" "tools.development.check_autonomous_state"
& $pythonPath @pythonArgs "-m" "tools.docs.test_markdown_links"
& $pythonPath @pythonArgs "-m" "tools.docs.check_markdown_links"
& $pythonPath @pythonArgs "-m" "tools.docs.test_integrations_readme"
& $pythonPath @pythonArgs "-m" "tools.docs.check_integrations_readme"
& $pythonPath @pythonArgs "-m" "tools.docs.test_contract_flows"
& $pythonPath @pythonArgs "-m" "tools.docs.check_contract_flows"
& $pythonPath @pythonArgs "-m" "tools.docs.test_auction_flows"
& $pythonPath @pythonArgs "-m" "tools.docs.check_auction_flows"
& $pythonPath @pythonArgs "-m" "tools.docs.test_curator_rewards_flow"
& $pythonPath @pythonArgs "-m" "tools.docs.check_curator_rewards_flow"
& $pythonPath @pythonArgs "-m" "tools.docs.test_withdrawals_credits_flow"
& $pythonPath @pythonArgs "-m" "tools.docs.check_withdrawals_credits_flow"
& $pythonPath @pythonArgs "-m" "tools.docs.test_wallet_signature_flows"
& $pythonPath @pythonArgs "-m" "tools.docs.check_wallet_signature_flows"
& $pythonPath @pythonArgs "-m" "tools.docs.test_events_and_indexing"
& $pythonPath @pythonArgs "-m" "tools.docs.check_events_and_indexing"
& $pythonPath @pythonArgs "-m" "tools.docs.test_metadata_rendering"
& $pythonPath @pythonArgs "-m" "tools.docs.check_metadata_rendering"
& $pythonPath @pythonArgs "-m" "tools.docs.test_react_next_reference"
& $pythonPath @pythonArgs "-m" "tools.docs.check_react_next_reference"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_typescript_artifact_chain_config"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_typescript_artifact_chain_config"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_typescript_eip712_drop_authorization"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_typescript_eip712_drop_authorization"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_typescript_event_decoding_indexer"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_typescript_event_decoding_indexer"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_integration_conformance_fixtures"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_integration_conformance_fixtures"
& $pythonPath @pythonArgs "-m" "tools.docs.test_mobile_walletconnect"
& $pythonPath @pythonArgs "-m" "tools.docs.check_mobile_walletconnect"
& $pythonPath @pythonArgs "-m" "tools.docs.test_electron_security_wallets"
& $pythonPath @pythonArgs "-m" "tools.docs.check_electron_security_wallets"
& $pythonPath @pythonArgs "-m" "tools.docs.test_operator_admin_ui"
& $pythonPath @pythonArgs "-m" "tools.docs.check_operator_admin_ui"
& $pythonPath @pythonArgs "-m" "tools.docs.test_operator_dashboard_query_model"
& $pythonPath @pythonArgs "-m" "tools.docs.check_operator_dashboard_query_model"
& $pythonPath @pythonArgs "-m" "tools.docs.test_monitoring_spec"
& $pythonPath @pythonArgs "-m" "tools.docs.check_monitoring_spec"
& $pythonPath @pythonArgs "-m" "tools.docs.test_royalty_policy"
& $pythonPath @pythonArgs "-m" "tools.docs.check_royalty_policy"
& $pythonPath @pythonArgs "-m" "tools.security.test_warning_dispositions"
& $pythonPath @pythonArgs "-m" "tools.security.check_warning_dispositions" "--solc-warnings-log" "cache\forge-size.log"
& $pythonPath @pythonArgs "-m" "tools.protocol.test_one_of_one_permanence_package"
& $pythonPath @pythonArgs "-m" "tools.protocol.check_one_of_one_permanence_package"
& $pythonPath @pythonArgs "-m" "tools.protocol.generate_one_of_one_permanence_manifest" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_readiness"
& $pythonPath @pythonArgs "-m" "tools.release.check_release_readiness"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_mode"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_notes"
& $pythonPath @pythonArgs "-m" "tools.release.generate_release_notes" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_manifest"
& $pythonPath @pythonArgs "-m" "tools.release.generate_release_manifest" "--check"
& $pythonPath @pythonArgs "-m" "tools.build.test_bytecode_release_proof"
& $pythonPath @pythonArgs "-m" "tools.build.generate_bytecode_release_proof" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_candidate_lockfile"
& $pythonPath @pythonArgs "-m" "tools.release.generate_release_candidate_lockfile" "--check"
& $pythonPath @pythonArgs "-m" "tools.release.test_release_checksums"
& $pythonPath @pythonArgs "-m" "tools.release.generate_release_checksums" "--check"
& $pythonPath @pythonArgs "-m" "tools.build.test_verify_release_artifacts"
& $pythonPath @pythonArgs "-m" "tools.build.verify_release_artifacts"
& $pythonPath @pythonArgs "-m" "tools.docs.test_changelog_check"
& $pythonPath @pythonArgs "-m" "tools.docs.check_changelog"
& $pythonPath @pythonArgs "-m" "tools.deployment.test_deployment_rehearsal_gate"
& $pythonPath @pythonArgs "-m" "tools.deployment.check_deployment_rehearsal_gate"
forge script script/legacy/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir
forge script script/legacy/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/legacy/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/legacy/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
