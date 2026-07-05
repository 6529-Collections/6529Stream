#!/usr/bin/env python3
"""Recompute every pinned hash in the domain homes and protocol v1 mirrors.

The domain recomputation row of the Verification Tooling Backlog
(docs/launch-conformance-matrix.md [LCM-TOOLING]; [PV1-DOMAINS],
[PV1-MIRROR] rule 2; [LCM-REVIEW-ENTRY] condition 4) requires every
``keccak256`` and EIP-712 typehash in every domain home and every
protocol v1 mirror row to recompute from its adjacent string preimage,
with drift across Solidity constants, home tables, mirrors, and release
artifacts failing, and an unpinned hash placeholder failing.

This checker scans every Markdown table across the docs tree whose
header carries ``Constant name``, ``String preimage``, and ``Hash value``
columns and, per row:

1. requires a backticked string preimage and a pinned hex hash value
   (a 32-byte digest, or a 4-byte selector for ``bytes4`` rows);
2. recomputes keccak256 over the exact preimage bytes and fails on
   drift (selectors compare the first four bytes);
3. fails when one constant name pins different preimage/hash values in
   different tables (home versus mirror drift);
4. cross-checks any same-named ``bytes32 constant NAME =
   keccak256("...")`` Solidity declaration under smart-contracts/.

It is additive to scripts/check_mint_manager_domain_constants.py, whose
checked-manager-table semantics are unchanged. The deployed
domain-constants release manifest named by [PV1-MIRROR] rule 3 does not
exist yet; when present at release-artifacts/latest/domain-constants.json
its entries are cross-checked by constant name.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import (  # noqa: E402
    ascii_safe,
    first_backtick_span,
    iter_tables,
    keccak256_hex,
    markdown_docs,
    read_text,
)


REQUIRED_HEADERS = {"Constant name", "String preimage", "Hash value"}
FULL_HASH_RE = re.compile(r"0x[0-9a-fA-F]{64}")
SELECTOR_HASH_RE = re.compile(r"0x[0-9a-fA-F]{8}")
SOLIDITY_CONSTANT_RE = re.compile(
    r"bytes32\s+(?:public\s+|internal\s+|private\s+)?constant\s+"
    r"(?P<name>[A-Z0-9_]+)\s*=\s*keccak256\(\s*\"(?P<preimage>[^\"]+)\"\s*\)\s*;",
    re.DOTALL,
)
RELEASE_MANIFEST_PATH = Path("release-artifacts/latest/domain-constants.json")


class DomainRecomputationError(RuntimeError):
    """Raised when a pinned domain hash drifts or is left unpinned."""


REFERENTIAL = "<referential>"


@dataclass(frozen=True)
class DomainRow:
    document: Path
    line: int
    name: str
    preimage: str
    hash_value: str


def extract_rows(repo_root: Path) -> list[DomainRow]:
    """Collect every domain-table row across the docs tree."""
    rows: list[DomainRow] = []
    for path in markdown_docs(repo_root):
        relative = path.relative_to(repo_root)
        for table in iter_tables(relative, read_text(path)):
            if not REQUIRED_HEADERS <= set(table.headers):
                continue
            if table.ragged_lines:
                raise DomainRecomputationError(
                    f"{relative.as_posix()}:{table.ragged_lines[0]}: malformed "
                    "domain-table row (cell count drifts from the header)"
                )
            for line, cells in table.mapped_rows():
                name_cell = cells["Constant name"]
                preimage_cell = cells["String preimage"]
                hash_cell = cells["Hash value"].strip().strip("`")
                name = first_backtick_span(name_cell) or name_cell.strip()
                preimage = first_backtick_span(preimage_cell)
                if preimage is None:
                    if "pinned in [" in preimage_cell:
                        # Referential home cell: the inline preimage is
                        # pinned at the named rule and mirrored with the
                        # full string elsewhere; consistency is enforced
                        # against the same-named inline row below.
                        rows.append(
                            DomainRow(relative, line, name, REFERENTIAL, hash_cell)
                        )
                        continue
                    raise DomainRecomputationError(
                        f"{relative.as_posix()}:{line}: {name} has no backticked "
                        "string preimage adjacent to its hash value"
                    )
                rows.append(DomainRow(relative, line, name, preimage, hash_cell))
    return rows


def validate_row(row: DomainRow) -> str | None:
    """Return a failure reason for one row, or None when it recomputes."""
    location = f"{row.document.as_posix()}:{row.line}"
    if row.preimage == REFERENTIAL:
        if FULL_HASH_RE.fullmatch(row.hash_value) or SELECTOR_HASH_RE.fullmatch(
            row.hash_value
        ):
            return None
        return (
            f"{location}: {row.name} carries an unpinned hash placeholder "
            f"({row.hash_value!r}); [PV1-MIRROR] rule 2 requires a pinned value"
        )
    if FULL_HASH_RE.fullmatch(row.hash_value):
        expected = keccak256_hex(row.preimage)
        if row.hash_value.lower() != expected:
            return (
                f"{location}: {row.name} hash drifted: keccak256 of pinned "
                f"preimage is {expected}, table pins {row.hash_value.lower()}"
            )
        return None
    if SELECTOR_HASH_RE.fullmatch(row.hash_value):
        expected = keccak256_hex(row.preimage)[: 2 + 8]
        if row.hash_value.lower() != expected:
            return (
                f"{location}: {row.name} selector drifted: first four keccak256 "
                f"bytes are {expected}, table pins {row.hash_value.lower()}"
            )
        return None
    return (
        f"{location}: {row.name} carries an unpinned hash placeholder "
        f"({row.hash_value!r}); [PV1-MIRROR] rule 2 requires a pinned value"
    )


def validate_cross_table_consistency(rows: list[DomainRow]) -> list[str]:
    """Fail when one constant name pins divergent values across tables."""
    failures: list[str] = []
    inline_by_name: dict[str, DomainRow] = {}
    for row in rows:
        if row.preimage == REFERENTIAL:
            continue
        seen = inline_by_name.setdefault(row.name, row)
        if seen is row:
            continue
        if (seen.preimage, seen.hash_value.lower()) != (
            row.preimage,
            row.hash_value.lower(),
        ):
            failures.append(
                f"{row.name} drifts between {seen.document.as_posix()}:{seen.line} "
                f"and {row.document.as_posix()}:{row.line}"
            )
    for row in rows:
        if row.preimage != REFERENTIAL:
            continue
        inline = inline_by_name.get(row.name)
        if inline is None:
            failures.append(
                f"{row.name} ({row.document.as_posix()}:{row.line}) pins a hash "
                "with no inline string preimage in any home or mirror row"
            )
        elif inline.hash_value.lower() != row.hash_value.lower():
            failures.append(
                f"{row.name} drifts between {inline.document.as_posix()}:"
                f"{inline.line} and {row.document.as_posix()}:{row.line}"
            )
    return failures


def solidity_constants(repo_root: Path) -> dict[str, str]:
    """Map Solidity keccak256 constant names to their string preimages."""
    constants: dict[str, str] = {}
    contracts_dir = repo_root / "smart-contracts"
    if not contracts_dir.is_dir():
        return constants
    for path in sorted(contracts_dir.rglob("*.sol")):
        for match in SOLIDITY_CONSTANT_RE.finditer(read_text(path)):
            constants[match.group("name")] = match.group("preimage")
    return constants


def validate_solidity_leg(rows: list[DomainRow], constants: dict[str, str]) -> list[str]:
    failures: list[str] = []
    checked: set[str] = set()
    for row in rows:
        preimage = constants.get(row.name)
        if preimage is None or row.name in checked:
            continue
        checked.add(row.name)
        if preimage != row.preimage:
            failures.append(
                f"{row.name} Solidity preimage {preimage!r} drifts from the "
                f"documented preimage {row.preimage!r} "
                f"({row.document.as_posix()}:{row.line})"
            )
    return failures


def validate_release_manifest(repo_root: Path, rows: list[DomainRow]) -> list[str]:
    """Cross-check the deployed domain-constants manifest when present."""
    manifest_path = repo_root / RELEASE_MANIFEST_PATH
    if not manifest_path.exists():
        return []
    manifest = json.loads(read_text(manifest_path))
    entries = manifest.get("constants", [])
    documented = {row.name: row for row in rows}
    failures: list[str] = []
    for entry in entries:
        name = entry.get("name")
        row = documented.get(name)
        if row is None:
            failures.append(
                f"{RELEASE_MANIFEST_PATH.as_posix()}: {name} has no documented "
                "domain-table row"
            )
            continue
        if entry.get("preimage") != row.preimage or (
            str(entry.get("hash", "")).lower() != row.hash_value.lower()
        ):
            failures.append(
                f"{RELEASE_MANIFEST_PATH.as_posix()}: {name} drifts from "
                f"{row.document.as_posix()}:{row.line}"
            )
    return failures


def validate_repo(repo_root: Path) -> tuple[int, int]:
    """Validate all rows; return (row_count, solidity_checked_count)."""
    rows = extract_rows(repo_root)
    if not rows:
        raise DomainRecomputationError("no domain-constant tables found under docs/")
    failures = [reason for row in rows if (reason := validate_row(row))]
    failures.extend(validate_cross_table_consistency(rows))
    constants = solidity_constants(repo_root)
    failures.extend(validate_solidity_leg(rows, constants))
    failures.extend(validate_release_manifest(repo_root, rows))
    if failures:
        details = "\n  - ".join(failures[:60])
        remaining = len(failures) - 60
        suffix = f"\n  ... and {remaining} more" if remaining > 0 else ""
        raise DomainRecomputationError(
            f"domain recomputation failed with {len(failures)} failure(s):"
            f"\n  - {details}{suffix}"
        )
    checked = len({row.name for row in rows} & set(constants))
    return len(rows), checked


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
        row_count, solidity_count = validate_repo(args.repo_root)
    except DomainRecomputationError as exc:
        print(ascii_safe(f"domain recomputation check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        f"domain constants recompute: {row_count} pinned rows verified, "
        f"{solidity_count} matched against Solidity constants"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
