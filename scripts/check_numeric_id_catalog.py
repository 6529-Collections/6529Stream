#!/usr/bin/env python3
"""Validate the manifest-pinned Numeric ID Catalog ([LCM-IDS]).

The Numeric ID Catalog closed-world row of the Verification Tooling
Backlog (docs/launch-conformance-matrix.md [LCM-TOOLING]; [LCM-IDS];
ADR 0012 decision T9) binds the catalog artifact. The artifact does not
exist yet; until it lands at
``release-artifacts/latest/numeric-id-catalog.json`` this checker passes
with a note.

When present:

1. ``schema`` is ``6529.stream.numeric-id-catalog.v1`` with its own
   ``schemaVersion``, ``schemaURI``, ``schemaHash``,
   ``canonicalizationId``, and ``supersedesCatalogHash`` (null for the
   first catalog) — catalog format updates are supersessions, never
   mutations.
2. Enum entries carry a name, an owning home, and a literal->value map
   of unique non-negative integers; literals are ALL-CAPS.
3. Closed-world coverage: every enum family the [LCM-IDS] coverage list
   names (the backticked CamelCase enum names in the matrix's Numeric ID
   Catalog section) has a catalog entry.
4. The ``bytes32`` keccak name vocabularies pinned at their homes — the
   collection identity modes and conservation tiers — are not catalog
   members ([LCM-IDS]): assigning them numeric aliases would create a
   second boundary-crossing ID space.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import ascii_safe, read_text  # noqa: E402


DEFAULT_CATALOG_PATH = Path("release-artifacts/latest/numeric-id-catalog.json")
MATRIX_PATH = Path("docs/launch-conformance-matrix.md")
CATALOG_SCHEMA = "6529.stream.numeric-id-catalog.v1"
REQUIRED_TOP_LEVEL = (
    "schema",
    "schemaVersion",
    "schemaURI",
    "schemaHash",
    "canonicalizationId",
    "supersedesCatalogHash",
    "enums",
)
IDS_HEADING = "## Numeric ID Catalog"
CAMEL_ENUM_RE = re.compile(r"`([A-Z][a-z][A-Za-z0-9]*)`")
FORBIDDEN_NAME_VOCABULARY = {"CORE_NATIVE", "EXTERNAL_FACADE"}
LITERAL_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")


class NumericIdCatalogError(RuntimeError):
    """Raised when the Numeric ID Catalog violates [LCM-IDS]."""


def required_enum_families(repo_root: Path) -> set[str]:
    """CamelCase enum names the [LCM-IDS] coverage list pins."""
    text = read_text(repo_root / MATRIX_PATH)
    start = text.find(IDS_HEADING)
    if start == -1:
        raise NumericIdCatalogError(f"missing {IDS_HEADING!r} in the matrix")
    section = text[start:]
    next_heading = re.search(r"^## ", section[len(IDS_HEADING) :], re.MULTILINE)
    if next_heading is not None:
        section = section[: len(IDS_HEADING) + next_heading.start()]
    names = set(CAMEL_ENUM_RE.findall(section))
    return names


def validate_catalog(repo_root: Path, path: Path) -> tuple[int, int]:
    try:
        catalog = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise NumericIdCatalogError(f"{path}: invalid JSON: {exc}") from exc
    failures: list[str] = []
    for field in REQUIRED_TOP_LEVEL:
        if field not in catalog:
            failures.append(f"missing top-level field {field!r}")
    if catalog.get("schema") != CATALOG_SCHEMA:
        failures.append(
            f"schema {catalog.get('schema')!r} is not {CATALOG_SCHEMA!r}"
        )
    enums = catalog.get("enums", [])
    if not isinstance(enums, list):
        failures.append("enums must be a list")
        enums = []
    catalog_names: set[str] = set()
    for entry in enums:
        name = entry.get("name", "<missing>")
        catalog_names.add(name)
        if not entry.get("home"):
            failures.append(f"{name}: no owning home recorded")
        values = entry.get("values")
        if not isinstance(values, dict) or not values:
            failures.append(f"{name}: values must be a nonempty literal->value map")
            continue
        seen: dict[int, str] = {}
        for literal, value in values.items():
            if not LITERAL_RE.fullmatch(literal):
                failures.append(f"{name}.{literal}: literal is not ALL-CAPS")
            if not isinstance(value, int) or value < 0:
                failures.append(f"{name}.{literal}: value must be a non-negative integer")
                continue
            if value in seen:
                failures.append(
                    f"{name}: value {value} assigned to both {seen[value]} and {literal}"
                )
            seen[value] = literal
            if literal in FORBIDDEN_NAME_VOCABULARY:
                failures.append(
                    f"{name}.{literal}: bytes32 keccak name vocabularies are not "
                    "catalog members ([LCM-IDS])"
                )
    required = required_enum_families(repo_root)
    for family in sorted(required - catalog_names):
        failures.append(
            f"[LCM-IDS] coverage family {family} has no catalog entry "
            "(closed-world rule)"
        )
    if failures:
        details = "\n  - ".join(failures)
        raise NumericIdCatalogError(
            f"numeric ID catalog failed with {len(failures)} failure(s):"
            f"\n  - {details}"
        )
    return len(enums), len(required)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root to validate.",
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        default=None,
        help="Catalog path override (default: release-artifacts/latest/numeric-id-catalog.json).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    catalog_path = args.catalog or (args.repo_root / DEFAULT_CATALOG_PATH)
    if not catalog_path.exists():
        try:
            required = len(required_enum_families(args.repo_root))
        except NumericIdCatalogError as exc:
            print(ascii_safe(f"numeric ID catalog check failed: {exc}"), file=sys.stderr)
            return 1
        print(
            "numeric ID catalog check passes vacuously: the catalog artifact "
            f"does not exist yet at {DEFAULT_CATALOG_PATH.as_posix()} "
            f"([LCM-IDS]); {required} enum families await coverage"
        )
        return 0
    try:
        enum_count, required_count = validate_catalog(args.repo_root, catalog_path)
    except NumericIdCatalogError as exc:
        print(ascii_safe(f"numeric ID catalog check failed: {exc}"), file=sys.stderr)
        return 1
    print(
        f"numeric ID catalog is current: {enum_count} enum families cover the "
        f"{required_count} [LCM-IDS] coverage names"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
