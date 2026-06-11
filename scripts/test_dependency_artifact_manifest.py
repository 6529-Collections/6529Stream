#!/usr/bin/env python3
"""Focused tests for dependency artifact manifest generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_dependency_artifact_manifest.py")
SPEC = importlib.util.spec_from_file_location("generate_dependency_artifact_manifest", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


VALID_KEY = "0x" + "1" * 64


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def descriptor(
    *,
    key: str = VALID_KEY,
    version: int = 1,
    file_path: str = "release-artifacts/dependencies/anvil/example.js",
) -> dict[str, object]:
    return {
        "schema_version": generator.DEPENDENCY_ARTIFACT_SCHEMA,
        "protocol_version": "0.1.0",
        "deployment_version": "anvil-001",
        "dependency": {
            "name": "example",
            "key": key,
            "key_preimage": "example.dependency",
            "version": version,
            "registry_contract": "DependencyRegistry",
            "provenance": "local-test",
        },
        "source": {
            "registered_by": "script/RehearseDeployment.s.sol:_createSampleCollection",
            "notes": "test fixture",
        },
        "files": [
            {
                "path": file_path,
                "role": "script",
                "media_type": "application/javascript",
            }
        ],
    }


def seed_dependency_tree(root: Path) -> tuple[Path, Path]:
    descriptor_dir = root / "release-artifacts" / "dependencies"
    output = root / "release-artifacts" / "latest" / "dependency-artifact-manifest.json"
    write_text(descriptor_dir / "anvil" / "example.js", "function draw() { return 6529; }\n")
    write_json(descriptor_dir / "anvil" / "example.dependency.json", descriptor())
    return descriptor_dir, output


class DependencyArtifactManifestTests(unittest.TestCase):
    def test_generator_writes_deterministic_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_dependency_tree(root)

            written = generator.write_output(root, descriptor_dir, output)
            first = written.read_text(encoding="utf-8")
            generator.write_output(root, descriptor_dir, output)
            self.assertEqual(first, written.read_text(encoding="utf-8"))

            manifest = json.loads(first)
            self.assertEqual(
                manifest["schema_version"],
                generator.DEPENDENCY_ARTIFACT_MANIFEST_SCHEMA,
            )
            self.assertEqual(manifest["source"]["descriptor_count"], 1)
            artifact = manifest["artifacts"][0]
            self.assertEqual(artifact["dependency"]["key"], VALID_KEY)
            self.assertEqual(
                artifact["descriptor"]["path"],
                "release-artifacts/dependencies/anvil/example.dependency.json",
            )
            self.assertEqual(
                artifact["files"][0]["sha256"],
                generator.file_sha256(descriptor_dir / "anvil" / "example.js"),
            )

    def test_check_mode_accepts_current_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_dependency_tree(root)
            generator.write_output(root, descriptor_dir, output)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_output(root, descriptor_dir, output)
            self.assertEqual(result, 0)

    def test_check_mode_rejects_output_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_dependency_tree(root)
            generator.write_output(root, descriptor_dir, output)
            write_text(descriptor_dir / "anvil" / "example.js", "changed\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(root, descriptor_dir, output)
            self.assertEqual(result, 1)
            self.assertIn("changed release-artifacts/latest/dependency-artifact-manifest.json", stderr.getvalue())

    def test_generator_rejects_missing_artifact_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_dependency_tree(root)
            (descriptor_dir / "anvil" / "example.js").unlink()

            with self.assertRaisesRegex(generator.DependencyArtifactError, "missing required file"):
                generator.build_output_text(root, descriptor_dir, output)

    def test_generator_rejects_malformed_dependency_key(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_dependency_tree(root)
            write_json(
                descriptor_dir / "anvil" / "example.dependency.json",
                descriptor(key="0x1234"),
            )

            with self.assertRaisesRegex(generator.DependencyArtifactError, "32-byte hex"):
                generator.build_output_text(root, descriptor_dir, output)

    def test_generator_rejects_duplicate_dependency_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_dependency_tree(root)
            write_text(descriptor_dir / "anvil" / "copy.js", "function copy() {}\n")
            write_json(
                descriptor_dir / "anvil" / "copy.dependency.json",
                descriptor(file_path="release-artifacts/dependencies/anvil/copy.js"),
            )

            with self.assertRaisesRegex(generator.DependencyArtifactError, "duplicate dependency artifact"):
                generator.build_output_text(root, descriptor_dir, output)

    def test_generator_rejects_artifact_path_outside_dependency_root(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_dependency_tree(root)
            write_text(root / "docs" / "not-a-dependency.js", "secret\n")
            write_json(
                descriptor_dir / "anvil" / "example.dependency.json",
                descriptor(file_path="docs/not-a-dependency.js"),
            )

            with self.assertRaisesRegex(generator.DependencyArtifactError, "must stay under"):
                generator.build_output_text(root, descriptor_dir, output)

    def test_generator_rejects_parent_directory_artifact_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_dependency_tree(root)
            write_json(
                descriptor_dir / "anvil" / "example.dependency.json",
                descriptor(file_path="release-artifacts/dependencies/anvil/../escape.js"),
            )

            with self.assertRaisesRegex(generator.DependencyArtifactError, "parent-directory"):
                generator.build_output_text(root, descriptor_dir, output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
