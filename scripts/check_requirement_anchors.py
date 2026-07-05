#!/usr/bin/env python3
"""Validate bracketed requirement-anchor resolution across the docs tree.

docs/spec-policy.md (Requirement Anchors) pins stable bracketed anchors
on or directly beneath normative headings, and the anchor-resolution row
of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]) requires that every
bracketed anchor cited anywhere in the set resolves to exactly one home
section — anchor backfill complete, no orphan citations.

Two definition tiers keep the check precise across the corpus's lead-in
styles:

1. Resolution (backfill) uses permissive definition shapes: a heading
   containing the anchor, or a line where the anchor is followed by an
   optional qualifier and a colon introducing its rule block (the
   ``Requirements [X]:`` and ``Lead-in [X] (citation):`` conventions,
   wrapped parentheticals included). A cited anchor with no such home
   anywhere fails.
2. Exactly-one-home uses strict definition shapes only — heading-embedded
   anchors and colon-terminated lead-in lines followed by structured
   content — deduplicated per heading section, so a re-application phrase
   inside prose never reads as a second home.

Open-question markers (``OQ-``) and baseline-era roadmap tracker ids
(``P0-``/``P1-``/``P2-``) are excluded by the shared anchor grammar.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import (  # noqa: E402
    ANCHOR_RE,
    EXCLUDED_ANCHOR_PREFIXES,
    ascii_safe,
    markdown_docs,
    read_text,
    strip_fenced_code,
    strip_inline_code,
    strip_inline_links,
)


HEADING_LINE_RE = re.compile(r"^#{1,6}\s+\S")
STRICT_LEAD_IN_RE = re.compile(
    r"^[^\[\]]{0,160}\[(?P<anchor>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\]"
    r"(?:\s*\([^()]*\))?\s*:\s*$"
)
STRUCTURED_FOLLOWER_RE = re.compile(r"^\s*$|^\s*(\d+\.|[-*]\s|\||```|~~~)")


class RequirementAnchorError(RuntimeError):
    """Raised when requirement anchors do not resolve to exactly one home."""


def _line_anchors(line: str) -> list[str]:
    return [
        match.group("anchor")
        for match in ANCHOR_RE.finditer(line)
        if not match.group("anchor").startswith(EXCLUDED_ANCHOR_PREFIXES)
    ]


BARE_ANCHOR_LINE_RE = re.compile(
    r"^\[(?P<anchor>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\][.:]?\s*$"
)
TITLE_LEAD_IN_RE = re.compile(
    r"^[A-Z`][^.!?]*\[(?P<anchor>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\][.:]?\s*$"
)


def permissive_definitions(text: str) -> set[str]:
    """Anchors with any home-shaped occurrence in one document."""
    lines = strip_fenced_code(text).splitlines()
    defined: set[str] = set()
    for line in lines:
        stripped = line.strip()
        if HEADING_LINE_RE.match(line):
            defined.update(_line_anchors(line))
            continue
        bare = BARE_ANCHOR_LINE_RE.match(stripped)
        if bare and not bare.group("anchor").startswith(EXCLUDED_ANCHOR_PREFIXES):
            defined.add(bare.group("anchor"))
            continue
        title = TITLE_LEAD_IN_RE.match(stripped)
        if title and not title.group("anchor").startswith(EXCLUDED_ANCHOR_PREFIXES):
            defined.add(title.group("anchor"))
        for match in ANCHOR_RE.finditer(line):
            anchor = match.group("anchor")
            if anchor.startswith(EXCLUDED_ANCHOR_PREFIXES):
                continue
            tail = line[match.end() :]
            prefix = line[: match.start()].strip()
            # An anchor introducing its own rule block: optional short
            # qualifier or (possibly line-wrapped) parenthetical, then a
            # colon. ``[X]: ...``, ``[X] (ADR ...):``, ``[X] (ADR ...\n``.
            if re.match(r"(?:\s*\([^()]*\))?\s*:", tail) or re.match(
                r"\s*\([^()]*$", tail
            ):
                defined.add(anchor)
            # ``Requirements [X]. This section is the normative home ...``
            elif tail.startswith(".") and re.fullmatch(r"[A-Z`][^.!?]{0,80}", prefix):
                defined.add(anchor)
    return defined


LIST_ITEM_RE = re.compile(r"^\s*(\d+\.|[-*])\s")


def strict_definitions(path: Path, text: str) -> list[tuple[str, int, int]]:
    """Return (anchor, line, section_index) strict definition sites."""
    lines = strip_fenced_code(text).splitlines()
    section_index = 0
    sites: list[tuple[str, int, int]] = []
    for index, line in enumerate(lines):
        if HEADING_LINE_RE.match(line):
            section_index += 1
            for anchor in _line_anchors(line):
                sites.append((anchor, index + 1, section_index))
            continue
        previous = lines[index - 1] if index > 0 else ""
        paragraph_initial = not previous.strip() or bool(HEADING_LINE_RE.match(previous))
        if not paragraph_initial or LIST_ITEM_RE.match(line):
            continue
        stripped = line.strip()
        bare = BARE_ANCHOR_LINE_RE.match(stripped)
        candidate = bare or STRICT_LEAD_IN_RE.match(stripped)
        if candidate is None:
            continue
        anchor = candidate.group("anchor")
        if anchor.startswith(EXCLUDED_ANCHOR_PREFIXES):
            continue
        follower = lines[index + 1] if index + 1 < len(lines) else ""
        if bare or STRUCTURED_FOLLOWER_RE.match(follower):
            sites.append((anchor, index + 1, section_index))
    return sites


def citation_sites(text: str) -> list[tuple[str, int]]:
    """Return (anchor, line) citations in one doc, code and links stripped."""
    prose = strip_inline_links(strip_inline_code(strip_fenced_code(text)))
    citations: list[tuple[str, int]] = []
    for match in ANCHOR_RE.finditer(prose):
        anchor = match.group("anchor")
        if anchor.startswith(EXCLUDED_ANCHOR_PREFIXES):
            continue
        citations.append((anchor, prose.count("\n", 0, match.start()) + 1))
    return citations


def validate_repo(repo_root: Path) -> tuple[int, int]:
    """Validate anchor resolution; return (anchor_count, citation_count)."""
    resolvable: set[str] = set()
    strict: dict[str, list[tuple[Path, int, int]]] = defaultdict(list)
    citations: list[tuple[Path, int, str]] = []
    for path in markdown_docs(repo_root):
        relative = path.relative_to(repo_root)
        text = read_text(path)
        resolvable.update(permissive_definitions(text))
        for anchor, line, section in strict_definitions(relative, text):
            strict[anchor].append((relative, line, section))
        for anchor, line in citation_sites(text):
            citations.append((relative, line, anchor))

    failures: list[str] = []
    for anchor, sites in sorted(strict.items()):
        homes = sorted({(path.as_posix(), section) for path, _, section in sites})
        if len(homes) > 1:
            locations = ", ".join(f"{path.as_posix()}:{line}" for path, line, _ in sites)
            failures.append(
                f"anchor [{anchor}] is defined in {len(homes)} home sections: {locations}"
            )

    unresolved: dict[str, list[str]] = defaultdict(list)
    for path, line, anchor in citations:
        if anchor not in resolvable and anchor not in strict:
            unresolved[anchor].append(f"{path.as_posix()}:{line}")
    for anchor, sites in sorted(unresolved.items()):
        shown = ", ".join(sites[:3])
        suffix = f" (+{len(sites) - 3} more)" if len(sites) > 3 else ""
        failures.append(
            f"anchor [{anchor}] is cited but has no home section: {shown}{suffix}"
        )

    if failures:
        details = "\n  - ".join(failures)
        raise RequirementAnchorError(
            f"requirement anchor check failed with {len(failures)} failure(s):"
            f"\n  - {details}"
        )
    return len(resolvable | set(strict)), len(citations)


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
        anchor_count, citation_count = validate_repo(args.repo_root)
    except RequirementAnchorError as exc:
        print(ascii_safe(f"requirement anchor check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        "requirement anchors are current: "
        f"{anchor_count} anchors resolve for {citation_count} citations"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
