#!/usr/bin/env python3
"""Prove semantic equivalence across the reviewed Solidity source-layout move."""

from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence

import check_solidity_source_layout as layout


SCHEMA = "6529stream.solidity-layout-equivalence.v1"
DEFAULT_REPORT = Path("release-artifacts/evidence/solidity-layout-equivalence.json")
IMPORT_RE = re.compile(r'''(import\s+(?:[^"']*?\sfrom\s+)?["'])([^"']+)(["'])''')
EXPECTED_COMPILER_IDENTITY_DIFFERENCES = [
    "source paths and compiler source IDs",
    "source maps and AST IDs",
    "path-derived library placeholder hashes and positions",
    "via-IR internal function ordering and jump destinations",
    "compiler metadata and source hashes",
]
MATURITY_EFFECT = "none; pre-audit and not production-ready"
EXPECTED_RECEIPT_CANONICAL_SHA256 = (
    layout.EXPECTED_EQUIVALENCE_RECEIPT_CANONICAL_SHA256
)
SOURCE_RECEIPT_FIELDS = {
    "source_count",
    "exact_semantic_match_count",
    "semantic_inventory_sha256",
    "mismatches",
    "result",
}
ARTIFACT_RECEIPT_FIELDS = {
    "artifact_count",
    "semantic_surface_sha256",
    "semantic_mismatches",
    "raw_compiler_output_mismatches",
    "raw_compiler_output_mismatch_counts",
    "raw_bytecode_equal",
    "result",
}
RAW_MISMATCH_FIELDS = {
    "initcode",
    "runtime",
    "link_references",
    "immutable_references",
}
SEMANTIC_SURFACE_FIELDS = {
    "abi",
    "method_identifiers",
    "events",
    "errors",
    "storage_layout",
}
COMPILER_INPUT_RECEIPT_FIELDS = {
    "target_count",
    "exact_semantic_match_count",
    "semantic_inputs_sha256",
    "mismatches",
    "result",
}
LOWER_HEX_64_RE = re.compile(r"^[0-9a-f]{64}$")
TOP_LEVEL_FIELDS = {
    "schema_version",
    "migration_base_commit",
    "source_semantics",
    "expected_compiler_identity_differences",
    "raw_bytecode_identity_claimed",
    "maturity_effect",
    "full_foundry_artifacts",
    "release_compiler_inputs",
    "isolated_release_artifacts",
    "result",
}


class EquivalenceError(RuntimeError):
    """Raised when equivalence cannot be established."""


IJSON_SAFE_INTEGER_MAX = (1 << 53) - 1


def reject_duplicate_json_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise EquivalenceError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def parse_ijson_integer(token: str) -> int:
    value = int(token)
    if abs(value) > IJSON_SAFE_INTEGER_MAX:
        raise EquivalenceError(
            f"JSON integer is outside the I-JSON interoperable range: {token}"
        )
    return value


def reject_json_float(token: str) -> float:
    raise EquivalenceError(
        f"floating-point JSON is forbidden in layout-equivalence inputs: {token}"
    )


def reject_json_constant(token: str) -> None:
    raise EquivalenceError(f"non-I-JSON token is forbidden: {token}")


def load_strict_json(path: Path) -> Any:
    raw = path.read_bytes()
    try:
        text = raw.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise EquivalenceError(f"invalid JSON in {path}: {exc}") from exc
    try:
        return json.loads(
            text,
            object_pairs_hook=reject_duplicate_json_pairs,
            parse_int=parse_ijson_integer,
            parse_float=reject_json_float,
            parse_constant=reject_json_constant,
        )
    except json.JSONDecodeError as exc:
        raise EquivalenceError(f"invalid JSON in {path}: {exc}") from exc


def resolve_generation_output(repo_root: Path, output: Path) -> Path:
    candidate = output if output.is_absolute() else repo_root / output
    resolved = candidate.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise EquivalenceError(
            f"generation output must resolve inside repo_root: {output}"
        ) from exc
    _require(resolved != repo_root, "generation output must identify a file inside repo_root")
    return resolved


def canonical_json(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )


def sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json(value)).hexdigest()


def normalize_posix(value: str) -> str:
    parts: list[str] = []
    for part in value.replace("\\", "/").split("/"):
        if part == "..":
            if parts:
                parts.pop()
        elif part != ".":
            parts.append(part)
    return "/".join(parts)


def old_path(value: str, new_to_old: dict[str, str]) -> str:
    normalized = normalize_posix(value)
    return new_to_old.get(normalized, normalized)


def normalize_paths(value: Any, new_to_old: dict[str, str]) -> Any:
    if isinstance(value, list):
        return [normalize_paths(item, new_to_old) for item in value]
    if isinstance(value, dict):
        return {
            normalize_paths(key, new_to_old): normalize_paths(item, new_to_old)
            for key, item in sorted(value.items())
        }
    if isinstance(value, str):
        for new, old in new_to_old.items():
            value = value.replace(new, old)
        return value
    return value


def normalize_imports(content: str, source: str, new_to_old: dict[str, str]) -> str:
    def replace(match: re.Match[str]) -> str:
        target = match.group(2)
        if not target.startswith("."):
            return match.group(0)
        resolved = posixpath.normpath(posixpath.join(posixpath.dirname(source), target))
        return f"{match.group(1)}{old_path(resolved, new_to_old)}{match.group(3)}"

    return IMPORT_RE.sub(replace, content.replace("\r\n", "\n"))


def git_show(repo_root: Path, commit: str, relative: str) -> str:
    completed = subprocess.run(
        ["git", "show", f"{commit}:{relative}"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        raise EquivalenceError(f"cannot read {relative} at {commit}")
    return completed.stdout.decode("utf-8")


def source_receipt(repo_root: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    commit = manifest["migration_base_commit"]
    new_to_old = {move["new_path"]: move["old_path"] for move in manifest["moves"]}
    rows: list[dict[str, str]] = []
    mismatches: list[str] = []
    for move in manifest["moves"]:
        before = normalize_imports(
            git_show(repo_root, commit, move["old_path"]), move["old_path"], new_to_old
        )
        after = normalize_imports(
            (repo_root / move["new_path"]).read_text(encoding="utf-8"),
            move["new_path"],
            new_to_old,
        )
        if before != after:
            mismatches.append(move["old_path"])
        rows.append(
            {
                "old_path": move["old_path"],
                "new_path": move["new_path"],
                "semantic_sha256": hashlib.sha256(after.encode("utf-8")).hexdigest(),
            }
        )
    return {
        "source_count": len(rows),
        "exact_semantic_match_count": len(rows) - len(mismatches),
        "semantic_inventory_sha256": sha256(rows),
        "mismatches": mismatches,
        "result": "pass" if not mismatches else "fail",
    }


def artifact_paths(root: Path, excluded: set[str]) -> list[str]:
    return sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*.json")
        if not any(part in excluded for part in path.relative_to(root).parts)
        and path.name != "release-build-manifest.json"
    )


def normalized_links(value: dict[str, Any], new_to_old: dict[str, str]) -> list[Any]:
    rows = []
    for source, libraries in value.items():
        for library_name, positions in libraries.items():
            rows.append(
                {
                    "source": old_path(source, new_to_old),
                    "library": library_name,
                    "positions": positions,
                }
            )
    return sorted(rows, key=canonical_json)


def canonical_type(
    type_id: str, types: dict[str, Any], new_to_old: dict[str, str], seen: frozenset[str]
) -> Any:
    record = types.get(type_id)
    if record is None:
        return {"missing_type": type_id}
    signature = f"{record.get('label')}|{record.get('encoding')}|{record.get('numberOfBytes')}"
    if type_id in seen:
        return {"recursive": signature}
    next_seen = seen | {type_id}
    result: dict[str, Any] = {
        "encoding": record.get("encoding"),
        "label": normalize_paths(record.get("label"), new_to_old),
        "numberOfBytes": record.get("numberOfBytes"),
    }
    for key in ("base", "key", "value"):
        if key in record:
            result[key] = canonical_type(record[key], types, new_to_old, next_seen)
    if "members" in record:
        result["members"] = [
            {
                "contract": normalize_paths(member.get("contract"), new_to_old),
                "label": member.get("label"),
                "offset": member.get("offset"),
                "slot": member.get("slot"),
                "type": canonical_type(member["type"], types, new_to_old, next_seen),
            }
            for member in record["members"]
        ]
    return result


def canonical_storage(value: dict[str, Any], new_to_old: dict[str, str]) -> list[Any]:
    types = value.get("types", {})
    return [
        {
            "contract": normalize_paths(row.get("contract"), new_to_old),
            "label": row.get("label"),
            "offset": row.get("offset"),
            "slot": row.get("slot"),
            "type": canonical_type(row["type"], types, new_to_old, frozenset()),
        }
        for row in value.get("storage", [])
    ]


def artifact_receipt(
    before_root: Path,
    after_root: Path,
    new_to_old: dict[str, str],
    *,
    excluded: set[str],
) -> dict[str, Any]:
    before_paths = artifact_paths(before_root, excluded)
    after_paths = artifact_paths(after_root, excluded)
    _require(bool(before_paths), "pre-migration artifact inventory must not be empty")
    _require(bool(after_paths), "post-migration artifact inventory must not be empty")
    if before_paths != after_paths:
        raise EquivalenceError("pre/post artifact inventories differ")
    exact_fields = ("abi", "methodIdentifiers")
    semantic_mismatches: dict[str, list[str]] = {
        "abi": [],
        "method_identifiers": [],
        "events": [],
        "errors": [],
        "storage_layout": [],
    }
    raw_mismatches: dict[str, list[str]] = {
        "initcode": [],
        "runtime": [],
        "link_references": [],
        "immutable_references": [],
    }
    digests: dict[str, list[Any]] = {key: [] for key in semantic_mismatches}
    for relative in before_paths:
        before = load_strict_json(before_root / relative)
        after = load_strict_json(after_root / relative)
        comparisons = {
            "abi": (before.get("abi", []), after.get("abi", [])),
            "method_identifiers": (
                before.get(exact_fields[1], {}),
                after.get(exact_fields[1], {}),
            ),
            "events": (
                [row for row in before.get("abi", []) if row.get("type") == "event"],
                [row for row in after.get("abi", []) if row.get("type") == "event"],
            ),
            "errors": (
                [row for row in before.get("abi", []) if row.get("type") == "error"],
                [row for row in after.get("abi", []) if row.get("type") == "error"],
            ),
            "storage_layout": (
                canonical_storage(before.get("storageLayout", {}), new_to_old),
                canonical_storage(after.get("storageLayout", {}), new_to_old),
            ),
        }
        for field, (left, right) in comparisons.items():
            left = normalize_paths(left, new_to_old)
            right = normalize_paths(right, new_to_old)
            digests[field].append([relative, left])
            if canonical_json(left) != canonical_json(right):
                semantic_mismatches[field].append(relative)
        raw = {
            "initcode": (
                before.get("bytecode", {}).get("object", ""),
                after.get("bytecode", {}).get("object", ""),
            ),
            "runtime": (
                before.get("deployedBytecode", {}).get("object", ""),
                after.get("deployedBytecode", {}).get("object", ""),
            ),
            "link_references": (
                {
                    "initcode": normalized_links(
                        before.get("bytecode", {}).get("linkReferences", {}), new_to_old
                    ),
                    "runtime": normalized_links(
                        before.get("deployedBytecode", {}).get("linkReferences", {}),
                        new_to_old,
                    ),
                },
                {
                    "initcode": normalized_links(
                        after.get("bytecode", {}).get("linkReferences", {}), new_to_old
                    ),
                    "runtime": normalized_links(
                        after.get("deployedBytecode", {}).get("linkReferences", {}),
                        new_to_old,
                    ),
                },
            ),
            "immutable_references": (
                sorted(
                    before.get("deployedBytecode", {}).get("immutableReferences", {}).values(),
                    key=canonical_json,
                ),
                sorted(
                    after.get("deployedBytecode", {}).get("immutableReferences", {}).values(),
                    key=canonical_json,
                ),
            ),
        }
        for field, (left, right) in raw.items():
            if canonical_json(left) != canonical_json(right):
                raw_mismatches[field].append(relative)
    semantic_ok = all(not rows for rows in semantic_mismatches.values())
    return {
        "artifact_count": len(before_paths),
        "semantic_surface_sha256": {key: sha256(value) for key, value in digests.items()},
        "semantic_mismatches": semantic_mismatches,
        "raw_compiler_output_mismatches": raw_mismatches,
        "raw_compiler_output_mismatch_counts": {
            key: len(value) for key, value in raw_mismatches.items()
        },
        "raw_bytecode_equal": not raw_mismatches["initcode"] and not raw_mismatches["runtime"],
        "result": "pass" if semantic_ok else "fail",
    }


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise EquivalenceError(message)


def validate_source_receipt(value: Any) -> None:
    _require(isinstance(value, dict), "committed source receipt must be an object")
    _require(set(value) == SOURCE_RECEIPT_FIELDS, "committed source receipt fields are not exact")
    source_count = value["source_count"]
    exact_count = value["exact_semantic_match_count"]
    _require(
        isinstance(source_count, int) and source_count > 0,
        "committed source_count must be a positive integer",
    )
    _require(
        isinstance(exact_count, int) and exact_count == source_count,
        "committed source exact match count must equal source_count",
    )
    _require(
        isinstance(value["semantic_inventory_sha256"], str)
        and LOWER_HEX_64_RE.fullmatch(value["semantic_inventory_sha256"]),
        "committed source semantic digest must be lowercase 64-hex",
    )
    _require(value["mismatches"] == [], "committed source pass receipt must have no mismatches")
    _require(value["result"] == "pass", "committed source receipt result must be pass")


def validate_artifact_receipt(value: Any, label: str) -> None:
    _require(isinstance(value, dict), f"{label} must be an object")
    _require(set(value) == ARTIFACT_RECEIPT_FIELDS, f"{label} fields are not exact")
    _require(
        isinstance(value["artifact_count"], int) and value["artifact_count"] > 0,
        f"{label}.artifact_count must be a positive integer",
    )
    _require(value["result"] == "pass", f"{label}.result must be pass")
    _require(
        isinstance(value["raw_bytecode_equal"], bool),
        f"{label}.raw_bytecode_equal must be boolean",
    )
    mismatches = value["raw_compiler_output_mismatches"]
    counts = value["raw_compiler_output_mismatch_counts"]
    semantic_digests = value["semantic_surface_sha256"]
    semantic_mismatches = value["semantic_mismatches"]
    _require(
        isinstance(semantic_digests, dict)
        and set(semantic_digests) == SEMANTIC_SURFACE_FIELDS,
        f"{label} semantic digest fields are not exact",
    )
    _require(
        all(
            isinstance(digest, str) and LOWER_HEX_64_RE.fullmatch(digest)
            for digest in semantic_digests.values()
        ),
        f"{label} semantic digests must be lowercase 64-hex values",
    )
    _require(
        isinstance(semantic_mismatches, dict)
        and set(semantic_mismatches) == SEMANTIC_SURFACE_FIELDS,
        f"{label} semantic mismatch fields are not exact",
    )
    _require(
        all(rows == [] for rows in semantic_mismatches.values()),
        f"{label} pass receipt must have no semantic mismatches",
    )
    _require(isinstance(mismatches, dict), f"{label} raw mismatch arrays must be an object")
    _require(isinstance(counts, dict), f"{label} raw mismatch counts must be an object")
    _require(set(mismatches) == RAW_MISMATCH_FIELDS, f"{label} raw mismatch arrays are not exact")
    _require(set(counts) == RAW_MISMATCH_FIELDS, f"{label} raw mismatch counts are not exact")
    for field in sorted(RAW_MISMATCH_FIELDS):
        rows = mismatches[field]
        _require(
            isinstance(rows, list) and all(isinstance(row, str) for row in rows),
            f"{label}.{field} raw mismatches must be string arrays",
        )
        _require(len(rows) == len(set(rows)), f"{label}.{field} raw mismatches must be unique")
        _require(rows == sorted(rows), f"{label}.{field} raw mismatches must be sorted")
        for row in rows:
            _require(
                "\\" not in row
                and not row.startswith("/")
                and normalize_posix(row) == row
                and all(part not in ("", ".", "..") for part in row.split("/")),
                f"{label}.{field} raw mismatch paths must be normalized",
            )
        _require(counts[field] == len(rows), f"{label}.{field} raw mismatch count drifted")
    _require(
        value["raw_bytecode_equal"]
        is (not mismatches["initcode"] and not mismatches["runtime"]),
        f"{label}.raw_bytecode_equal contradicts initcode/runtime mismatches",
    )


def validate_compiler_input_receipt(value: Any) -> None:
    _require(isinstance(value, dict), "release compiler-input receipt must be an object")
    _require(
        set(value) == COMPILER_INPUT_RECEIPT_FIELDS,
        "release compiler-input receipt fields are not exact",
    )
    _require(value["result"] == "pass", "release compiler-input receipt result must be pass")
    target_count = value["target_count"]
    exact_count = value["exact_semantic_match_count"]
    _require(
        isinstance(target_count, int) and target_count > 0,
        "release compiler-input target_count must be a positive integer",
    )
    _require(
        isinstance(exact_count, int) and exact_count == target_count,
        "release compiler-input exact match count must equal target_count",
    )
    _require(
        value["mismatches"] == [],
        "release compiler-input pass receipt must have no mismatches",
    )
    compiler_digest = value["semantic_inputs_sha256"]
    _require(
        isinstance(compiler_digest, str) and LOWER_HEX_64_RE.fullmatch(compiler_digest),
        "release compiler-input digest must be lowercase 64-hex",
    )


def validate_committed_report(report: Any, expected_canonical_sha256: str) -> None:
    _require(isinstance(report, dict), "committed equivalence report must be an object")
    _require(set(report) == TOP_LEVEL_FIELDS, "committed equivalence report fields are not exact")
    _require(report["schema_version"] == SCHEMA, "committed equivalence schema is not exact")
    _require(
        report["migration_base_commit"] == layout.EXPECTED_MIGRATION_BASE_COMMIT,
        "committed equivalence migration base is not exact",
    )
    _require(report["result"] == "pass", "committed equivalence result must be pass")
    _require(
        report["raw_bytecode_identity_claimed"] is False,
        "committed equivalence report must not claim raw bytecode identity",
    )
    _require(
        report["expected_compiler_identity_differences"]
        == EXPECTED_COMPILER_IDENTITY_DIFFERENCES,
        "committed expected compiler identity differences are not exact",
    )
    _require(report["maturity_effect"] == MATURITY_EFFECT, "committed maturity boundary is not exact")
    validate_source_receipt(report["source_semantics"])
    validate_artifact_receipt(report["full_foundry_artifacts"], "full_foundry_artifacts")
    validate_artifact_receipt(
        report["isolated_release_artifacts"], "isolated_release_artifacts"
    )
    validate_compiler_input_receipt(report["release_compiler_inputs"])
    _require(
        expected_canonical_sha256 == EXPECTED_RECEIPT_CANONICAL_SHA256,
        "source-layout manifest receipt digest is not the exact reviewed digest",
    )
    _require(
        sha256(report) == expected_canonical_sha256,
        "committed equivalence receipt canonical digest drifted",
    )


def validate_source_recomputation(report: dict[str, Any], sources: dict[str, Any]) -> None:
    _require(
        report["source_semantics"] == sources,
        "committed equivalence source receipt diverges from current sources",
    )


def release_inputs(root: Path) -> dict[str, Any]:
    release_root = root.resolve()
    manifest = load_strict_json(release_root / "release-build-manifest.json")
    _require(isinstance(manifest, dict), "release build manifest must be an object")
    targets = manifest.get("targets")
    _require(isinstance(targets, list), "release build manifest targets must be a list")
    _require(bool(targets), "release build manifest targets must not be empty")

    inventory: list[tuple[str, Path]] = []
    target_names: set[str] = set()
    input_paths: set[str] = set()
    invariant_input_paths: set[str] = set()
    resolved_input_identities: set[str] = set()
    required_fields = {"name", "compiler_input_relative_path"}
    for index, row in enumerate(targets):
        label = f"release build manifest targets[{index}]"
        _require(isinstance(row, dict), f"{label} must be an object")
        missing = required_fields - set(row)
        _require(not missing, f"{label} is missing required fields: {sorted(missing)}")

        name = row["name"]
        _require(
            isinstance(name, str) and bool(name),
            f"{label}.name must be a nonempty string",
        )
        _require(
            name not in target_names,
            f"duplicate release compiler-input target name: {name}",
        )
        target_names.add(name)

        relative = row["compiler_input_relative_path"]
        _require(
            isinstance(relative, str) and bool(relative),
            f"{label}.compiler_input_relative_path must be a nonempty string",
        )
        _require(
            "\\" not in relative,
            f"{label}.compiler_input_relative_path must use forward slashes",
        )
        _require(
            not posixpath.isabs(relative) and re.match(r"^[A-Za-z]:", relative) is None,
            f"{label}.compiler_input_relative_path must be relative",
        )
        parts = relative.split("/")
        _require(
            all(part not in {"", ".", ".."} for part in parts),
            f"{label}.compiler_input_relative_path must be normalized without "
            "empty, dot, or dotdot segments",
        )
        _require(
            relative not in input_paths,
            f"duplicate release compiler-input relative path: {relative}",
        )
        input_paths.add(relative)
        invariant_relative = "/".join(parts).casefold()
        _require(
            invariant_relative not in invariant_input_paths,
            f"case-aliased release compiler-input relative path: {relative}",
        )
        invariant_input_paths.add(invariant_relative)

        resolved = (release_root / Path(*parts)).resolve()
        try:
            resolved.relative_to(release_root)
        except ValueError as exc:
            raise EquivalenceError(
                f"{label}.compiler_input_relative_path resolves outside the release root"
            ) from exc
        _require(resolved.is_file(), f"release compiler input does not exist: {relative}")
        resolved_identity = resolved.as_posix().casefold()
        _require(
            resolved_identity not in resolved_input_identities,
            f"release compiler-input paths resolve to the same file: {relative}",
        )
        resolved_input_identities.add(resolved_identity)
        inventory.append((name, resolved))

    return {name: load_strict_json(path) for name, path in inventory}


def normalized_compiler_input(value: dict[str, Any], new_to_old: dict[str, str]) -> Any:
    value = json.loads(json.dumps(value))
    sources = {}
    for source, record in value["sources"].items():
        record["content"] = normalize_imports(record["content"], source, new_to_old)
        sources[old_path(source, new_to_old)] = record
    value["sources"] = sources
    return normalize_paths(value, new_to_old)


def compiler_input_receipt(
    before_root: Path, after_root: Path, new_to_old: dict[str, str]
) -> dict[str, Any]:
    before = release_inputs(before_root)
    after = release_inputs(after_root)
    if set(before) != set(after):
        raise EquivalenceError("pre/post release compiler-input target sets differ")
    rows = []
    mismatches = []
    for name in sorted(before):
        left = normalized_compiler_input(before[name], new_to_old)
        right = normalized_compiler_input(after[name], new_to_old)
        if canonical_json(left) != canonical_json(right):
            mismatches.append(name)
        rows.append([name, left])
    return {
        "target_count": len(rows),
        "exact_semantic_match_count": len(rows) - len(mismatches),
        "semantic_inputs_sha256": sha256(rows),
        "mismatches": mismatches,
        "result": "pass" if not mismatches else "fail",
    }


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--before-out", type=Path)
    parser.add_argument("--after-out", type=Path)
    parser.add_argument("--before-release-out", type=Path)
    parser.add_argument("--after-release-out", type=Path)
    parser.add_argument("--output", type=Path, default=DEFAULT_REPORT)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--generate",
        action="store_true",
        help="generate a complete historical receipt from both artifact families",
    )
    mode.add_argument(
        "--check-receipt",
        action="store_true",
        help="validate the immutable historical receipt structure and canonical digest",
    )
    mode.add_argument(
        "--check-source",
        action="store_true",
        help="explicitly recompute current sources against the historical migration base",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    generation_output: Path | None = None
    if args.generate:
        generation_output = resolve_generation_output(repo_root, args.output)
    artifact_directories = (
        args.before_out,
        args.after_out,
        args.before_release_out,
        args.after_release_out,
    )
    if args.generate:
        _require(
            all(value is not None for value in artifact_directories),
            "--generate requires all four before/after full and release artifact directories",
        )
    else:
        _require(
            all(value is None for value in artifact_directories),
            "receipt check modes do not accept artifact directory arguments",
        )
    manifest = layout.load_manifest(repo_root)
    new_to_old = {move["new_path"]: move["old_path"] for move in manifest["moves"]}
    if args.check_receipt or args.check_source:
        report = load_strict_json(repo_root / args.output)
        validate_committed_report(
            report, manifest["equivalence_receipt_canonical_sha256"]
        )
        if args.check_source:
            sources = source_receipt(repo_root, manifest)
            validate_source_recomputation(report, sources)
            print(
                "Solidity layout source-equivalence recomputation is current "
                f"({sources['exact_semantic_match_count']}/{sources['source_count']})."
            )
        else:
            print(
                "Solidity layout historical equivalence receipt is valid "
                f"(canonical sha256:{EXPECTED_RECEIPT_CANONICAL_SHA256})."
            )
        return 0
    sources = source_receipt(repo_root, manifest)
    report: dict[str, Any] = {
        "schema_version": SCHEMA,
        "migration_base_commit": layout.EXPECTED_MIGRATION_BASE_COMMIT,
        "source_semantics": sources,
        "expected_compiler_identity_differences": EXPECTED_COMPILER_IDENTITY_DIFFERENCES,
        "raw_bytecode_identity_claimed": False,
        "maturity_effect": MATURITY_EFFECT,
    }
    results = [sources["result"]]
    report["full_foundry_artifacts"] = artifact_receipt(
        args.before_out.resolve(),
        args.after_out.resolve(),
        new_to_old,
        excluded={"build-info"},
    )
    results.append(report["full_foundry_artifacts"]["result"])
    report["release_compiler_inputs"] = compiler_input_receipt(
        args.before_release_out.resolve(),
        args.after_release_out.resolve(),
        new_to_old,
    )
    report["isolated_release_artifacts"] = artifact_receipt(
        args.before_release_out.resolve(),
        args.after_release_out.resolve(),
        new_to_old,
        excluded={"compiler-inputs"},
    )
    results.extend(
        [
            report["release_compiler_inputs"]["result"],
            report["isolated_release_artifacts"]["result"],
        ]
    )
    report["result"] = "pass" if all(result == "pass" for result in results) else "fail"
    _require(generation_output is not None, "generation output preflight was not completed")
    output = generation_output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"{output.relative_to(repo_root).as_posix()} ({report['result']})")
    return 0 if report["result"] == "pass" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (EquivalenceError, layout.SourceLayoutError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
