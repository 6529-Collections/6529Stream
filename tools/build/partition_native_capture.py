"""Read-only intake for original disjoint native partition captures.

This is an explicit alternative to scoped-paired intake, not a converter for
capture records. It authenticates one original partition and its own native
AST/output against the original completed analysis pass. The analysis is never
inserted into native output. Physical artifacts/cache, current source closure,
linked owner closure and deployability remain the caller's separate gates.
"""
from __future__ import annotations

import copy
import json
import math
from pathlib import Path, PurePosixPath
import re

from tools.build.scoped_standard_json import (
    VERSION, canonical, forge_output_transport, require, same_json, sha,
    split_request, successful, verify_pair, without_selection,
)


def strict_json(raw: bytes):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result
    def bad_constant(value):
        raise ValueError("Nonfinite JSON number: " + value)
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=bad_constant)


class _Files:
    def __init__(self):
        self.pins = {}

    def read(self, path: Path, expected: str | None = None) -> bytes:
        path = path.resolve()
        raw = path.read_bytes()
        actual = sha(raw)
        if expected is not None:
            require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected)
                    and actual == expected, "Evidence hash differs: " + str(path))
        require(str(path) not in self.pins or self.pins[str(path)] == actual,
                "Evidence changed during intake: " + str(path))
        self.pins[str(path)] = actual
        return raw

    def json(self, path: Path, expected: str | None = None):
        return strict_json(self.read(path, expected))

    def recheck(self):
        for path, expected in self.pins.items():
            require(sha(Path(path).read_bytes()) == expected,
                    "Evidence changed during intake: " + path)


def _file_table(files: _Files, folder: Path, record: dict, required: set[str]):
    table = record.get("files")
    require(isinstance(table, dict) and required <= set(table), "Incomplete capture file table")
    actual = {p.name for p in folder.iterdir() if p.is_file() and p.name != "record.json"}
    require(actual == set(table), "Capture file roster differs")
    for name, expected in table.items():
        require(isinstance(name, str) and name not in ("", ".", "..", "record.json")
                and Path(name).name == name and "/" not in name and "\\" not in name,
                "Invalid capture filename")
        files.read(folder / name, expected)


def _selection(request: dict, analysis: dict, coordinates: list[str]) -> dict:
    """Original a9e9733 selection rule, without its compiler invocation code."""
    definitions = {}
    names = {}
    for source, row in analysis["sources"].items():
        for node in row["ast"]["nodes"]:
            if node.get("nodeType") == "ContractDefinition":
                require(node["id"] not in definitions, "Duplicate contract declaration ID")
                definitions[node["id"]] = (source, node)
                coordinate = source + ":" + node["name"]
                require(coordinate not in names, "Duplicate contract coordinate")
                names[coordinate] = (source, node)
    require(isinstance(coordinates, list) and coordinates and all(isinstance(c, str) for c in coordinates)
            and len(coordinates) == len(set(coordinates)), "Duplicate or empty partition products")
    selected = {}
    for coordinate in coordinates:
        require(coordinate in names, "Unknown partition product: " + coordinate)
        source, node = names[coordinate]
        fields = request["settings"]["outputSelection"].get(source, {}).get(node["name"])
        require(bool(fields), "Product absent from original selection: " + coordinate)
        selected.setdefault(source, {})[node["name"]] = copy.deepcopy(fields)
        for ancestor in node.get("linearizedBaseContracts", [node["id"]]):
            require(ancestor in definitions, "Unknown original ancestor declaration")
            base_source, base = definitions[ancestor]
            if any(n.get("nodeType") == "VariableDeclaration" and n.get("mutability") == "immutable"
                   for n in base.get("nodes", [])):
                selected.setdefault(base_source, {})[""] = ["ast"]
    for source in selected:
        selected[source][""] = ["ast"]
    return selected


def _pinned_path(files: _Files, base: Path, row: dict) -> tuple[Path, dict]:
    require(isinstance(row, dict) and set(row) == {"path", "sha256"}
            and isinstance(row["path"], str) and row["path"], "Invalid pinned evidence path")
    path = (base / row["path"]).resolve()
    return path, files.json(path, row["sha256"])


def _read_partition(folder: Path, provenance: Path, files: _Files):
    folder, provenance = folder.resolve(), provenance.resolve()
    descriptor = files.json(provenance)
    require(isinstance(descriptor, dict) and set(descriptor) == {
        "schema", "kind", "partitionId", "plan", "index", "recordSha256"},
        "Expected explicit partition provenance descriptor")
    require(type(descriptor["schema"]) is int and descriptor["schema"] == 1
            and descriptor["kind"] == "partition-native"
            and re.fullmatch(r"part-[0-9]{3,}", descriptor["partitionId"]),
            "Unsupported partition provenance")
    plan_path, plan = _pinned_path(files, provenance.parent, descriptor["plan"])
    index_path, index = _pinned_path(files, provenance.parent, descriptor["index"])
    require(folder == (index_path.parent / descriptor["partitionId"]).resolve(),
            "Partition directory is not the indexed original owner")
    # The original runner retained its exact plan beside the partition index.
    files.read(index_path.parent / "plan.json", descriptor["plan"]["sha256"])
    require(type(plan.get("schema")) is int and plan["schema"] == 1
            and plan.get("kind") == "DISJOINT_NATIVE_PARTITIONS"
            and type(plan.get("automaticRetries")) is int and plan["automaticRetries"] == 0,
            "Unsupported original partition plan")
    require(type(plan.get("workers")) is int and 1 <= plan["workers"] <= 4
            and type(plan.get("timeoutSeconds")) in (int, float)
            and math.isfinite(plan["timeoutSeconds"]) and 0 < plan["timeoutSeconds"] <= 5400,
            "Original partition bounds differ")
    parent = Path(plan["capture"]).resolve()
    record = files.json(parent / "record.json", plan["captureRecordSha256"])
    require(type(record.get("schema")) is int and record["schema"] == 1
            and record.get("status") in ("VERIFIED", "FAILED"), "Parent capture is not terminal")
    _file_table(files, parent, record, {
        "analysis-input.json", "analysis-output.json", "analysis-stderr.log",
        "codegen-input.json", "requested-input.json", "selection.json", "version.stdout", "version.stderr"})
    require(plan["compiler"] == record.get("compiler")
            and plan["compilerSha256"] == record.get("compilerSha256")
            and same_json(plan["arguments"], record.get("arguments")), "Parent compiler identity differs")
    require(isinstance(plan["arguments"], list)
            and all(isinstance(a, str) for a in plan["arguments"])
            and plan["arguments"].count("--standard-json") == 1, "Invalid native compiler arguments")
    files.read(Path(plan["compiler"]), plan["compilerSha256"])
    files.read(Path(plan["verifier"]), plan["verifierSha256"])
    require(record.get("toolSha256") == plan["verifierSha256"], "Parent verifier identity differs")
    require(VERSION.encode() in files.read(parent / "version.stdout"), "Compiler version evidence differs")
    step = record.get("passes", {}).get("analysis", {})
    require(step.get("status") == "COMPLETE" and type(step.get("exitCode")) is int and step["exitCode"] == 0
            and step.get("compilerSha256") == plan["compilerSha256"]
            and same_json(step.get("command"), [plan["compiler"], *plan["arguments"]]),
            "Original analysis process did not complete authentically")
    original = files.json(parent / "codegen-input.json", plan["originalInputSha256"])
    ai = files.json(parent / "analysis-input.json", plan["analysisInputSha256"])
    ao = files.json(parent / "analysis-output.json", plan["analysisOutputSha256"])
    requested = files.json(parent / "requested-input.json")
    selection = files.json(parent / "selection.json")
    expected_ai, expected_original = split_request(requested, selection,
                                                  all_source_asts=record.get("allSourceAsts", False))
    require(same_json(ai, expected_ai) and same_json(original, expected_original),
            "Parent requests differ from original split")
    require(sha(canonical(without_selection(original))) == plan["semanticContextSha256"],
            "Original semantic context differs")
    successful(ao)
    require(not ao.get("contracts"), "Parent analysis emitted contracts")
    # Disallow alias paths and URL-based sources before any named declaration join.
    for source, row in original["sources"].items():
        path = PurePosixPath(source)
        require(path.as_posix() == source and not path.is_absolute() and ".." not in path.parts
                and "\\" not in source and ":" not in source
                and set(row) == {"content"} and isinstance(row["content"], str),
                "Expected canonical literal source path: " + source)
    require(set(ao["sources"]) == set(original["sources"]), "Original analysis source roster differs")
    require(isinstance(plan.get("partitions"), list) and plan["partitions"], "Empty original partition plan")
    seen, planned = set(), {}
    for number, partition in enumerate(plan["partitions"]):
        require(set(partition) == {"id", "products", "selection", "inputSha256"}
                and partition["id"] == f"part-{number:03d}", "Original partition ID/fields differ")
        products = partition["products"]
        selected = _selection(original, ao, products)
        require(products == sorted(products) and not seen.intersection(products), "Overlapping or unordered products")
        seen.update(products)
        _, ni = split_request(original, selected)
        require(same_json(selected, partition["selection"])
                and sha(canonical(ni)) == partition["inputSha256"], "Partition selection reconstruction differs")
        planned[partition["id"]] = partition
    require(type(plan.get("productCount")) is int and len(seen) == plan["productCount"], "Plan product count differs")
    require(index.get("schema") == 1 and index.get("status") in ("VERIFIED_PARTITION_SET", "INCOMPLETE_PARTITION_SET")
            and index.get("planSha256") == descriptor["plan"]["sha256"]
            and index.get("semanticContextSha256") == plan["semanticContextSha256"], "Original partition index differs")
    require(isinstance(index.get("partitions"), list) and len(index["partitions"]) == len(planned),
            "Original index partition roster differs")
    indexed = {r["id"]: r for r in index["partitions"]}
    require(len(indexed) == len(planned) and set(indexed) == set(planned), "Duplicate/unknown index partition")
    successful_owners = {}
    for ident, entry in indexed.items():
        if entry.get("status") == "VERIFIED_NATIVE_PARTITION":
            require(same_json(entry.get("products"), planned[ident]["products"]), "Indexed product roster differs")
            for coord in entry["products"]:
                successful_owners[coord] = ident
    require(set(index.get("products", {})) == set(successful_owners), "Index product roster differs")
    if index["status"] == "VERIFIED_PARTITION_SET":
        require(len(successful_owners) == len(seen), "Index claims an incomplete set is verified")
    ident = descriptor["partitionId"]
    require(ident in planned, "Partition absent from original plan")
    partition = planned[ident]
    native_record = files.json(folder / "record.json", descriptor["recordSha256"])
    require(same_json(native_record, indexed[ident]), "Original native record differs from index")
    require(native_record.get("status") == "VERIFIED_NATIVE_PARTITION"
            and type(native_record.get("exitCode")) is int and native_record["exitCode"] == 0
            and type(native_record.get("attempt")) is int and native_record["attempt"] == 1
            and native_record.get("id") == ident and native_record.get("compilerSha256") == plan["compilerSha256"]
            and same_json(native_record.get("command"), [plan["compiler"], *plan["arguments"]])
            and native_record.get("planSha256") == descriptor["plan"]["sha256"]
            and native_record.get("timeoutSeconds") == plan["timeoutSeconds"]
            and native_record.get("semanticContextSha256") == plan["semanticContextSha256"]
            and native_record.get("inputSha256") == partition["inputSha256"]
            and same_json(native_record.get("products"), partition["products"]), "Native partition provenance differs")
    _file_table(files, folder, native_record, {"input.json", "output.json", "stderr.log", "verification.json"})
    ni = files.json(folder / "input.json", partition["inputSha256"])
    no = files.json(folder / "output.json")
    wanted = copy.deepcopy(original)
    wanted["settings"]["outputSelection"] = partition["selection"]
    require(same_json(ni, wanted), "Actual native request differs from planned partition")
    for coord in partition["products"]:
        require(same_json(index["products"][coord], {
            "partition": ident, "inputSha256": partition["inputSha256"],
            "outputSha256": native_record["files"]["output.json"],
            "recordSha256": descriptor["recordSha256"]}), "Indexed product owner differs")
    verification = verify_pair(ai, ao, ni, no)
    # Historical report bytes are retained/pinned above. Revalidation uses the
    # current verifier; its schema may evolve without changing the old report.
    evidence = {
        "captureKind": "partition-native", "capture": str(folder),
        "captureRecordSha256": descriptor["recordSha256"],
        "partitionProvenance": str(provenance), "partitionProvenanceSha256": files.pins[str(provenance)],
        "partitionId": ident, "planSha256": descriptor["plan"]["sha256"],
        "indexSha256": descriptor["index"]["sha256"],
        "parentCaptureStatus": record["status"], "parentAnalysisStatus": step["status"],
        "parentCaptureRecordSha256": plan["captureRecordSha256"],
        "nativeInputSha256": native_record["files"]["input.json"],
        "nativeOutputSha256": native_record["files"]["output.json"],
        "analysisInputSha256": sha(canonical(ai)), "analysisOutputSha256": plan["analysisOutputSha256"],
        "compilerSha256": plan["compilerSha256"], "historicalVerifierSha256": plan["verifierSha256"],
        "currentVerification": verification,
        "qualification": "Original partition provenance and own-output AST only; current source/profile, physical artifacts/cache, links, sizes and execution require separate gates.",
    }
    return {"input": ai, "output": ao}, {"input": ni, "output": no}, evidence, requested


def bind_partition_build_capture(build: dict, folder: Path, *, provenance: Path) -> tuple[dict, dict, dict]:
    """Return the scoped binder's shape while preserving original partition files.

    The explicitly pinned provenance descriptor is not a readmission or a claim
    that historical sources are current. No compiler, replay or filesystem write
    occurs. Forge physical artifact validation remains with the existing exporter.
    """
    files = _Files()
    analysis, native, evidence, requested = _read_partition(Path(folder), Path(provenance), files)
    require(build.get("solcVersion") == "0.8.19", "Build compiler version differs")
    if "solcLongVersion" in build:
        require(build["solcLongVersion"] in ("0.8.19", VERSION)
                or build["solcLongVersion"].startswith(VERSION + "."), "Build long compiler version differs")
    envelope = build["input"]
    extra = set(envelope) - {"language", "sources", "settings"}
    require(extra <= {"version", "allowPaths", "basePath", "includePaths"}, "Unknown Forge input envelope fields")
    require(envelope.get("version", "0.8.19") == "0.8.19", "Forge input version differs")
    literal = {k: envelope[k] for k in ("language", "sources", "settings")}
    require(any(same_json(literal, value) for value in (requested, native["input"])),
            "Forge request differs from original requested/partition input")
    transports = forge_output_transport(native["output"], build["output"])
    evidence.update({
        "forgeRequestedInputSha256": sha(canonical(envelope)),
        "forgeRequestKind": "partition" if same_json(literal, native["input"]) else "original-parent-request",
        "nativeCompilerInputSha256": sha(canonical(native["input"])),
        "forgeEnvelopeFields": {k: envelope[k] for k in sorted(extra)},
        "forgeOutputTransports": transports, "authenticatedFiles": dict(sorted(files.pins.items())),
    })
    files.recheck()
    return {**build, "input": native["input"], "output": native["output"]}, analysis, evidence
