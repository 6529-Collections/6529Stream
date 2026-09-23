"""Assemble replayable object-dossier diagnostics; supplied bytes never prove completeness.

This first adapter consumes the exact actual-token capture. Its evidence covers
identity and a bounded semantic selection. No complete OBJECT_DOSSIER_V1 emitter
is exposed until canonical native adapters cover the remaining requirements.
"""
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, _paths, read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require
from .object_dossier_components import SCHEMA_BYTES as COMPONENT_SCHEMA_BYTES, admit
from .object_dossier_inventory import EvidenceRef, REQUIREMENTS_BYTES, assess
from .token_fixture import read as read_fixture, rebuild as replay_fixture

MODE = "object_dossier_partial_assembly"
NAME = "STREAM_MUSEUM_OBJECT_DOSSIER_ASSEMBLY_V1"
QUALIFICATION = (
    "Replayable partial diagnostics for OBJECT_DOSSIER_V1. Complete canonical input "
    "adapters, authoritative render inventory, complete record lanes and provenance "
    "remain required. Supplied component commitments establish byte identity only. "
    "No full dossier, registry, archival, consensus or institutional acceptance.")
SOURCE_NAMES = ("object_dossier.py", "object_dossier_inventory.py", "object_dossier_components.py")
RETENTION_NAMES = ("manifest.json", "inputs.json.gz")


def _ref(path, raw):
    return {"path": path, "bytes": str(len(raw)), "sha256": "0x" + sha256(raw).hexdigest(),
            "keccak256": keccak256(raw)}


def schema_bytes():
    from .object_dossier_components import SOURCE_STATE_SCHEMA
    from .schemas import HEX32, obj
    reference = obj({"path": {"type": "string"}, "bytes": {"type": "string", "pattern": "^(0|[1-9][0-9]*)$"},
                     "sha256": HEX32, "keccak256": HEX32})
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:6529stream:schema:" + NAME, "title": NAME,
        **obj({"mode": {"const": MODE}, "version": {"const": "1"},
            "target": {"const": "OBJECT_DOSSIER_V1"}, "sourceState": SOURCE_STATE_SCHEMA,
            "source": obj({key: HEX32 for key in ("retainedManifestHash", "exportManifestHash",
                "scopedBagManifestHash", "ocflInventoryHash")}),
            "suppliedComponentsHash": {"oneOf": [HEX32, {"type": "null"}]},
            "inventory": reference, "schema": reference, "toolSourceIndex": reference,
            "files": {"type": "array", "maxItems": MAX_FILES, "items": reference},
            "claims": obj({key: {"const": value} for key, value in CLAIMS.items()}),
            "qualification": {"const": QUALIFICATION}})})


CLAIMS = {"actualTokenReplay": True, "originalSourceBytesRetained": True,
    "fullObjectDossierConformance": False, "completeCanonicalData": False,
    "authoritativeRenderInventory": False, "completeLaneHistory": False,
    "completeOwnershipHistory": False, "profileRegistered": False,
    "preservedToolArchive": False, "consensusProof": False,
    "institutionalAcceptance": False, "networkFetch": False}


@dataclass(frozen=True)
class Assembly:
    files: tuple[tuple[str, bytes], ...]
    manifest: bytes
    report: dict

    @property
    def manifest_hash(self):
        return keccak256(self.manifest)


def _bounded(files):
    require(type(files) is dict and all(type(raw) is bytes for raw in files.values()),
        "assembly requires exact file bytes")
    _paths(files)
    require(len(files) <= MAX_FILES and sum(map(len, files.values())) <= MAX_BYTES,
        "assembly aggregate bound")


def _validate_manifest(raw):
    """The multi-file manifest has a larger explicit bound than record payloads."""
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    schema = loads(schema_bytes(), maximum=MAX_MANIFEST, canonical=True)
    try:
        Draft202012Validator(schema).validate(value)
    except ValidationError as exc:
        raise MuseumError("assembly closed manifest schema differs at " + exc.json_path) from exc
    return value


def _tool_snapshot(snapshot=None):
    names = {"tool/" + name + ".txt" for name in SOURCE_NAMES}
    if snapshot is None:
        snapshot = {"tool/" + name + ".txt": Path(__file__).with_name(name).read_bytes().replace(b"\r\n", b"\n")
                    for name in SOURCE_NAMES}
    require(type(snapshot) is dict and set(snapshot) == names, "assembly tool snapshot set differs")
    for raw in snapshot.values():
        require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST and b"\r" not in raw,
            "assembly tool snapshot byte bound/encoding")
        raw.decode("utf-8")
    result = dict(snapshot)
    result["tool/source-index.json"] = dumps({"mode": "inert_implementation_provenance",
        "completeRuntimeArchive": False, "files": [_ref(path, raw) for path, raw in sorted(snapshot.items())]})
    return result


def _replay(retained, expected_hash):
    require(set(retained) == set(RETENTION_NAMES), "assembly exact retained fixture files")
    _bounded(retained)
    with TemporaryDirectory(prefix="stream-object-source-") as temporary:
        directory = Path(temporary) / "retained"
        write_tree(retained, directory)
        originals, original_manifest = read_fixture(directory, expected_hash)
    export, bag, ocfl, replay = replay_fixture(originals)
    from .semantic_export import MANIFEST_PATH
    semantic = loads(dict(export.files)[MANIFEST_PATH], maximum=MAX_MANIFEST, canonical=True)["sourceState"]
    evidence = loads(originals["deployment-evidence.json"], maximum=MAX_BYTES, canonical=True)
    mint = evidence["tokenMint"]
    state = {key: semantic[key] for key in ("chainId", "core", "collectionId", "tokenId",
                                         "blockNumber", "blockHash", "canonicalCitation")}
    state.update(collectionSerial=mint["collectionSerial"], subjectId=replay["subjectId"])
    require(export.manifest_hash == original_manifest["exportManifestHash"]
        and bag.manifest_hash == original_manifest["bagManifestHash"]
        and ocfl.inventory_hash == original_manifest["ocflInventoryHash"],
        "assembly retained source result differs")
    return state, originals, export, bag, ocfl


def assemble(retained, expected_hash, *, components=None, tool_snapshot=None):
    """Replay exact token evidence, retain all bytes and report the fixed denominator.

    components is None or (original_envelope_bytes, external_hash, payload_files).
    There is deliberately no input for claimed verification, absence or work mode.
    """
    state, originals, export, bag, ocfl = _replay(retained, expected_hash)
    payloads = {"source/retained/" + name: raw for name, raw in retained.items()}
    payloads.update({"source/scoped-bag/" + name: raw for name, raw in bag.files})
    payloads.update(_tool_snapshot(tool_snapshot))
    supplied, components_hash = {}, None
    if components is not None:
        require(type(components) is tuple and len(components) == 3, "assembly components input shape")
        raw, components_hash, files = components
        _, supplied = admit(raw, components_hash, files, state)
        payloads["supplied/components.json"] = raw
        payloads.update({"supplied/data/" + name: value for name, value in files.items()})
    # Identity is the sole complete adopted requirement proven by this source.
    # The semantic package and record lane are verified within their explicit
    # narrower selection; neither proves the complete dossier-wide requirement.
    source_ref = "source/retained/inputs.json.gz"
    verified = {"identity": (EvidenceRef("package:" + source_ref, keccak256(retained["inputs.json.gz"]),
                                        "tokenSourceBlockViews/tokenCollectionIdentity"),)}
    # A supplied identity copy cannot replace or duplicate the actual Core join.
    require("identity" not in supplied, "supplied identity cannot replace verified Core identity")
    report = assess("unknown", verified, {key: tuple(values) for key, values in supplied.items()})
    require(report["complete"] is False, "partial adapter cannot promote full inventory")
    report["partialEvidence"] = [
        {"kind": "scoped_semantic_package", "hash": export.manifest_hash,
         "scope": "Exact selected token subject and one declared source lane; complete adopted semantic scope unproven."},
        {"kind": "selected_media", "hash": keccak256(originals["test-image.png"]),
         "scope": "Exact selected PNG and actual token metadata; authoritative render inventory unproven."},
        {"kind": "paid_mint", "hash": keccak256(originals["deployment-evidence.json"]),
         "scope": "Actual paid mint and Core Transfer hop; complete mint-to-anchor event-history snapshot unproven."}]
    report["qualification"] = QUALIFICATION
    payloads["inventory/requirements.json"] = REQUIREMENTS_BYTES
    payloads["inventory/report.json"] = dumps(report)
    payloads["definitions/assembly-schema.json"] = schema_bytes()
    payloads["definitions/components-schema.json"] = COMPONENT_SCHEMA_BYTES
    _bounded(payloads)
    manifest = {"mode": MODE, "version": "1", "target": "OBJECT_DOSSIER_V1", "sourceState": state,
        "source": {"retainedManifestHash": expected_hash, "exportManifestHash": export.manifest_hash,
            "scopedBagManifestHash": bag.manifest_hash, "ocflInventoryHash": ocfl.inventory_hash},
        "suppliedComponentsHash": components_hash,
        "inventory": _ref("inventory/report.json", payloads["inventory/report.json"]),
        "schema": _ref("definitions/assembly-schema.json", payloads["definitions/assembly-schema.json"]),
        "toolSourceIndex": _ref("tool/source-index.json", payloads["tool/source-index.json"]),
        "files": [_ref(path, raw) for path, raw in sorted(payloads.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION}
    raw = dumps(manifest)
    require(len(raw) <= MAX_MANIFEST, "assembly manifest bound")
    _validate_manifest(raw)
    payloads["manifest.json"] = raw
    _bounded(payloads)
    return Assembly(tuple(sorted(payloads.items())), raw, report)


def verify(files, expected_hash):
    """Rebuild from retained original inputs; never execute the inert source snapshot."""
    files = dict(files); _bounded(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "assembly external manifest pin differs")
    require(len(raw) <= MAX_MANIFEST, "assembly manifest bound")
    value = _validate_manifest(raw)
    payloads = {path: content for path, content in files.items() if path != "manifest.json"}
    require(value["files"] == [_ref(path, content) for path, content in sorted(payloads.items())],
        "assembly original file commitments differ")
    retained = {name: files["source/retained/" + name] for name in RETENTION_NAMES}
    components = None
    if value["suppliedComponentsHash"] is not None:
        components = (files["supplied/components.json"], value["suppliedComponentsHash"],
            {path[len("supplied/data/"):]: content for path, content in files.items() if path.startswith("supplied/data/")})
    snapshot = {"tool/" + name + ".txt": files["tool/" + name + ".txt"] for name in SOURCE_NAMES}
    rebuilt = assemble(retained, value["source"]["retainedManifestHash"],
                       components=components, tool_snapshot=snapshot)
    require(dict(rebuilt.files) == files, "assembly source reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    definition = commands.add_parser("definitions"); definition.add_argument("--check", action="store_true")
    for command in ("inspect", "build"):
        sub = commands.add_parser(command); sub.add_argument("fixture", type=Path)
        sub.add_argument("--fixture-hash", required=True)
        sub.add_argument("--components", type=Path); sub.add_argument("--components-hash")
        if command == "build": sub.add_argument("output", type=Path)
    check = commands.add_parser("verify"); check.add_argument("directory", type=Path)
    check.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    try:
        if args.command == "definitions":
            path = Path(__file__).resolve().parents[2] / "schemas/museum/object-dossier/assembly-schema.json"
            raw = schema_bytes()
            if args.check: require(path.read_bytes() == raw, "assembly schema differs")
            else: path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
            return
        if args.command == "verify": result = verify(read_tree(args.directory), args.manifest_hash)
        else:
            require((args.components is None) == (args.components_hash is None), "component directory and external hash must be paired")
            component_input = None
            if args.components is not None:
                component_files = read_tree(args.components)
                raw = component_files.pop("components.json")
                require(all(path.startswith("data/") for path in component_files), "component directory exact layout")
                component_input = (raw, args.components_hash, {path[5:]: value for path, value in component_files.items()})
            result = assemble(read_tree(args.fixture), args.fixture_hash, components=component_input)
            if args.command == "build": write_tree(result.files, args.output)
        print(dumps({"manifestHash": result.manifest_hash, "inventory": result.report,
                     "claims": CLAIMS}).decode("utf-8"))
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(1, str(exc) + "\n")


if __name__ == "__main__": main()
