#!/usr/bin/env python3
"""Validate the repository pull request template."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_TEMPLATE = Path(".github/PULL_REQUEST_TEMPLATE.md")

REQUIRED_HEADINGS = [
    (2, "Summary"),
    (2, "Roadmap"),
    (2, "Security And Maturity"),
    (2, "Review Routing"),
    (2, "Validation"),
    (2, "Release Impact"),
    (2, "Release Notes"),
    (2, "Reviewer Notes"),
]

REQUIRED_FIELDS = [
    "Gate:",
    "Roadmap issue or ADR:",
    "Non-roadmap rationale:",
    "Scope type: docs / tooling / tests / contracts / deployment / release artifacts",
    "Scope intentionally excluded:",
    "Local commands run:",
    "Test impact:",
    "Docs impact:",
    "Release-impacting paths changed: yes / no",
    "External behavior impact: none / ABI / events / metadata schema / authorization schema / role or admin semantics / deployment artifacts / release evidence",
    "Generated artifact impact: none / regenerated / intentionally unchanged with rationale",
    "Release evidence impact: none / public-beta evidence / production-release evidence / blocker reports / manifest or checksum coverage",
    "Version impact: none / patch / minor / major / operational",
    "Breaking-change approval issue or ADR:",
    "Known limitations or follow-up issues:",
]

REQUIRED_CHECKBOXES = [
    "This PR does not claim production readiness unless the relevant launch gate evidence is merged.",
    "Security-sensitive behavior is identified, or this PR is docs/tooling-only.",
    "New external behavior is documented.",
    "No private keys, signer material, RPC secrets, or production deployment secrets are included.",
    "Protocol review is required or not applicable.",
    "Security review is required or not applicable.",
    "Tooling/CI review is required or not applicable.",
    "Docs review is required or not applicable.",
    "`make check` or platform equivalent passed.",
    "Tests were added/updated, or this PR explains why no tests are required.",
    "CI is green.",
    "Bot and human review comments are resolved or explicitly accepted with rationale.",
    "`CHANGELOG.md` has a `## Unreleased` section with at least one non-placeholder bullet, or this PR has no release-impacting paths.",
    "Release-impacting ABI, metadata schema, authorization, role, deployment, or artifact changes are documented in `CHANGELOG.md`.",
    "Generated release artifacts, manifests, checksums, blocker reports, or evidence packets were regenerated and checked, or this PR explains why they are intentionally unchanged.",
    "Breaking changes are explicitly approved by a linked issue or ADR, or this PR has no breaking changes.",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
CHECKBOX_RE = re.compile(r"^- \[ \]\s+(.+?)\s*$", re.MULTILINE)
FENCED_CODE_RE = re.compile(r"^```[^\n]*\n(.*?)^```", re.MULTILINE | re.DOTALL)


class PullRequestTemplateError(ValueError):
    """Raised when the pull request template misses required structure."""


def markdown_headings(text: str) -> list[tuple[int, str]]:
    """Extract Markdown headings as level/title pairs."""
    headings = []
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.append((level, title))
    return headings


def checkbox_labels(text: str) -> set[str]:
    """Return PR-template checkbox labels."""
    return {match.group(1).strip() for match in CHECKBOX_RE.finditer(text)}


def fenced_code_blocks(text: str) -> list[str]:
    """Return fenced code block bodies."""
    return [match.group(1) for match in FENCED_CODE_RE.finditer(text)]


def missing_items(text: str, items: list[str]) -> list[str]:
    """Return exact required strings absent from the template."""
    return [item for item in items if item not in text]


def validate_required_headings(headings: list[tuple[int, str]]) -> None:
    """Validate required heading presence, order, and uniqueness."""
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        raise PullRequestTemplateError(
            "PR template is missing required headings: "
            + ", ".join(missing_headings)
        )

    duplicate_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if headings.count((level, title)) > 1
    ]
    if duplicate_headings:
        raise PullRequestTemplateError(
            "PR template has duplicate required headings: "
            + ", ".join(duplicate_headings)
        )

    positions = [headings.index(heading) for heading in REQUIRED_HEADINGS]
    if positions != sorted(positions):
        expected = ", ".join(f"{'#' * level} {title}" for level, title in REQUIRED_HEADINGS)
        raise PullRequestTemplateError(
            "PR template required headings are out of order; expected: " + expected
        )


def validate_pr_template(path: Path) -> None:
    """Validate pull request template structure and release-impact prompts."""
    if not path.is_file():
        raise PullRequestTemplateError(f"missing pull request template: {path}")

    text = path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    validate_required_headings(headings)

    missing_required_fields = missing_items(text, REQUIRED_FIELDS)
    if missing_required_fields:
        raise PullRequestTemplateError(
            "PR template is missing required fields: "
            + ", ".join(missing_required_fields)
        )

    labels = checkbox_labels(text)
    missing_required_checkboxes = [
        checkbox for checkbox in REQUIRED_CHECKBOXES if checkbox not in labels
    ]
    if missing_required_checkboxes:
        raise PullRequestTemplateError(
            "PR template is missing required checkboxes: "
            + ", ".join(missing_required_checkboxes)
        )

    code_blocks = fenced_code_blocks(text)
    if not any("# command and result summary" in block for block in code_blocks):
        raise PullRequestTemplateError(
            "PR template must keep the validation command evidence code block"
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse PR-template checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the PR-template checker CLI."""
    args = parse_args(argv or [])
    try:
        validate_pr_template(args.template)
    except PullRequestTemplateError as exc:
        print(f"PR template check failed: {exc}", file=sys.stderr)
        return 1

    print("PR template is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
