"""Join an exact acquisition ACCESSION to original owner and token history.

An acquisition selection is an explicit documentary choice, not a new native
latest-record rule. Original owner authority is retained without inventing the
numeric Artist authority required by the older generic packet record schema.
"""
from bisect import bisect_left
from copy import deepcopy

from . import institutional
from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_rpc import quantity
from .dossier_gather_records import _interpret, _wire
from .independent_wire import ZERO_ADDRESS, require
from .public_chain_history import LOG_FIELDS, MAX_LOGS, MAX_RECEIPTS, MAX_TOUCHED_BLOCKS, _matches
from .public_history_rpc import MAX_TRANSCRIPT, PublicReplayTransport

MODE = "acquisition_accession_history"
PROFILE = "STREAM_MUSEUM_ACQUISITION_ACCESSION_HISTORY_V1"
INPUTS = {"anchor.json", "transcript.json", "snapshot.json"}
PIN_NAMES = {"profileHash", "anchorHash", "transcriptHash", "snapshotHash", "provenance"}
MAX_INSTITUTIONAL_RECORDS, MAX_DOCUMENTS = 256, 128
CLAIMS = {"originalSourcesReplayed": True, "allAdmittedOwnerLanesRetained": True,
    "historicalReceiptOwnersReconciled": True, "selectedTitleTransferVerified": True,
    "transferPrecedesSourcePublicationChecked": True, "sameBlockLogOrderChecked": True,
    "providerLogCompletenessTrusted": True, "providerCanonicalMappingTrusted": True,
    "canonicalCurrentAccessionDerived": False, "globalHostCompleteness": False,
    "canonicalPacketEmitted": False, "fullAcquisitionItem10": False,
    "legalTitleProven": False, "custodyTransferred": False, "institutionIdentityProven": False,
    "actualChainAcceptance": False, "sourceConsensusVerified": False,
    "sourceProvenanceSelfAuthenticated": False, "networkObjectFetch": False}
QUALIFICATION = ("One explicitly selected original ACCESSION and every ACCESSION/DEACCESSION occurrence "
    "in one admitted native OwnerRecords host are joined to the exact Core token history. Historical owner "
    "receipts, native publication order and instrument commitments remain distinct from legal title, physical "
    "custody and institutional identity. Unknown schemas and missing referenced bytes remain explicit. "
    "Filtered RPC history completeness and canonical mapping remain trusted. This is not a global current "
    "ACCESSION selection, a full protocol event archive, or a canonical acquisition packet.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "sources": ["STREAM_MUSEUM_PUBLIC_OWNER_CATALOG_SOURCE_V1", "STREAM_MUSEUM_PUBLIC_CORE_OWNERSHIP_HISTORY_V1"],
    "selection": "Exact host, token and original ACCESSION hash selected for this acquisition; no latest rule.",
    "interpretation": "Original receipt schema/JCS commitments must match the retained exact implemented definitions.",
    "chronology": "All original owner receipt authors reconcile to the last Core Transfer strictly before publication. "
        "TITLE_BINDING matches chain/Core/token/block/transaction/log/from/to and strictly precedes publication.",
    "authority": "Explicit historical_native_owner_receipt; no numeric authorityClass is invented.",
    "documents": "Public supplied bytes keyed by Keccak256(JCS(HashRef)); exact RAW_BYTES Keccak/SHA256 only; never fetched.",
    "bounds": {"institutionalRecords": str(MAX_INSTITUTIONAL_RECORDS), "documents": str(MAX_DOCUMENTS),
        "documentBytes": "1048576", "aggregateDocumentBytes": "16777216"},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "accession requires explicit public disclosure before source reads")


def _sources():
    from . import public_owner_catalog_source as owner
    from . import public_ownership_source as ownership
    return {"owner": (owner.PublicOwnerCatalogSource, owner.PROFILE_BYTES, owner.PROFILE_HASH),
        "ownership": (ownership.PublicOwnershipSource, ownership.PROFILE_BYTES, ownership.PROFILE_HASH)}


def _capture(kind, files, pins):
    require(type(files) is dict and set(files) == INPUTS, "accession exact source triplet required")
    base._bounded(files)
    require(type(pins) is dict and set(pins) == PIN_NAMES
        and pins["provenance"] in ("synthetic_fixture", "trusted_rpc"), "accession explicit source pins/provenance required")
    constructor, _, profile_hash = _sources()[kind]
    require(pins["profileHash"] == profile_hash, "accession source profile differs")
    for name, maximum in (("anchor", 524288), ("transcript", MAX_TRANSCRIPT), ("snapshot", MAX_BYTES)):
        raw, digest = files[name + ".json"], pins[name + "Hash"]
        require(type(raw) is bytes and 0 < len(raw) <= maximum and any(hex_bytes(digest, 32))
            and keccak256(raw) == digest, "accession original source pin/bound differs")
    source = constructor(files["anchor.json"], PublicReplayTransport(files["transcript.json"], pins["transcriptHash"]),
        provenance=pins["provenance"])
    raw = source.snapshot()
    require(raw == files["snapshot.json"] and source.transcript() == files["transcript.json"],
        "accession original source reconstruction differs")
    return source, loads(raw, maximum=MAX_BYTES, canonical=True)


def _key(log):
    return log["blockHash"], log["transactionHash"], quantity(log["logIndex"])


def _position(value):
    return tuple(uint(value[k]) for k in ("blockNumber", "transactionIndex", "logIndex"))


def _join(owner, ownership):
    from .owner_catalog_source import ADMISSION_EVENT, RECORD_EVENT
    from .ownership_source import TRANSFER
    a, b = owner.a, ownership.a
    require(all(a[k] == b[k] for k in ("chainId", "core", "tokenId", "blockNumber", "blockHash",
        "timestamp", "stateRoot", "environment", "deploymentEvidenceHash")), "accession source anchors differ")
    require(owner.pins[a["core"]] == b["coreRuntimeHash"], "accession shared Core runtime differs")
    require(owner.provenance == ownership.provenance, "accession source provenance differs")
    token = "0x" + uint(a["tokenId"]).to_bytes(32, "big").hex()
    filters = [{"address": a["host"], "topics": [ADMISSION_EVENT]},
        {"address": a["host"], "topics": [RECORD_EVENT, token]},
        {"address": a["core"], "topics": [TRANSFER, None, None, token]}]
    reads, headers, receipts, logs, code = {}, {}, {}, {}, {}
    for source in (owner, ownership):
        for row in source.reader.rows:
            key = dumps([row["method"], row["params"]])
            outcome = dumps({k: row[k] for k in ("result", "limit") if k in row})
            require(key not in reads or reads[key] == outcome, "accession shared RPC response differs")
            reads[key] = outcome
            if "result" not in row:
                continue
            result, method = row["result"], row["method"]
            if method == "eth_getCode":
                address, block = row["params"]
                require(block == {"blockHash": a["blockHash"], "requireCanonical": True}, "accession code anchor differs")
                digest = keccak256(hex_bytes(result))
                require(address not in code or code[address] == digest, "accession shared observed code differs")
                code[address] = digest
            elif method in ("eth_getBlockByHash", "eth_getBlockByNumber"):
                number = quantity(result["number"])
                require(number not in headers or headers[number] == result, "accession shared canonical header differs")
                headers[number] = result
            elif method == "eth_getTransactionReceipt":
                tx = result["transactionHash"]
                require(tx not in receipts or receipts[tx] == result, "accession shared receipt differs")
                receipts[tx] = result
            elif method == "eth_getLogs":
                for raw in result:
                    log = {k: raw[k] for k in LOG_FIELDS}
                    key = _key(log)
                    require(key not in logs or logs[key] == log, "accession shared log differs")
                    logs[key] = log
    require(len(logs) <= MAX_LOGS and len(headers) <= MAX_TOUCHED_BLOCKS and len(receipts) <= MAX_RECEIPTS,
        "accession combined history bound")
    previous, transactions = None, {}
    for number, header in sorted(headers.items()):
        if previous is not None:
            require(quantity(previous["timestamp"]) <= quantity(header["timestamp"]), "accession union header time regresses")
            if quantity(previous["number"]) + 1 == number:
                require(header["parentHash"] == previous["hash"], "accession union adjacent parent differs")
        for tx in header["transactions"]:
            require(tx not in transactions or transactions[tx] == header["hash"], "accession union transaction blocks differ")
            transactions[tx] = header["hash"]
        previous = header
    positions, matched = {}, {}
    for receipt in receipts.values():
        for raw in receipt["logs"]:
            log = {k: raw[k] for k in LOG_FIELDS}
            pos = (log["blockHash"], quantity(log["logIndex"]))
            require(pos not in positions, "accession union duplicate block log position")
            positions[pos] = quantity(log["transactionIndex"])
            if any(_matches(log, f) for f in filters):
                matched[_key(log)] = log
    require(matched == logs, "accession union query/receipt matching logs differ")
    by_block = {}
    for (block_hash, log_index), tx_index in positions.items():
        by_block.setdefault(block_hash, []).append((log_index, tx_index))
    for positions in by_block.values():
        order = [tx for _, tx in sorted(positions)]
        require(order == sorted(order), "accession union transaction/log order differs")
    return {"logs": str(len(logs)), "touchedBlocks": str(len(headers)), "receipts": str(len(receipts))}


def _record(row, anchor):
    record, receipt = row["record"], row["receipt"]
    return {"lane": "owner", "recordHash": row["recordHash"], "host": anchor["host"],
        "subjectId": record[1], "subjectKind": "token", "recordType": record[0], "schemaId": record[2],
        "recordedBlock": row["publication"]["blockNumber"],
        "authority": {"kind": "historical_native_owner_receipt", "owner": receipt[1],
            "relayed": receipt[5], "signatureScheme": receipt[11]}}


def _binding(value, publication, transitions, transfer_indices):
    transfer = value["titleBinding"]["transfer"]
    key = (transfer["blockNumber"], transfer["transactionHash"], transfer["logIndex"])
    index = transfer_indices.get(key)
    if index is None:
        return {"status": "unmatched_native_transfer", "declared": transfer, "transferIndex": None}
    actual = transitions[index]
    if any(transfer[k] != actual[k] for k in ("from", "to")):
        return {"status": "unmatched_native_transfer", "declared": transfer, "transferIndex": str(index)}
    if _position(actual) >= _position(publication):
        return {"status": "transfer_follows_publication", "declared": transfer, "transferIndex": str(index)}
    return {"status": "matched_native_transfer", "declared": transfer, "transferIndex": str(index),
        "transactionIndex": actual["transactionIndex"], "transferPrecedesPublication": True}


def _documents(documents):
    require(type(documents) is dict and len(documents) <= MAX_DOCUMENTS
        and all(type(v) is bytes and 0 < len(v) <= 1048576 for v in documents.values())
        and sum(map(len, documents.values())) <= 16777216, "accession public document bounds")
    for key in documents:
        require(any(hex_bytes(key, 32)), "accession public document key")


def _derive(owner, owner_snapshot, ownership, ownership_snapshot, selection, documents):
    a, identity = owner.a, ownership_snapshot["identity"]
    state = {k: a[k] for k in ("chainId", "core", "tokenId", "blockNumber", "blockHash", "timestamp")}
    state.update({k: identity[k] for k in ("collectionId", "collectionSerial", "lifecycle")})
    state["subjectId"] = subject_id("token", a["chainId"], a["core"], identity["collectionId"], token_id=a["tokenId"])
    require(type(selection) is dict and set(selection) == {"profile", "host", "tokenId", "accessionRecordHash"}
        and selection["profile"] == PROFILE and selection["host"] == a["host"] and selection["tokenId"] == a["tokenId"]
        and any(hex_bytes(selection["accessionRecordHash"], 32)), "accession explicit original selection differs")
    transitions = ownership_snapshot["transitions"]
    positions = [_position(row) for row in transitions]
    require(positions == sorted(set(positions)), "accession transfer order differs")
    indices = {(t["blockNumber"], t["transactionHash"], t["logIndex"]): i for i, t in enumerate(transitions)}
    all_rows, rows, files, used, missing = owner_snapshot["records"], [], {}, set(), []
    families = {schema_id(name): name for name in ("ACCESSION", "DEACCESSION")}
    require(sum(r["record"][0] in families for r in all_rows) <= MAX_INSTITUTIONAL_RECORDS,
        "accession institutional record bound")
    chosen = None
    for original in sorted(all_rows, key=lambda r: _position(r["publication"])):
        publication, receipt = original["publication"], original["receipt"]
        at = bisect_left(positions, _position(publication)) - 1
        require(at >= 0 and positions[at] != _position(publication)
            and transitions[at]["to"] != ZERO_ADDRESS and transitions[at]["to"] == receipt[1],
            "accession historical receipt owner differs from native transfer history")
        family = families.get(original["record"][0])
        if family is None:
            continue
        wire = _wire("owner", original)
        interpretation, _ = _interpret("owner", wire, state, "exact_token")
        record = _record(original, a)
        row = {"recordHash": original["recordHash"], "family": family, "record": record,
            "publication": publication, "interpretation": interpretation, "ownerHistoryIndex": str(at)}
        prefix = "records/" + original["recordHash"][2:]
        files[prefix + "/original.json"] = dumps(original)
        files[prefix + "/payload.bin"] = wire["payload"]
        files[prefix + "/signature-bundle.bin"] = hex_bytes(original["signatureBundleHex"])
        if interpretation["status"] == "typed_historical":
            value = interpretation["value"]
            row["titleBinding"] = _binding(value, publication, transitions, indices)
            references = []
            for path, reference in institutional._references(value):
                evidence = institutional._evidence(reference, documents)
                entry = {"sourcePath": path, "reference": reference, **evidence}
                if evidence["bytesVerified"]:
                    key = evidence["hashRefKey"]; used.add(key)
                    entry["path"] = "documents/" + key[2:] + ".bin"
                    files[entry["path"]] = documents[key]
                else:
                    missing.append({"recordHash": original["recordHash"], "sourcePath": path,
                        "reference": reference, "reason": "referenced_bytes_not_supplied"})
                references.append(entry)
            row["references"] = references
            if row["titleBinding"]["status"] != "matched_native_transfer":
                missing.append({"recordHash": original["recordHash"], "sourcePath": "/titleBinding/transfer",
                    "reason": row["titleBinding"]["status"]})
        else:
            missing.append({"recordHash": original["recordHash"], "sourcePath": "",
                "reason": interpretation["reason"]})
        if original["recordHash"] == selection["accessionRecordHash"]:
            require(family == "ACCESSION" and interpretation["status"] == "typed_historical",
                "accession selected original schema/payload unsupported")
            require(row["titleBinding"]["status"] == "matched_native_transfer",
                "accession selected TITLE_BINDING does not precede publication or match native transfer")
            instrument = next(r for r in row["references"] if r["sourcePath"] == "/titleBinding/instrument")
            chosen = {"recordHash": row["recordHash"], "record": record, "publication": publication,
                "instrument": value["titleBinding"]["instrument"], "instrumentEvidence": instrument,
                "titleBinding": row["titleBinding"], "accessionIdentifier": value["accessionIdentifier"],
                "acquiringInstitution": value["acquiringInstitution"], "custodian": value["titleBinding"]["custodian"]}
        rows.append(row)
    require(chosen is not None, "accession selected original missing from admitted host")
    require(used == set(documents), "accession unreferenced public document supplied")
    return state, chosen, rows, files, missing


def compose(owner_files, owner_pins, ownership_files, ownership_pins, selection_bytes, selection_hash,
            *, disclosure, documents=None):
    _public(disclosure)
    documents = {} if documents is None else documents
    _documents(documents)
    require(type(selection_bytes) is bytes and 0 < len(selection_bytes) <= 4096
        and any(hex_bytes(selection_hash, 32)) and keccak256(selection_bytes) == selection_hash,
        "accession external selection pin/bound differs")
    selection = loads(selection_bytes, maximum=4096, canonical=True)
    owner, owner_snapshot = _capture("owner", owner_files, owner_pins)
    ownership, ownership_snapshot = _capture("ownership", ownership_files, ownership_pins)
    counts = _join(owner, ownership)
    state, chosen, rows, files, missing = _derive(owner, owner_snapshot, ownership, ownership_snapshot, selection, documents)
    from . import public_chain_history as history
    from . import public_history_rpc as rpc
    from .account_profile import JCS_BYTES
    files.update({"inputs/selection.json": selection_bytes, "definitions/acquisition-profile.json": PROFILE_BYTES,
        "definitions/institutional-profile.json": institutional.PROFILE_BYTES,
        "definitions/RFC8785_JCS.json": JCS_BYTES, "definitions/public-history-profile.json": history.PROFILE_BYTES,
        "definitions/public-rpc-profile.json": rpc.PROFILE_BYTES})
    for family in ("ACCESSION", "DEACCESSION"):
        files["definitions/" + institutional.NAMES[family] + ".json"] = institutional.SCHEMAS[family]
    for kind, source_files in (("owner", owner_files), ("ownership", ownership_files)):
        files.update({"sources/" + kind + "/" + p: b for p, b in source_files.items()})
        files["definitions/" + kind + "-source-profile.json"] = _sources()[kind][1]
    files["accession/selected.json"] = dumps(chosen)
    files["accession/records.json"] = dumps(rows)
    files["ownership/transfers.jsonl"] = ownership_snapshot["tokenTransferJsonl"].encode("utf-8")
    items = {"9": {"status": "derived_within_source_profile", "canonicalPacketCompatible": False,
        "remaining": ["Canonical packet v1 generic record requires numeric authorityClass; native OwnerRecords has none.",
            "Instrument byte availability is reported separately; no legal-validity or institution-identity determination."]},
        "10": {"status": "partial", "remaining": ["Complete protocol event-history archive is not supplied.",
            "All prior/unregistered OwnerRecords hosts are not enumerated; unmatched and unsupported statements remain explicit."]}}
    report = {"profile": PROFILE, "provenance": owner.provenance, "sourceState": state,
        "selectedAccession": chosen, "records": rows,
        "ownership": {"currentOwner": ownership_snapshot["identity"]["owner"],
            "transitions": ownership_snapshot["transitions"], "unionCounts": counts},
        "missingEvidence": missing, "items": items, "claims": CLAIMS, "qualification": QUALIFICATION}
    files["acquisition/report.json"] = dumps(report)
    files["acquisition/examination.md"] = ("# Acquisition instrument and token history\n\n" + QUALIFICATION
        + "\n\nSelected ACCESSION: `" + chosen["recordHash"] + "`.\n\nInstrument bytes: `"
        + chosen["instrumentEvidence"]["status"] + "`.\n\nThe native title transfer precedes the original publication. "
        + "The original owner receipt is retained under `authority`; no numeric authority class is fabricated.\n\n"
        + "Item 9 has source-backed documentary evidence. Canonical packet v1 owner-authority representation remains unresolved. "
        + "Item 10 remains partial. See `report.json` for every missing byte reference and unmatched historical statement.\n").encode("utf-8")
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "ownerPins": deepcopy(owner_pins), "ownershipPins": deepcopy(ownership_pins), "selectionHash": selection_hash,
        "documents": sorted(documents), "files": [base._ref(p, b) for p, b in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "accession manifest bound")
    files["manifest.json"] = raw
    base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "accession external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "ownerPins",
        "ownershipPins", "selectionHash", "documents", "files", "claims", "qualification"}
        and value["mode"] == MODE and value["profile"] == PROFILE and value["version"] == "1"
        and value["profileHash"] == PROFILE_HASH and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION,
        "accession closed manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "accession original file commitments differ")
    require(type(value["documents"]) is list and len(value["documents"]) <= MAX_DOCUMENTS
        and all(type(key) is str for key in value["documents"])
        and value["documents"] == sorted(set(value["documents"])), "accession document index differs")
    for key in value["documents"]:
        require(any(hex_bytes(key, 32)), "accession invalid document index key")
    needed = {"inputs/selection.json"} | {"sources/" + k + "/" + p for k in ("owner", "ownership") for p in INPUTS}
    needed |= {"documents/" + k[2:] + ".bin" for k in value["documents"]}
    require(needed <= set(files), "accession required original file missing")
    originals = [{p: files["sources/" + k + "/" + p] for p in INPUTS} for k in ("owner", "ownership")]
    result = compose(originals[0], value["ownerPins"], originals[1], value["ownershipPins"], files["inputs/selection.json"],
        value["selectionHash"], disclosure="public", documents={k: files["documents/" + k[2:] + ".bin"] for k in value["documents"]})
    require(dict(result.files) == files, "accession source reconstruction differs")
    return result
