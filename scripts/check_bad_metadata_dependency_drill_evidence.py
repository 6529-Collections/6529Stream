#!/usr/bin/env python3
"""Validate retained bad metadata/dependency drill evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "bad_metadata_dependency_drill_evidence"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/incident-drills/"
        "bad-metadata-dependency-drill-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Bad Metadata Or Dependency Drill Retained Artifact",
    "## Evidence Status",
    "## Drill Context",
    "## Detection And Containment",
    "## Recovery Sequence",
    "## Monitoring And Handoff",
    "## Required Retained Artifacts",
    "## Review",
    "## Redaction",
    "## Validation Commands",
    "## Operator Notes",
]

REQUIRED_FIELDS = {
    "Requirement ID",
    "Review status",
    "Readiness claim",
    "Environment",
    "Chain ID",
    "Repository",
    "Release commit",
    "Deployment version",
    "Drill bundle reference",
    "Incident class",
    "Core contract",
    "Dependency registry",
    "Token ID",
    "Collection ID",
    "Metadata schema version",
    "Metadata surface",
    "Failure mode",
    "Collection frozen",
    "Starting metadata state",
    "Ending metadata state",
    "Dependency key",
    "Starting dependency version",
    "Ending dependency version",
    "Dependency content hash",
    "Freeze manifest hash",
    "Metadata state snapshot evidence",
    "Token URI snapshot evidence",
    "URI policy evidence",
    "UTF-8 or raw-attributes evidence",
    "Dependency version/provenance evidence",
    "Freeze status evidence",
    "Metadata mutation pause evidence",
    "ERC-4906/cache invalidation evidence",
    "Browser sandbox evidence",
    "Marketplace/indexer communication evidence",
    "Recovery decision",
    "Corrected metadata evidence",
    "Corrected dependency/version evidence",
    "Dependency deprecation evidence",
    "Frozen collection decision evidence",
    "Post-recovery tokenURI evidence",
    "Post-recovery metadata state evidence",
    "Release artifact refresh evidence",
    "Operator dashboard confirmation",
    "Monitoring alert reference",
    "Incident response decision log",
    "Public communication status",
    "Follow-up issue links",
    "Command transcript bundle",
    "Event or state snapshot bundle",
    "Dependency operations evidence",
    "Metadata rendering evidence",
    "Browser/marketplace evidence",
    "Admin ceremony evidence",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Provider/API secrets removed",
    "Unreleased artist assets removed",
    "Unreleased token metadata removed",
    "Private dependency sources removed",
    "Private collector data removed",
}

FINAL_VALUE_FIELDS = sorted(
    REQUIRED_FIELDS
    - {
        "Requirement ID",
        "Review status",
        "Readiness claim",
        "Environment",
        "Incident class",
        "Review decision",
        "No secrets retained",
        "Private RPC URLs removed",
        "Private keys removed",
        "Provider/API secrets removed",
        "Unreleased artist assets removed",
        "Unreleased token metadata removed",
        "Private dependency sources removed",
        "Private collector data removed",
    }
)

REDACTION_FIELDS = (
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Provider/API secrets removed",
    "Unreleased artist assets removed",
    "Unreleased token metadata removed",
    "Private dependency sources removed",
    "Private collector data removed",
)

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
READINESS_CLAIMS = {"blocked", "complete"}
ENVIRONMENTS = {"template", "fork", "testnet", "live"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
COLLECTION_FROZEN_VALUES = {"yes", "no"}
METADATA_STATES = {"pending", "stale", "failed", "final"}
METADATA_SCHEMA_VERSION = "6529stream-v1"
METADATA_SURFACES = {
    "token_uri",
    "token_image",
    "attributes",
    "animation_html",
    "collection_base_uri",
    "collection_library",
    "contract_uri",
    "dependency_source",
    "dependency_provenance",
    "dependency_version",
    "dependency_pin",
    "frozen_output",
}
FAILURE_MODES_BY_SURFACE = {
    "token_uri": {
        "wrong_metadata_state",
        "invalid_json",
        "marketplace_cache_stale",
        "frozen_output_mismatch",
    },
    "token_image": {"unsafe_uri", "invalid_utf8", "marketplace_cache_stale"},
    "attributes": {"raw_attributes_invalid", "invalid_utf8", "invalid_json"},
    "animation_html": {
        "animation_sandbox_failure",
        "invalid_utf8",
        "marketplace_cache_stale",
    },
    "collection_base_uri": {"unsafe_uri", "invalid_utf8", "marketplace_cache_stale"},
    "collection_library": {"unsafe_uri", "invalid_utf8", "marketplace_cache_stale"},
    "contract_uri": {"unsafe_uri", "invalid_utf8", "marketplace_cache_stale"},
    "dependency_source": {
        "dependency_source_drift",
        "invalid_utf8",
        "private_source_leak",
    },
    "dependency_provenance": {
        "dependency_provenance_bad",
        "invalid_utf8",
        "private_source_leak",
    },
    "dependency_version": {
        "dependency_version_bad",
        "deprecated_dependency",
        "dependency_source_drift",
    },
    "dependency_pin": {
        "dependency_pin_bad",
        "unknown_dependency",
        "frozen_repin_attempt",
    },
    "frozen_output": {"frozen_output_mismatch", "frozen_repin_attempt"},
}
DEPENDENCY_SURFACES = {
    "dependency_source",
    "dependency_provenance",
    "dependency_version",
    "dependency_pin",
}
RECOVERY_DECISIONS = {
    "fix_forward_metadata",
    "fix_forward_dependency",
    "deprecate_dependency",
    "marketplace_cache_refresh",
    "document_immutable_proof",
    "redeploy_or_new_collection",
    "no_contract_change",
}
FROZEN_DISALLOWED_RECOVERIES = {"fix_forward_metadata", "fix_forward_dependency"}
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
ZERO_BYTES32 = "0x" + "0" * 64

REQUIRED_COMMANDS = [
    "python scripts/test_bad_metadata_dependency_drill_evidence.py",
    "python scripts/check_bad_metadata_dependency_drill_evidence.py",
    "python scripts/test_incident_drill_evidence.py",
    "python scripts/check_incident_drill_evidence.py",
    "python scripts/test_incident_response.py",
    "python scripts/check_incident_response.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

SOURCE_REQUIREMENTS = {
    # These intentionally brittle anchors force review if the underlying
    # metadata, dependency, or freeze controls move.
    Path("smart-contracts/StreamCore.sol"): [
        "error MetadataMutationPaused",
        "error FrozenCollectionDependencyRegistry",
        "error MetadataFrozen",
        "error UnsafeMetadataURI",
        "error UnsafeRawAttributes",
        "event CollectionFrozen",
        "event DependencyVersionPinned",
        "emit MetadataUpdate",
        "emit BatchMetadataUpdate",
        "function freezeCollection",
        "function tokenURI",
        "function tokenMetadataState",
        "function collectionFreezeManifestHash",
        "function collectionDependencyVersionState",
        "function _pinCollectionDependency",
    ],
    Path("smart-contracts/DependencyRegistry.sol"): [
        "event DependencyVersionCreated",
        "event DependencyVersionDeprecated",
        "function addDependency",
        "function addDependencyWithProvenance",
        "function addDependencyScriptIndex",
        "function deprecateDependencyVersion",
        "function getDependencyVersionRecord",
        "function getDependencyVersionProvenance",
        "function getDependencyScriptContentHashAtVersion",
        "DependencyFieldInvalidUTF8",
        "DependencyVersionMissing",
        "DependencyKeyReserved",
    ],
    Path("smart-contracts/StreamMetadataRenderer.sol"): [
        "error MetadataFieldTooLarge",
        "error MetadataFieldInvalidUTF8",
        "error UnsafeMetadataURI",
        "error UnsafeRawAttributes",
        "function onchainMetadataJson",
        "function tokenMetadataRecordHash",
        "function tokenMetadataState",
        "function pendingTokenMetadataState",
        "function requireValidUtf8ContentUri",
        "function requireValidUtf8ScriptUri",
        "function requireValidUtf8RawAttributes",
        "function requireTokenAttributes",
        "function isSafeContentUri",
        "function isSafeScriptUri",
    ],
    Path("test/StreamDependencyRegistry.t.sol"): [
        "testDependencyVersionsAreImmutableAndExposeProvenance",
        "testCollectionPinsDependencyVersionUntilExplicitRepin",
        "testFrozenCollectionIgnoresLaterDependencyVersions",
        "DependencyVersionPinned",
    ],
    Path("test/StreamMetadataFreeze.t.sol"): [
        "testFreezeStoresManifestEventAndFinalizesSupply",
        "testFrozenCollectionRejectsMetadataSignificantWrites",
        "testFrozenCollectionBlocksDependencyRegistrySwap",
    ],
    Path("test/StreamMetadataCrossInvariants.t.sol"): [
        "testFrozenDependencyPinSurvivesVersionDeprecationAndRegistryChurn",
        "testFrozenLiveTokenRejectsLateRandomnessAndPreservesDependencyManifest",
    ],
    Path("test/StreamMetadataEvents.t.sol"): [
        "testSupportsErc4906Interface",
        "testTokenMetadataMutationsEmitMetadataUpdate",
        "testCollectionMetadataMutationsEmitBatchMetadataUpdate",
    ],
    Path("test/StreamMetadataUriPolicy.t.sol"): [
        "testTokenImageRejectsUnsafeProductionUris",
        "testCollectionBaseUriRejectsUnsafeProductionUris",
        "testCollectionLibraryRejectsUnsafeProductionUris",
        "testCreateCollectionRejectsUnsafeProductionUris",
    ],
    Path("test/StreamMetadataEscaping.t.sol"): [
        "testRawAttributesRejectBreakoutFragment",
        "testRawAttributesRejectInvalidJsonStringEscapes",
        "testAnimationHtmlEscapesWrapperBoundaries",
    ],
    Path("test/StreamMetadataUtf8.t.sol"): [
        "testDependencyRegistryRejectsInvalidUtf8ScriptChunk",
        "testDependencyRegistryRejectsInvalidUtf8Provenance",
        "testStreamCoreRejectsInvalidUtf8TokenImageAttributesAndUpdates",
    ],
    Path("docs/incident-response.md"): [
        "Runbook: Bad Metadata Or Dependency Configuration",
        "For frozen collections, do not imply that frozen output can be mutated",
    ],
    Path("docs/dependency-operations.md"): [
        "Source Of Truth",
        "Frozen collections are immutable",
        "repin a frozen collection",
        "Rollback And Corrective Releases",
    ],
    Path("docs/metadata.md"): [
        "metadata_schema_version",
        "6529stream-v1",
        "pending",
        "stale",
        "failed",
        "final",
        "URI Policy",
        "ERC-4906 Events",
        "Dependency Versions",
        "Freeze Manifest And Boundaries",
    ],
}

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
UINT_RE = re.compile(r"^(0|[1-9][0-9]*)$")
ADDRESS_RE = re.compile(r"^0x[a-fA-F0-9]{40}$")
BYTES32_RE = re.compile(r"^0x[a-fA-F0-9]{64}$")
GIT_COMMIT_RE = re.compile(r"^(?:[a-fA-F0-9]{40}|[a-fA-F0-9]{64})$")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|provider[_ -]?secret|"
    r"provider[_ -]?dashboard[_ -]?secret|private[_ -]?dependency[_ -]?source|"
    r"unreleased[_ -]?artist[_ -]?asset|unreleased[_ -]?token[_ -]?metadata|"
    r"unreleased[_ -]?drop[_ -]?payload|private[_ -]?collector[_ -]?data"
    r")\s*[:=]",
    re.IGNORECASE,
)
CREDENTIAL_URL_RE = re.compile(r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+", re.IGNORECASE)


class BadMetadataDependencyDrillEvidenceError(RuntimeError):
    """Raised when bad metadata/dependency drill evidence is invalid."""


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise BadMetadataDependencyDrillEvidenceError(
            f"missing required file: {path}"
        ) from exc
    except UnicodeDecodeError as exc:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} must be valid UTF-8"
        ) from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    for match in CREDENTIAL_URL_RE.finditer(text):
        matched_url = match.group(0)
        if "[REDACTED]" in matched_url or "<redacted>" in matched_url.lower():
            continue
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} contains credentialed URL text: {matched_url}"
        )


def validate_headings(path: Path, text: str) -> None:
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} is missing required heading: {heading}"
            ) from exc
        cursor = index + 1


def field_map(path: Path, text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = FIELD_RE.match(line.strip())
        if not match:
            continue
        label = match.group("label").strip()
        value = normalize_value(match.group("value"))
        if label in fields:
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} is missing required fields: {', '.join(missing)}"
        )
    return fields


def require_value(path: Path, fields: dict[str, str], label: str, allowed: set[str]) -> str:
    value = fields[label]
    if value not in allowed:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} field {label} must be one of {sorted(allowed)}"
        )
    return value


def require_uint(path: Path, fields: dict[str, str], label: str) -> int:
    value = fields[label]
    if not UINT_RE.match(value):
        raise BadMetadataDependencyDrillEvidenceError(f"{path} field {label} must be a uint")
    return int(value)


def require_address(path: Path, fields: dict[str, str], label: str) -> None:
    value = fields[label]
    if not ADDRESS_RE.match(value) or value.lower() == ZERO_ADDRESS:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} field {label} must be a non-zero Ethereum address"
        )


def require_bytes32(path: Path, fields: dict[str, str], label: str) -> str:
    value = fields[label]
    if not BYTES32_RE.match(value):
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} field {label} must be bytes32 hex"
        )
    return value.lower()


def validate_template(path: Path, fields: dict[str, str], text: str) -> None:
    if fields["Review status"] != "template":
        return
    if "Template only. This file is not completion evidence." not in text:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} template evidence must keep the template-only warning"
        )
    if fields["Environment"] != "template":
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} template environment must be template"
        )
    if fields["Readiness claim"] != "blocked":
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} template readiness must be blocked"
        )
    if fields["Review decision"] != "template":
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} template decision must be template"
        )


def validate_review_lifecycle(path: Path, fields: dict[str, str], text: str) -> None:
    review_status = require_value(path, fields, "Review status", REVIEW_STATUSES)
    readiness = require_value(path, fields, "Readiness claim", READINESS_CLAIMS)
    environment = require_value(path, fields, "Environment", ENVIRONMENTS)
    decision = require_value(path, fields, "Review decision", REVIEW_DECISIONS)

    if fields["Requirement ID"] != REQUIREMENT_ID:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} field Requirement ID must be {REQUIREMENT_ID}"
        )
    if fields["Incident class"] != "bad_metadata_dependency":
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} field Incident class must be bad_metadata_dependency"
        )
    if review_status == "template":
        validate_template(path, fields, text)
        return
    if "Template only. This file is not completion evidence." in text:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} non-template evidence must remove the template-only warning"
        )
    if environment == "template":
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} reviewed evidence cannot use template environment"
        )
    if readiness == "complete" and (review_status != "reviewed" or decision != "reviewed"):
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} Readiness claim complete requires reviewed status and decision"
        )
    if review_status == "reviewed" and readiness != "complete":
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} reviewed evidence must make a complete readiness claim"
        )


def validate_final_fields(path: Path, fields: dict[str, str]) -> None:
    if fields["Review status"] == "template":
        return
    for label in FINAL_VALUE_FIELDS:
        value = fields[label]
        if value in {"", "TBD", "TODO", "N/A"} or ANGLE_PLACEHOLDER_RE.search(value):
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} field {label} must be replaced before review"
            )
    for label in REDACTION_FIELDS:
        if fields[label].lower() != "yes":
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} field {label} must be yes after redaction review"
            )


def validate_context_fields(path: Path, fields: dict[str, str]) -> None:
    if fields["Review status"] == "template":
        return

    require_uint(path, fields, "Chain ID")
    require_uint(path, fields, "Token ID")
    require_uint(path, fields, "Collection ID")
    starting_version = require_uint(path, fields, "Starting dependency version")
    ending_version = require_uint(path, fields, "Ending dependency version")
    require_address(path, fields, "Core contract")
    require_address(path, fields, "Dependency registry")
    dependency_key = require_bytes32(path, fields, "Dependency key")
    dependency_content_hash = require_bytes32(path, fields, "Dependency content hash")
    freeze_manifest_hash = require_bytes32(path, fields, "Freeze manifest hash")

    if not GIT_COMMIT_RE.match(fields["Release commit"]):
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} field Release commit must be a 40-char SHA-1 or 64-char SHA-256 hex commit"
        )
    if fields["Metadata schema version"] != METADATA_SCHEMA_VERSION:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} field Metadata schema version must be {METADATA_SCHEMA_VERSION}"
        )

    surface = require_value(path, fields, "Metadata surface", METADATA_SURFACES)
    failure_mode = fields["Failure mode"]
    allowed_modes = FAILURE_MODES_BY_SURFACE[surface]
    if failure_mode not in allowed_modes:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} field Failure mode must match Metadata surface {surface}: "
            f"{sorted(allowed_modes)}"
        )
    collection_frozen = require_value(
        path, fields, "Collection frozen", COLLECTION_FROZEN_VALUES
    )
    require_value(path, fields, "Starting metadata state", METADATA_STATES)
    require_value(path, fields, "Ending metadata state", METADATA_STATES)
    recovery_decision = require_value(path, fields, "Recovery decision", RECOVERY_DECISIONS)

    if failure_mode == "frozen_repin_attempt" and collection_frozen != "yes":
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} frozen_repin_attempt evidence must have Collection frozen yes"
        )
    if collection_frozen == "yes":
        if freeze_manifest_hash == ZERO_BYTES32:
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} frozen collection evidence must retain a non-zero freeze manifest hash"
            )
        if ending_version != starting_version:
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} frozen collection evidence must not change dependency version"
            )
        if recovery_decision in FROZEN_DISALLOWED_RECOVERIES:
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} frozen collection evidence cannot use {recovery_decision}"
            )

    if surface in DEPENDENCY_SURFACES:
        if dependency_key == ZERO_BYTES32:
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} dependency-related evidence requires non-zero Dependency key"
            )
        if dependency_content_hash == ZERO_BYTES32:
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} dependency-related evidence requires non-zero Dependency content hash"
            )
        if starting_version == 0 or ending_version == 0:
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} dependency-related evidence requires non-zero dependency versions"
            )
        if (
            collection_frozen == "no"
            and recovery_decision == "fix_forward_dependency"
            and ending_version <= starting_version
        ):
            raise BadMetadataDependencyDrillEvidenceError(
                f"{path} fix-forward dependency recovery must end on a newer version"
            )


def validate_required_commands(path: Path, text: str) -> None:
    missing = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing:
        raise BadMetadataDependencyDrillEvidenceError(
            f"{path} is missing required validation commands: {', '.join(missing)}"
        )


def validate_source_requirements(root: Path) -> None:
    missing: list[str] = []
    for source_path, snippets in SOURCE_REQUIREMENTS.items():
        text = read_text(root / source_path)
        for snippet in snippets:
            if snippet not in text:
                missing.append(f"{source_path}: {snippet}")
    if missing:
        raise BadMetadataDependencyDrillEvidenceError(
            "missing bad metadata/dependency source/test anchors: " + "; ".join(missing)
        )


def validate_evidence(path: Path, root: Path | None = None) -> None:
    root = root or Path(".")
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)
    validate_review_lifecycle(path, fields, text)
    validate_final_fields(path, fields)
    validate_context_fields(path, fields)
    validate_required_commands(path, text)
    validate_source_requirements(root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate retained bad metadata/dependency drill evidence artifacts."
    )
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        default=DEFAULT_EVIDENCE,
        help="Evidence Markdown files to validate.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("."),
        help="Repository root used for source-aware anchor validation.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        for path in args.paths:
            validate_evidence(path, args.root)
    except BadMetadataDependencyDrillEvidenceError as exc:
        print(f"bad-metadata-dependency-drill-evidence check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
