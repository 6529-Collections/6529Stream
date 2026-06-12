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


class NonLocalReleaseEvidenceTests(unittest.TestCase):
    """Checker behavior for non-local release evidence metadata."""

    def test_accepts_committed_template(self) -> None:
        """The committed template satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

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
