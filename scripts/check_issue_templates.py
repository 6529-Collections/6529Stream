#!/usr/bin/env python3
"""Validate GitHub issue templates for required OSS intake structure."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_TEMPLATE_DIR = Path(".github/ISSUE_TEMPLATE")

REQUIRED_TEMPLATES = {
    "bug_report.yml": {
        "name": "Bug report",
        "title": '"[Bug]: "',
        "labels": ["bug"],
        "ids": [
            "area",
            "problem",
            "current_behavior",
            "expected_behavior",
            "reproduction",
            "validation",
            "checks",
        ],
        "phrases": [
            "Do not report exploitable vulnerabilities here",
            "SECURITY.md",
            "not an exploitable vulnerability report",
        ],
    },
    "roadmap_item.yml": {
        "name": "Roadmap item",
        "title": '"[Roadmap]: "',
        "labels": ["roadmap"],
        "ids": [
            "priority",
            "severity",
            "gate",
            "work_type",
            "problem",
            "current_behavior",
            "intended_behavior",
            "code_changes",
            "tests",
            "docs",
            "acceptance",
            "dependencies",
        ],
        "phrases": [
            "Acceptance criteria",
            "Dependencies and blockers",
            "Required review lanes",
        ],
    },
    "integration_report.yml": {
        "name": "Integration report",
        "title": '"[Integration]: "',
        "labels": ["integration", "documentation"],
        "ids": [
            "consumer_surface",
            "environment",
            "source_version",
            "problem",
            "current_behavior",
            "expected_behavior",
            "reproduction",
            "affected_surfaces",
            "validation",
            "checks",
        ],
        "phrases": [
            "pre-audit",
            "not production-ready",
            "private keys",
            "RPC credentials",
            "WalletConnect project secrets",
            "React or web frontend",
            "Mobile or WalletConnect",
            "Electron or desktop",
            "Indexer or data pipeline",
            "Backend signing service",
            "ABIs",
            "event topic catalog",
            "EIP-712",
            "ERC-1271",
            "docs/integrations/README.md",
        ],
    },
    "audit_finding.yml": {
        "name": "Audit finding",
        "title": '"[Audit]: "',
        "labels": ["audit", "security"],
        "ids": [
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
        ],
        "phrases": [
            "Do not disclose exploitable vulnerabilities publicly",
            "SECURITY.md",
            "pre-audit",
            "not production-ready",
            "Critical",
            "Accepted risk approved",
            "Threat model and exploit preconditions",
            "Required tests and evidence",
            "private keys",
            "non-redacted exploit artifacts",
            "post-audit remediation evidence",
        ],
    },
    "release_evidence.yml": {
        "name": "Release evidence",
        "title": '"[Evidence]: "',
        "labels": ["evidence", "release"],
        "ids": [
            "release_phase",
            "requirement_id",
            "evidence_type",
            "retained_artifact",
            "evidence_summary",
            "reviewer_status",
            "redaction",
            "blocker_impact",
            "commands",
            "checks",
        ],
        "phrases": [
            "no-secret",
            "private keys",
            "production deployment secrets",
            "Local templates do not prove public-beta or production readiness",
            "Public beta",
            "Production release",
            "Requirement ID",
            "Retained artifact path",
            "Reviewer status",
            "Redaction and no-secret confirmation",
            "Blocker and report impact",
            "Generator and checker commands",
            "release manifest",
            "checksum",
        ],
    },
}

REQUIRED_CONFIG_PHRASES = [
    "blank_issues_enabled: false",
    "Private security report",
    "Integration documentation",
    "Release evidence status",
    "docs/integrations/README.md",
    "docs/public-beta-evidence.md",
    "ops/ROADMAP.md",
]

ID_RE = re.compile(r"^\s+id:\s+([A-Za-z0-9_-]+)\s*$", re.MULTILINE)
LABEL_BLOCK_RE = re.compile(r"^labels:\n(?P<body>(?:\s+-\s+.+\n)+)", re.MULTILINE)


class IssueTemplateError(ValueError):
    """Raised when GitHub issue templates are missing required structure."""


def normalize_text(text: str) -> str:
    """Collapse whitespace for case-insensitive phrase checks."""
    return " ".join(text.lower().split())


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases absent from a template."""
    normalized = normalize_text(text)
    return [phrase for phrase in phrases if phrase.lower() not in normalized]


def template_ids(text: str) -> set[str]:
    """Return issue-form field IDs from a template."""
    return set(ID_RE.findall(text))


def template_labels(text: str) -> set[str]:
    """Return labels from the top-level labels block."""
    match = LABEL_BLOCK_RE.search(text)
    if match is None:
        return set()
    labels = set()
    for line in match.group("body").splitlines():
        _, value = line.split("-", 1)
        labels.add(value.strip())
    return labels


def require_line(text: str, line: str, path: Path) -> None:
    """Require an exact YAML line in a template."""
    if line not in {candidate.strip() for candidate in text.splitlines()}:
        raise IssueTemplateError(f"{path} is missing line: {line}")


def validate_template(template_dir: Path, filename: str, requirements: dict[str, object]) -> None:
    """Validate one issue form."""
    path = template_dir / filename
    if not path.is_file():
        raise IssueTemplateError(f"missing issue template: {path}")

    text = path.read_text(encoding="utf-8")
    require_line(text, f"name: {requirements['name']}", path)
    require_line(text, f"title: {requirements['title']}", path)

    labels = template_labels(text)
    missing_labels = [
        label
        for label in requirements["labels"]  # type: ignore[index]
        if label not in labels
    ]
    if missing_labels:
        raise IssueTemplateError(
            f"{path} is missing required labels: " + ", ".join(missing_labels)
        )

    ids = template_ids(text)
    missing_ids = [
        field_id
        for field_id in requirements["ids"]  # type: ignore[index]
        if field_id not in ids
    ]
    if missing_ids:
        raise IssueTemplateError(
            f"{path} is missing required field ids: " + ", ".join(missing_ids)
        )

    missing_required_phrases = missing_phrases(
        text,
        requirements["phrases"],  # type: ignore[arg-type]
    )
    if missing_required_phrases:
        raise IssueTemplateError(
            f"{path} is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    if "validations:\n      required: true" not in text:
        raise IssueTemplateError(f"{path} must contain required field validations")


def validate_config(template_dir: Path) -> None:
    """Validate the issue-template config."""
    path = template_dir / "config.yml"
    if not path.is_file():
        raise IssueTemplateError(f"missing issue template config: {path}")

    text = path.read_text(encoding="utf-8")
    missing_required_phrases = missing_phrases(text, REQUIRED_CONFIG_PHRASES)
    if missing_required_phrases:
        raise IssueTemplateError(
            f"{path} is missing required content: "
            + ", ".join(missing_required_phrases)
        )


def validate_issue_templates(template_dir: Path) -> None:
    """Validate all required issue forms and config links."""
    for filename, requirements in REQUIRED_TEMPLATES.items():
        validate_template(template_dir, filename, requirements)
    validate_config(template_dir)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse issue-template checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template-dir", type=Path, default=DEFAULT_TEMPLATE_DIR)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the issue-template checker CLI."""
    args = parse_args(argv or [])
    try:
        validate_issue_templates(args.template_dir)
    except IssueTemplateError as exc:
        print(f"issue template check failed: {exc}", file=sys.stderr)
        return 1

    print("issue templates are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
