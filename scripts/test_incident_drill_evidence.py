#!/usr/bin/env python3
"""Focused tests for retained incident drill evidence validation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_incident_drill_evidence.py")
SPEC = importlib.util.spec_from_file_location("check_incident_drill_evidence", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def template_text() -> str:
    return Path(
        "release-artifacts/evidence/incident-drills/"
        "incident-drill-retained-artifact-template.md"
    ).read_text(encoding="utf-8")


def reviewed_text() -> str:
    text = template_text()
    replacements = {
        "> Template only. This file is not completion evidence.\n\n": "",
        "Review status: `template`": "Review status: `reviewed`",
        "Readiness claim: `blocked`": "Readiness claim: `complete`",
        "Environment: `template`": "Environment: `testnet`",
        "Chain ID: `TBD`": "Chain ID: `11155111`",
        "Release commit: `TBD`": "Release commit: `0123456789abcdef0123456789abcdef01234567`",
        "Deployment version: `TBD`": "Deployment version: `sepolia-001`",
        "Drill bundle reference: `TBD`": "Drill bundle reference: `incident-drills/sepolia-001.md`",
        "Incident decision log: `TBD`": "Incident decision log: `decision-log.md`",
        "Command transcript bundle: `TBD`": "Command transcript bundle: `commands.md`",
        "Event or state snapshot bundle: `TBD`": "Event or state snapshot bundle: `snapshots.md`",
        "Recovery evidence bundle: `TBD`": "Recovery evidence bundle: `recovery.md`",
        "Release manifest/checksum digests: `TBD`": "Release manifest/checksum digests: `sha256 bundle retained`",
        "Operator: `TBD`": "Operator: `ops`",
        "Reviewer: `TBD`": "Reviewer: `reviewer`",
        "Review decision: `template`": "Review decision: `reviewed`",
        "No secrets retained: `TBD`": "No secrets retained: `yes`",
        "Private RPC URLs removed: `TBD`": "Private RPC URLs removed: `yes`",
        "Private keys removed: `TBD`": "Private keys removed: `yes`",
        "Signer-service secrets removed: `TBD`": "Signer-service secrets removed: `yes`",
        "Provider dashboard secrets removed: `TBD`": "Provider dashboard secrets removed: `yes`",
        "Unreleased drop payloads removed: `TBD`": "Unreleased drop payloads removed: `yes`",
        "Private collector data removed: `TBD`": "Private collector data removed: `yes`",
    }
    for prefix in checker.DRILL_FIELD_PREFIXES:
        replacements[f"{prefix} command evidence: `TBD`"] = (
            f"{prefix} command evidence: `{prefix.lower()} command transcript`"
        )
        replacements[f"{prefix} affected controls: `TBD`"] = (
            f"{prefix} affected controls: `{prefix.lower()} controls snapshot`"
        )
        replacements[f"{prefix} observed events: `TBD`"] = (
            f"{prefix} observed events: `{prefix.lower()} event log`"
        )
        replacements[f"{prefix} rollback/recovery status: `TBD`"] = (
            f"{prefix} rollback/recovery status: `passed`"
        )
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


class IncidentDrillEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        for path in checker.DEFAULT_EVIDENCE:
            checker.validate_evidence(path)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(path, reviewed_text())

            checker.validate_evidence(path)

    def test_wrong_requirement_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace(
                    checker.REQUIREMENT_ID, "live_ceremony_evidence", 1
                ),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "Requirement ID"
            ):
                checker.validate_evidence(path)

    def test_missing_drill_coverage_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace(",signer_compromise", ""),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "missing required drill"
            ):
                checker.validate_evidence(path)

    def test_unknown_drill_coverage_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace(
                    "signer_compromise", "signer_compromise,unknown_drill", 1
                ),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "unknown drill"
            ):
                checker.validate_evidence(path)

    def test_reviewed_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Incident decision log: `decision-log.md`",
                    "Incident decision log: `TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "must be replaced"
            ):
                checker.validate_evidence(path)

    def test_reviewed_non_passed_recovery_status_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Failed randomness rollback/recovery status: `passed`",
                    "Failed randomness rollback/recovery status: `pending`",
                ),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "must be 'passed'"
            ):
                checker.validate_evidence(path)

    def test_reviewed_template_environment_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace("Environment: `testnet`", "Environment: `template`"),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "reviewed evidence must use"
            ):
                checker.validate_evidence(path)

    def test_reviewed_bad_chain_id_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace("Chain ID: `11155111`", "Chain ID: `sepolia`"),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "Chain ID must be a uint"
            ):
                checker.validate_evidence(path)

    def test_reviewed_redaction_no_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Private keys removed: `yes`", "Private keys removed: `no`"
                ),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "Private keys removed"
            ):
                checker.validate_evidence(path)

    def test_missing_validation_command_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace("python scripts/check_release_readiness.py", ""),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError,
                "missing required validation command",
            ):
                checker.validate_evidence(path)

    def test_secret_like_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Command transcript bundle: `commands.md`",
                    "Command transcript bundle: `api_key=do-not-commit`",
                ),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path)

    def test_credentialed_urls_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "incident-drill.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Recovery evidence bundle: `recovery.md`",
                    "Recovery evidence bundle: `https://user:pass@example.invalid/recovery`",
                ),
            )

            with self.assertRaisesRegex(
                checker.IncidentDrillEvidenceError, "credentialed URL"
            ):
                checker.validate_evidence(path)


if __name__ == "__main__":
    unittest.main()
