#!/usr/bin/env python3
"""Validate the normalized first-party Slither High/Medium baseline."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from collections import Counter
from importlib import metadata
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


SCHEMA_VERSION = "6529stream.slither-first-party-hm.v1"
CANDIDATE_SCHEMA_VERSION = "6529stream.slither-normalized-candidate.v1"
DEFAULT_BASELINE = Path("ops/SLITHER_BASELINE.json")
DEFAULT_MARKDOWN = Path("ops/SLITHER_BASELINE.md")
CONFIG_PATH = Path("slither.config.json")
FOUNDRY_CONFIG_PATH = Path("foundry.toml")
REQUIREMENTS_PATH = Path("requirements-tools.txt")
SOLIDITY_ROOTS = (Path("smart-contracts"),)

EXPECTED_SLITHER_VERSION = "0.11.5"
EXPECTED_CRYTIC_COMPILE_VERSION = "0.3.11"
EXPECTED_SOLC_VERSION = "0.8.19"
EXPECTED_SOLC_SELECT_VERSION = "1.2.0"
EXPECTED_FOUNDRY_VERSION = "1.7.1"
EXPECTED_ANALYZED_COMMIT = "ce8fed6d7ec4366c42aab381ad739a00fe08bc08"
EXPECTED_CAPTURED_AT_UTC = "2026-07-22T19:23:25Z"
EXPECTED_CAPTURE_COMMAND = (
    "slither . --config-file slither.config.json --foundry-compile-all "
    "--json <temp-file>"
)
EXPECTED_GATE_COMMAND = (
    "python -m slither . --config-file slither.config.json --foundry-compile-all "
    "--exclude-low --exclude-informational --exclude-optimization "
    "--json-types detectors --json <temp-file> --fail-none"
)
EXPECTED_CAPTURE_NATIVE_EXIT_CODE = -1
EXPECTED_RAW_JSON_SIZE_BYTES = 143_333_855
EXPECTED_RAW_JSON_SHA256 = (
    "sha256:d98273df2d70954fd4442b11ca1b628b575788bf93cfc18f8918a91a9323c14c"
)

IMPACTS = ("High", "Medium")
EXPECTED_COUNTS = {"High": 4, "Medium": 34, "total": 38}
EXPECTED_CAPTURE_COUNTS = {
    "High": 46,
    "Medium": 579,
    "Low": 692,
    "Informational": 853,
    "Optimization": 34,
    "total": 2204,
}
EXPECTED_SCOPE_COUNTS = {
    "first_party_production": {"High": 4, "Medium": 34, "total": 38},
    "vendored": {"High": 1, "Medium": 9, "total": 10},
    "test": {"High": 41, "Medium": 529, "total": 570},
    "script": {"High": 0, "Medium": 7, "total": 7},
    "other": {"High": 0, "Medium": 0, "total": 0},
}
EXPECTED_TRIAGE_COUNTS = {
    "confirmed_gap": 1,
    "design_review": 6,
    "pending_disposition": 31,
}
EXPECTED_DETECTOR_COUNTS = {
    ("High", "arbitrary-send-eth"): 2,
    ("High", "uninitialized-state"): 2,
    ("Medium", "incorrect-equality"): 5,
    ("Medium", "reentrancy-no-eth"): 4,
    ("Medium", "uninitialized-local"): 12,
    ("Medium", "unused-return"): 13,
}
VENDORED_PATHS = (
    "smart-contracts/Base64.sol",
    "smart-contracts/Math.sol",
    "smart-contracts/SignedMath.sol",
    "smart-contracts/Strings.sol",
)
SCOPE_ORDER = (
    "first_party_production",
    "vendored",
    "test",
    "script",
    "other",
)
IDENTITY_FIELDS = (
    "fingerprint",
    "detector",
    "impact",
    "confidence",
    "source",
    "semantic_elements",
)
SEMANTIC_FIELDS = (
    "path",
    "start_line",
    "end_line",
    "element_type",
    "name",
    "signature",
)
ROW_FIELDS = IDENTITY_FIELDS + (
    "source_kind",
    "status",
    "triage_class",
    "rationale",
    "owner",
    "issues",
    "required_proof",
    "gate",
)
TOP_LEVEL_FIELDS = (
    "schema_version",
    "provenance",
    "scope",
    "capture_counts",
    "captured_high_medium_scope_counts",
    "counts",
    "findings",
)
PROVENANCE_FIELDS = (
    "analyzed_commit",
    "captured_at_utc",
    "slither_version",
    "crytic_compile_version",
    "solc_version",
    "solc_select_version",
    "foundry_version",
    "capture_command",
    "gate_command",
    "capture_native_exit_code",
    "capture_json_success",
    "raw_json_size_bytes",
    "raw_json_sha256",
    "solidity_tree_sha256",
    "slither_config_sha256",
    "foundry_config_sha256",
    "requirements_tools_sha256",
)
SCOPE_FIELDS = (
    "included_impacts",
    "first_party_prefix",
    "vendored_paths",
    "test_prefix",
    "script_prefix",
    "classification_rule",
)
HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
CAPTURE_TIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


class SlitherBaselineError(ValueError):
    """Raised when baseline structure, provenance, or live output drifts."""


def require_dict(value: Any, label: str) -> Dict[str, Any]:
    if not isinstance(value, dict):
        raise SlitherBaselineError(f"{label} must be an object")
    return value


def require_list(value: Any, label: str) -> List[Any]:
    if not isinstance(value, list):
        raise SlitherBaselineError(f"{label} must be an array")
    return value


def require_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise SlitherBaselineError(f"{label} must be a non-empty string")
    return value


def require_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise SlitherBaselineError(f"{label} must be an integer")
    return value


def require_exact_keys(value: Mapping[str, Any], expected: Sequence[str], label: str) -> None:
    actual = set(value)
    wanted = set(expected)
    if actual != wanted:
        missing = sorted(wanted - actual)
        unexpected = sorted(actual - wanted)
        parts = []
        if missing:
            parts.append("missing " + ", ".join(missing))
        if unexpected:
            parts.append("unexpected " + ", ".join(unexpected))
        raise SlitherBaselineError(f"{label} fields drifted: {'; '.join(parts)}")


def normalized_bytes(path: Path) -> bytes:
    return path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")


def file_sha256(path: Path) -> str:
    if not path.is_file():
        raise SlitherBaselineError(f"missing provenance input: {path}")
    return "sha256:" + hashlib.sha256(normalized_bytes(path)).hexdigest()


def solidity_tree_sha256(repo_root: Path) -> str:
    paths: List[Path] = []
    for root in SOLIDITY_ROOTS:
        absolute_root = repo_root / root
        if absolute_root.is_dir():
            paths.extend(absolute_root.rglob("*.sol"))
    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda item: item.relative_to(repo_root).as_posix()):
        relative = path.relative_to(repo_root).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(normalized_bytes(path))
        digest.update(b"\0")
    return "sha256:" + digest.hexdigest()


def normalize_path(value: Any) -> str:
    path = require_string(value, "source path").replace("\\", "/")
    while path.startswith("./"):
        path = path[2:]
    if path.startswith("/") or re.match(r"^[A-Za-z]:/", path) or ".." in Path(path).parts:
        raise SlitherBaselineError(f"source path must be repository-relative: {path}")
    return path


def semantic_sort_key(element: Mapping[str, Any]) -> Tuple[Any, ...]:
    return tuple(element[field] for field in SEMANTIC_FIELDS)


def normalize_element(element_value: Any) -> Dict[str, Any]:
    element = require_dict(element_value, "Slither element")
    mapping = require_dict(element.get("source_mapping"), "Slither element source_mapping")
    lines = require_list(mapping.get("lines"), "Slither source lines")
    if not lines:
        raise SlitherBaselineError("Slither source element has no line information")
    start_line = require_int(lines[0], "Slither source start line")
    end_line = require_int(lines[-1], "Slither source end line")
    type_specific = element.get("type_specific_fields")
    signature = ""
    if isinstance(type_specific, dict) and isinstance(type_specific.get("signature"), str):
        signature = type_specific["signature"]
    return {
        "path": normalize_path(mapping.get("filename_relative")),
        "start_line": start_line,
        "end_line": end_line,
        "element_type": require_string(element.get("type"), "Slither element type"),
        "name": require_string(element.get("name"), "Slither element name"),
        "signature": signature,
    }


def canonical_identity_payload(finding: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        "detector": finding["detector"],
        "impact": finding["impact"],
        "confidence": finding["confidence"],
        "source": finding["source"],
        "semantic_elements": finding["semantic_elements"],
    }


def semantic_fingerprint(finding: Mapping[str, Any]) -> str:
    payload = json.dumps(
        canonical_identity_payload(finding),
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def normalize_detector(detector_value: Any) -> Optional[Dict[str, Any]]:
    detector = require_dict(detector_value, "Slither detector")
    impact = require_string(detector.get("impact"), "Slither detector impact")
    if impact not in IMPACTS:
        return None
    elements = require_list(detector.get("elements"), "Slither detector elements")
    if not elements:
        raise SlitherBaselineError("High/Medium Slither detector has no source elements")
    primary = normalize_element(elements[0])
    semantic_elements = sorted(
        (normalize_element(element) for element in elements), key=semantic_sort_key
    )
    finding: Dict[str, Any] = {
        "detector": require_string(detector.get("check"), "Slither detector check"),
        "impact": impact,
        "confidence": require_string(
            detector.get("confidence"), "Slither detector confidence"
        ),
        "source": primary,
        "semantic_elements": semantic_elements,
    }
    finding["fingerprint"] = semantic_fingerprint(finding)
    return finding


def classify_source(path: str) -> str:
    if path in VENDORED_PATHS:
        return "vendored"
    if path.startswith("smart-contracts/"):
        return "first_party_production"
    if path.startswith("test/"):
        return "test"
    if path.startswith("script/"):
        return "script"
    return "other"


def load_json(path: Path, label: str) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return require_dict(json.load(handle), label)
    except (OSError, json.JSONDecodeError) as exc:
        raise SlitherBaselineError(f"cannot load {label} from {path}: {exc}") from exc


def normalized_slither_findings(document: Mapping[str, Any]) -> List[Dict[str, Any]]:
    if document.get("success") is not True or document.get("error") is not None:
        raise SlitherBaselineError(
            "Slither JSON must report success=true and error=null before findings are trusted"
        )
    results = require_dict(document.get("results"), "Slither results")
    detectors = results.get("detectors", [])
    normalized = []
    for detector in require_list(detectors, "Slither results.detectors"):
        finding = normalize_detector(detector)
        if finding is not None:
            normalized.append(finding)
    fingerprints = [finding["fingerprint"] for finding in normalized]
    duplicates = sorted(
        fingerprint for fingerprint, count in Counter(fingerprints).items() if count > 1
    )
    if duplicates:
        raise SlitherBaselineError(
            "normalized Slither output contains duplicate fingerprints: "
            + ", ".join(duplicates)
        )
    return normalized


def row_sort_key(row: Mapping[str, Any]) -> Tuple[Any, ...]:
    impact_rank = {"High": 0, "Medium": 1}
    source = row["source"]
    return (
        impact_rank[row["impact"]],
        row["detector"],
        source["path"],
        source["start_line"],
        source["end_line"],
        row["fingerprint"],
    )


def validate_hash(value: Any, label: str) -> str:
    digest = require_string(value, label)
    if not HASH_RE.fullmatch(digest):
        raise SlitherBaselineError(f"{label} must use sha256:<64 lowercase hex>")
    return digest


def validate_semantic_element(value: Any, label: str) -> Dict[str, Any]:
    element = require_dict(value, label)
    require_exact_keys(element, SEMANTIC_FIELDS, label)
    path = normalize_path(element["path"])
    start = require_int(element["start_line"], f"{label}.start_line")
    end = require_int(element["end_line"], f"{label}.end_line")
    if start <= 0 or end < start:
        raise SlitherBaselineError(f"{label} has an invalid line range")
    require_string(element["element_type"], f"{label}.element_type")
    require_string(element["name"], f"{label}.name")
    if not isinstance(element["signature"], str):
        raise SlitherBaselineError(f"{label}.signature must be a string")
    if path != element["path"]:
        raise SlitherBaselineError(f"{label}.path is not normalized")
    return element


def validate_source_anchor(repo_root: Path, source: Mapping[str, Any], label: str) -> None:
    path = repo_root / source["path"]
    if not path.is_file():
        raise SlitherBaselineError(f"{label} points to missing source: {source['path']}")
    line_count = len(path.read_text(encoding="utf-8").splitlines())
    if source["end_line"] > line_count:
        raise SlitherBaselineError(
            f"{label} line {source['end_line']} exceeds {source['path']} ({line_count} lines)"
        )


def validate_provenance(repo_root: Path, value: Any) -> Dict[str, Any]:
    provenance = require_dict(value, "provenance")
    require_exact_keys(provenance, PROVENANCE_FIELDS, "provenance")
    commit = require_string(provenance["analyzed_commit"], "provenance.analyzed_commit")
    if not COMMIT_RE.fullmatch(commit):
        raise SlitherBaselineError("provenance.analyzed_commit must be a 40-character SHA")
    if commit != EXPECTED_ANALYZED_COMMIT:
        raise SlitherBaselineError(
            f"provenance.analyzed_commit must be {EXPECTED_ANALYZED_COMMIT}, got {commit}"
        )
    captured_at = require_string(provenance["captured_at_utc"], "provenance.captured_at_utc")
    if not CAPTURE_TIME_RE.fullmatch(captured_at):
        raise SlitherBaselineError("provenance.captured_at_utc must be YYYY-MM-DDTHH:MM:SSZ")
    if captured_at != EXPECTED_CAPTURED_AT_UTC:
        raise SlitherBaselineError(
            f"provenance.captured_at_utc must be {EXPECTED_CAPTURED_AT_UTC}, got {captured_at}"
        )
    expected_versions = {
        "slither_version": EXPECTED_SLITHER_VERSION,
        "crytic_compile_version": EXPECTED_CRYTIC_COMPILE_VERSION,
        "solc_version": EXPECTED_SOLC_VERSION,
        "solc_select_version": EXPECTED_SOLC_SELECT_VERSION,
        "foundry_version": EXPECTED_FOUNDRY_VERSION,
    }
    for field, expected in expected_versions.items():
        if provenance[field] != expected:
            raise SlitherBaselineError(
                f"provenance.{field} must be {expected!r}, got {provenance[field]!r}"
            )
    capture_command = require_string(
        provenance["capture_command"], "provenance.capture_command"
    )
    if capture_command != EXPECTED_CAPTURE_COMMAND:
        raise SlitherBaselineError(
            f"provenance.capture_command must be {EXPECTED_CAPTURE_COMMAND!r}"
        )
    gate_command = require_string(provenance["gate_command"], "provenance.gate_command")
    if gate_command != EXPECTED_GATE_COMMAND:
        raise SlitherBaselineError(
            f"provenance.gate_command must be {EXPECTED_GATE_COMMAND!r}"
        )
    capture_exit = require_int(
        provenance["capture_native_exit_code"],
        "provenance.capture_native_exit_code",
    )
    if capture_exit != EXPECTED_CAPTURE_NATIVE_EXIT_CODE:
        raise SlitherBaselineError(
            "provenance.capture_native_exit_code must retain the audited -1 exit"
        )
    if provenance["capture_json_success"] is not True:
        raise SlitherBaselineError("provenance.capture_json_success must be true")
    raw_size = require_int(
        provenance["raw_json_size_bytes"], "provenance.raw_json_size_bytes"
    )
    if raw_size != EXPECTED_RAW_JSON_SIZE_BYTES:
        raise SlitherBaselineError(
            f"provenance.raw_json_size_bytes must be {EXPECTED_RAW_JSON_SIZE_BYTES}, "
            f"got {raw_size}"
        )
    raw_hash = validate_hash(
        provenance["raw_json_sha256"], "provenance.raw_json_sha256"
    )
    if raw_hash != EXPECTED_RAW_JSON_SHA256:
        raise SlitherBaselineError(
            f"provenance.raw_json_sha256 must be {EXPECTED_RAW_JSON_SHA256}, "
            f"got {raw_hash}"
        )
    expected_hashes = {
        "solidity_tree_sha256": solidity_tree_sha256(repo_root),
        "slither_config_sha256": file_sha256(repo_root / CONFIG_PATH),
        "foundry_config_sha256": file_sha256(repo_root / FOUNDRY_CONFIG_PATH),
        "requirements_tools_sha256": file_sha256(repo_root / REQUIREMENTS_PATH),
    }
    for field, expected in expected_hashes.items():
        actual = validate_hash(provenance[field], f"provenance.{field}")
        if actual != expected:
            raise SlitherBaselineError(
                f"provenance.{field} is stale: committed {actual}, current {expected}"
            )
    return provenance


def validate_scope(value: Any) -> Dict[str, Any]:
    scope = require_dict(value, "scope")
    require_exact_keys(scope, SCOPE_FIELDS, "scope")
    expected = {
        "included_impacts": list(IMPACTS),
        "first_party_prefix": "smart-contracts/",
        "vendored_paths": list(VENDORED_PATHS),
        "test_prefix": "test/",
        "script_prefix": "script/",
        "classification_rule": "classify by the primary Slither source element; unknown smart-contracts paths fail closed as first-party production",
    }
    if scope != expected:
        raise SlitherBaselineError("scope policy differs from the checked first-party policy")
    return scope


def validate_count_object(value: Any, label: str, impacts: Sequence[str]) -> Dict[str, int]:
    counts = require_dict(value, label)
    expected_keys = list(impacts) + ["total"]
    require_exact_keys(counts, expected_keys, label)
    total = 0
    for impact in impacts:
        count = require_int(counts[impact], f"{label}.{impact}")
        if count < 0:
            raise SlitherBaselineError(f"{label}.{impact} must be non-negative")
        total += count
    if require_int(counts["total"], f"{label}.total") != total:
        raise SlitherBaselineError(f"{label}.total does not equal its impact counts")
    return counts


def validate_baseline_data(repo_root: Path, data_value: Any) -> Dict[str, Any]:
    data = require_dict(data_value, "baseline")
    require_exact_keys(data, TOP_LEVEL_FIELDS, "baseline")
    if data["schema_version"] != SCHEMA_VERSION:
        raise SlitherBaselineError(f"schema_version must be {SCHEMA_VERSION!r}")
    validate_provenance(repo_root, data["provenance"])
    validate_scope(data["scope"])
    capture_counts = validate_count_object(
        data["capture_counts"],
        "capture_counts",
        ("High", "Medium", "Low", "Informational", "Optimization"),
    )
    if capture_counts != EXPECTED_CAPTURE_COUNTS:
        raise SlitherBaselineError(
            f"capture_counts must be {EXPECTED_CAPTURE_COUNTS}, got {capture_counts}"
        )
    scope_counts = require_dict(
        data["captured_high_medium_scope_counts"],
        "captured_high_medium_scope_counts",
    )
    require_exact_keys(scope_counts, SCOPE_ORDER, "captured_high_medium_scope_counts")
    for scope_name in SCOPE_ORDER:
        scope_row = validate_count_object(
            scope_counts[scope_name],
            f"captured_high_medium_scope_counts.{scope_name}",
            IMPACTS,
        )
        if scope_row != EXPECTED_SCOPE_COUNTS[scope_name]:
            raise SlitherBaselineError(
                f"captured_high_medium_scope_counts.{scope_name} must be "
                f"{EXPECTED_SCOPE_COUNTS[scope_name]}, got {scope_row}"
            )
    counts = validate_count_object(data["counts"], "counts", IMPACTS)
    if counts != EXPECTED_COUNTS:
        raise SlitherBaselineError(
            f"first-party counts must be {EXPECTED_COUNTS}, got {counts}"
        )
    rows = require_list(data["findings"], "findings")
    if len(rows) != EXPECTED_COUNTS["total"]:
        raise SlitherBaselineError(
            f"findings must contain exactly {EXPECTED_COUNTS['total']} rows"
        )
    validated_rows: List[Dict[str, Any]] = []
    fingerprints = set()
    triage_counts: Counter[str] = Counter()
    detector_counts: Counter[Tuple[str, str]] = Counter()
    impact_counts: Counter[str] = Counter()
    for index, row_value in enumerate(rows):
        label = f"findings[{index}]"
        row = require_dict(row_value, label)
        require_exact_keys(row, ROW_FIELDS, label)
        fingerprint = validate_hash(row["fingerprint"], f"{label}.fingerprint")
        if fingerprint in fingerprints:
            raise SlitherBaselineError(f"duplicate finding fingerprint: {fingerprint}")
        fingerprints.add(fingerprint)
        detector = require_string(row["detector"], f"{label}.detector")
        impact = require_string(row["impact"], f"{label}.impact")
        if impact not in IMPACTS:
            raise SlitherBaselineError(f"{label}.impact must be High or Medium")
        require_string(row["confidence"], f"{label}.confidence")
        source = validate_semantic_element(row["source"], f"{label}.source")
        semantic_values = require_list(row["semantic_elements"], f"{label}.semantic_elements")
        semantic = [
            validate_semantic_element(value, f"{label}.semantic_elements[{item_index}]")
            for item_index, value in enumerate(semantic_values)
        ]
        if not semantic or semantic != sorted(semantic, key=semantic_sort_key):
            raise SlitherBaselineError(f"{label}.semantic_elements must be non-empty and sorted")
        if source not in semantic:
            raise SlitherBaselineError(f"{label}.source is absent from semantic_elements")
        for item_index, element in enumerate(semantic):
            validate_source_anchor(
                repo_root, element, f"{label}.semantic_elements[{item_index}]"
            )
        if row["source_kind"] != "first_party_production":
            raise SlitherBaselineError(f"{label}.source_kind must be first_party_production")
        if classify_source(source["path"]) != "first_party_production":
            raise SlitherBaselineError(f"{label} is outside first-party production scope")
        validate_source_anchor(repo_root, source, f"{label}.source")
        if row["status"] != "Open":
            raise SlitherBaselineError(f"{label}.status must remain Open in the current baseline")
        triage_class = require_string(row["triage_class"], f"{label}.triage_class")
        if triage_class not in EXPECTED_TRIAGE_COUNTS:
            raise SlitherBaselineError(f"{label}.triage_class is unsupported")
        require_string(row["rationale"], f"{label}.rationale")
        require_string(row["owner"], f"{label}.owner")
        issues = require_list(row["issues"], f"{label}.issues")
        if not issues or not all(
            isinstance(issue, str)
            and issue.startswith("https://github.com/6529-Collections/6529Stream/issues/")
            for issue in issues
        ):
            raise SlitherBaselineError(f"{label}.issues must contain canonical issue URLs")
        if not any(issue.endswith("/658") for issue in issues):
            raise SlitherBaselineError(f"{label}.issues must include issue #658")
        proof = require_list(row["required_proof"], f"{label}.required_proof")
        if not proof or not all(isinstance(item, str) and item.strip() for item in proof):
            raise SlitherBaselineError(f"{label}.required_proof must be non-empty strings")
        if row["gate"] != "Gate C / Gate F":
            raise SlitherBaselineError(f"{label}.gate must be 'Gate C / Gate F'")
        expected_fingerprint = semantic_fingerprint(row)
        if fingerprint != expected_fingerprint:
            raise SlitherBaselineError(
                f"{label}.fingerprint is stale: {fingerprint}, expected {expected_fingerprint}"
            )
        if triage_class == "confirmed_gap":
            if not (
                detector == "uninitialized-state"
                and source["path"] == "smart-contracts/StreamCore.sol"
                and source["name"] == "collectionBurnsBlockedAtBlockHeights"
                and any(issue.endswith("/654") for issue in issues)
            ):
                raise SlitherBaselineError("confirmed_gap must be the #654 Core burn-block row")
        elif triage_class == "design_review" and detector not in {
            "arbitrary-send-eth",
            "reentrancy-no-eth",
        }:
            raise SlitherBaselineError(
                f"{label}.design_review must be an arbitrary-send or reentrancy row"
            )
        elif triage_class == "pending_disposition" and detector in {
            "arbitrary-send-eth",
            "reentrancy-no-eth",
        }:
            raise SlitherBaselineError(
                f"{label} leaves a design-review detector in pending_disposition"
            )
        triage_counts[triage_class] += 1
        detector_counts[(impact, detector)] += 1
        impact_counts[impact] += 1
        validated_rows.append(row)
    if dict(triage_counts) != EXPECTED_TRIAGE_COUNTS:
        raise SlitherBaselineError(
            f"triage counts must be {EXPECTED_TRIAGE_COUNTS}, got {dict(triage_counts)}"
        )
    if dict(detector_counts) != EXPECTED_DETECTOR_COUNTS:
        raise SlitherBaselineError(
            f"detector counts must be {EXPECTED_DETECTOR_COUNTS}, got {dict(detector_counts)}"
        )
    if {impact: impact_counts[impact] for impact in IMPACTS} != {
        impact: counts[impact] for impact in IMPACTS
    }:
        raise SlitherBaselineError("finding impact counts do not match counts")
    if validated_rows != sorted(validated_rows, key=row_sort_key):
        raise SlitherBaselineError("findings must use canonical sort order")
    return data


def markdown_escape(value: str) -> str:
    return value.replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def markdown_count_table(counts: Mapping[str, Any], impacts: Sequence[str]) -> List[str]:
    lines = ["| Impact | Count |", "| --- | ---: |"]
    for impact in impacts:
        lines.append(f"| {impact} | {counts[impact]} |")
    lines.append(f"| Total | {counts['total']} |")
    return lines


def render_markdown(data: Mapping[str, Any]) -> str:
    provenance = data["provenance"]
    scope_counts = data["captured_high_medium_scope_counts"]
    lines = [
        "# Slither Baseline",
        "",
        "This is the current first-party production High/Medium Slither inventory.",
        "Passing the drift gate means the inventory matches the analyzed source; it does",
        "not accept any finding, complete a security audit, or make the protocol ready for",
        "public beta or production. All 38 current rows remain `Open` under issue #658.",
        "",
        "## Capture Provenance",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Analyzed commit | `{provenance['analyzed_commit']}` |",
        f"| Captured at | `{provenance['captured_at_utc']}` |",
        f"| Slither | `{provenance['slither_version']}` |",
        f"| crytic-compile | `{provenance['crytic_compile_version']}` |",
        f"| Solidity compiler | `{provenance['solc_version']}` |",
        f"| solc-select | `{provenance['solc_select_version']}` |",
        f"| Foundry | `{provenance['foundry_version']}` |",
        f"| Production Solidity tree (`smart-contracts/**/*.sol`) | `{provenance['solidity_tree_sha256']}` |",
        f"| Slither config | `{provenance['slither_config_sha256']}` |",
        f"| Foundry config | `{provenance['foundry_config_sha256']}` |",
        f"| Current gate tool requirements | `{provenance['requirements_tools_sha256']}` |",
        f"| Capture command | `{markdown_escape(provenance['capture_command'])}` |",
        f"| Gate command | `{markdown_escape(provenance['gate_command'])}` |",
        f"| Capture process | Native exit `{provenance['capture_native_exit_code']}`; JSON `success=true`; `{provenance['raw_json_size_bytes']}` bytes |",
        f"| Raw JSON SHA-256 | `{provenance['raw_json_sha256']}` |",
        "",
        "The default Slither process exit is non-zero while findings exist. The checked",
        "gate uses `--fail-none`, then independently requires native success, JSON",
        "`success=true`, `error=null`, and an exact normalized first-party row match.",
        "",
        "## Full Capture Impact Counts",
        "",
    ]
    lines.extend(
        markdown_count_table(
            data["capture_counts"],
            ("High", "Medium", "Low", "Informational", "Optimization"),
        )
    )
    lines.extend(
        [
            "",
            "## High/Medium Scope Separation",
            "",
            "Only first-party production rows are release-blocking inventory. Vendored,",
            "test, and script rows stay visible as separately classified diagnostic input.",
            "",
            "| Scope | High | Medium | Total |",
            "| --- | ---: | ---: | ---: |",
        ]
    )
    for scope_name in SCOPE_ORDER:
        counts = scope_counts[scope_name]
        label = scope_name.replace("_", " ")
        lines.append(
            f"| {label} | {counts['High']} | {counts['Medium']} | {counts['total']} |"
        )
    lines.extend(
        [
            "",
            "## Current First-Party Production Findings",
            "",
            "The JSON companion is canonical. This table is a deterministic mirror checked",
            "by `scripts/check_slither_baseline.py --baseline-only`.",
            "",
            "| Fingerprint | Impact | Detector | Confidence | Source | Status | Triage | Owner | Issues | Rationale | Required proof | Gate |",
            "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
        ]
    )
    for row in data["findings"]:
        source = row["source"]
        source_label = (
            f"{source['path']}:{source['start_line']}-{source['end_line']} "
            f"`{source['signature'] or source['name']}`"
        )
        issue_links = ", ".join(
            f"[#{issue.rsplit('/', 1)[-1]}]({issue})" for issue in row["issues"]
        )
        proof = "<br>".join(markdown_escape(item) for item in row["required_proof"])
        cells = [
            f"`{row['fingerprint']}`",
            row["impact"],
            f"`{row['detector']}`",
            row["confidence"],
            markdown_escape(source_label),
            f"`{row['status']}`",
            f"`{row['triage_class']}`",
            markdown_escape(row["owner"]),
            issue_links,
            markdown_escape(row["rationale"]),
            proof,
            row["gate"],
        ]
        lines.append("| " + " | ".join(cells) + " |")
    lines.extend(
        [
            "",
            "## Triage Counts",
            "",
            "| Classification | Open rows |",
            "| --- | ---: |",
            f"| `confirmed_gap` | {EXPECTED_TRIAGE_COUNTS['confirmed_gap']} |",
            f"| `design_review` | {EXPECTED_TRIAGE_COUNTS['design_review']} |",
            f"| `pending_disposition` | {EXPECTED_TRIAGE_COUNTS['pending_disposition']} |",
            f"| Total | {sum(EXPECTED_TRIAGE_COUNTS.values())} |",
            "",
            "## Triage Boundary",
            "",
            "- `confirmed_gap` is the unwritten Core burn-block activation-height mapping;",
            "  it remains owned by #654 and cannot be accepted or marked fixed here.",
            "- `design_review` covers two governed/native-value transfer rows and four",
            "  callback/order rows. Existing guards do not replace threat-model and",
            "  adversarial-test evidence.",
            "- `pending_disposition` covers default/sentinel/ignored-field candidates. Each",
            "  row needs its own executable proof before `Accepted` or `False Positive`.",
            "- No broad detector suppression is part of this baseline.",
            "- A removed row also fails drift until this inventory and its disposition",
            "  history are deliberately refreshed.",
            "",
            "## Commands",
            "",
            "```text",
            "python scripts/test_slither_baseline.py",
            "python scripts/check_slither_baseline.py --render-markdown",
            "python scripts/check_slither_baseline.py --baseline-only",
            "python scripts/check_slither_baseline.py --run-slither",
            "```",
            "",
        ]
    )
    return "\n".join(lines)


def validate_markdown_mirror(path: Path, data: Mapping[str, Any]) -> None:
    if not path.is_file():
        raise SlitherBaselineError(f"missing Markdown mirror: {path}")
    actual = path.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    expected = render_markdown(data)
    if actual != expected:
        raise SlitherBaselineError(
            f"Markdown mirror drifted: {path}; regenerate it from {DEFAULT_BASELINE}"
        )


def validate_baseline(repo_root: Path, baseline_path: Path, markdown_path: Path) -> Dict[str, Any]:
    data = validate_baseline_data(repo_root, load_json(baseline_path, "baseline"))
    validate_markdown_mirror(markdown_path, data)
    return data


def finding_identity(row: Mapping[str, Any]) -> Dict[str, Any]:
    return {field: row[field] for field in IDENTITY_FIELDS}


def scope_counts(findings: Iterable[Mapping[str, Any]]) -> Dict[str, Dict[str, int]]:
    result = {
        scope: {"High": 0, "Medium": 0, "total": 0} for scope in SCOPE_ORDER
    }
    for finding in findings:
        scope = classify_source(finding["source"]["path"])
        result[scope][finding["impact"]] += 1
        result[scope]["total"] += 1
    return result


def normalized_candidate_report(document: Mapping[str, Any]) -> Dict[str, Any]:
    """Build non-authoritative normalized identities for intentional rebaseline work."""
    findings = normalized_slither_findings(document)
    first_party = sorted(
        (
            finding_identity(row)
            for row in findings
            if classify_source(row["source"]["path"]) == "first_party_production"
        ),
        key=row_sort_key,
    )
    return {
        "schema_version": CANDIDATE_SCHEMA_VERSION,
        "readiness_boundary": (
            "Diagnostic candidate output is not a reviewed baseline, finding "
            "disposition, audit result, or release approval."
        ),
        "scope_counts": scope_counts(findings),
        "first_party_production_findings": first_party,
    }


def write_candidate_report(path: Path, report: Mapping[str, Any]) -> None:
    """Write a deterministic candidate report without creating parent directories."""
    try:
        path.write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    except OSError as exc:
        raise SlitherBaselineError(f"cannot write candidate report to {path}: {exc}") from exc


def write_markdown_mirror(path: Path, data: Mapping[str, Any]) -> None:
    """Write the deterministic reviewer-facing Markdown mirror."""
    try:
        path.write_text(
            render_markdown(data),
            encoding="utf-8",
            newline="\n",
        )
    except OSError as exc:
        raise SlitherBaselineError(f"cannot write Markdown mirror to {path}: {exc}") from exc


def format_drift_row(row: Mapping[str, Any]) -> str:
    source = row["source"]
    return (
        f"{row['impact']} {row['detector']} {source['path']}:"
        f"{source['start_line']}-{source['end_line']} {row['fingerprint']}"
    )


def compare_live_findings(
    baseline: Mapping[str, Any], findings: Sequence[Mapping[str, Any]]
) -> Dict[str, Dict[str, int]]:
    counts = scope_counts(findings)
    actual_rows = {
        row["fingerprint"]: finding_identity(row)
        for row in findings
        if classify_source(row["source"]["path"]) == "first_party_production"
    }
    expected_rows = {
        row["fingerprint"]: finding_identity(row) for row in baseline["findings"]
    }
    missing = sorted(set(expected_rows) - set(actual_rows))
    unexpected = sorted(set(actual_rows) - set(expected_rows))
    changed = sorted(
        fingerprint
        for fingerprint in set(expected_rows) & set(actual_rows)
        if expected_rows[fingerprint] != actual_rows[fingerprint]
    )
    if missing or unexpected or changed:
        parts = []
        if unexpected:
            parts.append(
                "unreviewed first-party row(s): "
                + "; ".join(format_drift_row(actual_rows[item]) for item in unexpected)
            )
        if missing:
            parts.append(
                "stale/removed baseline row(s): "
                + "; ".join(format_drift_row(expected_rows[item]) for item in missing)
            )
        if changed:
            parts.append("changed normalized row(s): " + ", ".join(changed))
        raise SlitherBaselineError("live Slither baseline drifted; " + "; ".join(parts))
    return counts


def slither_command(output_path: Path) -> List[str]:
    return [
        sys.executable,
        "-m",
        "slither",
        ".",
        "--config-file",
        CONFIG_PATH.as_posix(),
        "--foundry-compile-all",
        "--exclude-low",
        "--exclude-informational",
        "--exclude-optimization",
        "--json-types",
        "detectors",
        "--json",
        str(output_path),
        "--fail-none",
    ]


def parse_forge_version(output: str) -> Optional[str]:
    for line in output.splitlines():
        match = re.fullmatch(r"forge Version:\s+(\d+\.\d+\.\d+)", line.strip())
        if match:
            return match.group(1)
    return None


def parse_solc_version(output: str) -> Optional[str]:
    for line in output.splitlines():
        match = re.fullmatch(
            r"Version:\s+(\d+\.\d+\.\d+)(?:\+\S+)?", line.strip()
        )
        if match:
            return match.group(1)
    return None


def validate_live_tool_versions(repo_root: Path) -> None:
    package_versions = {
        "slither-analyzer": EXPECTED_SLITHER_VERSION,
        "crytic-compile": EXPECTED_CRYTIC_COMPILE_VERSION,
        "solc-select": EXPECTED_SOLC_SELECT_VERSION,
    }
    for package, expected in package_versions.items():
        try:
            actual = metadata.version(package)
        except metadata.PackageNotFoundError as exc:
            raise SlitherBaselineError(
                f"missing {package}; install requirements-tools.txt before the live gate"
            ) from exc
        if actual != expected:
            raise SlitherBaselineError(
                f"{package} version drifted: expected {expected}, got {actual}"
            )
    try:
        result = subprocess.run(
            ["forge", "--version"],
            cwd=str(repo_root),
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        raise SlitherBaselineError("forge was not found for the live Slither gate") from exc
    output = (result.stdout + "\n" + result.stderr).strip()
    actual_version = parse_forge_version(output)
    if result.returncode != 0 or actual_version != EXPECTED_FOUNDRY_VERSION:
        raise SlitherBaselineError(
            f"Foundry version drifted; expected {EXPECTED_FOUNDRY_VERSION}, "
            f"got {actual_version!r}: {output}"
        )
    try:
        result = subprocess.run(
            ["solc", "--version"],
            cwd=str(repo_root),
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        raise SlitherBaselineError("solc was not found for the live Slither gate") from exc
    output = (result.stdout + "\n" + result.stderr).strip()
    actual_version = parse_solc_version(output)
    if result.returncode != 0 or actual_version != EXPECTED_SOLC_VERSION:
        raise SlitherBaselineError(
            f"solc version drifted; expected {EXPECTED_SOLC_VERSION}, "
            f"got {actual_version!r}: {output}"
        )


def run_slither(repo_root: Path) -> Dict[str, Any]:
    validate_live_tool_versions(repo_root)
    with tempfile.TemporaryDirectory(prefix="6529stream-slither-") as temp_dir:
        output_path = Path(temp_dir) / "slither-high-medium.json"
        command = slither_command(output_path)
        result = subprocess.run(
            command,
            cwd=str(repo_root),
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            diagnostic = (result.stderr or result.stdout)[-4000:]
            raise SlitherBaselineError(
                f"Slither live gate exited {result.returncode} despite --fail-none:\n{diagnostic}"
            )
        if not output_path.is_file():
            raise SlitherBaselineError("Slither live gate did not produce JSON output")
        return load_json(output_path, "live Slither JSON")


def report_scope_counts(counts: Mapping[str, Mapping[str, int]]) -> None:
    for scope in SCOPE_ORDER:
        row = counts[scope]
        print(
            f"Slither H/M scope {scope}: High={row['High']} "
            f"Medium={row['Medium']} total={row['total']}"
        )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--markdown", type=Path, default=DEFAULT_MARKDOWN)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--baseline-only", action="store_true")
    mode.add_argument("--run-slither", action="store_true")
    mode.add_argument(
        "--render-markdown",
        action="store_true",
        help="Validate canonical JSON and regenerate its deterministic Markdown mirror.",
    )
    mode.add_argument(
        "--slither-json",
        type=Path,
        help="Compare a retained Slither JSON result instead of invoking Slither.",
    )
    mode.add_argument(
        "--candidate-slither-json",
        type=Path,
        help=(
            "Normalize retained Slither JSON for rebaseline review without validating "
            "the currently stale baseline. This is diagnostic only."
        ),
    )
    parser.add_argument(
        "--candidate-output",
        type=Path,
        help="Output path required with --candidate-slither-json.",
    )
    return parser.parse_args(argv)


def resolve_under_root(repo_root: Path, path: Path) -> Path:
    return path if path.is_absolute() else repo_root / path


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    baseline_path = resolve_under_root(repo_root, args.baseline)
    markdown_path = resolve_under_root(repo_root, args.markdown)
    try:
        if args.candidate_slither_json is not None:
            if args.candidate_output is None:
                raise SlitherBaselineError(
                    "--candidate-output is required with --candidate-slither-json"
                )
            candidate_input_path = resolve_under_root(
                repo_root, args.candidate_slither_json
            )
            output_path = resolve_under_root(repo_root, args.candidate_output)
            if output_path.resolve() == candidate_input_path.resolve():
                raise SlitherBaselineError(
                    "candidate output cannot overwrite the candidate Slither JSON input"
                )
            if output_path.resolve() in {
                baseline_path.resolve(),
                markdown_path.resolve(),
            }:
                raise SlitherBaselineError(
                    "candidate output cannot overwrite the canonical baseline or Markdown mirror"
                )
            document = load_json(candidate_input_path, "candidate Slither JSON")
            report = normalized_candidate_report(document)
            write_candidate_report(output_path, report)
            report_scope_counts(report["scope_counts"])
            print(
                f"Wrote diagnostic normalized Slither candidate: {output_path}; "
                "this is not baseline acceptance"
            )
            return 0
        if args.candidate_output is not None:
            raise SlitherBaselineError(
                "--candidate-output is only valid with --candidate-slither-json"
            )
        if args.render_markdown:
            baseline = validate_baseline_data(
                repo_root,
                load_json(baseline_path, "baseline"),
            )
            write_markdown_mirror(markdown_path, baseline)
            print(f"Regenerated deterministic Slither Markdown mirror: {markdown_path}")
            return 0
        baseline = validate_baseline(repo_root, baseline_path, markdown_path)
        if args.run_slither or args.slither_json is not None:
            if args.run_slither:
                document = run_slither(repo_root)
            else:
                document = load_json(
                    resolve_under_root(repo_root, args.slither_json),
                    "retained Slither JSON",
                )
            findings = normalized_slither_findings(document)
            counts = compare_live_findings(baseline, findings)
            report_scope_counts(counts)
    except SlitherBaselineError as exc:
        print(f"Slither baseline check failed: {exc}", file=sys.stderr)
        return 1
    if args.run_slither or args.slither_json is not None:
        print("Slither first-party High/Medium live baseline is current")
    else:
        print("Slither baseline schema, provenance, and Markdown mirror are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
