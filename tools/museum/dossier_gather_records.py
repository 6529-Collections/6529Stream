"""Pure extraction of original facts from already replayed native catalogues.

The caller owns source admission, runtime pins, complete replay and cross-source
read consistency. This module is deliberately not a source authenticator. It
retains every occurrence in each admitted lane, including unrelated subjects,
and interprets only payloads matching an implemented original schema commitment.
"""
from copy import deepcopy
from hashlib import sha256
import re

from .account_profile import JCS_BYTES
from .bagit import _paths
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .independent_wire import ZERO, require
from .object_dossier_native import validate_reference

MAX_SOURCES, MAX_FILES, MAX_BYTES = 128, 8192, 96 * 1024 * 1024
MAX_RECORDS, MAX_ITEMS = 16384, 16384
CATALOGUES = ("owner", "independent", "metadata", "general")
KINDS = (*CATALOGUES, "ownership", "hosts", "inventory", "citation")
JCS_ID, JCS_HASH = schema_id("RFC8785_JCS"), keccak256(JCS_BYTES)
QUALIFICATION = (
    "Derived from caller-admitted, already replayed sources. Complete occurrences and heads are retained only "
    "within those admitted host scopes. Original receipt authority is historical; current selection, legal title, "
    "institutional identity, cited state, remote object availability, consensus and full packet/dossier conformance "
    "are not established. Typed payload validation checks the committed implemented meaning, not statement truth.")


def _object(value):
    value = loads(value, maximum=MAX_BYTES, canonical=True) if type(value) is bytes else value
    require(type(value) is dict, "gather decoded object required")
    return value


def _relation(subject, state):
    if subject == state["subjectId"]:
        return "exact_token"
    collection = subject_id("collection", state["chainId"], state["core"], state["collectionId"])
    return "collection_context" if subject == collection else "other_subject_context"


def _correspondence(wire):
    raw, (algorithm, digest, _) = wire["payload"], wire["content"]
    if not raw:
        return "external_or_empty_commitment"
    if algorithm not in ("1", "2"):
        return "opaque_algorithm_commitment"
    actual = keccak256(raw) if algorithm == "1" else "0x" + sha256(raw).hexdigest()
    require(actual == digest, "gather embedded payload digest differs")
    return "embedded_keccak256_verified" if algorithm == "1" else "embedded_sha256_verified"


def _wire(kind, row):
    """Exact native layouts; no common ABI is invented for the four hosts."""
    receipt = row["receipt"]
    if kind == "owner":
        r = row["record"]
        require(len(r) == 7 and len(receipt) == 13, "gather owner wire shape")
        return {"recordType": r[0], "subjectId": r[1], "schemaId": r[2], "content": r[3],
            "uri": r[4], "payload": hex_bytes(r[5]), "index": receipt[3], "chainHash": receipt[4],
            "schemaHash": receipt[9], "canonicalizationHash": receipt[10], "recordedAt": receipt[2],
            "effectiveAt": r[6], "authority": {"mode": "historical_native_owner_receipt", "owner": receipt[1],
                "relayed": receipt[5], "signatureScheme": receipt[11]}}
    if kind in ("metadata", "independent"):
        r = row["record"]
        require(len(r) == 8 and len(receipt) == (9 if kind == "metadata" else 11), "gather generic wire shape")
        authority = ({"mode": "historical_native_metadata_receipt", "recorder": receipt[1],
            "authorizationClass": receipt[2], "artistAuthorization": receipt[8]} if kind == "metadata" else
            {"mode": "historical_native_independent_receipt", "attestor": receipt[1], "authorizationClass": "5"})
        return {"recordType": r[0], "subjectId": r[1], "schemaId": r[4], "content": r[2],
            "uri": r[3], "payload": hex_bytes(row["payloadHex"]), "index": receipt[4], "chainHash": receipt[5],
            "schemaHash": receipt[6 if kind == "metadata" else 9],
            "canonicalizationHash": receipt[7 if kind == "metadata" else 10],
            "recordedAt": receipt[3], "effectiveAt": r[7], "authority": authority}
    r = row["value"]
    require(len(r) == 12 and len(receipt) == 24, "gather general wire shape")
    return {"recordType": r[3], "subjectId": r[2], "schemaId": r[5], "content": ["1", r[8], r[6]],
        "uri": r[7], "payload": hex_bytes(row["payloadHex"]), "index": receipt[4], "chainHash": receipt[5],
        "schemaHash": receipt[11], "canonicalizationHash": receipt[12], "recordedAt": receipt[3],
        "effectiveAt": r[11], "authority": {"mode": "historical_native_general_receipt", "recorder": receipt[0],
            "attester": r[0], "verificationClass": receipt[1], "qualificationClass": receipt[2],
            "signatureScheme": receipt[9], "authorityFamily": receipt[14], "authorizationClass": receipt[15],
            "grantCollection": receipt[16], "grantRevision": receipt[17], "artistAuthorizationRecordHash": r[10],
            "nativeArtistAuthorityClass": receipt[23]}}


def _interpret(kind, wire, state, relation):
    """A matching schema id alone never selects an interpretation."""
    rt, raw = wire["recordType"], wire["payload"]
    candidates = {}
    if kind == "metadata":
        from .metadata_rights_source import SCHEMA_BYTES, SCHEMA_NAME, PROFILE_BYTES, validate_rights
        candidates[schema_id("RIGHTS_STATEMENT")] = ("rights", SCHEMA_NAME, SCHEMA_BYTES, PROFILE_BYTES,
            lambda: validate_rights(raw, wire["subjectId"]))
    if kind in ("owner", "independent"):
        from . import condition
        candidates[schema_id("CONDITION_REPORT" if kind == "owner" else "INDEPENDENT_CONDITION")] = (
            "condition", condition.NAME, condition.SCHEMA_BYTES, condition.PROFILE_BYTES,
            lambda: condition.admit_payload(raw)["value"])
    if kind == "owner":
        from . import institutional
        for family in ("ACCESSION", "DEACCESSION"):
            candidates[schema_id(family)] = (family.lower(), institutional.NAMES[family],
                institutional.SCHEMAS[family], institutional.PROFILE_BYTES,
                lambda family=family: institutional.validate_payload(family, raw))
    if rt not in candidates:
        return {"status": "unsupported", "reason": "record_family_has_no_gather_interpreter"}, None
    label, name, schema, profile, validate = candidates[rt]
    if wire["schemaId"] != schema_id(name) or wire["schemaHash"] != keccak256(schema):
        return {"status": "unsupported", "reason": "original_schema_commitment_unsupported"}, None
    if wire["content"][2] != JCS_ID or wire["canonicalizationHash"] != JCS_HASH:
        return {"status": "unsupported", "reason": "original_canonicalization_commitment_unsupported"}, None
    algorithm, digest, _ = wire["content"]
    if algorithm not in ("1", "2") or not raw:
        return {"status": "unsupported", "reason": "embedded_payload_correspondence_unavailable"}, None
    actual = keccak256(raw) if algorithm == "1" else "0x" + sha256(raw).hexdigest()
    require(actual == digest, "gather typed payload digest differs")
    try:
        value = validate()
        require(dumps(value) == raw, "typed payload is not exact canonical JSON")
        if label != "rights":
            token = value["tokenId"]
            require(wire["subjectId"] == subject_id("token", state["chainId"], state["core"], "0", token_id=token),
                "typed token subject differs")
            if label == "condition":
                from .citations import parse_citation
                citation = parse_citation(value["workCitation"], require_state=True)
                require(citation["chainId"] == state["chainId"] and citation["core"] == state["core"]
                    and citation["tokenId"] == token, "condition citation identity differs")
            else:
                transfer = value["titleBinding"]["transfer"]
                require(transfer["chainId"] == state["chainId"] and transfer["core"] == state["core"],
                    "title binding chain/Core differs")
                require(uint(transfer["blockNumber"]) <= uint(state["blockNumber"]),
                    "title binding transfer is after source block")
    except MuseumError as exc:
        return {"status": "invalid", "reason": "implemented_payload_meaning_rejected", "detail": str(exc)}, None
    return {"status": "typed_historical", "kind": label, "value": value,
        "schemaId": schema_id(name), "schemaHash": keccak256(schema), "interpreterProfileHash": keccak256(profile),
        "currentSelection": "not_derived", "statementTruth": "not_established"}, (schema, profile)


class _Output:
    def __init__(self):
        self.files, self.total = {}, 0

    def add(self, path, raw):
        require(type(raw) is bytes and path not in self.files, "gather duplicate/nonbyte file")
        require(len(self.files) < MAX_FILES and len(raw) <= MAX_BYTES - self.total, "gather output aggregate bound")
        self.files[path] = raw
        self.total += len(raw)
        return path

    def json(self, path, value):
        return self.add(path, dumps(value))


def _catalogue(source, a, snap, prefix, state, out, report):
    kind, source_id, host = source["kind"], source["id"], a["host"]
    scope = a["tokenId" if kind == "owner" else "scopeKey" if kind == "independent" else "collectionId"]
    originals, lanes = snap["records"], snap["lanes"]
    require(type(originals) is list and len(originals) <= MAX_RECORDS and type(lanes) is list
        and len(lanes) <= 256, "gather native record/lane bound")
    original_by_hash = {}
    for position, original in enumerate(originals):
        digest = original["recordHash"]
        require(any(hex_bytes(digest, 32)) and digest not in original_by_hash, "gather duplicate/zero record")
        original_by_hash[digest] = (position, original, _wire(kind, original))
    used, lane_types = set(), set()
    for lane_index, lane in enumerate(lanes):
        rt, count = lane["recordType"], uint(lane["count"], 64)
        require(rt not in lane_types and any(hex_bytes(rt, 32)), "gather duplicate/zero lane")
        lane_types.add(rt)
        ordered = sorted((v for v in original_by_hash.values() if v[2]["recordType"] == rt),
            key=lambda v: uint(v[2]["index"], 64))
        require(count == len(ordered) and [v[2]["index"] for v in ordered] == [str(i) for i in range(count)],
            "gather lane occurrence/index differs")
        hashes = [v[1]["recordHash"] for v in ordered]
        if "records" in lane:
            require(lane["records"] == hashes, "gather original lane records differ")
        head = lane["chainHash"] if "chainHash" in lane else lane["head"]
        require(head == (ordered[-1][2]["chainHash"] if count else ZERO), "gather native lane head differs")
        head_path = out.json(f"{prefix}/lanes/{lane_index:04d}.json", lane)
        gathered = []
        for position, original, wire in ordered:
            digest, index = original["recordHash"], wire["index"]
            require(digest not in used and len(report["records"]) < MAX_RECORDS, "gather aggregate record bound/duplicate")
            used.add(digest)
            base = f"{prefix}/records/{lane_index:04d}/{uint(index):06d}"
            envelope = out.json(base + "/envelope.json", original)
            payload = out.add(base + "/payload.bin", wire["payload"])
            bundle = None
            if "signatureBundleHex" in original:
                bundle = out.add(base + "/signature-bundle.bin", hex_bytes(original["signatureBundleHex"]))
            native_proof = None
            if "nativeArtistEvidenceHex" in original:
                native_proof = out.add(base + "/native-artist-evidence.bin", hex_bytes(original["nativeArtistEvidenceHex"]))
            relation = _relation(wire["subjectId"], state)
            interpretation, definitions = _interpret(kind, wire, state, relation)
            if definitions is not None:
                schema, profile = definitions
                interpretation["schemaPath"] = out.add(base + "/matched-schema.json", schema)
                interpretation["interpreterProfilePath"] = out.add(base + "/interpreter-profile.json", profile)
                interpretation["canonicalizationPath"] = out.add(base + "/matched-canonicalization.json", JCS_BYTES)
            item = {"sourceId": source_id, "kind": kind, "host": host, "scopeKey": scope,
                "recordType": rt, "index": index, "recordHash": digest, "recordChainHash": wire["chainHash"],
                "subjectId": wire["subjectId"], "subjectRelation": relation,
                "originalSelector": f"/records/{position}", "envelopePath": envelope, "payloadPath": payload,
                "signatureBundlePath": bundle, "nativeArtistEvidencePath": native_proof,
                "schemaId": wire["schemaId"], "schemaHash": wire["schemaHash"],
                "contentCommitment": wire["content"], "uri": wire["uri"], "recordedAt": wire["recordedAt"],
                "effectiveAt": wire["effectiveAt"], "historicalAuthority": wire["authority"],
                "publication": deepcopy(original.get("publication")),
                "payloadCorrespondence": _correspondence(wire),
                "interpretation": interpretation, "payloadChunks": []}
            if kind == "general" and "payloadChunks" in original:
                offset = 0
                for chunk_index, descriptor in enumerate(original["payloadChunks"]):
                    length = uint(descriptor["byteLength"])
                    part = wire["payload"][offset:offset + length]
                    require(len(part) == length and keccak256(part) == descriptor["chunkHash"],
                        "gather original payload chunk differs")
                    path = out.add(base + f"/chunks/{chunk_index:04d}.bin", part)
                    item["payloadChunks"].append({"originalSelector": f"/records/{position}/payloadChunks/{chunk_index}",
                        "descriptor": deepcopy(descriptor), "path": path})
                    offset += length
                require(offset == len(wire["payload"]), "gather payload chunks incomplete")
            report["records"].append(item)
            gathered.append(envelope)
            if interpretation["status"] == "typed_historical":
                report["typedHistoricalFacts"].append({"sourceId": source_id, "recordHash": digest,
                    "envelopePath": envelope, "subjectRelation": relation, **deepcopy(interpretation)})
        report["heads"].append({"sourceId": source_id, "kind": kind, "host": host, "scopeKey": scope,
            "recordType": rt, "count": str(count), "headHash": head, "originalSelector": f"/lanes/{lane_index}",
            "originalPath": head_path, "recordEnvelopePaths": gathered,
            "scopeDisposition": "empty_within_admitted_host" if not count else "all_admitted_lane_occurrences"})
    require(used == set(original_by_hash), "gather orphan original record")
    for index, document in enumerate(snap.get("documents", [])):
        out.json(f"{prefix}/documents/{index:04d}/envelope.json", document)
        out.add(f"{prefix}/documents/{index:04d}/payload.bin", hex_bytes(document["payloadHex"]))


def _ownership(source, a, snap, prefix, state, out, report):
    identity = snap["identity"]
    require(identity["tokenId"] == state["tokenId"] and identity["collectionId"] == state["collectionId"]
        and identity["collectionSerial"] == state["collectionSerial"], "gather ownership identity differs")
    original = out.json(prefix + "/ownership.json", snap)
    jsonl = snap["tokenTransferJsonl"].encode("utf-8")
    require(keccak256(jsonl) == snap["tokenTransferJsonlHash"], "gather transfer JSONL differs")
    events = out.add(prefix + "/transfers.jsonl", jsonl)
    transitions = []
    for index, transition in enumerate(snap["transitions"]):
        same_transaction, title_bindings = [], []
        for row in report["records"]:
            if row["kind"] != "owner" or row["subjectRelation"] != "exact_token":
                continue
            publication = row["publication"]
            if publication is not None and publication["transactionHash"] == transition["transactionHash"]:
                same_transaction.append(row["envelopePath"])
            meaning = row["interpretation"]
            if meaning.get("kind") not in ("accession", "deaccession"):
                continue
            transfer = meaning["value"]["titleBinding"]["transfer"]
            keys = ("transactionHash", "blockNumber", "logIndex", "from", "to")
            if transfer["tokenId"] == state["tokenId"] and all(transfer[k] == transition[k] for k in keys):
                title_bindings.append(row["envelopePath"])
        transitions.append({"originalSelector": f"/transitions/{index}", "transition": deepcopy(transition),
            "sameTransactionOwnerRecords": same_transaction, "matchingTitleBindingStatements": title_bindings})
    report["ownership"].append({"sourceId": source["id"], "originalPath": original, "transferEventsPath": events,
        "identity": deepcopy(identity), "historyCoverage": deepcopy(snap["historyCoverage"]), "transitions": transitions,
        "qualification": "Transfer correspondence and owner statements remain distinct; matching does not prove legal title."})


def _inventory(source, snap, prefix, out, report):
    original_path = out.json(prefix + "/inventory.json", snap)
    items, record_lookup = [], {}
    for row in report["records"]:
        record_lookup.setdefault((row["host"], row["recordHash"]), []).append(row["envelopePath"])
    for segment_index, segment in enumerate(snap["segments"]):
        require(len(segment["items"]) == len(segment["itemHashes"]), "gather inventory item/hash count differs")
        for index, (item, digest) in enumerate(zip(segment["items"], segment["itemHashes"])):
            require(len(items) < MAX_ITEMS, "gather inventory item bound")
            path = out.json(f"{prefix}/items/{segment_index:04d}/{index:04d}.json", item)
            matching = record_lookup.get((item["source"], item["sourceRecord"]), [])
            items.append({"originalSelector": f"/segments/{segment_index}/items/{index}",
                "segmentIndex": segment["index"], "itemIndex": str(index), "itemHash": digest,
                "descriptorPath": path, "descriptor": deepcopy(item), "matchingRecordEnvelopes": matching,
                "referencedObjectBytes": "not_captured_by_inventory_reader"})
    report["renderInventories"].append({"sourceId": source["id"], "originalPath": original_path,
        "items": items, "tokens": deepcopy(snap["tokens"]), "context": deepcopy(snap["context"]),
        "qualification": "Complete admitted producer descriptors; descriptor files are not the referenced object bytes."})


def extract(reference, sources):
    """Return files and a deterministic fact report; sources must already be replayed.

    Input items are exactly ``id, kind, anchor, snapshot, provenance``. Anchor and
    snapshot may be canonical JSON bytes or decoded objects. This function makes
    no RPC calls and does not upgrade the provenance declared by the caller.
    """
    reference = validate_reference(reference)
    require(type(sources) is list and len(sources) <= MAX_SOURCES, "gather source count bound")
    prepared, ids, input_bytes = [], set(), 0
    for source in sources:
        require(type(source) is dict and set(source) == {"id", "kind", "anchor", "snapshot", "provenance"},
            "gather source item shape")
        identifier = source["id"]
        require(type(identifier) is str and re.fullmatch(r"[A-Za-z0-9_-]{1,128}", identifier)
            and identifier not in ids, "gather source id/duplicate")
        require(source["kind"] in KINDS and source["provenance"] in ("synthetic_fixture", "trusted_rpc"),
            "gather source kind/provenance")
        a, snap = _object(source["anchor"]), _object(source["snapshot"])
        input_bytes += len(dumps(a)) + len(dumps(snap))
        require(input_bytes <= MAX_BYTES, "gather input aggregate bound")
        prepared.append((source, a, snap)); ids.add(identifier)
    prepared.sort(key=lambda item: item[0]["id"])
    out = _Output()
    report = {"version": "1", "sourceState": deepcopy(reference["sourceState"]), "sources": [], "records": [],
        "heads": [], "ownership": [], "renderInventories": [], "typedHistoricalFacts": [],
        "qualification": QUALIFICATION, "claims": {"sourceAuthenticationPerformed": False,
            "allAdmittedRecordOccurrencesRetained": True, "currentRecordSelectionDerived": False,
            "globalHostCoverageComplete": False, "legalTitleProven": False, "institutionalIdentityProven": False,
            "actualChainAcceptance": False, "fullCanonicalPacket": False, "fullObjectDossierConformance": False}}
    # Catalogues first so ownership/inventory links do not depend on input order.
    deferred = []
    for index, (source, a, snap) in enumerate(prepared):
        prefix = f"gathered/sources/{index:04d}"
        before = len(report["records"])
        if source["kind"] in CATALOGUES:
            _catalogue(source, a, snap, prefix, reference["sourceState"], out, report)
        else:
            deferred.append((source, a, snap, prefix))
        report["sources"].append({"id": source["id"], "kind": source["kind"], "provenance": source["provenance"],
            "snapshotHash": keccak256(dumps(snap)), "recordCount": str(len(report["records"]) - before),
            "disposition": "handled_by_parent" if source["kind"] in ("hosts", "citation") else "extracted"})
    for source, a, snap, prefix in deferred:
        if source["kind"] == "ownership":
            _ownership(source, a, snap, prefix, reference["sourceState"], out, report)
        elif source["kind"] == "inventory":
            _inventory(source, snap, prefix, out, report)
    _paths(out.files)
    report["fileInventory"] = [{"path": path, "bytes": str(len(raw)), "sha256": "0x" + sha256(raw).hexdigest(),
        "keccak256": keccak256(raw)} for path, raw in sorted(out.files.items())]
    require(len(dumps(report)) <= MAX_BYTES - out.total, "gather report aggregate bound")
    return dict(sorted(out.files.items())), report
