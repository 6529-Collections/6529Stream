"""Pure V5 title derivation from an already replayed accession package.

The caller owns source replay and cross-package observation reconciliation.
This module binds retained bytes and native fields without legal-title inference.
"""
from copy import deepcopy

from ..metadata import acquisition_packet_v5 as packet
from ..metadata import acquisition_packet_v2 as owner_authority
from ..metadata import genesis_dossier_profile as legacy
from . import acquisition_accession as accession
from . import acquisition_packet_v2 as original_assembly
from . import institutional
from .bagit import MAX_BYTES, MAX_MANIFEST
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .independent_wire import require
from .object_dossier import Assembly
from .public_owner_catalog_source import PROFILE_HASH as OWNER_PROFILE_HASH
from .public_ownership_source import PROFILE_HASH as OWNERSHIP_PROFILE_HASH

PROFILE = "STREAM_MUSEUM_NATIVE_TITLE_V5_DERIVATION_V1"
SOURCE_REVISION = "6fb3291e0991f556ef642e206c7732d8882a336f"
MAX_TITLE_RECORDS = accession.MAX_INSTITUTIONAL_RECORDS
COVERAGE = {
    "legalInstrument": "derived_within_source_profile",
    "coreTransferHistory": "derived_within_source_profile",
    "supportedTitleBindings": "derived_within_source_profile",
    "ownerLaneHeads": "derived_within_source_profile",
    "protocolEventArchive": "supplied_unverified",
    "otherOwnerHosts": "not_enumerated",
    "legalTitle": "not_proven",
    "institutionIdentity": "not_proven",
    "canonicalCurrentAccession": False,
    "completeItem10": False,
}
QUALIFICATION = (
    "Explicitly selected original ACCESSION, supported original ACCESSION/DEACCESSION title statements, "
    "full captured Core transfers and captured owner-lane heads. Later supported statements remain represented; "
    "no global latest ACCESSION, legal title, institutional identity or complete protocol event archive is inferred. "
    "Unrelated supplied packet fields and protocol-archive reference remain supplied. Source replay and cross-source "
    "reconciliation are the caller's responsibility; this pure derivation is not source authentication."
)
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "reviewedSourceCommit": SOURCE_REVISION,
    "status": "prospective_unregistered_derivation_profile", "packetSchemaHash": packet.PACKET_SCHEMA_HASH,
    "nativeOwnerAuthorityProfileHash": owner_authority.PROFILE_HASH,
    "originalLegalInstrumentSchemaHash": owner_authority.LEGAL_INSTRUMENT_SCHEMA_HASH,
    "accessionProfileHash": accession.PROFILE_HASH, "originalAssemblyProfileHash": original_assembly.PROFILE_HASH,
    "ownerSourceProfileHash": OWNER_PROFILE_HASH, "ownershipSourceProfileHash": OWNERSHIP_PROFILE_HASH,
    "bounds": {"titleRecords": str(MAX_TITLE_RECORDS), "packetHeads": "64", "packetBytes": str(packet.MAX_BYTES)},
    "rules": ["The full original sourceState, including examinedAt, must equal the accession computed native state; no silent state rewrite.",
        "The chosen legal instrument uses the unchanged V2 owner fragment. Other supported title bindings retain the same native receipt discriminator and exact original byte hashes; no numeric authorityClass.",
        "Only exact captured host/token/type lane keys are replaced. Other heads and other-host title statements remain supplied. Matching source title lanes contain only supported matched originals after derivation.",
        "Core transfers/currentOwner come from the complete captured ownership source. The existing protocol-event snapshot reference is preserved unchanged and remains unverified.",
        "Unsupported/unmatched captured statements remain unresolved, never become a title binding and never select an older canonical accession.",
        "The resulting full packet must pass the unchanged V5 validator, including native owner chronology, head/count and shared-coordinate joins."],
    "coverage": COVERAGE, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)
TITLE_TYPES = {schema_id(name) for name in ("ACCESSION", "DEACCESSION")}


def _read(files, path, maximum=MAX_BYTES):
    raw = files[path]
    require(type(raw) is bytes and 0 < len(raw) <= maximum, "native title retained bytes bound")
    return loads(raw, maximum=maximum, canonical=True)


def _record(previous, files, manifest_hash, state, row, ownership, manifest):
    """Exact owner authority from retained originals, not a projected legacy class."""
    digest = row["recordHash"]; prefix = "records/" + digest[2:]
    raw = files[prefix + "/original.json"]; original = _read(files, prefix + "/original.json")
    payload, bundle = files[prefix + "/payload.bin"], files[prefix + "/signature-bundle.bin"]
    record = original["record"]
    receipt = dict(zip(original_assembly.RECEIPT_FIELDS, original["receipt"], strict=True))
    require(original["recordHash"] == digest and hex_bytes(record[5]) == payload
        and hex_bytes(original["signatureBundleHex"]) == bundle
        and receipt["signatureBundleHash"] == keccak256(bundle)
        and original["publication"] == row["publication"], "native title original byte/receipt correspondence")
    index = uint(row["ownerHistoryIndex"])
    require(index < len(ownership["transitions"]) == len(ownership["events"]), "native title prior holder index")
    prior, event = ownership["transitions"][index], ownership["events"][index]
    transfer = {key: prior[key] for key in ("from", "to", "blockNumber", "transactionHash", "transactionIndex", "logIndex")}
    transfer["blockHash"] = event["blockHash"]
    require(transfer["to"] == receipt["owner"], "native title original receipt owner")
    owner_pins, ownership_pins = manifest["ownerPins"], manifest["ownershipPins"]
    authority = {"kind": "native_owner_receipt", "version": "1", "receipt": receipt,
        "publication": deepcopy(original["publication"]),
        "ownerState": {"transferIndex": str(index), "transfer": transfer, "sourceBlockHash": state["blockHash"],
            "sourceBlockTimestamp": previous.report["sourceState"]["timestamp"]},
        "provenance": {"acquisitionManifestHash": manifest_hash,
            "ownerSourceProfileHash": owner_pins["profileHash"], "ownerAnchorHash": owner_pins["anchorHash"],
            "ownerTranscriptHash": owner_pins["transcriptHash"], "ownerSnapshotHash": owner_pins["snapshotHash"],
            "ownershipSourceProfileHash": ownership_pins["profileHash"], "ownershipAnchorHash": ownership_pins["anchorHash"],
            "ownershipTranscriptHash": ownership_pins["transcriptHash"], "ownershipSnapshotHash": ownership_pins["snapshotHash"],
            "originalRecordBytesHash": keccak256(raw), "originalPayloadBytesHash": keccak256(payload),
            "signatureBundleBytesHash": keccak256(bundle)}}
    result = {key: row["record"][key] for key in
        ("recordHash", "host", "subjectId", "subjectKind", "recordType", "schemaId", "recordedBlock")}
    require((result["recordType"], result["subjectId"], result["schemaId"]) == tuple(record[:3])
        and result["recordedBlock"] == original["publication"]["blockNumber"], "native title original record fields")
    result.update(signer=receipt["owner"], authority=authority)
    owner_authority._owner_record(result, state)
    return result


def _derive(previous, files, manifest_hash, original_packet):
    require(type(previous) is Assembly and type(files) is dict and files == dict(previous.files) and previous.manifest == files.get("manifest.json")
        and any(hex_bytes(manifest_hash, 32)) and previous.manifest_hash == manifest_hash
        and keccak256(previous.manifest) == manifest_hash, "native title verified accession bytes/pin differ")
    manifest = _read(files, "manifest.json", MAX_MANIFEST)
    require(manifest["profileHash"] == accession.PROFILE_HASH and manifest["profile"] == accession.PROFILE
        and manifest["ownerPins"]["profileHash"] == OWNER_PROFILE_HASH
        and manifest["ownershipPins"]["profileHash"] == OWNERSHIP_PROFILE_HASH
        and _read(files, "acquisition/report.json") == previous.report, "native title original profiles/report differ")
    result = packet.validate(dumps(original_packet))
    state = original_assembly._source_state(previous)
    require(result["sourceState"] == state, "native title sourceState differs")
    ownership = _read(files, "sources/ownership/snapshot.json")
    owner = _read(files, "sources/owner/snapshot.json")
    for kind, snapshot in (("owner", owner), ("ownership", ownership)):
        require(keccak256(files["sources/"+kind+"/snapshot.json"]) == manifest[kind+"Pins"]["snapshotHash"], "native title original snapshot pin differs")
    identity = ownership["identity"]
    require(all(identity[key] == state[key] for key in ("tokenId", "collectionId", "collectionSerial"))
        and (identity["lifecycle"] == "3") == state["burned"], "native title ownership identity differs")
    transitions = ownership["transitions"]
    require(transitions and len(transitions) == len(ownership["events"]) and identity["owner"] == transitions[-1]["to"], "native title ownership history/head differs")
    derived = original_assembly._fragment(previous, files, manifest_hash, state)
    result["legalInstrument"] = derived
    ownership_fields = result["ownershipProvenance"]
    ownership_fields["transfers"] = [{key: row[key] for key in ("from", "to", "blockNumber", "transactionHash", "logIndex")} for row in transitions]
    ownership_fields["currentOwner"] = identity["owner"]
    rows = previous.report["records"]
    require(len(rows) <= MAX_TITLE_RECORDS and len({row["recordHash"] for row in rows}) == len(rows), "native title source row bound/uniqueness")
    supported, unresolved = [], deepcopy(previous.report["missingEvidence"])
    for row in rows:
        interpretation = row["interpretation"]
        if interpretation["status"] != "typed_historical":
            unresolved.append({"recordHash": row["recordHash"], "reason": "unsupported_original_title_schema"})
            continue
        binding = row["titleBinding"]
        if binding["status"] != "matched_native_transfer":
            unresolved.append({"recordHash": row["recordHash"], "reason": binding["status"]})
            continue
        require(row["family"] in ("ACCESSION", "DEACCESSION"), "native title family differs")
        value = interpretation["value"]
        prefix = "records/" + row["recordHash"][2:]
        require(institutional.validate_payload(row["family"], files[prefix+"/payload.bin"]) == value, "native title payload interpretation differs")
        record = _record(previous, files, manifest_hash, state, row, ownership, manifest)
        index = uint(binding["transferIndex"])
        require(index < len(transitions), "native title declared transfer index")
        hop = transitions[index]; declared = value["titleBinding"]["transfer"]
        require(all(declared[key] == hop[key] for key in ("from", "to", "blockNumber", "transactionHash", "logIndex"))
            and declared["core"] == state["core"] and declared["tokenId"] == state["tokenId"]
            and declared["chainId"] == state["chainId"]
            and accession._position(hop) < accession._position(row["publication"]), "native title declared transfer differs")
        instrument = deepcopy(value["titleBinding"]["instrument"])
        instrument["hash"]["algorithm"] = uint(instrument["hash"]["algorithm"], 16)
        supported.append({"record": record, "mode": "TITLE_BINDING", "transferIndex": str(index),
            "transactionHash": hop["transactionHash"], "from": hop["from"], "to": hop["to"], "instrument": instrument})
    selected = previous.report["selectedAccession"]["recordHash"]
    require(any(row["record"] == derived["accession"] for row in supported), "native title selected accession absent from supported originals")
    retained = [row for row in ownership_fields["titleBindings"] if not (
        row["record"]["host"] == owner["host"] and row["record"]["recordType"] in TITLE_TYPES)]
    ownership_fields["titleBindings"] = retained + supported
    heads = {legacy._head_key(row): row for row in result["recordChainHeads"]}
    source_heads = set()
    for lane in owner["lanes"]:
        head = {"lane": "owner", "host": owner["host"], "scopeKey": state["tokenId"],
            "recordType": lane["recordType"], "headHash": lane["head"], "count": lane["count"]}
        key = legacy._head_key(head)
        require(key not in source_heads and uint(lane["count"]) == len(lane["records"]), "native title source lane denominator differs")
        source_heads.add(key); heads[key] = head
    require(len(heads) <= 64, "native title full packet head bound")
    result["recordChainHeads"] = [heads[key] for key in sorted(heads)]
    result = packet.validate(dumps(result))
    return {"packet": result, "coverage": deepcopy(COVERAGE),
        "selectedAccession": {"recordHash": selected, "selectionBasis": "explicit_original_accession", "canonicalCurrentAccession": False},
        "titleBindings": supported, "unresolved": unresolved}


def derive(previous_accession, accession_files, accession_manifest_hash, original_packet):
    """Caller must first replay the accession package and reconcile its other sources."""
    try: return _derive(previous_accession, accession_files, accession_manifest_hash, original_packet)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError) as exc:
        raise MuseumError("malformed native title derivation") from exc
