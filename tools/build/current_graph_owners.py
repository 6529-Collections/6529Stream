"""Explicit, independently authenticated native owners for flat graph projections."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile

from tools.build.scoped_standard_json import canonical
from tools.build.native_capture import bind_native_capture, native_filenames, validate_capture_options


def strict_json(raw: bytes):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=pairs)


def coordinate(value: str) -> tuple[str, str]:
    if not isinstance(value, str):
        raise ValueError("Native owner coordinate must be a string")
    source, separator, name = value.partition(":")
    path = PurePosixPath(source)
    if (not separator or not source.startswith(("smart-contracts/", "test/", "script/"))
            or path.suffix != ".sol" or path.as_posix() != source or ".." in path.parts
            or "\\" in source or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name)):
        raise ValueError(f"Invalid native owner coordinate: {value!r}")
    return source, name


def owner_manifest(data: dict, products: dict, hosts: tuple, creation: str | None) -> dict:
    if not isinstance(data, dict) or set(data) != {"version", "contexts", "owners"} or type(data["version"]) is not int or data["version"] != 1:
        raise ValueError("Expected native owner manifest version 1")
    contexts, owners = data["contexts"], data["owners"]
    if not isinstance(contexts, dict) or not contexts or not isinstance(owners, dict):
        raise ValueError("Nonempty native contexts and coordinate owners required")
    if not isinstance(products, dict) or (not products and creation is not None):
        raise ValueError("Nonempty projection product mapping required")
    for name, source in products.items():
        if not isinstance(name, str) or not isinstance(source, str):
            raise ValueError("Projection coordinates must be strings")
        coordinate(source + ":" + name)
        if not source.startswith("smart-contracts/"):
            raise ValueError("Projection products must be production coordinates")
    required = {s + ":" + n for n, s in products.items()} | {s + ":" + n for s, n in hosts} | ({creation} if creation is not None else set())
    if not required <= set(owners):
        raise ValueError(f"Missing explicit native owners: {sorted(required - set(owners))}")
    for value, label in owners.items():
        coordinate(value)
        if not isinstance(label, str) or label not in contexts:
            raise ValueError(f"Unknown native owner for {value}")
    if set(owners.values()) != set(contexts):
        raise ValueError("Unused or missing native context")
    fields = {"out", "cache", "buildId", "compilerCapture", "buildInfoSha256", "nativeInputSha256", "nativeOutputSha256"}
    for label, row in contexts.items():
        if (not isinstance(label, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", label) or not isinstance(row, dict)
                or not fields <= set(row) or set(row) - fields - {"compilerAdmission", "captureKind", "partitionProvenance"}):
            raise ValueError(f"Invalid native context: {label}")
        if not all(isinstance(v, str) and v for v in row.values()):
            raise ValueError(f"Native context values must be nonempty strings: {label}")
        validate_capture_options(row.get("captureKind", "scoped-paired"),
                                 row.get("partitionProvenance"), row.get("compilerAdmission"))
        if not re.fullmatch(r"[A-Za-z0-9_-]+", row["buildId"]):
            raise ValueError("Invalid native build ID")
        for key in ("buildInfoSha256", "nativeInputSha256", "nativeOutputSha256"):
            if not re.fullmatch(r"[0-9a-f]{64}", row[key]):
                raise ValueError(f"Expected exact SHA-256: {label}.{key}")
    return data


def getcode_creation(build: dict, source: str, name: str) -> bool:
    """Detect actual getCode calls in the cached creation library's native AST."""
    ast = build["output"]["sources"][source]["ast"]
    contract = next(n for n in ast["nodes"] if n.get("nodeType") == "ContractDefinition" and n["name"] == name)
    def walk(value):
        if isinstance(value, dict):
            yield value
            for item in value.values():
                yield from walk(item)
        elif isinstance(value, list):
            for item in value:
                yield from walk(item)
    return any(n.get("nodeType") == "FunctionCall"
               and n.get("expression", {}).get("nodeType") == "MemberAccess"
               and n["expression"].get("memberName") == "getCode" for n in walk(contract))


def literal_artifact_inventory(contexts: dict, owners: dict | None = None) -> dict:
    """Conservative literal inventory, including inherited fixture import closures.

    Analysis ASTs discover paths only; they never provide immutable declarations
    or executable fields. Unused literal entries are retained deliberately.
    """
    from tools.build.prepare_current_graph import source_closure
    found = {}
    def walk(value):
        if isinstance(value, dict):
            yield value
            for child in value.values():
                yield from walk(child)
        elif isinstance(value, list):
            for child in value:
                yield from walk(child)
    for context in contexts.values():
        closure = source_closure(context["build"], context["roots"], analysis=context["analysis"])
        asts = (context["analysis"] or context["build"])["output"]["sources"]
        for source in sorted(closure):
            for node in walk(asts[source]["ast"]):
                value = node.get("value")
                if (node.get("nodeType") == "Literal" and isinstance(value, str)
                        and re.fullmatch(r"[^\s:]+\.sol:[A-Za-z_][A-Za-z0-9_]*", value)):
                    coordinate(value)  # Abbreviated/ambiguous artifact names fail closed.
                    found.setdefault(value, set()).add(source)
    missing = set(found) - set(owners) if owners is not None else set()
    if missing:
        raise ValueError(f"Missing literal artifact owners: {sorted(missing)}")
    return {coord: sorted(sources) for coord, sources in sorted(found.items())}


def validate_destinations(artifact_root: Path, project: Path, contexts: dict) -> None:
    destinations = (artifact_root.resolve(), (project / "artifacts/native-assembly/compiled").resolve())
    for context in contexts.values():
        for original in (context["out"], context["cache"], context["capture"]):
            original = original.resolve()
            if any(original.is_relative_to(path) or path.is_relative_to(original) for path in destinations):
                raise ValueError(f"Graph destination overlaps original native evidence: {original}")


def load_context(project: Path, config: Path, label: str, row: dict, assignments: dict) -> dict:
    from tools.build.prepare_current_graph import sha, select_build, validate_sources
    resolve = lambda value: (config.parent / value).resolve()
    output, cache_dir = resolve(row["out"]), resolve(row["cache"])
    capture = resolve(row["compilerCapture"])
    admission = resolve(row["compilerAdmission"]) if "compilerAdmission" in row else None
    build_path = output / "build-info" / (row["buildId"] + ".json")
    cache_path = cache_dir / "solidity-files-cache.json"
    raw = build_path.read_bytes(); cache_raw = cache_path.read_bytes()
    kind = row.get("captureKind", "scoped-paired")
    provenance = resolve(row["partitionProvenance"]) if "partitionProvenance" in row else None
    input_name, output_name = native_filenames(kind)
    input_path, output_path = capture / input_name, capture / output_name
    pins = {"buildInfoSha256": sha(raw), "nativeInputSha256": sha(input_path.read_bytes()),
            "nativeOutputSha256": sha(output_path.read_bytes())}
    if any(row[key] != value for key, value in pins.items()):
        raise ValueError(f"Native owner evidence hash differs: {label}")
    envelope = json.loads(raw); cache = json.loads(cache_raw)
    if envelope["id"] != row["buildId"]:
        raise ValueError(f"Native owner build ID differs: {label}")
    build, analysis, evidence = bind_native_capture(envelope, capture, kind=kind, provenance=provenance, admission=admission)
    inventory = {}; physical = {}
    for coord, owner in assignments.items():
        if owner != label:
            continue
        source, name = coordinate(coord)
        if name in inventory:
            raise ValueError(f"Duplicate artifact basename in native owner {label}: {name}")
        if select_build(cache, ((source, name),)) != row["buildId"]:
            raise ValueError(f"Physical cache owns a different native product: {coord}")
        # Require the actual selected product, never a sibling's or other pass's emission.
        build["output"]["contracts"][source][name]
        path = output / Path(source).name / (name + ".json")
        physical[path] = sha(path.read_bytes())
        inventory[name] = source
    roots = set(inventory.values())
    transports = validate_sources(project, build, source_roots=roots, analysis=analysis)
    identity = {"out": str(output), "cache": str(cache_dir), "capture": str(capture),
                "admission": str(admission) if admission else None, "buildInfo": str(build_path), "cacheSha256": sha(cache_raw), **pins}
    if kind == "partition-native":
        identity.update(captureKind=kind, partitionProvenance=str(provenance), partitionProvenanceSha256=sha(provenance.read_bytes()))
    return {"captureKind": kind, "partitionProvenance": provenance, "identity": sha(canonical(identity)), "identityFields": identity, "buildId": row["buildId"],
            "build": build, "analysis": analysis, "captureEvidence": evidence,
            "capture": capture, "admission": admission, "path": build_path, "raw": raw,
            "out": output, "cache": cache_dir, "cachePath": cache_path, "cacheRaw": cache_raw,
            "physical": physical, "inventory": inventory, "roots": roots, "transports": transports}


def validate_owner_joins(contexts: dict, owners: dict, products: dict) -> None:
    """Require native link owners and same-context immutable parent projections."""
    identities = [c["identity"] for c in contexts.values()]
    if len(identities) != len(set(identities)):
        raise ValueError("Duplicate labels for one native context")
    settings = [{k: v for k, v in c["build"]["input"]["settings"].items() if k != "outputSelection"}
                for c in contexts.values()]
    if any(value != settings[0] for value in settings[1:]):
        raise ValueError("Native owner compiler settings differ beyond outputSelection")
    if settings[0].get("libraries"):
        raise ValueError("Prelinked compiler libraries are unsupported by explicit native owners")
    metadata = settings[0].get("metadata", {})
    if metadata.get("bytecodeHash") != "none" or metadata.get("appendCBOR") is not False:
        raise ValueError("Explicit native owners require original metadata-none/no-CBOR settings")
    product_coords = {s + ":" + n for n, s in products.items()}
    by_context = {}; definitions = {}; discovery = {}
    for label, context in contexts.items():
        declarations = {}; contracts = {}
        for filename, result in context["build"]["output"]["sources"].items():
            for definition in result.get("ast", {}).get("nodes", []):
                if definition.get("nodeType") != "ContractDefinition":
                    continue
                ident = definition["id"]
                if ident in contracts:
                    raise ValueError("Duplicate same-native contract declaration")
                contracts[ident] = (filename + ":" + definition["name"], definition)
                for node in definition["nodes"]:
                    if node.get("nodeType") == "VariableDeclaration" and node.get("mutability") == "immutable":
                        ident = str(node["id"])
                        if ident in declarations:
                            raise ValueError("Duplicate same-native immutable declaration")
                        declarations[ident] = filename + ":" + definition["name"]
        by_context[label] = declarations
        definitions[label] = contracts
        discovered = {}
        for filename, result in (context["analysis"] or context["build"])["output"]["sources"].items():
            for node in result.get("ast", {}).get("nodes", []):
                if node.get("nodeType") == "ContractDefinition":
                    if node["id"] in discovered:
                        raise ValueError("Duplicate analysis contract declaration")
                    discovered[node["id"]] = (filename + ":" + node["name"], node)
        discovery[label] = discovered
    for coord, label in owners.items():
        source, name = coordinate(coord); context = contexts[label]
        contract = context["build"]["output"]["contracts"][source][name]
        declarations = by_context[label]
        definition = next(n for c, n in definitions[label].values() if c == coord)
        # contractDependencies records embedded new/type.creationCode dependencies.
        # Discover names from the bound analysis; never substitute its child bytes.
        for ident in definition["contractDependencies"]:
            if ident not in discovery[label]:
                raise ValueError(f"Missing construction dependency declaration: {coord}:{ident}")
            child, node = discovery[label][ident]
            if node.get("contractKind") != "contract" or node.get("abstract"):
                continue
            if child not in owners:
                raise ValueError(f"Missing embedded construction owner: {coord} -> {child}")
            if contexts[owners[child]]["identity"] != context["identity"]:
                raise ValueError(f"Mixed embedded construction ownership: {coord} -> {child}")
        if coord in product_coords:
            # Intermediate projected bases can be supplied to the flat runtime reader
            # even when their own source declares no referenced immutable variable.
            for ident in definition["linearizedBaseContracts"]:
                if ident not in discovery[label]:
                    raise ValueError(f"Missing ancestor declaration: {coord}:{ident}")
                parent = discovery[label][ident][0]
                if parent in product_coords:
                    if ident not in definitions[label]:
                        raise ValueError(f"Missing same-native ancestor AST: {coord} -> {parent}")
                    if contexts[owners[parent]]["identity"] != context["identity"]:
                        raise ValueError(f"Mixed immutable parent ownership: {coord} -> {parent}")
        for field in ("bytecode", "deployedBytecode"):
            native = contract["evm"][field]
            for filename, libraries in native["linkReferences"].items():
                for library in libraries:
                    target = filename + ":" + library
                    if target not in owners:
                        raise ValueError(f"Missing explicit linked-library owner: {coord} -> {target}")
                    linked = contexts[owners[target]]["build"]["output"]["sources"][filename]["ast"]
                    if not any(n.get("nodeType") == "ContractDefinition" and n.get("name") == library
                               and n.get("contractKind") == "library" for n in linked["nodes"]):
                        raise ValueError(f"Linked target is not a native library: {target}")
            if coord not in product_coords:
                continue  # Export-only libraries keep their compiler-generated self-address refs.
            for ident in native.get("immutableReferences", {}):
                if ident not in declarations:
                    raise ValueError(f"Missing same-native immutable declaration: {coord}:{ident}")
                parent = declarations[ident]
                if parent not in product_coords:
                    raise ValueError(f"Missing flat immutable parent projection: {coord} -> {parent}")
                if contexts[owners[parent]]["identity"] != context["identity"]:
                    raise ValueError(f"Mixed immutable parent ownership: {coord} -> {parent}")


def recheck_context(project: Path, context: dict) -> None:
    from tools.build.prepare_current_graph import sha, validate_sources
    if context["path"].read_bytes() != context["raw"] or context["cachePath"].read_bytes() != context["cacheRaw"]:
        raise ValueError("Native build/cache changed during preparation")
    for path, digest in context["physical"].items():
        if sha(path.read_bytes()) != digest:
            raise ValueError(f"Physical artifact changed during preparation: {path}")
    _, _, evidence = bind_native_capture(json.loads(context["raw"]), context["capture"],
                                         kind=context.get("captureKind", "scoped-paired"),
                                         provenance=context.get("partitionProvenance"), admission=context["admission"])
    if evidence != context["captureEvidence"]:
        raise ValueError("Native capture changed during preparation")
    validate_sources(project, context["build"], source_roots=context["roots"], analysis=context["analysis"])


def prepare_owned(project: Path, products_path: Path, config: Path, hosts: tuple,
                  artifact_root: Path, *, owners_only: bool = False) -> dict:
    from tools.build.prepare_current_graph import ROOT, CREATION_SOURCE, CREATION_NAME, sha, retain_exports
    config = config.resolve(); products_raw = products_path.read_bytes(); config_raw = config.read_bytes()
    if sys.flags.optimize or os.environ.get("PYTHONOPTIMIZE", "0") not in ("", "0"):
        raise ValueError("Graph preparation requires enabled Python assertions")
    products = strict_json(products_raw)
    if owners_only:
        if products:
            raise ValueError("Export-only ownership requires an empty projection map")
    elif not products:
        raise ValueError("Nonempty projection products required")
    data = owner_manifest(strict_json(config_raw), products, hosts, None if owners_only else CREATION_SOURCE + ":" + CREATION_NAME)
    contexts = {label: load_context(project, config, label, row, data["owners"])
                for label, row in data["contexts"].items()}
    validate_destinations(artifact_root, project, contexts)
    validate_owner_joins(contexts, data["owners"], products)
    literal_artifacts = literal_artifact_inventory(contexts, data["owners"])
    spec = importlib.util.spec_from_file_location("stream_owned_projection", ROOT / "test/helpers/native_assembly_artifacts.py")
    projector = importlib.util.module_from_spec(spec); spec.loader.exec_module(projector)
    with tempfile.TemporaryDirectory(prefix="owners-", dir=artifact_root) as temporary:
        temp = Path(temporary); projections = {}; reports = {}
        for label, context in contexts.items():
            folder = temp / label; folder.mkdir()
            selected = {n: s for n, s in products.items() if data["owners"][s + ":" + n] == label}
            helpers = folder / "helpers.json"; inventory = folder / "products.json"
            helpers.write_bytes(canonical(context["inventory"])); inventory.write_bytes(canonical(selected))
            exports = folder / "exports"
            command = [sys.executable, "-B", str(ROOT / "test/helpers/native_assembly_native_exports.py"),
                       "--project", str(project), "--build-id", context["buildId"], "--products", str(inventory),
                       "--helpers", str(helpers), "--out", str(context["out"]), "--cache-path", str(context["cache"]),
                       "--output", str(exports), "--compiler-capture", str(context["capture"])]
            if context.get("captureKind") == "partition-native":
                command += ["--capture-kind", "partition-native", "--partition-provenance", str(context["partitionProvenance"])]
            if context["admission"]:
                command += ["--compiler-admission", str(context["admission"])]
            subprocess.run(command, check=True)
            # Every assigned coordinate is also passed as a helper: the exporter enforces
            # exact physical/native executable joins, in addition to the explicit cache owner.
            retained = retain_exports(exports, artifact_root, context["identity"])
            projected = folder / "compiled"
            report = projector.project(context["path"], retained, projected, selected, True,
                                       compiler_capture=context["capture"], compiler_admission=context["admission"],
                                       capture_kind=context.get("captureKind", "scoped-paired"),
                                       partition_provenance=context.get("partitionProvenance"))
            context["retained"] = retained
            reports[context["identity"]] = report
            for name in selected:
                projections[name + ".json"] = (projected / (name + ".json")).read_bytes()
        for context in contexts.values():
            recheck_context(project, context)
        if products_path.read_bytes() != products_raw or config.read_bytes() != config_raw:
            raise ValueError("Native owner/product manifest changed during preparation")
        owners = {coord: contexts[label]["identity"] for coord, label in data["owners"].items()}
        manifest = {"mode": "explicit-native-owners", "artifactInputKind": "current-native-export", "owners": owners, "contexts": reports,
                    "products": {name: {"source": source, "owner": owners[source + ":" + name],
                                          "projectionSha256": sha(projections[name + ".json"]),
                                          "projectionBytes": len(projections[name + ".json"])}
                                 for name, source in products.items()}}
        projections["manifest.json"] = canonical(manifest)
        destinations = [] if owners_only else [project / p for p in ("artifacts/current-graph/compiled", "artifacts/native-assembly/compiled")]
        for destination in destinations:
            if destination.exists() and {p.name for p in destination.iterdir()} - set(projections):
                raise ValueError(f"Unexpected files in managed graph directory: {destination}")
        for destination in destinations:
            destination.mkdir(parents=True, exist_ok=True)
            for name, raw in projections.items():
                path = destination / (name + ".tmp"); path.write_bytes(raw); path.replace(destination / name)
        result = {"mode": "explicit-native-owners", "projectionMode": "none" if owners_only else "flat",
                  "ownerManifestSha256": sha(config_raw),
                  "products": len(products), "owners": owners, "literalArtifactSources": literal_artifacts,
                  "compilerContexts": {c["identity"]: {**c["identityFields"], "label": label,
                      "buildId": c["buildId"], "compilerCapture": c["captureEvidence"],
                      "nativeExports": str(c["retained"]), "sourceRoots": sorted(c["roots"]),
                      "sourceLineEndingTransports": c["transports"],
                      "physicalArtifactHashes": {str(p): digest for p, digest in c["physical"].items()}}
                      for label, c in contexts.items()},
                  "projectionManifestSha256": None if owners_only else sha(projections["manifest.json"]),
                  "qualification": "Separate authenticated native owners; no bytecode or AST merging. No compiler, runtime or release accepted."}
        (artifact_root / "preparation.json").write_bytes(canonical(result))
        return result
