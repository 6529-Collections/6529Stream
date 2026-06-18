#!/usr/bin/env python3
"""Focused tests for fork/testnet randomizer operations retained evidence."""

from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_fork_randomizer_operations_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_fork_randomizer_operations_evidence",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


DEPLOYMENT_MANIFEST_PATH = (
    "deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json"
)
ADDRESS_BOOK_PATH = (
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json"
)
RANDOMIZER_OPERATIONS_PATH = (
    "deployments/randomizer-operations/fork-mainnet-6529stream-v0.1.0-001.json"
)
PROVIDER_DASHBOARD_PATH = (
    "release-artifacts/evidence/fork-randomizer-operations/provider-dashboard-redacted.md"
)
TRANSACTION_BUNDLE_PATH = (
    "release-artifacts/evidence/fork-randomizer-operations/"
    "fork-randomizer-transactions.json"
)
POST_STATE_PATH = (
    "release-artifacts/evidence/fork-randomizer-operations/post-state-requests.md"
)
RETAINED_PATHS = [
    DEPLOYMENT_MANIFEST_PATH,
    ADDRESS_BOOK_PATH,
    RANDOMIZER_OPERATIONS_PATH,
    PROVIDER_DASHBOARD_PATH,
    TRANSACTION_BUNDLE_PATH,
    POST_STATE_PATH,
]
ADDRESS_FIELD_VALUES = {
    "VRF adapter": "0x0000000000000000000000000000000000000008",
    "VRF coordinator": "0x0000000000000000000000000000000000006535",
    "arRNG adapter": "0x0000000000000000000000000000000000000009",
    "arRNG controller": "0x0000000000000000000000000000000000006536",
    "arRNG refund recipient": "0x0000000000000000000000000000000000000007",
}


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def template_text() -> str:
    """Return a valid fork/testnet randomizer retained-artifact template."""
    return """# Fork/Testnet Randomizer Operations Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `fork_testnet_randomizer_operations_evidence`
- Evidence type: `fork_testnet_randomizer_operations_evidence`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Fork/Testnet Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Fork/testnet block or reference: `TBD`
- Network and deployment version: `TBD`

## Provider Configuration

- VRF adapter: `TBD`
- VRF coordinator: `TBD`
- VRF provider epoch: `TBD`
- VRF funding status: `TBD`
- VRF evidence: `TBD`
- arRNG adapter: `TBD`
- arRNG controller: `TBD`
- arRNG provider epoch: `TBD`
- arRNG funding status: `TBD`
- arRNG refund recipient: `TBD`
- arRNG evidence: `TBD`

## Funding And Reserve Status

- Randomizer reserve status: `TBD`
- Pending request count: `TBD`
- Stale request handling: `TBD`
- Failed request handling: `TBD`
- Retry evidence: `TBD`
- Provider migration status: `TBD`

## Request Health

- Request tracking: `TBD`
- Callback validation: `TBD`
- Pending request migration block: `TBD`

## Lifecycle Controls

- Pause policy: `TBD`
- Emergency withdrawal boundary: `TBD`
- Monitoring handoff: `TBD`

## Required Retained Artifacts

- Deployment manifest: `TBD`
- Address book: `TBD`
- Randomizer operations JSON: `TBD`
- Provider dashboard or export: `TBD`
- Explorer or fork transaction bundle: `TBD`
- Post-state request views: `TBD`
- Release manifest/checksum digests: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- API keys removed: `TBD`
- Provider dashboard secrets removed: `TBD`
- Signer-service secrets removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_fork_randomizer_operations_evidence.py
python scripts/check_fork_randomizer_operations_evidence.py
python scripts/check_randomizer_operations.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-randomizer-operations-evidence-template.json --retained-artifact release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-retained-artifact-template.md --output release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-evidence.json --environment fork --chain-id 1 --block-or-reference "<fork/testnet block, provider epoch, request-health reference, or operations transcript>" --command-or-source-system "<provider export, explorer source, operations JSON, or reviewer source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed fork/testnet randomizer operations artifact."""
    text = template_text()
    replacements = {
        "> Template only. This file is not completion evidence.\n\n": "",
        "Review status: `template`": "Review status: `reviewed`",
        "Git commit: `TBD`": "Git commit: `1234567890abcdef1234567890abcdef12345678`",
        "CI run or operator transcript: `TBD`": "CI run or operator transcript: `ci-run-123`",
        "Fork/testnet block or reference: `TBD`": "Fork/testnet block or reference: `fork block 25316366`",
        "Network and deployment version: `TBD`": "Network and deployment version: `fork-mainnet-6529stream-v0.1.0-001`",
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
        "Randomizer reserve status: `TBD`": "Randomizer reserve status: `funded_and_reconciled`",
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
        "Deployment manifest: `TBD`": f"Deployment manifest: `{DEPLOYMENT_MANIFEST_PATH}`",
        "Address book: `TBD`": f"Address book: `{ADDRESS_BOOK_PATH}`",
        "Randomizer operations JSON: `TBD`": f"Randomizer operations JSON: `{RANDOMIZER_OPERATIONS_PATH}`",
        "Provider dashboard or export: `TBD`": f"Provider dashboard or export: `{PROVIDER_DASHBOARD_PATH}`",
        "Explorer or fork transaction bundle: `TBD`": f"Explorer or fork transaction bundle: `{TRANSACTION_BUNDLE_PATH}`",
        "Post-state request views: `TBD`": f"Post-state request views: `{POST_STATE_PATH}`",
        "Release manifest/checksum digests: `TBD`": "Release manifest/checksum digests: `release-manifest sha256:1111111111111111111111111111111111111111111111111111111111111111 and SHA256SUMS sha256:2222222222222222222222222222222222222222222222222222222222222222`",
        "Operator: `TBD`": "Operator: `release-operator`",
        "Reviewer: `TBD`": "Reviewer: `release-reviewer`",
        "Review decision: `template`": "Review decision: `reviewed`",
        "No secrets retained: `TBD`": "No secrets retained: `yes`",
        "Private RPC URLs removed: `TBD`": "Private RPC URLs removed: `yes`",
        "Private keys removed: `TBD`": "Private keys removed: `yes`",
        "API keys removed: `TBD`": "API keys removed: `yes`",
        "Provider dashboard secrets removed: `TBD`": "Provider dashboard secrets removed: `yes`",
        "Signer-service secrets removed: `TBD`": "Signer-service secrets removed: `yes`",
        "Unreleased drop payloads removed: `TBD`": "Unreleased drop payloads removed: `yes`",
        '--block-or-reference "<fork/testnet block, provider epoch, request-health reference, or operations transcript>"': '--block-or-reference "fork block 25316366"',
        '--command-or-source-system "<provider export, explorer source, operations JSON, or reviewer source>"': '--command-or-source-system "fork randomizer operations transcript"',
        '--owner "<operator>"': "--owner release-operator",
        '--reviewer "<reviewer>"': "--reviewer release-reviewer",
        '--source-git-commit "<release commit>"': "--source-git-commit 1234567890abcdef1234567890abcdef12345678",
        '--source-ci-run "<ci run>"': "--source-ci-run ci-run-123",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def seed_retained_paths(repo_root: Path, *, omit: str | None = None) -> None:
    """Create clean retained files referenced by the reviewed fixture."""
    for retained_path in RETAINED_PATHS:
        if retained_path == omit:
            continue
        write_text(
            repo_root / retained_path,
            f"retained fork randomizer operations evidence for {retained_path}\n",
        )


class ForkRandomizerOperationsEvidenceTests(unittest.TestCase):
    """Checker behavior for fork/testnet randomizer operations evidence."""

    def test_committed_template_passes(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_default_cli_works_outside_repo_root(self) -> None:
        """Default evidence paths resolve from the checker repo root."""
        original_cwd = Path.cwd()
        with tempfile.TemporaryDirectory() as temp_dir:
            try:
                os.chdir(temp_dir)
                with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                    result = checker.main([])
            finally:
                os.chdir(original_cwd)

        self.assertEqual(result, 0)

    def test_reviewed_artifact_passes(self) -> None:
        """A filled reviewed artifact can pass before manifest linkage."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "reviewed.md"
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_artifact_with_declared_hashes_passes(self) -> None:
        """Declared retained hashes are accepted when they match disk."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            dashboard_hash = checker.file_sha256(repo_root / PROVIDER_DASHBOARD_PATH)
            path = repo_root / "reviewed-hashes.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    f"Provider dashboard or export: `{PROVIDER_DASHBOARD_PATH}`",
                    "Provider dashboard or export: "
                    f"`{PROVIDER_DASHBOARD_PATH} / {dashboard_hash}`",
                ),
            )

            checker.validate_artifact(path, repo_root=repo_root)

    def test_testnet_reviewed_artifact_passes(self) -> None:
        """A filled testnet artifact is valid with a positive testnet chain ID."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "reviewed-testnet.md"
            write_text(
                path,
                reviewed_artifact()
                .replace("- Environment: `fork`", "- Environment: `testnet`")
                .replace("- Chain ID: `1`", "- Chain ID: `11155111`")
                .replace(
                    "--environment fork --chain-id 1",
                    "--environment testnet --chain-id 11155111",
                ),
            )

            checker.validate_artifact(path, repo_root=repo_root)

    def test_wrong_requirement_fails(self) -> None:
        """Requirement ID is fixed to fork/testnet randomizer operations."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong.md"
            write_text(
                path,
                template_text().replace(
                    checker.REQUIREMENT_ID,
                    "fork_testnet_ceremony_evidence",
                    1,
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                checker.REQUIREMENT_ID,
            ):
                checker.validate_artifact(path)

    def test_unsupported_environment_fails(self) -> None:
        """Only fork and testnet environments are valid."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live.md"
            write_text(
                path,
                template_text().replace("- Environment: `fork`", "- Environment: `live`"),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "fork",
            ):
                checker.validate_artifact(path)

    def test_leading_zero_chain_id_fails(self) -> None:
        """Chain IDs are positive decimal values without leading zeroes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "chain.md"
            write_text(
                path,
                template_text().replace("- Chain ID: `1`", "- Chain ID: `01`"),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "Chain ID",
            ):
                checker.validate_artifact(path)

    def test_reviewed_placeholder_fails(self) -> None:
        """Reviewed artifacts must replace placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "`fork-mainnet-6529stream-v0.1.0-001`",
                    "`TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "Network and deployment version",
            ):
                checker.validate_artifact(path)

    def test_pending_review_template_decision_fails(self) -> None:
        """Pending-review artifacts must advance the review decision."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "pending.md"
            write_text(
                path,
                reviewed_artifact()
                .replace("Review status: `reviewed`", "Review status: `pending_review`")
                .replace("Review decision: `reviewed`", "Review decision: `template`"),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "advance the review decision",
            ):
                checker.validate_artifact(path)

    def test_bad_address_fails(self) -> None:
        """Provider address fields must be addresses after template state."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-address.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "VRF adapter: `0x0000000000000000000000000000000000000008`",
                    "VRF adapter: `release-operator`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "VRF adapter",
            ):
                checker.validate_artifact(path)

    def test_reviewed_zero_address_fields_fail(self) -> None:
        """Reviewed provider address fields cannot be zero addresses."""
        zero_address = "0x0000000000000000000000000000000000000000"
        for label, original in ADDRESS_FIELD_VALUES.items():
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    repo_root = Path(temp_dir)
                    seed_retained_paths(repo_root)
                    path = repo_root / f"{label.replace(' ', '-').lower()}.md"
                    write_text(
                        path,
                        reviewed_artifact().replace(
                            f"{label}: `{original}`",
                            f"{label}: `{zero_address}`",
                        ),
                    )

                    with self.assertRaisesRegex(
                        checker.ForkRandomizerOperationsEvidenceError,
                        "zero address",
                    ):
                        checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_pending_control_fails(self) -> None:
        """Reviewed artifacts require all lifecycle controls to pass."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "pending-control.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "Callback validation: `passed`",
                    "Callback validation: `pending`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "Callback validation",
            ):
                checker.validate_artifact(path)

    def test_reviewed_unfunded_reserve_fails(self) -> None:
        """Reviewed artifacts require funded and reconciled randomizer reserve."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "unfunded-reserve.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "Randomizer reserve status: `funded_and_reconciled`",
                    "Randomizer reserve status: `unfunded`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "Randomizer reserve status",
            ):
                checker.validate_artifact(path)

    def test_reviewed_unfunded_provider_fails(self) -> None:
        """Reviewed artifacts require both providers to be funded."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "unfunded.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "VRF funding status: `funded`",
                    "VRF funding status: `pending`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "VRF funding status",
            ):
                checker.validate_artifact(path)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        """Reviewed retained artifact references must point at existing files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root, omit=POST_STATE_PATH)
            path = repo_root / "missing-retained.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "Post-state request views",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_placeholder_fails_clearly(self) -> None:
        """Reviewed retained artifact references cannot remain placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "placeholder-retained.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    f"Deployment manifest: `{DEPLOYMENT_MANIFEST_PATH}`",
                    "Deployment manifest: `TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "must be replaced before non-template review",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_parent_path_escape_fails(self) -> None:
        """Reviewed retained paths cannot escape through parent segments."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "escape-retained.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    f"Post-state request views: `{POST_STATE_PATH}`",
                    "Post-state request views: `../post-state.md`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "escape",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_absolute_path_escape_fails(self) -> None:
        """Reviewed retained paths cannot be absolute paths."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "absolute-retained.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    f"Post-state request views: `{POST_STATE_PATH}`",
                    "Post-state request views: `/tmp/post-state.md`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "repo-relative",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_file_secret_fails(self) -> None:
        """Secret-shaped text inside referenced retained files is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            write_text(repo_root / POST_STATE_PATH, "api_key=do-not-commit\n")
            path = repo_root / "secret-retained.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "api_key",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_multiple_hashes_fail(self) -> None:
        """A retained reference cannot silently carry multiple digests."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "multiple-hashes.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    f"Provider dashboard or export: `{PROVIDER_DASHBOARD_PATH}`",
                    "Provider dashboard or export: "
                    f"`{PROVIDER_DASHBOARD_PATH} / sha256:{'a' * 64} "
                    f"/ sha256:{'b' * 64}`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "multiple sha256",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_drift_fails(self) -> None:
        """Declared retained hashes must match disk contents."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "hash-drift.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    f"Provider dashboard or export: `{PROVIDER_DASHBOARD_PATH}`",
                    f"Provider dashboard or export: `{PROVIDER_DASHBOARD_PATH} / sha256:{'f' * 64}`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "sha256 mismatch",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_trailing_text_fails(self) -> None:
        """Declared retained hashes cannot hide trailing field text."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            dashboard_hash = checker.file_sha256(repo_root / PROVIDER_DASHBOARD_PATH)
            path = repo_root / "hash-trailing-text.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    f"Provider dashboard or export: `{PROVIDER_DASHBOARD_PATH}`",
                    "Provider dashboard or export: "
                    f"`{PROVIDER_DASHBOARD_PATH} / {dashboard_hash} trailing-note`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "trailing text",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_missing_validation_command_fails(self) -> None:
        """Validation command coverage is part of the retained artifact."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-command.md"
            write_text(
                path,
                template_text().replace(
                    "python scripts/check_randomizer_operations.py",
                    "python scripts/check_randomizer_operations_missing.py",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "check_randomizer_operations",
            ):
                checker.validate_artifact(path)

    def test_reviewed_release_manifest_digest_missing_fails(self) -> None:
        """Release manifest/checksum fields must carry a digest."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-release-digest.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "Release manifest/checksum digests: `release-manifest "
                    "sha256:1111111111111111111111111111111111111111111111111111111111111111 "
                    "and SHA256SUMS "
                    "sha256:2222222222222222222222222222222222222222222222222222222222222222`",
                    "Release manifest/checksum digests: `release manifest retained without digest`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "sha256",
            ):
                checker.validate_artifact(path)

    def test_missing_template_argument_fails(self) -> None:
        """The non-local envelope command must use the public-beta template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-template.md"
            write_text(
                path,
                template_text().replace(
                    " --template release-artifacts/evidence/public-beta-templates/"
                    "fork-testnet-randomizer-operations-evidence-template.json",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "fork-testnet-randomizer",
            ):
                checker.validate_artifact(path)

    def test_secret_key_value_fails(self) -> None:
        """Secret-shaped key/value text is not allowed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, template_text() + "\nprovider_dashboard_secret=abc123\n")

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "provider_dashboard_secret",
            ):
                checker.validate_artifact(path)

    def test_private_rpc_url_fails(self) -> None:
        """Provider URLs and unredacted RPC CLI values are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "rpc.md"
            write_text(
                path,
                template_text()
                + "\nforge script Ops --rpc-url https://eth-mainnet.g.alchemy.com/v2/key\n",
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "--rpc-url",
            ):
                checker.validate_artifact(path)

    def test_broad_redacted_rpc_token_fails(self) -> None:
        """RPC placeholders are restricted to documented redaction tokens."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "broad-redacted-rpc.md"
            write_text(
                path,
                template_text()
                + "\nforge script Ops --rpc-url REDACTEDsk_live_abc123\n",
            )

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "--rpc-url",
            ):
                checker.validate_artifact(path)

    def test_redacted_rpc_placeholder_passes(self) -> None:
        """Documented redacted RPC placeholders are allowed in notes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "redacted-rpc.md"
            write_text(
                path,
                template_text()
                + "\nforge script Ops --rpc-url REDACTED_LOCAL_ANVIL_FORK\n",
            )

            checker.validate_artifact(path)

    def test_bare_hex_secret_like_text_fails(self) -> None:
        """Unprefixed 64-hex material is rejected as secret-shaped text."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bare-hex.md"
            write_text(path, template_text() + "\n" + ("a" * 64) + "\n")

            with self.assertRaisesRegex(
                checker.ForkRandomizerOperationsEvidenceError,
                "64-hex",
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
