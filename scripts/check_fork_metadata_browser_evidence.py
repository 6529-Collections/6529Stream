#!/usr/bin/env python3
"""Validate retained fork/testnet metadata browser evidence artifacts."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIREMENT_ID = "fork_testnet_metadata_browser_evidence"
EVIDENCE_TYPE = "fork_testnet_metadata_browser_evidence"
SUMMARY_SCHEMA = "6529stream.fork-testnet-metadata-browser-evidence.v1"
ALLOWED_ENVIRONMENTS = {"fork", "testnet"}
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/fork-metadata-browser/"
        "fork-metadata-browser-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Fork/Testnet Metadata Browser Retained Artifact",
    "## Evidence Status",
    "## Source And Fork/Testnet Reference",
    "## Required Retained Artifacts",
    "## Browser Results",
    "## Review",
    "## Redaction",
    "## Validation Commands",
    "## Operator Notes",
]

REQUIRED_FIELDS = {
    "Requirement ID",
    "Evidence type",
    "Review status",
    "Readiness claim",
    "Environment",
    "Chain ID",
    "Repository",
    "Git commit",
    "CI run or operator transcript",
    "Fork/testnet block or reference",
    "Network and deployment version",
    "Contract addresses",
    "Token IDs",
    "Collection IDs",
    "Browser summary JSON",
    "Generated tokenURI or digest",
    "Browser transcript or screenshot",
    "Release manifest/checksum digests",
    "Metadata fetched from deployed contracts",
    "Browser sandbox executed",
    "Unexpected outbound requests blocked",
    "Console and page errors absent",
    "Animation bootstrap verified",
    "Parent frame isolation verified",
    "Token and collection IDs retained",
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
    "CI run or operator transcript",
    "Fork/testnet block or reference",
    "Network and deployment version",
    "Contract addresses",
    "Token IDs",
    "Collection IDs",
    "Browser summary JSON",
    "Generated tokenURI or digest",
    "Browser transcript or screenshot",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]
REVIEWED_YES_FIELDS = [
    "Metadata fetched from deployed contracts",
    "Browser sandbox executed",
    "Unexpected outbound requests blocked",
    "Console and page errors absent",
    "Animation bootstrap verified",
    "Parent frame isolation verified",
    "Token and collection IDs retained",
]
RETAINED_FILE_FIELDS = [
    "Browser summary JSON",
    "Generated tokenURI or digest",
    "Browser transcript or screenshot",
]

REQUIRED_COMMANDS = [
    "python scripts/test_fork_metadata_browser_evidence.py",
    "python scripts/check_fork_metadata_browser_evidence.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]
REQUIRED_TEMPLATE_ARGUMENT = (
    "--template "
    "release-artifacts/evidence/public-beta-templates/"
    "fork-testnet-metadata-browser-evidence-template.json"
)

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
CHAIN_ID_RE = re.compile(r"^[1-9][0-9]*$")
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
    r"https?://[^\s`]*(?:alchemy|ankr|blastapi|chainstack|infura|quicknode)[^\s`]*|"
    r"https?://[^\s`]*[?&](?:api[_-]?key|apikey|token|secret)=[^\s`&]+"
    r")",
    re.IGNORECASE,
)


class ForkMetadataBrowserEvidenceError(RuntimeError):
    """Raised when fork/testnet metadata browser evidence is invalid."""


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
        raise ForkMetadataBrowserEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise ForkMetadataBrowserEvidenceError(f"{path} must be valid UTF-8") from exc


def load_json(path: Path) -> Any:
    """Load JSON with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ForkMetadataBrowserEvidenceError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ForkMetadataBrowserEvidenceError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, context: str) -> dict[str, Any]:
    """Require a JSON value to be an object."""
    if not isinstance(value, dict):
        raise ForkMetadataBrowserEvidenceError(f"{context} must be an object")
    return value


def require_string(value: Any, context: str) -> str:
    """Require a JSON value to be a non-empty string."""
    if not isinstance(value, str) or not value:
        raise ForkMetadataBrowserEvidenceError(f"{context} must be a non-empty string")
    return value


def require_bool(value: Any, context: str) -> bool:
    """Require a JSON value to be a boolean."""
    if not isinstance(value, bool):
        raise ForkMetadataBrowserEvidenceError(f"{context} must be a boolean")
    return value


def require_array(value: Any, context: str) -> list[Any]:
    """Require a JSON value to be an array."""
    if not isinstance(value, list):
        raise ForkMetadataBrowserEvidenceError(f"{context} must be an array")
    return value


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value, CLI, and provider URL material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise ForkMetadataBrowserEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise ForkMetadataBrowserEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )


def repo_root_for(path: Path) -> Path:
    """Return the root used for repo-relative retained artifact paths."""
    cwd = Path.cwd().resolve()
    resolved = path.resolve()
    try:
        resolved.relative_to(cwd)
    except ValueError:
        # Standalone --evidence files resolve retained paths beside that artifact.
        return resolved.parent
    return cwd


def resolve_repo_relative_path(root: Path, value: str) -> Path:
    """Resolve a retained artifact path while rejecting escapes."""
    candidate = Path(value)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ForkMetadataBrowserEvidenceError(
            f"retained artifact path must be repo-relative: {value}"
        )
    resolved = (root / candidate).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise ForkMetadataBrowserEvidenceError(
            f"retained artifact path escapes repository: {value}"
        ) from exc
    return resolved


def referenced_artifact_paths(path: Path, fields: dict[str, str]) -> dict[str, Path]:
    """Return resolved referenced retained artifact paths."""
    root = repo_root_for(path)
    return {
        label: resolve_repo_relative_path(root, fields[label])
        for label in RETAINED_FILE_FIELDS
    }


def validate_referenced_artifacts(path: Path, fields: dict[str, str]) -> None:
    """Require reviewed retained artifact paths to exist and be no-secret."""
    for label, target in referenced_artifact_paths(path, fields).items():
        if not target.is_file():
            raise ForkMetadataBrowserEvidenceError(
                f"{path} field {label!r} points to missing retained file: {fields[label]}"
            )
        validate_no_secret_values(target, read_text(target))


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise ForkMetadataBrowserEvidenceError(
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
            raise ForkMetadataBrowserEvidenceError(f"{path} has duplicate field: {label}")
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise ForkMetadataBrowserEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise ForkMetadataBrowserEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def require_environment(path: Path, value: str) -> str:
    """Require a fork or testnet environment marker."""
    if value not in ALLOWED_ENVIRONMENTS:
        expected = ", ".join(sorted(ALLOWED_ENVIRONMENTS))
        raise ForkMetadataBrowserEvidenceError(
            f"{path} field 'Environment' must be one of: {expected}"
        )
    return value


def require_positive_chain_id(path: Path, value: str, label: str = "Chain ID") -> int:
    """Require a positive decimal chain ID."""
    if not CHAIN_ID_RE.fullmatch(value):
        raise ForkMetadataBrowserEvidenceError(
            f"{path} field {label!r} must be a positive integer"
        )
    try:
        chain_id = int(value, 10)
    except ValueError as exc:
        raise ForkMetadataBrowserEvidenceError(
            f"{path} field {label!r} must be a positive integer"
        ) from exc
    if chain_id <= 0 or str(chain_id) != value:
        raise ForkMetadataBrowserEvidenceError(
            f"{path} field {label!r} must be a positive integer"
        )
    return chain_id


def is_placeholder(value: str) -> bool:
    """Return whether a value is still placeholder/template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or bool(
        ANGLE_PLACEHOLDER_RE.search(value)
    )


def require_address(value: Any, context: str) -> str:
    """Require an Ethereum address-shaped JSON value."""
    if not isinstance(value, str) or not ADDRESS_RE.fullmatch(value):
        raise ForkMetadataBrowserEvidenceError(f"{context} must be a 20-byte address")
    return value.lower()


def validate_summary_contracts(path: Path, data: dict[str, Any]) -> None:
    """Validate contract address references in the browser summary."""
    contracts = require_dict(data.get("contracts"), f"{path}.contracts")
    if not contracts:
        raise ForkMetadataBrowserEvidenceError(f"{path}.contracts must not be empty")
    seen: dict[str, str] = {}
    for name, value in contracts.items():
        if not isinstance(name, str) or not name:
            raise ForkMetadataBrowserEvidenceError(f"{path}.contracts has invalid name")
        record = require_dict(value, f"{path}.contracts.{name}")
        address = require_address(record.get("address"), f"{path}.contracts.{name}.address")
        if address in seen:
            raise ForkMetadataBrowserEvidenceError(
                f"{path} duplicates contract address {record.get('address')} for "
                f"{seen[address]} and {name}"
            )
        seen[address] = name


def validate_token_result(path: Path, index: int, value: Any) -> None:
    """Validate one retained browser result row."""
    row = require_dict(value, f"{path}.token_results[{index}]")
    token_id = row.get("token_id")
    collection_id = row.get("collection_id")
    if not isinstance(token_id, int) or isinstance(token_id, bool) or token_id < 0:
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.token_results[{index}].token_id must be a non-negative integer"
        )
    if (
        not isinstance(collection_id, int)
        or isinstance(collection_id, bool)
        or collection_id < 0
    ):
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.token_results[{index}].collection_id must be a non-negative integer"
        )

    digest = require_string(
        row.get("token_uri_sha256"),
        f"{path}.token_results[{index}].token_uri_sha256",
    )
    if not SHA256_RE.fullmatch(digest):
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.token_results[{index}].token_uri_sha256 must be sha256:<hex>"
        )

    sandbox = require_dict(row.get("sandbox"), f"{path}.token_results[{index}].sandbox")
    required_true = [
        "metadata_fetched_from_deployed_contract",
        "browser_executed",
        "dependency_loaded",
        "draw_is_function",
        "parent_access_blocked",
    ]
    for key in required_true:
        if not require_bool(sandbox.get(key), f"{path}.token_results[{index}].sandbox.{key}"):
            raise ForkMetadataBrowserEvidenceError(
                f"{path}.token_results[{index}].sandbox.{key} must be true"
            )
    if require_array(
        sandbox.get("unexpected_requests"),
        f"{path}.token_results[{index}].sandbox.unexpected_requests",
    ):
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.token_results[{index}].sandbox.unexpected_requests must be empty"
        )
    if require_array(
        sandbox.get("page_errors"),
        f"{path}.token_results[{index}].sandbox.page_errors",
    ):
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.token_results[{index}].sandbox.page_errors must be empty"
        )
    if require_array(
        sandbox.get("console_errors"),
        f"{path}.token_results[{index}].sandbox.console_errors",
    ):
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.token_results[{index}].sandbox.console_errors must be empty"
        )


def validate_browser_summary(path: Path, fields: dict[str, str]) -> None:
    """Validate retained fork/testnet metadata browser summary JSON."""
    data = require_dict(load_json(path), str(path))
    if require_string(data.get("schema_version"), f"{path}.schema_version") != SUMMARY_SCHEMA:
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.schema_version must be {SUMMARY_SCHEMA!r}"
        )
    environment = require_string(data.get("environment"), f"{path}.environment")
    if environment != fields["Environment"]:
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.environment must match retained artifact environment"
        )
    require_environment(path, environment)
    chain_id = data.get("chain_id")
    if not isinstance(chain_id, int) or isinstance(chain_id, bool) or chain_id <= 0:
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.chain_id must be a positive integer"
        )
    if chain_id != require_positive_chain_id(path, fields["Chain ID"]):
        raise ForkMetadataBrowserEvidenceError(
            f"{path}.chain_id must match retained artifact chain ID"
        )
    if not require_bool(data.get("no_secrets"), f"{path}.no_secrets"):
        raise ForkMetadataBrowserEvidenceError(f"{path}.no_secrets must be true")
    source = require_dict(data.get("source"), f"{path}.source")
    require_string(source.get("git_commit"), f"{path}.source.git_commit")
    require_string(source.get("command_or_source_system"), f"{path}.source.command_or_source_system")
    validate_summary_contracts(path, data)
    token_results = require_array(data.get("token_results"), f"{path}.token_results")
    if not token_results:
        raise ForkMetadataBrowserEvidenceError(f"{path}.token_results must not be empty")
    for index, value in enumerate(token_results):
        validate_token_result(path, index, value)


def validate_payloads(path: Path, fields: dict[str, str]) -> None:
    """Validate retained payload files for reviewed/pending evidence."""
    validate_referenced_artifacts(path, fields)
    validate_browser_summary(
        referenced_artifact_paths(path, fields)["Browser summary JSON"],
        fields,
    )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    """Validate template, pending-review, and reviewed state semantics."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise ForkMetadataBrowserEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise ForkMetadataBrowserEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise ForkMetadataBrowserEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise ForkMetadataBrowserEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise ForkMetadataBrowserEvidenceError(
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
        validate_payloads(path, fields)
    elif review_status == "pending_review":
        validate_payloads(path, fields)


def validate_commands(path: Path, text: str) -> None:
    """Require the artifact to carry the validation sequence."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise ForkMetadataBrowserEvidenceError(
                f"{path} is missing validation command: {command}"
            )
    if REQUIRED_TEMPLATE_ARGUMENT not in text:
        raise ForkMetadataBrowserEvidenceError(
            f"{path} is missing validation command argument: {REQUIRED_TEMPLATE_ARGUMENT}"
        )


def validate_artifact(path: Path) -> None:
    """Validate one retained fork/testnet metadata browser artifact."""
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Evidence type", EVIDENCE_TYPE)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_environment(path, fields["Environment"])
    require_positive_chain_id(path, fields["Chain ID"])
    validate_review_state(path, text, fields)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained fork/testnet metadata browser evidence artifacts"
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
    except ForkMetadataBrowserEvidenceError as exc:
        print(f"fork/testnet metadata browser evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("fork/testnet metadata browser evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
