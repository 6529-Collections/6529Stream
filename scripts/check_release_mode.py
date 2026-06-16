#!/usr/bin/env python3
"""Enforce release-mode evidence gates for public beta and production."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import check_public_beta_evidence as evidence_checker


DEFAULT_EVIDENCE = evidence_checker.DEFAULT_EVIDENCE
PUBLIC_BETA_PHASE = evidence_checker.PUBLIC_BETA_PHASE
PRODUCTION_PHASE = evidence_checker.PRODUCTION_PHASE

PHASE_ALIASES = {
    "public-beta": PUBLIC_BETA_PHASE,
    "public_beta": PUBLIC_BETA_PHASE,
    "production-release": PRODUCTION_PHASE,
    "production_release": PRODUCTION_PHASE,
}
PHASE_LABELS = {
    PUBLIC_BETA_PHASE: "public beta",
    PRODUCTION_PHASE: "production release",
}
READY_REQUIREMENT_STATUSES = frozenset({"complete", "accepted_risk"})


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


def release_mode_blockers(data: dict[str, Any], phase: str) -> list[str]:
    """Return human-readable blockers for the requested release mode."""
    # Callers must run validate_evidence_document before using this helper; the
    # direct indexing below depends on that schema and no-secret validation.
    phases = required_phases(phase)
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
        if requirement_status not in READY_REQUIREMENT_STATUSES:
            blockers.append(
                f"{requirement_phase}.{requirement['id']} is "
                f"{requirement_status!r}, not 'complete' or 'accepted_risk'"
            )

    return blockers


def validate_release_mode(path: Path, repo_root: Path, phase: str) -> None:
    """Require retained evidence to satisfy the selected release mode."""
    normalized_phase = normalize_phase(phase)
    data = load_validated_evidence(path, repo_root)
    blockers = release_mode_blockers(data, normalized_phase)
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
        validate_release_mode(args.evidence, repo_root, args.phase)
    except (evidence_checker.PublicBetaEvidenceError, ReleaseModeError) as exc:
        print(f"release mode check failed: {exc}", file=sys.stderr)
        return 1
    print(f"release mode check passed for {args.phase}: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
