#!/usr/bin/env python3
"""Focused tests for retained marketplace and indexer evidence."""

from __future__ import annotations

import importlib.util
import json
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


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def envelope_template(
    retained_path: Path,
    *,
    requirement_id: str = checker.PUBLIC_BETA_REQUIREMENT_ID,
    environment: str = "fork",
    sha256: str | None = None,
) -> dict[str, object]:
    """Return a valid non-local envelope template for a retained artifact."""
    return {
        "schema_version": "6529stream.non-local-release-evidence.v1",
        "evidence_id": f"template-{requirement_id}",
        "record_type": "template",
        "review_status": "template",
        "environment": environment,
        "chain_id": 1,
        "block_or_reference": "template-only marketplace/indexer reference",
        "command_or_source_system": "template-only marketplace/indexer transcript",
        "retained_path": retained_path.as_posix(),
        "sha256": sha256 or checker.file_sha256(retained_path),
        "redaction_statement": "Template only; no secrets are present.",
        "owner": "TBD",
        "reviewer": "TBD",
        "public_beta_requirement_id": requirement_id,
        "template_notice": (
            "Template only. This file is not completion evidence and does not mark "
            "public beta or production ready."
        ),
        "operator_notes": "Replace this template with reviewed evidence.",
    }


def reviewed_envelope(
    retained_path: Path,
    retained_relative_path: str,
    *,
    requirement_id: str = checker.PUBLIC_BETA_REQUIREMENT_ID,
    environment: str = "fork",
    chain_id: int = 1,
    record_type: str = "evidence",
    review_status: str = "reviewed",
    reviewer: str = "release-reviewer",
    retained_sha256: str | None = None,
) -> dict[str, object]:
    """Return reviewed non-local evidence metadata for a retained artifact."""
    return {
        "schema_version": "6529stream.non-local-release-evidence.v1",
        "evidence_id": f"reviewed-{requirement_id}",
        "record_type": record_type,
        "review_status": review_status,
        "environment": environment,
        "chain_id": chain_id,
        "block_or_reference": "fork block 25316366 / marketplace-indexer transcript",
        "command_or_source_system": "reviewed marketplace/indexer transcript",
        "retained_path": retained_relative_path,
        "sha256": retained_sha256 or checker.file_sha256(retained_path),
        "redaction_statement": "Secrets were never present.",
        "owner": "release-operator",
        "reviewer": reviewer,
        "public_beta_requirement_id": requirement_id,
        "operator_notes": "Reviewed marketplace/indexer retained evidence.",
    }


def manifest_with_marketplace_row(
    requirement_id: str,
    *,
    status: str = "complete",
    evidence: list[dict[str, str]] | None = None,
) -> dict[str, object]:
    """Return a minimal manifest containing one marketplace/indexer row."""
    phase = (
        "production_release"
        if requirement_id == checker.PRODUCTION_REQUIREMENT_ID
        else "public_beta"
    )
    return {
        "requirements": [
            {
                "id": requirement_id,
                "phase": phase,
                "status": status,
                "owner": "release-operator",
                "evidence": [] if evidence is None else evidence,
                "risk_acceptance": None,
                "notes": f"{requirement_id} fixture row.",
            }
        ]
    }


def write_manifest_bundle(
    root: Path,
    *,
    requirement_id: str = checker.PUBLIC_BETA_REQUIREMENT_ID,
    artifact_text: str | None = None,
    envelope: dict[str, object] | None = None,
    envelope_updates: dict[str, object] | None = None,
) -> tuple[Path, Path, Path]:
    """Write retained Markdown, envelope JSON, and manifest JSON fixtures."""
    retained_relative = "release-artifacts/evidence/marketplace-indexer/reviewed.md"
    envelope_relative = "release-artifacts/evidence/marketplace-indexer/reviewed.json"
    manifest_relative = "release-artifacts/latest/public-beta-evidence.json"
    retained_path = root / retained_relative
    envelope_path = root / envelope_relative
    manifest_path = root / manifest_relative

    write_text(retained_path, artifact_text or reviewed_artifact(requirement_id=requirement_id))
    envelope_data = envelope or reviewed_envelope(
        retained_path,
        retained_relative,
        requirement_id=requirement_id,
    )
    if envelope_updates is not None:
        envelope_data = {**envelope_data, **envelope_updates}
    write_json(envelope_path, envelope_data)
    write_json(
        manifest_path,
        manifest_with_marketplace_row(
            requirement_id,
            evidence=[
                {
                    "path": envelope_relative,
                    "sha256": checker.file_sha256(envelope_path),
                }
            ],
        ),
    )
    return retained_path, envelope_path, manifest_path


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
        """The committed templates and blocked manifest satisfy the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_envelope_template_passes_with_matching_retained_hash(self) -> None:
        """Envelope templates pin the retained Markdown artifact digest."""
        with tempfile.TemporaryDirectory() as temp_dir:
            retained_path = Path(temp_dir) / "retained.md"
            envelope_path = Path(temp_dir) / "envelope.json"
            write_text(retained_path, valid_template())
            write_json(envelope_path, envelope_template(retained_path))

            checker.validate_envelope_template(
                envelope_path,
                retained_path,
                checker.PUBLIC_BETA_REQUIREMENT_ID,
                checker.PUBLIC_BETA_ENVIRONMENTS,
            )

    def test_envelope_template_hash_drift_fails(self) -> None:
        """Envelope sha256 pins cannot drift from retained Markdown artifacts."""
        with tempfile.TemporaryDirectory() as temp_dir:
            retained_path = Path(temp_dir) / "retained.md"
            envelope_path = Path(temp_dir) / "envelope.json"
            write_text(retained_path, valid_template())
            write_json(
                envelope_path,
                envelope_template(retained_path, sha256=f"sha256:{'0' * 64}"),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError, "sha256 mismatch"
            ):
                checker.validate_envelope_template(
                    envelope_path,
                    retained_path,
                    checker.PUBLIC_BETA_REQUIREMENT_ID,
                    checker.PUBLIC_BETA_ENVIRONMENTS,
                )

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

    def test_manifest_complete_public_beta_row_validates_reviewed_artifact(self) -> None:
        """Complete public-beta rows must resolve reviewed retained Markdown."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _retained, _envelope, manifest = write_manifest_bundle(root)

            checker.validate_manifest_marketplace_rows(manifest, root)

    @unittest.skipIf(not hasattr(Path, "symlink_to"), "symlinks unavailable")
    def test_manifest_complete_row_rejects_symlinked_envelope_file(self) -> None:
        """Manifest evidence refs cannot point at symlinked envelope files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _retained, envelope, manifest = write_manifest_bundle(root)
            symlink = envelope.with_name("reviewed-link.json")
            try:
                symlink.symlink_to(envelope)
            except (NotImplementedError, OSError) as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")
            write_json(
                manifest,
                manifest_with_marketplace_row(
                    checker.PUBLIC_BETA_REQUIREMENT_ID,
                    evidence=[
                        {
                            "path": (
                                "release-artifacts/evidence/marketplace-indexer/"
                                "reviewed-link.json"
                            ),
                            "sha256": checker.file_sha256(envelope),
                        }
                    ],
                ),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "symlinked marketplace/indexer evidence",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    @unittest.skipIf(not hasattr(Path, "symlink_to"), "symlinks unavailable")
    def test_manifest_complete_row_rejects_symlinked_envelope_directory(self) -> None:
        """Manifest evidence refs cannot cross symlinked envelope directories."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            retained_relative = "release-artifacts/evidence/marketplace-indexer/reviewed.md"
            retained = root / retained_relative
            target_dir = root / "release-artifacts/evidence/marketplace-indexer-target"
            symlink_dir = root / "release-artifacts/evidence/marketplace-indexer-link"
            envelope = target_dir / "reviewed.json"
            manifest = root / "release-artifacts/latest/public-beta-evidence.json"
            write_text(retained, reviewed_artifact())
            write_json(
                envelope,
                reviewed_envelope(retained, retained_relative),
            )
            try:
                symlink_dir.symlink_to(target_dir, target_is_directory=True)
            except (NotImplementedError, OSError) as exc:
                self.skipTest(f"directory symlink creation unavailable: {exc}")
            write_json(
                manifest,
                manifest_with_marketplace_row(
                    checker.PUBLIC_BETA_REQUIREMENT_ID,
                    evidence=[
                        {
                            "path": (
                                "release-artifacts/evidence/marketplace-indexer-link/"
                                "reviewed.json"
                            ),
                            "sha256": checker.file_sha256(envelope),
                        }
                    ],
                ),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "symlinked marketplace/indexer evidence",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    @unittest.skipIf(not hasattr(Path, "symlink_to"), "symlinks unavailable")
    def test_manifest_complete_row_rejects_symlinked_retained_file(self) -> None:
        """Reviewed envelopes cannot point at symlinked retained Markdown files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            retained, envelope, manifest = write_manifest_bundle(root)
            symlink = retained.with_name("reviewed-link.md")
            try:
                symlink.symlink_to(retained)
            except (NotImplementedError, OSError) as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")
            write_json(
                envelope,
                reviewed_envelope(
                    retained,
                    "release-artifacts/evidence/marketplace-indexer/reviewed-link.md",
                    retained_sha256=checker.file_sha256(retained),
                ),
            )
            write_json(
                manifest,
                manifest_with_marketplace_row(
                    checker.PUBLIC_BETA_REQUIREMENT_ID,
                    evidence=[
                        {
                            "path": (
                                "release-artifacts/evidence/marketplace-indexer/"
                                "reviewed.json"
                            ),
                            "sha256": checker.file_sha256(envelope),
                        }
                    ],
                ),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "symlinked marketplace/indexer evidence",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    @unittest.skipIf(not hasattr(Path, "symlink_to"), "symlinks unavailable")
    def test_manifest_complete_row_rejects_symlinked_retained_directory(self) -> None:
        """Reviewed envelopes cannot cross symlinked retained Markdown directories."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            target_dir = root / "release-artifacts/evidence/marketplace-indexer-target"
            symlink_dir = root / "release-artifacts/evidence/marketplace-indexer-link"
            retained = target_dir / "reviewed.md"
            envelope = root / "release-artifacts/evidence/marketplace-indexer/reviewed.json"
            manifest = root / "release-artifacts/latest/public-beta-evidence.json"
            write_text(retained, reviewed_artifact())
            try:
                symlink_dir.symlink_to(target_dir, target_is_directory=True)
            except (NotImplementedError, OSError) as exc:
                self.skipTest(f"directory symlink creation unavailable: {exc}")
            write_json(
                envelope,
                reviewed_envelope(
                    retained,
                    "release-artifacts/evidence/marketplace-indexer-link/reviewed.md",
                    retained_sha256=checker.file_sha256(retained),
                ),
            )
            write_json(
                manifest,
                manifest_with_marketplace_row(
                    checker.PUBLIC_BETA_REQUIREMENT_ID,
                    evidence=[
                        {
                            "path": (
                                "release-artifacts/evidence/marketplace-indexer/"
                                "reviewed.json"
                            ),
                            "sha256": checker.file_sha256(envelope),
                        }
                    ],
                ),
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "symlinked marketplace/indexer evidence",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_production_row_validates_live_artifact(self) -> None:
        """Complete production rows require live marketplace/indexer evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            artifact = reviewed_artifact(
                requirement_id=checker.PRODUCTION_REQUIREMENT_ID,
                environment="live",
                chain_id="1",
            )
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                requirement_id=checker.PRODUCTION_REQUIREMENT_ID,
                artifact_text=artifact,
                envelope_updates={"environment": "live"},
            )

            checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_row_rejects_template_envelope(self) -> None:
        """Completed manifest rows cannot point at template-only envelopes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            retained_path = root / "release-artifacts/evidence/marketplace-indexer/reviewed.md"
            write_text(retained_path, reviewed_artifact())
            template_envelope = envelope_template(retained_path)
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                envelope=template_envelope,
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "record_type",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_row_requires_evidence_reference(self) -> None:
        """Completed manifest rows need at least one reviewed envelope reference."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest = root / "release-artifacts/latest/public-beta-evidence.json"
            write_json(manifest, manifest_with_marketplace_row(checker.PUBLIC_BETA_REQUIREMENT_ID))

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "must contain reviewed evidence",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_row_rejects_wrong_envelope_requirement(self) -> None:
        """Reviewed envelopes must match the completed manifest requirement."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                envelope_updates={
                    "public_beta_requirement_id": checker.PRODUCTION_REQUIREMENT_ID,
                },
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "public_beta_requirement_id",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_row_rejects_retained_hash_drift(self) -> None:
        """Envelope retained-artifact hashes must match the Markdown artifact."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                envelope_updates={"sha256": f"sha256:{'0' * 64}"},
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "retained artifact",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_public_beta_row_rejects_wrong_environment(self) -> None:
        """Public-beta marketplace/indexer evidence cannot use live-only envelopes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                envelope_updates={"environment": "live"},
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "environment",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_public_beta_row_rejects_non_positive_chain_id(self) -> None:
        """Public-beta marketplace/indexer evidence needs a real chain ID."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                envelope_updates={"chain_id": 0},
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "positive number",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_row_rejects_tbd_reviewer_envelope(self) -> None:
        """Completed marketplace/indexer evidence requires a named reviewer."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                envelope_updates={"reviewer": "tBd"},
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "reviewer",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_row_rejects_placeholder_operator_notes(self) -> None:
        """Reviewed envelopes cannot keep generator placeholder notes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                envelope_updates={
                    "operator_notes": (
                        "Generated from a template; replace with operator and reviewer "
                        "notes before marking the requirement complete."
                    )
                },
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "operator_notes",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

    def test_manifest_complete_row_rejects_invalid_retained_markdown(self) -> None:
        """Reviewed envelopes must point at Markdown that passes the artifact checker."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            invalid_artifact = reviewed_artifact().replace(
                "- Cache invalidation: `yes`",
                "- Cache invalidation: `no`",
            )
            _retained, _envelope, manifest = write_manifest_bundle(
                root,
                artifact_text=invalid_artifact,
            )

            with self.assertRaisesRegex(
                checker.MarketplaceIndexerEvidenceError,
                "Cache invalidation",
            ):
                checker.validate_manifest_marketplace_rows(manifest, root)

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
