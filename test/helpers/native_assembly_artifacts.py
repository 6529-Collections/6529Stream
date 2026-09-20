"""Project exact native compiler artifacts for the assembly test; never alter bytecode.

Run after the native build and before its cached Forge test. Full build-info and
physical artifacts remain the authority for this compact, fixture-only read input.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def object_hex(value: str) -> str:
    return value[2:] if value.startswith("0x") else value


def project(build_info: Path, artifact_root: Path, destination: Path,
            products: dict[str, str], current_native_exports: bool = False, *, compiler_capture: Path | None = None) -> dict:
    raw_build = build_info.read_bytes()
    build = json.loads(raw_build)
    assert build["solcVersion"] == "0.8.19", "original native compiler"
    capture_evidence = None
    if compiler_capture is not None:
        import sys
        sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
        from tools.build.scoped_standard_json import bind_build_capture
        build, _, capture_evidence = bind_build_capture(build, compiler_capture)
    compiler_input, output = build["input"], build["output"]
    context = sha(canonical(compiler_input))
    declarations: dict[int, dict] = {}
    by_source: dict[str, dict[str, dict]] = {}
    for source, result in output["sources"].items():
        ast = result.get("ast")
        if ast is None:
            assert compiler_capture is not None, "missing native AST without verified split capture"
            continue  # Analysis-only imported ASTs never become bytecode evidence.
        assert ast["absolutePath"] == source and source in compiler_input["sources"]
        table: dict[str, dict] = {}
        for contract in ast["nodes"]:
            if contract["nodeType"] != "ContractDefinition":
                continue
            for node in contract["nodes"]:
                if node["nodeType"] != "VariableDeclaration" or node.get("mutability") != "immutable":
                    continue
                ident = node["id"]
                assert ident not in declarations and str(ident) not in table, "duplicate immutable AST id"
                declaration = {"source": source, "contractName": contract["name"],
                               "variable": node["name"], "id": ident,
                               "compilationHash": context, "nodeType": "VariableDeclaration",
                               "mutability": "immutable"}
                declarations[ident] = declaration
                table[str(ident)] = declaration
        by_source[source] = table

    report = {"buildInfo": str(build_info.resolve()), "buildInfoSha256": sha(raw_build),
              "compilerInputSha256": context, "generatorSha256": sha(Path(__file__).read_bytes()),
              "compilerCapture": capture_evidence,
              "artifactInputKind": "current-native-export" if current_native_exports else "forge-physical",
              "products": {}, "productionRuntimeSizes": {},
              "qualification": "Fixture-only projection. No CREATE, runtime, gas, or deployment acceptance."}
    for source, contracts in output["contracts"].items():
        if not source.startswith("smart-contracts/"):
            continue
        for name, contract in contracts.items():
            if "evm" not in contract or "deployedBytecode" not in contract["evm"]:
                assert compiler_capture is not None, "missing native runtime without verified split capture"
                continue  # Explicit analysis-field outputs are not measured runtime products.
            runtime = object_hex(contract["evm"]["deployedBytecode"]["object"])
            assert len(runtime) % 2 == 0
            size = len(runtime) // 2
            assert size <= 24576, (source, name, size)
            if size:
                report["productionRuntimeSizes"][source + ":" + name] = size

    projections: dict[str, bytes] = {}
    for name, source in sorted(products.items()):
        contract = output["contracts"][source][name]
        artifact_path = artifact_root / (Path(source).name) / (name + ".json")
        artifact_raw = artifact_path.read_bytes()
        artifact = json.loads(artifact_raw)
        assert artifact["metadata"]["settings"]["compilationTarget"] == {source: name}
        assert artifact["abi"] == contract["abi"], (name, "ABI")
        # Foundry's parsed metadata view omits some empty/default fields; its raw
        # compiler metadata retains the exact original output for this join.
        assert json.loads(artifact["rawMetadata"]) == json.loads(contract["metadata"]), (name, "metadata")
        assert ("storageLayout" in artifact) == ("storageLayout" in contract), (name, "storage layout emission")
        if "storageLayout" in contract:
            assert artifact["storageLayout"] == contract["storageLayout"], (name, "storage layout")
        assert artifact["methodIdentifiers"] == contract["evm"]["methodIdentifiers"], (name, "selectors")
        assert artifact["ast"] == output["sources"][source]["ast"], (name, "same-compilation AST")
        projected = {"compilationHash": context, "source": source, "contractName": name,
                     ("currentNativeExportSha256" if current_native_exports else "physicalArtifactSha256"): sha(artifact_raw),
                     "immutableDeclarations": by_source[source]}
        for field in ("bytecode", "deployedBytecode"):
            native = contract["evm"][field]
            physical = artifact[field]
            assert object_hex(physical["object"]) == object_hex(native["object"]), (name, field, "complete bytes")
            assert physical["linkReferences"] == native["linkReferences"], (name, field, "links")
            refs = native.get("immutableReferences", {})
            assert physical.get("immutableReferences", {}) == refs, (name, field, "immutables")
            length = len(object_hex(native["object"])) // 2
            occupied: set[int] = set()
            for libraries in native["linkReferences"].values():
                for sites in libraries.values():
                    assert sites
                    for site in sites:
                        assert site["length"] == 20 and 0 <= site["start"] <= length - 20
                        span = set(range(site["start"], site["start"] + 20))
                        assert not occupied.intersection(span), "overlapping link range"
                        occupied.update(span)
            for ident, sites in refs.items():
                assert int(ident) in declarations and sites, "unresolved immutable declaration"
                for site in sites:
                    assert site["length"] == 32 and 0 <= site["start"] <= length - 32
                    span = set(range(site["start"], site["start"] + 32))
                    assert not occupied.intersection(span), "overlapping immutable range"
                    occupied.update(span)
                    start = site["start"] * 2
                    assert object_hex(native["object"])[start:start + 64] == "0" * 64
            projected[field] = {"object": "0x" + object_hex(native["object"]),
                                "linkReferences": native["linkReferences"]}
            if field == "deployedBytecode":
                projected[field]["immutableReferences"] = refs
        data = canonical(projected)
        projections[name + ".json"] = data
        report["products"][name] = {"source": source,
                                    "storageLayoutEmitted": "storageLayout" in contract,
                                    "sourceSha256": sha(compiler_input["sources"][source]["content"].encode()),
                                    ("currentNativeExport" if current_native_exports else "physicalArtifact"): str(artifact_path.resolve()),
                                    ("currentNativeExportSha256" if current_native_exports else "physicalArtifactSha256"): sha(artifact_raw),
                                    "projectionBytes": len(data), "projectionSha256": sha(data)}
    destination.mkdir(parents=True, exist_ok=False)
    for name, data in projections.items():
        (destination / name).write_bytes(data)
    (destination / "manifest.json").write_bytes(canonical(report))
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-info", type=Path, required=True)
    parser.add_argument("--artifact-root", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--products", type=Path, required=True)
    parser.add_argument("--current-native-exports", action="store_true")
    args = parser.parse_args()
    products = json.loads(args.products.read_bytes())
    report = project(args.build_info, args.artifact_root, args.destination, products, args.current_native_exports)
    print(json.dumps({"products": len(report["products"]),
                      "productionRuntimes": len(report["productionRuntimeSizes"]),
                      "compilationHash": report["compilerInputSha256"]}))


if __name__ == "__main__":
    main()
