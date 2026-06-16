#!/usr/bin/env python3
"""Focused tests for production verified-address evidence."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_production_verified_addresses.py")
SPEC = importlib.util.spec_from_file_location(
    "check_production_verified_addresses", SCRIPT_PATH
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


def valid_template() -> str:
    """Return a valid production verified-addresses retained-artifact template."""
    return """# Production Verified Addresses Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `production_verified_addresses`
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

## Required Retained Artifacts

- Generated live address book: `TBD`
- Generated live deployment manifest: `TBD`
- Source verification inputs: `TBD`
- Explorer verification evidence: `TBD`
- Bytecode release proof: `TBD`
- Release manifest/checksum digests: `TBD`

## Verified Address Results

- Address book covers live deployment: `TBD`
- Explorer source verification confirmed: `TBD`
- Runtime bytecode matches release proof: `TBD`
- Constructor arguments verified: `TBD`
- Linked libraries verified: `TBD`
- Common explorer/indexer links retained: `TBD`

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
python scripts/test_production_verified_addresses.py
python scripts/check_production_verified_addresses.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/production-address-books-template.json --retained-artifact release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md --output release-artifacts/evidence/production-verified-addresses/production-address-books-evidence.json --environment live --chain-id 1 --block-or-reference "<production block, deployment version, or address-book reference>" --command-or-source-system "<operator transcript or explorer verification source>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<ci run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep #227 and #228 open until reviewed retained evidence is linked from the
  shared production-release evidence manifest rows for production address books
  and live explorer verification.
- Generate separate non-local evidence envelopes for each production
  requirement row that reuses this reviewed retained artifact.
- Do not retain private RPC URLs, private keys, API keys, signing material,
  unreleased drop payloads, or unredacted operator logs in this repository.
- Replace private RPC or provider URLs with `<redacted>` before review; the
  checker fails closed on provider/API-token-shaped URLs.
"""


def reviewed_artifact() -> str:
    """Return a valid reviewed retained artifact."""
    return """# Production Verified Addresses Retained Artifact

## Evidence Status

- Requirement ID: `production_verified_addresses`
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

## Required Retained Artifacts

- Generated live address book: `deployments/address-books/mainnet-6529stream-v0.1.0-001.json`
- Generated live deployment manifest: `deployments/examples/mainnet-6529stream-v0.1.0-001.json`
- Source verification inputs: `release-artifacts/latest/source-verification-inputs.json`
- Explorer verification evidence: `release-artifacts/evidence/production-verified-addresses/explorer-verification.json`
- Bytecode release proof: `release-artifacts/latest/bytecode-release-proof.json`
- Release manifest/checksum digests: `release-artifacts/latest/release-manifest.json and SHA256SUMS`

## Verified Address Results

- Address book covers live deployment: `yes`
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
python scripts/test_production_verified_addresses.py
python scripts/check_production_verified_addresses.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/production-release-templates/production-address-books-template.json --retained-artifact release-artifacts/evidence/production-verified-addresses/production-verified-addresses-retained-artifact-template.md --output release-artifacts/evidence/production-verified-addresses/production-address-books-evidence.json --environment live --chain-id 1 --block-or-reference "mainnet block 12345678" --command-or-source-system "operator transcript" --owner release-operator --reviewer release-reviewer --source-git-commit 1234567890abcdef1234567890abcdef12345678 --source-ci-run ci-run-123
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Reviewed retained evidence remains blocked until linked from the shared
  production-release evidence manifest.
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


ADDRESS_BOOK_PATH = "deployments/address-books/mainnet-6529stream-v0.1.0-001.json"
DEPLOYMENT_MANIFEST_PATH = "deployments/examples/mainnet-6529stream-v0.1.0-001.json"
SOURCE_VERIFICATION_PATH = "release-artifacts/latest/source-verification-inputs.json"
EXPLORER_EVIDENCE_PATH = (
    "release-artifacts/evidence/production-verified-addresses/explorer-verification.json"
)
BYTECODE_PROOF_PATH = "release-artifacts/latest/bytecode-release-proof.json"


def contract_records(*, address: str = "0x1111111111111111111111111111111111111111") -> dict[str, object]:
    """Return compact contract records used by address-book and manifest fixtures."""
    return {
        "StreamCore": {
            "address": address,
            "source": "smart-contracts/StreamCore.sol",
            "runtime_bytecode_hash": "sha256:abc",
            "verification_status": "verified",
        },
        "StreamDrops": {
            "address": "0x2222222222222222222222222222222222222222",
            "source": "smart-contracts/StreamDrops.sol",
            "runtime_bytecode_hash": "sha256:def",
            "verification_status": "verified",
        },
    }


def seed_reviewed_retained_files(
    root: Path,
    *,
    manifest_core_address: str = "0x1111111111111111111111111111111111111111",
    explorer_core_address: str = "0x1111111111111111111111111111111111111111",
    explorer_status: str = "verified",
    secret_text: str | None = None,
) -> None:
    """Create retained files referenced by reviewed_artifact under a root."""
    address_book = {
        "schema_version": "6529stream.address-book.v1",
        "network": {"name": "mainnet", "chain_id": 1},
        "contracts": contract_records(),
    }
    manifest = {
        "manifest_schema_version": "6529stream.deployment-manifest.v1",
        "network": {"name": "mainnet", "chain_id": 1},
        "contracts": contract_records(address=manifest_core_address),
    }
    explorer = {
        "schema_version": "6529stream.explorer-verification-evidence.v1",
        "network": {"name": "mainnet", "chain_id": 1},
        "contracts": {
            "StreamCore": {
                "address": explorer_core_address,
                "explorer_status": explorer_status,
                "explorer_url": "https://etherscan.io/address/0x1111111111111111111111111111111111111111",
            },
            "StreamDrops": {
                "address": "0x2222222222222222222222222222222222222222",
                "explorer_status": "verified",
                "explorer_url": "https://etherscan.io/address/0x2222222222222222222222222222222222222222",
            },
        },
    }
    write_json(root / ADDRESS_BOOK_PATH, address_book)
    write_json(root / DEPLOYMENT_MANIFEST_PATH, manifest)
    write_json(root / EXPLORER_EVIDENCE_PATH, explorer)
    write_json(root / SOURCE_VERIFICATION_PATH, {"inputs": []})
    write_json(
        root / BYTECODE_PROOF_PATH,
        {
            "schema_version": "6529stream.bytecode-release-proof.v1",
            "contract_proofs": [
                {
                    "contract": {
                        "name": "StreamCore",
                        "address": manifest_core_address,
                    },
                    "hashes": {"runtime_bytecode": "sha256:abc"},
                },
                {
                    "contract": {
                        "name": "StreamDrops",
                        "address": "0x2222222222222222222222222222222222222222",
                    },
                    "hashes": {"runtime_bytecode": "sha256:def"},
                },
            ],
        },
    )
    if secret_text is not None:
        write_text(root / SOURCE_VERIFICATION_PATH, secret_text)


class ProductionVerifiedAddressesTests(unittest.TestCase):
    """Checker behavior for production verified-address evidence."""

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

    def test_pending_review_validates_payloads(self) -> None:
        """Pending-review evidence validates retained payload shape early."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "pending-review.md"
            seed_reviewed_retained_files(
                Path(temp_dir),
                explorer_status="pending",
            )
            write_text(path, pending_review_artifact())

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "explorer status",
            ):
                checker.validate_artifact(path)

    def test_address_book_manifest_mismatch_fails(self) -> None:
        """Reviewed address evidence fails on address-book/manifest mismatch."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-mismatch.md"
            seed_reviewed_retained_files(
                Path(temp_dir),
                manifest_core_address="0x3333333333333333333333333333333333333333",
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "address mismatch",
            ):
                checker.validate_artifact(path)

    def test_explorer_address_mismatch_fails(self) -> None:
        """Reviewed address evidence fails when explorer address disagrees."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-explorer-mismatch.md"
            seed_reviewed_retained_files(
                Path(temp_dir),
                explorer_core_address="0x3333333333333333333333333333333333333333",
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "explorer address mismatch",
            ):
                checker.validate_artifact(path)

    def test_bytecode_proof_contract_mismatch_fails(self) -> None:
        """Reviewed address evidence fails on unrelated bytecode proof rows."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-bytecode-mismatch.md"
            seed_reviewed_retained_files(Path(temp_dir))
            proof_path = Path(temp_dir) / BYTECODE_PROOF_PATH
            proof = json.loads(proof_path.read_text(encoding="utf-8"))
            proof["contract_proofs"][0]["contract"]["address"] = (
                "0x3333333333333333333333333333333333333333"
            )
            write_json(proof_path, proof)
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "bytecode proof does not match",
            ):
                checker.validate_artifact(path)

    def test_invalid_address_fails(self) -> None:
        """Retained JSON address values must be 20-byte address strings."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-invalid-address.md"
            seed_reviewed_retained_files(Path(temp_dir))
            data = json.loads((Path(temp_dir) / ADDRESS_BOOK_PATH).read_text(encoding="utf-8"))
            data["contracts"]["StreamCore"]["address"] = "0x1234"
            write_json(Path(temp_dir) / ADDRESS_BOOK_PATH, data)
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "20-byte address",
            ):
                checker.validate_artifact(path)

    def test_reviewed_failed_result_fields_fail(self) -> None:
        """Reviewed result fields must affirm successful checks."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-failed-result.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "- Runtime bytecode matches release proof: `yes`",
                    "- Runtime bytecode matches release proof: `no`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "Runtime bytecode matches release proof",
            ):
                checker.validate_artifact(path)

    def test_reviewed_missing_retained_file_fails(self) -> None:
        """Reviewed retained artifact references must point to files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-missing-retained-file.md"
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "missing retained file",
            ):
                checker.validate_artifact(path)

    def test_missing_heading_fails(self) -> None:
        """Required sections cannot silently disappear."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-heading.md"
            write_text(path, valid_template().replace("## Verified Address Results\n\n", ""))

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "Verified Address Results",
            ):
                checker.validate_artifact(path)

    def test_wrong_requirement_fails(self) -> None:
        """The artifact must map only to the production verified-address row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-requirement.md"
            write_text(
                path,
                valid_template().replace(
                    "`production_verified_addresses`",
                    "`production_address_books`",
                ),
            )

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "production_verified_addresses",
            ):
                checker.validate_artifact(path)

    def test_wrong_environment_fails(self) -> None:
        """The artifact is only for live mainnet production evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-environment.md"
            write_text(path, valid_template().replace("- Environment: `live`", "- Environment: `sepolia`"))

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "Environment",
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
                checker.ProductionVerifiedAddressesError,
                "Production block or reference",
            ):
                checker.validate_artifact(path)

    def test_reviewed_template_notice_fails(self) -> None:
        """Reviewed artifacts must remove the template-only notice."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-template-notice.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "# Production Verified Addresses Retained Artifact\n\n",
                    "# Production Verified Addresses Retained Artifact\n\n"
                    "> Template only. This file is not completion evidence.\n\n",
                ),
            )

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "non-template evidence",
            ):
                checker.validate_artifact(path)

    def test_template_without_notice_fails(self) -> None:
        """Template-state artifacts must keep the template-only notice."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "template-without-notice.md"
            write_text(
                path,
                valid_template().replace(
                    "> Template only. This file is not completion evidence.\n\n",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "template-only notice",
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
                checker.ProductionVerifiedAddressesError,
                "check_public_beta_evidence",
            ):
                checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        """Secret-shaped key/value text is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\napi_key=do-not-commit\n")

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "secret-like",
            ):
                checker.validate_artifact(path)

    def test_referenced_artifact_secret_values_fail(self) -> None:
        """Reviewed retained files are scanned too."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-referenced-secret.md"
            seed_reviewed_retained_files(
                Path(temp_dir),
                secret_text="--private-key 0xabc123\n",
            )
            write_text(path, reviewed_artifact())

            with self.assertRaisesRegex(
                checker.ProductionVerifiedAddressesError,
                "secret-like CLI",
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main()
