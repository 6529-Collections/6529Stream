"""Offline scoped semantic-evidence dossiers from authenticated V3 export packages."""
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory

from .bagit import MAX_BYTES, MAX_MANIFEST, ZERO, read_tree, verify_bag_files, write_tree
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .dossier_bagit import INPUT_MODE, PROFILE_BYTES, PROFILE_HASH, external_identifier
from .dossier_bagit import build_bag as build_scoped_bag
from .independent_wire import require
from .review import _validate
from .schemas import HEX32, obj, ref
from .semantic_export import MANIFEST_PATH, document, verify_export
from .typed_authority_profile import NAMES, SCHEMAS

NAME = "STREAM_MUSEUM_SEMANTIC_EVIDENCE_DOSSIER_V1"
BUNDLE = "MUSEUM_SEMANTIC_EVIDENCE_DOSSIER_V1"
MANIFEST = "dossier/manifest.json"
SCHEMA_PATH = "dossier/schema.json"
CLAIMS = {"authenticatedExportReplayed": True, "selectedMediaBytesVerified": True,
    "selectedMediaEmbedded": True, "originalExportBytesPreserved": True,
    "fullObjectDossierConformance": False, "authoritativeRenderInventory": False,
    "formatIdentified": False, "priorFixityPerformed": False, "mediaArchiveAuthority": False,
    "publisherAuthenticated": False, "qualifiedHumanReview": False,
    "consensusFinality": False, "institutionalIngest": False, "networkFetch": False}
QUALIFICATION = ("Complete embedding of this bounded public selection only. Source records remain "
    "externally admitted trusted-RPC evidence. Media facts are signer-attributed assertions plus "
    "present local byte agreement, not publisher, institutional, format-identification, historical "
    "fixity or archival-availability proof. This profile does not establish the complete token "
    "render inventory or OBJECT_DOSSIER_V1 conformance.")
_EXPORT_SCHEMA = loads(SCHEMAS[NAMES[2]], maximum=524288, canonical=True)
SCHEMA_BYTES = dumps({"$schema": _EXPORT_SCHEMA["$schema"], "$id": "urn:6529stream:schema:" + NAME,
    "title": NAME, "$defs": _EXPORT_SCHEMA["$defs"],
    **obj({"mode": {"const": "scoped_semantic_evidence_dossier"}, "version": {"const": "1"},
        "profileHash": {"const": PROFILE_HASH}, "source": obj({"prefix": {"const": "semantic"}, "manifestHash": HEX32}),
        "scope": ref("sourceState"), "mediaIndex": ref("document"),
        "archivePublication": {"oneOf": [{"type": "null"}, obj({"evidence": ref("document"), "report": ref("document")})]},
        "claims": obj({key: {"const": value} for key, value in CLAIMS.items()}),
        "qualification": {"const": QUALIFICATION}})})


def _source_snapshot():
    """Normalized implementation text, not a complete executable/runtime archive."""
    files = {}
    for name in ("dossier.py", "dossier_media.py", "dossier_bagit.py"):
        raw = Path(__file__).with_name(name).read_bytes().replace(b"\r\n", b"\n")
        raw.decode("utf-8")
        files["tool/" + name + ".txt"] = raw
    files["tool/source-index.json"] = _source_index(files)
    return _validate_source_snapshot(files)


def _source_index(files):
    return dumps({"normalization": "UTF-8 with LF line endings", "completeRuntimeArchive": False,
        "files": [{"path": name, "hash": keccak256(raw)} for name, raw in sorted(files.items())]})


def _validate_source_snapshot(files):
    """Validate inert reported source bytes; never assert they were executed by a producer."""
    files = dict(files)
    names = {"tool/" + name + ".txt" for name in ("dossier.py", "dossier_media.py", "dossier_bagit.py")}
    require(set(files) == names | {"tool/source-index.json"}, "dossier source snapshot file set differs")
    for name in names:
        raw = files[name]
        require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST and b"\r" not in raw,
            "dossier source snapshot must be bounded LF text")
        raw.decode("utf-8")
    index = _source_index({name: files[name] for name in names})
    require(files["tool/source-index.json"] == index, "dossier source snapshot index differs")
    return files, keccak256(index)


def _archive(export, raw, pin):
    require((raw is None) == (pin is None), "archive evidence bytes and external pin must be paired")
    if raw is None: return {}, None
    from .archive_evidence import verify_evidence
    originals = dict(export.files)
    report = verify_evidence(raw, pin, originals[MANIFEST_PATH],
        source_anchor_bytes=originals["input/source/inputs/anchor.json"])
    files = {"publication/evidence.json": raw, "publication/report.json": dumps(report)}
    return files, {"evidence": document("publication/evidence.json", raw),
        "report": document("publication/report.json", files["publication/report.json"])}


def _assemble(export, supplied, *, bagging_date, predecessor=ZERO, archive_raw=None, archive_hash=None, tool_snapshot=None):
    """Internal: export must already be authenticated by verify_export."""
    from .dossier_media import requirements, validate_media
    originals = dict(export.files)
    source = loads(originals[MANIFEST_PATH], canonical=True)["sourceState"]
    media = requirements(originals)
    payloads = {"semantic/" + name: raw for name, raw in originals.items()}
    payloads["semantic/manifest.json"] = export.manifest
    payloads.update(validate_media(media, supplied))
    payloads["dossier/media-index.json"] = dumps(media)
    publication, publication_ref = _archive(export, archive_raw, archive_hash)
    payloads.update(publication)
    tool, tool_hash = _source_snapshot() if tool_snapshot is None else _validate_source_snapshot(tool_snapshot)
    payloads.update(tool)
    payloads["dossier/profile.json"] = PROFILE_BYTES
    payloads[SCHEMA_PATH] = SCHEMA_BYTES
    manifest = dumps({"mode": "scoped_semantic_evidence_dossier", "version": "1", "profileHash": PROFILE_HASH,
        "source": {"prefix": "semantic", "manifestHash": export.manifest_hash}, "scope": source,
        "mediaIndex": document("dossier/media-index.json", payloads["dossier/media-index.json"]),
        "archivePublication": publication_ref, "claims": CLAIMS, "qualification": QUALIFICATION})
    _validate(SCHEMA_BYTES, manifest); payloads[MANIFEST] = manifest
    critical = {row["path"] for row in media if row["renderCritical"]}
    description = {"mode": INPUT_MODE, "version": "1", "bundleKind": BUNDLE,
        "sourceMode": "externally_admitted_records", "disclosure": "public", "scope": source,
        "externalIdentifier": external_identifier(source), "baggingDate": bagging_date,
        "bundleManifest": {"path": MANIFEST, "hash": keccak256(manifest)},
        "schema": {"path": SCHEMA_PATH, "id": schema_id(NAME), "hash": keccak256(SCHEMA_BYTES)},
        "recordChainHeads": sorted([{"scope": row["host"] + ":" + row["recordType"] + ":" + row["subjectId"],
            "head": row["recordChainHash"]} for row in source["recordHeads"]], key=lambda row: row["scope"]),
        "tool": {"name": "tools.museum.dossier", "version": "1", "sourceHash": tool_hash},
        "predecessor": predecessor,
        "payloads": [{"path": name, "bytes": str(len(raw)), "sha256": "0x" + sha256(raw).hexdigest(),
            "keccak256": keccak256(raw), "renderCritical": name in critical, "delivery": {"kind": "embedded"}}
            for name, raw in sorted(payloads.items())],
        "semanticPackages": [{"prefix": "semantic", "manifestHash": export.manifest_hash}]}
    return build_scoped_bag(dumps(description), payloads)


def inspect_export(directory, expected_manifest_hash, supplied=None):
    from .dossier_media import requirements, validate_media
    export = verify_export(directory, expected_manifest_hash)
    originals = dict(export.files); media = requirements(originals)
    supplied = {} if supplied is None else dict(supplied)
    names = {row["sha256"] + ".bin" for row in media}
    require(set(supplied) <= names, "unrequested local media supply")
    present = [row for row in media if row["sha256"] + ".bin" in supplied]
    validate_media(present, supplied)
    return {"mode": "scoped_dossier_inspection", "sourceManifestHash": export.manifest_hash,
        "scope": loads(originals[MANIFEST_PATH], canonical=True)["sourceState"], "media": media,
        "missingMedia": sorted(names - set(supplied)), "readyToPackage": names <= set(supplied),
        "qualification": QUALIFICATION}


def build_dossier(directory, expected_manifest_hash, supplied, *, bagging_date,
                  predecessor=ZERO, archive_raw=None, archive_hash=None):
    return _assemble(verify_export(directory, expected_manifest_hash), supplied, bagging_date=bagging_date,
        predecessor=predecessor, archive_raw=archive_raw, archive_hash=archive_hash)


def verify_payload_directory(description, directory):
    """Recompute all payloads and descriptor fields from the original authenticated export."""
    from .dossier_bagit import description as validate_description
    validate_description(dumps(description))
    payloads = read_tree(directory)
    manifest = loads(payloads[MANIFEST], maximum=MAX_MANIFEST, canonical=True)
    _validate(SCHEMA_BYTES, dumps(manifest))
    export = verify_export(Path(directory) / "semantic", manifest["source"]["manifestHash"])
    publication = manifest["archivePublication"]
    raw = None if publication is None else payloads["publication/evidence.json"]
    pin = None if publication is None else publication["evidence"]["contentHash"]["digest"]
    supplied = {name[6:]: content for name, content in payloads.items() if name.startswith("media/")}
    rebuilt = _assemble(export, supplied, bagging_date=description["baggingDate"],
        predecessor=description["predecessor"], archive_raw=raw, archive_hash=pin,
        tool_snapshot={name: raw for name, raw in payloads.items() if name.startswith("tool/")})
    expected = loads(rebuilt.manifest, maximum=MAX_MANIFEST, canonical=True)["input"]
    require(expected == description and {name[5:]: raw for name, raw in rebuilt.files if name.startswith("data/")} == payloads,
        "dossier semantic/media reconstruction differs")
    return rebuilt


def verify_dossier(directory, expected_manifest_hash):
    from .bagit import verify_bag
    bag = verify_bag(directory, expected_manifest_hash)
    require(loads(bag.manifest, maximum=MAX_MANIFEST)["input"]["mode"] == INPUT_MODE, "scoped dossier required")
    return bag


def verify_ocfl(directory, expected_inventory_hash):
    """Verify every version, then replay every distinct dossier; never execute archived code."""
    from .ocfl import _bag_for_state, verify_object_files
    result = verify_object_files(read_tree(directory), expected_inventory_hash)
    files = dict(result.files); inventory = loads(result.inventory, maximum=MAX_MANIFEST, canonical=True)
    seen = set()
    with TemporaryDirectory(prefix="stream-dossier-verify-") as temporary:
        for version, value in inventory["versions"].items():
            bag, description = _bag_for_state(files, inventory, value["state"])
            require(description["mode"] == INPUT_MODE, "OCFL version is not a scoped dossier")
            if bag.manifest_hash in seen: continue
            path = Path(temporary) / version
            write_tree(bag.files, path); verify_dossier(path, bag.manifest_hash)
            seen.add(bag.manifest_hash)
    return result


def _bounded_file(path):
    require(path.stat().st_size <= MAX_BYTES, "dossier input file bound")
    raw = path.read_bytes(); require(len(raw) <= MAX_BYTES, "dossier input changed beyond bound")
    return raw


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    defs = sub.add_parser("definitions"); defs.add_argument("--check", action="store_true")
    for name in ("inspect", "build"):
        command = sub.add_parser(name); command.add_argument("source", type=Path)
        if name == "build": command.add_argument("output", type=Path)
        command.add_argument("--manifest-hash", required=True); command.add_argument("--media-directory", type=Path)
        if name == "build":
            command.add_argument("--bagging-date", required=True); command.add_argument("--predecessor", default=ZERO)
            command.add_argument("--archive-evidence", type=Path); command.add_argument("--archive-evidence-hash")
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    version = sub.add_parser("ocfl"); version.add_argument("bag", type=Path); version.add_argument("output", type=Path)
    version.add_argument("--manifest-hash", required=True); version.add_argument("--created", required=True)
    version.add_argument("--message", required=True); version.add_argument("--previous", type=Path)
    version.add_argument("--previous-inventory-hash")
    ocfl = sub.add_parser("verify-ocfl"); ocfl.add_argument("directory", type=Path); ocfl.add_argument("--inventory-hash", required=True)
    args = parser.parse_args()
    try:
        if args.command == "definitions":
            root = Path(__file__).resolve().parents[2] / "schemas/museum/dossier"
            for name, raw in ((NAME, SCHEMA_BYTES), ("profile", PROFILE_BYTES)):
                path = root / (name + ".json")
                if args.check: require(path.read_bytes() == raw, "stale scoped dossier definition")
                else: root.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
            return
        if args.command in ("inspect", "build"):
            supplied = {} if args.media_directory is None else read_tree(args.media_directory)
            if args.command == "inspect":
                print(dumps(inspect_export(args.source, args.manifest_hash, supplied)).decode("utf-8")); return
            raw = None if args.archive_evidence is None else _bounded_file(args.archive_evidence)
            result = build_dossier(args.source, args.manifest_hash, supplied, bagging_date=args.bagging_date,
                predecessor=args.predecessor, archive_raw=raw, archive_hash=args.archive_evidence_hash)
            write_tree(result.files, args.output)
            verify_bag_files(read_tree(args.output), result.manifest_hash)
        elif args.command == "verify": result = verify_dossier(args.directory, args.manifest_hash)
        elif args.command == "ocfl":
            from .ocfl import build_version
            require((args.previous is None) == (args.previous_inventory_hash is None), "previous path and external pin must be paired")
            previous = None if args.previous is None else verify_ocfl(args.previous, args.previous_inventory_hash)
            result = build_version(verify_dossier(args.bag, args.manifest_hash), created=args.created, message=args.message,
                previous=previous, previous_inventory_hash=args.previous_inventory_hash)
            write_tree(result.files, args.output)
        else: result = verify_ocfl(args.directory, args.inventory_hash)
        print(dumps({"manifestHash" if hasattr(result, "manifest_hash") else "inventoryHash":
            result.manifest_hash if hasattr(result, "manifest_hash") else result.inventory_hash,
            "qualification": QUALIFICATION}).decode("utf-8"))
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(1, str(exc) + "\n")


if __name__ == "__main__": main()
