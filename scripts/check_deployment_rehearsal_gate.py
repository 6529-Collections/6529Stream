#!/usr/bin/env python3
"""Validate deployment rehearsal gate parity across local and CI entrypoints."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


REHEARSAL_COMMANDS = [
    (
        "aggregate suite",
        'forge script script/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir',
    ),
    (
        "standalone deployment",
        'forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir',
    ),
    (
        "standalone auction ceremony",
        'forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir',
    ),
    (
        "standalone emergency redeployment",
        'forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir',
    ),
]

CI_REHEARSAL_LOGS = [
    ("aggregate suite", "ci-logs/forge-deployment-suite-rehearsal.log"),
    ("standalone deployment", "ci-logs/forge-deployment-rehearsal.log"),
    ("standalone auction ceremony", "ci-logs/forge-auction-ceremony-rehearsal.log"),
    ("standalone emergency redeployment", "ci-logs/forge-emergency-redeployment-rehearsal.log"),
]

GATE_FILES = [
    Path("Makefile"),
    Path("scripts/check.sh"),
    Path("scripts/check.ps1"),
    Path(".github/workflows/ci.yml"),
]

MAKE_TARGETS = [
    "deploy-rehearsal:",
    "deploy-rehearsal-standalone:",
]


class DeploymentRehearsalGateError(ValueError):
    """Raised when rehearsal gate wiring drifts."""


def _repo_relative(path: Path, repo_root: Path) -> str:
    """Return a stable repository-relative POSIX path for errors."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def _read_required(repo_root: Path, relative_path: Path) -> str:
    """Read a required gate file or fail closed."""
    path = repo_root / relative_path
    if not path.is_file():
        raise DeploymentRehearsalGateError(f"missing required gate file: {relative_path}")
    return path.read_text(encoding="utf-8")


def _require_ordered_entries(
    *,
    text: str,
    entries: list[tuple[str, str]],
    path: Path,
    repo_root: Path,
    entry_kind: str = "deployment rehearsal commands",
) -> None:
    """Require every entry to appear in order."""
    previous_index = -1
    missing = []
    out_of_order = []
    for label, needle in entries:
        indexes = []
        start = 0
        while True:
            index = text.find(needle, start)
            if index == -1:
                break
            indexes.append(index)
            start = index + len(needle)

        if not indexes:
            missing.append(f"{label}: {needle}")
            continue

        ordered_index = next((index for index in indexes if index > previous_index), None)
        if ordered_index is None:
            out_of_order.append(label)
            continue
        previous_index = ordered_index

    if missing:
        raise DeploymentRehearsalGateError(
            f"{_repo_relative(path, repo_root)} is missing required "
            f"{entry_kind}: " + "; ".join(missing)
        )
    if out_of_order:
        raise DeploymentRehearsalGateError(
            f"{_repo_relative(path, repo_root)} has required {entry_kind} "
            f"out of order: " + ", ".join(out_of_order)
        )


def _validate_makefile(repo_root: Path, text: str) -> None:
    """Validate Makefile targets and rehearsal commands."""
    missing_targets = [target for target in MAKE_TARGETS if target not in text]
    if missing_targets:
        raise DeploymentRehearsalGateError(
            "Makefile is missing deployment rehearsal targets: " + ", ".join(missing_targets)
        )
    _require_ordered_entries(
        text=text,
        entries=REHEARSAL_COMMANDS,
        path=repo_root / "Makefile",
        repo_root=repo_root,
    )


def _validate_ci(repo_root: Path, text: str) -> None:
    """Validate CI commands and distinct retained log names."""
    ci_path = repo_root / ".github/workflows/ci.yml"
    _require_ordered_entries(
        text=text,
        entries=REHEARSAL_COMMANDS,
        path=ci_path,
        repo_root=repo_root,
    )
    _require_ordered_entries(
        text=text,
        entries=CI_REHEARSAL_LOGS,
        path=ci_path,
        repo_root=repo_root,
        entry_kind="CI rehearsal logs",
    )

    log_values = [log for _, log in CI_REHEARSAL_LOGS]
    if len(set(log_values)) != len(log_values):
        raise DeploymentRehearsalGateError("CI rehearsal log names must be distinct")


def validate_deployment_rehearsal_gate(repo_root: Path) -> None:
    """Validate deployment rehearsal gate parity across all local and CI files."""
    texts = {relative: _read_required(repo_root, relative) for relative in GATE_FILES}

    _validate_makefile(repo_root, texts[Path("Makefile")])

    for relative in [Path("scripts/check.sh"), Path("scripts/check.ps1")]:
        _require_ordered_entries(
            text=texts[relative],
            entries=REHEARSAL_COMMANDS,
            path=repo_root / relative,
            repo_root=repo_root,
        )

    _validate_ci(repo_root, texts[Path(".github/workflows/ci.yml")])


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse checker command-line options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the deployment rehearsal gate checker."""
    args = parse_args(argv or [])
    try:
        validate_deployment_rehearsal_gate(args.repo_root.resolve())
    except DeploymentRehearsalGateError as exc:
        print(f"deployment rehearsal gate check failed: {exc}", file=sys.stderr)
        return 1

    print("deployment rehearsal gate parity is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
