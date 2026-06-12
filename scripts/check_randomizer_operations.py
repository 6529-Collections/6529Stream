#!/usr/bin/env python3
"""Validate retained randomizer operations evidence bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


EVIDENCE_SCHEMA = "6529stream.randomizer-operations-evidence.v1"
CHECKSUM_DIGEST_STATUS = "not_available_self_referential"

DEFAULT_EVIDENCE = [
    Path("deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json")
]

ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
UINT_RE = re.compile(r"^(0|[1-9][0-9]*)$")

ENVIRONMENTS = frozenset({"local", "fork", "testnet", "mainnet", "production"})
NON_LOCAL_ENVIRONMENTS = frozenset({"fork", "testnet", "mainnet", "production"})
PRODUCTION_ENVIRONMENTS = frozenset({"mainnet", "production"})
PROVIDER_TYPES = frozenset({"chainlink_vrf", "arrng", "local_mock"})
FUNDING_STATUSES = frozenset({"not_applicable_local", "funded", "pending", "blocked"})
CONTROL_STATUSES = frozenset({"passed", "failed", "blocked", "pending", "not_applicable"})
REQUIRED_PROVIDERS = ("vrf", "arrng")
REQUIRED_CONTROLS = (
    "request_tracking",
    "callback_validation",
    "provider_epoch_migration",
    "pending_request_migration_block",
    "stale_request_policy",
    "failed_request_policy",
    "retry_policy",
    "reserve_accounting",
    "pause_policy",
    "emergency_withdrawal_boundary",
)
SECRET_KEY_PARTS = (
    "private_key",
    "mnemonic",
    "seed_phrase",
    "secret",
    "rpc_url",
    "api_key",
    "password",
)
SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|api[_ -]?key|password)\s*[:=]",
    re.IGNORECASE,
)


class RandomizerOperationsError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise RandomizerOperationsError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RandomizerOperationsError(f"invalid JSON in {path}: {exc}") from exc


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise RandomizerOperationsError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise RandomizerOperationsError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise RandomizerOperationsError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise RandomizerOperationsError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise RandomizerOperationsError(f"{path} must be an integer")
    return value


def require_nonnegative_int(value: Any, path: str) -> int:
    number = require_int(value, path)
    if number < 0:
        raise RandomizerOperationsError(f"{path} must be zero or greater")
    return number


def require_positive_int(value: Any, path: str) -> int:
    number = require_int(value, path)
    if number < 1:
        raise RandomizerOperationsError(f"{path} must be greater than zero")
    return number


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise RandomizerOperationsError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise RandomizerOperationsError(f"{path} must be a sha256: hash")
    return digest


def require_git_commit(value: Any, path: str) -> str:
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise RandomizerOperationsError(f"{path} must be a 40-character git commit hash")
    return commit


def require_address(value: Any, path: str) -> str:
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise RandomizerOperationsError(f"{path} must be a 20-byte hex address")
    return address.lower()


def require_uint_string(value: Any, path: str) -> str:
    text = require_string(value, path)
    if not UINT_RE.fullmatch(text):
        raise RandomizerOperationsError(f"{path} must be a base-10 unsigned integer string")
    return text


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    if "\\" in relative_path:
        raise RandomizerOperationsError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise RandomizerOperationsError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise RandomizerOperationsError(f"{path} must stay inside the repository") from exc
    if not resolved.is_file():
        raise RandomizerOperationsError(f"{path} references missing file: {relative_path}")
    return resolved


def validate_file_ref(value: Any, repo_root: Path, path: str) -> Path:
    ref = require_dict(value, path)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    expected_hash = require_sha256(ref.get("sha256"), f"{path}.sha256")
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    actual_hash = file_sha256(resolved)
    if actual_hash != expected_hash:
        raise RandomizerOperationsError(
            f"{path}.sha256 mismatch for {relative_path}: expected {expected_hash}, got {actual_hash}"
        )
    return resolved


def validate_checksum_bundle_ref(value: Any, repo_root: Path, path: str) -> None:
    ref = require_dict(value, path)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    resolve_repo_file(repo_root, relative_path, f"{path}.path")
    digest_status = require_string(ref.get("digest_status"), f"{path}.digest_status")
    if digest_status != CHECKSUM_DIGEST_STATUS:
        raise RandomizerOperationsError(
            f"{path}.digest_status must be {CHECKSUM_DIGEST_STATUS}"
        )
    require_string(ref.get("reason"), f"{path}.reason")


def validate_source(value: Any) -> None:
    source = require_dict(value, "source")
    require_string(source.get("repository"), "source.repository")
    require_git_commit(source.get("git_commit"), "source.git_commit")
    require_bool(source.get("source_dirty"), "source.source_dirty")
    require_string(source.get("ci_run"), "source.ci_run")


def validate_network(value: Any) -> str:
    network = require_dict(value, "network")
    environment = require_enum(network.get("environment"), "network.environment", ENVIRONMENTS)
    require_string(network.get("name"), "network.name")
    require_positive_int(network.get("chain_id"), "network.chain_id")
    require_int(network.get("confirmation_depth"), "network.confirmation_depth")
    return environment


def validate_artifacts(value: Any, repo_root: Path) -> dict[str, Path]:
    artifacts = require_dict(value, "artifacts")
    deployment_manifest = validate_file_ref(
        artifacts.get("deployment_manifest"), repo_root, "artifacts.deployment_manifest"
    )
    address_book = validate_file_ref(
        artifacts.get("address_book"), repo_root, "artifacts.address_book"
    )
    validate_file_ref(artifacts.get("abi_checksums"), repo_root, "artifacts.abi_checksums")
    validate_checksum_bundle_ref(
        artifacts.get("release_checksum_bundle"), repo_root, "artifacts.release_checksum_bundle"
    )
    return {
        "deployment_manifest": deployment_manifest,
        "address_book": address_book,
    }


def validate_evidence_list(value: Any, repo_root: Path, path: str, *, required: bool) -> int:
    evidence = require_list(value, path)
    if required and not evidence:
        raise RandomizerOperationsError(f"{path} must not be empty")
    for index, item in enumerate(evidence):
        validate_file_ref(item, repo_root, f"{path}[{index}]")
    return len(evidence)


def validate_provider(value: Any, repo_root: Path, path: str) -> dict[str, Any]:
    provider = require_dict(value, path)
    adapter = require_address(provider.get("adapter"), f"{path}.adapter")
    provider_address = require_address(provider.get("provider"), f"{path}.provider")
    provider_type = require_enum(provider.get("provider_type"), f"{path}.provider_type", PROVIDER_TYPES)
    provider_epoch = require_nonnegative_int(provider.get("provider_epoch"), f"{path}.provider_epoch")
    funding_status = require_enum(
        provider.get("funding_status"), f"{path}.funding_status", FUNDING_STATUSES
    )
    require_uint_string(provider.get("balance_wei"), f"{path}.balance_wei")
    refund_recipient = provider.get("refund_recipient")
    if refund_recipient is not None:
        require_address(refund_recipient, f"{path}.refund_recipient")
    require_string(provider.get("operator_notes"), f"{path}.operator_notes")
    evidence_count = validate_evidence_list(
        provider.get("evidence"),
        repo_root,
        f"{path}.evidence",
        required=funding_status == "funded",
    )
    return {
        "adapter": adapter,
        "provider": provider_address,
        "provider_type": provider_type,
        "provider_epoch": provider_epoch,
        "funding_status": funding_status,
        "evidence_count": evidence_count,
    }


def validate_provider_configuration(value: Any, repo_root: Path) -> dict[str, dict[str, Any]]:
    configuration = require_dict(value, "provider_configuration")
    providers: dict[str, dict[str, Any]] = {}
    for key in REQUIRED_PROVIDERS:
        providers[key] = validate_provider(
            configuration.get(key), repo_root, f"provider_configuration.{key}"
        )
    return providers


def validate_control_result(value: Any, repo_root: Path, path: str) -> str:
    result = require_dict(value, path)
    status = require_enum(result.get("status"), f"{path}.status", CONTROL_STATUSES)
    require_string(result.get("notes"), f"{path}.notes")
    validate_evidence_list(
        result.get("evidence"),
        repo_root,
        f"{path}.evidence",
        required=status == "passed",
    )
    return status


def validate_lifecycle_controls(value: Any, repo_root: Path) -> dict[str, str]:
    controls = require_dict(value, "lifecycle_controls")
    statuses: dict[str, str] = {}
    for key in REQUIRED_CONTROLS:
        statuses[key] = validate_control_result(
            controls.get(key), repo_root, f"lifecycle_controls.{key}"
        )
    return statuses


def validate_retained_artifacts(value: Any, repo_root: Path) -> set[str]:
    retained = require_list(value, "retained_artifacts")
    categories: set[str] = set()
    for index, item in enumerate(retained):
        artifact = require_dict(item, f"retained_artifacts[{index}]")
        category = require_string(artifact.get("category"), f"retained_artifacts[{index}].category")
        if category in categories:
            raise RandomizerOperationsError(f"retained_artifacts category is duplicated: {category}")
        categories.add(category)
        validate_file_ref(artifact, repo_root, f"retained_artifacts[{index}]")
    return categories


def validate_redaction_policy(value: Any) -> None:
    policy = require_dict(value, "redaction_policy")
    if require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets") is not True:
        raise RandomizerOperationsError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def reject_secret_like_keys(value: Any, path: str = "evidence") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            key_text = str(key).lower()
            if key_text != "no_secrets" and any(part in key_text for part in SECRET_KEY_PARTS):
                raise RandomizerOperationsError(f"{path}.{key} uses a secret-like key name")
            reject_secret_like_keys(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_secret_like_keys(child, f"{path}[{index}]")
    elif isinstance(value, str) and not path.startswith(
        "evidence.redaction_policy.redacted_fields["
    ):
        value_text = value.lower()
        if any(part in value_text for part in SECRET_KEY_PARTS) or SECRET_VALUE_RE.search(value):
            raise RandomizerOperationsError(f"{path} contains a secret-like value")


def validate_deployment_alignment(
    artifact_paths: dict[str, Path],
    providers: dict[str, dict[str, Any]],
) -> None:
    manifest = require_dict(load_json(artifact_paths["deployment_manifest"]), "deployment_manifest")
    contracts = require_dict(manifest.get("contracts"), "deployment_manifest.contracts")
    external = require_dict(
        manifest.get("external_dependencies"), "deployment_manifest.external_dependencies"
    )

    expected_contracts = {
        "vrf": "NextGenRandomizerVRF",
        "arrng": "NextGenRandomizerRNG",
    }
    expected_external = {
        "vrf": "vrf_coordinator",
        "arrng": "arrng_controller",
    }
    for provider_key, contract_name in expected_contracts.items():
        contract = require_dict(
            contracts.get(contract_name), f"deployment_manifest.contracts.{contract_name}"
        )
        manifest_address = require_address(
            contract.get("address"), f"deployment_manifest.contracts.{contract_name}.address"
        )
        if manifest_address != providers[provider_key]["adapter"]:
            raise RandomizerOperationsError(
                f"provider_configuration.{provider_key}.adapter does not match {contract_name}"
            )

        external_key = expected_external[provider_key]
        external_address = require_address(
            external.get(external_key), f"deployment_manifest.external_dependencies.{external_key}"
        )
        if external_address != providers[provider_key]["provider"]:
            raise RandomizerOperationsError(
                f"provider_configuration.{provider_key}.provider does not match {external_key}"
            )

    address_book = require_dict(load_json(artifact_paths["address_book"]), "address_book")
    address_book_contracts = require_dict(address_book.get("contracts"), "address_book.contracts")
    for provider_key, contract_name in expected_contracts.items():
        contract = require_dict(
            address_book_contracts.get(contract_name), f"address_book.contracts.{contract_name}"
        )
        address_book_address = require_address(
            contract.get("address"), f"address_book.contracts.{contract_name}.address"
        )
        if address_book_address != providers[provider_key]["adapter"]:
            raise RandomizerOperationsError(
                f"provider_configuration.{provider_key}.adapter does not match address book"
            )


def validate_environment_requirements(
    environment: str,
    providers: dict[str, dict[str, Any]],
    controls: dict[str, str],
    retained_categories: set[str],
) -> None:
    if environment not in NON_LOCAL_ENVIRONMENTS:
        return

    for provider_key, provider in providers.items():
        if provider["funding_status"] == "not_applicable_local":
            raise RandomizerOperationsError(
                f"non-local {provider_key} provider cannot use not_applicable_local funding"
            )

    if environment in PRODUCTION_ENVIRONMENTS:
        required_categories = {"provider_configuration", "provider_funding", "provider_health"}
        missing = sorted(required_categories - retained_categories)
        if missing:
            raise RandomizerOperationsError(
                "production randomizer evidence is missing retained categories: "
                + ", ".join(missing)
            )
        for provider_key, provider in providers.items():
            if provider["funding_status"] != "funded":
                raise RandomizerOperationsError(
                    f"production {provider_key} provider funding_status must be funded"
                )
            if provider["evidence_count"] == 0:
                raise RandomizerOperationsError(
                    f"production {provider_key} provider requires funding evidence"
                )
        for control_key, status in controls.items():
            if status != "passed":
                raise RandomizerOperationsError(
                    f"production lifecycle control must pass: {control_key}"
                )


def validate_evidence(path: Path, repo_root: Path) -> None:
    evidence = require_dict(load_json(path), str(path))
    reject_secret_like_keys(evidence)
    schema = require_string(evidence.get("schema_version"), "schema_version")
    if schema != EVIDENCE_SCHEMA:
        raise RandomizerOperationsError(f"unsupported randomizer evidence schema: {schema}")

    require_string(evidence.get("evidence_id"), "evidence_id")
    require_string(evidence.get("protocol_version"), "protocol_version")
    require_string(evidence.get("deployment_version"), "deployment_version")
    environment = validate_network(evidence.get("network"))
    validate_source(evidence.get("source"))
    artifact_paths = validate_artifacts(evidence.get("artifacts"), repo_root)
    providers = validate_provider_configuration(evidence.get("provider_configuration"), repo_root)
    controls = validate_lifecycle_controls(evidence.get("lifecycle_controls"), repo_root)
    retained_categories = validate_retained_artifacts(evidence.get("retained_artifacts"), repo_root)
    validate_redaction_policy(evidence.get("redaction_policy"))
    require_string(evidence.get("operator_notes"), "operator_notes")

    validate_deployment_alignment(artifact_paths, providers)
    validate_environment_requirements(environment, providers, controls, retained_categories)


def validate_many(paths: list[Path], repo_root: Path) -> None:
    if not paths:
        raise RandomizerOperationsError("no randomizer operations evidence files configured")
    for path in paths:
        validate_evidence(path, repo_root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", nargs="*", type=Path, default=DEFAULT_EVIDENCE)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()
    try:
        validate_many(args.evidence, repo_root)
    except RandomizerOperationsError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print("randomizer operations evidence is valid")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
