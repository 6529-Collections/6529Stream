#!/usr/bin/env python3
"""Validate release evidence backlog-to-issue links."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import check_public_beta_evidence as evidence_checker


ISSUE_LINKS_SCHEMA = "6529stream.release-evidence-issue-links.v1"
BACKLOG_SCHEMA = "6529stream.release-evidence-issue-backlog.v1"
DEFAULT_ISSUE_LINKS = Path("release-artifacts/latest/release-evidence-issue-links.json")
DEFAULT_BACKLOG = Path("release-artifacts/latest/release-evidence-issue-backlog.json")
ISSUE_URL_RE = re.compile(
    r"^https://github\.com/6529-Collections/6529Stream/issues/([1-9][0-9]*)$"
)


class ReleaseEvidenceIssueLinksError(RuntimeError):
    """Raised when issue-link evidence is incomplete or malformed."""


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
    """Load JSON with issue-link-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueLinksError(f"missing required file: {path}") from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ReleaseEvidenceIssueLinksError(f"unable to read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueLinksError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ReleaseEvidenceIssueLinksError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceIssueLinksError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise ReleaseEvidenceIssueLinksError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a JSON boolean."""
    if not isinstance(value, bool):
        raise ReleaseEvidenceIssueLinksError(f"{path} must be a boolean")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer, excluding bool."""
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ReleaseEvidenceIssueLinksError(f"{path} must be a positive integer")
    return value


def require_string_list(value: Any, path: str) -> list[str]:
    """Require a list of non-empty strings."""
    return [
        require_string(item, f"{path}[{index}]")
        for index, item in enumerate(require_list(value, path))
    ]


def validate_issue_url(url: str, issue_number: int, path: str) -> None:
    """Require a GitHub issue URL whose numeric suffix matches issue_number."""
    match = ISSUE_URL_RE.match(url)
    if match is None:
        raise ReleaseEvidenceIssueLinksError(f"{path} must be a 6529Stream issue URL")
    if int(match.group(1)) != issue_number:
        raise ReleaseEvidenceIssueLinksError(
            f"{path} issue number does not match issue_number"
        )


def validate_policy(policy: dict[str, Any]) -> None:
    """Validate no-secret tracker-only policy flags."""
    if not require_bool(policy.get("no_secrets"), "policy.no_secrets"):
        raise ReleaseEvidenceIssueLinksError("policy.no_secrets must be true")
    if not require_bool(policy.get("tracker_only"), "policy.tracker_only"):
        raise ReleaseEvidenceIssueLinksError("policy.tracker_only must be true")
    if require_bool(policy.get("auto_create_issues"), "policy.auto_create_issues"):
        raise ReleaseEvidenceIssueLinksError("policy.auto_create_issues must be false")
    if not require_bool(
        policy.get("completion_requires_reviewed_retained_evidence"),
        "policy.completion_requires_reviewed_retained_evidence",
    ):
        raise ReleaseEvidenceIssueLinksError(
            "policy.completion_requires_reviewed_retained_evidence must be true"
        )


def backlog_entries_by_id(backlog: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Return validated backlog entries by entry_id."""
    schema = require_string(backlog.get("schema_version"), "backlog.schema_version")
    if schema != BACKLOG_SCHEMA:
        raise ReleaseEvidenceIssueLinksError(
            f"backlog.schema_version must be {BACKLOG_SCHEMA}"
        )
    entries: dict[str, dict[str, Any]] = {}
    for index, raw_entry in enumerate(
        require_list(backlog.get("entries"), "backlog.entries")
    ):
        entry = require_dict(raw_entry, f"backlog.entries[{index}]")
        entry_id = require_string(
            entry.get("entry_id"),
            f"backlog.entries[{index}].entry_id",
        )
        if entry_id in entries:
            raise ReleaseEvidenceIssueLinksError(f"duplicate backlog entry: {entry_id}")
        entries[entry_id] = entry
    return entries


def validate_links_document(
    issue_links: dict[str, Any],
    backlog: dict[str, Any],
    repo_root: Path,
    backlog_path: Path,
) -> None:
    """Validate the issue links document against the generated backlog."""
    schema = require_string(issue_links.get("schema_version"), "schema_version")
    if schema != ISSUE_LINKS_SCHEMA:
        raise ReleaseEvidenceIssueLinksError(
            f"schema_version must be {ISSUE_LINKS_SCHEMA}"
        )

    source_backlog = require_dict(issue_links.get("source_backlog"), "source_backlog")
    expected_backlog_path = normalize_path(backlog_path, repo_root)
    source_backlog_path = require_string(
        source_backlog.get("path"),
        "source_backlog.path",
    )
    if source_backlog_path != expected_backlog_path:
        raise ReleaseEvidenceIssueLinksError(
            f"source_backlog.path must be {expected_backlog_path}"
        )
    source_backlog_schema = require_string(
        source_backlog.get("schema_version"),
        "source_backlog.schema_version",
    )
    if source_backlog_schema != BACKLOG_SCHEMA:
        raise ReleaseEvidenceIssueLinksError(
            f"source_backlog.schema_version must be {BACKLOG_SCHEMA}"
        )

    parent_issue = require_dict(issue_links.get("parent_issue"), "parent_issue")
    parent_issue_number = require_positive_int(
        parent_issue.get("issue_number"),
        "parent_issue.issue_number",
    )
    validate_issue_url(
        require_string(parent_issue.get("issue_url"), "parent_issue.issue_url"),
        parent_issue_number,
        "parent_issue.issue_url",
    )
    require_string(parent_issue.get("title"), "parent_issue.title")

    validate_policy(require_dict(issue_links.get("policy"), "policy"))
    entries = backlog_entries_by_id(backlog)
    links = require_list(issue_links.get("links"), "links")
    seen_entry_ids: set[str] = set()
    seen_issue_numbers: set[int] = {parent_issue_number}

    for index, raw_link in enumerate(links):
        link = require_dict(raw_link, f"links[{index}]")
        entry_id = require_string(link.get("entry_id"), f"links[{index}].entry_id")
        if entry_id in seen_entry_ids:
            raise ReleaseEvidenceIssueLinksError(f"duplicate issue link: {entry_id}")
        seen_entry_ids.add(entry_id)
        if entry_id not in entries:
            raise ReleaseEvidenceIssueLinksError(f"stale issue link entry_id: {entry_id}")

        entry = entries[entry_id]
        for field in ("phase", "phase_label", "requirement_id", "status", "title"):
            linked_value = require_string(link.get(field), f"links[{index}].{field}")
            backlog_value = require_string(
                entry.get(field),
                f"backlog.{entry_id}.{field}",
            )
            if linked_value != backlog_value:
                raise ReleaseEvidenceIssueLinksError(
                    f"links[{index}].{field} does not match backlog entry {entry_id}"
                )

        issue_number = require_positive_int(
            link.get("issue_number"),
            f"links[{index}].issue_number",
        )
        if issue_number in seen_issue_numbers:
            raise ReleaseEvidenceIssueLinksError(f"duplicate issue number: {issue_number}")
        seen_issue_numbers.add(issue_number)
        validate_issue_url(
            require_string(link.get("issue_url"), f"links[{index}].issue_url"),
            issue_number,
            f"links[{index}].issue_url",
        )
        suggested_labels = require_string_list(
            link.get("suggested_labels"),
            f"links[{index}].suggested_labels",
        )
        backlog_labels = require_string_list(
            entry.get("suggested_labels"),
            f"backlog.{entry_id}.suggested_labels",
        )
        if suggested_labels != backlog_labels:
            raise ReleaseEvidenceIssueLinksError(
                f"links[{index}].suggested_labels does not match backlog entry {entry_id}"
            )
        applied_labels = require_string_list(
            link.get("applied_labels"),
            f"links[{index}].applied_labels",
        )
        if not applied_labels:
            raise ReleaseEvidenceIssueLinksError(
                f"links[{index}].applied_labels must not be empty"
            )

    missing = sorted(set(entries) - seen_entry_ids)
    if missing:
        raise ReleaseEvidenceIssueLinksError(
            "missing issue links for backlog entries: " + ", ".join(missing)
        )

    try:
        evidence_checker.scan_for_secret_like_data(issue_links)
    except evidence_checker.PublicBetaEvidenceError as exc:
        raise ReleaseEvidenceIssueLinksError(
            f"issue links contain secret-like data: {exc}"
        ) from exc


def check_issue_links(repo_root: Path, issue_links_path: Path, backlog_path: Path) -> None:
    """Load and validate issue-link evidence files."""
    resolved_links = resolve_repo_path(repo_root, issue_links_path)
    resolved_backlog = resolve_repo_path(repo_root, backlog_path)
    issue_links = require_dict(load_json(resolved_links), str(resolved_links))
    backlog = require_dict(load_json(resolved_backlog), str(resolved_backlog))
    validate_links_document(issue_links, backlog, repo_root, resolved_backlog)


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--issue-links", type=Path, default=DEFAULT_ISSUE_LINKS)
    parser.add_argument("--backlog", type=Path, default=DEFAULT_BACKLOG)
    args = parser.parse_args(argv)

    try:
        check_issue_links(args.repo_root, args.issue_links, args.backlog)
    except ReleaseEvidenceIssueLinksError as exc:
        print(f"release evidence issue links check failed: {exc}", file=sys.stderr)
        return 1

    print("release evidence issue links are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
