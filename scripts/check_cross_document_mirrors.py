#!/usr/bin/env python3
"""Validate the named cross-document mirror rows against their homes.

The cross-document mirror row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]) names four checker
surfaces comparing mirror tables and field inventories to their homes:

1. Attribution mirror ([MRR-ATTRIBUTION] rule 1 versus [AA-DISPLAY];
   ADR 0011 decision R7.6): every attribution field or vocabulary token
   the mirror names exists at the [AA-DISPLAY] home, with the retired
   flat fields (``attribution_status``/``artist_attestation_status``)
   named only as nonconformant.
2. Attestation mirror ([CMC-ARTIST-ATTESTATION] rule 1 versus
   [AA-ATTEST]; ADR 0011 decision R7): the metadata contract's
   ``StreamArtistAttestation`` field inventory matches the home's pinned
   struct field list name-for-name in order.
3. Record-family event mirror rows and the [CMC-RECONSTRUCTION] tooling
   row bind the machine-readable event catalog; until the v1 catalog
   exists ([LCM-REVIEW-ENTRY] condition 3) those legs pass vacuously
   with a note, and once present they are covered by the event-catalog
   checker.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import ascii_safe, read_text  # noqa: E402


MRR_PATH = Path("docs/metadata-router-and-renderer.md")
ARTIST_PATH = Path("docs/stream-artist-authority.md")
CMC_PATH = Path("docs/collection-metadata-contract.md")
EVENT_CATALOG_PATH = Path("release-artifacts/latest/event-catalog.json")
RETIRED_FLAT_FIELDS = {"attribution_status", "artist_attestation_status"}
SNAKE_TOKEN_RE = re.compile(r"[a-z][a-z0-9_]*(?:_[a-z0-9]+)+")
STRUCT_RE = re.compile(r"StreamArtistAttestation\(\s*(?P<body>.*?)\)", re.DOTALL)
FIELD_INVENTORY_RE = re.compile(r"full field\s*inventory\s*\((?P<body>[^)]*)\)", re.DOTALL)


class CrossDocumentMirrorError(RuntimeError):
    """Raised when a named cross-document mirror drifts from its home."""


def anchor_slice(repo_root: Path, document: Path, anchor: str) -> str:
    """Return the text from an anchor's definitional line to the next heading."""
    lines = read_text(repo_root / document).splitlines()
    start = None
    for index, line in enumerate(lines):
        if f"[{anchor}]" not in line:
            continue
        if line.startswith("#") or re.search(
            rf"\[{re.escape(anchor)}\](?:\s*\([^()]*\))?\s*:\s*$", line
        ):
            start = index
            break
    if start is None:
        raise CrossDocumentMirrorError(
            f"missing [{anchor}] home section in {document.as_posix()}"
        )
    collected: list[str] = []
    for line in lines[start + 1 :]:
        if re.match(r"^#{1,6}\s", line):
            break
        collected.append(line)
    return "\n".join(collected)


def backticked_snake_tokens(text: str) -> set[str]:
    tokens: set[str] = set()
    for span in re.findall(r"`([^`]+)`", text):
        tokens.update(SNAKE_TOKEN_RE.findall(span))
    return tokens


def numbered_item(text: str, number: int) -> str:
    match = re.search(
        rf"^{number}\.\s.*?(?=^\d+\.\s|\Z)", text, re.MULTILINE | re.DOTALL
    )
    if match is None:
        raise CrossDocumentMirrorError(f"missing numbered item {number}")
    return match.group(0)


def validate_attribution_mirror(repo_root: Path) -> list[str]:
    mirror_rule = numbered_item(anchor_slice(repo_root, MRR_PATH, "MRR-ATTRIBUTION"), 1)
    home_slice = anchor_slice(repo_root, ARTIST_PATH, "AA-DISPLAY")
    mirror_tokens = backticked_snake_tokens(mirror_rule) - RETIRED_FLAT_FIELDS
    home_tokens = set(SNAKE_TOKEN_RE.findall(home_slice))
    failures = [
        f"attribution mirror field {token!r} ([MRR-ATTRIBUTION] rule 1) does "
        f"not exist at the [AA-DISPLAY] home"
        for token in sorted(mirror_tokens - home_tokens)
    ]
    # The retired flat fields may be named only as nonconformant/superseded
    # shapes (ADR 0011 decision R7.6), never as members of the required
    # attribution object.
    if RETIRED_FLAT_FIELDS & backticked_snake_tokens(mirror_rule) and (
        "nonconformant" not in mirror_rule
    ):
        failures.append(
            "[MRR-ATTRIBUTION] rule 1 names the retired flat fields without "
            "declaring them nonconformant"
        )
    return failures


def validate_attestation_mirror(repo_root: Path) -> list[str]:
    cmc_slice = anchor_slice(repo_root, CMC_PATH, "CMC-ARTIST-ATTESTATION")
    inventory_match = FIELD_INVENTORY_RE.search(cmc_slice)
    if inventory_match is None:
        return [
            "[CMC-ARTIST-ATTESTATION] rule 1 no longer carries the full field "
            "inventory"
        ]
    mirror_fields = re.findall(r"`(\w+)`", inventory_match.group("body"))
    home_slice = anchor_slice(repo_root, ARTIST_PATH, "AA-ATTEST")
    struct_match = STRUCT_RE.search(home_slice)
    if struct_match is None:
        return ["[AA-ATTEST] no longer pins the StreamArtistAttestation struct"]
    home_fields = [
        field.split()[-1]
        for field in struct_match.group("body").split(",")
        if field.strip()
    ]
    if mirror_fields != home_fields:
        return [
            "artist-attestation field inventory drifted: "
            f"[CMC-ARTIST-ATTESTATION] pins {mirror_fields}, [AA-ATTEST] pins "
            f"{home_fields}"
        ]
    return []


def validate_repo(repo_root: Path) -> tuple[int, str]:
    failures = validate_attribution_mirror(repo_root)
    failures.extend(validate_attestation_mirror(repo_root))
    if failures:
        details = "\n  - ".join(failures)
        raise CrossDocumentMirrorError(
            f"cross-document mirror check failed with {len(failures)} failure(s):"
            f"\n  - {details}"
        )
    catalog_note = (
        "event-catalog-bound mirror rows verified by the event catalog checker"
        if (repo_root / EVENT_CATALOG_PATH).exists()
        else (
            "record-family event mirror rows pass vacuously: the v1 event "
            "catalog does not exist yet ([LCM-REVIEW-ENTRY] condition 3)"
        )
    )
    return 2, catalog_note


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
        legs, catalog_note = validate_repo(args.repo_root)
    except CrossDocumentMirrorError as exc:
        print(ascii_safe(f"cross-document mirror check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        f"cross-document mirrors are current: {legs} field-inventory mirrors "
        f"verified; {catalog_note}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
