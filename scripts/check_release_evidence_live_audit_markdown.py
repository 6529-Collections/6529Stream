#!/usr/bin/env python3
"""Validate retained release evidence live audit Markdown report parity."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import audit_release_evidence_issue_snapshots as auditor
import check_release_evidence_live_audit_report as report_checker


DEFAULT_SCHEMA = report_checker.DEFAULT_SCHEMA
DEFAULT_REPORT_JSON = report_checker.DEFAULT_REPORT_JSON
DEFAULT_REPORT_MARKDOWN = Path(
    "release-artifacts/evidence/release-evidence-live-audit-report-template.md"
)


class ReleaseEvidenceLiveAuditMarkdownError(RuntimeError):
    """Raised when a retained Markdown live audit report is invalid."""


def read_markdown(path: Path) -> str:
    """Read Markdown without newline translation so CRLF drift is visible."""
    try:
        with path.open("r", encoding="utf-8", newline="") as handle:
            return handle.read()
    except FileNotFoundError as exc:
        raise ReleaseEvidenceLiveAuditMarkdownError(
            f"missing required file: {path}"
        ) from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ReleaseEvidenceLiveAuditMarkdownError(
            f"unable to read {path}: {exc}"
        ) from exc


def load_valid_report(
    repo_root: Path,
    schema_path: Path,
    report_path: Path,
) -> dict[str, Any]:
    """Validate the retained JSON report and return its object."""
    report_checker.validate_schema_document(report_checker.load_json(schema_path))
    report = report_checker.load_json(report_path)
    report_checker.validate_report_document(report, repo_root)
    return report_checker.require_dict(report, "report")


def validate_markdown_parity(report: dict[str, Any], markdown_text: str) -> None:
    """Validate retained Markdown is safe and exactly matches the JSON render."""
    report_checker.scan_for_secret_like_data(markdown_text, "markdown")
    expected = auditor.markdown_report(report)
    if markdown_text != expected:
        raise ReleaseEvidenceLiveAuditMarkdownError(
            "Markdown report does not match the canonical JSON report render"
        )


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--report-json", type=Path, default=DEFAULT_REPORT_JSON)
    parser.add_argument("--report-md", type=Path, default=DEFAULT_REPORT_MARKDOWN)
    return parser


def main(argv: list[str] | None = None) -> int:
    """Validate a retained live audit Markdown report."""
    parser = build_parser()
    args = parser.parse_args(argv)
    repo_root = args.repo_root.resolve()
    schema_path = report_checker.resolve_cli_path(repo_root, args.schema)
    report_path = report_checker.resolve_cli_path(repo_root, args.report_json)
    markdown_path = report_checker.resolve_cli_path(repo_root, args.report_md)

    try:
        report = load_valid_report(repo_root, schema_path, report_path)
        validate_markdown_parity(report, read_markdown(markdown_path))
    except (
        ReleaseEvidenceLiveAuditMarkdownError,
        report_checker.ReleaseEvidenceLiveAuditReportError,
    ) as exc:
        print(
            f"release evidence live audit Markdown check failed: {exc}",
            file=sys.stderr,
        )
        return 1

    print(f"release evidence live audit Markdown is valid: {args.report_md.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
