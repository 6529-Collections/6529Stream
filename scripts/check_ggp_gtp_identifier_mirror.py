#!/usr/bin/env python3
"""Validate GGP/GTP identifier mirror completeness and name uniformity.

The GGP/GTP identifier completeness row of the Verification Tooling
Backlog (docs/launch-conformance-matrix.md [LCM-TOOLING]; ADR 0011
decision R12; ADR 0013 decision U9) requires exactly one identifier
mirror row per [LTA-GGP]/[LTA-GTP] inventory entry with no orphan rows,
and uniform ``GGP_``/``GTP_`` constant names row-for-row against the
Solidity constants.

Docs leg (buildable now): the [LTA-GGP] inventory table in
docs/stream-long-term-architecture.md and the three [EC-TIME] Governed
Time Parameter instantiations in docs/stream-entropy-coordinator.md are
compared against the consolidated Governed Gas Parameter Identifier
Mirror Rows table in docs/launch-v1-target-architecture.md: one
``GGP_<PARAMETER>``/``GTP_<PARAMETER>`` row per inventory entry, no
orphans, and each preimage exactly ``6529STREAM_GGP_<PARAMETER>`` or
``6529STREAM_GTP_<PARAMETER>`` per [LTA-GGP] rule 5 and [LTA-GTP]
rule 3 (hash recomputation is owned by the domain recomputation
checker).

Solidity leg: uniform identifier constants are verified against any
``GGP_``/``GTP_`` keccak256 constants declared under smart-contracts/;
no Governed Gas Parameter store exists in Solidity yet, so this leg
reports vacuously until the GGP hosts land.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import (  # noqa: E402
    ascii_safe,
    first_backtick_span,
    iter_tables,
    read_text,
)


UMBRELLA_PATH = Path("docs/stream-long-term-architecture.md")
COORDINATOR_PATH = Path("docs/stream-entropy-coordinator.md")
PROTOCOL_V1_PATH = Path("docs/launch-v1-target-architecture.md")
MIRROR_HEADING = "### Governed Gas Parameter Identifier Mirror Rows"
INVENTORY_HEADERS = ("Parameter", "Host", "Normative home")
GTP_SECTION_MARKER = "Requirements [EC-TIME]"
GTP_NAME_RE = re.compile(r"`(?P<name>ENTROPY_[A-Z0-9_]*BLOCKS)`")
SOLIDITY_IDENTIFIER_RE = re.compile(
    r"bytes32\s+(?:public\s+|internal\s+|private\s+)?constant\s+"
    r"(?P<name>G[GT]P_[A-Z0-9_]+)\s*=\s*keccak256\(\s*\"(?P<preimage>[^\"]+)\"\s*\)",
    re.DOTALL,
)


class GgpIdentifierMirrorError(RuntimeError):
    """Raised when the GGP/GTP identifier mirror drifts from its inventories."""


def ggp_inventory(repo_root: Path) -> list[str]:
    """Parameter names from the [LTA-GGP] inventory table."""
    text = read_text(repo_root / UMBRELLA_PATH)
    for table in iter_tables(UMBRELLA_PATH, text):
        if table.headers == INVENTORY_HEADERS:
            names = []
            for _, cells in table.mapped_rows():
                name = first_backtick_span(cells["Parameter"])
                if name is None:
                    raise GgpIdentifierMirrorError(
                        f"{UMBRELLA_PATH.as_posix()}: inventory row without a "
                        f"backticked parameter name: {cells['Parameter']!r}"
                    )
                names.append(name)
            if not names:
                raise GgpIdentifierMirrorError("empty [LTA-GGP] inventory table")
            return names
    raise GgpIdentifierMirrorError(
        f"missing [LTA-GGP] inventory table in {UMBRELLA_PATH.as_posix()}"
    )


def gtp_instantiations(repo_root: Path) -> list[str]:
    """Governed Time Parameter names from the [EC-TIME] home."""
    text = read_text(repo_root / COORDINATOR_PATH)
    start = text.find(GTP_SECTION_MARKER)
    if start == -1:
        raise GgpIdentifierMirrorError(
            f"missing {GTP_SECTION_MARKER!r} in {COORDINATOR_PATH.as_posix()}"
        )
    section = text[start:]
    next_heading = re.search(r"^## ", section[1:], re.MULTILINE)
    if next_heading is not None:
        section = section[: next_heading.start() + 1]
    names: list[str] = []
    for match in GTP_NAME_RE.finditer(section):
        name = match.group("name")
        if name not in names:
            names.append(name)
    if not names:
        raise GgpIdentifierMirrorError("no [EC-TIME] GTP instantiations found")
    return names


def mirror_rows(repo_root: Path) -> dict[str, str]:
    """Constant-name -> preimage rows of the consolidated identifier mirror."""
    text = read_text(repo_root / PROTOCOL_V1_PATH)
    start = text.find(MIRROR_HEADING)
    if start == -1:
        raise GgpIdentifierMirrorError(
            f"missing heading in {PROTOCOL_V1_PATH.as_posix()}: {MIRROR_HEADING}"
        )
    section = text[start:]
    next_heading = re.search(r"^### ", section[len(MIRROR_HEADING) :], re.MULTILINE)
    if next_heading is not None:
        section = section[: len(MIRROR_HEADING) + next_heading.start()]
    rows: dict[str, str] = {}
    for table in iter_tables(PROTOCOL_V1_PATH, section):
        if "Constant name" not in table.headers:
            continue
        for line, cells in table.mapped_rows():
            name = first_backtick_span(cells["Constant name"])
            preimage = first_backtick_span(cells["String preimage"])
            if name is None or preimage is None:
                raise GgpIdentifierMirrorError(
                    f"{PROTOCOL_V1_PATH.as_posix()}:{line}: malformed identifier "
                    "mirror row"
                )
            if name in rows:
                raise GgpIdentifierMirrorError(
                    f"{PROTOCOL_V1_PATH.as_posix()}:{line}: duplicate identifier "
                    f"mirror row for {name}"
                )
            rows[name] = preimage
    if not rows:
        raise GgpIdentifierMirrorError("empty GGP identifier mirror table")
    return rows


def solidity_identifier_constants(repo_root: Path) -> dict[str, str]:
    constants: dict[str, str] = {}
    contracts_dir = repo_root / "smart-contracts"
    if not contracts_dir.is_dir():
        return constants
    for path in sorted(contracts_dir.rglob("*.sol")):
        for match in SOLIDITY_IDENTIFIER_RE.finditer(read_text(path)):
            constants[match.group("name")] = match.group("preimage")
    return constants


def validate_repo(repo_root: Path) -> tuple[int, int, int]:
    """Validate the mirror; return (ggp_count, gtp_count, solidity_count)."""
    ggp_names = ggp_inventory(repo_root)
    gtp_names = gtp_instantiations(repo_root)
    rows = mirror_rows(repo_root)

    expected: dict[str, str] = {}
    for name in ggp_names:
        expected[f"GGP_{name}"] = f"6529STREAM_GGP_{name}"
    for name in gtp_names:
        expected[f"GTP_{name}"] = f"6529STREAM_GTP_{name}"

    failures: list[str] = []
    for constant, preimage in sorted(expected.items()):
        actual = rows.get(constant)
        if actual is None:
            failures.append(
                f"inventory entry {constant[4:]} has no {constant} mirror row"
            )
        elif actual != preimage:
            failures.append(
                f"{constant} preimage drifted: expected {preimage}, mirror pins {actual}"
            )
    for constant in sorted(set(rows) - set(expected)):
        failures.append(
            f"orphan mirror row {constant}: no [LTA-GGP]/[EC-TIME] inventory entry"
        )

    constants = solidity_identifier_constants(repo_root)
    for name, preimage in sorted(constants.items()):
        if name not in expected:
            failures.append(
                f"Solidity identifier constant {name} has no inventory entry"
            )
        elif expected[name] != preimage:
            failures.append(
                f"Solidity identifier constant {name} preimage drifted: "
                f"expected {expected[name]}, got {preimage}"
            )

    if failures:
        details = "\n  - ".join(failures)
        raise GgpIdentifierMirrorError(
            f"GGP/GTP identifier mirror failed with {len(failures)} failure(s):"
            f"\n  - {details}"
        )
    return len(ggp_names), len(gtp_names), len(constants)


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
        ggp_count, gtp_count, solidity_count = validate_repo(args.repo_root)
    except GgpIdentifierMirrorError as exc:
        print(ascii_safe(f"GGP/GTP identifier mirror check failed: {exc}"), file=sys.stderr)
        return 1
    solidity_note = (
        f"{solidity_count} Solidity identifier constants matched"
        if solidity_count
        else "Solidity leg vacuous (no GGP/GTP identifier constants exist yet)"
    )
    print(
        f"GGP/GTP identifier mirror is current: {ggp_count} GGP rows, "
        f"{gtp_count} GTP rows; {solidity_note}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
