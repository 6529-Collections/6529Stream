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
from unittest import mock


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
    effective_paths = set(covered_paths)
    genesis_profile = (
        verifier.governed_parameter_inventory_checker.GENESIS_PROFILE
    ).as_posix()
    if (root / genesis_profile).is_file():
        effective_paths.add(genesis_profile)
    for relative_path in sorted(effective_paths):
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


def seed_governed_parameter_inventory_tree(root: Path) -> None:
    source_root = SCRIPT_PATH.parent.parent
    inventory = json.loads(
        (
            source_root
            / verifier.governed_parameter_inventory_checker.DEFAULT_INVENTORY
        ).read_text(encoding="utf-8")
    )
    write_json(
        root / verifier.governed_parameter_inventory_checker.DEFAULT_INVENTORY,
        inventory,
    )

    dependency_paths = {
        Path(source["path"])
        for source in inventory["normative_sources"]
    }
    dependency_paths.update(
        Path(parameter["normative_source"]["path"])
        for parameter in inventory["parameters"]
    )
    dependency_paths.add(
        verifier.governed_parameter_inventory_checker.GENESIS_PROFILE
    )
    dependency_paths.add(
        verifier.governed_parameter_inventory_checker.DEFAULT_SCHEMA
    )
    for relative_path in dependency_paths:
        write_text(
            root / relative_path,
            (source_root / relative_path).read_text(encoding="utf-8"),
        )


def seed_release_bundle(root: Path) -> None:
    latest = root / "release-artifacts" / "latest"
    write_text(latest / "abi-checksums.json", '{"schema_version":"fixture.abi"}\n')
    seed_governed_parameter_inventory_tree(root)
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
                ),
                "governed_parameter_inventory": {
                    **file_record(
                        root,
                        verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
                    ),
                    "schema_version": verifier.GOVERNED_PARAMETER_INVENTORY_SCHEMA,
                },
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
                "governed_parameter_inventory": {
                    **file_record(
                        root,
                        verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
                    ),
                    "schema_version": verifier.GOVERNED_PARAMETER_INVENTORY_SCHEMA,
                },
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
            verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
            verifier.governed_parameter_inventory_checker.GENESIS_PROFILE.as_posix(),
            "release-artifacts/latest/abi-checksums.json",
            "release-artifacts/latest/bytecode-release-proof.json",
            "release-artifacts/latest/release-candidate-lockfile.json",
            "release-artifacts/latest/release-manifest.json",
        ],
    )


class ReleaseArtifactVerifierTests(unittest.TestCase):
    def test_offline_verifier_invokes_canonical_inventory_validator(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            with mock.patch.object(
                verifier.governed_parameter_inventory_checker,
                "validate_inventory",
                wraps=(
                    verifier.governed_parameter_inventory_checker.validate_inventory
                ),
            ) as validate_inventory:
                verifier.verify_release_artifacts(root)

        validate_inventory.assert_called_once_with(
            root.resolve(),
            verifier.governed_parameter_inventory_checker.DEFAULT_INVENTORY,
            require_complete=False,
        )

    def test_offline_verifier_rejects_malformed_planning_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            inventory_path = (
                root
                / verifier.governed_parameter_inventory_checker.DEFAULT_INVENTORY
            )
            inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
            inventory["status"] = "complete"
            write_json(inventory_path, inventory)

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "semantic validation failed.*inventory.status must be 'planning'",
            ):
                verifier.verify_release_artifacts(root)

    def test_every_complete_inventory_reference_requires_checksum_coverage(
        self,
    ) -> None:
        inventory = {
            "genesis_profile": {
                "path": "release-artifacts/genesis-deployment-profile.json",
                "sha256": "0" * 64,
            },
            "candidate_binding": {
                "status": "complete",
                "candidate_artifact_path": "release-artifacts/candidate.json",
                "candidate_artifact_sha256": "1" * 64,
                "host_bindings": [
                    {
                        "source_verification_binding": {
                            "path": (
                                "release-artifacts/latest/"
                                "source-verification-inputs.json"
                            ),
                            "sha256": "4" * 64,
                        }
                    }
                ],
            },
            "parameters": [
                {
                    "measurement_evidence": {
                        "status": "complete",
                        "path": "release-artifacts/evidence/measurement.json",
                        "sha256": "2" * 64,
                    },
                    "fixed_stipend_compatibility": {
                        "status": "complete",
                        "evidence_path": (
                            "release-artifacts/evidence/fixed-stipend.json"
                        ),
                        "evidence_sha256": "3" * 64,
                    },
                }
            ],
        }
        references = (
            verifier.release_checksum_generator.complete_governed_parameter_references(
                inventory
            )
        )
        all_entries = {
            path.as_posix(): sha256
            for path, sha256, _source in references
        }
        for missing_path, recorded_sha256, source in references:
            with self.subTest(source=source):
                checksum_entries = dict(all_entries)
                del checksum_entries[missing_path.as_posix()]
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "complete reference is not covered",
                ):
                    verifier.verify_governed_parameter_reference_checksum_coverage(
                        Path.cwd(),
                        inventory,
                        checksum_entries,
                    )
                checksum_entries = dict(all_entries)
                checksum_entries[missing_path.as_posix()] = (
                    "f" * 64 if recorded_sha256 != "f" * 64 else "e" * 64
                )
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "complete reference hash does not match",
                ):
                    verifier.verify_governed_parameter_reference_checksum_coverage(
                        Path.cwd(),
                        inventory,
                        checksum_entries,
                    )

    def test_full_verifier_rejects_unchecksummed_complete_candidate_reference(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            inventory = {
                "candidate_binding": {
                    "status": "complete",
                    "candidate_artifact_path": (
                        "release-artifacts/candidate.json"
                    ),
                    "candidate_artifact_sha256": "1" * 64,
                },
                "parameters": [],
            }
            with mock.patch.object(
                verifier,
                "validate_governed_parameter_inventory_semantics",
                return_value=inventory,
            ):
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "candidate_binding complete reference is not covered",
                ):
                    verifier.verify_release_artifacts(root)

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
            self.assertEqual(summary.checksum_entries, 7)
            self.assertEqual(summary.checksum_manifest_records, 7)

    def test_verifier_requires_direct_governed_parameter_inventory_bindings(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")
            del lockfile["locked_inputs"]["governed_parameter_inventory"]

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "governed_parameter_inventory",
            ):
                verifier.verify_governed_parameter_inventory_bindings(
                    release_manifest,
                    lockfile,
                )

    def test_verifier_rejects_unchecksummed_extra_release_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_text(root / "release-artifacts" / "latest" / "unlisted.json", "{}\n")
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "unchecksummed file",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_nested_unchecksummed_release_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_text(
                root / "release-artifacts" / "latest" / "nested" / "unlisted.json",
                "{}\n",
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "release-artifacts/latest/nested/unlisted.json",
            ):
                verifier.verify_release_artifacts(root)

    def test_release_directory_closure_allows_checksum_index_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            checksum_entries = verifier.verify_checksum_file(
                root,
                latest / verifier.CHECKSUM_FILE_NAME,
            )
            allowed_uncovered = {
                f"release-artifacts/latest/{name}"
                for name in verifier.ALLOWED_UNCHECKSUMMED_RELEASE_FILES
            }
            expected_checked = sum(
                path.startswith("release-artifacts/latest/") and path not in allowed_uncovered
                for path in checksum_entries
            )

            checked = verifier.verify_release_directory_checksum_closure(
                root,
                latest,
                checksum_entries,
            )

            self.assertEqual(checked, expected_checked)

    def test_verifier_rejects_release_directory_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            link_path = root / "release-artifacts" / "latest" / "unlisted-link.json"
            target_path = root / "release-artifacts" / "latest" / "abi-checksums.json"
            try:
                link_path.symlink_to(target_path)
            except OSError as exc:
                self.skipTest(f"symlinks unavailable in this environment: {exc}")

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "contains symlink",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_symlinked_checksum_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            checksum_path = root / "release-artifacts" / "latest" / "SHA256SUMS"
            target_path = root / "tmp" / "SHA256SUMS"
            write_text(target_path, checksum_path.read_text(encoding="utf-8"))
            checksum_path.unlink()
            try:
                checksum_path.symlink_to(target_path)
            except OSError as exc:
                self.skipTest(f"symlinks unavailable in this environment: {exc}")

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "SHA256SUMS must not be a symlink",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_symlinked_checksum_covered_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            covered_path = root / "deployments" / "examples" / "anvil.json"
            target_path = root / "tmp" / "anvil-target.json"
            write_text(target_path, covered_path.read_text(encoding="utf-8"))
            covered_path.unlink()
            try:
                covered_path.symlink_to(target_path)
            except OSError as exc:
                self.skipTest(f"symlinks unavailable in this environment: {exc}")

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "must not include symlinks|must not be a symlink",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_symlinked_checksum_covered_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            covered_path = root / "deployments" / "examples" / "anvil.json"
            target_dir = root / "tmp" / "deployment-target"
            write_text(target_dir / "anvil.json", covered_path.read_text(encoding="utf-8"))
            covered_path.unlink()
            covered_path.parent.rmdir()
            try:
                covered_path.parent.symlink_to(target_dir, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"directory symlinks unavailable in this environment: {exc}")

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "SHA256SUMS.deployments/examples/anvil.json must not include symlinks",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_symlinked_release_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            link_path = root / "release-artifacts" / "linked-latest"
            target_path = root / "release-artifacts" / "latest"
            try:
                link_path.symlink_to(target_path, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"directory symlinks unavailable in this environment: {exc}")

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "release directory must not include symlinks",
            ):
                verifier.verify_release_artifacts(root, Path("release-artifacts/linked-latest"))

    def test_verifier_rejects_release_directory_outside_repo(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir) / "repo"
            seed_release_bundle(root)
            outside = Path(temp_dir) / "outside-latest"
            outside.mkdir()

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "release directory must stay inside the repository",
            ):
                verifier.verify_release_artifacts(root, outside)

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
                    verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
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
                    verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
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

    def test_checksum_record_rejects_bad_sha_marker(self) -> None:
        with self.assertRaisesRegex(
            verifier.ReleaseArtifactVerificationError,
            "sha256 has invalid sha256 marker for release-artifacts/latest/a.json",
        ):
            verifier.require_checksum_record(
                {"release-artifacts/latest/a.json": "0" * 64},
                path="release-artifacts/latest/a.json",
                sha256="not-a-prefixed-sha",
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
                    verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
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
                    verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
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
                    verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
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
                    verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
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
