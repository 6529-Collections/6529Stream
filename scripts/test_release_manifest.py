#!/usr/bin/env python3
"""Focused tests for release manifest generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_release_manifest.py")
SPEC = importlib.util.spec_from_file_location("generate_release_manifest", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_release_tree(root: Path) -> dict[str, Path]:
    latest = root / "release-artifacts" / "latest"
    baseline = root / "release-artifacts" / "baselines" / "v0.1.0" / "abi-surface.json"
    gas_snapshot = root / "release-artifacts" / "baselines" / "v0.1.0" / "gas-snapshot.snap"
    contract_config = root / "release-artifacts" / "contracts.json"
    deployment_config_dir = root / "deployments" / "config"
    deployment_broadcast_dir = root / "deployments" / "broadcasts"
    deployment_manifest_dir = root / "deployments" / "examples"
    address_book_dir = root / "deployments" / "address-books"
    deployment_schema_dir = root / "deployments" / "schema"
    ceremony_evidence_dir = root / "deployments" / "ceremony-evidence"
    randomizer_operations_dir = root / "deployments" / "randomizer-operations"
    release_signatures_dir = root / "release-artifacts" / "signatures"
    non_local_evidence_dir = root / "release-artifacts" / "evidence"
    drop_authorization_signing_dir = (
        root / "release-artifacts" / "drop-authorization-signing"
    )
    signer_custody_readiness_dir = (
        root / "release-artifacts" / "signer-custody-readiness"
    )
    release_signature_schema = root / "release-artifacts" / "schema" / (
        "release-signature-evidence.schema.json"
    )
    drop_authorization_signing_schema = root / "release-artifacts" / "schema" / (
        "drop-authorization-signing-evidence.schema.json"
    )
    signer_custody_readiness_schema = root / "release-artifacts" / "schema" / (
        "signer-custody-readiness.schema.json"
    )
    public_beta_schema = root / "release-artifacts" / "schema" / (
        "public-beta-evidence.schema.json"
    )
    non_local_evidence_schema = root / "release-artifacts" / "schema" / (
        "non-local-release-evidence.schema.json"
    )
    non_local_retained_artifact = (
        non_local_evidence_dir / "non-local-template-retained-artifact.txt"
    )
    drop_authorization_retained_artifact = (
        drop_authorization_signing_dir
        / "drop-authorization-signing-retained-artifact.txt"
    )
    signer_custody_retained_artifact = (
        signer_custody_readiness_dir
        / "signer-custody-readiness-retained-artifact.txt"
    )
    drop_authorization_payload_output = root / (
        "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json"
    )
    output = latest / "release-manifest.json"
    changelog = root / "CHANGELOG.md"
    docs = [
        root / "docs" / "release-policy.md",
        root / "docs" / "deployment.md",
        root / "docs" / "tooling.md",
        root / "docs" / "status.md",
        root / "docs" / "randomizer-operations.md",
        root / "docs" / "release-signatures.md",
        root / "docs" / "public-beta-evidence.md",
        root / "docs" / "non-local-release-evidence.md",
        root / "docs" / "architecture.md",
        root / "docs" / "threat-model.md",
        root / "docs" / "audit-package.md",
        root / "docs" / "incident-response.md",
        root / "docs" / "drop-authorization-signing.md",
        root / "docs" / "signer-custody-readiness.md",
        root / "docs" / "release-readiness.md",
    ]

    write_json(
        contract_config,
        {
            "schema_version": "6529stream.release-artifact-contracts.v1",
            "production_contracts": [{"name": "Example", "source": "Example.sol"}],
            "interfaces": [],
        },
    )
    write_json(
        latest / "abi-checksums.json",
        {
            "schema_version": "6529stream.abi-checksums.v1",
            "contracts": {},
            "abi_hashes": {},
            "bytecode_hashes": {},
        },
    )
    write_json(
        latest / "event-topic-catalog.json",
        {"schema_version": "6529stream.event-topic-catalog.v1", "topics": []},
    )
    write_json(
        latest / "interface-ids.json",
        {"schema_version": "6529stream.interface-ids.v1", "interfaces": {}},
    )
    write_json(
        latest / "release-artifact-manifest.json",
        {
            "schema_version": "6529stream.release-artifact-manifest.v1",
            "artifacts": {
                "abi-checksums.json": {
                    "path": "abi-checksums.json",
                    "sha256": "sha256:" + "1" * 64,
                }
            },
        },
    )
    write_json(
        latest / "dependency-artifact-manifest.json",
        {
            "schema_version": "6529stream.dependency-artifact-manifest.v1",
            "artifacts": [],
        },
    )
    write_json(
        latest / "source-verification-inputs.json",
        {"schema_version": "6529stream.source-verification-inputs.v1", "contracts": {}},
    )
    write_text(output, "{}\n")
    write_text(latest / "SHA256SUMS", "placeholder\n")
    write_json(
        baseline,
        {"schema_version": "6529stream.abi-surface.v1", "contracts": {}},
    )
    write_text(gas_snapshot, "StreamGasSnapshotTest:testGasFixedPriceMint() (gas: 1)\n")
    write_json(
        deployment_config_dir / "anvil.json",
        {"schema_version": "6529stream.deployment-manifest-input.v1"},
    )
    write_json(
        deployment_broadcast_dir / "run-latest.json",
        {"chain": 31337, "transactions": [], "receipts": []},
    )
    write_json(
        deployment_manifest_dir / "anvil.json",
        {
            "manifest_schema_version": "6529stream.deployment-manifest.v1",
            "protocol_version": "0.1.0",
            "deployment_version": "anvil-001",
            "lifecycle_state": "Rehearsed",
            "network": {"name": "anvil", "chain_id": 31337},
            "release_artifacts": {"manifest_sha256": "sha256:" + "2" * 64},
            "contracts": {"Example": {"address": "0x" + "1" * 40}},
        },
    )
    write_json(
        address_book_dir / "anvil.json",
        {
            "schema_version": "6529stream.address-book.v1",
            "protocol_version": "0.1.0",
            "deployment_version": "anvil-001",
            "lifecycle_state": "Rehearsed",
            "network": {"name": "anvil", "chain_id": 31337},
            "source": {
                "deployment_manifest": "deployments/examples/anvil.json",
                "deployment_manifest_sha256": "sha256:" + "2" * 64,
            },
            "contracts": {"Example": {"address": "0x" + "1" * 40}},
        },
    )
    write_json(
        deployment_schema_dir / "deployment-manifest.schema.json",
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        deployment_schema_dir / "address-book.schema.json",
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        deployment_schema_dir / "ceremony-evidence.schema.json",
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        deployment_schema_dir / "randomizer-operations-evidence.schema.json",
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        release_signature_schema,
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        drop_authorization_signing_schema,
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        signer_custody_readiness_schema,
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        public_beta_schema,
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        non_local_evidence_schema,
        {"schema_version": "https://json-schema.org/draft/2020-12/schema"},
    )
    write_json(
        ceremony_evidence_dir / "anvil-local.json",
        {
            "schema_version": "6529stream.deployment-ceremony-evidence.v1",
            "evidence_id": "anvil-local",
            "protocol_version": "0.1.0",
            "deployment_version": "anvil-001",
            "network": {"environment": "local", "name": "anvil", "chain_id": 31337},
            "artifacts": {
                "deployment_manifest": {"path": "deployments/examples/anvil.json"},
                "address_book": {"path": "deployments/address-books/anvil.json"},
                "release_checksum_bundle": {
                    "path": "release-artifacts/latest/SHA256SUMS"
                },
            },
            "verification_status": {"contract_verification": "not_applicable"},
        },
    )
    write_json(
        randomizer_operations_dir / "anvil-randomizer-local.json",
        {
            "schema_version": "6529stream.randomizer-operations-evidence.v1",
            "evidence_id": "anvil-randomizer-local",
            "protocol_version": "0.1.0",
            "deployment_version": "anvil-001",
            "network": {"environment": "local", "name": "anvil", "chain_id": 31337},
            "artifacts": {
                "deployment_manifest": {"path": "deployments/examples/anvil.json"},
                "address_book": {"path": "deployments/address-books/anvil.json"},
            },
            "provider_configuration": {
                "vrf": {
                    "adapter": "0x" + "8" * 40,
                    "provider": "0x" + "5" * 40,
                    "provider_type": "local_mock",
                    "provider_epoch": 0,
                    "funding_status": "not_applicable_local",
                },
                "arrng": {
                    "adapter": "0x" + "9" * 40,
                    "provider": "0x" + "6" * 40,
                    "provider_type": "local_mock",
                    "provider_epoch": 0,
                    "funding_status": "not_applicable_local",
                },
            },
        },
    )
    write_json(
        release_signatures_dir / "anvil-signature-local.json",
        {
            "schema_version": "6529stream.release-signature-evidence.v1",
            "evidence_id": "anvil-release-signature-local",
            "protocol_version": "0.1.0",
            "release_version": "v0.1.0-local",
            "network": {
                "environment": "local",
                "name": "anvil",
                "chain_id": 31337,
                "confirmation_depth": 0,
            },
            "source": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "git_commit": "0" * 40,
                "source_dirty": False,
                "ci_run": "local",
            },
            "artifacts": {
                "release_manifest": {
                    "path": "release-artifacts/latest/release-manifest.json",
                    "digest_status": "not_available_self_referential",
                    "reason": "Self-referential release output.",
                },
                "checksum_bundle": {
                    "path": "release-artifacts/latest/SHA256SUMS",
                    "digest_status": "not_available_self_referential",
                    "reason": "Self-referential release output.",
                },
            },
            "signing_identity": {
                "status": "not_available_local",
                "public_key_fingerprint": "not_applicable_local",
                "key_custody": "not_applicable_local",
                "rotation_policy": "Production releases must document signer rotation.",
            },
            "signatures": {
                "detached_checksum_signature": {
                    "status": "not_available_local",
                    "format": "not_applicable_local",
                    "artifact_path": "not_applicable_local",
                    "verification_command": "not_applicable_local",
                    "evidence": [],
                    "notes": "local placeholder signature result",
                },
                "signed_git_tag": {
                    "status": "not_available_local",
                    "format": "not_applicable_local",
                    "artifact_path": "not_applicable_local",
                    "verification_command": "not_applicable_local",
                    "evidence": [],
                    "notes": "local placeholder signed tag result",
                },
            },
            "retained_artifacts": [
                {
                    "category": "release_signature_schema",
                    "path": "release-artifacts/schema/release-signature-evidence.schema.json",
                    "sha256": generator.file_sha256(release_signature_schema),
                }
            ],
            "redaction_policy": {
                "no_secrets": True,
                "redacted_fields": ["private_key", "mnemonic", "api_key", "rpc_url"],
            },
            "operator_notes": "local placeholder only",
        },
    )
    public_beta_requirements = [
        {
            "id": requirement_id,
            "phase": generator.public_beta_checker.PUBLIC_BETA_PHASE,
            "status": "missing",
            "owner": "TBD",
            "evidence": [],
            "risk_acceptance": None,
            "notes": f"{requirement_id} is missing.",
        }
        for requirement_id in generator.public_beta_checker.PUBLIC_BETA_REQUIREMENTS
    ] + [
        {
            "id": requirement_id,
            "phase": generator.public_beta_checker.PRODUCTION_PHASE,
            "status": "missing",
            "owner": "TBD",
            "evidence": [],
            "risk_acceptance": None,
            "notes": f"{requirement_id} is missing.",
        }
        for requirement_id in generator.public_beta_checker.PRODUCTION_REQUIREMENTS
    ]
    write_json(
        latest / "public-beta-evidence.json",
        {
            "schema_version": "6529stream.public-beta-evidence.v1",
            "release_version": "v0.1.0-local",
            "source": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "git_commit": "0" * 40,
                "source_dirty": False,
                "ci_run": "local",
            },
            "status": {
                "public_beta": "blocked",
                "production_release": "blocked",
            },
            "requirements": public_beta_requirements,
            "retained_artifacts": [
                {
                    "category": "public_beta_evidence_schema",
                    "path": "release-artifacts/schema/public-beta-evidence.schema.json",
                    "sha256": generator.file_sha256(public_beta_schema),
                }
            ],
            "redaction_policy": {
                "no_secrets": True,
                "redacted_fields": [
                    "private_key",
                    "mnemonic",
                    "api_key",
                    "rpc_url",
                    "unreleased_drop_payload",
                ],
            },
            "operator_notes": "public beta and production remain blocked",
        },
    )
    write_text(
        latest / "public-beta-blockers.md",
        "# Public Beta Evidence Blocker Report\n\nGenerated fixture.\n",
    )
    write_text(
        non_local_retained_artifact,
        (
            "Template retained artifact for non-local release evidence tests.\n"
            "This placeholder is not completion evidence.\n"
        ),
    )
    drop_authorization_payload = {
        "schema_version": "6529stream.drop-authorization-payload.v1",
        "signing_status": "unsigned",
        "no_secret_policy": {
            "key_material_included": False,
            "mnemonic_included": False,
            "production_payload": False,
        },
        "typed_data": {
            "primaryType": "DropAuthorization",
            "domain": {
                "name": "6529StreamDrops",
                "version": "1",
                "chainId": 31337,
                "verifyingContract": "0x100000000000000000000000000000000000dEaD",
            },
            "message": {
                "dropId": "0x" + "1" * 64,
                "poster": "0x0000000000000000000000000000000000001001",
                "recipient": "0x0000000000000000000000000000000000005005",
                "payer": "0x0000000000000000000000000000000000000000",
                "collectionId": "1",
                "saleMode": 1,
                "signerEpoch": "1",
                "nonce": "1",
                "deadline": "1893456000",
            },
        },
        "derived": {
            "signer": "0xe05fcc23807536bee418f142d19fa0d21bb0cff7",
            "drop_id": "0x" + "1" * 64,
            "token_data_hash": "0x" + "2" * 64,
            "domain_separator": "0x" + "3" * 64,
            "struct_hash": "0x" + "4" * 64,
            "digest": "0x" + "5" * 64,
        },
    }
    write_json(drop_authorization_payload_output, drop_authorization_payload)
    write_text(
        drop_authorization_retained_artifact,
        (
            "Template retained artifact for drop authorization signing evidence tests.\n"
            "This placeholder is not completion evidence.\n"
        ),
    )
    drop_authorization_payload_ref = {
        "path": "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json",
        "sha256": generator.file_sha256(drop_authorization_payload_output),
    }
    write_json(
        drop_authorization_signing_dir
        / "drop-authorization-signing-evidence-template.json",
        {
            "schema_version": "6529stream.drop-authorization-signing-evidence.v1",
            "evidence_id": "drop-authorization-signing-evidence-template",
            "record_type": "template",
            "review_status": "template",
            "environment": "local",
            "chain_id": 31337,
            "source": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "git_commit": "0" * 40,
                "source_dirty": False,
                "ci_run": "local",
            },
            "payload": {
                "payload_file": drop_authorization_payload_ref,
                "payload_schema_version": "6529stream.drop-authorization-payload.v1",
                "payload_kind": "fixed_price",
                "typed_data_primary_type": "DropAuthorization",
                "domain": {
                    "name": "6529StreamDrops",
                    "version": "1",
                    "chain_id": 31337,
                    "verifying_contract": "0x100000000000000000000000000000000000dEaD",
                },
                "message": {
                    "drop_id": "0x" + "1" * 64,
                    "poster": "0x0000000000000000000000000000000000001001",
                    "recipient": "0x0000000000000000000000000000000000005005",
                    "payer": "0x0000000000000000000000000000000000000000",
                    "collection_id": 1,
                    "sale_mode": 1,
                    "signer_epoch": 1,
                    "nonce": 1,
                    "deadline": 1893456000,
                },
                "derived": {
                    "signer": "0xe05fcc23807536bee418f142d19fa0d21bb0cff7",
                    "drop_id": "0x" + "1" * 64,
                    "token_data_hash": "0x" + "2" * 64,
                    "domain_separator": "0x" + "3" * 64,
                    "struct_hash": "0x" + "4" * 64,
                    "digest": "0x" + "5" * 64,
                },
            },
            "signing_identity": {
                "signer_type": "local_placeholder",
                "signer": "0xe05fcc23807536bee418f142d19fa0d21bb0cff7",
                "signer_epoch": 1,
                "custody_status": "not_available_local",
                "custody_reference": "not_available_local",
                "signer_lifecycle_status": "not_available_local",
                "signer_service": "not_available_local",
                "signer_epoch_source": "not_available_local",
            },
            "signature": {
                "status": "not_available_local",
                "signature_format": "not_available_local",
                "signature_hash": "not_available_local",
                "verification_status": "not_available_local",
                "verification_command": "not_available_local",
                "returned_at": "not_available_local",
                "evidence_note": "local placeholder signature result",
            },
            "review": {
                "owner": "TBD",
                "reviewer": "TBD",
                "approval_status": "template",
                "approval_reference": "TBD",
                "reviewed_at": "not_available_local",
            },
            "retained_artifacts": [
                {
                    "category": "drop_signing_schema",
                    "path": (
                        "release-artifacts/schema/"
                        "drop-authorization-signing-evidence.schema.json"
                    ),
                    "sha256": generator.file_sha256(drop_authorization_signing_schema),
                },
                {**drop_authorization_payload_ref, "category": "payload_output"},
                {
                    "category": "retained_transcript",
                    "path": (
                        "release-artifacts/drop-authorization-signing/"
                        "drop-authorization-signing-retained-artifact.txt"
                    ),
                    "sha256": generator.file_sha256(
                        drop_authorization_retained_artifact
                    ),
                },
            ],
            "redaction_policy": {
                "no_secrets": True,
                "redacted_fields": [
                    "private_key",
                    "mnemonic",
                    "seed_phrase",
                    "api_key",
                    "rpc_url",
                    "raw_signature",
                    "unreleased_drop_payload",
                ],
            },
            "template_notice": "Template only. This file is not completion evidence.",
            "operator_notes": "local template only",
        },
    )
    write_json(
        non_local_evidence_dir / "non-local-release-evidence-template.json",
        {
            "schema_version": "6529stream.non-local-release-evidence.v1",
            "evidence_id": "non-local-release-evidence-template",
            "record_type": "template",
            "review_status": "template",
            "environment": "audit",
            "chain_id": "not_applicable",
            "block_or_reference": "TBD",
            "command_or_source_system": "TBD",
            "retained_path": (
                "release-artifacts/evidence/non-local-template-retained-artifact.txt"
            ),
            "sha256": generator.file_sha256(non_local_retained_artifact),
            "redaction_statement": "Template contains no secrets and no completion evidence.",
            "owner": "TBD",
            "reviewer": "TBD",
            "public_beta_requirement_id": "external_audit_report",
            "source": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "git_commit": "0" * 40,
                "source_dirty": False,
                "ci_run": "local",
            },
            "redaction_policy": {
                "no_secrets": True,
                "redacted_fields": [
                    "private_key",
                    "mnemonic",
                    "api_key",
                    "rpc_url",
                    "unreleased_drop_payload",
                ],
            },
            "template_notice": (
                "This template is not completion evidence and must be replaced "
                "by reviewed evidence before any public-beta status changes."
            ),
            "operator_notes": "local template only",
        },
    )
    write_json(
        non_local_evidence_dir
        / "public-beta-templates"
        / "testnet-deployment-rehearsal-template.json",
        {
            "schema_version": "6529stream.non-local-release-evidence.v1",
            "evidence_id": "public-beta-template-testnet-deployment-rehearsal",
            "record_type": "template",
            "review_status": "template",
            "environment": "testnet",
            "chain_id": 11155111,
            "block_or_reference": "TBD",
            "command_or_source_system": "TBD",
            "retained_path": (
                "release-artifacts/evidence/non-local-template-retained-artifact.txt"
            ),
            "sha256": generator.file_sha256(non_local_retained_artifact),
            "redaction_statement": "Template contains no secrets and no completion evidence.",
            "owner": "TBD",
            "reviewer": "TBD",
            "public_beta_requirement_id": "testnet_deployment_rehearsal",
            "source": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "git_commit": "0" * 40,
                "source_dirty": False,
                "ci_run": "local",
            },
            "redaction_policy": {
                "no_secrets": True,
                "redacted_fields": [
                    "private_key",
                    "mnemonic",
                    "api_key",
                    "rpc_url",
                    "unreleased_drop_payload",
                ],
            },
            "template_notice": (
                "This template is not completion evidence and must be replaced "
                "by reviewed evidence before any public-beta status changes."
            ),
            "operator_notes": "nested local template only",
        },
    )
    write_text(
        signer_custody_retained_artifact,
        (
            "Template retained artifact for signer custody readiness tests.\n"
            "This placeholder is not completion evidence.\n"
        ),
    )
    write_text(changelog, "# Changelog\n\n## Unreleased\n\n- Added release manifest.\n")
    for doc in docs:
        write_text(doc, f"# {doc.stem}\n")
    signer_custody_runbook_ref = {
        "path": "docs/signer-custody-readiness.md",
        "sha256": generator.file_sha256(root / "docs" / "signer-custody-readiness.md"),
    }
    incident_response_ref = {
        "path": "docs/incident-response.md",
        "sha256": generator.file_sha256(root / "docs" / "incident-response.md"),
    }
    write_json(
        signer_custody_readiness_dir / "signer-custody-readiness-template.json",
        {
            "schema_version": "6529stream.signer-custody-readiness.v1",
            "evidence_id": "signer-custody-readiness-template",
            "record_type": "template",
            "review_status": "template",
            "environment": "local",
            "chain_id": 31337,
            "source": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "git_commit": "0" * 40,
                "source_dirty": False,
                "ci_run": "local",
            },
            "signer_identity": {
                "signer_type": "local_placeholder",
                "expected_signer": "0x0000000000000000000000000000000000006532",
                "signer_epoch": 1,
                "signer_epoch_source": "not_available_local",
                "signer_manager": "0x0000000000000000000000000000000000000004",
                "signer_manager_type": "not_available_local",
                "erc1271_support_status": "not_available_local",
                "erc1271_support_detail": {
                    "rationale": "not_available_local",
                    "evidence_reference": "not_available_local",
                },
                "signer_service_class": "not_available_local",
            },
            "custody": {
                "custody_owner": "TBD",
                "custody_status": "not_available_local",
                "custody_system": "not_available_local",
                "approval_workflow_reference": "TBD",
                "key_material_location": "not_available_local",
                "separation_of_duties": "not_available_local",
            },
            "lifecycle": {
                "rotation_status": "not_available_local",
                "revocation_status": "not_available_local",
                "compromise_response_status": "not_available_local",
                "signer_epoch_rotation_tested": False,
                "per_drop_cancellation_tested": False,
                "last_rotation_drill": "not_available_local",
                "last_revocation_drill": "not_available_local",
            },
            "operations": {
                "monitoring_status": "not_available_local",
                "runbook": signer_custody_runbook_ref,
                "alerting_reference": "TBD",
                "incident_response_runbook": incident_response_ref,
                "signer_service_integration_status": "not_available_local",
            },
            "review": {
                "owner": "TBD",
                "reviewer": "TBD",
                "approval_status": "template",
                "approval_reference": "TBD",
                "reviewed_at": "not_available_local",
            },
            "retained_artifacts": [
                {
                    "category": "signer_custody_schema",
                    "path": "release-artifacts/schema/signer-custody-readiness.schema.json",
                    "sha256": generator.file_sha256(signer_custody_readiness_schema),
                },
                {
                    "category": "readiness_transcript",
                    "path": (
                        "release-artifacts/signer-custody-readiness/"
                        "signer-custody-readiness-retained-artifact.txt"
                    ),
                    "sha256": generator.file_sha256(
                        signer_custody_retained_artifact
                    ),
                },
            ],
            "redaction_policy": {
                "no_secrets": True,
                "redacted_fields": [
                    "private_key",
                    "mnemonic",
                    "seed_phrase",
                    "api_key",
                    "rpc_url",
                    "hsm_credentials",
                    "raw_signature",
                    "unreleased_drop_payload",
                ],
            },
            "template_notice": "Template only. This file is not completion evidence.",
            "operator_notes": "local template only",
        },
    )

    return {
        "latest": latest,
        "baseline": baseline,
        "gas_snapshot": gas_snapshot,
        "contract_config": contract_config,
        "deployment_config_dir": deployment_config_dir,
        "deployment_broadcast_dir": deployment_broadcast_dir,
        "deployment_manifest_dir": deployment_manifest_dir,
        "address_book_dir": address_book_dir,
        "deployment_schema_dir": deployment_schema_dir,
        "ceremony_evidence_dir": ceremony_evidence_dir,
        "randomizer_operations_dir": randomizer_operations_dir,
        "release_signatures_dir": release_signatures_dir,
        "non_local_evidence_dir": non_local_evidence_dir,
        "drop_authorization_signing_dir": drop_authorization_signing_dir,
        "signer_custody_readiness_dir": signer_custody_readiness_dir,
        "release_signature_schema": release_signature_schema,
        "drop_authorization_signing_schema": drop_authorization_signing_schema,
        "signer_custody_readiness_schema": signer_custody_readiness_schema,
        "public_beta_schema": public_beta_schema,
        "non_local_evidence_schema": non_local_evidence_schema,
        "non_local_retained_artifact": non_local_retained_artifact,
        "drop_authorization_retained_artifact": drop_authorization_retained_artifact,
        "signer_custody_retained_artifact": signer_custody_retained_artifact,
        "drop_authorization_payload_output": drop_authorization_payload_output,
        "output": output,
        "changelog": changelog,
        "docs": docs,
    }


class ReleaseManifestTests(unittest.TestCase):
    def test_generator_writes_deterministic_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)

            written = generator.write_output(
                root,
                paths["output"],
                paths["latest"],
                paths["baseline"],
                paths["gas_snapshot"],
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_broadcast_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
                paths["ceremony_evidence_dir"],
                paths["randomizer_operations_dir"],
                paths["changelog"],
                paths["docs"],
            )
            first = written.read_text(encoding="utf-8")
            generator.write_output(
                root,
                paths["output"],
                paths["latest"],
                paths["baseline"],
                paths["gas_snapshot"],
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_broadcast_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
                paths["ceremony_evidence_dir"],
                paths["randomizer_operations_dir"],
                paths["changelog"],
                paths["docs"],
            )
            self.assertEqual(first, written.read_text(encoding="utf-8"))

            manifest = json.loads(first)
            self.assertEqual(manifest["schema_version"], generator.RELEASE_MANIFEST_SCHEMA)
            self.assertEqual(manifest["release"]["protocol_versions"], ["0.1.0"])
            self.assertEqual(manifest["release"]["deployment_versions"], ["anvil-001"])
            self.assertEqual(
                manifest["release_artifacts"]["abi_checksums"]["sha256"],
                generator.file_sha256(paths["latest"] / "abi-checksums.json"),
            )
            self.assertEqual(
                manifest["release_artifacts"]["source_verification_inputs"]["schema_version"],
                "6529stream.source-verification-inputs.v1",
            )
            self.assertEqual(
                manifest["release_artifacts"]["dependency_artifact_manifest"]["schema_version"],
                "6529stream.dependency-artifact-manifest.v1",
            )
            self.assertEqual(
                manifest["release_artifacts"]["gas_snapshot_baseline"]["path"],
                "release-artifacts/baselines/v0.1.0/gas-snapshot.snap",
            )
            self.assertEqual(
                manifest["release_artifacts"]["gas_snapshot_baseline"]["sha256"],
                generator.file_sha256(paths["gas_snapshot"]),
            )
            self.assertEqual(
                manifest["release_artifacts"]["gas_snapshot_baseline"]["size_bytes"],
                paths["gas_snapshot"].stat().st_size,
            )
            self.assertEqual(
                manifest["deployment_artifacts"]["broadcasts"][0]["path"],
                "deployments/broadcasts/run-latest.json",
            )
            self.assertEqual(
                manifest["deployment_artifacts"]["manifests"][0]["contracts"],
                ["Example"],
            )
            self.assertEqual(
                manifest["deployment_artifacts"]["ceremony_evidence"][0]["evidence_id"],
                "anvil-local",
            )
            self.assertEqual(
                manifest["deployment_artifacts"]["ceremony_evidence"][0]["network"][
                    "environment"
                ],
                "local",
            )
            self.assertEqual(
                manifest["deployment_artifacts"]["randomizer_operations"][0]["evidence_id"],
                "anvil-randomizer-local",
            )
            self.assertEqual(
                manifest["deployment_artifacts"]["randomizer_operations"][0]["providers"]["arrng"][
                    "funding_status"
                ],
                "not_applicable_local",
            )
            self.assertEqual(
                manifest["release_artifacts"]["release_signature_evidence"][0][
                    "evidence_id"
                ],
                "anvil-release-signature-local",
            )
            self.assertEqual(
                manifest["release_artifacts"]["release_signature_evidence"][0][
                    "detached_checksum_signature"
                ]["status"],
                "not_available_local",
            )
            self.assertEqual(
                manifest["release_artifacts"]["release_signature_evidence"][0]["evidence"][
                    "operator_notes"
                ],
                "local placeholder only",
            )
            self.assertEqual(
                manifest["release_artifacts"]["public_beta_evidence"]["status"][
                    "public_beta"
                ],
                "blocked",
            )
            self.assertEqual(
                manifest["release_artifacts"]["public_beta_evidence"]["blocking_counts"][
                    "production_release"
                ],
                len(generator.public_beta_checker.PRODUCTION_REQUIREMENTS),
            )
            public_beta_blockers = manifest["release_artifacts"][
                "public_beta_blocker_report"
            ]
            self.assertEqual(
                public_beta_blockers["path"],
                "release-artifacts/latest/public-beta-blockers.md",
            )
            self.assertEqual(
                public_beta_blockers["sha256"],
                generator.file_sha256(paths["latest"] / "public-beta-blockers.md"),
            )
            self.assertEqual(
                manifest["source"]["non_local_evidence_dir"],
                "release-artifacts/evidence",
            )
            self.assertEqual(
                manifest["source"]["drop_authorization_signing_dir"],
                "release-artifacts/drop-authorization-signing",
            )
            self.assertEqual(
                manifest["source"]["signer_custody_readiness_dir"],
                "release-artifacts/signer-custody-readiness",
            )
            drop_signing_evidence = manifest["release_artifacts"][
                "drop_authorization_signing_evidence"
            ][0]
            self.assertEqual(
                drop_signing_evidence["evidence_id"],
                "drop-authorization-signing-evidence-template",
            )
            self.assertEqual(drop_signing_evidence["record_type"], "template")
            self.assertEqual(
                drop_signing_evidence["payload"]["payload_kind"], "fixed_price"
            )
            self.assertEqual(
                drop_signing_evidence["payload"]["derived"]["digest"],
                "0x" + "5" * 64,
            )
            self.assertEqual(
                drop_signing_evidence["signature"]["status"],
                "not_available_local",
            )
            signer_custody = manifest["release_artifacts"][
                "signer_custody_readiness"
            ][0]
            self.assertEqual(
                signer_custody["evidence_id"], "signer-custody-readiness-template"
            )
            self.assertEqual(signer_custody["record_type"], "template")
            self.assertEqual(
                signer_custody["signer_identity"]["expected_signer"],
                "0x0000000000000000000000000000000000006532",
            )
            self.assertEqual(
                signer_custody["custody"]["custody_status"],
                "not_available_local",
            )
            self.assertEqual(
                signer_custody["signer_identity"]["erc1271_support_detail"][
                    "rationale"
                ],
                "not_available_local",
            )
            self.assertEqual(
                signer_custody["operations"]["signer_service_integration_status"],
                "not_available_local",
            )
            non_local_evidence_rows = manifest["release_artifacts"][
                "non_local_release_evidence"
            ]
            non_local_evidence = {
                row["evidence_id"]: row for row in non_local_evidence_rows
            }["non-local-release-evidence-template"]
            self.assertEqual(
                non_local_evidence["evidence_id"],
                "non-local-release-evidence-template",
            )
            self.assertEqual(non_local_evidence["record_type"], "template")
            self.assertEqual(non_local_evidence["review_status"], "template")
            self.assertEqual(
                non_local_evidence["public_beta_requirement_id"],
                "external_audit_report",
            )
            self.assertEqual(
                non_local_evidence["evidence"]["operator_notes"],
                "local template only",
            )
            nested_template = {
                row["evidence_id"]: row for row in non_local_evidence_rows
            }["public-beta-template-testnet-deployment-rehearsal"]
            self.assertEqual(
                nested_template["path"],
                "release-artifacts/evidence/public-beta-templates/testnet-deployment-rehearsal-template.json",
            )
            self.assertEqual(
                nested_template["public_beta_requirement_id"],
                "testnet_deployment_rehearsal",
            )
            self.assertEqual(
                manifest["checksum_bundle"]["outputs"][0]["sha256"],
                generator.CHECKSUM_DIGEST_STATUS,
            )
            self.assertTrue(
                manifest["checksum_bundle"]["coverage_expectation"][
                    "covered_by_checksum_bundle"
                ]
            )

    def test_generator_uses_custom_release_artifacts_dir_for_public_beta_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            custom_latest = root / "custom-release-artifacts" / "latest"
            custom_latest.mkdir(parents=True, exist_ok=True)
            for source in paths["latest"].iterdir():
                if source.is_file():
                    (custom_latest / source.name).write_bytes(source.read_bytes())
            output = custom_latest / "release-manifest.json"

            written = generator.write_output(
                root,
                output,
                custom_latest,
                paths["baseline"],
                paths["gas_snapshot"],
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_broadcast_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
                paths["ceremony_evidence_dir"],
                paths["randomizer_operations_dir"],
                paths["changelog"],
                paths["docs"],
            )

            manifest = json.loads(written.read_text(encoding="utf-8"))
            self.assertEqual(
                manifest["source"]["release_artifacts_dir"],
                "custom-release-artifacts/latest",
            )
            public_beta = manifest["release_artifacts"]["public_beta_evidence"]
            self.assertEqual(
                public_beta["path"],
                "custom-release-artifacts/latest/public-beta-evidence.json",
            )
            self.assertEqual(
                public_beta["sha256"],
                generator.file_sha256(custom_latest / "public-beta-evidence.json"),
            )
            blockers = manifest["release_artifacts"]["public_beta_blocker_report"]
            self.assertEqual(
                blockers["path"],
                "custom-release-artifacts/latest/public-beta-blockers.md",
            )
            self.assertEqual(
                blockers["sha256"],
                generator.file_sha256(custom_latest / "public-beta-blockers.md"),
            )

    def test_check_mode_accepts_current_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            generator.write_output(
                root,
                paths["output"],
                paths["latest"],
                paths["baseline"],
                paths["gas_snapshot"],
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_broadcast_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
                paths["ceremony_evidence_dir"],
                paths["randomizer_operations_dir"],
                paths["changelog"],
                paths["docs"],
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_output(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["gas_snapshot"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
            )
            self.assertEqual(result, 0)

    def test_generator_rejects_invalid_release_signature_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            evidence_path = paths["release_signatures_dir"] / "anvil-signature-local.json"
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["source"]["unexpected"] = "value"
            write_json(evidence_path, evidence)

            with self.assertRaisesRegex(
                generator.ReleaseManifestError, "invalid release signature evidence"
            ):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["gas_snapshot"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )

    def test_generator_rejects_invalid_non_local_release_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            evidence_path = (
                paths["non_local_evidence_dir"]
                / "non-local-release-evidence-template.json"
            )
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["public_beta_requirement_id"] = "not_a_real_requirement"
            write_json(evidence_path, evidence)

            with self.assertRaisesRegex(
                generator.ReleaseManifestError, "invalid non-local release evidence"
            ):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["gas_snapshot"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )

    def test_generator_rejects_invalid_drop_authorization_signing_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            evidence_path = (
                paths["drop_authorization_signing_dir"]
                / "drop-authorization-signing-evidence-template.json"
            )
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["payload"]["derived"]["digest"] = "0x" + "0" * 64
            write_json(evidence_path, evidence)

            with self.assertRaisesRegex(
                generator.ReleaseManifestError,
                "invalid drop authorization signing evidence",
            ):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["gas_snapshot"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )

    def test_generator_rejects_invalid_signer_custody_readiness(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            evidence_path = (
                paths["signer_custody_readiness_dir"]
                / "signer-custody-readiness-template.json"
            )
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["signer_identity"]["signer_epoch"] = -1
            write_json(evidence_path, evidence)

            with self.assertRaisesRegex(
                generator.ReleaseManifestError,
                "invalid signer custody readiness evidence",
            ):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["gas_snapshot"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )

    def test_check_mode_rejects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            generator.write_output(
                root,
                paths["output"],
                paths["latest"],
                paths["baseline"],
                paths["gas_snapshot"],
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_broadcast_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
                paths["ceremony_evidence_dir"],
                paths["randomizer_operations_dir"],
                paths["changelog"],
                paths["docs"],
            )
            write_text(paths["changelog"], "# Changelog\n\n## Unreleased\n\n- Changed.\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["gas_snapshot"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )
            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/release-manifest.json",
                stderr.getvalue(),
            )

    def test_generator_derives_gas_snapshot_path_from_protocol_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)

            manifest = generator.build_manifest(
                root,
                paths["output"],
                paths["latest"],
                paths["baseline"],
                None,
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_broadcast_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
                paths["ceremony_evidence_dir"],
                paths["randomizer_operations_dir"],
                paths["changelog"],
                paths["docs"],
            )

            self.assertEqual(
                manifest["release_artifacts"]["gas_snapshot_baseline"]["path"],
                "release-artifacts/baselines/v0.1.0/gas-snapshot.snap",
            )

    def test_generator_rejects_gas_snapshot_version_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            mismatched = root / "release-artifacts" / "baselines" / "v0.2.0" / "gas-snapshot.snap"
            write_text(mismatched, "StreamGasSnapshotTest:testGasFixedPriceMint() (gas: 1)\n")

            with self.assertRaisesRegex(
                generator.ReleaseManifestError, "does not match release protocol version"
            ):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    mismatched,
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )

    def test_generator_rejects_gas_snapshot_outside_baseline_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            foreign = root / "tmp" / "v0.1.0" / "gas-snapshot.snap"
            write_text(foreign, "StreamGasSnapshotTest:testGasFixedPriceMint() (gas: 1)\n")

            with self.assertRaisesRegex(
                generator.ReleaseManifestError, "canonical release baseline"
            ):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    foreign,
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )

    def test_generator_rejects_missing_required_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            (paths["latest"] / "interface-ids.json").unlink()

            with self.assertRaisesRegex(generator.ReleaseManifestError, "missing required file"):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["gas_snapshot"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )

    def test_generator_rejects_json_without_schema_where_required(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            write_json(paths["contract_config"], {"production_contracts": []})

            with self.assertRaisesRegex(generator.ReleaseManifestError, "missing a schema version"):
                generator.build_manifest(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["gas_snapshot"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_broadcast_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["ceremony_evidence_dir"],
                    paths["randomizer_operations_dir"],
                    paths["changelog"],
                    paths["docs"],
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
