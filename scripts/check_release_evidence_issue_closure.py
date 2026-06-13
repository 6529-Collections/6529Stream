#!/usr/bin/env python3
"""Validate release evidence tracker issue closure readiness."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import check_public_beta_evidence as evidence_checker
import check_release_evidence_issue_bodies as body_checker
import check_release_evidence_issue_links as issue_link_checker


DEFAULT_ISSUE_LINKS = Path("release-artifacts/latest/release-evidence-issue-links.json")
DEFAULT_BACKLOG = Path("release-artifacts/latest/release-evidence-issue-backlog.json")
DEFAULT_BODY_SYNC = Path("release-artifacts/latest/release-evidence-issue-body-sync.json")
DEFAULT_PACKET_INDEX = Path("release-artifacts/latest/release-evidence-packet-index.json")
DEFAULT_EVIDENCE = Path("release-artifacts/latest/public-beta-evidence.json")

PACKET_INDEX_SCHEMA = "6529stream.release-evidence-packet-index.v1"
REPO_FULL_NAME = "6529-Collections/6529Stream"
CLOSURE_ALLOWED_STATUSES = frozenset({"complete", "accepted_risk"})
OPEN_STATES = frozenset({"open", "opened"})
CLOSED_STATES = frozenset({"closed"})


class ReleaseEvidenceIssueClosureError(RuntimeError):
    """Raised when tracker issue closure state is unsafe or inconsistent."""


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    """Resolve a path relative to the repository root."""
    return path if path.is_absolute() else repo_root / path


def load_json(path: Path) -> Any:
    """Load JSON with closure-checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8-sig") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueClosureError(f"missing required file: {path}") from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ReleaseEvidenceIssueClosureError(f"unable to read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueClosureError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ReleaseEvidenceIssueClosureError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceIssueClosureError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise ReleaseEvidenceIssueClosureError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a JSON boolean."""
    if not isinstance(value, bool):
        raise ReleaseEvidenceIssueClosureError(f"{path} must be a boolean")
    return value


def require_non_negative_int(value: Any, path: str) -> int:
    """Require a non-negative integer, excluding bool."""
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise ReleaseEvidenceIssueClosureError(f"{path} must be a non-negative integer")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer, excluding bool."""
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ReleaseEvidenceIssueClosureError(f"{path} must be a positive integer")
    return value


def requirement_key(phase: str, requirement_id: str) -> str:
    """Return the stable phase/requirement key used across artifacts."""
    return f"{phase}:{requirement_id}"


def evidence_requirements_by_key(
    evidence: dict[str, Any],
    repo_root: Path,
    evidence_path: Path,
) -> dict[str, dict[str, Any]]:
    """Validate and index the committed evidence manifest."""
    try:
        evidence_checker.validate_evidence_document(evidence, repo_root, str(evidence_path))
    except evidence_checker.PublicBetaEvidenceError as exc:
        raise ReleaseEvidenceIssueClosureError(str(exc)) from exc

    requirements: dict[str, dict[str, Any]] = {}
    for index, raw_requirement in enumerate(
        require_list(evidence.get("requirements"), "evidence.requirements")
    ):
        requirement = require_dict(raw_requirement, f"evidence.requirements[{index}]")
        phase = require_string(
            requirement.get("phase"),
            f"evidence.requirements[{index}].phase",
        )
        requirement_id = require_string(
            requirement.get("id"),
            f"evidence.requirements[{index}].id",
        )
        key = requirement_key(phase, requirement_id)
        if key in requirements:
            raise ReleaseEvidenceIssueClosureError(
                f"duplicate evidence requirement: {key}"
            )
        requirements[key] = requirement
    return requirements


def packet_rows_by_key(packet_index: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Validate and index release evidence packet rows."""
    schema = require_string(packet_index.get("schema_version"), "packet_index.schema_version")
    if schema != PACKET_INDEX_SCHEMA:
        raise ReleaseEvidenceIssueClosureError(
            f"packet_index.schema_version must be {PACKET_INDEX_SCHEMA}"
        )

    policy = require_dict(packet_index.get("policy"), "packet_index.policy")
    if not require_bool(policy.get("no_secrets"), "packet_index.policy.no_secrets"):
        raise ReleaseEvidenceIssueClosureError(
            "packet_index.policy.no_secrets must be true"
        )
    if require_bool(
        policy.get("template_only_can_complete"),
        "packet_index.policy.template_only_can_complete",
    ):
        raise ReleaseEvidenceIssueClosureError(
            "packet_index.policy.template_only_can_complete must be false"
        )

    rows: dict[str, dict[str, Any]] = {}
    for index, raw_row in enumerate(require_list(packet_index.get("rows"), "packet_index.rows")):
        row = require_dict(raw_row, f"packet_index.rows[{index}]")
        phase = require_string(row.get("phase"), f"packet_index.rows[{index}].phase")
        requirement_id = require_string(
            row.get("requirement_id"),
            f"packet_index.rows[{index}].requirement_id",
        )
        status = require_string(row.get("status"), f"packet_index.rows[{index}].status")
        if status not in evidence_checker.REQUIREMENT_STATUSES:
            raise ReleaseEvidenceIssueClosureError(
                f"packet_index.rows[{index}].status is not a known requirement status"
            )
        require_non_negative_int(
            row.get("evidence_count"),
            f"packet_index.rows[{index}].evidence_count",
        )
        key = requirement_key(phase, requirement_id)
        if key in rows:
            raise ReleaseEvidenceIssueClosureError(f"duplicate packet row: {key}")
        rows[key] = row
    return rows


def body_sync_issues_by_entry_id(
    body_sync: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    """Validate and index body-sync tracker rows."""
    body_checker.expected_issue_rows(body_sync)

    rows: dict[str, dict[str, Any]] = {}
    for index, raw_issue in enumerate(require_list(body_sync.get("issues"), "body_sync.issues")):
        issue = require_dict(raw_issue, f"body_sync.issues[{index}]")
        entry_id = require_string(
            issue.get("entry_id"),
            f"body_sync.issues[{index}].entry_id",
        )
        if entry_id in rows:
            raise ReleaseEvidenceIssueClosureError(
                f"duplicate body-sync issue: {entry_id}"
            )
        rows[entry_id] = issue
    return rows


def load_expected_issue_rows(
    repo_root: Path,
    issue_links_path: Path,
    backlog_path: Path,
    body_sync_path: Path,
    packet_index_path: Path,
    evidence_path: Path,
) -> list[dict[str, Any]]:
    """Load committed artifacts and return the expected closure rows."""
    issue_links = require_dict(load_json(issue_links_path), "issue_links")
    backlog = require_dict(load_json(backlog_path), "backlog")
    body_sync = require_dict(load_json(body_sync_path), "body_sync")
    packet_index = require_dict(load_json(packet_index_path), "packet_index")
    evidence = require_dict(load_json(evidence_path), "evidence")

    try:
        issue_link_checker.validate_links_document(
            issue_links,
            backlog,
            repo_root,
            backlog_path,
        )
    except issue_link_checker.ReleaseEvidenceIssueLinksError as exc:
        raise ReleaseEvidenceIssueClosureError(str(exc)) from exc

    body_rows = body_sync_issues_by_entry_id(body_sync)
    packet_rows = packet_rows_by_key(packet_index)
    evidence_rows = evidence_requirements_by_key(evidence, repo_root, evidence_path)

    rows: list[dict[str, Any]] = []
    for index, raw_link in enumerate(require_list(issue_links.get("links"), "issue_links.links")):
        link = require_dict(raw_link, f"issue_links.links[{index}]")
        entry_id = require_string(link.get("entry_id"), f"issue_links.links[{index}].entry_id")
        body_row = body_rows.get(entry_id)
        if body_row is None:
            raise ReleaseEvidenceIssueClosureError(
                f"body-sync artifact is missing linked entry_id: {entry_id}"
            )

        phase = require_string(link.get("phase"), f"issue_links.links[{index}].phase")
        requirement_id = require_string(
            link.get("requirement_id"),
            f"issue_links.links[{index}].requirement_id",
        )
        key = requirement_key(phase, requirement_id)
        packet_row = packet_rows.get(key)
        if packet_row is None:
            raise ReleaseEvidenceIssueClosureError(
                f"packet index is missing linked requirement: {key}"
            )
        evidence_row = evidence_rows.get(key)
        if evidence_row is None:
            raise ReleaseEvidenceIssueClosureError(
                f"evidence manifest is missing linked requirement: {key}"
            )

        expected_fields = ("phase", "phase_label", "requirement_id", "status", "title")
        for field in expected_fields:
            link_value = require_string(link.get(field), f"issue_links.{entry_id}.{field}")
            body_value = require_string(body_row.get(field), f"body_sync.{entry_id}.{field}")
            if body_value != link_value:
                raise ReleaseEvidenceIssueClosureError(
                    f"body-sync {entry_id}.{field} does not match issue links"
                )

        issue_number = require_positive_int(
            link.get("issue_number"),
            f"issue_links.{entry_id}.issue_number",
        )
        body_issue_number = require_positive_int(
            body_row.get("issue_number"),
            f"body_sync.{entry_id}.issue_number",
        )
        if body_issue_number != issue_number:
            raise ReleaseEvidenceIssueClosureError(
                f"body-sync {entry_id}.issue_number does not match issue links"
            )

        status = require_string(link.get("status"), f"issue_links.{entry_id}.status")
        packet_status = require_string(packet_row.get("status"), f"packet_index.{key}.status")
        evidence_status = require_string(evidence_row.get("status"), f"evidence.{key}.status")
        if packet_status != status:
            raise ReleaseEvidenceIssueClosureError(
                f"packet index {key}.status does not match issue links"
            )
        if evidence_status != status:
            raise ReleaseEvidenceIssueClosureError(
                f"evidence manifest {key}.status does not match issue links"
            )

        evidence_refs = require_list(evidence_row.get("evidence"), f"evidence.{key}.evidence")
        evidence_count = require_non_negative_int(
            packet_row.get("evidence_count"),
            f"packet_index.{key}.evidence_count",
        )
        if status == "complete":
            if not evidence_refs:
                raise ReleaseEvidenceIssueClosureError(
                    f"evidence manifest {key} is complete without retained evidence"
                )
            if evidence_count == 0:
                raise ReleaseEvidenceIssueClosureError(
                    f"packet index {key} is complete without retained evidence"
                )
            evidence_posture = require_string(
                packet_row.get("evidence_posture"),
                f"packet_index.{key}.evidence_posture",
            )
            if evidence_posture == "local-template-only":
                raise ReleaseEvidenceIssueClosureError(
                    f"packet index {key} cannot complete from local-template-only evidence"
                )
        if status == "accepted_risk" and evidence_row.get("risk_acceptance") is None:
            raise ReleaseEvidenceIssueClosureError(
                f"evidence manifest {key} is accepted_risk without risk_acceptance"
            )

        closure_allowed = status in CLOSURE_ALLOWED_STATUSES
        rows.append(
            {
                "entry_id": entry_id,
                "phase": phase,
                "requirement_id": requirement_id,
                "issue_number": issue_number,
                "title": require_string(link.get("title"), f"issue_links.{entry_id}.title"),
                "status": status,
                "closure_allowed": closure_allowed,
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
            raise ReleaseEvidenceIssueClosureError(
                f"duplicate issue in snapshot: {issue_number}"
            )
        issues[issue_number] = issue
    return issues


def normalize_issue_state(value: Any, path: str) -> str:
    """Normalize a GitHub issue state from the snapshot."""
    state = require_string(value, path).lower()
    if state in OPEN_STATES:
        return "open"
    if state in CLOSED_STATES:
        return "closed"
    raise ReleaseEvidenceIssueClosureError(
        f"{path} must be one of: closed, open, opened"
    )


def reopen_command(issue_number: int) -> str:
    """Return the deterministic remediation command for premature closure."""
    return f"gh issue reopen {issue_number} --repo {REPO_FULL_NAME}"


def validate_snapshot_closure(rows: list[dict[str, Any]], snapshot: Any) -> None:
    """Validate expected issue closure policy against a GitHub issue snapshot."""
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

        try:
            state = normalize_issue_state(issue.get("state"), f"issue #{issue_number}.state")
        except ReleaseEvidenceIssueClosureError as exc:
            errors.append(str(exc))
            continue

        if state == "closed" and not row["closure_allowed"]:
            key = requirement_key(row["phase"], row["requirement_id"])
            errors.append(
                f"issue #{issue_number} ({row['entry_id']}, {key}) is closed while "
                f"committed evidence status is {row['status']!r}; required state: "
                f"open until status is complete or accepted_risk; remediation: "
                f"{reopen_command(issue_number)}"
            )

    if errors:
        raise ReleaseEvidenceIssueClosureError("; ".join(errors))


def validate_files(
    repo_root: Path,
    issue_links_path: Path,
    backlog_path: Path,
    body_sync_path: Path,
    packet_index_path: Path,
    evidence_path: Path,
    snapshot_path: Path | None = None,
) -> None:
    """Validate committed closure policy and optional live/snapshot issue state."""
    rows = load_expected_issue_rows(
        repo_root,
        issue_links_path,
        backlog_path,
        body_sync_path,
        packet_index_path,
        evidence_path,
    )
    if snapshot_path is not None:
        validate_snapshot_closure(rows, load_json(snapshot_path))


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Validate release evidence tracker issue closure readiness"
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--issue-links", type=Path, default=DEFAULT_ISSUE_LINKS)
    parser.add_argument("--backlog", type=Path, default=DEFAULT_BACKLOG)
    parser.add_argument("--body-sync", type=Path, default=DEFAULT_BODY_SYNC)
    parser.add_argument("--packet-index", type=Path, default=DEFAULT_PACKET_INDEX)
    parser.add_argument("--evidence", type=Path, default=DEFAULT_EVIDENCE)
    parser.add_argument(
        "--live-json",
        type=Path,
        default=None,
        help=(
            "Optional GitHub issue JSON snapshot from "
            "`gh issue list --state all --json number,title,state`."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the release evidence issue closure checker."""
    parser = build_parser()
    args = parser.parse_args(argv)

    repo_root = args.repo_root.resolve()
    issue_links_path = resolve_repo_path(repo_root, args.issue_links)
    backlog_path = resolve_repo_path(repo_root, args.backlog)
    body_sync_path = resolve_repo_path(repo_root, args.body_sync)
    packet_index_path = resolve_repo_path(repo_root, args.packet_index)
    evidence_path = resolve_repo_path(repo_root, args.evidence)
    snapshot_path = (
        resolve_repo_path(repo_root, args.live_json)
        if args.live_json is not None
        else None
    )

    try:
        validate_files(
            repo_root,
            issue_links_path,
            backlog_path,
            body_sync_path,
            packet_index_path,
            evidence_path,
            snapshot_path,
        )
    except ReleaseEvidenceIssueClosureError as exc:
        print(f"release evidence issue closure check failed: {exc}", file=sys.stderr)
        return 1

    print("release evidence issue closure readiness is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
