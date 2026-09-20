"""Native preservation-object declarations joined to retained local file bytes.

Original account receipts and declarations remain separate from the current
offline size/digest comparison. No historical fixity event is inferred.
"""
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path

from .account_profile import JCS_BYTES, JCS_ID
from .bagit import MAX_BYTES, MAX_FILES, _paths, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .independent_catalog_source import IndependentCatalogSource, PROFILE_HASH as CATALOG_PROFILE_HASH
from .independent_wire import RAW_BYTES, require
from .premis import PinnedPremis, PROFILE_BYTES as XSD_PROFILE_BYTES, PROFILE_HASH as XSD_PROFILE_HASH, SCHEMA_SHA256
from .preservation_resources import OBJECT_NAME, SCHEMAS, FAMILY, MAX_OBJECTS, admit_objects, render
from .review import _selector
from .source import RecordSelector, RetainedSourceRecord

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_MUSEUM_NATIVE_RETAINED_PREMIS_V1"
MODE = "native_catalogue_retained_premis"
MAX_PLAN = 524288
MAX_FILE = 32 * 1024 * 1024
MAX_FILES_BYTES = 64 * 1024 * 1024
QUALIFICATION = ("Selected native independent-account preservation-object declarations, exact registered schema bytes "
    "and current offline comparison with supplied local file bytes. Source provenance is inherited from the caller-admitted "
    "catalogue and remains explicit. Format, role, relationships and URI are recorded claims. No historical fixity event, "
    "network availability, current authority, format detection, cryptographic state proof or complete PREMIS/dossier conformance is inferred.")
CLAIMS = {"nativeCatalogueReplayed": True, "originalRecordBytesRetained": True,
    "selectedObjectSubjectsChecked": True,
    "historicalFixityPerformedProven": False, "historicalEventsInvented": False,
    "currentAuthorityProven": False, "cryptographicStateProof": False, "formatIdentified": False,
    "networkAvailabilityProven": False, "fullPremisCrosswalk": False,
    "fullObjectDossierConformance": False, "institutionalAcceptance": False}
PROFILE_BYTES = dumps({"name": NAME, "version": "1", "mode": MODE,
    "status": "prospective_unregistered_export_profile", "catalogueProfileHash": CATALOG_PROFILE_HASH,
    "objectSchemaName": OBJECT_NAME, "objectSchemaHash": keccak256(SCHEMAS[OBJECT_NAME]),
    "canonicalizationId": JCS_ID, "canonicalizationHash": keccak256(JCS_BYTES),
    "premisXsdSHA256": "0x" + SCHEMA_SHA256,
    "source": "Whole-record selectors from one complete native Independent catalogue, including original payload/signature bytes and historical receipts; no semantic assertion selection prerequisite.",
    "selection": "Explicit selected record hashes and relative local paths. Distinct objects may reference the same exact file; all relationships must target selected original objects. No current-head selection or roles are inferred.",
    "comparison": "Compute SHA256 and KECCAK256 plus byte count over each supplied file; compare the algorithm and size declared in the original typed object. Missing/mismatching files produce diagnostics and no partial XML.",
    "premis": "Reuse original object/role/relationship mapping and pinned PREMIS3 XSD. No event/agent/time is created by byte measurement. Current comparison remains a separate report.",
    "limits": {"objects": str(MAX_OBJECTS), "planBytes": str(MAX_PLAN), "fileBytes": str(MAX_FILE),
        "totalDistinctFileBytes": str(MAX_FILES_BYTES), "sourceTranscriptBytes": str(MAX_TRANSCRIPT),
        "packageBytes": str(MAX_BYTES), "packageFiles": str(MAX_FILES)},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Projection:
    xml: bytes | None
    report: bytes
    correspondence: bytes
    provenance: bytes
    comparisons: bytes
    source: bytes


class _Objects:
    """Internal exact typed-record view; public entrypoint owns source admission."""
    def __init__(self, catalogue, snapshot, selections):
        self.anchor = dict(catalogue.a)
        self.records, self.canonicalizations, self.originals = {}, {}, {}
        docs = {d["documentId"]: d for d in snapshot["documents"]}
        selected = {row["recordHash"]: row for row in snapshot["records"]}
        snapshot_hash = keccak256(dumps(snapshot))
        if selections:
            for identifier, expected, kind, canonical in (
                (schema_id(OBJECT_NAME), SCHEMAS[OBJECT_NAME], "0", JCS_ID),
                (JCS_ID, JCS_BYTES, "1", RAW_BYTES)):
                doc = docs.get(identifier)
                require(doc is not None and hex_bytes(doc["payloadHex"]) == expected
                    and doc["view"][3][1:4] == [kind, keccak256(expected), canonical],
                    "retained PREMIS exact registered definition differs")
        for key in selections:
            require(key in selected, "retained PREMIS selected native record absent")
            row = selected[key]; record, receipt, subject = row["record"], row["receipt"], row["subject"]
            require(record[0] == FAMILY and record[4] == schema_id(OBJECT_NAME) and record[2][2] == JCS_ID
                    and receipt[2] == "5" and receipt[9:11] == [keccak256(SCHEMAS[OBJECT_NAME]), keccak256(JCS_BYTES)]
                    and subject[0] == "2" and receipt[0] == subject[1] == str(catalogue.scope),
                    "retained PREMIS native schema/family/subject/receipt differs")
            selector = RecordSelector(self.anchor["host"], key, record[1], record[4], receipt[9], record[0],
                receipt[1], "INDEPENDENT_ATTESTOR", receipt[4], receipt[5])
            authority = dumps({"mode": snapshot["mode"], "sourceProvenance": snapshot["evidence"],
                "basis": "original_native_receipt_consistency", "original": row,
                "sourceSnapshotHash": snapshot_hash, "humanIdentityProven": False,
                "currentSignatureRevalidation": False})
            self.records[key] = RetainedSourceRecord(selector, hex_bytes(row["payloadHex"]), record[2][1],
                SCHEMAS[OBJECT_NAME], authority, "public")
            self.canonicalizations[key] = JCS_ID
            self.originals[key] = row

    def record(self, selector):
        record = self.records.get(selector.get("recordHash"))
        require(record is not None and selector == _selector(record, ""), "retained PREMIS selector differs")
        return record


def project(catalogue, plan_raw, files, *, source_hash, plan_hash, profile_hash, disclosure):
    """Reconstruct original native objects, then measure supplied immutable bytes.

    Synthetic catalogues stay synthetic. A trusted-RPC catalogue is a caller's
    admitted observation, not a consensus proof or verifier endorsement.
    """
    require(disclosure == "public", "retained PREMIS explicit public disclosure required")
    require(type(catalogue) is IndependentCatalogSource, "retained PREMIS concrete native catalogue required")
    require(type(plan_raw) is bytes and keccak256(plan_raw) == plan_hash and profile_hash == PROFILE_HASH,
            "retained PREMIS external plan/profile differs")
    require(type(files) is dict and len(files) <= MAX_OBJECTS
            and all(type(p) is str and type(b) is bytes and len(b) <= MAX_FILE for p, b in files.items())
            and sum(map(len, files.values())) <= MAX_FILES_BYTES, "retained PREMIS file bounds")
    _paths(files)
    plan = loads(plan_raw, maximum=MAX_PLAN, canonical=True)
    require(type(plan) is dict and set(plan) == {"mode", "version", "sourceSnapshotHash", "profileHash", "objects"}
            and plan["mode"] == MODE and plan["version"] == "1" and plan["sourceSnapshotHash"] == source_hash
            and plan["profileHash"] == profile_hash and type(plan["objects"]) is list
            and len(plan["objects"]) <= MAX_OBJECTS, "retained PREMIS plan shape/scope")
    chosen, paths = [], []
    for row in plan["objects"]:
        require(type(row) is dict and set(row) == {"recordHash", "path"}
                and type(row["path"]) is str and any(hex_bytes(row["recordHash"], 32)), "retained PREMIS selection shape")
        chosen.append(row["recordHash"]); paths.append(row["path"])
    require(chosen == sorted(set(chosen)), "retained PREMIS record selection must be sorted and unique")
    _paths(set(paths))
    require(set(files) <= set(paths), "retained PREMIS unselected file supplied")
    raw = catalogue.snapshot()
    require(keccak256(raw) == source_hash, "retained PREMIS external native snapshot differs")
    snapshot = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
    require(snapshot["evidence"] == catalogue.provenance and snapshot["mode"] ==
            ("recorded_state" if catalogue.provenance == "trusted_rpc" else "synthetic_fixture"),
            "retained PREMIS source provenance differs")
    adapter = _Objects(catalogue, snapshot, chosen)
    objects = admit_objects(adapter, [_selector(adapter.records[k], "") for k in chosen])
    # Check all present typed declarations before diagnosing unavailable bytes.
    schema = PinnedPremis(ROOT / "schemas/museum", XSD_PROFILE_BYTES, profile_hash=XSD_PROFILE_HASH)
    xml, issues, mapping, provenance = render(objects, [], schema)
    observations = []
    by_hash = {r["record"].selector.record_hash: r for r in objects}
    for key, path in zip(chosen, paths):
        row = by_hash[key]; value = row["value"]; ref = value["object"]
        original_subject = adapter.originals[key]["subject"]
        require(original_subject[1:4] == [value["collectionId"], "0", ref["objectId"]],
                "retained PREMIS original media subject differs")
        expected = {"algorithm": value["hashAlgorithm"], "digest": ref["contentHash"], "byteSize": ref["byteSize"]}
        measured = None
        if path not in files:
            status = "missing"
            issues.append({"objectSubject": row["subject"], "path": path, "reasonCode": "retained_file_missing"})
        else:
            content = files[path]
            measured = {"byteSize": str(len(content)), "SHA256": "0x" + sha256(content).hexdigest(),
                        "KECCAK256": keccak256(content)}
            status = "matches" if measured["byteSize"] == expected["byteSize"] and measured[expected["algorithm"]] == expected["digest"] else "mismatch"
            if status == "mismatch":
                issues.append({"objectSubject": row["subject"], "path": path, "reasonCode": "retained_file_differs_from_original_declaration"})
        observations.append({"source": row["selector"], "objectSubject": row["subject"], "path": path,
            "expectedOriginalDeclaration": expected, "observedLocalBytes": measured, "status": status,
            "observationBasis": "current_offline_byte_comparison", "historicalPerformanceProven": False,
            "historicalCheckTime": None})
    if issues: xml = None
    report = dumps({"mode": MODE, "version": "1", "profileHash": PROFILE_HASH,
        "sourceSnapshotHash": source_hash, "planHash": plan_hash, "sourceMode": snapshot["mode"],
        "sourceProvenance": snapshot["evidence"], "sourceState": snapshot["sourceState"],
        "status": "supported" if xml is not None else "unsupported", "issues": issues,
        "selectedObjects": str(len(objects)), "suppliedFiles": str(len(files)),
        "performedLocalComparisons": str(sum(r["observedLocalBytes"] is not None for r in observations)),
        "allSelectedFilesMatch": bool(objects) and all(r["status"] == "matches" for r in observations),
        "xmlHash": None if xml is None else keccak256(xml), "premisXsdSHA256": "0x" + SCHEMA_SHA256,
        "claims": CLAIMS, "qualification": QUALIFICATION})
    return Projection(xml, report, dumps(mapping), dumps(provenance), dumps(observations), raw)


def replay(anchor, transcript, plan, files, *, anchor_hash, transcript_hash, source_hash,
           plan_hash, profile_hash, provenance, disclosure):
    """Offline public entry: externally pin and replay the complete native source."""
    require(disclosure == "public", "retained PREMIS explicit public disclosure required")
    require(type(anchor) is bytes and len(anchor) <= MAX_PLAN and keccak256(anchor) == anchor_hash,
            "retained PREMIS external anchor differs")
    require(type(transcript) is bytes and len(transcript) <= MAX_TRANSCRIPT, "retained PREMIS transcript bound")
    source = IndependentCatalogSource(anchor, ReplayTransport(transcript, transcript_hash), provenance=provenance)
    result = project(source, plan, files, source_hash=source_hash, plan_hash=plan_hash,
        profile_hash=profile_hash, disclosure=disclosure)
    require(source.transcript() == transcript, "retained PREMIS original transcript differs")
    return result


def output_files(result, anchor, transcript, plan, files):
    """Retain exact originals and measured files alongside the derived outputs."""
    output = {"source/anchor.json": anchor, "source/transcript.json": transcript,
        "source/snapshot.json": result.source, "input/plan.json": plan,
        "definitions/profile.json": PROFILE_BYTES, "definitions/" + OBJECT_NAME + ".json": SCHEMAS[OBJECT_NAME],
        "definitions/RFC8785_JCS.json": JCS_BYTES,
        **{"projection/" + field + ".json": getattr(result, field)
           for field in ("report", "correspondence", "provenance", "comparisons")},
        **{"retained/" + path: raw for path, raw in files.items()}}
    if result.xml is not None: output["projection/premis.xml"] = result.xml
    dependency = ROOT / "schemas/museum/premis"
    output["dependencies/premis/profile.json"] = XSD_PROFILE_BYTES
    output["dependencies/premis/dependency-index.json"] = (dependency / "dependency-index.json").read_bytes()
    for path in sorted((dependency / "chunks" / SCHEMA_SHA256).glob("*.bin")):
        output["dependencies/premis/chunks/" + SCHEMA_SHA256 + "/" + path.name] = path.read_bytes()
    return output


def _bounded_package(files):
    require(type(files) is dict and len(files) <= MAX_FILES
            and all(type(p) is str and type(b) is bytes for p, b in files.items())
            and sum(map(len, files.values())) <= MAX_BYTES, "retained PREMIS package bounds")
    _paths(files)


def _inventory(files):
    return [{"path": path, "keccak256": keccak256(raw), "byteLength": str(len(raw))}
            for path, raw in sorted(files.items())]


def build(anchor, transcript, plan, files, **pins):
    """Build a fully replayable derivative, including unsupported diagnostics."""
    expected = {"anchor_hash", "transcript_hash", "source_hash", "plan_hash", "profile_hash", "provenance", "disclosure"}
    require(set(pins) == expected, "retained PREMIS package pins differ")
    result = replay(anchor, transcript, plan, files, **pins)
    output = output_files(result, anchor, transcript, plan, files)
    _bounded_package(output)
    manifest = dumps({"mode": MODE, "version": "1", "profileHash": PROFILE_HASH,
        "pins": pins, "files": _inventory(output), "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_PLAN, "retained PREMIS manifest bound")
    output["manifest.json"] = manifest
    _bounded_package(output)
    return output


def verify(files, manifest_hash):
    """An external manifest pin plus exact source replay, not hash-only acceptance."""
    _bounded_package(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == manifest_hash, "retained PREMIS external manifest differs")
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "version", "profileHash", "pins", "files", "claims", "qualification"}
            and value["mode"] == MODE and value["version"] == "1" and value["profileHash"] == PROFILE_HASH
            and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION,
            "retained PREMIS closed manifest differs")
    require(value["files"] == _inventory({p: b for p, b in files.items() if p != "manifest.json"}),
            "retained PREMIS original inventory differs")
    require(type(value["pins"]) is dict, "retained PREMIS pins shape")
    try:
        rebuilt = build(files["source/anchor.json"], files["source/transcript.json"], files["input/plan.json"],
            {p[len("retained/"):]: b for p, b in files.items() if p.startswith("retained/")}, **value["pins"])
    except KeyError as exc:
        raise MuseumError("retained PREMIS reconstruction input absent") from exc
    require(rebuilt == files, "retained PREMIS reconstruction differs")
    return loads(rebuilt["projection/report.json"], maximum=MAX_PLAN, canonical=True)


def definitions(check=False):
    path = ROOT / "schemas/museum/premis-retained/profile.json"
    if check:
        require(path.is_file() and path.read_bytes() == PROFILE_BYTES, "retained PREMIS profile differs")
    else:
        path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    definition = commands.add_parser("definitions"); definition.add_argument("--check", action="store_true")
    build_command = commands.add_parser("build")
    for arg in ("anchor", "transcript", "plan", "files", "output"):
        build_command.add_argument("--" + arg, type=Path, required=True)
    for arg in ("anchor-hash", "transcript-hash", "source-hash", "plan-hash", "profile-hash"):
        build_command.add_argument("--" + arg, required=True)
    build_command.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"), required=True)
    build_command.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    check = commands.add_parser("verify")
    check.add_argument("directory", type=Path); check.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "definitions":
        print(definitions(args.check)); return
    if args.command == "verify":
        print(dumps(verify(read_tree(args.directory), args.manifest_hash)).decode()); return
    require(args.disclosure == "public", "retained PREMIS explicit public disclosure required")
    inputs = []
    for path, maximum in ((args.anchor, MAX_PLAN), (args.transcript, MAX_TRANSCRIPT), (args.plan, MAX_PLAN)):
        with path.open("rb") as stream: raw = stream.read(maximum + 1)
        require(len(raw) <= maximum, "retained PREMIS input file bound")
        inputs.append(raw)
    anchor, transcript, plan = inputs; files = read_tree(args.files)
    output = build(anchor, transcript, plan, files, anchor_hash=args.anchor_hash,
        transcript_hash=args.transcript_hash, source_hash=args.source_hash, plan_hash=args.plan_hash,
        profile_hash=args.profile_hash, provenance=args.provenance, disclosure=args.disclosure)
    write_tree(output, args.output)
    print(dumps({"manifestHash": keccak256(output["manifest.json"]), "reportHash": keccak256(output["projection/report.json"])}).decode())


if __name__ == "__main__":
    main()
