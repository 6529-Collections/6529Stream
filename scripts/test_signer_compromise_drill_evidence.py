#!/usr/bin/env python3
"""Focused tests for signer-compromise drill evidence validation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_signer_compromise_drill_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_signer_compromise_drill_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def template_text() -> str:
    return Path(
        "release-artifacts/evidence/incident-drills/"
        "signer-compromise-drill-retained-artifact-template.md"
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
        "Drill bundle reference: `TBD`": "Drill bundle reference: `incident-drills/signer-compromise-sepolia-001.md`",
        "Affected signer: `TBD`": "Affected signer: `0x0000000000000000000000000000000000001001`",
        "Replacement signer: `TBD`": "Replacement signer: `0x0000000000000000000000000000000000001002`",
        "Signer manager: `TBD`": "Signer manager: `0x0000000000000000000000000000000000001003`",
        "Starting signer epoch: `TBD`": "Starting signer epoch: `1`",
        "Ending signer epoch: `TBD`": "Ending signer epoch: `2`",
        "Affected drop IDs: `TBD`": "Affected drop IDs: `0x1111111111111111111111111111111111111111111111111111111111111111,0x2222222222222222222222222222222222222222222222222222222222222222`",
        "Affected EIP-712 domain: `TBD`": "Affected EIP-712 domain: `chain=11155111 verifyingContract=0x0000000000000000000000000000000000002001`",
        "Drop execution pause evidence: `TBD`": "Drop execution pause evidence: `pause tx and isPaused read retained`",
        "Signer rotation evidence: `TBD`": "Signer rotation evidence: `DropSignerChanged event retained`",
        "Signer revocation evidence: `TBD`": "Signer revocation evidence: `old signer removed from ceremony outputs`",
        "Signer epoch invalidation evidence: `TBD`": "Signer epoch invalidation evidence: `SignerEpochChanged event retained`",
        "Per-drop cancellation evidence: `TBD`": "Per-drop cancellation evidence: `DropAuthorizationCancelled events retained`",
        "Withdrawal availability evidence: `TBD`": "Withdrawal availability evidence: `credit withdrawal smoke retained`",
        "Stale payload rejection evidence: `TBD`": "Stale payload rejection evidence: `Bad epoch revert retained`",
        "Cancelled payload rejection evidence: `TBD`": "Cancelled payload rejection evidence: `Drop cancelled revert retained`",
        "Wrong-domain rejection evidence: `TBD`": "Wrong-domain rejection evidence: `wrong domain signature failure retained`",
        "Recovered fixed-price payload evidence: `TBD`": "Recovered fixed-price payload evidence: `new signer fixed-price mint retained`",
        "Recovered auction payload evidence: `TBD`": "Recovered auction payload evidence: `new signer auction creation retained`",
        "Post-recovery signer state evidence: `TBD`": "Post-recovery signer state evidence: `signer and epoch reads retained`",
        "Operator dashboard confirmation: `TBD`": "Operator dashboard confirmation: `dashboard panel screenshot hash retained`",
        "Monitoring alert reference: `TBD`": "Monitoring alert reference: `alert SIM-SIGNER-001 retained`",
        "Incident response decision log: `TBD`": "Incident response decision log: `decision-log.md`",
        "Public communication status: `TBD`": "Public communication status: `no public user impact`",
        "Follow-up issue links: `TBD`": "Follow-up issue links: `https://github.com/6529-Collections/6529Stream/issues/510`",
        "Command transcript bundle: `TBD`": "Command transcript bundle: `commands.md`",
        "Event or state snapshot bundle: `TBD`": "Event or state snapshot bundle: `snapshots.md`",
        "Signer custody readiness evidence: `TBD`": "Signer custody readiness evidence: `signer-custody-readiness.json`",
        "Drop authorization signing evidence: `TBD`": "Drop authorization signing evidence: `drop-authorization-signing.json`",
        "Admin ceremony evidence: `TBD`": "Admin ceremony evidence: `admin-ceremony.json`",
        "Release manifest/checksum digests: `TBD`": "Release manifest/checksum digests: `sha256 bundle retained`",
        "Operator: `TBD`": "Operator: `ops`",
        "Reviewer: `TBD`": "Reviewer: `reviewer`",
        "Review decision: `template`": "Review decision: `reviewed`",
        "No secrets retained: `TBD`": "No secrets retained: `yes`",
        "Private RPC URLs removed: `TBD`": "Private RPC URLs removed: `yes`",
        "Private keys removed: `TBD`": "Private keys removed: `yes`",
        "Signer-service secrets removed: `TBD`": "Signer-service secrets removed: `yes`",
        "Raw signatures removed: `TBD`": "Raw signatures removed: `yes`",
        "Unreleased drop payloads removed: `TBD`": "Unreleased drop payloads removed: `yes`",
        "Private collector data removed: `TBD`": "Private collector data removed: `yes`",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


class SignerCompromiseDrillEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        for path in checker.DEFAULT_EVIDENCE:
            checker.validate_evidence(path)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(path, reviewed_text())

            checker.validate_evidence(path)

    def test_wrong_requirement_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    checker.REQUIREMENT_ID, "incident_drill_evidence", 1
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "Requirement ID"
            ):
                checker.validate_evidence(path)

    def test_reviewed_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Incident response decision log: `decision-log.md`",
                    "Incident response decision log: `TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "must be replaced"
            ):
                checker.validate_evidence(path)

    def test_pending_review_complete_readiness_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            text = reviewed_text().replace(
                "Review status: `reviewed`", "Review status: `pending_review`"
            )
            text = text.replace(
                "Review decision: `reviewed`", "Review decision: `pending_review`"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "Readiness claim"
            ):
                checker.validate_evidence(path)

    def test_reviewed_template_environment_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace("Environment: `testnet`", "Environment: `template`"),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "reviewed evidence must use"
            ):
                checker.validate_evidence(path)

    def test_reviewed_bad_chain_id_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace("Chain ID: `11155111`", "Chain ID: `sepolia`"),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "Chain ID must be a uint"
            ):
                checker.validate_evidence(path)

    def test_affected_drop_ids_must_be_bytes32(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    (
                        "Affected drop IDs: "
                        "`0x1111111111111111111111111111111111111111111111111111111111111111,"
                        "0x2222222222222222222222222222222222222222222222222222222222222222`"
                    ),
                    "Affected drop IDs: `0x1234`",
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "Affected drop IDs"
            ):
                checker.validate_evidence(path)

    def test_domain_chain_must_match_chain_id(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Affected EIP-712 domain: `chain=11155111",
                    "Affected EIP-712 domain: `chain=1",
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "domain chain"
            ):
                checker.validate_evidence(path)

    def test_domain_requires_verifying_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    " verifyingContract=0x0000000000000000000000000000000000002001",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "verifyingContract"
            ):
                checker.validate_evidence(path)

    def test_replacement_signer_must_change(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Replacement signer: `0x0000000000000000000000000000000000001002`",
                    "Replacement signer: `0x0000000000000000000000000000000000001001`",
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "replacement signer"
            ):
                checker.validate_evidence(path)

    def test_ending_epoch_must_increase(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace("Ending signer epoch: `2`", "Ending signer epoch: `1`"),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "Ending signer epoch"
            ):
                checker.validate_evidence(path)

    def test_reviewed_redaction_no_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Raw signatures removed: `yes`", "Raw signatures removed: `no`"
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "Raw signatures removed"
            ):
                checker.validate_evidence(path)

    def test_missing_validation_command_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    "python scripts/check_release_readiness.py", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError,
                "missing required validation command",
            ):
                checker.validate_evidence(path)

    def test_secret_like_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Command transcript bundle: `commands.md`",
                    "Command transcript bundle: `api_key=do-not-commit`",
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path)

    def test_credentialed_urls_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Operator dashboard confirmation: `dashboard panel screenshot hash retained`",
                    "Operator dashboard confirmation: `https://operator:password@example.invalid/panel`",
                ),
            )

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "credentialed URL"
            ):
                checker.validate_evidence(path)

    def test_redacted_urls_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "signer-compromise.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Operator dashboard confirmation: `dashboard panel screenshot hash retained`",
                    "Operator dashboard confirmation: `https://<redacted>@example.invalid/panel`",
                ),
            )

            checker.validate_evidence(path)

    def test_source_requirement_missing_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "signer-compromise.md"
            write_text(path, reviewed_text())
            for source_path, snippets in checker.SOURCE_REQUIREMENTS.items():
                body = "\n".join(snippets)
                if source_path.as_posix().endswith("StreamDrops.sol"):
                    body = body.replace("function cancelDrop", "")
                write_text(root / source_path, body)

            with self.assertRaisesRegex(
                checker.SignerCompromiseDrillEvidenceError, "source snippet"
            ):
                checker.validate_evidence(path, repo_root=root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
