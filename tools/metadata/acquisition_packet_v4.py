"""Prospective packet V4: native conservation supplied data, never source authentication."""
import argparse
import copy

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from . import acquisition_packet_v2 as v2
from . import acquisition_packet_v3 as v3
from . import genesis_dossier_profile as v1
from tools.museum import public_conservation_floor_source as floor
from tools.museum import public_conservation_source as selection
from tools.museum import public_conservation_tier_source as tier_source
from tools.museum import public_conservation_capture as selection_capture
from tools.museum import public_conservation_floor_capture as floor_capture
from tools.museum import public_conservation_tier_capture as tier_capture
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from tools.museum.chain_abi import Array, encode

ROOT, MAX_BYTES, ZERO, ZERO_ADDRESS = v1.ROOT, v1.MAX_BYTES, v1.ZERO, v1.ZERO_ADDRESS
PACKET = "STREAM_ACQUISITION_PACKET_V4"
CONSERVATION = "STREAM_ACQUISITION_CONSERVATION_V4"
QUALIFICATION = (
    "Prospective unregistered V4 supplied-data schema. Exact native conservation fields, hash preimages, "
    "source context and relationships are checked. Source references and assertions do not authenticate "
    "RPC provenance, receipt inclusion, completeness, absence, signatures, underlying documentary facts, "
    "personhood, payment execution, institutional acceptance or full packet conformance. Original Metadata "
    "receipt authority and Artist op24 authority remain distinct. Current selection never replaces historical "
    "first-sale facts. Only universal_primary_v1 floor receipts are supported; unknown families fail closed.")
RULES = [
    "Numeric version4 selects V4. V1–V3 documents and validators remain unchanged; legacy conservation keeps its original meaning.",
    "Native conservation carries exact source package pins, never a fabricated tier record or signing authority.",
    "Collection/token and Artist/estate lanes remain separate. Bound-selector absence is not generic record absence; no scope/origin precedence is inferred.",
    "Historical Metadata class1 and original Artist class1/3 are separate facts. Original bytes remain in externally pinned sidecars; no signature or candidate preimage recovery is claimed.",
    "Native conservation records share Metadata collection lanes across subjects and origins: identical host/collection/type/index slots must retain identical records, and distinct supplied indices follow strictly increasing publication block/log order with gaps allowed. Full packets require matching metadata heads, index below count and final recordChainHash equal to headHash; fragments do not establish those head joins. A selection cannot name itself as predecessor.",
    "Default effective tier requires a completed mint. First-sale tier follows the original declaration position; a later pre-first-mint declaration does not rewrite an earlier prospective LITE sale.",
    "Native floor receipt hashes use zero receiptHash in the exact static tuple; source heads, release keys, original result/sale commitments and supplied publication coordinates must agree.",
    "Current heads need not equal historical floor evidence. Documentary commitment resolution and unobserved histories are not established by this validator.",
]
SOURCE_PROFILES = {
    "tier": (tier_capture.PROFILE_HASH, tier_source.PROFILE_HASH),
    "selection": (selection_capture.PROFILE_HASH, selection.PROFILE_HASH),
    "floor": (floor_capture.PROFILE_HASH, floor.PROFILE_HASH),
}
SOURCE_REF_FIELDS = ("captureProfileHash", "sourceProfileHash", "manifestHash", "anchorHash", "transcriptHash", "snapshotHash")
PUBLICATION_FIELDS = ("blockHash", "blockNumber", "transactionHash", "transactionIndex", "logIndex")
ARTIST_FIELDS = ("attestationRecordHash", "artistId", "bindingHash", "bindingGeneration", "signer", "authorityClass", "requiredCapability", "signedAt", "publicationHash")
EVIDENCE_FIELDS = ("recordHash", "recordKind", "payloadHash", "recorder", "recordedAt", "recordIndex", "recordChainHash", "receiptHash", "artist", "savedPublicationHash")
ASSOCIATION_FIELDS = ("artistId", "bindingHash", "generation", "identityRecordHash")
CATALOG_FIELDS = ("documentId", "documentHash", "byteLength")
LOCK_FIELDS = ("locker", "artistId", "identityRecordHash", "bindingHash", "generation", "recordHash", "revision", "lockedAt")
SOURCE_FIELDS = ("metadata", "metadataCodeHash", "provider", "providerCodeHash", "configurationHash", "predecessor", "admittedAt", "actionId")
COLLECTION_FIELDS = ("artistId", "identityRecordHash", "intentRecordHash", "intentWaiverRecordHash", "interviewEvidenceHash", "rightsRecordHash", "personhoodEvidenceHash", "platformWorks")
RELEASE_CONTEXT_FIELDS = ("scopeSubject", "membershipHash", "mediaInventoryHash", "scriptSourceHash", "sourceContextHash", "scriptWork")
RELEASE_FACT_FIELDS = ("sourceContextHash", "mediaEvidenceHash", "referenceEvidenceHash")
FIRST_FIELDS = ("receiptHash", "collectionId", "effectiveTier", "recorder", "settlementKey", "recordedAt", "sourceId", "sourceSetHash", "facts")
RELEASE_FIELDS = ("receiptHash", "releaseKey", "collectionId", "effectiveTier", "recorder", "settlementKey", "recordedAt", "sourceId", "sourceSetHash", "context", "facts")
SETTLEMENT_FIELDS = ("receiptHash", "recorder", "recorderCodeHash", "settlementKey", "candidatePayloadHash", "candidateCommitment", "resultHash", "collectionId", "tokenId", "effectiveTier", "firstSaleReceiptHash", "releaseReceiptHash", "recordedAt")
RESULT_FIELDS = ("candidateCommitment", "settlementKey", "profileId", "wallet", "asset", "amount", "executor", "executionId", "escrowed", "operationIdentityCommitment", "currentPolicyHash", "boundPolicyHash")
SALE_FIELDS = ("settlementId", "revenueClass", "policyMode", "collectionId", "tokenId", "saleNonce", "payer", "poster", "beneficiary", "amount", "expectedPrimaryPolicyHash")
REASONS = ("fixed_definition_inactive", "selected_catalog_inactive", "current_association_differs", "no_selected_head")


def _struct(fields, kinds, nested=None):
    nested = nested or {}
    def kind(name, item):
        if name in nested: return v1.ref(nested[name])
        if item == "bool": return {"type": "boolean"}
        return v1.ref("hash0" if item == "bytes32" else "address0" if item == "address" else item)
    return v1.closed({name: kind(name, item) for name, item in zip(fields, kinds)})


def definitions():
    d = copy.deepcopy(v3.definitions()); r, c = v1.ref, v1.closed
    d["packet"]["properties"].update(schema={"const": PACKET}, version={"const": 4})
    d["legacyConservation"] = d.pop("conservation")
    d["nativePublication"] = c({"blockHash": r("hash"), "blockNumber": r("uint64"), "transactionHash": r("hash"),
        "transactionIndex": r("uint64"), "logIndex": r("uint32")})
    d["nativeSourceRef"] = c({key: r("hash") for key in SOURCE_REF_FIELDS})
    d["nativeEligibility"] = c({"checked": {"type": "boolean"}, "eligible": {"type": "boolean"},
        "reasons": {**v1.array(v1.enum(*REASONS), maximum=4), "uniqueItems": True}})
    d["nativeArtistEvidence"] = _struct(ARTIST_FIELDS, selection.EVIDENCE)
    d["nativeRecordEvidence"] = _struct(EVIDENCE_FIELDS, selection.RECORD_EVIDENCE, {"artist": "nativeArtistEvidence"})
    d["nativeRecord"] = c({"evidence": r("nativeRecordEvidence"), "original": c({
        "host": r("address"), "subjectId": r("hash"), "recordType": r("hash"), "schemaId": r("hash"),
        "metadataAuthorityClass": {"const": "1"}, "originalRecordBytesHash": r("hash"),
        "payloadBytesHash": r("hash"), "statementBytesHash": r("hash"), "signatureBundleHash": r("hash"),
        "publication": r("nativePublication")})})
    d["nativeAssociation"] = _struct(ASSOCIATION_FIELDS, selection.ASSOCIATION)
    d["nativeCatalogPin"] = _struct(CATALOG_FIELDS, selection.CATALOG_PIN)
    d["nativeSelection"] = c({"record": r("nativeRecord"), "association": r("nativeAssociation"),
        "statementOrigin": v1.enum("artist", "estate"), "interviewStatus": v1.enum("present", "waived"),
        "interview": v1.nullable(r("nativeRecord")), "interviewReferenceHash": r("hash0"),
        "interviewPayloadCorrespondence": r("uint8"), "predecessorRecordHash": r("hash0"), "selector": r("address"),
        "revision": r("uint64"), "selectedAt": r("uint64"), "catalogHash": r("hash"), "selectionHash": r("hash"),
        "catalogs": v1.array(r("nativeCatalogPin"), maximum=selection.MAX_CATALOGS), "publication": r("nativePublication"),
        "currentEligibility": r("nativeEligibility")})
    d["nativeLane"] = v1.choice(v1.tagged("absent_on_bound_selector", currentEligibility=r("nativeEligibility")),
        v1.tagged("selected", selection=r("nativeSelection")))
    lock = _struct(LOCK_FIELDS, selection.LOCK[1:])["properties"]
    d["nativeLock"] = v1.choice(v1.tagged("unlocked"), v1.tagged("locked", **lock, publication=r("nativePublication")))
    d["nativeScope"] = c({"subjectId": r("hash"), "artist": r("nativeLane"), "estate": r("nativeLane"), "lock": r("nativeLock")})
    d["nativeTierDeclaration"] = c({"tier": v1.enum(*floor.TIERS.values()), "tierHash": r("hash"), "metadataHost": r("address"),
        "blockTimestamp": r("uint64"), "publication": r("nativePublication"), "facadePublication": r("nativePublication")})
    d["nativeFirstMint"] = c({"tokenId": r("uint256"), "collectionSerial": r("uint256"), "recipient": r("address"),
        "blockTimestamp": r("uint64"), "publication": r("nativePublication")})
    d["nativeTier"] = c({"rawDeclaredTier": r("hash0"), "tierBasis": v1.enum("declared", "default", "not_yet_effective"),
        "effectiveTier": v1.nullable(v1.enum(*floor.TIERS.values())), "prospectiveSaleTier": v1.enum(*floor.TIERS.values()),
        "declaration": v1.nullable(r("nativeTierDeclaration")), "firstCompletedMint": v1.nullable(r("nativeFirstMint")),
        "completedMintCount": r("uint256"), "nextCollectionSerial": r("uint256")})
    d["nativeFloorSource"] = c({**_struct(SOURCE_FIELDS, floor.SOURCE)["properties"], "sourceId": r("uint64"),
        "head": r("hash"), "publication": r("nativePublication")})
    d["nativeCollectionFacts"] = _struct(COLLECTION_FIELDS, floor.COLLECTION_FACTS)
    d["nativeReleaseContext"] = _struct(RELEASE_CONTEXT_FIELDS, floor.RELEASE_CONTEXT)
    d["nativeReleaseFacts"] = _struct(RELEASE_FACT_FIELDS, floor.RELEASE_FACTS)
    d["nativeFirstSale"] = c({**_struct(FIRST_FIELDS, floor.FIRST, {"facts": "nativeCollectionFacts"})["properties"], "publication": r("nativePublication")})
    d["nativeReleaseReceipt"] = c({**_struct(RELEASE_FIELDS, floor.RELEASE, {"context": "nativeReleaseContext", "facts": "nativeReleaseFacts"})["properties"], "publication": r("nativePublication")})
    d["nativePrimaryResult"] = _struct(RESULT_FIELDS, floor.RESULT)
    d["nativePrimarySale"] = _struct(SALE_FIELDS, floor.SALE)
    d["nativeSettlementReceipt"] = c({**_struct(SETTLEMENT_FIELDS, floor.SETTLEMENT)["properties"],
        "publication": r("nativePublication"), "result": r("nativePrimaryResult"), "sale": r("nativePrimarySale"),
        "saleAdapter": r("address"), "saleContextHash": r("hash")})
    d["nativeHistoricalFloor"] = c({"kind": {"const": "universal_primary_v1"}, "host": r("address"),
        "status": v1.enum("present", "none_recorded"), "sourceCount": r("uint64"), "sourceHead": r("hash"),
        "sources": v1.array(r("nativeFloorSource"), maximum=floor.MAX_SOURCES),
        "firstSale": v1.nullable(r("nativeFirstSale")), "releases": v1.array(r("nativeReleaseReceipt"), maximum=floor.MAX_RECEIPTS),
        "settlements": v1.array(r("nativeSettlementReceipt"), maximum=floor.MAX_RECEIPTS)})
    d["nativeConservation"] = c({"kind": {"const": "native_conservation"}, "version": {"const": "1"},
        "sourceRefs": c({key: c({**d["nativeSourceRef"]["properties"], "captureProfileHash": {"const": pins[0]},
            "sourceProfileHash": {"const": pins[1]}}) for key, pins in SOURCE_PROFILES.items()}), "sourceBlockTimestamp": r("uint64"),
        "coreRuntimeHash": r("hash"), "metadataHost": r("address"), "conservationSelector": r("address"),
        "schemaRegistry": r("address"), "store": r("address"), "tier": r("nativeTier"),
        "scopes": c({key: r("nativeScope") for key in ("collection", "token")}), "historicalFloor": r("nativeHistoricalFloor")})
    d["conservation"] = v1.choice(r("legacyConservation"), r("nativeConservation"))
    return d


def _schema(name, root):
    d = definitions(); selected, pending = {}, [root]
    while pending:
        key = pending.pop()
        if key in selected: continue
        selected[key] = d[key]
        pending.extend(row["$ref"].split("/")[-1] for row in v1._walk(d[key]) if "$ref" in row)
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + name,
        "title": name, "description": QUALIFICATION, **v1.ref(root), "$defs": selected,
        "x-stream-base-packet": {"name": v3.PACKET, "hash": v3.PACKET_SCHEMA_HASH},
        "x-stream-native-owner-authority-profile": {"name": v2.PROFILE, "hash": v2.PROFILE_HASH},
        "x-stream-constraints": [*v1.CONSTRAINTS, *(rule.removeprefix("Packet version is numeric2. ") for rule in v2.RULES),
            *[rule for rule in v3.RULES if not rule.startswith("Numeric packet version3")], *RULES],
        "x-stream-source-profile-pins": {k: list(v) for k, v in SOURCE_PROFILES.items()},
        **({"x-stream-CMC-ACQUISITION-PACKET": v1.PACKET_REQUIREMENTS} if root == "packet" else {})}


PACKET_SCHEMA_BYTES = dumps(_schema(PACKET, "packet"))
PACKET_SCHEMA_HASH = keccak256(PACKET_SCHEMA_BYTES)
CONSERVATION_SCHEMA_BYTES = dumps(_schema(CONSERVATION, "conservation"))
CONSERVATION_SCHEMA_HASH = keccak256(CONSERVATION_SCHEMA_BYTES)


def _tuple(row, fields, kinds, nested=None):
    nested = nested or {}
    return tuple(_tuple(row[name], *nested[name]) if name in nested else
        uint(row[name], int(kind[4:])) if isinstance(kind, str) and kind.startswith("uint") else row[name]
        for name, kind in zip(fields, kinds))


def _named(row, fields, kinds, nested=None):
    nested = nested or {}
    return {name: _named(value, *nested[name]) if name in nested else str(value) if type(value) is int else value
        for name, kind, value in zip(fields, kinds, row)}


def _pub(log):
    return {k: str(int(log[k], 16)) if k in ("blockNumber", "transactionIndex", "logIndex") and log[k].startswith("0x") else log[k]
        for k in PUBLICATION_FIELDS}


def _pos(row): return tuple(uint(row[k]) for k in ("blockNumber", "transactionIndex", "logIndex"))


class _Observations:
    """Reject contradictions in supplied coordinates, without claiming chain authentication."""
    def __init__(self, source, timestamp):
        self.source = source
        self.numbers = {uint(source["blockNumber"]): source["blockHash"]}
        self.hashes = {source["blockHash"]: uint(source["blockNumber"])}
        self.times = {uint(source["blockNumber"]): uint(timestamp)}
        self.txs, self.slots, self.logs = {}, {}, {}

    def add(self, publication, timestamp, identity):
        n, h = uint(publication["blockNumber"]), publication["blockHash"]
        v1.need(n <= uint(self.source["blockNumber"]), "native publication beyond source block")
        v1.need(self.numbers.get(n, h) == h and self.hashes.get(h, n) == n, "native block mapping differs")
        self.numbers[n], self.hashes[h] = h, n
        tx, i, j = publication["transactionHash"], uint(publication["transactionIndex"]), uint(publication["logIndex"])
        v1.need(self.txs.get(tx, (h, i)) == (h, i) and self.slots.get((h, i), tx) == tx, "native transaction mapping differs")
        v1.need(self.logs.get((h, j), (tx, identity)) == (tx, identity), "native event slot differs")
        self.txs[tx], self.slots[h, i], self.logs[h, j] = (h, i), tx, (tx, identity)
        if timestamp is not None:
            t = uint(timestamp, 64)
            v1.need(t <= uint(self.source["examinedAt"]) and self.times.get(n, t) == t, "native publication timestamp differs")
            self.times[n] = t

    def finish(self):
        stamps = [self.times[n] for n in sorted(self.times)]
        v1.need(stamps == sorted(stamps), "native publication timestamp regresses")
        for h in self.hashes:
            indices = [self.txs[tx][1] for (block, _), (tx, _) in sorted(self.logs.items()) if block == h]
            v1.need(indices == sorted(indices), "native transaction/log ordering differs")


def _legacy_conservation(c):
    v1.need((c["tierRecord"] is None) == (c["tierBasis"] == "default"), "conservation tier basis")
    if c["tierBasis"] == "default": v1.need(c["tier"] == "MUSEUM_GRADE_LITE", "default tier")
    if c["artistIntent"]["status"] == "present": v1.need(v1._kind(c["artistIntent"]["record"], "ARTIST_INTENT"), "intent type")
    else: v1.need(v1._kind(c["artistIntent"]["waiver"], "ARTIST_INTENT_WAIVER"), "intent waiver type")
    if c["interview"]["status"] == "present": v1.need(c["interview"]["record"]["schemaId"] == schema_id("STREAM_ARTIST_INTERVIEW_V1"), "interview schema")
    if c["interview"]["status"] == "waived": v1.need(v1._kind(c["interview"]["waiver"], "ARTIST_INTENT", "ARTIST_INTENT_WAIVER"), "interview waiver statement carrier")


def _tier(c, source, obs):
    t = c["tier"]; raw, declaration, mint = t["rawDeclaredTier"], t["declaration"], t["firstCompletedMint"]
    v1.need(raw == ZERO or raw in floor.TIERS, "unknown native tier")
    count, serial = uint(t["completedMintCount"]), uint(t["nextCollectionSerial"])
    v1.need(count < serial and serial > 0 and (mint is None) == (count == 0), "native first completed mint/count")
    if mint:
        v1.need(uint(mint["tokenId"]) > 0 and 0 < uint(mint["collectionSerial"]) < serial, "native first mint identity")
        obs.add(mint["publication"], mint["blockTimestamp"], ("transfer", ZERO_ADDRESS, mint["recipient"], mint["tokenId"]))
    v1.need((declaration is None) == (raw == ZERO), "native tier declaration/raw join")
    if declaration:
        v1.need(declaration["tierHash"] == raw and declaration["tier"] == floor.TIERS[raw], "native tier declaration differs")
        obs.add(declaration["publication"], declaration["blockTimestamp"], ("tier", raw))
        obs.add(declaration["facadePublication"], declaration["blockTimestamp"], ("tier_facade", raw))
        v1.need(declaration["publication"]["transactionHash"] == declaration["facadePublication"]["transactionHash"]
            and _pos(declaration["publication"]) < _pos(declaration["facadePublication"]), "native tier facade order")
        v1.need(mint is None or _pos(declaration["facadePublication"]) < _pos(mint["publication"]), "native tier declaration after first mint")
    basis = "declared" if declaration else "default" if count else "not_yet_effective"
    effective = floor.TIERS[raw] if declaration else "MUSEUM_GRADE_LITE" if count else None
    v1.need(t["tierBasis"] == basis and t["effectiveTier"] == effective and
        t["prospectiveSaleTier"] == (floor.TIERS[raw] if declaration else "MUSEUM_GRADE_LITE"), "native tier basis/effective differs")
    # A packet's original token is completed, even if subsequently burned.
    v1.need(count > 0 and mint is not None and uint(mint["tokenId"]) <= uint(source["tokenId"])
        and uint(mint["collectionSerial"]) <= uint(source["collectionSerial"]), "native token requires completed mint")
    v1.need(uint(source["collectionSerial"]) < serial, "native target serial exceeds allocation high-water")
    v1.need(uint(mint["collectionSerial"]) + count <= serial, "native completed mint count exceeds remaining serial slots")
    v1.need(mint["tokenId"] == source["tokenId"] or count >= 2, "native nonfirst target requires two completed mints")
    v1.need((mint["tokenId"] == source["tokenId"]) == (mint["collectionSerial"] == source["collectionSerial"]), "native first mint token/serial correspondence")


def _record(row, subject, c, obs, seen):
    e, original = row["evidence"], row["original"]; a = e["artist"]
    kind = uint(e["recordKind"], 8)
    v1.need(kind in (0, 1, 2) and original["host"] == c["metadataHost"] and original["subjectId"] == subject
        and original["recordType"] == selection.RECORD_TYPES[kind] and original["schemaId"] == schema_id(selection.FAMILIES[kind]), "native record family/subject")
    v1.need(e["payloadHash"] == original["payloadBytesHash"] and e["recordHash"] != ZERO
        and all(e[k] != ZERO for k in ("payloadHash", "recordChainHash", "receiptHash", "savedPublicationHash")), "native record commitments")
    v1.need(a["signer"] == e["recorder"] != ZERO_ADDRESS and a["authorityClass"] in ("1", "3")
        and all(a[k] != ZERO for k in ("attestationRecordHash", "artistId", "bindingHash", "publicationHash"))
        and uint(a["bindingGeneration"]) > 0 and 0 < uint(a["signedAt"]) <= uint(e["recordedAt"])
        and uint(a["requiredCapability"]) == (1 if kind == 2 else 64), "native original Artist authority")
    key = (original["host"], e["recordHash"])
    v1.need(key not in seen or seen[key] == row, "native repeated original record differs"); seen[key] = row
    obs.add(original["publication"], e["recordedAt"], ("metadata", *key))
    return _tuple(e, EVIDENCE_FIELDS, selection.RECORD_EVIDENCE, {"artist": (ARTIST_FIELDS, selection.EVIDENCE)})


def _eligibility(value, *, absent=False):
    reasons = value["reasons"]
    if absent:
        v1.need(value == {"checked": False, "eligible": False, "reasons": ["no_selected_head"]}, "native absent selector eligibility")
    else:
        v1.need("no_selected_head" not in reasons and value["checked"] == value["eligible"] == (not reasons), "native consuming eligibility contradiction")


def _scopes(c, source, obs):
    seen = {}
    for scope_name, scope in c["scopes"].items():
        expected = source["subjectId" if scope_name == "token" else "collectionSubjectId"]
        v1.need(scope["subjectId"] == expected, "native scope subject")
        for origin in ("artist", "estate"):
            lane = scope[origin]
            if lane["status"] == "absent_on_bound_selector":
                _eligibility(lane["currentEligibility"], absent=True); continue
            h = lane["selection"]; e = _record(h["record"], expected, c, obs, seen); association = h["association"]
            v1.need(e[1] in (0, 1) and h["statementOrigin"] == origin and e[8][5] == (1 if origin == "artist" else 3), "native origin/authority class")
            v1.need(tuple(association[k] for k in ASSOCIATION_FIELDS[:3]) == (e[8][1], e[8][2], str(e[8][3]))
                and association["identityRecordHash"] != ZERO, "native selection original association")
            v1.need(uint(h["revision"]) > 0 and (h["predecessorRecordHash"] == ZERO) == (h["revision"] == "1")
                and uint(h["selectedAt"]) >= e[4] and h["selector"] != ZERO_ADDRESS, "native selected revision/time")
            v1.need(h["predecessorRecordHash"] != e[0], "native selection self predecessor")
            _eligibility(h["currentEligibility"])
            obs.add(h["publication"], h["selectedAt"], ("selection", expected, origin, h["revision"]))
            v1.need(_pos(h["record"]["original"]["publication"]) < _pos(h["publication"]), "native selection before record")
            interview = selection.EMPTY_RECORD
            if h["interviewStatus"] == "present":
                v1.need(h["interview"] is not None and h["interviewReferenceHash"] != ZERO and h["interviewPayloadCorrespondence"] in ("0", "1", "2"), "native present interview")
                interview = _record(h["interview"], expected, c, obs, seen)
                v1.need(interview[1] == 2 and interview[8][1:4] == e[8][1:4]
                    and _pos(h["interview"]["original"]["publication"]) < _pos(h["publication"]), "native parent interview association/order")
            else:
                v1.need(h["interview"] is None and h["interviewReferenceHash"] == ZERO and h["interviewPayloadCorrespondence"] == "0", "native interview waiver")
            pins = tuple(_tuple(p, CATALOG_FIELDS, selection.CATALOG_PIN) for p in h["catalogs"])
            v1.need(all(p[0] != ZERO and p[1] != ZERO and p[2] > 0 for p in pins)
                and keccak256(encode((Array(selection.CATALOG_PIN, selection.MAX_CATALOGS),), (pins,))) == h["catalogHash"], "native ordered catalog hash")
            v1.need(h["interviewStatus"] == "present" or not pins, "native waived interview catalogs")
            native = (e, _tuple(association, ASSOCIATION_FIELDS, selection.ASSOCIATION), 0 if origin == "artist" else 1,
                0 if h["interviewStatus"] == "present" else 1, interview, h["interviewReferenceHash"], uint(h["interviewPayloadCorrespondence"]),
                h["predecessorRecordHash"], h["selector"], uint(h["revision"]), uint(h["selectedAt"]), h["catalogHash"], h["selectionHash"])
            anchor = {**source, "conservationSelector": c["conservationSelector"], "host": c["metadataHost"], "schemas": c["schemaRegistry"], "store": c["store"]}
            v1.need(selection.selection_hash(anchor, expected, native) == h["selectionHash"], "native selection hash")
        lock = scope["lock"]
        if lock["status"] == "locked":
            v1.need(scope["artist"]["status"] == "selected", "native lock without Artist selection")
            h = scope["artist"]["selection"]; a = h["association"]
            v1.need(lock["locker"] != ZERO_ADDRESS and all(lock[k] == a[k] for k in ASSOCIATION_FIELDS)
                and lock["recordHash"] == h["record"]["evidence"]["recordHash"] and lock["revision"] == h["revision"]
                and uint(lock["lockedAt"]) >= uint(h["selectedAt"]) and _pos(lock["publication"]) > _pos(h["publication"]), "native intent lock differs")
            obs.add(lock["publication"], lock["lockedAt"], ("lock", expected))
    return tuple(seen.values())


def _record_lanes(records, source, heads=None):
    """Check supplied Metadata lane slots; token/Artist/estate are not separate lanes."""
    lanes = {}
    head_map = None if heads is None else {v1._head_key(head): head for head in heads}
    for row in records:
        evidence, original = row["evidence"], row["original"]
        key = ("metadata", original["host"], source["collectionId"], original["recordType"])
        index = uint(evidence["recordIndex"])
        slots = lanes.setdefault(key, {})
        v1.need(index not in slots or slots[index] == row, "native metadata record index collision")
        slots[index] = row
        if head_map is not None:
            v1.need(key in head_map, "native metadata matching record head missing")
            head = head_map[key]; count = uint(head["count"])
            v1.need(index < count, "native metadata record index exceeds supplied head count")
            v1.need(index + 1 != count or evidence["recordChainHash"] == head["headHash"],
                "native metadata last receipt chain differs from supplied head")
    for slots in lanes.values():
        positions = [tuple(uint(row["original"]["publication"][k]) for k in ("blockNumber", "logIndex"))
            for _, row in sorted(slots.items())]
        v1.need(all(before < after for before, after in zip(positions, positions[1:])),
            "native metadata record index publication order differs")


def _floor(c, source, obs):
    f = c["historicalFloor"]; anchor = {**source, "conservationFloor": f["host"]}
    previous = floor.empty_head(anchor); admissions = []
    for index, item in enumerate(f["sources"], 1):
        native = _tuple(item, SOURCE_FIELDS, floor.SOURCE)
        v1.need(item["sourceId"] == str(index) and item["predecessor"] == str(index - 1)
            and native[0] != ZERO_ADDRESS and native[2] != ZERO_ADDRESS and all(native[k] != ZERO for k in (1, 3, 4, 7))
            and native[6] > 0, "native floor source identity/predecessor")
        v1.need(not admissions or (native[0], native[2]) != (admissions[-1]["metadata"], admissions[-1]["provider"]), "native repeated adjacent floor source")
        v1.need(not admissions or _pos(item["publication"]) > _pos(admissions[-1]["publication"]), "native source admission order")
        previous = floor.next_head(previous, index, native)
        v1.need(previous == item["head"], "native floor source head")
        obs.add(item["publication"], item["admittedAt"], ("floor_source", item["sourceId"])); admissions.append(item)
    v1.need(uint(f["sourceCount"]) == len(admissions) and f["sourceHead"] == previous, "native floor source count/head")
    first, releases, settlements = f["firstSale"], f["releases"], f["settlements"]
    v1.need((f["status"] == "none_recorded") == (first is None) and len(releases) + len(settlements) + (first is not None) <= floor.MAX_RECEIPTS, "native floor status/bound")
    if first is None:
        v1.need(not releases and not settlements, "native absent floor has receipts"); return
    v1.need(settlements, "native floor first sale lacks settlement")
    def receipt(row, fields, kinds, domain, nested=None):
        native = _tuple(row, fields, kinds, nested)
        v1.need(row["collectionId"] == source["collectionId"] and row["effectiveTier"] in floor.TIERS
            and row["recorder"] != ZERO_ADDRESS and row["settlementKey"] != ZERO and uint(row["recordedAt"]) > 0
            and floor.receipt_hash(anchor, domain, kinds, native) == row["receiptHash"], "native floor receipt scope/hash/time")
        obs.add(row["publication"], row["recordedAt"], ("floor", domain, row["receiptHash"]))
        return native
    def admitted(row, waived=False):
        prior = [a for a in admissions if _pos(a["publication"]) < _pos(row["publication"])]
        head = prior[-1]["head"] if prior else floor.empty_head(anchor)
        v1.need(uint(row["sourceId"]) == (0 if waived else len(prior)) and (waived or prior)
            and row["sourceSetHash"] == head, "native historical source admission")
    first_native = receipt(first, FIRST_FIELDS, floor.FIRST, floor.FIRST_DOMAIN, {"facts": (COLLECTION_FIELDS, floor.COLLECTION_FACTS)})
    waived = first["effectiveTier"] == floor.WAIVED; facts = first_native[8]; admitted(first, waived)
    if waived: v1.need(facts == (ZERO,) * 7 + (False,), "native waived floor facts")
    elif facts[7]: v1.need(facts[:5] == (ZERO,) * 5 and facts[5] != ZERO and facts[6] == ZERO, "native platform floor facts")
    else: v1.need(all(facts[k] != ZERO for k in (0, 1, 4, 5, 6)) and (facts[2] == ZERO) != (facts[3] == ZERO), "native Artist floor facts")
    declaration = c["tier"]["declaration"]
    original_tier = declaration["tierHash"] if declaration and _pos(declaration["publication"]) < _pos(first["publication"]) else schema_id("MUSEUM_GRADE_LITE")
    v1.need(first["effectiveTier"] == original_tier, "native first-sale historical tier")
    by_key, by_release = {}, {}
    for row in settlements:
        receipt(row, SETTLEMENT_FIELDS, floor.SETTLEMENT, floor.SETTLEMENT_DOMAIN)
        sale_tier = declaration["tierHash"] if declaration and _pos(declaration["publication"]) < _pos(row["publication"]) else schema_id("MUSEUM_GRADE_LITE")
        v1.need(row["effectiveTier"] == sale_tier, "native settlement historical tier")
        v1.need(row["settlementKey"] not in by_key and (not by_key or _pos(row["publication"]) > _pos(list(by_key.values())[-1]["publication"])), "native settlement duplicate/order")
        v1.need(row["firstSaleReceiptHash"] == first["receiptHash"] and row["effectiveTier"] == first["effectiveTier"]
            and all(row[k] != ZERO for k in ("recorderCodeHash", "candidatePayloadHash", "candidateCommitment", "resultHash")), "native settlement first/commitments")
        result, sale = _tuple(row["result"], RESULT_FIELDS, floor.RESULT), _tuple(row["sale"], SALE_FIELDS, floor.SALE)
        v1.need(keccak256(encode((floor.RESULT,), (result,))) == row["resultHash"] and result[:2] == (row["candidateCommitment"], row["settlementKey"])
            and result[2] != ZERO and result[3] != ZERO_ADDRESS and result[5] > 0 and result[6] != ZERO_ADDRESS and result[7] != ZERO, "native stored primary result")
        key = keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32"),
            (floor.KEY_DOMAIN, uint(source["chainId"]), row["recorder"], row["saleAdapter"], result[7])))
        v1.need(key == row["settlementKey"] and sale[0] != ZERO and sale[1] == floor.PRIMARY and sale[3:5] == (uint(source["collectionId"]), uint(row["tokenId"]))
            and sale[5] > 0 and sale[6] != ZERO_ADDRESS and sale[8] != ZERO_ADDRESS and sale[9] == result[5] and sale[10] != ZERO
            and keccak256(encode((floor.SALE,), (sale,))) == row["saleContextHash"], "native original primary sale")
        v1.need((result[9] == ZERO and sale[4] > 0 and result[10:] == (ZERO, ZERO)) or
            (result[9] != ZERO and all(h != ZERO for h in result[10:])), "native primary operation projection")
        by_key[row["settlementKey"]] = row
    def created(row, creator):
        v1.need(row["settlementKey"] == creator["settlementKey"] and row["recorder"] == creator["recorder"]
            and row["recordedAt"] == creator["recordedAt"] and row["effectiveTier"] == creator["effectiveTier"]
            and row["publication"]["transactionHash"] == creator["publication"]["transactionHash"]
            and _pos(row["publication"]) < _pos(creator["publication"]), "native floor creating settlement")
    created(first, settlements[0]); release_keys = set()
    for row in releases:
        native = receipt(row, RELEASE_FIELDS, floor.RELEASE, floor.RELEASE_DOMAIN,
            {"context": (RELEASE_CONTEXT_FIELDS, floor.RELEASE_CONTEXT), "facts": (RELEASE_FACT_FIELDS, floor.RELEASE_FACTS)})
        context, facts = native[9:11]; admitted(row)
        v1.need(not waived and row["releaseKey"] not in release_keys and row["receiptHash"] not in by_release
            and (not by_release or _pos(row["publication"]) > _pos(list(by_release.values())[-1]["publication"])), "native release duplicate/order")
        v1.need(floor.release_key(anchor, uint(source["collectionId"]), context) == row["releaseKey"] and all(context[k] != ZERO for k in (0, 1, 2, 4))
            and context[5] == (context[3] != ZERO) and facts[0] == context[4] and facts[1] != ZERO
            and (context[5] or facts[2] == ZERO) and (row["effectiveTier"] != floor.FULL or not context[5] or facts[2] != ZERO), "native release key/facts")
        v1.need(row["settlementKey"] in by_key, "native release creating settlement absent")
        creator = by_key[row["settlementKey"]]; created(row, creator)
        v1.need(creator["releaseReceiptHash"] == row["receiptHash"] and uint(row["publication"]["logIndex"]) + 1 == uint(creator["publication"]["logIndex"]), "native release creation order/hash")
        by_release[row["receiptHash"]] = row; release_keys.add(row["releaseKey"])
    first_release = next((r for r in releases if r["settlementKey"] == first["settlementKey"]), None)
    v1.need(uint(first["publication"]["logIndex"]) + 1 == uint((first_release or settlements[0])["publication"]["logIndex"]), "native first receipt order")
    for row in settlements:
        h = row["releaseReceiptHash"]
        if waived: v1.need(h == ZERO and not releases, "native waived release")
        else: v1.need(h in by_release and _pos(by_release[h]["publication"]) < _pos(row["publication"]), "native historical release link")


def _packet_observations(packet, source, obs, timestamp):
    """Join actual native-owner references and available transfer coordinates."""
    owner_keys = set(v2.definitions()["nativeOwnerRecord"]["properties"])
    for record in v1._walk(packet):
        if set(record) != owner_keys: continue
        authority = record["authority"]; state = authority["ownerState"]; transfer = state["transfer"]
        v1.need(state["sourceBlockTimestamp"] == timestamp, "native owner/conservation source timestamp differs")
        obs.add(authority["publication"], authority["receipt"]["recordedAt"], ("owner", record["host"], record["recordHash"]))
        obs.add(transfer, None, ("transfer", transfer["from"], transfer["to"], source["tokenId"]))
    # V1 transfer rows lack hash/index; check only coordinates actually supplied.
    for transfer in packet["ownershipProvenance"]["transfers"]:
        n, tx, j = uint(transfer["blockNumber"]), transfer["transactionHash"], uint(transfer["logIndex"])
        h = obs.numbers.get(n)
        if tx in obs.txs:
            v1.need(obs.hashes[obs.txs[tx][0]] == n, "native transfer transaction block differs")
        if h is not None and (h, j) in obs.logs:
            v1.need(obs.logs[h, j] == (tx, ("transfer", transfer["from"], transfer["to"], source["tokenId"])), "native transfer occupied event slot differs")
    mint = packet["conservation"]["tier"]["firstCompletedMint"]
    if mint["tokenId"] == source["tokenId"]:
        transfer = packet["ownershipProvenance"]["transfers"][0]
        v1.need(transfer["from"] == ZERO_ADDRESS and transfer["to"] == mint["recipient"]
            and all(transfer[k] == mint["publication"][k] for k in ("blockNumber", "transactionHash", "logIndex")), "native first mint/ownership history differs")


def _conservation(c, source, packet=None):
    if c.get("kind") != "native_conservation":
        _legacy_conservation(c); v1._record_context(c, source); return
    v1.need(uint(c["sourceBlockTimestamp"]) <= uint(source["examinedAt"]), "native source timestamp after examination")
    for key, pins in SOURCE_PROFILES.items():
        v1.need(tuple(c["sourceRefs"][key][name] for name in SOURCE_REF_FIELDS[:2]) == pins, "native source profile pins differ")
    obs = _Observations(source, c["sourceBlockTimestamp"])
    _tier(c, source, obs)
    records = _scopes(c, source, obs)
    _record_lanes(records, source, None if packet is None else packet["recordChainHeads"])
    _floor(c, source, obs)
    if packet is not None: _packet_observations(packet, source, obs, c["sourceBlockTimestamp"])
    obs.finish()


def _curated(curated, conservation):
    v1.need(v1._kind(curated["attestation"], "INSTITUTIONAL_VERIFICATION", "INDEPENDENT_CONDITION"), "curated attestation type")
    if conservation.get("kind") != "native_conservation":
        intent = conservation["artistIntent"]
        v1.need(intent["status"] == "present" and curated["artistIntentRecordHash"] == intent["record"]["recordHash"], "curated attestation/intent join")
        return
    matches = []
    for scope in conservation["scopes"].values():
        lane = scope["artist"]
        if lane["status"] != "selected": continue
        h = lane["selection"]; record = h["record"]
        if record["evidence"]["recordHash"] == curated["artistIntentRecordHash"]:
            v1.need(record["evidence"]["recordKind"] == "0" and h["currentEligibility"]["eligible"], "curated native intent must be eligible Artist intent")
            matches.append(record)
    v1.need(matches and all(record == matches[0] for record in matches), "curated exact native Artist intent missing/ambiguous")


def _errors(call):
    try: return call()
    except (ValidationError, MuseumError, ValueError, TypeError, KeyError, IndexError, RecursionError, OverflowError) as exc:
        if isinstance(exc, v1.DossierError): raise
        raise v1.DossierError(str(exc)) from exc


def validate_conservation(raw, source_state):
    """Validate supplied item13 data; no capture replay or source authentication occurs."""
    def run():
        v2._source_context(source_state)
        value = v2._parse(raw, CONSERVATION_SCHEMA_BYTES)
        _conservation(value, source_state)
        return value
    return _errors(run)


def validate(raw):
    def run():
        value = v2._parse(raw, PACKET_SCHEMA_BYTES)
        _packet(value)
        v2._record_context(value, value["sourceState"], value["ownershipProvenance"], value["recordChainHeads"])
        for binding in value["ownershipProvenance"]["titleBindings"]:
            if "authority" in binding["record"]:
                hop = value["ownershipProvenance"]["transfers"][uint(binding["transferIndex"])]
                v1.need(v2._before(hop, binding["record"]["authority"]["publication"]), "native owner title transfer must precede publication")
        return value
    return _errors(run)


def project(tier_snapshot, selection_snapshot, floor_snapshot, source_refs, source_state):
    """Project supplied snapshots. The caller owns replay/authentication; hashes alone prove neither."""
    def run():
        snapshots = {"tier": tier_snapshot, "selection": selection_snapshot, "floor": floor_snapshot}
        ss = selection_snapshot["source"]; stamp = ss["timestamp"]
        for key, snapshot in snapshots.items():
            state = snapshot["source"] if key == "selection" else snapshot["sourceState"]
            v1.need(all(state[k] == source_state[k] for k in ("chainId", "core", "collectionId", "blockHash", "blockNumber"))
                and state["timestamp"] == stamp and state["environment"] == ss["environment"], "native snapshot source context differs")
            v1.need(snapshot["profileHash"] == SOURCE_PROFILES[key][1] and snapshot["anchorHash"] == source_refs[key]["anchorHash"]
                and snapshot["transcriptHash"] == source_refs[key]["transcriptHash"] and keccak256(dumps(snapshot)) == source_refs[key]["snapshotHash"], "native snapshot pin differs")
        identity = selection_snapshot["identity"]
        v1.need(all(identity[k] == source_state[k] for k in ("tokenId", "collectionId", "collectionSerial", "burned")), "native token snapshot identity differs")
        value = {"kind": "native_conservation", "version": "1", "sourceRefs": copy.deepcopy(source_refs), "sourceBlockTimestamp": stamp,
            "coreRuntimeHash": tier_snapshot["sourceState"]["coreRuntimeHash"], "metadataHost": ss["host"],
            "conservationSelector": ss["conservationSelector"], "schemaRegistry": ss["schemas"], "store": ss["store"]}
        v1.need(next(p["runtimeHash"] for p in ss["codePins"] if p["address"] == ss["core"]) == value["coreRuntimeHash"], "native shared Core runtime differs")
        original_tier = tier_snapshot["tier"]
        value["tier"] = {k: copy.deepcopy(original_tier[k]) for k in definitions()["nativeTier"]["properties"]}
        declaration = value["tier"]["declaration"]
        if declaration:
            value["tier"]["declaration"] = {k: declaration[k] for k in ("tier", "tierHash", "metadataHost", "blockTimestamp", "publication")}
            value["tier"]["declaration"]["facadePublication"] = _pub(declaration["facadeEvent"])
        mint = value["tier"]["firstCompletedMint"]
        if mint: value["tier"]["firstCompletedMint"] = {k: mint[k] for k in definitions()["nativeFirstMint"]["properties"]}
        originals = {r["recordHash"]: r for r in selection_snapshot["records"]}
        def record(e):
            o = originals[e[0]]; wire = o["record"]
            return {"evidence": _named(e, EVIDENCE_FIELDS, selection.RECORD_EVIDENCE, {"artist": (ARTIST_FIELDS, selection.EVIDENCE)}),
                "original": {"host": ss["host"], "subjectId": wire[1], "recordType": wire[0], "schemaId": wire[4],
                    "metadataAuthorityClass": o["receipt"][2], "originalRecordBytesHash": keccak256(dumps(wire)),
                    "payloadBytesHash": keccak256(hex_bytes(o["payloadHex"])), "statementBytesHash": keccak256(hex_bytes(o["statementHex"])),
                    "signatureBundleHash": keccak256(hex_bytes(o["signatureHex"])), "publication": _pub(o["publication"])}}
        value["scopes"] = {}
        for scope_name, original in selection_snapshot["scopes"].items():
            scope = {"subjectId": original["subjectId"]}
            for origin, lane in original["origins"].items():
                if lane["status"] == "absent_on_bound_selector":
                    scope[origin] = {"status": lane["status"], "currentEligibility": copy.deepcopy(lane["currentEligibility"])}; continue
                h = lane["current"]
                selected = {"record": record(h[0]), "association": _named(h[1], ASSOCIATION_FIELDS, selection.ASSOCIATION),
                    "statementOrigin": origin, "interviewStatus": "present" if h[3] == "0" else "waived", "interview": record(h[4]) if h[4][0] != ZERO else None,
                    "interviewReferenceHash": h[5], "interviewPayloadCorrespondence": h[6], "predecessorRecordHash": h[7],
                    "selector": h[8], "revision": h[9], "selectedAt": h[10], "catalogHash": h[11], "selectionHash": h[12],
                    "catalogs": [_named(p, CATALOG_FIELDS, selection.CATALOG_PIN) for p in lane["catalogs"][-1]],
                    "publication": _pub(lane["events"][-1]), "currentEligibility": copy.deepcopy(lane["currentEligibility"])}
                scope[origin] = {"status": "selected", "selection": selected}
            lock = original["lock"]
            scope["lock"] = {"status": "unlocked"} if not lock[0] else {"status": "locked",
                **_named(lock[1:], LOCK_FIELDS, selection.LOCK[1:]), "publication": _pub(original["lockEvent"])}
            value["scopes"][scope_name] = scope
        original_floor, catalogue = floor_snapshot["floor"], floor_snapshot["catalogue"]
        f = {"kind": "universal_primary_v1", "host": floor_snapshot["sourceState"]["conservationFloor"], "status": original_floor["status"],
            "sourceCount": catalogue["count"], "sourceHead": catalogue["head"], "sources": [], "firstSale": None, "releases": [], "settlements": []}
        for row in catalogue["sources"]:
            f["sources"].append({**_named(row["source"], SOURCE_FIELDS, floor.SOURCE), "sourceId": row["sourceId"],
                "head": row["head"], "publication": row["admission"]["publication"]})
        for key, fields, kinds, nested in (("firstSale", FIRST_FIELDS, floor.FIRST, {"facts": (COLLECTION_FIELDS, floor.COLLECTION_FACTS)}),
                ("releases", RELEASE_FIELDS, floor.RELEASE, {"context": (RELEASE_CONTEXT_FIELDS, floor.RELEASE_CONTEXT), "facts": (RELEASE_FACT_FIELDS, floor.RELEASE_FACTS)}),
                ("settlements", SETTLEMENT_FIELDS, floor.SETTLEMENT, {})):
            rows = [original_floor[key]] if key == "firstSale" and original_floor[key] else [] if key == "firstSale" else original_floor[key]
            for row in rows:
                projected = {**_named(row["receipt"], fields, kinds, nested), "publication": row["publication"]}
                if key == "settlements":
                    original = row["originalSettlement"]
                    projected.update(result=_named(original["result"], RESULT_FIELDS, floor.RESULT), sale=_named(original["sale"], SALE_FIELDS, floor.SALE),
                        saleAdapter=original["events"][1]["data"][1], saleContextHash=original["events"][0]["data"][5])
                if key == "firstSale": f[key] = projected
                else: f[key].append(projected)
        value["historicalFloor"] = f
        return validate_conservation(dumps(value), source_state)
    return _errors(run)


def documents(): return {PACKET: PACKET_SCHEMA_BYTES, CONSERVATION: CONSERVATION_SCHEMA_BYTES}
def outputs(): return {"schemas/records/" + name + ".json": raw for name, raw in documents().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for module in (v1, v2, v3):
        for name, raw in module.documents().items():
            path = ROOT / "schemas/records" / ("profiles/" if name == v2.PROFILE else "") / (name + ".json")
            v1.need(path.read_bytes() == raw, "original schema/profile bytes differ: " + name)
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: v1.need(destination.is_file() and destination.read_bytes() == raw, "generated bytes differ: " + path)
        else: destination.parent.mkdir(parents=True, exist_ok=True); destination.write_bytes(raw)
    print("Packet V4 and native conservation supplied-data definitions match; source authentication is separate.")


# Version-local copy of V1 packet joins. Only the conservation and curated-intent
# hooks differ; V1–V3 source and validators remain unchanged.
need, _kind, _sorted_unique = v1.need, v1._kind, v1._sorted_unique
_head_key, _record_context, _entropy_hash = v1._head_key, v1._record_context, v1._entropy_hash
USES = v1.USES

def _packet(value):
    s = value["sourceState"]
    need(all(uint(s[k]) > 0 for k in ("chainId", "collectionId", "tokenId", "collectionSerial")), "nonzero source identity")
    token = subject_id("token", s["chainId"], s["core"], s["collectionId"], token_id=s["tokenId"])
    collection = subject_id("collection", s["chainId"], s["core"], s["collectionId"])
    need(s["subjectId"] == value["subjectId"] == value["contentRootProof"]["subjectId"] == token, "token subject join")
    need(s["collectionSubjectId"] == collection, "collection subject join")
    need(value["erc721Identity"] == {"core": s["core"], "collectionId": s["collectionId"], "globalTokenId": s["tokenId"],
        "catalogNumber": s["tokenId"], "collectionSerial": s["collectionSerial"]}, "sole ERC721 identity join")
    citation = value["citation"]
    base = f"eip155:{s['chainId']}/erc721:{s['core']}/{s['tokenId']}"
    need(citation["work"] == base and citation["qualified"] == base + "@" + citation["qualifier"]["kind"] + ":" + citation["qualifier"]["hash"], "canonical citation join")
    if citation["qualifier"]["kind"] == "fin":
        need(value["finality"]["status"] == "finalized" and citation["qualifier"]["hash"] == value["finality"]["record"]["recordHash"], "finality citation join")
    snapshot = value["snapshotCommitment"]
    if snapshot is not None:
        need(snapshot["collectionId"] == s["collectionId"] and uint(snapshot["revision"]) > 0
            and uint(snapshot["recordedBlock"]) <= uint(s["blockNumber"])
            and snapshot["manifest"]["hash"]["algorithm"] == 1, "snapshot commitment context")
    if citation["qualifier"]["kind"] == "snap":
        need(snapshot is not None and citation["qualifier"]["hash"] == snapshot["manifest"]["hash"]["digest"], "snapshot citation join")
    heads = value["recordChainHeads"]
    _sorted_unique(heads, _head_key, "record heads")
    for head in heads:
        need((head["count"] == "0") == (head["headHash"] == ZERO), "empty head/count join")
        expected_scopes = (s["tokenId"],) if head["lane"] == "owner" else (
            ("0", s["collectionId"]) if head["lane"] == "independent" else (s["collectionId"],))
        need(head["scopeKey"] in expected_scopes, "native lane scope key")
    if citation["qualifier"]["kind"] == "chain":
        need(citation["qualifier"]["hash"] in {h["headHash"] for h in heads}, "chain citation join")
    _record_context(value, s)
    entropy = value["entropy"]; leaf = entropy["leaf"]
    need(leaf["tokenId"] == s["tokenId"] and entropy["leafHash"] == _entropy_hash(leaf), "pinned entropy leaf preimage")
    _sorted_unique(entropy["events"], lambda e: (uint(e["blockNumber"]), uint(e["logIndex"])), "entropy events")
    for event in entropy["events"]:
        need(event["tokenId"] == s["tokenId"] and event["emitter"] == leaf["coordinatorAtMint"]
            and uint(event["blockNumber"]) <= uint(s["blockNumber"]), "entropy event source join")
    if leaf["status"] == "5":
        events = [e["event"] for e in entropy["events"]]
        need(len(events) >= 2 and events[-1] == "EntropyFinalized"
            and all(event == "EntropyRequested" for event in events[:-1]), "finalized entropy event sequence")
    a = value["attribution"]
    observation = a["attestation"]
    code = int(observation["nativeStatus"])
    need(observation["statusLabel"] == ("NONE", "CURRENT", "STALE", "DISPUTED")[code], "native attestation status label")
    need(observation["collectionId"] == s["collectionId"] and observation["observedBlock"] == s["blockNumber"]
        and observation["observedBlockHash"] == s["blockHash"], "native attestation observation context")
    if code == 0:
        need(observation["attestationRecordHash"] == observation["attestedSubjectStateHash"] == ZERO
            and observation["authorityClass"] == observation["signedAt"] == "0", "native absent attestation tuple")
    else:
        need(observation["attestationRecordHash"] != ZERO, "native attestation original record")
        need((code == 3) == (a["state"] == "disputed"), "native disputed attribution/status join")
        if code == 1:
            need(a["state"] in ("artist_accepted", "artist_sanctioned")
                and (observation["subjectKind"] == "8"
                    or observation["attestedSubjectStateHash"] == observation["currentSubjectStateHash"]),
                "native current attestation state join")
        # STALE under an accepted binding can reflect an older generation;
        # omitted original-generation evidence is not inferred here.
    need((a["artistId"] is None) == (a["state"] == "platform_works"), "artist identity/state join")
    if a["state"] in ("artist_accepted", "artist_sanctioned"):
        need(a["binding"]["status"] == "present" and uint(a["bindingGeneration"]) > 0, "accepted binding evidence")
    if a["state"] == "artist_sanctioned": need(a["sanction"]["status"] == "present", "sanction evidence")
    if a["personhood"]["status"] == "present":
        p = a["personhood"]
        need(p["artistId"] == a["artistId"] and _kind(p["record"], "INSTITUTIONAL_VERIFICATION", "ESTATE_VERIFICATION")
            and p["record"]["schemaId"] == keccak256(b"STREAM_IDENTITY_NOTARIZATION_V1"), "personhood attestation join")
    rights = value["rights"]
    for scope in ("collection", "token"):
        item = rights[scope]
        if item is not None:
            need(item["record"]["subjectKind"] == scope and _kind(item["record"], "RIGHTS_STATEMENT")
                and item["record"]["schemaId"] == keccak256(b"STREAM_RIGHTS_V1"), "rights scope/schema")
    selected = rights["token"] or rights["collection"]
    effective = selected["grants"] if selected is not None else {k: "unspecified" for k in USES}
    count = sum(status != "unspecified" for status in effective.values())
    status = "absent" if selected is None else "specified" if count == len(USES) else "unspecified" if count == 0 else "partially_specified"
    need(rights["effectiveGrants"] == effective and rights["completeness"] == status, "rights precedence/completeness")
    preservation = value["preservation"]; mode = value["metadataMode"]; script = value["workClass"] == "script"
    expected = {"ONCHAIN": ("onchain_bound",), "HYBRID": ("onchain_bound",),
        "OFFCHAIN_HASH_BOUND": ("covered", "uncovered_within_window", "uncovered_overdue"), "SERVICE_BACKED": ("service_backed_mutable",)}[mode]
    need(preservation["coverage"] in expected, "mode-total preservation coverage")
    need(mode not in ("ONCHAIN", "HYBRID") or script, "onchain/hybrid script preservation lane")
    need((preservation["scriptCoverage"]["status"] != "not_applicable") == script, "script coverage applicability")
    if preservation["coverage"] == "covered": need(preservation["fixityCycle"]["status"] == "recorded", "covered requires cycle")
    if preservation["scriptCoverage"]["status"] == "covered":
        need(preservation["scriptCoverage"]["captureSet"] is not None and preservation["scriptCoverage"]["environment"] is not None, "covered script evidence")
    _sorted_unique(preservation["masters"], lambda m: m["mediaClass"], "master slots")
    ownership = value["ownershipProvenance"]
    need(ownership["core"] == s["core"] and ownership["tokenId"] == s["tokenId"], "ownership identity")
    previous = ZERO_ADDRESS; last_order = (-1, -1)
    for i, hop in enumerate(ownership["transfers"]):
        order = (uint(hop["blockNumber"]), uint(hop["logIndex"]))
        need(hop["from"] == previous and (i == 0 or previous != ZERO_ADDRESS)
            and order > last_order and order[0] <= uint(s["blockNumber"]), "mint-to-source transfer continuity")
        need(i != 0 or hop["to"] != ZERO_ADDRESS, "mint initial holder")
        previous = hop["to"]; last_order = order
    need(ownership["currentOwner"] == previous and s["burned"] == (previous == ZERO_ADDRESS), "current owner/burn join")
    for binding in ownership["titleBindings"]:
        index = uint(binding["transferIndex"])
        need(index < len(ownership["transfers"]), "title hop index")
        hop = ownership["transfers"][index]
        need(all(binding[k] == hop[k] for k in ("from", "to", "transactionHash"))
            and _kind(binding["record"], "ACCESSION", "DEACCESSION"), "title transfer join")
    drill = value["scriptDrill"]
    need((drill["status"] != "not_applicable") == script, "script drill applicability")
    if drill["status"] == "recorded":
        need(drill["outcome"] != "TOLERABLE_VARIANCE" or drill["acceptanceMode"] != "BYTE_EXACT", "drill acceptance mode")
        need((drill["curatedEvidence"] is not None) == (drill["acceptanceMode"] == "CURATED_EQUIVALENCE"), "curated evidence applicability")
        if drill["curatedEvidence"] is not None:
            curated = drill["curatedEvidence"]
            _curated(curated, value["conservation"])
    _conservation(value["conservation"], s, value)
    if value["legalInstrument"]["status"] == "recorded": need(_kind(value["legalInstrument"]["accession"], "ACCESSION"), "accession instrument")
    if value["tombstone"]["status"] == "present":
        need(value["tombstone"]["record"]["schemaId"] == keccak256(b"STREAM_WORK_DESCRIPTION_V1"), "tombstone schema")
    if value["c2pa"]["status"] == "present":
        c2pa = value["c2pa"]
        need(_kind(c2pa["record"], "C2PA_REFERENCE"), "C2PA record type")
        if c2pa["assetHash"] != c2pa["committedMediaHash"]:
            need(c2pa["validationStatus"] == keccak256(b"INVALID"), "C2PA mismatched media must be INVALID")
    for lane, expected_type in (("owner", "CONDITION_REPORT"), ("independent", "INDEPENDENT_CONDITION")):
        condition = value["conditionReports"][lane]
        if condition["status"] == "present": need(_kind(condition["record"], expected_type), "condition lane/type")
    if value["recoveryLineage"]["status"] == "present":
        rows = value["recoveryLineage"]["lineage"]
        need(len({r["recoveryId"] for r in rows}) == len(rows), "duplicate recovery")
        for recovery in rows:
            for response in recovery["responses"]:
                need(_kind(response["record"], "RECOVERY_RESPONSE") and response["recoveryId"] == recovery["recoveryId"]
                    and recovery["manifest"]["hash"]["algorithm"] == 1
                    and response["manifestHash"] == recovery["manifest"]["hash"]["digest"], "recovery response join")
    sustain = value["platformSustainability"]
    expected_status = "meets_floor" if uint(sustain["coverageHorizonSeconds"]) >= uint(sustain["viabilityFloorSeconds"]) else "below_floor"
    need(sustain["horizonStatus"] == expected_status, "funding horizon")
    export = sustain["stateExport"]
    need(uint(export["exportedAt"]) <= uint(s["examinedAt"])
        and uint(export["ageSeconds"]) == uint(s["examinedAt"]) - uint(export["exportedAt"]), "state export age")



if __name__ == "__main__": main()
