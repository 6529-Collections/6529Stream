#!/usr/bin/env python3
"""Focused tests for fork/testnet ceremony retained evidence."""

from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_fork_ceremony_evidence.py")
SPEC = importlib.util.spec_from_file_location("check_fork_ceremony_evidence", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_template() -> str:
    """Return a valid fork/testnet ceremony retained-artifact template."""
    return """# Fork/Testnet Ceremony Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `fork_testnet_ceremony_evidence`
- Evidence type: `fork_testnet_ceremony_evidence`
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
- Command: `TBD`

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

- Deployment manifest: `TBD`
- Address book: `TBD`
- Safe or multisig export: `TBD`
- Explorer or fork transaction bundle: `TBD`
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
- API keys removed: `TBD`
- Signer-service secrets removed: `TBD`
- Unreleased drop payloads removed: `TBD`

## Validation Commands

```sh
python scripts/test_fork_ceremony_evidence.py
python scripts/check_fork_ceremony_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-ceremony-evidence-template.json --retained-artifact release-artifacts/evidence/fork-ceremony/fork-ceremony-retained-artifact-template.md --output release-artifacts/evidence/fork-ceremony/fork-ceremony-evidence.json --environment fork --chain-id 1 --block-or-reference "<fork/testnet block, Safe transaction set, or ceremony transcript reference>" --command-or-source-system-from-retained --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed fork ceremony artifact."""
    return """# Fork/Testnet Ceremony Retained Artifact

## Evidence Status

- Requirement ID: `fork_testnet_ceremony_evidence`
- Evidence type: `fork_testnet_ceremony_evidence`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `fork`
- Chain ID: `1`

## Fork/Testnet Deployment Context

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `1234567890abcdef1234567890abcdef12345678`
- CI run or operator transcript: `ci-run-123`
- Fork/testnet block or reference: `fork block 25316366`
- Network and deployment version: `fork-mainnet-6529stream-v0.1.0-001`
- Command: `forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --rpc-url REDACTED_LOCAL_ANVIL_FORK --broadcast --unlocked --via-ir`

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
- Metadata and freeze ceremony: `release-artifacts/evidence/fork-ceremony/metadata.md`
- Auction ceremony: `release-artifacts/evidence/fork-ceremony/auction.md`
- Emergency controls ceremony: `release-artifacts/evidence/fork-ceremony/emergency.md`

## Dry Runs And Monitoring

- Dry-run mint evidence: `release-artifacts/evidence/fork-ceremony/mint.md`
- Dry-run auction evidence: `release-artifacts/evidence/fork-ceremony/auction-dry-run.md`
- Monitoring handoff: `release-artifacts/evidence/fork-ceremony/monitoring.md`

## Required Retained Artifacts

- Deployment manifest: `deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`
- Address book: `deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`
- Safe or multisig export: `release-artifacts/evidence/fork-ceremony/safe-export.json`
- Explorer or fork transaction bundle: `release-artifacts/evidence/fork-ceremony/fork-transactions.json`
- Post-state views: `release-artifacts/evidence/fork-ceremony/post-state.md`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and SHA256SUMS`

## Review

- Operator: `release-operator`
- Reviewer: `release-reviewer`
- Review decision: `reviewed`

## Redaction

- No secrets retained: `yes`
- Private RPC URLs removed: `yes`
- Private keys removed: `yes`
- API keys removed: `yes`
- Signer-service secrets removed: `yes`
- Unreleased drop payloads removed: `yes`

## Validation Commands

```sh
python scripts/test_fork_ceremony_evidence.py
python scripts/check_fork_ceremony_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-ceremony-evidence-template.json --retained-artifact release-artifacts/evidence/fork-ceremony/fork-ceremony-retained-artifact-template.md --output release-artifacts/evidence/fork-ceremony/fork-ceremony-evidence.json --environment fork --chain-id 1 --block-or-reference "fork block 25316366" --command-or-source-system-from-retained --owner release-operator --reviewer release-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  public-beta evidence manifest.
"""


RETAINED_PATHS = [
    "deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "release-artifacts/evidence/fork-ceremony/safe-export.json",
    "release-artifacts/evidence/fork-ceremony/fork-transactions.json",
    "release-artifacts/evidence/fork-ceremony/post-state.md",
]


def seed_retained_paths(repo_root: Path, *, omit: str | None = None) -> None:
    """Create clean retained files referenced by the reviewed fixture."""
    for retained_path in RETAINED_PATHS:
        if retained_path == omit:
            continue
        write_text(
            repo_root / retained_path,
            f"retained fork ceremony evidence for {retained_path}\n",
        )


class ForkCeremonyEvidenceTests(unittest.TestCase):
    """Checker behavior for fork/testnet ceremony evidence."""

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
        """Requirement ID is fixed to fork/testnet ceremony evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong.md"
            write_text(
                path,
                valid_template().replace(
                    "`fork_testnet_ceremony_evidence`",
                    "`fork_testnet_randomizer_operations_evidence`",
                    1,
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkCeremonyEvidenceError, "fork_testnet_ceremony_evidence"
            ):
                checker.validate_artifact(path)

    def test_unsupported_environment_fails(self) -> None:
        """Only fork and testnet environments are valid."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "live.md"
            write_text(path, valid_template().replace("- Environment: `fork`", "- Environment: `live`"))

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "fork"):
                checker.validate_artifact(path)

    def test_leading_zero_chain_id_fails(self) -> None:
        """Chain IDs are positive decimal values without leading zeroes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "chain.md"
            write_text(path, valid_template().replace("- Chain ID: `1`", "- Chain ID: `01`"))

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "Chain ID"):
                checker.validate_artifact(path)

    def test_reviewed_placeholder_fails(self) -> None:
        """Reviewed artifacts must replace placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "`fork-mainnet-6529stream-v0.1.0-001`", "`TBD`"
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkCeremonyEvidenceError, "Network and deployment version"
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
                checker.ForkCeremonyEvidenceError, "advance the review decision"
            ):
                checker.validate_artifact(path)

    def test_bad_address_fails(self) -> None:
        """Governance participant fields must be addresses after template state."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-address.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "Deployer: `0x0000000000000000000000000000000000006537`",
                    "Deployer: `release-operator`",
                ),
            )

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "Deployer"):
                checker.validate_artifact(path)

    def test_reviewed_missing_retained_path_fails(self) -> None:
        """Reviewed retained artifact references must point at existing files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            missing = "release-artifacts/evidence/fork-ceremony/post-state.md"
            seed_retained_paths(repo_root, omit=missing)
            path = repo_root / "missing-retained.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ForkCeremonyEvidenceError, "Post-state views"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_path_escape_fails(self) -> None:
        """Retained artifact references cannot escape the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "escape-retained.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "Post-state views: `release-artifacts/evidence/fork-ceremony/post-state.md`",
                    "Post-state views: `../post-state.md`",
                ),
            )

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "escape"):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_absolute_retained_path_fails(self) -> None:
        """Retained artifact references must be repo-relative paths."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            path = repo_root / "absolute-retained.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "Post-state views: `release-artifacts/evidence/fork-ceremony/post-state.md`",
                    "Post-state views: `/tmp/post-state.md`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkCeremonyEvidenceError, "repo-relative"
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_file_secret_fails(self) -> None:
        """Secret-shaped text inside referenced retained files is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            write_text(
                repo_root / "release-artifacts/evidence/fork-ceremony/post-state.md",
                "private_key=abc123\n",
            )
            path = repo_root / "secret-retained.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "private_key"):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_file_allows_sha256_digest(self) -> None:
        """Explicit sha256 digests in retained files are not secret-shaped text."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            write_text(
                repo_root / "release-artifacts/evidence/fork-ceremony/post-state.md",
                "retained digest sha256:" + ("a" * 64) + "\n",
            )
            path = repo_root / "digest-retained.md"
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path, repo_root=repo_root)

    def test_reviewed_retained_file_bare_64_hex_fails(self) -> None:
        """Bare 64-hex values in retained files still fail closed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            seed_retained_paths(repo_root)
            write_text(
                repo_root / "release-artifacts/evidence/fork-ceremony/post-state.md",
                "retained digest " + ("a" * 64) + "\n",
            )
            path = repo_root / "bare-digest-retained.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ForkCeremonyEvidenceError,
                "bare 64-hex",
            ):
                checker.validate_artifact(path, repo_root=repo_root)

    def test_missing_validation_command_fails(self) -> None:
        """Validation command coverage is part of the retained artifact."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-command.md"
            write_text(
                path,
                valid_template().replace(
                    "python scripts/check_public_beta_evidence.py\n", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkCeremonyEvidenceError, "check_public_beta_evidence"
            ):
                checker.validate_artifact(path)

    def test_missing_template_argument_fails(self) -> None:
        """The non-local envelope command must use the public-beta template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-template.md"
            write_text(
                path,
                valid_template().replace(
                    " --template release-artifacts/evidence/public-beta-templates/"
                    "fork-testnet-ceremony-evidence-template.json",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.ForkCeremonyEvidenceError, "fork-testnet-ceremony"
            ):
                checker.validate_artifact(path)

    def test_secret_key_value_fails(self) -> None:
        """Secret-shaped key/value text is not allowed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\nprivate_key=abc123\n")

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "private_key"):
                checker.validate_artifact(path)

    def test_private_rpc_url_fails(self) -> None:
        """Provider URLs and unredacted RPC CLI values are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "rpc.md"
            write_text(
                path,
                valid_template()
                + "\nforge script Deploy --rpc-url https://eth-mainnet.g.alchemy.com/v2/key\n",
            )

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "--rpc-url"):
                checker.validate_artifact(path)

    def test_broad_redacted_rpc_token_fails(self) -> None:
        """RPC placeholders are restricted to documented redaction tokens."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "broad-redacted-rpc.md"
            write_text(path, valid_template() + "\nforge script Deploy --rpc-url REDACTEDsk_live_abc123\n")

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "--rpc-url"):
                checker.validate_artifact(path)

    def test_redacted_rpc_placeholder_passes(self) -> None:
        """Redacted RPC placeholders are allowed in operator notes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "redacted-rpc.md"
            write_text(path, valid_template() + "\nforge script Deploy --rpc-url REDACTED_LOCAL_ANVIL_FORK\n")

            checker.validate_artifact(path)

    def test_bare_hex_secret_like_text_fails(self) -> None:
        """Unprefixed 64-hex material is rejected as secret-shaped text."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bare-hex.md"
            write_text(path, valid_template() + "\n" + ("a" * 64) + "\n")

            with self.assertRaisesRegex(checker.ForkCeremonyEvidenceError, "64-hex"):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
