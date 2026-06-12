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
    release_signature_schema = root / "release-artifacts" / "schema" / (
        "release-signature-evidence.schema.json"
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
        root / "docs" / "audit-package.md",
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
    write_text(changelog, "# Changelog\n\n## Unreleased\n\n- Added release manifest.\n")
    for doc in docs:
        write_text(doc, f"# {doc.stem}\n")

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
        "release_signature_schema": release_signature_schema,
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
                manifest["checksum_bundle"]["outputs"][0]["sha256"],
                generator.CHECKSUM_DIGEST_STATUS,
            )
            self.assertTrue(
                manifest["checksum_bundle"]["coverage_expectation"][
                    "covered_by_checksum_bundle"
                ]
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
