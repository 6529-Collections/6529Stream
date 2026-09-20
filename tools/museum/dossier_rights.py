"""Compose complete current RIGHTS evidence into an unchanged token examination.

The required source captures both native selection heads, their selected record
histories and original publications. Missing reads never produce an absence.
"""
from copy import deepcopy
from pathlib import Path

from . import dossier_gather as gather
from . import dossier_mint_entropy as mint
from . import object_dossier as base
from . import object_dossier_native as native
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .independent_wire import require

MODE = "token_current_rights_examination"
PROFILE = "STREAM_MUSEUM_CURRENT_RIGHTS_EXAMINATION_V1"
INPUTS = ("anchor.json", "transcript.json", "snapshot.json")
PIN_NAMES = {"anchorHash", "transcriptHash", "snapshotHash", "provenance"}
TOOL_NAMES = ("dossier_rights.py", "current_rights_source.py")
CLAIMS = {"originalExaminationReplayed": True, "bothCurrentRightsScopesChecked": True,
    "originalReceiptAuthorityRetained": True, "unknownConvertedToAbsence": False,
    "legalRightsAdjudicated": False, "datesUsedToOverrideNativeSelection": False,
    "syntheticEvidencePromoted": False, "canonicalAcquisitionPacketEmitted": False,
    "fullObjectDossierConformance": False, "sourceConsensusVerified": False,
    "institutionalAcceptance": False, "networkFetch": False}
QUALIFICATION = ("Item 7 is complete within the declared current RIGHTS source profile and its bounded "
    "RPC evidence. Both native scopes, selection histories, original publication receipts and payloads "
    "are retained. Token grants override collection grants for every explicit use, including unspecified. "
    "Recorded dates remain evidence; this is not a determination of legal ownership or enforceability. "
    "Source provenance remains externally admitted. Other acquisition requirements retain their prior status.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "baseModes": [gather.MODE, mint.MODE], "rightsSourceCount": "1",
    "scope": "One unchanged verified token examination and one complete current RIGHTS source triplet.",
    "joins": "Exact original token identity and source anchor; shared runtime hashes and repeated RPC answers.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "RIGHTS requires explicit public disclosure before source reads")


def _inputs(files, pins):
    require(type(files) is dict and set(files) == set(INPUTS), "RIGHTS exact capture triplet required")
    base._bounded(files)
    require(type(pins) is dict and set(pins) == PIN_NAMES
        and pins["provenance"] in ("synthetic_fixture", "trusted_rpc"), "RIGHTS explicit capture pins/provenance required")
    for name, limit in (("anchor", 65536), ("transcript", MAX_TRANSCRIPT), ("snapshot", MAX_BYTES)):
        raw, digest = files[name + ".json"], pins[name + "Hash"]
        require(0 < len(raw) <= limit and any(hex_bytes(digest, 32)) and keccak256(raw) == digest,
            "RIGHTS original " + name + " pin/bound differs")


def _base(examination, expected_hash):
    """Closed, bounded composition; a RIGHTS package cannot wrap itself."""
    base._bounded(examination)
    raw = examination.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "RIGHTS base external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    mode = manifest.get("mode") if type(manifest) is dict else None
    require(mode in (gather.MODE, mint.MODE), "RIGHTS base examination mode unsupported")
    previous = (gather.verify if mode == gather.MODE else mint.verify)(examination, expected_hash)
    gathered = dict(previous.files) if mode == gather.MODE else {
        p[len("examination/"):]: b for p, b in previous.files if p.startswith("examination/")}
    gathered_manifest = loads(gathered["manifest.json"], maximum=MAX_MANIFEST, canonical=True)
    originals = mint._originals(gathered, gathered_manifest)
    reference = native.reference_from_originals(previous.report["sourceState"], originals)
    return previous, gathered, originals, reference


def _capture(examination, gathered, originals, reference, files, pins):
    from .current_rights_source import CurrentRightsSource
    _inputs(files, pins)
    source = CurrentRightsSource(files["anchor.json"],
        ReplayTransport(files["transcript.json"], pins["transcriptHash"]), provenance=pins["provenance"])
    shared_pins, reads = mint._shared_observations(gathered, originals, reference)
    if "entropy/source/transcript.json" in examination:
        mint._merge_transcript(examination["entropy/source/transcript.json"], reads, shared_pins)
    native._join_anchor("current_rights", source.a, reference, shared_pins)
    state = reference["sourceState"]
    require(all(source.a[k] == state[k] for k in ("tokenId", "collectionId")),
        "RIGHTS exact token/collection differs")
    snapshot = source.snapshot()
    require(snapshot == files["snapshot.json"] and source.transcript() == files["transcript.json"],
        "RIGHTS original source replay differs")
    native._merge_observed_code(source, shared_pins)
    native._merge_rpc_results(source.reader.rows, reads)
    result = loads(snapshot, maximum=MAX_BYTES, canonical=True)
    expected = {k: state[k] for k in ("tokenId", "collectionId", "collectionSerial")}
    expected.update({k: reference["coreFacts"][k] for k in ("lifecycle", "burned")})
    require({k: result["identity"].get(k) for k in expected} == expected,
        "RIGHTS original Core identity differs")
    return result


def _fragment(result, anchor, snapshot):
    """Build the unchanged packet schema from original authority and publications."""
    from ..metadata import genesis_dossier_profile as packet
    from .metadata_rights_source import RECORD_TYPE, SCHEMA_NAME
    records = {row["recordHash"]: row for row in result["records"]}
    require(len(records) == len(result["records"]), "RIGHTS duplicate source original")
    fragment = {}
    for scope in ("collection", "token"):
        selected = result["scopes"][scope]
        expected_subject = subject_id(scope, anchor["chainId"], anchor["core"], anchor["collectionId"],
            token_id=anchor["tokenId"] if scope == "token" else "0")
        require(selected["subjectId"] == expected_subject, "RIGHTS fragment subject differs")
        if selected["status"] == "absent":
            fragment[scope] = None
            continue
        require(selected["status"] == "present", "RIGHTS unknown selection cannot form packet fragment")
        row = records[selected["current"][0]]
        record, receipt = row["record"], row["receipt"]
        require(record[0] == RECORD_TYPE and record[1] == expected_subject
            and record[4] == schema_id(SCHEMA_NAME) and receipt[2] in ("7", "8"),
            "RIGHTS original record family/authority differs")
        block = row["publication"]["recordedBlock"]
        require(uint(block, 64) <= uint(anchor["blockNumber"], 64), "RIGHTS publication follows source")
        fragment[scope] = {"record": {"recordHash": row["recordHash"], "host": anchor["host"],
            "subjectId": record[1], "subjectKind": scope, "recordType": record[0], "schemaId": record[4],
            "signer": receipt[1], "authorityClass": receipt[2], "recordedBlock": block},
            "grants": {use: row["value"]["grants"][use]["status"] for use in packet.USES}}
    chosen = fragment["token"] or fragment["collection"]
    effective = chosen["grants"] if chosen else {use: "unspecified" for use in packet.USES}
    specified = sum(value != "unspecified" for value in effective.values())
    completeness = ("absent" if chosen is None else "specified" if specified == len(packet.USES)
        else "unspecified" if specified == 0 else "partially_specified")
    require(result["effectiveGrants"] == effective and result["completeness"] == completeness,
        "RIGHTS native selection precedence/completeness differs")
    fragment.update(effectiveGrants=effective, completeness=completeness,
        selectionEvidence={"uri": "rights/source/snapshot.json", "hash": {"algorithm": 1,
            "canonicalizationId": schema_id("RFC8785_JCS"), "digest": keccak256(snapshot)}})
    definitions = packet.definitions()
    require(packet.Draft202012Validator({"$defs": definitions, **packet.ref("rights")}).is_valid(fragment),
        "RIGHTS canonical packet fragment shape differs")
    packet._typed(fragment, packet.ref("rights"), definitions)
    return fragment


def _extract(result):
    """Keep selected originals, dates and authority readable beside the raw capture."""
    files, rows = {}, []
    for row in result["records"]:
        prefix = "rights/records/" + row["recordHash"][2:]
        raw = hex_bytes(row["payloadHex"])
        require(keccak256(raw) == row["record"][2][1], "RIGHTS extracted original payload differs")
        files[prefix + "/payload.json"] = raw
        files[prefix + "/original.json"] = dumps(row)
        rows.append({"recordHash": row["recordHash"], "payloadPath": prefix + "/payload.json",
            "originalPath": prefix + "/original.json", "effectiveAt": row["record"][7],
            "effectiveDates": row["value"]["effectiveDates"], "receiptAuthorityClass": row["receipt"][2],
            "recorder": row["receipt"][1], "publication": row["publication"]})
    for document in result["documents"]:
        path = "rights/definitions/" + document["documentId"][2:] + ".json"
        require(path not in files, "RIGHTS duplicate original definition")
        files[path] = hex_bytes(document["payloadHex"])
    files["rights/records.json"] = dumps({"records": rows,
        "dateInterpretation": "Recorded date windows are retained without changing native selection or inferring a timezone."})
    return files


def _tools(snapshot=None):
    expected = {"tool/" + name + ".txt" for name in TOOL_NAMES}
    if snapshot is None:
        snapshot = {"tool/" + name + ".txt": Path(__file__).with_name(name).read_bytes().replace(b"\r\n", b"\n")
            for name in TOOL_NAMES}
    require(type(snapshot) is dict and set(snapshot) == expected, "RIGHTS inert tool snapshot set differs")
    for raw in snapshot.values():
        require(type(raw) is bytes and 0 < len(raw) <= MAX_MANIFEST and b"\r" not in raw, "RIGHTS inert tool bounds/encoding")
        raw.decode("utf-8")
    return snapshot | {"tool/source-index.json": dumps({"mode": "inert_implementation_provenance",
        "completeRuntimeArchive": False, "files": [base._ref(p, b) for p, b in sorted(snapshot.items())]})}


def compose(examination, examination_hash, *, disclosure, rights_files, rights_pins, tool_snapshot=None):
    _public(disclosure)
    _inputs(rights_files, rights_pins)
    previous, gathered, originals, reference = _base(examination, examination_hash)
    result = _capture(examination, gathered, originals, reference, rights_files, rights_pins)
    anchor = loads(rights_files["anchor.json"], maximum=524288, canonical=True)
    fragment = _fragment(result, anchor, rights_files["snapshot.json"])
    from .current_rights_source import PROFILE_BYTES as SOURCE_PROFILE_BYTES
    payloads = {"examination/" + p: b for p, b in previous.files}
    payloads.update(_tools(tool_snapshot))
    payloads.update(_extract(result))
    payloads.update({"rights/source/" + p: b for p, b in rights_files.items()})
    payloads["rights/packet-fragment.json"] = dumps(fragment)
    payloads["definitions/current-rights-source-profile.json"] = SOURCE_PROFILE_BYTES
    payloads["definitions/current-rights-examination-profile.json"] = PROFILE_BYTES
    items = deepcopy(previous.report["items"])
    for row in items:
        row["evidence"] = [("examination/packet/fields.json#" + p if p.startswith("/") else "examination/" + p)
            for p in row["evidence"]]
    item = items[6]
    require(item["item"] == "7", "RIGHTS base item order differs")
    item.update(status="derived_within_source_profile", evidence=["rights/packet-fragment.json",
        "rights/source/snapshot.json", "rights/records.json"],
        remaining="Source provenance remains externally admitted; legal enforceability and consensus are not established.")
    report = {"profile": PROFILE, "sourceState": previous.report["sourceState"], "sourceAnchor": previous.report["sourceAnchor"],
        "baseExamination": {"manifestHash": examination_hash, "fieldsPath": "examination/packet/fields.json"},
        "rights": {"status": "complete_within_source_profile", "packetFragmentPath": "rights/packet-fragment.json",
            "completeness": fragment["completeness"], "provenance": rights_pins["provenance"], "missing": []},
        "items": items, "unresolvedItems": [r["item"] for r in items if r["status"] == "unresolved"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    payloads["packet/fields.json"] = dumps(report)
    lines = ["# Current RIGHTS examination", "", QUALIFICATION, "",
        "RIGHTS completeness: `" + fragment["completeness"] + "`.", "",
        "| Item | Requirement | Status | Remaining evidence |", "| --- | --- | --- | --- |"]
    lines += ["| " + " | ".join((r["item"], r["name"], r["status"], r["remaining"])) + " |" for r in items]
    lines += ["", "Both selected original records and their payloads are retained under `rights/`.",
        "The earlier examination is retained unchanged under `examination/`.", ""]
    payloads["packet/examination.md"] = "\n".join(lines).encode("utf-8")
    base._bounded(payloads)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "examinationManifestHash": examination_hash, "rightsPins": rights_pins,
        "files": [base._ref(p, b) for p, b in sorted(payloads.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "RIGHTS manifest bound")
    payloads["manifest.json"] = raw
    base._bounded(payloads)
    return base.Assembly(tuple(sorted(payloads.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "RIGHTS external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "examinationManifestHash",
        "rightsPins", "files", "claims", "qualification"} and value["mode"] == MODE and value["profile"] == PROFILE
        and value["version"] == "1" and value["profileHash"] == PROFILE_HASH and value["claims"] == CLAIMS
        and value["qualification"] == QUALIFICATION, "RIGHTS closed manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "RIGHTS original file commitments differ")
    rebuilt = compose({p[len("examination/"):]: b for p, b in files.items() if p.startswith("examination/")},
        value["examinationManifestHash"], disclosure="public",
        rights_files={p[len("rights/source/"):]: b for p, b in files.items() if p.startswith("rights/source/")},
        rights_pins=value["rightsPins"],
        tool_snapshot={"tool/" + p + ".txt": files.get("tool/" + p + ".txt") for p in TOOL_NAMES})
    require(dict(rebuilt.files) == files, "RIGHTS source reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("canonical acquisition packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build")
    build.add_argument("--examination", type=Path, required=True)
    build.add_argument("--examination-hash", required=True)
    build.add_argument("--rights", type=Path, required=True)
    for name in ("anchor-hash", "transcript-hash", "snapshot-hash"):
        build.add_argument("--rights-" + name, required=True)
    build.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"), required=True)
    build.add_argument("--disclosure", required=True)
    build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "complete-packet"):
        command = sub.add_parser(name)
        command.add_argument("directory", type=Path)
        command.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "build":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        inputs = [args.examination, args.rights]
        _destination(args.output, inputs)
        pins = {"anchorHash": args.rights_anchor_hash, "transcriptHash": args.rights_transcript_hash,
            "snapshotHash": args.rights_snapshot_hash, "provenance": args.provenance}
        result = compose(read_tree(args.examination), args.examination_hash, disclosure=args.disclosure,
            rights_files=read_tree(args.rights), rights_pins=pins)
        _publish(dict(result.files), args.output, inputs)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash)
        return
    else:
        result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "rightsEvidence": result.report["rights"]["status"], "canonicalPacketReady": False,
        "unresolvedItems": result.report["unresolvedItems"]}).decode("utf-8"))


if __name__ == "__main__":
    main()
