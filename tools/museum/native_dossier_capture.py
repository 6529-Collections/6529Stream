"""Read-only, externally pinned native dossier capture and offline assembly.

The caller supplies a verified same-block V1 base and every native anchor. This
runner never deploys, publishes, starts a chain, or discovers trusted code pins.
"""
import argparse
import os
import re
from pathlib import Path
from tempfile import TemporaryDirectory

from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads, uint
from .chain_history import MAX_BLOCKS
from .chain_rpc import ReplayTransport, RpcTransport
from .independent_wire import require
from . import object_dossier as base
from . import object_dossier_native as native
from . import object_dossier_native_assembly as assembly
from .token_fixture import read as read_fixture

PLAN = "STREAM_MUSEUM_NATIVE_DOSSIER_CAPTURE_PLAN_V1"
RESULT = "STREAM_MUSEUM_NATIVE_DOSSIER_CAPTURE_RESULT_V1"
CLAIMS = {"readOnlyRpc": True, "sameBlockNativeSourcesReplayed": True,
          "originalBaseRetained": True, "sourceRevisionAuthenticated": False,
          "actualNativeCaptureAcceptance": False, "globalApplicableHostsComplete": False,
          "fullObjectDossierConformance": False, "consensusProof": False}
QUALIFICATION = ("Caller-admitted RPC consistency evidence at one externally pinned block. "
    "The source revision is declared provenance, not a build-equivalence proof. "
    "Unsupported registered versions, alternate registries and unregistered hosts remain unresolved. "
    "No chain launch, native deployment, publication, genuine-capture acceptance or full dossier claim.")


def _read_plan(raw, expected_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST
            and keccak256(raw) == expected_hash, "capture plan external commitment/bound differs")
    plan = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(plan) is dict and set(plan) == {"profile", "version", "disclosure",
        "baseManifestHash", "sourceRevision", "nativeInputManifestSha256", "sources"}
        and plan["profile"] == PLAN and plan["version"] == "1" and plan["disclosure"] == "public",
        "capture plan closed shape/disclosure")
    for key, size in (("sourceRevision", 40), ("nativeInputManifestSha256", 64)):
        require(type(plan[key]) is str and re.fullmatch("[0-9a-f]{" + str(size) + "}", plan[key]) is not None,
                "capture plan source provenance pin")
    require(type(plan["sources"]) is list and 6 <= len(plan["sources"]) <= native.MAX_SOURCES,
            "capture plan requires six or more bounded sources")
    ids = []
    for row in plan["sources"]:
        require(type(row) is dict and set(row) == {"id", "kind", "anchor"}
                and type(row["id"]) is str and re.fullmatch(r"[A-Za-z0-9_-]{1,128}", row["id"]) is not None
                and row["kind"] in native.KINDS and type(row["anchor"]) is dict,
                "capture plan source shape/kind")
        ids.append(row["id"])
    require(ids == sorted(set(ids)), "capture plan source ids must be sorted/unique")
    return plan


def _reference(base_files, expected_hash):
    checked = base.verify(base_files, expected_hash)
    manifest = loads(checked.manifest, maximum=MAX_MANIFEST, canonical=True)
    retained = {p: base_files["source/retained/" + p] for p in base.RETENTION_NAMES}
    with TemporaryDirectory(prefix="stream-native-capture-reference-") as temporary:
        path = Path(temporary) / "retained"
        write_tree(retained, path)
        originals, _ = read_fixture(path, manifest["source"]["retainedManifestHash"])
    evidence = loads(originals["deployment-evidence.json"], maximum=MAX_BYTES, canonical=True)
    return (native.reference_from_originals(manifest["sourceState"], originals),
            evidence["nativeInputManifestSha256"])


def _preflight(plan, reference, native_manifest_sha256):
    """Validate every anchor before a transport can make its first request."""
    require(plan["nativeInputManifestSha256"] == native_manifest_sha256,
            "capture plan original native-input manifest differs")
    native.validate_reference(reference)
    require(uint(reference["sourceState"]["blockNumber"]) < MAX_BLOCKS,
            "capture source block exceeds complete-history bound")
    empty = dumps({"version": 1, "calls": []})
    classes = native._classes()
    shared = {p["address"]: p["runtimeHash"] for p in reference["sourceAnchor"]["runtimePins"]}
    keys, kinds, independent = set(), set(), {}
    for row in plan["sources"]:
        source = classes[row["kind"]](dumps(row["anchor"]),
            ReplayTransport(empty, keccak256(empty)), provenance="trusted_rpc")
        native._join_anchor(row["kind"], source.a, reference, shared)
        key = native._source_key(row["kind"], source.a)
        require(key not in keys, "capture plan duplicate logical source")
        keys.add(key); kinds.add(row["kind"])
        if row["kind"] == "independent":
            independent.setdefault(source.a["host"], set()).add(source.a["scopeKey"])
    require(kinds == set(native.KINDS), "capture plan missing required reader kind")
    require(all(scopes == {"0", reference["sourceState"]["collectionId"]} for scopes in independent.values()),
            "capture plan requires both independent scopes for each host")


def _capture_sources(plan, reference, transport):
    require(type(transport) is RpcTransport, "capture requires explicit read-only RPC transport")
    files, rows, size = {}, [], 0
    classes = native._classes()
    for item in plan["sources"]:
        raw = dumps(item["anchor"])
        source = classes[item["kind"]](raw, transport, provenance="trusted_rpc")
        snapshot = source.snapshot()
        transcript = source.transcript()
        row = {"id": item["id"], "kind": item["kind"], "provenance": "trusted_rpc"}
        for label, content in (("anchor", raw), ("snapshot", snapshot), ("transcript", transcript)):
            path = item["id"] + "/" + label + ".json"
            size += len(content)
            require(size <= MAX_BYTES, "capture source aggregate bound")
            files[path] = content
            row[label + "Path"] = path
            row[label + "Hash"] = keccak256(content)
        rows.append(row)
    envelope = dumps({"profile": native.PROFILE, "version": "1", "disclosure": "public",
                      "sourceState": reference["sourceState"], "sources": rows})
    return envelope, keccak256(envelope), files


def _complete_plan_sources(plan, result):
    """The bounded recipe must cover every supported host seen in its roster."""
    require(all(row["status"] not in ("missing_source", "synthetic_only")
                for row in result.report["scopeCoverage"]),
            "capture plan omits a supported registered host/scope")
    files = dict(result.files)
    envelope = loads(files["native/inputs.json"], maximum=MAX_MANIFEST, canonical=True)
    expected = [(row["id"], row["kind"], dumps(row["anchor"])) for row in plan["sources"]]
    actual = [(row["id"], row["kind"], files["native/data/" + row["anchorPath"]])
              for row in envelope["sources"]]
    require(expected == actual and all(row["provenance"] == "trusted_rpc" for row in envelope["sources"]),
            "capture assembly source plan/provenance differs")


def _result(plan, plan_hash, result):
    manifest = loads(result.manifest, maximum=MAX_MANIFEST, canonical=True)
    return dumps({"profile": RESULT, "version": "1", "planHash": plan_hash,
        "baseManifestHash": plan["baseManifestHash"], "sourceRevision": plan["sourceRevision"],
        "nativeInputManifestSha256": plan["nativeInputManifestSha256"],
        "nativeInputsHash": manifest["nativeInputsHash"], "assemblyManifestHash": result.manifest_hash,
        "sourceCount": str(len(plan["sources"])), "claims": CLAIMS, "qualification": QUALIFICATION})


def capture(plan_raw, plan_hash, base_files, transport):
    plan = _read_plan(plan_raw, plan_hash)
    reference, native_manifest = _reference(base_files, plan["baseManifestHash"])
    _preflight(plan, reference, native_manifest)
    inputs = _capture_sources(plan, reference, transport)
    # This concrete assembler independently replays every captured transcript.
    result = assembly.assemble(base_files, plan["baseManifestHash"], inputs)
    _complete_plan_sources(plan, result)
    output = {"assembly/" + p: b for p, b in result.files}
    output["plan.json"] = plan_raw
    output["result.json"] = _result(plan, plan_hash, result)
    base._bounded(output)
    return output


def verify(files, expected_hash):
    """Offline verification; neither RPC nor retained implementation files execute."""
    files = dict(files); base._bounded(files)
    raw = files.get("result.json", b"")
    require(keccak256(raw) == expected_hash, "capture result external commitment differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"profile", "version", "planHash", "baseManifestHash",
        "sourceRevision", "nativeInputManifestSha256", "nativeInputsHash", "assemblyManifestHash",
        "sourceCount", "claims", "qualification"}, "capture result closed shape")
    require("plan.json" in files and all(p in ("plan.json", "result.json") or p.startswith("assembly/") for p in files),
            "capture output inventory differs")
    plan = _read_plan(files["plan.json"], value["planHash"])
    result = assembly.verify({p[9:]: b for p, b in files.items() if p.startswith("assembly/")},
                             value["assemblyManifestHash"])
    base_files = {p[5:]: b for p, b in result.files if p.startswith("base/")}
    reference, native_manifest = _reference(base_files, plan["baseManifestHash"])
    _preflight(plan, reference, native_manifest)
    _complete_plan_sources(plan, result)
    require(raw == _result(plan, value["planHash"], result), "capture result reconstruction differs")
    return value


def _bounded_read(path):
    require(path.is_file() and not path.is_symlink()
            and not (hasattr(path, "is_junction") and path.is_junction()), "capture plan must be a regular file")
    with path.open("rb") as handle:
        raw = handle.read(MAX_MANIFEST + 1)
    require(len(raw) <= MAX_MANIFEST, "capture plan file bound")
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("check-plan", "capture"):
        command = commands.add_parser(name)
        command.add_argument("--plan", type=Path, required=True)
        command.add_argument("--plan-hash", required=True)
        command.add_argument("--base", type=Path, required=True)
        if name == "capture":
            command.add_argument("--rpc-env", required=True)
            command.add_argument("--output", type=Path, required=True)
    replay = commands.add_parser("verify")
    replay.add_argument("directory", type=Path)
    replay.add_argument("--result-hash", required=True)
    args = parser.parse_args()
    try:
        if args.command == "verify":
            result = verify(read_tree(args.directory), args.result_hash)
        else:
            raw = _bounded_read(args.plan)
            plan = _read_plan(raw, args.plan_hash)
            base_files = read_tree(args.base)
            if args.command == "check-plan":
                reference, native_manifest = _reference(base_files, plan["baseManifestHash"])
                _preflight(plan, reference, native_manifest)
                result = {"planHash": args.plan_hash, "sourceCount": str(len(plan["sources"])),
                          "offlinePlanValid": True, "rpcAvailabilityChecked": False}
            else:
                require(not args.output.exists(), "capture output already exists")
                endpoint = os.environ.get(args.rpc_env)
                require(endpoint is not None, "capture RPC environment variable is absent")
                files = capture(raw, args.plan_hash, base_files, RpcTransport(endpoint))
                result_hash = keccak256(files["result.json"])
                verify(files, result_hash)
                write_tree(files, args.output)
                result = loads(files["result.json"], canonical=True) | {"resultHash": result_hash}
    except (MuseumError, OSError, KeyError, TypeError, ValueError):
        # Endpoint credentials and remote payloads must never enter error output.
        parser.exit(1, "Native capture failed; inspect the pinned plan, source prerequisites and local paths.\n")
    print(dumps(result).decode())


if __name__ == "__main__":
    main()
