#!/usr/bin/env python3
"""Validate the release risk register."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import sys
from datetime import date
from pathlib import Path
from typing import Any


RISK_REGISTER_SCHEMA = "6529stream.risk-register.v1"
DEFAULT_REGISTER = Path("release-artifacts/latest/risk-register.json")

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "generated_by",
        "maturity",
        "readiness_boundary",
        "source_documents",
        "status_taxonomy",
        "risk_acceptance_policy",
        "risks",
        "redaction_policy",
        "operator_notes",
    }
)
FILE_REF_FIELDS = frozenset({"path", "sha256"})
RISK_FIELDS = frozenset(
    {
        "id",
        "title",
        "area",
        "severity",
        "status",
        "owner",
        "target_gate",
        "source",
        "mitigation",
        "residual_risk",
        "evidence",
        "checks",
        "tracking",
        "risk_acceptance",
    }
)
RISK_ACCEPTANCE_FIELDS = frozenset(
    {"accepted_by", "accepted_at", "expires_at", "reference", "notes"}
)
REDACTION_POLICY_FIELDS = frozenset({"no_secrets", "redacted_fields"})

VALID_AREAS = frozenset(
    {
        "audit",
        "audit_boundary",
        "core_size",
        "external_evidence",
        "governance",
        "metadata_marketplace",
        "one_of_one_product",
        "randomizer_operations",
        "release_integrity",
        "static_analysis",
        "warning_hygiene",
    }
)
REQUIRED_AREAS = VALID_AREAS
VALID_SEVERITIES = frozenset({"critical", "high", "medium", "low", "informational"})
VALID_STATUSES = frozenset(
    {
        "open_blocker",
        "planned_mitigation",
        "mitigated_local",
        "accepted_local_baseline",
        "accepted_risk",
    }
)
VALID_GATES = frozenset({"Gate D", "Gate E", "Gate F", "Gate G"})
REQUIRED_RISK_IDS = frozenset({"RISK-AUD-002"})

RISK_ID_RE = re.compile(r"^RISK-[A-Z0-9]+-\d{3}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
HTTP_URL_RE = re.compile(
    r"^https://github\.com/6529-Collections/6529Stream/(issues|pull)/\d+$"
)
SECRET_KEY_RE = re.compile(
    r"(^|[_\-\s])("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|rpc[_\-\s]?url|"
    r"api[_\-\s]?key|password|bearer[_\-\s]?token|client[_\-\s]?secret|"
    r"session[_\-\s]?cookie|unreleased[_\-\s]?drop[_\-\s]?payload"
    r")([_\-\s]|$)",
    re.IGNORECASE,
)
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|rpc[_ -]?url|api[_ -]?key|"
    r"password|bearer[_ -]?token|client[_ -]?secret|session[_ -]?cookie|"
    r"unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)


class RiskRegisterError(RuntimeError):
    """Raised when the risk register is missing, stale, or unsafe."""


def load_json(path: Path) -> Any:
    """Load JSON with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise RiskRegisterError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RiskRegisterError(f"invalid JSON in {path}: {exc}") from exc


def sha256_bytes(value: bytes) -> str:
    """Return a sha256-prefixed digest."""
    return "sha256:" + hashlib.sha256(value).hexdigest()


def normalized_text_bytes(path: Path) -> bytes:
    """Read a text evidence file with repository-stable line endings."""
    return path.read_bytes().replace(b"\r\n", b"\n")


def file_sha256(path: Path) -> str:
    """Hash a risk-register file reference using repository-stable line endings."""
    return sha256_bytes(normalized_text_bytes(path))


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require an object at a JSON path."""
    if not isinstance(value, dict):
        raise RiskRegisterError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require an object to have exactly the expected keys."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise RiskRegisterError(f"{path} is missing required field(s): {', '.join(missing)}")
    if extra:
        raise RiskRegisterError(f"{path} has unexpected field(s): {', '.join(extra)}")


def require_list(value: Any, path: str) -> list[Any]:
    """Require an array at a JSON path."""
    if not isinstance(value, list):
        raise RiskRegisterError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise RiskRegisterError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean value."""
    if not isinstance(value, bool):
        raise RiskRegisterError(f"{path} must be a boolean")
    return value


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    """Require a string from a fixed enum."""
    text = require_string(value, path)
    if text not in choices:
        raise RiskRegisterError(f"{path} must be one of: {', '.join(sorted(choices))}")
    return text


def require_sha256(value: Any, path: str) -> str:
    """Require a sha256-prefixed digest."""
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise RiskRegisterError(f"{path} must be a sha256: hash")
    return digest


def require_iso_date(value: Any, path: str) -> str:
    """Require an ISO-8601 date string in YYYY-MM-DD form."""
    text = require_string(value, path)
    if not ISO_DATE_RE.fullmatch(text):
        raise RiskRegisterError(f"{path} must be an ISO-8601 date")
    try:
        date.fromisoformat(text)
    except ValueError as exc:
        raise RiskRegisterError(f"{path} must be an ISO-8601 date") from exc
    return text


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    """Resolve a forward-slash repo path and reject traversal."""
    if "\\" in relative_path:
        raise RiskRegisterError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise RiskRegisterError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise RiskRegisterError(f"{path} must stay inside the repository") from exc
    if not resolved.is_file():
        raise RiskRegisterError(f"{path} references missing file: {relative_path}")
    return resolved


def validate_file_ref(value: Any, repo_root: Path, path: str) -> Path:
    """Validate a file reference and its current digest."""
    ref = require_dict(value, path)
    require_exact_keys(ref, path, FILE_REF_FIELDS)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    expected_hash = require_sha256(ref.get("sha256"), f"{path}.sha256")
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    actual_hash = file_sha256(resolved)
    if actual_hash != expected_hash:
        raise RiskRegisterError(
            f"{path}.sha256 mismatch for {relative_path}: "
            f"expected {expected_hash}, got {actual_hash}"
        )
    return resolved


def validate_tracking_ref(value: Any, repo_root: Path, path: str) -> None:
    """Validate a tracking URL or local repo path."""
    ref = require_string(value, path)
    if ref.startswith("https://"):
        if not HTTP_URL_RE.fullmatch(ref):
            raise RiskRegisterError(f"{path} must be a 6529Stream GitHub issue or PR URL")
        return
    local_path = ref.split("#", 1)[0].split("?", 1)[0]
    if not local_path:
        raise RiskRegisterError(f"{path} must not be an empty local reference")
    resolve_repo_file(repo_root, local_path, path)


def validate_check_command(value: Any, repo_root: Path, path: str) -> None:
    """Validate check command strings and script references when present."""
    command = require_string(value, path)
    try:
        tokens = shlex.split(command, posix=True)
    except ValueError as exc:
        raise RiskRegisterError(f"{path} must be a parseable command string") from exc

    if len(tokens) < 2 or tokens[0] != "python":
        return

    script_path = tokens[1].replace("\\", "/")
    if script_path.startswith("scripts/") and script_path.endswith(".py"):
        resolve_repo_file(repo_root, script_path, path)


def validate_no_secret_shape(value: Any, path: str = "$") -> None:
    """Reject secret-shaped keys and assignment-looking values."""
    if path.startswith("$.redaction_policy"):
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if SECRET_KEY_RE.search(str(key)):
                raise RiskRegisterError(f"{path}.{key} uses a secret-shaped key")
            validate_no_secret_shape(item, f"{path}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            validate_no_secret_shape(item, f"{path}[{index}]")
    elif isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise RiskRegisterError(f"{path} contains a secret-shaped assignment")


def validate_redaction_policy(value: Any) -> None:
    """Validate the top-level no-secret posture."""
    policy = require_dict(value, "redaction_policy")
    require_exact_keys(policy, "redaction_policy", REDACTION_POLICY_FIELDS)
    if require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets") is not True:
        raise RiskRegisterError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    if not fields:
        raise RiskRegisterError("redaction_policy.redacted_fields must not be empty")
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def validate_risk_acceptance(value: Any, status: str, path: str) -> None:
    """Validate accepted-risk metadata."""
    if status != "accepted_risk":
        if value is not None:
            raise RiskRegisterError(f"{path} must be null unless status is accepted_risk")
        return

    acceptance = require_dict(value, path)
    require_exact_keys(acceptance, path, RISK_ACCEPTANCE_FIELDS)
    require_string(acceptance.get("accepted_by"), f"{path}.accepted_by")
    require_iso_date(acceptance.get("accepted_at"), f"{path}.accepted_at")
    require_iso_date(acceptance.get("expires_at"), f"{path}.expires_at")
    require_string(acceptance.get("reference"), f"{path}.reference")
    require_string(acceptance.get("notes"), f"{path}.notes")


def validate_risk(value: Any, repo_root: Path, index: int) -> dict[str, str]:
    """Validate one risk row and return its normalized identity fields."""
    path = f"risks[{index}]"
    risk = require_dict(value, path)
    require_exact_keys(risk, path, RISK_FIELDS)

    risk_id = require_string(risk.get("id"), f"{path}.id")
    if not RISK_ID_RE.fullmatch(risk_id):
        raise RiskRegisterError(f"{path}.id must match RISK-AREA-000")
    require_string(risk.get("title"), f"{path}.title")
    area = require_enum(risk.get("area"), f"{path}.area", VALID_AREAS)
    severity = require_enum(risk.get("severity"), f"{path}.severity", VALID_SEVERITIES)
    status = require_enum(risk.get("status"), f"{path}.status", VALID_STATUSES)
    require_string(risk.get("owner"), f"{path}.owner")
    require_enum(risk.get("target_gate"), f"{path}.target_gate", VALID_GATES)
    require_string(risk.get("source"), f"{path}.source")
    require_string(risk.get("mitigation"), f"{path}.mitigation")
    require_string(risk.get("residual_risk"), f"{path}.residual_risk")

    evidence = require_list(risk.get("evidence"), f"{path}.evidence")
    if not evidence:
        raise RiskRegisterError(f"{path}.evidence must not be empty")
    for evidence_index, ref in enumerate(evidence):
        validate_file_ref(ref, repo_root, f"{path}.evidence[{evidence_index}]")

    checks = require_list(risk.get("checks"), f"{path}.checks")
    if not checks:
        raise RiskRegisterError(f"{path}.checks must not be empty")
    for check_index, check in enumerate(checks):
        validate_check_command(check, repo_root, f"{path}.checks[{check_index}]")

    tracking = require_list(risk.get("tracking"), f"{path}.tracking")
    if not tracking:
        raise RiskRegisterError(f"{path}.tracking must not be empty")
    for tracking_index, ref in enumerate(tracking):
        validate_tracking_ref(ref, repo_root, f"{path}.tracking[{tracking_index}]")

    validate_risk_acceptance(risk.get("risk_acceptance"), status, f"{path}.risk_acceptance")
    return {"id": risk_id, "area": area, "severity": severity, "status": status}


def validate_risk_register(repo_root: Path, register_path: Path) -> None:
    """Validate the canonical release risk register."""
    data = require_dict(load_json(register_path), "risk_register")
    require_exact_keys(data, "risk_register", TOP_LEVEL_FIELDS)
    validate_no_secret_shape(data)

    schema = require_string(data.get("schema_version"), "schema_version")
    if schema != RISK_REGISTER_SCHEMA:
        raise RiskRegisterError(f"schema_version must be {RISK_REGISTER_SCHEMA}")
    require_string(data.get("generated_by"), "generated_by")
    require_string(data.get("maturity"), "maturity")
    require_string(data.get("readiness_boundary"), "readiness_boundary")
    require_string(data.get("risk_acceptance_policy"), "risk_acceptance_policy")
    require_string(data.get("operator_notes"), "operator_notes")
    validate_redaction_policy(data.get("redaction_policy"))

    source_documents = require_list(data.get("source_documents"), "source_documents")
    if not source_documents:
        raise RiskRegisterError("source_documents must not be empty")
    for index, ref in enumerate(source_documents):
        validate_file_ref(ref, repo_root, f"source_documents[{index}]")

    taxonomy = require_dict(data.get("status_taxonomy"), "status_taxonomy")
    require_exact_keys(taxonomy, "status_taxonomy", VALID_STATUSES)
    for status in sorted(VALID_STATUSES):
        require_string(taxonomy.get(status), f"status_taxonomy.{status}")

    risks = require_list(data.get("risks"), "risks")
    if not risks:
        raise RiskRegisterError("risks must not be empty")

    seen_ids: set[str] = set()
    areas: set[str] = set()
    ordered_ids: list[str] = []
    for index, risk in enumerate(risks):
        normalized = validate_risk(risk, repo_root, index)
        risk_id = normalized["id"]
        if risk_id in seen_ids:
            raise RiskRegisterError(f"duplicate risk id: {risk_id}")
        seen_ids.add(risk_id)
        ordered_ids.append(risk_id)
        areas.add(normalized["area"])

    if sorted(seen_ids) != ordered_ids:
        raise RiskRegisterError("risks must be sorted by id")

    missing_ids = sorted(REQUIRED_RISK_IDS - seen_ids)
    if missing_ids:
        raise RiskRegisterError(
            "risk register is missing required risk id(s): " + ", ".join(missing_ids)
        )

    missing_areas = sorted(REQUIRED_AREAS - areas)
    if missing_areas:
        raise RiskRegisterError(
            "risk register is missing required area(s): " + ", ".join(missing_areas)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--register", type=Path, default=DEFAULT_REGISTER)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    register_path = args.register
    if not register_path.is_absolute():
        register_path = repo_root / register_path

    try:
        validate_risk_register(repo_root, register_path.resolve())
    except RiskRegisterError as exc:
        print(f"risk register check failed: {exc}", file=sys.stderr)
        return 1

    print("risk register is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
