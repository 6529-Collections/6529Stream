#!/usr/bin/env python3
"""Focused tests for 1/1 permanence package validation and generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


CHECKER_PATH = Path(__file__).with_name("check_one_of_one_permanence_package.py")
CHECKER_SPEC = importlib.util.spec_from_file_location(
    "check_one_of_one_permanence_package", CHECKER_PATH
)
assert CHECKER_SPEC is not None and CHECKER_SPEC.loader is not None
checker = importlib.util.module_from_spec(CHECKER_SPEC)
CHECKER_SPEC.loader.exec_module(checker)

GENERATOR_PATH = Path(__file__).with_name("generate_one_of_one_permanence_manifest.py")
GENERATOR_SPEC = importlib.util.spec_from_file_location(
    "generate_one_of_one_permanence_manifest", GENERATOR_PATH
)
assert GENERATOR_SPEC is not None and GENERATOR_SPEC.loader is not None
generator = importlib.util.module_from_spec(GENERATOR_SPEC)
GENERATOR_SPEC.loader.exec_module(generator)

REPO_ROOT = Path(__file__).resolve().parents[1]
COMMITTED_TEMPLATE = (
    "release-artifacts/permanence/one-of-one-permanence-template.permanence.json"
)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def file_ref(root: Path, relative_path: str, content: str, *, category: str) -> dict[str, str]:
    """Create or hash a retained file reference."""
    path = root / relative_path
    write_text(path, content)
    return {
        "category": category,
        "path": relative_path,
        "sha256": checker.file_sha256(path),
    }


def binding_file(root: Path, relative_path: str, content: str) -> dict[str, str]:
    """Create a binding file reference without a category field."""
    path = root / relative_path
    write_text(path, content)
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def seed_binding_files(root: Path) -> dict[str, dict[str, str]]:
    """Create release/provenance/dependency binding files."""
    write_text(root / "release-artifacts/latest/release-manifest.json", "{}\n")
    write_text(root / "release-artifacts/latest/SHA256SUMS", "placeholder\n")
    return {
        "dependency": binding_file(
            root,
            "release-artifacts/latest/dependency-artifact-manifest.json",
            '{"schema_version":"6529stream.dependency-artifact-manifest.v1"}\n',
        ),
        "provenance": binding_file(
            root,
            "release-artifacts/latest/one-of-one-provenance-manifest.json",
            '{"schema_version":"6529stream.one-of-one-provenance-release-manifest.v1"}\n',
        ),
    }


def valid_package(root: Path, *, review_status: str = "reviewed") -> dict[str, object]:
    """Build a valid permanence package fixture."""
    schema_ref = file_ref(
        root,
        "release-artifacts/schema/one-of-one-permanence-package.schema.json",
        '{"schema_version":"test"}\n',
        category="permanence_schema",
    )
    retained_ref = file_ref(
        root,
        "release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md",
        "# retained\n",
        category="permanence_retained_artifact_template",
    )
    runbook_ref = file_ref(
        root,
        "docs/permanence-packages.md",
        "# Permanence\n",
        category="permanence_runbook",
    )
    renderer_source_ref = file_ref(
        root,
        "smart-contracts/StreamMetadataRenderer.sol",
        "library StreamMetadataRenderer {}\n",
        category="renderer_source",
    )
    dependency_binding = seed_binding_files(root)["dependency"]
    provenance_binding = binding_file(
        root,
        "release-artifacts/latest/one-of-one-provenance-manifest.json",
        '{"schema_version":"6529stream.one-of-one-provenance-release-manifest.v1"}\n',
    )
    dependency_ref = {**dependency_binding, "category": "dependency_artifact_manifest"}
    provenance_ref = {**provenance_binding, "category": "provenance_manifest"}
    source_ref = file_ref(
        root,
        "src/archive/source.txt",
        "source archive input\n",
        category="source_archive_file",
    )

    template = review_status == "template"
    record_type = "template" if template else "evidence"
    approval_status = "template" if template else "approved"
    reviewed_at = checker.LOCAL_PLACEHOLDER_STATUS if template else "2026-06-15T00:00:00Z"
    placeholder = checker.LOCAL_PLACEHOLDER_STATUS

    return {
        "schema_version": checker.PERMANENCE_SCHEMA,
        "package_id": "test-1-of-1-permanence",
        "record_type": record_type,
        "review_status": review_status,
        "environment": "local" if template else "testnet",
        "protocol_version": "0.1.0",
        "deployment_version": "testnet-001",
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "1" * 40,
            "source_dirty": False,
            "ci_run": "local",
        },
        "scope": {
            "scope_type": "one_of_one_token",
            "chain_id": 11155111,
            "core_contract": "0x0000000000000000000000000000000000000003",
            "contract_metadata_adapter": "0x000000000000000000000000000000000000000a",
            "collection_id": 1,
            "token_id": 1,
            "token_standard": "ERC721",
            "metadata_schema_version": "6529stream-v1",
            "contract_uri_hash": "0x" + "2" * 64,
            "collection_freeze_manifest_hash": "0x" + "3" * 64,
        },
        "renderer": {
            "renderer_name": "StreamMetadataRenderer",
            "renderer_version": "0.1.0",
            "renderer_contract": "0x000000000000000000000000000000000000000b",
            "renderer_source": renderer_source_ref,
            "rendering_mode": "animation_html",
            "runtime_assumptions": {
                "browser": "Chromium pinned by requirements-tools.txt",
                "node": "not required",
                "python": "3.x",
                "foundry": "v1.7.1",
                "notes": "No network secrets required.",
            },
        },
        "dependencies": {
            "dependency_artifact_manifest": dependency_ref,
            "dependency_registry": "0x0000000000000000000000000000000000000004",
            "dependency_count": 1,
            "dependency_records": [
                {
                    "dependency_key": "p5js",
                    "version": 1,
                    "content_sha256": placeholder if template else "sha256:" + "4" * 64,
                    "provenance_sha256": placeholder if template else "sha256:" + "5" * 64,
                    "source_status": "template" if template else "reviewed",
                }
            ],
        },
        "source_archive": {
            "archive_status": "template" if template else "reviewed",
            "repository_archive_uri": placeholder if template else "ipfs://source-archive",
            "archive_sha256": placeholder if template else "sha256:" + "6" * 64,
            "included_files": [source_ref],
        },
        "replay": {
            "deterministic_replay_status": "template" if template else "reviewed_replayable",
            "replay_requires_network": False,
            "replay_commands": [
                {
                    "command": "python scripts/check_metadata_browser_sandbox.py",
                    "purpose": "Replay retained metadata/browser fixture.",
                    "working_directory": ".",
                }
            ],
            "expected_replay_outputs": [
                "metadata JSON digest",
                "animation HTML digest",
                "browser proof digest",
            ],
        },
        "output_evidence": {
            "metadata_json_sha256": placeholder if template else "sha256:" + "7" * 64,
            "animation_html_sha256": placeholder if template else "sha256:" + "8" * 64,
            "image_sha256": placeholder if template else "sha256:" + "9" * 64,
            "rendered_output_sha256": placeholder if template else "sha256:" + "a" * 64,
            "browser_proof_sha256": placeholder if template else "sha256:" + "b" * 64,
            "browser_proof_status": "template" if template else "reviewed",
            "output_hash_status": "template" if template else "reviewed",
        },
        "storage_guarantees": {
            "fully_on_chain_components": ["token data", "dependency references"],
            "decentralized_storage_components": ["source archive", "browser proof"],
            "external_service_dependencies": ["gateway availability"],
            "gateway_assumptions": ["ipfs gateway availability"],
            "permanence_summary": (
                "Fully on-chain inputs are separated from decentralized storage "
                "artifacts and gateway assumptions."
            ),
            "known_failure_modes": ["gateway outage"],
        },
        "release_bindings": {
            "release_manifest": {
                "path": "release-artifacts/latest/release-manifest.json",
                "sha256": checker.SELF_REFERENTIAL_STATUS,
                "status": "self_referential",
            },
            "release_checksums": {
                "path": "release-artifacts/latest/SHA256SUMS",
                "sha256": checker.SELF_REFERENTIAL_STATUS,
                "status": "self_referential",
            },
            "dependency_artifact_manifest": {
                **dependency_binding,
                "status": "template" if template else "reviewed",
            },
            "one_of_one_provenance_manifest": {
                **provenance_binding,
                "status": "template" if template else "reviewed",
            },
        },
        "integration_guidance": {
            "collector_verification": "Verify retained hashes before display.",
            "frontend_replay": "Use sandboxed replay only.",
            "indexer_binding": "Index from release artifacts.",
            "marketplace_boundary": "Not marketplace acceptance evidence.",
        },
        "review": {
            "owner": "TBD" if template else "release-owner",
            "reviewer": "TBD" if template else "release-reviewer",
            "approval_status": approval_status,
            "approval_reference": "TBD" if template else "review-ticket",
            "reviewed_at": reviewed_at,
        },
        "retained_artifacts": [
            schema_ref,
            retained_ref,
            runbook_ref,
            dependency_ref,
            provenance_ref,
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
        "operator_notes": "No-secret fixture.",
    }


def seed_descriptor_tree(root: Path) -> tuple[Path, Path]:
    """Create a valid descriptor tree and output path."""
    descriptor_dir = root / "release-artifacts/permanence"
    output = root / "release-artifacts/latest/one-of-one-permanence-manifest.json"
    write_json(
        descriptor_dir / "test-1-of-1.permanence.json",
        valid_package(root),
    )
    return descriptor_dir, output


class OneOfOnePermanencePackageTests(unittest.TestCase):
    def test_accepts_committed_template(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(REPO_ROOT), COMMITTED_TEMPLATE])

        self.assertEqual(result, 0)

    def test_accepts_reviewed_evidence(self) -> None:
        """Reviewed non-local permanence evidence can pass the model."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "release-artifacts/permanence/reviewed.permanence.json"
            write_json(path, valid_package(root))

            checker.validate_package(path, root)

    def test_generator_writes_deterministic_manifest(self) -> None:
        """The generated aggregate is deterministic and summarizes descriptors."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_descriptor_tree(root)

            written = generator.write_output(root, descriptor_dir, output)
            first = written.read_text(encoding="utf-8")
            generator.write_output(root, descriptor_dir, output)
            self.assertEqual(first, written.read_text(encoding="utf-8"))

            manifest = json.loads(first)
            self.assertEqual(
                manifest["schema_version"],
                generator.PERMANENCE_RELEASE_MANIFEST_SCHEMA,
            )
            self.assertEqual(manifest["source"]["descriptor_count"], 1)
            record = manifest["packages"][0]
            self.assertEqual(record["package_id"], "test-1-of-1-permanence")
            self.assertEqual(record["scope"]["collection_id"], 1)
            self.assertEqual(
                record["replay"]["deterministic_replay_status"], "reviewed_replayable"
            )

    def test_check_mode_accepts_current_manifest(self) -> None:
        """Check mode accepts a current generated manifest."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_descriptor_tree(root)
            generator.write_output(root, descriptor_dir, output)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_output(root, descriptor_dir, output)

            self.assertEqual(result, 0)

    def test_check_mode_rejects_output_drift(self) -> None:
        """Check mode rejects stale generated output."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_descriptor_tree(root)
            generator.write_output(root, descriptor_dir, output)
            data = valid_package(root)
            data["renderer"]["renderer_version"] = "changed"
            write_json(descriptor_dir / "test-1-of-1.permanence.json", data)

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(root, descriptor_dir, output)

            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/one-of-one-permanence-manifest.json",
                stderr.getvalue(),
            )

    def test_rejects_reviewed_placeholder_output_hash(self) -> None:
        """Reviewed evidence cannot leave output hashes as placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_package(root)
            data["output_evidence"]["browser_proof_sha256"] = (
                checker.LOCAL_PLACEHOLDER_STATUS
            )
            path = root / "release-artifacts/permanence/reviewed.permanence.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.PermanencePackageError, "browser_proof_sha256"
            ):
                checker.validate_package(path, root)

    def test_rejects_zero_freeze_hash_for_reviewed_evidence(self) -> None:
        """Reviewed permanence packages must bind to a nonzero freeze hash."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_package(root)
            data["scope"]["collection_freeze_manifest_hash"] = "0x" + "0" * 64
            path = root / "release-artifacts/permanence/reviewed.permanence.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.PermanencePackageError, "collection_freeze_manifest_hash"
            ):
                checker.validate_package(path, root)

    def test_rejects_stale_retained_hash(self) -> None:
        """Retained artifact hashes must match file contents."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_package(root)
            data["retained_artifacts"][0]["sha256"] = "sha256:" + "0" * 64
            path = root / "release-artifacts/permanence/reviewed.permanence.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.PermanencePackageError, "sha256 mismatch"
            ):
                checker.validate_package(path, root)

    def test_rejects_path_escape(self) -> None:
        """Retained artifacts cannot escape the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_package(root)
            data["retained_artifacts"][0]["path"] = "../outside.md"
            path = root / "release-artifacts/permanence/reviewed.permanence.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.PermanencePackageError, "stay inside"
            ):
                checker.validate_package(path, root)

    def test_rejects_secret_like_value(self) -> None:
        """Secret-shaped values cannot be committed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_package(root)
            data["operator_notes"] = "api_key=do-not-commit"
            path = root / "release-artifacts/permanence/reviewed.permanence.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.PermanencePackageError, "secret-like"
            ):
                checker.validate_package(path, root)

    def test_rejects_duplicate_descriptor_identity(self) -> None:
        """The generated aggregate rejects duplicated package identities."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_descriptor_tree(root)
            write_json(
                descriptor_dir / "copy.permanence.json",
                valid_package(root),
            )

            with self.assertRaisesRegex(
                generator.PermanenceReleaseManifestError,
                "duplicate permanence package identity",
            ):
                generator.build_output_text(root, descriptor_dir, output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
