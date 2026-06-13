#!/usr/bin/env python3
"""Generate an issue-ready release evidence backlog from the packet index."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import check_public_beta_evidence as evidence_checker
import generate_public_beta_blocker_report as shared_report


BACKLOG_SCHEMA = "6529stream.release-evidence-issue-backlog.v1"
PACKET_SCHEMA = "6529stream.release-evidence-packet-index.v1"
GENERATOR_VERSION = "1"
SCRIPT_NAME = Path(__file__).name

DEFAULT_PACKET_INDEX = Path("release-artifacts/latest/release-evidence-packet-index.json")
DEFAULT_JSON_OUTPUT = Path("release-artifacts/latest/release-evidence-issue-backlog.json")
DEFAULT_MARKDOWN_OUTPUT = Path("release-artifacts/latest/release-evidence-issue-backlog.md")

PUBLIC_BETA_PHASE = "public_beta"
PRODUCTION_PHASE = "production_release"
INCOMPLETE_STATUSES = shared_report.INCOMPLETE_STATUSES
PHASE_LABELS = {
    PUBLIC_BETA_PHASE: "Public Beta",
    PRODUCTION_PHASE: "Production Release",
}
PHASE_LABEL_SLUGS = {
    PUBLIC_BETA_PHASE: "public-beta",
    PRODUCTION_PHASE: "production-release",
}
PHASE_ISSUE_PREFIXES = {
    PUBLIC_BETA_PHASE: "Retain public beta evidence",
    PRODUCTION_PHASE: "Retain production release evidence",
}
COMMON_LABELS = ["release", "evidence", "roadmap"]


class ReleaseEvidenceIssueBacklogError(RuntimeError):
    """Raised when issue-backlog generation cannot safely continue."""


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
    """Load a JSON file with backlog-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidenceIssueBacklogError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceIssueBacklogError(f"invalid JSON in {path}: {exc}") from exc


def file_record(path: Path, repo_root: Path) -> dict[str, Any]:
    """Return a deterministic file record for a required input or output."""
    if not path.is_file():
        raise ReleaseEvidenceIssueBacklogError(
            f"missing required file: {normalize_path(path, repo_root)}"
        )
    return {
        "path": normalize_path(path, repo_root),
        "sha256": evidence_checker.file_sha256(path),
        "size_bytes": path.stat().st_size,
    }


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ReleaseEvidenceIssueBacklogError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceIssueBacklogError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise ReleaseEvidenceIssueBacklogError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a JSON boolean."""
    if not isinstance(value, bool):
        raise ReleaseEvidenceIssueBacklogError(f"{path} must be a boolean")
    return value


def load_packet_index(path: Path) -> dict[str, Any]:
    """Load and minimally validate the release evidence packet index."""
    packet = require_dict(load_json(path), str(path))
    schema = require_string(packet.get("schema_version"), "packet.schema_version")
    if schema != PACKET_SCHEMA:
        raise ReleaseEvidenceIssueBacklogError(
            f"packet.schema_version must be {PACKET_SCHEMA}"
        )
    require_list(packet.get("rows"), "packet.rows")
    policy = require_dict(packet.get("policy"), "packet.policy")
    if require_bool(policy.get("template_only_can_complete"), "packet.policy.template_only_can_complete"):
        raise ReleaseEvidenceIssueBacklogError(
            "packet policy cannot allow template-only completion"
        )
    return packet


def requirement_title(row: dict[str, Any]) -> str:
    """Build a deterministic GitHub issue title for a packet row."""
    phase = require_string(row.get("phase"), "row.phase")
    requirement_id = require_string(row.get("requirement_id"), "row.requirement_id")
    prefix = PHASE_ISSUE_PREFIXES.get(phase)
    if prefix is None:
        raise ReleaseEvidenceIssueBacklogError(f"unknown packet row phase: {phase}")
    return f"{prefix}: {requirement_id}"


def suggested_labels(row: dict[str, Any]) -> list[str]:
    """Return deterministic labels for an evidence issue."""
    phase = require_string(row.get("phase"), "row.phase")
    phase_slug = PHASE_LABEL_SLUGS.get(phase)
    if phase_slug is None:
        raise ReleaseEvidenceIssueBacklogError(f"unknown packet row phase: {phase}")
    return [*COMMON_LABELS, phase_slug]


def completion_gate(row: dict[str, Any]) -> str:
    """Describe the completion rule for one issue."""
    retained = require_dict(
        row.get("retained_artifact_expectation"),
        "row.retained_artifact_expectation",
    )
    template = require_dict(row.get("template"), "row.template")
    template_path = require_string(template.get("path"), "row.template.path")
    retained_path = require_string(
        retained.get("path"),
        "row.retained_artifact_expectation.path",
    )
    return (
        "This issue can close only after reviewed retained evidence replaces or "
        f"supplements `{template_path}` and is referenced from "
        "`release-artifacts/latest/public-beta-evidence.json`. The retained "
        f"artifact expectation is `{retained_path}`. Template-only evidence "
        "cannot complete the row."
    )


def issue_body(row: dict[str, Any]) -> str:
    """Build issue body Markdown suitable for creating a GitHub issue."""
    phase_label = require_string(row.get("phase_label"), "row.phase_label")
    requirement_id = require_string(row.get("requirement_id"), "row.requirement_id")
    status = require_string(row.get("status"), "row.status")
    evidence_posture = require_string(
        row.get("evidence_posture"),
        "row.evidence_posture",
    )
    owner_reviewer_posture = require_string(
        row.get("owner_reviewer_posture"),
        "row.owner_reviewer_posture",
    )
    blocker = require_dict(row.get("blocker_report"), "row.blocker_report")
    blocker_path = require_string(blocker.get("path"), "row.blocker_report.path")
    blocker_section = require_string(
        blocker.get("section"),
        "row.blocker_report.section",
    )
    blocker_marker = require_string(
        blocker.get("requirement_marker"),
        "row.blocker_report.requirement_marker",
    )
    template = require_dict(row.get("template"), "row.template")
    template_path = require_string(template.get("path"), "row.template.path")
    retained = require_dict(
        row.get("retained_artifact_expectation"),
        "row.retained_artifact_expectation",
    )
    retained_path = require_string(
        retained.get("path"),
        "row.retained_artifact_expectation.path",
    )
    retained_notes = require_string(
        retained.get("operator_notes"),
        "row.retained_artifact_expectation.operator_notes",
    )
    template_only_can_complete = require_bool(
        row.get("template_only_can_complete"),
        "row.template_only_can_complete",
    )
    validation_commands = [
        require_string(command, f"row.validation_commands[{command_index}]")
        for command_index, command in enumerate(
            require_list(row.get("validation_commands"), "row.validation_commands")
        )
    ]
    command_lines = "\n".join(f"- `{command}`" for command in validation_commands)
    return "\n".join(
        [
            "## Evidence Requirement",
            "",
            f"- Phase: `{phase_label}`",
            f"- Requirement ID: `{requirement_id}`",
            f"- Current status: `{status}`",
            f"- Evidence posture: {evidence_posture}",
            f"- Owner/reviewer posture: {owner_reviewer_posture}",
            "",
            "## Source Links",
            "",
            (
                f"- Blocker report: `{blocker_path}` / "
                f"{blocker_section} / {blocker_marker}"
            ),
            f"- Evidence template: `{template_path}`",
            f"- Retained artifact placeholder: `{retained_path}`",
            "",
            "## Required Evidence",
            "",
            f"- Retained artifact expectation: {retained_notes}",
            f"- Completion gate: {completion_gate(row)}",
            f"- Template-only can complete: `{str(template_only_can_complete).lower()}`",
            "",
            "## Validation",
            "",
            command_lines,
            "",
            "## Non-Goals",
            "",
            "- Do not commit private keys, RPC URLs, API keys, signer-service secrets, or unreleased drop payloads.",
            "- Do not change public-beta or production-release readiness claims without reviewed retained evidence.",
            "- Do not use the checked template alone as completion evidence.",
            "",
            "## Acceptance Criteria",
            "",
            "- Reviewed retained evidence exists and is no-secret or properly redacted.",
            "- The evidence manifest references the retained evidence path and hash.",
            "- The blocker report no longer lists this row as incomplete, or the remaining status is explicitly risk-accepted.",
            "- All validation commands above pass.",
        ]
    )


def backlog_entries(packet: dict[str, Any]) -> list[dict[str, Any]]:
    """Build one issue-ready backlog entry for every incomplete packet row."""
    entries: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for row_index, raw_row in enumerate(
        require_list(packet.get("rows"), "packet.rows")
    ):
        row = require_dict(raw_row, f"packet.rows[{row_index}]")
        phase = require_string(row.get("phase"), f"packet.rows[{row_index}].phase")
        phase_slug = PHASE_LABEL_SLUGS.get(phase)
        if phase_slug is None:
            raise ReleaseEvidenceIssueBacklogError(f"unknown packet row phase: {phase}")
        requirement_id = require_string(
            row.get("requirement_id"),
            f"packet.rows[{row_index}].requirement_id",
        )
        status = require_string(row.get("status"), f"packet.rows[{row_index}].status")
        if status not in shared_report.STATUS_ORDER:
            raise ReleaseEvidenceIssueBacklogError(
                f"unknown packet row status for {phase}:{requirement_id}: {status}"
            )
        if status not in INCOMPLETE_STATUSES:
            continue
        template_only_can_complete = require_bool(
            row.get("template_only_can_complete"),
            f"packet.rows[{row_index}].template_only_can_complete",
        )
        if template_only_can_complete:
            raise ReleaseEvidenceIssueBacklogError(
                f"template-only completion is not allowed for {phase}:{requirement_id}"
            )
        entry_id = f"{phase_slug}-{requirement_id.replace('_', '-')}"
        if entry_id in seen_ids:
            raise ReleaseEvidenceIssueBacklogError(f"duplicate backlog entry: {entry_id}")
        seen_ids.add(entry_id)
        entries.append(
            {
                "entry_id": entry_id,
                "phase": phase,
                "phase_label": require_string(
                    row.get("phase_label"),
                    f"packet.rows[{row_index}].phase_label",
                ),
                "requirement_id": requirement_id,
                "status": status,
                "evidence_posture": require_string(
                    row.get("evidence_posture"),
                    f"packet.rows[{row_index}].evidence_posture",
                ),
                "title": requirement_title(row),
                "suggested_labels": suggested_labels(row),
                "owner": require_string(row.get("owner"), f"packet.rows[{row_index}].owner"),
                "template_owner": require_string(
                    row.get("template_owner"),
                    f"packet.rows[{row_index}].template_owner",
                ),
                "reviewer": require_string(
                    row.get("reviewer"),
                    f"packet.rows[{row_index}].reviewer",
                ),
                "review_status": require_string(
                    row.get("review_status"),
                    f"packet.rows[{row_index}].review_status",
                ),
                "owner_reviewer_posture": require_string(
                    row.get("owner_reviewer_posture"),
                    f"packet.rows[{row_index}].owner_reviewer_posture",
                ),
                "blocker_report": require_dict(
                    row.get("blocker_report"),
                    f"packet.rows[{row_index}].blocker_report",
                ),
                "template": require_dict(
                    row.get("template"),
                    f"packet.rows[{row_index}].template",
                ),
                "retained_artifact_expectation": require_dict(
                    row.get("retained_artifact_expectation"),
                    f"packet.rows[{row_index}].retained_artifact_expectation",
                ),
                "validation_commands": [
                    require_string(command, f"packet.rows[{row_index}].validation_commands")
                    for command in require_list(
                        row.get("validation_commands"),
                        f"packet.rows[{row_index}].validation_commands",
                    )
                ],
                "template_only_can_complete": False,
                "completion_gate": completion_gate(row),
                "issue_body": issue_body(row),
            }
        )
    return entries


def status_summary(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Build entry counts by release phase."""
    summaries: list[dict[str, Any]] = []
    for phase in (PUBLIC_BETA_PHASE, PRODUCTION_PHASE):
        phase_entries = [entry for entry in entries if entry["phase"] == phase]
        counts = {status: 0 for status in shared_report.STATUS_ORDER}
        for entry in phase_entries:
            counts[entry["status"]] += 1
        summaries.append(
            {
                "phase": phase,
                "label": PHASE_LABELS[phase],
                "entry_count": len(phase_entries),
                "counts": counts,
            }
        )
    return summaries


def build_backlog(
    repo_root: Path,
    packet_index_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> dict[str, Any]:
    """Build the machine-readable issue backlog."""
    resolved_packet = resolve_repo_path(repo_root, packet_index_path)
    resolved_json_output = resolve_repo_path(repo_root, json_output_path)
    resolved_markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    packet = load_packet_index(resolved_packet)
    entries = backlog_entries(packet)
    release_version = require_string(
        packet.get("release_version"),
        "packet.release_version",
    )
    release_source = require_dict(packet.get("release_source"), "packet.release_source")
    status = require_dict(packet.get("status"), "packet.status")
    policy = require_dict(packet.get("policy"), "packet.policy")
    no_secrets = require_bool(policy.get("no_secrets"), "packet.policy.no_secrets")
    backlog = {
        "schema_version": BACKLOG_SCHEMA,
        "generated_by": f"scripts/{SCRIPT_NAME}:{GENERATOR_VERSION}",
        "generator_version": GENERATOR_VERSION,
        "outputs": {
            "json": normalize_path(resolved_json_output, repo_root),
            "markdown": normalize_path(resolved_markdown_output, repo_root),
        },
        "source": {
            "packet_index": file_record(resolved_packet, repo_root),
        },
        "release_version": release_version,
        "release_source": release_source,
        "status": status,
        "policy": {
            "no_secrets": no_secrets,
            "template_only_can_complete": False,
            "auto_create_issues": False,
            "completion_rule": (
                "Backlog entries are issue preparation material only. A row can "
                "be complete only when reviewed retained evidence is referenced "
                "in release-artifacts/latest/public-beta-evidence.json."
            ),
        },
        "status_summary": status_summary(entries),
        "entries": entries,
        "validation_commands": sorted(
            {
                command
                for entry in entries
                for command in entry["validation_commands"]
            }
            | {
                "python scripts/test_release_evidence_issue_backlog.py",
                "python scripts/generate_release_evidence_issue_backlog.py --check",
            }
        ),
    }
    try:
        evidence_checker.scan_for_secret_like_data(backlog)
    except evidence_checker.PublicBetaEvidenceError as exc:
        raise ReleaseEvidenceIssueBacklogError(
            f"generated backlog contains secret-like data: {exc}"
        ) from exc
    return backlog


def json_text(value: Any) -> str:
    """Return deterministic JSON text."""
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def markdown_for_backlog(backlog: dict[str, Any]) -> str:
    """Build the human-readable issue backlog."""
    lines = [
        "# Release Evidence Issue Backlog",
        "",
        (
            "This generated backlog turns every incomplete public-beta and "
            "production-release evidence packet row into an issue-ready entry. "
            "It contains no secrets, does not create GitHub issues automatically, "
            "and does not change readiness claims."
        ),
        "",
        "The committed baseline remains blocked for public beta and production release.",
        "",
        "## Backlog Metadata",
        "",
        shared_report.markdown_table(
            ["Field", "Value"],
            [
                ["Generated by", f"`{backlog['generated_by']}`"],
                ["Generator version", f"`{backlog['generator_version']}`"],
                ["JSON output", f"`{backlog['outputs']['json']}`"],
                ["Markdown output", f"`{backlog['outputs']['markdown']}`"],
                ["Packet index", f"`{backlog['source']['packet_index']['path']}`"],
                ["Release version", f"`{backlog['release_version']}`"],
                ["Public beta status", f"`{backlog['status'][PUBLIC_BETA_PHASE]}`"],
                [
                    "Production release status",
                    f"`{backlog['status'][PRODUCTION_PHASE]}`",
                ],
                [
                    "Template-only can complete",
                    f"`{str(backlog['policy']['template_only_can_complete']).lower()}`",
                ],
                [
                    "Auto-create issues",
                    f"`{str(backlog['policy']['auto_create_issues']).lower()}`",
                ],
            ],
        ),
        "",
        "## Status Summary",
        "",
        shared_report.markdown_table(
            [
                "Phase",
                "Issue Entries",
                "Missing",
                "Pending",
                "Blocked",
                "Accepted Risk",
                "Not Applicable",
                "Complete",
            ],
            [
                [
                    summary["label"],
                    summary["entry_count"],
                    summary["counts"]["missing"],
                    summary["counts"]["pending"],
                    summary["counts"]["blocked"],
                    summary["counts"]["accepted_risk"],
                    summary["counts"]["not_applicable"],
                    summary["counts"]["complete"],
                ]
                for summary in backlog["status_summary"]
            ],
        ),
        "",
        "## Issue Entries",
        "",
    ]
    for entry in backlog["entries"]:
        lines.extend(
            [
                f"### {entry['title']}",
                "",
                shared_report.markdown_table(
                    ["Field", "Value"],
                    [
                        ["Entry ID", f"`{entry['entry_id']}`"],
                        ["Phase", f"`{entry['phase_label']}`"],
                        ["Requirement ID", f"`{entry['requirement_id']}`"],
                        ["Status", f"`{entry['status']}`"],
                        ["Evidence posture", entry["evidence_posture"]],
                        ["Suggested labels", ", ".join(f"`{label}`" for label in entry["suggested_labels"])],
                        ["Owner/reviewer posture", entry["owner_reviewer_posture"]],
                        [
                            "Blocker report",
                            (
                                f"`{entry['blocker_report']['path']}` / "
                                f"{entry['blocker_report']['section']}"
                            ),
                        ],
                        ["Template", f"`{entry['template']['path']}`"],
                        [
                            "Retained artifact expectation",
                            (
                                f"`{entry['retained_artifact_expectation']['path']}`; "
                                f"{entry['retained_artifact_expectation']['operator_notes']}"
                            ),
                        ],
                        [
                            "Template-only can complete",
                            f"`{str(entry['template_only_can_complete']).lower()}`",
                        ],
                    ],
                ),
                "",
                "Suggested issue body:",
                "",
                "```md",
                entry["issue_body"],
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
                [[f"`{command}`"] for command in backlog["validation_commands"]],
            ),
        ]
    )
    return "\n".join(lines) + "\n"


def build_outputs(
    repo_root: Path,
    packet_index_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> tuple[str, str]:
    """Return deterministic JSON and Markdown output text."""
    backlog = build_backlog(
        repo_root,
        packet_index_path,
        json_output_path,
        markdown_output_path,
    )
    return json_text(backlog), markdown_for_backlog(backlog)


def write_outputs(
    repo_root: Path,
    packet_index_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> list[Path]:
    """Generate and write the committed backlog outputs."""
    json_output = resolve_repo_path(repo_root, json_output_path)
    markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    json_output_text, markdown_output_text = build_outputs(
        repo_root,
        packet_index_path,
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
    packet_index_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> int:
    """Check that committed backlog outputs match generated output."""
    json_output = resolve_repo_path(repo_root, json_output_path)
    markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    missing = [
        output
        for output in (json_output, markdown_output)
        if not output.exists()
    ]
    if missing:
        for output in missing:
            print(f"missing {normalize_path(output, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_evidence_issue_backlog.py` "
            "and commit the regenerated files",
            file=sys.stderr,
        )
        return 1

    expected_json, expected_markdown = build_outputs(
        repo_root,
        packet_index_path,
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
            "run `python scripts/generate_release_evidence_issue_backlog.py` "
            "and commit the regenerated files",
            file=sys.stderr,
        )
        return 1
    print("release evidence issue backlog is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--packet-index", type=Path, default=DEFAULT_PACKET_INDEX)
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
                args.packet_index,
                args.json_output,
                args.markdown_output,
            )
        written = write_outputs(
            repo_root,
            args.packet_index,
            args.json_output,
            args.markdown_output,
        )
    except ReleaseEvidenceIssueBacklogError as exc:
        print(f"release evidence issue backlog generation failed: {exc}", file=sys.stderr)
        return 1
    for path in written:
        print(normalize_path(path, repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
