"""Check the exact optional INSTANT provider runtime without invoking a compiler.

The supplied standard-JSON output is a trusted compiler capture, not a signed
build attestation. This check binds its metadata-listed dependencies to the input
and current source, then scans the actual runtime bytes. Unused compiler inputs
may be historical; complete capture hashes do not claim they are current.
It does not establish entropy quality,
deployment identity, reachability proofs, or execution acceptance.
This approved stateless profile additionally forbids storage/balance reads and
external-code inspection. Constructor instructions are not runtime instructions.

Run from the repository: python -m tools.build.check_instant_provider_runtime
    --input <solc-input.json> --output <solc-output.json>
Or use the actual completed Foundry cache: --out out/current --cache-path cache/current
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from typing import Any, Sequence

from tools.build.prepare_current_graph import select_build
from tools.protocol.check_drop_authorization_fixtures import keccak256

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol"
CONTRACT = "StreamEntropyProviderInstant"
TARGET = f"{SOURCE}:{CONTRACT}"
COMPILER = "0.8.19+commit.7dd6d404"
SCHEMA = "6529stream.instant-provider-runtime-check.v1"
FORBIDDEN = {
    0x31: "BALANCE", 0x3B: "EXTCODESIZE", 0x3C: "EXTCODECOPY", 0x3F: "EXTCODEHASH",
    0x47: "SELFBALANCE", 0x54: "SLOAD",
    0x55: "SSTORE", 0x5D: "TSTORE",
    0xA0: "LOG0", 0xA1: "LOG1", 0xA2: "LOG2", 0xA3: "LOG3", 0xA4: "LOG4",
    0xF0: "CREATE", 0xF1: "CALL", 0xF2: "CALLCODE", 0xF4: "DELEGATECALL",
    0xF5: "CREATE2", 0xFA: "STATICCALL", 0xFF: "SELFDESTRUCT",
}
PARIS_OPCODES = (
    {0x00, 0x20, 0xF3, 0xFD, 0xFE}
    | set(range(0x01, 0x0C)) | set(range(0x10, 0x1E))
    | set(range(0x30, 0x49)) | set(range(0x50, 0x5C)) | set(range(0x60, 0xA0))
)


class RuntimeCheckError(ValueError):
    """Malformed, stale, unsupported, or unsafe runtime evidence."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeCheckError(message)


def _object(value: Any, label: str) -> dict:
    _require(isinstance(value, dict), f"{label} must be an object")
    return value


def _unique(pairs: list[tuple[str, Any]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        _require(key not in result, f"Duplicate JSON member: {key}")
        result[key] = value
    return result


def _invalid_constant(value: str) -> None:
    raise RuntimeCheckError(f"Non-JSON numeric constant: {value}")


def _json(raw: bytes | str, label: str) -> dict:
    try:
        if isinstance(raw, bytes):
            raw = raw.decode("utf-8")
        return _object(json.loads(raw, object_pairs_hook=_unique,
                                  parse_constant=_invalid_constant), label)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise RuntimeCheckError(f"Invalid UTF-8 JSON in {label}: {exc}") from exc


def _sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _profile(settings: Any, label: str) -> dict:
    settings = _object(settings, label)
    _require(settings.get("viaIR") is True, f"{label}: viaIR must be true")
    _require(settings.get("evmVersion") == "paris", f"{label}: EVM must be Paris")
    optimizer = _object(settings.get("optimizer"), f"{label}.optimizer")
    _require(optimizer == {"enabled": True, "runs": 200}
             and optimizer.get("enabled") is True and type(optimizer.get("runs")) is int,
             f"{label}: exact enabled optimizer/200 profile required")
    metadata = _object(settings.get("metadata"), f"{label}.metadata")
    _require(metadata.get("bytecodeHash") == "none" and metadata.get("appendCBOR") is False,
             f"{label}: bytecodeHash=none and appendCBOR=false required")
    _require(set(metadata) <= {"bytecodeHash", "appendCBOR", "useLiteralContent"},
             f"{label}: unexpected metadata settings")
    if "useLiteralContent" in metadata:
        _require(type(metadata["useLiteralContent"]) is bool,
                 f"{label}: useLiteralContent must be boolean")
    _require(set(settings) <= {"viaIR", "evmVersion", "optimizer", "metadata",
                              "libraries", "remappings", "outputSelection", "compilationTarget"},
             f"{label}: unsupported compiler settings")
    _require(settings.get("libraries", {}) == {}, f"{label}: linked libraries are not allowed")
    remappings = settings.get("remappings", [])
    _require(isinstance(remappings, list) and all(isinstance(v, str) for v in remappings),
             f"{label}: remappings must be strings")
    return settings


def _sources(root: Path, sources: dict, selected: dict) -> list[dict]:
    sources = _object(sources, "input.sources")
    _require(SOURCE in sources, "Approved production source is absent from compiler input")
    root = root.resolve()
    rows = []
    for name in sorted(selected):
        _require(name in sources, f"Metadata source absent from compiler input: {name}")
        record = sources[name]
        path = PurePosixPath(name)
        _require(bool(name) and not path.is_absolute() and path.as_posix() == name
                 and ".." not in path.parts and "\\" not in name and ":" not in name,
                 f"Non-project source path: {name}")
        candidate = (root / name).resolve()
        _require(candidate.is_relative_to(root), f"Source escapes repository: {name}")
        record = _object(record, f"input.sources.{name}")
        _require(set(record) == {"content"} and isinstance(record["content"], str),
                 f"Literal source content required: {name}")
        captured = record["content"].encode("utf-8")
        current = candidate.read_bytes()
        transport = "exact"
        if captured != current:
            _require(captured == current.replace(b"\r\n", b"\n"),
                     f"Stale or changed compiler source: {name}")
            transport = "CRLF-to-LF"
        rows.append({"path": name, "transport": transport,
                     "current_sha256": _sha(current), "captured_sha256": _sha(captured),
                     "keccak256": "0x" + keccak256(captured).hex()})
    return rows


def scan_runtime(value: Any) -> dict:
    """Scan every runtime instruction, including bytes after STOP/INVALID.

    Only PUSH immediate operands are data. Compiler immutable references must
    lie wholly inside one such operand; they never suppress opcode scanning.
    """
    value = _object(value, "evm.deployedBytecode")
    code = value.get("object")
    _require(isinstance(code, str) and bool(code), "Exact nonempty deployed runtime required")
    _require("__" not in code, "Unresolved library link in deployed runtime")
    _require(re.fullmatch(r"(?:[0-9a-fA-F]{2})+", code) is not None,
             "Runtime must be even-length, unprefixed hexadecimal")
    _require(value.get("linkReferences") == {}, "Runtime link references must be empty")
    references = _object(value.get("immutableReferences"), "immutableReferences")
    raw = bytes.fromhex(code)
    _require(len(raw) <= 24576, "Provider runtime exceeds EIP-170")
    immediates: list[tuple[int, int]] = []
    instructions = 0
    pc = 0
    while pc < len(raw):
        opcode = raw[pc]
        _require(opcode not in FORBIDDEN,
                 f"Forbidden {FORBIDDEN.get(opcode)} opcode at byte {pc}")
        _require(opcode in PARIS_OPCODES, f"Non-Paris/undefined opcode 0x{opcode:02x} at byte {pc}")
        instructions += 1
        width = opcode - 0x5F if 0x60 <= opcode <= 0x7F else 0
        _require(pc + 1 + width <= len(raw), f"Truncated PUSH{width} at byte {pc}")
        if width:
            immediates.append((pc + 1, pc + 1 + width))
        pc += 1 + width
    masked = bytearray(raw)
    ranges = []
    occupied: set[int] = set()
    for identity, entries in sorted(references.items()):
        _require(re.fullmatch(r"[0-9]+", identity) is not None,
                 "Immutable reference identifier must be a compiler AST id")
        _require(isinstance(entries, list) and bool(entries), "Empty or malformed immutable references")
        for reference in entries:
            _require(isinstance(reference, dict) and set(reference) == {"start", "length"},
                     "Malformed immutable reference")
            start, length = reference["start"], reference["length"]
            _require(type(start) is int and type(length) is int and start >= 0 and length > 0,
                     "Invalid immutable reference range")
            end = start + length
            _require(any(low <= start < end <= high for low, high in immediates),
                     "Immutable reference must lie entirely within one PUSH immediate")
            covered = set(range(start, end))
            _require(not occupied.intersection(covered), "Overlapping immutable reference ranges")
            occupied.update(covered)
            masked[start:end] = bytes(length)
            ranges.append({"id": identity, "start": start, "length": length})
    return {"runtime_bytes": len(raw), "instructions": instructions,
            "runtime_sha256": _sha(raw), "runtime_keccak256": "0x" + keccak256(raw).hex(),
            "immutable_masked_runtime_sha256": _sha(bytes(masked)),
            "immutable_references": ranges, "scan": "all runtime instruction bytes; PUSH operands skipped"}


def validate(compiler_input: dict, compiler_output: dict, root: Path = ROOT) -> dict:
    _require(compiler_input.get("language") == "Solidity", "Solidity standard-JSON input required")
    settings = _profile(compiler_input.get("settings"), "input.settings")
    _require("compilationTarget" not in settings, "compilationTarget is an output metadata field")
    input_sources = _object(compiler_input.get("sources"), "input.sources")
    errors = compiler_output.get("errors", [])
    _require(isinstance(errors, list) and all(isinstance(v, dict) for v in errors),
             "Malformed compiler diagnostics")
    _require(not any(v.get("severity") == "error" for v in errors), "Compiler output contains errors")
    contracts = _object(compiler_output.get("contracts"), "output.contracts")
    artifact = _object(_object(contracts.get(SOURCE), f"contracts.{SOURCE}").get(CONTRACT), TARGET)
    metadata_raw = artifact.get("metadata")
    _require(isinstance(metadata_raw, str), "Exact compiler artifact metadata is required")
    metadata = _json(metadata_raw, "artifact metadata")
    _require(metadata.get("language") == "Solidity", "Metadata language differs")
    _require(_object(metadata.get("compiler"), "metadata.compiler").get("version") == COMPILER,
             "Compiler must be exact Solidity " + COMPILER)
    actual_settings = _profile(metadata.get("settings"), "metadata.settings")
    _require(actual_settings.get("compilationTarget") == {SOURCE: CONTRACT},
             "Metadata compilation target differs from approved production provider")
    _require(actual_settings.get("remappings", []) == settings.get("remappings", []),
             "Input/metadata remappings differ")
    _require(actual_settings["metadata"].get("useLiteralContent", False)
             == settings["metadata"].get("useLiteralContent", False),
             "Input/metadata literal-content setting differs")
    sources = _object(metadata.get("sources"), "metadata.sources")
    _require(SOURCE in sources, "Metadata omits approved production source")
    rows = _sources(root, input_sources, sources)
    bindings = {row["path"]: row for row in rows}
    for name, evidence in sources.items():
        evidence = _object(evidence, f"metadata.sources.{name}")
        _require(name in bindings and evidence.get("keccak256") == bindings[name]["keccak256"],
                 f"Metadata source binding differs: {name}")
        if "content" in evidence:
            _require(evidence["content"] == compiler_input["sources"][name]["content"],
                     f"Metadata literal source differs: {name}")
    runtime = scan_runtime(_object(artifact.get("evm"), "artifact.evm").get("deployedBytecode"))
    return {"schema": SCHEMA, "status": "passed", "target": TARGET,
            "compiler": COMPILER, "profile": "viaIR/optimizer200/Paris/noCBOR",
            "metadata_sha256": _sha(metadata_raw.encode("utf-8")),
            "input_source_count": len(input_sources), "verified_source_count": len(rows),
            "metadata_source_count": len(sources),
            "source_scope": "Only the target metadata dependency set is verified current; unused input sources are not checked",
            "sources": rows, **runtime,
            "evidence_boundary": "Supplied compiler capture consistency and runtime scan; no compiler or EVM run"}


def check_capture(input_path: Path, output_path: Path, root: Path = ROOT) -> dict:
    raw_input, raw_output = input_path.read_bytes(), output_path.read_bytes()
    report = validate(_json(raw_input, "compiler input"), _json(raw_output, "compiler output"), root)
    return {**report, "input_sha256": _sha(raw_input), "output_sha256": _sha(raw_output)}


def check_foundry(out: Path, cache_path: Path, root: Path = ROOT) -> dict:
    """Select the actual cached product, never a newer dependency emission."""
    out, cache_path = out.resolve(), cache_path.resolve()
    cache_file = cache_path / "solidity-files-cache.json"
    cache_raw = cache_file.read_bytes()
    cache = _json(cache_raw, "Foundry cache")
    try:
        build_id = select_build(cache, ((SOURCE, CONTRACT),))
        _require(isinstance(build_id, str) and re.fullmatch(r"[0-9a-fA-F]+", build_id) is not None,
                 "Invalid selected build-info id")
        entries = cache["files"][SOURCE]["artifacts"][CONTRACT]["0.8.19"]
        relative = Path(SOURCE).name + "/" + CONTRACT + ".json"
        matches = [entry for entry in entries.values()
                   if entry["path"].replace("\\", "/") == relative]
        _require(len(matches) == 1 and matches[0]["build_id"] == build_id,
                 "Ambiguous selected cache artifact")
    except (KeyError, TypeError, AttributeError, ValueError) as exc:
        raise RuntimeCheckError(f"Cannot select exact cached provider: {exc}") from exc
    build_file = out / "build-info" / (build_id + ".json")
    artifact_file = (out / relative).resolve()
    _require(build_file.resolve().is_relative_to(out) and artifact_file.is_relative_to(out),
             "Foundry artifact/build-info path escapes output directory")
    build_raw, artifact_raw = build_file.read_bytes(), artifact_file.read_bytes()
    build, artifact = _json(build_raw, "build-info"), _json(artifact_raw, "Foundry artifact")
    _require(build.get("id") == build_id, "Build-info id differs from selected cache")
    _require(build.get("solcVersion") == "0.8.19", "Selected build-info requires Solidity 0.8.19")
    compiler_input = _object(build.get("input"), "build-info.input")
    compiler_output = _object(build.get("output"), "build-info.output")
    report = validate(compiler_input, compiler_output, root)
    selected = compiler_output["contracts"][SOURCE][CONTRACT]
    runtime = selected["evm"]["deployedBytecode"]
    physical = _object(artifact.get("deployedBytecode"), "Foundry deployedBytecode")
    physical_code = physical.get("object")
    _require(isinstance(physical_code, str)
             and physical_code.removeprefix("0x").lower() == runtime["object"].lower(),
             "Cached artifact runtime differs from selected compiler product")
    for field in ("immutableReferences", "linkReferences"):
        _require(field in physical and physical[field] == runtime[field],
                 f"Cached artifact {field} differs from selected compiler product")
    raw_metadata = artifact.get("rawMetadata")
    _require(isinstance(raw_metadata, str), "Cached artifact rawMetadata is required")
    selected_metadata = _json(selected["metadata"], "selected metadata")
    _require(_json(raw_metadata, "cached rawMetadata") == selected_metadata,
             "Cached artifact metadata differs from selected compiler product")
    if "metadata" in artifact:
        # Foundry's parsed view can omit compiler metadata fields. Authenticate
        # the complete rawMetadata above; use this lossy view only for identity,
        # matching test/helpers/native_assembly_artifacts.py.
        parsed = _object(artifact["metadata"], "Cached parsed metadata")
        parsed_settings = _object(parsed.get("settings"), "Cached parsed metadata.settings")
        _require(parsed_settings.get("compilationTarget") == {SOURCE: CONTRACT},
                 "Cached parsed metadata compilation target differs")
    for path, raw in ((cache_file, cache_raw), (build_file, build_raw), (artifact_file, artifact_raw)):
        _require(path.read_bytes() == raw, f"Compiler capture changed while checking: {path}")
    return {**report, "capture_mode": "Foundry cache-selected product", "build_id": build_id,
            "cache_sha256": _sha(cache_raw), "build_info_sha256": _sha(build_raw),
            "artifact_sha256": _sha(artifact_raw), "artifact_path": relative}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--input", type=Path, help="Exact solc standard-JSON input")
    mode.add_argument("--out", type=Path, help="Completed Foundry output directory")
    parser.add_argument("--output", type=Path, help="Exact solc standard-JSON output")
    parser.add_argument("--cache-path", type=Path, help="Matching Foundry cache directory")
    args = parser.parse_args(argv)
    try:
        if args.input is not None:
            _require(args.output is not None and args.cache_path is None,
                     "Pair mode requires --input/--output and forbids --cache-path")
            report = check_capture(args.input, args.output)
        else:
            _require(args.cache_path is not None and args.output is None,
                     "Foundry mode requires --out/--cache-path and forbids --output")
            report = check_foundry(args.out, args.cache_path)
    except (ValueError, OSError, UnicodeError) as exc:
        print(json.dumps({"schema": SCHEMA, "status": "failed", "target": TARGET, "error": str(exc)},
                         sort_keys=True))
        return 1
    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
