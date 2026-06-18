#!/usr/bin/env python3
"""Validate retained live deployment-manifest evidence artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIREMENT_ID = "live_deployment_manifest"
EXPECTED_ENVIRONMENT = "live"
EXPECTED_CHAIN_ID = "1"
EXPECTED_CHAIN_ID_INT = 1
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVIDENCE_RELATIVE = Path(
    "release-artifacts/evidence/live-deployment-manifest/"
    "live-deployment-manifest-retained-artifact-template.md"
)
DEFAULT_EVIDENCE = [DEFAULT_REPO_ROOT / DEFAULT_EVIDENCE_RELATIVE]

REQUIRED_HEADINGS = [
    "# Live Deployment Manifest Retained Artifact",
    "## Evidence Status",
    "## Source And Production Reference",
    "## Required Retained Artifacts",
    "## Deployment Manifest Results",
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
    "CI run or operator transcript",
    "Production block or reference",
    "Network and deployment version",
    "Command or source system",
    "Broadcast manifest input",
    "Generated live deployment manifest",
    "Generated live address book",
    "Source verification inputs",
    "Release manifest/checksum digests",
    "Manifest generated from production inputs",
    "Chain ID matches live",
    "Contract addresses finalized",
    "Runtime bytecode hashes retained",
    "Constructor arguments retained",
    "Release digest references retained",
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
    "Production block or reference",
    "Network and deployment version",
    "Command or source system",
    "Broadcast manifest input",
    "Generated live deployment manifest",
    "Generated live address book",
    "Source verification inputs",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]
REVIEWED_YES_FIELDS = [
    "Manifest generated from production inputs",
    "Chain ID matches live",
    "Contract addresses finalized",
    "Runtime bytecode hashes retained",
    "Constructor arguments retained",
    "Release digest references retained",
]
RETAINED_FILE_FIELDS = [
    "Broadcast manifest input",
    "Generated live deployment manifest",
    "Generated live address book",
    "Source verification inputs",
    "Release manifest/checksum digests",
]

DEPLOYMENT_MANIFEST_FIELD = "Generated live deployment manifest"
ADDRESS_BOOK_FIELD = "Generated live address book"
RELEASE_DIGESTS_FIELD = "Release manifest/checksum digests"

REQUIRED_COMMANDS = [
    "python scripts/test_live_deployment_manifest_evidence.py",
    "python scripts/check_live_deployment_manifest_evidence.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
GIT_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_REF_RE = re.compile(r"sha256:[0-9a-f]{64}")
SHA256_PREFIX_RE = re.compile(r"sha256:", re.IGNORECASE)
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
    r"--rpc-url\b(?:\s+|=)(?!<redacted>|redacted\b|REDACTED_(?:MAINNET_)?RPC(?=\s|$))\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+(?:<[^>\s]+>|[A-Za-z0-9._~+/=-]{12,})|"
    r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+|"
    r"https?://[^\s`]*(?:alchemy|infura|quicknode|api[_-]?key|apikey|token|secret)[^\s`]*|"
    r"https?://[^\s`]*[?&](?:api[_-]?key|apikey|token|secret)=[^\s`&]+"
    r")",
    re.IGNORECASE,
)
BARE_HEX_KEY_RE = re.compile(
    r"(?<![0-9a-fA-FxX:])(?:[0-9a-fA-F]{64})(?![0-9a-fA-F])"
)


class LiveDeploymentManifestEvidenceError(RuntimeError):
    """Raised when live deployment manifest evidence is invalid."""


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
        raise LiveDeploymentManifestEvidenceError(
            f"missing required file: {path}"
        ) from exc
    except UnicodeDecodeError as exc:
        raise LiveDeploymentManifestEvidenceError(f"{path} must be valid UTF-8") from exc


def load_json(path: Path) -> Any:
    """Load JSON with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise LiveDeploymentManifestEvidenceError(
            f"missing required file: {path}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise LiveDeploymentManifestEvidenceError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, context: str) -> dict[str, Any]:
    """Require a JSON value to be an object."""
    if not isinstance(value, dict):
        raise LiveDeploymentManifestEvidenceError(f"{context} must be an object")
    return value


def file_sha256(path: Path) -> str:
    """Return a sha256: digest for one file."""
    hasher = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                hasher.update(chunk)
    except FileNotFoundError as exc:
        raise LiveDeploymentManifestEvidenceError(
            f"missing required file: {path}"
        ) from exc
    except OSError as exc:
        raise LiveDeploymentManifestEvidenceError(
            f"could not read retained file for sha256: {path}: {exc}"
        ) from exc
    return "sha256:" + hasher.hexdigest()


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value, CLI, URL, token, and bare-key material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )
    match = BARE_HEX_KEY_RE.search(text)
    if match:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} contains bare 64-hex secret-like text: {match.group(0)}"
        )


def split_retained_file_reference(value: str) -> tuple[str, str | None]:
    """Split a retained file reference into path text and optional digest."""
    cleaned = value.strip()
    if "`" in cleaned:
        raise LiveDeploymentManifestEvidenceError(
            f"retained artifact reference must not contain backticks: {value}"
        )
    digest_prefixes = [
        match
        for match in SHA256_PREFIX_RE.finditer(cleaned)
        if cleaned[: match.start()].endswith(" / ")
        or (match.start() > 0 and cleaned[match.start() - 1].isspace())
    ]
    if len(digest_prefixes) > 1:
        raise LiveDeploymentManifestEvidenceError(
            f"retained artifact reference has multiple sha256 digests: {value}"
        )
    if not digest_prefixes:
        strict_matches = list(SHA256_REF_RE.finditer(cleaned))
        if strict_matches:
            raise LiveDeploymentManifestEvidenceError(
                "retained artifact reference must separate path and sha256 digest "
                f"with whitespace or ' / ': {value}"
            )
        if not cleaned:
            raise LiveDeploymentManifestEvidenceError(
                f"retained artifact reference is missing a path: {value}"
            )
        return cleaned, None

    digest_start = digest_prefixes[0].start()
    match = SHA256_REF_RE.match(cleaned[digest_start:])
    if not match:
        raise LiveDeploymentManifestEvidenceError(
            f"retained artifact reference has malformed sha256 digest: {value}"
        )
    digest = match.group(0)
    digest_end = digest_start + match.end()
    path_with_separator = cleaned[:digest_start]
    if path_with_separator.endswith(" / "):
        path_text = path_with_separator[:-3].strip()
    else:
        path_text = path_with_separator.rstrip()
    suffix = cleaned[digest_end:].strip()
    if suffix:
        raise LiveDeploymentManifestEvidenceError(
            f"retained artifact reference has trailing text after sha256 digest: {value}"
        )
    if not path_text:
        raise LiveDeploymentManifestEvidenceError(
            f"retained artifact reference is missing a path: {value}"
        )
    return path_text, digest


def resolve_retained_path(
    artifact_path: Path, repo_root: Path, label: str, value: str
) -> tuple[Path, str, str | None]:
    """Resolve and constrain a retained artifact path."""
    path_text, expected_digest = split_retained_file_reference(value)
    if re.search(r"\s", path_text):
        raise LiveDeploymentManifestEvidenceError(
            f"{artifact_path} field {label!r} must be one repo-relative path"
        )
    retained_path = Path(path_text)
    if retained_path.is_absolute() or retained_path.drive or retained_path.root:
        raise LiveDeploymentManifestEvidenceError(
            f"{artifact_path} field {label!r} must be repo-relative"
        )
    if "\\" in path_text or ".." in retained_path.parts:
        raise LiveDeploymentManifestEvidenceError(
            f"{artifact_path} field {label!r} must not escape the repository"
        )
    candidate = repo_root / retained_path
    resolved = candidate.resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise LiveDeploymentManifestEvidenceError(
            f"{artifact_path} field {label!r} escapes repository: {path_text}"
        ) from exc
    return candidate, path_text, expected_digest


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise LiveDeploymentManifestEvidenceError(
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
            raise LiveDeploymentManifestEvidenceError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def is_placeholder(value: str) -> bool:
    """Return whether a value is still placeholder/template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or bool(
        ANGLE_PLACEHOLDER_RE.search(value)
    )


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def validate_common_fields(path: Path, fields: dict[str, str]) -> None:
    """Validate fields that apply to templates and reviewed artifacts."""
    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_field_value(path, fields, "Environment", EXPECTED_ENVIRONMENT)
    require_field_value(path, fields, "Chain ID", EXPECTED_CHAIN_ID)

    if fields["Review status"] not in REVIEW_STATUSES:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} has invalid Review status: {fields['Review status']}"
        )
    if fields["Review decision"] not in REVIEW_DECISIONS:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} has invalid Review decision: {fields['Review decision']}"
        )
    if fields["Review status"] == "template" and fields["Review decision"] != "template":
        raise LiveDeploymentManifestEvidenceError(
            f"{path} template evidence must use template review decision"
        )
    if fields["Review status"] != "template" and fields["Review decision"] == "template":
        raise LiveDeploymentManifestEvidenceError(
            f"{path} non-template evidence cannot use template review decision"
        )


def validate_reviewed_fields(path: Path, fields: dict[str, str]) -> None:
    """Validate fields required once evidence leaves template state."""
    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise LiveDeploymentManifestEvidenceError(
                f"{path} field {label!r} must be filled before review"
            )
    for label in REVIEWED_YES_FIELDS:
        if fields[label].lower() != "yes":
            raise LiveDeploymentManifestEvidenceError(
                f"{path} field {label!r} must be yes for reviewed evidence"
            )
    for label in [
        "No secrets retained",
        "Private RPC URLs removed",
        "Private keys removed",
        "API keys removed",
        "Unreleased drop payloads removed",
    ]:
        if fields[label].lower() != "yes":
            raise LiveDeploymentManifestEvidenceError(
                f"{path} field {label!r} must be yes for reviewed evidence"
            )
    if not GIT_COMMIT_RE.match(fields["Git commit"]):
        raise LiveDeploymentManifestEvidenceError(
            f"{path} field 'Git commit' must be a lowercase 40-character commit"
        )


def validate_required_commands(path: Path, text: str) -> None:
    """Require validation command snippets to stay discoverable."""
    missing = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} is missing validation command(s): {', '.join(missing)}"
        )


def validate_retained_files(
    path: Path, fields: dict[str, str], repo_root: Path
) -> dict[str, Path]:
    """Validate referenced retained files and optional declared hashes."""
    resolved: dict[str, Path] = {}
    for label in RETAINED_FILE_FIELDS:
        target, _path_text, expected_digest = resolve_retained_path(
            path, repo_root, label, fields[label]
        )
        if not target.is_file():
            raise LiveDeploymentManifestEvidenceError(
                f"{path} field {label!r} points to missing retained file: {fields[label]}"
            )
        if target.is_symlink():
            raise LiveDeploymentManifestEvidenceError(
                f"{path} field {label!r} points to symlinked retained file: {fields[label]}"
            )
        if expected_digest is not None and file_sha256(target) != expected_digest:
            raise LiveDeploymentManifestEvidenceError(
                f"{path} field {label!r} has stale sha256 digest: {fields[label]}"
            )
        validate_no_secret_values(target, read_text(target))
        resolved[label] = target
    return resolved


def contracts_from(value: Any, context: str) -> dict[str, dict[str, Any]]:
    """Return contract records as a name-keyed mapping."""
    if isinstance(value, dict):
        records: dict[str, dict[str, Any]] = {}
        for name, record in value.items():
            records[str(name)] = require_dict(record, f"{context}.{name}")
        return records
    if isinstance(value, list):
        records = {}
        for index, record_value in enumerate(value):
            record = require_dict(record_value, f"{context}[{index}]")
            name = record.get("name") or record.get("contract") or record.get("contract_name")
            if not isinstance(name, str) or not name:
                raise LiveDeploymentManifestEvidenceError(
                    f"{context}[{index}] is missing contract name"
                )
            records[name] = record
        return records
    raise LiveDeploymentManifestEvidenceError(f"{context} must be an object or array")


def validate_contract_record(name: str, record: dict[str, Any]) -> None:
    """Validate one live manifest contract record."""
    address = record.get("address")
    if not isinstance(address, str) or not ADDRESS_RE.match(address):
        raise LiveDeploymentManifestEvidenceError(
            f"deployment manifest contract {name} has invalid address"
        )
    if address.lower() == "0x0000000000000000000000000000000000000000":
        raise LiveDeploymentManifestEvidenceError(
            f"deployment manifest contract {name} has zero address"
        )
    bytecode_hash = record.get("bytecode_hash") or record.get("runtime_bytecode_hash")
    if not isinstance(bytecode_hash, str) or not SHA256_REF_RE.fullmatch(bytecode_hash):
        raise LiveDeploymentManifestEvidenceError(
            f"deployment manifest contract {name} is missing sha256 bytecode hash"
        )
    if "constructor_args" not in record:
        raise LiveDeploymentManifestEvidenceError(
            f"deployment manifest contract {name} is missing constructor_args"
        )


def validate_live_deployment_manifest(
    path: Path, expected_deployment_version: str
) -> dict[str, dict[str, Any]]:
    """Validate the retained live deployment manifest JSON."""
    manifest = require_dict(load_json(path), str(path))
    if manifest.get("manifest_schema_version") != "6529stream.deployment-manifest.v1":
        raise LiveDeploymentManifestEvidenceError(
            f"{path} must use manifest_schema_version 6529stream.deployment-manifest.v1"
        )
    if manifest.get("deployment_version") != expected_deployment_version:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} deployment_version must match Network and deployment version"
        )
    network = require_dict(manifest.get("network"), f"{path}.network")
    if network.get("chain_id") != EXPECTED_CHAIN_ID_INT:
        raise LiveDeploymentManifestEvidenceError(f"{path} network.chain_id must be 1")
    if str(network.get("name", "")).lower() != "mainnet":
        raise LiveDeploymentManifestEvidenceError(f"{path} network.name must be mainnet")
    contracts = contracts_from(manifest.get("contracts"), f"{path}.contracts")
    if not contracts:
        raise LiveDeploymentManifestEvidenceError(f"{path} must include contracts")
    for name, record in contracts.items():
        validate_contract_record(name, record)
    return contracts


def validate_address_book(path: Path, manifest_contracts: dict[str, dict[str, Any]]) -> None:
    """Validate a retained live address book against the deployment manifest."""
    address_book = require_dict(load_json(path), str(path))
    network = require_dict(address_book.get("network"), f"{path}.network")
    if network.get("chain_id") != EXPECTED_CHAIN_ID_INT:
        raise LiveDeploymentManifestEvidenceError(f"{path} network.chain_id must be 1")
    contracts = contracts_from(address_book.get("contracts"), f"{path}.contracts")
    for name, manifest_record in manifest_contracts.items():
        if name not in contracts:
            raise LiveDeploymentManifestEvidenceError(
                f"{path} is missing contract from deployment manifest: {name}"
            )
        address = contracts[name].get("address")
        if not isinstance(address, str) or address.lower() != str(
            manifest_record["address"]
        ).lower():
            raise LiveDeploymentManifestEvidenceError(
                f"{path} address mismatch for contract {name}"
            )


def validate_release_digests(path: Path) -> None:
    """Require release manifest/checksum digest references to be explicit."""
    text = read_text(path)
    if len(SHA256_REF_RE.findall(text)) < 2:
        raise LiveDeploymentManifestEvidenceError(
            f"{path} must include at least two sha256 digest references"
        )


def validate_artifact(path: Path, repo_root: Path | None = None) -> None:
    """Validate one retained artifact."""
    repo_root = (repo_root or DEFAULT_REPO_ROOT).resolve()
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)
    validate_common_fields(path, fields)
    validate_required_commands(path, text)

    if fields["Review status"] == "template":
        return

    validate_reviewed_fields(path, fields)
    retained_files = validate_retained_files(path, fields, repo_root)
    manifest_contracts = validate_live_deployment_manifest(
        retained_files[DEPLOYMENT_MANIFEST_FIELD],
        fields["Network and deployment version"],
    )
    validate_address_book(retained_files[ADDRESS_BOOK_FIELD], manifest_contracts)
    validate_release_digests(retained_files[RELEASE_DIGESTS_FIELD])


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained live deployment manifest evidence artifacts."
    )
    parser.add_argument(
        "evidence",
        nargs="*",
        type=Path,
        default=DEFAULT_EVIDENCE,
        help="Retained artifact Markdown files to validate.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=DEFAULT_REPO_ROOT,
        help="Repository root for resolving retained artifact paths.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the checker CLI."""
    args = parse_args(list(sys.argv[1:] if argv is None else argv))
    try:
        for path in args.evidence:
            validate_artifact(path, args.repo_root)
    except LiveDeploymentManifestEvidenceError as exc:
        print(f"live deployment manifest evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("live deployment manifest evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
