#!/usr/bin/env python3
"""Focused tests for failed-randomness drill evidence validation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_failed_randomness_drill_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_failed_randomness_drill_evidence", SCRIPT_PATH
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
        "failed-randomness-drill-retained-artifact-template.md"
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
        "Drill bundle reference: `TBD`": "Drill bundle reference: `incident-drills/failed-randomness-sepolia-001.md`",
        "Randomizer adapter: `TBD`": "Randomizer adapter: `0x0000000000000000000000000000000000004001`",
        "Randomizer provider type: `TBD`": "Randomizer provider type: `vrf`",
        "Request ID: `TBD`": "Request ID: `1`",
        "Provider request ID: `TBD`": "Provider request ID: `1`",
        "Token ID: `TBD`": "Token ID: `1001`",
        "Collection ID: `TBD`": "Collection ID: `42`",
        "Randomizer epoch: `TBD`": "Randomizer epoch: `2`",
        "Request path: `TBD`": "Request path: `post_processing_failed`",
        "Failure mode: `TBD`": "Failure mode: `metadata_write_failed`",
        "Starting request state: `TBD`": "Starting request state: `Pending`",
        "Ending request state: `TBD`": "Ending request state: `Fulfilled`",
        "Starting metadata state: `TBD`": "Starting metadata state: `pending`",
        "Ending metadata state: `TBD`": "Ending metadata state: `final`",
        "Pending-age evidence: `TBD`": "Pending-age evidence: `pending age retained`",
        "Invalid callback evidence: `TBD`": "Invalid callback evidence: `wrong request/token/collection/provider/epoch reverts retained`",
        "Provider epoch evidence: `TBD`": "Provider epoch evidence: `epoch read and event retained`",
        "Provider migration boundary evidence: `TBD`": "Provider migration boundary evidence: `migration blocked while pending retained`",
        "Randomness pause evidence: `TBD`": "Randomness pause evidence: `randomness request pause state retained`",
        "Metadata state snapshot evidence: `TBD`": "Metadata state snapshot evidence: `pending failed final tokenURI snapshots retained`",
        "Retry or stale-marking decision: `TBD`": "Retry or stale-marking decision: `retry accepted after stored seed review`",
        "Stored seed or raw-output evidence: `TBD`": "Stored seed or raw-output evidence: `derived seed and raw-output hash retained`",
        "Post-processing retry evidence: `TBD`": "Post-processing retry evidence: `RandomnessPostProcessingRetried event retained`",
        "Stale request marking evidence: `TBD`": "Stale request marking evidence: `not applicable; retry path retained`",
        "Final token hash evidence: `TBD`": "Final token hash evidence: `retrieveTokenHash final seed retained`",
        "Duplicate callback rejection evidence: `TBD`": "Duplicate callback rejection evidence: `duplicate callback revert retained`",
        "Post-recovery pending-count evidence: `TBD`": "Post-recovery pending-count evidence: `pending count zero retained`",
        "Operator dashboard confirmation: `TBD`": "Operator dashboard confirmation: `dashboard panel screenshot hash retained`",
        "Monitoring alert reference: `TBD`": "Monitoring alert reference: `alert SIM-RANDOMNESS-001 retained`",
        "Incident response decision log: `TBD`": "Incident response decision log: `decision-log.md`",
        "Public communication status: `TBD`": "Public communication status: `no public user impact`",
        "Follow-up issue links: `TBD`": "Follow-up issue links: `https://github.com/6529-Collections/6529Stream/issues/514`",
        "Command transcript bundle: `TBD`": "Command transcript bundle: `commands.md`",
        "Event or state snapshot bundle: `TBD`": "Event or state snapshot bundle: `snapshots.md`",
        "Randomizer operations evidence: `TBD`": "Randomizer operations evidence: `docs/randomizer-operations.md reviewed`",
        "Metadata rendering evidence: `TBD`": "Metadata rendering evidence: `docs/metadata.md reviewed`",
        "Admin ceremony evidence: `TBD`": "Admin ceremony evidence: `admin-ceremony.json`",
        "Release manifest/checksum digests: `TBD`": "Release manifest/checksum digests: `sha256 bundle retained`",
        "Operator: `TBD`": "Operator: `ops`",
        "Reviewer: `TBD`": "Reviewer: `reviewer`",
        "Review decision: `template`": "Review decision: `reviewed`",
        "No secrets retained: `TBD`": "No secrets retained: `yes`",
        "Private RPC URLs removed: `TBD`": "Private RPC URLs removed: `yes`",
        "Private keys removed: `TBD`": "Private keys removed: `yes`",
        "Provider dashboard secrets removed: `TBD`": "Provider dashboard secrets removed: `yes`",
        "Raw randomness payloads removed: `TBD`": "Raw randomness payloads removed: `yes`",
        "Unreleased token metadata removed: `TBD`": "Unreleased token metadata removed: `yes`",
        "Private collector data removed: `TBD`": "Private collector data removed: `yes`",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


class FailedRandomnessDrillEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        for path in checker.DEFAULT_EVIDENCE:
            checker.validate_evidence(path)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(path, reviewed_text())

            checker.validate_evidence(path)

    def test_wrong_requirement_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    checker.REQUIREMENT_ID, "incident_drill_evidence", 1
                ),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "Requirement ID"
            ):
                checker.validate_evidence(path)

    def test_reviewed_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Incident response decision log: `decision-log.md`",
                    "Incident response decision log: `TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "must be replaced"
            ):
                checker.validate_evidence(path)

    def test_pending_review_complete_readiness_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            text = reviewed_text().replace(
                "Review status: `reviewed`", "Review status: `pending_review`"
            )
            text = text.replace(
                "Review decision: `reviewed`", "Review decision: `pending_review`"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "Readiness claim"
            ):
                checker.validate_evidence(path)

    def test_reviewed_bad_chain_id_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace("Chain ID: `11155111`", "Chain ID: `sepolia`"),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "Chain ID must be a uint"
            ):
                checker.validate_evidence(path)

    def test_git_sha256_release_commit_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Release commit: `0123456789abcdef0123456789abcdef01234567`",
                    (
                        "Release commit: "
                        "`0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef`"
                    ),
                ),
            )

            checker.validate_evidence(path)

    def test_randomizer_adapter_must_be_nonzero_address(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Randomizer adapter: `0x0000000000000000000000000000000000004001`",
                    "Randomizer adapter: `0x0000000000000000000000000000000000000000`",
                ),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "Randomizer adapter"
            ):
                checker.validate_evidence(path)

    def test_failure_mode_must_match_request_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Failure mode: `metadata_write_failed`",
                    "Failure mode: `unknown_request`",
                ),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "Failure mode"
            ):
                checker.validate_evidence(path)

    def test_ending_request_state_must_match_request_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Ending request state: `Fulfilled`",
                    "Ending request state: `Stale`",
                ),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "Ending request state"
            ):
                checker.validate_evidence(path)

    def test_metadata_state_must_match_request_state(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Ending metadata state: `final`",
                    "Ending metadata state: `failed`",
                ),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "Ending metadata state"
            ):
                checker.validate_evidence(path)

    def test_stale_marking_path_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            text = reviewed_text()
            text = text.replace(
                "Request path: `post_processing_failed`",
                "Request path: `stale_marking`",
            )
            text = text.replace(
                "Failure mode: `metadata_write_failed`",
                "Failure mode: `manual_stale_mark`",
            )
            text = text.replace("Ending request state: `Fulfilled`", "Ending request state: `Stale`")
            text = text.replace("Ending metadata state: `final`", "Ending metadata state: `stale`")
            write_text(path, text)

            checker.validate_evidence(path)

    def test_invalid_callback_cannot_end_fulfilled(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            text = reviewed_text()
            text = text.replace(
                "Request path: `post_processing_failed`",
                "Request path: `invalid_callback`",
            )
            text = text.replace(
                "Failure mode: `metadata_write_failed`",
                "Failure mode: `wrong_provider`",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "invalid callback"
            ):
                checker.validate_evidence(path)

    def test_redaction_fields_must_be_yes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Raw randomness payloads removed: `yes`",
                    "Raw randomness payloads removed: `no`",
                ),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError,
                "Raw randomness payloads removed",
            ):
                checker.validate_evidence(path)

    def test_secret_like_key_value_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(path, reviewed_text() + "\napi_key=abc123\n")

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path)

    def test_credentialed_url_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(path, reviewed_text() + "\nhttps://user:pass@example.invalid\n")

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "credentialed URL"
            ):
                checker.validate_evidence(path)

    def test_redacted_credentialed_url_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(path, reviewed_text() + "\nhttps://user:[REDACTED]@example.invalid\n")

            checker.validate_evidence(path)

    def test_unredacted_credentialed_url_fails_even_with_redacted_line_marker(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text()
                + "\nhttps://user:pass@example.invalid retained dashboard [REDACTED]\n",
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "credentialed URL"
            ):
                checker.validate_evidence(path)

    def test_missing_required_command_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "failed-randomness.md"
            write_text(
                path,
                reviewed_text().replace(
                    "python scripts/check_failed_randomness_drill_evidence.py", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "validation commands"
            ):
                checker.validate_evidence(path)

    def test_missing_source_anchor_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = root / "failed-randomness.md"
            write_text(evidence, reviewed_text())
            for source_path, snippets in checker.SOURCE_REQUIREMENTS.items():
                write_text(root / source_path, "\n".join(snippets))
            target = root / "docs/randomizer-operations.md"
            write_text(target, "missing anchors\n")

            with self.assertRaisesRegex(
                checker.FailedRandomnessDrillEvidenceError, "source/test anchors"
            ):
                checker.validate_evidence(evidence, root)


if __name__ == "__main__":
    unittest.main()
