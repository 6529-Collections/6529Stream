#!/usr/bin/env python3
"""Focused tests for testnet deployment rehearsal retained evidence."""

from __future__ import annotations

import importlib.util
import re
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name(
    "check_testnet_deployment_rehearsal_evidence.py"
)
SPEC = importlib.util.spec_from_file_location(
    "check_testnet_deployment_rehearsal_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_template() -> str:
    """Return a valid testnet deployment retained-artifact template."""
    return """# Testnet Deployment Rehearsal Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `testnet_deployment_rehearsal`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `testnet`
- Testnet name: `sepolia`
- Chain ID: `11155111`

## Source And Testnet Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Testnet block or reference: `TBD`
- Deployment transaction references: `TBD`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --rpc-url <redacted> --broadcast --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `TBD`
- Sanitized Foundry broadcast: `TBD`
- Generated deployment manifest: `TBD`
- Generated address book: `TBD`
- Explorer verification status: `TBD`
- Gas or invariant summary: `TBD`
- Release manifest/checksum digests: `TBD`

## Rehearsal Results

- Deployment completed: `TBD`
- Manifest generated: `TBD`
- Address book generated: `TBD`
- Transaction references retained: `TBD`
- Explorer status checked: `TBD`
- Gas or invariant summary checked: `TBD`

## Review

- Operator: `TBD`
- Reviewer: `TBD`
- Review decision: `template`

## Redaction

- No secrets retained: `TBD`
- Private RPC URLs removed: `TBD`
- Private keys removed: `TBD`
- API keys removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_testnet_deployment_rehearsal_evidence.py
python scripts/check_testnet_deployment_rehearsal_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/testnet-deployment-rehearsal-template.json --retained-artifact release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md --output release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-evidence.json --environment testnet --chain-id 11155111 --block-or-reference "<testnet block or transaction reference>" --command-or-source-system "<operator transcript>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #217 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# Testnet Deployment Rehearsal Retained Artifact

## Evidence Status

- Requirement ID: `testnet_deployment_rehearsal`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `testnet`
- Testnet name: `sepolia`
- Chain ID: `11155111`

## Source And Testnet Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `1234567890abcdef1234567890abcdef12345678`
- CI run or operator transcript: `ci-run-123`
- Testnet block or reference: `sepolia block 1234567`
- Deployment transaction references: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --broadcast --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md`
- Sanitized Foundry broadcast: `deployments/broadcasts/sepolia-6529stream-v0.1.0-001-run-latest.json`
- Generated deployment manifest: `deployments/examples/sepolia-6529stream-v0.1.0-001.json`
- Generated address book: `deployments/address-books/sepolia-6529stream-v0.1.0-001.json`
- Explorer verification status: `verified sources submitted for StreamCore and linked libraries`
- Gas or invariant summary: `release-artifacts/evidence/testnet-deployment-rehearsal/gas-and-invariants.md`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and SHA256SUMS`

## Rehearsal Results

- Deployment completed: `yes`
- Manifest generated: `yes`
- Address book generated: `yes`
- Transaction references retained: `yes`
- Explorer status checked: `yes`
- Gas or invariant summary checked: `yes`

## Review

- Operator: `release-operator`
- Reviewer: `release-reviewer`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- API keys removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_testnet_deployment_rehearsal_evidence.py
python scripts/check_testnet_deployment_rehearsal_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/testnet-deployment-rehearsal-template.json --retained-artifact release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md --output release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-evidence.json --environment testnet --chain-id 11155111 --block-or-reference "sepolia block 1234567" --command-or-source-system "operator transcript" --owner release-operator --reviewer release-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  public-beta evidence manifest.
"""


REVIEWED_RETAINED_PATHS = [
    "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md",
    "deployments/broadcasts/sepolia-6529stream-v0.1.0-001-run-latest.json",
    "deployments/examples/sepolia-6529stream-v0.1.0-001.json",
    "deployments/address-books/sepolia-6529stream-v0.1.0-001.json",
    "release-artifacts/evidence/testnet-deployment-rehearsal/gas-and-invariants.md",
]


def seed_reviewed_retained_files(root: Path, *, secret_text: str | None = None) -> None:
    """Create retained files referenced by reviewed_artifact under a root."""
    for relative_path in REVIEWED_RETAINED_PATHS:
        content = "sanitized retained evidence\n"
        if secret_text is not None and relative_path.endswith("transcript.md"):
            content += secret_text
        write_text(root / relative_path, content)


def artifact_with_field(text: str, label: str, value: str) -> str:
    """Replace one Markdown bullet field value."""
    return re.sub(
        rf"^- {re.escape(label)}: `?[^\n`]*`?$",
        lambda _match: f"- {label}: `{value}`",
        text,
        flags=re.MULTILINE,
    )


class TestnetDeploymentRehearsalEvidenceTests(unittest.TestCase):
    """Checker behavior for testnet deployment rehearsal evidence."""

    def test_committed_template_passes(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_reviewed_artifact_passes(self) -> None:
        """A filled reviewed artifact can pass before manifest linkage."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed.md"
            seed_reviewed_retained_files(Path(temp_dir))
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path, repo_root=Path(temp_dir))

    def test_reviewed_failed_result_fields_fail(self) -> None:
        """Reviewed rehearsal result fields must affirm successful checks."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-failed-result.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "- Deployment completed: `yes`",
                    "- Deployment completed: `no`",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "Deployment completed",
            ):
                checker.validate_artifact(path)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        """Reviewed retained artifact references must point to files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-missing-retained-file.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "missing retained file",
            ):
                checker.validate_artifact(path, repo_root=Path(temp_dir))

    def test_pending_review_retained_files_are_validated(self) -> None:
        """Pending review artifacts also validate retained file references."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "pending-missing-retained-file.md"
            write_text(
                path,
                reviewed_artifact()
                .replace("- Review status: `reviewed`", "- Review status: `pending_review`")
                .replace("- Review decision: `reviewed`", "- Review decision: `pending_review`"),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "missing retained file",
            ):
                checker.validate_artifact(path, repo_root=Path(temp_dir))

    def test_reviewed_artifact_with_declared_hashes_passes(self) -> None:
        """Declared retained hashes are accepted when they match disk."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            transcript_hash = checker.file_sha256(
                repo_root
                / "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md"
            )
            path = repo_root / "reviewed-hashes.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md "
                    f"/ {transcript_hash}",
                ),
            )

            checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_placeholder_fails_clearly(self) -> None:
        """Retained artifact placeholders fail before path resolution."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "placeholder-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "TBD",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "must be replaced before non-template review",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_parent_path_escape_fails(self) -> None:
        """Retained artifact paths cannot escape through parent segments."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "escape-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "../transcript.md",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "escape",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_absolute_path_fails(self) -> None:
        """Retained artifact paths must be repo-relative."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "absolute-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "/tmp/transcript.md",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "repo-relative",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_backslash_path_fails(self) -> None:
        """Retained artifact paths cannot use Windows backslashes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "backslash-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "release-artifacts\\evidence\\testnet-deployment-rehearsal\\transcript.md",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "escape",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_whitespace_path_fails(self) -> None:
        """Retained artifact references must be a single path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "whitespace-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "release-artifacts/evidence/testnet-deployment-rehearsal/transcript copy.md",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "one repo-relative path",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_multiple_hashes_fail(self) -> None:
        """A retained reference cannot silently carry multiple digests."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "multi-hash-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md "
                    f"/ sha256:{'a' * 64} / sha256:{'b' * 64}",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "multiple sha256",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_drift_fails(self) -> None:
        """Declared retained hashes must match disk contents."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            path = repo_root / "hash-drift-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md "
                    f"/ sha256:{'f' * 64}",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "sha256 mismatch",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_without_separator_fails(self) -> None:
        """Declared retained hashes need an explicit path/hash separator."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            transcript_hash = checker.file_sha256(
                repo_root
                / "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md"
            )
            path = repo_root / "hash-no-separator-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md"
                    f"/{transcript_hash}",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "separate path and sha256 digest",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_hash_trailing_text_fails(self) -> None:
        """Declared retained hashes cannot hide trailing field text."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_reviewed_retained_files(repo_root)
            transcript_hash = checker.file_sha256(
                repo_root
                / "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md"
            )
            path = repo_root / "hash-trailing-retained.md"
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(),
                    "Sanitized command transcript",
                    "release-artifacts/evidence/testnet-deployment-rehearsal/transcript.md "
                    f"/ {transcript_hash} unexpected",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "trailing text",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_missing_heading_fails(self) -> None:
        """Required sections cannot silently disappear."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-heading.md"
            write_text(path, valid_template().replace("## Rehearsal Results\n\n", ""))

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "Rehearsal Results",
            ):
                checker.validate_artifact(path)

    def test_wrong_requirement_fails(self) -> None:
        """The artifact must map only to the testnet deployment row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-requirement.md"
            write_text(
                path,
                valid_template().replace(
                    "`testnet_deployment_rehearsal`",
                    "`fork_deployment_rehearsal`",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "testnet_deployment_rehearsal",
            ):
                checker.validate_artifact(path)

    def test_reviewed_placeholders_fail(self) -> None:
        """Reviewed artifacts cannot retain template placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace("`sepolia block 1234567`", "`TBD`"),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "Testnet block or reference",
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
                checker.TestnetDeploymentRehearsalEvidenceError,
                "check_public_beta_evidence",
            ):
                checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        """Secret-shaped key/value text is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\napi_key=do-not-commit\n")

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "secret-like",
            ):
                checker.validate_artifact(path)

    def test_cli_secret_values_fail(self) -> None:
        """CLI-style private key and RPC URL values are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret-cli.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "--broadcast --via-ir",
                    "--rpc-url https://eth-sepolia.g.alchemy.com/v2/token "
                    "--private-key 0xabc123 --broadcast --via-ir",
                ),
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "secret-like CLI",
            ):
                checker.validate_artifact(path)

    def test_referenced_artifact_secret_values_fail(self) -> None:
        """Reviewed retained transcript/broadcast files are scanned too."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-referenced-secret.md"
            seed_reviewed_retained_files(
                Path(temp_dir),
                secret_text="--private-key 0xabc123\n",
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "secret-like CLI",
            ):
                checker.validate_artifact(path, repo_root=Path(temp_dir))

    def test_credentialed_url_fails(self) -> None:
        """Credentialed URLs are secret-shaped even outside explicit keys."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "credentialed-url.md"
            write_text(
                path,
                valid_template() + "\nhttps://user:pass@example.invalid/path\n",
            )

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "secret-like CLI",
            ):
                checker.validate_artifact(path)

    def test_bare_hex_secret_like_text_fails(self) -> None:
        """Unprefixed 64-hex strings are treated as secret-shaped material."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bare-hex.md"
            write_text(path, valid_template() + f"\n{'a' * 64}\n")

            with self.assertRaisesRegex(
                checker.TestnetDeploymentRehearsalEvidenceError,
                "bare 64-hex",
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
