#!/usr/bin/env python3
"""Focused tests for release artifact verification."""

from __future__ import annotations

import importlib.util
import json
import re
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

SOURCE_REPO_ROOT = SCRIPT_PATH.parent.parent
RELEASE_TOOL_FIXTURE_PATH = "scripts/generate_bytecode_release_proof.py"


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


def record_family_grant_map_schema_record(root: Path) -> dict[str, object]:
    return {
        **file_record(
            root,
            verifier.RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_PATH,
        ),
        "schema_version": verifier.JSON_SCHEMA_DRAFT,
        "schema_id": verifier.RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_ID,
        "document_schema_version": (
            verifier.RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA
        ),
    }


def record_family_inventory_schema_record(root: Path) -> dict[str, object]:
    return {
        **file_record(
            root,
            verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_PATH,
        ),
        "schema_version": verifier.JSON_SCHEMA_DRAFT,
        "schema_id": verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_ID,
        "document_schema_version": (
            verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA
        ),
    }


def seed_release_tool_trust_tree(root: Path) -> None:
    required_paths = set(
        verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
    )
    required_paths.update(
        verifier.REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
    )
    for relative_path in sorted(required_paths):
        write_text(
            root / relative_path,
            (SOURCE_REPO_ROOT / relative_path).read_text(encoding="utf-8"),
        )


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
    for record_family_path in (
        verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
        verifier.record_family_authorization_checker.DEFAULT_INVENTORY_SCHEMA.as_posix(),
        verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH,
        verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH,
        verifier.RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_PATH,
    ):
        if (root / record_family_path).is_file():
            effective_paths.add(record_family_path)
    required_trust_paths = set(
        verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
    )
    required_trust_paths.update(
        verifier.REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
    )
    effective_paths.update(
        path.as_posix()
        for path in required_trust_paths
    )
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
                "coverage_policy": (
                    verifier.release_checksum_generator.CANONICAL_COVERAGE_POLICY
                ),
                "covered_paths": [
                    path.as_posix()
                    for path in (
                        verifier.release_checksum_generator.DEFAULT_COVERED_PATHS
                    )
                ],
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


def seed_record_family_authorization_tree(root: Path) -> None:
    source_root = SCRIPT_PATH.parent.parent
    for relative_path in (
        verifier.record_family_authorization_checker.DEFAULT_INVENTORY,
        verifier.record_family_authorization_checker.DEFAULT_INVENTORY_SCHEMA,
        verifier.record_family_authorization_checker.DEFAULT_EVIDENCE_TEMPLATE,
        verifier.record_family_authorization_checker.DEFAULT_EVIDENCE_SCHEMA,
        verifier.record_family_authorization_checker.DEFAULT_GRANT_MAP_SCHEMA,
    ):
        write_text(
            root / relative_path,
            (source_root / relative_path).read_text(encoding="utf-8"),
        )


def seed_release_bundle(root: Path) -> None:
    latest = root / "release-artifacts" / "latest"
    seed_release_tool_trust_tree(root)
    write_text(latest / "abi-checksums.json", '{"schema_version":"fixture.abi"}\n')
    seed_governed_parameter_inventory_tree(root)
    seed_record_family_authorization_tree(root)
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
                "record_family_authorization": {
                    "inventory": {
                        **file_record(
                            root,
                            verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
                        ),
                        "schema_version": (
                            verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA
                        ),
                    },
                    "inventory_schema": record_family_inventory_schema_record(root),
                    "evidence_schema": file_record(
                        root,
                        verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH,
                    )
                    | {"schema_version": verifier.JSON_SCHEMA_DRAFT},
                    "grant_map_schema": record_family_grant_map_schema_record(root),
                    "evidence_template": {
                        **file_record(
                            root,
                            verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH,
                        ),
                        "schema_version": (
                            verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA
                        ),
                    },
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
                "record_family_authorization_inventory": {
                    **file_record(
                        root,
                        verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
                    ),
                    "schema_version": (
                        verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA
                    ),
                },
                "record_family_authorization_inventory_schema": (
                    record_family_inventory_schema_record(root)
                ),
                "record_family_authorization_evidence_template": {
                    **file_record(
                        root,
                        verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH,
                    ),
                    "schema_version": (
                        verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA
                    ),
                },
                "record_family_authorization_grant_map_schema": (
                    record_family_grant_map_schema_record(root)
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
            verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
            verifier.governed_parameter_inventory_checker.GENESIS_PROFILE.as_posix(),
            verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
            verifier.record_family_authorization_checker.DEFAULT_INVENTORY_SCHEMA.as_posix(),
            verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_PATH,
            "release-artifacts/latest/abi-checksums.json",
            "release-artifacts/latest/bytecode-release-proof.json",
            "release-artifacts/latest/release-candidate-lockfile.json",
            "release-artifacts/latest/release-manifest.json",
        ],
    )


def seed_release_bundle_with_trust_input(root: Path) -> None:
    seed_release_bundle(root)


class ReleaseArtifactVerifierTests(unittest.TestCase):
    def setUp(self) -> None:
        self.record_package_validator = mock.patch.object(
            verifier.record_family_authorization_checker,
            "validate_package",
            return_value=({}, {}),
        ).start()
        self.addCleanup(mock.patch.stopall)

    def test_verifier_and_generator_reviewed_trust_literals_match(
        self,
    ) -> None:
        self.assertEqual(
            verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE,
            (
                verifier.release_checksum_generator
                .REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
            ),
        )
        self.assertEqual(
            verifier.REVIEWED_RELEASE_TOOL_FOCUSED_TESTS,
            verifier.release_checksum_generator.RELEASE_TOOL_FOCUSED_TESTS,
        )

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

    def test_offline_verifier_invokes_record_family_authorization_validator(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            self.record_package_validator.reset_mock()
            verifier.verify_release_artifacts(root)

        self.record_package_validator.assert_called_once_with(root.resolve())

    def test_offline_verifier_rejects_record_family_semantic_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            with mock.patch.object(
                verifier.record_family_authorization_checker,
                "validate_package",
                side_effect=(
                    verifier.record_family_authorization_checker
                    .RecordFamilyAuthorizationError("invalid retained evidence")
                ),
            ):
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "record-family authorization semantic validation failed: "
                    "invalid retained evidence",
                ):
                    verifier.verify_release_artifacts(root)

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
        stderr = StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            result = verifier.main(["--repo-root", str(repo_root), "--json"])
        self.assertEqual(result, 0, stderr.getvalue())
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
            required_trust_count = len(
                set(
                    verifier.release_checksum_generator.release_tool_runtime_closure(
                        root
                    )
                ).union(
                    verifier.release_checksum_generator.RELEASE_TOOL_FOCUSED_TESTS
                )
            )
            expected_count = 12 + required_trust_count
            self.assertEqual(summary.checksum_entries, expected_count)
            self.assertEqual(
                summary.checksum_manifest_records,
                expected_count,
            )

    def assert_record_family_inventory_schema_index_mutation_rejected(
        self,
        mutation: str,
        expected_error: str,
    ) -> None:
        target = verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_PATH
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            checksum_path = latest / verifier.CHECKSUM_FILE_NAME
            checksum_manifest_path = latest / verifier.CHECKSUM_MANIFEST_NAME
            lines = checksum_path.read_text(encoding="utf-8").splitlines()
            checksum_manifest = json.loads(
                checksum_manifest_path.read_text(encoding="utf-8")
            )
            target_line_index = next(
                index
                for index, line in enumerate(lines)
                if line.endswith(f"  {target}")
            )
            target_entry = next(
                entry
                for entry in checksum_manifest["files"]
                if entry["path"] == target
            )

            if mutation in {"delete", "substitute"}:
                lines.pop(target_line_index)
                checksum_manifest["files"].remove(target_entry)
                if mutation == "substitute":
                    substitute = (
                        "release-artifacts/schema/"
                        "substituted-record-family-inventory.schema.json"
                    )
                    write_text(root / substitute, '{"substituted":true}\n')
                    substitute_digest = verifier.file_sha256(
                        root / substitute
                    ).removeprefix("sha256:")
                    lines.append(f"{substitute_digest}  {substitute}")
                    checksum_manifest["files"].append(file_record(root, substitute))
            elif mutation == "sha_wrong_hash":
                lines[target_line_index] = "0" * 64 + f"  {target}"
            elif mutation == "manifest_wrong_hash":
                target_entry["sha256"] = "sha256:" + "0" * 64
            elif mutation == "manifest_wrong_size":
                target_entry["size_bytes"] += 1
            elif mutation == "post_file_mutation":
                write_text(
                    root / target,
                    (root / target).read_text(encoding="utf-8") + "\n",
                )
            else:
                raise AssertionError(f"unsupported inventory-schema mutation {mutation}")

            lines.sort()
            checksum_manifest["files"].sort(key=lambda entry: entry["path"])
            checksum_text = "\n".join(lines) + "\n"
            write_text(checksum_path, checksum_text)
            checksum_manifest["text_checksum_file"]["sha256"] = (
                verifier.sha256_bytes(checksum_text.encode("utf-8"))
            )
            write_json(checksum_manifest_path, checksum_manifest)

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                expected_error,
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_coordinated_inventory_schema_index_deletion(
        self,
    ) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "delete",
            (
                "inventory-schema checksum binding requires exactly one "
                "SHA256SUMS entry.*got 0"
            ),
        )

    def test_verifier_rejects_same_cardinality_inventory_schema_substitution(
        self,
    ) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "substitute",
            (
                "inventory-schema checksum binding requires exactly one "
                "SHA256SUMS entry.*got 0"
            ),
        )

    def test_verifier_rejects_inventory_schema_checksum_hash_drift(self) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "sha_wrong_hash",
            "inventory-schema checksum binding SHA256SUMS hash mismatch",
        )
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "manifest_wrong_hash",
            (
                "inventory-schema checksum binding release-checksums.json "
                "hash mismatch"
            ),
        )

    def test_verifier_rejects_inventory_schema_checksum_size_drift(self) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "manifest_wrong_size",
            (
                "inventory-schema checksum binding release-checksums.json "
                "size mismatch"
            ),
        )

    def test_verifier_rejects_inventory_schema_post_bundle_mutation(self) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "post_file_mutation",
            "inventory-schema checksum binding SHA256SUMS hash mismatch",
        )

    def assert_release_tool_bundle_mutation_rejected(
        self,
        mutation: str,
        expected_error: str,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle_with_trust_input(root)
            latest = root / "release-artifacts" / "latest"
            checksum_path = latest / "SHA256SUMS"
            manifest_path = latest / "release-checksums.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

            if mutation.startswith("sha_"):
                lines = checksum_path.read_text(encoding="utf-8").splitlines()
                target_index = next(
                    index
                    for index, line in enumerate(lines)
                    if line.endswith(f"  {RELEASE_TOOL_FIXTURE_PATH}")
                )
                if mutation == "sha_delete":
                    lines.pop(target_index)
                elif mutation == "sha_substitute":
                    substitute = "scripts/substituted_release_tool.py"
                    write_text(root / substitute, "VALUE = 2\n")
                    digest = verifier.file_sha256(
                        root / substitute
                    ).removeprefix("sha256:")
                    lines[target_index] = f"{digest}  {substitute}"
                elif mutation == "sha_wrong_hash":
                    lines[target_index] = (
                        "0" * 64 + f"  {RELEASE_TOOL_FIXTURE_PATH}"
                    )
                else:
                    raise AssertionError(f"unsupported SHA mutation {mutation}")
                lines.sort()
                checksum_text = "\n".join(lines) + "\n"
                write_text(checksum_path, checksum_text)
                manifest["text_checksum_file"]["sha256"] = (
                    verifier.sha256_bytes(checksum_text.encode("utf-8"))
                )
            else:
                target_entry = next(
                    entry
                    for entry in manifest["files"]
                    if entry["path"] == RELEASE_TOOL_FIXTURE_PATH
                )
                if mutation == "manifest_delete":
                    manifest["files"].remove(target_entry)
                elif mutation == "manifest_substitute":
                    manifest["files"].remove(target_entry)
                    substitute = "scripts/substituted_release_tool.py"
                    write_text(root / substitute, "VALUE = 2\n")
                    manifest["files"].append(file_record(root, substitute))
                    manifest["files"].sort(key=lambda entry: entry["path"])
                elif mutation == "manifest_wrong_hash":
                    target_entry["sha256"] = "sha256:" + "0" * 64
                elif mutation == "manifest_wrong_size":
                    target_entry["size_bytes"] += 1
                else:
                    raise AssertionError(
                        f"unsupported checksum-manifest mutation {mutation}"
                    )
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                expected_error,
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_required_trust_file_deleted_from_sha256sums(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "sha_delete",
            (
                "release-tool trust binding requires exactly one SHA256SUMS "
                "entry for scripts/generate_bytecode_release_proof.py: got 0"
            ),
        )

    def test_verifier_rejects_required_trust_file_deleted_from_checksum_manifest(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "manifest_delete",
            (
                "release-tool trust binding requires exactly one "
                "release-checksums.json entry for "
                "scripts/generate_bytecode_release_proof.py: got 0"
            ),
        )

    def test_verifier_rejects_required_trust_file_substituted_in_sha256sums(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "sha_substitute",
            (
                "release-tool trust binding requires exactly one SHA256SUMS "
                "entry for scripts/generate_bytecode_release_proof.py: got 0"
            ),
        )

    def test_verifier_rejects_required_trust_file_substituted_in_checksum_manifest(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "manifest_substitute",
            (
                "release-tool trust binding requires exactly one "
                "release-checksums.json entry for "
                "scripts/generate_bytecode_release_proof.py: got 0"
            ),
        )

    def test_verifier_rejects_required_trust_file_wrong_hash_in_sha256sums(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "sha_wrong_hash",
            (
                "release-tool trust binding SHA256SUMS hash mismatch for "
                "scripts/generate_bytecode_release_proof.py"
            ),
        )

    def test_verifier_rejects_required_trust_file_wrong_hash_in_checksum_manifest(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "manifest_wrong_hash",
            (
                "release-tool trust binding release-checksums.json hash "
                "mismatch for "
                "scripts/generate_bytecode_release_proof.py"
            ),
        )

    def test_verifier_rejects_required_trust_file_wrong_size_in_checksum_manifest(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "manifest_wrong_size",
            (
                "release-tool trust binding release-checksums.json size "
                "mismatch for "
                "scripts/generate_bytecode_release_proof.py"
            ),
        )

    def assert_coordinated_release_tool_bundle_mutation_rejected(
        self,
        mutation: str,
        expected_error: str,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle_with_trust_input(root)
            latest = root / "release-artifacts" / "latest"
            checksum_path = latest / "SHA256SUMS"
            manifest_path = latest / "release-checksums.json"
            lines = checksum_path.read_text(encoding="utf-8").splitlines()
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            target_line_index = next(
                index
                for index, line in enumerate(lines)
                if line.endswith(f"  {RELEASE_TOOL_FIXTURE_PATH}")
            )
            target_entry = next(
                entry
                for entry in manifest["files"]
                if entry["path"] == RELEASE_TOOL_FIXTURE_PATH
            )
            lines.pop(target_line_index)
            manifest["files"].remove(target_entry)

            if mutation == "delete":
                pass
            elif mutation == "substitute":
                substitute = "scripts/substituted_release_tool.py"
                write_text(root / substitute, "VALUE = 2\n")
                digest = verifier.file_sha256(
                    root / substitute
                ).removeprefix("sha256:")
                lines.append(f"{digest}  {substitute}")
                manifest["files"].append(file_record(root, substitute))
            else:
                raise AssertionError(
                    f"unsupported coordinated mutation {mutation}"
                )

            lines.sort()
            manifest["files"].sort(key=lambda entry: entry["path"])
            checksum_text = "\n".join(lines) + "\n"
            write_text(checksum_path, checksum_text)
            manifest["text_checksum_file"]["sha256"] = (
                verifier.sha256_bytes(checksum_text.encode("utf-8"))
            )
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                expected_error,
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_coordinated_trust_file_deletion(self) -> None:
        self.assert_coordinated_release_tool_bundle_mutation_rejected(
            "delete",
            (
                "release-tool trust binding requires exactly one SHA256SUMS "
                "entry for scripts/generate_bytecode_release_proof.py: got 0"
            ),
        )

    def test_verifier_rejects_coordinated_trust_file_substitution(self) -> None:
        self.assert_coordinated_release_tool_bundle_mutation_rejected(
            "substitute",
            (
                "release-tool trust binding requires exactly one SHA256SUMS "
                "entry for scripts/generate_bytecode_release_proof.py: got 0"
            ),
        )

    def test_verifier_rejects_coordinated_transitive_source_deletion(
        self,
    ) -> None:
        target = "scripts/check_changelog.py"
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts/latest"
            checksum_path = latest / "SHA256SUMS"
            manifest_path = latest / "release-checksums.json"
            lines = [
                line
                for line in checksum_path.read_text(
                    encoding="utf-8"
                ).splitlines()
                if not line.endswith(f"  {target}")
            ]
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"] = [
                entry
                for entry in manifest["files"]
                if entry["path"] != target
            ]
            (root / target).unlink()
            checksum_text = "\n".join(lines) + "\n"
            write_text(checksum_path, checksum_text)
            manifest["text_checksum_file"]["sha256"] = (
                verifier.sha256_bytes(checksum_text.encode("utf-8"))
            )
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                re.escape(target),
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_coordinated_transitive_source_substitution(
        self,
    ) -> None:
        target = "scripts/check_changelog.py"
        substitute = "scripts/substituted_changelog_check.py"
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts/latest"
            checksum_path = latest / "SHA256SUMS"
            manifest_path = latest / "release-checksums.json"
            write_text(root / substitute, "VALUE = 1\n")
            substitute_digest = verifier.file_sha256(
                root / substitute
            ).removeprefix("sha256:")
            lines = checksum_path.read_text(
                encoding="utf-8"
            ).splitlines()
            target_index = next(
                index
                for index, line in enumerate(lines)
                if line.endswith(f"  {target}")
            )
            lines[target_index] = f"{substitute_digest}  {substitute}"
            lines.sort()
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            target_entry = next(
                entry
                for entry in manifest["files"]
                if entry["path"] == target
            )
            manifest["files"].remove(target_entry)
            manifest["files"].append(file_record(root, substitute))
            manifest["files"].sort(key=lambda entry: entry["path"])
            checksum_text = "\n".join(lines) + "\n"
            write_text(checksum_path, checksum_text)
            manifest["text_checksum_file"]["sha256"] = (
                verifier.sha256_bytes(checksum_text.encode("utf-8"))
            )
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                re.escape(target),
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_symlinked_reviewed_transitive_source(
        self,
    ) -> None:
        target = Path("scripts/check_changelog.py")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            target_path = root / target
            outside = root / "outside/check_changelog.py"
            write_text(
                outside,
                target_path.read_text(encoding="utf-8"),
            )
            target_path.unlink()
            try:
                target_path.symlink_to(outside)
            except OSError as exc:
                self.skipTest(f"symlinks unavailable in this environment: {exc}")

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                re.escape(target.as_posix()),
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_noncanonical_trust_source_policy(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            manifest_path = (
                root
                / "release-artifacts/latest/release-checksums.json"
            )
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["source"]["coverage_policy"] = (
                verifier.release_checksum_generator.CUSTOM_SUBSET_COVERAGE_POLICY
            )
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "require canonical coverage_policy",
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_broad_trust_source_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            manifest_path = (
                root
                / "release-artifacts/latest/release-checksums.json"
            )
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            removed = (
                verifier.release_checksum_generator.RELEASE_TOOL_ROOTS[0]
                .as_posix()
            )
            covered_paths = manifest["source"]["covered_paths"]
            covered_paths.remove(removed)
            covered_paths.append("scripts")
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                re.escape(removed),
            ):
                verifier.verify_release_artifacts(root)

    def test_verifier_rejects_mutated_release_tool_after_bundle_creation(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle_with_trust_input(root)
            write_text(root / RELEASE_TOOL_FIXTURE_PATH, "VALUE = 2\n")
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                (
                    "release-tool trust binding SHA256SUMS hash mismatch for "
                    "scripts/generate_bytecode_release_proof.py"
                ),
            ):
                verifier.verify_release_artifacts(root)

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

    def test_verifier_requires_exact_record_family_authorization_bindings(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")

            verifier.verify_record_family_authorization_bindings(
                release_manifest,
                lockfile,
            )

    def test_verifier_rejects_coordinated_record_family_binding_omission(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")
            del release_manifest["release_artifacts"]["record_family_authorization"]
            del lockfile["locked_inputs"]["record_family_authorization_inventory"]
            del lockfile["locked_inputs"][
                "record_family_authorization_inventory_schema"
            ]
            del lockfile["locked_inputs"][
                "record_family_authorization_evidence_template"
            ]
            del lockfile["locked_inputs"][
                "record_family_authorization_grant_map_schema"
            ]

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "record_family_authorization",
            ):
                verifier.verify_record_family_authorization_bindings(
                    release_manifest,
                    lockfile,
                )

    def test_verifier_rejects_record_family_manifest_key_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")
            release_manifest["release_artifacts"]["record_family_authorization"][
                "unreviewed"
            ] = {}

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "keys must be exactly inventory, inventory_schema, "
                "evidence_schema, grant_map_schema, and evidence_template",
            ):
                verifier.verify_record_family_authorization_bindings(
                    release_manifest,
                    lockfile,
                )

    def test_verifier_rejects_record_family_path_and_schema_drift(self) -> None:
        for field, value, expected_error in (
            (
                "path",
                "release-artifacts/substituted-inventory.json",
                "inventory path must be",
            ),
            (
                "schema_version",
                "6529stream.record-family-authorization-inventory.v2",
                "inventory must use schema",
            ),
        ):
            with self.subTest(field=field):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    release_manifest = verifier.load_json(
                        latest / "release-manifest.json"
                    )
                    lockfile = verifier.load_json(
                        latest / "release-candidate-lockfile.json"
                    )
                    release_manifest["release_artifacts"][
                        "record_family_authorization"
                    ]["inventory"][field] = value

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        expected_error,
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_record_family_inventory_schema_omission(self) -> None:
        for owner, key in (
            ("manifest", "inventory_schema"),
            ("lockfile", "record_family_authorization_inventory_schema"),
        ):
            with self.subTest(owner=owner):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    release_manifest = verifier.load_json(
                        latest / "release-manifest.json"
                    )
                    lockfile = verifier.load_json(
                        latest / "release-candidate-lockfile.json"
                    )
                    if owner == "manifest":
                        del release_manifest["release_artifacts"][
                            "record_family_authorization"
                        ][key]
                    else:
                        del lockfile["locked_inputs"][key]

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "inventory_schema|record_family_authorization_inventory_schema",
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_record_family_inventory_schema_identity_drift(
        self,
    ) -> None:
        mutations = (
            (
                "path",
                "release-artifacts/schema/substituted-inventory.schema.json",
                "inventory schema path must be",
            ),
            (
                "schema_version",
                "https://json-schema.org/draft/2019-09/schema",
                "inventory schema must use schema",
            ),
            (
                "schema_id",
                "https://example.invalid/inventory.json",
                r"inventory schema\.schema_id must be",
            ),
            (
                "document_schema_version",
                "6529stream.record-family-authorization-inventory.v2",
                r"inventory schema\.document_schema_version must be",
            ),
        )
        for field, value, expected_error in mutations:
            with self.subTest(field=field):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    release_manifest = verifier.load_json(
                        latest / "release-manifest.json"
                    )
                    lockfile = verifier.load_json(
                        latest / "release-candidate-lockfile.json"
                    )
                    release_manifest["release_artifacts"][
                        "record_family_authorization"
                    ]["inventory_schema"][field] = value

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        expected_error,
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_record_family_inventory_schema_record_key_drift(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")
            release_manifest["release_artifacts"]["record_family_authorization"][
                "inventory_schema"
            ]["unreviewed"] = True

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "inventory schema keys must be exactly",
            ):
                verifier.verify_record_family_authorization_bindings(
                    release_manifest,
                    lockfile,
                )

    def test_verifier_rejects_record_family_inventory_schema_manifest_lock_drift(
        self,
    ) -> None:
        for field, value in (
            ("sha256", "sha256:" + "0" * 64),
            ("size_bytes", 1),
        ):
            with self.subTest(field=field):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    release_manifest = verifier.load_json(
                        latest / "release-manifest.json"
                    )
                    lockfile = verifier.load_json(
                        latest / "release-candidate-lockfile.json"
                    )
                    release_manifest["release_artifacts"][
                        "record_family_authorization"
                    ]["inventory_schema"][field] = value

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "inventory schema records do not match",
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_record_family_grant_schema_omission(self) -> None:
        for owner, key in (
            ("manifest", "grant_map_schema"),
            ("lockfile", "record_family_authorization_grant_map_schema"),
        ):
            with self.subTest(owner=owner):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    release_manifest = verifier.load_json(
                        latest / "release-manifest.json"
                    )
                    lockfile = verifier.load_json(
                        latest / "release-candidate-lockfile.json"
                    )
                    if owner == "manifest":
                        del release_manifest["release_artifacts"][
                            "record_family_authorization"
                        ][key]
                    else:
                        del lockfile["locked_inputs"][key]

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "grant_map_schema|grant_map_schema",
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_record_family_grant_schema_identity_drift(
        self,
    ) -> None:
        mutations = (
            (
                "path",
                "deployments/schema/substituted-grant-map.schema.json",
                "grant-map schema path must be",
            ),
            (
                "schema_version",
                "https://json-schema.org/draft/2019-09/schema",
                "grant-map schema must use schema",
            ),
            (
                "schema_id",
                "https://example.invalid/grant-map.json",
                r"grant-map schema\.schema_id must be",
            ),
            (
                "document_schema_version",
                "6529stream.record-family-authorization-grant-map.v2",
                r"grant-map schema\.document_schema_version must be",
            ),
        )
        for field, value, expected_error in mutations:
            with self.subTest(field=field):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    release_manifest = verifier.load_json(
                        latest / "release-manifest.json"
                    )
                    lockfile = verifier.load_json(
                        latest / "release-candidate-lockfile.json"
                    )
                    release_manifest["release_artifacts"][
                        "record_family_authorization"
                    ]["grant_map_schema"][field] = value

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        expected_error,
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_record_family_grant_schema_record_key_drift(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")
            release_manifest["release_artifacts"]["record_family_authorization"][
                "grant_map_schema"
            ]["unreviewed"] = True

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "grant-map schema keys must be exactly",
            ):
                verifier.verify_record_family_authorization_bindings(
                    release_manifest,
                    lockfile,
                )

    def test_verifier_rejects_record_family_grant_schema_hash_or_size_mismatch(
        self,
    ) -> None:
        for field, value in (
            ("sha256", "sha256:" + "0" * 64),
            ("size_bytes", 1),
        ):
            with self.subTest(field=field):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    release_manifest = verifier.load_json(
                        latest / "release-manifest.json"
                    )
                    lockfile = verifier.load_json(
                        latest / "release-candidate-lockfile.json"
                    )
                    release_manifest["release_artifacts"][
                        "record_family_authorization"
                    ]["grant_map_schema"][field] = value

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "grant-map schema records do not match",
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_coordinated_grant_schema_hash_or_size_drift(
        self,
    ) -> None:
        for field, value, expected_error in (
            ("sha256", "sha256:" + "0" * 64, "hash mismatch"),
            ("size_bytes", 1, "size mismatch"),
        ):
            with self.subTest(field=field):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    release_manifest = verifier.load_json(
                        latest / "release-manifest.json"
                    )
                    lockfile = verifier.load_json(
                        latest / "release-candidate-lockfile.json"
                    )
                    release_manifest_record = release_manifest["release_artifacts"][
                        "record_family_authorization"
                    ]["grant_map_schema"]
                    lockfile_record = lockfile["locked_inputs"][
                        "record_family_authorization_grant_map_schema"
                    ]
                    release_manifest_record[field] = value
                    lockfile_record[field] = value
                    verifier.verify_record_family_authorization_bindings(
                        release_manifest,
                        lockfile,
                    )
                    checksum_entries = verifier.verify_checksum_file(
                        root,
                        latest / verifier.CHECKSUM_FILE_NAME,
                    )

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        expected_error,
                    ):
                        verifier.verify_nested_file_records(
                            root,
                            release_manifest,
                            verifier.RELEASE_MANIFEST_NAME,
                            checksum_entries,
                        )

    def test_verifier_rejects_record_family_manifest_lock_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")
            lockfile["locked_inputs"][
                "record_family_authorization_evidence_template"
            ]["sha256"] = "sha256:" + "0" * 64

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "evidence template records do not match",
            ):
                verifier.verify_record_family_authorization_bindings(
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
