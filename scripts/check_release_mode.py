#!/usr/bin/env python3
"""Enforce release-mode evidence gates for public beta and production."""

from __future__ import annotations

import argparse
import sys
from datetime import date
from pathlib import Path
from typing import Any

import check_public_beta_evidence as evidence_checker


DEFAULT_EVIDENCE = evidence_checker.DEFAULT_EVIDENCE
DEFAULT_ABI_CHECKSUMS = Path("release-artifacts/latest/abi-checksums.json")
PUBLIC_BETA_PHASE = evidence_checker.PUBLIC_BETA_PHASE
PRODUCTION_PHASE = evidence_checker.PRODUCTION_PHASE

ABI_CHECKSUMS_SCHEMA = "6529stream.abi-checksums.v1"
STREAM_CORE_NAME = "StreamCore"
STREAM_CORE_SOURCE = "smart-contracts/StreamCore.sol"
EIP170_RUNTIME_LIMIT_BYTES = 24_576
# Governing deployment rule: docs/launch-conformance-matrix.md (Genesis
# Deployment Profile), docs/launch-v1-target-architecture.md (Core Hook Budget),
# and https://github.com/6529-Collections/6529Stream/issues/654.
PRODUCTION_CORE_MIN_RUNTIME_MARGIN_BYTES = 2_000
PRODUCTION_CORE_HEADROOM_TRACKING = (
    "docs/launch-conformance-matrix.md, docs/launch-v1-target-architecture.md, "
    "and issue #654"
)

PHASE_ALIASES = {
    "public-beta": PUBLIC_BETA_PHASE,
    "public_beta": PUBLIC_BETA_PHASE,
    "production-release": PRODUCTION_PHASE,
    "production_release": PRODUCTION_PHASE,
}
PHASE_LABELS = {
    PUBLIC_BETA_PHASE: "public beta",
    PRODUCTION_PHASE: "production",
}
READY_REQUIREMENT_STATUSES = frozenset({"complete", "accepted_risk"})
NON_WAIVABLE_REQUIREMENTS_BY_PHASE = {
    PUBLIC_BETA_PHASE: frozenset({"external_audit_report"}),
    PRODUCTION_PHASE: frozenset(evidence_checker.PRODUCTION_REQUIREMENTS),
}


class ReleaseModeError(RuntimeError):
    """Raised when retained evidence is insufficient for release mode."""


def normalize_phase(value: str) -> str:
    """Normalize CLI phase aliases to manifest phase names."""
    try:
        return PHASE_ALIASES[value]
    except KeyError as exc:
        choices = ", ".join(sorted(PHASE_ALIASES))
        raise ReleaseModeError(f"phase must be one of: {choices}") from exc


def required_phases(phase: str) -> tuple[str, ...]:
    """Return the manifest phases that must be ready for the release phase."""
    if phase == PUBLIC_BETA_PHASE:
        return (PUBLIC_BETA_PHASE,)
    if phase == PRODUCTION_PHASE:
        return (PUBLIC_BETA_PHASE, PRODUCTION_PHASE)
    raise ReleaseModeError(f"unsupported phase: {phase}")


def load_validated_evidence(path: Path, repo_root: Path) -> dict[str, Any]:
    """Load and schema-validate the evidence manifest before release checks."""
    evidence_path = path if path.is_absolute() else repo_root / path
    data = evidence_checker.load_json(evidence_path)
    evidence_checker.validate_evidence_document(data, repo_root, str(evidence_path))
    return data


def require_artifact_int(value: Any, path: str) -> int:
    """Require an integer artifact field without accepting JSON booleans."""
    if isinstance(value, bool) or not isinstance(value, int):
        raise ReleaseModeError(f"{path} must be an integer")
    return value


def production_core_headroom_blocker(path: Path, repo_root: Path) -> str | None:
    """Validate artifact-backed Core size and return a deployment blocker."""
    artifact_path = path if path.is_absolute() else repo_root / path
    data = evidence_checker.load_json(artifact_path)
    artifact_label = str(artifact_path)
    document = evidence_checker.require_dict(data, artifact_label)
    if document.get("schema_version") != ABI_CHECKSUMS_SCHEMA:
        raise ReleaseModeError(
            f"{artifact_label}.schema_version must be {ABI_CHECKSUMS_SCHEMA!r}"
        )

    contracts = evidence_checker.require_dict(
        document.get("contracts"), f"{artifact_label}.contracts"
    )
    core = evidence_checker.require_dict(
        contracts.get(STREAM_CORE_NAME),
        f"{artifact_label}.contracts.{STREAM_CORE_NAME}",
    )
    core_label = f"{artifact_label}.contracts.{STREAM_CORE_NAME}"
    if core.get("source") != STREAM_CORE_SOURCE:
        raise ReleaseModeError(
            f"{core_label}.source must be {STREAM_CORE_SOURCE!r}"
        )

    runtime_size = require_artifact_int(
        core.get("deployed_bytecode_size_bytes"),
        f"{core_label}.deployed_bytecode_size_bytes",
    )
    runtime_limit = require_artifact_int(
        core.get("eip170_runtime_limit_bytes"),
        f"{core_label}.eip170_runtime_limit_bytes",
    )
    runtime_margin = require_artifact_int(
        core.get("deployed_runtime_margin_bytes"),
        f"{core_label}.deployed_runtime_margin_bytes",
    )
    if runtime_size < 0:
        raise ReleaseModeError(
            f"{core_label}.deployed_bytecode_size_bytes must be non-negative"
        )
    if runtime_limit != EIP170_RUNTIME_LIMIT_BYTES:
        raise ReleaseModeError(
            f"{core_label}.eip170_runtime_limit_bytes must be "
            f"{EIP170_RUNTIME_LIMIT_BYTES}"
        )
    expected_margin = runtime_limit - runtime_size
    if runtime_margin != expected_margin:
        raise ReleaseModeError(
            f"{core_label}.deployed_runtime_margin_bytes is {runtime_margin}, "
            f"expected {expected_margin} from the EIP-170 limit and runtime size"
        )
    if runtime_margin < PRODUCTION_CORE_MIN_RUNTIME_MARGIN_BYTES:
        return (
            f"artifact-backed {STREAM_CORE_NAME} EIP-170 runtime margin is "
            f"{runtime_margin} bytes, below the production deployment minimum "
            f"of {PRODUCTION_CORE_MIN_RUNTIME_MARGIN_BYTES} bytes; see "
            f"{PRODUCTION_CORE_HEADROOM_TRACKING}"
        )
    return None


def accepted_risk_blocker(
    requirement: dict[str, Any], as_of: date
) -> str | None:
    """Return a blocker when an accepted-risk row is non-waivable or inactive."""
    requirement_phase = requirement["phase"]
    requirement_id = requirement["id"]
    label = f"{requirement_phase}.{requirement_id}"
    if requirement_id in NON_WAIVABLE_REQUIREMENTS_BY_PHASE[requirement_phase]:
        return f"{label} is non-waivable and must be 'complete', not 'accepted_risk'"

    risk_acceptance = requirement["risk_acceptance"]
    accepted_at = date.fromisoformat(risk_acceptance["accepted_at"])
    expires_at = date.fromisoformat(risk_acceptance["expires_at"])
    if expires_at < accepted_at:
        return (
            f"{label} has an invalid risk-acceptance window: expires_at "
            f"{expires_at.isoformat()!r} precedes accepted_at {accepted_at.isoformat()!r}"
        )
    if accepted_at > as_of:
        return (
            f"{label} risk acceptance is not active until {accepted_at.isoformat()!r}; "
            f"release date is {as_of.isoformat()!r}"
        )
    if expires_at < as_of:
        return (
            f"{label} risk acceptance expired on {expires_at.isoformat()!r}; "
            f"release date is {as_of.isoformat()!r}"
        )
    return None


def release_mode_blockers(
    data: dict[str, Any], phase: str, *, as_of: date | None = None
) -> list[str]:
    """Return human-readable blockers for the requested release mode."""
    # Callers must run validate_evidence_document before using this helper; the
    # direct indexing below depends on that schema and no-secret validation.
    phases = required_phases(phase)
    release_date = date.today() if as_of is None else as_of
    blockers: list[str] = []

    status = data["status"]
    for required_phase in phases:
        if status[required_phase] != "ready":
            blockers.append(
                f"status.{required_phase} is {status[required_phase]!r}, not 'ready'"
            )

    for requirement in data["requirements"]:
        requirement_phase = requirement["phase"]
        if requirement_phase not in phases:
            continue
        requirement_status = requirement["status"]
        if requirement_status == "accepted_risk":
            risk_blocker = accepted_risk_blocker(requirement, release_date)
            if risk_blocker is not None:
                blockers.append(risk_blocker)
            continue
        if requirement_status not in READY_REQUIREMENT_STATUSES:
            blockers.append(
                f"{requirement_phase}.{requirement['id']} is "
                f"{requirement_status!r}, not 'complete' or 'accepted_risk'"
            )

    return blockers


def validate_release_mode(
    path: Path,
    repo_root: Path,
    phase: str,
    *,
    as_of: date | None = None,
    abi_checksums: Path = DEFAULT_ABI_CHECKSUMS,
) -> None:
    """Require retained evidence to satisfy the selected release mode."""
    normalized_phase = normalize_phase(phase)
    data = load_validated_evidence(path, repo_root)
    blockers = release_mode_blockers(data, normalized_phase, as_of=as_of)
    if normalized_phase == PRODUCTION_PHASE:
        headroom_blocker = production_core_headroom_blocker(
            abi_checksums, repo_root
        )
        if headroom_blocker is not None:
            blockers.append(headroom_blocker)
    if blockers:
        label = PHASE_LABELS[normalized_phase]
        details = "\n".join(f"- {blocker}" for blocker in blockers)
        raise ReleaseModeError(f"{label} release mode is blocked:\n{details}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--evidence", type=Path, default=DEFAULT_EVIDENCE)
    parser.add_argument(
        "--abi-checksums",
        type=Path,
        default=DEFAULT_ABI_CHECKSUMS,
        help="Checksum-covered build artifact used for the production Core headroom gate.",
    )
    parser.add_argument(
        "--phase",
        choices=sorted(PHASE_ALIASES),
        default="public-beta",
        help="Release gate to enforce. Production release also requires public-beta readiness.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the checker CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        validate_release_mode(
            args.evidence,
            repo_root,
            args.phase,
            abi_checksums=args.abi_checksums,
        )
    except (evidence_checker.PublicBetaEvidenceError, ReleaseModeError) as exc:
        print(f"release mode check failed: {exc}", file=sys.stderr)
        return 1
    print(f"release mode check passed for {args.phase}: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
