#!/usr/bin/env python3
"""Export the exact globally-via-IR current deployment compilation, without rebuilding it."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any


CONFIG = Path("release-artifacts/current-contracts.json")
SOLC = "0.8.19+commit.7dd6d404"
RUNTIME_LIMIT = 24_576


class CurrentArtifactError(ValueError):
    pass


def encoded(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()


def digest(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CurrentArtifactError(message)


def object_text(value: Any) -> str:
    require(isinstance(value, str), "missing compiler bytecode object")
    return value.removeprefix("0x")


def runtime_size(value: str) -> int:
    substituted = re.sub(r"__\$[0-9a-fA-F]{34}\$__", "0" * 40, object_text(value))
    require(bool(re.fullmatch(r"(?:[0-9a-fA-F]{2})*", substituted)), "invalid bytecode object")
    return len(substituted) // 2


def target_entries(config: dict[str, Any]) -> list[dict[str, Any]]:
    require(config.get("schema_version") == "6529stream.current-stack-targets.v1", "invalid current target schema")
    entries = [dict(entry, kind="contract") for entry in config["contracts"]]
    entries += [dict(entry, kind="interface") for entry in config["interfaces"]]
    entries.append(dict(config["deployment_script"], kind="deployment_script"))
    require(bool(config["contracts"]), "current contract targets must not be empty")
    names: set[str] = set()
    for entry in entries:
        name, source = entry["name"], entry["source"]
        require(bool(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name)), "invalid target name")
        require(name not in names, f"duplicate target: {name}")
        names.add(name)
        path = PurePosixPath(source)
        require(not path.is_absolute() and ".." not in path.parts and path.as_posix() == source, f"nonportable target source: {source}")
        expected_root = "script/current/" if entry["kind"] == "deployment_script" else "smart-contracts/"
        require(source.startswith(expected_root) and source.endswith(".sol"), f"invalid target source: {source}")
    return entries


def validate_settings(info: dict[str, Any]) -> None:
    settings = info["input"]["settings"]
    require(info.get("solcVersion") == "0.8.19", "current build must use Solidity 0.8.19")
    require(settings.get("viaIR") is True, "current build must use global viaIR")
    require(settings.get("optimizer") == {"enabled": True, "runs": 200}, "current optimizer must be enabled with 200 runs")
    require(settings.get("evmVersion") == "paris", "current EVM target must be Paris")
    metadata = settings.get("metadata", {})
    require(metadata.get("bytecodeHash") == "none" and metadata.get("appendCBOR") is False, "current build must omit CBOR and bytecode metadata hashes")
    require(not any(item.get("severity") == "error" for item in info["output"].get("errors", [])), "compiler output contains errors")


def artifact_metadata(artifact: dict[str, Any]) -> dict[str, Any]:
    # Foundry's parsed metadata can insert optional null fields absent from
    # solc's output. The retained raw metadata preserves the compiler object.
    return json.loads(artifact["rawMetadata"]) if "rawMetadata" in artifact else artifact["metadata"]


def matches_artifact(artifact: dict[str, Any], output: dict[str, Any]) -> bool:
    evm = output.get("evm", {})
    if artifact.get("abi") != output.get("abi"):
        return False
    for artifact_key, output_key in (("bytecode", "bytecode"), ("deployedBytecode", "deployedBytecode")):
        actual = artifact.get(artifact_key, {})
        expected = evm.get(output_key, {})
        if object_text(actual.get("object", "")) != object_text(expected.get("object", "")):
            return False
        for field in ("linkReferences", "immutableReferences"):
            if actual.get(field, {}) != expected.get(field, {}):
                return False
    if artifact.get("methodIdentifiers", {}) != evm.get("methodIdentifiers", {}):
        return False
    return artifact_metadata(artifact) == json.loads(output.get("metadata", "{}"))


def select_build_info(out: Path, targets: list[dict[str, Any]], artifacts: dict[str, Any]) -> dict[str, Any]:
    matches: dict[str, dict[str, Any]] = {}
    for path in sorted((out / "build-info").glob("*.json")):
        info = load(path)
        if "input" not in info or "output" not in info:
            continue
        compiled = info["output"].get("contracts", {})
        if all(
            entry["name"] in compiled.get(entry["source"], {})
            and matches_artifact(artifacts[entry["name"]], compiled[entry["source"]][entry["name"]])
            for entry in targets
        ):
            matches[digest(encoded(info["input"]))] = info
    require(bool(matches), "no full build-info matches every current artifact and deployment script; build with FOUNDRY_PROFILE=current and build_info=true")
    require(len(matches) == 1, "multiple distinct compiler inputs match this output; select one clean Foundry output directory")
    info = next(iter(matches.values()))
    validate_settings(info)
    return info


def compiler_sources(root: Path, compiler_input: dict[str, Any]) -> dict[str, Any]:
    sources: dict[str, Any] = {}
    for name, entry in sorted(compiler_input["sources"].items()):
        path = PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts and path.as_posix() == name and ":" not in name, f"nonportable compiler source: {name}")
        content = entry.get("content")
        require(isinstance(content, str), f"compiler input omits literal source: {name}")
        local = (root / name).read_bytes().decode("utf-8")
        # Foundry normalizes platform line endings before sending source text to
        # solc. Retain its exact input; only freshness comparison normalizes CRLF.
        require(local.replace("\r\n", "\n") == content.replace("\r\n", "\n"), f"compiler source is stale: {name}")
        sources[name] = {"sha256": digest(content.encode()), "bytes": len(content.encode())}
    return sources


def solidity_interface_id(info: dict[str, Any], entry: dict[str, Any]) -> str:
    nodes = info["output"]["sources"][entry["source"]]["ast"]["nodes"]
    declarations = [node for node in nodes if node.get("nodeType") == "ContractDefinition" and node.get("name") == entry["name"]]
    require(len(declarations) == 1 and declarations[0].get("contractKind") == "interface", f"missing interface AST for {entry['name']}")
    value = 0
    for node in declarations[0]["nodes"]:
        if node.get("nodeType") == "FunctionDefinition" and node.get("kind") == "function":
            value ^= int(node["functionSelector"], 16)
    return f"0x{value:08x}"


def load_targets_and_libraries(out: Path, targets: list[dict[str, Any]]) -> dict[str, Any]:
    artifacts: dict[str, Any] = {}
    known = {entry["name"]: entry["source"] for entry in targets}
    for entry in targets:
        name = entry["name"]
        artifact = load(out / Path(entry["source"]).name / (name + ".json"))
        artifacts[name] = artifact
        for field in ("bytecode", "deployedBytecode"):
            for source, libraries in artifact.get(field, {}).get("linkReferences", {}).items():
                for library in libraries:
                    if library in known:
                        require(known[library] == source, f"ambiguous linked library name: {library}")
                        continue
                    require(source.startswith("smart-contracts/") and ".." not in PurePosixPath(source).parts, f"non-protocol linked library: {source}")
                    known[library] = source
                    targets.append({"name": library, "source": source, "kind": "linked_library"})
    return artifacts


def candidate_files(root: Path, out: Path, config_path: Path) -> dict[str, bytes]:
    config = load(config_path)
    targets = target_entries(config)
    artifacts = load_targets_and_libraries(out, targets)
    info = select_build_info(out, targets, artifacts)
    sources = compiler_sources(root, info["input"])
    files = {"compiler-input.json": encoded(info["input"])}
    rows: list[dict[str, Any]] = []
    for entry in targets:
        name = entry["name"]
        artifact = artifacts[name]
        metadata = artifact_metadata(artifact)
        require(metadata["compiler"]["version"] == SOLC, f"unexpected compiler version for {name}")
        runtime = artifact["deployedBytecode"]
        size = runtime_size(runtime["object"])
        if entry["kind"] in {"contract", "linked_library"}:
            require(0 < size <= RUNTIME_LIMIT, f"{name} runtime is {size} bytes; EIP-170 limit is {RUNTIME_LIMIT}")
        # Selected ABI and bytecode remain the actual output objects, including
        # link placeholders and immutable references. This is not a deployed
        # runtime hash or an address/constructor-argument attestation.
        selected = {key: artifact[key] for key in ("abi", "bytecode", "deployedBytecode", "methodIdentifiers", "metadata")}
        selected["metadata"] = metadata
        artifact_path = f"artifacts/{name}.json"
        files[artifact_path] = encoded(selected)
        row = dict(entry, artifact=artifact_path, runtime_bytes=size)
        if entry["kind"] == "interface":
            row["solidity_interface_id"] = solidity_interface_id(info, entry)
            configured = entry.get("interface_id")
            # ERC-4906 deliberately assigns an interface ID to an event-only
            # standard. All other configured IDs must match Solidity's own
            # declaration selectors, excluding inherited functions.
            standard_event_id = name == "IERC4906" and configured == "0x49064906"
            require(not configured or standard_event_id or configured == row["solidity_interface_id"], f"configured interface ID differs from Solidity for {name}")
        rows.append(row)
    manifest = {
        "schema_version": "6529stream.current-stack-compilation.v1",
        "generated_by": "scripts/generate_current_stack_artifacts.py:1",
        "generator_sha256": digest(Path(__file__).read_text(encoding="utf-8").encode()),
        "maturity": "development/testnet candidate; not an audit or live deployment attestation",
        "compilation_unit": "one complete globally-via-IR Foundry compiler input containing the current deployment script and all selected targets",
        "compiler_version": SOLC,
        "compiler_input": "compiler-input.json",
        "compiler_input_sha256": digest(files["compiler-input.json"]),
        "settings": info["input"]["settings"],
        "reviewed_targets_sha256": digest(encoded(config)),
        "sources": sources,
        "targets": rows,
        "files": {name: digest(value) for name, value in sorted(files.items())},
    }
    files["manifest.json"] = encoded(manifest)
    return files


def publish(files: dict[str, bytes], output: Path, check: bool) -> None:
    actual = {path.relative_to(output).as_posix() for path in output.rglob("*") if path.is_file()} if output.exists() else set()
    extra = actual - set(files)
    require(not extra, "unexpected files in current candidate directory: " + ", ".join(sorted(extra)))
    if check:
        mismatches = [name for name, data in files.items() if not (output / name).is_file() or (output / name).read_bytes() != data]
        require(not mismatches, "current candidate is stale: " + ", ".join(mismatches))
        return
    for name, data in files.items():
        path = output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--foundry-out", type=Path, default=Path("out/current"))
    parser.add_argument("--config", type=Path, default=CONFIG)
    parser.add_argument("--output-dir", type=Path, default=Path("release-artifacts/current"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    root = args.repo_root.resolve()
    try:
        files = candidate_files(root, root / args.foundry_out, root / args.config)
        publish(files, root / args.output_dir, args.check)
    except (CurrentArtifactError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"Current candidate export failed: {exc}", file=sys.stderr)
        return 1
    print(f"Current candidate {'verified' if args.check else 'exported'}: {len(files)} files at {root / args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
