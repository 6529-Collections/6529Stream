"""Additive native personhood fragment: supplied-data joins, never source authentication."""
import argparse
import copy
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from tools.museum import artist_attestation_source as artist
from tools.museum import general_attestation_source as general
from tools.museum import personhood_documentary as proof
from tools.museum import public_personhood_source as source
from tools.museum import public_personhood_capture as capture
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from tools.museum.chain_abi import decode, encode
from tools.museum.independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from . import identity_notarization_profile as notarization

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_ACQUISITION_PERSONHOOD_V1"
MAX_BYTES = 131072
SOURCE_REF_FIELDS = ("manifestHash", "anchorHash", "transcriptHash", "snapshotHash", "sourceProfileHash", "captureProfileHash")
AUTHORITY_KIND = "native_general_receipt"
QUALIFICATION = (
    "Prospective unregistered native personhood supplied-data fragment. Native Artist authority and the "
    "General receipt's verification/qualification fields remain separate. Exact original records, typed "
    "payloads, byte commitments and supplied context are reconciled; the original notarization collection "
    "need not be the Artist collection. Source pins do not authenticate themselves. Validation performs no "
    "RPC replay, signature verification, historical execution, source-artifact admission, legal personhood "
    "or institutional-standing proof. NONE and UNRESOLVED do not prove universal absence. This fragment "
    "does not change or complete acquisition packets V1–V4.")
RULES = [
    "Numeric version1 selects this standalone fragment, not a new complete packet version.",
    "Original registration identity, current operative identity and original attested operative identity are separate fields.",
    "The native General authority discriminator is native_general_receipt/string1. All 24 original Receipt fields remain in native order; no legacy numeric authorityClass is synthesized.",
    "Original Artist op24 record and signed preimages use their original Registry domain. An unknown original Registry preserves nullable provenance without inventing a preimage or signature.",
    "Full Summary, General record, subject, payload, signature bundle, four exact definitions and six carriers use their original hash recipes. Original record hashing zeros its index/chain; documentary hashing retains the full original receipt.",
    "Native NONE/WAIVER/RESOLVED/STALE/UNRESOLVED remain distinct. A waiver commits its original native record, resolved evidence commits its tagged Summary, and neither an unresolved observation nor a newer notary head selects replacement evidence.",
    "Definition lifecycle is excluded from immutable fact hashes. ACTIVE and DEPRECATED General module status may remain current; unknown and incident-revoked status cannot.",
    "Publication and retention coordinates are supplied observations, internally consistent with source height/hash and original transaction order; no missing ancestry, receipt inclusion or history completeness is proved.",
    "Distinct supplied events cannot share a block log position; block log order agrees with transaction order. Immutable owner domains and supplied address/runtime commitments must agree across original and current evidence; equal repeated observations remain allowed.",
]


def closed(properties):
    return {"type": "object", "properties": properties, "required": list(properties), "additionalProperties": False}


def nullable(shape): return {"anyOf": [shape, {"type": "null"}]}
def ref(name): return {"$ref": "#/$defs/" + name}
def array(shape, maximum, minimum=0): return {"type": "array", "items": shape, "minItems": minimum, "maxItems": maximum}
def blob(maximum): return {"type": "string", "pattern": "^0x(?:[0-9a-f]{2})*(?![\\s\\S])", "maxLength": 2 + 2 * maximum}


def abi(kind):
    if isinstance(kind, tuple):
        return {"type": "array", "prefixItems": [abi(k) for k in kind], "items": False,
            "minItems": len(kind), "maxItems": len(kind)}
    if kind == "bool": return {"type": "boolean"}
    if kind == "bytes": return blob(8192)
    if kind == "string": return {"type": "string", "maxLength": 8192}
    if kind.startswith("uint"):
        return {"type": "string", "pattern": "^(0|[1-9][0-9]*)(?![\\s\\S])", "maxLength": 78,
            "x-stream-uint-bits": int(kind[4:])}
    length = 20 if kind == "address" else int(kind[5:])
    return {"type": "string", "pattern": "^0x[0-9a-f]{" + str(length * 2) + "}(?![\\s\\S])"}


def definitions():
    h, a, b = ref("hash"), abi("address"), {"type": "boolean"}
    d = {"hash": abi("bytes32"), "publication": closed({"blockHash": h, "blockNumber": abi("uint64"),
        "transactionHash": h, "transactionIndex": abi("uint64"), "logIndex": abi("uint32")})}
    pins = {key: h for key in SOURCE_REF_FIELDS}
    pins["sourceProfileHash"] = {"const": source.PROFILE_HASH}
    pins["captureProfileHash"] = {"const": capture.PROFILE_HASH}
    d["sourceRef"] = closed(pins)
    d["sourceState"] = closed({key: abi("address") if key == "core" else h if key in
        ("blockHash", "stateRoot", "deploymentEvidenceHash") else {"enum": ["public_chain", "local_evm_fixture"]}
        if key == "environment" else abi("uint64" if key in ("blockNumber", "timestamp") else "uint256") for key in source.COMMON})
    d["identities"] = closed({"currentRegistration": h, "currentOperative": h, "originalAttested": nullable(h)})
    d["sourceBindings"] = closed({key: nullable(a) if key.startswith("original") else a for key in
        ("currentRegistry", "currentAttribution", "currentArchive", "originalRegistry", "originalAttribution", "originalArchive")})
    d["current"] = closed({"artistId": h, "binding": abi(artist.BINDING), "registrationIdentityRecordHash": h,
        "operativeIdentityRecordHash": h, "selection": abi(proof.SELECTION), "status": {"enum": list(proof.STATUSES)},
        "evidenceHash": h, "evidenceHashDomain": {"enum": ["none", "native_op24_record", "personhood_proof_summary"]},
        "identityCurrent": b, "notarizationCurrent": b,
        "currentReadGas": nullable(abi(("uint256", "uint256", "uint8", "uint64")))})
    d["stored"] = closed({"owner": a, "pointer": a, "payloadType": h, "payloadHash": h,
        "index": abi("uint256"), "publication": ref("publication")})
    d["authorization"] = closed({"bodyHex": blob(352), "domainHex": blob(160), "domainHash": h, "digest": h,
        "authorityClass": abi("uint8"), "nonce": abi("uint256"), "signedAt": abi("uint64"),
        "originalSignatureBytesRetained": {"const": True}, "signatureCryptographyRevalidated": {"const": False}})
    d["original"] = closed({"recordHash": h, "record": abi(artist.ATTESTATION_RECORD), "recordPreimageHex": nullable(blob(512)),
        "statementHex": blob(8192), "originalRegistry": a, "originalBinding": nullable(abi(artist.BINDING)),
        "signatureHex": nullable(blob(4096)), "publication": nullable(ref("publication")),
        "authorization": nullable(ref("authorization")), "summary": abi(proof.SUMMARY), "summaryHash": h,
        "statementRetention": nullable(ref("stored")), "summaryRetentions": array(closed({"owner": a, "publication": ref("publication")}), 2),
        "summaryCarriers": array(ref("stored"), 4), "originalOp24Correspondence": {"enum": ["origin_unavailable", "reconstructed"]}})
    d["nativeGeneralAuthority"] = closed({"kind": {"const": AUTHORITY_KIND}, "version": {"const": "1"},
        "receipt": abi(general.RECEIPT), "signatureBundleHex": blob(8192), "signatureHex": blob(4096),
        "domain": h, "words": abi(("bytes32",) * 15)})
    d["definition"] = closed({"documentId": h, "facts": abi(proof.DOCUMENT_FACTS), "factsHash": h,
        "payloadHex": blob(8192), "pointer": a, "carrierCodeHash": h})
    d["general"] = closed({"recordHash": h, "attestation": abi(general.ATTESTATION), "subject": abi(general.SUBJECT),
        "payloadHex": blob(8192), "payloadValue": notarization.schema(), "authority": ref("nativeGeneralAuthority"),
        "facts": abi(proof.FACTS), "publication": ref("publication"), "module": abi(proof.MODULE),
        "moduleIdentityHash": h, "moduleRegistryPointer": abi(proof.POINTER), "definitions": array(ref("definition"), 4, 4),
        "carriers": array(closed({"address": a, "runtimeHash": h}), 6, 6), "documentaryHash": h,
        "recorderHistory": closed({"eventCount": abi("uint64"), "latestByRecorder": array(closed({"recorder": a, "recordHash": h}), 128, 1)})})
    d["fragment"] = closed({"schema": {"const": NAME}, "version": {"const": 1}, "sourceRef": ref("sourceRef"),
        "sourceState": ref("sourceState"), "sourceBindings": ref("sourceBindings"), "identities": ref("identities"),
        "current": ref("current"), "original": nullable(ref("original")), "general": nullable(ref("general")),
        "qualification": {"const": QUALIFICATION}})
    return d


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + NAME,
        "title": NAME, "description": QUALIFICATION, **ref("fragment"), "$defs": definitions(), "x-stream-constraints": RULES})


SCHEMA_BYTES = schema_document_bytes()
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def native(kind, value):
    if isinstance(kind, tuple): result = tuple(native(k, v) for k, v in zip(kind, value, strict=True))
    elif kind.startswith("uint"): result = uint(value, int(kind[4:]))
    elif kind == "bytes": result = hex_bytes(value)
    else: result = value
    encode((kind,), (result,))
    return result


def _position(row): return tuple(uint(row[k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
def _transaction(row): return tuple(row[k] for k in ("blockHash", "blockNumber", "transactionHash", "transactionIndex"))


def _observations(value):
    state = value["sourceState"]
    numbers, hashes, transactions, slots = {state["blockNumber"]: state["blockHash"]}, {state["blockHash"]: state["blockNumber"]}, {}, {}
    def walk(row):
        if isinstance(row, dict):
            if set(row) == {"owner", "pointer", "payloadType", "payloadHash", "index", "publication"}:
                uint(row["index"], 256)
            if set(row) == {"blockHash", "blockNumber", "transactionHash", "transactionIndex", "logIndex"}:
                n, bh, tx, ix = (row[k] for k in ("blockNumber", "blockHash", "transactionHash", "transactionIndex"))
                require(uint(n, 64) <= uint(state["blockNumber"], 64) and bh != ZERO and tx != ZERO,
                    "personhood publication source bounds")
                require(numbers.setdefault(n, bh) == bh and hashes.setdefault(bh, n) == n,
                    "personhood publication block mapping differs")
                placement = (n, bh, ix)
                require(transactions.setdefault(tx, placement) == placement and slots.setdefault((n, ix), tx) == tx,
                    "personhood publication transaction mapping differs")
                uint(ix, 64); uint(row["logIndex"], 32)
            for child in row.values(): walk(child)
        elif isinstance(row, list):
            for child in row: walk(child)
    walk(value)
    events = []
    original, general_row = value["original"], value["general"]
    if original is not None:
        if original["publication"] is not None:
            events.append((original["publication"], ("op24", value["sourceBindings"]["originalAttribution"], original["recordHash"])))
        stored = original["summaryCarriers"] + ([] if original["statementRetention"] is None else [original["statementRetention"]])
        for row in stored:
            events.append((row["publication"], ("stored", row["owner"], row["pointer"], row["payloadType"], row["payloadHash"], row["index"])))
        for row in original["summaryRetentions"]:
            events.append((row["publication"], ("summary", row["owner"], original["recordHash"], original["summaryHash"])))
    if general_row is not None:
        events.append((general_row["publication"], ("general", original["summary"][9][5], general_row["recordHash"])))
    log_slots = {}
    for row, identity in events:
        key = (uint(row["blockNumber"]), uint(row["logIndex"]))
        observed = (uint(row["transactionIndex"]), row["transactionHash"], identity)
        require(log_slots.setdefault(key, observed) == observed, "personhood distinct events share a block log position")
    previous = {}
    for (number, _), (transaction_index, _, _) in sorted(log_slots.items()):
        require(transaction_index >= previous.get(number, 0), "personhood block log/transaction order differs")
        previous[number] = transaction_index


def _runtime_observations(value, summary):
    """Reconcile supplied code commitments, without authenticating any runtime."""
    observed = {}
    def remember(address, digest):
        require(observed.setdefault(address, digest) == digest, "personhood supplied runtime commitments conflict")
    original = value["original"]
    if original is None: return
    retained = original["statementRetention"]
    if retained is not None: remember(retained["pointer"], keccak256(b"\0" + hex_bytes(original["statementHex"])))
    if summary[0] != 1: return
    s, p = summary, summary[9]
    for address, digest in ((p[2], s[10]), (p[5], p[6]), (s[11], s[12]), (s[13], s[14]), (s[15], s[16]), (s[17], s[18])):
        remember(address, digest)
    for address, digest in zip(s[26], s[27], strict=True): remember(address, digest)
    summary_runtime = keccak256(b"\0" + encode(("bytes32", proof.SUMMARY), (proof.SUMMARY_TAG, s)))
    for row in original["summaryCarriers"]: remember(row["pointer"], summary_runtime)
    for row in value["general"]["definitions"]: remember(row["pointer"], row["carrierCodeHash"])


def _general(value, summary, original):
    row, state = value["general"], value["sourceState"]
    require(row is not None, "personhood admitted summary has no General evidence")
    a, r = native(general.ATTESTATION, row["attestation"]), native(general.RECEIPT, row["authority"]["receipt"])
    require(len(encode((general.ATTESTATION, general.RECEIPT), (a, r))) <= 12288, "personhood General ABI byte limit")
    s, p = summary, summary[9]
    require(row["recordHash"] == p[7] and a[3] in (general.INSTITUTIONAL, general.ESTATE)
        and a[0] == r[0] != ZERO_ADDRESS and r[1:3] == (1, 1) and a[5:7] == (general.SCHEMA_ID, general.JCS_ID)
        and r[11:14] == (notarization.SCHEMA_HASH, general.JCS_HASH, notarization.PROFILE_HASH)
        and r[18:22] == (p[2], s[10], p[3], p[4]) and 0 < r[3] <= uint(state["timestamp"])
        and r[6] != ZERO and r[10] != ZERO and a[2] != ZERO and a[8] != ZERO and a[10] == ZERO
        and r[14:18] == (ZERO, 0, 0, 0) and r[22:24] == (ZERO, 0), "personhood General original receipt fields differ")
    require(general.native_record_hash(s[1], p[5], a, r) == p[7] and (a[1], a[3], a[2], r[0]) == s[20:24],
        "personhood General record/hash/scope differs")
    subject = native(general.SUBJECT, row["subject"]); kind, cid, token, obj = subject
    require(cid == a[1] and ((kind == 0 and token == 0 and obj == ZERO) or
        (kind == 1 and cid > 0 and token > 0 and obj == ZERO) or (kind == 2 and cid > 0 and token == 0 and obj != ZERO)),
        "personhood General subject shape differs")
    require(subject_id(("collection", "token", "media")[kind], state["chainId"], state["core"], str(cid),
        token_id=str(token), object_id=obj) == a[2], "personhood General subject hash differs")
    payload, bundle = hex_bytes(row["payloadHex"]), hex_bytes(row["authority"]["signatureBundleHex"])
    require(0 < len(payload) <= 8192 and keccak256(payload) == a[8] and 0 < len(bundle) <= 8192
        and keccak256(bundle) == r[10], "personhood General payload/bundle commitment differs")
    require(notarization.validate(payload, artist_id=p[3], operative_identity_record_hash=p[4]) == row["payloadValue"],
        "personhood typed original payload differs")
    domain, words, signature = decode(("bytes32", ("bytes32",) * 15, "bytes"), bundle, maximum=8192)
    require(0 < len(signature) <= 4096 and r[9] in (general.EIP712, general.ERC1271)
        and domain == row["authority"]["domain"] == general.domain(s[1], p[5])
        and json_values(words) == row["authority"]["words"] and signature == hex_bytes(row["authority"]["signatureHex"])
        and encode(("bytes32",) * 15, words) == general.signed_words(a, payload, r)
        and keccak256(b"\x19\x01" + hex_bytes(domain) + hex_bytes(keccak256(encode(("bytes32",) * 15, words)))) == r[6],
        "personhood General signature preimage differs")
    module = native(proof.MODULE, row["module"])
    require(len(encode((proof.MODULE,), (module,))) <= 8192, "personhood General module ABI byte limit")
    require(module[0] <= 3 and module[1:4] == (proof.GENERAL_TYPE, proof.GENERAL_VERSION, proof.GENERAL_INTERFACE)
        and module[5] == p[6] and proof.module_identity(module) == s[25] == row["moduleIdentityHash"],
        "personhood General module identity differs")
    pointer = native(proof.POINTER, row["moduleRegistryPointer"])
    require(pointer[:2] == (s[13], s[14]), "personhood General module pointer differs")
    fact_hashes, carrier_hashes = [], [keccak256(b"\0" + payload), keccak256(b"\0" + bundle)]
    for actual, (identifier, kind, digest, raw) in zip(row["definitions"], proof.definitions(), strict=True):
        f = native(proof.DOCUMENT_FACTS, actual["facts"])
        require(actual["documentId"] == identifier and hex_bytes(actual["payloadHex"]) == raw
            and f[0] and f[1] == kind and f[2] <= 2 and f[3] == digest and f[4] == general.RAW_BYTES
            and f[5] == ZERO and f[6] == len(raw) and f[7] == 1 and f[8] != ZERO,
            "personhood immutable definition differs")
        facts_hash = proof.definition_facts_hash(f); code_hash = keccak256(b"\0" + raw)
        require(actual["factsHash"] == facts_hash and actual["carrierCodeHash"] == code_hash,
            "personhood definition facts/carrier hash differs")
        fact_hashes.append(facts_hash); carrier_hashes.append(code_hash)
    require(tuple(fact_hashes) == s[19] and tuple(x["address"] for x in row["carriers"]) == s[26]
        and tuple(x["runtimeHash"] for x in row["carriers"]) == tuple(carrier_hashes) == s[27]
        and tuple(x["pointer"] for x in row["definitions"]) == s[26][2:]
        and all(x != ZERO_ADDRESS for x in s[26]), "personhood summary carriers/definitions differ")
    digest = keccak256(encode(("bytes32", "uint256", "address", proof.REFERENCE, general.ATTESTATION, general.RECEIPT,
        "bytes32", "bytes32", "address", "bytes32", "address", "bytes32", ("bytes32",) * 4),
        (proof.DOCUMENTARY_TAG, s[1], s[11], p, a, r, keccak256(encode((general.SUBJECT,), (subject,))),
            keccak256(encode(("bytes", "bytes"), (payload, bundle))), s[15], s[16], s[17], s[18], tuple(fact_hashes))))
    require(digest == s[24] == row["documentaryHash"], "personhood documentary hash differs")
    history = row["recorderHistory"]; pairs = [(x["recorder"], x["recordHash"]) for x in history["latestByRecorder"]]
    require(pairs == sorted(pairs) and len({who for who, _ in pairs}) == len(pairs)
        and all(who != ZERO_ADDRESS and record != ZERO for who, record in pairs)
        and len(pairs) <= uint(history["eventCount"]) <= source.MAX_RECORDS and r[0] in dict(pairs),
        "personhood supplied recorder heads differ")
    eligible = module[0] in (1, 2) and module[11] > 0
    head = dict(pairs)[r[0]] if eligible else ZERO
    facts = (a[3], r[0], head, eligible and head == p[7])
    require(native(proof.FACTS, row["facts"]) == facts, "personhood General currentness differs")
    require(original["publication"] is not None and _position(row["publication"]) < _position(original["publication"]),
        "personhood General publication follows original op24")
    if row["publication"]["blockNumber"] == state["blockNumber"]:
        require(r[3] == uint(state["timestamp"]), "personhood General source-block timestamp differs")
    return facts


def _original(value, selected):
    n, state, current = value["original"], value["sourceState"], value["current"]
    record = selected[0]
    if record[0] == ZERO:
        require(n is None and value["general"] is None and selected == source.zero(proof.SELECTION),
            "personhood empty native head differs")
        require(all(value["sourceBindings"][key] is None for key in ("originalRegistry", "originalAttribution", "originalArchive")),
            "personhood empty head original bindings were invented")
        return None, None
    require(n is not None and native(artist.ATTESTATION_RECORD, n["record"]) == record and n["recordHash"] == record[0]
        and record[1] != ZERO and record[2] in (proof.WAIVER_SCHEMA, proof.EVIDENCE_SCHEMA) and record[3] != ZERO
        and record[4] > 0 and record[6] != ZERO_ADDRESS and 0 < record[5] <= uint(state["timestamp"]),
        "personhood native original record differs")
    statement = hex_bytes(n["statementHex"])
    require(0 < len(statement) <= 8192 and keccak256(statement) == record[3]
        and n["originalRegistry"] == selected[1], "personhood original statement/Registry differs")
    s = native(proof.SUMMARY, n["summary"]); admitted = s[0] == 1
    if admitted:
        require(record[2] == proof.EVIDENCE_SCHEMA and proof.summary_hash(s) == n["summaryHash"]
            and s[1:5] == (uint(state["chainId"]), record[0], record[3], current["artistId"])
            and s[6:9] == (record[4], uint(state["collectionId"]), record[1])
            and s[9] == selected[2] and s[9][2] == selected[1] and s[9][3:5] == (current["artistId"], record[1])
            and s[11] == state["core"] and all(x != ZERO for x in (s[10], s[12], s[14], s[16], s[18]))
            and all(x != ZERO_ADDRESS for x in (s[13], s[15], s[17]))
            and proof.decode_reference(statement) == s[9], "personhood admitted Summary differs")
    else:
        require(s == source.zero(proof.SUMMARY) and n["summaryHash"] == ZERO and value["general"] is None
            and selected[2] == source.zero(proof.REFERENCE), "personhood empty Summary differs")
    bindings = value["sourceBindings"]
    if selected[1] == ZERO_ADDRESS:
        require(not admitted and all(n[key] is None for key in ("originalBinding", "recordPreimageHex", "signatureHex", "publication", "authorization", "statementRetention"))
            and n["originalOp24Correspondence"] == "origin_unavailable"
            and all(bindings[key] is None for key in ("originalRegistry", "originalAttribution", "originalArchive")),
            "personhood unavailable origin was invented")
    else:
        require(all(n[key] is not None for key in ("originalBinding", "recordPreimageHex", "signatureHex", "publication", "authorization", "statementRetention"))
            and n["originalOp24Correspondence"] == "reconstructed" and bindings["originalRegistry"] == selected[1]
            and bindings["originalAttribution"] not in (None, ZERO_ADDRESS) and bindings["originalArchive"] not in (None, ZERO_ADDRESS),
            "personhood original provenance missing")
        binding = native(artist.BINDING, n["originalBinding"])
        require(binding[0] == current["artistId"] and binding[4] == record[4] and binding[9]
            and binding[3] != ZERO and (not admitted or binding[3] == s[5]), "personhood original binding differs")
        preimage = hex_bytes(n["recordPreimageHex"]); terms = decode(source.PREIMAGE, preimage, maximum=512)
        require(keccak256(preimage) == record[0] and terms[:6] == (schema_id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
            uint(state["chainId"]), selected[1], state["core"], uint(state["collectionId"]), 10)
            and terms[6:10] == (current["artistId"], record[1], record[2], record[3])
            and terms[11:13] == (current["artistId"], record[6]) and terms[13] in (1, 2, 3, 4) and terms[15] == record[5],
            "personhood original op24 preimage differs")
        auth = n["authorization"]
        body = encode(("bytes32", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64"),
            (artist.TYPE_HASH, state["core"], uint(state["collectionId"]), 10, *terms[6:11], terms[14], terms[15]))
        domain = encode(("bytes32", "bytes32", "bytes32", "uint256", "address"),
            (schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                schema_id("6529StreamArtistRegistry"), schema_id("1"), uint(state["chainId"]), selected[1]))
        require(hex_bytes(auth["bodyHex"]) == body and hex_bytes(auth["domainHex"]) == domain
            and auth["domainHash"] == keccak256(domain) and auth["digest"] == keccak256(b"\x19\x01" + hex_bytes(keccak256(domain)) + hex_bytes(keccak256(body)))
            and tuple(uint(auth[k]) for k in ("authorityClass", "nonce", "signedAt")) == terms[13:16]
            and len(hex_bytes(n["signatureHex"])) <= 4096, "personhood original authorization differs")
        retained = n["statementRetention"]
        require(retained["owner"] == bindings["originalAttribution"] and retained["pointer"] != ZERO_ADDRESS
            and retained["payloadType"] == source.STATEMENT_TYPE and retained["payloadHash"] == record[3]
            and _position(retained["publication"]) < _position(n["publication"]), "personhood original statement retention differs")
    if not admitted:
        require(n["summaryRetentions"] == n["summaryCarriers"] == [], "personhood unadmitted summary retention")
        return s, None
    retentions = {r["owner"]: r for r in n["summaryRetentions"]}
    carriers = {r["owner"]: r for r in n["summaryCarriers"]}
    expected_owners = {bindings["originalAttribution"], bindings["currentAttribution"]}
    expected_carriers = expected_owners | {bindings["originalArchive"], bindings["currentArchive"]}
    require(len(retentions) == len(n["summaryRetentions"]) and set(retentions) == expected_owners
        and len(carriers) == len(n["summaryCarriers"]) and set(carriers) == expected_carriers,
        "personhood Summary retention owner set differs")
    require(_transaction(retentions[bindings["originalAttribution"]]["publication"]) == _transaction(n["publication"]),
        "personhood original Summary transaction differs")
    for prefix in ("original", "current"):
        owner, archive = bindings[prefix + "Attribution"], bindings[prefix + "Archive"]
        own, retained, archived = carriers[owner], retentions[owner], carriers[archive]
        require(own["pointer"] == archived["pointer"] != ZERO_ADDRESS
            and _transaction(own["publication"]) == _transaction(retained["publication"]) == _transaction(archived["publication"])
            and _position(own["publication"]) < _position(retained["publication"]) < _position(archived["publication"])
            and _position(n["publication"]) < _position(retained["publication"]), "personhood Summary carrier chronology differs")
    require(all(row["payloadType"] == source.SUMMARY_TYPE and row["payloadHash"] == n["summaryHash"] for row in carriers.values()),
        "personhood Summary carrier hash differs")
    return s, _general(value, s, n)


def validate(raw):
    """Check closed supplied fields and hashes; never treat source commitments as authentication."""
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        Draft202012Validator(loads(SCHEMA_BYTES, maximum=MAX_BYTES)).validate(value)
        state, current, identities, bindings = (value[k] for k in ("sourceState", "current", "identities", "sourceBindings"))
        require(all(any(hex_bytes(value["sourceRef"][key], 32)) for key in SOURCE_REF_FIELDS), "personhood empty source reference")
        for key in ("chainId", "collectionId"): require(uint(state[key]) > 0, "personhood empty source identity")
        uint(state["timestamp"], 64); uint(state["blockNumber"], 64)
        require(state["core"] != ZERO_ADDRESS and all(state[k] != ZERO for k in ("blockHash", "stateRoot", "deploymentEvidenceHash")),
            "personhood empty source state")
        require(all(bindings[k] != ZERO_ADDRESS for k in ("currentRegistry", "currentAttribution", "currentArchive")),
            "personhood empty current source binding")
        for prefix in ("current", "original"):
            addresses = [bindings[prefix + k] for k in ("Registry", "Attribution", "Archive")]
            require(all(x is None for x in addresses) or (all(x not in (None, ZERO_ADDRESS) for x in addresses)
                and len(set(addresses)) == 3), "personhood source binding identities collide")
        if bindings["originalRegistry"] == bindings["currentRegistry"]:
            require(all(bindings["original" + k] == bindings["current" + k] for k in ("Attribution", "Archive")),
                "personhood same Registry has conflicting original owners")
        owner_domains = {}
        for prefix in ("current", "original"):
            if bindings[prefix + "Registry"] is not None:
                for role in ("Attribution", "Archive"):
                    require(owner_domains.setdefault(bindings[prefix + role], bindings[prefix + "Registry"]) == bindings[prefix + "Registry"],
                        "personhood immutable owner belongs to conflicting Registries")
        selected, binding = native(proof.SELECTION, current["selection"]), native(artist.BINDING, current["binding"])
        require(selected[-1] < len(proof.STATUSES) and current["status"] == proof.STATUSES[selected[-1]]
            and current["artistId"] == binding[0] and (current["identityCurrent"], current["notarizationCurrent"]) == selected[-3:-1],
            "personhood current native observation differs")
        require((binding == source.zero(artist.BINDING) and current["registrationIdentityRecordHash"] == current["operativeIdentityRecordHash"] == ZERO)
            if binding[0] == ZERO else (binding[4] > 0 and current["registrationIdentityRecordHash"] != ZERO),
            "personhood registration/binding context differs")
        require(identities == {"currentRegistration": current["registrationIdentityRecordHash"],
            "currentOperative": current["operativeIdentityRecordHash"], "originalAttested": None if selected[0][0] == ZERO else selected[0][1]},
            "personhood original/current identity projection differs")
        _observations(value)
        summary, facts = _original(value, selected)
        _runtime_observations(value, summary)
        if selected[0][0] != ZERO:
            gas = current["currentReadGas"]
            require(gas is not None, "personhood current gas observation missing")
            gas = native(("uint256", "uint256", "uint8", "uint64"), gas)
            if selected[-1] != 4:
                require(0 < gas[0] <= ((1 << 256) - 1) // 64 and gas[2] == 2 and gas[3] > 0, "personhood current gas differs")
            record = selected[0]
            identity_current = binding[9] and binding[4] == record[4] and current["operativeIdentityRecordHash"] == record[1] != ZERO
            if facts is not None: identity_current = identity_current and binding[3] == summary[5]
            if selected[-1] == 4:
                require(not selected[-2] and selected[3:6] == (ZERO, ZERO_ADDRESS, ZERO)
                    and (not selected[-3] or (facts is None and record[2] == proof.EVIDENCE_SCHEMA and identity_current)),
                    "personhood UNRESOLVED flags differ")
            elif record[2] == proof.WAIVER_SCHEMA:
                require(facts is None and selected[3:6] == (ZERO, ZERO_ADDRESS, ZERO) and not selected[-2]
                    and selected[-3] == identity_current and selected[-1] == (1 if identity_current else 3), "personhood waiver status differs")
            else:
                require(facts is not None and selected[3:6] == facts[:3] and selected[-2] == facts[3]
                    and selected[-3] == identity_current and selected[-1] == (2 if identity_current and facts[3] else 3),
                    "personhood resolved/stale status differs")
        else: require(current["currentReadGas"] is None, "personhood empty-head gas differs")
        expected = (selected[0][0], "native_op24_record") if selected[-1] == 1 else (
            (value["original"]["summaryHash"], "personhood_proof_summary") if selected[-1] == 2 else (ZERO, "none"))
        require((current["evidenceHash"], current["evidenceHashDomain"]) == expected, "personhood evidence hash domain differs")
        return value
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied native personhood fragment") from exc


def semanticProjection(snapshot, sourceRef):
    """Derive from a caller-verified canonical snapshot; no replay is performed here."""
    require(type(snapshot) is dict and snapshot.get("profile") == source.PROFILE and snapshot.get("profileHash") == source.PROFILE_HASH
        and snapshot.get("version") == "1" and snapshot.get("sourceReviewCommit") == proof.SOURCE_REVISION,
        "personhood projection source profile differs")
    require(type(sourceRef) is dict and set(sourceRef) == set(SOURCE_REF_FIELDS)
        and sourceRef["sourceProfileHash"] == source.PROFILE_HASH and sourceRef["captureProfileHash"] == capture.PROFILE_HASH
        and sourceRef["snapshotHash"] == keccak256(dumps(snapshot)) and sourceRef["anchorHash"] == snapshot["anchorHash"]
        and sourceRef["transcriptHash"] == snapshot["transcriptHash"]
        and snapshot["anchorHash"] == keccak256(dumps(snapshot["source"]))
        and snapshot["sourceState"] == {key: snapshot["source"][key] for key in source.COMMON},
        "personhood projection source commitments differ")
    current = copy.deepcopy(snapshot["current"])
    original = copy.deepcopy(snapshot["native"])
    if original is not None:
        original.setdefault("statementRetention", None); original.setdefault("summaryCarriers", [])
    doc, general_row = snapshot["documentary"], None
    if doc is not None:
        keys = ("recordHash", "attestation", "subject", "payloadHex", "payloadValue", "facts", "publication", "module",
            "moduleIdentityHash", "moduleRegistryPointer", "definitions", "carriers", "documentaryHash", "recorderHistory")
        general_row = {key: copy.deepcopy(doc[key]) for key in keys}
        general_row["authority"] = {"kind": AUTHORITY_KIND, "version": "1", "receipt": copy.deepcopy(doc["receipt"]),
            "signatureBundleHex": doc["signatureBundleHex"], "signatureHex": doc["signatureHex"],
            "domain": doc["signatureDomain"], "words": copy.deepcopy(doc["signatureWords"])}
    graph = snapshot["graph"]
    bindings = {prefix + name: None if graph[prefix] is None else graph[prefix][field]
        for prefix in ("current", "original") for name, field in (("Registry", "registry"), ("Attribution", "attribution"), ("Archive", "archive"))}
    value = {"schema": NAME, "version": 1, "sourceRef": copy.deepcopy(sourceRef), "sourceState": copy.deepcopy(snapshot["sourceState"]),
        "sourceBindings": bindings, "identities": {"currentRegistration": current["registrationIdentityRecordHash"],
            "currentOperative": current["operativeIdentityRecordHash"], "originalAttested": None if original is None else original["record"][1]},
        "current": current, "original": original, "general": general_row, "qualification": QUALIFICATION}
    return validate(dumps(value))


def documents(): return {NAME: SCHEMA_BYTES}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    path = ROOT / "schemas/records" / (NAME + ".json")
    if args.check: require(path.is_file() and path.read_bytes() == SCHEMA_BYTES, "personhood generated definition differs")
    else: path.write_bytes(SCHEMA_BYTES)
    print("Native personhood supplied-data definition matches; no source or complete-packet proof.")


if __name__ == "__main__": main()
