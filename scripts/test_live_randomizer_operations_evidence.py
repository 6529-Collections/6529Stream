#!/usr/bin/env python3
"""Focused tests for retained live randomizer operations evidence validation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_live_randomizer_operations_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_live_randomizer_operations_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def template_text() -> str:
    return Path(
        "release-artifacts/evidence/live-randomizer-operations/"
        "live-randomizer-operations-retained-artifact-template.md"
    ).read_text(encoding="utf-8")


def reviewed_text() -> str:
    text = template_text()
    replacements = {
        "> Template only. This file is not completion evidence.\n\n": "",
        "Review status: `template`": "Review status: `reviewed`",
        "Release commit: `TBD`": "Release commit: `0123456789abcdef0123456789abcdef01234567`",
        "Deployment version: `TBD`": "Deployment version: `mainnet-001`",
        "Live block or reference: `TBD`": "Live block or reference: `block 19000000`",
        "VRF adapter: `TBD`": "VRF adapter: `0x0000000000000000000000000000000000000008`",
        "VRF coordinator: `TBD`": "VRF coordinator: `0x0000000000000000000000000000000000006535`",
        "VRF provider epoch: `TBD`": "VRF provider epoch: `1`",
        "VRF funding status: `TBD`": "VRF funding status: `funded`",
        "VRF evidence: `TBD`": "VRF evidence: `provider-funding-vrf.md`",
        "arRNG adapter: `TBD`": "arRNG adapter: `0x0000000000000000000000000000000000000009`",
        "arRNG controller: `TBD`": "arRNG controller: `0x0000000000000000000000000000000000006536`",
        "arRNG provider epoch: `TBD`": "arRNG provider epoch: `1`",
        "arRNG funding status: `TBD`": "arRNG funding status: `funded`",
        "arRNG refund recipient: `TBD`": "arRNG refund recipient: `0x0000000000000000000000000000000000000007`",
        "arRNG evidence: `TBD`": "arRNG evidence: `provider-funding-arrng.md`",
        "Randomizer reserve status: `TBD`": "Randomizer reserve status: `funded and reconciled`",
        "Pending request count: `TBD`": "Pending request count: `0`",
        "Stale request handling: `TBD`": "Stale request handling: `passed`",
        "Failed request handling: `TBD`": "Failed request handling: `passed`",
        "Retry evidence: `TBD`": "Retry evidence: `passed`",
        "Provider migration status: `TBD`": "Provider migration status: `passed`",
        "Request tracking: `TBD`": "Request tracking: `passed`",
        "Callback validation: `TBD`": "Callback validation: `passed`",
        "Pending request migration block: `TBD`": "Pending request migration block: `passed`",
        "Pause policy: `TBD`": "Pause policy: `passed`",
        "Emergency withdrawal boundary: `TBD`": "Emergency withdrawal boundary: `passed`",
        "Monitoring handoff: `TBD`": "Monitoring handoff: `monitoring-owner-reviewed`",
        "Live deployment manifest: `TBD`": "Live deployment manifest: `deployments/live/mainnet.json`",
        "Live address book: `TBD`": "Live address book: `deployments/address-books/mainnet.json`",
        "Randomizer operations JSON: `TBD`": "Randomizer operations JSON: `deployments/randomizer-operations/mainnet.json`",
        "Provider dashboard or export: `TBD`": "Provider dashboard or export: `provider-dashboard-redacted.md`",
        "Explorer transaction bundle: `TBD`": "Explorer transaction bundle: `explorer-randomizer-bundle.md`",
        "Release manifest/checksum digests: `TBD`": "Release manifest/checksum digests: `sha256 bundle retained`",
        "Operator: `TBD`": "Operator: `ops`",
        "Reviewer: `TBD`": "Reviewer: `reviewer`",
        "Review decision: `template`": "Review decision: `reviewed`",
        "No secrets retained: `TBD`": "No secrets retained: `yes`",
        "Private RPC URLs removed: `TBD`": "Private RPC URLs removed: `yes`",
        "Private keys removed: `TBD`": "Private keys removed: `yes`",
        "Provider dashboard secrets removed: `TBD`": "Provider dashboard secrets removed: `yes`",
        "Signer-service secrets removed: `TBD`": "Signer-service secrets removed: `yes`",
        "Unreleased drop payloads removed: `TBD`": "Unreleased drop payloads removed: `yes`",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


class LiveRandomizerOperationsEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        for path in checker.DEFAULT_EVIDENCE:
            checker.validate_evidence(path)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(path, reviewed_text())

            checker.validate_evidence(path)

    def test_wrong_requirement_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    checker.REQUIREMENT_ID, "live_ceremony_evidence", 1
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "Requirement ID"
            ):
                checker.validate_evidence(path)

    def test_reviewed_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Live deployment manifest: `deployments/live/mainnet.json`",
                    "Live deployment manifest: `TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must be replaced"
            ):
                checker.validate_evidence(path)

    def test_pending_review_template_decision_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            text = reviewed_text()
            text = text.replace("Review status: `reviewed`", "Review status: `pending_review`")
            text = text.replace("Review decision: `reviewed`", "Review decision: `template`")
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "advance the review decision"
            ):
                checker.validate_evidence(path)

    def test_bad_address_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    "VRF adapter: `0x0000000000000000000000000000000000000008`",
                    "VRF adapter: `release-operator`",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must be an address"
            ):
                checker.validate_evidence(path)

    def test_reviewed_pending_control_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Callback validation: `passed`", "Callback validation: `pending`"
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must be 'passed'"
            ):
                checker.validate_evidence(path)

    def test_reviewed_unfunded_provider_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    "VRF funding status: `funded`", "VRF funding status: `pending`"
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must be 'funded'"
            ):
                checker.validate_evidence(path)

    def test_missing_validation_command_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    "python scripts/check_randomizer_operations.py", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError,
                "missing required validation command",
            ):
                checker.validate_evidence(path)

    def test_comparison_angle_text_is_not_placeholder(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Monitoring handoff: `monitoring-owner-reviewed`",
                    "Monitoring handoff: `alert threshold < 5 minutes`",
                ),
            )

            checker.validate_evidence(path)

    def test_secret_like_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Provider dashboard or export: `provider-dashboard-redacted.md`",
                    "Provider dashboard or export: `api_key=do-not-commit`",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path)

    def test_credentialed_urls_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Provider dashboard or export: `provider-dashboard-redacted.md`",
                    "Provider dashboard or export: `https://user:pass@example.invalid/export`",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "credentialed URL"
            ):
                checker.validate_evidence(path)


if __name__ == "__main__":
    unittest.main()
