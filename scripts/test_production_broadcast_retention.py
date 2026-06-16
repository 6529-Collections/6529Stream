#!/usr/bin/env python3
"""Focused tests for production broadcast retention evidence."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_production_broadcast_retention.py")
SPEC = importlib.util.spec_from_file_location(
    "check_production_broadcast_retention", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_template() -> str:
    """Return a valid production broadcast retained-artifact template."""
    return """# Production Broadcast Retention Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `production_broadcast_retention`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Production Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Production block or reference: `TBD`
- Deployment transaction references: `TBD`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --rpc-url <redacted> --broadcast --verify --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `TBD`
- Sanitized Foundry broadcast: `TBD`
- Derived broadcast manifest input: `TBD`
- Generated live deployment manifest: `TBD`
- Generated live address book: `TBD`
- Release manifest/checksum digests: `TBD`

## Broadcast Results

- Broadcast completed: `TBD`
- Manifest input generated: `TBD`
- Deployment manifest generated: `TBD`
- Address book generated: `TBD`
- Transaction references retained: `TBD`

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
python scripts/test_production_broadcast_retention.py
python scripts/check_production_broadcast_retention.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/production-broadcast-retention-template.json --retained-artifact release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md --output release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-evidence.json --environment live --chain-id 1 --block-or-reference "<production block or transaction reference>" --command-or-source-system "<operator transcript>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #226 open until reviewed retained evidence is linked from the shared
  public-beta evidence manifest.
- Do not retain private RPC URLs, private keys, API keys, signing material,
  unreleased drop payloads, or unredacted operator logs in this repository.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# Production Broadcast Retention Retained Artifact

## Evidence Status

- Requirement ID: `production_broadcast_retention`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Production Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `1234567890abcdef1234567890abcdef12345678`
- CI run or operator transcript: `ci-run-123`
- Production block or reference: `mainnet block 12345678`
- Deployment transaction references: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --broadcast --verify --via-ir`

## Required Retained Artifacts

- Sanitized command transcript: `release-artifacts/evidence/production-broadcast-retention/transcript.md`
- Sanitized Foundry broadcast: `deployments/broadcasts/mainnet-6529stream-v0.1.0-001-run-latest.json`
- Derived broadcast manifest input: `deployments/config/mainnet-6529stream-v0.1.0-001-broadcast.json`
- Generated live deployment manifest: `deployments/examples/mainnet-6529stream-v0.1.0-001-broadcast.json`
- Generated live address book: `deployments/address-books/mainnet-6529stream-v0.1.0-001-broadcast.json`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and SHA256SUMS`

## Broadcast Results

- Broadcast completed: `yes`
- Manifest input generated: `yes`
- Deployment manifest generated: `yes`
- Address book generated: `yes`
- Transaction references retained: `yes`

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
python scripts/test_production_broadcast_retention.py
python scripts/check_production_broadcast_retention.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/production-broadcast-retention-template.json --retained-artifact release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-retained-artifact-template.md --output release-artifacts/evidence/production-broadcast-retention/production-broadcast-retention-evidence.json --environment live --chain-id 1 --block-or-reference "mainnet block 12345678" --command-or-source-system "operator transcript" --owner release-operator --reviewer release-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
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
    "release-artifacts/evidence/production-broadcast-retention/transcript.md",
    "deployments/broadcasts/mainnet-6529stream-v0.1.0-001-run-latest.json",
    "deployments/config/mainnet-6529stream-v0.1.0-001-broadcast.json",
    "deployments/examples/mainnet-6529stream-v0.1.0-001-broadcast.json",
    "deployments/address-books/mainnet-6529stream-v0.1.0-001-broadcast.json",
]


def seed_reviewed_retained_files(root: Path, *, secret_text: str | None = None) -> None:
    """Create retained files referenced by reviewed_artifact under a root."""
    for relative_path in REVIEWED_RETAINED_PATHS:
        content = "sanitized retained production broadcast evidence\n"
        if secret_text is not None and relative_path.endswith("transcript.md"):
            content += secret_text
        write_text(root / relative_path, content)


class ProductionBroadcastRetentionTests(unittest.TestCase):
    """Checker behavior for production broadcast retention evidence."""

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

            checker.validate_artifact(path)

    def test_reviewed_failed_result_fields_fail(self) -> None:
        """Reviewed broadcast result fields must affirm successful checks."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-failed-result.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "- Broadcast completed: `yes`",
                    "- Broadcast completed: `no`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ProductionBroadcastRetentionError,
                "Broadcast completed",
            ):
                checker.validate_artifact(path)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        """Reviewed retained artifact references must point to files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-missing-retained-file.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionBroadcastRetentionError,
                "missing retained file",
            ):
                checker.validate_artifact(path)

    def test_missing_heading_fails(self) -> None:
        """Required sections cannot silently disappear."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-heading.md"
            write_text(path, valid_template().replace("## Broadcast Results\n\n", ""))

            with self.assertRaisesRegex(
                checker.ProductionBroadcastRetentionError,
                "Broadcast Results",
            ):
                checker.validate_artifact(path)

    def test_wrong_requirement_fails(self) -> None:
        """The artifact must map only to the production broadcast row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-requirement.md"
            write_text(
                path,
                valid_template().replace(
                    "`production_broadcast_retention`",
                    "`production_address_books`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ProductionBroadcastRetentionError,
                "production_broadcast_retention",
            ):
                checker.validate_artifact(path)

    def test_reviewed_placeholders_fail(self) -> None:
        """Reviewed artifacts cannot retain template placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace("`mainnet block 12345678`", "`TBD`"),
            )

            with self.assertRaisesRegex(
                checker.ProductionBroadcastRetentionError,
                "Production block or reference",
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
                checker.ProductionBroadcastRetentionError,
                "check_public_beta_evidence",
            ):
                checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        """Secret-shaped key/value text is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\napi_key=do-not-commit\n")

            with self.assertRaisesRegex(
                checker.ProductionBroadcastRetentionError,
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
                    "--broadcast --verify --via-ir",
                    "--rpc-url https://eth-mainnet.g.alchemy.com/v2/token "
                    "--private-key 0xabc123 --broadcast --verify --via-ir",
                ),
            )

            with self.assertRaisesRegex(
                checker.ProductionBroadcastRetentionError,
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
                checker.ProductionBroadcastRetentionError,
                "secret-like CLI",
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
