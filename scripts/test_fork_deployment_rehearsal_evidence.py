#!/usr/bin/env python3
"""Focused tests for fork deployment rehearsal retained evidence."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_fork_deployment_rehearsal_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_fork_deployment_rehearsal_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


TRANSCRIPT_PATH = "release-artifacts/evidence/fork/transcript.md"
BROADCAST_PATH = "release-artifacts/evidence/fork/broadcast.json"
DEPLOYMENT_MANIFEST_PATH = "deployments/examples/fork-6529stream-v0.1.0-001.json"
ADDRESS_BOOK_PATH = "deployments/address-books/fork-6529stream-v0.1.0-001.json"
GAS_SUMMARY_PATH = "release-artifacts/evidence/fork/gas-and-invariants.md"


def seed_reviewed_retained_files(root: Path, *, secret_text: str | None = None) -> None:
    """Create retained files referenced by reviewed_artifact under a root."""
    transcript = "sanitized fork deployment rehearsal transcript\n"
    if secret_text is not None:
        transcript += secret_text
    write_text(root / TRANSCRIPT_PATH, transcript)
    write_text(root / BROADCAST_PATH, '{"transactions":[],"receipts":[]}\n')
    write_text(root / DEPLOYMENT_MANIFEST_PATH, '{"deployment":"fork"}\n')
    write_text(root / ADDRESS_BOOK_PATH, '{"contracts":{}}\n')
    write_text(root / GAS_SUMMARY_PATH, "estimated_total_gas_used=32521731\n")


def valid_template() -> str:
    """Return a valid template artifact."""
    return """# Fork Deployment Rehearsal Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `fork_deployment_rehearsal`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Source And Fork Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Fork block number: `TBD`
- Fork block hash: `TBD`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --rpc-url <redacted> --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `TBD`
- Sanitized Foundry broadcast: `TBD`
- Generated deployment manifest: `TBD`
- Generated address book: `TBD`
- Verification status: `TBD`
- Gas or invariant summary: `TBD`
- Release manifest/checksum digests: `TBD`

## Rehearsal Results

- Deployment completed: `TBD`
- Manifest generated: `TBD`
- Address book generated: `TBD`
- Verification checked: `TBD`
- Gas or invariant summary checked: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-deployment-rehearsal-template.json --retained-artifact release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md --output release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-evidence.json --environment fork --chain-id 1 --block-or-reference "<fork block>" --command-or-source-system-from-retained --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #216 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# Fork Deployment Rehearsal Retained Artifact

## Evidence Status

- Requirement ID: `fork_deployment_rehearsal`
- Review status: `reviewed`
- Readiness claim: `complete`
- Environment: `fork`
- Chain ID: `1`

## Source And Fork Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `1234567890abcdef1234567890abcdef12345678`
- CI run or operator transcript: `ci-run-123`
- Fork block number: `19000000`
- Fork block hash: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `release-artifacts/evidence/fork/transcript.md`
- Sanitized Foundry broadcast: `release-artifacts/evidence/fork/broadcast.json`
- Generated deployment manifest: `deployments/examples/fork-6529stream-v0.1.0-001.json`
- Generated address book: `deployments/address-books/fork-6529stream-v0.1.0-001.json`
- Verification status: `checked`
- Gas or invariant summary: `release-artifacts/evidence/fork/gas-and-invariants.md`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and SHA256SUMS`

## Rehearsal Results

- Deployment completed: `yes`
- Manifest generated: `yes`
- Address book generated: `yes`
- Verification checked: `yes`
- Gas or invariant summary checked: `yes`

## Review

- Operator: `release-operator`
- Reviewer: `release-reviewer`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-deployment-rehearsal-template.json --retained-artifact release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md --output release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-evidence.json --environment fork --chain-id 1 --block-or-reference "fork block 19000000" --command-or-source-system-from-retained --owner release-operator --reviewer release-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence can complete this row once linked from the shared
  public-beta evidence manifest.
"""


class ForkDeploymentRehearsalEvidenceTests(unittest.TestCase):
    """Checker behavior for fork deployment rehearsal evidence."""

    def test_committed_template_passes(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_reviewed_artifact_passes(self) -> None:
        """A filled reviewed artifact can pass before manifest linkage."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed.md"
            seed_reviewed_retained_files(root)
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_reviewed_artifact_with_declared_hashes_passes(self) -> None:
        """Declared retained hashes are accepted when they match disk."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-hashed.md"
            seed_reviewed_retained_files(root)
            broadcast_hash = checker.file_sha256(root / BROADCAST_PATH)
            write_text(
                path,
                reviewed_artifact().replace(
                    f"`{BROADCAST_PATH}`",
                    f"`{BROADCAST_PATH} / {broadcast_hash}`",
                ),
            )

            checker.validate_artifact(path)

    def test_missing_heading_fails(self) -> None:
        """Required sections cannot silently disappear."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-heading.md"
            write_text(path, valid_template().replace("## Rehearsal Results\n\n", ""))

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "Rehearsal Results",
            ):
                checker.validate_artifact(path)

    def test_wrong_requirement_fails(self) -> None:
        """The artifact must map only to the fork deployment rehearsal row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-requirement.md"
            write_text(
                path,
                valid_template().replace(
                    "`fork_deployment_rehearsal`", "`testnet_deployment_rehearsal`"
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "fork_deployment_rehearsal",
            ):
                checker.validate_artifact(path)

    def test_reviewed_placeholders_fail(self) -> None:
        """Reviewed artifacts cannot retain template placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-placeholder.md"
            write_text(path, reviewed_artifact().replace("`19000000`", "`TBD`"))

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "Fork block number",
            ):
                checker.validate_artifact(path)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        """Reviewed retained references must point to files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-missing-retained.md"
            seed_reviewed_retained_files(root)
            (root / BROADCAST_PATH).unlink()
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "missing retained file",
            ):
                checker.validate_artifact(path)

    def test_reviewed_retained_parent_path_escape_fails(self) -> None:
        """Reviewed retained paths cannot escape through parent segments."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-parent-escape.md"
            seed_reviewed_retained_files(root)
            write_text(
                path,
                reviewed_artifact().replace(
                    f"`{BROADCAST_PATH}`",
                    "`../broadcast.json`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "repo-relative",
            ):
                checker.validate_artifact(path)

    def test_reviewed_retained_absolute_path_escape_fails(self) -> None:
        """Reviewed retained paths cannot be absolute paths."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-absolute-escape.md"
            seed_reviewed_retained_files(root)
            write_text(
                path,
                reviewed_artifact().replace(
                    f"`{BROADCAST_PATH}`",
                    f"`{root / BROADCAST_PATH}`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "repo-relative",
            ):
                checker.validate_artifact(path)

    def test_referenced_artifact_secret_values_fail(self) -> None:
        """Referenced retained files are scanned for secret-shaped content."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-referenced-secret.md"
            seed_reviewed_retained_files(root, secret_text="api_key=do-not-commit\n")
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "secret-like",
            ):
                checker.validate_artifact(path)

    def test_referenced_artifact_redacted_rpc_placeholder_passes(self) -> None:
        """Reviewed retained files can contain explicit redacted RPC placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-redacted-rpc.md"
            seed_reviewed_retained_files(
                root,
                secret_text="forge script Deploy --rpc-url <redacted local anvil fork>\n",
            )
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_referenced_artifact_uppercase_redacted_rpc_token_passes(self) -> None:
        """The committed REDACTED_LOCAL_ANVIL_FORK placeholder stays accepted."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-uppercase-redacted-rpc.md"
            seed_reviewed_retained_files(
                root,
                secret_text=(
                    "forge script Deploy --rpc-url REDACTED_LOCAL_ANVIL_FORK "
                    "--broadcast\n"
                ),
            )
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_reviewed_retained_multiple_hashes_fail(self) -> None:
        """A retained reference cannot silently carry multiple digests."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-duplicate-hash.md"
            seed_reviewed_retained_files(root)
            write_text(
                path,
                reviewed_artifact().replace(
                    f"`{BROADCAST_PATH}`",
                    (
                        f"`{BROADCAST_PATH} / sha256:{'a' * 64} "
                        f"/ sha256:{'b' * 64}`"
                    ),
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "multiple sha256",
            ):
                checker.validate_artifact(path)

    def test_reviewed_retained_hash_drift_fails(self) -> None:
        """Declared retained hashes must match disk contents."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-stale-hash.md"
            seed_reviewed_retained_files(root)
            write_text(
                path,
                reviewed_artifact().replace(
                    f"`{BROADCAST_PATH}`",
                    f"`{BROADCAST_PATH} / sha256:{'f' * 64}`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "sha256 mismatch",
            ):
                checker.validate_artifact(path)

    def test_missing_validation_command_fails(self) -> None:
        """The template must carry the full validation sequence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-command.md"
            write_text(
                path,
                valid_template().replace(
                    "python scripts/check_public_beta_evidence.py\n", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "check_public_beta_evidence",
            ):
                checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        """Secret-shaped key/value text is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\nrpc_url=https://example.invalid\n")

            with self.assertRaisesRegex(
                checker.ForkDeploymentRehearsalEvidenceError,
                "secret-like",
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
