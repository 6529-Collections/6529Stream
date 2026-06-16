#!/usr/bin/env python3
"""Focused tests for dependency provenance attestation generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_dependency_provenance_attestation.py")
SPEC = importlib.util.spec_from_file_location(
    "generate_dependency_provenance_attestation",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


VALID_KEY = "0x" + "1" * 64


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def file_record(root: Path, relative_path: str, *, schema_version: str | None = None) -> dict[str, object]:
    path = root / relative_path
    record: dict[str, object] = {
        "path": relative_path,
        "sha256": generator.file_sha256(path),
        "size_bytes": path.stat().st_size,
    }
    if schema_version is not None:
        record["schema_version"] = schema_version
    return record


def artifact_manifest(root: Path) -> dict[str, object]:
    return {
        "schema_version": generator.DEPENDENCY_ARTIFACT_MANIFEST_SCHEMA,
        "generated_by": "unit-test",
        "source": {
            "output": "release-artifacts/latest/dependency-artifact-manifest.json",
            "descriptor_dir": "release-artifacts/dependencies",
            "descriptor_count": 1,
        },
        "artifacts": [
            {
                "descriptor": file_record(
                    root,
                    "release-artifacts/dependencies/anvil/example.dependency.json",
                    schema_version="6529stream.dependency-artifact.v1",
                ),
                "protocol_version": "0.1.0",
                "deployment_version": "anvil-001",
                "dependency": {
                    "name": "example",
                    "key": VALID_KEY,
                    "key_preimage": "example.dependency",
                    "version": 1,
                    "registry_contract": "DependencyRegistry",
                    "provenance": "local-test",
                },
                "source": {
                    "registered_by": "script/RehearseDeployment.s.sol:_createSampleCollection",
                    "notes": "test fixture",
                },
                "files": [
                    {
                        **file_record(root, "release-artifacts/dependencies/anvil/example.js"),
                        "role": "script",
                        "media_type": "application/javascript",
                    }
                ],
            }
        ],
    }


def seed_dependency_bundle(root: Path) -> tuple[Path, Path]:
    descriptor_path = root / "release-artifacts" / "dependencies" / "anvil" / "example.dependency.json"
    source_path = root / "release-artifacts" / "dependencies" / "anvil" / "example.js"
    manifest_path = root / "release-artifacts" / "latest" / "dependency-artifact-manifest.json"
    output_path = root / "release-artifacts" / "latest" / "dependency-provenance-attestation.json"
    write_text(source_path, "function draw() { return 6529; }\n")
    write_json(
        descriptor_path,
        {
            "schema_version": "6529stream.dependency-artifact.v1",
            "protocol_version": "0.1.0",
            "deployment_version": "anvil-001",
        },
    )
    write_json(manifest_path, artifact_manifest(root))
    return manifest_path, output_path


class DependencyProvenanceAttestationTests(unittest.TestCase):
    def test_generator_writes_deterministic_attestation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path, output_path = seed_dependency_bundle(root)

            written = generator.write_output(root, manifest_path, output_path)
            first = written.read_text(encoding="utf-8")
            generator.write_output(root, manifest_path, output_path)
            self.assertEqual(first, written.read_text(encoding="utf-8"))

            attestation = json.loads(first)
            self.assertEqual(attestation["schema_version"], generator.ATTESTATION_SCHEMA)
            self.assertEqual(attestation["release_status"]["status"], "pre_audit_local_baseline")
            self.assertIn("does not prove live chain registration", attestation["release_status"]["limitations"])
            self.assertEqual(attestation["source"]["descriptor_count"], 1)
            artifact = attestation["artifacts"][0]
            self.assertEqual(artifact["identity"]["dependency_key"], VALID_KEY)
            self.assertEqual(artifact["source"]["provenance"], "local-test")
            self.assertTrue(artifact["artifact_digest"].startswith("sha256:"))

    def test_check_mode_accepts_current_attestation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path, output_path = seed_dependency_bundle(root)
            generator.write_output(root, manifest_path, output_path)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_output(root, manifest_path, output_path)
            self.assertEqual(result, 0)

    def test_check_mode_rejects_stale_attestation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path, output_path = seed_dependency_bundle(root)
            generator.write_output(root, manifest_path, output_path)
            attestation = json.loads(output_path.read_text(encoding="utf-8"))
            attestation["release_status"]["status"] = "changed"
            write_json(output_path, attestation)

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(root, manifest_path, output_path)
            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/dependency-provenance-attestation.json",
                stderr.getvalue(),
            )

    def test_generator_rejects_source_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path, output_path = seed_dependency_bundle(root)
            write_text(root / "release-artifacts" / "dependencies" / "anvil" / "example.js", "changed\n")

            with self.assertRaisesRegex(generator.DependencyProvenanceAttestationError, "sha256 mismatch"):
                generator.build_output_text(root, manifest_path, output_path)

    def test_generator_rejects_manifest_path_escape(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path, output_path = seed_dependency_bundle(root)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["artifacts"][0]["files"][0]["path"] = "release-artifacts/dependencies/../escape.js"
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.DependencyProvenanceAttestationError, "parent-directory"):
                generator.build_output_text(root, manifest_path, output_path)

    def test_generator_rejects_secret_shaped_manifest_value(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path, output_path = seed_dependency_bundle(root)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["artifacts"][0]["source"]["notes"] = "api_key=abc123"
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.DependencyProvenanceAttestationError, "secret-like value"):
                generator.build_output_text(root, manifest_path, output_path)

    def test_generator_rejects_descriptor_count_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path, output_path = seed_dependency_bundle(root)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["source"]["descriptor_count"] = 2
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.DependencyProvenanceAttestationError, "descriptor_count"):
                generator.build_output_text(root, manifest_path, output_path)

    def test_generator_rejects_invalid_manifest_schema(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path, output_path = seed_dependency_bundle(root)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["schema_version"] = "wrong"
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.DependencyProvenanceAttestationError, "schema_version"):
                generator.build_output_text(root, manifest_path, output_path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
