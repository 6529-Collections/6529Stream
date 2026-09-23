"""Pinned historical Metadata RIGHTS records; selected rows, never a current rights reducer."""
from types import MappingProxyType

import jsonschema
from tools.metadata import rights_profile as rights
from tools.metadata import work_profile as work
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import decode
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_source import IndependentSourceAdapter
from .independent_wire import RECORD, ZERO, ZERO_ADDRESS, generic_hash, json_values, require

PROFILE = "STREAM_MUSEUM_METADATA_RIGHTS_SOURCE_V1"
SCHEMA_NAME = "STREAM_RIGHTS_V1"
SCHEMA_BYTES = dumps(rights.schema())
PROFILE_NAME = "STREAM_RIGHTS_JSON_PROFILE_V1"
PROFILE_BYTES = dumps(rights.profile())
SCHEMA_HASH, PROFILE_HASH = keccak256(SCHEMA_BYTES), keccak256(PROFILE_BYTES)
JCS_ID = schema_id("RFC8785_JCS")
RECORD_TYPE = schema_id("RIGHTS_STATEMENT")
RECEIPT = ("uint256", "address", "uint8", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32")
POINTER = ("bytes32",) * 10  # Exact 320-byte facade record; inspect the same fixed words as the production reader.


def validate_rights(raw, expected_subject):
    """Complete original JSON meaning checks; this pure function confers no publication authority."""
    try:
        value = work._load(raw)
        jsonschema.Draft202012Validator(rights.schema()).validate(value)
        work._pattern_checks(value, rights.schema())
    except (work.WorkError, jsonschema.ValidationError) as exc:
        raise MuseumError("RIGHTS source interpretation rejected") from exc
    require(value["subjectId"] == expected_subject and value["profileHash"] == PROFILE_HASH,
            "RIGHTS subject/profile differs")
    dates = value["effectiveDates"]
    require(dates["end"] is None or dates["end"] >= dates["start"], "RIGHTS date order")
    instrument = value["instrument"]
    require(value["licensor"]["instrumentDigest"] == (None if instrument is None else instrument["hash"]["digest"]),
            "RIGHTS licensor instrument differs")
    return value


class MetadataRightsSource:
    """Exact one-block reads from externally pinned native owners and registered definitions.

    Original class 7/8 is read from its immutable receipt. Current family-writer
    memberships are not substituted for historical authorship. No transaction,
    signature, state-trie or legal-identity proof is invented by this reader.
    """
    _read = IndependentSourceAdapter._read
    _block = IndependentSourceAdapter._block
    _chunk = IndependentSourceAdapter._chunk
    _document = IndependentSourceAdapter._document

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
                (provenance != "trusted_rpc" or type(transport) in (ReplayTransport, RpcTransport)), "RIGHTS provenance")
        a = loads(anchor_bytes, maximum=524288, canonical=True)
        require(isinstance(a, dict) and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp",
            "stateRoot", "environment", "deploymentEvidenceHash", "host", "core", "schemas", "store", "codePins", "records"}
            and a["profile"] == PROFILE, "RIGHTS anchor shape")
        require(a["environment"] in ("local_evm_fixture", "public_chain"), "RIGHTS environment")
        for field in ("chainId", "blockNumber", "timestamp"): uint(a[field], 64 if field == "timestamp" else 256)
        for field in ("blockHash", "stateRoot", "deploymentEvidenceHash"): require(hex_bytes(a[field], 32) != bytes(32), "RIGHTS anchor commitment")
        for field in ("host", "core", "schemas", "store"): require(hex_bytes(a[field], 20) != bytes(20), "RIGHTS owner address")
        require(isinstance(a["codePins"], list) and 4 <= len(a["codePins"]) <= 64, "RIGHTS pin bounds")
        pins = {}
        for pin in a["codePins"]:
            require(isinstance(pin, dict) and set(pin) == {"address", "runtimeHash"}, "RIGHTS pin shape")
            hex_bytes(pin["address"], 20); require(hex_bytes(pin["runtimeHash"], 32) != bytes(32), "RIGHTS runtime hash")
            require(pin["address"] not in pins, "RIGHTS duplicate pin"); pins[pin["address"]] = pin["runtimeHash"]
        require(all(a[f] in pins for f in ("host", "core", "schemas", "store")), "RIGHTS missing pin")
        require(isinstance(a["records"], list) and 0 < len(a["records"]) <= 128, "RIGHTS selection bound")
        seen = set()
        for item in a["records"]:
            require(isinstance(item, dict) and set(item) == {"recordHash", "collectionId", "kind", "tokenId"}, "RIGHTS record selection")
            require(hex_bytes(item["recordHash"], 32) != bytes(32) and item["recordHash"] not in seen, "RIGHTS duplicate record")
            seen.add(item["recordHash"])
            require(uint(item["collectionId"]) > 0 and item["kind"] in ("collection", "token")
                and (uint(item["tokenId"]) > 0 if item["kind"] == "token" else item["tokenId"] == "0"), "RIGHTS scope selection")
        self.anchor_bytes, self.a, self.pins, self.provenance = anchor_bytes, a, pins, provenance
        self.reader = RecordingReader(transport, a["blockHash"])
        self.documents, self.document_stack, self.chunks = {}, set(), {}
        self.document_bytes, self._started, self._snapshot = 0, False, None
        self.records = MappingProxyType({})

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "RIGHTS failed capture cannot resume"); self._started = True
        a = self.a
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]), "RIGHTS chain mismatch")
        self._block()
        for address, digest in self.pins.items():
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "RIGHTS runtime differs")
        for key, getter in (("core", "core()"), ("schemas", "schemaRegistry()"), ("store", "chunkStore()")):
            _, (value,) = self._read(a["host"], getter, outputs=("address",))
            require(value == a[key], "RIGHTS host dependency differs")
        for key, getter in (("core", "coreCodeHash()"), ("schemas", "schemaRegistryCodeHash()"), ("store", "chunkStoreCodeHash()")):
            _, (value,) = self._read(a["host"], getter, outputs=("bytes32",))
            require(value == self.pins[a[key]], "RIGHTS saved runtime differs")
        _, (store,) = self._read(a["schemas"], "chunkStore()", outputs=("address",))
        require(store == a["store"], "RIGHTS schema store differs")
        module = schema_id("COLLECTION_METADATA")
        _, (pointer,) = self._read(a["core"], "getSatellitePointer(bytes32)", ("bytes32",), (module,), (POINTER,))
        require(pointer[0] == "0x" + "00" * 12 + a["host"][2:] and pointer[1] == self.pins[a["host"]] and pointer[3] == module and pointer[6] == "0x" + "00" * 31 + "01",
                "RIGHTS Metadata owner not selected at anchor")
        for name, kind, raw in ((SCHEMA_NAME, 0, SCHEMA_BYTES), (PROFILE_NAME, 2, PROFILE_BYTES)):
            self._document(schema_id(name), kind, keccak256(raw))
            require(self.documents[schema_id(name)][1] == raw and self.documents[schema_id(name)][2][3][3] == JCS_ID,
                    "RIGHTS registered interpretation bytes differ")
        require(self.documents[JCS_ID][1] == JCS_BYTES, "RIGHTS canonicalization bytes differ")
        records = {}
        for chosen in a["records"]:
            h, collection = chosen["recordHash"], uint(chosen["collectionId"])
            _, (record, receipt) = self._read(a["host"], "collectionRecord(bytes32)", ("bytes32",), (h,), (RECORD, RECEIPT))
            rt, sid, content, uri, schema, scheme, signature, effective = record
            expected = subject_id(chosen["kind"], a["chainId"], a["core"], chosen["collectionId"], token_id=chosen["tokenId"])
            require(receipt[0] == collection and receipt[1] != ZERO_ADDRESS and receipt[2] in (7, 8)
                and 0 < receipt[3] <= uint(a["timestamp"]) and receipt[8] == ZERO
                and receipt[6] == SCHEMA_HASH and receipt[7] == self.documents[JCS_ID][2][3][2]
                and rt == RECORD_TYPE and sid == expected and schema == schema_id(SCHEMA_NAME)
                and content[0] == 1 and len(content[1]) == 32 and content[2] == JCS_ID
                and scheme == ZERO and signature == (0, b"", ZERO) and effective > 0,
                "RIGHTS original receipt/family/subject/definition differs")
            require(generic_hash(uint(a["chainId"]), a["host"], a["core"], collection, receipt[1], record) == h,
                    "RIGHTS original record hash differs")
            _, (indexed,) = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)",
                ("uint256", "bytes32", "uint256"), (collection, rt, receipt[4]), ("bytes32",))
            require(indexed == h, "RIGHTS record index differs")
            previous = ZERO
            if receipt[4]:
                _, (prior,) = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)",
                    ("uint256", "bytes32", "uint256"), (collection, rt, receipt[4] - 1), ("bytes32",))
                _, (prior_record, prior_receipt) = self._read(a["host"], "collectionRecord(bytes32)", ("bytes32",), (prior,), (RECORD, RECEIPT))
                require(prior != ZERO and prior_receipt[0] == collection and prior_receipt[4] + 1 == receipt[4]
                    and prior_record[0] == rt and generic_hash(uint(a["chainId"]), a["host"], a["core"], collection, prior_receipt[1], prior_record) == prior,
                    "RIGHTS admitted immediate chain predecessor differs")
                previous = prior_receipt[5]
            require(record_chain(a["chainId"], a["host"], str(collection), rt, previous, h, str(receipt[4])) == receipt[5],
                    "RIGHTS receipt chain differs")
            payload = self._chunk("0x" + content[1].hex())
            value = validate_rights(payload, sid)
            records[h] = {"recordHash": h, "record": json_values(record), "receipt": json_values(receipt),
                "selection": chosen, "payloadHex": "0x" + payload.hex(), "value": value,
                "authority": {"mode": "historical_metadata_rights_receipt", "authorizationClass": str(receipt[2]),
                    "recorder": receipt[1], "artistAuthorization": receipt[8], "recordedAt": str(receipt[3]),
                    "currentSelectionProven": False, "legalOwnershipProven": False}}
        self._block()
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        self.records = MappingProxyType(records)
        self._snapshot = dumps({"profile": PROFILE, "version": "1", "mode": "recorded_state" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "records": list(records.values()), "documents": [{"documentId": k, "payloadHex": "0x" + raw.hex()} for k, (_, raw, _) in self.documents.items()],
            "claims": {"selectedHistoricalReceiptsChecked": True, "currentRightsSelection": False, "fullLaneHistory": False,
                "legalIdentityProven": False, "cryptographicStateProof": False, "institutionalAcceptance": False}})
        return self._snapshot