"""Strict ART38 historical consumption of supplied native observations.

All inputs are inert bytes. Hash and ABI agreement is not RPC authentication,
signature verification, a C2PA validator, current authority or freeze evidence.
The original Metadata-backlink Artist adapter keeps its separate kind7/8 scope.
"""
import argparse
from dataclasses import dataclass
from pathlib import Path

from .artist_attestation_source import ATTESTATION_RECORD
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, decode, encode
from .independent_wire import RAW_BYTES, RAW_DEFINITION, RECORD, ZERO, ZERO_ADDRESS, json_values, require
from .metadata_catalog_source import RECEIPT, generic_hash

SOURCE_REVISION = "3f1a068088347176f85f3aa1a2731079e39d8227"
SOURCE_PINS = {
    "smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol": "a5cd5339e3acf43e8d33f0042dbb2d359e9a61972c329a2ea691b07dea170fda",
    "smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol": "0668a4076a94f107c8fa98b02b425a6d5b6cbe2935c8985beea4000da2aa267d",
    "smart-contracts/domains/artist/StreamArtistC2PACredentials.sol": "d7065355fca20821c32a94711253379405713d778bf7a8c8693fba724597a8f2",
    "smart-contracts/domains/metadata/StreamC2PAReconciliation.sol": "d7e9b674ecde58e075be178a9ca20530dd7b92b9d44be824c2930c52496b0424",
    "tools/artist/c2pa_reconciliation.py": "21521a2fc05022d889b5eea47e962c6ea0a149b2d4fe5c6eb076bf2fd8bb594d",
    "schemas/records/6529STREAM_C2PA_RECONCILIATION_REPORT_V1.json": "7d8e94b8b1ccb158d7296c86005915ef38f1c4e5e9429ce8fbf8c8ad9f50539e",
}
NAME = "STREAM_MUSEUM_ARTIST_C2PA_CONSUMPTION_V1"
PROFILE = schema_id("6529STREAM_C2PA_RECONCILIATION_V1")
CREDENTIAL_SCHEMA = schema_id("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1")
REPORT_NAME = "6529STREAM_C2PA_RECONCILIATION_REPORT_V1"
REPORT_SCHEMA = schema_id(REPORT_NAME)
REPORT_SCHEMA_HASH = "0x9c896dc177954cc145f240cbcd4097a3b953b0121360c7f2acef053bc17e68cb"
PERSONHOOD_SCHEMAS = tuple(schema_id("6529STREAM_ARTIST_PERSONHOOD_" + s + "_V1")
                          for s in ("WAIVER", "EVIDENCE"))
MAX_HISTORY = 256
MAX_INPUT_BYTES = 16 * 1024 * 1024
CREDENTIAL_FIELDS = ("kind", "fingerprint", "keyId", "validFrom", "validUntil")
CREDENTIAL = ("uint8", "bytes32", "bytes32", "uint64", "uint64")
PAYLOAD = ("uint16", "bytes32", "bytes32", "bytes32", Array(CREDENTIAL, 48))
HEAD_FIELDS = ("revision", "recordHash", "previousRecordHash", "artistId", "collectionId", "bindingHash",
               "generation", "identityRecordHash", "statementHash", "sourceRegistry")
HEAD = ("uint64", "bytes32", "bytes32", "bytes32", "uint256", "bytes32", "uint64", "bytes32", "bytes32", "address")
REPORT_FIELDS = ("version", "profile", "collectionId", "subjectId", "artistId", "bindingHash", "generation",
    "identityRecordHash", "credentialRecordHash", "identityDocumentHash", "publicKeyHistoryHash",
    "credentialEnumerationHash", "selectedMediaManifestHash", "mediaSlot", "mediaHash", "claimAssetHash",
    "manifestHash", "claimHash", "claimSignatureHash", "signerKind", "signerFingerprint", "signerKeyFingerprint",
    "keyId", "signedAt", "validation", "authorship", "assertsAuthorship", "validatorIdentityHash",
    "softwareVersionHash", "validationReportHash", "trustAnchorsHash", "reportURI")
REPORT = ("uint16", "bytes32", "uint256", "bytes32", "bytes32", "bytes32", "uint64", "bytes32", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
    "uint8", "bytes32", "bytes32", "bytes32", "uint64", "uint8", "uint8", "bool", "bytes32", "bytes32", "bytes32", "bytes32", "string")
SELECTION_FIELDS = ("recordHash", "previousSelection", "selectionHash", "revision", "recordIndex", "authorizationClass")
SELECTION = ("bytes32", "bytes32", "bytes32", "uint64", "uint64", "uint8", REPORT)
DISPLAY_FIELDS = ("recordHash", "selectionHash", "validation", "authorship", "current", "assertsAuthorship")
DISPLAY = ("bytes32", "bytes32", "uint8", "uint8", "bool", "bool")
VALIDATION = ("unevaluated", "valid", "invalid")
AUTHORSHIP = ("unevaluated", "consistent", "divergent")
CLAIMS = {"strictNativeDecoding": True, "suppliedByteCommitmentsChecked": True,
    "personhoodKeptSeparate": True, "selectedReportKeptHistorical": True,
    "authenticatedSource": False, "nativeAdmissionProven": False, "historyCompletenessProven": False,
    "currentAuthorityProven": False, "c2paCryptographyVerified": False, "trustAnchorsValidated": False,
    "personhoodProven": False, "frozenOutputConformance": False, "fullObjectDossierConformance": False}
QUALIFICATION = ("Supplied native ABI, record and selection hash correspondence only. Verifier validation and authorship "
    "are recorded claims. Display is a separate supplied observation. Source/runtime admission, original op24 signatures "
    "and receipts, complete chain history, identity/key interpretation, C2PA cryptography, trust quality, human identity "
    "and freeze-safe rendering require separate evidence. No URI is fetched or executed.")


def _named(names, values):
    return dict(zip(names, (json_values(v) for v in values)))


def _bytes(raw, maximum=8192):
    require(type(raw) is bytes and 0 < len(raw) <= maximum, "C2PA immutable byte bound")
    return {"bytesHex": "0x" + raw.hex(), "byteLength": str(len(raw)), "keccak256": keccak256(raw)}


def _input_budget(raws):
    total = 0
    for raw in raws:
        require(type(raw) is bytes, "C2PA immutable input bytes required")
        total += len(raw)
        require(total <= MAX_INPUT_BYTES, "C2PA aggregate offchain input bound")


def _payload(schema, raw):
    require(schema == CREDENTIAL_SCHEMA, "C2PA credential schema differs")
    value, = decode((PAYLOAD,), raw, maximum=8192)
    version, artist, identity, _, rows = value
    require(version == 1 and artist != ZERO and identity != ZERO, "C2PA credential identity/version")
    keys = []
    for kind, fingerprint, key, start, end in rows:
        require(kind != 0 and fingerprint != ZERO and key != ZERO and (end == 0 or end > start),
                "C2PA credential shape/validity")
        keys.append(keccak256(encode(CREDENTIAL, (kind, fingerprint, key, start, end))))
    require(keys == sorted(set(keys)), "C2PA credential ordering/duplicate")
    return value


def decode_credentials(schema, raw):
    """Decode the explicit new schema; unknown kinds remain opaque declarations."""
    version, artist, identity, previous, rows = _payload(schema, raw)
    return {"schemaVersion": str(version), "artistId": artist, "identityRecordHash": identity,
        "previousRecordHash": previous, "enumerationWithdrawn": not rows,
        "credentials": [{**_named(CREDENTIAL_FIELDS, row), "interpretation":
            {1: "sha256_spki", 2: "sha256_der_certificate"}.get(row[0], "opaque_unsupported")}
            for row in rows], "original": _bytes(raw)}


def _head(raw):
    head, = decode((HEAD,), raw, maximum=320)
    if head[1] == ZERO:
        require(head == (0, ZERO, ZERO, ZERO, 0, ZERO, 0, ZERO, ZERO, ZERO_ADDRESS), "C2PA partial empty head")
    else:
        require(head[0] > 0 and head[3] != ZERO and head[4] > 0 and head[5] != ZERO and head[6] > 0
                and head[7] != ZERO and head[8] != ZERO and head[9] != ZERO_ADDRESS, "C2PA head shape")
    return head


def decode_head(raw):
    return _named(HEAD_FIELDS, _head(raw))


@dataclass(frozen=True)
class CredentialEvidence:
    """Exact c2paCredentialRecord, attestationRecord and unwrapped statement bytes."""
    head: bytes
    attestation: bytes
    statement: bytes


def consume_credentials(artist_id, collection_id, current_head, history, personhood):
    """Join a supplied genesis-to-head chain; retain a separate personhood read.

    Credential history is artist-global, so prior collection IDs and source
    registries can differ. The personhood query is (collection_id, artist_id).
    Supplied revision coverage does not authenticate omission-free chain history.
    """
    require(any(hex_bytes(artist_id, 32)), "C2PA artist must be nonzero")
    encode(("uint256",), (collection_id,))
    require(type(history) is tuple and len(history) <= MAX_HISTORY, "C2PA history bound")
    tip = _head(current_head)
    require(tip[0] == len(history), "C2PA supplied history revision coverage")
    previous, rows = ZERO, []
    seen = set()
    for revision, item in enumerate(history, 1):
        require(type(item) is CredentialEvidence, "C2PA credential evidence type")
        head = _head(item.head)
        require(head[0] == revision and head[2] == previous and head[3] == artist_id
                and head[1] not in seen, "C2PA credential history linkage")
        attestation, = decode((ATTESTATION_RECORD,), item.attestation, maximum=224)
        require(attestation[:5] == (head[1], head[7], CREDENTIAL_SCHEMA, head[8], head[6])
                and attestation[6] != ZERO_ADDRESS, "C2PA original attestation/head differs")
        payload = _payload(CREDENTIAL_SCHEMA, item.statement)
        require(payload[1:4] == (artist_id, head[7], previous) and keccak256(item.statement) == head[8],
                "C2PA statement/head differs")
        rows.append({"head": _named(HEAD_FIELDS, head), "headOriginal": _bytes(item.head),
            "attestationWire": json_values(attestation), "attestationOriginal": _bytes(item.attestation),
            "statement": decode_credentials(CREDENTIAL_SCHEMA, item.statement)})
        seen.add(head[1]); previous = head[1]
    require((not history and tip[1] == ZERO) or (history and history[-1].head == current_head), "C2PA current head differs")
    person, = decode((ATTESTATION_RECORD,), personhood, maximum=224)
    if person[0] == ZERO:
        require(person == (ZERO, ZERO, ZERO, ZERO, 0, 0, ZERO_ADDRESS), "C2PA partial empty personhood")
    else:
        require(person[1] != ZERO and person[2] in PERSONHOOD_SCHEMAS and person[3] != ZERO and person[4] > 0
                and person[6] != ZERO_ADDRESS and person[0] not in seen, "C2PA personhood is not credential evidence")
    return {"profile": NAME, "sourceRevision": SOURCE_REVISION, "artistId": artist_id,
        "personhoodQueryCollectionId": str(collection_id), "currentHead": _named(HEAD_FIELDS, tip),
        "currentHeadOriginal": _bytes(current_head), "credentialHistory": rows,
        "personhood": {"wire": json_values(person), "original": _bytes(personhood),
            "status": "absent" if person[0] == ZERO else "supplied_separate_native_record"},
        "claims": dict(CLAIMS), "qualification": QUALIFICATION}


def report_schema_definition():
    raw = dumps({"name": REPORT_NAME, "version": "1", "encoding": "abi.encode(Report)",
        "fields": [{"name": name, "type": kind} for name, kind in zip(REPORT_FIELDS, REPORT)],
        "semantics": "Selected verifier observation; validation and authorship are separate. Zero is unevaluated. No authority is conferred."})
    require(keccak256(raw) == REPORT_SCHEMA_HASH, "C2PA pinned source schema differs")
    return raw


def _report(raw, definition):
    require(definition == report_schema_definition(), "C2PA exact report schema required")
    report, = decode((REPORT,), raw, maximum=8192)
    p = dict(zip(REPORT_FIELDS, report))
    nonzero = ("subjectId", "artistId", "bindingHash", "identityRecordHash", "publicKeyHistoryHash",
        "credentialEnumerationHash", "selectedMediaManifestHash", "mediaHash", "claimAssetHash", "manifestHash",
        "claimHash", "claimSignatureHash", "signerFingerprint", "signerKeyFingerprint", "keyId",
        "validatorIdentityHash", "softwareVersionHash", "validationReportHash", "trustAnchorsHash")
    require(p["version"] == 1 and p["profile"] == PROFILE and p["collectionId"] > 0 and p["generation"] > 0
            and p["signedAt"] > 0 and all(p[k] != ZERO for k in nonzero)
            and p["identityDocumentHash"] == p["identityRecordHash"] and p["mediaSlot"] in (1, 2, 3)
            and 0 < len(p["reportURI"].encode("utf-8")) <= 2048, "C2PA report shape")
    require(p["validation"] in range(3) and p["authorship"] in range(3), "C2PA report enum")
    require(p["mediaHash"] == p["claimAssetHash"] or p["validation"] == 2, "C2PA media hard-binding contradiction")
    require(p["signerKind"] != 1 or p["signerFingerprint"] == p["signerKeyFingerprint"], "C2PA SPKI contradiction")
    require((p["validation"] == 1 and p["assertsAuthorship"] and p["signerKind"] in (1, 2)) or p["authorship"] == 0,
            "C2PA unevaluated authorship required")
    return report


def decode_report(raw, definition):
    report = _report(raw, definition)
    return {**_named(REPORT_FIELDS, report), "validationLabel": VALIDATION[report[24]],
        "authorshipLabel": AUTHORSHIP[report[25]], "basis": "selected_verifier_recorded_claim",
        "original": _bytes(raw)}


@dataclass(frozen=True)
class Context:
    chain_id: int
    companion: str
    core: str
    metadata: str
    artist: str
    router: str
    verifier: str
    collection_id: int
    subject_id: str
    block_number: int
    block_hash: str

    def __post_init__(self):
        encode(("uint256", "uint256", "uint256"), (self.chain_id, self.collection_id, self.block_number))
        require(self.chain_id > 0 and self.collection_id > 0 and any(hex_bytes(self.subject_id, 32))
                and any(hex_bytes(self.block_hash, 32)), "C2PA context identity")
        for address in (self.companion, self.core, self.metadata, self.artist, self.router, self.verifier):
            require(any(hex_bytes(address, 20)), "C2PA context address")


@dataclass(frozen=True)
class ReportEvidence:
    """One exact original Metadata collectionRecord and unwrapped payload/artifacts."""
    record: bytes
    payload: bytes
    observation: bytes
    trust_anchors: bytes


def selection_hash(context, selection):
    """Original preimage: selectionHash is zero inside the nested Selection."""
    require(type(context) is Context, "C2PA context type")
    blank = (*selection[:2], ZERO, *selection[3:])
    return keccak256(encode(("bytes32", "uint256", *("address",) * 6, SELECTION),
        (PROFILE, context.chain_id, context.companion, context.core, context.metadata,
         context.artist, context.router, context.verifier, blank)))


def _original(context, selected, evidence, definition):
    require(type(evidence) is ReportEvidence, "C2PA report evidence type")
    report = _report(evidence.payload, definition)
    require(report == selected[6] and report[2:4] == (context.collection_id, context.subject_id), "C2PA selected report differs")
    record, receipt = decode((RECORD, RECEIPT), evidence.record, maximum=8192)
    require(record[0:2] == (schema_id("C2PA_VALIDATION"), context.subject_id)
            and record[2] == (1, hex_bytes(keccak256(evidence.payload)), RAW_BYTES)
            and record[4:7] == (REPORT_SCHEMA, ZERO, (0, b"", ZERO)) and record[7] > 0,
            "C2PA original Metadata record differs")
    require(receipt[0:3] == (context.collection_id, context.verifier, selected[5])
            and receipt[2] in (4, 6) and receipt[4] == selected[4]
            and receipt[6:9] == (REPORT_SCHEMA_HASH, keccak256(RAW_DEFINITION), ZERO),
            "C2PA original Metadata receipt differs")
    require(generic_hash(context.chain_id, context.metadata, context.core, context.collection_id,
                         context.verifier, record) == selected[0], "C2PA original record hash differs")
    uri = record[3].encode("utf-8")
    require(len(uri) <= 2048 and (not uri or (all(b > 32 and b != 127 for b in uri)
            and ((uri.startswith(b"https://") and len(uri) > 8 and uri[8] not in b"/?#")
                 or (uri.startswith(b"ipfs://") and len(uri) > 7)
                 or (uri.startswith(b"ar://") and len(uri) > 5)))), "C2PA Metadata URI shape")
    for raw, digest in ((evidence.observation, report[29]), (evidence.trust_anchors, report[30])):
        _bytes(raw)
        require(keccak256(raw) == digest, "C2PA retained verifier artifact differs")
    return {"report": decode_report(evidence.payload, definition), "recordWire": json_values(record),
        "receiptWire": json_values(receipt), "recordOriginal": _bytes(evidence.record),
        "validationObservation": _bytes(evidence.observation), "trustAnchors": _bytes(evidence.trust_anchors)}


def consume_reconciliation(context, definition, current, history, display, evidence):
    """Consume supplied selections without promoting verifier claims to truth.

    A stale display keeps the original report and identifiers. A successful
    current display is still an observation, not proof of current source pins.
    This base seam deliberately makes no finality/frozen-presentation claim.
    """
    require(type(context) is Context and type(history) is tuple and type(evidence) is tuple
            and len(history) == len(evidence) <= MAX_HISTORY, "C2PA selection history bound")
    require(definition == report_schema_definition(), "C2PA exact report schema required")
    tip, = decode((SELECTION,), current, maximum=8192)
    require(tip[3] == len(history), "C2PA selection revision coverage")
    previous, previous_index, seen, rows = ZERO, -1, set(), []
    for revision, (raw, original) in enumerate(zip(history, evidence), 1):
        selected, = decode((SELECTION,), raw, maximum=8192)
        require(selected[0] != ZERO and selected[0] not in seen and selected[1] == previous
                and selected[3] == revision and selected[4] > previous_index and selected[5] in (4, 6)
                and selected[2] == selection_hash(context, selected), "C2PA selection chain differs")
        rows.append({**_named(SELECTION_FIELDS, selected[:6]), "selectionOriginal": _bytes(raw),
                     **_original(context, selected, original, definition)})
        previous, previous_index = selected[2], selected[4]; seen.add(selected[0])
    if history:
        require(history[-1] == current, "C2PA current selection differs")
    else:
        empty_report = tuple(False if t == "bool" else "" if t == "string" else ZERO if t == "bytes32" else 0 for t in REPORT)
        require(tip == (ZERO, ZERO, ZERO, 0, 0, 0, empty_report), "C2PA partial empty selection")
    shown, = decode((DISPLAY,), display, maximum=192)
    require(shown[:2] == (tip[0], tip[2]) and shown[2] in range(3) and shown[3] in range(3)
            and shown[5] == tip[6][26], "C2PA display identity/enum differs")
    if shown[4]:
        require(tip[0] != ZERO and shown[2:4] == tip[6][24:26], "C2PA current display contradicts selected report")
    else:
        require(shown[2:4] == (0, 0), "C2PA stale display must be unevaluated")
    return {"profile": NAME, "sourceRevision": SOURCE_REVISION,
        "context": {k: json_values(v) for k, v in context.__dict__.items()},
        "reportDefinition": _bytes(definition), "selectionHistory": rows,
        "currentSelectionOriginal": _bytes(current), "displayOriginal": _bytes(display),
        "displayObservation": {**_named(DISPLAY_FIELDS, shown), "validationLabel": VALIDATION[shown[2]],
            "authorshipLabel": AUTHORSHIP[shown[3]], "basis": "supplied_native_display_observation"},
        "claims": dict(CLAIMS), "qualification": QUALIFICATION}


@dataclass(frozen=True)
class ArtistEvidence:
    artist_id: str
    current_head: bytes
    history: tuple[CredentialEvidence, ...]
    personhood: bytes


def consume(context, definition, current, history, display, evidence, artists, identity_documents):
    """Join historical reports to exact identity bytes and original credentials.

    Each artist has its own global credential history and collection-scoped
    personhood read. A later withdrawal does not erase an older selected report.
    Identity-only enumeration applies only to the report's zero credential head.
    The verifier's observation and its cryptography remain unexecuted claims.
    """
    require(type(artists) is tuple and len(artists) <= MAX_HISTORY and type(identity_documents) is dict
            and len(identity_documents) <= MAX_HISTORY, "C2PA joined evidence bound")
    require(type(history) is tuple and type(evidence) is tuple and len(history) == len(evidence) <= MAX_HISTORY,
            "C2PA selection history bound")
    raws = [definition, current, display, *history, *identity_documents.values()]
    for original in evidence:
        require(type(original) is ReportEvidence, "C2PA report evidence type")
        raws.extend((original.record, original.payload, original.observation, original.trust_anchors))
    for supplied in artists:
        require(type(supplied) is ArtistEvidence and type(supplied.history) is tuple
                and len(supplied.history) <= MAX_HISTORY, "C2PA artist evidence shape/bound")
        raws.extend((supplied.current_head, supplied.personhood))
        for item in supplied.history:
            require(type(item) is CredentialEvidence, "C2PA credential evidence type")
            raws.extend((item.head, item.attestation, item.statement))
    # Count occurrences, including reused bytes, before constructing any output.
    _input_budget(raws)
    reconciled = consume_reconciliation(context, definition, current, history, display, evidence)
    states, original_records = {}, {}
    for supplied in artists:
        require(type(supplied) is ArtistEvidence and supplied.artist_id not in states, "C2PA duplicate artist evidence")
        states[supplied.artist_id] = consume_credentials(supplied.artist_id, context.collection_id,
            supplied.current_head, supplied.history, supplied.personhood)
        original_records[supplied.artist_id] = {_head(item.head)[1]: item for item in supplied.history}
    documents, used_documents, joins = {}, set(), []
    for digest, raw in identity_documents.items():
        require(any(hex_bytes(digest, 32)) and type(raw) is bytes and keccak256(raw) == digest, "C2PA identity bytes differ")
        value = loads(raw, maximum=8192, canonical=True)
        required = {"schema", "displayName", "biographicalRefs", "publicKeyHistory", "c2paCredentials", "payoutAccounts"}
        require(type(value) is dict and required <= set(value) and set(value) <= required | {"extensions"}
                and value["schema"] == "6529STREAM_ARTIST_IDENTITY_V1"
                and type(value["publicKeyHistory"]) is list and type(value["c2paCredentials"]) is list,
                "C2PA identity document shape")
        documents[digest] = value
    for row in reconciled["selectionHistory"]:
        report = _report(hex_bytes(row["report"]["original"]["bytesHex"]), definition)
        p = dict(zip(REPORT_FIELDS, report))
        require(p["artistId"] in states and p["identityRecordHash"] in documents, "C2PA report source absent")
        identity = documents[p["identityRecordHash"]]; used_documents.add(p["identityRecordHash"])
        require(keccak256(dumps(identity["publicKeyHistory"])) == p["publicKeyHistoryHash"], "C2PA key-history bytes differ")
        if p["credentialRecordHash"] == ZERO:
            require(keccak256(dumps(identity["c2paCredentials"])) == p["credentialEnumerationHash"], "C2PA identity enumeration differs")
            basis = "historical_identity_document_enumeration"
        else:
            item = original_records[p["artistId"]].get(p["credentialRecordHash"])
            require(item is not None, "C2PA original credential record absent")
            head = _head(item.head)
            require(head[7:9] == (p["identityRecordHash"], p["credentialEnumerationHash"]), "C2PA historical credential head differs")
            credentials = _payload(CREDENTIAL_SCHEMA, item.statement)[4]
            matched = any(c[0] == p["signerKind"] and c[1] == p["signerFingerprint"] and c[2] == p["keyId"]
                and c[3] <= p["signedAt"] and (c[4] == 0 or p["signedAt"] < c[4]) for c in credentials)
            opaque = any(c[0] not in (1, 2) for c in credentials)
            require(matched or p["authorship"] != 1, "C2PA declared credential does not match consistent claim")
            require((credentials and (matched or not opaque)) or p["authorship"] == 0, "C2PA withdrawal/opaque authorship must be unevaluated")
            basis = "historical_native_credential_record"
        joins.append({"selectionHash": row["selectionHash"], "artistId": p["artistId"], "basis": basis,
            "identityDocumentHash": p["identityDocumentHash"], "credentialRecordHash": p["credentialRecordHash"],
            "keyHistoryInterpretationVerified": False, "c2paCryptographyVerified": False})
    require(used_documents == set(documents), "C2PA unrelated identity documents")
    if reconciled["displayObservation"]["current"]:
        latest = reconciled["selectionHistory"][-1]["report"]
        head = states[latest["artistId"]]["currentHead"]
        require(head["recordHash"] == latest["credentialRecordHash"], "C2PA current display credential head differs")
        if head["recordHash"] != ZERO:
            require(head["identityRecordHash"] == latest["identityRecordHash"]
                    and head["statementHash"] == latest["credentialEnumerationHash"], "C2PA current display credential source differs")
    return {"profile": NAME, "sourceRevision": SOURCE_REVISION, "reconciliation": reconciled,
        "artists": [states[k] for k in sorted(states)], "identityDocuments":
            [{"hash": k, "original": _bytes(identity_documents[k])} for k in sorted(documents)],
        "historicalJoins": joins, "claims": dict(CLAIMS), "qualification": QUALIFICATION}


def profile_bytes():
    return dumps({"name": NAME, "version": "1", "status": "prospective_unregistered_supplied_evidence_profile",
        "sourceRevision": SOURCE_REVISION, "sourceSHA256": SOURCE_PINS,
        "credentialSchemaId": CREDENTIAL_SCHEMA, "reportSchemaId": REPORT_SCHEMA,
        "reportSchemaHash": REPORT_SCHEMA_HASH, "reconciliationProfile": PROFILE,
        "scope": "Exact native credential/personhood reads and historical Metadata reconciliation observations; no network capture or source authentication.",
        "bounds": {"credentialRows": "48", "historyPerArtistOrSubject": str(MAX_HISTORY),
            "artists": str(MAX_HISTORY), "identityDocuments": str(MAX_HISTORY), "statementBytes": "8192",
            "joinedInputOccurrenceBytes": str(MAX_INPUT_BYTES),
            "reportBytes": "8192", "observationOrTrustAnchorBytes": "8192", "reportURIBytes": "2048"},
        "claims": CLAIMS, "qualification": QUALIFICATION})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[2] / "schemas/museum/artist-c2pa/profile.json"
    raw = profile_bytes()
    if args.check:
        require(path.is_file() and path.read_bytes() == raw, "C2PA consumer profile drift")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    print("Museum ART38 consumer profile exact; supplied-byte agreement only.")


if __name__ == "__main__":
    main()
