# Release Artifacts reference

This is detailed maintainer reference. Start everyday work with the
[developer commands](../../tooling.md); run aggregate release validation only when
preparing the corresponding evidence. Commands below run from the repository root.

## Release Artifacts

The current candidate is separate from the historical engineering artifact
baseline in `latest`. Its reviewed targets are in
`release-artifacts/current-contracts.json`. After validating the selected
current build, export it without recompiling:

```bash
python -m tools.deployment.generate_current_stack_artifacts
python -m tools.deployment.generate_current_stack_artifacts --check
```

The exporter reads `out/current` by default; `--foundry-out` selects the actual
output used for a deployment rehearsal. It requires complete build-info and
checks that every selected ABI and bytecode object, including the deployment
script, belongs to one globally-via-IR compiler input with the pinned settings.
It rejects stale sources, mismatched outputs and runtime size violations. The
separate `release-artifacts/current` bundle retains that exact compiler input,
source hashes, ABIs, bytecode, recursively linked library targets, link references
and immutable references. These
are compilation facts: constructor arguments, deployed library addresses and
actual on-chain runtime hashes still need deployment evidence.

The current CI job runs concurrently with the historical Foundry job. Its
profile excludes historical test and script bytecode while compiling the
actual current deployment closure. It exports the selected build as a CI
artifact. The single-controller `StreamGovernanceActor` remains a
development/testnet authority template; the local `DevelopmentEntropyProvider`
is not an exported deployable target. Explicit semantic interface IDs use
Solidity `type(I).interfaceId`; a full ABI selector XOR also includes inherited
methods and may differ.

The historical generator sequence below still maintains the default
engineering checks. Its target-isolated bytecode must not be substituted for
the exact current deployment compilation, even when ABI and source match.

After changing any production contract ABI or event surface, optionally run the
aggregate diagnostic, then build the canonical target-isolated artifacts and
regenerate the tracked release baseline.

The release-tool call policy and its schema are reviewed inputs, not generated
outputs. Any change to a reviewed tool/test source listed in the
[call policy](../../../release-artifacts/release-tool-call-policy.json) or to an allowed
dangerous exception must update and review the policy before the generated
tail with:

```bash
python -m tools.release.generate_release_checksums --refresh-release-tool-call-policy
```

Preserve the canonical tail order after that reviewed-input refresh: risk
register, release notes, release
manifest, bytecode proof, candidate lockfile, then checksum bundle. This keeps
the dependency graph acyclic: the policy never records its own digest or a
generated-tail digest, while manifest and lockfile supply the policy/schema
hash bindings.

Run the canonical sequence with:

```bash
python -m tools.protocol.test_external_call_gas_inventory
python -m tools.protocol.check_external_call_gas_inventory
python -m tools.build.test_abi_compatibility
python -m tools.build.check_abi_compatibility --target-only
forge build --sizes --via-ir --skip test --skip script --force
python -m tools.build.test_release_build_artifacts
python -m tools.build.build_release_artifacts
python -m tools.build.build_release_artifacts --check
forge snapshot --match-path test/gas/StreamGasSnapshot.t.sol --snap release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python -m tools.build.test_core_bytecode_spend_policy
python -m tools.build.check_core_bytecode_spend_policy
python -m tools.build.generate_release_artifacts
python -m tools.build.generate_source_verification_inputs
python -m tools.build.check_abi_compatibility --check
python -m tools.deployment.generate_broadcast_manifest_input
python -m tools.deployment.generate_deployment_manifest
python -m tools.deployment.generate_deployment_manifest --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json
python -m tools.deployment.generate_address_books
python -m tools.deployment.test_ceremony_evidence
python -m tools.deployment.check_ceremony_evidence
python -m tools.deployment.check_randomizer_operations
python -m tools.release.check_release_signatures
python -m tools.release.test_production_release_signing_evidence
python -m tools.release.check_production_release_signing_evidence
python -m tools.release.test_non_local_release_evidence_generator
python -m tools.release.test_non_local_release_evidence
python -m tools.release.check_non_local_release_evidence
python -m tools.deployment.test_fork_deployment_rehearsal_evidence
python -m tools.deployment.check_fork_deployment_rehearsal_evidence
python -m tools.release.check_public_beta_evidence
python -m tools.release.generate_public_beta_blocker_report
python -m tools.release.generate_production_release_blocker_report
python -m tools.release.generate_release_evidence_packet_index
python -m tools.release.generate_release_evidence_issue_backlog
python -m tools.release.check_release_evidence_issue_links
python -m tools.release.check_release_evidence_issue_labels
python -m tools.release.check_release_evidence_live_audit_report
python -m tools.release.generate_release_evidence_live_audit_archive
python -m tools.release.generate_release_evidence_issue_body_sync
python -m tools.release.check_release_evidence_issue_bodies
python -m tools.release.check_release_evidence_issue_closure
python -m tools.docs.check_architecture_threat_model
python -m tools.protocol.test_artist_semantic_owner_matrix
python -m tools.protocol.check_artist_semantic_owner_matrix
python -m tools.protocol.check_mint_manager_domain_constants
python -m tools.docs.check_audit_package
python -m tools.build.test_natspec_coverage
python -m tools.build.check_natspec_coverage
python -m tools.docs.test_incident_response
python -m tools.docs.check_incident_response
python -m tools.protocol.test_drop_authorization_payload_generator
python -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python -m tools.protocol.test_drop_authorization_fixtures
python -m tools.protocol.check_drop_authorization_fixtures
python -m tools.release.test_drop_authorization_signing_evidence
python -m tools.release.check_drop_authorization_signing_evidence
python -m tools.release.test_signer_custody_readiness
python -m tools.release.check_signer_custody_readiness
python -m tools.deployment.test_admin_ceremony_evidence
python -m tools.deployment.check_admin_ceremony_evidence
python -m tools.docs.test_monitoring_spec
python -m tools.docs.check_monitoring_spec
python -m tools.docs.test_operator_dashboard_query_model
python -m tools.docs.check_operator_dashboard_query_model
python -m tools.release.check_release_readiness
python -m tools.protocol.test_genesis_deployment_profile
python -m tools.protocol.check_genesis_deployment_profile
python -m tools.protocol.test_governed_parameter_identifiers
python -m tools.protocol.check_governed_parameter_identifiers
python -m tools.protocol.test_governed_parameter_inventory
python -m tools.protocol.check_governed_parameter_inventory
python -m tools.protocol.generate_system_manifest_payload_vector
python -m tools.protocol.test_system_manifest_payload_vector
python -m tools.protocol.check_system_manifest_payload_vector
python -m tools.protocol.test_system_manifest_payload_vector_reference
python -m tools.protocol.check_system_manifest_payload_vector_reference
python -m tools.security.generate_risk_register
python -m tools.release.generate_release_notes
python -m tools.release.generate_release_manifest
python -m tools.build.generate_bytecode_release_proof
python -m tools.release.generate_release_candidate_lockfile
python -m tools.release.generate_release_checksums
python -m tools.docs.check_changelog
```

The check mode is:

```bash
python -m tools.protocol.test_external_call_gas_inventory
python -m tools.protocol.check_external_call_gas_inventory
python -m tools.build.test_abi_compatibility
python -m tools.build.build_release_artifacts --check
python -m tools.build.generate_release_artifacts --check
forge snapshot --match-path test/gas/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python -m tools.build.generate_source_verification_inputs --check
python -m tools.build.check_abi_compatibility --check
python -m tools.deployment.generate_broadcast_manifest_input --check
python -m tools.deployment.generate_deployment_manifest --check
python -m tools.deployment.generate_deployment_manifest --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
python -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --check
python -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check
python -m tools.deployment.generate_address_books --check
python -m tools.deployment.test_ceremony_evidence
python -m tools.deployment.check_ceremony_evidence
python -m tools.deployment.check_randomizer_operations
python -m tools.release.check_release_signatures
python -m tools.release.test_production_release_signing_evidence
python -m tools.release.check_production_release_signing_evidence
python -m tools.release.test_non_local_release_evidence_generator
python -m tools.release.test_non_local_release_evidence
python -m tools.release.check_non_local_release_evidence
python -m tools.deployment.test_fork_deployment_rehearsal_evidence
python -m tools.deployment.check_fork_deployment_rehearsal_evidence
python -m tools.release.check_public_beta_evidence
python -m tools.release.generate_public_beta_blocker_report --check
python -m tools.release.generate_production_release_blocker_report --check
python -m tools.release.test_release_evidence_packet_index
python -m tools.release.generate_release_evidence_packet_index --check
python -m tools.release.test_release_evidence_issue_backlog
python -m tools.release.generate_release_evidence_issue_backlog --check
python -m tools.release.test_release_evidence_issue_links
python -m tools.release.check_release_evidence_issue_links
python -m tools.release.test_release_evidence_issue_snapshot
python -m tools.release.test_release_evidence_issue_snapshot_audit
python -m tools.release.test_release_evidence_live_audit_report
python -m tools.release.check_release_evidence_live_audit_report
python -m tools.release.test_release_evidence_live_audit_markdown
python -m tools.release.check_release_evidence_live_audit_markdown
python -m tools.release.test_release_evidence_live_audit_archive
python -m tools.release.generate_release_evidence_live_audit_archive --check
python -m tools.release.test_release_evidence_issue_labels
python -m tools.release.check_release_evidence_issue_labels
python -m tools.release.test_release_evidence_issue_body_sync
python -m tools.release.generate_release_evidence_issue_body_sync --check
python -m tools.release.test_release_evidence_issue_bodies
python -m tools.release.check_release_evidence_issue_bodies
python -m tools.release.test_release_evidence_issue_closure
python -m tools.release.check_release_evidence_issue_closure
python -m tools.docs.check_architecture_threat_model
python -m tools.protocol.test_artist_semantic_owner_matrix
python -m tools.protocol.check_artist_semantic_owner_matrix
python -m tools.protocol.check_mint_manager_domain_constants
python -m tools.docs.check_audit_package
python -m tools.build.test_natspec_coverage
python -m tools.build.check_natspec_coverage
python -m tools.docs.test_incident_response
python -m tools.docs.check_incident_response
python -m tools.protocol.test_drop_authorization_payload_generator
python -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python -m tools.protocol.test_drop_authorization_fixtures
python -m tools.protocol.check_drop_authorization_fixtures
python -m tools.release.test_drop_authorization_signing_evidence
python -m tools.release.check_drop_authorization_signing_evidence
python -m tools.release.test_signer_custody_readiness
python -m tools.release.check_signer_custody_readiness
python -m tools.deployment.test_admin_ceremony_evidence
python -m tools.deployment.check_admin_ceremony_evidence
python -m tools.docs.test_monitoring_spec
python -m tools.docs.check_monitoring_spec
python -m tools.release.check_release_readiness
python -m tools.protocol.test_genesis_deployment_profile
python -m tools.protocol.check_genesis_deployment_profile
python -m tools.protocol.test_governed_parameter_identifiers
python -m tools.protocol.check_governed_parameter_identifiers
python -m tools.protocol.test_governed_parameter_inventory
python -m tools.protocol.check_governed_parameter_inventory
python -m tools.protocol.test_system_manifest_payload_vector
python -m tools.protocol.check_system_manifest_payload_vector
python -m tools.protocol.test_system_manifest_payload_vector_reference
python -m tools.protocol.check_system_manifest_payload_vector_reference
python -m tools.security.generate_risk_register --check
python -m tools.release.generate_release_notes --check
python -m tools.release.generate_release_manifest --check
python -m tools.build.generate_bytecode_release_proof --check
python -m tools.release.generate_release_candidate_lockfile --check
python -m tools.release.generate_release_checksums --check
python -m tools.docs.check_changelog
```

The generator uses `release-artifacts/contracts.json` to define the production
contract and interface surface. Standard ERC interface IDs are pinned there when
the advertised ERC ID differs from a raw XOR over the artifact ABI.
An `unbound_singleton` production-contract scope includes Proposed bytecode,
ABI, protocol-surface, and source-verification evidence while deliberately
excluding that contract from deployment manifests and address books until a
later candidate-bound change supplies a real singleton instance. It must not be
used to claim a rehearsal, deployment, candidate, or readiness result.

The ABI compatibility baseline uses the production contract and published
interface sets from the same config file. Refresh it only when maintainers
intentionally accept a release surface change; removed or changed entries
should also update the breaking change documentation and release notes.
Checker diagnostics identify the changed production contract or published
interface with canonical `subject`; `contract` is retained as a deprecated
compatibility alias with the same value.

The gas snapshot baseline lives at
`release-artifacts/baselines/v0.1.0/gas-snapshot.snap`. Refresh it only when
maintainers intentionally accept changed gas for the focused Gate D operations:
fixed-price mint, auction bid, auction settlement, curator claim, final
on-chain `tokenURI`, and dependency/script reads.

The deployment manifest generator uses committed inputs under
`deployments/config/`. The broadcast-derived input is generated first from the
sanitized Foundry broadcast fixture under `deployments/broadcasts/`. Manifest
checksums are the SHA-256 of canonical JSON with
`release_artifacts.manifest_sha256` normalized to `sha256:` plus 64 zeroes,
which avoids a self-referential checksum while making manifest drift
machine-detectable.

The address-book generator reads committed deployment manifests and
`release-artifacts/latest/abi-checksums.json`. Refresh address books after
deployment manifests change; the `--check` mode fails on stale output, invalid
or duplicate contract addresses, missing contract metadata, or mismatch against
the release artifact contract set.

The release-checksum generator covers `release-artifacts/contracts.json`,
`requirements-tools.txt`, `requirements-tools.lock`, the ordinary CI and
release-mode workflows, the Python toolchain checker and its tests, the
canonical `release-artifacts/genesis-deployment-profile.json` and its checker,
tests, every profile normative-anchor document, release-mode integration,
the aggregate release wrappers, the external-call gas inventory policy, the ABI
compatibility verifier/goldens, and normative inventory mirrors,
`release-artifacts/evidence/`,
`release-artifacts/drop-authorization-signing/`,
`release-artifacts/signer-custody-readiness/`,
`release-artifacts/schema/`,
`release-artifacts/latest/public-beta-evidence.json`,
`release-artifacts/latest/`, `release-artifacts/baselines/`,
`deployments/broadcasts/`, `deployments/config/`, `deployments/examples/`,
`deployments/address-books/`, `deployments/ceremony-evidence/`,
`deployments/admin-ceremony/`, `deployments/randomizer-operations/`,
`deployments/schema/`, and `test/fixtures/drop-authorization/`, excluding its
own generated checksum files to avoid self-referential hashes. Refresh the
release manifest before refreshing the checksum bundle after changing any
covered artifact.


ABI compatibility commands above use `--check`. The bare checker command writes a
baseline; use that only for a deliberately reviewed baseline change, never as an
ordinary refresh of an immutable historical snapshot.
