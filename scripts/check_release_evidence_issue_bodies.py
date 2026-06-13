#!/usr/bin/env python3
"""Validate release evidence tracker issue bodies."""

from __future__ import annotations

import argparse
import json
import shlex
import sys
from pathlib import Path
from typing import Any

import generate_release_evidence_issue_body_sync as body_sync_generator


DEFAULT_BODY_SYNC = Path("release-artifacts/latest/release-evidence-issue-body-sync.json")
DEFAULT_REMEDIATION_DIR = Path("tmp/release-evidence-issue-bodies")
REPO_FULL_NAME = "6529-Collections/6529Stream"


class ReleaseEvidenceIssueBodiesError(RuntimeError):
    """Raised when tracker issue body evidence is incomplete or malformed."""


def load_json(path: Path) -> Any:
    """Load JSON with body-checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueBodiesError(f"missing required file: {path}") from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ReleaseEvidenceIssueBodiesError(f"unable to read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueBodiesError(f"invalid JSON in {path}: {exc}") from exc


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    """Resolve a path relative to the repository root."""
    return path if path.is_absolute() else repo_root / path


def normalize_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path when possible."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ReleaseEvidenceIssueBodiesError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceIssueBodiesError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise ReleaseEvidenceIssueBodiesError(f"{path} must be a non-empty string")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer, excluding bool."""
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ReleaseEvidenceIssueBodiesError(f"{path} must be a positive integer")
    return value


def canonical_issue_body(body: str) -> str:
    """Normalize platform newline differences while preserving content drift."""
    normalized = body.replace("\r\n", "\n").replace("\r", "\n")
    return normalized.rstrip("\n") + "\n"


def expected_issue_rows(body_sync: dict[str, Any]) -> list[dict[str, Any]]:
    """Return expected issue body rows from a committed body-sync document."""
    try:
        body_sync_generator.validate_body_sync_document(body_sync)
    except body_sync_generator.ReleaseEvidenceIssueBodySyncError as exc:
        raise ReleaseEvidenceIssueBodiesError(str(exc)) from exc

    rows: list[dict[str, Any]] = []
    for index, raw_issue in enumerate(require_list(body_sync.get("issues"), "issues")):
        issue = require_dict(raw_issue, f"issues[{index}]")
        expected_body = canonical_issue_body(
            require_string(issue.get("expected_body"), f"issues[{index}].expected_body")
        )
        issue_number = require_positive_int(
            issue.get("issue_number"),
            f"issues[{index}].issue_number",
        )
        rows.append(
            {
                "entry_id": require_string(
                    issue.get("entry_id"),
                    f"issues[{index}].entry_id",
                ),
                "issue_number": issue_number,
                "title": require_string(issue.get("title"), f"issues[{index}].title"),
                "expected_body": expected_body,
                "body_sha256": body_sync_generator.sha256_text(expected_body),
            }
        )
    return rows


def snapshot_issues_by_number(snapshot: Any) -> dict[int, dict[str, Any]]:
    """Normalize GitHub issue JSON into a mapping keyed by issue number."""
    if isinstance(snapshot, dict) and "issues" in snapshot:
        raw_issues = require_list(snapshot.get("issues"), "snapshot.issues")
    else:
        raw_issues = require_list(snapshot, "snapshot")

    issues: dict[int, dict[str, Any]] = {}
    for index, raw_issue in enumerate(raw_issues):
        issue = require_dict(raw_issue, f"snapshot[{index}]")
        issue_number = require_positive_int(
            issue.get("number"),
            f"snapshot[{index}].number",
        )
        if issue_number in issues:
            raise ReleaseEvidenceIssueBodiesError(
                f"duplicate issue in snapshot: {issue_number}"
            )
        issues[issue_number] = issue
    return issues


def body_file_path(output_dir: Path, issue_number: int) -> Path:
    """Return the deterministic body-file path for an issue number."""
    return output_dir / f"issue-{issue_number}.md"


def remediation_command(issue_number: int) -> str:
    """Return deterministic commands for restoring one tracker issue body."""
    output_dir = DEFAULT_REMEDIATION_DIR.as_posix()
    body_file = body_file_path(DEFAULT_REMEDIATION_DIR, issue_number).as_posix()
    write_command = (
        "python scripts/check_release_evidence_issue_bodies.py "
        f"--write-body-files {shlex.quote(output_dir)}"
    )
    edit_command = (
        f"gh issue edit {issue_number} --repo {REPO_FULL_NAME} "
        f"--body-file {shlex.quote(body_file)}"
    )
    return f"{write_command} && {edit_command}"


def validate_snapshot_bodies(rows: list[dict[str, Any]], snapshot: Any) -> None:
    """Validate expected issue bodies against a GitHub issue JSON snapshot."""
    issues = snapshot_issues_by_number(snapshot)
    errors: list[str] = []

    for row in rows:
        issue_number = row["issue_number"]
        issue = issues.get(issue_number)
        if issue is None:
            errors.append(f"issue #{issue_number} is missing from snapshot")
            continue

        actual_title = require_string(issue.get("title"), f"issue #{issue_number}.title")
        if actual_title != row["title"]:
            errors.append(
                f"issue #{issue_number} title mismatch: expected "
                f"{row['title']!r}, got {actual_title!r}"
            )

        raw_body = require_string(issue.get("body"), f"issue #{issue_number}.body")
        actual_body = canonical_issue_body(raw_body)
        if actual_body != row["expected_body"]:
            actual_sha = body_sync_generator.sha256_text(actual_body)
            errors.append(
                f"issue #{issue_number} body drift for {row['entry_id']}: expected "
                f"{row['body_sha256']}, got {actual_sha}; remediation: "
                f"{remediation_command(issue_number)}"
            )

        raw_state = issue.get("state")
        if raw_state is not None:
            state = require_string(raw_state, f"issue #{issue_number}.state")
            if state.lower() not in {"open", "opened"}:
                errors.append(f"issue #{issue_number} is not open: {state!r}")

    if errors:
        raise ReleaseEvidenceIssueBodiesError("; ".join(errors))


def write_expected_body_files(
    rows: list[dict[str, Any]],
    output_dir: Path,
    repo_root: Path,
) -> None:
    """Write one deterministic body file per expected tracker issue."""
    output_dir.mkdir(parents=True, exist_ok=True)
    for row in rows:
        issue_number = row["issue_number"]
        path = body_file_path(output_dir, issue_number)
        path.write_text(row["expected_body"], encoding="utf-8", newline="\n")
    print(
        "wrote release evidence issue body files to "
        f"{normalize_path(output_dir, repo_root)}"
    )


def validate_files(
    repo_root: Path,
    body_sync_path: Path,
    snapshot_path: Path | None = None,
    body_files_dir: Path | None = None,
) -> None:
    """Validate committed bodies and optional live/snapshot issue bodies."""
    body_sync = require_dict(load_json(body_sync_path), "body_sync")
    rows = expected_issue_rows(body_sync)

    if body_files_dir is not None:
        write_expected_body_files(rows, body_files_dir, repo_root)

    if snapshot_path is not None:
        validate_snapshot_bodies(rows, load_json(snapshot_path))


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Validate release evidence tracker issue bodies"
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--body-sync", type=Path, default=DEFAULT_BODY_SYNC)
    parser.add_argument(
        "--live-json",
        type=Path,
        default=None,
        help=(
            "Optional GitHub issue JSON snapshot from "
            "`gh issue list --json number,title,body,state`."
        ),
    )
    parser.add_argument(
        "--write-body-files",
        type=Path,
        default=None,
        help=(
            "Optional directory for deterministic per-issue body files that can "
            "be passed to `gh issue edit --body-file`."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the release evidence issue body checker."""
    parser = build_parser()
    args = parser.parse_args(argv)

    repo_root = args.repo_root.resolve()
    body_sync_path = resolve_repo_path(repo_root, args.body_sync)
    snapshot_path = (
        resolve_repo_path(repo_root, args.live_json)
        if args.live_json is not None
        else None
    )
    body_files_dir = (
        resolve_repo_path(repo_root, args.write_body_files)
        if args.write_body_files is not None
        else None
    )

    try:
        validate_files(repo_root, body_sync_path, snapshot_path, body_files_dir)
    except ReleaseEvidenceIssueBodiesError as exc:
        print(f"release evidence issue body check failed: {exc}", file=sys.stderr)
        return 1

    print("release evidence issue bodies are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
