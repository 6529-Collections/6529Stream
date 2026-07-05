#!/usr/bin/env python3
"""Extract anchored ``must`` requirements and validate their mapping artifact.

The traceability extractor row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; [LCM-REVIEW-ENTRY]
condition 2; ADR 0010 decision D3.3) requires a machine-checked artifact
mapping every anchored ``must`` in every inventory document to at least
one named gate row, test, static check, or release artifact, with CI
failing on unmapped requirements.

Extraction grammar (deterministic over the spec inventory):

- an anchored section is a heading or lead-in carrying a bracketed
  requirement anchor;
- inside it, every top-level numbered item containing ``must`` is the
  requirement ``<ANCHOR>.<n>``;
- unnumbered paragraphs containing ``must`` aggregate per section as
  ``<ANCHOR>.p<k>`` in document order.

The mapping artifact does not exist yet; until it lands at
``release-artifacts/latest/requirement-traceability.json`` this checker
reports the extracted requirement inventory and passes with a note.
When present, the artifact schema is
``{"schema": "6529.stream.requirement-traceability.v1", "requirements":
[{"id", "document", "mappedTo": [{"kind": gate-row|test|static-check|
release-artifact, "name"}]}]}`` and the check is closed-world in both
directions: every extracted requirement is mapped at least once, and no
artifact entry names an unknown requirement.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import (  # noqa: E402
    ANCHOR_RE,
    ascii_safe,
    iter_sections,
    read_text,
    strip_fenced_code,
)


DEFAULT_ARTIFACT_PATH = Path("release-artifacts/latest/requirement-traceability.json")
SPEC_POLICY_PATH = Path("docs/spec-policy.md")
ARTIFACT_SCHEMA = "6529.stream.requirement-traceability.v1"
MAPPING_KINDS = {"gate-row", "test", "static-check", "release-artifact"}
MUST_RE = re.compile(r"\bmust(?:\s+not)?\b")
NUMBERED_ITEM_RE = re.compile(r"^(\d+)\.\s", re.MULTILINE)
LEAD_IN_ANCHOR_RE = re.compile(
    r"^[^\[\]]{0,160}\[(?P<anchor>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\]"
    r"(?:\s*\([^()]*\))?\s*[:.]"
)


class TraceabilityError(RuntimeError):
    """Raised when the traceability artifact drifts from the requirement set."""


def inventory_documents(repo_root: Path) -> list[Path]:
    policy = read_text(repo_root / SPEC_POLICY_PATH)
    section = policy[policy.find("## Specification Inventory") :]
    documents: list[Path] = []
    for match in re.finditer(r"\]\(([^)#]+\.md)\)", section):
        path = ((repo_root / SPEC_POLICY_PATH).parent / match.group(1)).resolve()
        if not path.is_file():
            continue
        relative = Path("docs") / path.relative_to((repo_root / "docs").resolve())
        if relative.parts[:2] == ("docs", "adr"):
            continue
        if relative not in documents:
            documents.append(relative)
    if not documents:
        raise TraceabilityError("no inventory documents resolved from spec-policy")
    return documents


def section_anchor(heading: str, body: str) -> str | None:
    for match in ANCHOR_RE.finditer(heading):
        return match.group("anchor")
    for line in body.splitlines()[:8]:
        lead_in = LEAD_IN_ANCHOR_RE.match(line.strip())
        if lead_in is not None:
            return lead_in.group("anchor")
    return None


def split_numbered_items(body: str) -> tuple[list[tuple[int, str]], str]:
    """Return (numbered items, residual prose) for one section body."""
    items: list[tuple[int, str]] = []
    residual: list[str] = []
    current: list[str] | None = None
    current_number = 0
    for line in body.splitlines():
        match = re.match(r"^(\d+)\.\s", line)
        if match:
            if current is not None:
                items.append((current_number, "\n".join(current)))
            current_number = int(match.group(1))
            current = [line]
        elif current is not None and (line.startswith(("   ", "\t")) or not line.strip()):
            current.append(line)
        else:
            if current is not None:
                items.append((current_number, "\n".join(current)))
                current = None
            residual.append(line)
    if current is not None:
        items.append((current_number, "\n".join(current)))
    return items, "\n".join(residual)


def extract_requirements(repo_root: Path) -> dict[str, str]:
    """Map requirement id -> owning document path."""
    requirements: dict[str, str] = {}
    for document in inventory_documents(repo_root):
        text = read_text(repo_root / document)
        for section in iter_sections(document, text):
            anchor = section_anchor(section.heading, section.text)
            if anchor is None:
                continue
            body = strip_fenced_code(section.text)
            items, residual = split_numbered_items(body)
            for number, item_text in items:
                if MUST_RE.search(item_text):
                    requirements.setdefault(
                        f"{anchor}.{number}", document.as_posix()
                    )
            paragraph_counter = 0
            for paragraph in re.split(r"\n\s*\n", residual):
                if MUST_RE.search(paragraph):
                    paragraph_counter += 1
                    requirements.setdefault(
                        f"{anchor}.p{paragraph_counter}", document.as_posix()
                    )
    if not requirements:
        raise TraceabilityError("extraction found no anchored must requirements")
    return requirements


def validate_artifact(repo_root: Path, path: Path, requirements: dict[str, str]) -> int:
    try:
        artifact = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise TraceabilityError(f"{path}: invalid JSON: {exc}") from exc
    if artifact.get("schema") != ARTIFACT_SCHEMA:
        raise TraceabilityError(
            f"artifact schema {artifact.get('schema')!r} is not {ARTIFACT_SCHEMA!r}"
        )
    entries = artifact.get("requirements", [])
    failures: list[str] = []
    mapped_ids: set[str] = set()
    for entry in entries:
        requirement_id = entry.get("id", "<missing>")
        mapped_ids.add(requirement_id)
        if requirement_id not in requirements:
            failures.append(
                f"{requirement_id}: artifact entry for an unknown requirement"
            )
            continue
        mappings = entry.get("mappedTo", [])
        if not mappings:
            failures.append(f"{requirement_id}: unmapped requirement")
        for mapping in mappings:
            if mapping.get("kind") not in MAPPING_KINDS or not mapping.get("name"):
                failures.append(
                    f"{requirement_id}: mapping must carry a kind in "
                    f"{sorted(MAPPING_KINDS)} and a name"
                )
    for missing in sorted(set(requirements) - mapped_ids):
        failures.append(
            f"{missing} ({requirements[missing]}): anchored must with no "
            "traceability entry"
        )
    if failures:
        shown = failures[:60]
        remaining = len(failures) - len(shown)
        suffix = f"\n  ... and {remaining} more" if remaining > 0 else ""
        raise TraceabilityError(
            f"traceability failed with {len(failures)} failure(s):\n  - "
            + "\n  - ".join(shown)
            + suffix
        )
    return len(entries)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root to validate.",
    )
    parser.add_argument(
        "--artifact",
        type=Path,
        default=None,
        help=(
            "Traceability artifact override (default: "
            "release-artifacts/latest/requirement-traceability.json)."
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        requirements = extract_requirements(args.repo_root)
    except TraceabilityError as exc:
        print(ascii_safe(f"traceability check failed: {exc}"), file=sys.stderr)
        return 1
    artifact_path = args.artifact or (args.repo_root / DEFAULT_ARTIFACT_PATH)
    if not artifact_path.exists():
        documents = len(set(requirements.values()))
        print(
            f"traceability check passes vacuously: {len(requirements)} anchored "
            f"must requirements extracted across {documents} inventory "
            "documents; the mapping artifact does not exist yet at "
            f"{DEFAULT_ARTIFACT_PATH.as_posix()} ([LCM-REVIEW-ENTRY] condition 2)"
        )
        return 0
    try:
        entry_count = validate_artifact(args.repo_root, artifact_path, requirements)
    except TraceabilityError as exc:
        print(ascii_safe(f"traceability check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        f"traceability is current: {len(requirements)} requirements covered by "
        f"{entry_count} artifact entries"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
