"""Source-replayed item-9 assembly for the additive canonical packet V2.

Compatibility means compatibility with the explicitly pinned new schema and
replayed declared source profile. It does not authenticate source provenance or
complete the other acquisition requirements. Original V1 packages are retained.
"""
import argparse
from copy import deepcopy
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from ..metadata import acquisition_packet_v2 as packet
from ..metadata import genesis_dossier_profile as original_packet
from . import acquisition_accession as accession
from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from .dossier_gather import ITEMS
from .independent_wire import require

MODE = "acquisition_packet_assembly_v2"
PROFILE = "STREAM_MUSEUM_ACQUISITION_PACKET_ASSEMBLY_V2"
RECEIPT_FIELDS = ("tokenId", "owner", "recordedAt", "recordIndex", "recordChainHash", "relayed",
    "authorizationDigest", "nonce", "deadline", "schemaDefinitionHash", "canonicalizationDefinitionHash",
    "signatureScheme", "signatureBundleHash")
QUALIFICATION = ("Partial assembly under the explicitly declared canonical acquisition packet V2. "
    "Item 9 uses the original native owner receipt, publication, preceding Core ownership state and recorded "
    "signature-byte commitments after exact source replay. Original classed authority and V1 meanings are "
    "unchanged. Schema compatibility does not authenticate provenance, turn a fixture into chain evidence, "
    "establish legal title or complete the other acquisition requirements. Unknown items are never absence or waiver.")
CLAIMS = {"originalAcquisitionReplayed": True, "originalOwnerAuthorityRetained": True,
    "originalSignatureBytesBound": True, "historicalOwnershipReconciled": True,
    "item9CompatibleWithDeclaredV2Schema": True, "v1PacketCompatible": False,
    "completeCanonicalPacket": False, "actualChainAcceptance": False, "legalTitleProven": False,
    "custodyTransferred": False, "institutionIdentityProven": False,
    "sourceProvenanceSelfAuthenticated": False, "sourceConsensusVerified": False,
    "unknownConvertedToAbsence": False, "networkFetch": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "2", "status": "prospective_unregistered_assembly_profile",
    "packetSchema": packet.PACKET, "packetSchemaHash": packet.PACKET_SCHEMA_HASH,
    "legalInstrumentSchemaHash": packet.LEGAL_INSTRUMENT_SCHEMA_HASH,
    "nativeOwnerAuthorityProfileHash": packet.PROFILE_HASH,
    "originalAcquisitionProfileHash": accession.PROFILE_HASH,
    "admission": "Explicit external acquisition manifest, new packet schema and owner authority definition hashes; exact original source replay.",
    "scope": "Item9 native_owner_receipt variant plus source-derived token identity; all19 requirements retained, complete export unavailable.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def schema_bytes():
    p = original_packet
    defs = packet.definitions()
    fields = p.closed({"sourceState": p.ref("sourceState"), "subjectId": p.ref("hash"),
        "legalInstrument": p.ref("legalInstrument"), "erc721Identity": p.ref("identity")})
    item = p.closed({"item": p.enum(*(str(i) for i in range(1, 20))), "name": p.text(128),
        "status": p.enum("derived_within_source_profile", "partial", "unresolved"),
        "canonicalPacketCompatible": {"type": "boolean"}, "evidence": p.array(p.text(1024), maximum=8),
        "remaining": {"type": "string", "maxLength": 2048}})
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:6529stream:schema:" + PROFILE, "title": PROFILE,
        "$defs": defs, **p.closed({"schema": {"const": PROFILE}, "version": {"const": 2},
            "packetSchema": {"const": packet.PACKET}, "packetSchemaHash": {"const": packet.PACKET_SCHEMA_HASH},
            "authorityProfileHash": {"const": packet.PROFILE_HASH},
            "sourceProvenance": p.enum("synthetic_fixture", "trusted_rpc"), "fields": fields,
            "items": p.array(item, 19, 19), "unresolvedItems": p.array(p.enum(*(str(i) for i in range(1, 20))), 16, 16),
            "canonicalPacketReady": {"const": False},
            "claims": p.closed({k: {"const": v} for k, v in CLAIMS.items()}),
            "qualification": {"const": QUALIFICATION}})})


SCHEMA_BYTES = schema_bytes()
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def _pins(packet_schema_hash, authority_profile_hash):
    require(packet_schema_hash == packet.PACKET_SCHEMA_HASH and authority_profile_hash == packet.PROFILE_HASH,
        "packet V2 explicit schema/authority profile pins differ")


def _source_state(previous):
    s = previous.report["sourceState"]
    return {k: s[k] for k in ("chainId", "core", "collectionId", "tokenId", "collectionSerial", "subjectId",
        "blockNumber", "blockHash")} | {"collectionSubjectId": subject_id("collection", s["chainId"], s["core"], s["collectionId"]),
        "examinedAt": s["timestamp"], "burned": s["lifecycle"] == "3"}


def _fragment(previous, files, acquisition_hash, state):
    chosen = previous.report["selectedAccession"]
    digest = chosen["recordHash"]
    prefix = "records/" + digest[2:]
    original_bytes = files[prefix + "/original.json"]
    original = loads(original_bytes, maximum=1048576, canonical=True)
    payload, bundle = files[prefix + "/payload.bin"], files[prefix + "/signature-bundle.bin"]
    receipt = dict(zip(RECEIPT_FIELDS, original["receipt"], strict=True))
    manifest = loads(previous.manifest, maximum=MAX_MANIFEST, canonical=True)
    owner_pins, ownership_pins = manifest["ownerPins"], manifest["ownershipPins"]
    row = next(r for r in previous.report["records"] if r["recordHash"] == digest)
    index = uint(row["ownerHistoryIndex"])
    ownership = loads(files["sources/ownership/snapshot.json"], maximum=MAX_BYTES, canonical=True)
    prior, event = ownership["transitions"][index], ownership["events"][index]
    transfer = {k: prior[k] for k in ("from", "to", "blockNumber", "transactionHash", "transactionIndex", "logIndex")}
    transfer["blockHash"] = event["blockHash"]
    require(prior["to"] == receipt["owner"] and receipt["signatureBundleHash"] == keccak256(bundle)
        and original["recordHash"] == digest and hex_bytes(original["record"][5]) == payload,
        "packet V2 original owner/signature/payload binding differs")
    authority = {"kind": "native_owner_receipt", "version": "1", "receipt": receipt,
        "publication": deepcopy(original["publication"]),
        "ownerState": {"transferIndex": str(index), "transfer": transfer, "sourceBlockHash": state["blockHash"],
            "sourceBlockTimestamp": previous.report["sourceState"]["timestamp"]},
        "provenance": {"acquisitionManifestHash": acquisition_hash,
            "ownerSourceProfileHash": owner_pins["profileHash"], "ownerAnchorHash": owner_pins["anchorHash"],
            "ownerTranscriptHash": owner_pins["transcriptHash"], "ownerSnapshotHash": owner_pins["snapshotHash"],
            "ownershipSourceProfileHash": ownership_pins["profileHash"], "ownershipAnchorHash": ownership_pins["anchorHash"],
            "ownershipTranscriptHash": ownership_pins["transcriptHash"], "ownershipSnapshotHash": ownership_pins["snapshotHash"],
            "originalRecordBytesHash": keccak256(original_bytes), "originalPayloadBytesHash": keccak256(payload),
            "signatureBundleBytesHash": keccak256(bundle)}}
    old_ref = chosen["record"]
    record = {k: old_ref[k] for k in ("recordHash", "host", "subjectId", "subjectKind", "recordType", "schemaId", "recordedBlock")}
    record.update(signer=receipt["owner"], authority=authority)
    instrument = deepcopy(chosen["instrument"])
    # The committed institutional payload uses a decimal-string algorithm; the
    # canonical packet reference has always used its numeric JSON enum. This is
    # an explicit representation conversion, not a change to the original bytes.
    instrument["hash"]["algorithm"] = uint(instrument["hash"]["algorithm"], 16)
    fragment = {"status": "recorded", "instrument": instrument, "accession": record}
    packet.validate_legal_instrument(dumps(fragment), state)
    return fragment


def _items():
    rows = [{"item": str(i), "name": title, "status": "unresolved", "canonicalPacketCompatible": False,
        "evidence": [], "remaining": "Complete evidence for this requirement is not supplied to this assembly."}
        for i, (title, _) in enumerate(ITEMS, 1)]
    for i, path in ((2, "packet/assembly.json#/fields/subjectId"), (19, "packet/assembly.json#/fields/erc721Identity")):
        rows[i - 1].update(status="derived_within_source_profile", canonicalPacketCompatible=True,
            evidence=[path, "acquisition/sources/ownership/snapshot.json"], remaining="")
    rows[8].update(status="derived_within_source_profile", canonicalPacketCompatible=True,
        evidence=["packet/legal-instrument.json", "acquisition/accession/selected.json", "acquisition/sources/owner/snapshot.json"],
        remaining="Source provenance remains externally admitted; referenced-byte availability and legal validity are separate observations.")
    rows[9].update(status="partial", evidence=["acquisition/ownership/transfers.jsonl", "acquisition/acquisition/report.json"],
        remaining="A complete protocol event archive and all prior/unregistered applicable owner hosts remain required.")
    rows[12]["remaining"] = ("Required native conservation-tier declaration writer/event/getter and authoritative declaration-host binding remain missing "
        "(Metadata/records lead; Root for shared Core binding). Existing intent/interview selectors need their separate Museum source reader.")
    rows[14]["remaining"] = ("Required canonical condition-host/current-selection and complete absence denominator producers remain missing "
        "(Metadata/records lead; Root for shared Core binding). Museum must join selected reports/capture bytes after these exist.")
    return rows


def _validate_report(report):
    raw = dumps(report)
    require(len(raw) <= original_packet.MAX_BYTES, "packet V2 partial assembly bound")
    schema = loads(SCHEMA_BYTES, maximum=MAX_MANIFEST, canonical=True)
    try:
        Draft202012Validator(schema).validate(report)
        original_packet._typed(report, schema, schema["$defs"])
    except (ValidationError, MuseumError, KeyError, TypeError, ValueError) as exc:
        raise MuseumError("packet V2 partial assembly schema differs") from exc
    require(report["items"] == _items() and report["unresolvedItems"] == [r["item"] for r in _items()
        if r["status"] != "derived_within_source_profile"], "packet V2 unresolved requirement index differs")
    fields, state = report["fields"], report["fields"]["sourceState"]
    require(fields["subjectId"] == state["subjectId"] and fields["erc721Identity"] == {
        "core": state["core"], "collectionId": state["collectionId"], "globalTokenId": state["tokenId"],
        "catalogNumber": state["tokenId"], "collectionSerial": state["collectionSerial"]}, "packet V2 identity projection differs")
    packet.validate_legal_instrument(dumps(fields["legalInstrument"]), state)
    return raw


def compose(acquisition_files, acquisition_hash, *, disclosure, packet_schema_hash, authority_profile_hash):
    accession._public(disclosure)
    _pins(packet_schema_hash, authority_profile_hash)
    acquisition_files = dict(acquisition_files)
    previous = accession.verify(acquisition_files, acquisition_hash)
    original_files = dict(previous.files)
    state = _source_state(previous)
    fragment = _fragment(previous, original_files, acquisition_hash, state)
    fields = {"sourceState": state, "subjectId": state["subjectId"], "legalInstrument": fragment,
        "erc721Identity": {"core": state["core"], "collectionId": state["collectionId"], "globalTokenId": state["tokenId"],
            "catalogNumber": state["tokenId"], "collectionSerial": state["collectionSerial"]}}
    rows = _items()
    report = {"schema": PROFILE, "version": 2, "packetSchema": packet.PACKET, "packetSchemaHash": packet_schema_hash,
        "authorityProfileHash": authority_profile_hash, "sourceProvenance": previous.report["provenance"],
        "fields": fields, "items": rows, "unresolvedItems": [r["item"] for r in rows if r["status"] != "derived_within_source_profile"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    report_bytes = _validate_report(report)
    files = {"acquisition/" + p: b for p, b in previous.files}
    files.update({"definitions/packet-schema.json": packet.PACKET_SCHEMA_BYTES,
        "definitions/legal-instrument-schema.json": packet.LEGAL_INSTRUMENT_SCHEMA_BYTES,
        "definitions/native-owner-authority-profile.json": packet.PROFILE_BYTES,
        "definitions/assembly-profile.json": PROFILE_BYTES, "definitions/assembly-schema.json": SCHEMA_BYTES,
        "packet/legal-instrument.json": dumps(fragment), "packet/assembly.json": report_bytes})
    lines = ["# Canonical packet V2: partial acquisition assembly", "", QUALIFICATION, "",
        "Item 9 is compatible with `" + packet.PACKET + "` only. The original V1 package remains unchanged under `acquisition/`.", "",
        "| Item | Requirement | Status | Remaining evidence |", "| --- | --- | --- | --- |"]
    lines += ["| " + " | ".join((r["item"], r["name"], r["status"], r["remaining"])) + " |" for r in rows]
    files["packet/examination.md"] = ("\n".join(lines) + "\n").encode("utf-8")
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "2", "profileHash": PROFILE_HASH,
        "acquisitionManifestHash": acquisition_hash, "packetSchemaHash": packet_schema_hash,
        "authorityProfileHash": authority_profile_hash, "assemblySchemaHash": SCHEMA_HASH,
        "files": [base._ref(p, b) for p, b in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "packet V2 manifest bound")
    files["manifest.json"] = raw
    base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "packet V2 external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "acquisitionManifestHash",
        "packetSchemaHash", "authorityProfileHash", "assemblySchemaHash", "files", "claims", "qualification"}
        and manifest["mode"] == MODE and manifest["profile"] == PROFILE and manifest["version"] == "2"
        and manifest["profileHash"] == PROFILE_HASH and manifest["assemblySchemaHash"] == SCHEMA_HASH
        and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION,
        "packet V2 closed manifest differs")
    require(manifest["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "packet V2 original file commitments differ")
    rebuilt = compose({p[len("acquisition/"):]: b for p, b in files.items() if p.startswith("acquisition/")},
        manifest["acquisitionManifestHash"], disclosure="public", packet_schema_hash=manifest["packetSchemaHash"],
        authority_profile_hash=manifest["authorityProfileHash"])
    require(dict(rebuilt.files) == files, "packet V2 source reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    build.add_argument("--acquisition", type=Path, required=True)
    build.add_argument("--acquisition-hash", required=True)
    build.add_argument("--packet-schema-hash", required=True)
    build.add_argument("--authority-profile-hash", required=True)
    build.add_argument("--disclosure", required=True)
    build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "complete-packet"):
        command = sub.add_parser(name)
        command.add_argument("directory", type=Path)
        command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles")
    args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "assemblySchemaHash": SCHEMA_HASH,
            "packetSchema": packet.PACKET, "packetSchemaHash": packet.PACKET_SCHEMA_HASH,
            "legalInstrumentSchemaHash": packet.LEGAL_INSTRUMENT_SCHEMA_HASH,
            "authorityProfileHash": packet.PROFILE_HASH}).decode("utf-8"))
        return
    if args.command == "assemble":
        accession._public(args.disclosure)
        _pins(args.packet_schema_hash, args.authority_profile_hash)
        from .repository_exchange import _destination, _publish
        _destination(args.output, [args.acquisition])
        result = compose(read_tree(args.acquisition), args.acquisition_hash, disclosure=args.disclosure,
            packet_schema_hash=args.packet_schema_hash, authority_profile_hash=args.authority_profile_hash)
        require(verify(result.files, result.manifest_hash).files == result.files, "packet V2 pre-publication replay differs")
        _publish(dict(result.files), args.output, [args.acquisition])
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash)
        return
    else:
        result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "packetSchema": packet.PACKET, "item9CanonicalPacketCompatible": True,
        "canonicalPacketReady": False, "sourceProvenance": result.report["sourceProvenance"],
        "unresolvedItems": result.report["unresolvedItems"]}).decode("utf-8"))


if __name__ == "__main__":
    main()
