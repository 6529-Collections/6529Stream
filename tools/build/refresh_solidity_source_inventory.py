#!/usr/bin/env python3
"""Refresh active Solidity paths after validating the complete source-layout policy."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Sequence

from tools.build import check_solidity_source_layout as layout


def refresh(repo_root: Path, *, check: bool = False) -> bool:
    """Change only source_paths; refuse invalid layouts before writing anything."""
    repo_root = repo_root.resolve()
    current = layout.load_current_manifest(repo_root)
    candidate = dict(current)
    candidate["source_paths"] = sorted(
        path.relative_to(repo_root).as_posix()
        for path in (repo_root / layout.EXPECTED_SOURCE_ROOT).rglob("*.sol")
        if path.is_file()
    )
    errors = layout.check_repository(repo_root, current_candidate=candidate)
    if errors:
        raise layout.SourceLayoutError("\n".join(errors))
    changed = candidate["source_paths"] != current["source_paths"]
    if changed and not check:
        (repo_root / layout.CURRENT_MANIFEST_PATH).write_bytes(
            (json.dumps(candidate, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
        )
    return changed


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--check", action="store_true", help="Report stale inventory without writing.")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    try:
        changed = refresh(args.repo_root, check=args.check)
    except layout.SourceLayoutError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if changed and args.check:
        print("ERROR: Active Solidity source inventory is stale.", file=sys.stderr)
        return 1
    print("Active Solidity source inventory refreshed." if changed else "Active Solidity source inventory is current.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
