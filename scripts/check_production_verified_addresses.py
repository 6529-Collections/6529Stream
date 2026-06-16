#!/usr/bin/env python3
"""Validate retained production verified-address evidence artifacts."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIREMENT_ID = "production_verified_addresses"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/production-verified-addresses/"
        "production-verified-addresses-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Production Verified Addresses Retained Artifact",
    "## Evidence Status",
    "## Source And Production Reference",
    "## Required Retained Artifacts",
    "## Verified Address Results",
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
    "Generated live address book",
    "Generated live deployment manifest",
    "Source verification inputs",
    "Explorer verification evidence",
    "Bytecode release proof",
    "Release manifest/checksum digests",
    "Address book covers live deployment",
    "Explorer source verification confirmed",
    "Runtime bytecode matches release proof",
    "Constructor arguments verified",
    "Linked libraries verified",
    "Common explorer/indexer links retained",
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
    "Generated live address book",
    "Generated live deployment manifest",
    "Source verification inputs",
    "Explorer verification evidence",
    "Bytecode release proof",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]
REVIEWED_YES_FIELDS = [
    "Address book covers live deployment",
    "Explorer source verification confirmed",
    "Runtime bytecode matches release proof",
    "Constructor arguments verified",
    "Linked libraries verified",
    "Common explorer/indexer links retained",
]
RETAINED_FILE_FIELDS = [
    "Generated live address book",
    "Generated live deployment manifest",
    "Source verification inputs",
    "Explorer verification evidence",
    "Bytecode release proof",
]
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")

REQUIRED_COMMANDS = [
    "python scripts/test_production_verified_addresses.py",
    "python scripts/check_production_verified_addresses.py",
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


class ProductionVerifiedAddressesError(RuntimeError):
    """Raised when production verified-address evidence is invalid."""


def require_dict(value: Any, context: str) -> dict[str, Any]:
    """Require a JSON value to be an object."""
    if not isinstance(value, dict):
        raise ProductionVerifiedAddressesError(f"{context} must be an object")
    return value


def load_json(path: Path) -> Any:
    """Load JSON with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ProductionVerifiedAddressesError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ProductionVerifiedAddressesError(f"invalid JSON in {path}: {exc}") from exc


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
        raise ProductionVerifiedAddressesError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise ProductionVerifiedAddressesError(f"{path} must be valid UTF-8") from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value, CLI, and provider URL material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise ProductionVerifiedAddressesError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise ProductionVerifiedAddressesError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )


def repo_root_for(path: Path) -> Path:
    """Return the root used for repo-relative retained artifact paths."""
    # CLI use resolves paths from the checkout root. Tests may validate temp
    # artifacts outside CWD, so those use the evidence file's parent as root.
    cwd = Path.cwd().resolve()
    resolved = path.resolve()
    try:
        resolved.relative_to(cwd)
    except ValueError:
        return resolved.parent
    return cwd


def resolve_repo_relative_path(root: Path, value: str) -> Path:
    """Resolve a retained artifact path while rejecting escapes."""
    candidate = Path(value)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ProductionVerifiedAddressesError(
            f"retained artifact path must be repo-relative: {value}"
        )
    resolved = (root / candidate).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise ProductionVerifiedAddressesError(
            f"retained artifact path escapes repository: {value}"
        ) from exc
    return resolved


def validate_referenced_artifacts(path: Path, fields: dict[str, str]) -> None:
    """Require retained artifact paths to exist and be no-secret."""
    root = repo_root_for(path)
    for label in RETAINED_FILE_FIELDS:
        target = resolve_repo_relative_path(root, fields[label])
        if not target.is_file():
            raise ProductionVerifiedAddressesError(
                f"{path} field {label!r} points to missing retained file: {fields[label]}"
            )
        validate_no_secret_values(target, read_text(target))


def referenced_artifact_paths(path: Path, fields: dict[str, str]) -> dict[str, Path]:
    """Return resolved referenced retained artifact paths."""
    root = repo_root_for(path)
    return {
        label: resolve_repo_relative_path(root, fields[label])
        for label in RETAINED_FILE_FIELDS
    }


def require_address(value: Any, context: str) -> str:
    """Require a checksummed-or-lowercase Ethereum address-shaped value."""
    if not isinstance(value, str) or not ADDRESS_RE.fullmatch(value):
        raise ProductionVerifiedAddressesError(f"{context} must be a 20-byte address")
    return value.lower()


def contract_map(data: dict[str, Any], context: str) -> dict[str, dict[str, Any]]:
    """Require a contracts object keyed by contract name."""
    contracts = require_dict(data.get("contracts"), f"{context}.contracts")
    if not contracts:
        raise ProductionVerifiedAddressesError(f"{context}.contracts must not be empty")
    normalized: dict[str, dict[str, Any]] = {}
    seen_addresses: dict[str, str] = {}
    for name, value in contracts.items():
        if not isinstance(name, str) or not name:
            raise ProductionVerifiedAddressesError(f"{context}.contracts has invalid name")
        record = require_dict(value, f"{context}.contracts.{name}")
        address = require_address(record.get("address"), f"{context}.contracts.{name}.address")
        if address in seen_addresses:
            raise ProductionVerifiedAddressesError(
                f"{context} duplicates address {record.get('address')} for "
                f"{seen_addresses[address]} and {name}"
            )
        seen_addresses[address] = name
        normalized[name] = record
    return normalized


def validate_address_book_and_manifest(
    address_book_path: Path,
    deployment_manifest_path: Path,
) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    """Validate address-book and deployment-manifest address agreement."""
    address_book = require_dict(load_json(address_book_path), str(address_book_path))
    deployment_manifest = require_dict(
        load_json(deployment_manifest_path),
        str(deployment_manifest_path),
    )

    address_network = require_dict(
        address_book.get("network"),
        f"{address_book_path}.network",
    )
    manifest_network = require_dict(
        deployment_manifest.get("network"),
        f"{deployment_manifest_path}.network",
    )
    if address_network.get("chain_id") != 1 or manifest_network.get("chain_id") != 1:
        raise ProductionVerifiedAddressesError("production verified addresses require chain ID 1")

    address_contracts = contract_map(address_book, str(address_book_path))
    manifest_contracts = contract_map(deployment_manifest, str(deployment_manifest_path))
    missing = sorted(set(address_contracts) - set(manifest_contracts))
    if missing:
        raise ProductionVerifiedAddressesError(
            "deployment manifest is missing contract(s): " + ", ".join(missing)
        )
    extra = sorted(set(manifest_contracts) - set(address_contracts))
    if extra:
        raise ProductionVerifiedAddressesError(
            "address book is missing contract(s): " + ", ".join(extra)
        )
    for name, address_record in address_contracts.items():
        address = require_address(
            address_record.get("address"),
            f"{address_book_path}.contracts.{name}.address",
        )
        manifest_address = require_address(
            manifest_contracts[name].get("address"),
            f"{deployment_manifest_path}.contracts.{name}.address",
        )
        if address != manifest_address:
            raise ProductionVerifiedAddressesError(
                f"address mismatch for {name}: address book has "
                f"{address_record.get('address')}, manifest has "
                f"{manifest_contracts[name].get('address')}"
            )
    return address_contracts, manifest_contracts


def explorer_contracts(path: Path) -> dict[str, dict[str, Any]]:
    """Load explorer verification evidence contracts."""
    data = require_dict(load_json(path), str(path))
    contracts = contract_map(data, str(path))
    for name, record in contracts.items():
        status = record.get("explorer_status") or record.get("verification_status")
        if status != "verified":
            raise ProductionVerifiedAddressesError(
                f"{path}.contracts.{name} explorer status must be verified"
            )
        url = record.get("explorer_url")
        if not isinstance(url, str) or not url.startswith("https://"):
            raise ProductionVerifiedAddressesError(
                f"{path}.contracts.{name}.explorer_url must be an https URL"
            )
    return contracts


def validate_bytecode_proof(
    path: Path,
    address_contracts: dict[str, dict[str, Any]],
) -> None:
    """Validate bytecode proof coverage for retained address-book contracts."""
    data = require_dict(load_json(path), str(path))
    proof_rows = data.get("contract_proofs")
    if not isinstance(proof_rows, list) or not proof_rows:
        raise ProductionVerifiedAddressesError(
            f"{path}.contract_proofs must be a non-empty array"
        )

    proof_by_name: dict[str, list[dict[str, Any]]] = {}
    for index, value in enumerate(proof_rows):
        proof = require_dict(value, f"{path}.contract_proofs[{index}]")
        contract = require_dict(
            proof.get("contract"),
            f"{path}.contract_proofs[{index}].contract",
        )
        name = contract.get("name")
        if not isinstance(name, str) or not name:
            raise ProductionVerifiedAddressesError(
                f"{path}.contract_proofs[{index}].contract.name must be a string"
            )
        proof_by_name.setdefault(name, []).append(proof)

    for name, address_record in address_contracts.items():
        expected_address = require_address(
            address_record.get("address"),
            f"address book {name}",
        )
        expected_runtime_hash = address_record.get("runtime_bytecode_hash")
        matching_rows = proof_by_name.get(name, [])
        if not matching_rows:
            raise ProductionVerifiedAddressesError(
                f"bytecode proof is missing contract: {name}"
            )
        for proof in matching_rows:
            contract = require_dict(proof.get("contract"), f"bytecode proof {name}.contract")
            actual_address = require_address(
                contract.get("address"),
                f"bytecode proof {name}.address",
            )
            hashes = require_dict(proof.get("hashes"), f"bytecode proof {name}.hashes")
            actual_runtime_hash = hashes.get("runtime_bytecode")
            if (
                actual_address == expected_address
                and (
                    expected_runtime_hash is None
                    or actual_runtime_hash == expected_runtime_hash
                )
            ):
                break
        else:
            raise ProductionVerifiedAddressesError(
                f"bytecode proof does not match address book contract: {name}"
            )


def validate_verified_address_payloads(path: Path, fields: dict[str, str]) -> None:
    """Validate retained JSON evidence for reviewed/pending verified addresses."""
    targets = referenced_artifact_paths(path, fields)
    address_contracts, _ = validate_address_book_and_manifest(
        targets["Generated live address book"],
        targets["Generated live deployment manifest"],
    )
    explorer_records = explorer_contracts(targets["Explorer verification evidence"])
    missing = sorted(set(address_contracts) - set(explorer_records))
    if missing:
        raise ProductionVerifiedAddressesError(
            "explorer evidence is missing contract(s): " + ", ".join(missing)
        )
    for name, address_record in address_contracts.items():
        expected = require_address(address_record.get("address"), f"address book {name}")
        actual = require_address(explorer_records[name].get("address"), f"explorer {name}")
        if expected != actual:
            raise ProductionVerifiedAddressesError(
                f"explorer address mismatch for {name}: expected "
                f"{address_record.get('address')}, got {explorer_records[name].get('address')}"
            )
    validate_bytecode_proof(targets["Bytecode release proof"], address_contracts)


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise ProductionVerifiedAddressesError(
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
            raise ProductionVerifiedAddressesError(f"{path} has duplicate field: {label}")
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise ProductionVerifiedAddressesError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise ProductionVerifiedAddressesError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def is_placeholder(value: str) -> bool:
    """Return whether a value is still placeholder/template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or bool(
        ANGLE_PLACEHOLDER_RE.search(value)
    )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    """Validate template, pending-review, and reviewed state semantics."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise ProductionVerifiedAddressesError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise ProductionVerifiedAddressesError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise ProductionVerifiedAddressesError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise ProductionVerifiedAddressesError(
            f"{path} non-template evidence must remove the template-only notice"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise ProductionVerifiedAddressesError(
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
        validate_referenced_artifacts(path, fields)
        validate_verified_address_payloads(path, fields)
    elif review_status == "pending_review":
        validate_referenced_artifacts(path, fields)
        validate_verified_address_payloads(path, fields)


def validate_commands(path: Path, text: str) -> None:
    """Require the artifact to carry the validation sequence."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise ProductionVerifiedAddressesError(
                f"{path} is missing validation command: {command}"
            )


def validate_artifact(path: Path) -> None:
    """Validate one retained production verified-address artifact."""
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_field_value(path, fields, "Environment", "live")
    require_field_value(path, fields, "Chain ID", "1")
    validate_review_state(path, text, fields)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained production verified-address evidence artifacts"
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
    except ProductionVerifiedAddressesError as exc:
        print(f"production verified-addresses check failed: {exc}", file=sys.stderr)
        return 1
    print("production verified-addresses evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
