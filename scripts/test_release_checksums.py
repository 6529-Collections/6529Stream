#!/usr/bin/env python3
"""Focused tests for release checksum bundle generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_release_checksums.py")
SPEC = importlib.util.spec_from_file_location("generate_release_checksums", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


class ReleaseChecksumTests(unittest.TestCase):
    def test_default_covered_paths_include_evidence_artifacts(self) -> None:
        self.assertIn(Path("release-artifacts/schema"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("release-artifacts/evidence"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(
            Path("release-artifacts/drop-authorization-signing"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("release-artifacts/signer-custody-readiness"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(Path("release-artifacts/permanence"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("release-artifacts/provenance"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("deployments/admin-ceremony"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("release-artifacts/signatures"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("test/fixtures/drop-authorization"), generator.DEFAULT_COVERED_PATHS)

    def test_committed_checksums_cover_permanence_package_artifacts(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        expected_paths = {
            "release-artifacts/latest/one-of-one-permanence-manifest.json",
            "release-artifacts/permanence/one-of-one-permanence-template.permanence.json",
            "release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md",
            "release-artifacts/schema/one-of-one-permanence-package.schema.json",
        }

        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            relative_path: digest
            for digest, relative_path in generator.parse_checksum_file(checksum_text)
        }
        self.assertTrue(expected_paths <= set(checksum_entries))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}

        for relative_path in expected_paths:
            path = repo_root / relative_path
            expected_hash = generator.file_sha256(path)
            self.assertEqual(
                checksum_entries[relative_path],
                expected_hash.removeprefix("sha256:"),
            )
            self.assertIn(relative_path, manifest_entries)
            self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
            self.assertEqual(
                manifest_entries[relative_path]["size_bytes"],
                path.stat().st_size,
            )

    def test_committed_checksums_cover_retained_live_audit_reports(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        expected_paths = {
            "release-artifacts/evidence/live-audit-reports/20260614T015000Z-release-evidence-live-audit-dry-run.json",
            "release-artifacts/evidence/live-audit-reports/20260614T015000Z-release-evidence-live-audit-dry-run.md",
            "release-artifacts/latest/release-evidence-live-audit-report-archive.json",
            "release-artifacts/latest/release-evidence-live-audit-report-archive.md",
        }

        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            relative_path: digest
            for digest, relative_path in generator.parse_checksum_file(checksum_text)
        }
        self.assertTrue(expected_paths <= set(checksum_entries))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}

        for relative_path in expected_paths:
            path = repo_root / relative_path
            expected_hash = generator.file_sha256(path)
            self.assertEqual(
                checksum_entries[relative_path],
                expected_hash.removeprefix("sha256:"),
            )
            self.assertIn(relative_path, manifest_entries)
            self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
            self.assertEqual(
                manifest_entries[relative_path]["size_bytes"],
                path.stat().st_size,
            )

    def test_committed_checksums_cover_bytecode_release_proof(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        relative_path = "release-artifacts/latest/bytecode-release-proof.json"
        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            path: digest for digest, path in generator.parse_checksum_file(checksum_text)
        }
        self.assertIn(relative_path, checksum_entries)

        proof_path = repo_root / relative_path
        expected_hash = generator.file_sha256(proof_path)
        self.assertEqual(checksum_entries[relative_path], expected_hash.removeprefix("sha256:"))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}
        self.assertIn(relative_path, manifest_entries)
        self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
        self.assertEqual(manifest_entries[relative_path]["size_bytes"], proof_path.stat().st_size)

    def test_committed_checksums_cover_risk_register(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        relative_path = "release-artifacts/latest/risk-register.json"
        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            path: digest for digest, path in generator.parse_checksum_file(checksum_text)
        }
        self.assertIn(relative_path, checksum_entries)

        register_path = repo_root / relative_path
        expected_hash = generator.file_sha256(register_path)
        self.assertEqual(checksum_entries[relative_path], expected_hash.removeprefix("sha256:"))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}
        self.assertIn(relative_path, manifest_entries)
        self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
        self.assertEqual(
            manifest_entries[relative_path]["size_bytes"],
            register_path.stat().st_size,
        )

    def test_generator_writes_sorted_checksums_and_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "release-artifacts" / "latest"
            write_text(output_dir / "event-topic-catalog.json", '{"events":[]}\n')
            write_text(output_dir / "abi-checksums.json", '{"abis":[]}\n')
            write_text(output_dir / "release-manifest.json", '{"release":{}}\n')
            write_text(
                root / "release-artifacts" / "baselines" / "v0.1.0" / "gas-snapshot.snap",
                "StreamGasSnapshotTest:testGasFixedPriceMint() (gas: 1)\n",
            )
            write_text(
                root / "deployments" / "examples" / "anvil.json",
                '{"chain":31337}\n',
            )

            written = generator.write_outputs(
                root,
                [
                    Path("release-artifacts/latest"),
                    Path("release-artifacts/baselines"),
                    Path("deployments/examples"),
                ],
                output_dir,
            )
            self.assertEqual(
                [path.name for path in written],
                ["SHA256SUMS", "release-checksums.json"],
            )

            checksum_lines = (output_dir / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
            covered_paths = [line.split("  ", 1)[1] for line in checksum_lines]
            self.assertEqual(
                covered_paths,
                [
                    "deployments/examples/anvil.json",
                    "release-artifacts/baselines/v0.1.0/gas-snapshot.snap",
                    "release-artifacts/latest/abi-checksums.json",
                    "release-artifacts/latest/event-topic-catalog.json",
                    "release-artifacts/latest/release-manifest.json",
                ],
            )
            self.assertNotIn("release-artifacts/latest/SHA256SUMS", covered_paths)
            self.assertNotIn("release-artifacts/latest/release-checksums.json", covered_paths)

            manifest = json.loads(
                (output_dir / "release-checksums.json").read_text(encoding="utf-8")
            )
            self.assertEqual(manifest["schema_version"], generator.CHECKSUM_SCHEMA)
            self.assertEqual(manifest["algorithm"], "sha256")
            self.assertEqual(manifest["source"]["output_dir"], "release-artifacts/latest")
            self.assertEqual(
                manifest["source"]["covered_paths"],
                [
                    "release-artifacts/latest",
                    "release-artifacts/baselines",
                    "deployments/examples",
                ],
            )
            self.assertEqual(
                manifest["text_checksum_file"]["sha256"],
                generator.sha256_bytes((output_dir / "SHA256SUMS").read_bytes()),
            )
            self.assertEqual(
                [entry["path"] for entry in manifest["files"]],
                covered_paths,
            )

    def test_check_mode_accepts_current_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "release-artifacts" / "latest"
            write_text(output_dir / "abi-checksums.json", '{"abis":[]}\n')
            generator.write_outputs(root, [Path("release-artifacts/latest")], output_dir)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_outputs(
                    root,
                    [Path("release-artifacts/latest")],
                    output_dir,
                )
            self.assertEqual(result, 0)

    def test_check_mode_rejects_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "release-artifacts" / "latest"
            artifact = output_dir / "abi-checksums.json"
            write_text(artifact, '{"abis":[]}\n')
            generator.write_outputs(root, [Path("release-artifacts/latest")], output_dir)
            write_text(artifact, '{"abis":["changed"]}\n')

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    [Path("release-artifacts/latest")],
                    output_dir,
                )
            self.assertEqual(result, 1)
            self.assertIn(
                "hash mismatch for release-artifacts/latest/abi-checksums.json",
                stderr.getvalue(),
            )
            self.assertIn("changed release-artifacts/latest/SHA256SUMS", stderr.getvalue())

    def test_check_mode_rejects_deleted_covered_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "release-artifacts" / "latest"
            artifact = output_dir / "abi-checksums.json"
            write_text(artifact, '{"abis":[]}\n')
            generator.write_outputs(root, [Path("release-artifacts/latest")], output_dir)
            artifact.unlink()

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    [Path("release-artifacts/latest")],
                    output_dir,
            )
            self.assertEqual(result, 1)
            missing_message = (
                "missing covered file listed in SHA256SUMS: "
                "release-artifacts/latest/abi-checksums.json"
            )
            self.assertIn(
                missing_message,
                stderr.getvalue(),
            )

    def test_check_mode_rejects_missing_generated_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "release-artifacts" / "latest"
            write_text(output_dir / "abi-checksums.json", '{"abis":[]}\n')
            generator.write_outputs(root, [Path("release-artifacts/latest")], output_dir)
            (output_dir / "SHA256SUMS").unlink()

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    [Path("release-artifacts/latest")],
                    output_dir,
                )
            self.assertEqual(result, 1)
            self.assertIn("missing release-artifacts/latest/SHA256SUMS", stderr.getvalue())

    def test_generator_rejects_missing_covered_root(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "release-artifacts" / "latest"

            with self.assertRaisesRegex(generator.ChecksumError, "covered path does not exist"):
                generator.build_outputs(root, [Path("missing")], output_dir)

    def test_generator_rejects_empty_covered_set(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "release-artifacts" / "latest"
            (root / "empty").mkdir()

            with self.assertRaisesRegex(generator.ChecksumError, "did not contain any files"):
                generator.build_outputs(root, [Path("empty")], output_dir)

    def test_checksum_parser_rejects_parent_directory_paths(self) -> None:
        checksum = (
            "0" * 64
            + "  release-artifacts/latest/../secrets.json\n"
        )

        with self.assertRaisesRegex(generator.ChecksumError, "path traversal"):
            generator.parse_checksum_file(checksum)


if __name__ == "__main__":
    unittest.main(verbosity=2)
