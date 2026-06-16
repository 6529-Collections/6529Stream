#!/usr/bin/env python3
"""Focused tests for live ceremony retained evidence."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_live_ceremony_evidence.py")
SPEC = importlib.util.spec_from_file_location("check_live_ceremony_evidence", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_template() -> str:
    return """# Live Ceremony Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `live_ceremony_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Live Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Release commit: `TBD`
- Deployment version: `TBD`
- Live block or reference: `TBD`

## Participants And Governance

- Deployer: `TBD`
- Admin Safe or multisig: `TBD`
- Pause guardian: `TBD`
- Emergency recipient: `TBD`
- Drop signer: `TBD`
- Signer manager: `TBD`

## Ceremony Transactions

- Ownership transfer transaction: `TBD`
- Role grant and revoke transactions: `TBD`
- Signer setup transactions: `TBD`
- Metadata and freeze ceremony: `TBD`
- Auction ceremony: `TBD`
- Emergency controls ceremony: `TBD`

## Dry Runs And Monitoring

- Dry-run mint evidence: `TBD`
- Dry-run auction evidence: `TBD`
- Monitoring handoff: `TBD`

## Required Retained Artifacts

- Live deployment manifest: `TBD`
- Live address book: `TBD`
- Safe or multisig export: `TBD`
- Explorer transaction bundle: `TBD`
- Post-state views: `TBD`
- Release manifest/checksum digests: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- Signer-service secrets removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_live_ceremony_evidence.py
python scripts/check_live_ceremony_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-ceremony-evidence-template.json --retained-artifact release-artifacts/evidence/live-ceremony/live-ceremony-retained-artifact-template.md --output release-artifacts/evidence/live-ceremony/live-ceremony-evidence.json --environment live --chain-id 1 --block-or-reference "<mainnet block, ceremony transcript, or deployment version>" --command-or-source-system "<safe export, explorer source, or reviewer source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<release CI run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep issue #228 open until reviewed retained evidence is linked from the
  shared production-release evidence manifest.
"""


def reviewed_artifact() -> str:
    return """# Live Ceremony Retained Artifact

## Evidence Status

- Requirement ID: `live_ceremony_evidence`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Live Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Release commit: `1234567890abcdef1234567890abcdef12345678`
- Deployment version: `mainnet-6529stream-v0.1.0-001`
- Live block or reference: `mainnet block 23000000`

## Participants And Governance

- Deployer: `0x0000000000000000000000000000000000006537`
- Admin Safe or multisig: `0x0000000000000000000000000000000000006529`
- Pause guardian: `0x0000000000000000000000000000000000006530`
- Emergency recipient: `0x0000000000000000000000000000000000006531`
- Drop signer: `0x0000000000000000000000000000000000006532`
- Signer manager: `0x0000000000000000000000000000000000006533`

## Ceremony Transactions

- Ownership transfer transaction: `0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`
- Role grant and revoke transactions: `0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb`
- Signer setup transactions: `0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc`
- Metadata and freeze ceremony: `release-artifacts/evidence/live-ceremony/metadata.md`
- Auction ceremony: `release-artifacts/evidence/live-ceremony/auction.md`
- Emergency controls ceremony: `release-artifacts/evidence/live-ceremony/emergency.md`

## Dry Runs And Monitoring

- Dry-run mint evidence: `release-artifacts/evidence/live-ceremony/mint.md`
- Dry-run auction evidence: `release-artifacts/evidence/live-ceremony/auction-dry-run.md`
- Monitoring handoff: `release-artifacts/evidence/live-ceremony/monitoring.md`

## Required Retained Artifacts

- Live deployment manifest: `deployments/live/mainnet-6529stream-v0.1.0-001.json`
- Live address book: `deployments/address-books/mainnet-6529stream-v0.1.0-001.json`
- Safe or multisig export: `release-artifacts/evidence/live-ceremony/safe-export.json`
- Explorer transaction bundle: `release-artifacts/evidence/live-ceremony/explorer-transactions.json`
- Post-state views: `release-artifacts/evidence/live-ceremony/post-state.md`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and SHA256SUMS`

## Review

- Operator: `release-operator`
- Reviewer: `security-reviewer`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- Signer-service secrets removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_live_ceremony_evidence.py
python scripts/check_live_ceremony_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-ceremony-evidence-template.json --retained-artifact release-artifacts/evidence/live-ceremony/live-ceremony-retained-artifact-template.md --output release-artifacts/evidence/live-ceremony/live-ceremony-evidence.json --environment live --chain-id 1 --block-or-reference "mainnet block 23000000" --command-or-source-system "Safe export and explorer bundle" --owner release-operator --reviewer security-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  production-release evidence manifest.
"""


class LiveCeremonyEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed.md"
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_wrong_requirement_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong.md"
            write_text(path, valid_template().replace("`live_ceremony_evidence`", "`post_audit_remediation`"))

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "live_ceremony_evidence"):
                checker.validate_artifact(path)

    def test_reviewed_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "placeholder.md"
            write_text(path, reviewed_artifact().replace("`mainnet-6529stream-v0.1.0-001`", "`TBD`"))

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "Deployment version"):
                checker.validate_artifact(path)

    def test_pending_review_template_decision_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "pending.md"
            write_text(
                path,
                reviewed_artifact()
                .replace("Review status: `reviewed`", "Review status: `pending_review`")
                .replace("Review decision: `reviewed`", "Review decision: `template`"),
            )

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "advance the review decision"):
                checker.validate_artifact(path)

    def test_bad_address_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-address.md"
            write_text(path, reviewed_artifact().replace("Deployer: `0x0000000000000000000000000000000000006537`", "Deployer: `release-operator`"))

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "Deployer"):
                checker.validate_artifact(path)

    def test_missing_validation_command_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-command.md"
            write_text(path, valid_template().replace("python scripts/check_public_beta_evidence.py\n", ""))

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "check_public_beta_evidence"):
                checker.validate_artifact(path)

    def test_comparison_angle_text_is_not_placeholder(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "angle.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "Monitoring handoff: `release-artifacts/evidence/live-ceremony/monitoring.md`",
                    "Monitoring handoff: `alert threshold < 5 minutes documented`",
                ),
            )

            checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\nprivate_key=do-not-commit\n")

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "secret-like"):
                checker.validate_artifact(path)

    def test_credentialed_urls_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "credential-url.md"
            write_text(path, valid_template() + "\nhttps://user:pass@example.invalid\n")

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "credentialed URL"):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
