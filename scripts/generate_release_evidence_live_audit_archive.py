#!/usr/bin/env python3
"""Generate a deterministic release evidence live audit report archive index."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import check_release_evidence_live_audit_markdown as markdown_checker
import check_release_evidence_live_audit_report as report_checker
import generate_public_beta_blocker_report as shared_report


ARCHIVE_SCHEMA = "6529stream.release-evidence-live-audit-report-archive.v1"
GENERATOR_VERSION = "1"
SCRIPT_NAME = Path(__file__).name

DEFAULT_JSON_OUTPUT = Path(
    "release-artifacts/latest/release-evidence-live-audit-report-archive.json"
)
DEFAULT_MARKDOWN_OUTPUT = Path(
    "release-artifacts/latest/release-evidence-live-audit-report-archive.md"
)
DEFAULT_ARCHIVE_DIR = Path("release-artifacts/evidence/live-audit-reports")
DEFAULT_TEMPLATE_JSON = report_checker.DEFAULT_REPORT_JSON
DEFAULT_TEMPLATE_MARKDOWN = markdown_checker.DEFAULT_REPORT_MARKDOWN


class ReleaseEvidenceLiveAuditArchiveError(RuntimeError):
    """Raised when the live audit archive index cannot be generated."""


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    """Resolve a path relative to the repository root."""
    return path if path.is_absolute() else repo_root / path


def normalize_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path when possible."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def require_relative_path(path: Path, field: str) -> str:
    """Require a repository-relative POSIX path string."""
    path_text = path.as_posix()
    if path.is_absolute() or "\\" in path_text or ".." in Path(path_text).parts:
        raise ReleaseEvidenceLiveAuditArchiveError(
            f"{field} must be a repository-relative path"
        )
    return path_text


def resolve_existing_file(repo_root: Path, path: Path, field: str) -> Path:
    """Resolve a repository-relative file path through the report checker."""
    try:
        return report_checker.resolve_repo_file(
            repo_root,
            require_relative_path(path, field),
            field,
        )
    except report_checker.ReleaseEvidenceLiveAuditReportError as exc:
        raise ReleaseEvidenceLiveAuditArchiveError(str(exc)) from exc


def file_record(path: Path, repo_root: Path) -> dict[str, Any]:
    """Return a deterministic file record with a bare SHA-256 digest."""
    if not path.is_file():
        raise ReleaseEvidenceLiveAuditArchiveError(
            f"missing required file: {normalize_path(path, repo_root)}"
        )
    return {
        "path": normalize_path(path, repo_root),
        "sha256": report_checker.file_sha256_hex(path),
        "size_bytes": path.stat().st_size,
    }


def default_report_pairs(repo_root: Path, archive_dir: Path) -> list[dict[str, Any]]:
    """Return the committed template pair plus any retained operator reports."""
    pairs = [
        {
            "archive_id": "template",
            "record_type": "template",
            "report_json": DEFAULT_TEMPLATE_JSON,
            "report_markdown": DEFAULT_TEMPLATE_MARKDOWN,
        }
    ]
    resolved_archive_dir = resolve_repo_path(repo_root, archive_dir)
    if not resolved_archive_dir.exists():
        return pairs
    if not resolved_archive_dir.is_dir():
        raise ReleaseEvidenceLiveAuditArchiveError(
            f"archive path is not a directory: {normalize_path(resolved_archive_dir, repo_root)}"
        )
    for report_json in sorted(resolved_archive_dir.glob("*.json")):
        report_markdown = report_json.with_suffix(".md")
        relative_json = Path(normalize_path(report_json, repo_root))
        relative_markdown = Path(normalize_path(report_markdown, repo_root))
        pairs.append(
            {
                "archive_id": report_json.stem,
                "record_type": "retained_operator_report",
                "report_json": relative_json,
                "report_markdown": relative_markdown,
            }
        )
    return pairs


def cli_report_pairs(args: argparse.Namespace, repo_root: Path) -> list[dict[str, Any]]:
    """Return report pairs from CLI arguments or default discovery."""
    if args.report_json is None and args.report_md is None:
        return default_report_pairs(repo_root, args.archive_dir)
    if args.report_json is None or args.report_md is None:
        raise ReleaseEvidenceLiveAuditArchiveError(
            "--report-json and --report-md must be supplied together"
        )
    if len(args.report_json) != len(args.report_md):
        raise ReleaseEvidenceLiveAuditArchiveError(
            "--report-json and --report-md must have the same count"
        )
    pairs = []
    for report_json, report_md in zip(args.report_json, args.report_md):
        pairs.append(
            {
                "archive_id": report_json.stem,
                "record_type": "operator_supplied",
                "report_json": report_json,
                "report_markdown": report_md,
            }
        )
    return pairs


def validation_commands(row: dict[str, Any]) -> list[str]:
    """Return validation commands for one archive row."""
    report_json = row["report_json"]["path"]
    report_markdown = row["report_markdown"]["path"]
    return [
        f"python scripts/check_release_evidence_live_audit_report.py --report-json {report_json}",
        (
            "python scripts/check_release_evidence_live_audit_markdown.py "
            f"--report-json {report_json} --report-md {report_markdown}"
        ),
        "python scripts/generate_release_evidence_live_audit_archive.py --check",
    ]


def validate_report_pair(
    repo_root: Path,
    schema_path: Path,
    raw_pair: dict[str, Any],
) -> dict[str, Any]:
    """Validate one retained JSON/Markdown report pair and return an archive row."""
    archive_id = report_checker.require_string(raw_pair.get("archive_id"), "archive_id")
    record_type = report_checker.require_string(raw_pair.get("record_type"), "record_type")
    if record_type not in {"template", "retained_operator_report", "operator_supplied"}:
        raise ReleaseEvidenceLiveAuditArchiveError(
            f"archive {archive_id} has unsupported record_type: {record_type}"
        )
    report_json_path = raw_pair.get("report_json")
    report_markdown_path = raw_pair.get("report_markdown")
    if not isinstance(report_json_path, Path) or not isinstance(report_markdown_path, Path):
        raise ReleaseEvidenceLiveAuditArchiveError(
            f"archive {archive_id} paths must be pathlib.Path values"
        )

    report_json = resolve_existing_file(repo_root, report_json_path, "report_json")
    report_markdown = resolve_existing_file(
        repo_root,
        report_markdown_path,
        "report_markdown",
    )
    try:
        report = markdown_checker.load_valid_report(repo_root, schema_path, report_json)
        markdown_checker.validate_markdown_parity(
            report,
            markdown_checker.read_markdown(report_markdown),
        )
    except (
        markdown_checker.ReleaseEvidenceLiveAuditMarkdownError,
        report_checker.ReleaseEvidenceLiveAuditReportError,
    ) as exc:
        raise ReleaseEvidenceLiveAuditArchiveError(
            f"archive {archive_id} report validation failed: {exc}"
        ) from exc

    row = {
        "archive_id": archive_id,
        "record_type": record_type,
        "repo": report["repo"],
        "generated_at": report["generated_at"],
        "readiness_claim": report["readiness_claim"],
        "validation_status": report["validation"]["status"],
        "profile_count": report["validation"]["profile_count"],
        "profiles": [
            {
                "profile": profile["profile"],
                "snapshot_path": profile["snapshot_path"],
                "snapshot_sha256": profile["snapshot_sha256"],
                "export_status": profile["export_status"],
                "checker_status": profile["checker_status"],
            }
            for profile in report["profiles"]
        ],
        "report_json": file_record(report_json, repo_root),
        "report_markdown": file_record(report_markdown, repo_root),
    }
    row["validation_commands"] = validation_commands(row)
    return row


def build_archive(
    repo_root: Path,
    schema_path: Path,
    report_pairs: list[dict[str, Any]],
    json_output_path: Path,
    markdown_output_path: Path,
    archive_dir: Path,
) -> dict[str, Any]:
    """Build the archive index object."""
    resolved_schema = resolve_existing_file(repo_root, schema_path, "schema")
    rows = []
    seen_ids: set[str] = set()
    for raw_pair in report_pairs:
        row = validate_report_pair(repo_root, resolved_schema, raw_pair)
        archive_id = row["archive_id"]
        if archive_id in seen_ids:
            raise ReleaseEvidenceLiveAuditArchiveError(
                f"duplicate archive_id: {archive_id}"
            )
        seen_ids.add(archive_id)
        rows.append(row)
    rows.sort(key=lambda row: row["archive_id"])

    archive = {
        "schema_version": ARCHIVE_SCHEMA,
        "generated_by": f"scripts/{SCRIPT_NAME}:{GENERATOR_VERSION}",
        "generator_version": GENERATOR_VERSION,
        "outputs": {
            "json": normalize_path(resolve_repo_path(repo_root, json_output_path), repo_root),
            "markdown": normalize_path(
                resolve_repo_path(repo_root, markdown_output_path),
                repo_root,
            ),
        },
        "source": {
            "report_schema": file_record(resolved_schema, repo_root),
            "template_json": normalize_path(
                resolve_repo_path(repo_root, DEFAULT_TEMPLATE_JSON),
                repo_root,
            ),
            "template_markdown": normalize_path(
                resolve_repo_path(repo_root, DEFAULT_TEMPLATE_MARKDOWN),
                repo_root,
            ),
            "optional_archive_dir": normalize_path(
                resolve_repo_path(repo_root, archive_dir),
                repo_root,
            ),
        },
        "policy": {
            "no_secrets": True,
            "network_access_in_ci": False,
            "readiness_claim": "blocked",
            "readiness_warning": markdown_checker.auditor.READINESS_WARNING,
            "no_secret_notice": markdown_checker.auditor.NO_SECRET_NOTICE,
        },
        "report_count": len(rows),
        "rows": rows,
        "validation_commands": sorted(
            {command for row in rows for command in row["validation_commands"]}
            | {"python scripts/test_release_evidence_live_audit_archive.py"}
        ),
    }
    try:
        report_checker.scan_for_secret_like_data(archive, "archive")
    except report_checker.ReleaseEvidenceLiveAuditReportError as exc:
        raise ReleaseEvidenceLiveAuditArchiveError(
            f"generated archive contains secret-like data: {exc}"
        ) from exc
    return archive


def json_text(value: Any) -> str:
    """Return deterministic JSON text."""
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def markdown_for_archive(archive: dict[str, Any]) -> str:
    """Return the human-readable archive index."""
    policy = archive["policy"]
    source = archive["source"]
    lines = [
        "# Release Evidence Live Audit Report Archive",
        "",
        (
            "This generated index records retained no-secret live audit report "
            "JSON/Markdown bundles and their validation commands. It does not "
            "change public-beta or production-release readiness claims."
        ),
        "",
        "The committed baseline remains blocked for public beta and production release.",
        "",
        "## Archive Metadata",
        "",
        shared_report.markdown_table(
            ["Field", "Value"],
            [
                ["Generated by", f"`{archive['generated_by']}`"],
                ["Generator version", f"`{archive['generator_version']}`"],
                ["JSON output", f"`{archive['outputs']['json']}`"],
                ["Markdown output", f"`{archive['outputs']['markdown']}`"],
                ["Report schema", f"`{source['report_schema']['path']}`"],
                ["Template JSON", f"`{source['template_json']}`"],
                ["Template Markdown", f"`{source['template_markdown']}`"],
                ["Optional archive dir", f"`{source['optional_archive_dir']}`"],
                ["Report count", archive["report_count"]],
                ["No secrets", f"`{str(policy['no_secrets']).lower()}`"],
                [
                    "Network access in CI",
                    f"`{str(policy['network_access_in_ci']).lower()}`",
                ],
                ["Readiness claim", f"`{policy['readiness_claim']}`"],
            ],
        ),
        "",
        "## Archive Rows",
        "",
        shared_report.markdown_table(
            [
                "Archive ID",
                "Type",
                "Generated At",
                "Profiles",
                "Validation",
                "JSON",
                "Markdown",
                "Validation Commands",
            ],
            [
                [
                    f"`{row['archive_id']}`",
                    f"`{row['record_type']}`",
                    f"`{row['generated_at']}`",
                    ", ".join(f"`{profile['profile']}`" for profile in row["profiles"]),
                    f"`{row['validation_status']}`",
                    f"`{row['report_json']['path']}`",
                    f"`{row['report_markdown']['path']}`",
                    "; ".join(f"`{command}`" for command in row["validation_commands"]),
                ]
                for row in archive["rows"]
            ],
        ),
        "",
        "## Validation Commands",
        "",
        shared_report.markdown_table(
            ["Command"],
            [[f"`{command}`"] for command in archive["validation_commands"]],
        ),
    ]
    return "\n".join(lines) + "\n"


def build_outputs(
    repo_root: Path,
    schema_path: Path,
    report_pairs: list[dict[str, Any]],
    json_output_path: Path,
    markdown_output_path: Path,
    archive_dir: Path,
) -> tuple[str, str]:
    """Return deterministic JSON and Markdown outputs."""
    archive = build_archive(
        repo_root,
        schema_path,
        report_pairs,
        json_output_path,
        markdown_output_path,
        archive_dir,
    )
    return json_text(archive), markdown_for_archive(archive)


def write_outputs(
    repo_root: Path,
    schema_path: Path,
    report_pairs: list[dict[str, Any]],
    json_output_path: Path,
    markdown_output_path: Path,
    archive_dir: Path,
) -> list[Path]:
    """Generate and write archive index outputs."""
    json_output = resolve_repo_path(repo_root, json_output_path)
    markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    json_output_text, markdown_output_text = build_outputs(
        repo_root,
        schema_path,
        report_pairs,
        json_output_path,
        markdown_output_path,
        archive_dir,
    )
    json_output.parent.mkdir(parents=True, exist_ok=True)
    markdown_output.parent.mkdir(parents=True, exist_ok=True)
    json_output.write_text(json_output_text, encoding="utf-8", newline="\n")
    markdown_output.write_text(markdown_output_text, encoding="utf-8", newline="\n")
    return [json_output, markdown_output]


def check_outputs(
    repo_root: Path,
    schema_path: Path,
    report_pairs: list[dict[str, Any]],
    json_output_path: Path,
    markdown_output_path: Path,
    archive_dir: Path,
) -> int:
    """Check committed archive index outputs for drift."""
    json_output = resolve_repo_path(repo_root, json_output_path)
    markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    missing = [path for path in (json_output, markdown_output) if not path.exists()]
    if missing:
        for path in missing:
            print(f"missing {normalize_path(path, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_evidence_live_audit_archive.py` "
            "and commit the regenerated files",
            file=sys.stderr,
        )
        return 1

    expected_json, expected_markdown = build_outputs(
        repo_root,
        schema_path,
        report_pairs,
        json_output_path,
        markdown_output_path,
        archive_dir,
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
            "run `python scripts/generate_release_evidence_live_audit_archive.py` "
            "and commit the regenerated files",
            file=sys.stderr,
        )
        return 1
    print("release evidence live audit archive is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--schema", type=Path, default=report_checker.DEFAULT_SCHEMA)
    parser.add_argument("--archive-dir", type=Path, default=DEFAULT_ARCHIVE_DIR)
    parser.add_argument("--report-json", type=Path, action="append")
    parser.add_argument("--report-md", type=Path, action="append")
    parser.add_argument("--json-output", type=Path, default=DEFAULT_JSON_OUTPUT)
    parser.add_argument("--markdown-output", type=Path, default=DEFAULT_MARKDOWN_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the archive index generator."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        pairs = cli_report_pairs(args, repo_root)
        if args.check:
            return check_outputs(
                repo_root,
                args.schema,
                pairs,
                args.json_output,
                args.markdown_output,
                args.archive_dir,
            )
        written = write_outputs(
            repo_root,
            args.schema,
            pairs,
            args.json_output,
            args.markdown_output,
            args.archive_dir,
        )
    except ReleaseEvidenceLiveAuditArchiveError as exc:
        print(
            f"release evidence live audit archive generation failed: {exc}",
            file=sys.stderr,
        )
        return 1
    for path in written:
        print(normalize_path(path, repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
