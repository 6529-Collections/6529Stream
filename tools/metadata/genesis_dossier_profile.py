"""Broad prospective artifacts; canonical shape and supplied joins, never chain proof.

Schema validation does not authenticate absence, records, source/reviewer
authority, completeness, archival availability or institutional acceptance.
"""
import argparse
import copy
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError
from tools.museum.canonical import MuseumError, dumps, loads, keccak256, subject_id, uint, word, hex_bytes, record_chain
from tools.museum.bagit import _paths as _packaging_paths

ROOT = Path(__file__).resolve().parents[2]
OBJECT = "STREAM_OBJECT_DOSSIER_V1"
PACKET = "STREAM_ACQUISITION_PACKET_V1"
MAX_BYTES = 1048576
ZERO = "0x" + "0" * 64
ZERO_ADDRESS = "0x" + "0" * 40
RAW = keccak256(b"RAW_BYTES")
USES = ("ai_training", "derivative", "exhibition", "print", "publication", "reproduction")
GRANTS = ("unspecified", "granted", "granted_with_conditions", "denied")
QUALIFICATION = (
    "Prospective unregistered broad artifact schema. Validation checks canonical bytes and "
    "internal consistency of supplied data only; it does not authenticate chain state, "
    "complete histories or absence, signatures, source/reviewer authority, legal title, "
    "fixity, storage availability, institutional ingest or full-v1 conformance. "
    "Synthetic examples are not chain-regeneration or institutional evidence."
)


class DossierError(MuseumError):
    pass


def closed(fields, **extra):
    return {"type": "object", "properties": fields, "required": list(fields),
            "additionalProperties": False, **extra}


def ref(name): return {"$ref": "#/$defs/" + name}
def nullable(item): return {"oneOf": [{"type": "null"}, item]}
def enum(*values): return {"enum": list(values)}
def array(item, minimum=0, maximum=512):
    return {"type": "array", "items": item, "minItems": minimum, "maxItems": maximum}
def text(maximum=2048):
    return {"type": "string", "minLength": 1, "maxLength": maximum,
            "x-stream-max-utf8-bytes": maximum}
def tagged(status, **fields): return closed({"status": {"const": status}, **fields})
def choice(*rows): return {"oneOf": list(rows)}
def record_state(*statuses):
    rows = [tagged("present", record=ref("record"))]
    if "waived" in statuses: rows.append(tagged("waived", waiver=ref("record")))
    if "absent" in statuses: rows.append(tagged("absent", evidence=ref("reference")))
    return choice(*rows)


def definitions():
    d = {}
    for bits in (8, 16, 32, 64, 256):
        d["uint" + str(bits)] = {"type": "string", "pattern": "^(0|[1-9][0-9]*)(?![\\s\\S])",
            "maxLength": len(str((1 << bits) - 1)), "x-stream-uint-bits": bits}
    d["hash0"] = {"type": "string", "pattern": "^0x[0-9a-f]{64}(?![\\s\\S])"}
    d["hash"] = {**d["hash0"], "not": {"const": ZERO}}
    d["address0"] = {"type": "string", "pattern": "^0x[0-9a-f]{40}(?![\\s\\S])"}
    d["address"] = {**d["address0"], "not": {"const": ZERO_ADDRESS}}
    d["path"] = {**text(512), "pattern": "^data/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*(?![\\s\\S])"}
    d["hashRef"] = closed({"algorithm": enum(1, 2, 3, 4, 5, 6), "canonicalizationId": ref("hash"),
        "digest": {"type": "string", "pattern": "^0x(?:[0-9a-f]{2}){1,128}(?![\\s\\S])"}})
    d["reference"] = closed({"uri": text(), "hash": ref("hashRef")})
    d["sourceState"] = closed({"chainId": ref("uint256"), "core": ref("address"),
        "collectionId": ref("uint256"), "tokenId": ref("uint256"), "collectionSerial": ref("uint256"),
        "subjectId": ref("hash"), "collectionSubjectId": ref("hash"), "blockNumber": ref("uint64"),
        "blockHash": ref("hash"), "examinedAt": ref("uint64"), "burned": {"type": "boolean"}})
    d["citation"] = closed({"work": text(256), "qualified": text(340),
        "qualifier": closed({"kind": enum("fin", "snap", "chain"), "hash": ref("hash")})})
    d["snapshotCommitment"] = closed({"host": ref("address"), "collectionId": ref("uint256"),
        "snapshotId": ref("hash"), "recordHash": ref("hash"), "manifest": ref("reference"),
        "sourceHash": ref("hash"), "revision": ref("uint64"), "recordedBlock": ref("uint64")})
    d["record"] = closed({"recordHash": ref("hash"), "host": ref("address"),
        "subjectId": ref("hash"), "subjectKind": enum("token", "collection", "media", "scope", "deployment"),
        "recordType": ref("hash"), "schemaId": ref("hash"), "signer": ref("address"),
        "authorityClass": ref("uint8"), "recordedBlock": ref("uint64")})
    d["head"] = closed({"lane": enum("metadata", "general", "owner", "independent"),
        "host": ref("address"), "scopeKey": ref("uint256"),
        "recordType": ref("hash"), "headHash": ref("hash0"), "count": ref("uint64")})
    d["event"] = closed({"event": enum("EntropyRequested", "EntropyFinalized"),
        "emitter": ref("address"), "tokenId": ref("uint256"), "blockNumber": ref("uint64"),
        "transactionHash": ref("hash"), "logIndex": ref("uint32")})
    d["entropy"] = closed({"leaf": closed({"tokenId": ref("uint256"),
        "status": {**ref("uint8"), "enum": [str(i) for i in range(8)]}, "seed": ref("hash0"),
        "coordinatorAtMint": ref("address0"), "provider": ref("address0"),
        "providerEpoch": ref("uint32"), "requestKey": ref("hash0"), "requestAttempt": ref("uint16")}),
        "leafHash": ref("hash"), "events": array(ref("event"), maximum=64)})
    d["finality"] = choice(tagged("finalized", record=ref("record")),
        tagged("not_finalized", evidence=ref("reference")))
    d["proof"] = closed({"subjectId": ref("hash"), "root": ref("hash"),
        "leafHash": ref("hash"), "proof": ref("reference")})
    d["personhood"] = choice(tagged("present", record=ref("record"), artistId=ref("hash"),
        operativeIdentityRecordHash=ref("hash"), legalPersonReference=ref("reference")),
        tagged("waived", waiver=ref("record")), tagged("absent", evidence=ref("reference")))
    d["nativeAttestationObservation"] = closed({"host": ref("address"), "collectionId": ref("uint256"),
        "subjectKind": ref("uint8"), "subjectId": ref("hash0"), "currentSubjectStateHash": ref("hash0"),
        "nativeStatus": enum("0", "1", "2", "3"), "statusLabel": enum("NONE", "CURRENT", "STALE", "DISPUTED"),
        "attestationRecordHash": ref("hash0"), "attestedSubjectStateHash": ref("hash0"),
        "authorityClass": ref("uint8"), "signedAt": ref("uint64"),
        "observedBlock": ref("uint64"), "observedBlockHash": ref("hash"), "evidence": ref("reference")})
    d["attribution"] = closed({"state": enum("claimed", "artist_accepted", "artist_sanctioned", "disputed", "revoked", "platform_works"),
        "artistId": nullable(ref("hash")), "bindingGeneration": ref("uint64"),
        "binding": record_state("absent"), "attestation": ref("nativeAttestationObservation"),
        "sanction": record_state("absent"), "personhood": ref("personhood")})
    d["rightsRecord"] = closed({"record": ref("record"), "grants": closed({use: enum(*GRANTS) for use in USES})})
    d["rights"] = closed({"collection": nullable(ref("rightsRecord")), "token": nullable(ref("rightsRecord")),
        "effectiveGrants": closed({use: enum(*GRANTS) for use in USES}),
        "completeness": enum("specified", "partially_specified", "unspecified", "absent"),
        "selectionEvidence": ref("reference")})
    d["preservation"] = closed({"coverage": enum("covered", "uncovered_within_window", "uncovered_overdue", "onchain_bound", "service_backed_mutable"),
        "fixityCycle": choice(tagged("recorded", report=ref("reference")), tagged("none_recorded", evidence=ref("reference"))),
        "scriptCoverage": choice(tagged("not_applicable"), closed({"status": enum("covered", "uncovered_within_window", "uncovered_overdue"),
            "captureSet": nullable(ref("record")), "environment": nullable(ref("record")), "evidence": ref("reference")})),
        "masters": array(closed({"mediaClass": ref("hash"), "master": record_state("waived", "absent")}))})
    d["legalInstrument"] = choice(tagged("recorded", instrument=ref("reference"), accession=ref("record")),
        tagged("to_be_recorded", instrument=ref("reference")))
    d["transfer"] = closed({"from": ref("address0"), "to": ref("address0"), "blockNumber": ref("uint64"),
        "transactionHash": ref("hash"), "logIndex": ref("uint32")})
    d["titleBinding"] = closed({"record": ref("record"), "mode": {"const": "TITLE_BINDING"},
        "transferIndex": ref("uint64"), "transactionHash": ref("hash"), "from": ref("address0"),
        "to": ref("address0"), "instrument": ref("reference")})
    d["ownership"] = closed({"core": ref("address"), "tokenId": ref("uint256"),
        "eventHistorySnapshot": ref("reference"), "transfers": array(ref("transfer"), 1),
        "titleBindings": array(ref("titleBinding")), "currentOwner": ref("address0")})
    d["curatedEvidence"] = closed({"attestation": ref("record"), "verificationClass": {"const": "SIGNER_VERIFIED"},
        "artistIntentRecordHash": ref("hash"), "examinerInstitution": ref("reference"), "examinerName": text(512),
        "examinerCredential": ref("reference"), "fieldEvaluation": ref("reference")})
    d["drill"] = choice(tagged("not_applicable"), tagged("never_drilled", evidence=ref("reference")),
        tagged("recorded", report=ref("reference"), acceptanceMode=enum("BYTE_EXACT", "PERCEPTUAL_TOLERANCE", "CURATED_EQUIVALENCE"),
            outcome=enum("MATCH", "TOLERABLE_VARIANCE", "DIVERGENT"), referenceRender=ref("record"),
            curatedEvidence=nullable(ref("curatedEvidence"))))
    d["conservation"] = closed({"tier": enum("MUSEUM_GRADE", "MUSEUM_GRADE_LITE", "CONSERVATION_WAIVED"),
        "tierBasis": enum("declared", "default"), "tierRecord": nullable(ref("record")),
        "artistIntent": record_state("waived"), "interview": record_state("waived", "absent")})
    d["c2pa"] = choice(tagged("no_c2pa", evidence=ref("reference")), tagged("present", record=ref("record"),
        validationStatus=ref("hash"), validatorClass=ref("hash"), validationReport=ref("reference"),
        validatorIdentity=ref("reference"), softwareVersion=ref("reference"), trustAnchorSet=ref("reference"),
        assetHash=ref("hash"), committedMediaHash=ref("hash")))
    d["condition"] = choice(tagged("none_recorded", evidence=ref("reference")),
        tagged("present", record=ref("record"), examinationCaptures=array(ref("reference"), 1)))
    d["bag"] = choice(tagged("not_accompanied"), tagged("accompanied", selfContainment=enum("self_contained", "fetch_dependent")))
    d["recovery"] = closed({"recoveryId": ref("hash"), "manifest": ref("reference"),
        "status": enum("scheduled", "executed"), "artworkBytesChanged": {"type": "boolean"},
        "responses": array(closed({"record": ref("record"), "recoveryId": ref("hash"), "manifestHash": ref("hash")}))})
    d["recoveries"] = choice(tagged("no_recoveries", evidence=ref("reference")),
        tagged("present", lineage=array(ref("recovery"), 1)))
    d["sustainability"] = closed({"fundingManifest": ref("reference"), "coverageHorizonSeconds": ref("uint64"),
        "viabilityFloorSeconds": ref("uint64"), "horizonStatus": enum("meets_floor", "below_floor"),
        "stateExport": closed({"manifest": ref("reference"), "exportedAt": ref("uint64"), "ageSeconds": ref("uint64")}),
        "zeroSignerMuseumDrill": ref("reference")})
    d["identity"] = closed({"core": ref("address"), "collectionId": ref("uint256"),
        "globalTokenId": ref("uint256"), "catalogNumber": ref("uint256"), "collectionSerial": ref("uint256")})
    d["packet"] = closed({"schema": {"const": PACKET}, "version": {"const": 1},
        "sourceState": ref("sourceState"), "workClass": enum("script", "non_script"),
        "metadataMode": enum("ONCHAIN", "HYBRID", "OFFCHAIN_HASH_BOUND", "SERVICE_BACKED"),
        "citation": ref("citation"), "snapshotCommitment": nullable(ref("snapshotCommitment")),
        "subjectId": ref("hash"), "finality": ref("finality"),
        "contentRootProof": ref("proof"), "entropy": ref("entropy"), "recordChainHeads": array(ref("head"), 1, 64),
        "attribution": ref("attribution"), "rights": ref("rights"), "preservation": ref("preservation"),
        "legalInstrument": ref("legalInstrument"), "ownershipProvenance": ref("ownership"), "scriptDrill": ref("drill"),
        "tombstone": record_state("absent"), "conservation": ref("conservation"), "c2pa": ref("c2pa"),
        "conditionReports": closed({"owner": ref("condition"), "independent": ref("condition")}),
        "dossierBag": ref("bag"), "recoveryLineage": ref("recoveries"), "platformSustainability": ref("sustainability"),
        "erc721Identity": ref("identity")})
    d["component"] = closed({"path": ref("path"), "hash": ref("hashRef"), "byteLength": ref("uint64"),
        "role": enum("record_payload", "record_envelope", "signature_bundle", "script", "dependency", "media",
            "semantic_manifest", "entity_index", "linked_art", "assertions", "provenance", "authority_snapshot",
            "dependency_lock", "interpretation", "coverage_report", "validation_report", "tool_source", "tool_build",
            "tool_vectors", "other_documentary"), "renderCritical": {"type": "boolean"},
        "disposition": enum("embedded", "fetch"), "retrievalURI": nullable(text()),
        "archiveReceipts": array(closed({"storageFamily": ref("hash"), "receipt": ref("reference")}), maximum=8)})
    d["manifest"] = closed({"reference": ref("reference"), "subjectId": ref("hash"), "componentPaths": array(ref("path"))})
    d["inventoryEntry"] = closed({"record": ref("record"), "index": ref("uint64"), "chainHash": ref("hash"),
        "envelopePath": ref("path"), "payloadPath": ref("path"), "signatureBundlePath": nullable(ref("path"))})
    d["inventoryLane"] = closed({"head": ref("head"), "entries": array(ref("inventoryEntry"))})
    d["semantic"] = closed({"schema": {"const": "STREAM_SEMANTIC_EXPORT_V1"}, "manifestPath": ref("path"),
        "sourceStateHash": ref("hash"), "selectedRecordHashes": array(ref("hash")), "sourceHeadHashes": array(ref("hash0")),
        "subsequentExportRecordHash": nullable(ref("hash")), "selectionPolicy": ref("reference"),
        "disclosureScope": closed({"policy": ref("reference"), "withheldResourceCount": ref("uint32")}),
        "entityIndexPath": ref("path"), "linkedArtPaths": array(ref("path")), "assertionPaths": array(ref("path"), 1),
        "provenancePath": ref("path"), "authoritySnapshotPaths": array(ref("path")), "dependencyLockPath": ref("path"),
        "interpretationPaths": array(ref("path"), 1), "coverageReportPath": ref("path"), "validationReportPath": ref("path"),
        "sharedSourceCrossFormatReportPath": ref("path")})
    d["tooling"] = closed({"sourceArchive": ref("reference"), "buildInstructions": ref("reference"),
        "testVectors": ref("reference"), "systemManifest": ref("reference"), "manifestToolSourceHash": ref("hash"),
        "archiveReceipts": array(closed({"storageFamily": ref("hash"), "receipt": ref("reference")}), 2, 8),
        "packetRegenerationDrill": ref("reference")})
    d["institutional"] = closed({"repositoryIngestReports": array(closed({"repositoryFamily": enum("ocfl_fedora", "archivematica_aip"),
        "stackName": text(128), "stackVersion": text(128), "configuration": ref("reference"), "report": ref("reference")}), maximum=16),
        "practitionerReviews": array(closed({"reviewerIdentity": ref("reference"),
        "roles": array(enum("registrar_collection_management", "time_based_media_conservation", "crm_linked_art_authority"), 1, 3),
        "review": ref("reference"), "dispositionLog": ref("reference")}), maximum=16)})
    d["object"] = closed({"schema": {"const": OBJECT}, "version": {"const": 1}, "exportProfile": {"const": "OBJECT_DOSSIER_V1"},
        "acquisitionPacket": ref("packet"), "collectionManifests": closed({
            "script": choice(tagged("present", manifest=ref("manifest")), tagged("not_applicable")),
            "dependency": ref("manifest"), "media": ref("manifest")}),
        "recordInventory": array(ref("inventoryLane"), 1, 64),
        "collectionConservation": closed({"iiifManifests": array(ref("record")), "significantProperties": array(ref("record"), 1)}),
        "components": array(ref("component"), 1), "semanticPackage": ref("semantic"),
        "packaging": closed({"profile": ref("reference"), "selfContainment": enum("self_contained", "fetch_dependent"),
            "ocflObjectId": text(340), "ocflVersion": {"type": "string", "pattern": "^v[1-9][0-9]*(?![\\s\\S])"},
            "previousDossier": nullable(ref("reference"))}), "tooling": ref("tooling"), "institutionalEvidence": ref("institutional")})
    return d


CONSTRAINTS = [
    QUALIFICATION,
    "RFC8785, no duplicate keys/floats, max1048576 UTF8 bytes, nesting64, arrays at explicit bounds. This offchain interpreter bound does not change onchain limits.",
    "Unsigned decimal-string integers at declared widths; lowercase exact-width hex. HashRef algorithms1/2/3/6 require32 digest bytes;4/5 retain1..128 opaque bytes.",
    "Token/collection subjects and citations derive from exact sourceState; other original scope/media/deployment subject hashes remain supplied references. Identity, entropy leaf/events, records, transfer/title continuity, rights precedence and coverage join supplied state.",
    "Named absence branches never mean authenticated absence. Required references are supplied commitments, not proof of bytes or facts.",
    "Snapshot citations join a supplied native snapshot manifest Keccak commitment. Native Artist observations retain query, status0..3/record/state/authority/signedAt and source block. NONE has the zero tuple; nonzero DISPUTED iff attribution is disputed; CURRENT requires accepted/sanctioned attribution and matching state hashes except kind8. STALE may reflect an omitted historical generation. These are not general records or authority proof.",
    "Object inventory exactly projects native lane/host/scopeKey/recordType heads, retaining all indexed original subjects including off-target denominator entries. Metadata/general use collectionId; owner uses tokenId; independent uses collectionId or deployment0. Only selected packet/conservation references must match target subjects. No authenticated completeness claim. Sort heads by lane/host/scopeKey/type, components by path, semantic records by hash, events by block/log; preserve transfers and lane entries.",
    "Record types are original bytes32, including opaque unknown families. Recompute every supplied chain step: General uses its six-word GENERAL_ATTESTATION_CHAIN_V1 preimage; the other three lanes use the eight-word RECORD_CHAIN_V1 preimage. Supplied record hashes are not reconstructed payload/signature proofs.",
    "FINALIZED entropy retains one or more ordered Requested events followed by one Finalized event, never a later request. Component paths share the portable BagIt reserved-name, case-alias and file/directory-collision checks.",
    "Render-critical and semantic components must be embedded; fetch components require ipfs/ar and two distinct archive families. Derive self-containment from inventory.",
    "Semantic state/records/heads bind packet; exclude subsequent export record from sources. No self or enclosing bag hash field: child commitments are acyclic.",
    "Tool source/system-manifest hash is a supplied join. Empty institutional arrays explicitly mean no supplied reports, never satisfaction of external gates.",
]

PACKET_REQUIREMENTS = {
    "1": ["citation", "snapshotCommitment"], "2": ["subjectId"], "3": ["finality", "contentRootProof"],
    "4": ["entropy"], "5": ["recordChainHeads"], "6": ["attribution"], "7": ["rights"],
    "8": ["preservation"], "9": ["legalInstrument"], "10": ["ownershipProvenance"],
    "11": ["scriptDrill"], "12": ["tombstone"], "13": ["conservation"], "14": ["c2pa"],
    "15": ["conditionReports"], "16": ["dossierBag"], "17": ["recoveryLineage"],
    "18": ["platformSustainability"], "19": ["erc721Identity"],
}


def schemas():
    d = definitions()
    result = {}
    for name, root in ((PACKET, "packet"), (OBJECT, "object")):
        pending, selected = [root], {}
        while pending:
            key = pending.pop()
            if key in selected: continue
            selected[key] = copy.deepcopy(d[key])
            pending.extend(row["$ref"].split("/")[-1] for row in _walk(d[key]) if "$ref" in row)
        result[name] = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + name,
            "title": name, "description": QUALIFICATION, **ref(root), "$defs": selected,
            "x-stream-constraints": CONSTRAINTS, "x-stream-CMC-ACQUISITION-PACKET": PACKET_REQUIREMENTS}
    return result


def documents():
    """Canonical proposed schema bytes keyed by exact genesis names."""
    return {name: dumps(value) for name, value in schemas().items()}


def need(condition, message):
    if not condition: raise DossierError(message)


def _typed(value, definition, defs):
    if "$ref" in definition: return _typed(value, defs[definition["$ref"].split("/")[-1]], defs)
    if "oneOf" in definition:
        matches = [row for row in definition["oneOf"] if Draft202012Validator({"$defs": defs, **row}).is_valid(value)]
        need(len(matches) == 1, "ambiguous typed branch")
        return _typed(value, matches[0], defs)
    if isinstance(value, dict):
        for key, item in value.items(): _typed(item, definition["properties"][key], defs)
    elif isinstance(value, list):
        for item in value: _typed(item, definition["items"], defs)
    elif isinstance(value, str):
        if "x-stream-uint-bits" in definition: uint(value, definition["x-stream-uint-bits"])
        if "x-stream-max-utf8-bytes" in definition:
            need(len(value.encode("utf-8")) <= definition["x-stream-max-utf8-bytes"], "UTF8 byte bound")


def _walk(value):
    if isinstance(value, dict):
        yield value
        for item in value.values(): yield from _walk(item)
    elif isinstance(value, list):
        for item in value: yield from _walk(item)


def _head_key(h): return tuple(h[k] for k in ("lane", "host", "scopeKey", "recordType"))
def _record_key(r): return r["host"], r["recordHash"]
def _kind(record, *names): return record["recordType"] in {keccak256(name.encode()) for name in names}


def _chain_step(source, head, previous, digest, index):
    if head["lane"] == "general":
        return keccak256(hex_bytes(keccak256(b"6529STREAM_GENERAL_ATTESTATION_CHAIN_V1"), 32)
            + word(head["scopeKey"]) + hex_bytes(head["recordType"], 32)
            + hex_bytes(previous, 32) + hex_bytes(digest, 32) + word(str(index), 64))
    return record_chain(source["chainId"], head["host"], head["scopeKey"], head["recordType"], previous, digest, str(index))
def _sorted_unique(rows, key, label):
    keys = [key(row) for row in rows]
    need(keys == sorted(set(keys)), label + " must be sorted and unique")


def _references(value):
    for row in _walk(value):
        if set(row) == {"algorithm", "canonicalizationId", "digest"}:
            need(row["algorithm"] not in (1, 2, 3, 6) or len(row["digest"]) == 66, "fixed HashRef digest length")
        if set(row) == {"uri", "hash"}:
            uri = row["uri"]
            need(uri.startswith(("https://", "ipfs://", "ar://")) and len(uri.split("://", 1)[1]) > 0
                and not any(ord(c) <= 32 or ord(c) == 127 for c in uri), "reference URI")
            need(not uri.startswith("https://") or uri[8] not in "/?#", "HTTPS authority")


def _entropy_hash(leaf):
    encoded = hex_bytes(keccak256(b"6529STREAM_EXPORT_ENTROPY_LEAF_V1"), 32)
    encoded += word(leaf["tokenId"]) + word(leaf["status"], 8) + hex_bytes(leaf["seed"], 32)
    encoded += bytes(12) + hex_bytes(leaf["coordinatorAtMint"], 20)
    encoded += bytes(12) + hex_bytes(leaf["provider"], 20) + word(leaf["providerEpoch"], 32)
    encoded += hex_bytes(leaf["requestKey"], 32) + word(leaf["requestAttempt"], 16)
    return keccak256(encoded)


def _records_in(value):
    keys = set(definitions()["record"]["properties"])
    return (row for row in _walk(value) if set(row) == keys)


def _record_context(value, source, *, selected=True):
    seen = {}
    for record in _records_in(value):
        key = _record_key(record)
        need(key not in seen or seen[key] == record, "contradictory repeated record reference")
        seen[key] = record
        need(uint(record["recordedBlock"]) <= uint(source["blockNumber"]), "record beyond source block")
        if selected and record["subjectKind"] in ("token", "collection"):
            expected = source["subjectId" if record["subjectKind"] == "token" else "collectionSubjectId"]
            need(record["subjectId"] == expected, "record subject join")


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
            intent = value["conservation"]["artistIntent"]
            need(_kind(curated["attestation"], "INSTITUTIONAL_VERIFICATION", "INDEPENDENT_CONDITION")
                and intent["status"] == "present" and curated["artistIntentRecordHash"] == intent["record"]["recordHash"], "curated attestation/intent join")
    c = value["conservation"]
    need((c["tierRecord"] is None) == (c["tierBasis"] == "default"), "conservation tier basis")
    if c["tierBasis"] == "default": need(c["tier"] == "MUSEUM_GRADE_LITE", "default tier")
    if c["artistIntent"]["status"] == "present": need(_kind(c["artistIntent"]["record"], "ARTIST_INTENT"), "intent type")
    else: need(_kind(c["artistIntent"]["waiver"], "ARTIST_INTENT_WAIVER"), "intent waiver type")
    if c["interview"]["status"] == "present": need(c["interview"]["record"]["schemaId"] == keccak256(b"STREAM_ARTIST_INTERVIEW_V1"), "interview schema")
    if c["interview"]["status"] == "waived":
        need(_kind(c["interview"]["waiver"], "ARTIST_INTENT", "ARTIST_INTENT_WAIVER"), "interview waiver statement carrier")
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


def _object(value):
    packet = value["acquisitionPacket"]; _packet(packet)
    s = packet["sourceState"]
    # Full family inventories preserve the native denominator, including records
    # for other subjects. Packet selections and conservation refs remain scoped.
    _record_context(value, s, selected=False)
    _record_context(value["collectionConservation"], s)
    components = value["components"]
    _sorted_unique(components, lambda c: c["path"], "component paths")
    _packaging_paths([c["path"] for c in components])
    indexed = {c["path"]: c for c in components}
    for c in components:
        need(all(part not in (".", "..") for part in c["path"].split("/")), "unsafe path")
        if c["disposition"] == "fetch":
            uri = c["retrievalURI"]
            need(not c["renderCritical"] and isinstance(uri, str) and uri.startswith(("ipfs://", "ar://"))
                and len(uri.split("://", 1)[1]) > 0 and not any(ord(ch) <= 32 or ord(ch) == 127 for ch in uri), "fetch-only rule")
            need(len({r["storageFamily"] for r in c["archiveReceipts"]}) >= 2, "fetch dual-family commitments")
        else: need(c["retrievalURI"] is None, "embedded retrieval marker")
    def component(path, role=None, embedded=False):
        need(path in indexed, "missing component: " + path)
        row = indexed[path]
        need(role is None or row["role"] == role, "component role")
        need(not embedded or row["disposition"] == "embedded", "semantic interpretation must be embedded")
    contained = "fetch_dependent" if any(c["disposition"] == "fetch" for c in components) else "self_contained"
    need(packet["dossierBag"] == {"status": "accompanied", "selfContainment": contained}
        and value["packaging"]["selfContainment"] == contained, "bag self-containment join")
    need(value["packaging"]["ocflObjectId"] == packet["citation"]["qualified"], "OCFL citation")
    manifests = value["collectionManifests"]
    need((manifests["script"]["status"] == "present") == (packet["workClass"] == "script"), "script manifest applicability")
    for kind in ("script", "dependency", "media"):
        manifest = manifests[kind]
        if kind == "script":
            if manifest["status"] != "present": continue
            manifest = manifest["manifest"]
        need(manifest["subjectId"] == s["collectionSubjectId"], "collection manifest subject")
        for path in manifest["componentPaths"]: component(path, kind)
    lanes = value["recordInventory"]
    need({lane["head"]["lane"] for lane in lanes} == {"metadata", "general", "owner", "independent"}, "explicit inventory for all four lanes")
    _sorted_unique(lanes, lambda lane: _head_key(lane["head"]), "inventory lanes")
    need([lane["head"] for lane in lanes] == packet["recordChainHeads"], "declared head inventory join")
    records = {}
    for lane in lanes:
        head = lane["head"]; entries = lane["entries"]
        need(len(entries) == uint(head["count"]), "declared lane count")
        previous_chain = ZERO
        for index, entry in enumerate(entries):
            record = entry["record"]
            need(uint(entry["index"]) == index and record["host"] == head["host"]
                and record["recordType"] == head["recordType"], "record lane/index")
            if head["lane"] == "owner":
                need(record["subjectKind"] == "token" and record["subjectId"] == s["subjectId"], "owner lane token subject")
            previous_chain = _chain_step(s, head, previous_chain, record["recordHash"], index)
            need(entry["chainHash"] == previous_chain, "native record chain hash step")
            key = _record_key(record)
            need(key not in records, "duplicate original record")
            records[key] = record
            component(entry["envelopePath"], "record_envelope")
            component(entry["payloadPath"], "record_payload")
            if entry["signatureBundlePath"] is not None: component(entry["signatureBundlePath"], "signature_bundle")
        if entries: need(entries[-1]["chainHash"] == head["headHash"], "last retained chain hash")
    for record in _records_in({"packet": packet, "conservation": value["collectionConservation"]}):
        need(records.get(_record_key(record)) == record, "referenced record missing/contradictory")
    for record in value["collectionConservation"]["iiifManifests"]:
        need(record["schemaId"] == keccak256(b"STREAM_IIIF_P3_MIN_V1"), "IIIF schema")
    for record in value["collectionConservation"]["significantProperties"]:
        need(record["subjectKind"] in ("collection", "token", "scope"), "significant-properties scope")
    sem = value["semanticPackage"]
    need(sem["sourceStateHash"] == keccak256(dumps(s)), "semantic source-state")
    _sorted_unique(sem["selectedRecordHashes"], lambda x: x, "semantic source records")
    need(set(sem["selectedRecordHashes"]) <= {key[1] for key in records}, "semantic source inventory")
    need(sem["sourceHeadHashes"] == [head["headHash"] for head in packet["recordChainHeads"]], "semantic heads")
    need(sem["subsequentExportRecordHash"] not in sem["selectedRecordHashes"], "cyclic semantic export source")
    for field, role in (("manifestPath", "semantic_manifest"), ("entityIndexPath", "entity_index"),
        ("provenancePath", "provenance"), ("dependencyLockPath", "dependency_lock"),
        ("coverageReportPath", "coverage_report"), ("validationReportPath", "validation_report"),
        ("sharedSourceCrossFormatReportPath", "validation_report")):
        component(sem[field], role, True)
    for field, role in (("linkedArtPaths", "linked_art"), ("assertionPaths", "assertions"),
        ("authoritySnapshotPaths", "authority_snapshot"), ("interpretationPaths", "interpretation")):
        _sorted_unique(sem[field], lambda x: x, "semantic paths")
        for path in sem[field]: component(path, role, True)
    tooling = value["tooling"]
    need(tooling["sourceArchive"]["hash"]["algorithm"] == 1
        and tooling["manifestToolSourceHash"] == tooling["sourceArchive"]["hash"]["digest"], "tool system-manifest hash")
    need(len({r["storageFamily"] for r in tooling["archiveReceipts"]}) >= 2, "tool archive distinct families")


def validate(name, raw):
    """Validate exact bytes and supplied joins; never fetch or authenticate."""
    need(name in (OBJECT, PACKET), "unsupported schema")
    need(type(raw) is bytes, "exact bytes required")
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        definition = schemas()[name]
        Draft202012Validator(definition).validate(value)
        _typed(value, definition, definition["$defs"])
        _references(value)
        if name == PACKET: _packet(value)
        else: _object(value)
        return value
    except (ValidationError, MuseumError, ValueError, TypeError, KeyError, RecursionError) as exc:
        if isinstance(exc, DossierError): raise
        raise DossierError(str(exc)) from exc


def _h(label): return keccak256(("synthetic supplied example: " + label).encode())
def _reference(label): return {"uri": "https://evidence.example/" + label,
    "hash": {"algorithm": 1, "canonicalizationId": RAW, "digest": _h(label)}}


def examples():
    """Invented commitments for shape tests, with no represented child-file bytes."""
    core = "0x" + "11" * 20; holder = "0x" + "22" * 20; host = "0x" + "33" * 20
    source = {"chainId": "1", "core": core, "collectionId": "2", "tokenId": "123", "collectionSerial": "7",
        "blockNumber": "100", "blockHash": _h("source-block"), "examinedAt": "1000", "burned": False}
    source["subjectId"] = subject_id("token", "1", core, "2", token_id="123")
    source["collectionSubjectId"] = subject_id("collection", "1", core, "2")
    def record(kind, schema, scope="collection"):
        return {"recordHash": _h(kind), "host": host, "subjectId": source["subjectId" if scope == "token" else "collectionSubjectId"],
            "subjectKind": scope, "recordType": keccak256(kind.encode()), "schemaId": keccak256(schema.encode()),
            "signer": holder, "authorityClass": "1", "recordedBlock": "90"}
    intent = record("ARTIST_INTENT", "STREAM_ARTIST_INTENT_V1")
    significant = record("SIGNIFICANT_PROPERTIES", "STREAM_SIGNIFICANT_PROPERTIES_V1")
    rights_record = record("RIGHTS_STATEMENT", "STREAM_RIGHTS_V1")
    tombstone = record("WORK_DESCRIPTION", "STREAM_WORK_DESCRIPTION_V1", "token")
    records = [intent, significant, rights_record, tombstone]
    heads = sorted([{"lane": "metadata", "host": host, "scopeKey": "2",
        "recordType": row["recordType"], "headHash": record_chain("1", host, "2", row["recordType"], ZERO, row["recordHash"], "0"), "count": "1"} for row in records], key=_head_key)
    for lane, kind in (("general", "INSTITUTIONAL_VERIFICATION"), ("owner", "ACCESSION"), ("independent", "INDEPENDENT_CONDITION")):
        heads.append({"lane": lane, "host": host, "scopeKey": source["tokenId"] if lane == "owner" else source["collectionId"],
            "recordType": keccak256(kind.encode()), "headHash": ZERO, "count": "0"})
    heads.sort(key=_head_key)
    citation_head = next(h["headHash"] for h in heads if h["headHash"] != ZERO)
    absent = lambda label: {"status": "absent", "evidence": _reference(label)}
    leaf = {"tokenId": "123", "status": "5", "seed": _h("seed"), "coordinatorAtMint": host,
        "provider": holder, "providerEpoch": "1", "requestKey": _h("request"), "requestAttempt": "0"}
    citation = f"eip155:1/erc721:{core}/123"
    packet = {"schema": PACKET, "version": 1, "sourceState": source, "workClass": "non_script", "metadataMode": "OFFCHAIN_HASH_BOUND",
        "citation": {"work": citation, "qualified": citation + "@chain:" + citation_head,
            "qualifier": {"kind": "chain", "hash": citation_head}}, "snapshotCommitment": None, "subjectId": source["subjectId"],
        "finality": {"status": "not_finalized", "evidence": _reference("not-finalized")},
        "contentRootProof": {"subjectId": source["subjectId"], "root": _h("content-root"), "leafHash": _h("content-leaf"), "proof": _reference("content-proof")},
        "entropy": {"leaf": leaf, "leafHash": _entropy_hash(leaf), "events": [
            {"event": event, "emitter": host, "tokenId": "123", "blockNumber": str(80 + i), "transactionHash": _h(event), "logIndex": "0"}
            for i, event in enumerate(("EntropyRequested", "EntropyFinalized"))]}, "recordChainHeads": heads,
        "attribution": {"state": "claimed", "artistId": _h("artist"), "bindingGeneration": "0", "binding": absent("binding-absent"),
            "attestation": {"host": host, "collectionId": "2", "subjectKind": "1", "subjectId": ZERO,
                "currentSubjectStateHash": _h("artist-subject-current"), "nativeStatus": "0", "statusLabel": "NONE",
                "attestationRecordHash": ZERO, "attestedSubjectStateHash": ZERO, "authorityClass": "0", "signedAt": "0",
                "observedBlock": source["blockNumber"], "observedBlockHash": source["blockHash"], "evidence": _reference("attestation-status-read")},
            "sanction": absent("sanction-absent"), "personhood": absent("personhood-absent")},
        "rights": {"collection": {"record": rights_record, "grants": {u: "unspecified" for u in USES}}, "token": None,
            "effectiveGrants": {u: "unspecified" for u in USES}, "completeness": "unspecified", "selectionEvidence": _reference("rights-selection")},
        "preservation": {"coverage": "uncovered_within_window", "fixityCycle": {"status": "none_recorded", "evidence": _reference("no-cycle")},
            "scriptCoverage": {"status": "not_applicable"}, "masters": [{"mediaClass": _h("still-image-class"), "master": absent("master-absent")}]},
        "legalInstrument": {"status": "to_be_recorded", "instrument": _reference("synthetic-gift-instrument")},
        "ownershipProvenance": {"core": core, "tokenId": "123", "eventHistorySnapshot": _reference("event-history-snapshot"),
            "transfers": [{"from": ZERO_ADDRESS, "to": holder, "blockNumber": "80", "transactionHash": _h("mint"), "logIndex": "1"}],
            "titleBindings": [], "currentOwner": holder}, "scriptDrill": {"status": "not_applicable"},
        "tombstone": {"status": "present", "record": tombstone}, "conservation": {"tier": "MUSEUM_GRADE_LITE", "tierBasis": "default",
            "tierRecord": None, "artistIntent": {"status": "present", "record": intent}, "interview": absent("interview-absent")},
        "c2pa": {"status": "no_c2pa", "evidence": _reference("no-c2pa")},
        "conditionReports": {lane: {"status": "none_recorded", "evidence": _reference(lane + "-condition-empty")} for lane in ("owner", "independent")},
        "dossierBag": {"status": "accompanied", "selfContainment": "self_contained"},
        "recoveryLineage": {"status": "no_recoveries", "evidence": _reference("no-recoveries")},
        "platformSustainability": {"fundingManifest": _reference("funding"), "coverageHorizonSeconds": "100", "viabilityFloorSeconds": "200",
            "horizonStatus": "below_floor", "stateExport": {"manifest": _reference("state-export"), "exportedAt": "900", "ageSeconds": "100"},
            "zeroSignerMuseumDrill": _reference("museum-drill")},
        "erc721Identity": {"core": core, "collectionId": "2", "globalTokenId": "123", "catalogNumber": "123", "collectionSerial": "7"}}
    components = []
    def component(label, role, critical=False):
        path = "data/" + label + ".json"
        components.append({"path": path, "hash": _reference(label)["hash"], "byteLength": "1", "role": role,
            "renderCritical": critical, "disposition": "embedded", "retrievalURI": None, "archiveReceipts": []})
        return path
    lanes = []
    for head in heads:
        if head["count"] == "0":
            lanes.append({"head": head, "entries": []})
            continue
        original = next(r for r in records if r["recordType"] == head["recordType"])
        label = original["recordType"].lower()
        lanes.append({"head": head, "entries": [{"record": original, "index": "0", "chainHash": head["headHash"],
            "envelopePath": component(label + "-envelope", "record_envelope"), "payloadPath": component(label + "-payload", "record_payload"),
            "signatureBundlePath": component(label + "-signature", "signature_bundle")}]})
    media = component("display-media", "media", True)
    semantic = {"schema": "STREAM_SEMANTIC_EXPORT_V1", "manifestPath": component("semantic-manifest", "semantic_manifest"),
        "sourceStateHash": keccak256(dumps(source)), "selectedRecordHashes": sorted(r["recordHash"] for r in records),
        "sourceHeadHashes": [h["headHash"] for h in heads], "subsequentExportRecordHash": None,
        "selectionPolicy": _reference("selection-policy"), "disclosureScope": {"policy": _reference("disclosure-policy"), "withheldResourceCount": "0"},
        "entityIndexPath": component("entity-index", "entity_index"), "linkedArtPaths": [component("linked-art-work", "linked_art")],
        "assertionPaths": [component("assertions", "assertions")], "provenancePath": component("provenance", "provenance"),
        "authoritySnapshotPaths": [], "dependencyLockPath": component("dependency-lock", "dependency_lock"),
        "interpretationPaths": [component("interpretation", "interpretation")], "coverageReportPath": component("coverage", "coverage_report"),
        "validationReportPath": component("validation", "validation_report"), "sharedSourceCrossFormatReportPath": component("cross-format", "validation_report")}
    dossier = {"schema": OBJECT, "version": 1, "exportProfile": "OBJECT_DOSSIER_V1", "acquisitionPacket": packet,
        "collectionManifests": {"script": {"status": "not_applicable"},
            "dependency": {"reference": _reference("dependency-manifest"), "subjectId": source["collectionSubjectId"], "componentPaths": []},
            "media": {"reference": _reference("media-manifest"), "subjectId": source["collectionSubjectId"], "componentPaths": [media]}},
        "recordInventory": lanes, "collectionConservation": {"iiifManifests": [], "significantProperties": [significant]},
        "components": sorted(components, key=lambda c: c["path"]), "semanticPackage": semantic,
        "packaging": {"profile": _reference("bagit-profile"), "selfContainment": "self_contained", "ocflObjectId": packet["citation"]["qualified"],
            "ocflVersion": "v1", "previousDossier": None}, "tooling": {"sourceArchive": _reference("tool-source"),
            "buildInstructions": _reference("tool-build"), "testVectors": _reference("tool-vectors"), "systemManifest": _reference("system-manifest"),
            "manifestToolSourceHash": _h("tool-source"), "archiveReceipts": [{"storageFamily": _h("family-" + str(i)),
                "receipt": _reference("tool-receipt-" + str(i))} for i in (1, 2)], "packetRegenerationDrill": _reference("regeneration-drill")},
        "institutionalEvidence": {"repositoryIngestReports": [], "practitionerReviews": []}}
    script = copy.deepcopy(packet)
    script.update(workClass="script", metadataMode="ONCHAIN")
    script["dossierBag"] = {"status": "not_accompanied"}
    script["preservation"].update(coverage="onchain_bound", scriptCoverage={"status": "uncovered_overdue",
        "captureSet": None, "environment": None, "evidence": _reference("script-coverage-overdue")})
    script["scriptDrill"] = {"status": "never_drilled", "evidence": _reference("script-never-drilled")}
    curated = copy.deepcopy(script)
    curated["scriptDrill"] = {"status": "recorded", "report": _reference("curated-drill"),
        "acceptanceMode": "CURATED_EQUIVALENCE", "outcome": "MATCH",
        "referenceRender": record("REFERENCE_RENDER", "STREAM_REFERENCE_RENDER_V1"),
        "curatedEvidence": {"attestation": record("INDEPENDENT_CONDITION", "STREAM_CONDITION_REPORT_V1", "token"),
            "verificationClass": "SIGNER_VERIFIED", "artistIntentRecordHash": intent["recordHash"],
            "examinerInstitution": _reference("synthetic-institution"), "examinerName": "Synthetic Conservator",
            "examinerCredential": _reference("synthetic-credential"), "fieldEvaluation": _reference("synthetic-field-evaluation")}}
    return {"acquisition-packet.json": packet, "object-dossier.json": dossier,
        "script-packet.json": script, "curated-script-packet.json": curated}


def outputs():
    result = {"schemas/records/" + name + ".json": raw for name, raw in documents().items()}
    for filename, value in examples().items():
        raw = dumps(value); validate(value["schema"], raw)
        result["schemas/records/examples/genesis-dossier/" + filename] = raw
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: need(destination.is_file() and destination.read_bytes() == raw, "generated bytes differ: " + path)
        else: destination.parent.mkdir(parents=True, exist_ok=True); destination.write_bytes(raw)
    print("Broad dossier/packet schemas and synthetic examples match; no registration or conformance claim.")


if __name__ == "__main__": main()
