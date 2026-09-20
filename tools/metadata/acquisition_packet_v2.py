"""Additive packet owner-receipt references; supplied joins are not source proof.

The V1 record definition and every other role remain unchanged. Only accession
and title-binding record slots accept the new explicitly native owner variant.
"""
import argparse
import copy

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from . import genesis_dossier_profile as v1
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint

ROOT, MAX_BYTES = v1.ROOT, v1.MAX_BYTES
PACKET = "STREAM_ACQUISITION_PACKET_V2"
LEGAL_INSTRUMENT = "STREAM_ACQUISITION_LEGAL_INSTRUMENT_V2"
PROFILE = "STREAM_NATIVE_OWNER_RECORD_AUTHORITY_V1"
V1_PACKET_SCHEMA_HASH = "0x88d89a5ee0a1b15bc4c4b38e73c57f6c120bf198e03a82f7f8ad61d0f9923357"
V1_OBJECT_SCHEMA_HASH = "0xd9d328022f6c30fd3d6b961504d67f4b1732c03e4f73f1dd41b542db74982f74"
OWNER_SOURCE_PROFILE_HASH = "0x9025dcde06f0ffd69cbbf5fae55108fdb43dd3d80462cf6452963d85c81e3e6d"
OWNERSHIP_SOURCE_PROFILE_HASH = "0xee8aa538afdbab3e79051ffc52cacbae63fdb26b44557f28e28cf1709319cc6d"
RECEIPT_FIELDS = ("tokenId", "owner", "recordedAt", "recordIndex", "recordChainHash", "relayed",
    "authorizationDigest", "nonce", "deadline", "schemaDefinitionHash", "canonicalizationDefinitionHash",
    "signatureScheme", "signatureBundleHash")
PROVENANCE_FIELDS = ("acquisitionManifestHash", "ownerSourceProfileHash", "ownerAnchorHash", "ownerTranscriptHash",
    "ownerSnapshotHash", "ownershipSourceProfileHash", "ownershipAnchorHash", "ownershipTranscriptHash",
    "ownershipSnapshotHash", "originalRecordBytesHash", "originalPayloadBytesHash", "signatureBundleBytesHash")
QUALIFICATION = (
    "Prospective unregistered packet V2 and native-owner authority interpretation. Canonical validation checks "
    "only the shape and internal consistency of supplied references, receipts, chronology and byte commitments. "
    "It does not replay source packages or verify signatures, RPC provenance, cryptographic state, complete "
    "history, absence, legal title, institutional identity, actual-chain acceptance or full packet conformance. "
    "A native owner receipt remains distinct from Artist, General or institutional authority classes.")
RULES = [
    "The exact V1 record shape remains unchanged. Only legalInstrument.accession and ownershipProvenance.titleBindings[].record admit the additive native owner record variant.",
    "Packet version is numeric2. Native authority discriminator is kind=native_owner_receipt, version=string1. No numeric authorityClass is assigned or synthesized.",
    "All thirteen Receipt fields retain their original names, order and integer widths. Common recordHash remains the native record hash; provenance originalRecordBytesHash commits the exact extracted original.json bytes, not that native hash.",
    "signer=receipt.owner=ownerState.transfer.to; original token/subject, publication block and source context agree. The owner-state transfer strictly precedes publication. Same-height supplied block hashes and same-transaction coordinates agree.",
    "Across all native references, block-number/hash and transaction/index mappings agree, distinct events cannot occupy one block log slot, and supplied log order agrees with transaction order. ownerState.sourceBlockTimestamp is the common observed source-block timestamp, never later than sourceState.examinedAt. Publication timestamps agree at each supplied height including the source block and never decrease over supplied heights; no missing ancestry is inferred.",
    "Full packets join ownerState.transferIndex to the last supplied token transfer before publication. Native owner title bindings must also reference a transfer before their publication. Fragment validation has no independent transfer-history denominator.",
    "Full packets require a matching native owner head for host/token/recordType, recordIndex below its count and final indexed receipt recordChainHash equal to its headHash. Supplied native records at the same host/token/type/index must agree on original recordHash and receipt; distinct supplied indices must follow strictly increasing publication block/log order, with gaps allowed. Fragments have no head input and do not claim the head join.",
    "Direct receipts have zero authorizationDigest/nonce/deadline and DIRECT signatureScheme. Relayed receipts preserve nonzero digest, EIP712 or ERC1271 scheme and deadline>=recordedAt. SignatureBundleHash equals provenance.signatureBundleBytesHash; original bundle verification requires separately replayed bytes.",
    "Exact public owner-catalogue and ownership source profile commitments are fixed. Provenance hashes commit supplied evidence, never authenticate their own origin. Only the separately replaying adapter may report evidence verification.",
    "Repeated (host,native recordHash) references must be exactly equal across both legacy and native-owner variants. All original V1 structural and semantic joins remain in force.",
]
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_interpretation_profile",
    "baseSchemaHashes": {v1.PACKET: V1_PACKET_SCHEMA_HASH, v1.OBJECT: V1_OBJECT_SCHEMA_HASH},
    "sourceProfileHashes": {"STREAM_MUSEUM_PUBLIC_OWNER_CATALOG_SOURCE_V1": OWNER_SOURCE_PROFILE_HASH,
        "STREAM_MUSEUM_PUBLIC_CORE_OWNERSHIP_HISTORY_V1": OWNERSHIP_SOURCE_PROFILE_HASH},
    "receiptFields": list(RECEIPT_FIELDS), "provenanceFields": list(PROVENANCE_FIELDS),
    "bounds": {"packetBytes": str(MAX_BYTES), "integerRepresentation": "unsigned decimal strings at declared native widths"},
    "rules": RULES, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def definitions():
    """Copy original definitions, changing only packet identity and two record slots."""
    d = copy.deepcopy(v1.definitions())
    r, closed = v1.ref, v1.closed
    receipt_types = ("uint256", "address", "uint64", "uint64", "hash", None, "hash0", "uint256",
        "uint64", "hash", "hash", "hash", "hash")
    d["nativeOwnerReceipt"] = closed({name: {"type": "boolean"} if kind is None else r(kind)
        for name, kind in zip(RECEIPT_FIELDS, receipt_types)})
    d["nativeOwnerPublication"] = closed({"blockHash": r("hash"), "blockNumber": r("uint64"),
        "transactionHash": r("hash"), "transactionIndex": r("uint64"), "logIndex": r("uint32")})
    d["nativeOwnerTransfer"] = closed({"from": r("address0"), "to": r("address"),
        **copy.deepcopy(d["nativeOwnerPublication"]["properties"])})
    d["nativeOwnerState"] = closed({"transferIndex": r("uint64"), "transfer": r("nativeOwnerTransfer"),
        "sourceBlockHash": r("hash"), "sourceBlockTimestamp": r("uint64")})
    provenance = {name: r("hash") for name in PROVENANCE_FIELDS}
    provenance["ownerSourceProfileHash"] = {"const": OWNER_SOURCE_PROFILE_HASH}
    provenance["ownershipSourceProfileHash"] = {"const": OWNERSHIP_SOURCE_PROFILE_HASH}
    d["nativeOwnerProvenance"] = closed(provenance)
    d["nativeOwnerAuthority"] = closed({"kind": {"const": "native_owner_receipt"}, "version": {"const": "1"},
        "receipt": r("nativeOwnerReceipt"), "publication": r("nativeOwnerPublication"),
        "ownerState": r("nativeOwnerState"), "provenance": r("nativeOwnerProvenance")})
    fields = copy.deepcopy(d["record"]["properties"])
    del fields["authorityClass"]
    fields["subjectKind"] = {"const": "token"}
    fields["authority"] = r("nativeOwnerAuthority")
    d["nativeOwnerRecord"] = closed(fields)
    variant = v1.choice(r("record"), r("nativeOwnerRecord"))
    d["legalInstrument"]["oneOf"][0]["properties"]["accession"] = copy.deepcopy(variant)
    d["titleBinding"]["properties"]["record"] = copy.deepcopy(variant)
    d["packet"]["properties"]["schema"] = {"const": PACKET}
    d["packet"]["properties"]["version"] = {"const": 2}
    return d


def _schema(name, root):
    d = definitions(); pending, selected = [root], {}
    while pending:
        key = pending.pop()
        if key in selected: continue
        selected[key] = d[key]
        pending.extend(row["$ref"].split("/")[-1] for row in v1._walk(d[key]) if "$ref" in row)
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + name,
        "title": name, "description": QUALIFICATION, **v1.ref(root), "$defs": selected,
        "x-stream-native-owner-authority-profile": {"name": PROFILE, "hash": PROFILE_HASH},
        "x-stream-constraints": [*v1.CONSTRAINTS, *RULES],
        **({"x-stream-CMC-ACQUISITION-PACKET": v1.PACKET_REQUIREMENTS} if root == "packet" else {})}


PACKET_SCHEMA_BYTES = dumps(_schema(PACKET, "packet"))
PACKET_SCHEMA_HASH = keccak256(PACKET_SCHEMA_BYTES)
LEGAL_INSTRUMENT_SCHEMA_BYTES = dumps(_schema(LEGAL_INSTRUMENT, "legalInstrument"))
LEGAL_INSTRUMENT_SCHEMA_HASH = keccak256(LEGAL_INSTRUMENT_SCHEMA_BYTES)


def schema_document_bytes():
    return {PACKET: PACKET_SCHEMA_BYTES, LEGAL_INSTRUMENT: LEGAL_INSTRUMENT_SCHEMA_BYTES}


def documents():
    return {**schema_document_bytes(), PROFILE: PROFILE_BYTES}


def _source_context(source):
    defs = definitions()
    Draft202012Validator({"$defs": defs, **v1.ref("sourceState")}).validate(source)
    v1._typed(source, v1.ref("sourceState"), defs)
    v1.need(all(uint(source[k]) > 0 for k in ("chainId", "collectionId", "tokenId", "collectionSerial")),
        "native owner nonzero source identity")
    v1.need(source["subjectId"] == subject_id("token", source["chainId"], source["core"], source["collectionId"],
        token_id=source["tokenId"]) and source["collectionSubjectId"] == subject_id(
        "collection", source["chainId"], source["core"], source["collectionId"]), "native owner source subjects")


def _before(transfer, publication):
    first, second = uint(transfer["blockNumber"]), uint(publication["blockNumber"])
    return first < second or (first == second and uint(transfer["logIndex"]) < uint(publication["logIndex"]))


def _owner_record(record, source):
    authority = record["authority"]
    receipt, publication, state, provenance = (authority[k] for k in ("receipt", "publication", "ownerState", "provenance"))
    transfer = state["transfer"]
    v1.need(record["subjectKind"] == "token" and record["subjectId"] == source["subjectId"]
        and receipt["tokenId"] == source["tokenId"], "native owner record token/subject join")
    v1.need(record["signer"] == receipt["owner"] == transfer["to"], "native owner signer/receipt/prior holder join")
    v1.need(record["recordedBlock"] == publication["blockNumber"]
        and uint(record["recordedBlock"]) <= uint(source["blockNumber"])
        and uint(receipt["recordedAt"]) <= uint(state["sourceBlockTimestamp"]) <= uint(source["examinedAt"]),
        "native owner publication source context")
    v1.need(publication["blockNumber"] != source["blockNumber"] or receipt["recordedAt"] == state["sourceBlockTimestamp"],
        "native owner source-block publication timestamp differs")
    v1.need(state["sourceBlockHash"] == source["blockHash"], "native owner observation block differs")
    v1.need((uint(state["transferIndex"]) == 0) == (transfer["from"] == v1.ZERO_ADDRESS),
        "native owner original mint index")
    v1.need(_before(transfer, publication), "native owner transfer must precede publication")
    # These are only contradictions among supplied coordinates, not receipt proofs.
    v1.need((transfer["blockNumber"] == publication["blockNumber"]) == (transfer["blockHash"] == publication["blockHash"]),
        "native owner same-height block hash differs")
    for row in (transfer, publication):
        v1.need((row["blockNumber"] == source["blockNumber"]) == (row["blockHash"] == source["blockHash"]),
            "native owner source block hash/number differs")
    same_block = transfer["blockNumber"] == publication["blockNumber"]
    same_transaction = transfer["transactionHash"] == publication["transactionHash"]
    if same_block:
        v1.need(uint(transfer["transactionIndex"]) <= uint(publication["transactionIndex"])
            and (transfer["transactionIndex"] == publication["transactionIndex"]) == same_transaction,
            "native owner same-block transaction coordinates")
    else:
        v1.need(not same_transaction, "native owner transaction occurs in different blocks")
    if receipt["relayed"]:
        v1.need(receipt["authorizationDigest"] != v1.ZERO and receipt["signatureScheme"] in
            (keccak256(b"EIP712"), keccak256(b"ERC1271"))
            and uint(receipt["deadline"]) >= uint(receipt["recordedAt"]), "native owner relayed receipt")
    else:
        v1.need(receipt["authorizationDigest"] == v1.ZERO and receipt["nonce"] == receipt["deadline"] == "0"
            and receipt["signatureScheme"] == keccak256(b"DIRECT"), "native owner direct receipt")
    v1.need(receipt["signatureBundleHash"] == provenance["signatureBundleBytesHash"],
        "native owner signature bundle hash differs")


def _record_context(value, source, ownership=None, heads=None):
    definitions_ = definitions()
    legacy_keys, owner_keys = (set(definitions_[name]["properties"]) for name in ("record", "nativeOwnerRecord"))
    seen = {}
    number_hashes = {uint(source["blockNumber"]): source["blockHash"]}
    hash_numbers = {source["blockHash"]: uint(source["blockNumber"])}
    timestamps = {}
    transactions, transaction_slots, log_slots, transfer_indices, native_indices = {}, {}, {}, {}, {}
    native_records = []

    def observe(row, event_kind, identity):
        number, block_hash = uint(row["blockNumber"]), row["blockHash"]
        v1.need((number not in number_hashes or number_hashes[number] == block_hash)
            and (block_hash not in hash_numbers or hash_numbers[block_hash] == number),
            "native owner shared block mapping differs")
        number_hashes[number], hash_numbers[block_hash] = block_hash, number
        tx, tx_index, log_index = row["transactionHash"], uint(row["transactionIndex"]), uint(row["logIndex"])
        coordinate = (number, block_hash, tx_index)
        slot = (block_hash, tx_index)
        v1.need((tx not in transactions or transactions[tx] == coordinate)
            and (slot not in transaction_slots or transaction_slots[slot] == tx),
            "native owner shared transaction mapping differs")
        transactions[tx], transaction_slots[slot] = coordinate, tx
        log_slot, observation = (block_hash, log_index), (tx, tx_index, event_kind, identity)
        v1.need(log_slot not in log_slots or log_slots[log_slot] == observation,
            "native owner conflicting shared block log slot")
        log_slots[log_slot] = observation

    for record in v1._walk(value):
        if set(record) not in (legacy_keys, owner_keys): continue
        key = (record["host"], record["recordHash"])
        v1.need(key not in seen or seen[key] == record, "contradictory repeated record reference")
        seen[key] = record
        if set(record) == legacy_keys: continue
        _owner_record(record, source)
        native_records.append(record)
        authority = record["authority"]
        receipt = authority["receipt"]
        native_index = (record["host"], receipt["tokenId"], record["recordType"], receipt["recordIndex"])
        original = (record["recordHash"], dumps(receipt))
        v1.need(native_index not in native_indices or native_indices[native_index] == original,
            "native owner shared record index differs")
        native_indices[native_index] = original
        publication, owner_state = authority["publication"], authority["ownerState"]
        source_number, source_time = uint(source["blockNumber"]), uint(owner_state["sourceBlockTimestamp"])
        v1.need(source_number not in timestamps or timestamps[source_number] == source_time,
            "native owner source block timestamp differs across references")
        timestamps[source_number] = source_time
        observe(publication, "owner_publication", key)
        transfer = owner_state["transfer"]
        observe(transfer, "core_transfer", (transfer["from"], transfer["to"]))
        index, transfer_bytes = uint(owner_state["transferIndex"]), dumps(transfer)
        v1.need(index not in transfer_indices or transfer_indices[index] == transfer_bytes,
            "native owner shared transfer index differs")
        transfer_indices[index] = transfer_bytes
        number, recorded_at = uint(publication["blockNumber"]), uint(authority["receipt"]["recordedAt"])
        v1.need(number not in timestamps or timestamps[number] == recorded_at,
            "native owner shared publication timestamp differs")
        timestamps[number] = recorded_at
        if ownership is not None:
            state = record["authority"]["ownerState"]; index = uint(state["transferIndex"])
            transfers = ownership["transfers"]
            v1.need(index < len(transfers) and all(state["transfer"][k] == transfers[index][k] for k in transfers[index]),
                "native owner prior transfer index/history differs")
            previous = [i for i, hop in enumerate(transfers) if _before(hop, record["authority"]["publication"])]
            v1.need(previous and previous[-1] == index, "native owner state is not last transfer before publication")
    ordered_timestamps = [stamp for _, stamp in sorted(timestamps.items())]
    v1.need(ordered_timestamps == sorted(ordered_timestamps), "native owner supplied block time regresses")
    by_block = {}
    for (block_hash, log_index), observation in log_slots.items():
        by_block.setdefault(block_hash, []).append((log_index, observation[1]))
    for slots in by_block.values():
        indices = [index for _, index in sorted(slots)]
        v1.need(indices == sorted(indices), "native owner shared transaction/log order differs")
    lane_positions = {}
    for record in native_records:
        receipt, publication = (record["authority"][k] for k in ("receipt", "publication"))
        lane = (record["host"], receipt["tokenId"], record["recordType"])
        lane_positions.setdefault(lane, {})[uint(receipt["recordIndex"])] = (
            uint(publication["blockNumber"]), uint(publication["logIndex"]))
    for positions in lane_positions.values():
        ordered = [position for _, position in sorted(positions.items())]
        v1.need(all(before < after for before, after in zip(ordered, ordered[1:])),
            "native owner record index publication order differs")
    if heads is not None:
        head_map = {v1._head_key(head): head for head in heads}
        for record in native_records:
            receipt = record["authority"]["receipt"]
            key = ("owner", record["host"], receipt["tokenId"], record["recordType"])
            v1.need(key in head_map, "native owner matching record head missing")
            head = head_map[key]
            index, count = uint(receipt["recordIndex"]), uint(head["count"])
            v1.need(index < count, "native owner record index exceeds supplied head count")
            v1.need(index + 1 != count or receipt["recordChainHash"] == head["headHash"],
                "native owner last receipt chain differs from supplied head")


def _parse(raw, schema_bytes):
    v1.need(type(raw) is bytes, "exact bytes required")
    value = loads(raw, maximum=MAX_BYTES, canonical=True)
    definition = loads(schema_bytes, maximum=MAX_BYTES)
    Draft202012Validator(definition).validate(value)
    v1._typed(value, definition, definition["$defs"])
    v1._references(value)
    return value


def validate(raw):
    """Validate a complete V2 packet's supplied data; never authenticate sources."""
    try:
        value = _parse(raw, PACKET_SCHEMA_BYTES)
        v1._packet(value)
        _record_context(value, value["sourceState"], value["ownershipProvenance"], value["recordChainHeads"])
        for binding in value["ownershipProvenance"]["titleBindings"]:
            if "authority" in binding["record"]:
                hop = value["ownershipProvenance"]["transfers"][uint(binding["transferIndex"])]
                v1.need(_before(hop, binding["record"]["authority"]["publication"]),
                    "native owner title transfer must precede publication")
        return value
    except (ValidationError, MuseumError, ValueError, TypeError, KeyError, IndexError, RecursionError) as exc:
        if isinstance(exc, v1.DossierError): raise
        raise v1.DossierError(str(exc)) from exc


def validate_legal_instrument(raw, source_state):
    """Validate an item9 fragment and source context, without a history denominator."""
    try:
        _source_context(source_state)
        value = _parse(raw, LEGAL_INSTRUMENT_SCHEMA_BYTES)
        v1._record_context(value, source_state)
        _record_context(value, source_state)
        if value["status"] == "recorded":
            v1.need(v1._kind(value["accession"], "ACCESSION"), "accession instrument")
        return value
    except (ValidationError, MuseumError, ValueError, TypeError, KeyError, IndexError, RecursionError) as exc:
        if isinstance(exc, v1.DossierError): raise
        raise v1.DossierError(str(exc)) from exc


def outputs():
    return {"schemas/records/" + PACKET + ".json": PACKET_SCHEMA_BYTES,
        "schemas/records/" + LEGAL_INSTRUMENT + ".json": LEGAL_INSTRUMENT_SCHEMA_BYTES,
        "schemas/records/profiles/" + PROFILE + ".json": PROFILE_BYTES}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for name, expected in ((v1.PACKET, V1_PACKET_SCHEMA_HASH), (v1.OBJECT, V1_OBJECT_SCHEMA_HASH)):
        v1.need(keccak256((ROOT / "schemas/records" / (name + ".json")).read_bytes()) == expected,
            "original schema bytes differ")
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: v1.need(destination.is_file() and destination.read_bytes() == raw, "generated bytes differ: " + path)
        else: destination.parent.mkdir(parents=True, exist_ok=True); destination.write_bytes(raw)
    print("Additive packet V2 and native owner authority definitions match; supplied joins only.")


if __name__ == "__main__": main()
