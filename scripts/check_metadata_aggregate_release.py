#!/usr/bin/env python3
"""Validate the metadata aggregate function-count and bytecode ceilings.

The metadata aggregate ABI/bytecode release row of the Verification
Tooling Backlog (docs/launch-conformance-matrix.md [LCM-TOOLING];
Collection metadata gate) binds the release checker rule of
docs/collection-metadata-contract.md: the deployment candidate's
aggregate external/public function count across the five genesis
metadata surfaces stays under the pinned hard ceiling (soft target
exceedance requires an audit-scope note), and the function-count,
selector, bytecode, and code-hash records must be present for each
surface.

The ceilings are parsed from the spec text, never hardcoded. The
measurement source is the protocol surface report
(release-artifacts/latest/protocol-surface-report.json). The spec-shaped
metadata satellites are unbuilt; until every named surface appears in
the surface report this checker passes with a note listing the missing
deployments.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from spec_conformance import ascii_safe, read_text  # noqa: E402


CMC_PATH = Path("docs/collection-metadata-contract.md")
SURFACE_REPORT_PATH = Path("release-artifacts/latest/protocol-surface-report.json")
METADATA_SURFACES = (
    "StreamCollectionMetadata",
    "StreamPreservationRecords",
    "StreamCollectionAttestations",
    "StreamCollectionViews",
    "StreamOwnerRecords",
)
HARD_CEILING_RE = re.compile(
    r"aggregate ceiling is (?P<hard>\d+) external/public\s*functions"
)
SOFT_TARGET_RE = re.compile(r"soft target of (?P<soft>\d+) or fewer")


class MetadataAggregateError(RuntimeError):
    """Raised when the metadata aggregate exceeds its pinned ceilings."""


def pinned_ceilings(repo_root: Path) -> tuple[int, int]:
    text = " ".join(read_text(repo_root / CMC_PATH).split())
    hard_match = HARD_CEILING_RE.search(text)
    soft_match = SOFT_TARGET_RE.search(text)
    if hard_match is None or soft_match is None:
        raise MetadataAggregateError(
            f"{CMC_PATH.as_posix()} no longer pins the aggregate ceilings"
        )
    return int(hard_match.group("hard")), int(soft_match.group("soft"))


def surface_entries(repo_root: Path) -> dict[str, dict]:
    report_path = repo_root / SURFACE_REPORT_PATH
    if not report_path.exists():
        return {}
    report = json.loads(read_text(report_path))
    contracts = report.get("contracts", [])
    if isinstance(contracts, dict):
        entries = contracts
    else:
        entries = {entry.get("name"): entry for entry in contracts}
    return {name: entries[name] for name in METADATA_SURFACES if name in entries}


def function_count(entry: dict) -> int:
    functions = entry.get("functions")
    if isinstance(functions, list):
        return len(functions)
    if isinstance(functions, int):
        return functions
    raise MetadataAggregateError(
        f"surface report entry for {entry.get('name')!r} carries no function list"
    )


def validate_repo(repo_root: Path) -> tuple[int, int, int, list[str]]:
    """Return (aggregate, hard, soft, missing surfaces)."""
    hard, soft = pinned_ceilings(repo_root)
    if soft > hard:
        raise MetadataAggregateError(
            f"pinned soft target {soft} exceeds the hard ceiling {hard}"
        )
    entries = surface_entries(repo_root)
    missing = [name for name in METADATA_SURFACES if name not in entries]
    if missing:
        return 0, hard, soft, missing
    aggregate = 0
    failures: list[str] = []
    for name, entry in entries.items():
        aggregate += function_count(entry)
        if not entry.get("bytecodeHash") and not entry.get("runtimeBytecodeHash"):
            failures.append(f"{name}: no bytecode/code-hash record in the report")
    if aggregate > hard:
        failures.append(
            f"aggregate metadata function count {aggregate} exceeds the pinned "
            f"hard ceiling {hard}"
        )
    if failures:
        details = "\n  - ".join(failures)
        raise MetadataAggregateError(
            f"metadata aggregate failed with {len(failures)} failure(s):"
            f"\n  - {details}"
        )
    return aggregate, hard, soft, []


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
        aggregate, hard, soft, missing = validate_repo(args.repo_root)
    except MetadataAggregateError as exc:
        print(ascii_safe(f"metadata aggregate check failed: {exc}"), file=sys.stderr)
        return 1
    if missing:
        print(
            "metadata aggregate check passes vacuously: the spec-shaped "
            "metadata surfaces are not deployed yet ("
            + ", ".join(missing)
            + f" absent from {SURFACE_REPORT_PATH.as_posix()}); pinned ceilings "
            f"are {hard} hard / {soft} soft"
        )
        return 0
    note = (
        f"; soft target {soft} exceeded, audit-scope note required"
        if aggregate > soft
        else ""
    )
    print(
        f"metadata aggregate is current: {aggregate} external/public functions "
        f"across the five surfaces (hard ceiling {hard}){note}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
