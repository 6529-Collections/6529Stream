#!/usr/bin/env python3
"""Validate the external audit finding workflow."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_WORKFLOW = Path("docs/audit-finding-workflow.md")
DEFAULT_ISSUE_TEMPLATE = Path(".github/ISSUE_TEMPLATE/audit_finding.yml")

REQUIRED_HEADINGS = [
    (1, "External Audit Finding Workflow"),
    (2, "Intake Channels"),
    (2, "Finding Record"),
    (2, "Triage"),
    (2, "Remediation Path"),
    (2, "Retest And Closure"),
    (2, "Accepted Risk"),
    (2, "Evidence Handoff"),
    (2, "Required Updates"),
    (2, "Validation Commands"),
    (2, "Non-Goals"),
]

REQUIRED_PHRASES = [
    "pre-audit local baseline",
    "not a completed audit report",
    "not a production-readiness claim",
    "Use private reporting through [`SECURITY.md`](../SECURITY.md)",
    "public-safe audit issue form",
    "stable finding ID",
    "Critical, High, Medium, Low, Informational, or Undetermined",
    "New finding, Remediation planned, Remediation in progress",
    "Ready for retest, Retest passed, Accepted risk proposed",
    "Accepted risk approved, or Duplicate or out of scope",
    "audited commit and audit scope",
    "Disclosure posture",
    "direct regression test",
    "negative test",
    "invariant, fork, deployment rehearsal, or retained evidence coverage",
    "Accepted risk does not close a public-beta or production-release blocker",
    "Template-only evidence cannot complete either row",
    "No private keys, RPC credentials, signer material, auditor portal tokens",
]

REQUIRED_LINK_TARGETS = [
    "SECURITY.md",
    ".github/ISSUE_TEMPLATE/audit_finding.yml",
    "docs/audit-package.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
    "release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md",
    "release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/release-notes.md",
    "CHANGELOG.md",
    "ops/EXECUTION_BACKLOG.md",
]

REQUIRED_COMMANDS = [
    "make check",
    "python scripts/test_audit_finding_workflow.py",
    "python scripts/check_audit_finding_workflow.py",
    "python scripts/test_issue_templates.py",
    "python scripts/check_issue_templates.py",
    "python scripts/test_audit_package.py",
    "python scripts/check_audit_package.py",
    "python scripts/check_release_readiness.py",
    "python scripts/check_release_evidence_issue_closure.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
    "python scripts/check_changelog.py",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_TEMPLATE_IDS = [
    "severity",
    "status",
    "affected_component",
    "finding_summary",
    "threat_model",
    "impact",
    "remediation",
    "required_tests",
    "references",
    "checks",
]

REQUIRED_TEMPLATE_OPTIONS = [
    "Critical",
    "High",
    "Medium",
    "Low",
    "Informational",
    "Undetermined",
    "New finding",
    "Remediation planned",
    "Remediation in progress",
    "Ready for retest",
    "Retest passed",
    "Accepted risk proposed",
    "Accepted risk approved",
    "Duplicate or out of scope",
]

REQUIRED_TEMPLATE_CHECKS = [
    "This issue is safe for public tracking, or sensitive details are withheld.",
    "Required remediation includes tests or explicit accepted-risk rationale.",
    "Release notes, risk register, and post-audit remediation evidence impact were considered.",
    "No private keys, RPC credentials, signer material, or non-redacted exploit artifacts are included.",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCED_CODE_RE = re.compile(r"^```[^\n]*\n(.*?)^```", re.MULTILINE | re.DOTALL)


class AuditFindingWorkflowError(ValueError):
    """Raised when the audit finding workflow is missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise AuditFindingWorkflowError(
            f"linked path escapes repository: {path}"
        ) from exc


def markdown_headings(text: str) -> list[tuple[int, str]]:
    """Extract Markdown headings as level/title pairs."""
    headings = []
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.append((level, title))
    return headings


def validate_required_headings(headings: list[tuple[int, str]]) -> None:
    """Validate required heading presence, order, and uniqueness."""
    missing = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing:
        raise AuditFindingWorkflowError(
            "audit finding workflow is missing required headings: "
            + ", ".join(missing)
        )

    duplicates = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if headings.count((level, title)) > 1
    ]
    if duplicates:
        raise AuditFindingWorkflowError(
            "audit finding workflow has duplicate required headings: "
            + ", ".join(duplicates)
        )

    positions = [headings.index(heading) for heading in REQUIRED_HEADINGS]
    if positions != sorted(positions):
        expected = ", ".join(
            f"{'#' * level} {title}" for level, title in REQUIRED_HEADINGS
        )
        raise AuditFindingWorkflowError(
            "audit finding workflow required headings are out of order; expected: "
            + expected
        )


def normalized_link_target(raw_target: str) -> str | None:
    """Return a local Markdown link path without anchors or query strings."""
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if "://" in target or target.startswith("mailto:"):
        return None

    path_part = target.split("#", 1)[0].split("?", 1)[0]
    if not path_part:
        return None
    return path_part


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
    """Collect existing repository-relative file links from Markdown text."""
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        target = normalized_link_target(match.group(1))
        if target is None:
            continue

        target_path = Path(target)
        if not target_path.is_absolute():
            target_path = document_path.parent / target_path

        resolved = target_path.resolve()
        relative = normalize_repo_path(resolved, repo_root)
        if not resolved.exists():
            missing.append(relative)
            continue
        links.add(relative)

    if missing:
        raise AuditFindingWorkflowError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases that are absent from text, case-insensitively."""
    normalized_text = " ".join(text.lower().split())
    return [phrase for phrase in phrases if phrase.lower() not in normalized_text]


def fenced_command_lines(text: str) -> set[str]:
    """Return non-empty lines presented inside fenced Markdown code blocks."""
    command_lines = set()
    for match in FENCED_CODE_RE.finditer(text):
        for line in match.group(1).splitlines():
            stripped = line.strip()
            if stripped:
                command_lines.add(stripped)
    return command_lines


def missing_commands(text: str, commands: list[str]) -> list[str]:
    """Return required commands absent from fenced code blocks."""
    command_lines = fenced_command_lines(text)
    return [command for command in commands if command not in command_lines]


def validate_issue_template(template_path: Path) -> None:
    """Validate the workflow's source issue template still exposes required fields."""
    if not template_path.is_file():
        raise AuditFindingWorkflowError(f"missing audit finding issue template: {template_path}")

    text = template_path.read_text(encoding="utf-8")
    missing_ids = [f"id: {field_id}" for field_id in REQUIRED_TEMPLATE_IDS if f"id: {field_id}" not in text]
    if missing_ids:
        raise AuditFindingWorkflowError(
            "audit finding issue template is missing required fields: "
            + ", ".join(missing_ids)
        )

    missing_options = [option for option in REQUIRED_TEMPLATE_OPTIONS if f"- {option}" not in text]
    if missing_options:
        raise AuditFindingWorkflowError(
            "audit finding issue template is missing required options: "
            + ", ".join(missing_options)
        )

    missing_checks = [check for check in REQUIRED_TEMPLATE_CHECKS if check not in text]
    if missing_checks:
        raise AuditFindingWorkflowError(
            "audit finding issue template is missing required closure checks: "
            + ", ".join(missing_checks)
        )


def validate_workflow(repo_root: Path, workflow_path: Path, template_path: Path) -> None:
    """Validate the workflow document and source issue-template alignment."""
    if not workflow_path.is_file():
        relative = normalize_repo_path(workflow_path, repo_root)
        raise AuditFindingWorkflowError(f"missing workflow: {relative}")

    text = workflow_path.read_text(encoding="utf-8")
    validate_required_headings(markdown_headings(text))

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise AuditFindingWorkflowError(
            "audit finding workflow is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    links = linked_repo_paths(repo_root, workflow_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise AuditFindingWorkflowError(
            "audit finding workflow is missing required links: "
            + ", ".join(missing_targets)
        )

    missing_required_commands = missing_commands(text, REQUIRED_COMMANDS)
    if missing_required_commands:
        raise AuditFindingWorkflowError(
            "audit finding workflow is missing required commands: "
            + ", ".join(missing_required_commands)
        )

    validate_issue_template(template_path)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--workflow", type=Path, default=DEFAULT_WORKFLOW)
    parser.add_argument("--issue-template", type=Path, default=DEFAULT_ISSUE_TEMPLATE)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the audit finding workflow checker CLI."""
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    workflow_path = args.workflow
    issue_template = args.issue_template
    if not workflow_path.is_absolute():
        workflow_path = repo_root / workflow_path
    if not issue_template.is_absolute():
        issue_template = repo_root / issue_template

    try:
        validate_workflow(repo_root, workflow_path.resolve(), issue_template.resolve())
    except AuditFindingWorkflowError as exc:
        print(f"audit finding workflow check failed: {exc}", file=sys.stderr)
        return 1

    print("audit finding workflow is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
