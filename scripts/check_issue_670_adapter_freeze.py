#!/usr/bin/env python3
"""Fail-closed checker for the issue #670 mechanical adapter vectors."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import generate_issue_670_adapter_freeze as generator


def reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise generator.AdapterFreezeError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_float(token: str) -> Any:
    raise generator.AdapterFreezeError(
        f"floating-point JSON values are forbidden: {token}"
    )


def reject_constant(token: str) -> Any:
    raise generator.AdapterFreezeError(f"non-I-JSON value is forbidden: {token}")


def load_json_strict(path: Path) -> tuple[Any, bytes]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise generator.AdapterFreezeError(f"cannot read artifact: {path}") from exc
    try:
        text = raw.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise generator.AdapterFreezeError(
            f"artifact is not strict UTF-8: {path}"
        ) from exc
    try:
        value = json.loads(
            text,
            object_pairs_hook=reject_duplicate_pairs,
            parse_float=reject_float,
            parse_constant=reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise generator.AdapterFreezeError(
            f"artifact is not valid JSON: {path}: {exc}"
        ) from exc
    return value, raw


def first_difference(actual: Any, expected: Any, path: str = "$") -> str:
    """Return a compact path to the first deterministic structural difference."""
    if type(actual) is not type(expected):
        return (
            f"{path} type differs: actual {type(actual).__name__}, "
            f"expected {type(expected).__name__}"
        )
    if isinstance(expected, dict):
        actual_keys = set(actual)
        expected_keys = set(expected)
        if actual_keys != expected_keys:
            missing = sorted(expected_keys - actual_keys)
            unexpected = sorted(actual_keys - expected_keys)
            return (
                f"{path} keys differ: missing={missing}, unexpected={unexpected}"
            )
        for key in sorted(expected):
            difference = first_difference(actual[key], expected[key], f"{path}.{key}")
            if difference:
                return difference
        return ""
    if isinstance(expected, list):
        if len(actual) != len(expected):
            return (
                f"{path} length differs: actual {len(actual)}, "
                f"expected {len(expected)}"
            )
        for index, (actual_item, expected_item) in enumerate(
            zip(actual, expected, strict=True)
        ):
            difference = first_difference(
                actual_item, expected_item, f"{path}[{index}]"
            )
            if difference:
                return difference
        return ""
    if actual != expected:
        return f"{path} differs: actual {actual!r}, expected {expected!r}"
    return ""


def validate_artifact(candidate: Any, repo_root: Path) -> dict[str, Any]:
    if not isinstance(candidate, dict):
        raise generator.AdapterFreezeError("artifact root must be a JSON object")
    expected = generator.build_artifact(repo_root)
    difference = first_difference(candidate, expected)
    if difference:
        raise generator.AdapterFreezeError(
            f"mechanical vector content is stale or invalid: {difference}"
        )

    external = candidate["required_external_artifacts"]
    if not external:
        raise generator.AdapterFreezeError(
            "required_external_artifacts must not be empty"
        )
    for index, record in enumerate(external):
        if record["status"] != "required_external":
            raise generator.AdapterFreezeError(
                f"required_external_artifacts[{index}] must remain required"
            )
        if record["satisfied_by_this_artifact"] is not False:
            raise generator.AdapterFreezeError(
                f"required_external_artifacts[{index}] cannot be satisfied here"
            )

    status = candidate["status"]
    false_claims = (
        "acceptance_freeze_satisfied",
        "implementation_authorized",
        "production_readiness_evidence",
    )
    for field in false_claims:
        if status[field] is not False:
            raise generator.AdapterFreezeError(f"status.{field} must remain false")
    return candidate


def check_artifact(path: Path, repo_root: Path) -> dict[str, Any]:
    candidate, raw = load_json_strict(path)
    validated = validate_artifact(candidate, repo_root)
    canonical = generator.canonical_json_bytes(validated)
    if raw != canonical:
        raise generator.AdapterFreezeError(
            "artifact bytes are not the canonical sorted two-space JSON encoding"
        )
    return validated


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
    )
    parser.add_argument("--artifact", type=Path, default=generator.DEFAULT_OUTPUT)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    artifact = args.artifact
    if not artifact.is_absolute():
        artifact = repo_root / artifact
    try:
        validated = check_artifact(artifact, repo_root)
        print(
            "issue #670 mechanical adapter vectors verified: "
            f"{len(validated['revenue_resolver_packet']['adapter_interface']['entries'])} "
            "revenue entries, "
            f"{len(validated['artist_registry_packet']['adapter_interface']['operations'])} "
            "artist entries; acceptance remains external"
        )
        return 0
    except generator.AdapterFreezeError as exc:
        print(f"issue #670 mechanical vector check failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
