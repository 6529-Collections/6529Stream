#!/usr/bin/env python3
"""Focused tests for release artifact verification."""

from __future__ import annotations

import importlib.util
import inspect
import json
import os
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
COMMITTED_COVERED_PATHS = tuple(
    json.loads(
        (
            SOURCE_REPO_ROOT
            / "release-artifacts/latest/release-checksums.json"
        ).read_text(encoding="utf-8")
    )["source"]["covered_paths"]
)
REQUIRED_CANONICAL_FIXTURE_PATHS = tuple(
    Path(path)
    for path in (
        verifier.GIT_ATTRIBUTES_PATH,
        verifier.RELEASE_TOOL_CALL_POLICY_PATH,
        verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_PATH,
        *verifier.RECORD_FAMILY_AUTHORIZATION_SEMANTIC_SOURCE_PATHS,
    )
)
TEST_CANONICAL_COVERED_PATHS = tuple(
    dict.fromkeys(
        (
            *(Path(path) for path in COMMITTED_COVERED_PATHS),
            *REQUIRED_CANONICAL_FIXTURE_PATHS,
        )
    )
)
if (
    len(TEST_CANONICAL_COVERED_PATHS) != 263
    or len(set(TEST_CANONICAL_COVERED_PATHS)) != 263
):
    raise AssertionError(
        "canonical verifier fixtures require exactly 263 unique coverage roots"
    )
TEST_RELEASE_TOOL_ROOTS = (
    Path("scripts/generate_risk_register.py"),
    Path("scripts/generate_release_notes.py"),
    Path("scripts/generate_release_manifest.py"),
    Path("scripts/generate_bytecode_release_proof.py"),
    Path("scripts/generate_release_candidate_lockfile.py"),
    Path("scripts/generate_release_checksums.py"),
    Path("scripts/verify_release_artifacts.py"),
)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_bytes(path: Path, value: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value)


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


def record_family_source_catalog_schema_record(
    root: Path,
) -> dict[str, object]:
    return {
        **file_record(
            root,
            verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA_PATH,
        ),
        "schema_version": verifier.JSON_SCHEMA_DRAFT,
        "schema_id": (
            verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA_ID
        ),
        "document_schema_version": (
            verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA
        ),
    }


def record_family_evidence_schema_record(root: Path) -> dict[str, object]:
    return {
        **file_record(
            root,
            verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH,
        ),
        "schema_version": verifier.JSON_SCHEMA_DRAFT,
        "schema_id": verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_ID,
        "document_schema_version": (
            verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA
        ),
    }


def release_tool_policy_record(root: Path) -> dict[str, object]:
    return {
        **file_record(root, verifier.RELEASE_TOOL_CALL_POLICY_PATH),
        "schema_version": verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA,
    }


def release_tool_policy_schema_record(root: Path) -> dict[str, object]:
    return {
        **file_record(root, verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH),
        "schema_version": verifier.JSON_SCHEMA_DRAFT,
        "schema_id": verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA_ID,
        "document_schema_version": verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA,
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


def seed_release_tool_policy_tree(root: Path) -> None:
    write_bytes(
        root / verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
        (
            SOURCE_REPO_ROOT
            / verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
        ).read_bytes(),
    )
    roles = {
        **{
            path.as_posix(): "runtime"
            for path in verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
        },
        **{
            path.as_posix(): "focused-test"
            for path in verifier.REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
        },
    }
    snapshots = {}
    for relative_path in sorted(roles):
        data = (root / relative_path).read_bytes()
        snapshots[relative_path] = verifier.CanonicalCoveredFile(
            data=data,
            sha256=verifier.sha256_bytes(data),
            size_bytes=len(data),
            line_ending="lf",
        )
    write_json(
        root / verifier.RELEASE_TOOL_CALL_POLICY_PATH,
        {
            "schema_version": verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA,
            "generator_version": "1",
            "runtime_roots": [
                path.as_posix()
                for path in verifier.REVIEWED_RELEASE_TOOL_ROOTS
            ],
            "external_modules": sorted(
                verifier.RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES
            ),
            "reviewed_paths": [
                verifier._policy_row_from_snapshot(
                    Path(relative_path),
                    roles[relative_path],
                    snapshots[relative_path],
                )
                for relative_path in sorted(roles)
            ],
        },
    )


def seed_canonical_coverage_tree(root: Path) -> None:
    for relative_path in TEST_CANONICAL_COVERED_PATHS:
        source = SOURCE_REPO_ROOT / relative_path
        target = root / relative_path
        if source.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif source.is_file():
            write_bytes(
                target,
                source.read_bytes(),
            )
        elif relative_path.as_posix() == verifier.RELEASE_TOOL_CALL_POLICY_PATH:
            target.parent.mkdir(parents=True, exist_ok=True)
        else:
            raise AssertionError(
                f"canonical fixture source is missing {relative_path.as_posix()}"
            )


def write_checksum_bundle(root: Path, covered_paths: list[str]) -> None:
    latest = root / "release-artifacts" / "latest"
    checksum_lines = []
    files = []
    effective_paths = set(covered_paths)
    genesis_profile = (
        verifier.GENESIS_DEPLOYMENT_PROFILE_PATH
    )
    if (root / genesis_profile).is_file():
        effective_paths.add(genesis_profile)
    for record_family_path in (
        verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
        verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_PATH,
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
    excluded = {
        "release-artifacts/latest/SHA256SUMS",
        "release-artifacts/latest/release-checksums.json",
    }
    for configured_path in (
        TEST_CANONICAL_COVERED_PATHS
    ):
        configured = root / configured_path
        if configured.is_file():
            effective_paths.add(configured_path.as_posix())
        elif configured.is_dir():
            effective_paths.update(
                path.relative_to(root).as_posix()
                for path in configured.rglob("*")
                if path.is_file()
                and path.relative_to(root).as_posix() not in excluded
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
                    verifier.CANONICAL_COVERAGE_POLICY
                ),
                "covered_paths": [
                    path.as_posix()
                    for path in TEST_CANONICAL_COVERED_PATHS
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


def write_mutated_checksum_indexes(
    root: Path,
    lines: list[str],
    manifest: dict[str, object],
) -> None:
    latest = root / "release-artifacts" / "latest"
    lines.sort()
    manifest["files"].sort(key=lambda entry: entry["path"])
    checksum_text = "\n".join(lines) + "\n"
    write_text(latest / "SHA256SUMS", checksum_text)
    manifest["text_checksum_file"]["sha256"] = verifier.sha256_bytes(
        checksum_text.encode("utf-8")
    )
    write_json(latest / "release-checksums.json", manifest)


def refresh_checksum_indexes(root: Path) -> None:
    latest = root / "release-artifacts" / "latest"
    manifest_path = latest / "release-checksums.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    lines: list[str] = []
    for entry in manifest["files"]:
        path = root / entry["path"]
        entry["sha256"] = verifier.file_sha256(path)
        entry["size_bytes"] = path.stat().st_size
        lines.append(
            f"{entry['sha256'].removeprefix('sha256:')}  {entry['path']}"
        )
    write_mutated_checksum_indexes(root, lines, manifest)


def checksum_bundle_snapshot(root: Path) -> verifier.ChecksumBundleSnapshot:
    latest = root / "release-artifacts" / "latest"
    return verifier.snapshot_checksum_bundle(
        root,
        latest / verifier.CHECKSUM_FILE_NAME,
        latest / verifier.CHECKSUM_MANIFEST_NAME,
    )


def canonical_covered_snapshots(
    root: Path,
    checksum_bundle: verifier.ChecksumBundleSnapshot,
) -> dict[str, verifier.CanonicalCoveredFile]:
    return verifier.verify_canonical_line_ending_bindings(
        root,
        checksum_bundle,
    )


def remove_path_from_checksum_indexes(root: Path, target: str) -> None:
    latest = root / "release-artifacts" / "latest"
    checksum_path = latest / "SHA256SUMS"
    manifest_path = latest / "release-checksums.json"
    lines = [
        line
        for line in checksum_path.read_text(encoding="utf-8").splitlines()
        if not line.endswith(f"  {target}")
    ]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["files"] = [
        entry
        for entry in manifest["files"]
        if entry["path"] != target
    ]
    write_mutated_checksum_indexes(root, lines, manifest)


def seed_governed_parameter_inventory_tree(root: Path) -> None:
    source_root = SCRIPT_PATH.parent.parent
    inventory = json.loads(
        (
            source_root
            / verifier.GOVERNED_PARAMETER_INVENTORY_PATH
        ).read_text(encoding="utf-8")
    )
    write_json(
        root / verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
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
        Path(verifier.GENESIS_DEPLOYMENT_PROFILE_PATH)
    )
    dependency_paths.add(
        Path(verifier.GOVERNED_PARAMETER_INVENTORY_SCHEMA_PATH)
    )
    for relative_path in dependency_paths:
        write_text(
            root / relative_path,
            (source_root / relative_path).read_text(encoding="utf-8"),
        )


def seed_record_family_authorization_tree(root: Path) -> None:
    source_root = SCRIPT_PATH.parent.parent
    for relative_path in (
        Path(verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_PATH),
        Path(verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA_PATH),
        Path(verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH),
        Path(verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_PATH),
        Path(verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH),
        Path(verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH),
        Path(verifier.RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_PATH),
    ):
        write_text(
            root / relative_path,
            (source_root / relative_path).read_text(encoding="utf-8"),
        )


def seed_release_bundle(root: Path) -> None:
    latest = root / "release-artifacts" / "latest"
    seed_canonical_coverage_tree(root)
    seed_release_tool_trust_tree(root)
    seed_release_tool_policy_tree(root)
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
                    "source_catalog": {
                        **file_record(
                            root,
                            verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_PATH,
                        ),
                        "schema_version": (
                            verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA
                        ),
                    },
                    "source_catalog_schema": (
                        record_family_source_catalog_schema_record(root)
                    ),
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
                    "evidence_schema": record_family_evidence_schema_record(root),
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
                "release_tool_call_policy": {
                    "policy": release_tool_policy_record(root),
                    "schema": release_tool_policy_schema_record(root),
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
                "record_family_authorization_source_catalog": {
                    **file_record(
                        root,
                        verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_PATH,
                    ),
                    "schema_version": (
                        verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA
                    ),
                },
                "record_family_authorization_source_catalog_schema": (
                    record_family_source_catalog_schema_record(root)
                ),
                "record_family_authorization_inventory_schema": (
                    record_family_inventory_schema_record(root)
                ),
                "record_family_authorization_evidence_schema": (
                    record_family_evidence_schema_record(root)
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
                "release_tool_call_policy": release_tool_policy_record(root),
                "release_tool_call_policy_schema": (
                    release_tool_policy_schema_record(root)
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
            verifier.GENESIS_DEPLOYMENT_PROFILE_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_PATH,
            verifier.RELEASE_TOOL_CALL_POLICY_PATH,
            verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
            "release-artifacts/latest/abi-checksums.json",
            "release-artifacts/latest/bytecode-release-proof.json",
            "release-artifacts/latest/release-candidate-lockfile.json",
            "release-artifacts/latest/release-manifest.json",
        ],
    )


def seed_release_bundle_with_trust_input(root: Path) -> None:
    seed_release_bundle(root)


class ReleaseArtifactVerifierTests(unittest.TestCase):
    @staticmethod
    def verify_fixture_release_artifacts(
        root: Path,
        release_dir: Path = verifier.DEFAULT_RELEASE_DIR,
    ) -> verifier.VerificationSummary:
        def validate_fixture_snapshot(
            snapshots: dict[str, verifier.CanonicalCoveredFile],
        ) -> dict[str, object]:
            return json.loads(
                snapshots[
                    verifier.GOVERNED_PARAMETER_INVENTORY_PATH
                ].data.decode("utf-8")
            )

        with mock.patch.object(
            verifier,
            "validate_bound_snapshot_semantics",
            side_effect=validate_fixture_snapshot,
        ):
            return verifier.verify_release_artifacts(root, release_dir)

    def test_verifier_reviewed_trust_literals_are_exact(
        self,
    ) -> None:
        self.assertEqual(len(verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE), 22)
        self.assertEqual(len(verifier.REVIEWED_RELEASE_TOOL_FOCUSED_TESTS), 9)
        self.assertFalse(
            set(verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE)
            & set(verifier.REVIEWED_RELEASE_TOOL_FOCUSED_TESTS)
        )
        self.assertEqual(len(TEST_CANONICAL_COVERED_PATHS), 263)
        self.assertEqual(len(set(TEST_CANONICAL_COVERED_PATHS)), 263)
        self.assertTrue(
            set(REQUIRED_CANONICAL_FIXTURE_PATHS).issubset(
                TEST_CANONICAL_COVERED_PATHS
            )
        )

    def test_verifier_bootstrap_imports_are_standard_library_only(self) -> None:
        tree = verifier.ast.parse(SCRIPT_PATH.read_text(encoding="utf-8"))
        top_level_modules: set[str] = set()
        for node in tree.body:
            if isinstance(node, verifier.ast.Import):
                top_level_modules.update(
                    alias.name.split(".", 1)[0] for alias in node.names
                )
            elif isinstance(node, verifier.ast.ImportFrom):
                top_level_modules.add((node.module or "").split(".", 1)[0])
        self.assertNotIn("generate_release_checksums", top_level_modules)
        self.assertNotIn(
            "check_governed_parameter_inventory",
            top_level_modules,
        )
        self.assertNotIn(
            "check_record_family_authorization",
            top_level_modules,
        )
        self.assertTrue(
            {
                "argparse",
                "ast",
                "hashlib",
                "json",
                "os",
                "re",
                "stat",
                "sys",
                "tempfile",
                "pathlib",
                "typing",
                "__future__",
            }.issuperset(top_level_modules)
        )

    def test_snapshot_consumers_expose_no_live_path_fallback(self) -> None:
        consumers = (
            verifier.verify_file_record,
            verifier.verify_checksum_file,
            verifier.verify_release_tool_trust_bindings,
            verifier.verify_record_family_inventory_schema_checksum_bindings,
            verifier.verify_checksum_manifest,
            verifier.verify_nested_file_records,
            verifier.verify_bytecode_proof_release_manifest_binding,
        )
        for consumer in consumers:
            with self.subTest(consumer=consumer.__name__):
                parameter = inspect.signature(consumer).parameters[
                    "covered_file_snapshots"
                ]
                self.assertIs(parameter.default, inspect.Parameter.empty)
                self.assertNotIn("None", str(parameter.annotation))
                source = inspect.getsource(consumer)
                self.assertNotIn("file_sha256(", source)
                self.assertNotIn("resolve_release_file(", source)
                self.assertNotIn("covered_file_snapshots is not None", source)

    def test_verifier_eol_policy_is_independent_of_generator_helper(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_bytes(
                root / "docs/release-readiness.md",
                b"bad\r\nline\r\n",
            )
            refresh_checksum_indexes(root)
            with (
                mock.patch.dict(
                    verifier.sys.modules,
                    {
                        "generate_release_checksums": mock.Mock(
                            validate_covered_file_line_endings=lambda *_a, **_k: {},
                            CANONICAL_COVERAGE_POLICY="weakened",
                        )
                    },
                ),
                self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "violates declared eol=lf: docs/release-readiness.md",
                ),
            ):
                self.verify_fixture_release_artifacts(root)

    def assert_post_snapshot_mutation_uses_bound_bytes(
        self,
        target: str,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            original_snapshot = (
                verifier.verify_canonical_line_ending_bindings
            )

            def snapshot_then_mutate(*args, **kwargs):
                snapshots = original_snapshot(*args, **kwargs)
                write_bytes(root / target, b"{}\n")
                return snapshots

            with mock.patch.object(
                verifier,
                "verify_canonical_line_ending_bindings",
                side_effect=snapshot_then_mutate,
            ):
                summary = self.verify_fixture_release_artifacts(root)
            self.assertGreater(summary.checksum_entries, 0)

    def test_release_documents_use_bound_snapshot_bytes(self) -> None:
        for target in (
            "release-artifacts/latest/release-manifest.json",
            "release-artifacts/latest/bytecode-release-proof.json",
            "release-artifacts/latest/release-candidate-lockfile.json",
        ):
            with self.subTest(target=target):
                self.assert_post_snapshot_mutation_uses_bound_bytes(target)

    def test_semantic_inputs_use_bound_snapshot_bytes(self) -> None:
        for target in (
            verifier.GOVERNED_PARAMETER_INVENTORY_PATH,
            verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
        ):
            with self.subTest(target=target):
                self.assert_post_snapshot_mutation_uses_bound_bytes(target)

    def test_release_tool_closure_uses_bound_snapshot_bytes(self) -> None:
        self.assert_post_snapshot_mutation_uses_bound_bytes(
            "scripts/generate_release_checksums.py"
        )

    def test_release_tool_policy_and_semantic_sources_use_bound_snapshot_bytes(
        self,
    ) -> None:
        for target in (
            verifier.RELEASE_TOOL_CALL_POLICY_PATH,
            verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
            *verifier.RECORD_FAMILY_AUTHORIZATION_SEMANTIC_SOURCE_PATHS,
        ):
            with self.subTest(target=target):
                self.assert_post_snapshot_mutation_uses_bound_bytes(target)

    def test_closed_world_policy_rejects_path_aliases_independently(self) -> None:
        for path in (
            "scripts/./x.py",
            "scripts/a/./x.py",
            "scripts/../x.py",
            "scripts/a/../x.py",
            "scripts//x.py",
            "scripts/a//x.py",
            r"scripts\x.py",
        ):
            with self.subTest(path_alias=path):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    policy_path = (
                        root / verifier.RELEASE_TOOL_CALL_POLICY_PATH
                    )
                    policy = json.loads(
                        policy_path.read_text(encoding="utf-8")
                    )
                    policy["reviewed_paths"][0]["path"] = path
                    write_json(policy_path, policy)
                    refresh_checksum_indexes(root)
                    bundle = checksum_bundle_snapshot(root)
                    snapshots = canonical_covered_snapshots(root, bundle)
                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        r"normalized scripts/\.\.\./\*\.py path",
                    ):
                        verifier.verify_release_tool_call_policy(
                            bundle,
                            snapshots,
                        )

    def test_closed_world_policy_rejects_unreviewed_surface_shapes(self) -> None:
        target = Path("scripts/generate_bytecode_release_proof.py")
        mutations = {
            "unlisted-call": "\nPath.cwd()\n",
            "unlisted-member": "\nUNLISTED = Path.cwd\n",
            "alias": "\nimport pathlib as hidden_pathlib\n",
            "container": "\nESCAPED = [Path]\n",
            "return": "\ndef escape_import():\n    return Path\n",
            "conditional": "\nESCAPED = Path if True else None\n",
            "getattr": "\ngetattr(Path, \"cwd\")()\n",
            "unknown-descendant": "\nPath.cwd().unexpected()\n",
        }
        for label, suffix in mutations.items():
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    target_path = root / target
                    write_text(
                        target_path,
                        target_path.read_text(encoding="utf-8") + suffix,
                    )
                    refresh_checksum_indexes(root)
                    bundle = checksum_bundle_snapshot(root)
                    snapshots = canonical_covered_snapshots(root, bundle)
                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "release-tool call policy .*"
                        "generate_bytecode_release_proof",
                    ):
                        verifier.verify_release_tool_call_policy(
                            bundle,
                            snapshots,
                        )

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            runtime_root = root / "scripts/generate_release_notes.py"
            write_bytes(
                runtime_root,
                runtime_root.read_bytes()
                + b"\nimport test_changelog_check\n",
            )
            seed_release_tool_policy_tree(root)
            refresh_checksum_indexes(root)
            bundle = checksum_bundle_snapshot(root)
            snapshots = canonical_covered_snapshots(root, bundle)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "snapshot runtime closure.*unexpected=.*test_changelog_check",
            ):
                verifier.verify_release_tool_call_policy(
                    bundle,
                    snapshots,
                )

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            runtime_root = root / "scripts/generate_release_notes.py"
            write_bytes(
                runtime_root,
                runtime_root.read_bytes()
                + b"\nimport importlib.util\n"
                + b"_spec = importlib.util.spec_from_file_location("
                + b"'hidden', 'scripts/test_changelog_check.py')\n"
                + b"_module = importlib.util.module_from_spec(_spec)\n"
                + b"_spec.loader.exec_module(_module)\n",
            )
            refresh_checksum_indexes(root)
            bundle = checksum_bundle_snapshot(root)
            snapshots = canonical_covered_snapshots(root, bundle)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "runtime call policy forbids alternate loader",
            ):
                verifier.verify_release_tool_call_policy(
                    bundle,
                    snapshots,
                )

        for field in ("imports", "members", "calls"):
            with self.subTest(
                duplicate_semantic_key=field,
            ), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                seed_release_bundle(root)
                policy_path = root / verifier.RELEASE_TOOL_CALL_POLICY_PATH
                policy = json.loads(policy_path.read_text(encoding="utf-8"))
                row = next(
                    candidate
                    for candidate in policy["reviewed_paths"]
                    if candidate[field]
                )
                duplicate_record = json.loads(json.dumps(row[field][0]))
                duplicate_record["count"] += 1
                row[field].append(duplicate_record)
                write_json(policy_path, policy)
                refresh_checksum_indexes(root)
                bundle = checksum_bundle_snapshot(root)
                snapshots = canonical_covered_snapshots(root, bundle)
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "differs from verifier reconstruction",
                ):
                    verifier.verify_release_tool_call_policy(
                        bundle,
                        snapshots,
                    )

        for label, mutate_roots in (
            (
                "missing-root",
                lambda roots: roots.pop(),
            ),
            (
                "substituted-root",
                lambda roots: roots.__setitem__(
                    -1,
                    "scripts/check_changelog.py",
                ),
            ),
        ):
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                seed_release_bundle(root)
                policy_path = root / verifier.RELEASE_TOOL_CALL_POLICY_PATH
                policy = json.loads(policy_path.read_text(encoding="utf-8"))
                mutate_roots(policy["runtime_roots"])
                write_json(policy_path, policy)
                refresh_checksum_indexes(root)
                bundle = checksum_bundle_snapshot(root)
                snapshots = canonical_covered_snapshots(root, bundle)
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "runtime roots differ from the independent exact",
                ):
                    verifier.verify_release_tool_call_policy(
                        bundle,
                        snapshots,
                    )

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            bundle = checksum_bundle_snapshot(root)
            snapshots = canonical_covered_snapshots(root, bundle)
            with mock.patch.object(
                verifier,
                "RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES",
                frozenset(
                    {
                        *verifier.RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES,
                        "unused_external_permission",
                    }
                ),
            ), self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "external-module literal differs from the independent pinned digest",
            ):
                verifier.verify_release_tool_call_policy(
                    bundle,
                    snapshots,
                )

    def test_closed_world_policy_expression_receiver_boundary(self) -> None:
        allowed = b"def resolve(root, child):\n    return (root / child).resolve()\n"
        allowed_snapshot = verifier.CanonicalCoveredFile(
            data=allowed,
            sha256=verifier.sha256_bytes(allowed),
            size_bytes=len(allowed),
            line_ending="lf",
        )
        row = verifier._policy_row_from_snapshot(
            Path("scripts/allowed_control.py"),
            "runtime",
            allowed_snapshot,
        )
        self.assertTrue(
            any(
                call["target"].startswith("expression:BinOp:")
                and call["target"].endswith(".resolve")
                for call in row["calls"]
            )
        )

        imported = (
            b"import json\n"
            b"def encode(value):\n"
            b"    return (json.dumps(value) + '\\n').encode('utf-8')\n"
        )
        imported_snapshot = verifier.CanonicalCoveredFile(
            data=imported,
            sha256=verifier.sha256_bytes(imported),
            size_bytes=len(imported),
            line_ending="lf",
        )
        with self.assertRaisesRegex(
            verifier.ReleaseArtifactVerificationError,
            "forbids computed imported receiver",
        ):
            verifier._policy_row_from_snapshot(
                Path("scripts/imported_receiver.py"),
                "runtime",
                imported_snapshot,
            )

    def test_closed_world_policy_rejects_relative_imports_and_value_escapes(
        self,
    ) -> None:
        mutations = {
            "relative-current": b"from . import hidden\n",
            "relative-parent": b"from ..hidden import value\n",
            "module-assignment": b"import json\nescaped = json\n",
            "callable-assignment": b"import json\nescaped = json.dumps\n",
            "function-return": (
                b"import json\n"
                b"def expose():\n    return json\n"
                b"expose().dumps({})\n"
            ),
            "argument-callback": (
                b"import json\n"
                b"def consume(callback):\n    return callback({})\n"
                b"consume(json.dumps)\n"
            ),
            "assignment-shadow": (
                b"import json\njson = object()\njson.dumps({})\n"
            ),
            "deletion-shadow": b"import json\ndel json\n",
            "parameter-shadow": (
                b"import json\ndef encode(json):\n    return json.dumps({})\n"
            ),
            "for-shadow": b"import json\nfor json in ():\n    pass\n",
            "with-shadow": (
                b"import json\nwith open('unused') as json:\n    pass\n"
            ),
            "except-shadow": (
                b"import json\ntry:\n    pass\n"
                b"except Exception as json:\n    pass\n"
            ),
            "function-shadow": b"import json\ndef json():\n    pass\n",
            "async-function-shadow": (
                b"import json\nasync def json():\n    pass\n"
            ),
            "class-shadow": b"import json\nclass json:\n    pass\n",
            "global-shadow": b"import json\ndef use():\n    global json\n",
            "nonlocal-shadow": (
                b"def outer():\n"
                b"    import json\n"
                b"    def inner():\n"
                b"        nonlocal json\n"
            ),
            "match-as-shadow": (
                b"import json\n"
                b"match value:\n"
                b"    case json:\n"
                b"        pass\n"
                b"json.dumps({})\n"
            ),
            "match-star-shadow": (
                b"import json\n"
                b"match value:\n"
                b"    case [*json]:\n"
                b"        pass\n"
                b"json.dumps({})\n"
            ),
            "match-mapping-rest-shadow": (
                b"import json\n"
                b"match value:\n"
                b"    case {**json}:\n"
                b"        pass\n"
                b"json.dumps({})\n"
            ),
        }
        for label, source in mutations.items():
            with self.subTest(label=label):
                snapshot = verifier.CanonicalCoveredFile(
                    data=source,
                    sha256=verifier.sha256_bytes(source),
                    size_bytes=len(source),
                    line_ending="lf",
                )
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    (
                        "forbids (relative import|unreviewed imported value|"
                        "imported binding shadow)"
                    ),
                ):
                    verifier._policy_row_from_snapshot(
                        Path(f"scripts/{label}.py"),
                        "runtime",
                        snapshot,
                    )

        duplicate_fallback = (
            b"try:\n"
            b"    from jsonschema import Draft202012Validator\n"
            b"except ModuleNotFoundError:\n"
            b"    Draft202012Validator = None\n"
            b"try:\n"
            b"    pass\n"
            b"except ModuleNotFoundError:\n"
            b"    Draft202012Validator = None\n"
        )
        duplicate_snapshot = verifier.CanonicalCoveredFile(
            data=duplicate_fallback,
            sha256=verifier.sha256_bytes(duplicate_fallback),
            size_bytes=len(duplicate_fallback),
            line_ending="lf",
        )
        with self.assertRaisesRegex(
            verifier.ReleaseArtifactVerificationError,
            "forbids imported binding shadow",
        ):
            verifier._policy_row_from_snapshot(
                Path("scripts/check_governed_parameter_inventory.py"),
                "runtime",
                duplicate_snapshot,
            )

    def test_closed_world_policy_rejects_hollow_schema(self) -> None:
        hollow = {
            "$schema": verifier.JSON_SCHEMA_DRAFT,
            "$id": verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA_ID,
            "type": "object",
            "properties": {
                "schema_version": {
                    "const": verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA
                },
                "reviewed_paths": {
                    "type": "array",
                    "minItems": 31,
                    "maxItems": 31,
                },
            },
        }
        with self.assertRaisesRegex(
            verifier.ReleaseArtifactVerificationError,
            "exact independent closed-world schema",
        ):
            verifier._validate_policy_schema_document(hollow)

    def test_release_tool_policy_manifest_lock_bindings_are_exact(self) -> None:
        mutations = (
            "manifest-omission",
            "lock-omission",
            "policy-path-substitution",
            "policy-hash",
            "policy-size",
            "schema-id",
            "manifest-lock-drift",
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts/latest"
                    manifest = verifier.load_json(
                        latest / verifier.RELEASE_MANIFEST_NAME
                    )
                    lockfile = verifier.load_json(
                        latest / verifier.RELEASE_CANDIDATE_LOCKFILE_NAME
                    )
                    snapshots = canonical_covered_snapshots(
                        root,
                        checksum_bundle_snapshot(root),
                    )
                    if mutation == "manifest-omission":
                        del manifest["release_artifacts"][
                            "release_tool_call_policy"
                        ]
                    elif mutation == "lock-omission":
                        del lockfile["locked_inputs"][
                            "release_tool_call_policy"
                        ]
                    elif mutation == "policy-path-substitution":
                        for record in (
                            manifest["release_artifacts"][
                                "release_tool_call_policy"
                            ]["policy"],
                            lockfile["locked_inputs"][
                                "release_tool_call_policy"
                            ],
                        ):
                            record["path"] = "scripts/substitute.py"
                    elif mutation == "policy-hash":
                        for record in (
                            manifest["release_artifacts"][
                                "release_tool_call_policy"
                            ]["policy"],
                            lockfile["locked_inputs"][
                                "release_tool_call_policy"
                            ],
                        ):
                            record["sha256"] = "sha256:" + "0" * 64
                    elif mutation == "policy-size":
                        for record in (
                            manifest["release_artifacts"][
                                "release_tool_call_policy"
                            ]["policy"],
                            lockfile["locked_inputs"][
                                "release_tool_call_policy"
                            ],
                        ):
                            record["size_bytes"] += 1
                    elif mutation == "schema-id":
                        for record in (
                            manifest["release_artifacts"][
                                "release_tool_call_policy"
                            ]["schema"],
                            lockfile["locked_inputs"][
                                "release_tool_call_policy_schema"
                            ],
                        ):
                            record["schema_id"] = "https://example.invalid"
                    elif mutation == "manifest-lock-drift":
                        lockfile["locked_inputs"][
                            "release_tool_call_policy"
                        ]["sha256"] = "sha256:" + "1" * 64
                    else:
                        raise AssertionError(mutation)

                    with self.assertRaises(
                        verifier.ReleaseArtifactVerificationError
                    ):
                        verifier.verify_release_tool_call_policy_bindings(
                            manifest,
                            lockfile,
                            snapshots,
                        )

    def test_policy_and_semantic_sources_require_exact_both_index_bindings(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            original = checksum_bundle_snapshot(root)
            snapshots = canonical_covered_snapshots(root, original)
            targets = (
                verifier.RELEASE_TOOL_CALL_POLICY_PATH,
                verifier.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
                *verifier.RECORD_FAMILY_AUTHORIZATION_SEMANTIC_SOURCE_PATHS,
            )
            for target in targets:
                for mutation in (
                    "checksum-omission",
                    "manifest-omission",
                    "same-cardinality-substitution",
                    "checksum-hash",
                    "manifest-hash",
                    "manifest-size",
                ):
                    with self.subTest(target=target, mutation=mutation):
                        checksum_entries = list(original.checksum_entries)
                        manifest = json.loads(
                            original.checksum_manifest_data.decode("utf-8")
                        )
                        if mutation == "checksum-omission":
                            checksum_entries = [
                                entry
                                for entry in checksum_entries
                                if entry[1] != target
                            ]
                        elif mutation == "manifest-omission":
                            manifest["files"] = [
                                entry
                                for entry in manifest["files"]
                                if entry["path"] != target
                            ]
                        elif mutation == "same-cardinality-substitution":
                            checksum_entries = [
                                (
                                    digest,
                                    "scripts/substitute.py"
                                    if path == target
                                    else path,
                                )
                                for digest, path in checksum_entries
                            ]
                            for entry in manifest["files"]:
                                if entry["path"] == target:
                                    entry["path"] = "scripts/substitute.py"
                        elif mutation == "checksum-hash":
                            checksum_entries = [
                                (
                                    "0" * 64 if path == target else digest,
                                    path,
                                )
                                for digest, path in checksum_entries
                            ]
                        else:
                            for entry in manifest["files"]:
                                if entry["path"] != target:
                                    continue
                                if mutation == "manifest-hash":
                                    entry["sha256"] = "sha256:" + "0" * 64
                                else:
                                    entry["size_bytes"] += 1
                        mutated = original._replace(
                            checksum_entries=tuple(checksum_entries),
                            checksum_manifest=manifest,
                        )
                        with self.assertRaises(
                            verifier.ReleaseArtifactVerificationError
                        ):
                            verifier._require_index_binding(
                                mutated,
                                snapshots,
                                target,
                                label=target,
                            )

    def test_verifier_independently_pins_reviewed_subprocess_sources(
        self,
    ) -> None:
        expected = {
            Path("scripts/check_changelog.py"): (
                "3a1e93aa1b524b54ff492b432dc143afd5ecb1c6b8c4ec42c377d62d70733065",
                8_999,
            ),
            Path("scripts/check_record_family_authorization.py"): (
                "255dbad891416458370fe598f863c21301b307f4d27e1343b3a64f9a48ecb2b0",
                100_553,
            ),
            Path("scripts/check_slither_baseline.py"): (
                "052ccda0c60bcd597cd6c1d7901ade55bbf56c644dc0cf79bed06e30ce749096",
                46_536,
            ),
        }
        self.assertEqual(
            verifier.REVIEWED_RELEASE_TOOL_SUBPROCESS_SOURCES,
            expected,
        )
        self.assertTrue(
            set(expected).issubset(
                verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
            )
        )
        snapshots: dict[str, verifier.CanonicalCoveredFile] = {}
        for relative_path, (expected_sha256, expected_size) in expected.items():
            data = (SOURCE_REPO_ROOT / relative_path).read_bytes()
            self.assertEqual(len(data), expected_size)
            self.assertEqual(
                verifier.hashlib.sha256(data).hexdigest(),
                expected_sha256,
            )
            snapshots[relative_path.as_posix()] = verifier.CanonicalCoveredFile(
                data=data,
                sha256=f"sha256:{expected_sha256}",
                size_bytes=expected_size,
                line_ending="lf",
            )

        verifier.verify_reviewed_subprocess_source_bindings(snapshots)

        for target in expected:
            original = snapshots[target.as_posix()]
            mutations = (
                bytes([original.data[0] ^ 1]) + original.data[1:],
                original.data + b"\n",
            )
            for data in mutations:
                with self.subTest(target=target, size=len(data)):
                    mutated = dict(snapshots)
                    mutated[target.as_posix()] = original._replace(data=data)
                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "reviewed subprocess source differs from the "
                        "verifier's exact hash/size binding",
                    ):
                        verifier.verify_reviewed_subprocess_source_bindings(
                            mutated
                        )

    def test_full_verifier_keeps_subprocess_binding_when_generator_is_weakened(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            target = Path("scripts/check_changelog.py")
            target_path = root / target
            original = target_path.read_bytes()
            write_bytes(
                target_path,
                bytes([original[0] ^ 1]) + original[1:],
            )
            refresh_checksum_indexes(root)

            with mock.patch.dict(
                verifier.sys.modules,
                {
                    "generate_release_checksums": mock.Mock(
                        validate_canonical_release_checksum_policy=(
                            lambda *_a, **_k:
                            verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
                        )
                    )
                },
            ):
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "reviewed subprocess source differs from the verifier's "
                    "exact hash/size binding",
                ):
                    self.verify_fixture_release_artifacts(root)

    def test_checksum_indexes_use_one_immutable_snapshot(self) -> None:
        target = "docs/release-readiness.md"
        substitute = "docs/status.md"
        for mutation in (
            "delete",
            "substitute",
            "hash",
            "size",
            "eol",
            "replace_checksum",
            "replace_manifest",
            "relink_checksum",
            "relink_manifest",
        ):
            with self.subTest(mutation=mutation):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts" / "latest"
                    checksum_path = latest / verifier.CHECKSUM_FILE_NAME
                    manifest_path = latest / verifier.CHECKSUM_MANIFEST_NAME
                    original_snapshot = verifier.snapshot_checksum_bundle

                    def snapshot_then_mutate(*args, **kwargs):
                        bundle = original_snapshot(*args, **kwargs)
                        lines = checksum_path.read_text(
                            encoding="utf-8"
                        ).splitlines()
                        manifest = json.loads(
                            manifest_path.read_text(encoding="utf-8")
                        )
                        if mutation == "delete":
                            lines = [
                                line
                                for line in lines
                                if not line.endswith(f"  {target}")
                            ]
                            manifest["files"] = [
                                entry
                                for entry in manifest["files"]
                                if entry["path"] != target
                            ]
                            write_mutated_checksum_indexes(
                                root,
                                lines,
                                manifest,
                            )
                        elif mutation == "substitute":
                            lines = [
                                (
                                    line.removesuffix(target) + substitute
                                    if line.endswith(f"  {target}")
                                    else line
                                )
                                for line in lines
                            ]
                            for entry in manifest["files"]:
                                if entry["path"] == target:
                                    entry["path"] = substitute
                            write_mutated_checksum_indexes(
                                root,
                                lines,
                                manifest,
                            )
                        elif mutation == "hash":
                            lines = [
                                (
                                    f"{'0' * 64}  {target}"
                                    if line.endswith(f"  {target}")
                                    else line
                                )
                                for line in lines
                            ]
                            for entry in manifest["files"]:
                                if entry["path"] == target:
                                    entry["sha256"] = "sha256:" + "0" * 64
                            write_mutated_checksum_indexes(
                                root,
                                lines,
                                manifest,
                            )
                        elif mutation == "size":
                            for entry in manifest["files"]:
                                if entry["path"] == target:
                                    entry["size_bytes"] += 1
                            write_json(manifest_path, manifest)
                        elif mutation == "eol":
                            write_bytes(
                                checksum_path,
                                checksum_path.read_bytes().replace(
                                    b"\n",
                                    b"\r\n",
                                ),
                            )
                            write_bytes(
                                manifest_path,
                                manifest_path.read_bytes().replace(
                                    b"\n",
                                    b"\r\n",
                                ),
                            )
                        elif mutation in {
                            "replace_checksum",
                            "replace_manifest",
                        }:
                            replaced_path = (
                                checksum_path
                                if mutation == "replace_checksum"
                                else manifest_path
                            )
                            replaced_path.unlink()
                            write_bytes(replaced_path, b"replacement\n")
                        elif mutation in {
                            "relink_checksum",
                            "relink_manifest",
                        }:
                            relinked_path = (
                                checksum_path
                                if mutation == "relink_checksum"
                                else manifest_path
                            )
                            replacement = (
                                root / "tmp" / f"{mutation}.replacement"
                            )
                            write_bytes(replacement, b"replacement\n")
                            relinked_path.unlink()
                            os.link(replacement, relinked_path)
                        else:
                            raise AssertionError(
                                f"unsupported index mutation {mutation}"
                            )
                        return bundle

                    with mock.patch.object(
                        verifier,
                        "snapshot_checksum_bundle",
                        side_effect=snapshot_then_mutate,
                    ):
                        summary = self.verify_fixture_release_artifacts(root)
                    self.assertEqual(
                        summary.checksum_entries,
                        summary.checksum_manifest_records,
                    )
                    self.assertGreater(summary.checksum_entries, 0)

    def test_each_checksum_index_is_read_exactly_once(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            tracked = {
                (latest / verifier.CHECKSUM_FILE_NAME).resolve(): 0,
                (latest / verifier.CHECKSUM_MANIFEST_NAME).resolve(): 0,
            }
            path_class = type(next(iter(tracked)))
            original_open = path_class.open

            def count_index_reads(path: Path, *args, **kwargs):
                lexical = path.resolve()
                if lexical in tracked:
                    tracked[lexical] += 1
                    if tracked[lexical] > 1:
                        raise AssertionError(
                            f"checksum index reread: {lexical}"
                        )
                return original_open(path, *args, **kwargs)

            with mock.patch.object(
                path_class,
                "open",
                new=count_index_reads,
            ):
                summary = self.verify_fixture_release_artifacts(root)
            self.assertGreater(summary.checksum_entries, 0)
            self.assertEqual(set(tracked.values()), {1})

    def test_checksum_indexes_must_each_have_one_hard_link(self) -> None:
        for name in (
            verifier.CHECKSUM_FILE_NAME,
            verifier.CHECKSUM_MANIFEST_NAME,
        ):
            with self.subTest(name=name):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    target = root / "release-artifacts" / "latest" / name
                    alias = root / "tmp" / name
                    alias.parent.mkdir(parents=True, exist_ok=True)
                    try:
                        os.link(target, alias)
                    except OSError as exc:
                        self.skipTest(
                            f"hardlinks unavailable in this environment: {exc}"
                        )
                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "must have exactly one hard link",
                    ):
                        self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_lf_declared_file_with_crlf(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_bytes(
                root / "docs/release-readiness.md",
                b"line one\r\nline two\r\n",
            )
            refresh_checksum_indexes(root)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "violates declared eol=lf: docs/release-readiness.md",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_crlf_declared_file_with_bare_or_mixed_lf(
        self,
    ) -> None:
        for label, data in (
            ("bare-lf", b"line one\nline two\n"),
            ("mixed", b"line one\r\nline two\n"),
            ("lone-cr", b"line one\rline two\r\n"),
        ):
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    write_bytes(root / "scripts/check.ps1", data)
                    refresh_checksum_indexes(root)
                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "violates declared eol=crlf: scripts/check.ps1",
                    ):
                        self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_attribute_unspecified_text(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            target = "deployments/examples/unclassified.dat"
            write_bytes(root / target, b"text without a NUL\n")
            manifest_path = (
                root / "release-artifacts/latest/release-checksums.json"
            )
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"].append(file_record(root, target))
            write_json(manifest_path, manifest)
            refresh_checksum_indexes(root)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "must declare explicit eol=lf or eol=crlf",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_accepts_binary_crlf_bytes_without_normalization(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            target = "deployments/examples/binary-payload.dat"
            payload = b"\x00prefix\r\nbinary\rbytes\n"
            write_bytes(root / target, payload)
            manifest_path = (
                root / "release-artifacts/latest/release-checksums.json"
            )
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"].append(file_record(root, target))
            write_json(manifest_path, manifest)
            refresh_checksum_indexes(root)
            snapshots = verifier.verify_canonical_line_ending_bindings(
                root,
                checksum_bundle_snapshot(root),
            )
            self.assertEqual(snapshots[target].line_ending, "binary")
            self.assertEqual(snapshots[target].data, payload)
            self.verify_fixture_release_artifacts(root)

    def test_canonical_snapshot_is_stable_across_equivalent_checkouts(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            roots = (Path(temp_dir) / "one", Path(temp_dir) / "two")
            snapshots_by_root = []
            for root in roots:
                seed_release_bundle(root)
                snapshots_by_root.append(
                    verifier.verify_canonical_line_ending_bindings(
                        root,
                        checksum_bundle_snapshot(root),
                    )
                )
            for target in (
                verifier.GIT_ATTRIBUTES_PATH,
                "docs/release-readiness.md",
                "scripts/check.ps1",
            ):
                self.assertEqual(
                    snapshots_by_root[0][target],
                    snapshots_by_root[1][target],
                )

    def test_verifier_rejects_nested_gitattributes_override(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            target = "release-artifacts/evidence/.gitattributes"
            write_bytes(root / target, b"* text eol=crlf\n")
            manifest_path = (
                root / "release-artifacts/latest/release-checksums.json"
            )
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"].append(file_record(root, target))
            write_json(manifest_path, manifest)
            refresh_checksum_indexes(root)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "forbids nested .gitattributes",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_coordinated_nontrust_file_omission(
        self,
    ) -> None:
        target = "docs/release-readiness.md"
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
            write_mutated_checksum_indexes(root, lines, manifest)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical coverage root.*docs/release-readiness.md|"
                "exact on-disk component spelling",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_checksum_path_aliases(self) -> None:
        target = "docs/release-readiness.md"
        aliases = (
            "docs//release-readiness.md",
            "docs/./release-readiness.md",
            r"docs\release-readiness.md",
            "DOCS/release-readiness.md",
        )
        for alias in aliases:
            with self.subTest(alias=alias):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts/latest"
                    checksum_path = latest / "SHA256SUMS"
                    manifest_path = latest / "release-checksums.json"
                    lines = checksum_path.read_text(
                        encoding="utf-8"
                    ).splitlines()
                    target_index = next(
                        index
                        for index, line in enumerate(lines)
                        if line.endswith(f"  {target}")
                    )
                    digest = lines[target_index].split("  ", 1)[0]
                    lines[target_index] = f"{digest}  {alias}"
                    manifest = json.loads(
                        manifest_path.read_text(encoding="utf-8")
                    )
                    next(
                        entry
                        for entry in manifest["files"]
                        if entry["path"] == target
                    )["path"] = alias
                    write_mutated_checksum_indexes(root, lines, manifest)
                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "normalized repository-relative path|invalid path|"
                        "checksum indexes omit configured files.*"
                        "docs/release-readiness.md",
                    ):
                        self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_on_disk_case_alias(self) -> None:
        target = Path("docs/release-readiness.md")
        alias = Path("docs/RELEASE-READINESS.md")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            intermediate = root / "docs/release-readiness.tmp"
            (root / target).rename(intermediate)
            intermediate.rename(root / alias)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "exact on-disk component spelling",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_gitattributes_index_mutations(self) -> None:
        target = verifier.GIT_ATTRIBUTES_PATH
        for mutation, expected_error in (
            (
                "delete",
                "checksum indexes omit configured files.*.gitattributes",
            ),
            (
                "substitute",
                "checksum indexes omit configured files.*.gitattributes",
            ),
            ("sha_wrong_hash", "checksum indexes disagree.*.gitattributes"),
            ("manifest_wrong_size", "size mismatch.*.gitattributes"),
            ("post_mutation", "hash mismatch.*.gitattributes"),
        ):
            with self.subTest(mutation=mutation):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_release_bundle(root)
                    latest = root / "release-artifacts/latest"
                    checksum_path = latest / "SHA256SUMS"
                    manifest_path = latest / "release-checksums.json"
                    lines = checksum_path.read_text(
                        encoding="utf-8"
                    ).splitlines()
                    manifest = json.loads(
                        manifest_path.read_text(encoding="utf-8")
                    )
                    target_index = next(
                        index
                        for index, line in enumerate(lines)
                        if line.endswith(f"  {target}")
                    )
                    target_entry = next(
                        entry
                        for entry in manifest["files"]
                        if entry["path"] == target
                    )
                    if mutation in {"delete", "substitute"}:
                        lines.pop(target_index)
                        manifest["files"].remove(target_entry)
                        if mutation == "substitute":
                            substitute = ".attributes-substitute"
                            write_bytes(root / substitute, b"* text eol=lf\n")
                            substitute_record = file_record(root, substitute)
                            lines.append(
                                substitute_record["sha256"].removeprefix(
                                    "sha256:"
                                )
                                + f"  {substitute}"
                            )
                            manifest["files"].append(substitute_record)
                    elif mutation == "sha_wrong_hash":
                        lines[target_index] = "0" * 64 + f"  {target}"
                    elif mutation == "manifest_wrong_size":
                        target_entry["size_bytes"] += 1
                    elif mutation == "post_mutation":
                        attributes = (root / target).read_bytes()
                        write_bytes(
                            root / target,
                            attributes.replace(
                                b".gitignore",
                                b".GITIGNORE",
                                1,
                            ),
                        )
                    write_mutated_checksum_indexes(root, lines, manifest)
                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        expected_error,
                    ):
                        self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_coordinated_gitattributes_rewrite(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_bytes(
                root / verifier.GIT_ATTRIBUTES_PATH,
                (
                    (root / verifier.GIT_ATTRIBUTES_PATH).read_bytes()
                    + b"*.bad text unsupported\n"
                ),
            )
            refresh_checksum_indexes(root)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "unsupported .gitattributes attribute",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_offline_verifier_loads_checkers_only_after_policy_validation(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            order: list[str] = []
            original_trust = verifier.verify_release_tool_trust_bindings
            original_load = verifier._load_snapshot_checker

            def checked_trust(*args, **kwargs):
                order.append("trust")
                return original_trust(*args, **kwargs)

            def checked_load(*args, **kwargs):
                self.assertEqual(order[0], "trust")
                self.assertNotIn(args[1], order)
                order.append(args[1])
                return original_load(*args, **kwargs)

            with (
                mock.patch.object(
                    verifier,
                    "verify_release_tool_trust_bindings",
                    side_effect=checked_trust,
                ),
                mock.patch.object(
                    verifier,
                    "_load_snapshot_checker",
                    side_effect=checked_load,
                ),
            ):
                verifier.verify_release_artifacts(root)

        self.assertEqual(
            order,
            [
                "trust",
                "check_governed_parameter_inventory",
                "check_record_family_authorization",
            ],
        )

    def test_offline_verifier_loads_checkers_from_materialized_snapshot(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            observed_roots: list[tuple[Path, bool]] = []
            original_load = verifier._load_snapshot_checker

            def capture_load(snapshot_root: Path, module_name: str):
                observed_roots.append(
                    (snapshot_root, (snapshot_root / "scripts").is_dir())
                )
                return original_load(snapshot_root, module_name)

            with mock.patch.object(
                verifier,
                "_load_snapshot_checker",
                side_effect=capture_load,
            ) as checker_loader:
                verifier.verify_release_artifacts(repo_root=root)

        self.assertEqual(checker_loader.call_count, 2)
        for validated_root, scripts_present in observed_roots:
            self.assertNotEqual(validated_root, root.resolve())
            self.assertTrue(scripts_present)

    def test_snapshot_checker_loader_uses_snapshot_dependency_and_restores_preloaded_module(
        self,
    ) -> None:
        dependency_name = "check_governed_parameter_identifiers"
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(
                root / "scripts/check_governed_parameter_identifiers.py",
                "VALUE = 'snapshot'\n",
            )
            checker_path = root / "scripts/check_governed_parameter_inventory.py"
            write_text(
                checker_path,
                "import check_governed_parameter_identifiers as identifier_checker\n"
                "VALUE = identifier_checker.VALUE\n",
            )
            preloaded = type(verifier)(dependency_name)
            preloaded.VALUE = "live"
            preloaded.__file__ = str(root.parent / "live_dependency.py")
            prior = verifier.sys.modules.get(dependency_name)
            original_path = list(verifier.sys.path)
            verifier.sys.modules[dependency_name] = preloaded
            try:
                loaded = verifier._load_snapshot_checker(
                    root,
                    "check_governed_parameter_inventory",
                )
                self.assertEqual(loaded.VALUE, "snapshot")
                self.assertIsNot(loaded.identifier_checker, preloaded)
                self.assertEqual(
                    Path(loaded.identifier_checker.__file__).resolve(),
                    (
                        root
                        / "scripts/check_governed_parameter_identifiers.py"
                    ).resolve(),
                )
                self.assertIs(verifier.sys.modules[dependency_name], preloaded)
                self.assertEqual(verifier.sys.path, original_path)

                write_text(
                    checker_path,
                    "import check_governed_parameter_identifiers\n"
                    "raise RuntimeError('boom')\n",
                )
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "cannot execute validated snapshot checker",
                ):
                    verifier._load_snapshot_checker(
                        root,
                        "check_governed_parameter_inventory",
                    )
                self.assertIs(verifier.sys.modules[dependency_name], preloaded)
                self.assertEqual(verifier.sys.path, original_path)
            finally:
                if prior is None:
                    verifier.sys.modules.pop(dependency_name, None)
                else:
                    verifier.sys.modules[dependency_name] = prior

    def test_snapshot_checker_loader_rejects_unreviewed_module(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(
                root / "scripts/unreviewed_checker.py",
                "VALUE = True\n",
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "unreviewed snapshot checker module",
            ):
                verifier._load_snapshot_checker(
                    root,
                    "unreviewed_checker",
                )

    def test_failed_policy_validation_never_loads_snapshot_checker(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            with (
                mock.patch.object(
                    verifier,
                    "verify_release_tool_trust_bindings",
                    side_effect=verifier.ReleaseArtifactVerificationError(
                        "policy rejected"
                    ),
                ),
                mock.patch.object(
                    verifier,
                    "_load_snapshot_checker",
                ) as checker_loader,
                self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "policy rejected",
                ),
            ):
                verifier.verify_release_artifacts(root)
            checker_loader.assert_not_called()

    def test_offline_verifier_rejects_record_family_semantic_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            inventory_path = (
                root / verifier.RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH
            )
            inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
            inventory["schema_version"] = "invalid"
            write_json(inventory_path, inventory)
            refresh_checksum_indexes(root)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "record-family authorization semantic validation failed",
            ):
                verifier.verify_release_artifacts(root)

    def test_offline_verifier_rejects_malformed_planning_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            inventory_path = (
                root
                / verifier.GOVERNED_PARAMETER_INVENTORY_PATH
            )
            inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
            inventory["status"] = "complete"
            write_json(inventory_path, inventory)
            refresh_checksum_indexes(root)

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
        references = verifier._independent_complete_reference_bindings(
            inventory
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
            write_text(
                root / "release-artifacts/candidate.json",
                '{"candidate":true}\n',
            )
            with mock.patch.object(
                verifier,
                "validate_bound_snapshot_semantics",
                return_value=inventory,
            ):
                with self.assertRaisesRegex(
                    verifier.ReleaseArtifactVerificationError,
                    "complete reference is not covered.*"
                    "release-artifacts/candidate.json",
                ):
                    verifier.verify_release_artifacts(root)

    def test_committed_release_bundle_verifies(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        summary = verifier.verify_release_artifacts(repo_root)
        self.assertEqual(summary.checksum_entries, 432)
        self.assertEqual(summary.checksum_manifest_records, 432)
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
        self.assertEqual(data["checksum_entries"], 432)
        self.assertEqual(data["checksum_manifest_records"], 432)

    def test_main_failure_returns_nonzero_and_stderr(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_text(root / "release-artifacts" / "latest" / "abi-checksums.json", "changed\n")
            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = verifier.main(["--repo-root", str(root)])
            self.assertEqual(result, 1)
            self.assertIn(
                "error: canonical line-ending binding size mismatch",
                stderr.getvalue(),
            )

    def test_minimal_bundle_verifies(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            summary = self.verify_fixture_release_artifacts(root)
            required_trust_count = len(
                set(verifier.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE).union(
                    verifier.REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
                )
            )
            expected_count = 12 + required_trust_count
            self.assertGreaterEqual(summary.checksum_entries, expected_count)
            self.assertEqual(
                summary.checksum_manifest_records,
                summary.checksum_entries,
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
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_coordinated_inventory_schema_index_deletion(
        self,
    ) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "delete",
            (
                "canonical line-ending checksum indexes omit configured files.*"
                "record-family-authorization-inventory"
            ),
        )

    def test_verifier_rejects_same_cardinality_inventory_schema_substitution(
        self,
    ) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "substitute",
            (
                "canonical line-ending checksum indexes omit configured files.*"
                "record-family-authorization-inventory"
            ),
        )

    def test_verifier_rejects_inventory_schema_checksum_hash_drift(self) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "sha_wrong_hash",
            "canonical line-ending binding checksum indexes disagree",
        )
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "manifest_wrong_hash",
            "canonical line-ending binding checksum indexes disagree",
        )

    def test_verifier_rejects_inventory_schema_checksum_size_drift(self) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "manifest_wrong_size",
            "canonical line-ending binding size mismatch",
        )

    def test_verifier_rejects_inventory_schema_post_bundle_mutation(self) -> None:
        self.assert_record_family_inventory_schema_index_mutation_rejected(
            "post_file_mutation",
            "canonical line-ending binding size mismatch",
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
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_required_trust_file_deleted_from_sha256sums(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "sha_delete",
            (
                "canonical line-ending checksum-index file-set mismatch.*"
                "release-checksums.json-only=.*"
                "scripts/generate_bytecode_release_proof.py"
            ),
        )

    def test_verifier_rejects_required_trust_file_deleted_from_checksum_manifest(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "manifest_delete",
            (
                "canonical line-ending checksum-index file-set mismatch.*"
                "SHA256SUMS-only=.*"
                "scripts/generate_bytecode_release_proof.py"
            ),
        )

    def test_verifier_rejects_required_trust_file_substituted_in_sha256sums(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "sha_substitute",
            (
                "canonical line-ending checksum-index file-set mismatch.*"
                "release-checksums.json-only=.*"
                "scripts/generate_bytecode_release_proof.py"
            ),
        )

    def test_verifier_rejects_required_trust_file_substituted_in_checksum_manifest(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "manifest_substitute",
            (
                "canonical line-ending checksum-index file-set mismatch.*"
                "SHA256SUMS-only=.*scripts/generate_bytecode_release_proof.py"
            ),
        )

    def test_verifier_rejects_required_trust_file_wrong_hash_in_sha256sums(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "sha_wrong_hash",
            "canonical line-ending binding checksum indexes disagree for "
            "scripts/generate_bytecode_release_proof.py",
        )

    def test_verifier_rejects_required_trust_file_wrong_hash_in_checksum_manifest(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "manifest_wrong_hash",
            "canonical line-ending binding checksum indexes disagree for "
            "scripts/generate_bytecode_release_proof.py",
        )

    def test_verifier_rejects_required_trust_file_wrong_size_in_checksum_manifest(
        self,
    ) -> None:
        self.assert_release_tool_bundle_mutation_rejected(
            "manifest_wrong_size",
            "canonical line-ending binding size mismatch for "
            "scripts/generate_bytecode_release_proof.py",
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
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_coordinated_trust_file_deletion(self) -> None:
        self.assert_coordinated_release_tool_bundle_mutation_rejected(
            "delete",
            (
                "canonical line-ending checksum indexes omit configured files.*"
                "scripts/generate_bytecode_release_proof.py"
            ),
        )

    def test_verifier_rejects_coordinated_trust_file_substitution(self) -> None:
        self.assert_coordinated_release_tool_bundle_mutation_rejected(
            "substitute",
            (
                "canonical line-ending checksum indexes omit configured files.*"
                "scripts/generate_bytecode_release_proof.py"
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
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_noncanonical_trust_source_policy(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            manifest_path = (
                root
                / "release-artifacts/latest/release-checksums.json"
            )
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["source"]["coverage_policy"] = "custom-subset"
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "require canonical coverage_policy",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_broad_trust_source_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            manifest_path = (
                root
                / "release-artifacts/latest/release-checksums.json"
            )
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            removed = TEST_RELEASE_TOOL_ROOTS[0].as_posix()
            covered_paths = manifest["source"]["covered_paths"]
            covered_paths.remove(removed)
            covered_paths.append("scripts")
            write_json(manifest_path, manifest)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "coverage roots differ from the independent verifier policy",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_mutated_release_tool_after_bundle_creation(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle_with_trust_input(root)
            write_text(root / RELEASE_TOOL_FIXTURE_PATH, "VALUE = 2\n")
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical line-ending binding size mismatch for "
                "scripts/generate_bytecode_release_proof.py",
            ):
                self.verify_fixture_release_artifacts(root)

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
                "record_family_authorization_evidence_schema"
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
                "keys must be exactly source_catalog, source_catalog_schema, "
                "inventory, inventory_schema, evidence_schema, grant_map_schema, "
                "and evidence_template",
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

    def test_verifier_rejects_record_family_evidence_schema_omission(self) -> None:
        for owner, key in (
            ("manifest", "evidence_schema"),
            ("lockfile", "record_family_authorization_evidence_schema"),
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
                        "evidence_schema|record_family_authorization_evidence_schema",
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_record_family_evidence_schema_identity_drift(
        self,
    ) -> None:
        mutations = (
            (
                "path",
                "deployments/schema/substituted-evidence.schema.json",
                "evidence schema path must be",
            ),
            (
                "schema_version",
                "https://json-schema.org/draft/2019-09/schema",
                "evidence schema must use schema",
            ),
            (
                "schema_id",
                "https://example.invalid/evidence.json",
                r"evidence schema\.schema_id must be",
            ),
            (
                "document_schema_version",
                "6529stream.record-family-authorization-evidence.v2",
                r"evidence schema\.document_schema_version must be",
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
                    ]["evidence_schema"][field] = value

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        expected_error,
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_record_family_evidence_schema_record_key_drift(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")
            release_manifest["release_artifacts"]["record_family_authorization"][
                "evidence_schema"
            ]["unreviewed"] = True

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "evidence schema keys must be exactly",
            ):
                verifier.verify_record_family_authorization_bindings(
                    release_manifest,
                    lockfile,
                )

    def test_verifier_rejects_record_family_evidence_schema_manifest_lock_drift(
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
                    ]["evidence_schema"][field] = value

                    with self.assertRaisesRegex(
                        verifier.ReleaseArtifactVerificationError,
                        "evidence schema records do not match",
                    ):
                        verifier.verify_record_family_authorization_bindings(
                            release_manifest,
                            lockfile,
                        )

    def test_verifier_rejects_coordinated_evidence_schema_substitution(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            release_manifest = verifier.load_json(latest / "release-manifest.json")
            lockfile = verifier.load_json(latest / "release-candidate-lockfile.json")
            substituted = record_family_grant_map_schema_record(root)
            release_manifest["release_artifacts"]["record_family_authorization"][
                "evidence_schema"
            ] = dict(substituted)
            lockfile["locked_inputs"][
                "record_family_authorization_evidence_schema"
            ] = dict(substituted)

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "evidence schema path must be",
            ):
                verifier.verify_record_family_authorization_bindings(
                    release_manifest,
                    lockfile,
                )

    def test_verifier_rejects_coordinated_evidence_schema_hash_or_size_drift(
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
                    ]["evidence_schema"]
                    lockfile_record = lockfile["locked_inputs"][
                        "record_family_authorization_evidence_schema"
                    ]
                    release_manifest_record[field] = value
                    lockfile_record[field] = value
                    verifier.verify_record_family_authorization_bindings(
                        release_manifest,
                        lockfile,
                    )
                    checksum_bundle = checksum_bundle_snapshot(root)
                    snapshots = canonical_covered_snapshots(
                        root,
                        checksum_bundle,
                    )
                    checksum_entries = verifier.verify_checksum_file(
                        root,
                        checksum_bundle,
                        snapshots,
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
                            snapshots,
                        )

    def test_verifier_rejects_evidence_schema_post_bundle_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            evidence_schema_path = (
                root / verifier.RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH
            )
            write_text(
                evidence_schema_path,
                evidence_schema_path.read_text(encoding="utf-8") + "\n",
            )

            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical line-ending binding size mismatch|"
                "canonical line-ending binding SHA256SUMS hash mismatch",
            ):
                self.verify_fixture_release_artifacts(root)

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
                        "grant_map_schema|"
                        "record_family_authorization_grant_map_schema",
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
                    checksum_bundle = checksum_bundle_snapshot(root)
                    snapshots = canonical_covered_snapshots(
                        root,
                        checksum_bundle,
                    )
                    checksum_entries = verifier.verify_checksum_file(
                        root,
                        checksum_bundle,
                        snapshots,
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
                            snapshots,
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
                "canonical line-ending checksum indexes omit configured files.*"
                "release-artifacts/latest/unlisted.json",
            ):
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(root)

    def test_release_directory_closure_allows_checksum_index_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            latest = root / "release-artifacts" / "latest"
            checksum_bundle = checksum_bundle_snapshot(root)
            snapshots = canonical_covered_snapshots(root, checksum_bundle)
            checksum_entries = verifier.verify_checksum_file(
                root,
                checksum_bundle,
                snapshots,
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
                "must not include symlinks or reparse points",
            ):
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(root)

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
                "canonical coverage root deployments/examples must not "
                "include symlinks or reparse points|"
                "canonical covered path must not include symlinks or "
                "reparse points",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_nested_checksum_covered_directory_symlink(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            target_dir = root / "outside" / "nested-target"
            write_text(target_dir / "payload.json", "{}\n")
            link_path = root / "deployments" / "examples" / "nested-link"
            try:
                link_path.symlink_to(target_dir, target_is_directory=True)
            except OSError as exc:
                self.skipTest(
                    f"directory symlinks unavailable in this environment: {exc}"
                )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical covered path must not include symlinks or "
                "reparse points: deployments/examples/nested-link",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_dangling_checksum_covered_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            link_path = root / "deployments" / "examples" / "dangling.json"
            try:
                link_path.symlink_to(root / "missing" / "target.json")
            except OSError as exc:
                self.skipTest(f"symlinks unavailable in this environment: {exc}")
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical covered path must not include symlinks or "
                "reparse points: deployments/examples/dangling.json",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_covered_symlink_to_excluded_checksum_output(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            link_path = root / "deployments" / "examples" / "checksum-link"
            checksum_path = root / "release-artifacts/latest/SHA256SUMS"
            try:
                link_path.symlink_to(checksum_path)
            except OSError as exc:
                self.skipTest(f"symlinks unavailable in this environment: {exc}")
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical covered path must not include symlinks or "
                "reparse points: deployments/examples/checksum-link",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_symlinked_repository_root(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            real_root = Path(temp_dir) / "real"
            seed_release_bundle(real_root)
            linked_root = Path(temp_dir) / "linked"
            try:
                linked_root.symlink_to(real_root, target_is_directory=True)
            except OSError as exc:
                self.skipTest(
                    f"directory symlinks unavailable in this environment: {exc}"
                )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "repository root must not include symlinks or reparse points",
            ):
                self.verify_fixture_release_artifacts(linked_root)

    def test_verifier_rejects_covered_file_hardlinked_to_checksum_output(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            target = root / "docs/release-readiness.md"
            checksum_path = root / "release-artifacts/latest/SHA256SUMS"
            target.unlink()
            try:
                os.link(checksum_path, target)
            except OSError as exc:
                self.skipTest(f"hardlinks unavailable in this environment: {exc}")
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "SHA256SUMS must have exactly one hard link",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_two_covered_paths_hardlinked_together(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            source = root / "docs/tooling.md"
            target = root / "docs/release-readiness.md"
            target.unlink()
            try:
                os.link(source, target)
            except OSError as exc:
                self.skipTest(f"hardlinks unavailable in this environment: {exc}")
            refresh_checksum_indexes(root)
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical covered files must not alias the same file: "
                "docs/release-readiness.md, docs/tooling.md|"
                "docs/tooling.md, docs/release-readiness.md",
            ):
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(
                    root,
                    Path("release-artifacts/linked-latest"),
                )

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
                self.verify_fixture_release_artifacts(root, outside)

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
                "release-artifacts/latest/abi-checksums.json.*"
                "must use exact on-disk component spelling",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_rejects_stale_checksum_file_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            write_text(root / "release-artifacts" / "latest" / "abi-checksums.json", "changed\n")
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical line-ending binding size mismatch for "
                "release-artifacts/latest/abi-checksums.json",
            ):
                self.verify_fixture_release_artifacts(root)

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
                "canonical line-ending binding checksum indexes disagree",
            ):
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(root)

    def test_verifier_requires_nested_release_manifest_checksum_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            remove_path_from_checksum_indexes(
                root,
                "deployments/examples/anvil.json",
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical line-ending checksum indexes omit configured files.*"
                "deployments/examples/anvil.json",
            ):
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(root)

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
                self.verify_fixture_release_artifacts(root)

    def test_verifier_requires_release_manifest_checksum_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            remove_path_from_checksum_indexes(
                root,
                "release-artifacts/latest/release-manifest.json",
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical line-ending checksum indexes omit configured files.*"
                "release-artifacts/latest/release-manifest.json",
            ):
                self.verify_fixture_release_artifacts(root)

    def test_verifier_requires_release_candidate_lockfile_checksum_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_release_bundle(root)
            remove_path_from_checksum_indexes(
                root,
                "release-artifacts/latest/release-candidate-lockfile.json",
            )
            with self.assertRaisesRegex(
                verifier.ReleaseArtifactVerificationError,
                "canonical line-ending checksum indexes omit configured files.*"
                "release-artifacts/latest/release-candidate-lockfile.json",
            ):
                self.verify_fixture_release_artifacts(root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
