#!/usr/bin/env python3
"""Validate release evidence tracker issue labels."""

from __future__ import annotations

import argparse
import json
import shlex
import sys
from pathlib import Path
from typing import Any

import check_release_evidence_issue_links as issue_link_checker


DEFAULT_ISSUE_LINKS = Path("release-artifacts/latest/release-evidence-issue-links.json")
DEFAULT_BACKLOG = Path("release-artifacts/latest/release-evidence-issue-backlog.json")
REPO_FULL_NAME = "6529-Collections/6529Stream"


class ReleaseEvidenceIssueLabelsError(RuntimeError):
    """Raised when tracker issue label evidence is incomplete or malformed."""


def load_json(path: Path) -> Any:
    """Load JSON with label-checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueLabelsError(f"missing required file: {path}") from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ReleaseEvidenceIssueLabelsError(f"unable to read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueLabelsError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ReleaseEvidenceIssueLabelsError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceIssueLabelsError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise ReleaseEvidenceIssueLabelsError(f"{path} must be a non-empty string")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer, excluding bool."""
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ReleaseEvidenceIssueLabelsError(f"{path} must be a positive integer")
    return value


def require_string_list(value: Any, path: str) -> list[str]:
    """Require a list of non-empty strings."""
    return [
        require_string(item, f"{path}[{index}]")
        for index, item in enumerate(require_list(value, path))
    ]


def duplicate_values(values: list[str]) -> list[str]:
    """Return duplicate strings while preserving first duplicate order."""
    seen: set[str] = set()
    duplicates: list[str] = []
    for value in values:
        if value in seen and value not in duplicates:
            duplicates.append(value)
        seen.add(value)
    return duplicates


def expected_issue_rows(
    issue_links: dict[str, Any],
    backlog: dict[str, Any],
    repo_root: Path,
    backlog_path: Path,
) -> list[dict[str, Any]]:
    """Return issue rows after validating committed label expectations."""
    try:
        issue_link_checker.validate_links_document(
            issue_links,
            backlog,
            repo_root,
            backlog_path,
        )
    except issue_link_checker.ReleaseEvidenceIssueLinksError as exc:
        raise ReleaseEvidenceIssueLabelsError(str(exc)) from exc

    rows: list[dict[str, Any]] = []
    for index, raw_link in enumerate(require_list(issue_links.get("links"), "links")):
        link = require_dict(raw_link, f"links[{index}]")
        issue_number = require_positive_int(
            link.get("issue_number"),
            f"links[{index}].issue_number",
        )
        title = require_string(link.get("title"), f"links[{index}].title")
        suggested_labels = require_string_list(
            link.get("suggested_labels"),
            f"links[{index}].suggested_labels",
        )
        applied_labels = require_string_list(
            link.get("applied_labels"),
            f"links[{index}].applied_labels",
        )

        duplicates = duplicate_values(applied_labels)
        if duplicates:
            raise ReleaseEvidenceIssueLabelsError(
                f"links[{index}].applied_labels has duplicate labels: "
                + ", ".join(duplicates)
            )

        unknown_labels = sorted(set(applied_labels) - set(suggested_labels))
        if unknown_labels:
            raise ReleaseEvidenceIssueLabelsError(
                f"links[{index}].applied_labels not in suggested_labels: "
                + ", ".join(unknown_labels)
            )

        rows.append(
            {
                "issue_number": issue_number,
                "title": title,
                "applied_labels": applied_labels,
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
            raise ReleaseEvidenceIssueLabelsError(
                f"duplicate issue in snapshot: {issue_number}"
            )
        issues[issue_number] = issue
    return issues


def label_names(raw_labels: Any, path: str) -> set[str]:
    """Return label names from GitHub JSON label objects or strings."""
    names: set[str] = set()
    for index, raw_label in enumerate(require_list(raw_labels, path)):
        if isinstance(raw_label, str):
            name = require_string(raw_label, f"{path}[{index}]")
        else:
            label = require_dict(raw_label, f"{path}[{index}]")
            name = require_string(label.get("name"), f"{path}[{index}].name")
        names.add(name)
    return names


def sync_command(issue_number: int, missing_labels: list[str]) -> str:
    """Return a deterministic GitHub CLI command for missing labels."""
    label_args = " ".join(
        f"--add-label {shlex.quote(label)}" for label in missing_labels
    )
    return f"gh issue edit {issue_number} --repo {REPO_FULL_NAME} {label_args}"


def validate_snapshot_labels(rows: list[dict[str, Any]], snapshot: Any) -> None:
    """Validate expected applied labels against a GitHub issue JSON snapshot."""
    issues = snapshot_issues_by_number(snapshot)
    errors: list[str] = []

    for row in rows:
        issue_number = row["issue_number"]
        expected_title = row["title"]
        expected_labels = list(row["applied_labels"])
        issue = issues.get(issue_number)
        if issue is None:
            errors.append(f"issue #{issue_number} is missing from snapshot")
            continue

        actual_title = require_string(issue.get("title"), f"issue #{issue_number}.title")
        if actual_title != expected_title:
            errors.append(
                f"issue #{issue_number} title mismatch: expected "
                f"{expected_title!r}, got {actual_title!r}"
            )

        actual_labels = label_names(issue.get("labels"), f"issue #{issue_number}.labels")
        missing_labels = [label for label in expected_labels if label not in actual_labels]
        if missing_labels:
            errors.append(
                f"issue #{issue_number} missing applied labels: "
                + ", ".join(missing_labels)
                + f"; remediation: {sync_command(issue_number, missing_labels)}"
            )

    if errors:
        raise ReleaseEvidenceIssueLabelsError("; ".join(errors))


def validate_files(
    repo_root: Path,
    issue_links_path: Path,
    backlog_path: Path,
    snapshot_path: Path | None = None,
) -> None:
    """Validate committed labels and optional live/snapshot issue labels."""
    issue_links = require_dict(load_json(issue_links_path), "issue_links")
    backlog = require_dict(load_json(backlog_path), "backlog")
    rows = expected_issue_rows(issue_links, backlog, repo_root, backlog_path)

    if snapshot_path is not None:
        validate_snapshot_labels(rows, load_json(snapshot_path))


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Validate release evidence tracker issue labels"
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--issue-links", type=Path, default=DEFAULT_ISSUE_LINKS)
    parser.add_argument("--backlog", type=Path, default=DEFAULT_BACKLOG)
    parser.add_argument(
        "--live-json",
        type=Path,
        default=None,
        help=(
            "Optional GitHub issue JSON snapshot from "
            "`gh issue list --json number,title,labels`."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the release evidence issue label checker."""
    parser = build_parser()
    args = parser.parse_args(argv)

    repo_root = args.repo_root.resolve()
    issue_links_path = issue_link_checker.resolve_repo_path(repo_root, args.issue_links)
    backlog_path = issue_link_checker.resolve_repo_path(repo_root, args.backlog)
    snapshot_path = (
        issue_link_checker.resolve_repo_path(repo_root, args.live_json)
        if args.live_json is not None
        else None
    )

    try:
        validate_files(repo_root, issue_links_path, backlog_path, snapshot_path)
    except ReleaseEvidenceIssueLabelsError as exc:
        print(f"release evidence issue label check failed: {exc}", file=sys.stderr)
        return 1

    print("release evidence issue labels are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
