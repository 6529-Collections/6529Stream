#!/usr/bin/env python3
"""Validate retained deployment ceremony evidence bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


EVIDENCE_SCHEMA = "6529stream.deployment-ceremony-evidence.v1"
CHECKSUM_DIGEST_STATUS = "not_available_self_referential"

DEFAULT_EVIDENCE = [
    Path("deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json")
]

ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")

ENVIRONMENTS = frozenset({"local", "fork", "testnet", "mainnet", "production"})
NON_LOCAL_ENVIRONMENTS = frozenset({"fork", "testnet", "mainnet", "production"})
RESULT_STATUSES = frozenset({"passed", "failed", "blocked", "pending", "not_applicable"})
VERIFICATION_STATUSES = frozenset(
    {"not_started", "submitted", "verified", "partial", "not_applicable"}
)
REQUIRED_RESULTS = (
    "admin_ceremony",
    "signer_setup",
    "metadata_browser",
    "auction_ceremony",
    "emergency_redeployment",
)
SECRET_KEY_PARTS = (
    "private_key",
    "mnemonic",
    "seed_phrase",
    "secret",
    "rpc_url",
    "api_key",
)


class CeremonyEvidenceError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise CeremonyEvidenceError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise CeremonyEvidenceError(f"invalid JSON in {path}: {exc}") from exc


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CeremonyEvidenceError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise CeremonyEvidenceError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise CeremonyEvidenceError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise CeremonyEvidenceError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise CeremonyEvidenceError(f"{path} must be an integer")
    return value


def require_positive_int(value: Any, path: str) -> int:
    number = require_int(value, path)
    if number < 1:
        raise CeremonyEvidenceError(f"{path} must be greater than zero")
    return number


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise CeremonyEvidenceError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise CeremonyEvidenceError(f"{path} must be a sha256: hash")
    return digest


def require_git_commit(value: Any, path: str) -> str:
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise CeremonyEvidenceError(f"{path} must be a 40-character git commit hash")
    return commit


def require_address(value: Any, path: str) -> str:
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise CeremonyEvidenceError(f"{path} must be a 20-byte hex address")
    return address.lower()


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    if "\\" in relative_path:
        raise CeremonyEvidenceError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise CeremonyEvidenceError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise CeremonyEvidenceError(f"{path} must stay inside the repository") from exc
    if not resolved.is_file():
        raise CeremonyEvidenceError(f"{path} references missing file: {relative_path}")
    return resolved


def validate_file_ref(value: Any, repo_root: Path, path: str) -> dict[str, Any]:
    ref = require_dict(value, path)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    expected_hash = require_sha256(ref.get("sha256"), f"{path}.sha256")
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    actual_hash = file_sha256(resolved)
    if actual_hash != expected_hash:
        raise CeremonyEvidenceError(
            f"{path}.sha256 mismatch for {relative_path}: expected {expected_hash}, got {actual_hash}"
        )
    return ref


def validate_checksum_bundle_ref(value: Any, repo_root: Path, path: str) -> None:
    ref = require_dict(value, path)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    resolve_repo_file(repo_root, relative_path, f"{path}.path")
    digest_status = require_string(ref.get("digest_status"), f"{path}.digest_status")
    if digest_status != CHECKSUM_DIGEST_STATUS:
        raise CeremonyEvidenceError(
            f"{path}.digest_status must be {CHECKSUM_DIGEST_STATUS}"
        )
    require_string(ref.get("reason"), f"{path}.reason")


def validate_artifacts(value: Any, repo_root: Path) -> None:
    artifacts = require_dict(value, "artifacts")
    validate_file_ref(artifacts.get("deployment_manifest"), repo_root, "artifacts.deployment_manifest")
    require_sha256(artifacts.get("deployment_manifest_canonical_sha256"), "artifacts.deployment_manifest_canonical_sha256")
    validate_file_ref(artifacts.get("address_book"), repo_root, "artifacts.address_book")
    validate_file_ref(artifacts.get("abi_checksums"), repo_root, "artifacts.abi_checksums")
    validate_checksum_bundle_ref(
        artifacts.get("release_checksum_bundle"), repo_root, "artifacts.release_checksum_bundle"
    )


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


def validate_participants(value: Any) -> None:
    participants = require_dict(value, "participants")
    require_address(participants.get("deployer"), "participants.deployer")
    require_address(participants.get("admin_safe"), "participants.admin_safe")
    require_address(participants.get("tdh_signer"), "participants.tdh_signer")
    require_address(participants.get("emergency_recipient"), "participants.emergency_recipient")


def validate_result(value: Any, repo_root: Path, path: str) -> str:
    result = require_dict(value, path)
    status = require_enum(result.get("status"), f"{path}.status", RESULT_STATUSES)
    command = result.get("command")
    if command is not None:
        require_string(command, f"{path}.command")
    require_string(result.get("notes"), f"{path}.notes")

    evidence = require_list(result.get("evidence"), f"{path}.evidence")
    if status == "passed" and not evidence:
        raise CeremonyEvidenceError(f"{path}.evidence must not be empty when status is passed")
    for index, item in enumerate(evidence):
        validate_file_ref(item, repo_root, f"{path}.evidence[{index}]")
    return status


def validate_ceremony_results(value: Any, repo_root: Path) -> dict[str, str]:
    results = require_dict(value, "ceremony_results")
    statuses: dict[str, str] = {}
    for key in REQUIRED_RESULTS:
        statuses[key] = validate_result(results.get(key), repo_root, f"ceremony_results.{key}")
    return statuses


def validate_verification_status(value: Any) -> str:
    verification = require_dict(value, "verification_status")
    contract_status = require_enum(
        verification.get("contract_verification"),
        "verification_status.contract_verification",
        VERIFICATION_STATUSES,
    )
    require_enum(
        verification.get("source_verification_inputs"),
        "verification_status.source_verification_inputs",
        VERIFICATION_STATUSES,
    )
    submissions = require_list(
        verification.get("explorer_submissions"), "verification_status.explorer_submissions"
    )
    for index, submission in enumerate(submissions):
        item = require_dict(submission, f"verification_status.explorer_submissions[{index}]")
        require_string(item.get("explorer"), f"verification_status.explorer_submissions[{index}].explorer")
        require_enum(
            item.get("status"),
            f"verification_status.explorer_submissions[{index}].status",
            VERIFICATION_STATUSES,
        )
    return contract_status


def validate_retained_artifacts(value: Any, repo_root: Path) -> int:
    retained = require_list(value, "retained_artifacts")
    for index, item in enumerate(retained):
        artifact = validate_file_ref(item, repo_root, f"retained_artifacts[{index}]")
        require_string(artifact.get("category"), f"retained_artifacts[{index}].category")
    return len(retained)


def validate_redaction_policy(value: Any) -> None:
    policy = require_dict(value, "redaction_policy")
    if require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets") is not True:
        raise CeremonyEvidenceError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def reject_secret_like_keys(value: Any, path: str = "evidence") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            key_text = str(key).lower()
            if key_text != "no_secrets" and any(part in key_text for part in SECRET_KEY_PARTS):
                raise CeremonyEvidenceError(f"{path}.{key} uses a secret-like key name")
            reject_secret_like_keys(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_secret_like_keys(child, f"{path}[{index}]")


def validate_evidence(path: Path, repo_root: Path) -> None:
    evidence = require_dict(load_json(path), str(path))
    reject_secret_like_keys(evidence)
    schema = require_string(evidence.get("schema_version"), "schema_version")
    if schema != EVIDENCE_SCHEMA:
        raise CeremonyEvidenceError(f"unsupported ceremony evidence schema: {schema}")

    require_string(evidence.get("evidence_id"), "evidence_id")
    require_string(evidence.get("protocol_version"), "protocol_version")
    require_string(evidence.get("deployment_version"), "deployment_version")
    environment = validate_network(evidence.get("network"))
    validate_source(evidence.get("source"))
    validate_participants(evidence.get("participants"))
    validate_artifacts(evidence.get("artifacts"), repo_root)
    statuses = validate_ceremony_results(evidence.get("ceremony_results"), repo_root)
    contract_verification = validate_verification_status(evidence.get("verification_status"))
    retained_count = validate_retained_artifacts(evidence.get("retained_artifacts"), repo_root)
    validate_redaction_policy(evidence.get("redaction_policy"))
    require_string(evidence.get("operator_notes"), "operator_notes")

    if environment in NON_LOCAL_ENVIRONMENTS:
        passed_sections = [name for name, status in statuses.items() if status == "passed"]
        if passed_sections and retained_count == 0:
            raise CeremonyEvidenceError(
                "non-local passed ceremony evidence requires retained_artifacts"
            )
        if environment in {"testnet", "mainnet", "production"} and contract_verification == "not_applicable":
            raise CeremonyEvidenceError(
                f"{environment} evidence cannot mark contract verification as not_applicable"
            )


def validate_many(paths: list[Path], repo_root: Path) -> None:
    if not paths:
        raise CeremonyEvidenceError("no ceremony evidence files configured")
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
    except CeremonyEvidenceError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print("ceremony evidence is valid")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
