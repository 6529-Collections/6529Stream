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
    contract_config = root / "release-artifacts" / "contracts.json"
    deployment_config_dir = root / "deployments" / "config"
    deployment_manifest_dir = root / "deployments" / "examples"
    address_book_dir = root / "deployments" / "address-books"
    deployment_schema_dir = root / "deployments" / "schema"
    output = latest / "release-manifest.json"
    changelog = root / "CHANGELOG.md"
    docs = [
        root / "docs" / "release-policy.md",
        root / "docs" / "deployment.md",
        root / "docs" / "tooling.md",
        root / "docs" / "status.md",
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
        baseline,
        {"schema_version": "6529stream.abi-surface.v1", "contracts": {}},
    )
    write_json(
        deployment_config_dir / "anvil.json",
        {"schema_version": "6529stream.deployment-manifest-input.v1"},
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
    write_text(changelog, "# Changelog\n\n## Unreleased\n\n- Added release manifest.\n")
    for doc in docs:
        write_text(doc, f"# {doc.stem}\n")

    return {
        "latest": latest,
        "baseline": baseline,
        "contract_config": contract_config,
        "deployment_config_dir": deployment_config_dir,
        "deployment_manifest_dir": deployment_manifest_dir,
        "address_book_dir": address_book_dir,
        "deployment_schema_dir": deployment_schema_dir,
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
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
                paths["changelog"],
                paths["docs"],
            )
            first = written.read_text(encoding="utf-8")
            generator.write_output(
                root,
                paths["output"],
                paths["latest"],
                paths["baseline"],
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
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
                manifest["deployment_artifacts"]["manifests"][0]["contracts"],
                ["Example"],
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
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
                paths["changelog"],
                paths["docs"],
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_output(
                    root,
                    paths["output"],
                    paths["latest"],
                    paths["baseline"],
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["changelog"],
                    paths["docs"],
                )
            self.assertEqual(result, 0)

    def test_check_mode_rejects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_release_tree(root)
            generator.write_output(
                root,
                paths["output"],
                paths["latest"],
                paths["baseline"],
                paths["contract_config"],
                paths["deployment_config_dir"],
                paths["deployment_manifest_dir"],
                paths["address_book_dir"],
                paths["deployment_schema_dir"],
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
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["changelog"],
                    paths["docs"],
                )
            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/release-manifest.json",
                stderr.getvalue(),
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
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
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
                    paths["contract_config"],
                    paths["deployment_config_dir"],
                    paths["deployment_manifest_dir"],
                    paths["address_book_dir"],
                    paths["deployment_schema_dir"],
                    paths["changelog"],
                    paths["docs"],
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
