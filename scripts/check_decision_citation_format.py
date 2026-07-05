#!/usr/bin/env python3
"""Validate ADR decision citation shapes and cited-id existence.

docs/spec-policy.md (Decision Citation Format) pins the citation shape
``(ADR <number> decision <id>)`` with per-ADR id prefixes — D (0010),
R (0011), T (0012), U (0013), V (0014), W (0015) — and ADR 0009's plain
numerals exempt by construction (ADR 0014 decision V9). This checker is
the citation-format row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]): every decision
citation in the docs tree must carry well-formed ids with the owning
ADR's shape, and every cited id must exist in the cited ADR. Conjoined
lists (``decisions U6 and U7``) validate per id. Template placeholders
containing ``<`` (for example ``decision D<n>``) are format
descriptions, not citations, and are skipped.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import (  # noqa: E402
    ascii_safe,
    markdown_docs,
    read_text,
    strip_fenced_code,
)


ADR_DIR = Path("docs/adr")
ADR_ID_PREFIXES = {
    "0009": "",
    "0010": "D",
    "0011": "R",
    "0012": "T",
    "0013": "U",
    "0014": "V",
    "0015": "W",
}
CITATION_RE = re.compile(r"\bADR\s+(?P<adr>\d{4})\s+(?P<word>decisions?)\s+")
ID_TOKEN_RE = re.compile(r"(?P<prefix>[A-Z]?)(?P<major>\d+)(?:\.(?P<minor>\d+))?")
DECISION_HEADING_RE = re.compile(r"^###\s+(?P<id>[A-Z]\d+)\.\s", re.MULTILINE)
NUMBERED_ITEM_RE = re.compile(r"^(?P<number>\d+)\.\s", re.MULTILINE)


class DecisionCitationError(RuntimeError):
    """Raised when decision citations drift from the pinned format."""


def adr_decision_index(repo_root: Path) -> dict[str, dict[str, set[int]]]:
    """Map ADR number -> base decision id -> numbered sub-item set.

    ADR 0009 decisions are plain top-level numerals, indexed under the
    empty base id. Lettered ADRs declare ``### <ID>. Title`` headings with
    top-level numbered items as their dotted sub-decisions.
    """
    index: dict[str, dict[str, set[int]]] = {}
    for path in sorted((repo_root / ADR_DIR).glob("[0-9][0-9][0-9][0-9]-*.md")):
        adr_number = path.name[:4]
        text = strip_fenced_code(read_text(path))
        decisions: dict[str, set[int]] = {}
        headings = list(DECISION_HEADING_RE.finditer(text))
        for position, match in enumerate(headings):
            end = (
                headings[position + 1].start()
                if position + 1 < len(headings)
                else len(text)
            )
            section = text[match.end() : end]
            next_heading = re.search(r"^#{1,3}\s", section, re.MULTILINE)
            if next_heading is not None:
                section = section[: next_heading.start()]
            items = {
                int(item.group("number"))
                for item in NUMBERED_ITEM_RE.finditer(section)
            }
            decisions[match.group("id")] = items
        if not decisions:
            items = {
                int(item.group("number")) for item in NUMBERED_ITEM_RE.finditer(text)
            }
            if items:
                decisions[""] = items
        index[adr_number] = decisions
    return index


def parse_id_list(text: str, start: int) -> tuple[list[str], bool]:
    """Parse the id list following ``decision``/``decisions``.

    Returns the parsed ids and whether the trailing token was a template
    placeholder (id containing ``<``).
    """
    ids: list[str] = []
    cursor = start
    while True:
        remainder = text[cursor:]
        stripped = remainder.lstrip()
        offset = len(remainder) - len(stripped)
        if stripped.startswith("<") or re.match(r"[A-Z]?<", stripped):
            return ids, True
        match = ID_TOKEN_RE.match(stripped)
        if match is None:
            return ids, False
        ids.append(match.group(0))
        cursor += offset + match.end()
        connective = re.match(r"(\s*,\s*and\s+|\s*,\s*|\s+and\s+)", text[cursor:])
        if connective is None:
            return ids, False
        lookahead = text[cursor + connective.end() :].lstrip()
        if not ID_TOKEN_RE.match(lookahead) and not lookahead.startswith("<"):
            return ids, False
        cursor += connective.end()


def validate_citation_ids(
    adr_number: str,
    ids: list[str],
    index: dict[str, dict[str, set[int]]],
) -> list[str]:
    """Return failure reasons for one citation's parsed id list."""
    failures: list[str] = []
    expected_prefix = ADR_ID_PREFIXES.get(adr_number)
    if expected_prefix is None:
        return [
            f"ADR {adr_number} has no pinned decision-id shape "
            "(docs/spec-policy.md Decision Citation Format)"
        ]
    decisions = index.get(adr_number, {})
    for decision_id in ids:
        match = ID_TOKEN_RE.fullmatch(decision_id)
        assert match is not None
        prefix = match.group("prefix")
        if prefix != expected_prefix:
            failures.append(
                f"decision id {decision_id!r} does not match the ADR "
                f"{adr_number} id shape "
                f"({expected_prefix + '<n>' if expected_prefix else 'plain numerals'})"
            )
            continue
        base = f"{prefix}{match.group('major')}" if prefix else ""
        known = decisions.get(base)
        if not prefix:
            numbered = decisions.get("", set())
            if int(match.group("major")) not in numbered:
                failures.append(
                    f"decision {decision_id} does not exist in ADR {adr_number}"
                )
            continue
        if known is None:
            failures.append(
                f"decision {decision_id} does not exist in ADR {adr_number} "
                f"(no {base} heading)"
            )
            continue
        minor = match.group("minor")
        if minor is not None and int(minor) not in known:
            failures.append(
                f"decision {decision_id} does not exist in ADR {adr_number} "
                f"({base} has no item {minor})"
            )
    return failures


def validate_document(path: Path, text: str, index: dict[str, dict[str, set[int]]]) -> list[str]:
    prose = strip_fenced_code(text)
    failures: list[str] = []
    for match in CITATION_RE.finditer(prose):
        ids, is_template = parse_id_list(prose, match.end())
        line = prose.count("\n", 0, match.start()) + 1
        location = f"{path.as_posix()}:{line}"
        if is_template and not ids:
            continue
        if not ids:
            failures.append(f"{location}: citation names no decision id")
            continue
        for reason in validate_citation_ids(match.group("adr"), ids, index):
            failures.append(f"{location}: {reason}")
    return failures


def validate_repo(repo_root: Path) -> None:
    index = adr_decision_index(repo_root)
    failures: list[str] = []
    for path in markdown_docs(repo_root):
        relative = path.relative_to(repo_root)
        failures.extend(validate_document(relative, read_text(path), index))
    if failures:
        details = "\n  - ".join(failures[:80])
        remaining = len(failures) - 80
        suffix = f"\n  ... and {remaining} more" if remaining > 0 else ""
        raise DecisionCitationError(
            f"decision citation check failed with {len(failures)} failure(s):"
            f"\n  - {details}{suffix}"
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
    except DecisionCitationError as exc:
        print(ascii_safe(f"decision citation format check failed: {exc}"), file=sys.stderr)
        return 1
    print("decision citations are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
