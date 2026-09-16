"""Synthetic native MetadataV1 controls; these fixtures are not chain evidence."""
from copy import deepcopy
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import calldata, encode
from .chain_rpc import ReplayTransport
from . import metadata_catalog_source as catalog


def H(label):
    return keccak256(str(label).encode())


def A(number):
    return "0x" + number.to_bytes(20, "big").hex()


class Transport:
    def __init__(self, responses):
        self.responses = responses

    def request(self, method, params):
        key = dumps([method, params])
        if key not in self.responses:
            raise MuseumError("unexpected synthetic metadata catalogue request")
        return deepcopy(self.responses[key])


def record_pair(*, rt=catalog.WORK, subject=None, recorder=A(8), auth=3, index=0,
                previous=catalog.ZERO, uri="ipfs://original", payload=b"same original payload", schema=None):
    subject = subject or subject_id("collection", "31337", A(2), "7")
    record = (rt, subject, (1, hex_bytes(keccak256(payload)), schema_id("RAW_BYTES")), uri,
        schema or schema_id("STREAM_WORK_DESCRIPTION_V1"), catalog.ZERO, (0, b"", catalog.ZERO), 99)
    digest = catalog.generic_hash(31337, A(1), A(2), 7, recorder, record)
    receipt = (7, recorder, auth, 100 + index, index,
        record_chain("31337", A(1), "7", rt, previous, digest, str(index)), H("historical-schema-definition"),
        H("historical-canon-definition"), H("authorization" + digest) if auth == 1 else catalog.ZERO)
    return digest, record, receipt, payload


class Fixture:
    def __init__(self, *, empty=False, no_types=False):
        self.responses = {}
        self.rights, self.empty, self.artist = H("CUSTOM_RIGHTS"), H("EMPTY_LANE"), schema_id("ARTIST_STATEMENT")
        self.policies = {catalog.WORK: (catalog.CURATOR, (1 << 1) | (1 << 3) | (1 << 8), True),
            self.rights: (schema_id("6529STREAM_RECORD_FAMILY_RIGHTS_V1"), (1 << 7) | (1 << 8), True),
            self.empty: (schema_id("6529STREAM_RECORD_FAMILY_ARCHIVE_V1"), 1 << 6, True),
            self.artist: (catalog.ARTIST, 1 << 1, True)} if not no_types else {}
        self.block = {"hash": H("block"), "number": "0x9", "timestamp": "0x70", "stateRoot": H("state")}
        runtimes = {A(i): b"\x60" + bytes([i]) for i in range(1, 6)}
        self.anchor = {"profile": catalog.PROFILE, "chainId": "31337", "blockHash": self.block["hash"],
            "blockNumber": "9", "timestamp": "112", "stateRoot": self.block["stateRoot"],
            "environment": "local_evm_fixture", "deploymentEvidenceHash": H("deployment"),
            "host": A(1), "core": A(2), "schemas": A(3), "store": A(4), "artistRegistry": A(5), "collectionId": "7",
            "codePins": [{"address": address, "runtimeHash": keccak256(raw)} for address, raw in runtimes.items()]}
        self.block_ref = {"blockHash": self.anchor["blockHash"], "requireCanonical": True}
        self.put("eth_chainId", [], "0x7a69")
        self.put("eth_getBlockByHash", [self.block["hash"], False], self.block)
        for address, raw in runtimes.items():
            self.put("eth_getCode", [address, self.block_ref], "0x" + raw.hex())
        for key, getter in (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore"), ("artistRegistry", "artistRegistry")):
            address = self.anchor[key]
            self.call(getter + "()", ("address",), (address,))
            self.call(getter + "CodeHash()", ("bytes32",), (keccak256(runtimes[address]),))
        self.call("chunkStore()", ("address",), (A(4),), target=A(3))
        self.call("streamModuleType()", ("bytes32",), (schema_id("COLLECTION_METADATA"),))
        self.call("streamModuleVersion()", ("bytes32",), (schema_id("6529stream.collection-metadata.full-bytes.v1"),))
        self.call("collectionExists(uint256)", ("bool",), (True,), ("uint256",), (7,), target=A(2))
        self.rows = []
        if not empty and not no_types:
            token = subject_id("token", "31337", A(2), "7", token_id="71")
            other = subject_id("token", "31337", A(2), "7", token_id="72")
            first = record_pair()
            second = record_pair(subject=token, index=1, previous=first[2][5])
            third = record_pair(subject=other, index=2, previous=second[2][5])
            fourth = record_pair(subject=token, index=3, previous=third[2][5], uri="ipfs://updated")
            fifth = record_pair(rt=self.rights, subject=other, auth=7, schema=H("rights-schema"))
            sixth = record_pair(rt=self.artist, auth=1, schema=schema_id("STREAM_ARTIST_STATEMENT_V1"))
            self.rows = [first, second, third, fourth, fifth, sixth]
        self.call("recordTypeCount()", ("uint256",), (len(self.policies),))
        for type_index, (rt, policy) in enumerate(self.policies.items()):
            self.call("recordTypeAt(uint256)", ("bytes32",), (rt,), ("uint256",), (type_index,))
            self.call("recordPolicy(bytes32)", (catalog.POLICY,), (policy,), ("bytes32",), (rt,))
            lane = [row for row in self.rows if row[1][0] == rt]
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (lane[-1][2][5] if lane else catalog.ZERO, len(lane)), ("uint256", "bytes32"), (7, rt))
            latest = {(row[1][1], row[2][1]): row[0] for row in lane}
            for (subject, recorder), digest in latest.items():
                self.call("latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)", ("bytes32",), (digest,),
                    ("uint256", "bytes32", "bytes32", "address"), (7, rt, subject, recorder))
        self.pointers = {}
        for row in self.rows:
            digest, record, receipt, payload = row
            self.record_response(row)
            self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
                ("uint256", "bytes32", "uint256"), (7, record[0], receipt[4]))
            self.call("recordPayload(bytes32)", ("address", "bytes"), (A(30), payload), ("bytes32",), (digest,))
            self.call("chunk(bytes32)", ("address", "uint32"), (A(30), len(payload)),
                ("bytes32",), (keccak256(payload),), target=A(4))
            self.put("eth_getCode", [A(30), self.block_ref], "0x00" + payload.hex())
            if receipt[8] != catalog.ZERO:
                self.call("consumedArtistAuthorization(bytes32)", ("bool",), (True,), ("bytes32",), (receipt[8],))
            self.pointers[(self.policies[record[0]][0], keccak256(payload))] = A(30)
        self.call("payloadPointerCount(uint256)", ("uint256",), (len(self.pointers),), ("uint256",), (7,))
        for index, ((family, digest), pointer) in enumerate(self.pointers.items()):
            self.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                (pointer, family, digest), ("uint256", "uint256"), (7, index))

    def put(self, method, params, result):
        self.responses[dumps([method, params])] = result

    def call(self, signature, outputs, result, kinds=(), values=(), target=A(1)):
        self.put("eth_call", [{"to": target, "data": calldata(signature, kinds, values), "gas": "0x1312d00"}, self.block_ref],
            "0x" + encode(outputs, result).hex())

    def record_response(self, row):
        digest, record, receipt, _ = row
        self.call("collectionRecord(bytes32)", (catalog.RECORD, catalog.RECEIPT), (record, receipt), ("bytes32",), (digest,))
        self.call("collectionRecordReceipt(bytes32)", (catalog.RECEIPT,), (receipt,), ("bytes32",), (digest,))

    def source(self, **kwargs):
        return catalog.MetadataCatalogSource(dumps(self.anchor), Transport(self.responses), **kwargs)


class NativeWireTests(unittest.TestCase):
    def verify(self, row, policy=(catalog.CURATOR, (1 << 1) | (1 << 3) | (1 << 8), True)):
        digest, record, receipt, payload = row
        catalog.verify_record(31337, A(1), A(2), 7, 112, digest, record[0], policy, 0, catalog.ZERO, record, receipt, payload)

    def test_native_direct_and_artist_work_paths(self):
        self.verify(record_pair())
        self.verify(record_pair(auth=1))
        for rt, schemas in catalog.ARTIST_SCHEMAS.items():
            if rt == catalog.WORK:
                continue
            for schema in schemas:
                self.verify(record_pair(rt=rt, auth=1, schema=schema), (catalog.ARTIST, 1 << 1, True))

    def test_native_payload_signature_schema_and_receipt_rejections(self):
        for change in ("empty", "large", "algorithm", "payload", "signature", "scheme", "work-schema", "effective",
                       "collection", "time", "index", "schema-hash", "canon-hash", "auth", "artist-proof"):
            digest, record, receipt, payload = record_pair()
            record, receipt = list(record), list(receipt)
            if change == "empty": payload = b""
            elif change == "large": payload = b"x" * 8193
            elif change == "algorithm": record[2] = (2, record[2][1], record[2][2])
            elif change == "payload": payload += b"edited"
            elif change == "signature": record[6] = (1, b"x" * 32, catalog.ZERO)
            elif change == "scheme": record[5] = H("scheme")
            elif change == "work-schema": record[4] = H("not-work-schema")
            elif change == "effective": record[7] = 0
            elif change == "collection": receipt[0] = 8
            elif change == "time": receipt[3] = 113
            elif change == "index": receipt[4] = 1
            elif change == "schema-hash": receipt[6] = catalog.ZERO
            elif change == "canon-hash": receipt[7] = catalog.ZERO
            elif change == "auth": receipt[2] = 5
            else: receipt[8] = H("unexpected-authorization")
            with self.subTest(change=change), self.assertRaises(MuseumError):
                self.verify((digest, tuple(record), tuple(receipt), payload))

    def test_native_uri_validation(self):
        for uri in ("", "https://host/path", "https://host/é", "ipfs://cid", "ar://data"):
            self.verify(record_pair(uri=uri))
        for uri in ("https://", "https:///path", "https://?x", "https://host/a b", "https://host/\x7f", "ipfs://", "ar://", "javascript:x", "x" * 2049):
            with self.subTest(uri=uri), self.assertRaisesRegex(MuseumError, "URI"):
                self.verify(record_pair(uri=uri))

    def test_policies_match_native_families_masks_and_work_exception(self):
        for family, classes in catalog.FAMILIES.items():
            catalog.validate_policy(H("custom"), (family, sum(1 << c for c in classes), True))
        catalog.validate_policy(catalog.WORK, (catalog.CURATOR, 1 << 1, True))
        for rt, policy in ((catalog.ZERO, (catalog.CURATOR, 8, True)), (H("custom"), (catalog.CURATOR, 2, True)),
                (catalog.WORK, (catalog.ARTIST, 2, True)), (H("custom"), (catalog.CURATOR, 0, True)),
                (H("custom"), (catalog.CURATOR, 8, False))):
            with self.assertRaises(MuseumError): catalog.validate_policy(rt, policy)
        for family in ("OWNER", "INDEPENDENT", "SNAPSHOT"):
            with self.assertRaises(MuseumError):
                catalog.validate_policy(H("custom"), (schema_id("6529STREAM_RECORD_FAMILY_" + family + "_V1"), 65535, True))


class CatalogueTests(unittest.TestCase):
    def test_all_subjects_whole_lane_heads_and_occurrences_preserved(self):
        f = Fixture(); source = f.source()
        with patch("socket.socket", side_effect=AssertionError("synthetic reader used network")):
            raw = source.snapshot()
        value = loads(raw, maximum=1048576, canonical=True)
        self.assertEqual(value["mode"], "synthetic_fixture")
        self.assertEqual(len(value["catalog"]), 4)
        self.assertEqual(len(value["lanes"]), 4)
        self.assertEqual([r["recordHash"] for r in value["records"]], [r[0] for r in f.rows])
        self.assertEqual(value["lanes"][0]["chainHash"], f.rows[3][2][5])
        self.assertEqual(value["lanes"][0]["count"], "4")
        self.assertEqual(len(value["lanes"][0]["latest"]), 3)
        self.assertIn({"subjectId": f.rows[3][1][1], "recorder": A(8), "recordHash": f.rows[3][0]}, value["lanes"][0]["latest"])
        self.assertEqual(sum(r["subjectKind"] == "collection" for r in value["records"]), 2)
        self.assertEqual(sum(r["subjectKind"] == "host_admitted_token_subject" for r in value["records"]), 4)
        self.assertEqual(len(value["payloadPointers"]), 3)
        self.assertEqual(len({r["pointer"] for r in value["payloadPointers"]}), 1)
        self.assertEqual(value["sourceState"], {k: f.anchor[k] for k in ("chainId", "core", "collectionId", "blockHash", "blockNumber")})
        for key in ("currentHostSelectionProven", "currentWriterPermissionsChecked", "tokenSubjectPreimagesResolved",
                    "actualChainAcceptance", "consensusProof", "fullObjectDossierConformance", "semanticPayloadValidation"):
            self.assertFalse(value["claims"][key])
        self.assertEqual(source.snapshot(), raw)
        transcript = source.transcript()
        replay = catalog.MetadataCatalogSource(dumps(f.anchor), ReplayTransport(transcript, keccak256(transcript)))
        self.assertEqual(replay.snapshot(), raw)

    def test_empty_admitted_lanes_and_no_types_are_native_empty_states(self):
        for no_types in (False, True):
            value = loads(Fixture(empty=True, no_types=no_types).source().snapshot(), maximum=1048576, canonical=True)
            self.assertEqual(value["records"], [])
            self.assertEqual(value["payloadPointers"], [])
            self.assertEqual(len(value["lanes"]), 0 if no_types else 4)
            self.assertTrue(all(row["status"] == "authenticated_empty" and row["count"] == "0"
                and row["chainHash"] == catalog.ZERO for row in value["lanes"]))

    def test_catalogue_duplicate_zero_unadmitted_and_bounds_refuse(self):
        for change in ("duplicate", "zero", "unadmitted", "types-bound", "records-bound"):
            f = Fixture()
            if change in ("duplicate", "zero"):
                f.call("recordTypeAt(uint256)", ("bytes32",), (catalog.WORK if change == "duplicate" else catalog.ZERO,), ("uint256",), (1,))
            elif change == "unadmitted":
                f.call("recordPolicy(bytes32)", (catalog.POLICY,), ((catalog.CURATOR, 8, False),), ("bytes32",), (catalog.WORK,))
            elif change == "types-bound": f.call("recordTypeCount()", ("uint256",), (catalog.MAX_TYPES + 1,))
            else: f.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (H("head"), catalog.MAX_RECORDS + 1), ("uint256", "bytes32"), (7, catalog.WORK))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.source().snapshot()

    def test_record_receipt_head_latest_and_artist_consumption_are_bound(self):
        for change in ("empty-head", "count", "duplicate", "latest", "fixed-receipt", "artist-consumed", "record"):
            f = Fixture(); digest, record, receipt, payload = f.rows[0]
            if change == "empty-head": f.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (H("nonempty"), 0), ("uint256", "bytes32"), (7, f.empty))
            elif change == "count": f.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (f.rows[3][2][5], 3), ("uint256", "bytes32"), (7, catalog.WORK))
            elif change == "duplicate": f.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
                ("uint256", "bytes32", "uint256"), (7, catalog.WORK, 1))
            elif change == "latest": f.call("latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)",
                ("bytes32",), (f.rows[1][0],), ("uint256", "bytes32", "bytes32", "address"), (7, catalog.WORK, f.rows[1][1][1], A(8)))
            elif change == "fixed-receipt": f.call("collectionRecordReceipt(bytes32)", (catalog.RECEIPT,),
                ((8, *receipt[1:]),), ("bytes32",), (digest,))
            elif change == "artist-consumed": f.call("consumedArtistAuthorization(bytes32)", ("bool",), (False,),
                ("bytes32",), (f.rows[-1][2][8],))
            else: f.record_response((digest, (*record[:3], "ipfs://edited", *record[4:]), receipt, payload))
            source = f.source()
            with self.subTest(change=change), self.assertRaises(MuseumError): source.snapshot()
            with self.assertRaisesRegex(MuseumError, "cannot resume"): source.snapshot()

    def test_pointer_catalogue_is_bijective_by_family_and_hash(self):
        for change in ("omitted", "duplicate", "foreign-family", "foreign-hash", "wrong-pointer", "code", "payload", "store"):
            f = Fixture(); digest = keccak256(f.rows[0][3])
            if change == "omitted": f.call("payloadPointerCount(uint256)", ("uint256",), (2,), ("uint256",), (7,))
            elif change in ("duplicate", "foreign-family", "foreign-hash", "wrong-pointer"):
                family = catalog.CURATOR if change == "duplicate" else H("unknown-family") if change == "foreign-family" else catalog.ARTIST
                f.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                    (A(31) if change == "wrong-pointer" else A(30), family, H("wrong") if change == "foreign-hash" else digest),
                    ("uint256", "uint256"), (7, 2))
            elif change == "code": f.put("eth_getCode", [A(30), f.block_ref], "0x00" + b"wrong".hex())
            elif change == "payload": f.call("recordPayload(bytes32)", ("address", "bytes"), (A(30), b"edited"), ("bytes32",), (f.rows[0][0],))
            else: f.call("chunk(bytes32)", ("address", "uint32"), (A(31), len(f.rows[0][3])), ("bytes32",), (digest,), target=A(4))
            with self.subTest(change=change), self.assertRaises(MuseumError): f.source().snapshot()

    def test_scope_zero_foreign_chain_missing_pins_and_anchor_changes_refuse(self):
        for change in ("zero", "chain", "collection", "pins", "code", "artist", "block"):
            f = Fixture()
            if change == "zero": f.anchor["collectionId"] = "0"
            elif change == "chain": f.put("eth_chainId", [], "0x1")
            elif change == "collection": f.call("collectionExists(uint256)", ("bool",), (False,), ("uint256",), (7,), target=A(2))
            elif change == "pins": f.anchor["codePins"].pop()
            elif change == "code": f.put("eth_getCode", [A(5), f.block_ref], "0x60ff")
            elif change == "artist": f.call("artistRegistryCodeHash()", ("bytes32",), (H("wrong"),))
            else: f.block["timestamp"] = "0x71"
            with self.subTest(change=change), self.assertRaises(MuseumError): f.source().snapshot()

    def test_entire_anchor_header_is_identical_after_capture(self):
        f = Fixture(); transport = Transport(f.responses); request = transport.request; blocks = 0
        def changing_request(method, params):
            nonlocal blocks
            value = request(method, params)
            if method == "eth_getBlockByHash":
                blocks += 1
                value["parentHash"] = H("parent" + str(blocks))
            return value
        transport.request = changing_request
        source = catalog.MetadataCatalogSource(dumps(f.anchor), transport)
        with self.assertRaisesRegex(MuseumError, "anchor changed"): source.snapshot()

    def test_replay_provenance_is_an_explicit_caller_declaration(self):
        f = Fixture()
        with self.assertRaisesRegex(MuseumError, "provenance"): f.source(provenance="trusted_rpc")
        source = f.source(); source.snapshot(); transcript = source.transcript()
        with self.assertRaises(MuseumError): ReplayTransport(transcript, H("wrong"))
        replay = catalog.MetadataCatalogSource(dumps(f.anchor), ReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
        value = loads(replay.snapshot(), maximum=1048576, canonical=True)
        self.assertEqual(value["mode"], "caller_admitted_rpc_metadata_catalogue")
        self.assertTrue(value["provenanceDeclaredByCaller"])
        self.assertFalse(value["claims"]["actualChainAcceptance"])

    def test_generator_and_guarded_offline_cli(self):
        f = Fixture(); source = f.source(); snapshot = source.snapshot(); transcript = source.transcript(); anchor = dumps(f.anchor)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.assertEqual(catalog.definitions(root), catalog.PROFILE_HASH)
            self.assertEqual(catalog.definitions(root, check=True), catalog.PROFILE_HASH)
            (root / "metadata-catalog-profile.json").write_bytes(b"{}")
            with self.assertRaises(MuseumError): catalog.definitions(root, check=True)
            (root / "anchor.json").write_bytes(anchor); (root / "transcript.json").write_bytes(transcript)
            argv = ["metadata-catalog", "replay", "--anchor", str(root / "anchor.json"), "--anchor-hash", keccak256(anchor),
                "--transcript", str(root / "transcript.json"), "--transcript-hash", keccak256(transcript), "--output", str(root / "result")]
            with patch("sys.argv", argv), patch("builtins.print"), patch("socket.socket", side_effect=AssertionError("offline CLI used network")):
                catalog.main()
                with self.assertRaises(FileExistsError): catalog.main()
            self.assertEqual((root / "result/snapshot.json").read_bytes(), snapshot)
            self.assertEqual((root / "result/transcript.json").read_bytes(), transcript)
            self.assertEqual((root / "result/anchor.json").read_bytes(), anchor)
            pins = loads((root / "result/pins.json").read_bytes(), canonical=True)
            self.assertEqual(pins["snapshotHash"], keccak256(snapshot))
            self.assertEqual(pins["provenance"], "synthetic_fixture")
            self.assertFalse(pins["actualChainAcceptance"])
            argv[argv.index("--anchor-hash") + 1] = H("wrong")
            with patch("sys.argv", argv), self.assertRaisesRegex(MuseumError, "anchor commitment"): catalog.main()

    def test_input_bound_and_output_parent_guard(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); (root / "large.bin").write_bytes(b"123")
            with self.assertRaisesRegex(MuseumError, "input file bound"): catalog._bounded_read(root / "large.bin", 2)
            with patch("pathlib.Path.is_symlink", return_value=True), self.assertRaisesRegex(MuseumError, "parent links"):
                catalog.write_capture(Fixture().source(), root / "output")
            self.assertFalse((root / "output").exists())


class SourceParityTests(unittest.TestCase):
    def test_native_metadata_abi_policy_and_receipt_layouts(self):
        root = Path(__file__).resolve().parents[2] / "smart-contracts"
        interface = (root / "interfaces/stream/metadata/IStreamCollectionMetadataV1.sol").read_text(encoding="utf-8")
        for name, expected in (("RecordPolicy", catalog.POLICY), ("RecordReceipt", catalog.RECEIPT)):
            body = re.search(r"struct " + name + r"\s*\{(.*?)\}", interface, re.S)[1]
            self.assertEqual(tuple(row.strip().split()[0] for row in body.split(";") if row.strip()), expected)
        self.assertNotIn("function recordSubject(", interface)
        source = (root / "domains/metadata/StreamCollectionMetadataV1.sol").read_text(encoding="utf-8")
        self.assertIn('keccak256("6529stream.collection-metadata.full-bytes.v1")', source)
        self.assertIn("collectionId == 0", source)
        self.assertIn("abi.encode(family, contentHash)", source)
        self.assertIn("abi.encode(collectionId, record.recordType, record.subjectId, receipt.recorder)", source)


if __name__ == "__main__":
    unittest.main()
