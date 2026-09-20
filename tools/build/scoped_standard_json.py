"""Split Solidity 0.8.19 analysis from selected code generation, without joining outputs.

The full source universe and every setting except outputSelection stay identical.
An AST selector also selects contract names for code generation in this compiler;
the bytecode pass therefore requests AST only in explicitly selected source files.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

VERSION = "0.8.19+commit.7dd6d404"
ANALYSIS_SELECTION = {"*": {"": ["ast"]}}
LEGACY_SELECTOR_TOOL = "3f650af99ecd951fed44b25fb39790f1af7de2e0620d4e68e3ff9a6e19a69d43"


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def same_json(left: object, right: object) -> bool:
    """JSON types matter: Python otherwise equates false, 0 and 0.0."""
    return canonical(left) == canonical(right)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def without_selection(request: dict) -> dict:
    result = copy.deepcopy(request)
    result["settings"].pop("outputSelection", None)
    return result


def split_request(request: dict, selection: dict | None = None) -> tuple[dict, dict]:
    """Return analysis and codegen requests; reject implicit/wildcard contract roots."""
    require(set(request) == {"language", "sources", "settings"} and request["language"] == "Solidity",
            "Expected literal Solidity standard JSON")
    require(bool(request["sources"]), "Empty source universe")
    for source, entry in request["sources"].items():
        require(source not in ("", "*") and set(entry) == {"content"}
                and isinstance(entry["content"], str), f"Expected literal source: {source}")
    selected = copy.deepcopy(selection if selection is not None else request["settings"]["outputSelection"])
    if "*" in selected:
        require(selected.pop("*") == {"": ["ast"]}, "Wildcard contract selection is forbidden")
    scoped = {}
    binary = False
    for source, outputs in selected.items():
        require(source in request["sources"], f"Unknown output source: {source}")
        require(isinstance(outputs, dict), f"Invalid contract selection: {source}")
        if "" in outputs:
            require(outputs.pop("") == ["ast"], "Only AST source output is supported")
        require(bool(outputs), f"AST-only source must name an explicit output contract: {source}")
        for name, fields in outputs.items():
            require(bool(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name)), "Exact contract names required")
            require(isinstance(fields, list) and bool(fields) and all(isinstance(f, str) and f for f in fields),
                    f"Empty or invalid output fields: {source}:{name}")
            require("*" not in fields and "ast" not in fields, "Explicit contract output fields required")
            binary |= any(f in ("evm", "evm.bytecode", "evm.deployedBytecode")
                          or f.startswith(("evm.bytecode.", "evm.deployedBytecode.")) for f in fields)
        scoped[source] = {"": ["ast"], **outputs}
    require(bool(scoped) and binary, "Select at least one bytecode output")
    analysis, codegen = copy.deepcopy(request), copy.deepcopy(request)
    analysis["settings"]["outputSelection"] = copy.deepcopy(ANALYSIS_SELECTION)
    codegen["settings"]["outputSelection"] = scoped
    return analysis, codegen


def successful(output: dict) -> None:
    errors = [e.get("formattedMessage", e.get("message", "compiler error"))
              for e in output.get("errors", []) if e.get("severity") == "error"]
    require(not errors, "Compiler errors: " + "\n".join(errors))


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def instruction_boundary(code: str, target: int) -> bool:
    """Decode only to a claimed opcode; linked PUSH immediates need no decoding."""
    offset = 0
    while offset < target:
        opcode = int(code[offset * 2:(offset + 1) * 2], 16)
        offset += 1 + (opcode - 0x5f if 0x60 <= opcode <= 0x7f else 0)
    return offset == target


def verify_requested_fields(contract: dict, fields: list[str], coordinate: str) -> None:
    for field in fields:
        value = contract
        for part in field.split("."):
            require(isinstance(value, dict) and part in value, f"Requested output missing: {coordinate}:{field}")
            value = value[part]
    if any(f == "evm" or f.startswith(("evm.bytecode", "evm.deployedBytecode")) for f in fields):
        # A partial bytecode object cannot establish absence of immutable refs.
        for field in ("evm.bytecode.object", "evm.bytecode.linkReferences",
                      "evm.deployedBytecode.object", "evm.deployedBytecode.linkReferences",
                      "evm.deployedBytecode.immutableReferences"):
            value = contract
            for part in field.split("."):
                require(isinstance(value, dict) and part in value,
                        f"Incomplete native bytecode evidence: {coordinate}:{field}")
                value = value[part]


def verify_pair(analysis_input: dict, analysis_output: dict,
                codegen_input: dict, codegen_output: dict) -> dict:
    """Validate identities and declarations, never import analysis AST into codegen."""
    require(same_json(without_selection(analysis_input), without_selection(codegen_input)),
            "Source universe or compiler settings differ")
    expected_analysis, expected_codegen = split_request(codegen_input)
    require(same_json(analysis_input, expected_analysis) and same_json(codegen_input, expected_codegen),
            "Requests do not use the separated output selections")
    successful(analysis_output); successful(codegen_output)
    require(not analysis_output.get("contracts"), "Analysis pass unexpectedly emitted contracts")
    sources = set(codegen_input["sources"])
    require(set(analysis_output["sources"]) == sources == set(codegen_output["sources"]),
            "Incomplete compiler source IDs")
    selected = codegen_input["settings"]["outputSelection"]
    actual_contracts = {(s, n) for s, outputs in codegen_output.get("contracts", {}).items() for n in outputs}
    expected_contracts = {(s, n) for s, outputs in selected.items() for n in outputs if n}
    require(actual_contracts == expected_contracts, "Selected contract outputs missing or unexpected")
    all_ids = set(); declarations = {}; definitions = {}; scheduled = set()
    for source in sorted(sources):
        analysis = analysis_output["sources"][source]
        native = codegen_output["sources"][source]
        require(type(analysis.get("id")) is int and analysis["id"] not in all_ids,
                f"Invalid or duplicate source ID: {source}")
        all_ids.add(analysis["id"])
        require(same_json(native.get("id"), analysis["id"]), f"Source ID differs: {source}")
        ast = analysis.get("ast")
        require(isinstance(ast, dict) and ast.get("absolutePath") == source, f"Analysis AST missing: {source}")
        require(("ast" in native) == (source in selected), f"Unexpected native AST roster: {source}")
        if source in selected:
            require(same_json(native["ast"], ast), f"Native AST differs from analysis: {source}")
        contracts = [n for n in ast["nodes"] if n.get("nodeType") == "ContractDefinition"]
        for contract in contracts:
            ident = contract["id"]
            require(ident not in definitions, "Duplicate contract AST ID")
            definitions[ident] = {"source": source, "name": contract["name"],
                                  "kind": contract.get("contractKind"),
                                  "abstract": contract.get("abstract", False),
                                  "dependencies": contract.get("contractDependencies", [])}
            if source in selected:
                scheduled.add(ident)
        if source in selected:
            require(set(selected[source]) - {""} <= {n["name"] for n in contracts},
                    f"Selected contract absent from native AST: {source}")
            for node in walk(native["ast"]):
                if node.get("nodeType") == "VariableDeclaration" and node.get("mutability") == "immutable":
                    ident = str(node["id"])
                    require(ident not in declarations, "Duplicate immutable AST ID")
                    declarations[ident] = {"source": source, "variable": node["name"]}
    joins = []; library_joins = []
    kinds = {(v["source"], v["name"]): v["kind"] for v in definitions.values()}
    for source, name in sorted(actual_contracts):
        contract = codegen_output["contracts"][source][name]
        verify_requested_fields(contract, selected[source][name], source + ":" + name)
        evm = contract.get("evm", {})
        for field in ("bytecode", "deployedBytecode"):
            artifact = evm.get(field, {})
            for ident, sites in artifact.get("immutableReferences", {}).items():
                library_address = ident == "library_deploy_address"
                if library_address:
                    require(field == "deployedBytecode" and kinds[(source, name)] == "library",
                            "Compiler library address requires same-native library runtime AST")
                else:
                    require(ident in declarations,
                            f"Missing same-native immutable declaration {ident} for {source}:{name}; explicitly select its source")
                require(bool(sites), "Empty immutable reference sites")
                code = artifact["object"].removeprefix("0x")
                for site in sites:
                    start, length = site["start"], site["length"]
                    require(type(length) is int and length == 32 and type(start) is int and 0 <= start <= len(code) // 2 - length,
                            "Invalid immutable reference range")
                    require(code[start * 2:(start + length) * 2] == "0" * 64, "Immutable placeholder is not zero")
                    if library_address:
                        # IRGenerator deployCode assigns address(); the runtime
                        # compares loadimmutable(library_deploy_address) to ADDRESS.
                        require(start >= 1 and instruction_boundary(code, start - 1)
                                and code[(start - 1) * 2:start * 2] == "7f"
                                and ((start >= 2 and instruction_boundary(code, start - 2)
                                      and code[(start - 2) * 2:(start - 1) * 2] == "30"
                                      and code[(start + 32) * 2:(start + 33) * 2] == "14")
                                     or code[(start + 32) * 2:(start + 34) * 2] == "3014"),
                                "Compiler library address comparison differs")
                if library_address:
                    library_joins.append({"source": source, "contract": name, "field": field, "id": ident,
                                          "value": "deployed library address", "sites": copy.deepcopy(sites)})
                else:
                    joins.append({"source": source, "contract": name, "field": field, "id": ident,
                                  "declaration": declarations[ident], "sites": copy.deepcopy(sites)})
    closure = set(); pending = list(scheduled)
    while pending:
        ident = pending.pop()
        if ident in closure:
            continue
        require(ident in definitions, "Missing code-generation dependency AST ID")
        closure.add(ident); pending.extend(definitions[ident]["dependencies"])
    coordinates = lambda ids: sorted(definitions[i]["source"] + ":" + definitions[i]["name"] for i in ids)
    result = {"sourceCount": len(sources), "selectedContracts": len(actual_contracts),
            "nativeAstSources": sorted(selected), "immutableJoins": joins,
            "scheduledDefinitions": coordinates(scheduled), "dependencyClosure": coordinates(closure),
            "qualification": "Selector/AST/declaration verification only. Siblings and embedded dependencies still generate code; no deployment, runtime acceptance or speed claim."}
    if library_joins:
        result["librarySelfAddressJoins"] = library_joins
    return result


def capture_pair(request_raw: bytes, selection: dict, compiler: Path, compiler_sha256: str,
                 destination: Path, *, timeout: float, arguments: tuple[str, ...] = ("--standard-json",)) -> dict:
    """Run two bounded native requests, retaining exact stdin/stdout and process records."""
    require(math.isfinite(timeout) and timeout > 0, "Positive finite timeout required")
    require(arguments.count("--standard-json") == 1, "Expected standard JSON compiler arguments")
    compiler = compiler.resolve()
    require(sha(compiler.read_bytes()) == compiler_sha256, "Compiler executable hash differs")
    request = json.loads(request_raw)
    analysis, codegen = split_request(request, selection)
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "requested-input.json").write_bytes(request_raw)
    (destination / "selection.json").write_bytes(canonical(selection))
    record = {"schema": 1, "status": "RUNNING", "compiler": str(compiler), "compilerSha256": compiler_sha256,
              "arguments": list(arguments), "timeoutSecondsPerPass": timeout, "passes": {},
              "toolSha256": sha(Path(__file__).read_bytes())}

    def save():
        record["files"] = {p.name: sha(p.read_bytes()) for p in sorted(destination.iterdir())
                           if p.is_file() and p.name != "record.json"}
        (destination / "record.json").write_bytes(canonical(record))

    save()
    try:
        version = subprocess.run([str(compiler), "--version"], capture_output=True, timeout=min(timeout, 15))
        (destination / "version.stdout").write_bytes(version.stdout)
        (destination / "version.stderr").write_bytes(version.stderr)
        require(version.returncode == 0 and VERSION.encode() in version.stdout, "Pinned Solidity version required")
        outputs = {}
        for name, native_input in (("analysis", analysis), ("codegen", codegen)):
            require(sha(compiler.read_bytes()) == compiler_sha256, "Compiler executable changed")
            (destination / (name + "-input.json")).write_bytes(canonical(native_input))
            step = {"status": "RUNNING", "command": [str(compiler), *arguments], "compilerSha256": compiler_sha256}
            record["passes"][name] = step; save()
            started = time.monotonic()
            with (destination / (name + "-input.json")).open("rb") as inp, \
                    (destination / (name + "-output.json")).open("wb") as out, \
                    (destination / (name + "-stderr.log")).open("wb") as err:
                process = subprocess.Popen(step["command"], stdin=inp, stdout=out, stderr=err)
                try:
                    step["pid"] = process.pid; save()
                    try:
                        step["exitCode"] = process.wait(timeout=timeout)
                        step["status"] = "COMPLETE"
                    except subprocess.TimeoutExpired:
                        step.update(status="TIMEOUT", exitCode=None)
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait()
                    step["seconds"] = round(time.monotonic() - started, 6)
            save()
            require(step["status"] == "COMPLETE" and step["exitCode"] == 0, f"{name} native pass failed: {step['status']}")
            require(sha(compiler.read_bytes()) == compiler_sha256, "Compiler executable changed during pass")
            outputs[name] = json.loads((destination / (name + "-output.json")).read_bytes())
            successful(outputs[name])
        report = verify_pair(analysis, outputs["analysis"], codegen, outputs["codegen"])
        (destination / "verification.json").write_bytes(canonical(report))
        record["status"] = "VERIFIED"
    except BaseException as exc:
        record.update(status="FAILED", error=str(exc))
        raise
    finally:
        save()
    return record


def _read_capture(folder: Path, *, allow_library_revalidation: bool = False) -> tuple[dict, dict, dict, dict]:
    record = json.loads((folder / "record.json").read_bytes())
    legacy_failure = (record.get("status") == "FAILED" and record.get("toolSha256") == LEGACY_SELECTOR_TOOL
                      and re.fullmatch(r"Missing same-native immutable declaration library_deploy_address for .+; explicitly select its source",
                                       record.get("error", "")) is not None)
    require(type(record.get("schema")) is int and record["schema"] == 1 and (record.get("status") == "VERIFIED"
            or (allow_library_revalidation and legacy_failure)), "Capture is not verified")
    actual = {p.name: sha(p.read_bytes()) for p in sorted(folder.iterdir()) if p.is_file() and p.name != "record.json"}
    require(actual == record["files"], "Capture files changed")
    required = {"requested-input.json", "selection.json", "version.stdout", "version.stderr", "verification.json"}
    if legacy_failure:
        required.remove("verification.json")
    required |= {f"{n}-{f}" for n in ("analysis", "codegen") for f in ("input.json", "output.json", "stderr.log")}
    require(set(actual) == required, "Incomplete capture files")
    require(VERSION.encode() in (folder / "version.stdout").read_bytes(), "Pinned compiler version missing")
    require(set(record["passes"]) == {"analysis", "codegen"}, "Incomplete native passes")
    for step in record["passes"].values():
        require(step.get("status") == "COMPLETE" and type(step.get("exitCode")) is int and step["exitCode"] == 0
                and step.get("compilerSha256") == record["compilerSha256"]
                and step.get("command") == [record["compiler"], *record["arguments"]], "Native process evidence differs")
    contexts = [{"solcVersion": "0.8.19", "input": json.loads((folder / (n + "-input.json")).read_bytes()),
                 "output": json.loads((folder / (n + "-output.json")).read_bytes())} for n in ("analysis", "codegen")]
    expected = split_request(json.loads((folder / "requested-input.json").read_bytes()),
                             json.loads((folder / "selection.json").read_bytes()))
    require(same_json(tuple(c["input"] for c in contexts), expected), "Captured request transformation differs")
    analysis, codegen = contexts
    report = verify_pair(analysis["input"], analysis["output"], codegen["input"], codegen["output"])
    if not legacy_failure:
        require(same_json(report, json.loads((folder / "verification.json").read_bytes())), "Capture verification differs")
    else:
        require(bool(report.get("librarySelfAddressJoins")), "Known compiler library field was not verified")
    return analysis, codegen, record, report


def admission_value(folder: Path, record: dict, report: dict) -> dict:
    return {"schema": 1, "status": "VERIFIED_TERMINAL_NATIVE", "capture": str(folder.resolve()),
            "originalCaptureRecordSha256": sha((folder / "record.json").read_bytes()),
            "originalCaptureStatus": record["status"], "originalError": record.get("error"),
            "originalCaptureFiles": record["files"], "verifierSha256": sha(Path(__file__).read_bytes()),
            "verification": report,
            "qualification": "Readmission of unchanged completed native outputs after the specific legacy library-self-address verifier failure. No compiler rerun, artifact rewrite or runtime acceptance."}


def admit_completed_capture(folder: Path, receipt: Path) -> dict:
    """Explicitly admit only the known terminal verifier failure; preserve its record."""
    _, _, record, report = _read_capture(folder, allow_library_revalidation=True)
    require(record["status"] == "FAILED", "Readmission requires the known failed legacy verifier")
    require(not receipt.resolve().is_relative_to(folder.resolve()), "Admission receipt must be outside original capture")
    value = admission_value(folder, record, report)
    with receipt.open("xb") as stream:
        stream.write(canonical(value))
    return value


def read_capture(folder: Path, *, admission: Path | None = None) -> tuple[dict, dict, dict]:
    """Recheck capture and optional explicit readmission; never rewrite prior evidence."""
    analysis, codegen, record, report = _read_capture(folder, allow_library_revalidation=admission is not None)
    if record["status"] == "FAILED":
        value = json.loads(admission.read_bytes())
        require(same_json(value, admission_value(folder, record, report)), "Readmission receipt differs")
        record = {**record, "readmission": {"path": str(admission.resolve()), "sha256": sha(admission.read_bytes()),
                                           "status": value["status"], "verifierSha256": value["verifierSha256"]}}
    elif admission is not None:
        raise ValueError("Readmission is not needed for an originally verified capture")
    return analysis, codegen, record


def forge_ast_transport(native: dict, serialized: dict, prefix: str = "ast") -> list[str]:
    """Recognize only Foundry's added empty AST-node children; keep native AST intact."""
    changes = []

    def visit(left, right, path):
        if isinstance(left, dict) and isinstance(right, dict):
            extra = set(right) - set(left)
            require(not extra or (extra == {"nodes"} and "nodeType" in left and right["nodes"] == []),
                    f"Forge AST added fields: {path}")
            require(not (set(left) - set(right)), f"Forge AST omitted fields: {path}")
            if extra:
                changes.append(path + "/nodes: added empty children")
            for key in left:
                visit(left[key], right[key], path + "/" + key)
        elif isinstance(left, list) and isinstance(right, list):
            require(len(left) == len(right), f"Forge AST list differs: {path}")
            for index, (a, b) in enumerate(zip(left, right)):
                visit(a, b, path + "/" + str(index))
        else:
            require(type(left) is type(right) and left == right, f"Forge AST value differs: {path}")
    visit(native, serialized, prefix)
    return changes


def forge_output_transport(native: dict, serialized: dict) -> list[str]:
    """Check the narrow empty-field serialization observed in pinned Foundry 1.7.1."""
    expected = copy.deepcopy(native); changes = []
    require(set(native["sources"]) == set(serialized["sources"]), "Forge source roster differs")
    for source, value in native["sources"].items():
        actual = serialized["sources"][source]
        if "ast" in value:
            changes.extend(forge_ast_transport(value["ast"], actual["ast"], source))
            expected["sources"][source]["ast"] = actual["ast"]
        elif actual.get("ast") == {}:
            expected["sources"][source]["ast"] = {}
            changes.append(source + ": absent AST serialized as empty object")
    require(set(native["contracts"]) == set(serialized["contracts"]), "Forge contract source roster differs")
    for source, contracts in native["contracts"].items():
        require(set(contracts) == set(serialized["contracts"][source]), "Forge contract roster differs")
        for name, contract in contracts.items():
            actual = serialized["contracts"][source][name]; target = expected["contracts"][source][name]
            label = source + ":" + name
            for field in ("devdoc", "userdoc"):
                if field not in contract and actual.get(field) == {}:
                    target[field] = {}; changes.append(label + ": added empty " + field)
            if contract.get("storageLayout") == {"storage": [], "types": None} and "storageLayout" not in actual:
                del target["storageLayout"]; changes.append(label + ": omitted empty storage layout")
            for field in ("bytecode", "deployedBytecode"):
                original = contract.get("evm", {}).get(field, {})
                serialized_code = actual.get("evm", {}).get(field, {})
                if original.get("immutableReferences") == {} and "immutableReferences" not in serialized_code:
                    del target["evm"][field]["immutableReferences"]
                    changes.append(label + ": omitted empty " + field + " immutable references")
    require(same_json(expected, serialized), "Forge output differs from native output beyond recorded empty-field transport")
    return changes


def forge_storage_transport(native: dict, serialized: dict) -> list[str]:
    if same_json(native, serialized):
        return []
    require(native == {"storage": [], "types": None} and serialized == {"storage": [], "types": {}},
            "Forge storage layout differs")
    return ["empty storage layout types: null serialized as empty object"]


def bind_build_capture(build: dict, folder: Path, *, admission: Path | None = None) -> tuple[dict, dict, dict]:
    """Bind a Forge envelope to actual native requests without rewriting build-info.

    Forge records the request it sent to a forwarding compiler. Retain that
    envelope, but derive compiler-input identities from the actual bytecode pass.
    The two native outputs remain separate, including their AST inventories.
    """
    analysis, native, record = read_capture(folder, admission=admission)
    requested = json.loads((folder / "requested-input.json").read_bytes())
    require(build.get("solcVersion") == "0.8.19", "Build compiler version differs")
    envelope = build["input"]
    extra = set(envelope) - {"language", "sources", "settings"}
    require(extra <= {"version", "allowPaths", "basePath", "includePaths"}, "Unknown Forge input envelope fields")
    require(envelope.get("version", "0.8.19") == "0.8.19", "Forge input version differs")
    literal = {k: envelope[k] for k in ("language", "sources", "settings")}
    require(any(same_json(literal, item) for item in (requested, native["input"])), "Forge request differs from compiler capture")
    transports = forge_output_transport(native["output"], build["output"])
    context = {**build, "input": native["input"], "output": native["output"]}
    evidence = {"capture": str(folder.resolve()), "captureRecordSha256": sha((folder / "record.json").read_bytes()),
                "forgeRequestedInputSha256": sha(canonical(build["input"])),
                "nativeCompilerInputSha256": sha(canonical(native["input"])),
                "analysisInputSha256": sha(canonical(analysis["input"])),
                "compilerSha256": record["compilerSha256"], "forgeEnvelopeFields": {k: envelope[k] for k in sorted(extra)},
                "forgeOutputTransports": transports}
    if "readmission" in record:
        evidence["readmission"] = record["readmission"]
    return context, analysis, evidence


def replay_capture(folder: Path, admission: Path, receipt: Path, arguments: list[str]) -> int:
    """One-use authenticated stdout replay for Forge; no native compiler invocation."""
    _, _, record = read_capture(folder, admission=admission)
    if arguments == ["--version"]:
        sys.stdout.buffer.write((folder / "version.stdout").read_bytes())
        sys.stderr.buffer.write((folder / "version.stderr").read_bytes())
        return 0
    require(arguments == record["arguments"], "Replay compiler arguments differ")
    raw = sys.stdin.buffer.read()
    require(same_json(json.loads(raw), json.loads((folder / "requested-input.json").read_bytes())),
            "Replay requested input differs")
    require(not receipt.resolve().is_relative_to(folder.resolve()), "Replay receipt must be outside original capture")
    value = {"status": "STARTED", "mode": "retained-native-output-replay", "nativeInvocations": 0,
             "captureRecordSha256": sha((folder / "record.json").read_bytes()),
             "admissionSha256": sha(admission.read_bytes()), "requestedInputSha256": sha(raw),
             "nativeOutputSha256": sha((folder / "codegen-output.json").read_bytes()),
             "arguments": arguments, "toolSha256": sha(Path(__file__).read_bytes())}
    with receipt.open("xb") as stream:
        stream.write(canonical(value))
    try:
        sys.stdout.buffer.write((folder / "codegen-output.json").read_bytes()); sys.stdout.buffer.flush()
        sys.stderr.buffer.write((folder / "codegen-stderr.log").read_bytes()); sys.stderr.buffer.flush()
        value["status"] = "COMPLETE"
    except BaseException as exc:
        value.update(status="FAILED", error=str(exc))
        raise
    finally:
        receipt.write_bytes(canonical(value))
    return 0


def forward(manifest_path: Path, arguments: list[str]) -> int:
    """Single-use Forge compiler shim. Return only unchanged native codegen stdout."""
    manifest = json.loads(manifest_path.read_bytes())
    compiler = Path(manifest["compiler"])
    require(sha(compiler.read_bytes()) == manifest["compilerSha256"], "Compiler executable hash differs")
    if arguments == ["--version"]:
        version = subprocess.run([str(compiler), "--version"], capture_output=True, timeout=15)
        require(version.returncode == 0 and VERSION.encode() in version.stdout, "Pinned compiler version required")
        sys.stdout.buffer.write(version.stdout); sys.stderr.buffer.write(version.stderr)
        return version.returncode
    require(arguments == manifest["compilerArguments"], "Unexpected compiler arguments")
    raw = sys.stdin.buffer.read(); request = json.loads(raw)
    require(set(request) == {"language", "sources", "settings"} and request["language"] == "Solidity",
            "Unexpected standard JSON request")
    require(all(set(v) == {"content"} for v in request["sources"].values()), "Literal sources required")
    require({s: sha(v["content"].encode("utf-8")) for s, v in request["sources"].items()} == manifest["sources"],
            "Requested source hashes differ")
    settings = dict(request["settings"]); selection = settings.pop("outputSelection")
    require(same_json(settings, manifest["settingsWithoutOutputSelection"]), "Requested compiler settings differ")
    require(same_json(selection, manifest["expectedOutputSelection"]), "Requested output selection differs")
    destination = Path(manifest["captureDirectory"])
    capture_pair(raw, manifest["actualOutputSelection"], compiler, manifest["compilerSha256"],
                 destination, timeout=manifest["timeoutSeconds"], arguments=tuple(arguments))
    sys.stdout.buffer.write((destination / "codegen-output.json").read_bytes())
    sys.stderr.buffer.write((destination / "codegen-stderr.log").read_bytes())
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("capture")
    run.add_argument("--input", type=Path, required=True)
    run.add_argument("--selection", type=Path, required=True)
    run.add_argument("--solc", type=Path, required=True)
    run.add_argument("--compiler-sha256", required=True)
    run.add_argument("--output", type=Path, required=True)
    run.add_argument("--timeout", type=float, required=True, help="Bound in seconds for each native pass")
    verify = commands.add_parser("verify")
    verify.add_argument("--capture", type=Path, required=True)
    verify.add_argument("--admission", type=Path)
    admit = commands.add_parser("admit")
    admit.add_argument("--capture", type=Path, required=True)
    admit.add_argument("--receipt", type=Path, required=True)
    shim = commands.add_parser("forward")
    shim.add_argument("--manifest", type=Path, required=True)
    shim.add_argument("arguments", nargs=argparse.REMAINDER)
    replay = commands.add_parser("replay")
    replay.add_argument("--capture", type=Path, required=True)
    replay.add_argument("--admission", type=Path, required=True)
    replay.add_argument("--receipt", type=Path, required=True)
    replay.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command == "capture":
        record = capture_pair(args.input.read_bytes(), json.loads(args.selection.read_bytes()), args.solc,
                              args.compiler_sha256, args.output, timeout=args.timeout)
    elif args.command == "verify":
        _, _, record = read_capture(args.capture, admission=args.admission)
    elif args.command == "admit":
        value = admit_completed_capture(args.capture, args.receipt)
        print(json.dumps({"status": value["status"], "originalCaptureStatus": value["originalCaptureStatus"]}))
        return 0
    elif args.command == "forward":
        arguments = args.arguments[1:] if args.arguments[:1] == ["--"] else args.arguments
        return forward(args.manifest, arguments)
    else:
        arguments = args.arguments[1:] if args.arguments[:1] == ["--"] else args.arguments
        return replay_capture(args.capture, args.admission, args.receipt, arguments)
    print(json.dumps({"status": record["status"], "readmission": record.get("readmission"),
                      "passes": record["passes"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
