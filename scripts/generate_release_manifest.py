#!/usr/bin/env python3
"""Generate a deterministic top-level release manifest."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

import check_drop_authorization_signing_evidence as drop_signing_evidence_checker
import check_non_local_release_evidence as non_local_evidence_checker
import check_public_beta_evidence as public_beta_checker
import check_release_signatures as release_signature_checker
import check_signer_custody_readiness as signer_custody_checker


RELEASE_MANIFEST_SCHEMA = "6529stream.release-manifest.v1"
GENERATOR_VERSION = "1"

DEFAULT_OUTPUT = Path("release-artifacts/latest/release-manifest.json")
DEFAULT_RELEASE_ARTIFACTS_DIR = Path("release-artifacts/latest")
BASELINE_DIR = Path("release-artifacts/baselines")
DEFAULT_BASELINE = BASELINE_DIR / "v0.1.0" / "abi-surface.json"
GAS_SNAPSHOT_FILENAME = "gas-snapshot.snap"
DEFAULT_CONTRACT_CONFIG = Path("release-artifacts/contracts.json")
PUBLIC_BETA_EVIDENCE_FILENAME = "public-beta-evidence.json"
PUBLIC_BETA_BLOCKERS_FILENAME = "public-beta-blockers.md"
PRODUCTION_RELEASE_BLOCKERS_FILENAME = "production-release-blockers.md"
RELEASE_EVIDENCE_PACKET_INDEX_JSON_FILENAME = "release-evidence-packet-index.json"
RELEASE_EVIDENCE_PACKET_INDEX_MARKDOWN_FILENAME = "release-evidence-packet-index.md"
RELEASE_EVIDENCE_LIVE_AUDIT_ARCHIVE_JSON_FILENAME = (
    "release-evidence-live-audit-report-archive.json"
)
RELEASE_EVIDENCE_LIVE_AUDIT_ARCHIVE_MARKDOWN_FILENAME = (
    "release-evidence-live-audit-report-archive.md"
)
RELEASE_EVIDENCE_ISSUE_BACKLOG_JSON_FILENAME = "release-evidence-issue-backlog.json"
RELEASE_EVIDENCE_ISSUE_BACKLOG_MARKDOWN_FILENAME = "release-evidence-issue-backlog.md"
RELEASE_EVIDENCE_ISSUE_LINKS_JSON_FILENAME = "release-evidence-issue-links.json"
RELEASE_EVIDENCE_ISSUE_BODY_SYNC_JSON_FILENAME = "release-evidence-issue-body-sync.json"
RELEASE_EVIDENCE_ISSUE_BODY_SYNC_MARKDOWN_FILENAME = "release-evidence-issue-body-sync.md"
DEFAULT_DEPLOYMENT_CONFIG_DIR = Path("deployments/config")
DEFAULT_DEPLOYMENT_BROADCAST_DIR = Path("deployments/broadcasts")
DEFAULT_DEPLOYMENT_MANIFEST_DIR = Path("deployments/examples")
DEFAULT_ADDRESS_BOOK_DIR = Path("deployments/address-books")
DEFAULT_DEPLOYMENT_SCHEMA_DIR = Path("deployments/schema")
DEFAULT_CEREMONY_EVIDENCE_DIR = Path("deployments/ceremony-evidence")
DEFAULT_RANDOMIZER_OPERATIONS_DIR = Path("deployments/randomizer-operations")
DEFAULT_RELEASE_SIGNATURES_DIR = Path("release-artifacts/signatures")
DEFAULT_NON_LOCAL_EVIDENCE_DIR = Path("release-artifacts/evidence")
DEFAULT_DROP_AUTHORIZATION_SIGNING_DIR = Path(
    "release-artifacts/drop-authorization-signing"
)
DEFAULT_SIGNER_CUSTODY_READINESS_DIR = Path(
    "release-artifacts/signer-custody-readiness"
)
DEFAULT_CHANGELOG = Path("CHANGELOG.md")
DEFAULT_GOVERNANCE_DOCS = [
    Path("docs/release-policy.md"),
    Path("docs/deployment.md"),
    Path("docs/dependency-operations.md"),
    Path("docs/randomizer-operations.md"),
    Path("docs/release-signatures.md"),
    Path("docs/public-beta-evidence.md"),
    Path("docs/non-local-release-evidence.md"),
    Path("docs/architecture.md"),
    Path("docs/threat-model.md"),
    Path("docs/audit-package.md"),
    Path("docs/incident-response.md"),
    Path("docs/drop-authorization-signing.md"),
    Path("docs/signer-custody-readiness.md"),
    Path("docs/release-readiness.md"),
    Path("docs/tooling.md"),
    Path("docs/status.md"),
]
CHECKSUM_OUTPUTS = [
    {
        "path": "release-artifacts/latest/SHA256SUMS",
        "format": "sha256sum",
    },
    {
        "path": "release-artifacts/latest/release-checksums.json",
        "format": "json",
    },
]
CHECKSUM_DIGEST_STATUS = "not_available_self_referential"


class ReleaseManifestError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseManifestError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseManifestError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseManifestError(f"{path} must be an object")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ReleaseManifestError(f"{path} must be a non-empty string")
    return value


def require_existing_file(path: Path) -> None:
    if not path.is_file():
        raise ReleaseManifestError(f"missing required file: {path}")


def json_schema_version(value: Any) -> str | None:
    if not isinstance(value, dict):
        return None
    schema = value.get("schema_version") or value.get("manifest_schema_version") or value.get("$schema")
    if isinstance(schema, str) and schema:
        return schema
    return None


def file_record(path: Path, repo_root: Path, *, schema_required: bool = False) -> dict[str, Any]:
    require_existing_file(path)
    record: dict[str, Any] = {
        "path": normalize_path(path, repo_root),
        "sha256": file_sha256(path),
        "size_bytes": path.stat().st_size,
    }
    if path.suffix == ".json":
        data = load_json(path)
        schema = json_schema_version(data)
        if schema_required and schema is None:
            raise ReleaseManifestError(f"{path} is missing a schema version")
        if schema is not None:
            record["schema_version"] = schema
    return record


def json_files(directory: Path) -> list[Path]:
    if not directory.is_dir():
        raise ReleaseManifestError(f"missing required directory: {directory}")
    files = sorted(path for path in directory.glob("*.json") if path.is_file())
    if not files:
        raise ReleaseManifestError(f"required directory has no JSON files: {directory}")
    return files


def recursive_json_files(directory: Path) -> list[Path]:
    """Return JSON files from a directory and its subdirectories."""
    if not directory.is_dir():
        raise ReleaseManifestError(f"missing required directory: {directory}")
    files = sorted(path for path in directory.rglob("*.json") if path.is_file())
    if not files:
        raise ReleaseManifestError(f"required directory has no JSON files: {directory}")
    return files


def is_non_local_release_evidence_metadata(value: Any) -> bool:
    """Return whether JSON data is non-local release evidence metadata."""
    if not isinstance(value, dict):
        return False
    return (
        value.get("schema_version") == non_local_evidence_checker.EVIDENCE_SCHEMA
        and isinstance(value.get("evidence_id"), str)
        and isinstance(value.get("record_type"), str)
        and isinstance(value.get("source"), dict)
    )


def non_local_release_evidence_files(directory: Path) -> list[Path]:
    """Return recursive JSON files that are non-local evidence metadata."""
    files = [
        path
        for path in recursive_json_files(directory)
        if is_non_local_release_evidence_metadata(load_json(path))
    ]
    if not files:
        raise ReleaseManifestError(
            f"required directory has no non-local release evidence metadata: {directory}"
        )
    return files


def deployment_manifest_record(path: Path, repo_root: Path) -> dict[str, Any]:
    data = require_dict(load_json(path), str(path))
    release_artifacts = require_dict(data.get("release_artifacts"), f"{path}.release_artifacts")
    network = require_dict(data.get("network"), f"{path}.network")
    contracts = require_dict(data.get("contracts"), f"{path}.contracts")
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "protocol_version": require_string(data.get("protocol_version"), "protocol_version"),
            "deployment_version": require_string(
                data.get("deployment_version"), "deployment_version"
            ),
            "lifecycle_state": require_string(data.get("lifecycle_state"), "lifecycle_state"),
            "network": {
                "name": require_string(network.get("name"), "network.name"),
                "chain_id": network.get("chain_id"),
            },
            "manifest_sha256": require_string(
                release_artifacts.get("manifest_sha256"),
                "release_artifacts.manifest_sha256",
            ),
            "contracts": sorted(str(name) for name in contracts),
        }
    )
    return record


def address_book_record(path: Path, repo_root: Path) -> dict[str, Any]:
    data = require_dict(load_json(path), str(path))
    source = require_dict(data.get("source"), f"{path}.source")
    network = require_dict(data.get("network"), f"{path}.network")
    contracts = require_dict(data.get("contracts"), f"{path}.contracts")
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "protocol_version": require_string(data.get("protocol_version"), "protocol_version"),
            "deployment_version": require_string(
                data.get("deployment_version"), "deployment_version"
            ),
            "lifecycle_state": require_string(data.get("lifecycle_state"), "lifecycle_state"),
            "network": {
                "name": require_string(network.get("name"), "network.name"),
                "chain_id": network.get("chain_id"),
            },
            "deployment_manifest": require_string(
                source.get("deployment_manifest"), "source.deployment_manifest"
            ),
            "deployment_manifest_sha256": require_string(
                source.get("deployment_manifest_sha256"),
                "source.deployment_manifest_sha256",
            ),
            "contracts": sorted(str(name) for name in contracts),
        }
    )
    return record


def ceremony_evidence_record(path: Path, repo_root: Path) -> dict[str, Any]:
    data = require_dict(load_json(path), str(path))
    network = require_dict(data.get("network"), f"{path}.network")
    artifacts = require_dict(data.get("artifacts"), f"{path}.artifacts")
    verification_status = require_dict(
        data.get("verification_status"), f"{path}.verification_status"
    )
    release_checksum_bundle = require_dict(
        artifacts.get("release_checksum_bundle"), f"{path}.artifacts.release_checksum_bundle"
    )
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "evidence_id": require_string(data.get("evidence_id"), "evidence_id"),
            "protocol_version": require_string(data.get("protocol_version"), "protocol_version"),
            "deployment_version": require_string(
                data.get("deployment_version"), "deployment_version"
            ),
            "network": {
                "environment": require_string(network.get("environment"), "network.environment"),
                "name": require_string(network.get("name"), "network.name"),
                "chain_id": network.get("chain_id"),
            },
            "deployment_manifest": require_string(
                require_dict(
                    artifacts.get("deployment_manifest"), "artifacts.deployment_manifest"
                ).get("path"),
                "artifacts.deployment_manifest.path",
            ),
            "address_book": require_string(
                require_dict(artifacts.get("address_book"), "artifacts.address_book").get("path"),
                "artifacts.address_book.path",
            ),
            "release_checksum_bundle": require_string(
                release_checksum_bundle.get("path"), "artifacts.release_checksum_bundle.path"
            ),
            "contract_verification": require_string(
                verification_status.get("contract_verification"),
                "verification_status.contract_verification",
            ),
        }
    )
    return record


def randomizer_operations_record(path: Path, repo_root: Path) -> dict[str, Any]:
    data = require_dict(load_json(path), str(path))
    network = require_dict(data.get("network"), f"{path}.network")
    artifacts = require_dict(data.get("artifacts"), f"{path}.artifacts")
    provider_configuration = require_dict(
        data.get("provider_configuration"), f"{path}.provider_configuration"
    )
    providers = {}
    for key in ("vrf", "arrng"):
        provider = require_dict(
            provider_configuration.get(key), f"{path}.provider_configuration.{key}"
        )
        providers[key] = {
            "adapter": require_string(
                provider.get("adapter"), f"provider_configuration.{key}.adapter"
            ),
            "provider": require_string(
                provider.get("provider"), f"provider_configuration.{key}.provider"
            ),
            "provider_type": require_string(
                provider.get("provider_type"), f"provider_configuration.{key}.provider_type"
            ),
            "provider_epoch": provider.get("provider_epoch"),
            "funding_status": require_string(
                provider.get("funding_status"), f"provider_configuration.{key}.funding_status"
            ),
        }
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "evidence_id": require_string(data.get("evidence_id"), "evidence_id"),
            "protocol_version": require_string(data.get("protocol_version"), "protocol_version"),
            "deployment_version": require_string(
                data.get("deployment_version"), "deployment_version"
            ),
            "network": {
                "environment": require_string(network.get("environment"), "network.environment"),
                "name": require_string(network.get("name"), "network.name"),
                "chain_id": network.get("chain_id"),
            },
            "deployment_manifest": require_string(
                require_dict(
                    artifacts.get("deployment_manifest"), "artifacts.deployment_manifest"
                ).get("path"),
                "artifacts.deployment_manifest.path",
            ),
            "address_book": require_string(
                require_dict(artifacts.get("address_book"), "artifacts.address_book").get("path"),
                "artifacts.address_book.path",
            ),
            "providers": providers,
        }
    )
    return record


def release_signature_record(path: Path, repo_root: Path) -> dict[str, Any]:
    data = require_dict(load_json(path), str(path))
    try:
        release_signature_checker.validate_evidence_document(data, repo_root, str(path))
    except release_signature_checker.ReleaseSignatureEvidenceError as exc:
        raise ReleaseManifestError(f"invalid release signature evidence {path}: {exc}") from exc

    network = require_dict(data.get("network"), f"{path}.network")
    signing_identity = require_dict(data.get("signing_identity"), f"{path}.signing_identity")
    signatures = require_dict(data.get("signatures"), f"{path}.signatures")
    detached_signature = require_dict(
        signatures.get("detached_checksum_signature"),
        f"{path}.signatures.detached_checksum_signature",
    )
    signed_git_tag = require_dict(
        signatures.get("signed_git_tag"), f"{path}.signatures.signed_git_tag"
    )
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "evidence_id": require_string(data.get("evidence_id"), "evidence_id"),
            "protocol_version": require_string(data.get("protocol_version"), "protocol_version"),
            "release_version": require_string(data.get("release_version"), "release_version"),
            "network": {
                "environment": require_string(network.get("environment"), "network.environment"),
                "name": require_string(network.get("name"), "network.name"),
                "chain_id": network.get("chain_id"),
            },
            "signing_identity_status": require_string(
                signing_identity.get("status"), "signing_identity.status"
            ),
            "detached_checksum_signature": {
                "status": require_string(
                    detached_signature.get("status"),
                    "signatures.detached_checksum_signature.status",
                ),
                "format": require_string(
                    detached_signature.get("format"),
                    "signatures.detached_checksum_signature.format",
                ),
            },
            "signed_git_tag": {
                "status": require_string(
                    signed_git_tag.get("status"), "signatures.signed_git_tag.status"
                ),
                "format": require_string(
                    signed_git_tag.get("format"), "signatures.signed_git_tag.format"
                ),
            },
            "evidence": data,
        }
    )
    return record


def non_local_release_evidence_record(path: Path, repo_root: Path) -> dict[str, Any]:
    """Load, validate, and summarize non-local release evidence metadata."""
    data = require_dict(load_json(path), str(path))
    try:
        non_local_evidence_checker.validate_evidence_document(data, repo_root, str(path))
    except non_local_evidence_checker.NonLocalReleaseEvidenceError as exc:
        raise ReleaseManifestError(f"invalid non-local release evidence {path}: {exc}") from exc

    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "evidence_id": require_string(data.get("evidence_id"), "evidence_id"),
            "record_type": require_string(data.get("record_type"), "record_type"),
            "review_status": require_string(data.get("review_status"), "review_status"),
            "environment": require_string(data.get("environment"), "environment"),
            "public_beta_requirement_id": require_string(
                data.get("public_beta_requirement_id"), "public_beta_requirement_id"
            ),
            "retained_path": require_string(data.get("retained_path"), "retained_path"),
            "evidence": data,
        }
    )
    return record


def drop_authorization_signing_record(path: Path, repo_root: Path) -> dict[str, Any]:
    """Load, validate, and summarize drop authorization signing evidence."""
    data = require_dict(load_json(path), str(path))
    try:
        drop_signing_evidence_checker.validate_evidence_document(data, repo_root, str(path))
    except drop_signing_evidence_checker.DropAuthorizationSigningEvidenceError as exc:
        raise ReleaseManifestError(
            f"invalid drop authorization signing evidence {path}: {exc}"
        ) from exc

    payload = require_dict(data.get("payload"), f"{path}.payload")
    domain = require_dict(payload.get("domain"), f"{path}.payload.domain")
    message = require_dict(payload.get("message"), f"{path}.payload.message")
    derived = require_dict(payload.get("derived"), f"{path}.payload.derived")
    signature = require_dict(data.get("signature"), f"{path}.signature")
    signing_identity = require_dict(
        data.get("signing_identity"), f"{path}.signing_identity"
    )
    review = require_dict(data.get("review"), f"{path}.review")
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "evidence_id": require_string(data.get("evidence_id"), "evidence_id"),
            "record_type": require_string(data.get("record_type"), "record_type"),
            "review_status": require_string(data.get("review_status"), "review_status"),
            "environment": require_string(data.get("environment"), "environment"),
            "chain_id": data.get("chain_id"),
            "payload": {
                "payload_kind": require_string(payload.get("payload_kind"), "payload.payload_kind"),
                "payload_file": require_string(
                    require_dict(payload.get("payload_file"), "payload.payload_file").get("path"),
                    "payload.payload_file.path",
                ),
                "domain": {
                    "name": require_string(domain.get("name"), "payload.domain.name"),
                    "version": require_string(
                        domain.get("version"), "payload.domain.version"
                    ),
                    "chain_id": domain.get("chain_id"),
                    "verifying_contract": require_string(
                        domain.get("verifying_contract"),
                        "payload.domain.verifying_contract",
                    ),
                },
                "message": {
                    "drop_id": require_string(message.get("drop_id"), "payload.message.drop_id"),
                    "collection_id": message.get("collection_id"),
                    "sale_mode": message.get("sale_mode"),
                    "signer_epoch": message.get("signer_epoch"),
                    "nonce": message.get("nonce"),
                    "deadline": message.get("deadline"),
                },
                "derived": {
                    "signer": require_string(derived.get("signer"), "payload.derived.signer"),
                    "digest": require_string(derived.get("digest"), "payload.derived.digest"),
                    "domain_separator": require_string(
                        derived.get("domain_separator"), "payload.derived.domain_separator"
                    ),
                    "struct_hash": require_string(
                        derived.get("struct_hash"), "payload.derived.struct_hash"
                    ),
                },
            },
            "signing_identity": {
                "signer_type": require_string(
                    signing_identity.get("signer_type"), "signing_identity.signer_type"
                ),
                "signer": require_string(signing_identity.get("signer"), "signing_identity.signer"),
                "signer_epoch": signing_identity.get("signer_epoch"),
                "custody_status": require_string(
                    signing_identity.get("custody_status"),
                    "signing_identity.custody_status",
                ),
                "signer_lifecycle_status": require_string(
                    signing_identity.get("signer_lifecycle_status"),
                    "signing_identity.signer_lifecycle_status",
                ),
            },
            "signature": {
                "status": require_string(signature.get("status"), "signature.status"),
                "verification_status": require_string(
                    signature.get("verification_status"), "signature.verification_status"
                ),
            },
            "review": {
                "reviewer": require_string(review.get("reviewer"), "review.reviewer"),
                "approval_status": require_string(
                    review.get("approval_status"), "review.approval_status"
                ),
            },
            "evidence": data,
        }
    )
    return record


def signer_custody_readiness_record(path: Path, repo_root: Path) -> dict[str, Any]:
    """Load, validate, and summarize signer custody readiness evidence."""
    data = require_dict(load_json(path), str(path))
    try:
        signer_custody_checker.validate_evidence_document(data, repo_root, str(path))
    except signer_custody_checker.SignerCustodyReadinessError as exc:
        raise ReleaseManifestError(
            f"invalid signer custody readiness evidence {path}: {exc}"
        ) from exc

    signer_identity = require_dict(
        data.get("signer_identity"), f"{path}.signer_identity"
    )
    custody = require_dict(data.get("custody"), f"{path}.custody")
    lifecycle = require_dict(data.get("lifecycle"), f"{path}.lifecycle")
    operations = require_dict(data.get("operations"), f"{path}.operations")
    review = require_dict(data.get("review"), f"{path}.review")
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "evidence_id": require_string(data.get("evidence_id"), "evidence_id"),
            "record_type": require_string(data.get("record_type"), "record_type"),
            "review_status": require_string(data.get("review_status"), "review_status"),
            "environment": require_string(data.get("environment"), "environment"),
            "chain_id": data.get("chain_id"),
            "signer_identity": {
                "signer_type": require_string(
                    signer_identity.get("signer_type"),
                    "signer_identity.signer_type",
                ),
                "expected_signer": require_string(
                    signer_identity.get("expected_signer"),
                    "signer_identity.expected_signer",
                ),
                "signer_epoch": signer_identity.get("signer_epoch"),
                "signer_manager": require_string(
                    signer_identity.get("signer_manager"),
                    "signer_identity.signer_manager",
                ),
                "signer_manager_type": require_string(
                    signer_identity.get("signer_manager_type"),
                    "signer_identity.signer_manager_type",
                ),
                "erc1271_support_status": require_string(
                    signer_identity.get("erc1271_support_status"),
                    "signer_identity.erc1271_support_status",
                ),
                "erc1271_support_detail": require_dict(
                    signer_identity.get("erc1271_support_detail"),
                    "signer_identity.erc1271_support_detail",
                ),
                "signer_service_class": require_string(
                    signer_identity.get("signer_service_class"),
                    "signer_identity.signer_service_class",
                ),
            },
            "custody": {
                "custody_status": require_string(
                    custody.get("custody_status"), "custody.custody_status"
                ),
                "key_material_location": require_string(
                    custody.get("key_material_location"),
                    "custody.key_material_location",
                ),
                "separation_of_duties": require_string(
                    custody.get("separation_of_duties"),
                    "custody.separation_of_duties",
                ),
            },
            "lifecycle": {
                "rotation_status": require_string(
                    lifecycle.get("rotation_status"), "lifecycle.rotation_status"
                ),
                "revocation_status": require_string(
                    lifecycle.get("revocation_status"), "lifecycle.revocation_status"
                ),
                "compromise_response_status": require_string(
                    lifecycle.get("compromise_response_status"),
                    "lifecycle.compromise_response_status",
                ),
                "signer_epoch_rotation_tested": lifecycle.get(
                    "signer_epoch_rotation_tested"
                ),
                "per_drop_cancellation_tested": lifecycle.get(
                    "per_drop_cancellation_tested"
                ),
            },
            "operations": {
                "monitoring_status": require_string(
                    operations.get("monitoring_status"),
                    "operations.monitoring_status",
                ),
                "signer_service_integration_status": require_string(
                    operations.get("signer_service_integration_status"),
                    "operations.signer_service_integration_status",
                ),
            },
            "review": {
                "reviewer": require_string(review.get("reviewer"), "review.reviewer"),
                "approval_status": require_string(
                    review.get("approval_status"), "review.approval_status"
                ),
            },
            "evidence": data,
        }
    )
    return record


def public_beta_evidence_record(path: Path, repo_root: Path) -> dict[str, Any]:
    """Load, validate, and summarize public-beta evidence status."""
    data = require_dict(load_json(path), str(path))
    try:
        public_beta_checker.validate_evidence_document(data, repo_root, str(path))
    except public_beta_checker.PublicBetaEvidenceError as exc:
        raise ReleaseManifestError(f"invalid public beta evidence {path}: {exc}") from exc

    status = require_dict(data.get("status"), f"{path}.status")
    phase_requirements = {
        public_beta_checker.PUBLIC_BETA_PHASE: {},
        public_beta_checker.PRODUCTION_PHASE: {},
    }
    for item in data.get("requirements", []):
        if not isinstance(item, dict):
            continue
        phase = item.get("phase")
        requirement_id = item.get("id")
        requirement_status = item.get("status")
        if phase in phase_requirements and isinstance(requirement_id, str):
            phase_requirements[phase][requirement_id] = requirement_status

    blocking_counts = {
        phase: sum(
            1
            for requirement_status in requirements.values()
            if requirement_status in public_beta_checker.BLOCKING_STATUSES
        )
        for phase, requirements in phase_requirements.items()
    }

    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "release_version": require_string(data.get("release_version"), "release_version"),
            "status": {
                "public_beta": require_string(
                    status.get("public_beta"), "status.public_beta"
                ),
                "production_release": require_string(
                    status.get("production_release"), "status.production_release"
                ),
            },
            "blocking_counts": blocking_counts,
        }
    )
    return record


def artifact_manifest_record(release_artifacts_dir: Path, repo_root: Path) -> dict[str, Any]:
    path = release_artifacts_dir / "release-artifact-manifest.json"
    data = require_dict(load_json(path), str(path))
    artifacts = require_dict(data.get("artifacts"), "release-artifact-manifest.artifacts")
    record = file_record(path, repo_root, schema_required=True)
    record["artifacts"] = {
        str(name): require_dict(value, f"artifacts.{name}")
        for name, value in sorted(artifacts.items())
    }
    return record


def default_gas_snapshot_path(protocol_versions: list[str]) -> Path:
    if len(protocol_versions) != 1:
        raise ReleaseManifestError(
            "gas snapshot baseline requires exactly one protocol version; "
            f"found {protocol_versions}"
        )

    protocol_version = protocol_versions[0]
    if "/" in protocol_version or "\\" in protocol_version:
        raise ReleaseManifestError(
            f"protocol version is not safe for a baseline path: {protocol_version}"
        )
    return BASELINE_DIR / f"v{protocol_version}" / GAS_SNAPSHOT_FILENAME


def resolve_gas_snapshot_path(
    gas_snapshot_path: Path | None, protocol_versions: list[str], repo_root: Path
) -> Path:
    expected_path = default_gas_snapshot_path(protocol_versions)
    expected_resolved = (repo_root / expected_path).resolve()
    if gas_snapshot_path is None:
        return expected_resolved
    if gas_snapshot_path.name != GAS_SNAPSHOT_FILENAME:
        raise ReleaseManifestError(
            f"gas snapshot path must end with {GAS_SNAPSHOT_FILENAME}: {gas_snapshot_path}"
        )
    if gas_snapshot_path.parent.name != expected_path.parent.name:
        raise ReleaseManifestError(
            "gas snapshot path version does not match release protocol version "
            f"{protocol_versions[0]}: {gas_snapshot_path}"
        )
    candidate_resolved = (
        gas_snapshot_path
        if gas_snapshot_path.is_absolute()
        else repo_root / gas_snapshot_path
    ).resolve()
    if candidate_resolved != expected_resolved:
        raise ReleaseManifestError(
            "gas snapshot path must match canonical release baseline "
            f"{expected_path}: {gas_snapshot_path}"
        )
    return expected_resolved


def checksum_bundle() -> dict[str, Any]:
    return {
        "status": "generated_after_release_manifest",
        "generated_by": "scripts/generate_release_checksums.py:1",
        "digest_policy": {
            "status": CHECKSUM_DIGEST_STATUS,
            "reason": (
                "The checksum bundle covers release-manifest.json. Embedding the "
                "checksum bundle digest here would create a self-referential hash cycle."
            ),
        },
        "outputs": [
            {
                **entry,
                "sha256": CHECKSUM_DIGEST_STATUS,
            }
            for entry in CHECKSUM_OUTPUTS
        ],
        "coverage_expectation": {
            "release_manifest_path": "release-artifacts/latest/release-manifest.json",
            "covered_by_checksum_bundle": True,
        },
    }


def build_manifest(
    repo_root: Path,
    output_path: Path,
    release_artifacts_dir: Path,
    baseline_path: Path,
    gas_snapshot_path: Path | None,
    contract_config_path: Path,
    deployment_config_dir: Path,
    deployment_broadcast_dir: Path,
    deployment_manifest_dir: Path,
    address_book_dir: Path,
    deployment_schema_dir: Path,
    ceremony_evidence_dir: Path,
    randomizer_operations_dir: Path,
    changelog_path: Path,
    governance_docs: list[Path],
    non_local_evidence_dir: Path | None = None,
    drop_authorization_signing_dir: Path | None = None,
    signer_custody_readiness_dir: Path | None = None,
) -> dict[str, Any]:
    release_signatures_dir = repo_root / DEFAULT_RELEASE_SIGNATURES_DIR
    resolved_non_local_evidence_dir = (
        repo_root / DEFAULT_NON_LOCAL_EVIDENCE_DIR
        if non_local_evidence_dir is None
        else (
            non_local_evidence_dir
            if non_local_evidence_dir.is_absolute()
            else repo_root / non_local_evidence_dir
        )
    )
    resolved_drop_authorization_signing_dir = (
        repo_root / DEFAULT_DROP_AUTHORIZATION_SIGNING_DIR
        if drop_authorization_signing_dir is None
        else (
            drop_authorization_signing_dir
            if drop_authorization_signing_dir.is_absolute()
            else repo_root / drop_authorization_signing_dir
        )
    )
    resolved_signer_custody_readiness_dir = (
        repo_root / DEFAULT_SIGNER_CUSTODY_READINESS_DIR
        if signer_custody_readiness_dir is None
        else (
            signer_custody_readiness_dir
            if signer_custody_readiness_dir.is_absolute()
            else repo_root / signer_custody_readiness_dir
        )
    )
    deployment_manifests = [
        deployment_manifest_record(path, repo_root) for path in json_files(deployment_manifest_dir)
    ]
    address_books = [address_book_record(path, repo_root) for path in json_files(address_book_dir)]
    ceremony_evidence = [
        ceremony_evidence_record(path, repo_root) for path in json_files(ceremony_evidence_dir)
    ]
    randomizer_operations = [
        randomizer_operations_record(path, repo_root)
        for path in json_files(randomizer_operations_dir)
    ]
    release_signatures = [
        release_signature_record(path, repo_root) for path in json_files(release_signatures_dir)
    ]
    non_local_release_evidence = [
        non_local_release_evidence_record(path, repo_root)
        for path in non_local_release_evidence_files(resolved_non_local_evidence_dir)
    ]
    drop_authorization_signing_evidence = [
        drop_authorization_signing_record(path, repo_root)
        for path in json_files(resolved_drop_authorization_signing_dir)
    ]
    signer_custody_readiness = [
        signer_custody_readiness_record(path, repo_root)
        for path in json_files(resolved_signer_custody_readiness_dir)
    ]
    protocol_versions = sorted(
        set(
            [record["protocol_version"] for record in deployment_manifests]
            + [record["protocol_version"] for record in address_books]
            + [record["protocol_version"] for record in ceremony_evidence]
            + [record["protocol_version"] for record in randomizer_operations]
            + [record["protocol_version"] for record in release_signatures]
        )
    )
    deployment_versions = sorted(
        set(
            [record["deployment_version"] for record in deployment_manifests]
            + [record["deployment_version"] for record in address_books]
            + [record["deployment_version"] for record in ceremony_evidence]
            + [record["deployment_version"] for record in randomizer_operations]
        )
    )
    resolved_gas_snapshot_path = resolve_gas_snapshot_path(
        gas_snapshot_path, protocol_versions, repo_root
    )

    return {
        "schema_version": RELEASE_MANIFEST_SCHEMA,
        "generated_by": f"scripts/generate_release_manifest.py:{GENERATOR_VERSION}",
        "release": {
            "project": "6529Stream",
            "status": "pre_audit_local_baseline",
            "protocol_versions": protocol_versions,
            "deployment_versions": deployment_versions,
        },
        "source": {
            "output": normalize_path(output_path, repo_root),
            "release_artifacts_dir": normalize_path(release_artifacts_dir, repo_root),
            "deployment_config_dir": normalize_path(deployment_config_dir, repo_root),
            "deployment_broadcast_dir": normalize_path(deployment_broadcast_dir, repo_root),
            "deployment_manifest_dir": normalize_path(deployment_manifest_dir, repo_root),
            "address_book_dir": normalize_path(address_book_dir, repo_root),
            "deployment_schema_dir": normalize_path(deployment_schema_dir, repo_root),
            "ceremony_evidence_dir": normalize_path(ceremony_evidence_dir, repo_root),
            "randomizer_operations_dir": normalize_path(
                randomizer_operations_dir, repo_root
            ),
            "release_signatures_dir": normalize_path(release_signatures_dir, repo_root),
            "non_local_evidence_dir": normalize_path(
                resolved_non_local_evidence_dir, repo_root
            ),
            "drop_authorization_signing_dir": normalize_path(
                resolved_drop_authorization_signing_dir, repo_root
            ),
            "signer_custody_readiness_dir": normalize_path(
                resolved_signer_custody_readiness_dir, repo_root
            ),
        },
        "release_artifacts": {
            "contract_config": file_record(contract_config_path, repo_root, schema_required=True),
            "abi_checksums": file_record(
                release_artifacts_dir / "abi-checksums.json",
                repo_root,
                schema_required=True,
            ),
            "event_topic_catalog": file_record(
                release_artifacts_dir / "event-topic-catalog.json",
                repo_root,
                schema_required=True,
            ),
            "interface_ids": file_record(
                release_artifacts_dir / "interface-ids.json",
                repo_root,
                schema_required=True,
            ),
            "artifact_manifest": artifact_manifest_record(release_artifacts_dir, repo_root),
            "dependency_artifact_manifest": file_record(
                release_artifacts_dir / "dependency-artifact-manifest.json",
                repo_root,
                schema_required=True,
            ),
            "source_verification_inputs": file_record(
                release_artifacts_dir / "source-verification-inputs.json",
                repo_root,
                schema_required=True,
            ),
            "public_beta_evidence": public_beta_evidence_record(
                release_artifacts_dir / PUBLIC_BETA_EVIDENCE_FILENAME,
                repo_root,
            ),
            "public_beta_blocker_report": file_record(
                release_artifacts_dir / PUBLIC_BETA_BLOCKERS_FILENAME,
                repo_root,
            ),
            "production_release_blocker_report": file_record(
                release_artifacts_dir / PRODUCTION_RELEASE_BLOCKERS_FILENAME,
                repo_root,
            ),
            "release_evidence_packet_index": {
                "json": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_PACKET_INDEX_JSON_FILENAME,
                    repo_root,
                    schema_required=True,
                ),
                "markdown": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_PACKET_INDEX_MARKDOWN_FILENAME,
                    repo_root,
                ),
            },
            "release_evidence_live_audit_report_archive": {
                "json": file_record(
                    release_artifacts_dir
                    / RELEASE_EVIDENCE_LIVE_AUDIT_ARCHIVE_JSON_FILENAME,
                    repo_root,
                    schema_required=True,
                ),
                "markdown": file_record(
                    release_artifacts_dir
                    / RELEASE_EVIDENCE_LIVE_AUDIT_ARCHIVE_MARKDOWN_FILENAME,
                    repo_root,
                ),
            },
            "release_evidence_issue_backlog": {
                "json": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_ISSUE_BACKLOG_JSON_FILENAME,
                    repo_root,
                    schema_required=True,
                ),
                "markdown": file_record(
                    release_artifacts_dir / RELEASE_EVIDENCE_ISSUE_BACKLOG_MARKDOWN_FILENAME,
                    repo_root,
                ),
            },
            "release_evidence_issue_links": file_record(
                release_artifacts_dir / RELEASE_EVIDENCE_ISSUE_LINKS_JSON_FILENAME,
                repo_root,
                schema_required=True,
            ),
            "release_evidence_issue_body_sync": {
                "json": file_record(
                    release_artifacts_dir
                    / RELEASE_EVIDENCE_ISSUE_BODY_SYNC_JSON_FILENAME,
                    repo_root,
                    schema_required=True,
                ),
                "markdown": file_record(
                    release_artifacts_dir
                    / RELEASE_EVIDENCE_ISSUE_BODY_SYNC_MARKDOWN_FILENAME,
                    repo_root,
                ),
            },
            "release_signature_evidence": release_signatures,
            "non_local_release_evidence": non_local_release_evidence,
            "drop_authorization_signing_evidence": (
                drop_authorization_signing_evidence
            ),
            "signer_custody_readiness": signer_custody_readiness,
            "abi_compatibility_baseline": file_record(
                baseline_path,
                repo_root,
                schema_required=True,
            ),
            "gas_snapshot_baseline": file_record(resolved_gas_snapshot_path, repo_root),
        },
        "deployment_artifacts": {
            "configs": [
                file_record(path, repo_root, schema_required=True)
                for path in json_files(deployment_config_dir)
            ],
            "broadcasts": [
                file_record(path, repo_root) for path in json_files(deployment_broadcast_dir)
            ],
            "manifests": deployment_manifests,
            "address_books": address_books,
            "schemas": [
                file_record(path, repo_root, schema_required=True)
                for path in json_files(deployment_schema_dir)
            ],
            "ceremony_evidence": ceremony_evidence,
            "randomizer_operations": randomizer_operations,
        },
        "release_notes_and_policy": {
            "changelog": file_record(changelog_path, repo_root),
            "governance_docs": [file_record(path, repo_root) for path in governance_docs],
        },
        "checksum_bundle": checksum_bundle(),
        "unavailable_release_ceremony": {
            "signed_git_tag": "not_available",
            "detached_checksum_signature": "not_available",
            "production_broadcast_manifest": "not_available",
            "live_contract_verification": "not_available",
        },
    }


def build_output_text(
    repo_root: Path,
    output_path: Path,
    release_artifacts_dir: Path,
    baseline_path: Path,
    gas_snapshot_path: Path | None,
    contract_config_path: Path,
    deployment_config_dir: Path,
    deployment_broadcast_dir: Path,
    deployment_manifest_dir: Path,
    address_book_dir: Path,
    deployment_schema_dir: Path,
    ceremony_evidence_dir: Path,
    randomizer_operations_dir: Path,
    changelog_path: Path,
    governance_docs: list[Path],
    non_local_evidence_dir: Path | None = None,
    drop_authorization_signing_dir: Path | None = None,
    signer_custody_readiness_dir: Path | None = None,
) -> str:
    manifest = build_manifest(
        repo_root,
        output_path,
        release_artifacts_dir,
        baseline_path,
        gas_snapshot_path,
        contract_config_path,
        deployment_config_dir,
        deployment_broadcast_dir,
        deployment_manifest_dir,
        address_book_dir,
        deployment_schema_dir,
        ceremony_evidence_dir,
        randomizer_operations_dir,
        changelog_path,
        governance_docs,
        non_local_evidence_dir,
        drop_authorization_signing_dir,
        signer_custody_readiness_dir,
    )
    return json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"


def write_output(
    repo_root: Path,
    output_path: Path,
    release_artifacts_dir: Path,
    baseline_path: Path,
    gas_snapshot_path: Path | None,
    contract_config_path: Path,
    deployment_config_dir: Path,
    deployment_broadcast_dir: Path,
    deployment_manifest_dir: Path,
    address_book_dir: Path,
    deployment_schema_dir: Path,
    ceremony_evidence_dir: Path,
    randomizer_operations_dir: Path,
    changelog_path: Path,
    governance_docs: list[Path],
    non_local_evidence_dir: Path | None = None,
    drop_authorization_signing_dir: Path | None = None,
    signer_custody_readiness_dir: Path | None = None,
) -> Path:
    output_text = build_output_text(
        repo_root,
        output_path,
        release_artifacts_dir,
        baseline_path,
        gas_snapshot_path,
        contract_config_path,
        deployment_config_dir,
        deployment_broadcast_dir,
        deployment_manifest_dir,
        address_book_dir,
        deployment_schema_dir,
        ceremony_evidence_dir,
        randomizer_operations_dir,
        changelog_path,
        governance_docs,
        non_local_evidence_dir,
        drop_authorization_signing_dir,
        signer_custody_readiness_dir,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output_text, encoding="utf-8", newline="\n")
    return output_path


def check_output(
    repo_root: Path,
    output_path: Path,
    release_artifacts_dir: Path,
    baseline_path: Path,
    gas_snapshot_path: Path | None,
    contract_config_path: Path,
    deployment_config_dir: Path,
    deployment_broadcast_dir: Path,
    deployment_manifest_dir: Path,
    address_book_dir: Path,
    deployment_schema_dir: Path,
    ceremony_evidence_dir: Path,
    randomizer_operations_dir: Path,
    changelog_path: Path,
    governance_docs: list[Path],
    non_local_evidence_dir: Path | None = None,
    drop_authorization_signing_dir: Path | None = None,
    signer_custody_readiness_dir: Path | None = None,
) -> int:
    if not output_path.exists():
        print(f"missing {normalize_path(output_path, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_manifest.py` and commit the regenerated file",
            file=sys.stderr,
        )
        return 1

    expected_text = build_output_text(
        repo_root,
        output_path,
        release_artifacts_dir,
        baseline_path,
        gas_snapshot_path,
        contract_config_path,
        deployment_config_dir,
        deployment_broadcast_dir,
        deployment_manifest_dir,
        address_book_dir,
        deployment_schema_dir,
        ceremony_evidence_dir,
        randomizer_operations_dir,
        changelog_path,
        governance_docs,
        non_local_evidence_dir,
        drop_authorization_signing_dir,
        signer_custody_readiness_dir,
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        expected = Path(temp_dir) / output_path.name
        expected.write_text(expected_text, encoding="utf-8", newline="\n")
        if not filecmp.cmp(expected, output_path, shallow=False):
            print(
                f"changed {normalize_path(output_path, repo_root)}",
                file=sys.stderr,
            )
            print(
                "run `python scripts/generate_release_manifest.py` and commit the regenerated file",
                file=sys.stderr,
            )
            return 1

    print("release manifest is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--release-artifacts-dir", type=Path, default=DEFAULT_RELEASE_ARTIFACTS_DIR)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--gas-snapshot", type=Path)
    parser.add_argument("--contract-config", type=Path, default=DEFAULT_CONTRACT_CONFIG)
    parser.add_argument("--deployment-config-dir", type=Path, default=DEFAULT_DEPLOYMENT_CONFIG_DIR)
    parser.add_argument(
        "--deployment-broadcast-dir",
        type=Path,
        default=DEFAULT_DEPLOYMENT_BROADCAST_DIR,
    )
    parser.add_argument(
        "--deployment-manifest-dir",
        type=Path,
        default=DEFAULT_DEPLOYMENT_MANIFEST_DIR,
    )
    parser.add_argument("--address-book-dir", type=Path, default=DEFAULT_ADDRESS_BOOK_DIR)
    parser.add_argument("--deployment-schema-dir", type=Path, default=DEFAULT_DEPLOYMENT_SCHEMA_DIR)
    parser.add_argument(
        "--ceremony-evidence-dir",
        type=Path,
        default=DEFAULT_CEREMONY_EVIDENCE_DIR,
    )
    parser.add_argument(
        "--randomizer-operations-dir",
        type=Path,
        default=DEFAULT_RANDOMIZER_OPERATIONS_DIR,
    )
    parser.add_argument(
        "--non-local-evidence-dir",
        type=Path,
        default=DEFAULT_NON_LOCAL_EVIDENCE_DIR,
    )
    parser.add_argument(
        "--drop-authorization-signing-dir",
        type=Path,
        default=DEFAULT_DROP_AUTHORIZATION_SIGNING_DIR,
    )
    parser.add_argument(
        "--signer-custody-readiness-dir",
        type=Path,
        default=DEFAULT_SIGNER_CUSTODY_READINESS_DIR,
    )
    parser.add_argument("--changelog", type=Path, default=DEFAULT_CHANGELOG)
    parser.add_argument("--governance-doc", type=Path, action="append", dest="governance_docs")
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()
    governance_docs = args.governance_docs or DEFAULT_GOVERNANCE_DOCS

    try:
        if args.check:
            return check_output(
                repo_root,
                args.output,
                args.release_artifacts_dir,
                args.baseline,
                args.gas_snapshot,
                args.contract_config,
                args.deployment_config_dir,
                args.deployment_broadcast_dir,
                args.deployment_manifest_dir,
                args.address_book_dir,
                args.deployment_schema_dir,
                args.ceremony_evidence_dir,
                args.randomizer_operations_dir,
                args.changelog,
                governance_docs,
                args.non_local_evidence_dir,
                args.drop_authorization_signing_dir,
                args.signer_custody_readiness_dir,
            )
        written = write_output(
            repo_root,
            args.output,
            args.release_artifacts_dir,
            args.baseline,
            args.gas_snapshot,
            args.contract_config,
            args.deployment_config_dir,
            args.deployment_broadcast_dir,
            args.deployment_manifest_dir,
            args.address_book_dir,
            args.deployment_schema_dir,
            args.ceremony_evidence_dir,
            args.randomizer_operations_dir,
            args.changelog,
            governance_docs,
            args.non_local_evidence_dir,
            args.drop_authorization_signing_dir,
            args.signer_custody_readiness_dir,
        )
    except ReleaseManifestError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(normalize_path(written, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
