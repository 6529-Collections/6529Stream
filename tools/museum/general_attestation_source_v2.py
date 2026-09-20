"""Complete V2 GeneralAttestations reader with ordered payload chunk closure.

This is a prospective read profile.  It preserves the V1 native authority and
history checks while authenticating V2's larger generic payloads through both
the full-payload getter and every ordered SSTORE2 chunk descriptor.
"""

from . import general_attestation_source as v1
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import decode, encode
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values, require
from .owner_notice_semantics import consistent_reads
from tools.metadata import identity_notarization_profile as notarization


PROFILE = "STREAM_MUSEUM_GENERAL_ATTESTATION_SOURCE_V2"
MODULE_VERSION = schema_id("6529stream.general-attestations.v2")
MODULE_SCHEMA_HASH = MODULE_VERSION
BASE_INTERFACE_ID = "0xb4afac56"
PAYLOAD_CHUNKS_INTERFACE_ID = "0xc637353c"
MAX_PAYLOAD = 24576
MAX_CHUNKS = 3
CHUNK_BYTES = 8192
MAX_SNAPSHOT = v1.MAX_SNAPSHOT

QUALIFICATION = (
    "Complete fixed native V2 GeneralAttestations lanes for one collection at a caller-admitted pinned block. "
    "Original attestation, receipt, full payload, ordered payload chunks, signature bundle, native Artist proof "
    "and registered definitions are retained. SIGNER_VERIFIED authenticates an account signature; "
    "OPERATOR_ASSERTED authenticates a historical configured writer; neither proves legal personhood, "
    "institution identity, truth, reviewer independence, consensus, or current authority."
)
CLAIMS = dict(v1.CLAIMS, orderedPayloadChunkClosureComplete=True)
PROFILE_BYTES = dumps({"name": PROFILE, "version": "2", "status": "prospective_unregistered_read_profile",
    "scope": "all four natively admissible V2 GeneralAttestations types for one nonzero collection",
    "types": list(v1.TYPE_NAMES), "bounds": {"types": str(v1.MAX_TYPES), "records": str(v1.MAX_RECORDS),
        "genericPayloadBytes": str(MAX_PAYLOAD), "typedOrNativeArtistPayloadBytes": str(CHUNK_BYTES),
        "payloadChunks": str(MAX_CHUNKS), "payloadChunkBytes": str(CHUNK_BYTES),
        "signatureBytes": "4096", "snapshotBytes": str(MAX_SNAPSHOT)},
    "interfaces": {"base": BASE_INTERFACE_ID, "payloadChunks": PAYLOAD_CHUNKS_INTERFACE_ID},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _anchor(raw):
    value = loads(raw, maximum=524288, canonical=True)
    fields = {"profile", "chainId", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment",
        "deploymentEvidenceHash", "host", "core", "schemas", "store", "metadata", "artistRegistry",
        "artistAttribution", "codePins", "collectionId"}
    require(type(value) is dict and set(value) == fields and value["profile"] == PROFILE
        and value["environment"] in ("local_evm_fixture", "public_chain"), "general attestation V2 anchor shape")
    for key in ("chainId", "blockNumber", "collectionId"):
        uint(value[key])
    uint(value["timestamp"], 64)
    require(uint(value["chainId"]) > 0 and uint(value["collectionId"]) > 0,
        "general attestation V2 source scope")
    for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
        require(any(hex_bytes(value[key], 32)), "general attestation V2 empty commitment")
    dependencies = ("host", "core", "schemas", "store", "metadata", "artistRegistry", "artistAttribution")
    for key in dependencies:
        require(any(hex_bytes(value[key], 20)), "general attestation V2 dependency address")
    require(type(value["codePins"]) is list and 7 <= len(value["codePins"]) <= 64,
        "general attestation V2 code pin bound")
    pins = {}
    for row in value["codePins"]:
        require(type(row) is dict and set(row) == {"address", "runtimeHash"}
            and any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
            and row["address"] not in pins, "general attestation V2 code pin shape")
        pins[row["address"]] = row["runtimeHash"]
    require(all(value[key] in pins for key in dependencies), "general attestation V2 missing dependency pin")
    return value, pins


class GeneralAttestationSourceV2(v1.GeneralAttestationSource):
    """Read an exact V2 host; failed V2 reads never fall back to V1."""

    def __init__(self, anchor_raw, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc")
            and (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)),
            "general attestation V2 provenance")
        self.a, self.pins = _anchor(anchor_raw)
        self.anchor_bytes, self.provenance = anchor_raw, provenance
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self.documents, self.document_stack, self.chunks = {}, set(), {}
        self.identities = {}
        self.document_bytes, self._started, self._snapshot = 0, False, None

    def _bindings(self):
        a = self.a
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]),
            "general attestation V2 chain differs")
        self._block()
        for address, digest in sorted(self.pins.items()):
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest,
                "general attestation V2 runtime differs")
        getters = (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore"),
                   ("metadata", "metadataAuthority"), ("artistRegistry", "artistRegistry"),
                   ("artistAttribution", "artistAttribution"))
        for key, getter in getters:
            _, (actual,) = self._read(a["host"], getter + "()", outputs=("address",))
            require(actual == a[key], "general attestation V2 dependency differs")
            _, (saved,) = self._read(a["host"], getter + "CodeHash()", outputs=("bytes32",))
            require(saved == self.pins[a[key]], "general attestation V2 constructor pin differs")
        _, (store,) = self._read(a["schemas"], "chunkStore()", outputs=("address",))
        require(store == a["store"], "general attestation V2 schema store differs")
        for getter, expected in (("streamModuleType()", schema_id("GENERAL_ATTESTATIONS")),
                                 ("streamModuleVersion()", MODULE_VERSION),
                                 ("streamModuleSchemaHash()", MODULE_SCHEMA_HASH)):
            _, (actual,) = self._read(a["host"], getter, outputs=("bytes32",))
            require(actual == expected, "general attestation V2 module identity differs")
        for interface_id in (BASE_INTERFACE_ID, PAYLOAD_CHUNKS_INTERFACE_ID):
            _, (supported,) = self._read(a["host"], "supportsInterface(bytes4)", ("bytes4",),
                (interface_id,), ("bool",))
            require(supported, "general attestation V2 interface differs")
        _, (exists,) = self._read(a["core"], "collectionExists(uint256)", ("uint256",),
            (uint(a["collectionId"]),), ("bool",))
        require(exists, "general attestation V2 collection missing")
        catalogue = []
        for identifier, name in sorted(v1.TYPES.items()):
            _, (classification,) = self._read(a["host"], "verificationClass(bytes32)", ("bytes32",),
                (identifier,), ("uint8",))
            _, policy = self._read(a["host"], "operatorPolicy(bytes32)", ("bytes32",),
                (identifier,), ("bytes32", "uint16"))
            expected_class = 2 if identifier == v1.CURATORIAL else 1
            expected_policy = (v1.CURATOR_FAMILY, 1 << 3) if identifier == v1.CURATORIAL else (ZERO, 0)
            require(classification == expected_class and policy == expected_policy,
                "general attestation V2 fixed type catalogue differs")
            catalogue.append({"recordType": identifier, "name": name,
                "verificationClass": "OPERATOR_ASSERTED" if classification == 2 else "SIGNER_VERIFIED"})
        return catalogue

    def _verify(self, lane_type, digest, index, previous, latest, used_nonces,
                value, receipt, payload, bundle, evidence):
        encode((v1.ATTESTATION, v1.RECEIPT), (value, receipt))
        chain, collection, timestamp = uint(self.a["chainId"]), uint(self.a["collectionId"]), uint(self.a["timestamp"])
        typed_or_artist = value[3] == v1.ARTIST or value[5] == v1.SCHEMA_ID
        require(value[0] != ZERO_ADDRESS and value[1] == collection and value[2] != ZERO
            and value[3] == lane_type and value[3] in v1.TYPES
            and value[5] != ZERO and value[6] != ZERO and value[8] == keccak256(payload)
            and value[11] > 0 and 0 < len(payload) <= MAX_PAYLOAD
            and (not typed_or_artist or len(payload) <= CHUNK_BYTES) and receipt[0] != ZERO_ADDRESS
            and 0 < receipt[3] <= timestamp and receipt[4] == index
            and receipt[5] == v1.chain_hash(collection, value[3], previous, digest, index)
            and receipt[8] >= receipt[3] and receipt[11] != ZERO and receipt[12] != ZERO,
            "general attestation V2 original wire differs")
        v1._safe_text(value[4], 2048, "general attestation V2 DID")
        v1._safe_text(value[7], 2048, "general attestation V2 statement URI", uri=True)
        require(v1.native_record_hash(chain, self.a["host"], value, receipt) == digest,
            "general attestation V2 record hash differs")
        key = (value[2], receipt[0])
        require(value[9] == latest.get(key, ZERO), "general attestation V2 supersession differs")
        latest[key] = digest
        self._document(value[5], 0, receipt[11])
        self._document(value[6], 1, receipt[12])
        signed = value[3] != v1.CURATORIAL
        if signed:
            require(receipt[0] == value[0] and receipt[1] == 1 and receipt[9] in (v1.EIP712, v1.ERC1271)
                and receipt[10] != ZERO and receipt[14:18] == (ZERO, 0, 0, 0)
                and 0 < len(bundle) <= CHUNK_BYTES and keccak256(bundle) == receipt[10],
                "general attestation V2 signer receipt differs")
            saved_domain, words, signature = decode(("bytes32", ("bytes32",) * 15, "bytes"), bundle,
                maximum=CHUNK_BYTES)
            body = v1.signed_words(value, payload, receipt)
            require(saved_domain == v1.domain(chain, self.a["host"])
                and encode(("bytes32",) * 15, words) == body
                and receipt[6] == keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(body)))
                and len(signature) <= 4096 and (receipt[9] != v1.EIP712 or len(signature) in (64, 65)),
                "general attestation V2 original signature preimage differs")
        else:
            require(bundle == b"" and receipt[1:3] == (2, 2) and receipt[6] == ZERO and receipt[9] == ZERO
                and receipt[10] == ZERO and receipt[14] == v1.CURATOR_FAMILY and receipt[15] == 3
                and receipt[16] == collection and receipt[17] > 0 and receipt[13] == ZERO
                and receipt[18] == ZERO_ADDRESS and receipt[19:24] == (ZERO, ZERO, ZERO, ZERO, 0),
                "general attestation V2 configured operator receipt differs")
        interpretation = {"verificationClass": "SIGNER_VERIFIED" if signed else "OPERATOR_ASSERTED",
            "authorityQualification": ("NATIVE_ARTIST_HISTORY" if value[3] == v1.ARTIST else
                "GENERAL_SIGNER_CLAIM" if signed else "CONFIGURED_OPERATOR_CLAIM"),
            "accountSignatureProvenByHistoricalReceipt": signed, "currentAuthorityRevalidated": False}
        typed, artist, identity_evidence = None, None, None
        if value[3] == v1.ARTIST:
            require(value[5] != v1.SCHEMA_ID and receipt[2] == 3 and value[10] != ZERO
                and receipt[13:18] == (ZERO, ZERO, 0, 0, 0)
                and receipt[18] != ZERO_ADDRESS and receipt[20] != ZERO and receipt[21] == ZERO,
                "general attestation V2 Artist classification differs")
            artist = self._artist(value, receipt, evidence)
        else:
            require(evidence == b"" and value[10] == ZERO, "general attestation V2 unexpected Artist proof")
            if signed:
                require(receipt[2] == 1, "general attestation V2 signer qualification differs")
            if value[5] == v1.SCHEMA_ID:
                require(value[3] in (v1.INSTITUTIONAL, v1.ESTATE) and value[6] == v1.JCS_ID
                    and receipt[13] == notarization.PROFILE_HASH and receipt[18] == self.a["artistRegistry"]
                    and receipt[14:18] == (ZERO, 0, 0, 0)
                    and receipt[19] == self.pins[self.a["artistRegistry"]] and receipt[20] != ZERO
                    and receipt[21] != ZERO and receipt[22:24] == (ZERO, 0),
                    "general attestation V2 typed notarization receipt differs")
                self._document(v1.PROFILE_ID, 2, notarization.PROFILE_HASH)
                require(self.documents[v1.SCHEMA_ID][1] == notarization.SCHEMA_BYTES
                    and self.documents[v1.PROFILE_ID][1] == notarization.PROFILE_BYTES
                    and self.documents[v1.JCS_ID][1] == v1.JCS_BYTES
                    and all(self.documents[identifier][2][3][3] == RAW_BYTES
                        and self.documents[identifier][2][3][4] == ZERO
                        for identifier in (v1.SCHEMA_ID, v1.PROFILE_ID, v1.JCS_ID)),
                    "general attestation V2 typed definitions differ")
                typed = notarization.validate(payload, artist_id=receipt[20],
                    operative_identity_record_hash=receipt[21])
                identity_evidence = self._identity_evidence(receipt[20], receipt[21])
            else:
                require(receipt[13] == ZERO and receipt[18] == ZERO_ADDRESS
                    and receipt[19:24] == (ZERO, ZERO, ZERO, ZERO, 0),
                    "general attestation V2 untyped identity fields differ")
        nonce_key = (receipt[0], receipt[7])
        require(nonce_key not in used_nonces, "general attestation V2 reused accepted nonce")
        used_nonces.add(nonce_key)
        _, (used,) = self._read(self.a["host"], "isAttesterNonceUsed(address,uint256)",
            ("address", "uint256"), (receipt[0], receipt[7]), ("bool",))
        require(used, "general attestation V2 accepted nonce missing")
        return interpretation, typed, artist, identity_evidence

    def _payload(self, digest, expected_hash):
        _, (first_pointer, payload) = self._read(self.a["host"], "recordPayload(bytes32)",
            ("bytes32",), (digest,), ("address", "bytes"), maximum=32768)
        _, (content_hash, byte_length, chunk_count) = self._read(self.a["host"],
            "recordPayloadInfo(bytes32)", ("bytes32",), (digest,), ("bytes32", "uint32", "uint32"))
        require(content_hash == expected_hash and byte_length == len(payload)
            and 0 < byte_length <= MAX_PAYLOAD and chunk_count == (byte_length + CHUNK_BYTES - 1) // CHUNK_BYTES
            and 1 <= chunk_count <= MAX_CHUNKS and first_pointer != ZERO_ADDRESS,
            "general attestation V2 payload info differs")
        chunks, parts = [], []
        for index in range(chunk_count):
            _, (chunk_hash, pointer, length) = self._read(self.a["host"],
                "recordPayloadChunkAt(bytes32,uint256)", ("bytes32", "uint256"),
                (digest, index), ("bytes32", "address", "uint32"))
            require(chunk_hash != ZERO and pointer != ZERO_ADDRESS and 0 < length <= CHUNK_BYTES
                and (index == chunk_count - 1 or length == CHUNK_BYTES)
                and (index != 0 or pointer == first_pointer),
                "general attestation V2 payload chunk descriptor differs")
            part = self._chunk(chunk_hash, pointer)
            require(len(part) == length, "general attestation V2 payload chunk length differs")
            parts.append(part)
            chunks.append({"index": str(index), "chunkHash": chunk_hash,
                "pointer": pointer, "byteLength": str(length)})
        require(b"".join(parts) == payload and keccak256(payload) == content_hash,
            "general attestation V2 full payload differs")
        return payload, {"contentHash": content_hash, "byteLength": str(byte_length),
            "chunkCount": str(chunk_count), "firstChunkPointer": first_pointer}, chunks

    def _capture(self):
        a, records, lanes, seen, used_nonces = self.a, [], [], set(), set()
        catalogue = self._bindings()
        expected_pointers = {}
        for record_type, name in sorted(v1.TYPES.items()):
            _, (head, count) = self._read(a["host"], "recordChainHash(uint256,bytes32)",
                ("uint256", "bytes32"), (uint(a["collectionId"]), record_type), ("bytes32", "uint64"))
            require(count <= v1.MAX_RECORDS - len(records), "general attestation V2 record bound")
            previous, latest, hashes, last_time = ZERO, {}, [], 0
            for index in range(count):
                _, (digest,) = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)",
                    ("uint256", "bytes32", "uint256"), (uint(a["collectionId"]), record_type, index), ("bytes32",))
                require(digest != ZERO and digest not in seen, "general attestation V2 duplicate/missing record")
                _, (value, receipt) = self._read(a["host"], "attestation(bytes32)", ("bytes32",),
                    (digest,), (v1.ATTESTATION, v1.RECEIPT))
                payload, payload_info, payload_chunks = self._payload(digest, value[8])
                _, (signature_pointer, bundle) = self._read(a["host"], "recordSignatureBundle(bytes32)",
                    ("bytes32",), (digest,), ("address", "bytes"))
                _, (evidence,) = self._read(a["host"], "recordArtistEvidence(bytes32)", ("bytes32",),
                    (digest,), ("bytes",), maximum=32768)
                subject = self._subject(value, digest)
                interpretation, typed, artist, identity_evidence = self._verify(record_type, digest, index,
                    previous, latest, used_nonces, value, receipt, payload, bundle, evidence)
                require(receipt[3] >= last_time, "general attestation V2 lane publication time differs")
                for descriptor in payload_chunks:
                    key = (v1.FAMILY, descriptor["chunkHash"])
                    require(key not in expected_pointers or expected_pointers[key] == descriptor["pointer"],
                        "general attestation V2 repeated payload chunk pointer differs")
                    expected_pointers[key] = descriptor["pointer"]
                if bundle:
                    require(signature_pointer != ZERO_ADDRESS and self._chunk(receipt[10], signature_pointer) == bundle,
                        "general attestation V2 signature pointer differs")
                    signature_key = (v1.BUNDLE_FAMILY, receipt[10])
                    require(signature_key not in expected_pointers or expected_pointers[signature_key] == signature_pointer,
                        "general attestation V2 repeated signature pointer differs")
                    expected_pointers[signature_key] = signature_pointer
                else:
                    require(signature_pointer == ZERO_ADDRESS, "general attestation V2 empty signature pointer differs")
                records.append({"recordHash": digest, "value": json_values(value), "receipt": json_values(receipt),
                    "payloadHex": "0x" + payload.hex(), "payloadInfo": payload_info, "payloadChunks": payload_chunks,
                    "signatureBundleHex": "0x" + bundle.hex(), "nativeArtistEvidenceHex": "0x" + evidence.hex(),
                    "subject": None if subject is None else json_values(subject), "interpretation": interpretation,
                    "qualification": QUALIFICATION, "notarization": typed, "identityEvidence": identity_evidence,
                    "nativeArtistProof": artist})
                seen.add(digest); hashes.append(digest); previous, last_time = receipt[5], receipt[3]
            require(previous == head, "general attestation V2 complete lane head differs")
            for (subject_id_, recorder), expected in sorted(latest.items()):
                _, (actual,) = self._read(a["host"], "latestAttestationHashFor(uint256,bytes32,bytes32,address)",
                    ("uint256", "bytes32", "bytes32", "address"),
                    (uint(a["collectionId"]), record_type, subject_id_, recorder), ("bytes32",))
                require(actual == expected, "general attestation V2 per-recorder latest differs")
            lanes.append({"recordType": record_type, "name": name, "count": str(count), "head": head,
                "records": hashes, "state": "authenticated_empty" if count == 0 else "complete_history"})
        _, (pointer_count,) = self._read(a["host"], "payloadPointerCount(uint256)", ("uint256",),
            (uint(a["collectionId"]),), ("uint256",))
        require(pointer_count <= v1.MAX_RECORDS * (MAX_CHUNKS + 1), "general attestation V2 pointer bound")
        pointers, observed = [], {}
        for index in range(pointer_count):
            _, (pointer, family, digest) = self._read(a["host"], "payloadPointerAt(uint256,uint256)",
                ("uint256", "uint256"), (uint(a["collectionId"]), index), ("address", "bytes32", "bytes32"))
            key = (family, digest)
            require(key in expected_pointers and key not in observed and expected_pointers[key] == pointer,
                "general attestation V2 pointer inventory differs")
            observed[key] = pointer
            pointers.append({"index": str(index), "pointer": pointer, "family": family, "contentHash": digest})
        require(observed == expected_pointers, "general attestation V2 pointer inventory incomplete")
        self._block()
        consistent_reads([self.transcript()])
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "2",
            "mode": "caller_admitted_rpc_general_attestations_v2" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "provenanceDeclaredByCaller": True, "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.transcript()),
            "sourceState": {key: a[key] for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber")},
            "host": a["host"], "catalogue": catalogue, "lanes": lanes, "records": records,
            "payloadPointers": pointers,
            "documents": [{"documentId": key, "view": json_values(view), "payloadHex": "0x" + payload.hex()}
                for key, (_, payload, view) in sorted(self.documents.items())],
            "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_SNAPSHOT, "general attestation V2 snapshot bound")
        return result
