#!/usr/bin/env python3
"""Generate exact GitHub issue body payloads for release evidence trackers."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import check_public_beta_evidence as evidence_checker
import check_release_evidence_issue_links as issue_link_checker
import generate_public_beta_blocker_report as shared_report


BODY_SYNC_SCHEMA = "6529stream.release-evidence-issue-body-sync.v1"
GENERATOR_VERSION = "1"
SCRIPT_NAME = Path(__file__).name

DEFAULT_BACKLOG = Path("release-artifacts/latest/release-evidence-issue-backlog.json")
DEFAULT_ISSUE_LINKS = Path("release-artifacts/latest/release-evidence-issue-links.json")
DEFAULT_JSON_OUTPUT = Path("release-artifacts/latest/release-evidence-issue-body-sync.json")
DEFAULT_MARKDOWN_OUTPUT = Path("release-artifacts/latest/release-evidence-issue-body-sync.md")

REQUIRED_ISSUE_BODY_HEADINGS = (
    "## Evidence Requirement",
    "## Source Links",
    "## Required Evidence",
    "## Validation",
    "## Non-Goals",
    "## Acceptance Criteria",
)
SYNC_MARKER_RE = re.compile(r"^[a-z0-9][a-z0-9._:-]*$")


class ReleaseEvidenceIssueBodySyncError(RuntimeError):
    """Raised when issue body sync payload generation fails."""


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
    """Load JSON with body-sync-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueBodySyncError(f"missing required file: {path}") from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ReleaseEvidenceIssueBodySyncError(f"unable to read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueBodySyncError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ReleaseEvidenceIssueBodySyncError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceIssueBodySyncError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise ReleaseEvidenceIssueBodySyncError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a JSON boolean."""
    if not isinstance(value, bool):
        raise ReleaseEvidenceIssueBodySyncError(f"{path} must be a boolean")
    return value


def sha256_text(value: str) -> str:
    """Return a sha256 digest string for UTF-8 text."""
    return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def json_text(value: Any) -> str:
    """Return deterministic JSON text."""
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def file_record(path: Path, repo_root: Path) -> dict[str, Any]:
    """Return path, checksum, and size for an input artifact."""
    return {
        "path": normalize_path(path, repo_root),
        "sha256": sha256_text(path.read_text(encoding="utf-8")),
        "size_bytes": path.stat().st_size,
    }


def validate_policy(policy: dict[str, Any]) -> None:
    """Validate body-sync policy flags."""
    if not require_bool(policy.get("no_secrets"), "policy.no_secrets"):
        raise ReleaseEvidenceIssueBodySyncError("policy.no_secrets must be true")
    if not require_bool(policy.get("tracker_only"), "policy.tracker_only"):
        raise ReleaseEvidenceIssueBodySyncError("policy.tracker_only must be true")
    if require_bool(policy.get("auto_update_issues"), "policy.auto_update_issues"):
        raise ReleaseEvidenceIssueBodySyncError("policy.auto_update_issues must be false")
    if not require_bool(
        policy.get("completion_requires_reviewed_retained_evidence"),
        "policy.completion_requires_reviewed_retained_evidence",
    ):
        raise ReleaseEvidenceIssueBodySyncError(
            "policy.completion_requires_reviewed_retained_evidence must be true"
        )


def validate_issue_body(entry_id: str, issue_body: str) -> None:
    """Require an issue-ready backlog body with the canonical sections."""
    for heading in REQUIRED_ISSUE_BODY_HEADINGS:
        if heading not in issue_body:
            raise ReleaseEvidenceIssueBodySyncError(
                f"backlog entry {entry_id} issue_body is missing {heading}"
            )


def body_prefix(
    entry_id: str,
    issue_number: int,
    parent_issue_url: str,
    backlog_path: str,
    issue_links_path: str,
) -> str:
    """Build the deterministic synchronization preamble."""
    if SYNC_MARKER_RE.match(entry_id) is None:
        raise ReleaseEvidenceIssueBodySyncError(
            f"entry_id contains unsupported sync marker characters: {entry_id}"
        )
    return "\n".join(
        [
            (
                f"<!-- {BODY_SYNC_SCHEMA} entry_id={entry_id} "
                f"issue_number={issue_number} -->"
            ),
            "",
            f"Parent tracker: {parent_issue_url}",
            f"Source backlog entry: `{backlog_path}` / `{entry_id}`",
            f"Issue-link artifact: `{issue_links_path}`",
            (
                "Completion policy: this tracker issue can close only after reviewed "
                "retained evidence is referenced by the release evidence manifest."
            ),
            "",
            "",
        ]
    )


def expected_issue_body(
    entry: dict[str, Any],
    link: dict[str, Any],
    parent_issue_url: str,
    backlog_path: str,
    issue_links_path: str,
) -> str:
    """Return the exact GitHub issue body expected for one tracker issue."""
    entry_id = require_string(entry.get("entry_id"), "entry.entry_id")
    issue_number = issue_link_checker.require_positive_int(
        link.get("issue_number"),
        f"link.{entry_id}.issue_number",
    )
    issue_body = require_string(entry.get("issue_body"), f"backlog.{entry_id}.issue_body")
    validate_issue_body(entry_id, issue_body)
    return (
        body_prefix(
            entry_id,
            issue_number,
            parent_issue_url,
            backlog_path,
            issue_links_path,
        )
        + issue_body.rstrip()
        + "\n"
    )


def body_line_count(body: str) -> int:
    """Count issue body lines deterministically."""
    return len(body.rstrip("\n").splitlines())


def entries_by_id(backlog: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Return backlog entries by entry_id after link-check validation."""
    entries: dict[str, dict[str, Any]] = {}
    for index, raw_entry in enumerate(require_list(backlog.get("entries"), "backlog.entries")):
        entry = require_dict(raw_entry, f"backlog.entries[{index}]")
        entry_id = require_string(entry.get("entry_id"), f"backlog.entries[{index}].entry_id")
        if entry_id in entries:
            raise ReleaseEvidenceIssueBodySyncError(f"duplicate backlog entry: {entry_id}")
        entries[entry_id] = entry
    return entries


def issue_row(
    entry: dict[str, Any],
    link: dict[str, Any],
    parent_issue_url: str,
    backlog_path: str,
    issue_links_path: str,
) -> dict[str, Any]:
    """Build one exact issue body payload row."""
    entry_id = require_string(entry.get("entry_id"), "entry.entry_id")
    body = expected_issue_body(entry, link, parent_issue_url, backlog_path, issue_links_path)
    source_issue_body = require_string(
        entry.get("issue_body"),
        f"backlog.{entry_id}.issue_body",
    )
    return {
        "entry_id": entry_id,
        "phase": require_string(entry.get("phase"), f"backlog.{entry_id}.phase"),
        "phase_label": require_string(
            entry.get("phase_label"),
            f"backlog.{entry_id}.phase_label",
        ),
        "requirement_id": require_string(
            entry.get("requirement_id"),
            f"backlog.{entry_id}.requirement_id",
        ),
        "status": require_string(entry.get("status"), f"backlog.{entry_id}.status"),
        "evidence_posture": require_string(
            entry.get("evidence_posture"),
            f"backlog.{entry_id}.evidence_posture",
        ),
        "title": require_string(entry.get("title"), f"backlog.{entry_id}.title"),
        "issue_number": issue_link_checker.require_positive_int(
            link.get("issue_number"),
            f"links.{entry_id}.issue_number",
        ),
        "issue_url": require_string(link.get("issue_url"), f"links.{entry_id}.issue_url"),
        "suggested_labels": issue_link_checker.require_string_list(
            link.get("suggested_labels"),
            f"links.{entry_id}.suggested_labels",
        ),
        "applied_labels": issue_link_checker.require_string_list(
            link.get("applied_labels"),
            f"links.{entry_id}.applied_labels",
        ),
        "source_issue_body_sha256": sha256_text(source_issue_body),
        "body_sha256": sha256_text(body),
        "body_line_count": body_line_count(body),
        "expected_body": body,
    }


def validate_body_sync_document(document: dict[str, Any]) -> None:
    """Validate the generated body-sync document shape and policy."""
    schema = require_string(document.get("schema_version"), "schema_version")
    if schema != BODY_SYNC_SCHEMA:
        raise ReleaseEvidenceIssueBodySyncError(
            f"schema_version must be {BODY_SYNC_SCHEMA}"
        )
    validate_policy(require_dict(document.get("policy"), "policy"))
    issues = require_list(document.get("issues"), "issues")
    seen_entry_ids: set[str] = set()
    seen_issue_numbers: set[int] = set()
    for index, raw_issue in enumerate(issues):
        issue = require_dict(raw_issue, f"issues[{index}]")
        entry_id = require_string(issue.get("entry_id"), f"issues[{index}].entry_id")
        if entry_id in seen_entry_ids:
            raise ReleaseEvidenceIssueBodySyncError(f"duplicate issue body: {entry_id}")
        seen_entry_ids.add(entry_id)
        issue_number = issue_link_checker.require_positive_int(
            issue.get("issue_number"),
            f"issues[{index}].issue_number",
        )
        if issue_number in seen_issue_numbers:
            raise ReleaseEvidenceIssueBodySyncError(
                f"duplicate issue number: {issue_number}"
            )
        seen_issue_numbers.add(issue_number)
        expected_body = require_string(
            issue.get("expected_body"),
            f"issues[{index}].expected_body",
        )
        body_sha256 = require_string(issue.get("body_sha256"), f"issues[{index}].body_sha256")
        if body_sha256 != sha256_text(expected_body):
            raise ReleaseEvidenceIssueBodySyncError(
                f"issues[{index}].body_sha256 does not match expected_body"
            )
        if f"entry_id={entry_id}" not in expected_body:
            raise ReleaseEvidenceIssueBodySyncError(
                f"issues[{index}].expected_body is missing sync entry marker"
            )
        if f"issue_number={issue_number}" not in expected_body:
            raise ReleaseEvidenceIssueBodySyncError(
                f"issues[{index}].expected_body is missing sync issue marker"
            )

    try:
        evidence_checker.scan_for_secret_like_data(document)
    except evidence_checker.PublicBetaEvidenceError as exc:
        raise ReleaseEvidenceIssueBodySyncError(
            f"issue body sync contains secret-like data: {exc}"
        ) from exc


def build_body_sync(
    repo_root: Path,
    backlog_path: Path,
    issue_links_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> dict[str, Any]:
    """Build the issue body sync document."""
    resolved_backlog = resolve_repo_path(repo_root, backlog_path)
    resolved_issue_links = resolve_repo_path(repo_root, issue_links_path)
    backlog = require_dict(load_json(resolved_backlog), str(resolved_backlog))
    issue_links = require_dict(load_json(resolved_issue_links), str(resolved_issue_links))

    try:
        issue_link_checker.validate_links_document(
            issue_links,
            backlog,
            repo_root,
            resolved_backlog,
        )
    except issue_link_checker.ReleaseEvidenceIssueLinksError as exc:
        raise ReleaseEvidenceIssueBodySyncError(f"invalid issue links: {exc}") from exc

    backlog_relative = normalize_path(resolved_backlog, repo_root)
    issue_links_relative = normalize_path(resolved_issue_links, repo_root)
    output_json = normalize_path(resolve_repo_path(repo_root, json_output_path), repo_root)
    output_markdown = normalize_path(
        resolve_repo_path(repo_root, markdown_output_path),
        repo_root,
    )
    parent_issue = require_dict(issue_links.get("parent_issue"), "issue_links.parent_issue")
    parent_issue_url = require_string(parent_issue.get("issue_url"), "parent_issue.issue_url")
    entries = entries_by_id(backlog)
    issues = [
        issue_row(
            entries[require_string(link.get("entry_id"), f"links[{index}].entry_id")],
            require_dict(link, f"links[{index}]"),
            parent_issue_url,
            backlog_relative,
            issue_links_relative,
        )
        for index, link in enumerate(require_list(issue_links.get("links"), "issue_links.links"))
    ]

    document = {
        "schema_version": BODY_SYNC_SCHEMA,
        "generated_by": f"scripts/{SCRIPT_NAME}:{GENERATOR_VERSION}",
        "generator_version": GENERATOR_VERSION,
        "outputs": {
            "json": output_json,
            "markdown": output_markdown,
        },
        "source": {
            "backlog": {
                **file_record(resolved_backlog, repo_root),
                "schema_version": issue_link_checker.BACKLOG_SCHEMA,
            },
            "issue_links": {
                **file_record(resolved_issue_links, repo_root),
                "schema_version": issue_link_checker.ISSUE_LINKS_SCHEMA,
            },
        },
        "parent_issue": parent_issue,
        "policy": {
            "no_secrets": True,
            "tracker_only": True,
            "auto_update_issues": False,
            "completion_requires_reviewed_retained_evidence": True,
        },
        "status_summary": require_list(
            backlog.get("status_summary"),
            "backlog.status_summary",
        ),
        "issues": issues,
        "validation_commands": [
            "python scripts/test_release_evidence_issue_body_sync.py",
            "python scripts/generate_release_evidence_issue_body_sync.py --check",
            "python scripts/test_release_evidence_issue_bodies.py",
            "python scripts/check_release_evidence_issue_bodies.py",
            "python scripts/test_release_evidence_issue_links.py",
            "python scripts/check_release_evidence_issue_links.py",
            "python scripts/generate_release_manifest.py --check",
            "python scripts/generate_release_checksums.py --check",
        ],
    }
    validate_body_sync_document(document)
    return document


def markdown_for_body_sync(document: dict[str, Any]) -> str:
    """Render the body sync document for human review."""
    source = require_dict(document.get("source"), "source")
    backlog = require_dict(source.get("backlog"), "source.backlog")
    issue_links = require_dict(source.get("issue_links"), "source.issue_links")
    policy = require_dict(document.get("policy"), "policy")
    issues = [
        require_dict(issue, f"issues[{index}]")
        for index, issue in enumerate(require_list(document.get("issues"), "issues"))
    ]
    lines = [
        "# Release Evidence Issue Body Sync",
        "",
        (
            "This generated artifact contains the exact GitHub issue bodies expected "
            "for retained release-evidence tracker issues. It is tracker-only, contains "
            "no secrets, and does not auto-update GitHub."
        ),
        "",
        "## Source",
        "",
        shared_report.markdown_table(
            ["Field", "Value"],
            [
                ["Schema", f"`{document['schema_version']}`"],
                ["JSON output", f"`{document['outputs']['json']}`"],
                ["Markdown output", f"`{document['outputs']['markdown']}`"],
                ["Backlog", f"`{backlog['path']}`"],
                ["Backlog SHA-256", f"`{backlog['sha256']}`"],
                ["Issue links", f"`{issue_links['path']}`"],
                ["Issue links SHA-256", f"`{issue_links['sha256']}`"],
            ],
        ),
        "",
        "## Policy",
        "",
        shared_report.markdown_table(
            ["Field", "Value"],
            [[key, f"`{value}`"] for key, value in policy.items()],
        ),
        "",
        "## Issue Payloads",
        "",
        shared_report.markdown_table(
            ["Issue", "Entry", "Status", "Body SHA-256", "Lines"],
            [
                [
                    f"[#{issue['issue_number']}]({issue['issue_url']})",
                    f"`{issue['entry_id']}`",
                    f"`{issue['status']}`",
                    f"`{issue['body_sha256']}`",
                    str(issue["body_line_count"]),
                ]
                for issue in issues
            ],
        ),
        "",
    ]
    for issue in issues:
        lines.extend(
            [
                f"### #{issue['issue_number']} {issue['entry_id']}",
                "",
                f"- Issue: {issue['issue_url']}",
                f"- Body SHA-256: `{issue['body_sha256']}`",
                f"- Source body SHA-256: `{issue['source_issue_body_sha256']}`",
                "",
                "```markdown",
                issue["expected_body"].rstrip(),
                "```",
                "",
            ]
        )
    lines.extend(
        [
            "## Validation Commands",
            "",
            shared_report.markdown_table(
                ["Command"],
                [[f"`{command}`"] for command in document["validation_commands"]],
            ),
        ]
    )
    return "\n".join(lines) + "\n"


def build_outputs(
    repo_root: Path,
    backlog_path: Path,
    issue_links_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> tuple[str, str]:
    """Return deterministic JSON and Markdown output text."""
    document = build_body_sync(
        repo_root,
        backlog_path,
        issue_links_path,
        json_output_path,
        markdown_output_path,
    )
    return json_text(document), markdown_for_body_sync(document)


def write_outputs(
    repo_root: Path,
    backlog_path: Path,
    issue_links_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> list[Path]:
    """Generate and write the committed body-sync outputs."""
    json_output = resolve_repo_path(repo_root, json_output_path)
    markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    json_output_text, markdown_output_text = build_outputs(
        repo_root,
        backlog_path,
        issue_links_path,
        json_output_path,
        markdown_output_path,
    )
    json_output.parent.mkdir(parents=True, exist_ok=True)
    markdown_output.parent.mkdir(parents=True, exist_ok=True)
    json_output.write_text(json_output_text, encoding="utf-8", newline="\n")
    markdown_output.write_text(markdown_output_text, encoding="utf-8", newline="\n")
    return [json_output, markdown_output]


def check_outputs(
    repo_root: Path,
    backlog_path: Path,
    issue_links_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> int:
    """Check that committed body-sync outputs match generated output."""
    json_output = resolve_repo_path(repo_root, json_output_path)
    markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    missing = [output for output in (json_output, markdown_output) if not output.exists()]
    if missing:
        for output in missing:
            print(f"missing {normalize_path(output, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_evidence_issue_body_sync.py` "
            "and commit the regenerated files",
            file=sys.stderr,
        )
        return 1

    expected_json, expected_markdown = build_outputs(
        repo_root,
        backlog_path,
        issue_links_path,
        json_output_path,
        markdown_output_path,
    )
    mismatches = []
    if json_output.read_text(encoding="utf-8") != expected_json:
        mismatches.append(normalize_path(json_output, repo_root))
    if markdown_output.read_text(encoding="utf-8") != expected_markdown:
        mismatches.append(normalize_path(markdown_output, repo_root))
    if mismatches:
        for path in mismatches:
            print(f"changed {path}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_evidence_issue_body_sync.py` "
            "and commit the regenerated files",
            file=sys.stderr,
        )
        return 1
    print("release evidence issue body sync is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--backlog", type=Path, default=DEFAULT_BACKLOG)
    parser.add_argument("--issue-links", type=Path, default=DEFAULT_ISSUE_LINKS)
    parser.add_argument("--json-output", type=Path, default=DEFAULT_JSON_OUTPUT)
    parser.add_argument("--markdown-output", type=Path, default=DEFAULT_MARKDOWN_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the generator CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        if args.check:
            return check_outputs(
                repo_root,
                args.backlog,
                args.issue_links,
                args.json_output,
                args.markdown_output,
            )
        written = write_outputs(
            repo_root,
            args.backlog,
            args.issue_links,
            args.json_output,
            args.markdown_output,
        )
    except ReleaseEvidenceIssueBodySyncError as exc:
        print(f"release evidence issue body sync generation failed: {exc}", file=sys.stderr)
        return 1
    for path in written:
        print(normalize_path(path, repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
