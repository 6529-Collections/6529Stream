#!/usr/bin/env python3
"""Focused tests for release artifact verification."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("verify_release_artifacts.py")
SPEC = importlib.util.spec_from_file_location("verify_release_artifacts", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def file_record(root: Path, relative_path: str) -> dict[str, object]:
    path = root / relative_path
    return {
        "path": relative_path,
        "sha256": verifier.file_sha256(path),
        "size_bytes": path.stat().st_size,
    }


def write_checksum_bundle(root: Path, covered_paths: list[str]) -> None:
    latest = root / "release-artifacts" / "latest"
    checksum_lines = []
    files = []
    for relative_path in sorted(covered_paths):
        path = root / relative_path
        digest = verifier.file_sha256(path).removeprefix("sha256:")
        checksum_lines.append(f"{digest}  {relative_path}")
        files.append(
            {
                "path": relative_path,
                "sha256": f"sha256:{digest}",
                "size_bytes": path.stat().st_size,
            }
        )
    checksum_text = "\n".join(checksum_lines) + "\n"
    write_text(latest / "SHA256SUMS", checksum_text)
    write_json(
        latest / "release-checksums.json",
        {
            "schema_version": verifier.CHECKSUM_SCHEMA,
            "generated_by": "unit-test",
            "algorithm": "sha256",
            "source": {
                "covered_paths": ["release-artifacts/latest"],
                "output_dir": "release-artifacts/latest",
            },
            "text_checksum_file": {
                "path": "release-artifacts/latest/SHA256SUMS",
                "format": "sha256sum",
                "sha256": verifier.sha256_bytes(checksum_text.encode("utf-8")),
            },
            "manifest_file": {
                "path": "release-artifacts/latest/release-checksums.json",
                "self_hash": False,
            },
            "files": files,
        },
    )


def seed_release_bundle(root: Path) -> None:
    latest = root / "release-artifacts" / "latest"
    write_text(latest / "abi-checksums.json", '{"schema_version":"fixture.abi"}\n')
    write_text(
        root / "deployments" / "examples" / "anvil.json",
        '{"schema_version":"fixture.deployment"}\n',
    )

    write_json(
        latest / "release-manifest.json",
        {
            "schema_version": verifier.RELEASE_MANIFEST_SCHEMA,
            "generated_by": "unit-test",
            "release_artifacts": {
                "abi_checksums": file_record(
                    root,
                    "release-artifacts/latest/abi-checksums.json",
                )
            },
            "deployment_artifacts": {
                "manifests": [
                    file_record(root, "deployments/examples/anvil.json")
                ]
            },
            "checksum_bundle": {
                "outputs": [
                    {
                        "path": "release-artifacts/latest/SHA256SUMS",
                        "sha256": "not_available_self_referential",
                    }
                ]
            },
        },
    )
    write_json(
        latest / "bytecode-release-proof.json",
        {
            "schema_version": verifier.BYTECODE_PROOF_SCHEMA,
            "generated_by": "unit-test",
            "source": {
                "release_manifest": file_record(
                    root,
                    "release-artifacts/latest/release-manifest.json",
                ),
                "deployment_manifests": [
                    file_record(root, "deployments/examples/anvil.json")
                ],
            },
        },
    )
    write_json(
        latest / "release-candidate-lockfile.json",
        {
            "schema_version": verifier.RELEASE_CANDIDATE_LOCKFILE_SCHEMA,
            "generated_by": "unit-test",
            "locked_inputs": {
                "release_manifest": file_record(
                    root,
                    "release-artifacts/latest/release-manifest.json",
                ),
                "bytecode_release_proof": file_record(
                    root,
                    "release-artifacts/latest/bytecode-release-proof.json",
                ),
            },
            "checksum_bundle": {
                "outputs": [
                    {
                        "path": "release-artifacts/latest/SHA256SUMS",
                        "sha256": "not_available_self_referential",
                    }
                ]
            },
        },
    )
    write_checksum_bundle(
        root,
        [
            "deployments/examples/anvil.json",
            "release-artifacts/latest/abi-checksums.json",
            "release-artifacts/latest/bytecode-release-proof.json",
            "release-artifacts/latest/release-candidate-lockfile.json",
            "release-artifacts/latest/release-manifest.json",
        ],
    )


class ReleaseArtifactVerifierTests(unittest.TestCase):
    def test_committed_release_bundle_verifies(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        summary = verifier.verify_release_artifacts(repo_root)
        self.assertGreater(summary.checksum_entries, 0)
        self.assertGreater(summary.release_manifest_records, 0)
        self.assertGreater(summary.bytecode_proof_records, 0)

    def test_main_json_output(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        stdout = StringIO()
        with redirect_stdout(stdout), redirect_stderr(StringIO()):
            result = verifier.main(["--repo-root", str(repo_root), "--json"])
        self.assertEqual(result, 0)
        data = json.loads(stdout.getvalue())
        self.assertGreater(data["checksum_entries"], 0)

    def test_main_failure_returns_nonzero_and_stderr(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_text(root / "release-artifacts" / "latest" / "abi-checksums.json", "changed\n")
            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = verifier.main(["--repo-root", str(root)])
            self.assertEqual(result, 1)
            self.assertIn("error: SHA256SUMS hash mismatch", stderr.getvalue())

    def test_minimal_bundle_verifies(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            summary = verifier.verify_release_artifacts(root)
            self.assertEqual(summary.checksum_entries, 5)
            self.assertEqual(summary.checksum_manifest_records, 5)

    def test_checksum_parser_rejects_duplicate_paths(self) -> None:
        line = "0" * 64 + "  release-artifacts/latest/a.json\n"
        with self.assertRaisesRegex(verifier.ReleaseArtifactVerificationError, "duplicate path"):
            verifier.parse_checksum_file(line + line)

    def test_checksum_parser_rejects_parent_directory_paths(self) -> None:
        checksum = "0" * 64 + "  release-artifacts/latest/../secret.json\n"
        with self.assertRaisesRegex(verifier.ReleaseArtifactVerificationError, "path traversal"):
            verifier.parse_checksum_file(checksum)

    def test_verifier_rejects_missing_checksum_covered_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            (root / "release-artifacts" / "latest" / "abi-checksums.json").unlink()
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "SHA256SUMS references missing file",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_stale_checksum_file_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_text(root / "release-artifacts" / "latest" / "abi-checksums.json", "changed\n")
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "SHA256SUMS hash mismatch",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_release_checksum_manifest_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            manifest_path = root / "release-artifacts" / "latest" / "release-checksums.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"][0]["sha256"] = "sha256:" + "1" * 64
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "release-checksums hash mismatch",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_release_manifest_file_record_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            manifest_path = root / "release-artifacts" / "latest" / "release-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["release_artifacts"]["abi_checksums"]["sha256"] = "sha256:" + "2" * 64
            write_json(manifest_path, manifest)
            write_checksum_bundle(
                root,
                [
                    "deployments/examples/anvil.json",
                    "release-artifacts/latest/abi-checksums.json",
                    "release-artifacts/latest/bytecode-release-proof.json",
                    "release-artifacts/latest/release-candidate-lockfile.json",
                    "release-artifacts/latest/release-manifest.json",
                ],
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "release-manifest.json.release_artifacts.abi_checksums hash mismatch",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_requires_nested_release_manifest_checksum_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_checksum_bundle(
                root,
                [
                    "release-artifacts/latest/abi-checksums.json",
                    "release-artifacts/latest/bytecode-release-proof.json",
                    "release-artifacts/latest/release-candidate-lockfile.json",
                    "release-artifacts/latest/release-manifest.json",
                ],
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                (
                    "release-manifest.json.deployment_artifacts.manifests\\[0\\] "
                    "references file not covered by SHA256SUMS"
                ),
            ):
                verifier.verify_release_artifacts(root)

    def test_checksum_record_rejects_nested_hash_mismatch(self) -> None:
        with self.assertRaisesRegex(
            verifier.ReleaseArtifactVerificationError,
            "checksum hash mismatch for release-artifacts/latest/a.json",
        ):
            verifier.require_checksum_record(
                {"release-artifacts/latest/a.json": "0" * 64},
                path="release-artifacts/latest/a.json",
                sha256="sha256:" + "1" * 64,
                source="release-manifest.json.release_artifacts.a",
            )

    def test_verifier_rejects_malformed_manifest_sha_marker(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            manifest_path = root / "release-artifacts" / "latest" / "release-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["checksum_bundle"]["outputs"][0]["sha256"] = "legacy-marker"
            write_json(manifest_path, manifest)
            write_checksum_bundle(
                root,
                [
                    "deployments/examples/anvil.json",
                    "release-artifacts/latest/abi-checksums.json",
                    "release-artifacts/latest/bytecode-release-proof.json",
                    "release-artifacts/latest/release-candidate-lockfile.json",
                    "release-artifacts/latest/release-manifest.json",
                ],
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "invalid sha256 marker",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_bytecode_proof_release_manifest_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            proof_path = root / "release-artifacts" / "latest" / "bytecode-release-proof.json"
            proof = json.loads(proof_path.read_text(encoding="utf-8"))
            proof["source"]["release_manifest"]["sha256"] = "sha256:" + "3" * 64
            write_json(proof_path, proof)
            write_checksum_bundle(
                root,
                [
                    "deployments/examples/anvil.json",
                    "release-artifacts/latest/abi-checksums.json",
                    "release-artifacts/latest/bytecode-release-proof.json",
                    "release-artifacts/latest/release-candidate-lockfile.json",
                    "release-artifacts/latest/release-manifest.json",
                ],
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "bytecode-release-proof.json.source.release_manifest hash mismatch",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_requires_release_manifest_checksum_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_checksum_bundle(
                root,
                [
                    "deployments/examples/anvil.json",
                    "release-artifacts/latest/abi-checksums.json",
                    "release-artifacts/latest/bytecode-release-proof.json",
                ],
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "required files are not checksum-covered",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_requires_release_candidate_lockfile_checksum_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_checksum_bundle(
                root,
                [
                    "deployments/examples/anvil.json",
                    "release-artifacts/latest/abi-checksums.json",
                    "release-artifacts/latest/bytecode-release-proof.json",
                    "release-artifacts/latest/release-manifest.json",
                ],
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "required files are not checksum-covered",
            ):
                verifier.verify_release_artifacts(root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
