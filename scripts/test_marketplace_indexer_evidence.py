#!/usr/bin/env python3
"""Focused tests for retained marketplace and indexer evidence."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_marketplace_indexer_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_marketplace_indexer_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_template(
    *,
    requirement_id: str = checker.PUBLIC_BETA_REQUIREMENT_ID,
    environment: str = "fork",
    chain_id: str = "1",
) -> str:
    """Return a valid marketplace/indexer retained-artifact template."""
    return f"""# Marketplace And Indexer Retained Artifact

> Template only. This file is not completion evidence.

## Evidence Status

- Requirement ID: `{requirement_id}`
- Review status: `template`
- Readiness claim: `blocked`
- Environment: `{environment}`
- Chain ID: `{chain_id}`

## Source And Contract References

- Repository: `https://github.com/6529-Collections/6529Stream`
- Git commit: `TBD`
- Release manifest/checksum digests: `TBD`
- Deployment manifest: `TBD`
- Address book: `TBD`
- Contract addresses: `TBD`
- Token IDs: `TBD`
- Collection IDs: `TBD`
- Marketplace/indexer tools: `OpenSea, Reservoir, Blur, Manifold, and equivalent collector/indexer tooling`
- Command or source system: `TBD`

## Coverage

- Contract metadata discovery: `TBD`
- ContractURI read: `TBD`
- ContractURIHash read: `TBD`
- ContractURIUpdated event observed: `TBD`
- Token metadata refresh: `TBD`
- ERC-4906 event observed: `TBD`
- Animation rendering: `TBD`
- Royalty display: `TBD`
- Royalty disclosure boundary: `royalty disclosure, not payment enforcement`
- Transfer/listing/sale path: `TBD`
- Event replay: `TBD`
- Cache invalidation: `TBD`
- Stale/failed/frozen/burned states: `TBD`

## Platform Results

- OpenSea: `TBD`
- Reservoir: `TBD`
- Blur: `TBD`
- Manifold: `TBD`
- Equivalent collector/indexer tooling: `TBD`
- Contract metadata: `contractURI()`, `contractURIHash()`, and `ContractURIUpdated`
- Token refresh event references: `ERC-4906`, `MetadataUpdate`, and `BatchMetadataUpdate`
- Readiness boundary: `ONE-005 retained marketplace/indexer evidence is fork/testnet/live evidence, not release readiness proof. No production-readiness claim depends on marketplaces honoring royalties.`

## Required Retained Artifacts

- Screenshot or public reference: `TBD`
- Query or transcript reference: `TBD`

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
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/generate_non_local_release_evidence.py --template release-artifacts/evidence/public-beta-templates/fork-testnet-marketplace-indexer-evidence-template.json --retained-artifact release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact-template.md --output release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-evidence.json --environment fork --chain-id 1 --block-or-reference "<fork or testnet block, token ID, and collection ID>" --command-or-source-system "<marketplace/indexer transcript>" --owner "<operator>" --reviewer "<reviewer>" --source-git-commit "<release commit>" --source-ci-run "<release CI run>"
python scripts/check_non_local_release_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

## Operator Notes

- Replace every `TBD` field before requesting review.
- Keep the matching tracker issue open until reviewed retained evidence is
  linked from the shared public-beta evidence manifest.
"""


def reviewed_artifact(
    *,
    requirement_id: str = checker.PUBLIC_BETA_REQUIREMENT_ID,
    environment: str = "fork",
    chain_id: str = "1",
) -> str:
    """Return a valid reviewed marketplace/indexer artifact."""
    text = valid_template(
        requirement_id=requirement_id,
        environment=environment,
        chain_id=chain_id,
    )
    replacements = {
        "> Template only. This file is not completion evidence.\n\n": "",
        "- Review status: `template`": "- Review status: `reviewed`",
        "- Git commit: `TBD`": "- Git commit: `1234567890abcdef1234567890abcdef12345678`",
        "- Release manifest/checksum digests: `TBD`": "- Release manifest/checksum digests: `release-manifest sha256 and SHA256SUMS sha256`",
        "- Deployment manifest: `TBD`": "- Deployment manifest: `deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`",
        "- Address book: `TBD`": "- Address book: `deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`",
        "- Contract addresses: `TBD`": "- Contract addresses: `StreamCore=0x1000000000000000000000000000000000000001, StreamContractMetadata=0x2000000000000000000000000000000000000002`",
        "- Token IDs: `TBD`": "- Token IDs: `1, 2, 3`",
        "- Collection IDs: `TBD`": "- Collection IDs: `1`",
        "- Command or source system: `TBD`": "- Command or source system: `marketplace/indexer reviewed transcript`",
        "- Contract metadata discovery: `TBD`": "- Contract metadata discovery: `yes`",
        "- ContractURI read: `TBD`": "- ContractURI read: `yes`",
        "- ContractURIHash read: `TBD`": "- ContractURIHash read: `yes`",
        "- ContractURIUpdated event observed: `TBD`": "- ContractURIUpdated event observed: `yes`",
        "- Token metadata refresh: `TBD`": "- Token metadata refresh: `yes`",
        "- ERC-4906 event observed: `TBD`": "- ERC-4906 event observed: `yes`",
        "- Animation rendering: `TBD`": "- Animation rendering: `yes`",
        "- Royalty display: `TBD`": "- Royalty display: `yes`",
        "- Transfer/listing/sale path: `TBD`": "- Transfer/listing/sale path: `yes`",
        "- Event replay: `TBD`": "- Event replay: `yes`",
        "- Cache invalidation: `TBD`": "- Cache invalidation: `yes`",
        "- Stale/failed/frozen/burned states: `TBD`": "- Stale/failed/frozen/burned states: `yes`",
        "- OpenSea: `TBD`": "- OpenSea: `reviewed`",
        "- Reservoir: `TBD`": "- Reservoir: `reviewed`",
        "- Blur: `TBD`": "- Blur: `reviewed`",
        "- Manifold: `TBD`": "- Manifold: `reviewed`",
        "- Equivalent collector/indexer tooling: `TBD`": "- Equivalent collector/indexer tooling: `reviewed`",
        "- Screenshot or public reference: `TBD`": "- Screenshot or public reference: `release-artifacts/evidence/marketplace-indexer/screenshot-reference.md`",
        "- Query or transcript reference: `TBD`": "- Query or transcript reference: `release-artifacts/evidence/marketplace-indexer/query-transcript.md`",
        "- Operator: `TBD`": "- Operator: `release-operator`",
        "- Reviewer: `TBD`": "- Reviewer: `release-reviewer`",
        "- Review decision: `template`": "- Review decision: `reviewed`",
        "- No secrets retained: `TBD`": "- No secrets retained: `yes`",
        "- Private RPC URLs removed: `TBD`": "- Private RPC URLs removed: `yes`",
        "- Private keys removed: `TBD`": "- Private keys removed: `yes`",
        "- API keys removed: `TBD`": "- API keys removed: `yes`",
        "- Unreleased drop payloads removed: `TBD`": "- Unreleased drop payloads removed: `yes`",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


class MarketplaceIndexerEvidenceTests(unittest.TestCase):
    """Checker behavior for marketplace/indexer evidence."""

    def test_committed_templates_pass(self) -> None:
        """The committed templates satisfy the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_reviewed_public_beta_artifact_passes(self) -> None:
        """A reviewed fork/testnet artifact can satisfy the checker."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed.md"
            write_text(path, reviewed_artifact())

            checker.validate_artifact(path)

    def test_reviewed_production_artifact_passes(self) -> None:
        """A reviewed live artifact can satisfy the checker."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-live.md"
            write_text(
                path,
                reviewed_artifact(
                    requirement_id=checker.PRODUCTION_REQUIREMENT_ID,
                    environment="live",
                    chain_id="1",
                ),
            )

            checker.validate_artifact(path)

    def test_wrong_requirement_environment_pair_fails(self) -> None:
        """Live requirement rows cannot use fork/testnet evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "wrong-env.md"
            write_text(
                path,
                valid_template(
                    requirement_id=checker.PRODUCTION_REQUIREMENT_ID,
                    environment="testnet",
                    chain_id="11155111",
                ),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError, "Environment"
            ):
                checker.validate_artifact(path)

    def test_reviewed_placeholders_fail(self) -> None:
        """Reviewed evidence cannot retain template placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-placeholder.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "- Token IDs: `1, 2, 3`",
                    "- Token IDs: `TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError, "Token IDs"
            ):
                checker.validate_artifact(path)

    def test_reviewed_coverage_must_pass(self) -> None:
        """Reviewed evidence must affirm each required coverage area."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "reviewed-no-cache.md"
            write_text(
                path,
                reviewed_artifact().replace(
                    "- Cache invalidation: `yes`",
                    "- Cache invalidation: `no`",
                ),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError, "Cache invalidation"
            ):
                checker.validate_artifact(path)

    def test_missing_platform_phrase_fails(self) -> None:
        """The artifact must retain the expected marketplace/indexer surface."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-platform.md"
            write_text(path, valid_template().replace("Blur, ", "").replace("- Blur: `TBD`\n", ""))

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError, "Blur"
            ):
                checker.validate_artifact(path)

    def test_missing_validation_command_fails(self) -> None:
        """The artifact must carry the full validation sequence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "missing-command.md"
            write_text(
                path,
                valid_template().replace(
                    "python scripts/check_public_beta_evidence.py\n", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError, "check_public_beta_evidence"
            ):
                checker.validate_artifact(path)

    def test_secret_like_values_fail(self) -> None:
        """Secret-shaped key/value text is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "secret.md"
            write_text(path, valid_template() + "\napi_key=do-not-commit\n")

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError, "secret-like"
            ):
                checker.validate_artifact(path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
