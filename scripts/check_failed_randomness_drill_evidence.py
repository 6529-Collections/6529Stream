#!/usr/bin/env python3
"""Validate retained failed-randomness drill evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "failed_randomness_drill_evidence"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/incident-drills/"
        "failed-randomness-drill-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Failed Randomness Drill Retained Artifact",
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
    "Randomizer adapter",
    "Randomizer provider type",
    "Request ID",
    "Provider request ID",
    "Token ID",
    "Collection ID",
    "Randomizer epoch",
    "Request path",
    "Failure mode",
    "Starting request state",
    "Ending request state",
    "Starting metadata state",
    "Ending metadata state",
    "Pending-age evidence",
    "Invalid callback evidence",
    "Provider epoch evidence",
    "Provider migration boundary evidence",
    "Randomness pause evidence",
    "Metadata state snapshot evidence",
    "Retry or stale-marking decision",
    "Stored seed or raw-output evidence",
    "Post-processing retry evidence",
    "Stale request marking evidence",
    "Final token hash evidence",
    "Duplicate callback rejection evidence",
    "Post-recovery pending-count evidence",
    "Operator dashboard confirmation",
    "Monitoring alert reference",
    "Incident response decision log",
    "Public communication status",
    "Follow-up issue links",
    "Command transcript bundle",
    "Event or state snapshot bundle",
    "Randomizer operations evidence",
    "Metadata rendering evidence",
    "Admin ceremony evidence",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Provider dashboard secrets removed",
    "Raw randomness payloads removed",
    "Unreleased token metadata removed",
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
        "Provider dashboard secrets removed",
        "Raw randomness payloads removed",
        "Unreleased token metadata removed",
        "Private collector data removed",
    }
)

REDACTION_FIELDS = (
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Provider dashboard secrets removed",
    "Raw randomness payloads removed",
    "Unreleased token metadata removed",
    "Private collector data removed",
)

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
READINESS_CLAIMS = {"blocked", "complete"}
ENVIRONMENTS = {"template", "fork", "testnet", "live"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
PROVIDER_TYPES = {"vrf", "arrng"}
REQUEST_PATHS = {
    "pending_timeout",
    "invalid_callback",
    "post_processing_failed",
    "provider_migration",
    "stale_marking",
}
FAILURE_MODES_BY_PATH = {
    "pending_timeout": {"pending_too_long"},
    "invalid_callback": {
        "unknown_request",
        "wrong_token",
        "wrong_collection",
        "wrong_provider",
        "stale_epoch",
        "duplicate_callback",
    },
    "post_processing_failed": {"metadata_write_failed", "core_rejected_seed"},
    "provider_migration": {"migration_blocked_pending", "migration_after_stale"},
    "stale_marking": {"manual_stale_mark"},
}
REQUEST_STATES = {"Pending", "Stale", "FailedPostProcessing", "Fulfilled"}
METADATA_STATES = {"pending", "stale", "failed", "final"}
ENDING_REQUEST_STATE_BY_PATH = {
    "pending_timeout": {"Stale", "Fulfilled"},
    "invalid_callback": {"Pending", "Stale", "Fulfilled"},
    "post_processing_failed": {"FailedPostProcessing", "Fulfilled"},
    "provider_migration": {"Stale", "Fulfilled"},
    "stale_marking": {"Stale"},
}
ENDING_METADATA_STATE_BY_REQUEST_STATE = {
    "Pending": {"pending"},
    "Stale": {"stale"},
    "FailedPostProcessing": {"failed"},
    "Fulfilled": {"final"},
}
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

REQUIRED_COMMANDS = [
    "python scripts/test_failed_randomness_drill_evidence.py",
    "python scripts/check_failed_randomness_drill_evidence.py",
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
    # These checks are intentionally brittle substring guards. They make the
    # evidence checker fail loudly if the source/test anchors it documents move.
    Path("smart-contracts/StreamRandomizerLifecycle.sol"): [
        "event RandomnessRequested",
        "event RandomnessFulfilled",
        "event RandomnessRequestMarkedStale",
        "event RandomnessPostProcessingFailed",
        "event RandomnessPostProcessingRetried",
        "event RandomnessPostProcessingRetryFailed",
        "function _fulfillRandomness",
        "function _markRandomnessRequestStale",
        "function _prepareRandomnessPostProcessingRetry",
        "StaleRandomnessRequest",
    ],
    Path("smart-contracts/RandomizerVRF.sol"): [
        "function fulfillRandomWords",
        "function markStaleRequest",
        "function retryRandomnessPostProcessing",
    ],
    Path("smart-contracts/RandomizerRNG.sol"): [
        "function fulfillRandomWords",
        "function markStaleRequest",
        "function retryRandomnessPostProcessing",
    ],
    Path("test/StreamRandomizerLifecycle.t.sol"): [
        "testVrfUnknownAndEmptyFulfillmentsFailClosed",
        "testVrfPostProcessingFailureRecordsFailedState",
        "testVrfStaleEpochOrProviderFulfillmentFails",
        "testMarkedStaleRequestIsObservableAndCannotFulfill",
        "testMarkedStaleRequestUnblocksMigrationAndNewProviderFulfillment",
        "testArrngRequestAndFulfillmentUseSameLifecycle",
    ],
    Path("test/StreamRandomizerRetry.t.sol"): [
        "testVrfRetryCompletesFailedPostProcessingWithStoredSeed",
        "testArrngRetryCompletesFailedPostProcessingWithStoredSeed",
        "testRetryRejectsChangedRandomizerEpoch",
        "testRetryRejectsChangedRandomizerProvider",
        "MAX_RANDOMNESS_POST_PROCESSING_RETRIES",
    ],
    Path("docs/randomizer-operations.md"): [
        "pending request count",
        "stale or failed request IDs",
        "retry",
        "provider epoch",
        "provider migration",
    ],
    Path("docs/metadata.md"): [
        "Stale randomness",
        "Failed randomness",
        "pending",
        "stale",
        "failed",
        "final",
    ],
}

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
UINT_RE = re.compile(r"^(0|[1-9][0-9]*)$")
ADDRESS_RE = re.compile(r"^0x[a-fA-F0-9]{40}$")
GIT_COMMIT_RE = re.compile(r"^[a-fA-F0-9]{40}([a-fA-F0-9]{24})?$")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|provider[_ -]?dashboard[_ -]?secret|"
    r"raw[_ -]?randomness[_ -]?payload|vrf[_ -]?secret|arrng[_ -]?secret|"
    r"unreleased[_ -]?token[_ -]?metadata|private[_ -]?collector[_ -]?data"
    r")\s*[:=]",
    re.IGNORECASE,
)
CREDENTIAL_URL_RE = re.compile(r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+", re.IGNORECASE)


class FailedRandomnessDrillEvidenceError(RuntimeError):
    """Raised when failed-randomness drill evidence is invalid."""


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise FailedRandomnessDrillEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise FailedRandomnessDrillEvidenceError(f"{path} must be valid UTF-8") from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    for match in CREDENTIAL_URL_RE.finditer(text):
        line = text.rfind("\n", 0, match.start()) + 1
        line_text = text[line : text.find("\n", match.start())]
        if "[REDACTED]" in line_text or "<redacted>" in line_text.lower():
            continue
        raise FailedRandomnessDrillEvidenceError(
            f"{path} contains credentialed URL text: {match.group(0)}"
        )


def validate_headings(path: Path, text: str) -> None:
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise FailedRandomnessDrillEvidenceError(
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
            raise FailedRandomnessDrillEvidenceError(f"{path} has duplicate field: {label}")
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} is missing required fields: {', '.join(missing)}"
        )
    return fields


def require_value(path: Path, fields: dict[str, str], label: str, allowed: set[str]) -> str:
    value = fields[label]
    if value not in allowed:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field {label} must be one of {sorted(allowed)}"
        )
    return value


def require_uint(path: Path, fields: dict[str, str], label: str) -> int:
    value = fields[label]
    if not UINT_RE.match(value):
        raise FailedRandomnessDrillEvidenceError(f"{path} field {label} must be a uint")
    return int(value)


def require_address(path: Path, fields: dict[str, str], label: str) -> None:
    value = fields[label]
    if not ADDRESS_RE.match(value) or value.lower() == ZERO_ADDRESS:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field {label} must be a non-zero Ethereum address"
        )


def validate_template(path: Path, fields: dict[str, str], text: str) -> None:
    if fields["Review status"] != "template":
        return
    if "Template only. This file is not completion evidence." not in text:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} template evidence must keep the template-only warning"
        )
    if fields["Environment"] != "template":
        raise FailedRandomnessDrillEvidenceError(f"{path} template environment must be template")
    if fields["Readiness claim"] != "blocked":
        raise FailedRandomnessDrillEvidenceError(f"{path} template readiness must be blocked")
    if fields["Review decision"] != "template":
        raise FailedRandomnessDrillEvidenceError(f"{path} template decision must be template")


def validate_review_lifecycle(path: Path, fields: dict[str, str], text: str) -> None:
    review_status = require_value(path, fields, "Review status", REVIEW_STATUSES)
    readiness = require_value(path, fields, "Readiness claim", READINESS_CLAIMS)
    environment = require_value(path, fields, "Environment", ENVIRONMENTS)
    decision = require_value(path, fields, "Review decision", REVIEW_DECISIONS)

    if fields["Requirement ID"] != REQUIREMENT_ID:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field Requirement ID must be {REQUIREMENT_ID}"
        )
    if fields["Incident class"] != "failed_randomness":
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field Incident class must be failed_randomness"
        )
    if review_status == "template":
        validate_template(path, fields, text)
        return
    if "Template only. This file is not completion evidence." in text:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} non-template evidence must remove the template-only warning"
        )
    if environment == "template":
        raise FailedRandomnessDrillEvidenceError(
            f"{path} reviewed evidence cannot use template environment"
        )
    if readiness == "complete" and (review_status != "reviewed" or decision != "reviewed"):
        raise FailedRandomnessDrillEvidenceError(
            f"{path} Readiness claim complete requires reviewed status and decision"
        )
    if review_status == "reviewed" and readiness != "complete":
        raise FailedRandomnessDrillEvidenceError(
            f"{path} reviewed evidence must make a complete readiness claim"
        )


def validate_final_fields(path: Path, fields: dict[str, str]) -> None:
    if fields["Review status"] == "template":
        return
    for label in FINAL_VALUE_FIELDS:
        value = fields[label]
        if value in {"", "TBD", "TODO", "N/A"} or ANGLE_PLACEHOLDER_RE.search(value):
            raise FailedRandomnessDrillEvidenceError(
                f"{path} field {label} must be replaced before review"
            )
    for label in REDACTION_FIELDS:
        if fields[label].lower() != "yes":
            raise FailedRandomnessDrillEvidenceError(
                f"{path} field {label} must be yes after redaction review"
            )


def validate_randomizer_fields(path: Path, fields: dict[str, str]) -> None:
    if fields["Review status"] == "template":
        return
    require_uint(path, fields, "Chain ID")
    require_uint(path, fields, "Request ID")
    require_uint(path, fields, "Provider request ID")
    require_uint(path, fields, "Token ID")
    require_uint(path, fields, "Collection ID")
    require_uint(path, fields, "Randomizer epoch")
    require_address(path, fields, "Randomizer adapter")
    if not GIT_COMMIT_RE.match(fields["Release commit"]):
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field Release commit must be a 40-char SHA-1 or 64-char SHA-256 hex commit"
        )

    require_value(path, fields, "Randomizer provider type", PROVIDER_TYPES)
    request_path = require_value(path, fields, "Request path", REQUEST_PATHS)
    failure_mode = fields["Failure mode"]
    allowed_modes = FAILURE_MODES_BY_PATH[request_path]
    if failure_mode not in allowed_modes:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field Failure mode must match Request path {request_path}: "
            f"{sorted(allowed_modes)}"
        )
    starting_state = require_value(path, fields, "Starting request state", REQUEST_STATES)
    ending_state = require_value(path, fields, "Ending request state", REQUEST_STATES)
    starting_metadata = require_value(path, fields, "Starting metadata state", METADATA_STATES)
    ending_metadata = require_value(path, fields, "Ending metadata state", METADATA_STATES)

    if starting_state != "Pending":
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field Starting request state must be Pending for incident drill evidence"
        )
    if starting_metadata != "pending":
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field Starting metadata state must be pending for incident drill evidence"
        )
    if ending_state not in ENDING_REQUEST_STATE_BY_PATH[request_path]:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field Ending request state must match Request path {request_path}: "
            f"{sorted(ENDING_REQUEST_STATE_BY_PATH[request_path])}"
        )
    if ending_metadata not in ENDING_METADATA_STATE_BY_REQUEST_STATE[ending_state]:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} field Ending metadata state must match Ending request state {ending_state}: "
            f"{sorted(ENDING_METADATA_STATE_BY_REQUEST_STATE[ending_state])}"
        )
    if request_path == "post_processing_failed" and fields["Stored seed or raw-output evidence"] in {
        "",
        "TBD",
        "none",
    }:
        raise FailedRandomnessDrillEvidenceError(
            f"{path} post-processing recovery must retain stored seed or raw-output evidence"
        )
    if request_path == "invalid_callback" and ending_state == "Fulfilled":
        raise FailedRandomnessDrillEvidenceError(
            f"{path} invalid callback drill cannot end as Fulfilled from the invalid callback itself"
        )


def validate_required_commands(path: Path, text: str) -> None:
    missing = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing:
        raise FailedRandomnessDrillEvidenceError(
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
        raise FailedRandomnessDrillEvidenceError(
            "missing failed-randomness source/test anchors: " + "; ".join(missing)
        )


def validate_evidence(path: Path, root: Path | None = None) -> None:
    root = root or Path(".")
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)
    validate_review_lifecycle(path, fields, text)
    validate_final_fields(path, fields)
    validate_randomizer_fields(path, fields)
    validate_required_commands(path, text)
    validate_source_requirements(root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate retained failed-randomness drill evidence artifacts."
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
    except FailedRandomnessDrillEvidenceError as exc:
        print(f"failed-randomness-drill-evidence check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
