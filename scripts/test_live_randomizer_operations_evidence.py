#!/usr/bin/env python3
"""Focused tests for retained live randomizer operations evidence validation."""

from __future__ import annotations

import importlib.util
import re
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
        "VRF evidence: `TBD`": (
            "VRF evidence: "
            "`release-artifacts/evidence/live-randomizer-operations/vrf-evidence.md`"
        ),
        "arRNG adapter: `TBD`": "arRNG adapter: `0x0000000000000000000000000000000000000009`",
        "arRNG controller: `TBD`": "arRNG controller: `0x0000000000000000000000000000000000006536`",
        "arRNG provider epoch: `TBD`": "arRNG provider epoch: `1`",
        "arRNG funding status: `TBD`": "arRNG funding status: `funded`",
        "arRNG refund recipient: `TBD`": "arRNG refund recipient: `0x0000000000000000000000000000000000000007`",
        "arRNG evidence: `TBD`": (
            "arRNG evidence: "
            "`release-artifacts/evidence/live-randomizer-operations/arrng-evidence.md`"
        ),
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
        "Monitoring handoff: `TBD`": (
            "Monitoring handoff: "
            "`release-artifacts/evidence/live-randomizer-operations/monitoring.md`"
        ),
        "Live deployment manifest: `TBD`": (
            "Live deployment manifest: "
            "`deployments/live/mainnet-randomizer-operations.json`"
        ),
        "Live address book: `TBD`": (
            "Live address book: "
            "`deployments/address-books/mainnet-randomizer-operations.json`"
        ),
        "Randomizer operations JSON: `TBD`": (
            "Randomizer operations JSON: "
            "`deployments/randomizer-operations/mainnet-randomizer-operations.json`"
        ),
        "Provider dashboard or export: `TBD`": (
            "Provider dashboard or export: "
            "`release-artifacts/evidence/live-randomizer-operations/provider-dashboard.md`"
        ),
        "Explorer transaction bundle: `TBD`": (
            "Explorer transaction bundle: "
            "`release-artifacts/evidence/live-randomizer-operations/explorer-transactions.json`"
        ),
        "Release manifest/checksum digests: `TBD`": (
            "Release manifest/checksum digests: "
            "`release-artifacts/evidence/live-randomizer-operations/release-digests.md`"
        ),
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


def artifact_with_field(text: str, label: str, value: str) -> str:
    return re.sub(
        rf"^- {re.escape(label)}: `[^`\n]*`$",
        lambda _match: f"- {label}: `{value}`",
        text,
        count=1,
        flags=re.MULTILINE,
    )


RETAINED_FILE_LABELS = {
    "VRF evidence": "release-artifacts/evidence/live-randomizer-operations/vrf-evidence.md",
    "arRNG evidence": "release-artifacts/evidence/live-randomizer-operations/arrng-evidence.md",
    "Monitoring handoff": "release-artifacts/evidence/live-randomizer-operations/monitoring.md",
    "Live deployment manifest": "deployments/live/mainnet-randomizer-operations.json",
    "Live address book": "deployments/address-books/mainnet-randomizer-operations.json",
    "Randomizer operations JSON": (
        "deployments/randomizer-operations/mainnet-randomizer-operations.json"
    ),
    "Provider dashboard or export": (
        "release-artifacts/evidence/live-randomizer-operations/provider-dashboard.md"
    ),
    "Explorer transaction bundle": (
        "release-artifacts/evidence/live-randomizer-operations/explorer-transactions.json"
    ),
    "Release manifest/checksum digests": (
        "release-artifacts/evidence/live-randomizer-operations/release-digests.md"
    ),
}


def seed_reviewed_retained_files(
    repo_root: Path, overrides: dict[str, str] | None = None
) -> None:
    values = {
        "release-artifacts/evidence/live-randomizer-operations/vrf-evidence.md": (
            "vrf provider evidence retained\n"
        ),
        "release-artifacts/evidence/live-randomizer-operations/arrng-evidence.md": (
            "arrng provider evidence retained\n"
        ),
        "release-artifacts/evidence/live-randomizer-operations/monitoring.md": (
            "monitoring handoff retained\n"
        ),
        "deployments/live/mainnet-randomizer-operations.json": '{"chain_id":1}\n',
        "deployments/address-books/mainnet-randomizer-operations.json": '{"chain_id":1}\n',
        "deployments/randomizer-operations/mainnet-randomizer-operations.json": (
            '{"request_health":"ok"}\n'
        ),
        "release-artifacts/evidence/live-randomizer-operations/provider-dashboard.md": (
            "redacted provider dashboard retained\n"
        ),
        "release-artifacts/evidence/live-randomizer-operations/explorer-transactions.json": (
            '{"txs":[]}\n'
        ),
        "release-artifacts/evidence/live-randomizer-operations/release-digests.md": (
            "release manifest/checksum digests retained\n"
        ),
    }
    values.update(overrides or {})
    for relative_path, contents in values.items():
        write_text(repo_root / relative_path, contents)


class LiveRandomizerOperationsEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        for path in checker.DEFAULT_EVIDENCE:
            checker.validate_evidence(path)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            seed_reviewed_retained_files(repo_root)
            write_text(path, reviewed_text())

            checker.validate_evidence(path, repo_root=repo_root)

    def test_template_state_does_not_resolve_retained_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "template-missing-retained-files.md"
            text = template_text()
            for label in RETAINED_FILE_LABELS:
                text = artifact_with_field(text, label, f"missing/{label}.md")
            write_text(path, text)

            checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_declared_hash_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "reviewed-hash.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Provider dashboard or export"]
            digest = checker.file_sha256(repo_root / retained_path)
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                f"{retained_path} {digest}",
            )
            write_text(path, text)

            checker.validate_evidence(path, repo_root=repo_root)

    def test_wrong_requirement_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            write_text(
                path,
                reviewed_text().replace(
                    checker.REQUIREMENT_ID, "live_ceremony_evidence", 1
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "Requirement ID"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_text(), "Live deployment manifest", "TBD"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must be replaced"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "missing-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_text(), "Provider dashboard or export", "missing/provider.md"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "missing retained file"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_parent_path_escape_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "escape-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_text(), "Provider dashboard or export", "../provider.md"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must not escape"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_absolute_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "absolute-retained.md"
            seed_reviewed_retained_files(repo_root)
            absolute_path = str((repo_root / "outside.md").resolve()).replace("\\", "/")
            text = artifact_with_field(
                reviewed_text(), "Provider dashboard or export", absolute_path
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "repo-relative"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_backslash_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "backslash-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                "release-artifacts\\evidence\\live-randomizer-operations\\provider.md",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must use forward slashes"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_whitespace_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "whitespace-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                "release-artifacts/evidence/live randomizer/provider.md",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "one repo-relative path"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_backtick_path_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "backtick-retained.md"
            seed_reviewed_retained_files(repo_root)
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                "release-artifacts/evidence/live-randomizer-operations/prov`ider.md",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must not contain backticks"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_symlink_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "symlink-retained.md"
            seed_reviewed_retained_files(repo_root)
            target = (
                repo_root
                / "release-artifacts/evidence/live-randomizer-operations/target.md"
            )
            symlink = (
                repo_root
                / "release-artifacts/evidence/live-randomizer-operations/symlink.md"
            )
            write_text(target, "retained symlink target\n")
            try:
                symlink.symlink_to(target)
            except (NotImplementedError, OSError):
                self.skipTest("symlinks are not available in this environment")
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                "release-artifacts/evidence/live-randomizer-operations/symlink.md",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must not use symlinked"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_multiple_hashes_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "multiple-hashes.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Provider dashboard or export"]
            digest = checker.file_sha256(repo_root / retained_path)
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                f"{retained_path} {digest} {digest}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "multiple sha256"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_stale_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "stale-hash.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Provider dashboard or export"]
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                f"{retained_path} sha256:{'0' * 64}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "sha256 mismatch"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_missing_path_hash_separator_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "missing-separator.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Provider dashboard or export"]
            digest = checker.file_sha256(repo_root / retained_path)
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                f"{retained_path}{digest}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must separate path"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_malformed_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "malformed-hash.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Provider dashboard or export"]
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                f"{retained_path} sha256:{'A' * 64}",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "malformed sha256"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_retained_trailing_hash_text_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "trailing-hash-text.md"
            seed_reviewed_retained_files(repo_root)
            retained_path = RETAINED_FILE_LABELS["Provider dashboard or export"]
            digest = checker.file_sha256(repo_root / retained_path)
            text = artifact_with_field(
                reviewed_text(),
                "Provider dashboard or export",
                f"{retained_path} {digest} reviewed",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "trailing text"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_referenced_retained_file_secret_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "retained-secret.md"
            retained_path = RETAINED_FILE_LABELS["Provider dashboard or export"]
            seed_reviewed_retained_files(
                repo_root, {retained_path: "provider_dashboard_secret=hidden\n"}
            )
            write_text(path, reviewed_text())

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_referenced_retained_file_bare_hex_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "retained-bare-hex.md"
            retained_path = RETAINED_FILE_LABELS["Provider dashboard or export"]
            seed_reviewed_retained_files(repo_root, {retained_path: f"{'a' * 64}\n"})
            write_text(path, reviewed_text())

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "bare 64-hex"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

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
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            seed_reviewed_retained_files(repo_root)
            write_text(
                path,
                reviewed_text().replace(
                    "Callback validation: `passed`", "Callback validation: `pending`"
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must be 'passed'"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_reviewed_unfunded_provider_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            seed_reviewed_retained_files(repo_root)
            write_text(
                path,
                reviewed_text().replace(
                    "VRF funding status: `funded`", "VRF funding status: `pending`"
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "must be 'funded'"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_missing_validation_command_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            seed_reviewed_retained_files(repo_root)
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
                checker.validate_evidence(path, repo_root=repo_root)

    def test_comparison_angle_text_is_not_placeholder(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            seed_reviewed_retained_files(repo_root)
            write_text(
                path,
                artifact_with_field(
                    reviewed_text(),
                    "Live block or reference",
                    "alert threshold < 5 minutes",
                ),
            )

            checker.validate_evidence(path, repo_root=repo_root)

    def test_secret_like_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_text(),
                    "Provider dashboard or export",
                    "api_key=do-not-commit",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path, repo_root=repo_root)

    def test_credentialed_urls_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            path = repo_root / "live-randomizer.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_text(),
                    "Provider dashboard or export",
                    "https://user:pass@example.invalid/export",
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveRandomizerOperationsEvidenceError, "secret-like CLI or URL"
            ):
                checker.validate_evidence(path, repo_root=repo_root)


if __name__ == "__main__":
    unittest.main()
