import unittest

from .account_profile import JCS_BYTES
from .archive_publication import (
    ARCHIVE_MASK, AUTHORITY_NAMES, EVENT_TOPIC, FAMILY, JCS, METADATA,
    RECORD_TYPE, configure_archive_lane, evidence_bytes, publish_archive_export,
    validate_manifest,
)
from .canonical import dumps, hex_bytes, keccak256, record_chain, schema_id, subject_id
from .chain_abi import encode
from .independent_wire import DOCUMENT, RECORD, ZERO, generic_hash
from .semantic_export import NAME as SCHEMA_NAME, POLICY_BYTES, POLICY_NAME, SCHEMA_BYTES
from .typed_authority_profile import NAMES as TYPED_NAMES


A = lambda n: "0x" + f"{n:040x}"
H = lambda n: "0x" + f"{n:064x}"
SUBJECT = subject_id("collection", "31337", A(2), "1")
def schema_bytes():
    return SCHEMA_BYTES


def manifest(subject=SUBJECT, record_heads=None):
    document = {"path": "component.json", "contentHash": {"algorithm": "1",
        "digest": H(9), "canonicalizationId": JCS}, "byteLength": "2",
        "mediaType": "application/json"}
    return dumps({
        "profileSchemaId": "0xfaee2f29c54d176f8f98707f5863507a334c47f3c554630cbaf4194acd46e088",
        "profileHash": H(1),
        "sourceState": {
            "chainId": "31337", "core": A(2), "collectionId": "1",
            "tokenId": None,
            "blockNumber": "100", "blockHash": H(100),
            "anchorSubject": {"kind": "collection", "subjectId": subject},
            "canonicalCitation": "", "finalityQualifier": "unfinalized_trusted_rpc_block",
            "recordHeads": [] if record_heads is None else record_heads,
            "disclosurePolicyHash": H(2),
        },
        "selectionPolicyHash": H(3),
        "components": {name: document for name in ("entityIndex", "assertions", "provenance",
            "authoritySnapshots", "dependencyLock", "coverage", "validation", "identityCorrespondence")},
        "authoritySelection": document, "resourceIndex": document,
        "exportPolicy": {"path": "definitions/" + POLICY_NAME + ".json",
            "contentHash": {"algorithm": "1", "digest": keccak256(POLICY_BYTES),
                "canonicalizationId": JCS}, "byteLength": str(len(POLICY_BYTES)),
            "mediaType": "application/json"},
        "completeness": "complete_for_profile",
        "conformance": {"streamProfile": "pass", "linkedArtModel": "pass", "linkedArtApi": "not_claimed"},
        "previousExport": None,
    })


def selector(record_type=H(8)):
    return {"recordHash": H(5), "subjectId": SUBJECT, "schemaId": H(6),
        "schemaHash": H(9), "recordType": record_type, "host": A(1),
        "recorder": A(6), "authorizationClass": "PRESERVATION_ADMIN",
        "pointer": "", "recordIndex": "0", "recordChainHash": H(10)}


class FakeFixture:
    def __init__(self):
        self.addresses = {METADATA: A(1), "StreamCore": A(2), "StreamSchemaRegistry": A(3)}
        self.receipts = []
        self.policy = (ZERO, 0, False)
        self.grants = {}
        self.schema = schema_bytes()
        self.schema_view = (True, 0, H(20), (SCHEMA_NAME, 0, keccak256(self.schema), JCS,
            schema_id(TYPED_NAMES[2]), "", len(self.schema)), (H(21), H(22)))
        self.policy_view = (True, 0, H(23), (POLICY_NAME, 2, keccak256(POLICY_BYTES), JCS,
            ZERO, "", len(POLICY_BYTES)), (H(24),))
        self.record = self.saved_receipt = self.record_hash = self.payload = None
        self.pointer = A(9)
        self.data_values = None
        self.last_data_function = None

    def rpc(self, method, params):
        if method == "eth_chainId": return "0x7a69"
        if method == "eth_getBlockByNumber":
            number = int(params[0], 16)
            return self.block(number)
        if method == "eth_getBlockByHash":
            return self.block(int(params[0], 16))
        if method == "eth_getCode":
            return "0x00" + self.payload.hex() if params[0] == self.pointer else "0x6000"
        if method == "eth_call":
            document_id = "0x" + params[0]["data"][-64:]
            view = self.schema_view if document_id == schema_id(SCHEMA_NAME) else self.policy_view
            return "0x" + encode((DOCUMENT,), (view,)).hex()
        raise AssertionError(method)

    def block(self, number):
        return {"number": hex(number), "hash": H(number), "parentHash": H(number - 1),
            "timestamp": hex(number), "stateRoot": H(number + 1000),
            "transactions": [H(90)] if number == 101 else []}

    def governed(self, name, function, values, transition):
        self.receipts.append({"transaction": {"data": function}, "transactionHash": H(len(self.receipts)+1),
                              "receipt": {"status": "0x1"}})
        if function == "admitRecordType": self.policy = (values[1], values[2], True)
        elif function == "setFamilyWriter": self.grants[values[:-1]] = (values[-1], 1)
        else: raise AssertionError(function)

    def call(self, name, function, values=()):
        if function in ("recordTypeTransition", "familyWriterTransition"):
            return (H(1), H(2), H(3))
        if function == "recordPolicy": return (self.policy,)
        if function == "familyWriter": return self.grants.get(values, (False, 0))
        if function == "documentBytes":
            if values[0] == schema_id(SCHEMA_NAME): return (self.schema,)
            if values[0] == schema_id(POLICY_NAME): return (POLICY_BYTES,)
            return (JCS_BYTES,)
        if function == "document":
            return (self.schema_view if values[0] == schema_id(SCHEMA_NAME) else self.policy_view,)
        if function == "deriveCollectionRecordHashFor":
            writer, collection, record = values
            return (generic_hash(31337, A(1), A(2), collection, writer, record),)
        if function == "collectionRecord": return self.record, self.saved_receipt
        if function == "recordPayload": return self.pointer, self.payload
        if function == "latestCollectionRecordHashFor": return (self.record_hash,)
        if function == "recordHashAt": return (self.record_hash,)
        if function == "recordChainHash":
            return (ZERO, 0) if self.saved_receipt is None else (self.saved_receipt[5], self.saved_receipt[4] + 1)
        raise AssertionError((name, function, values))

    def data(self, name, function, values=()):
        if function == "document":
            return "0x" + (b"doc!" + hex_bytes(values[0])).hex()
        self.data_values = values
        return "0x5e763983" + "00" * 4

    def safe_call(self, writer, host, data):
        collection, record, payload = self.data_values
        self.record, self.payload = record, payload
        self.record_hash = generic_hash(31337, host, A(2), collection, writer, record)
        chain = record_chain("31337", host, "1", RECORD_TYPE, ZERO, self.record_hash, "0")
        self.saved_receipt = (collection, writer, 6, 101, 0, chain,
                              keccak256(self.schema), keccak256(JCS_BYTES), ZERO)
        event_data = encode(
            (RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
            (record, self.record_hash, chain, writer, "0x" + (6).to_bytes(32, "big").hex(), 1),
        )
        receipt = {"status": "0x1", "blockNumber": "0x65", "blockHash": H(101),
                   "transactionIndex": "0x0",
                   "transactionHash": H(90),
                   "logs": [{"address": host, "topics": [EVENT_TOPIC, H(collection), RECORD_TYPE, record[1]],
                             "transactionHash": H(90), "transactionIndex": "0x0",
                             "data": "0x" + event_data.hex()}]}
        self.receipts.append({"transaction": {"to": host, "data": data},
                              "transactionHash": H(90), "receipt": receipt})
        return receipt


class ArchivePublicationTests(unittest.TestCase):
    def test_constants_are_the_existing_archive_lane(self):
        self.assertEqual(RECORD_TYPE, schema_id("ARCHIVE_SEMANTIC_EXPORT"))
        self.assertEqual(FAMILY, schema_id("6529STREAM_RECORD_FAMILY_ARCHIVE_V1"))
        self.assertEqual(ARCHIVE_MASK, 0x140)
        self.assertEqual(AUTHORITY_NAMES, {6: "PRESERVATION_ADMIN", 8: "GLOBAL_ADMIN"})

    def test_manifest_binds_exact_source_and_rejects_self_lane(self):
        raw, schema = manifest(), schema_bytes()
        value = validate_manifest(raw, schema, schema_name=SCHEMA_NAME,
            schema_hash=keccak256(schema), chain_id="0x7a69", core=A(2), collection_id=1,
            subject_id=SUBJECT, source_block_number=100, source_block_hash=H(100))
        self.assertEqual(value["sourceState"]["blockNumber"], "100")
        bad = manifest(record_heads=[selector(RECORD_TYPE)])
        with self.assertRaisesRegex(Exception, "cannot be a semantic-export source"):
            validate_manifest(bad, schema, schema_name=SCHEMA_NAME,
                schema_hash=keccak256(schema), chain_id=31337, core=A(2), collection_id=1,
                subject_id=SUBJECT, source_block_number=100, source_block_hash=H(100))

    def test_manifest_rejects_noncanonical_oversize_and_wrong_pin(self):
        schema = schema_bytes()
        with self.assertRaises(Exception):
            validate_manifest(b'{"z":0, "sourceState":{}}', schema, schema_name=SCHEMA_NAME,
                schema_hash=keccak256(schema), chain_id=31337, core=A(2), collection_id=1,
                subject_id=SUBJECT, source_block_number=100, source_block_hash=H(100))
        with self.assertRaisesRegex(Exception, "payload bound"):
            validate_manifest(b"x" * 8193, schema, schema_name=SCHEMA_NAME,
                schema_hash=keccak256(schema), chain_id=31337, core=A(2), collection_id=1,
                subject_id=SUBJECT, source_block_number=100, source_block_hash=H(100))
        with self.assertRaisesRegex(Exception, "schema pin"):
            validate_manifest(manifest(), schema, schema_name=SCHEMA_NAME,
                schema_hash=H(4), chain_id=31337, core=A(2), collection_id=1,
                subject_id=SUBJECT, source_block_number=100, source_block_hash=H(100))

    def test_configure_uses_governed_archive_admission_and_class_six_grant(self):
        f = FakeFixture()
        result = configure_archive_lane(f, A(6), 6)
        self.assertEqual(f.policy, (FAMILY, 0x140, True))
        self.assertEqual(f.grants[(1, FAMILY, 6, A(6))], (True, 1))
        self.assertEqual(result["authorizationClassName"], "PRESERVATION_ADMIN")
        self.assertEqual(len(result["admissionTransactions"]), 1)
        self.assertEqual(len(result["grantTransactions"]), 1)

    def test_configure_rejects_independent_and_metadata_classes(self):
        for cls in (5, 7):
            with self.subTest(cls=cls), self.assertRaisesRegex(Exception, "archive authorization"):
                configure_archive_lane(FakeFixture(), A(6), cls)

    def test_publish_retains_exact_transaction_event_receipt_payload_and_schema(self):
        f = FakeFixture()
        configure_archive_lane(f, A(6), 6)
        raw, schema = manifest(), schema_bytes()
        result = publish_archive_export(f, raw, schema, schema_name=SCHEMA_NAME,
            schema_hash=keccak256(schema), source_block_number=100, source_block_hash=H(100),
            subject_id=SUBJECT, writer=A(6), authorization_class=6, uri="urn:test:export",
            effective_at=101)
        self.assertEqual(result["payloadBytesHex"], "0x" + raw.hex())
        self.assertEqual(result["schemaBytesHex"], "0x" + schema.hex())
        self.assertEqual(result["recordReceipt"][2], "6")
        self.assertEqual(result["authorizationClassName"], "PRESERVATION_ADMIN")
        self.assertEqual(result["publicationEvent"]["topics"][0], EVENT_TOPIC)
        self.assertEqual(result["recordHash"], f.record_hash)
        self.assertEqual([row["hash"] for row in result["publicationAncestry"]], [H(101), H(100)])
        self.assertFalse(result["claims"]["collectionSnapshotPublished"])
        self.assertFalse(result["claims"]["independentAttestorLaneUsed"])
        self.assertEqual(dumps(result), evidence_bytes(result))

    def test_publish_rejects_receipt_authority_relabelling(self):
        class WrongClass(FakeFixture):
            def safe_call(self, writer, host, data):
                receipt = super().safe_call(writer, host, data)
                row = list(self.saved_receipt); row[2] = 8; self.saved_receipt = tuple(row)
                return receipt
        f = WrongClass(); configure_archive_lane(f, A(6), 6)
        schema = schema_bytes()
        with self.assertRaisesRegex(Exception, "receipt differs"):
            publish_archive_export(f, manifest(), schema, schema_name=SCHEMA_NAME,
                schema_hash=keccak256(schema), source_block_number=100, source_block_hash=H(100),
                subject_id=SUBJECT, writer=A(6), authorization_class=6, effective_at=101)


if __name__ == "__main__":
    unittest.main()
