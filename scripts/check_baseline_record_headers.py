#!/usr/bin/env python3
"""Validate the spec-policy baseline-record header across non-inventory docs.

docs/spec-policy.md (Specification Inventory) pins a literal header block
(ADR 0012 decision T9) that every Markdown document under docs/ outside
the spec inventory must carry directly beneath its title, excluding ADRs
under docs/adr/, the policy itself, the open-question register, and index
or README files. This checker is the release checker named by that
section and tracked by the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING], baseline-record header
row). Documents superseded by a specific spec may extend the header
paragraph after the pinned sentence ends.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import ascii_safe, read_text  # noqa: E402


SPEC_POLICY_PATH = Path("docs/spec-policy.md")
INVENTORY_HEADING = "## Specification Inventory"
ALWAYS_EXCLUDED_NAMES = {"README.md", "readme.md", "index.md", "INDEX.md"}
ALWAYS_EXCLUDED_DOCS = {
    Path("docs/spec-policy.md"),
    Path("docs/spec-open-questions.md"),
}
REQUIRED_HEADER = (
    "Baseline record — not a specification. This document describes "
    "as-built or operational state; the normative target is the "
    "specification set indexed in docs/spec-policy.md, and where this "
    "document conflicts with a specification home, the specification "
    "wins."
)


class BaselineRecordHeaderError(RuntimeError):
    """Raised when a non-inventory doc lacks the pinned header block."""


def inventory_documents(repo_root: Path) -> set[Path]:
    """Parse the spec-policy inventory table into repo-relative doc paths."""
    text = read_text(repo_root / SPEC_POLICY_PATH)
    start = text.find(INVENTORY_HEADING)
    if start == -1:
        raise BaselineRecordHeaderError(
            f"missing heading in {SPEC_POLICY_PATH}: {INVENTORY_HEADING}"
        )
    section = text[start:]
    docs_root = (repo_root / "docs").resolve()
    documents: set[Path] = set()
    for match in re.finditer(r"\]\(([^)#]+\.md)\)", section):
        target = ((repo_root / SPEC_POLICY_PATH).parent / match.group(1)).resolve()
        try:
            documents.add(Path("docs") / target.relative_to(docs_root))
        except ValueError:
            continue
    return documents


def checked_documents(repo_root: Path) -> list[Path]:
    """Return the non-inventory docs/ Markdown set requiring the header."""
    inventory = inventory_documents(repo_root)
    checked: list[Path] = []
    for path in sorted((repo_root / "docs").rglob("*.md")):
        relative = path.relative_to(repo_root)
        if relative.parts[:2] == ("docs", "adr"):
            continue
        if path.name in ALWAYS_EXCLUDED_NAMES:
            continue
        if relative in ALWAYS_EXCLUDED_DOCS or relative in inventory:
            continue
        checked.append(relative)
    return checked


def normalize_header_paragraph(paragraph: str) -> str:
    """Normalize a header paragraph for literal-block comparison.

    Markdown links collapse to their link text, inline backticks are
    stripped, and whitespace runs collapse, so the pinned block matches
    both plain-text and linked renderings of the spec-policy reference.
    """
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", paragraph)
    text = text.replace("`", "")
    return " ".join(text.split())


def header_failure(repo_root: Path, document: Path) -> str | None:
    """Return a failure reason when a doc lacks the pinned header block."""
    lines = read_text(repo_root / document).splitlines()
    title_index = next(
        (index for index, line in enumerate(lines) if line.startswith("# ")),
        None,
    )
    if title_index is None:
        return "missing Markdown title"
    cursor = title_index + 1
    while cursor < len(lines) and not lines[cursor].strip():
        cursor += 1
    paragraph_lines: list[str] = []
    while cursor < len(lines) and lines[cursor].strip():
        paragraph_lines.append(lines[cursor].strip())
        cursor += 1
    if not paragraph_lines:
        return "no paragraph beneath the title"
    normalized = normalize_header_paragraph(" ".join(paragraph_lines))
    if not normalized.startswith(REQUIRED_HEADER):
        return "first paragraph beneath the title is not the pinned baseline-record block"
    return None


def validate_repo(repo_root: Path) -> None:
    failures: list[str] = []
    for document in checked_documents(repo_root):
        reason = header_failure(repo_root, document)
        if reason is not None:
            failures.append(f"{document.as_posix()}: {reason}")
    if failures:
        details = "\n  - ".join(failures)
        raise BaselineRecordHeaderError(
            f"baseline-record header check failed for {len(failures)} document(s) "
            f"(docs/spec-policy.md pinned block):\n  - {details}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root to validate.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validate_repo(args.repo_root)
    except BaselineRecordHeaderError as exc:
        print(ascii_safe(f"baseline-record header check failed: {exc}"), file=sys.stderr)
        return 1
    print("baseline-record headers are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
