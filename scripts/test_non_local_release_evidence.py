#!/usr/bin/env python3
"""Focused tests for non-local release evidence metadata validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_non_local_release_evidence.py")
SPEC = importlib.util.spec_from_file_location("check_non_local_release_evidence", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def seed_retained_artifact(root: Path, relative_path: str = "evidence/log.txt") -> dict[str, str]:
    """Create a retained artifact and return its path/hash pair."""
    path = root / relative_path
    write_text(path, "sanitized evidence\n")
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def valid_evidence(root: Path, *, record_type: str = "evidence") -> dict[str, object]:
    """Build valid evidence metadata."""
    retained = seed_retained_artifact(root)
    review_status = "reviewed" if record_type == "evidence" else "template"
    reviewer = "release-reviewer" if record_type == "evidence" else "TBD"
    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "evidence_id": "test-non-local-evidence",
        "record_type": record_type,
        "review_status": review_status,
        "environment": "testnet",
        "chain_id": 11155111,
        "block_or_reference": "block 123456",
        "command_or_source_system": "operator transcript",
        "retained_path": retained["path"],
        "sha256": retained["sha256"],
        "redaction_statement": "Secrets were never present.",
        "owner": "release-operator",
        "reviewer": reviewer,
        "public_beta_requirement_id": "testnet_deployment_rehearsal",
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "0" * 40,
            "source_dirty": False,
            "ci_run": "local",
        },
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": [
                "private_key",
                "mnemonic",
                "seed_phrase",
                "api_key",
                "rpc_url",
                "unreleased_drop_payload",
            ],
        },
        "template_notice": "Template only. This file is not completion evidence.",
        "operator_notes": "No-secret test fixture.",
    }


def valid_public_beta_template(root: Path, requirement_id: str) -> dict[str, object]:
    """Build a valid public-beta requirement template."""
    retained = seed_retained_artifact(
        root,
        "release-artifacts/evidence/public-beta-templates/retained-artifact.txt",
    )
    evidence = valid_evidence(root, record_type="template")
    evidence.update(
        {
            "evidence_id": f"public-beta-template-{requirement_id}",
            "public_beta_requirement_id": requirement_id,
            "retained_path": retained["path"],
            "sha256": retained["sha256"],
            "block_or_reference": "template-only reference",
            "command_or_source_system": "template-only source",
            "operator_notes": f"Template for {requirement_id}.",
        }
    )
    return evidence


class NonLocalReleaseEvidenceTests(unittest.TestCase):
    """Checker behavior for non-local release evidence metadata."""

    def test_accepts_committed_template(self) -> None:
        """The committed template satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_committed_public_beta_templates_cover_required_ids(self) -> None:
        """Default templates cover each public-beta requirement exactly once."""
        repo_root = Path(__file__).resolve().parents[1]

        paths = checker.public_beta_template_paths(repo_root)
        requirements = {}
        for path in paths:
            data = checker.load_json(path)
            requirements[data["public_beta_requirement_id"]] = data
            self.assertEqual(data["record_type"], "template")
            self.assertEqual(data["review_status"], "template")

        self.assertEqual(
            set(requirements),
            set(checker.PUBLIC_BETA_TEMPLATE_REQUIREMENTS),
        )
        checker.validate_public_beta_template_set(repo_root)

    def test_rejects_missing_public_beta_template(self) -> None:
        """The template set must include every public-beta requirement."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template_dir = root / checker.PUBLIC_BETA_TEMPLATE_DIR
            template_dir.mkdir(parents=True)
            write_json(
                template_dir / "only-one.json",
                valid_public_beta_template(
                    root, sorted(checker.PUBLIC_BETA_TEMPLATE_REQUIREMENTS)[0]
                ),
            )

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError,
                "missing public-beta template",
            ):
                checker.validate_public_beta_template_set(root)

    def test_rejects_duplicate_public_beta_template(self) -> None:
        """The template set cannot map two files to the same requirement."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template_dir = root / checker.PUBLIC_BETA_TEMPLATE_DIR
            template_dir.mkdir(parents=True)
            requirement_id = sorted(checker.PUBLIC_BETA_TEMPLATE_REQUIREMENTS)[0]
            write_json(
                template_dir / "first.json",
                valid_public_beta_template(root, requirement_id),
            )
            write_json(
                template_dir / "second.json",
                valid_public_beta_template(root, requirement_id),
            )

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError,
                "duplicate public-beta template",
            ):
                checker.validate_public_beta_template_set(root)

    def test_rejects_production_requirement_in_public_beta_template_set(self) -> None:
        """Production-only rows do not satisfy public-beta template coverage."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            template_dir = root / checker.PUBLIC_BETA_TEMPLATE_DIR
            template_dir.mkdir(parents=True)
            write_json(
                template_dir / "production.json",
                valid_public_beta_template(root, "production_signatures"),
            )

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError,
                "non-public-beta requirement",
            ):
                checker.validate_public_beta_template_set(root)

    def test_accepts_reviewed_evidence(self) -> None:
        """Reviewed non-local evidence accepts a real reviewer."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, valid_evidence(root))

            checker.validate_evidence(path, root)

    def test_accepts_template_with_tbd_reviewer(self) -> None:
        """Templates can carry TBD owner/reviewer placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "release-artifacts/evidence/template.json"
            write_json(path, valid_evidence(root, record_type="template"))

            checker.validate_evidence(path, root)

    def test_rejects_reviewed_tbd_reviewer(self) -> None:
        """Reviewed evidence needs a named reviewer."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["reviewer"] = " TBD "
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError, "reviewer must be set"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_unknown_requirement_id(self) -> None:
        """Requirement IDs must match the public-beta evidence manifest."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["public_beta_requirement_id"] = "unknown_requirement"
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError, "not recognized"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_unsupported_environment(self) -> None:
        """Only runbook environments are accepted."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["environment"] = "local"
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError, "environment must be one of"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_boolean_chain_id_for_chainless_environment(self) -> None:
        """Audit and signing evidence cannot use booleans as chain IDs."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["environment"] = "audit"
            evidence["chain_id"] = True
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError, "chain_id must be a number"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_missing_retained_file(self) -> None:
        """The retained_path must point to a committed file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_path"] = "missing.txt"
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError, "references missing file"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_stale_hash(self) -> None:
        """The retained artifact hash must match file content."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["sha256"] = "sha256:" + "0" * 64
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.NonLocalReleaseEvidenceError, "mismatch"):
                checker.validate_evidence(path, root)

    def test_rejects_path_escape(self) -> None:
        """Retained paths must stay inside the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_path"] = "../outside.txt"
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError, "stay inside"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_secret_like_value(self) -> None:
        """Secret-shaped values cannot be committed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operator_notes"] = "api_key=do-not-commit"
            path = root / "release-artifacts/evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.NonLocalReleaseEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_secret_like_key(self) -> None:
        """Secret-shaped keys cannot be committed."""
        with self.assertRaisesRegex(checker.NonLocalReleaseEvidenceError, "secret-like key"):
            checker.scan_for_secret_like_data({"client_secret": "do-not-commit"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
