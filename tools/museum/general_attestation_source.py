"""Complete one-collection reader for the prospective GeneralAttestations host.

The reader preserves accepted native bytes and classifications at one pinned
block. RPC provenance remains caller admitted; no legal identity, truth,
institutional standing, consensus, or deployment acceptance is inferred.
"""

from pathlib import Path

from tools.metadata import identity_notarization_profile as notarization

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_abi import decode, encode
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_source import IndependentSourceAdapter
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values, require
from .owner_notice_semantics import consistent_reads


PROFILE = "STREAM_MUSEUM_GENERAL_ATTESTATION_SOURCE_V1"
MAX_RECORDS, MAX_TYPES, MAX_SNAPSHOT = 4096, 4, 67108864
TYPE_NAMES = ("ARTIST_STATEMENT", "INSTITUTIONAL_VERIFICATION", "ESTATE_VERIFICATION",
              "CURATORIAL_STATEMENT")
TYPES = {schema_id(name): name for name in TYPE_NAMES}
ARTIST = schema_id("ARTIST_STATEMENT")
INSTITUTIONAL = schema_id("INSTITUTIONAL_VERIFICATION")
ESTATE = schema_id("ESTATE_VERIFICATION")
CURATORIAL = schema_id("CURATORIAL_STATEMENT")
CURATOR_FAMILY = schema_id("6529STREAM_RECORD_FAMILY_CURATOR_V1")
FAMILY = schema_id("6529STREAM_RECORD_FAMILY_GENERAL_ATTESTATION_V1")
BUNDLE_FAMILY = schema_id("STREAM_GENERAL_ATTESTATION_SIGNATURE_BUNDLE_V1")
EIP712 = schema_id("EIP712")
ERC1271 = schema_id("ERC1271")
TYPE_HASH = schema_id("StreamGeneralAttestation(address attester,uint256 collectionId,bytes32 subjectId,bytes32 attestationType,string attesterDID,bytes32 schemaId,bytes32 canonicalizationId,string statementURI,bytes payload,bytes32 supersedes,bytes32 artistAuthorizationRecordHash,uint64 effectiveAt,uint256 nonce,uint64 deadline)")
RECORD_HASH_TYPE = schema_id("6529STREAM_GENERAL_ATTESTATION_RECORD_V1")
CHAIN_HASH_TYPE = schema_id("6529STREAM_GENERAL_ATTESTATION_CHAIN_V1")
ATTESTATION = ("address", "uint256", "bytes32", "bytes32", "string", "bytes32", "bytes32",
               "string", "bytes32", "bytes32", "bytes32", "uint64")
RECEIPT = ("address", "uint8", "uint8", "uint64", "uint64", "bytes32", "bytes32", "uint256",
           "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint8",
           "uint256", "uint64", "address", "bytes32", "bytes32", "bytes32", "bytes32", "uint8")
SUBJECT = ("uint8", "uint256", "uint256", "bytes32")
ARTIST_RECEIPT = ("uint16", "bytes32", "uint256", "bytes32")
ARTIST_TERMS = ("uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "string")
ARTIST_RECORD = ("bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint64", "address")
ARTIST_FACT = ("address", "bytes32", "bytes32", "bytes32")
ARTIST_ASSOCIATION = ("bytes32", "bytes32", "uint64", "bytes32", ARTIST_FACT)
ARTIST_PROOF = ("address", "bytes32", "address", "bytes32", "uint256", ARTIST_RECEIPT,
                ARTIST_TERMS, ARTIST_RECORD, ARTIST_ASSOCIATION, "uint8", "uint256")
IDENTITY = ("address", "uint8", "uint8", "uint64", "uint64", "bytes32", "string", "string", "uint256")
JCS_NAME = "RFC8785_JCS"
JCS_ID = schema_id(JCS_NAME)
SCHEMA_ID = schema_id(notarization.SCHEMA_NAME)
PROFILE_ID = schema_id(notarization.PROFILE_NAME)
JCS_BYTES = (Path(__file__).resolve().parents[2] / "schemas/museum/account-profile/RFC8785_JCS.json").read_bytes()
JCS_HASH = keccak256(JCS_BYTES)
QUALIFICATION = (
    "Complete fixed native GeneralAttestations lanes for one collection at a caller-admitted pinned block. "
    "Original attestation, receipt, payload, signature bundle, native Artist proof and registered definitions are retained. "
    "SIGNER_VERIFIED authenticates an account signature; OPERATOR_ASSERTED authenticates a historical configured writer; "
    "neither proves legal personhood, institution identity, truth, reviewer independence, consensus, or current authority."
)
CLAIMS = {"completeFixedTypeCatalogue": True, "completeCollectionLanes": True,
    "authenticatedEmptyLanes": True, "payloadPointerCatalogueComplete": True,
    "historicalReceiptCorrespondenceChecked": True, "typedNotarizationShapeChecked": True,
    "signatureCurrentlyRevalidated": False, "legalIdentityProven": False,
    "institutionalStandingProven": False, "reviewerIndependenceProven": False,
    "actualChainAcceptance": False, "consensusProof": False, "fullObjectDossierConformance": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_read_profile",
    "scope": "all four natively admissible GeneralAttestations types for one nonzero collection",
    "types": list(TYPE_NAMES), "bounds": {"types": str(MAX_TYPES), "records": str(MAX_RECORDS),
        "payloadBytes": "8192", "signatureBytes": "4096", "snapshotBytes": str(MAX_SNAPSHOT)},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def domain(chain, host):
    return keccak256(encode(("bytes32", "bytes32", "bytes32", "uint256", "address"),
        (schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
         schema_id("6529StreamGeneralAttestations"), schema_id("1"), chain, host)))


def signed_words(value, payload, receipt):
    return encode(("bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32",
        "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint256", "uint64"),
        (TYPE_HASH, value[0], value[1], value[2], value[3],
        keccak256(value[4].encode("utf-8")), value[5], value[6], keccak256(value[7].encode("utf-8")),
        keccak256(payload), value[9], value[10], value[11], receipt[7], receipt[8]))


def native_record_hash(chain, host, value, receipt):
    before_position = list(receipt)
    before_position[4], before_position[5] = 0, ZERO
    return keccak256(encode(("bytes32", "uint256", "address", ATTESTATION, RECEIPT),
        (RECORD_HASH_TYPE, chain, host, value, tuple(before_position))))


def chain_hash(collection, record_type, previous, digest, index):
    return keccak256(encode(("bytes32", "uint256", "bytes32", "bytes32", "bytes32", "uint64"),
        (CHAIN_HASH_TYPE, collection, record_type, previous, digest, index)))


def artist_authorization_hash(chain, core, proof):
    registry, _, _, _, _, _, terms, record, association, authority_class, nonce = proof
    return keccak256(encode(("bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32",
        "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"),
        (schema_id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), chain, registry, core, *terms[:6],
         keccak256(terms[6].encode("utf-8")), association[0], record[6], authority_class, nonce, record[5])))


def _safe_text(value, maximum, label, *, uri=False):
    raw = value.encode("utf-8")
    require(len(raw) <= maximum, label + " differs")
    if uri and raw:
        require(all(byte > 32 and byte != 127 for byte in raw)
            and ((raw.startswith(b"https://") and len(raw) > 8 and raw[8] not in b"/?#")
            or (raw.startswith(b"ipfs://") and len(raw) > 7)
            or (raw.startswith(b"ar://") and len(raw) > 5)), label + " differs")


def _anchor(raw):
    value = loads(raw, maximum=524288, canonical=True)
    fields = {"profile", "chainId", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment",
        "deploymentEvidenceHash", "host", "core", "schemas", "store", "metadata", "artistRegistry",
        "artistAttribution", "codePins", "collectionId"}
    require(type(value) is dict and set(value) == fields and value["profile"] == PROFILE
        and value["environment"] in ("local_evm_fixture", "public_chain"), "general attestation anchor shape")
    for key in ("chainId", "blockNumber", "collectionId"):
        uint(value[key])
    uint(value["timestamp"], 64)
    require(uint(value["chainId"]) > 0 and uint(value["collectionId"]) > 0, "general attestation source scope")
    for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
        require(any(hex_bytes(value[key], 32)), "general attestation empty commitment")
    dependencies = ("host", "core", "schemas", "store", "metadata", "artistRegistry", "artistAttribution")
    for key in dependencies:
        require(any(hex_bytes(value[key], 20)), "general attestation dependency address")
    require(type(value["codePins"]) is list and 7 <= len(value["codePins"]) <= 64,
        "general attestation code pin bound")
    pins = {}
    for row in value["codePins"]:
        require(type(row) is dict and set(row) == {"address", "runtimeHash"}
            and any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
            and row["address"] not in pins, "general attestation code pin shape")
        pins[row["address"]] = row["runtimeHash"]
    require(all(value[key] in pins for key in dependencies), "general attestation missing dependency pin")
    return value, pins


class GeneralAttestationSource:
    _read = IndependentSourceAdapter._read
    _block = IndependentSourceAdapter._block
    _chunk = IndependentSourceAdapter._chunk
    _document = IndependentSourceAdapter._document

    def __init__(self, anchor_raw, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc")
            and (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)),
            "general attestation provenance")
        self.a, self.pins = _anchor(anchor_raw)
        self.anchor_bytes, self.provenance = anchor_raw, provenance
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self.documents, self.document_stack, self.chunks = {}, set(), {}
        self.identities = {}
        self.document_bytes, self._started, self._snapshot = 0, False, None

    def transcript(self):
        return self.reader.transcript()

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed general attestation capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
        except MuseumError:
            raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError, notarization.NotarizationError) as exc:
            raise MuseumError("malformed general attestation evidence") from exc
        return self._snapshot

    def _bindings(self):
        a = self.a
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]),
            "general attestation chain differs")
        self._block()
        for address, digest in sorted(self.pins.items()):
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "general attestation runtime differs")
        getters = (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore"),
                   ("metadata", "metadataAuthority"), ("artistRegistry", "artistRegistry"),
                   ("artistAttribution", "artistAttribution"))
        for key, getter in getters:
            _, (actual,) = self._read(a["host"], getter + "()", outputs=("address",))
            require(actual == a[key], "general attestation dependency differs")
            _, (saved,) = self._read(a["host"], getter + "CodeHash()", outputs=("bytes32",))
            require(saved == self.pins[a[key]], "general attestation constructor pin differs")
        _, (store,) = self._read(a["schemas"], "chunkStore()", outputs=("address",))
        require(store == a["store"], "general attestation schema store differs")
        for getter, expected in (("streamModuleType()", schema_id("GENERAL_ATTESTATIONS")),
                                 ("streamModuleVersion()", schema_id("6529stream.general-attestations.v1"))):
            _, (actual,) = self._read(a["host"], getter, outputs=("bytes32",))
            require(actual == expected, "general attestation module identity differs")
        _, (exists,) = self._read(a["core"], "collectionExists(uint256)", ("uint256",),
            (uint(a["collectionId"]),), ("bool",))
        require(exists, "general attestation collection missing")
        catalogue = []
        for identifier, name in sorted(TYPES.items()):
            _, (classification,) = self._read(a["host"], "verificationClass(bytes32)", ("bytes32",),
                (identifier,), ("uint8",))
            _, policy = self._read(a["host"], "operatorPolicy(bytes32)", ("bytes32",),
                (identifier,), ("bytes32", "uint16"))
            expected_class = 2 if identifier == CURATORIAL else 1
            expected_policy = (CURATOR_FAMILY, 1 << 3) if identifier == CURATORIAL else (ZERO, 0)
            require(classification == expected_class and policy == expected_policy,
                "general attestation fixed type catalogue differs")
            catalogue.append({"recordType": identifier, "name": name,
                "verificationClass": "OPERATOR_ASSERTED" if classification == 2 else "SIGNER_VERIFIED"})
        return catalogue

    def _subject(self, value, digest):
        if value[3] == ARTIST:
            return None
        _, (subject,) = self._read(self.a["host"], "recordSubject(bytes32)", ("bytes32",), (digest,), (SUBJECT,))
        kind, collection, token, object_id = subject
        require(collection == uint(self.a["collectionId"]) and kind in (0, 1, 2),
            "general attestation subject scope differs")
        if kind == 0:
            require(token == 0 and object_id == ZERO, "general attestation collection subject differs")
        elif kind == 1:
            require(token > 0 and object_id == ZERO, "general attestation token subject differs")
        else:
            require(token == 0 and object_id != ZERO, "general attestation media subject differs")
        expected = subject_id(("collection", "token", "media")[kind], self.a["chainId"], self.a["core"],
            self.a["collectionId"], token_id=str(token), object_id=object_id)
        require(value[2] == expected, "general attestation subject preimage differs")
        return subject

    def _artist(self, value, receipt, evidence):
        require(0 < len(evidence) <= 24575 and keccak256(evidence) == receipt[22],
            "general attestation native Artist proof hash differs")
        proof, = decode((ARTIST_PROOF,), evidence, maximum=32768)
        registry, registry_hash, attribution, attribution_hash, _, native_receipt, terms, record, association, authority, nonce = proof
        require(registry == self.a["artistRegistry"] and registry_hash == self.pins[registry]
            and attribution == self.a["artistAttribution"] and attribution_hash == self.pins[attribution],
            "general attestation native Artist dependency differs")
        require(native_receipt[0] == 24 and native_receipt[1] != ZERO and native_receipt[2] == value[1]
            and native_receipt[3] == value[10] and record[0] == value[10] and record[2] == value[5]
            and record[3] == value[8] and record[4] > 0 and 0 < record[5] <= receipt[3]
            and record[6] == value[0] and terms == (value[1], terms[1], value[2], record[1], value[5], value[8], value[7]),
            "general attestation native Artist original differs")
        require(association[0] == native_receipt[1] and association[1] != ZERO
            and association[2] == record[4] and association[4][0] != ZERO_ADDRESS
            and association[4][1] != ZERO and association[4][2] == value[2]
            and association[4][3] == record[1] and 1 <= authority <= 4
            and (authority == 2) == (association[3] != ZERO), "general attestation native Artist association differs")
        require(artist_authorization_hash(uint(self.a["chainId"]), self.a["core"], proof) == value[10]
            and receipt[18] == registry and receipt[19] == registry_hash and receipt[20] == association[0]
            and receipt[22] == keccak256(evidence) and receipt[23] == authority,
            "general attestation native Artist receipt differs")
        return {"registry": registry, "attribution": attribution, "nativeReceiptIndex": str(proof[4]),
            "nativeReceipt": json_values(native_receipt), "terms": json_values(terms), "record": json_values(record),
            "association": json_values(association), "authorityClass": str(authority), "nonce": str(nonce)}

    def _identity_evidence(self, artist_id, historical_hash):
        key = (artist_id, historical_hash)
        if key in self.identities:
            return self.identities[key]
        registry = self.a["artistRegistry"]
        _, (historical,) = self._read(registry, "identityDocumentBytes(bytes32)",
            ("bytes32",), (historical_hash,), ("bytes",), maximum=16384)
        require(0 < len(historical) <= 8192 and keccak256(historical) == historical_hash,
            "general attestation historical identity document differs")
        _, (current_hash,) = self._read(registry, "operativeIdentityRecord(bytes32)",
            ("bytes32",), (artist_id,), ("bytes32",))
        require(current_hash != ZERO, "general attestation current operative identity missing")
        _, (current,) = self._read(registry, "identityRecordBytes(bytes32)",
            ("bytes32",), (artist_id,), ("bytes",), maximum=16384)
        _, (current_by_hash,) = self._read(registry, "identityDocumentBytes(bytes32)",
            ("bytes32",), (current_hash,), ("bytes",), maximum=16384)
        _, (identity,) = self._read(registry, "identity(bytes32)", ("bytes32",), (artist_id,), (IDENTITY,))
        require(0 < len(current) <= 8192 and current == current_by_hash and keccak256(current) == current_hash
            and identity[0] != ZERO_ADDRESS and identity[1] in (1, 3, 4) and 1 <= identity[2] <= 4
            and 0 < identity[3] <= identity[4] <= uint(self.a["timestamp"]) and identity[5] != ZERO,
            "general attestation current identity observation differs")
        result = {"artistId": artist_id, "registry": registry,
            "historicalOperativeIdentityRecordHash": historical_hash,
            "historicalDocumentHex": "0x" + historical.hex(),
            "currentOperativeIdentityRecordHash": current_hash,
            "currentDocumentHex": "0x" + current.hex(), "currentIdentity": json_values(identity),
            "currentDiffersFromHistorical": current_hash != historical_hash,
            "qualification": "Same-block current rotation/status is observational and never rewrites the historical notarization."}
        self.identities[key] = result
        return result

    def _verify(self, lane_type, digest, index, previous, latest, used_nonces,
                value, receipt, payload, bundle, evidence):
        encode((ATTESTATION, RECEIPT), (value, receipt))
        chain, collection, timestamp = uint(self.a["chainId"]), uint(self.a["collectionId"]), uint(self.a["timestamp"])
        require(value[0] != ZERO_ADDRESS and value[1] == collection and value[2] != ZERO
            and value[3] == lane_type and value[3] in TYPES
            and value[5] != ZERO and value[6] != ZERO and value[8] == keccak256(payload)
            and value[11] > 0 and 0 < len(payload) <= 8192 and receipt[0] != ZERO_ADDRESS
            and 0 < receipt[3] <= timestamp and receipt[4] == index and receipt[5] == chain_hash(collection, value[3], previous, digest, index)
            and receipt[8] >= receipt[3] and receipt[11] != ZERO and receipt[12] != ZERO,
            "general attestation original wire differs")
        _safe_text(value[4], 2048, "general attestation DID")
        _safe_text(value[7], 2048, "general attestation statement URI", uri=True)
        require(native_record_hash(chain, self.a["host"], value, receipt) == digest,
            "general attestation record hash differs")
        key = (value[2], receipt[0])
        require(value[9] == latest.get(key, ZERO), "general attestation supersession differs")
        latest[key] = digest
        self._document(value[5], 0, receipt[11])
        self._document(value[6], 1, receipt[12])
        signed = value[3] != CURATORIAL
        if signed:
            require(receipt[0] == value[0] and receipt[1] == 1 and receipt[9] in (EIP712, ERC1271)
                and receipt[10] != ZERO and receipt[14:18] == (ZERO, 0, 0, 0)
                and 0 < len(bundle) <= 8192 and keccak256(bundle) == receipt[10],
                "general attestation signer receipt differs")
            saved_domain, words, signature = decode(("bytes32", ("bytes32",) * 15, "bytes"), bundle, maximum=8192)
            body = signed_words(value, payload, receipt)
            require(saved_domain == domain(chain, self.a["host"]) and encode(("bytes32",) * 15, words) == body
                and receipt[6] == keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(body)))
                and len(signature) <= 4096
                and (receipt[9] != EIP712 or len(signature) in (64, 65)),
                "general attestation original signature preimage differs")
        else:
            require(bundle == b"" and receipt[1:3] == (2, 2) and receipt[6] == ZERO and receipt[9] == ZERO
                and receipt[10] == ZERO and receipt[14] == CURATOR_FAMILY and receipt[15] == 3
                and receipt[16] == collection and receipt[17] > 0 and receipt[13] == ZERO
                and receipt[18] == ZERO_ADDRESS and receipt[19:24] == (ZERO, ZERO, ZERO, ZERO, 0),
                "general attestation configured operator receipt differs")
        interpretation = {"verificationClass": "SIGNER_VERIFIED" if signed else "OPERATOR_ASSERTED",
            "authorityQualification": ("NATIVE_ARTIST_HISTORY" if value[3] == ARTIST else
                "GENERAL_SIGNER_CLAIM" if signed else "CONFIGURED_OPERATOR_CLAIM"),
            "accountSignatureProvenByHistoricalReceipt": signed, "currentAuthorityRevalidated": False}
        typed, artist, identity_evidence = None, None, None
        if value[3] == ARTIST:
            require(value[5] != SCHEMA_ID and receipt[2] == 3 and value[10] != ZERO
                and receipt[13:18] == (ZERO, ZERO, 0, 0, 0)
                and receipt[18] != ZERO_ADDRESS and receipt[20] != ZERO and receipt[21] == ZERO,
                "general attestation Artist classification differs")
            artist = self._artist(value, receipt, evidence)
        else:
            require(evidence == b"" and value[10] == ZERO, "general attestation unexpected Artist proof")
            if signed:
                require(receipt[2] == 1, "general attestation signer qualification differs")
            if value[5] == SCHEMA_ID:
                require(value[3] in (INSTITUTIONAL, ESTATE) and value[6] == JCS_ID
                    and receipt[13] == notarization.PROFILE_HASH and receipt[18] == self.a["artistRegistry"]
                    and receipt[14:18] == (ZERO, 0, 0, 0)
                    and receipt[19] == self.pins[self.a["artistRegistry"]] and receipt[20] != ZERO
                    and receipt[21] != ZERO and receipt[22:24] == (ZERO, 0),
                    "general attestation typed notarization receipt differs")
                self._document(PROFILE_ID, 2, notarization.PROFILE_HASH)
                require(self.documents[SCHEMA_ID][1] == notarization.SCHEMA_BYTES
                    and self.documents[PROFILE_ID][1] == notarization.PROFILE_BYTES
                    and self.documents[JCS_ID][1] == JCS_BYTES
                    and all(self.documents[identifier][2][3][3] == RAW_BYTES
                        and self.documents[identifier][2][3][4] == ZERO
                        for identifier in (SCHEMA_ID, PROFILE_ID, JCS_ID)),
                    "general attestation typed definitions differ")
                typed = notarization.validate(payload, artist_id=receipt[20],
                    operative_identity_record_hash=receipt[21])
                identity_evidence = self._identity_evidence(receipt[20], receipt[21])
            else:
                require(receipt[13] == ZERO and receipt[18] == ZERO_ADDRESS and receipt[19:24] == (ZERO, ZERO, ZERO, ZERO, 0),
                    "general attestation untyped identity fields differ")
        nonce_key = (receipt[0], receipt[7])
        require(nonce_key not in used_nonces, "general attestation reused accepted nonce")
        used_nonces.add(nonce_key)
        _, (used,) = self._read(self.a["host"], "isAttesterNonceUsed(address,uint256)",
            ("address", "uint256"), (receipt[0], receipt[7]), ("bool",))
        require(used, "general attestation accepted nonce missing")
        return interpretation, typed, artist, identity_evidence

    def _capture(self):
        a, records, lanes, seen, used_nonces = self.a, [], [], set(), set()
        catalogue = self._bindings()
        expected_pointers = {}
        for record_type, name in sorted(TYPES.items()):
            _, (head, count) = self._read(a["host"], "recordChainHash(uint256,bytes32)",
                ("uint256", "bytes32"), (uint(a["collectionId"]), record_type), ("bytes32", "uint64"))
            require(count <= MAX_RECORDS - len(records), "general attestation record bound")
            previous, latest, hashes, last_time = ZERO, {}, [], 0
            for index in range(count):
                _, (digest,) = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)",
                    ("uint256", "bytes32", "uint256"), (uint(a["collectionId"]), record_type, index), ("bytes32",))
                require(digest != ZERO and digest not in seen, "general attestation duplicate/missing record")
                _, (value, receipt) = self._read(a["host"], "attestation(bytes32)", ("bytes32",),
                    (digest,), (ATTESTATION, RECEIPT))
                _, (payload_pointer, payload) = self._read(a["host"], "recordPayload(bytes32)", ("bytes32",),
                    (digest,), ("address", "bytes"))
                _, (signature_pointer, bundle) = self._read(a["host"], "recordSignatureBundle(bytes32)",
                    ("bytes32",), (digest,), ("address", "bytes"))
                _, (evidence,) = self._read(a["host"], "recordArtistEvidence(bytes32)", ("bytes32",),
                    (digest,), ("bytes",), maximum=32768)
                subject = self._subject(value, digest)
                interpretation, typed, artist, identity_evidence = self._verify(record_type, digest, index, previous, latest,
                    used_nonces, value, receipt, payload, bundle, evidence)
                require(receipt[3] >= last_time, "general attestation lane publication time differs")
                require(self._chunk(value[8], payload_pointer) == payload,
                    "general attestation payload pointer differs")
                payload_key = (FAMILY, value[8])
                require(payload_key not in expected_pointers or expected_pointers[payload_key] == payload_pointer,
                    "general attestation repeated payload pointer differs")
                expected_pointers[payload_key] = payload_pointer
                if bundle:
                    require(signature_pointer != ZERO_ADDRESS and self._chunk(receipt[10], signature_pointer) == bundle,
                        "general attestation signature pointer differs")
                    signature_key = (BUNDLE_FAMILY, receipt[10])
                    require(signature_key not in expected_pointers or expected_pointers[signature_key] == signature_pointer,
                        "general attestation repeated signature pointer differs")
                    expected_pointers[signature_key] = signature_pointer
                else:
                    require(signature_pointer == ZERO_ADDRESS, "general attestation empty signature pointer differs")
                records.append({"recordHash": digest, "value": json_values(value), "receipt": json_values(receipt),
                    "payloadHex": "0x" + payload.hex(), "signatureBundleHex": "0x" + bundle.hex(),
                    "nativeArtistEvidenceHex": "0x" + evidence.hex(),
                    "subject": None if subject is None else json_values(subject), "interpretation": interpretation,
                    "qualification": QUALIFICATION, "notarization": typed, "identityEvidence": identity_evidence,
                    "nativeArtistProof": artist})
                seen.add(digest); hashes.append(digest); previous, last_time = receipt[5], receipt[3]
            require(previous == head, "general attestation complete lane head differs")
            for (subject_id_, recorder), expected in sorted(latest.items()):
                _, (actual,) = self._read(a["host"], "latestAttestationHashFor(uint256,bytes32,bytes32,address)",
                    ("uint256", "bytes32", "bytes32", "address"),
                    (uint(a["collectionId"]), record_type, subject_id_, recorder), ("bytes32",))
                require(actual == expected, "general attestation per-recorder latest differs")
            lanes.append({"recordType": record_type, "name": name, "count": str(count), "head": head,
                "records": hashes, "state": "authenticated_empty" if count == 0 else "complete_history"})
        _, (pointer_count,) = self._read(a["host"], "payloadPointerCount(uint256)", ("uint256",),
            (uint(a["collectionId"]),), ("uint256",))
        require(pointer_count <= MAX_RECORDS * 2, "general attestation pointer bound")
        pointers, observed = [], {}
        for index in range(pointer_count):
            _, (pointer, family, digest) = self._read(a["host"], "payloadPointerAt(uint256,uint256)",
                ("uint256", "uint256"), (uint(a["collectionId"]), index), ("address", "bytes32", "bytes32"))
            key = (family, digest)
            require(key in expected_pointers and key not in observed and expected_pointers[key] == pointer,
                "general attestation pointer inventory differs")
            observed[key] = pointer
            pointers.append({"index": str(index), "pointer": pointer, "family": family, "contentHash": digest})
        require(observed == expected_pointers, "general attestation pointer inventory incomplete")
        self._block()
        consistent_reads([self.transcript()])
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "caller_admitted_rpc_general_attestations" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "provenanceDeclaredByCaller": True, "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.transcript()),
            "sourceState": {key: a[key] for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber")},
            "host": a["host"], "catalogue": catalogue, "lanes": lanes, "records": records,
            "payloadPointers": pointers,
            "documents": [{"documentId": key, "view": json_values(view), "payloadHex": "0x" + payload.hex()}
                for key, (_, payload, view) in sorted(self.documents.items())],
            "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_SNAPSHOT, "general attestation snapshot bound")
        return result
