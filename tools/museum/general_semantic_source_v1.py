"""Exact General-account semantic statements and earlier Metadata evidence.

The source replays both original catalogues before interpreting a finite profile.
It does not select assertions, re-execute historical signatures or turn named
institutions, curatorial DID text or documentary references into authority.
"""

from .account_profile import ACCOUNT_PREFIX, ASSERTION_SCHEMA_BYTES, JCS_ID, account_iri
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport
from .general_attestation_source import CURATORIAL, ESTATE, INSTITUTIONAL
from .general_attestation_source_v2 import (
    GeneralAttestationSourceV2, MAX_PAYLOAD, PROFILE_HASH as GENERAL_PROFILE_HASH,
)
from .general_semantic_profile_v1 import (
    CLAIMS, QUALIFICATION, GeneralSemanticProfileV1, NAME as INTERPRETATION_NAME,
)
from .independent_source import IndependentSourceAdapter
from .independent_wire import RAW_BYTES, ZERO, require
from .metadata_catalog_source import MetadataCatalogSource, PROFILE_HASH as METADATA_PROFILE_HASH
from .native_attribution_semantics import selector as metadata_selector
from .owner_notice_semantics import consistent_reads
from .recorded_semantic import resolve_pointer
from .review import _validate
from .schemas import NAMES


NAME = PROFILE = "STREAM_MUSEUM_GENERAL_SEMANTIC_SOURCE_V1"
COMMON = ("chainId", "core", "collectionId", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment")
VERIFICATION = {1: "SIGNER_VERIFIED", 2: "OPERATOR_ASSERTED"}
AUTHORITY = {1: "GENERAL_SIGNER_CLAIM", 2: "CONFIGURED_OPERATOR_CLAIM", 3: "NATIVE_ARTIST_HISTORY"}
PROFILE_BYTES = SOURCE_PROFILE_BYTES = dumps({
    "name": NAME, "version": "1", "status": "prospective_unregistered_read_profile",
    "interpretationProfile": INTERPRETATION_NAME,
    "sources": {"generalProfileHash": GENERAL_PROFILE_HASH, "metadataProfileHash": METADATA_PROFILE_HASH},
    "scope": "All original four-lane General V2 records retained before interpretation or selection; only generic institutional, estate and curatorial exact-profile payloads are interpreted.",
    "sharedState": list(COMMON),
    "deploymentEvidence": "Both original anchor commitments retained separately; host-specific deployment artifacts need not be equal and are not authenticated here.",
    "runtimeAndReads": "Intersecting admitted runtime pins and every repeated observed call/code answer across both sources and this reader must agree.",
    "ordering": "Every referenced Metadata receipt timestamp must be strictly earlier than the General receipt timestamp. No same-timestamp or cross-host transaction ordering inference.",
    "unknown": "Other families/schema/canonicalization combinations and valid JSON with another interpretation profile remain unsupported. Claimed assertion-schema/JCS payloads must be canonical JSON; a claimed supported profile is validated strictly.",
    "interpretationDocuments": "Registered interpretation documents are read only when a payload claims this supported profile. interpretationDocumentsChecked reports that actual capture; empty and all-unsupported catalogues do not establish registration of this new profile.",
    "evidence": "Only documentary_evidence, exact algorithm1 original payload HashRef, and whole_document/JSON Pointer. No own_signed_statement or external URI fetch.",
    "bounds": {"originalGeneralRecords": "4096", "genericPayloadBytes": str(MAX_PAYLOAD),
        "snapshotBytes": str(MAX_TRANSCRIPT), "documentaryPayloadBytes": "8192"},
    "claims": CLAIMS, "qualification": QUALIFICATION,
})
PROFILE_HASH = SOURCE_PROFILE_HASH = keccak256(PROFILE_BYTES)


def selector(row, anchor, pointer=""):
    """General selectors deliberately use no Metadata authorizationClass field."""
    value, receipt = row["value"], row["receipt"]
    return {"kind": "native_general_attestation", "chainId": anchor["chainId"],
        "host": anchor["host"], "recordHash": row["recordHash"], "subjectId": value[2],
        "recordType": value[3], "schemaId": value[5], "schemaHash": receipt[11],
        "canonicalizationId": value[6], "recorder": receipt[0],
        "verificationClass": VERIFICATION[uint(receipt[1])],
        "authorityQualification": AUTHORITY[uint(receipt[2])],
        "recordIndex": receipt[4], "recordChainHash": receipt[5], "pointer": pointer}


def _authority(row, anchor):
    value, receipt = row["value"], row["receipt"]
    signed = uint(receipt[1]) == 1
    return {"kind": "historical_general_receipt", "authenticatedRecorder": receipt[0],
        "assertingAccount": account_iri(anchor["chainId"], receipt[0]),
        "assertedAttester": value[0], "assertedAttesterDID": value[4],
        "assertedAttesterSigned": signed, "unsignedAttesterAndDIDNotUsedAsAuthority": not signed,
        "verificationClass": VERIFICATION[uint(receipt[1])],
        "authorityQualification": AUTHORITY[uint(receipt[2])],
        "recordedAt": receipt[3], "effectiveAt": value[11],
        "signatureScheme": receipt[9], "signatureBundleHash": receipt[10],
        "authorizationDigest": receipt[6], "nonce": receipt[7], "deadline": receipt[8],
        "authorityFamily": receipt[14], "authorizationClass": receipt[15],
        "grantCollectionId": receipt[16], "grantRevision": receipt[17],
        "originalProfileDefinitionHash": receipt[13],
        "currentAuthorityRevalidated": False, "namedInstitutionIdentityProven": False,
        "signatureCurrentlyRevalidated": False}


def _consistent(transcripts, pins):
    consistent_reads(transcripts)
    # Getter identity is independent of the caller's gas allowance.  The raw
    # request is still retained; this additional join cannot hide contradictions.
    calls, codes = {}, {}
    for raw in transcripts:
        for row in loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)["calls"]:
            method, params = row["method"], row["params"]
            if method == "eth_call":
                request = params[0]
                key = dumps([request["to"], request["data"], params[1]])
                result = row["result"]
                require(key not in calls or calls[key] == result, "general semantic cross-source getter differs")
                calls[key] = result
            elif method == "eth_getCode":
                address = params[0]
                digest = keccak256(hex_bytes(row["result"]))
                key = dumps(params)
                require(key not in codes or codes[key] == digest, "general semantic cross-source runtime differs")
                require(address not in pins or pins[address] == digest,
                    "general semantic observed runtime contradicts admitted pin")
                codes[key] = digest


class GeneralSemanticSourceV1:
    _read = IndependentSourceAdapter._read
    _block = IndependentSourceAdapter._block
    _chunk = IndependentSourceAdapter._chunk
    _document = IndependentSourceAdapter._document

    def __init__(self, metadata, general, transport, *, profile=None):
        require(type(metadata) is MetadataCatalogSource and type(general) is GeneralAttestationSourceV2,
            "concrete Metadata and General V2 sources required")
        require(metadata.provenance == general.provenance,
            "general semantic source provenance differs")
        require(metadata.provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport),
            "synthetic semantic transport cannot become trusted")
        require(all(metadata.a[key] == general.a[key] for key in COMMON),
            "general semantic shared source state differs")
        require(all(metadata.a[left] == general.a[right] for left, right in (
            ("host", "metadata"), ("schemas", "schemas"), ("store", "store"),
            ("artistRegistry", "artistRegistry"))), "general semantic shared dependencies differ")
        pins = dict(metadata.pins)
        for address, digest in general.pins.items():
            require(address not in pins or pins[address] == digest,
                "general semantic admitted runtime pins conflict")
            pins[address] = digest
        self.metadata, self.general = metadata, general
        self.a, self.pins, self.anchor_bytes = general.a, pins, general.anchor_bytes
        self.provenance = general.provenance
        self.profile = profile or GeneralSemanticProfileV1()
        require(type(self.profile) is GeneralSemanticProfileV1, "exact General semantic profile required")
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self.documents, self.document_stack, self.chunks = {}, set(), {}
        self.document_bytes, self._started, self._snapshot = 0, False, None

    def transcript(self):
        require(self._snapshot is not None, "general semantic snapshot required")
        return self.reader.transcript()

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed General semantic capture cannot resume")
        self._started = True
        try:
            return self._capture()
        except MuseumError:
            raise
        except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
            raise MuseumError("malformed General semantic evidence") from exc

    def _definitions(self):
        for name, (kind, expected) in self.profile.documents.items():
            identifier = schema_id(name)
            self._document(identifier, kind, keccak256(expected))
            _, actual, view = self.documents[identifier]
            require(actual == expected and view[3][2] == keccak256(expected)
                and view[3][3] == (RAW_BYTES if identifier == JCS_ID else JCS_ID)
                and view[3][4] == ZERO, "general semantic registered interpretation differs")

    def _capture(self):
        metadata_raw, general_raw = self.metadata.snapshot(), self.general.snapshot()
        metadata = loads(metadata_raw, maximum=MAX_TRANSCRIPT, canonical=True)
        general = loads(general_raw, maximum=MAX_TRANSCRIPT, canonical=True)
        originals = {row["recordHash"]: row for row in metadata["records"]}
        payloads = {key: hex_bytes(row["payloadHex"]) for key, row in originals.items()}
        payload_hashes = {key: keccak256(raw) for key, raw in payloads.items()}
        resolved = set()

        def resolve(key, pointer):
            if (key, pointer) not in resolved:
                resolve_pointer(payloads[key], pointer)
                resolved.add((key, pointer))

        self._block()
        for name in ("schemas", "store"):
            code = hex_bytes(self.reader.code(self.a[name]))
            require(0 < len(code) <= 24576 and keccak256(code) == self.pins[self.a[name]],
                "general semantic definition runtime differs")
        statements, checked_documents = [], False
        for original in general["records"]:
            value, receipt = original["value"], original["receipt"]
            row = {"source": selector(original, self.a), "original": original,
                "status": "unsupported", "reasonCode": "source_family_schema_or_canonicalization_unsupported",
                "value": None, "authority": _authority(original, self.a), "sourceRecords": []}
            statements.append(row)
            if value[3] not in (INSTITUTIONAL, ESTATE, CURATORIAL) or value[5] != schema_id(NAMES[1]) or value[6] != JCS_ID:
                continue
            raw = hex_bytes(original["payloadHex"])
            parsed = loads(raw, maximum=MAX_PAYLOAD, canonical=True)
            if type(parsed) is not dict or parsed.get("profileHash") != self.profile.profile_hash:
                row["reasonCode"] = "interpretation_profile_unsupported"
                continue
            parsed = _validate(ASSERTION_SCHEMA_BYTES, raw)
            if not checked_documents:
                self._definitions()
                checked_documents = True
            require(receipt[11] == keccak256(ASSERTION_SCHEMA_BYTES)
                and receipt[12] == keccak256(self.profile.documents["RFC8785_JCS"][1])
                and receipt[13] == ZERO, "general semantic original definition commitments differ")
            subject = original["subject"]
            require(type(subject) is list and len(subject) == 4,
                "general semantic original subject missing")
            kind = uint(subject[0], 8)
            require(kind in (0, 1, 2) and parsed["profileSchemaId"] == schema_id(NAMES[0])
                and parsed["anchorSubject"] == {"kind": ("collection", "token", "media")[kind],
                    "subjectId": value[2]}, "general semantic subject/profile differs")
            issuer = account_iri(self.a["chainId"], receipt[0])
            require(all(entity["declaringAgent"] == issuer
                and not entity["id"].casefold().startswith(ACCOUNT_PREFIX)
                for entity in parsed["entities"]), "general semantic declaring account impersonation")
            require(all(assertion["assertingAgent"] == issuer for assertion in parsed["assertions"]),
                "general semantic asserting account impersonation")
            priors = []
            references = [*parsed["sourceRecords"],
                *(reference for entity in parsed["entities"] for reference in entity["sourceRecords"])]
            for reference in references:
                key = reference["recordHash"]
                previous = originals.get(key)
                require(previous is not None and reference == metadata_selector(previous,
                    self.metadata.a["host"], reference["pointer"]),
                    "general semantic documentary selector differs")
                require(uint(previous["receipt"][3], 64) < uint(receipt[3], 64),
                    "general semantic evidence must have strictly earlier timestamp")
                resolve(key, reference["pointer"])
                row["sourceRecords"].append({"source": reference,
                    "recordedAt": previous["receipt"][3], "payloadHash": payload_hashes[key]})
            priors = [originals[reference["recordHash"]] for reference in parsed["sourceRecords"]]
            for assertion in parsed["assertions"]:
                for evidence in assertion["evidence"]:
                    require(evidence["basis"] == "documentary_evidence",
                        "general semantic own_signed_statement is unsupported")
                    matches = [previous for previous in priors if evidence["source"] == {
                        "algorithm": "1", "digest": payload_hashes[previous["recordHash"]],
                        "canonicalizationId": previous["record"][2][2]}]
                    require(matches, "general semantic evidence hash is not a referenced original")
                    require(evidence["selectorType"] in ("json_pointer", "whole_document")
                        and (evidence["selectorType"] != "whole_document" or evidence["selector"] == ""),
                        "general semantic evidence selector unsupported")
                    for previous in matches:
                        resolve(previous["recordHash"], evidence["selector"])
            require(len({assertion["id"] for assertion in parsed["assertions"]}) == len(parsed["assertions"]),
                "general semantic duplicate assertion ID")
            row.update(status="supported", reasonCode=None, value=parsed)
        self._block()
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        transcript = self.reader.transcript()
        _consistent([self.metadata.transcript(), self.general.transcript(), transcript], self.pins)
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "interpretationProfileHash": self.profile.profile_hash,
            "interpretationDocumentsChecked": checked_documents,
            "sourceState": {key: self.a[key] for key in COMMON}, "provenance": self.provenance,
            "generalHost": self.a["host"], "metadataHost": self.metadata.a["host"],
            "generalSourceHash": keccak256(general_raw), "metadataSourceHash": keccak256(metadata_raw),
            "generalAnchorHash": keccak256(self.general.anchor_bytes),
            "metadataAnchorHash": keccak256(self.metadata.anchor_bytes),
            "deploymentEvidence": {"general": self.general.a["deploymentEvidenceHash"],
                "metadata": self.metadata.a["deploymentEvidenceHash"]},
            "transcriptHash": keccak256(transcript), "statements": statements,
            "catalogue": general["catalogue"], "lanes": general["lanes"],
            "documents": [{"documentId": key, "rawViewHex": "0x" + view.hex(),
                "payloadHex": "0x" + payload.hex()} for key, (view, payload, _) in sorted(self.documents.items())],
            "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_TRANSCRIPT, "general semantic snapshot byte bound")
        self._snapshot = result
        return result
