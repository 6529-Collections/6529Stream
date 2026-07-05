#!/usr/bin/env python3
"""Flag ``should`` inside Permanent/Replaceable sections gate rows cite.

The normative-language lint row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; spec-policy Normative
Language; [LCM-REVIEW-ENTRY] condition 1; ADR 0014 decision V9) enforces
the must-ward sweep: each flagged ``should`` inside a section whose
anchor the conformance matrix cites either becomes ``must`` or states
its deviation license explicitly.

Mechanics: the cited-anchor set is every bracketed anchor the matrix
cites; the linted sections are the heading- or lead-in-anchored sections
of the spec-inventory documents (the matrix itself excluded — it is the
gate document, not a Permanent/Replaceable surface) plus the designated
ADR 0004 governance home. A ``should`` whose sentence carries an
explicit deviation-license marker (a recorded rationale, deviation
record, or Operational-discretion statement) is treated as licensed;
every other occurrence is a candidate and fails the lint until the
sweep resolves it.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import (  # noqa: E402
    ANCHOR_RE,
    anchors_in_text,
    ascii_safe,
    iter_sections,
    read_text,
    strip_fenced_code,
)


MATRIX_PATH = Path("docs/launch-conformance-matrix.md")
SPEC_POLICY_PATH = Path("docs/spec-policy.md")
DESIGNATED_ADR_HOMES = (Path("docs/adr/0004-admin-governance.md"),)
SHOULD_RE = re.compile(r"\bshould(?:\s+not)?\b")
LEAD_IN_ANCHOR_RE = re.compile(
    r"^[^\[\]]{0,160}\[(?P<anchor>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\]"
    r"(?:\s*\([^()]*\))?\s*[:.]"
)
LICENSE_MARKERS = (
    "records the rationale",
    "recorded rationale",
    "rationale in the",
    "deviation",
    "operational discretion",
)
SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")


class NormativeLanguageError(RuntimeError):
    """Raised when unlicensed ``should`` candidates remain in cited sections."""


def inventory_documents(repo_root: Path) -> list[Path]:
    policy = read_text(repo_root / SPEC_POLICY_PATH)
    section = policy[policy.find("## Specification Inventory") :]
    documents: list[Path] = []
    for match in re.finditer(r"\]\(([^)#]+\.md)\)", section):
        path = ((repo_root / SPEC_POLICY_PATH).parent / match.group(1)).resolve()
        if not path.exists():
            continue
        relative = Path("docs") / path.relative_to((repo_root / "docs").resolve())
        if relative != MATRIX_PATH and relative not in documents:
            documents.append(relative)
    documents.extend(DESIGNATED_ADR_HOMES)
    return documents


def section_anchors(section_heading: str, section_text: str) -> set[str]:
    anchors = {match.group("anchor") for match in ANCHOR_RE.finditer(section_heading)}
    for line in section_text.splitlines()[:8]:
        lead_in = LEAD_IN_ANCHOR_RE.match(line.strip())
        if lead_in is not None:
            anchors.add(lead_in.group("anchor"))
    return anchors


def licensed(sentence: str) -> bool:
    lowered = sentence.lower()
    return any(marker in lowered for marker in LICENSE_MARKERS)


def should_candidates(path: Path, section_text: str, start_line: int) -> list[str]:
    candidates: list[str] = []
    body = strip_fenced_code(section_text)
    flat = " ".join(body.split())
    for sentence in SENTENCE_SPLIT_RE.split(flat):
        hits = SHOULD_RE.findall(sentence)
        if not hits or licensed(sentence):
            continue
        first_words = " ".join(sentence.split()[:8])
        candidates.append(
            f"{path.as_posix()}:{start_line}: unlicensed 'should' near "
            f"{first_words!r}"
        )
    return candidates


def validate_repo(repo_root: Path) -> tuple[int, int]:
    """Lint cited sections; return (section_count, cited_anchor_count)."""
    cited = set(anchors_in_text(read_text(repo_root / MATRIX_PATH)))
    if not cited:
        raise NormativeLanguageError("the matrix cites no anchors; scan misconfigured")
    failures: list[str] = []
    linted_sections = 0
    for document in inventory_documents(repo_root):
        text = read_text(repo_root / document)
        for section in iter_sections(document, text):
            anchors = section_anchors(section.heading, section.text)
            if not anchors & cited:
                continue
            linted_sections += 1
            failures.extend(
                should_candidates(document, section.text, section.start_line)
            )
    if failures:
        details = "\n  - ".join(failures)
        raise NormativeLanguageError(
            f"normative language lint flagged {len(failures)} unlicensed "
            f"'should' candidate(s) in gate-cited sections:\n  - {details}"
        )
    return linted_sections, len(cited)


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
        sections, cited = validate_repo(args.repo_root)
    except NormativeLanguageError as exc:
        print(ascii_safe(f"normative language lint failed: {exc}"), file=sys.stderr)
        return 1
    print(
        f"normative language is current: {sections} gate-cited sections linted "
        f"against {cited} cited anchors"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
