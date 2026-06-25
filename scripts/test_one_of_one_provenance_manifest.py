#!/usr/bin/env python3
"""Focused tests for 1/1 provenance manifest validation and generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


CHECKER_PATH = Path(__file__).with_name("check_one_of_one_provenance_manifest.py")
CHECKER_SPEC = importlib.util.spec_from_file_location(
    "check_one_of_one_provenance_manifest", CHECKER_PATH
)
assert CHECKER_SPEC is not None and CHECKER_SPEC.loader is not None
checker = importlib.util.module_from_spec(CHECKER_SPEC)
CHECKER_SPEC.loader.exec_module(checker)

GENERATOR_PATH = Path(__file__).with_name("generate_one_of_one_provenance_manifest.py")
GENERATOR_SPEC = importlib.util.spec_from_file_location(
    "generate_one_of_one_provenance_manifest", GENERATOR_PATH
)
assert GENERATOR_SPEC is not None and GENERATOR_SPEC.loader is not None
generator = importlib.util.module_from_spec(GENERATOR_SPEC)
GENERATOR_SPEC.loader.exec_module(generator)

REPO_ROOT = Path(__file__).resolve().parents[1]
COMMITTED_TEMPLATE = (
    "release-artifacts/provenance/one-of-one-provenance-template.provenance.json"
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


def file_ref(root: Path, relative_path: str, content: str) -> dict[str, str]:
    """Create or hash a retained file reference."""
    path = root / relative_path
    write_text(path, content)
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def seed_binding_files(root: Path) -> tuple[dict[str, str], dict[str, str]]:
    """Create release/deployment binding files used by fixtures."""
    write_text(root / "release-artifacts/latest/release-manifest.json", "{}\n")
    write_text(root / "release-artifacts/latest/SHA256SUMS", "placeholder\n")
    deployment_ref = file_ref(
        root,
        "deployments/examples/testnet-001.json",
        '{"schema_version":"6529stream.deployment-manifest.v1"}\n',
    )
    address_ref = file_ref(
        root,
        "deployments/address-books/testnet-001.json",
        '{"schema_version":"6529stream.address-book.v1"}\n',
    )
    return deployment_ref, address_ref


def valid_manifest(root: Path, *, review_status: str = "reviewed") -> dict[str, object]:
    """Build a valid provenance manifest fixture."""
    schema_ref = file_ref(
        root,
        "release-artifacts/schema/one-of-one-provenance-manifest.schema.json",
        '{"schema_version":"test"}\n',
    )
    retained_ref = file_ref(
        root,
        "release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md",
        "# retained\n",
    )
    runbook_ref = file_ref(root, "docs/provenance-manifests.md", "# Provenance\n")
    deployment_ref, address_ref = seed_binding_files(root)
    template = review_status == "template"
    record_type = "template" if template else "evidence"
    approval_status = "template" if template else "approved"
    authenticity_status = "template" if template else "reviewed"
    reviewed_at = checker.LOCAL_PLACEHOLDER_STATUS if template else "2026-06-15T00:00:00Z"

    return {
        "schema_version": checker.PROVENANCE_SCHEMA,
        "provenance_id": "test-1-of-1",
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
        "artwork": {
            "title": "Reviewed 1/1",
            "artist": "Test Artist",
            "artist_statement": "A reviewed statement.",
            "medium": "generative art",
            "creation_date": "2026-06-15",
            "image_uri": "ipfs://image-cid",
            "animation_uri": "ipfs://animation-cid",
        },
        "authenticity": {
            "authenticity_status": authenticity_status,
            "authority": "TBD" if template else "release-review",
            "authority_reference": "TBD" if template else "AUTH-001",
            "artist_statement_sha256": checker.LOCAL_PLACEHOLDER_STATUS
            if template
            else "sha256:" + "4" * 64,
            "artwork_content_sha256": checker.LOCAL_PLACEHOLDER_STATUS
            if template
            else "sha256:" + "5" * 64,
            "certificate_sha256": checker.LOCAL_PLACEHOLDER_STATUS
            if template
            else "sha256:" + "6" * 64,
        },
        "provenance_entries": [
            {
                "entry_id": "creation",
                "entry_type": "creation",
                "occurred_at": "2026-06-15T00:00:00Z",
                "title": "Creation",
                "description": "Creation evidence retained.",
                "evidence_refs": [
                    {
                        "label": "artwork media package",
                        "uri": "ipfs://media-package",
                        "sha256": checker.LOCAL_PLACEHOLDER_STATUS
                        if template
                        else "sha256:" + "7" * 64,
                        "notes": "Reviewed media hash.",
                    }
                ],
            },
            {
                "entry_id": "release-binding",
                "entry_type": "release_binding",
                "occurred_at": "2026-06-15T00:00:00Z",
                "title": "Release binding",
                "description": "Release artifact binding retained.",
                "evidence_refs": [
                    {
                        "label": "release artifact catalog",
                        "uri": "ipfs://release-evidence",
                        "sha256": checker.LOCAL_PLACEHOLDER_STATUS
                        if template
                        else "sha256:" + "8" * 64,
                        "notes": "Reviewed release artifact hash.",
                    }
                ],
            },
        ],
        "mutability_policy": {
            "token_metadata_boundary": "separate_from_token_uri",
            "contract_metadata_boundary": "separate_from_contract_uri",
            "freeze_boundary": "not_in_collection_freeze_manifest",
            "provenance_update_policy": "append_only",
            "correction_policy": "append_only_with_supersedes",
            "authority_rotation_policy": checker.LOCAL_PLACEHOLDER_STATUS
            if template
            else "reviewed_release_ceremony",
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
            "deployment_manifest": {
                **deployment_ref,
                "status": "template" if template else "reviewed",
            },
            "address_book": {
                **address_ref,
                "status": "template" if template else "reviewed",
            },
            "contract_uri_hash_source": "adapter contractURIHash",
            "collection_freeze_manifest_hash_source": "core collectionFreezeManifestHash",
        },
        "integration_guidance": {
            "frontend_display": "Display as context only.",
            "indexer_source": "Index from release artifacts.",
            "marketplace_boundary": "Not marketplace evidence.",
            "ownership_boundary": "Ownership remains on-chain.",
        },
        "review": {
            "owner": "TBD" if template else "release-owner",
            "reviewer": "TBD" if template else "release-reviewer",
            "approval_status": approval_status,
            "approval_reference": "TBD" if template else "review-ticket",
            "reviewed_at": reviewed_at,
        },
        "retained_artifacts": [
            {**schema_ref, "category": "provenance_schema"},
            {**retained_ref, "category": "provenance_retained_artifact_template"},
            {**runbook_ref, "category": "provenance_runbook"},
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
    descriptor_dir = root / "release-artifacts/provenance"
    output = root / "release-artifacts/latest/one-of-one-provenance-manifest.json"
    write_json(
        descriptor_dir / "test-1-of-1.provenance.json",
        valid_manifest(root),
    )
    return descriptor_dir, output


class OneOfOneProvenanceManifestTests(unittest.TestCase):
    def test_accepts_committed_template(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(REPO_ROOT), COMMITTED_TEMPLATE])

        self.assertEqual(result, 0)

    def test_accepts_reviewed_evidence(self) -> None:
        """Reviewed non-local provenance evidence can pass the model."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "release-artifacts/provenance/reviewed.provenance.json"
            write_json(path, valid_manifest(root))

            checker.validate_manifest(path, root)

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
                generator.PROVENANCE_RELEASE_MANIFEST_SCHEMA,
            )
            self.assertEqual(manifest["source"]["descriptor_count"], 1)
            record = manifest["manifests"][0]
            self.assertEqual(record["provenance_id"], "test-1-of-1")
            self.assertEqual(record["scope"]["collection_id"], 1)

    def test_descriptor_file_record_uses_lf_normalized_text(self) -> None:
        """Descriptor file records are stable across CRLF and LF checkouts."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_descriptor_tree(root)
            descriptor = descriptor_dir / "test-1-of-1.provenance.json"

            lf_record = json.loads(
                generator.build_output_text(root, descriptor_dir, output)
            )["manifests"][0]["descriptor"]
            crlf_text = descriptor.read_text(encoding="utf-8").replace("\n", "\r\n")
            descriptor.write_text(crlf_text, encoding="utf-8", newline="")
            crlf_record = json.loads(
                generator.build_output_text(root, descriptor_dir, output)
            )["manifests"][0]["descriptor"]

            self.assertEqual(crlf_record, lf_record)

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
            data = valid_manifest(root)
            data["artwork"]["title"] = "Changed"
            write_json(descriptor_dir / "test-1-of-1.provenance.json", data)

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(root, descriptor_dir, output)

            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/one-of-one-provenance-manifest.json",
                stderr.getvalue(),
            )

    def test_rejects_missing_creation_entry(self) -> None:
        """A provenance manifest needs creation history."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_manifest(root)
            data["provenance_entries"] = [
                entry
                for entry in data["provenance_entries"]
                if entry["entry_type"] != "creation"
            ]
            path = root / "release-artifacts/provenance/reviewed.provenance.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.ProvenanceManifestError, "must include creation"
            ):
                checker.validate_manifest(path, root)

    def test_rejects_reviewed_placeholder_hash(self) -> None:
        """Reviewed evidence cannot leave authenticity hashes as placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_manifest(root)
            data["authenticity"]["certificate_sha256"] = checker.LOCAL_PLACEHOLDER_STATUS
            path = root / "release-artifacts/provenance/reviewed.provenance.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.ProvenanceManifestError, "certificate_sha256"
            ):
                checker.validate_manifest(path, root)

    def test_accepts_template_self_referential_release_catalog(self) -> None:
        """Template release-binding refs may point at their generated catalog."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_manifest(root, review_status="template")
            release_ref = data["provenance_entries"][1]["evidence_refs"][0]
            release_ref["uri"] = checker.SELF_REFERENTIAL_PROVENANCE_MANIFEST_URI
            release_ref["sha256"] = checker.SELF_REFERENTIAL_STATUS
            path = root / "release-artifacts/provenance/template.provenance.json"
            write_json(path, data)

            checker.validate_manifest(path, root)

    def test_rejects_reviewed_self_referential_release_catalog(self) -> None:
        """Reviewed provenance evidence refs need concrete retained hashes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_manifest(root)
            release_ref = data["provenance_entries"][1]["evidence_refs"][0]
            release_ref["uri"] = checker.SELF_REFERENTIAL_PROVENANCE_MANIFEST_URI
            release_ref["sha256"] = checker.SELF_REFERENTIAL_STATUS
            path = root / "release-artifacts/provenance/reviewed.provenance.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.ProvenanceManifestError, "reviewed provenance evidence refs"
            ):
                checker.validate_manifest(path, root)

    def test_rejects_stale_retained_hash(self) -> None:
        """Retained artifact hashes must match file contents."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_manifest(root)
            data["retained_artifacts"][0]["sha256"] = "sha256:" + "0" * 64
            path = root / "release-artifacts/provenance/reviewed.provenance.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.ProvenanceManifestError, "sha256 mismatch"
            ):
                checker.validate_manifest(path, root)

    def test_rejects_path_escape(self) -> None:
        """Retained artifacts cannot escape the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_manifest(root)
            data["retained_artifacts"][0]["path"] = "../outside.md"
            path = root / "release-artifacts/provenance/reviewed.provenance.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.ProvenanceManifestError, "stay inside"
            ):
                checker.validate_manifest(path, root)

    def test_rejects_secret_like_value(self) -> None:
        """Secret-shaped values cannot be committed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            data = valid_manifest(root)
            data["operator_notes"] = "api_key=do-not-commit"
            path = root / "release-artifacts/provenance/reviewed.provenance.json"
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.ProvenanceManifestError, "secret-like"
            ):
                checker.validate_manifest(path, root)

    def test_rejects_duplicate_descriptor_identity(self) -> None:
        """The generated aggregate rejects duplicated provenance identities."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            descriptor_dir, output = seed_descriptor_tree(root)
            write_json(
                descriptor_dir / "copy.provenance.json",
                valid_manifest(root),
            )

            with self.assertRaisesRegex(
                generator.ProvenanceReleaseManifestError,
                "duplicate provenance identity",
            ):
                generator.build_output_text(root, descriptor_dir, output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
