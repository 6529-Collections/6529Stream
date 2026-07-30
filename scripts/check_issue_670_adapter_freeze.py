#!/usr/bin/env python3
"""Fail-closed checker for issue #670 adapter vectors and semantic matrix."""

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


def validate_operation_matrix(
    candidate: Any, supplement: Any
) -> dict[str, Any]:
    """Validate generated matrix precedence and the reviewed overlay contract."""
    if not isinstance(candidate, dict):
        raise generator.AdapterFreezeError(
            "artist operation matrix root must be a JSON object"
        )
    if not isinstance(supplement, dict):
        raise generator.AdapterFreezeError(
            "finality supplement root must be a JSON object"
        )

    expected = generator.artist_operation_matrix_artifact()
    difference = first_difference(candidate, expected)
    if difference:
        raise generator.AdapterFreezeError(
            f"artist operation matrix is stale or invalid: {difference}"
        )

    overlays = candidate["implementation_stop_overlays"]
    if overlays != [generator.finality_stop_overlay()]:
        raise generator.AdapterFreezeError(
            "implementation_stop_overlays must equal the reviewed v1 overlay"
        )
    if supplement.get("schema") != overlays[0]["overlay_schema"]:
        raise generator.AdapterFreezeError(
            "finality supplement schema does not match matrix overlay"
        )
    if supplement.get("matrix_overlay") != overlays[0]:
        raise generator.AdapterFreezeError(
            "finality supplement matrix_overlay does not match generated matrix"
        )

    effective = generator.apply_implementation_stop_overlays(
        candidate["operations"], overlays
    )
    if candidate["effective_implementation_stops"] != effective:
        raise generator.AdapterFreezeError(
            "effective_implementation_stops do not match overlay application"
        )
    if effective["12"] or effective["13"]:
        raise generator.AdapterFreezeError(
            "finality supplement must resolve only row 12/13 finality stops"
        )
    if effective["22"] != [generator.FINALITY_STOP_ID]:
        raise generator.AdapterFreezeError(
            "finality supplement must preserve the row 22 finality stop"
        )

    status = supplement.get("status", {})
    expected_status = {
        "row_12_recordArtistSanction": "GO",
        "row_13_confirmSanctionFinalized": "GO",
        "row_22_recordRecoveryApproval": "NO_GO",
    }
    for field, expected_value in expected_status.items():
        if status.get(field) != expected_value:
            raise generator.AdapterFreezeError(
                f"finality supplement status.{field} must be {expected_value}"
            )
    if status.get("production_source_implementation") != "not_authorized":
        raise generator.AdapterFreezeError(
            "finality supplement production implementation must remain unauthorized"
        )

    decisions = supplement.get("row_decisions")
    if not isinstance(decisions, list):
        raise generator.AdapterFreezeError(
            "finality supplement row_decisions must be a list"
        )
    decisions_by_row = {
        record.get("row"): record
        for record in decisions
        if isinstance(record, dict)
    }
    if set(decisions_by_row) != {12, 13, 22} or len(decisions) != 3:
        raise generator.AdapterFreezeError(
            "finality supplement row_decisions must be exactly rows 12, 13, and 22"
        )
    expected_decisions = {
        12: ("recordArtistSanction", "GO"),
        13: ("confirmSanctionFinalized", "GO"),
        22: ("recordRecoveryApproval", "NO_GO"),
    }
    for row_id, (write, decision) in expected_decisions.items():
        record = decisions_by_row[row_id]
        if record.get("operation") != write or record.get("decision") != decision:
            raise generator.AdapterFreezeError(
                f"finality supplement row {row_id} decision mismatch"
            )
        if record.get("implementation_authorized") is not False:
            raise generator.AdapterFreezeError(
                f"finality supplement row {row_id} cannot authorize implementation"
            )
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


def check_operation_matrix(
    path: Path, supplement_path: Path
) -> dict[str, Any]:
    candidate, raw = load_json_strict(path)
    supplement, _ = load_json_strict(supplement_path)
    validated = validate_operation_matrix(candidate, supplement)
    canonical = generator.operation_matrix_json_bytes(validated)
    if raw != canonical:
        raise generator.AdapterFreezeError(
            "artist operation matrix bytes do not match generated encoding"
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
    parser.add_argument(
        "--matrix",
        type=Path,
        default=generator.DEFAULT_MATRIX_OUTPUT,
    )
    parser.add_argument(
        "--finality-supplement",
        type=Path,
        default=generator.DEFAULT_FINALITY_SUPPLEMENT,
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    artifact = args.artifact
    if not artifact.is_absolute():
        artifact = repo_root / artifact
    matrix = args.matrix
    if not matrix.is_absolute():
        matrix = repo_root / matrix
    supplement = args.finality_supplement
    if not supplement.is_absolute():
        supplement = repo_root / supplement
    try:
        validated = check_artifact(artifact, repo_root)
        validated_matrix = check_operation_matrix(matrix, supplement)
        print(
            "issue #670 mechanical adapter vectors verified: "
            f"{len(validated['revenue_resolver_packet']['adapter_interface']['entries'])} "
            "revenue entries, "
            f"{len(validated['artist_registry_packet']['adapter_interface']['operations'])} "
            "artist entries; "
            f"{len(validated_matrix['implementation_stop_overlays'])} "
            "versioned stop overlay; acceptance remains external"
        )
        return 0
    except generator.AdapterFreezeError as exc:
        print(f"issue #670 mechanical vector check failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
