#!/usr/bin/env python3
"""Validate retained marketplace and indexer evidence artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


PUBLIC_BETA_REQUIREMENT_ID = "fork_testnet_marketplace_indexer_evidence"
PRODUCTION_REQUIREMENT_ID = "live_marketplace_indexer_evidence"
PUBLIC_BETA_ENVIRONMENTS = {"fork", "testnet"}
PRODUCTION_ENVIRONMENTS = {"live"}
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/marketplace-indexer/"
        "fork-testnet-marketplace-indexer-retained-artifact-template.md"
    ),
    Path(
        "release-artifacts/evidence/marketplace-indexer/"
        "live-marketplace-indexer-retained-artifact-template.md"
    ),
]
DEFAULT_ENVELOPE_TEMPLATES = [
    (
        Path(
            "release-artifacts/evidence/public-beta-templates/"
            "fork-testnet-marketplace-indexer-evidence-template.json"
        ),
        DEFAULT_EVIDENCE[0],
        PUBLIC_BETA_REQUIREMENT_ID,
        PUBLIC_BETA_ENVIRONMENTS,
    ),
    (
        Path(
            "release-artifacts/evidence/production-release-templates/"
            "live-marketplace-indexer-evidence-template.json"
        ),
        DEFAULT_EVIDENCE[1],
        PRODUCTION_REQUIREMENT_ID,
        PRODUCTION_ENVIRONMENTS,
    ),
]

REQUIRED_HEADINGS = [
    "# Marketplace And Indexer Retained Artifact",
    "## Evidence Status",
    "## Source And Contract References",
    "## Coverage",
    "## Platform Results",
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
    "Git commit",
    "Release manifest/checksum digests",
    "Deployment manifest",
    "Address book",
    "Contract addresses",
    "Token IDs",
    "Collection IDs",
    "Marketplace/indexer tools",
    "Command or source system",
    "Contract metadata discovery",
    "ContractURI read",
    "ContractURIHash read",
    "ContractURIUpdated event observed",
    "Token metadata refresh",
    "ERC-4906 event observed",
    "Animation rendering",
    "Royalty display",
    "Royalty disclosure boundary",
    "Transfer/listing/sale path",
    "Event replay",
    "Cache invalidation",
    "Stale/failed/frozen/burned states",
    "Screenshot or public reference",
    "Query or transcript reference",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "API keys removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Git commit",
    "Release manifest/checksum digests",
    "Deployment manifest",
    "Address book",
    "Contract addresses",
    "Token IDs",
    "Collection IDs",
    "Marketplace/indexer tools",
    "Command or source system",
    "Contract metadata discovery",
    "ContractURI read",
    "ContractURIHash read",
    "ContractURIUpdated event observed",
    "Token metadata refresh",
    "ERC-4906 event observed",
    "Animation rendering",
    "Royalty display",
    "Transfer/listing/sale path",
    "Event replay",
    "Cache invalidation",
    "Stale/failed/frozen/burned states",
    "Screenshot or public reference",
    "Query or transcript reference",
    "Operator",
    "Reviewer",
]
REVIEWED_YES_FIELDS = [
    "Contract metadata discovery",
    "ContractURI read",
    "ContractURIHash read",
    "ContractURIUpdated event observed",
    "Token metadata refresh",
    "ERC-4906 event observed",
    "Animation rendering",
    "Royalty display",
    "Transfer/listing/sale path",
    "Event replay",
    "Cache invalidation",
    "Stale/failed/frozen/burned states",
]
REQUIRED_PLATFORM_PHRASES = [
    "OpenSea",
    "Reservoir",
    "Blur",
    "Manifold",
    "equivalent collector/indexer tooling",
]
REQUIRED_EVIDENCE_PHRASES = [
    "ONE-005",
    "retained marketplace/indexer evidence",
    "contract metadata",
    "contractURI()",
    "contractURIHash()",
    "ContractURIUpdated",
    "token metadata refresh",
    "ERC-4906",
    "MetadataUpdate",
    "BatchMetadataUpdate",
    "animation rendering",
    "royalty display",
    "royalty disclosure, not payment enforcement",
    "transfer/listing/sale path",
    "event replay",
    "cache invalidation",
    "fork/testnet/live evidence",
    "not release readiness proof",
    "No production-readiness claim depends on marketplaces honoring royalties",
]
REQUIRED_COMMANDS = [
    "python scripts/test_marketplace_indexer_evidence.py",
    "python scripts/check_marketplace_indexer_evidence.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|"
    r"unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)
CLI_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b(?:\s+|=)\S+|"
    r"--rpc-url\b(?:\s+|=)(?!<redacted>|redacted\b)\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s`]*(?:alchemy|infura|quicknode|api[_-]?key|apikey|token|secret)[^\s`]*"
    r")",
    re.IGNORECASE,
)


class MarketplaceIndexerEvidenceError(RuntimeError):
    """Raised when marketplace/indexer evidence is invalid."""


def normalize_value(value: str) -> str:
    """Normalize a Markdown field value."""
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    """Read UTF-8 text with checker-specific errors."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise MarketplaceIndexerEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise MarketplaceIndexerEvidenceError(f"{path} must be valid UTF-8") from exc


def load_json(path: Path) -> object:
    """Load JSON with checker-specific errors."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise MarketplaceIndexerEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise MarketplaceIndexerEvidenceError(f"{path} must be valid UTF-8") from exc
    except json.JSONDecodeError as exc:
        raise MarketplaceIndexerEvidenceError(f"invalid JSON in {path}: {exc}") from exc


def file_sha256(path: Path) -> str:
    """Return the sha256 digest string used by release evidence envelopes."""
    try:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
    except FileNotFoundError as exc:
        raise MarketplaceIndexerEvidenceError(f"missing required file: {path}") from exc
    return f"sha256:{digest}"


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value and CLI material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise MarketplaceIndexerEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise MarketplaceIndexerEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise MarketplaceIndexerEvidenceError(
                f"{path} is missing required heading: {heading}"
            ) from exc
        cursor = index + 1


def field_map(path: Path, text: str) -> dict[str, str]:
    """Extract Markdown bullet fields."""
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = FIELD_RE.match(line.strip())
        if not match:
            continue
        label = match.group("label").strip()
        value = normalize_value(match.group("value"))
        if label in fields:
            raise MarketplaceIndexerEvidenceError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise MarketplaceIndexerEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise MarketplaceIndexerEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def require_field_in(
    path: Path, fields: dict[str, str], label: str, choices: set[str]
) -> None:
    """Require one field to be in an allowed set."""
    actual = fields[label]
    if actual not in choices:
        expected = ", ".join(sorted(choices))
        raise MarketplaceIndexerEvidenceError(
            f"{path} field {label!r} must be one of {expected}, got {actual!r}"
        )


def is_placeholder(value: str) -> bool:
    """Return whether a value is still placeholder/template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or "<" in value


def require_text_phrases(path: Path, text: str, phrases: list[str]) -> None:
    """Require normalized phrases to appear in the artifact."""
    normalized_text = " ".join(text.lower().split())
    missing = [
        phrase
        for phrase in phrases
        if " ".join(phrase.lower().split()) not in normalized_text
    ]
    if missing:
        raise MarketplaceIndexerEvidenceError(
            f"{path} is missing required content: {', '.join(missing)}"
        )


def validate_requirement_environment(path: Path, fields: dict[str, str]) -> None:
    """Validate requirement ID, environment, and chain pairings."""
    requirement_id = fields["Requirement ID"]
    if requirement_id == PUBLIC_BETA_REQUIREMENT_ID:
        require_field_in(path, fields, "Environment", PUBLIC_BETA_ENVIRONMENTS)
        if fields["Chain ID"] == "not_applicable":
            raise MarketplaceIndexerEvidenceError(
                f"{path} public-beta marketplace/indexer evidence needs a chain ID"
            )
        return
    if requirement_id == PRODUCTION_REQUIREMENT_ID:
        require_field_in(path, fields, "Environment", PRODUCTION_ENVIRONMENTS)
        require_field_value(path, fields, "Chain ID", "1")
        return
    raise MarketplaceIndexerEvidenceError(
        f"{path} field 'Requirement ID' must be {PUBLIC_BETA_REQUIREMENT_ID!r} "
        f"or {PRODUCTION_REQUIREMENT_ID!r}"
    )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    """Validate template, pending-review, and reviewed state semantics."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise MarketplaceIndexerEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise MarketplaceIndexerEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if fields["Royalty disclosure boundary"] != (
        "royalty disclosure, not payment enforcement"
    ):
        raise MarketplaceIndexerEvidenceError(
            f"{path} field 'Royalty disclosure boundary' must state "
            "royalty disclosure, not payment enforcement"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise MarketplaceIndexerEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise MarketplaceIndexerEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise MarketplaceIndexerEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )

    require_field_value(path, fields, "No secrets retained", "yes")
    require_field_value(path, fields, "Private RPC URLs removed", "yes")
    require_field_value(path, fields, "Private keys removed", "yes")
    require_field_value(path, fields, "API keys removed", "yes")
    require_field_value(path, fields, "Unreleased drop payloads removed", "yes")

    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")
        for label in REVIEWED_YES_FIELDS:
            require_field_value(path, fields, label, "yes")


def validate_commands(path: Path, text: str) -> None:
    """Require the artifact to carry the validation sequence."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise MarketplaceIndexerEvidenceError(
                f"{path} is missing validation command: {command}"
            )


def validate_artifact(path: Path) -> None:
    """Validate one retained marketplace/indexer artifact."""
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Readiness claim", "blocked")
    validate_requirement_environment(path, fields)
    require_text_phrases(path, text, REQUIRED_PLATFORM_PHRASES)
    require_text_phrases(path, text, REQUIRED_EVIDENCE_PHRASES)
    validate_review_state(path, text, fields)
    validate_commands(path, text)


def require_json_string(data: dict[str, object], path: Path, key: str) -> str:
    """Return a required JSON string field."""
    value = data.get(key)
    if not isinstance(value, str) or not value:
        raise MarketplaceIndexerEvidenceError(
            f"{path} field {key!r} must be a non-empty string"
        )
    return value


def validate_envelope_template(
    envelope_path: Path,
    retained_path: Path,
    requirement_id: str,
    environments: set[str],
) -> None:
    """Validate an envelope template points at the retained template digest."""
    data = load_json(envelope_path)
    if not isinstance(data, dict):
        raise MarketplaceIndexerEvidenceError(f"{envelope_path} must be a JSON object")

    if require_json_string(data, envelope_path, "record_type") != "template":
        raise MarketplaceIndexerEvidenceError(
            f"{envelope_path} field 'record_type' must be 'template'"
        )
    if require_json_string(data, envelope_path, "review_status") != "template":
        raise MarketplaceIndexerEvidenceError(
            f"{envelope_path} field 'review_status' must be 'template'"
        )
    if (
        require_json_string(data, envelope_path, "public_beta_requirement_id")
        != requirement_id
    ):
        raise MarketplaceIndexerEvidenceError(
            f"{envelope_path} public_beta_requirement_id must be {requirement_id!r}"
        )
    environment = require_json_string(data, envelope_path, "environment")
    if environment not in environments:
        expected = ", ".join(sorted(environments))
        raise MarketplaceIndexerEvidenceError(
            f"{envelope_path} environment must be one of {expected}, got {environment!r}"
        )
    if (
        require_json_string(data, envelope_path, "retained_path")
        != retained_path.as_posix()
    ):
        raise MarketplaceIndexerEvidenceError(
            f"{envelope_path} retained_path must be {retained_path.as_posix()!r}"
        )

    expected_sha256 = file_sha256(retained_path)
    if require_json_string(data, envelope_path, "sha256") != expected_sha256:
        raise MarketplaceIndexerEvidenceError(
            f"{envelope_path} sha256 mismatch for {retained_path}: "
            f"expected {expected_sha256}"
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained marketplace and indexer evidence artifacts"
    )
    parser.add_argument(
        "--evidence",
        type=Path,
        action="append",
        help="Evidence Markdown path to validate; may be repeated.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    paths = args.evidence or DEFAULT_EVIDENCE
    try:
        for path in paths:
            validate_artifact(path)
        if args.evidence is None:
            for (
                envelope_path,
                retained_path,
                requirement_id,
                environments,
            ) in DEFAULT_ENVELOPE_TEMPLATES:
                validate_envelope_template(
                    envelope_path,
                    retained_path,
                    requirement_id,
                    environments,
                )
    except MarketplaceIndexerEvidenceError as exc:
        print(f"marketplace/indexer evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("marketplace/indexer evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
