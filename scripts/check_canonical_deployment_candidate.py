#!/usr/bin/env python3
"""Validate the preparatory canonical deployment candidate v2 identity model.

Version 2 extends the issue #677 canonical-deployment-candidate family. It does
not define a parallel deployment plan, receipt, or retained-evidence schema.
The checked planning candidate remains incomplete until the serialized source,
source-layout, catalog, build, deployment, and review dependencies are merged.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import materialize_canonical_deployment_plan as materializer


CANDIDATE_SCHEMA_VERSION = "6529stream.canonical-deployment-candidate.v2"
PROFILE_SCHEMA_VERSION = "6529stream.genesis-deployment-profile.v2"
PROFILE_ENTRY_COUNT = 37
DEFAULT_CANDIDATE = Path(
    "deployments/config/canonical-deployment-candidate-v2-planning.json"
)
DEFAULT_SCHEMA = Path(
    "deployments/schema/canonical-deployment-candidate.v2.schema.json"
)
DEFAULT_PROFILE = Path("release-artifacts/genesis-deployment-profile.json")
DEFAULT_RISK_REGISTER = Path("release-artifacts/latest/risk-register.json")
GOVERNANCE_RISK_ID = "RISK-GOV-003"
GOVERNANCE_RISK_REQUIRED = {
    "severity": "high",
    "status": "open_blocker",
    "risk_acceptance": None,
}
FORBIDDEN_RAW_CANDIDATE_KEYS = frozenset(
    {
        "candidate_sha256",
        "candidate_artifact_sha256",
        "raw_candidate_sha256",
    }
)


class CandidateError(RuntimeError):
    """Raised when a candidate is malformed or violates an identity boundary."""


@dataclass(frozen=True)
class CandidateAudit:
    candidate_id: str
    candidate_identity_sha256: str
    candidate_identity_keccak256: str
    raw_candidate_sha256: str
    profile_entry_count: int
    instance_count: int
    linked_library_count: int
    blockers: tuple[str, ...]


def _load_object(path: Path, label: str) -> tuple[dict[str, Any], str]:
    try:
        value, digest = materializer.load_json_with_sha256(path)
    except materializer.DeploymentPlanError as exc:
        raise CandidateError(str(exc)) from exc
    if not isinstance(value, dict):
        raise CandidateError(f"{label} root must be an object")
    return value, digest


def _resolve(repo_root: Path, relative: str | Path, label: str) -> Path:
    try:
        return materializer.normalize_repo_path(
            repo_root.resolve(),
            Path(relative),
            label,
        )
    except materializer.DeploymentPlanError as exc:
        raise CandidateError(str(exc)) from exc


def _validate_schema(
    repo_root: Path,
    schema_path: Path,
    candidate: dict[str, Any],
) -> None:
    try:
        materializer.validate_draft_2020_12_schema(
            repo_root,
            schema_path,
            candidate,
            "canonical deployment candidate v2",
        )
    except materializer.DeploymentPlanError as exc:
        raise CandidateError(str(exc)) from exc


def _jcs_quote(value: str, path: str) -> str:
    for character in value:
        if 0xD800 <= ord(character) <= 0xDFFF:
            raise CandidateError(f"{path} contains a lone UTF-16 surrogate")
    if unicodedata.normalize("NFC", value) != value:
        raise CandidateError(f"{path} is not NFC-normalized")
    try:
        value.encode("utf-8", "strict")
    except UnicodeEncodeError as exc:
        raise CandidateError(f"{path} is not valid Unicode: {exc}") from exc

    escaped: list[str] = ['"']
    short = {
        0x08: "\\b",
        0x09: "\\t",
        0x0A: "\\n",
        0x0C: "\\f",
        0x0D: "\\r",
    }
    for character in value:
        point = ord(character)
        if character == '"':
            escaped.append('\\"')
        elif character == "\\":
            escaped.append("\\\\")
        elif point in short:
            escaped.append(short[point])
        elif point <= 0x1F:
            escaped.append(f"\\u{point:04x}")
        else:
            escaped.append(character)
    escaped.append('"')
    return "".join(escaped)


def _utf16_sort_key(value: str) -> bytes:
    _jcs_quote(value, "object member name")
    return value.encode("utf-16-be")


def _jcs_bytes(value: Any, path: str = "$") -> bytes:
    def encode(item: Any, item_path: str) -> str:
        if item is None:
            return "null"
        if isinstance(item, bool):
            return "true" if item else "false"
        if isinstance(item, int):
            if abs(item) > materializer.IJSON_SAFE_INTEGER_MAX:
                raise CandidateError(
                    f"{item_path} is outside the I-JSON safe-integer range"
                )
            return str(item)
        if isinstance(item, str):
            return _jcs_quote(item, item_path)
        if isinstance(item, list):
            return "[" + ",".join(
                encode(child, f"{item_path}[{index}]")
                for index, child in enumerate(item)
            ) + "]"
        if isinstance(item, dict):
            for key in item:
                if not isinstance(key, str):
                    raise CandidateError(
                        f"{item_path} contains a non-string object name"
                    )
            names = sorted(item, key=_utf16_sort_key)
            return "{" + ",".join(
                _jcs_quote(name, f"{item_path} member name")
                + ":"
                + encode(item[name], f"{item_path}.{name}")
                for name in names
            ) + "}"
        raise CandidateError(
            f"{item_path} has unsupported JSON type {type(item).__name__}"
        )

    return encode(value, path).encode("utf-8")


def candidate_identity(candidate: dict[str, Any]) -> tuple[str, str]:
    """Return the cycle-free identity excluding only retained_evidence."""
    if "retained_evidence" not in candidate:
        raise CandidateError("candidate.retained_evidence is required")
    projection = {
        key: value
        for key, value in candidate.items()
        if key != "retained_evidence"
    }
    encoded = _jcs_bytes(projection, "candidate identity")
    try:
        keccak256 = materializer.keccak256_hex(encoded)
    except materializer.DeploymentPlanError as exc:
        raise CandidateError(str(exc)) from exc
    return "sha256:" + hashlib.sha256(encoded).hexdigest(), keccak256


def _validate_governance_risk(repo_root: Path, risk_path: Path) -> None:
    resolved = _resolve(repo_root, risk_path, "risk register")
    register, _ = _load_object(resolved, "risk register")
    risks = register.get("risks")
    if not isinstance(risks, list):
        raise CandidateError("risk register risks must be an array")
    matches = [
        risk
        for risk in risks
        if isinstance(risk, dict) and risk.get("id") == GOVERNANCE_RISK_ID
    ]
    if len(matches) != 1:
        raise CandidateError(
            f"risk register must contain exactly one {GOVERNANCE_RISK_ID} row"
        )
    risk = matches[0]
    for key, expected in GOVERNANCE_RISK_REQUIRED.items():
        if risk.get(key) != expected:
            raise CandidateError(
                f"{GOVERNANCE_RISK_ID}.{key} must remain {expected!r}"
            )


def _release_build_identity(candidate: dict[str, Any]) -> dict[str, Any]:
    release_build = candidate["release_build"]
    return {
        "receipt_sha256": release_build["receipt_sha256"],
        "target_catalog_sha256": release_build["target_catalog_sha256"],
        "config_sha256": release_build["config_sha256"],
        "foundry_config_sha256": release_build["foundry_config_sha256"],
    }


def _reject_raw_candidate_digest(
    value: Any,
    raw_candidate_sha256: str,
    path: str,
) -> None:
    raw_hex = raw_candidate_sha256.removeprefix("sha256:")
    if isinstance(value, str):
        if raw_candidate_sha256 in value or raw_hex in value:
            raise CandidateError(
                f"{path} must not contain the raw candidate artifact SHA-256"
            )
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _reject_raw_candidate_digest(
                item,
                raw_candidate_sha256,
                f"{path}[{index}]",
            )
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if key in FORBIDDEN_RAW_CANDIDATE_KEYS:
                raise CandidateError(
                    f"{path}.{key} is a forbidden raw-candidate digest field"
                )
            _reject_raw_candidate_digest(
                item,
                raw_candidate_sha256,
                f"{path}.{key}",
            )


def _validate_retained_evidence(
    repo_root: Path,
    candidate: dict[str, Any],
    *,
    candidate_identity_sha256: str,
    candidate_identity_keccak256: str,
    raw_candidate_sha256: str,
) -> None:
    binding = candidate["retained_evidence"]
    if binding["status"] != "bound":
        return
    if not all(
        isinstance(binding[key], str)
        for key in ("schema_version", "path", "sha256")
    ):
        raise CandidateError(
            "bound retained_evidence requires schema_version, path, and sha256"
        )
    evidence_path = _resolve(
        repo_root,
        binding["path"],
        "canonical retained evidence",
    )
    if not evidence_path.is_file():
        raise CandidateError(
            f"canonical retained evidence does not exist: {binding['path']}"
        )
    evidence, evidence_sha256 = _load_object(
        evidence_path,
        "canonical retained evidence",
    )
    if binding["sha256"] != evidence_sha256:
        raise CandidateError(
            "candidate.retained_evidence SHA-256 does not match retained bytes"
        )
    if evidence.get("schema_version") != binding["schema_version"]:
        raise CandidateError(
            "candidate.retained_evidence schema_version does not match envelope"
        )
    _reject_raw_candidate_digest(
        evidence,
        raw_candidate_sha256,
        "retained_evidence",
    )
    expected_identity = {
        "candidate_id": candidate["candidate_id"],
        "candidate_identity_sha256": candidate_identity_sha256,
        "candidate_identity_keccak256": candidate_identity_keccak256,
        "source_commit": candidate["source_commit"],
        "release_build": _release_build_identity(candidate),
    }
    if evidence.get("candidate_identity") != expected_identity:
        raise CandidateError(
            "retained evidence candidate_identity does not match candidate"
        )


def _implementation_blockers(
    instance: dict[str, Any],
    profile_entry: dict[str, Any],
) -> list[str]:
    blockers: list[str] = []
    label = (
        f"profile entry {profile_entry['id']} "
        f"({profile_entry['key']})"
    )
    if instance["profile_entry_key"] != profile_entry["key"]:
        blockers.append(f"{label} profile_entry_key mismatch")
    if instance["deployment_scope"] != profile_entry["deployment_scope"]:
        blockers.append(f"{label} deployment_scope mismatch")

    mode = profile_entry["implementation"]["mode"]
    allowed_names = profile_entry["implementation"]["names"]
    approved_aliases = profile_entry["approved_aliases"]
    match = instance["implementation_match"]
    name = instance["target"]["name"]
    if match == "approved_alias":
        if name not in approved_aliases:
            blockers.append(f"{label} uses an unapproved implementation alias")
    else:
        if match != mode:
            blockers.append(
                f"{label} implementation_match must be {mode!r}, got {match!r}"
            )
        if allowed_names and name not in allowed_names:
            blockers.append(
                f"{label} target {name!r} is not an approved implementation"
            )

    expected_interfaces = set(profile_entry["required_interfaces"])
    actual_interfaces = set(instance["verified_interfaces"])
    if actual_interfaces != expected_interfaces:
        blockers.append(f"{label} verified interface set mismatch")
    expected_markers = set(profile_entry["required_markers"])
    actual_markers = set(instance["verified_markers"])
    if actual_markers != expected_markers:
        blockers.append(f"{label} verified marker set mismatch")
    return blockers


def _instance_blockers(
    candidate: dict[str, Any],
    profile: dict[str, Any],
) -> list[str]:
    blockers: list[str] = []
    instances = candidate["instances"]
    instance_ids = [instance["instance_id"] for instance in instances]
    if len(instance_ids) != len(set(instance_ids)):
        blockers.append("candidate instance IDs are duplicated")
    addresses = [instance["address"] for instance in instances]
    if len(addresses) != len(set(addresses)):
        blockers.append("candidate instance addresses are duplicated")

    by_profile_id: dict[int, list[dict[str, Any]]] = {}
    for index, instance in enumerate(instances):
        if instance["order"] != index + 1:
            blockers.append(
                f"candidate.instances[{index}].order must equal {index + 1}"
            )
        profile_id = instance["profile_entry_id"]
        by_profile_id.setdefault(profile_id, []).append(instance)
        if len(instance["constructor"]["types"]) != len(
            instance["constructor"]["arguments"]
        ):
            blockers.append(
                f"candidate instance {instance['instance_id']} constructor "
                "type/argument cardinality mismatch"
            )
        if instance["on_chain"]["status"] != "observed":
            blockers.append(
                f"candidate instance {instance['instance_id']} lacks on-chain evidence"
            )
        else:
            if (
                instance["on_chain"]["initcode_keccak256"]
                != instance["expected_initcode_keccak256"]
            ):
                blockers.append(
                    (
                        f"candidate instance {instance['instance_id']} "
                        "initcode hash mismatch"
                    )
                )
            if (
                instance["on_chain"]["runtime_code_keccak256"]
                != instance["runtime"]["expected_keccak256"]
            ):
                blockers.append(
                    (
                        f"candidate instance {instance['instance_id']} "
                        "runtime hash mismatch"
                    )
                )
            if instance["on_chain"]["source_verification_status"] != "verified":
                blockers.append(
                    (
                        f"candidate instance {instance['instance_id']} "
                        "is not source verified"
                    )
                )
        if instance["review_status"] != "reviewed":
            blockers.append(
                f"candidate instance {instance['instance_id']} is not reviewed"
            )

    profile_entries = profile["entries"]
    profile_ids = {entry["id"] for entry in profile_entries}
    for profile_id in sorted(set(by_profile_id) - profile_ids):
        blockers.append(f"candidate has extra profile entry id {profile_id}")
    for entry in profile_entries:
        matches = by_profile_id.get(entry["id"], [])
        if not matches:
            blockers.append(
                f"profile entry {entry['id']} ({entry['key']}) is missing a "
                "concrete candidate instance"
            )
            continue
        if len(matches) > 1:
            blockers.append(f"duplicate profile entry id {entry['id']}")
            continue
        blockers.extend(_implementation_blockers(matches[0], entry))

    one_by_profile_id = {
        profile_id: matches[0]
        for profile_id, matches in by_profile_id.items()
        if len(matches) == 1
    }
    for entry in profile_entries:
        instance = one_by_profile_id.get(entry["id"])
        if instance is None:
            continue
        for other_id in entry["distinct_from"]:
            other = one_by_profile_id.get(other_id)
            if other is not None and instance["address"] == other["address"]:
                blockers.append(
                    f"profile entry {entry['id']} ({entry['key']}) aliases "
                    f"distinct profile entry {other_id}"
                )

    seen_instances: set[str] = set()
    for instance in instances:
        for dependency in instance["depends_on"]:
            if dependency not in seen_instances:
                blockers.append(
                    f"candidate instance {instance['instance_id']} dependency "
                    f"{dependency} is missing or not earlier"
                )
        seen_instances.add(instance["instance_id"])

    return blockers


def _library_blockers(candidate: dict[str, Any]) -> list[str]:
    blockers: list[str] = []
    libraries = candidate["linked_libraries"]
    library_ids = [library["library_id"] for library in libraries]
    if len(library_ids) != len(set(library_ids)):
        blockers.append("linked-library IDs are duplicated")
    addresses = [library["address"] for library in libraries]
    if len(addresses) != len(set(addresses)):
        blockers.append("linked-library addresses are duplicated")
    inventory = {library["library_id"]: library for library in libraries}
    used: set[str] = set()
    seen: set[str] = set()
    for index, library in enumerate(libraries):
        if library["order"] != index + 1:
            blockers.append(
                f"linked_libraries[{index}].order must equal {index + 1}"
            )
        for dependency in library["depends_on"]:
            if dependency not in seen:
                blockers.append(
                    f"linked library {library['library_id']} dependency "
                    f"{dependency} is missing or not earlier"
                )
        seen.add(library["library_id"])
        if library["on_chain"]["status"] != "observed":
            blockers.append(
                f"linked library {library['library_id']} lacks on-chain evidence"
            )
        else:
            if (
                library["on_chain"]["initcode_keccak256"]
                != library["expected_initcode_keccak256"]
            ):
                blockers.append(
                    f"linked library {library['library_id']} initcode hash mismatch"
                )
            if (
                library["on_chain"]["runtime_code_keccak256"]
                != library["runtime"]["expected_keccak256"]
            ):
                blockers.append(
                    f"linked library {library['library_id']} runtime hash mismatch"
                )
        if library["review_status"] != "reviewed":
            blockers.append(f"linked library {library['library_id']} is not reviewed")

    consumers = [*libraries, *candidate["instances"]]
    for consumer in consumers:
        consumer_id = consumer.get("instance_id", consumer.get("library_id"))
        for reference in consumer["linked_libraries"]:
            library_id = reference["library_id"]
            linked = inventory.get(library_id)
            if linked is None:
                blockers.append(
                    f"{consumer_id} references missing linked library {library_id}"
                )
                continue
            used.add(library_id)
            expected = {
                "library_id": linked["library_id"],
                "source": linked["target"]["source"],
                "name": linked["target"]["name"],
                "address": linked["address"],
            }
            if reference != expected:
                blockers.append(
                    f"{consumer_id} linked-library reference {library_id} "
                    "does not match the closed inventory"
                )
    unreferenced = set(inventory) - used
    if unreferenced:
        blockers.append(
            "linked-library inventory contains unreferenced entries: "
            + ", ".join(sorted(unreferenced))
        )
    return blockers


def _binding_blockers(candidate: dict[str, Any]) -> list[str]:
    blockers: list[str] = []
    instances = {
        instance["instance_id"]: instance for instance in candidate["instances"]
    }
    libraries = {
        library["library_id"]: library
        for library in candidate["linked_libraries"]
    }
    for instance in candidate["instances"]:
        semantic_keys: set[tuple[str, str]] = set()
        for binding in instance["authority_dependency_bindings"]:
            semantic_key = (binding["kind"], binding["name"])
            if semantic_key in semantic_keys:
                blockers.append(
                    f"candidate instance {instance['instance_id']} has duplicate "
                    f"binding {binding['kind']}:{binding['name']}"
                )
            semantic_keys.add(semantic_key)
            if binding["target_kind"] == "candidate_instance":
                target = instances.get(binding["target_id"])
                if target is None or target["address"] != binding["address"]:
                    blockers.append(
                        f"candidate instance {instance['instance_id']} binding "
                        f"{binding['name']} does not match its candidate target"
                    )
            elif binding["target_kind"] == "linked_library":
                target = libraries.get(binding["target_id"])
                if target is None or target["address"] != binding["address"]:
                    blockers.append(
                        f"candidate instance {instance['instance_id']} binding "
                        f"{binding['name']} does not match its library target"
                    )
    return blockers


def _top_level_blockers(candidate: dict[str, Any]) -> list[str]:
    blockers: list[str] = []
    if candidate["status"] != "complete":
        blockers.append("candidate status is planning")
    if candidate["production_candidate"] is not True:
        blockers.append("candidate is not frozen as a production candidate")
    if candidate["source_commit"] is None:
        blockers.append("candidate source commit is not frozen")

    source_layout = candidate["source_layout"]
    if source_layout["status"] != "complete" or not all(
        source_layout[key] is not None
        for key in ("manifest_path", "manifest_sha256")
    ):
        blockers.append("source layout remains pending issue #716")

    profile_binding = candidate["genesis_profile"]
    if (
        profile_binding["status"] != "complete"
        or profile_binding["sha256"] is None
    ):
        blockers.append("genesis profile identity is not frozen")

    for key in ("governed_parameter_inventory", "record_family_authorization"):
        binding = candidate[key]
        if binding["status"] != "complete" or binding["identity_sha256"] is None:
            blockers.append(f"{key} identity remains a serialized dependency")

    release_build = candidate["release_build"]
    if release_build["status"] != "complete" or any(
        release_build[key] is None
        for key in (
            "receipt_sha256",
            "target_catalog_sha256",
            "config_sha256",
            "foundry_config_sha256",
        )
    ):
        blockers.append("canonical release build identity is not complete")

    retained = candidate["retained_evidence"]
    if retained["status"] != "bound" or any(
        retained[key] is None for key in ("schema_version", "path", "sha256")
    ):
        blockers.append("canonical retained evidence is not bound")
    return blockers


def audit_candidate(
    repo_root: Path,
    candidate_path: Path = DEFAULT_CANDIDATE,
    schema_path: Path = DEFAULT_SCHEMA,
    profile_path: Path = DEFAULT_PROFILE,
    risk_path: Path = DEFAULT_RISK_REGISTER,
) -> CandidateAudit:
    root = repo_root.resolve(strict=True)
    _validate_governance_risk(root, risk_path)
    resolved_candidate = _resolve(root, candidate_path, "candidate")
    candidate, raw_candidate_sha256 = _load_object(
        resolved_candidate,
        "canonical deployment candidate v2",
    )
    _validate_schema(root, schema_path, candidate)

    if candidate["schema_version"] != CANDIDATE_SCHEMA_VERSION:
        raise CandidateError(
            f"candidate schema_version must be {CANDIDATE_SCHEMA_VERSION}"
        )
    resolved_profile = _resolve(root, profile_path, "genesis profile")
    profile, profile_sha256 = _load_object(resolved_profile, "genesis profile")
    if profile.get("schema_version") != PROFILE_SCHEMA_VERSION:
        raise CandidateError(
            f"genesis profile schema_version must be {PROFILE_SCHEMA_VERSION}"
        )
    entries = profile.get("entries")
    if not isinstance(entries, list) or len(entries) != PROFILE_ENTRY_COUNT:
        raise CandidateError(
            f"genesis profile must contain exactly {PROFILE_ENTRY_COUNT} entries"
        )
    profile_binding = candidate["genesis_profile"]
    if profile_binding["path"] != profile_path.as_posix():
        raise CandidateError("candidate genesis-profile path is noncanonical")
    if (
        profile_binding["sha256"] is not None
        and profile_binding["sha256"] != profile_sha256
    ):
        raise CandidateError("candidate genesis-profile SHA-256 mismatch")
    if profile_binding["entry_count"] != len(entries):
        raise CandidateError("candidate genesis-profile entry count mismatch")
    if candidate["factory_spawned_exclusions"] != profile[
        "factory_spawned_exclusions"
    ]:
        raise CandidateError(
            "candidate factory-spawned exclusions must exactly match the profile"
        )
    if candidate["out_of_inventory"] != profile["out_of_inventory"]:
        raise CandidateError(
            "candidate out-of-inventory rows must exactly match the profile"
        )

    identity_sha256, identity_keccak256 = candidate_identity(candidate)
    _validate_retained_evidence(
        root,
        candidate,
        candidate_identity_sha256=identity_sha256,
        candidate_identity_keccak256=identity_keccak256,
        raw_candidate_sha256=raw_candidate_sha256,
    )

    blockers = _top_level_blockers(candidate)
    blockers.extend(_instance_blockers(candidate, profile))
    blockers.extend(_library_blockers(candidate))
    blockers.extend(_binding_blockers(candidate))
    return CandidateAudit(
        candidate_id=candidate["candidate_id"],
        candidate_identity_sha256=identity_sha256,
        candidate_identity_keccak256=identity_keccak256,
        raw_candidate_sha256=raw_candidate_sha256,
        profile_entry_count=len(entries),
        instance_count=len(candidate["instances"]),
        linked_library_count=len(candidate["linked_libraries"]),
        blockers=tuple(blockers),
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--candidate", type=Path, default=DEFAULT_CANDIDATE)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    parser.add_argument("--risk-register", type=Path, default=DEFAULT_RISK_REGISTER)
    parser.add_argument("--require-complete", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        audit = audit_candidate(
            args.repo_root,
            candidate_path=args.candidate,
            schema_path=args.schema,
            profile_path=args.profile,
            risk_path=args.risk_register,
        )
    except CandidateError as exc:
        print(f"canonical deployment candidate v2 check failed: {exc}", file=sys.stderr)
        return 1
    if args.require_complete and audit.blockers:
        print(
            "canonical deployment candidate v2 is incomplete:\n- "
            + "\n- ".join(audit.blockers),
            file=sys.stderr,
        )
        return 1
    print(
        "canonical deployment candidate v2 is structurally valid: "
        f"profile_entries={audit.profile_entry_count}; "
        f"instances={audit.instance_count}; "
        f"linked_libraries={audit.linked_library_count}; "
        f"blockers={len(audit.blockers)}; "
        f"candidate_identity_sha256={audit.candidate_identity_sha256}; "
        f"candidate_identity_keccak256={audit.candidate_identity_keccak256}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
