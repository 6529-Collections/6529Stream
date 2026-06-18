#!/usr/bin/env python3
"""Focused tests for public-beta verified-address evidence."""

from __future__ import annotations

import importlib.util
import json
import re
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_public_beta_verified_addresses.py")
SPEC = importlib.util.spec_from_file_location(
    "check_public_beta_verified_addresses", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

TEMPLATE_PATH = checker.DEFAULT_REPO_ROOT / checker.DEFAULT_EVIDENCE_RELATIVE
ADDRESS_BOOK_PATH = "deployments/address-books/sepolia-6529stream-v0.1.0-001.json"
DEPLOYMENT_MANIFEST_PATH = "deployments/examples/sepolia-6529stream-v0.1.0-001.json"
SOURCE_VERIFICATION_PATH = "release-artifacts/latest/source-verification-inputs.json"
EXPLORER_EVIDENCE_PATH = (
    "release-artifacts/evidence/public-beta-verified-addresses/explorer-verification.json"
)
BYTECODE_PROOF_PATH = "release-artifacts/latest/bytecode-release-proof.json"
RELEASE_DIGESTS_PATH = (
    "release-artifacts/evidence/public-beta-verified-addresses/release-digests.md"
)
STREAM_CORE_ADDRESS = "0x1111111111111111111111111111111111111111"
STREAM_CORE_RUNTIME_HASH = "0x" + "ab" * 32


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def artifact_with_field(text: str, label: str, value: str) -> str:
    """Replace one Markdown bullet field value."""
    return re.sub(
        rf"^- {re.escape(label)}: .*$",
        lambda _match: f"- {label}: `{value}`",
        text,
        count=1,
        flags=re.MULTILINE,
    )


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# Public Beta Verified Addresses Retained Artifact

## Evidence Status

- Requirement ID: `public_beta_verified_addresses`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `testnet`
- Chain ID: `11155111`

## Source And Public Beta Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `1234567890abcdef1234567890abcdef12345678`
- CI run or operator transcript: `ci-run-123`
- Public beta block or reference: `sepolia block 12345678`
- Network and deployment version: `sepolia-6529stream-v0.1.0-001`

## Required Retained Artifacts

- Generated public-beta address book: `deployments/address-books/sepolia-6529stream-v0.1.0-001.json`
- Generated public-beta deployment manifest: `deployments/examples/sepolia-6529stream-v0.1.0-001.json`
- Source verification inputs: `release-artifacts/latest/source-verification-inputs.json`
- Explorer verification evidence: `release-artifacts/evidence/public-beta-verified-addresses/explorer-verification.json`
- Bytecode release proof: `release-artifacts/latest/bytecode-release-proof.json`
- Release manifest/checksum digests: `release-artifacts/evidence/public-beta-verified-addresses/release-digests.md`

## Verified Address Results

- Address book covers public-beta deployment: `yes`
- Explorer source verification confirmed: `yes`
- Runtime bytecode matches release proof: `yes`
- Constructor arguments verified: `yes`
- Linked libraries verified: `yes`
- Common explorer/indexer links retained: `yes`

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
python scripts/test_public_beta_verified_addresses.py
python scripts/check_public_beta_verified_addresses.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/verified-deployed-addresses-template.json --retained-artifact release-artifacts/evidence/public-beta-verified-addresses/public-beta-verified-addresses-retained-artifact-template.md --output release-artifacts/evidence/public-beta-verified-addresses/verified-deployed-addresses-evidence.json --environment testnet --chain-id 11155111 --block-or-reference "sepolia block 12345678" --command-or-source-system "operator transcript" --owner release-operator --reviewer release-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  public-beta evidence manifest.
"""


def pending_review_artifact() -> str:
    """Return a valid pending-review retained artifact."""
    return reviewed_artifact().replace(
        "- Review status: `reviewed`",
        "- Review status: `pending_review`",
    ).replace(
        "- Review decision: `reviewed`",
        "- Review decision: `pending_review`",
    )


def seed_reviewed_files(root: Path, *, chain_id: int = 11155111) -> None:
    """Create retained files referenced by reviewed public-beta evidence."""
    address_book = {
        "network": {"chain_id": chain_id, "name": "sepolia"},
        "contracts": {
            "StreamCore": {
                "address": STREAM_CORE_ADDRESS,
                "runtime_bytecode_hash": STREAM_CORE_RUNTIME_HASH,
            }
        },
    }
    deployment_manifest = {
        "network": {"chain_id": chain_id, "name": "sepolia"},
        "contracts": {
            "StreamCore": {
                "address": STREAM_CORE_ADDRESS,
                "runtime_bytecode_hash": STREAM_CORE_RUNTIME_HASH,
            }
        },
    }
    explorer_evidence = {
        "contracts": {
            "StreamCore": {
                "address": STREAM_CORE_ADDRESS,
                "explorer_status": "verified",
                "explorer_url": "https://sepolia.etherscan.io/address/"
                + STREAM_CORE_ADDRESS,
            }
        }
    }
    bytecode_proof = {
        "contract_proofs": [
            {
                "contract": {"name": "StreamCore", "address": STREAM_CORE_ADDRESS},
                "hashes": {"runtime_bytecode": STREAM_CORE_RUNTIME_HASH},
            }
        ]
    }

    write_json(root / ADDRESS_BOOK_PATH, address_book)
    write_json(root / DEPLOYMENT_MANIFEST_PATH, deployment_manifest)
    write_json(root / SOURCE_VERIFICATION_PATH, {"schema_version": "test"})
    write_json(root / EXPLORER_EVIDENCE_PATH, explorer_evidence)
    write_json(root / BYTECODE_PROOF_PATH, bytecode_proof)
    write_text(root / RELEASE_DIGESTS_PATH, f"sha256:{'a' * 64} release digests\n")


class PublicBetaVerifiedAddressesTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        checker.validate_artifact(TEMPLATE_PATH, checker.DEFAULT_REPO_ROOT)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root)
            path = root / "reviewed-public-beta-addresses.md"
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_pending_review_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root)
            path = root / "pending-public-beta-addresses.md"
            write_text(path, pending_review_artifact())

            checker.validate_artifact(path)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Explorer verification evidence",
                "release-artifacts/evidence/public-beta-verified-addresses/missing.json",
            )
            path = root / "missing.md"
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.PublicBetaVerifiedAddressesError, "missing retained file"
            ):
                checker.validate_artifact(path)

    def test_reviewed_stale_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root)
            text = artifact_with_field(
                reviewed_artifact(),
                "Release manifest/checksum digests",
                f"{RELEASE_DIGESTS_PATH} sha256:{'0' * 64}",
            )
            path = root / "stale-hash.md"
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.PublicBetaVerifiedAddressesError, "sha256 mismatch"
            ):
                checker.validate_artifact(path)

    def test_reviewed_wrong_chain_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root, chain_id=1)
            path = root / "wrong-chain.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.PublicBetaVerifiedAddressesError, "chain ID 11155111"
            ):
                checker.validate_artifact(path)

    def test_reviewed_wrong_environment_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root)
            path = root / "wrong-environment.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "- Environment: `testnet`",
                    "- Environment: `live`",
                ),
            )

            with self.assertRaisesRegex(
                checker.PublicBetaVerifiedAddressesError, "Environment"
            ):
                checker.validate_artifact(path)

    def test_reviewed_unverified_explorer_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root)
            explorer = {
                "contracts": {
                    "StreamCore": {
                        "address": STREAM_CORE_ADDRESS,
                        "explorer_status": "pending",
                        "explorer_url": "https://sepolia.etherscan.io/address/"
                        + STREAM_CORE_ADDRESS,
                    }
                }
            }
            write_json(root / EXPLORER_EVIDENCE_PATH, explorer)
            path = root / "unverified.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.PublicBetaVerifiedAddressesError, "explorer status"
            ):
                checker.validate_artifact(path)

    def test_reviewed_secret_retained_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root)
            write_text(root / RELEASE_DIGESTS_PATH, "--rpc-url https://alchemy.example/key\n")
            path = root / "secret.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.PublicBetaVerifiedAddressesError, "secret-like"
            ):
                checker.validate_artifact(path)

    def test_reviewed_template_notice_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_reviewed_files(root)
            path = root / "template-notice.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "## Evidence Status",
                    "> Template only. This file is not completion evidence.\n\n## Evidence Status",
                ),
            )

            with self.assertRaisesRegex(
                checker.PublicBetaVerifiedAddressesError, "template-only notice"
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
