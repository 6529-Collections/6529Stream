#!/usr/bin/env python3
"""Focused tests for live ceremony retained evidence."""

from __future__ import annotations

import importlib.util
import re
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


def artifact_with_field(text: str, label: str, value: str) -> str:
    """Replace one Markdown bullet field value."""
    return re.sub(
        rf"^- {re.escape(label)}: .*$",
        lambda _match: f"- {label}: `{value}`",
        text,
        flags=re.MULTILINE,
    )


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
- Release manifest/checksum digests: `release-artifacts/evidence/live-ceremony/release-digests.md`

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


RETAINED_FILE_LABELS = {
    "Metadata and freeze ceremony": "release-artifacts/evidence/live-ceremony/metadata.md",
    "Auction ceremony": "release-artifacts/evidence/live-ceremony/auction.md",
    "Emergency controls ceremony": "release-artifacts/evidence/live-ceremony/emergency.md",
    "Dry-run mint evidence": "release-artifacts/evidence/live-ceremony/mint.md",
    "Dry-run auction evidence": "release-artifacts/evidence/live-ceremony/auction-dry-run.md",
    "Monitoring handoff": "release-artifacts/evidence/live-ceremony/monitoring.md",
    "Live deployment manifest": "deployments/live/mainnet-6529stream-v0.1.0-001.json",
    "Live address book": "deployments/address-books/mainnet-6529stream-v0.1.0-001.json",
    "Safe or multisig export": "release-artifacts/evidence/live-ceremony/safe-export.json",
    "Explorer transaction bundle": "release-artifacts/evidence/live-ceremony/explorer-transactions.json",
    "Post-state views": "release-artifacts/evidence/live-ceremony/post-state.md",
    "Release manifest/checksum digests": "release-artifacts/evidence/live-ceremony/release-digests.md",
}


def seed_reviewed_retained_files(
    repo_root: Path, overrides: dict[str, str] | None = None
) -> None:
    """Create retained files referenced by reviewed_artifact under a root."""
    values = {
        "release-artifacts/evidence/live-ceremony/metadata.md": "metadata freeze ceremony retained\n",
        "release-artifacts/evidence/live-ceremony/auction.md": "auction ceremony retained\n",
        "release-artifacts/evidence/live-ceremony/emergency.md": "emergency controls retained\n",
        "release-artifacts/evidence/live-ceremony/mint.md": "dry-run mint retained\n",
        "release-artifacts/evidence/live-ceremony/auction-dry-run.md": "dry-run auction retained\n",
        "release-artifacts/evidence/live-ceremony/monitoring.md": "monitoring handoff retained\n",
        "deployments/live/mainnet-6529stream-v0.1.0-001.json": '{"chain_id":1}\n',
        "deployments/address-books/mainnet-6529stream-v0.1.0-001.json": '{"chain_id":1}\n',
        "release-artifacts/evidence/live-ceremony/safe-export.json": '{"safe":"export"}\n',
        "release-artifacts/evidence/live-ceremony/explorer-transactions.json": '{"txs":[]}\n',
        "release-artifacts/evidence/live-ceremony/post-state.md": "post-state views retained\n",
        "release-artifacts/evidence/live-ceremony/release-digests.md": "release manifest/checksum digests retained\n",
    }
    values.update(overrides or {})
    for relative_path, contents in values.items():
        write_text(repo_root / relative_path, contents)


class LiveCeremonyEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed.md"
            seed_reviewed_retained_files(repo_root)
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path, repo_root=repo_root)

    def test_template_state_does_not_resolve_retained_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "template-missing-retained-files.md"
            text = valid_template()
            for label in RETAINED_FILE_LABELS:
                text = artifact_with_field(text, label, f"missing/{label}.md")
            write_text(path, text)

            checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_declared_hash_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed-hash.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Monitoring handoff"]
            digest = checker.file_sha256(repo_root / retained_path)
            text = artifact_with_field(
                reviewed_artifact(), "Monitoring handoff", f"{retained_path} {digest}"
            )
            write_text(path, text)

            checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "retained-placeholder.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(reviewed_artifact(), "Monitoring handoff", "TBD")
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError,
                "must be replaced before non-template review",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "missing-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_artifact(), "Monitoring handoff", "missing/live/monitoring.md"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "missing retained file"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_parent_path_escape_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "escape-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_artifact(), "Monitoring handoff", "../outside.md"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "must not escape"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_absolute_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "absolute-retained.md"
            seed_reviewed_retained_files(repo_root)
            absolute_path = str((repo_root / "outside.md").resolve()).replace("\\", "/")
            text = artifact_with_field(
                reviewed_artifact(), "Monitoring handoff", absolute_path
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "repo-relative"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_backslash_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "backslash-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Monitoring handoff",
                "release-artifacts\\evidence\\live-ceremony\\monitoring.md",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "must use forward slashes"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_symlink_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "symlink-retained.md"
            seed_reviewed_retained_files(repo_root)
            target = repo_root / "release-artifacts/evidence/live-ceremony/target.md"
            symlink = repo_root / "release-artifacts/evidence/live-ceremony/symlink.md"
            write_text(target, "retained symlink target\n")
            try:
                symlink.symlink_to(target)
            except (NotImplementedError, OSError):
                self.skipTest("symlinks are not available in this environment")
            text = artifact_with_field(
                reviewed_artifact(),
                "Monitoring handoff",
                "release-artifacts/evidence/live-ceremony/symlink.md",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "must not use symlinked"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_whitespace_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "whitespace-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Monitoring handoff",
                "release-artifacts/evidence/live ceremony/monitoring.md",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "one repo-relative path"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_backtick_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "backtick-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Monitoring handoff",
                "release-artifacts/evidence/live-ceremony/mon`itoring.md",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "must not contain backticks"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_multiple_hashes_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "multi-hash-retained.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Monitoring handoff"]
            digest = checker.file_sha256(repo_root / retained_path)
            text = artifact_with_field(
                reviewed_artifact(),
                "Monitoring handoff",
                f"{retained_path} {digest} {digest}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "multiple sha256"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_drift_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "hash-drift-retained.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Monitoring handoff"]
            wrong_digest = "sha256:" + "0" * 64
            text = artifact_with_field(
                reviewed_artifact(), "Monitoring handoff", f"{retained_path} {wrong_digest}"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "sha256 mismatch"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_without_separator_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "hash-no-separator-retained.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Monitoring handoff"]
            digest = checker.file_sha256(repo_root / retained_path)
            text = artifact_with_field(
                reviewed_artifact(),
                "Monitoring handoff",
                f"{retained_path}{digest}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "must separate path"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_malformed_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "malformed-hash-retained.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Monitoring handoff"]
            text = artifact_with_field(
                reviewed_artifact(),
                "Monitoring handoff",
                f"{retained_path} sha256:{'A' * 64}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "malformed sha256"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_trailing_text_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "hash-trailing-retained.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Monitoring handoff"]
            digest = checker.file_sha256(repo_root / retained_path)
            text = artifact_with_field(
                reviewed_artifact(),
                "Monitoring handoff",
                f"{retained_path} {digest} extra",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "trailing text"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_referenced_retained_file_secret_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "referenced-secret.md"
            seed_reviewed_retained_files(
                repo_root,
                {
                    RETAINED_FILE_LABELS["Monitoring handoff"]:
                    "Authorization: Bearer abcdefghijklmnop\n"
                },
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveCeremonyEvidenceError, "secret-like CLI or URL"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_bare_64_hex_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bare-hex.md"
            write_text(path, valid_template() + f"\n{'a' * 64}\n")

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "bare 64-hex"):
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
            repo_root = Path(temp_dir)
            path = repo_root / "angle.md"
            seed_reviewed_retained_files(repo_root)
            write_text(
                path,
                reviewed_artifact().replace(
                    "Live block or reference: `mainnet block 23000000`",
                    "Live block or reference: `finality lag < 5 minutes documented`",
                ),
            )

            checker.validate_artifact(path, repo_root=repo_root)

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

            with self.assertRaisesRegex(checker.LiveCeremonyEvidenceError, "secret-like CLI or URL"):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
