#!/usr/bin/env python3
"""Validate integration conformance fixtures and guide."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


DEFAULT_FIXTURE = Path("docs/integrations/fixtures/integration-conformance-fixtures.json")
DEFAULT_DOC = Path("docs/integrations/integration-conformance-fixtures.md")

FIXTURE_SCHEMA = "6529stream.integration-conformance-fixtures.v1"
ADDRESS_BOOK_SCHEMA = "6529stream.address-book.v1"
EVENT_TOPIC_CATALOG_SCHEMA = "6529stream.event-topic-catalog.v1"

REQUIRED_SOURCE_ARTIFACT_KEYS = [
    "address_book",
    "deployment_manifest",
    "event_topic_catalog",
    "abi_checksums",
    "release_manifest",
    "release_checksums",
    "drop_authorization_fixed_price",
    "drop_authorization_auction",
]

REQUIRED_CONTRACTS = [
    "StreamAdmins",
    "StreamCore",
    "StreamCuratorsPool",
    "StreamDrops",
    "StreamAuctions",
    "NextGenRandomizerVRF",
    "NextGenRandomizerRNG",
    "StreamContractMetadata",
]

REQUIRED_CHAIN_NEGATIVES = {
    "wrong-chain-id",
    "wrong-deployment-version",
    "missing-contract",
}

REQUIRED_DROP_NEGATIVES = {
    "wrong-domain",
    "stale-signer-epoch",
    "expired-deadline",
    "zero-address-signer",
    "replayed-drop-id",
}

REQUIRED_EVENT_NEGATIVES = {
    "wrong-emitter",
    "unknown-topic",
    "duplicate-log-idempotent",
    "reorg-rollback",
}

REQUIRED_EVENT_CASES = {
    "stream-core-transfer-mint": ("StreamCore", "Transfer"),
    "drop-authorization-consumed": ("StreamDrops", "DropAuthorizationConsumed"),
    "auction-registered": ("StreamAuctions", "AuctionRegistered"),
}

REQUIRED_DOC_HEADINGS = [
    (1, "Integration Conformance Fixtures"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Fixture Bundle Contract"),
    (2, "Artifact Loading Case"),
    (2, "Drop Authorization Cases"),
    (2, "Event Dispatch Cases"),
    (2, "No-Secret Policy"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_DOC_PHRASES = [
    "INT-016",
    "integration conformance fixtures",
    "pre-audit local baseline",
    "not production-ready",
    "not a security claim",
    "not a generated SDK",
    "not an indexer service",
    "not retained marketplace/indexer evidence",
    "React",
    "mobile",
    "Electron",
    "operator UI",
    "backend signing service",
    "fail-closed chain config",
    "EIP-712",
    "ERC-1271",
    "Safe",
    "wrong chain ID",
    "wrong deployment version",
    "missing contract address",
    "wrong domain",
    "stale signer epoch",
    "expired deadline",
    "token-data substitution",
    "auction custody mismatch",
    "zero-address signer",
    "replayed drop ID",
    "unknown emitter",
    "unknown `topic0`",
    "idempotent",
    "confirmation depth",
    "reorg rollback",
    "read-after-event",
    "private keys",
    "raw signatures",
    "WalletConnect secrets",
    "unreleased token data",
    "release artifacts",
    "release checksums",
]

REQUIRED_DOC_COMMANDS = [
    "python scripts/test_integration_conformance_fixtures.py",
    "python scripts/check_integration_conformance_fixtures.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_events_and_indexing.py",
    "python scripts/check_events_and_indexing.py",
    "python scripts/test_react_next_reference.py",
    "python scripts/check_react_next_reference.py",
    "python scripts/test_typescript_artifact_chain_config.py",
    "python scripts/check_typescript_artifact_chain_config.py",
    "python scripts/test_typescript_eip712_drop_authorization.py",
    "python scripts/check_typescript_eip712_drop_authorization.py",
    "python scripts/test_typescript_event_decoding_indexer.py",
    "python scripts/check_typescript_event_decoding_indexer.py",
    "python scripts/test_release_manifest.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_release_checksums.py",
    "python scripts/generate_release_checksums.py --check",
    "python scripts/check_changelog.py",
    "make integration-conformance-fixtures-check",
    "make check",
    "powershell -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_DOC_LINK_TARGETS = [
    "docs/integrations/fixtures/integration-conformance-fixtures.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/examples/anvil-6529stream-v0.1.0-001.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/release-checksums.json",
    "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json",
    "test/fixtures/drop-authorization/payload-generator/auction-output.json",
    "docs/integrations/examples/typescript-artifacts-and-chain-config.md",
    "docs/integrations/examples/typescript-eip712-drop-authorization.md",
    "docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md",
    "docs/integrations/frontend-reference-architecture.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/README.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HEX32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
SECRET_KEY_RE = re.compile(
    r"(private[_-]?key|mnemonic|seed[_-]?phrase|api[_-]?key|api[_-]?token|"
    r"access[_-]?token|bearer|password|secret|raw[_-]?signature|rpc[_-]?url)",
    re.IGNORECASE,
)
PRIVATE_KEY_VALUE_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
ALLOWED_SECRET_KEY_FRAGMENTS = {
    "tokenDataHash",
    "tokenId",
    "No-Secret Policy",
    "no_secret_redaction_cases",
    "no_secret_policy",
}
VALID_SALE_MODES_BY_CASE = {
    "fixed-price-eoa": "fixed_price",
    "auction-eoa": "auction",
}


class IntegrationConformanceFixtureError(ValueError):
    """Raised when integration conformance fixtures drift or are incomplete."""


def load_json(path: Path, label: str) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise IntegrationConformanceFixtureError(f"missing {label}: {path}") from exc
    except json.JSONDecodeError as exc:
        raise IntegrationConformanceFixtureError(f"invalid JSON in {label}: {path}") from exc


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise IntegrationConformanceFixtureError(f"path escapes repository: {path}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise IntegrationConformanceFixtureError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise IntegrationConformanceFixtureError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise IntegrationConformanceFixtureError(f"{path} must be a non-empty string")
    return value


def require_int(value: Any, path: str) -> int:
    if not isinstance(value, int):
        raise IntegrationConformanceFixtureError(f"{path} must be an integer")
    return value


def require_bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise IntegrationConformanceFixtureError(f"{path} must be a boolean")
    return value


def require_address(value: Any, path: str) -> str:
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise IntegrationConformanceFixtureError(f"{path} must be an address")
    return address.lower()


def require_bytes32(value: Any, path: str) -> str:
    item = require_string(value, path)
    if not HEX32_RE.fullmatch(item):
        raise IntegrationConformanceFixtureError(f"{path} must be bytes32")
    return item.lower()


def normalized_link_target(raw_target: str) -> str | None:
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if "://" in target or target.startswith("mailto:"):
        return None
    path_part = target.split("#", 1)[0].split("?", 1)[0]
    return path_part or None


def label_looks_like_repo_path(label: str) -> bool:
    normalized = label.strip().strip("`")
    if any(character.isspace() for character in normalized):
        return False
    return "/" in normalized or "\\" in normalized or normalized.endswith((
        ".md",
        ".json",
        ".py",
        ".ps1",
        ".sh",
    ))


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        label = match.group(1).strip().strip("`")
        target = normalized_link_target(match.group(2))
        if target is None:
            continue
        target_path = Path(target)
        if not target_path.is_absolute():
            target_path = document_path.parent / target_path
        resolved = target_path.resolve()
        relative = normalize_repo_path(resolved, repo_root)
        if not resolved.exists():
            missing.append(relative)
            continue
        if label_looks_like_repo_path(label) and label.replace("\\", "/") != relative:
            raise IntegrationConformanceFixtureError(
                f"link label {label!r} resolves to {relative!r}"
            )
        links.add(relative)
    if missing:
        raise IntegrationConformanceFixtureError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def markdown_headings(text: str) -> set[tuple[int, str]]:
    headings = set()
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.add((level, title))
    return headings


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    normalized_text = " ".join(text.lower().split())
    return [
        phrase
        for phrase in phrases
        if " ".join(phrase.lower().split()) not in normalized_text
    ]


def path_from_source(repo_root: Path, source_artifacts: dict[str, Any], key: str) -> Path:
    relative = Path(require_string(source_artifacts.get(key), f"source_artifacts.{key}"))
    if relative.is_absolute() or ".." in relative.parts:
        raise IntegrationConformanceFixtureError(
            f"source_artifacts.{key} must be a repo-relative path"
        )
    path = repo_root / relative
    if not path.is_file():
        raise IntegrationConformanceFixtureError(
            f"source_artifacts.{key} is missing: {relative.as_posix()}"
        )
    return path


def event_catalog_by_name(catalog: dict[str, Any]) -> dict[str, dict[str, Any]]:
    topics = require_list(catalog.get("topics"), "event_topic_catalog.topics")
    by_name = {}
    for index, raw_entry in enumerate(topics):
        entry = require_dict(raw_entry, f"event_topic_catalog.topics[{index}]")
        name = require_string(entry.get("name"), f"event_topic_catalog.topics[{index}].name")
        by_name[name] = entry
    return by_name


def contains_secret_shape(key: str, value: Any) -> bool:
    if key in ALLOWED_SECRET_KEY_FRAGMENTS:
        return False
    key_is_secret_shaped = bool(SECRET_KEY_RE.search(key))
    if key_is_secret_shaped:
        return True
    if isinstance(value, str):
        lowered = value.lower()
        if lowered in {fragment.lower() for fragment in ALLOWED_SECRET_KEY_FRAGMENTS}:
            return False
        if SECRET_KEY_RE.search(value):
            return True
        if key_is_secret_shaped and PRIVATE_KEY_VALUE_RE.fullmatch(value):
            return True
    return False


def scan_no_secrets(value: Any, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, nested in value.items():
            nested_path = f"{path}.{key}"
            if contains_secret_shape(str(key), nested):
                if (
                    "no_secret_redaction_cases" not in nested_path
                    and not nested_path.endswith(".input_keys")
                ):
                    raise IntegrationConformanceFixtureError(
                        f"secret-shaped fixture field is not allowed: {nested_path}"
                    )
            scan_no_secrets(nested, nested_path)
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            scan_no_secrets(nested, f"{path}[{index}]")
    elif "no_secret_redaction_cases" not in path and contains_secret_shape("", value):
        raise IntegrationConformanceFixtureError(
            f"secret-shaped fixture value is not allowed: {path}"
        )


def validate_maturity(fixture: dict[str, Any]) -> None:
    maturity = require_dict(fixture.get("maturity"), "maturity")
    for key in ["not_production_ready", "not_generated_sdk", "not_external_evidence"]:
        if require_bool(maturity.get(key), f"maturity.{key}") is not True:
            raise IntegrationConformanceFixtureError(f"maturity.{key} must be true")


def validate_source_artifacts(repo_root: Path, fixture: dict[str, Any]) -> dict[str, Path]:
    source_artifacts = require_dict(fixture.get("source_artifacts"), "source_artifacts")
    missing_keys = [key for key in REQUIRED_SOURCE_ARTIFACT_KEYS if key not in source_artifacts]
    if missing_keys:
        raise IntegrationConformanceFixtureError(
            "source_artifacts is missing keys: " + ", ".join(missing_keys)
        )
    return {
        key: path_from_source(repo_root, source_artifacts, key)
        for key in REQUIRED_SOURCE_ARTIFACT_KEYS
    }


def validate_chain_config_case(fixture: dict[str, Any], address_book: dict[str, Any]) -> None:
    case = require_dict(fixture.get("artifact_chain_config_case"), "artifact_chain_config_case")
    chain_id = require_int(case.get("chain_id"), "artifact_chain_config_case.chain_id")
    deployment_version = require_string(
        case.get("deployment_version"), "artifact_chain_config_case.deployment_version"
    )
    expected_chain_id = require_int(address_book.get("network", {}).get("chain_id"), "address_book.network.chain_id")
    expected_deployment = require_string(address_book.get("deployment_version"), "address_book.deployment_version")
    if chain_id != expected_chain_id:
        raise IntegrationConformanceFixtureError(
            "artifact_chain_config_case.chain_id does not match address book"
        )
    if deployment_version != expected_deployment:
        raise IntegrationConformanceFixtureError(
            "artifact_chain_config_case.deployment_version does not match address book"
        )

    contracts = require_dict(case.get("required_contracts"), "artifact_chain_config_case.required_contracts")
    address_book_contracts = require_dict(address_book.get("contracts"), "address_book.contracts")
    missing_contracts = [contract for contract in REQUIRED_CONTRACTS if contract not in contracts]
    if missing_contracts:
        raise IntegrationConformanceFixtureError(
            "artifact_chain_config_case.required_contracts is missing: "
            + ", ".join(missing_contracts)
        )
    for contract_name in REQUIRED_CONTRACTS:
        fixture_address = require_address(
            contracts.get(contract_name),
            f"artifact_chain_config_case.required_contracts.{contract_name}",
        )
        address_book_entry = require_dict(
            address_book_contracts.get(contract_name),
            f"address_book.contracts.{contract_name}",
        )
        address_book_address = require_address(
            address_book_entry.get("address"), f"address_book.contracts.{contract_name}.address"
        )
        if fixture_address != address_book_address:
            raise IntegrationConformanceFixtureError(
                f"required contract address drift for {contract_name}"
            )

    negatives = {
        require_string(item.get("name"), "artifact_chain_config_case.negative_cases[].name")
        for item in require_list(case.get("negative_cases"), "artifact_chain_config_case.negative_cases")
        if isinstance(item, dict)
    }
    missing_negatives = REQUIRED_CHAIN_NEGATIVES - negatives
    if missing_negatives:
        raise IntegrationConformanceFixtureError(
            "artifact_chain_config_case is missing negative cases: "
            + ", ".join(sorted(missing_negatives))
        )


def validate_drop_authorization_cases(
    repo_root: Path,
    fixture: dict[str, Any],
    address_book: dict[str, Any],
) -> None:
    cases = require_list(fixture.get("drop_authorization_cases"), "drop_authorization_cases")
    if {case.get("name") for case in cases if isinstance(case, dict)} != {
        "fixed-price-eoa",
        "auction-eoa",
    }:
        raise IntegrationConformanceFixtureError(
            "drop_authorization_cases must include fixed-price-eoa and auction-eoa"
        )
    stream_drops = require_address(
        address_book["contracts"]["StreamDrops"]["address"],
        "address_book.contracts.StreamDrops.address",
    )
    chain_id = address_book["network"]["chain_id"]
    for index, raw_case in enumerate(cases):
        case = require_dict(raw_case, f"drop_authorization_cases[{index}]")
        fixture_path = repo_root / require_string(case.get("fixture"), f"drop_authorization_cases[{index}].fixture")
        if not fixture_path.is_file():
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}].fixture is missing"
            )
        payload = require_dict(load_json(fixture_path, f"drop_authorization_cases[{index}].fixture"), "payload")
        if payload.get("signing_status") != "unsigned":
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}].fixture must remain unsigned"
            )
        expected_domain = require_dict(case.get("expected_domain"), f"drop_authorization_cases[{index}].expected_domain")
        if expected_domain.get("name") != "6529StreamDrops":
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}].expected_domain.name drift"
            )
        if expected_domain.get("version") != "1":
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}].expected_domain.version drift"
            )
        if expected_domain.get("chainId") != chain_id:
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}].expected_domain.chainId drift"
            )
        if require_address(
            expected_domain.get("verifyingContract"),
            f"drop_authorization_cases[{index}].expected_domain.verifyingContract",
        ) != stream_drops:
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}].expected_domain.verifyingContract drift"
            )
        if case.get("expected_primary_type") != "DropAuthorization":
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}].expected_primary_type must be DropAuthorization"
            )
        expected_sale_mode = require_string(
            case.get("expected_sale_mode"),
            f"drop_authorization_cases[{index}].expected_sale_mode",
        )
        case_name = require_string(case.get("name"), f"drop_authorization_cases[{index}].name")
        if expected_sale_mode != VALID_SALE_MODES_BY_CASE[case_name]:
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}].expected_sale_mode drift"
            )
        negatives = set(require_list(case.get("negative_cases"), f"drop_authorization_cases[{index}].negative_cases"))
        missing_negatives = REQUIRED_DROP_NEGATIVES - negatives
        if missing_negatives:
            raise IntegrationConformanceFixtureError(
                f"drop_authorization_cases[{index}] is missing negative cases: "
                + ", ".join(sorted(missing_negatives))
            )


def validate_event_cases(
    fixture: dict[str, Any],
    address_book: dict[str, Any],
    event_catalog: dict[str, Any],
) -> None:
    cases = require_list(fixture.get("event_decoding_cases"), "event_decoding_cases")
    case_names = {case.get("name") for case in cases if isinstance(case, dict)}
    missing_cases = set(REQUIRED_EVENT_CASES) - case_names
    if missing_cases:
        raise IntegrationConformanceFixtureError(
            "event_decoding_cases is missing cases: " + ", ".join(sorted(missing_cases))
        )
    topics_by_name = event_catalog_by_name(event_catalog)
    contracts = require_dict(address_book.get("contracts"), "address_book.contracts")
    for index, raw_case in enumerate(cases):
        case = require_dict(raw_case, f"event_decoding_cases[{index}]")
        case_name = require_string(case.get("name"), f"event_decoding_cases[{index}].name")
        contract_name = require_string(case.get("contract"), f"event_decoding_cases[{index}].contract")
        event_name = require_string(case.get("event"), f"event_decoding_cases[{index}].event")
        if case_name in REQUIRED_EVENT_CASES and REQUIRED_EVENT_CASES[case_name] != (contract_name, event_name):
            raise IntegrationConformanceFixtureError(
                f"event_decoding_cases[{index}] has the wrong contract/event pair"
            )
        catalog_entry = require_dict(topics_by_name.get(event_name), f"event_topic_catalog.topics.{event_name}")
        expected_emitter = require_address(
            contracts[contract_name]["address"], f"address_book.contracts.{contract_name}.address"
        )
        emitter = require_address(case.get("emitter"), f"event_decoding_cases[{index}].emitter")
        if emitter != expected_emitter:
            raise IntegrationConformanceFixtureError(
                f"event_decoding_cases[{index}].emitter does not match address book"
            )
        if contract_name not in require_list(catalog_entry.get("emitted_by"), f"event_topic_catalog.{event_name}.emitted_by"):
            raise IntegrationConformanceFixtureError(
                f"event topic catalog does not list {contract_name} for {event_name}"
            )
        if case.get("signature") != catalog_entry.get("signature"):
            raise IntegrationConformanceFixtureError(
                f"event_decoding_cases[{index}].signature does not match topic catalog"
            )
        topic0 = require_bytes32(case.get("topic0"), f"event_decoding_cases[{index}].topic0")
        catalog_topic0 = require_bytes32(catalog_entry.get("topic0"), f"event_topic_catalog.{event_name}.topic0")
        if topic0 != catalog_topic0:
            raise IntegrationConformanceFixtureError(
                f"event_decoding_cases[{index}].topic0 does not match topic catalog"
            )
        dispatch_key = require_string(
            case.get("expected_dispatch_key"),
            f"event_decoding_cases[{index}].expected_dispatch_key",
        )
        if dispatch_key != f"{emitter}:{topic0}":
            raise IntegrationConformanceFixtureError(
                f"event_decoding_cases[{index}].expected_dispatch_key is stale"
            )
        log = require_dict(case.get("sample_log"), f"event_decoding_cases[{index}].sample_log")
        require_int(log.get("chain_id"), f"event_decoding_cases[{index}].sample_log.chain_id")
        require_int(log.get("block_number"), f"event_decoding_cases[{index}].sample_log.block_number")
        require_bytes32(log.get("block_hash"), f"event_decoding_cases[{index}].sample_log.block_hash")
        require_bytes32(log.get("transaction_hash"), f"event_decoding_cases[{index}].sample_log.transaction_hash")
        require_int(log.get("log_index"), f"event_decoding_cases[{index}].sample_log.log_index")
        read_after = require_list(
            case.get("expected_read_after_event"),
            f"event_decoding_cases[{index}].expected_read_after_event",
        )
        if not read_after:
            raise IntegrationConformanceFixtureError(
                f"event_decoding_cases[{index}].expected_read_after_event must not be empty"
            )
        negatives = set(require_list(case.get("negative_cases"), f"event_decoding_cases[{index}].negative_cases"))
        missing_negatives = REQUIRED_EVENT_NEGATIVES - negatives
        if missing_negatives:
            raise IntegrationConformanceFixtureError(
                f"event_decoding_cases[{index}] is missing negative cases: "
                + ", ".join(sorted(missing_negatives))
            )


def validate_indexer_behaviour(fixture: dict[str, Any]) -> None:
    cases = require_dict(fixture.get("indexer_behaviour_cases"), "indexer_behaviour_cases")
    log_identity = require_dict(cases.get("log_identity"), "indexer_behaviour_cases.log_identity")
    for key in ["optimistic_key_fields", "confirmed_key_fields"]:
        fields = set(require_list(log_identity.get(key), f"indexer_behaviour_cases.log_identity.{key}"))
        if not {"chain_id", "transaction_hash", "log_index"} <= fields:
            raise IntegrationConformanceFixtureError(
                f"indexer_behaviour_cases.log_identity.{key} is incomplete"
            )
    confirmed = set(require_list(log_identity.get("confirmed_key_fields"), "indexer_behaviour_cases.log_identity.confirmed_key_fields"))
    if "block_hash" not in confirmed:
        raise IntegrationConformanceFixtureError(
            "confirmed log identity must include block_hash"
        )
    confirmation = require_dict(cases.get("confirmation_policy"), "indexer_behaviour_cases.confirmation_policy")
    if require_int(confirmation.get("minimum_confirmations"), "indexer_behaviour_cases.confirmation_policy.minimum_confirmations") < 1:
        raise IntegrationConformanceFixtureError("minimum_confirmations must be positive")
    unknown = require_dict(cases.get("unknown_log_policy"), "indexer_behaviour_cases.unknown_log_policy")
    for key in ["unknown_emitter", "unknown_topic0", "known_topic_wrong_emitter"]:
        if unknown.get(key) != "reject":
            raise IntegrationConformanceFixtureError(
                f"indexer_behaviour_cases.unknown_log_policy.{key} must reject"
            )
    redaction_cases = require_list(
        cases.get("no_secret_redaction_cases"),
        "indexer_behaviour_cases.no_secret_redaction_cases",
    )
    if not redaction_cases:
        raise IntegrationConformanceFixtureError("missing no-secret redaction case")


def validate_fixture(repo_root: Path, fixture_path: Path) -> None:
    fixture = require_dict(load_json(fixture_path, "integration conformance fixture"), "fixture")
    if fixture.get("schema_version") != FIXTURE_SCHEMA:
        raise IntegrationConformanceFixtureError("fixture schema_version is unsupported")
    validate_maturity(fixture)
    source_paths = validate_source_artifacts(repo_root, fixture)
    address_book = require_dict(load_json(source_paths["address_book"], "address book"), "address_book")
    event_catalog = require_dict(load_json(source_paths["event_topic_catalog"], "event topic catalog"), "event_topic_catalog")
    if address_book.get("schema_version") != ADDRESS_BOOK_SCHEMA:
        raise IntegrationConformanceFixtureError("address book schema_version is unsupported")
    if event_catalog.get("schema_version") != EVENT_TOPIC_CATALOG_SCHEMA:
        raise IntegrationConformanceFixtureError("event topic catalog schema_version is unsupported")
    validate_chain_config_case(fixture, address_book)
    validate_drop_authorization_cases(repo_root, fixture, address_book)
    validate_event_cases(fixture, address_book, event_catalog)
    validate_indexer_behaviour(fixture)
    scan_no_secrets(fixture)


def validate_doc(repo_root: Path, document_path: Path) -> None:
    if not document_path.is_file():
        raise IntegrationConformanceFixtureError(f"missing guide: {document_path}")
    text = document_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_DOC_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        raise IntegrationConformanceFixtureError(
            "integration conformance guide is missing required headings: "
            + ", ".join(missing_headings)
        )
    missing_required_phrases = missing_phrases(text, REQUIRED_DOC_PHRASES)
    if missing_required_phrases:
        raise IntegrationConformanceFixtureError(
            "integration conformance guide is missing required content: "
            + ", ".join(missing_required_phrases)
        )
    missing_commands = [command for command in REQUIRED_DOC_COMMANDS if command not in text]
    if missing_commands:
        raise IntegrationConformanceFixtureError(
            "integration conformance guide is missing required commands: "
            + ", ".join(missing_commands)
        )
    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_DOC_LINK_TARGETS if target not in links]
    if missing_targets:
        raise IntegrationConformanceFixtureError(
            "integration conformance guide is missing required links: "
            + ", ".join(missing_targets)
        )


def validate_integration_conformance_fixtures(
    repo_root: Path, fixture_path: Path, document_path: Path
) -> None:
    validate_fixture(repo_root, fixture_path)
    validate_doc(repo_root, document_path)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--fixture", type=Path, default=DEFAULT_FIXTURE)
    parser.add_argument("--doc", type=Path, default=DEFAULT_DOC)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    fixture_path = args.fixture
    if not fixture_path.is_absolute():
        fixture_path = repo_root / fixture_path
    document_path = args.doc
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_integration_conformance_fixtures(
            repo_root,
            fixture_path.resolve(),
            document_path.resolve(),
        )
    except IntegrationConformanceFixtureError as exc:
        print(f"Integration conformance fixture check failed: {exc}", file=sys.stderr)
        return 1

    print("Integration conformance fixtures are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
