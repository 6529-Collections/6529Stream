#!/usr/bin/env python3
"""Focused tests for public-beta evidence validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_public_beta_evidence.py")
SPEC = importlib.util.spec_from_file_location("check_public_beta_evidence", SCRIPT_PATH)
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


def file_ref(root: Path, relative_path: str, content: str = "evidence\n") -> dict[str, str]:
    """Create a file and return its evidence reference."""
    path = root / relative_path
    write_text(path, content)
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def requirement(
    requirement_id: str,
    phase: str,
    status: str = "missing",
    *,
    evidence: list[dict[str, str]] | None = None,
    risk_acceptance: dict[str, str] | None = None,
) -> dict[str, object]:
    """Build one requirement row."""
    return {
        "id": requirement_id,
        "phase": phase,
        "status": status,
        "owner": "TBD",
        "evidence": [] if evidence is None else evidence,
        "risk_acceptance": risk_acceptance,
        "notes": f"{requirement_id} remains {status}.",
    }


def risk_acceptance() -> dict[str, str]:
    """Return complete risk-acceptance metadata."""
    return {
        "accepted_by": "protocol-owner",
        "accepted_at": "2026-06-12",
        "expires_at": "2026-07-12",
        "reference": "docs/release-policy.md#risk-acceptance",
        "notes": "Accepted only for test fixture coverage.",
    }


def valid_evidence(root: Path) -> dict[str, object]:
    """Build a conservative blocked evidence document."""
    schema_ref = {
        **file_ref(root, "release-artifacts/schema/public-beta-evidence.schema.json"),
        "category": "public_beta_evidence_schema",
    }
    requirements: list[dict[str, object]] = []
    for requirement_id in checker.PUBLIC_BETA_REQUIREMENTS:
        requirements.append(requirement(requirement_id, checker.PUBLIC_BETA_PHASE))
    for requirement_id in checker.PRODUCTION_REQUIREMENTS:
        requirements.append(requirement(requirement_id, checker.PRODUCTION_PHASE))

    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "release_version": "v0.1.0-local",
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "0" * 40,
            "source_dirty": False,
            "ci_run": "local",
        },
        "status": {
            "public_beta": "blocked",
            "production_release": "blocked",
        },
        "requirements": requirements,
        "retained_artifacts": [schema_ref],
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
        "operator_notes": "Public beta and production release remain blocked.",
    }


class PublicBetaEvidenceTests(unittest.TestCase):
    """Checker behavior for public-beta evidence manifests."""

    def test_accepts_committed_evidence(self) -> None:
        """The committed evidence status satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_blocked_status(self) -> None:
        """A complete blocked status file is valid."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, valid_evidence(root))

            checker.validate_evidence(path, root)

    def test_accepts_custom_evidence_path(self) -> None:
        """The CLI accepts a non-default evidence path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            custom_path = Path("custom/public-beta-evidence.json")
            write_json(root / custom_path, valid_evidence(root))

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    ["--repo-root", str(root), "--evidence", str(custom_path)]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_required_requirement(self) -> None:
        """All required public-beta and production rows must be present."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"] = evidence["requirements"][1:]
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.PublicBetaEvidenceError, "missing public_beta requirement"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_duplicate_requirement(self) -> None:
        """Requirement IDs cannot appear twice in the same phase."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"].append(evidence["requirements"][0])
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.PublicBetaEvidenceError, "duplicate"):
                checker.validate_evidence(path, root)

    def test_rejects_complete_requirement_without_evidence(self) -> None:
        """A complete row must point to retained evidence files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"][0]["status"] = "complete"
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.PublicBetaEvidenceError, "must not be empty"
            ):
                checker.validate_evidence(path, root)

    def test_accepts_accepted_risk_with_metadata(self) -> None:
        """Risk-accepted rows require complete acceptance metadata."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"][0] = requirement(
                checker.PUBLIC_BETA_REQUIREMENTS[0],
                checker.PUBLIC_BETA_PHASE,
                "accepted_risk",
                risk_acceptance=risk_acceptance(),
            )
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            checker.validate_evidence(path, root)

    def test_rejects_accepted_risk_without_metadata(self) -> None:
        """Accepted-risk rows cannot omit owner/date/reference metadata."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"][0]["status"] = "accepted_risk"
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.PublicBetaEvidenceError, "risk_acceptance must be an object"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_ready_status_with_blockers(self) -> None:
        """Overall ready status is rejected while blockers remain."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["status"]["public_beta"] = "ready"
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.PublicBetaEvidenceError, "cannot be ready"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_stale_file_hash(self) -> None:
        """Evidence file hashes must match committed content."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            write_text(
                root / "release-artifacts/schema/public-beta-evidence.schema.json",
                "changed\n",
            )
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.PublicBetaEvidenceError, "sha256 mismatch"):
                checker.validate_evidence(path, root)

    def test_rejects_path_escape(self) -> None:
        """Evidence paths must stay inside the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"][0]["status"] = "complete"
            evidence["requirements"][0]["evidence"] = [
                {"path": "../outside.txt", "sha256": "sha256:" + "0" * 64}
            ]
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.PublicBetaEvidenceError, "stay inside the repository"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_secret_like_value(self) -> None:
        """Secret-shaped values cannot be committed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operator_notes"] = "api_key=do-not-commit"
            path = root / checker.DEFAULT_EVIDENCE
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.PublicBetaEvidenceError, "secret-like"):
                checker.validate_evidence(path, root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
