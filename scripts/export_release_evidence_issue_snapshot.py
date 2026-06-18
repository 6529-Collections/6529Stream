#!/usr/bin/env python3
"""Export live GitHub issue snapshots for release evidence tracker audits."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from argparse_helpers import positive_int
import fetch_release_evidence_issue_snapshot as linked_issue_fetcher


REPO_FULL_NAME = "6529-Collections/6529Stream"
DEFAULT_ISSUE_LINKS = Path("release-artifacts/latest/release-evidence-issue-links.json")

PROFILE_FIELDS = {
    "labels": ("number", "title", "labels"),
    "bodies": ("number", "title", "body"),
    "closure": ("number", "title", "state"),
    "all": ("number", "title", "state", "labels", "body"),
}

PROFILE_STATES = {
    "labels": "open",
    "bodies": "open",
    "closure": "all",
    "all": "all",
}

PROFILE_OUTPUTS = {
    "labels": Path("tmp/release-evidence-issue-labels.json"),
    "bodies": Path("tmp/release-evidence-issue-bodies.json"),
    "closure": Path("tmp/release-evidence-issue-closure.json"),
    "all": Path("tmp/release-evidence-issues.json"),
}


class ReleaseEvidenceIssueSnapshotError(RuntimeError):
    """Raised when a live issue snapshot cannot be exported."""


def require_issue_list(value: Any) -> list[dict[str, Any]]:
    """Require a GitHub issue-list JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceIssueSnapshotError("gh issue list output must be a JSON array")
    rows: list[dict[str, Any]] = []
    for index, row in enumerate(value):
        if not isinstance(row, dict):
            raise ReleaseEvidenceIssueSnapshotError(
                f"gh issue list row {index} must be an object"
            )
        rows.append(row)
    return rows


def snapshot_text(rows: list[dict[str, Any]]) -> str:
    """Return deterministic UTF-8 JSON text for a snapshot."""
    return json.dumps(rows, indent=2, ensure_ascii=False) + "\n"


def gh_issue_list_args(
    repo: str,
    state: str,
    limit: int,
    fields: tuple[str, ...],
) -> list[str]:
    """Build the GitHub CLI argument list for the snapshot."""
    return [
        "issue",
        "list",
        "--repo",
        repo,
        "--state",
        state,
        "--limit",
        str(limit),
        "--json",
        ",".join(fields),
    ]


def resolve_gh_command(gh: str) -> list[str]:
    """Resolve gh, including Windows command shims."""
    resolved = shutil.which(gh) or gh
    suffix = Path(resolved).suffix.lower()
    if suffix in {".bat", ".cmd"}:
        return ["cmd.exe", "/c", resolved]
    return [resolved]


def run_gh_issue_list(
    gh: str,
    repo: str,
    state: str,
    limit: int,
    fields: tuple[str, ...],
) -> list[dict[str, Any]]:
    """Run gh issue list and return parsed JSON rows."""
    args = gh_issue_list_args(repo, state, limit, fields)
    command = [*resolve_gh_command(gh), *args]
    try:
        result = subprocess.run(
            command,
            check=False,
            encoding="utf-8",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueSnapshotError(
            f"GitHub CLI executable was not found: {gh}"
        ) from exc

    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh {' '.join(args)} failed: {message}"
        )

    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh issue list returned invalid JSON: {exc}"
        ) from exc
    return require_issue_list(parsed)


def run_gh_issue_view(
    gh: str,
    repo: str,
    issue_number: int,
    fields: tuple[str, ...],
) -> dict[str, Any]:
    """Run gh issue view for one linked tracker issue."""
    args = [
        "issue",
        "view",
        str(issue_number),
        "--repo",
        repo,
        "--json",
        ",".join(fields),
    ]
    command = [*resolve_gh_command(gh), *args]
    try:
        result = subprocess.run(
            command,
            check=False,
            encoding="utf-8",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueSnapshotError(
            f"GitHub CLI executable was not found: {gh}"
        ) from exc

    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh {' '.join(args)} failed: {message}"
        )

    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh issue view returned invalid JSON for #{issue_number}: {exc}"
        ) from exc
    if not isinstance(parsed, dict):
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh issue view output for #{issue_number} must be a JSON object"
        )
    actual_number = parsed.get("number")
    if actual_number != issue_number:
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh returned issue #{actual_number} while fetching #{issue_number}"
        )
    return parsed


def run_linked_issue_views(
    *,
    gh: str,
    repo: str,
    repo_root: Path,
    issue_links: Path,
    fields: tuple[str, ...],
) -> list[dict[str, Any]]:
    """Fetch the exact linked tracker issues for one audit profile."""
    issue_links_path = (
        issue_links if issue_links.is_absolute() else repo_root / issue_links
    )
    try:
        issue_numbers = linked_issue_fetcher.load_issue_numbers(issue_links_path)
    except linked_issue_fetcher.ReleaseEvidenceIssueSnapshotError as exc:
        raise ReleaseEvidenceIssueSnapshotError(str(exc)) from exc
    return [
        run_gh_issue_view(gh, repo, issue_number, fields)
        for issue_number in issue_numbers
    ]


def write_snapshot(path: Path | None, rows: list[dict[str, Any]]) -> None:
    """Write a snapshot as UTF-8 without a BOM, or stdout when path is None."""
    text = snapshot_text(rows)
    if path is None:
        sys.stdout.write(text)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--profile",
        choices=sorted(PROFILE_FIELDS),
        default="labels",
        help="Snapshot profile matching the existing live audit checkers.",
    )
    parser.add_argument("--repo", default=REPO_FULL_NAME)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--issue-links",
        type=Path,
        default=DEFAULT_ISSUE_LINKS,
        help=(
            "Release-evidence issue-link artifact used with "
            "--exact-linked-issues."
        ),
    )
    parser.add_argument(
        "--exact-linked-issues",
        action="store_true",
        help=(
            "Fetch every linked tracker issue with gh issue view instead of "
            "using a paginated gh issue list result. This mode intentionally "
            "ignores --state and --limit."
        ),
    )
    parser.add_argument(
        "--state",
        choices=("open", "closed", "all"),
        help=(
            "Override the profile's default issue state for list-based exports. "
            "Ignored with --exact-linked-issues."
        ),
    )
    parser.add_argument(
        "--limit",
        type=positive_int,
        default=100,
        help=(
            "Maximum issue list rows for list-based exports. Ignored with "
            "--exact-linked-issues."
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output path. Defaults to the profile-specific tmp snapshot path.",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Write the JSON snapshot to stdout instead of a file.",
    )
    parser.add_argument(
        "--gh",
        default="gh",
        help="GitHub CLI executable to run. Defaults to gh.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the snapshot exporter."""
    parser = build_parser()
    args = parser.parse_args(argv)

    fields = PROFILE_FIELDS[args.profile]
    state = args.state or PROFILE_STATES[args.profile]
    output = None if args.stdout else (args.output or PROFILE_OUTPUTS[args.profile])

    try:
        if args.exact_linked_issues:
            rows = run_linked_issue_views(
                gh=args.gh,
                repo=args.repo,
                repo_root=args.repo_root.resolve(),
                issue_links=args.issue_links,
                fields=fields,
            )
        else:
            rows = run_gh_issue_list(args.gh, args.repo, state, args.limit, fields)
        write_snapshot(output, rows)
    except ReleaseEvidenceIssueSnapshotError as exc:
        print(f"release evidence issue snapshot export failed: {exc}", file=sys.stderr)
        return 1

    if output is not None:
        print(output.as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
