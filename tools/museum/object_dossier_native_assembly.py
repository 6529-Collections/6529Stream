"""Versioned partial assembly with replayed native source joins; V1 stays unchanged."""
from pathlib import Path
from tempfile import TemporaryDirectory

from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, read_tree, write_tree
from .canonical import dumps, keccak256, loads
from .independent_wire import require
from . import object_dossier as base
from . import object_dossier_native as native
from .token_fixture import read as read_fixture

MODE = "object_dossier_native_partial_assembly"
NAME = "STREAM_MUSEUM_OBJECT_DOSSIER_ASSEMBLY_V2"
CLAIMS = {"actualTokenReplay": True, "originalBaseAssemblyRetained": True,
          "typedNativeSourcesReplayed": True, "syntheticEvidencePromoted": False,
          "globalApplicableHostsComplete": False, "fullObjectDossierConformance": False,
          "completeCanonicalData": False, "actualNativeCaptureAcceptance": False,
          "coveringProtocolEventArchive": False, "legalTitleProven": False,
          "preservedToolArchive": False, "consensusProof": False, "networkFetch": False}
SOURCES = ("object_dossier_native.py", "object_dossier_native_assembly.py", "chain_history.py",
           "owner_catalog_source.py", "independent_catalog_source.py", "ownership_source.py",
           "metadata_catalog_source.py", "dossier_hosts_source.py")


def _tools(snapshot=None):
    names = {"tool/" + name + ".txt" for name in SOURCES}
    if snapshot is None:
        snapshot = {"tool/" + name + ".txt": Path(__file__).with_name(name).read_bytes().replace(b"\r\n", b"\n")
                    for name in SOURCES}
    require(type(snapshot) is dict and set(snapshot) == names, "native assembly inert source set differs")
    for raw in snapshot.values():
        require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST and b"\r" not in raw,
                "native assembly inert source bounds/encoding")
        raw.decode("utf-8")
    return snapshot | {"tool/source-index.json": dumps({"mode": "inert_implementation_provenance",
        "completeRuntimeArchive": False, "files": [base._ref(p, b) for p, b in sorted(snapshot.items())]})}


def assemble(base_files, base_hash, inputs, *, tool_snapshot=None):
    """Join new typed inputs to an unchanged independently verified V1 assembly."""
    base_files = dict(base_files)
    require(type(inputs) is tuple and len(inputs) == 3, "native assembly inputs tuple required")
    raw, input_hash, native_files = inputs
    checked = base.verify(base_files, base_hash)
    base_manifest = loads(checked.manifest, maximum=MAX_MANIFEST, canonical=True)
    # Extract original anchor/deployment pins only from the verified retained fixture.
    retained = {name: base_files["source/retained/" + name] for name in base.RETENTION_NAMES}
    with TemporaryDirectory(prefix="stream-native-reference-") as temporary:
        path = Path(temporary) / "retained"
        write_tree(retained, path)
        originals, _ = read_fixture(path, base_manifest["source"]["retainedManifestHash"])
    reference = native.reference_from_originals(base_manifest["sourceState"], originals)
    report = native.admit(raw, input_hash, native_files, reference)
    payloads = {"base/" + p: b for p, b in base_files.items()}
    payloads.update({"native/data/" + p: b for p, b in native_files.items()})
    payloads.update(_tools(tool_snapshot))
    payloads["native/inputs.json"] = raw
    payloads["native/joins.json"] = report
    payloads["definitions/native-joins-profile.json"] = native.PROFILE_BYTES
    base._bounded(payloads)
    manifest = dumps({"mode": MODE, "name": NAME, "version": "2", "target": "OBJECT_DOSSIER_V1",
        "sourceState": reference["sourceState"], "baseManifestHash": base_hash,
        "nativeInputsHash": input_hash, "nativeJoinProfileHash": native.PROFILE_HASH,
        "nativeJoinReport": base._ref("native/joins.json", report),
        "baseRequirementReport": base._ref("base/inventory/report.json", base_files["inventory/report.json"]),
        "files": [base._ref(p, b) for p, b in sorted(payloads.items())],
        "claims": CLAIMS, "qualification": native.QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "native assembly manifest bound")
    payloads["manifest.json"] = manifest
    base._bounded(payloads)
    return base.Assembly(tuple(sorted(payloads.items())), manifest, loads(report, maximum=MAX_BYTES, canonical=True))


def verify(files, expected_hash):
    files = dict(files); base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "native assembly external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "name", "version", "target", "sourceState",
        "baseManifestHash", "nativeInputsHash", "nativeJoinProfileHash", "nativeJoinReport", "baseRequirementReport",
        "files", "claims", "qualification"} and value["mode"] == MODE and value["name"] == NAME
        and value["version"] == "2" and value["target"] == "OBJECT_DOSSIER_V1"
        and value["nativeJoinProfileHash"] == native.PROFILE_HASH and value["claims"] == CLAIMS
        and value["qualification"] == native.QUALIFICATION, "native assembly closed manifest differs")
    payloads = {p: b for p, b in files.items() if p != "manifest.json"}
    require(value["files"] == [base._ref(p, b) for p, b in sorted(payloads.items())],
            "native assembly original file commitments differ")
    required = {"native/inputs.json", "native/joins.json", "base/manifest.json", "base/inventory/report.json",
                "definitions/native-joins-profile.json", "tool/source-index.json"}
    required.update("tool/" + name + ".txt" for name in SOURCES)
    required.update("base/source/retained/" + name for name in base.RETENTION_NAMES)
    require(required <= files.keys(), "native assembly required original file missing")
    base_files = {p[len("base/"):]: b for p, b in files.items() if p.startswith("base/")}
    native_files = {p[len("native/data/"):]: b for p, b in files.items() if p.startswith("native/data/")}
    snapshot = {"tool/" + name + ".txt": files["tool/" + name + ".txt"] for name in SOURCES}
    rebuilt = assemble(base_files, value["baseManifestHash"],
        (files["native/inputs.json"], value["nativeInputsHash"], native_files), tool_snapshot=snapshot)
    require(dict(rebuilt.files) == files, "native assembly reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    definition = commands.add_parser("definitions")
    definition.add_argument("--output", type=Path, required=True)
    definition.add_argument("--check", action="store_true")
    build = commands.add_parser("build")
    build.add_argument("--base", type=Path, required=True)
    build.add_argument("--base-hash", required=True)
    build.add_argument("--native", type=Path, required=True,
                       help="directory with inputs.json and data/ source files")
    build.add_argument("--native-hash", required=True)
    build.add_argument("--output", type=Path, required=True)
    check = commands.add_parser("verify")
    check.add_argument("directory", type=Path)
    check.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "definitions":
        print(native.definitions(args.output, check=args.check))
        return
    if args.command == "verify":
        result = verify(read_tree(args.directory), args.manifest_hash)
    else:
        native_tree = read_tree(args.native)
        require("inputs.json" in native_tree and all(p == "inputs.json" or p.startswith("data/") for p in native_tree),
                "native input directory shape")
        files = {p[5:]: b for p, b in native_tree.items() if p.startswith("data/")}
        result = assemble(read_tree(args.base), args.base_hash,
                          (native_tree["inputs.json"], args.native_hash, files))
        write_tree(dict(result.files), args.output)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
                 "fullObjectDossierConformance": False}).decode())


if __name__ == "__main__":
    main()
