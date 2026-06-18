#!/usr/bin/env python3
"""Fetch a live GitHub snapshot for linked release evidence tracker issues."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, Sequence


SNAPSHOT_SCHEMA = "6529stream.release-evidence-live-issue-snapshot.v1"
SCRIPT_NAME = Path(__file__).name
DEFAULT_ISSUE_LINKS = Path("release-artifacts/latest/release-evidence-issue-links.json")
DEFAULT_OUTPUT = Path("tmp/release-evidence-live-issues.json")
DEFAULT_REPO = "6529-Collections/6529Stream"
GH_FIELDS = ("number", "title", "state", "body", "url", "closed", "closedAt")


class ReleaseEvidenceIssueSnapshotError(RuntimeError):
    """Raised when live issue snapshot generation fails."""


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    """Resolve a path relative to the repository root."""
    return path if path.is_absolute() else repo_root / path


def normalize_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path when possible."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def load_json(path: Path) -> Any:
    """Load JSON with snapshot-fetcher-specific errors."""
    try:
        with path.open("r", encoding="utf-8-sig") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueSnapshotError(f"missing required file: {path}") from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ReleaseEvidenceIssueSnapshotError(f"unable to read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueSnapshotError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ReleaseEvidenceIssueSnapshotError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceIssueSnapshotError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise ReleaseEvidenceIssueSnapshotError(f"{path} must be a non-empty string")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer, excluding bool."""
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ReleaseEvidenceIssueSnapshotError(f"{path} must be a positive integer")
    return value


def deterministic_json(value: Any) -> str:
    """Return deterministic JSON text with a trailing newline."""
    return json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n"


def load_issue_numbers(issue_links_path: Path) -> list[int]:
    """Load linked tracker issue numbers in deterministic order."""
    issue_links = require_dict(load_json(issue_links_path), "issue_links")
    numbers: list[int] = []
    seen: set[int] = set()
    for index, raw_link in enumerate(require_list(issue_links.get("links"), "links")):
        link = require_dict(raw_link, f"links[{index}]")
        number = require_positive_int(link.get("issue_number"), f"links[{index}].issue_number")
        if number in seen:
            raise ReleaseEvidenceIssueSnapshotError(
                f"duplicate issue_number in issue links: {number}"
            )
        seen.add(number)
        numbers.append(number)
    return numbers


def normalize_issue(raw_issue: Any, issue_number: int) -> dict[str, Any]:
    """Validate and normalize one GitHub issue payload."""
    issue = require_dict(raw_issue, f"issue #{issue_number}")
    actual_number = require_positive_int(issue.get("number"), f"issue #{issue_number}.number")
    if actual_number != issue_number:
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh returned issue #{actual_number} while fetching #{issue_number}"
        )

    normalized: dict[str, Any] = {
        "number": actual_number,
        "title": require_string(issue.get("title"), f"issue #{issue_number}.title"),
        "state": require_string(issue.get("state"), f"issue #{issue_number}.state"),
        "body": require_string(issue.get("body"), f"issue #{issue_number}.body"),
        "url": require_string(issue.get("url"), f"issue #{issue_number}.url"),
    }
    if "closed" in issue:
        normalized["closed"] = bool(issue["closed"])
    if issue.get("closedAt") is not None:
        normalized["closedAt"] = require_string(
            issue.get("closedAt"),
            f"issue #{issue_number}.closedAt",
        )
    else:
        normalized["closedAt"] = None
    return normalized


RunCommand = Callable[[Sequence[str], int], subprocess.CompletedProcess[str]]


def default_run_command(
    command: Sequence[str],
    timeout_seconds: int,
) -> subprocess.CompletedProcess[str]:
    """Run a GitHub CLI command and capture text output."""
    try:
        return subprocess.run(
            command,
            check=False,
            capture_output=True,
            encoding="utf-8",
            timeout=timeout_seconds,
        )
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueSnapshotError(
            f"unable to execute {command[0]!r}; install GitHub CLI or pass --gh"
        ) from exc
    except subprocess.TimeoutExpired as exc:
        raise ReleaseEvidenceIssueSnapshotError(
            f"GitHub CLI command timed out while fetching issue snapshot: {' '.join(command)}"
        ) from exc


def fetch_issue(
    *,
    gh: str,
    repo: str,
    issue_number: int,
    timeout_seconds: int,
    run_command: RunCommand = default_run_command,
) -> dict[str, Any]:
    """Fetch one GitHub issue through gh issue view."""
    fields = ",".join(GH_FIELDS)
    command = [
        gh,
        "issue",
        "view",
        str(issue_number),
        "--repo",
        repo,
        "--json",
        fields,
    ]
    result = run_command(command, timeout_seconds)
    if result.returncode != 0:
        stderr = (result.stderr or result.stdout or "").strip()
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh issue view failed for #{issue_number}: {stderr or 'unknown error'}"
        )
    try:
        issue = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueSnapshotError(
            f"gh issue view returned invalid JSON for #{issue_number}: {exc}"
        ) from exc
    return normalize_issue(issue, issue_number)


def build_snapshot(
    *,
    repo_root: Path,
    issue_links_path: Path,
    repo: str,
    gh: str,
    timeout_seconds: int,
    run_command: RunCommand = default_run_command,
) -> dict[str, Any]:
    """Build a live issue snapshot for every linked release evidence tracker."""
    issue_numbers = load_issue_numbers(issue_links_path)
    issues = [
        fetch_issue(
            gh=gh,
            repo=repo,
            issue_number=issue_number,
            timeout_seconds=timeout_seconds,
            run_command=run_command,
        )
        for issue_number in issue_numbers
    ]
    return {
        "schema_version": SNAPSHOT_SCHEMA,
        "generated_by": f"scripts/{SCRIPT_NAME}:1",
        "repo": repo,
        "source": {
            "issue_links": normalize_path(issue_links_path, repo_root),
            "issue_count": len(issue_numbers),
        },
        "issues": issues,
    }


def write_snapshot(path: Path, snapshot: dict[str, Any]) -> None:
    """Write a deterministic snapshot file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(deterministic_json(snapshot), encoding="utf-8", newline="\n")


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Fetch live GitHub release evidence tracker issue JSON"
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--issue-links", type=Path, default=DEFAULT_ISSUE_LINKS)
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--gh", default="gh")
    parser.add_argument("--timeout-seconds", type=int, default=30)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser


def main(argv: list[str] | None = None) -> int:
    """Fetch and write a live release evidence issue snapshot."""
    args = build_parser().parse_args(argv)
    repo_root = args.repo_root.resolve()
    issue_links_path = resolve_repo_path(repo_root, args.issue_links)
    output_path = resolve_repo_path(repo_root, args.output)

    try:
        snapshot = build_snapshot(
            repo_root=repo_root,
            issue_links_path=issue_links_path,
            repo=require_string(args.repo, "--repo"),
            gh=require_string(args.gh, "--gh"),
            timeout_seconds=require_positive_int(
                args.timeout_seconds,
                "--timeout-seconds",
            ),
            run_command=default_run_command,
        )
        write_snapshot(output_path, snapshot)
    except ReleaseEvidenceIssueSnapshotError as exc:
        print(f"release evidence issue snapshot fetch failed: {exc}", file=sys.stderr)
        return 1

    print(
        "wrote release evidence issue snapshot: "
        f"{normalize_path(output_path, repo_root)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
