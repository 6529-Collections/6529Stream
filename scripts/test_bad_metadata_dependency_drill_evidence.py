#!/usr/bin/env python3
"""Focused tests for bad metadata/dependency drill evidence validation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_bad_metadata_dependency_drill_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_bad_metadata_dependency_drill_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def template_text() -> str:
    return Path(
        "release-artifacts/evidence/incident-drills/"
        "bad-metadata-dependency-drill-retained-artifact-template.md"
    ).read_text(encoding="utf-8")


def reviewed_text() -> str:
    text = template_text()
    replacements = {
        "> Template only. This file is not completion evidence.\n\n": "",
        "Review status: `template`": "Review status: `reviewed`",
        "Readiness claim: `blocked`": "Readiness claim: `complete`",
        "Environment: `template`": "Environment: `testnet`",
        "Chain ID: `TBD`": "Chain ID: `11155111`",
        "Release commit: `TBD`": "Release commit: `0123456789abcdef0123456789abcdef01234567`",
        "Deployment version: `TBD`": "Deployment version: `sepolia-001`",
        "Drill bundle reference: `TBD`": "Drill bundle reference: `incident-drills/bad-metadata-dependency-sepolia-001.md`",
        "Core contract: `TBD`": "Core contract: `0x0000000000000000000000000000000000005001`",
        "Dependency registry: `TBD`": "Dependency registry: `0x0000000000000000000000000000000000005002`",
        "Token ID: `TBD`": "Token ID: `1001`",
        "Collection ID: `TBD`": "Collection ID: `42`",
        "Metadata schema version: `TBD`": "Metadata schema version: `6529stream-v1`",
        "Metadata surface: `TBD`": "Metadata surface: `dependency_pin`",
        "Failure mode: `TBD`": "Failure mode: `dependency_pin_bad`",
        "Collection frozen: `TBD`": "Collection frozen: `no`",
        "Starting metadata state: `TBD`": "Starting metadata state: `final`",
        "Ending metadata state: `TBD`": "Ending metadata state: `final`",
        "Dependency key: `TBD`": "Dependency key: `0x1111111111111111111111111111111111111111111111111111111111111111`",
        "Starting dependency version: `TBD`": "Starting dependency version: `1`",
        "Ending dependency version: `TBD`": "Ending dependency version: `2`",
        "Dependency content hash: `TBD`": "Dependency content hash: `0x2222222222222222222222222222222222222222222222222222222222222222`",
        "Freeze manifest hash: `TBD`": "Freeze manifest hash: `0x0000000000000000000000000000000000000000000000000000000000000000`",
        "Metadata state snapshot evidence: `TBD`": "Metadata state snapshot evidence: `tokenMetadataState before and after retained`",
        "Token URI snapshot evidence: `TBD`": "Token URI snapshot evidence: `tokenURI before and after retained`",
        "URI policy evidence: `TBD`": "URI policy evidence: `URI policy check retained`",
        "UTF-8 or raw-attributes evidence: `TBD`": "UTF-8 or raw-attributes evidence: `UTF-8 and raw attribute checks retained`",
        "Dependency version/provenance evidence: `TBD`": "Dependency version/provenance evidence: `getDependencyVersionRecord and provenance retained`",
        "Freeze status evidence: `TBD`": "Freeze status evidence: `collectionFreezeManifestHash zero and not frozen retained`",
        "Metadata mutation pause evidence: `TBD`": "Metadata mutation pause evidence: `METADATA_MUTATION pause assessment retained`",
        "ERC-4906/cache invalidation evidence: `TBD`": "ERC-4906/cache invalidation evidence: `BatchMetadataUpdate and marketplace refresh retained`",
        "Browser sandbox evidence: `TBD`": "Browser sandbox evidence: `metadata browser sandbox screenshot hash retained`",
        "Marketplace/indexer communication evidence: `TBD`": "Marketplace/indexer communication evidence: `marketplace and indexer notice retained`",
        "Recovery decision: `TBD`": "Recovery decision: `fix_forward_dependency`",
        "Corrected metadata evidence: `TBD`": "Corrected metadata evidence: `not applicable; dependency pin fix-forward retained`",
        "Corrected dependency/version evidence: `TBD`": "Corrected dependency/version evidence: `DependencyVersionPinned version 2 retained`",
        "Dependency deprecation evidence: `TBD`": "Dependency deprecation evidence: `bad dependency version deprecation decision retained`",
        "Frozen collection decision evidence: `TBD`": "Frozen collection decision evidence: `collection not frozen; repin allowed by runbook`",
        "Post-recovery tokenURI evidence: `TBD`": "Post-recovery tokenURI evidence: `tokenURI final output retained`",
        "Post-recovery metadata state evidence: `TBD`": "Post-recovery metadata state evidence: `final state retained`",
        "Release artifact refresh evidence: `TBD`": "Release artifact refresh evidence: `release manifest and checksums refreshed`",
        "Operator dashboard confirmation: `TBD`": "Operator dashboard confirmation: `dashboard panel screenshot hash retained`",
        "Monitoring alert reference: `TBD`": "Monitoring alert reference: `alert SIM-METADATA-001 retained`",
        "Incident response decision log: `TBD`": "Incident response decision log: `decision-log.md`",
        "Public communication status: `TBD`": "Public communication status: `no public user impact`",
        "Follow-up issue links: `TBD`": "Follow-up issue links: `https://github.com/6529-Collections/6529Stream/issues/516`",
        "Command transcript bundle: `TBD`": "Command transcript bundle: `commands.md`",
        "Event or state snapshot bundle: `TBD`": "Event or state snapshot bundle: `snapshots.md`",
        "Dependency operations evidence: `TBD`": "Dependency operations evidence: `docs/dependency-operations.md reviewed`",
        "Metadata rendering evidence: `TBD`": "Metadata rendering evidence: `docs/metadata.md reviewed`",
        "Browser/marketplace evidence: `TBD`": "Browser/marketplace evidence: `browser and marketplace evidence bundle retained`",
        "Admin ceremony evidence: `TBD`": "Admin ceremony evidence: `admin-ceremony.json`",
        "Release manifest/checksum digests: `TBD`": "Release manifest/checksum digests: `sha256 bundle retained`",
        "Operator: `TBD`": "Operator: `ops`",
        "Reviewer: `TBD`": "Reviewer: `reviewer`",
        "Review decision: `template`": "Review decision: `reviewed`",
        "No secrets retained: `TBD`": "No secrets retained: `yes`",
        "Private RPC URLs removed: `TBD`": "Private RPC URLs removed: `yes`",
        "Private keys removed: `TBD`": "Private keys removed: `yes`",
        "Provider/API secrets removed: `TBD`": "Provider/API secrets removed: `yes`",
        "Unreleased artist assets removed: `TBD`": "Unreleased artist assets removed: `yes`",
        "Unreleased token metadata removed: `TBD`": "Unreleased token metadata removed: `yes`",
        "Private dependency sources removed: `TBD`": "Private dependency sources removed: `yes`",
        "Private collector data removed: `TBD`": "Private collector data removed: `yes`",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


class BadMetadataDependencyDrillEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        for path in checker.DEFAULT_EVIDENCE:
            checker.validate_evidence(path)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(path, reviewed_text())

            checker.validate_evidence(path)

    def test_wrong_requirement_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    checker.REQUIREMENT_ID, "incident_drill_evidence", 1
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "Requirement ID"
            ):
                checker.validate_evidence(path)

    def test_reviewed_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Incident response decision log: `decision-log.md`",
                    "Incident response decision log: `TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "must be replaced"
            ):
                checker.validate_evidence(path)

    def test_pending_review_complete_readiness_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            text = reviewed_text().replace(
                "Review status: `reviewed`", "Review status: `pending_review`"
            )
            text = text.replace(
                "Review decision: `reviewed`", "Review decision: `pending_review`"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "Readiness claim"
            ):
                checker.validate_evidence(path)

    def test_reviewed_bad_chain_id_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace("Chain ID: `11155111`", "Chain ID: `sepolia`"),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "Chain ID must be a uint"
            ):
                checker.validate_evidence(path)

    def test_git_sha256_release_commit_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Release commit: `0123456789abcdef0123456789abcdef01234567`",
                    (
                        "Release commit: "
                        "`0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef`"
                    ),
                ),
            )

            checker.validate_evidence(path)

    def test_core_contract_must_be_nonzero_address(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Core contract: `0x0000000000000000000000000000000000005001`",
                    "Core contract: `0x0000000000000000000000000000000000000000`",
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "Core contract"
            ):
                checker.validate_evidence(path)

    def test_metadata_schema_version_must_match_current_schema(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Metadata schema version: `6529stream-v1`",
                    "Metadata schema version: `legacy`",
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError,
                "Metadata schema version",
            ):
                checker.validate_evidence(path)

    def test_failure_mode_must_match_surface(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Failure mode: `dependency_pin_bad`",
                    "Failure mode: `unsafe_uri`",
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "Failure mode"
            ):
                checker.validate_evidence(path)

    def test_dependency_surface_requires_nonzero_dependency_key(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Dependency key: `0x1111111111111111111111111111111111111111111111111111111111111111`",
                    "Dependency key: `0x0000000000000000000000000000000000000000000000000000000000000000`",
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "Dependency key"
            ):
                checker.validate_evidence(path)

    def test_fix_forward_dependency_must_advance_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Ending dependency version: `2`",
                    "Ending dependency version: `1`",
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError,
                "newer version",
            ):
                checker.validate_evidence(path)

    def test_frozen_collection_cannot_change_dependency_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            text = reviewed_text()
            text = text.replace("Collection frozen: `no`", "Collection frozen: `yes`")
            text = text.replace(
                "Freeze manifest hash: `0x0000000000000000000000000000000000000000000000000000000000000000`",
                "Freeze manifest hash: `0x3333333333333333333333333333333333333333333333333333333333333333`",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError,
                "must not change dependency version",
            ):
                checker.validate_evidence(path)

    def test_frozen_repin_attempt_requires_frozen_collection(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Failure mode: `dependency_pin_bad`",
                    "Failure mode: `frozen_repin_attempt`",
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError,
                "frozen_repin_attempt",
            ):
                checker.validate_evidence(path)

    def test_frozen_collection_documented_immutable_proof_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            text = reviewed_text()
            replacements = {
                "Failure mode: `dependency_pin_bad`": "Failure mode: `frozen_repin_attempt`",
                "Collection frozen: `no`": "Collection frozen: `yes`",
                "Ending dependency version: `2`": "Ending dependency version: `1`",
                "Recovery decision: `fix_forward_dependency`": "Recovery decision: `document_immutable_proof`",
                "Freeze manifest hash: `0x0000000000000000000000000000000000000000000000000000000000000000`": "Freeze manifest hash: `0x3333333333333333333333333333333333333333333333333333333333333333`",
            }
            for old, new in replacements.items():
                text = text.replace(old, new)
            write_text(path, text)

            checker.validate_evidence(path)

    def test_metadata_only_surface_allows_zero_dependency_fields(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            text = reviewed_text()
            replacements = {
                "Metadata surface: `dependency_pin`": "Metadata surface: `token_image`",
                "Failure mode: `dependency_pin_bad`": "Failure mode: `unsafe_uri`",
                "Dependency key: `0x1111111111111111111111111111111111111111111111111111111111111111`": "Dependency key: `0x0000000000000000000000000000000000000000000000000000000000000000`",
                "Starting dependency version: `1`": "Starting dependency version: `0`",
                "Ending dependency version: `2`": "Ending dependency version: `0`",
                "Dependency content hash: `0x2222222222222222222222222222222222222222222222222222222222222222`": "Dependency content hash: `0x0000000000000000000000000000000000000000000000000000000000000000`",
                "Recovery decision: `fix_forward_dependency`": "Recovery decision: `fix_forward_metadata`",
            }
            for old, new in replacements.items():
                text = text.replace(old, new)
            write_text(path, text)

            checker.validate_evidence(path)

    def test_redaction_fields_must_be_yes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Private dependency sources removed: `yes`",
                    "Private dependency sources removed: `no`",
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError,
                "Private dependency sources removed",
            ):
                checker.validate_evidence(path)

    def test_secret_like_key_value_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(path, reviewed_text() + "\napi_key=abc123\n")

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path)

    def test_credentialed_url_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(path, reviewed_text() + "\nhttps://user:pass@example.invalid\n")

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "credentialed URL"
            ):
                checker.validate_evidence(path)

    def test_redacted_credentialed_url_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(path, reviewed_text() + "\nhttps://user:[REDACTED]@example.invalid\n")

            checker.validate_evidence(path)

    def test_unredacted_credentialed_url_fails_even_with_redacted_line_marker(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text()
                + "\nhttps://user:pass@example.invalid retained dashboard [REDACTED]\n",
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "credentialed URL"
            ):
                checker.validate_evidence(path)

    def test_missing_required_command_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "bad-metadata-dependency.md"
            write_text(
                path,
                reviewed_text().replace(
                    "python scripts/check_bad_metadata_dependency_drill_evidence.py", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "validation commands"
            ):
                checker.validate_evidence(path)

    def test_missing_source_anchor_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = root / "bad-metadata-dependency.md"
            write_text(evidence, reviewed_text())
            for source_path, snippets in checker.SOURCE_REQUIREMENTS.items():
                write_text(root / source_path, "\n".join(snippets))
            target = root / "docs/dependency-operations.md"
            write_text(target, "missing anchors\n")

            with self.assertRaisesRegex(
                checker.BadMetadataDependencyDrillEvidenceError, "source/test anchors"
            ):
                checker.validate_evidence(evidence, root)


if __name__ == "__main__":
    unittest.main()
