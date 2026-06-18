#!/usr/bin/env python3
"""Focused tests for live deployment-manifest evidence."""

from __future__ import annotations

import importlib.util
import json
import re
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_live_deployment_manifest_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_live_deployment_manifest_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


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


def valid_template() -> str:
    """Return a valid retained-artifact template."""
    return """# Live Deployment Manifest Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `live_deployment_manifest`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Production Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- CI run or operator transcript: `TBD`
- Production block or reference: `TBD`
- Network and deployment version: `TBD`
- Command or source system: `TBD`

## Required Retained Artifacts

- Broadcast manifest input: `TBD`
- Generated live deployment manifest: `TBD`
- Generated live address book: `TBD`
- Source verification inputs: `TBD`
- Release manifest/checksum digests: `TBD`

## Deployment Manifest Results

- Manifest generated from production inputs: `TBD`
- Chain ID matches live: `TBD`
- Contract addresses finalized: `TBD`
- Runtime bytecode hashes retained: `TBD`
- Constructor arguments retained: `TBD`
- Release digest references retained: `TBD`

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
python scripts/test_live_deployment_manifest_evidence.py
python scripts/check_live_deployment_manifest_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-deployment-manifest-template.json --retained-artifact release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-retained-artifact-template.md --output release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-evidence.json --environment live --chain-id 1 --block-or-reference "<production block, deployment version, or manifest reference>" --command-or-source-system "<operator transcript or manifest generator source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #227 open until reviewed retained evidence is linked from the shared
  production-release evidence manifest.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# Live Deployment Manifest Retained Artifact

## Evidence Status

- Requirement ID: `live_deployment_manifest`
- Review status: `reviewed`
- Readiness claim: `blocked`
- Environment: `live`
- Chain ID: `1`

## Source And Production Reference

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `1234567890abcdef1234567890abcdef12345678`
- CI run or operator transcript: `ci-run-123`
- Production block or reference: `mainnet block 12345678`
- Network and deployment version: `mainnet-6529stream-v0.1.0-001`
- Command or source system: `deployment manifest generator transcript`

## Required Retained Artifacts

- Broadcast manifest input: `deployments/config/mainnet-6529stream-v0.1.0-001-broadcast.json`
- Generated live deployment manifest: `deployments/examples/mainnet-6529stream-v0.1.0-001.json`
- Generated live address book: `deployments/address-books/mainnet-6529stream-v0.1.0-001.json`
- Source verification inputs: `release-artifacts/latest/source-verification-inputs.json`
- Release manifest/checksum digests: `release-artifacts/evidence/live-deployment-manifest/release-digests.md`

## Deployment Manifest Results

- Manifest generated from production inputs: `yes`
- Chain ID matches live: `yes`
- Contract addresses finalized: `yes`
- Runtime bytecode hashes retained: `yes`
- Constructor arguments retained: `yes`
- Release digest references retained: `yes`

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
python scripts/test_live_deployment_manifest_evidence.py
python scripts/check_live_deployment_manifest_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/live-deployment-manifest-template.json --retained-artifact release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-retained-artifact-template.md --output release-artifacts/evidence/live-deployment-manifest/live-deployment-manifest-evidence.json --environment live --chain-id 1 --block-or-reference "mainnet block 12345678" --command-or-source-system "deployment manifest generator transcript" --owner release-operator --reviewer release-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  production-release evidence manifest.
"""


def contract_records(
    *, address: str = "0x1111111111111111111111111111111111111111"
) -> dict[str, object]:
    """Return compact contract records used by retained fixtures."""
    return {
        "StreamCore": {
            "address": address,
            "constructor_args": ["6529 Stream", "STREAM"],
            "abi_hash": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
            "bytecode_hash": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "verification_status": "verified",
        },
        "StreamDrops": {
            "address": "0x2222222222222222222222222222222222222222",
            "constructor_args": ["0x1111111111111111111111111111111111111111"],
            "abi_hash": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
            "bytecode_hash": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            "verification_status": "verified",
        },
    }


def seed_reviewed_retained_files(
    root: Path,
    *,
    manifest_chain_id: int = 1,
    manifest_network: str = "mainnet",
    deployment_version: str = "mainnet-6529stream-v0.1.0-001",
    manifest_core_address: str = "0x1111111111111111111111111111111111111111",
    address_book_core_address: str = "0x1111111111111111111111111111111111111111",
    release_digests: str | None = None,
    secret_text: str | None = None,
) -> None:
    """Create retained files referenced by reviewed_artifact under a root."""
    manifest = {
        "manifest_schema_version": "6529stream.deployment-manifest.v1",
        "protocol_version": "0.1.0",
        "deployment_version": deployment_version,
        "lifecycle_state": "Deployed",
        "network": {"name": manifest_network, "chain_id": manifest_chain_id},
        "contracts": contract_records(address=manifest_core_address),
    }
    address_book = {
        "schema_version": "6529stream.address-book.v1",
        "network": {"name": "mainnet", "chain_id": 1},
        "contracts": contract_records(address=address_book_core_address),
    }
    write_json(
        root / "deployments/config/mainnet-6529stream-v0.1.0-001-broadcast.json",
        {"network": {"name": "mainnet", "chain_id": 1}},
    )
    write_json(root / "deployments/examples/mainnet-6529stream-v0.1.0-001.json", manifest)
    write_json(
        root / "deployments/address-books/mainnet-6529stream-v0.1.0-001.json",
        address_book,
    )
    write_json(root / "release-artifacts/latest/source-verification-inputs.json", {"inputs": []})
    write_text(
        root / "release-artifacts/evidence/live-deployment-manifest/release-digests.md",
        release_digests
        or (
            "release manifest sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
            "SHA256SUMS sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n"
        ),
    )
    if secret_text is not None:
        write_text(root / "release-artifacts/latest/source-verification-inputs.json", secret_text)


class LiveDeploymentManifestEvidenceTests(unittest.TestCase):
    """Checker behavior for live deployment-manifest evidence."""

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

            checker.validate_artifact(path, root)

    def test_pending_review_artifact_passes(self) -> None:
        """Pending-review evidence can validate before final approval."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "pending.md"
            seed_reviewed_retained_files(root)
            artifact = reviewed_artifact().replace(
                "- Review status: `reviewed`", "- Review status: `pending_review`"
            ).replace("- Review decision: `reviewed`", "- Review decision: `pending_review`")
            write_text(path, artifact)

            checker.validate_artifact(path, root)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        """Reviewed retained artifact references must point to files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "reviewed-missing-file.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "missing retained file",
            ):
                checker.validate_artifact(path, root)

    def test_path_escape_fails(self) -> None:
        """Retained artifact references cannot escape the repo root."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "escape.md"
            seed_reviewed_retained_files(root)
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(), "Generated live deployment manifest", "../manifest.json"
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "must not escape",
            ):
                checker.validate_artifact(path, root)

    def test_declared_sha256_must_match(self) -> None:
        """Optional retained-file sha256 digests cannot drift."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "stale-digest.md"
            seed_reviewed_retained_files(root)
            bad = (
                "deployments/examples/mainnet-6529stream-v0.1.0-001.json "
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
            )
            write_text(
                path,
                artifact_with_field(
                    reviewed_artifact(), "Generated live deployment manifest", bad
                ),
            )

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "stale sha256",
            ):
                checker.validate_artifact(path, root)

    def test_secret_shaped_retained_file_fails(self) -> None:
        """Retained files are scanned for secret-shaped material."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "secret.md"
            seed_reviewed_retained_files(root, secret_text="private_key=abc123\n")
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "secret-like",
            ):
                checker.validate_artifact(path, root)

    @unittest.skipIf(not hasattr(Path, "symlink_to"), "symlinks unavailable")
    def test_symlinked_retained_file_fails(self) -> None:
        """Reviewed retained files must be ordinary files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "symlink.md"
            seed_reviewed_retained_files(root)
            source = root / "release-artifacts/latest/source-verification-inputs.json"
            source.unlink()
            try:
                source.symlink_to(
                    root / "deployments/config/mainnet-6529stream-v0.1.0-001-broadcast.json"
                )
            except OSError as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "symlinked retained file",
            ):
                checker.validate_artifact(path, root)

    def test_bare_hex_secret_shaped_text_fails(self) -> None:
        """Unlabelled 64-hex material is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "bare-hex.md"
            seed_reviewed_retained_files(
                root,
                release_digests=(
                    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
                    "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n"
                ),
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "bare 64-hex",
            ):
                checker.validate_artifact(path, root)

    def test_release_digests_must_name_manifest_and_checksum_bundle(self) -> None:
        """Release digest evidence must identify the manifest and checksum bundle."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "weak-release-digests.md"
            seed_reviewed_retained_files(
                root,
                release_digests=(
                    "unrelated artifact "
                    "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
                    "another artifact "
                    "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n"
                ),
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "release manifest sha256",
            ):
                checker.validate_artifact(path, root)

    def test_manifest_wrong_chain_fails(self) -> None:
        """Reviewed live manifests must be mainnet chain ID 1."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "wrong-chain.md"
            seed_reviewed_retained_files(root, manifest_chain_id=11155111)
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "network.chain_id",
            ):
                checker.validate_artifact(path, root)

    def test_manifest_wrong_network_fails(self) -> None:
        """Reviewed live manifests must identify mainnet, not a fork/testnet."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "wrong-network.md"
            seed_reviewed_retained_files(root, manifest_network="fork-mainnet")
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "network.name",
            ):
                checker.validate_artifact(path, root)

    def test_manifest_deployment_version_must_match_field(self) -> None:
        """The evidence version field must match the retained manifest."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "wrong-version.md"
            seed_reviewed_retained_files(root, deployment_version="mainnet-other")
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "deployment_version",
            ):
                checker.validate_artifact(path, root)

    def test_address_book_mismatch_fails(self) -> None:
        """Address book records must agree with the live manifest."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "address-mismatch.md"
            seed_reviewed_retained_files(
                root,
                address_book_core_address="0x3333333333333333333333333333333333333333",
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "address mismatch",
            ):
                checker.validate_artifact(path, root)

    def test_manifest_zero_address_fails(self) -> None:
        """Live manifests cannot finalize zero contract addresses."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "zero-address.md"
            seed_reviewed_retained_files(
                root,
                manifest_core_address="0x0000000000000000000000000000000000000000",
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "zero address",
            ):
                checker.validate_artifact(path, root)

    def test_manifest_duplicate_contract_names_fail(self) -> None:
        """List-form live manifests cannot silently collapse duplicate names."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "duplicate-contract-name.md"
            seed_reviewed_retained_files(root)
            manifest_path = (
                root / "deployments/examples/mainnet-6529stream-v0.1.0-001.json"
            )
            first = {
                "name": "StreamCore",
                "address": "0x1111111111111111111111111111111111111111",
                "constructor_args": ["6529 Stream", "STREAM"],
                "bytecode_hash": (
                    "sha256:"
                    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                ),
            }
            second = {
                "name": "StreamCore",
                "address": "0x2222222222222222222222222222222222222222",
                "constructor_args": ["0x1111111111111111111111111111111111111111"],
                "bytecode_hash": (
                    "sha256:"
                    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                ),
            }
            write_json(
                manifest_path,
                {
                    "manifest_schema_version": "6529stream.deployment-manifest.v1",
                    "protocol_version": "0.1.0",
                    "deployment_version": "mainnet-6529stream-v0.1.0-001",
                    "lifecycle_state": "Deployed",
                    "network": {"name": "mainnet", "chain_id": 1},
                    "contracts": [first, second],
                },
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "duplicates contract name",
            ):
                checker.validate_artifact(path, root)

    def test_reviewed_tbd_reviewer_fails(self) -> None:
        """Reviewed evidence must name a real reviewer."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "tbd-reviewer.md"
            seed_reviewed_retained_files(root)
            write_text(path, artifact_with_field(reviewed_artifact(), "Reviewer", "TBD"))

            with self.assertRaisesRegex(
                checker.LiveDeploymentManifestEvidenceError,
                "Reviewer",
            ):
                checker.validate_artifact(path, root)

    def test_main_reports_failure(self) -> None:
        """The CLI reports validation failures and returns non-zero."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "bad.md"
            write_text(path, valid_template().replace("- Chain ID: `1`", "- Chain ID: `5`"))
            stdout = StringIO()
            stderr = StringIO()

            with redirect_stdout(stdout), redirect_stderr(stderr):
                result = checker.main(["--repo-root", str(root), str(path)])

            self.assertEqual(result, 1)
            self.assertIn("live deployment manifest evidence check failed", stderr.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
