#!/usr/bin/env python3
"""Validate retained release signature evidence bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


EVIDENCE_SCHEMA = "6529stream.release-signature-evidence.v1"
SELF_REFERENTIAL_DIGEST_STATUS = "not_available_self_referential"
LOCAL_PLACEHOLDER_STATUS = "not_available_local"

DEFAULT_EVIDENCE = [
    Path("release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json")
]

GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
FINGERPRINT_RE = re.compile(r"^[0-9a-fA-F]{40,64}$")

ENVIRONMENTS = frozenset({"local", "fork", "testnet", "mainnet", "production"})
NON_LOCAL_ENVIRONMENTS = frozenset({"fork", "testnet", "mainnet", "production"})
PRODUCTION_ENVIRONMENTS = frozenset({"mainnet", "production"})
SIGNING_IDENTITY_STATUSES = frozenset({LOCAL_PLACEHOLDER_STATUS, "active", "rotated", "revoked"})
SIGNATURE_STATUSES = frozenset({LOCAL_PLACEHOLDER_STATUS, "signed", "pending", "blocked"})
TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "evidence_id",
        "protocol_version",
        "release_version",
        "network",
        "source",
        "artifacts",
        "signing_identity",
        "signatures",
        "retained_artifacts",
        "redaction_policy",
        "operator_notes",
    }
)
NETWORK_FIELDS = frozenset({"environment", "name", "chain_id", "confirmation_depth"})
SOURCE_FIELDS = frozenset({"repository", "git_commit", "source_dirty", "ci_run"})
ARTIFACT_FIELDS = frozenset({"release_manifest", "checksum_bundle"})
SELF_REFERENTIAL_REF_FIELDS = frozenset({"path", "digest_status", "reason"})
SIGNING_IDENTITY_FIELDS = frozenset(
    {"status", "public_key_fingerprint", "key_custody", "rotation_policy"}
)
SIGNATURES_FIELDS = frozenset({"detached_checksum_signature", "signed_git_tag"})
SIGNATURE_RESULT_FIELDS = frozenset(
    {"status", "format", "artifact_path", "verification_command", "evidence", "notes"}
)
FILE_REF_FIELDS = frozenset({"path", "sha256"})
RETAINED_ARTIFACT_FIELDS = frozenset({"category", "path", "sha256"})
REDACTION_POLICY_FIELDS = frozenset({"no_secrets", "redacted_fields"})
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


class ReleaseSignatureEvidenceError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseSignatureEvidenceError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseSignatureEvidenceError(f"invalid JSON in {path}: {exc}") from exc


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseSignatureEvidenceError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise ReleaseSignatureEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise ReleaseSignatureEvidenceError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise ReleaseSignatureEvidenceError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ReleaseSignatureEvidenceError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise ReleaseSignatureEvidenceError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise ReleaseSignatureEvidenceError(f"{path} must be an integer")
    return value


def require_nonnegative_int(value: Any, path: str) -> int:
    number = require_int(value, path)
    if number < 0:
        raise ReleaseSignatureEvidenceError(f"{path} must be zero or greater")
    return number


def require_positive_int(value: Any, path: str) -> int:
    number = require_int(value, path)
    if number < 1:
        raise ReleaseSignatureEvidenceError(f"{path} must be greater than zero")
    return number


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise ReleaseSignatureEvidenceError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise ReleaseSignatureEvidenceError(f"{path} must be a sha256: hash")
    return digest


def require_git_commit(value: Any, path: str) -> str:
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise ReleaseSignatureEvidenceError(f"{path} must be a 40-character git commit hash")
    return commit


def require_fingerprint(value: Any, path: str) -> str:
    fingerprint = require_string(value, path)
    if not FINGERPRINT_RE.fullmatch(fingerprint):
        raise ReleaseSignatureEvidenceError(f"{path} must be a 40-64 character hex fingerprint")
    return fingerprint.lower()


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    if "\\" in relative_path:
        raise ReleaseSignatureEvidenceError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ReleaseSignatureEvidenceError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise ReleaseSignatureEvidenceError(f"{path} must stay inside the repository") from exc
    if not resolved.is_file():
        raise ReleaseSignatureEvidenceError(f"{path} references missing file: {relative_path}")
    return resolved


def validate_file_ref(
    value: Any,
    repo_root: Path,
    path: str,
    expected_fields: frozenset[str] = FILE_REF_FIELDS,
) -> Path:
    ref = require_dict(value, path)
    require_exact_keys(ref, path, expected_fields)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    expected_hash = require_sha256(ref.get("sha256"), f"{path}.sha256")
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    actual_hash = file_sha256(resolved)
    if actual_hash != expected_hash:
        raise ReleaseSignatureEvidenceError(
            f"{path}.sha256 mismatch for {relative_path}: expected {expected_hash}, got {actual_hash}"
        )
    return resolved


def validate_self_referential_ref(value: Any, repo_root: Path, path: str) -> None:
    ref = require_dict(value, path)
    require_exact_keys(ref, path, SELF_REFERENTIAL_REF_FIELDS)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    resolve_repo_file(repo_root, relative_path, f"{path}.path")
    digest_status = require_string(ref.get("digest_status"), f"{path}.digest_status")
    if digest_status != SELF_REFERENTIAL_DIGEST_STATUS:
        raise ReleaseSignatureEvidenceError(
            f"{path}.digest_status must be {SELF_REFERENTIAL_DIGEST_STATUS}"
        )
    require_string(ref.get("reason"), f"{path}.reason")


def validate_source(value: Any) -> None:
    source = require_dict(value, "source")
    require_exact_keys(source, "source", SOURCE_FIELDS)
    require_string(source.get("repository"), "source.repository")
    require_git_commit(source.get("git_commit"), "source.git_commit")
    require_bool(source.get("source_dirty"), "source.source_dirty")
    require_string(source.get("ci_run"), "source.ci_run")


def validate_network(value: Any) -> str:
    network = require_dict(value, "network")
    require_exact_keys(network, "network", NETWORK_FIELDS)
    environment = require_enum(network.get("environment"), "network.environment", ENVIRONMENTS)
    require_string(network.get("name"), "network.name")
    require_positive_int(network.get("chain_id"), "network.chain_id")
    require_nonnegative_int(network.get("confirmation_depth"), "network.confirmation_depth")
    return environment


def validate_artifacts(value: Any, repo_root: Path) -> None:
    artifacts = require_dict(value, "artifacts")
    require_exact_keys(artifacts, "artifacts", ARTIFACT_FIELDS)
    validate_self_referential_ref(
        artifacts.get("release_manifest"), repo_root, "artifacts.release_manifest"
    )
    validate_self_referential_ref(
        artifacts.get("checksum_bundle"), repo_root, "artifacts.checksum_bundle"
    )


def validate_signing_identity(value: Any, environment: str) -> str:
    identity = require_dict(value, "signing_identity")
    require_exact_keys(identity, "signing_identity", SIGNING_IDENTITY_FIELDS)
    status = require_enum(
        identity.get("status"), "signing_identity.status", SIGNING_IDENTITY_STATUSES
    )
    fingerprint = require_string(
        identity.get("public_key_fingerprint"), "signing_identity.public_key_fingerprint"
    )
    require_string(identity.get("key_custody"), "signing_identity.key_custody")
    require_string(identity.get("rotation_policy"), "signing_identity.rotation_policy")

    if environment in NON_LOCAL_ENVIRONMENTS and status == LOCAL_PLACEHOLDER_STATUS:
        raise ReleaseSignatureEvidenceError(
            "non-local release signature evidence cannot use not_available_local signer status"
        )
    if status != LOCAL_PLACEHOLDER_STATUS:
        require_fingerprint(fingerprint, "signing_identity.public_key_fingerprint")
    elif fingerprint != "not_applicable_local":
        raise ReleaseSignatureEvidenceError(
            "local placeholder signer fingerprint must be not_applicable_local"
        )
    return status


def validate_signature_result(value: Any, repo_root: Path, path: str, environment: str) -> str:
    result = require_dict(value, path)
    require_exact_keys(result, path, SIGNATURE_RESULT_FIELDS)
    status = require_enum(result.get("status"), f"{path}.status", SIGNATURE_STATUSES)
    require_string(result.get("format"), f"{path}.format")
    artifact_path = require_string(result.get("artifact_path"), f"{path}.artifact_path")
    verification_command = require_string(
        result.get("verification_command"), f"{path}.verification_command"
    )
    require_string(result.get("notes"), f"{path}.notes")

    evidence = require_list(result.get("evidence"), f"{path}.evidence")
    for index, item in enumerate(evidence):
        validate_file_ref(item, repo_root, f"{path}.evidence[{index}]")

    if environment in NON_LOCAL_ENVIRONMENTS and status == LOCAL_PLACEHOLDER_STATUS:
        raise ReleaseSignatureEvidenceError(
            f"non-local {path} cannot use not_available_local status"
        )
    if status == "signed":
        if artifact_path == "not_applicable_local":
            raise ReleaseSignatureEvidenceError(f"{path}.artifact_path must identify the signed artifact")
        if verification_command == "not_applicable_local":
            raise ReleaseSignatureEvidenceError(
                f"{path}.verification_command must verify the signed artifact"
            )
        if not evidence:
            raise ReleaseSignatureEvidenceError(f"{path}.evidence must not be empty when signed")
    else:
        if evidence:
            raise ReleaseSignatureEvidenceError(f"{path}.evidence must be empty unless status is signed")
    return status


def validate_signatures(value: Any, repo_root: Path, environment: str) -> dict[str, str]:
    signatures = require_dict(value, "signatures")
    require_exact_keys(signatures, "signatures", SIGNATURES_FIELDS)
    statuses = {
        "detached_checksum_signature": validate_signature_result(
            signatures.get("detached_checksum_signature"),
            repo_root,
            "signatures.detached_checksum_signature",
            environment,
        ),
        "signed_git_tag": validate_signature_result(
            signatures.get("signed_git_tag"),
            repo_root,
            "signatures.signed_git_tag",
            environment,
        ),
    }
    if environment in PRODUCTION_ENVIRONMENTS:
        for key, status in statuses.items():
            if status != "signed":
                raise ReleaseSignatureEvidenceError(f"production release ceremony requires signed {key}")
    return statuses


def validate_retained_artifacts(value: Any, repo_root: Path) -> set[str]:
    retained = require_list(value, "retained_artifacts")
    categories: set[str] = set()
    for index, item in enumerate(retained):
        artifact = require_dict(item, f"retained_artifacts[{index}]")
        require_exact_keys(artifact, f"retained_artifacts[{index}]", RETAINED_ARTIFACT_FIELDS)
        category = require_string(artifact.get("category"), f"retained_artifacts[{index}].category")
        if category in categories:
            raise ReleaseSignatureEvidenceError(
                f"retained_artifacts category is duplicated: {category}"
            )
        categories.add(category)
        validate_file_ref(
            artifact,
            repo_root,
            f"retained_artifacts[{index}]",
            RETAINED_ARTIFACT_FIELDS,
        )
    return categories


def validate_redaction_policy(value: Any) -> None:
    policy = require_dict(value, "redaction_policy")
    require_exact_keys(policy, "redaction_policy", REDACTION_POLICY_FIELDS)
    if require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets") is not True:
        raise ReleaseSignatureEvidenceError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def reject_secret_like_keys(value: Any, path: str = "evidence") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            key_text = str(key).lower()
            if key_text != "no_secrets" and any(part in key_text for part in SECRET_KEY_PARTS):
                raise ReleaseSignatureEvidenceError(f"{path}.{key} uses a secret-like key name")
            reject_secret_like_keys(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_secret_like_keys(child, f"{path}[{index}]")
    elif isinstance(value, str) and not path.startswith(
        "evidence.redaction_policy.redacted_fields["
    ):
        value_text = value.lower()
        if any(part in value_text for part in SECRET_KEY_PARTS) or SECRET_VALUE_RE.search(value):
            raise ReleaseSignatureEvidenceError(f"{path} contains a secret-like value")


def validate_evidence_document(value: Any, repo_root: Path, path: str = "evidence") -> None:
    evidence = require_dict(value, path)
    reject_secret_like_keys(evidence)
    require_exact_keys(evidence, path, TOP_LEVEL_FIELDS)
    schema = require_string(evidence.get("schema_version"), "schema_version")
    if schema != EVIDENCE_SCHEMA:
        raise ReleaseSignatureEvidenceError(f"unsupported release signature evidence schema: {schema}")

    require_string(evidence.get("evidence_id"), "evidence_id")
    require_string(evidence.get("protocol_version"), "protocol_version")
    require_string(evidence.get("release_version"), "release_version")
    environment = validate_network(evidence.get("network"))
    validate_source(evidence.get("source"))
    validate_artifacts(evidence.get("artifacts"), repo_root)
    signer_status = validate_signing_identity(evidence.get("signing_identity"), environment)
    signature_statuses = validate_signatures(evidence.get("signatures"), repo_root, environment)
    retained_categories = validate_retained_artifacts(evidence.get("retained_artifacts"), repo_root)
    validate_redaction_policy(evidence.get("redaction_policy"))
    require_string(evidence.get("operator_notes"), "operator_notes")

    if signer_status == LOCAL_PLACEHOLDER_STATUS:
        missing_local = {"release_signature_schema"} - retained_categories
        if missing_local:
            raise ReleaseSignatureEvidenceError(
                "local release signature evidence is missing retained categories: "
                + ", ".join(sorted(missing_local))
            )
    if environment in PRODUCTION_ENVIRONMENTS:
        required_categories = {"detached_signature", "signed_git_tag", "verification_output"}
        missing = sorted(required_categories - retained_categories)
        if missing:
            raise ReleaseSignatureEvidenceError(
                "production release signature evidence is missing retained categories: "
                + ", ".join(missing)
            )
        if any(status != "signed" for status in signature_statuses.values()):
            raise ReleaseSignatureEvidenceError("production release signature evidence must be signed")


def validate_evidence(path: Path, repo_root: Path) -> None:
    validate_evidence_document(load_json(path), repo_root, str(path))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root used for resolving evidence file references.",
    )
    parser.add_argument(
        "evidence",
        nargs="*",
        type=Path,
        help="Evidence JSON files to validate. Defaults to the committed local release signature evidence.",
    )
    args = parser.parse_args(argv)

    repo_root = args.repo_root.resolve()
    evidence_paths = args.evidence or [repo_root / path for path in DEFAULT_EVIDENCE]
    if not evidence_paths:
        raise ReleaseSignatureEvidenceError("no release signature evidence files configured")

    for evidence_path in evidence_paths:
        path = evidence_path if evidence_path.is_absolute() else repo_root / evidence_path
        validate_evidence(path, repo_root)

    print("release signature evidence is valid")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ReleaseSignatureEvidenceError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
