#!/usr/bin/env python3
"""Run live release evidence issue snapshot audits."""

from __future__ import annotations

import argparse
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Iterable


REPO_FULL_NAME = "6529-Collections/6529Stream"
DEFAULT_PROFILES = ("labels", "bodies", "closure")

PROFILE_CONFIG = {
    "labels": {
        "output": "release-evidence-issue-labels.json",
        "checker": "check_release_evidence_issue_labels.py",
    },
    "bodies": {
        "output": "release-evidence-issue-bodies.json",
        "checker": "check_release_evidence_issue_bodies.py",
    },
    "closure": {
        "output": "release-evidence-issue-closure.json",
        "checker": "check_release_evidence_issue_closure.py",
    },
}


class ReleaseEvidenceIssueSnapshotAuditError(RuntimeError):
    """Raised when a live issue snapshot audit command fails."""


def positive_int(value: str) -> int:
    """Parse a positive integer for argparse."""
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a positive integer") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return parsed


def expand_profiles(profiles: Iterable[str] | None) -> list[str]:
    """Expand profile selections, treating all as labels, bodies, and closure."""
    selected = list(profiles or ("all",))
    expanded: list[str] = []
    for profile in selected:
        profile_names = DEFAULT_PROFILES if profile == "all" else (profile,)
        for profile_name in profile_names:
            if profile_name not in expanded:
                expanded.append(profile_name)
    return expanded


def command_text(command: list[str]) -> str:
    """Return a shell-readable command for error messages."""
    return shlex.join(command)


def run_checked(command: list[str], label: str) -> None:
    """Run one audit command and fail with context on non-zero exit."""
    result = subprocess.run(command, check=False)
    if result.returncode != 0:
        raise ReleaseEvidenceIssueSnapshotAuditError(
            f"{label} failed with exit {result.returncode}: {command_text(command)}"
        )


def script_path(name: str) -> Path:
    """Return the path to a sibling script."""
    return Path(__file__).resolve().with_name(name)


def snapshot_path(tmp_dir: Path, profile: str) -> Path:
    """Return the snapshot output path for a live audit profile."""
    return tmp_dir / PROFILE_CONFIG[profile]["output"]


def exporter_command(
    python: str,
    profile: str,
    repo: str,
    limit: int,
    gh: str,
    output: Path,
) -> list[str]:
    """Build the exporter command for one profile."""
    return [
        python,
        str(script_path("export_release_evidence_issue_snapshot.py")),
        "--profile",
        profile,
        "--repo",
        repo,
        "--limit",
        str(limit),
        "--output",
        output.as_posix(),
        "--gh",
        gh,
    ]


def checker_command(python: str, profile: str, output: Path) -> list[str]:
    """Build the checker command for one profile."""
    return [
        python,
        str(script_path(PROFILE_CONFIG[profile]["checker"])),
        "--live-json",
        output.as_posix(),
    ]


def audit_profile(
    python: str,
    profile: str,
    repo: str,
    limit: int,
    gh: str,
    tmp_dir: Path,
) -> None:
    """Export and check one live issue snapshot profile."""
    output = snapshot_path(tmp_dir, profile)
    run_checked(
        exporter_command(python, profile, repo, limit, gh, output),
        f"{profile} snapshot export",
    )
    run_checked(
        checker_command(python, profile, output),
        f"{profile} snapshot check",
    )
    print(f"{profile} live audit passed: {output.as_posix()}")


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--profile",
        action="append",
        choices=("all", *DEFAULT_PROFILES),
        help=(
            "Audit profile to run. May be supplied multiple times. "
            "Defaults to all live audit profiles."
        ),
    )
    parser.add_argument("--repo", default=REPO_FULL_NAME)
    parser.add_argument("--limit", type=positive_int, default=100)
    parser.add_argument("--tmp-dir", type=Path, default=Path("tmp"))
    parser.add_argument(
        "--python",
        default=sys.executable,
        help="Python executable used to run sibling scripts.",
    )
    parser.add_argument(
        "--gh",
        default="gh",
        help="GitHub CLI executable passed through to the exporter.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the selected live issue snapshot audits."""
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        for profile in expand_profiles(args.profile):
            audit_profile(
                args.python,
                profile,
                args.repo,
                args.limit,
                args.gh,
                args.tmp_dir,
            )
    except ReleaseEvidenceIssueSnapshotAuditError as exc:
        print(f"release evidence issue snapshot audit failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
