#!/usr/bin/env python3
"""Run live release evidence issue snapshot audits."""

from __future__ import annotations

import argparse
import hashlib
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Iterable

from argparse_helpers import positive_int


REPO_FULL_NAME = "6529-Collections/6529Stream"
DEFAULT_PROFILES = ("labels", "bodies", "closure")
REPORT_SCHEMA_VERSION = "6529stream.release-evidence-live-audit-report.v1"
NO_SECRET_NOTICE = (
    "This report records no-secret live issue audit evidence only. It must not "
    "include private keys, RPC credentials, access tokens, unreleased signer "
    "material, or secret operational metadata."
)
READINESS_WARNING = (
    "The report does not mark public-beta or production-release retained "
    "evidence complete and does not change the blocked readiness posture."
)
STALE_SNAPSHOT_POLICY = (
    "Retained reports are historical snapshots; reviewers must regenerate from "
    "live GitHub issue exports during the release ceremony before treating "
    "issue labels, bodies, or closure status as current."
)
LIVE_EXPORT_FRESHNESS_STATUS = "live_export_at_generation"
RETAINED_HISTORICAL_FRESHNESS_STATUS = "retained_historical"
LIVE_EXPORT_CURRENTNESS_CLAIM = "current_at_generation_only"
RETAINED_CURRENTNESS_CLAIM = "not_current"

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


def sha256_file(path: Path) -> str:
    """Return the SHA-256 digest for a retained evidence file."""
    if not path.is_file():
        raise ReleaseEvidenceIssueSnapshotAuditError(
            f"snapshot output is missing: {path.as_posix()}"
        )
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


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
    collect_report: bool = False,
) -> dict[str, object] | None:
    """Export and check one live issue snapshot profile."""
    output = snapshot_path(tmp_dir, profile)
    export_command = exporter_command(python, profile, repo, limit, gh, output)
    check_command = checker_command(python, profile, output)
    run_checked(export_command, f"{profile} snapshot export")
    run_checked(check_command, f"{profile} snapshot check")
    print(f"{profile} live audit passed: {output.as_posix()}")
    if not collect_report:
        return None
    return {
        "profile": profile,
        "snapshot_path": output.as_posix(),
        "snapshot_sha256": sha256_file(output),
        "export_command": command_text(export_command),
        "checker_command": command_text(check_command),
        "export_status": "passed",
        "checker_status": "passed",
    }


def build_report(
    repo: str,
    generated_at: str,
    profile_results: list[dict[str, object]],
) -> dict[str, object]:
    """Build a deterministic no-secret live audit report document."""
    return {
        "schema_version": REPORT_SCHEMA_VERSION,
        "repo": repo,
        "generated_at": generated_at,
        "readiness_claim": "blocked",
        "no_secret_notice": NO_SECRET_NOTICE,
        "readiness_warning": READINESS_WARNING,
        "snapshot_freshness": {
            "status": LIVE_EXPORT_FRESHNESS_STATUS,
            "generated_from_live_export": True,
            "currentness_claim": LIVE_EXPORT_CURRENTNESS_CLAIM,
            "stale_snapshot_policy": STALE_SNAPSHOT_POLICY,
            "profile_generated_at": {
                str(profile["profile"]): generated_at for profile in profile_results
            },
        },
        "profiles": profile_results,
        "validation": {
            "status": "passed",
            "profile_count": len(profile_results),
        },
    }


def write_report_json(path: Path, report: dict[str, object]) -> None:
    """Write a deterministic JSON live audit report."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def markdown_cell(value: object) -> str:
    """Escape a value for use inside a compact Markdown table cell."""
    return str(value).replace("|", "\\|").replace("\n", " ")


def markdown_report(report: dict[str, object]) -> str:
    """Render a deterministic Markdown live audit report."""
    freshness = report["snapshot_freshness"]
    assert isinstance(freshness, dict)
    profile_generated_at = freshness["profile_generated_at"]
    assert isinstance(profile_generated_at, dict)
    lines = [
        "# Release Evidence Live Audit Report",
        "",
        f"- Schema: `{report['schema_version']}`",
        f"- Repository: `{report['repo']}`",
        f"- Generated at: `{report['generated_at']}`",
        f"- Readiness claim: `{report['readiness_claim']}`",
        f"- Snapshot freshness: `{freshness['status']}`",
        (
            "- Generated from live export: "
            f"`{str(freshness['generated_from_live_export']).lower()}`"
        ),
        f"- Currentness claim: `{freshness['currentness_claim']}`",
        f"- Stale snapshot policy: {freshness['stale_snapshot_policy']}",
        f"- Notice: {report['no_secret_notice']}",
        f"- Warning: {report['readiness_warning']}",
        "",
        (
            "| Profile | Snapshot | Snapshot generated at | SHA-256 | "
            "Export status | Checker status |"
        ),
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for profile in report["profiles"]:
        assert isinstance(profile, dict)
        profile_name = str(profile["profile"])
        lines.append(
            "| "
            + " | ".join(
                [
                    markdown_cell(profile_name),
                    markdown_cell(profile["snapshot_path"]),
                    markdown_cell(profile_generated_at[profile_name]),
                    markdown_cell(profile["snapshot_sha256"]),
                    markdown_cell(profile["export_status"]),
                    markdown_cell(profile["checker_status"]),
                ]
            )
            + " |"
        )
    lines.extend(
        [
            "",
            "## Command Provenance",
            "",
        ]
    )
    for profile in report["profiles"]:
        assert isinstance(profile, dict)
        lines.extend(
            [
                f"### {profile['profile']}",
                "",
                "```bash",
                str(profile["export_command"]),
                str(profile["checker_command"]),
                "```",
                "",
            ]
        )
    return "\n".join(lines).rstrip() + "\n"


def write_report_markdown(path: Path, report: dict[str, object]) -> None:
    """Write a deterministic Markdown live audit report."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(markdown_report(report), encoding="utf-8", newline="\n")


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
    parser.add_argument(
        "--report-json",
        type=Path,
        help="Optional path for a no-secret deterministic JSON audit report.",
    )
    parser.add_argument(
        "--report-md",
        type=Path,
        help="Optional path for a no-secret deterministic Markdown audit report.",
    )
    parser.add_argument(
        "--generated-at",
        default="TBD",
        help=(
            "Report generation timestamp or evidence run ID. Defaults to TBD "
            "so test reports remain deterministic unless supplied by an operator."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the selected live issue snapshot audits."""
    parser = build_parser()
    args = parser.parse_args(argv)
    collect_report = args.report_json is not None or args.report_md is not None
    profile_results: list[dict[str, object]] = []

    try:
        for profile in expand_profiles(args.profile):
            profile_result = audit_profile(
                args.python,
                profile,
                args.repo,
                args.limit,
                args.gh,
                args.tmp_dir,
                collect_report=collect_report,
            )
            if profile_result is not None:
                profile_results.append(profile_result)
        if collect_report:
            report = build_report(args.repo, args.generated_at, profile_results)
            if args.report_json is not None:
                write_report_json(args.report_json, report)
            if args.report_md is not None:
                write_report_markdown(args.report_md, report)
    except ReleaseEvidenceIssueSnapshotAuditError as exc:
        print(f"release evidence issue snapshot audit failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
