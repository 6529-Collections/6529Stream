#!/usr/bin/env python3
"""Validate issue #671 checksum-bound shared Core read-buffer as-built evidence."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import generate_royalty_return_gas_buffer as generator


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVIDENCE = REPO_ROOT / "release-artifacts/evidence/royalty-return-gas-buffer.json"
REQUIRED_SPEC_FRAGMENTS = {
    "docs/revenue-splits-and-royalties.md": (
        "worst measured parent-side completion work across `royaltyInfo()`, "
        "`tokenURI()`, and `contractURI()`",
        "including maximum permitted returndata, canonical decoding, fallback "
        "construction, and return handling",
        "strictly monotonic, and bounded to at most 2x the current value per action",
        "as-built permanent `StreamCore`",
        "gasLimit + ceil(gasLimit / 63) + sharedBuffer",
    ),
    "docs/metadata-router-and-renderer.md": (
        "Launch v1 defines no 23rd, metadata-specific buffer parameter.",
        "Every raise of `METADATA_ROUTER_GAS_LIMIT` or the shared buffer replays "
        "all affected threshold measurements",
        "testActualCoreTokenUriBoundaryRejectsBelowAndRoutesAtAndAbove",
        "testActualCoreContractUriBoundaryRejectsBelowAndRoutesAtAndAbove",
        "testMetadataRouterMaximumBoundedReturnCompletes",
    ),
    "docs/adr/0017-raise-only-parameter-governance.md": (
        "`G >= L`, then `G - L >= ceil(L / 63)`",
        "precheck residues `L mod 63 = 0`, `1`, and `62`",
    ),
}
FORBIDDEN_SPEC_FRAGMENTS = (
    "shared-buffer evidence makes StreamCore production-ready",
    "ROYALTY_METADATA_RETURN_GAS_BUFFER",
    "gasLimit + floor(gasLimit / 63) + sharedBuffer",
    "This is checksum-bound target-fixture planning evidence, not an as-built StreamCore measurement.",
)


class SharedBufferCheckError(ValueError):
    """Raised when committed shared-buffer evidence is invalid or stale."""


def _load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        raise SharedBufferCheckError(f"cannot load shared-buffer evidence: {exc}") from exc
    if not isinstance(value, dict):
        raise SharedBufferCheckError("shared-buffer evidence must be an object")
    return value


def _first_drift(actual: Any, expected: Any, path: str = "$") -> str | None:
    if type(actual) is not type(expected):
        return path
    if isinstance(expected, dict):
        if actual.keys() != expected.keys():
            return path
        for key in expected:
            drift = _first_drift(actual[key], expected[key], f"{path}.{key}")
            if drift is not None:
                return drift
        return None
    if isinstance(expected, list):
        if len(actual) != len(expected):
            return path
        for index, item in enumerate(expected):
            drift = _first_drift(actual[index], item, f"{path}[{index}]")
            if drift is not None:
                return drift
        return None
    return None if actual == expected else path


def _validate_spec_fragments(root: Path) -> None:
    normalized_documents: dict[str, str] = {}
    for relative_path, fragments in REQUIRED_SPEC_FRAGMENTS.items():
        text = (root / relative_path).read_text(encoding="utf-8")
        normalized = " ".join(text.split())
        normalized_documents[relative_path] = normalized
        for fragment in fragments:
            if " ".join(fragment.split()) not in normalized:
                raise SharedBufferCheckError(
                    f"missing #671 spec fragment in {relative_path}: {fragment}"
                )
    all_text = " ".join(normalized_documents.values())
    for fragment in FORBIDDEN_SPEC_FRAGMENTS:
        if " ".join(fragment.split()) in all_text:
            raise SharedBufferCheckError(
                f"forbidden #671 production or parameter claim present: {fragment}"
            )


def validate_evidence(
    path: Path = DEFAULT_EVIDENCE, repo_root: Path = REPO_ROOT
) -> None:
    actual = _load(path)
    try:
        expected = generator.build_evidence()
    except generator.SharedBufferGenerationError as exc:
        raise SharedBufferCheckError(str(exc)) from exc
    drift = _first_drift(actual, expected)
    if drift is not None:
        raise SharedBufferCheckError(f"shared-buffer evidence drift at {drift}")
    _validate_spec_fragments(repo_root)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, default=DEFAULT_EVIDENCE)
    args = parser.parse_args(argv)
    evidence = args.evidence
    if not evidence.is_absolute():
        evidence = REPO_ROOT / evidence
    try:
        validate_evidence(evidence)
    except (
        SharedBufferCheckError,
        generator.SharedBufferGenerationError,
        OSError,
        KeyError,
        TypeError,
    ) as exc:
        print(f"shared-buffer evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("shared-buffer as-built evidence is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
