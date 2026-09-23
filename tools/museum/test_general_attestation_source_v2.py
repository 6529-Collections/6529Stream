"""Synthetic V2 GeneralAttestations controls; never native-chain evidence."""

import copy
import unittest
from unittest.mock import patch

from . import general_attestation_source as v1
from . import general_attestation_source_v2 as source
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .chain_abi import decode, encode
from .chain_rpc import ReplayTransport
from .independent_wire import ZERO, ZERO_ADDRESS
from .test_general_attestation_source import Fixture as V1Fixture, Transport, a, decode_words, h


class Fixture(V1Fixture):
    """V2 synthetic host; supports an opt-in large generic payload and Artist join."""

    def __init__(self, *, generic_payload_bytes=23, artist_context=None):
        super().__init__(artist_context=artist_context)
        self.anchor["profile"] = source.PROFILE
        self.call("streamModuleVersion()", ("bytes32",), (source.MODULE_VERSION,))
        self.call("streamModuleSchemaHash()", ("bytes32",), (source.MODULE_SCHEMA_HASH,))
        for interface_id in (source.BASE_INTERFACE_ID, source.PAYLOAD_CHUNKS_INTERFACE_ID):
            self.call("supportsInterface(bytes4)", ("bool",), (True,), ("bytes4",), (interface_id,))
        if generic_payload_bytes is not None:
            payload = b"".join(bytes([65 + index]) * min(source.CHUNK_BYTES,
                max(0, generic_payload_bytes - index * source.CHUNK_BYTES))
                for index in range((generic_payload_bytes + source.CHUNK_BYTES - 1) // source.CHUNK_BYTES))
            self._replace_payload(2, payload)
        self.install_v2_state()

    def _replace_payload(self, row_index, payload):
        _, old_value, old_receipt, _, old_bundle, evidence, subject = self.rows[row_index]
        value, receipt = list(old_value), list(old_receipt)
        value[8] = keccak256(payload)
        receipt[4], receipt[5] = 0, ZERO
        bundle = old_bundle
        if value[3] != v1.CURATORIAL:
            receipt[6], receipt[10] = ZERO, ZERO
            _, _, signature = decode(("bytes32", ("bytes32",) * 15, "bytes"), old_bundle,
                                     maximum=v1.MAX_SNAPSHOT)
            body = v1.signed_words(tuple(value), payload, receipt)
            bundle = encode(("bytes32", ("bytes32",) * 15, "bytes"),
                (v1.domain(31337, self.host), decode_words(body), signature))
            receipt[6] = keccak256(b"\x19\x01" + bytes.fromhex(v1.domain(31337, self.host)[2:])
                + bytes.fromhex(keccak256(body)[2:]))
            receipt[10] = keccak256(bundle)
        digest = v1.native_record_hash(31337, self.host, tuple(value), tuple(receipt))
        lane = [row for row in self.rows[:row_index] if row[1][3] == value[3]]
        index = len(lane)
        previous = lane[-1][2][5] if lane else ZERO
        receipt[4] = index
        receipt[5] = v1.chain_hash(7, value[3], previous, digest, index)
        self.rows[row_index] = (digest, tuple(value), tuple(receipt), payload, bundle, evidence, subject)

    def _v2_chunk(self, raw):
        digest = keccak256(raw)
        if digest not in self.v2_store:
            self.v2_store[digest] = self.install_chunk(raw)[1]
        return digest, self.v2_store[digest]

    def install_v2_state(self):
        self.v2_store, self.descriptors, pointers = {}, {}, {}
        for record_type in v1.TYPES:
            lane = [row for row in self.rows if row[1][3] == record_type]
            head = lane[-1][2][5] if lane else ZERO
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"), (head, len(lane)),
                ("uint256", "bytes32"), (7, record_type))
            latest = {}
            for index, row in enumerate(lane):
                digest, value, receipt, payload, bundle, evidence, subject = row
                self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
                    ("uint256", "bytes32", "uint256"), (7, record_type, index))
                self.call("attestation(bytes32)", (v1.ATTESTATION, v1.RECEIPT), (value, receipt),
                    ("bytes32",), (digest,))
                descriptors = []
                for chunk_index in range((len(payload) + source.CHUNK_BYTES - 1) // source.CHUNK_BYTES):
                    part = payload[chunk_index * source.CHUNK_BYTES:(chunk_index + 1) * source.CHUNK_BYTES]
                    chunk_hash, pointer = self._v2_chunk(part)
                    descriptor = (chunk_hash, pointer, len(part))
                    descriptors.append(descriptor)
                    self.call("recordPayloadChunkAt(bytes32,uint256)", ("bytes32", "address", "uint32"),
                        descriptor, ("bytes32", "uint256"), (digest, chunk_index))
                    pointers[(v1.FAMILY, chunk_hash)] = pointer
                first_pointer = descriptors[0][1] if descriptors else ZERO_ADDRESS
                self.call("recordPayload(bytes32)", ("address", "bytes"), (first_pointer, payload),
                    ("bytes32",), (digest,))
                self.call("recordPayloadInfo(bytes32)", ("bytes32", "uint32", "uint32"),
                    (keccak256(payload), len(payload), len(descriptors)), ("bytes32",), (digest,))
                self.descriptors[digest] = descriptors
                if bundle:
                    bundle_hash, bundle_pointer = self._v2_chunk(bundle)
                    pointers[(v1.BUNDLE_FAMILY, bundle_hash)] = bundle_pointer
                else:
                    bundle_pointer = ZERO_ADDRESS
                self.call("recordSignatureBundle(bytes32)", ("address", "bytes"),
                    (bundle_pointer, bundle), ("bytes32",), (digest,))
                self.call("recordArtistEvidence(bytes32)", ("bytes",), (evidence,), ("bytes32",), (digest,))
                if record_type != v1.ARTIST:
                    self.call("recordSubject(bytes32)", (v1.SUBJECT,), (subject,), ("bytes32",), (digest,))
                self.call("isAttesterNonceUsed(address,uint256)", ("bool",), (True,),
                    ("address", "uint256"), (receipt[0], receipt[7]))
                latest[(value[2], receipt[0])] = digest
            for (subject_id_, recorder), digest in latest.items():
                self.call("latestAttestationHashFor(uint256,bytes32,bytes32,address)", ("bytes32",),
                    (digest,), ("uint256", "bytes32", "bytes32", "address"),
                    (7, record_type, subject_id_, recorder))
        self.call("payloadPointerCount(uint256)", ("uint256",), (len(pointers),), ("uint256",), (7,))
        for index, ((family, digest), pointer) in enumerate(pointers.items()):
            self.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                (pointer, family, digest), ("uint256", "uint256"), (7, index))
        self.pointers = pointers

    def descriptor(self, row_index, chunk_index, value):
        digest = self.rows[row_index][0]
        self.call("recordPayloadChunkAt(bytes32,uint256)", ("bytes32", "address", "uint32"), value,
            ("bytes32", "uint256"), (digest, chunk_index))

    def reader(self, **kwargs):
        return source.GeneralAttestationSourceV2(dumps(self.anchor), Transport(self.responses), **kwargs)


class GeneralAttestationSourceV2Tests(unittest.TestCase):
    def test_large_payload_shape_pointer_dedup_and_offline_replay(self):
        f = Fixture(generic_payload_bytes=24576)
        reader = f.reader()
        with patch("socket.socket", side_effect=AssertionError("synthetic reader used network")):
            raw = reader.snapshot()
        result = loads(raw, maximum=source.MAX_SNAPSHOT, canonical=True)
        row = next(item for item in result["records"] if item["value"][3] == v1.CURATORIAL)
        self.assertEqual(row["payloadInfo"], {"contentHash": row["value"][8], "byteLength": "24576",
            "chunkCount": "3", "firstChunkPointer": row["payloadChunks"][0]["pointer"]})
        self.assertEqual([chunk["index"] for chunk in row["payloadChunks"]], ["0", "1", "2"])
        self.assertEqual(len(bytes.fromhex(row["payloadHex"][2:])), 24576)
        self.assertTrue(result["claims"]["orderedPayloadChunkClosureComplete"])
        self.assertEqual(result["profileHash"], source.PROFILE_HASH)
        replay = source.GeneralAttestationSourceV2(dumps(f.anchor),
            ReplayTransport(reader.transcript(), keccak256(reader.transcript())))
        self.assertEqual(replay.snapshot(), raw)

    def test_payload_boundaries(self):
        for length, accepted, chunks in ((8192, True, 1), (8193, True, 2), (16384, True, 2),
                                         (16385, True, 3), (24576, True, 3), (24577, False, 4)):
            with self.subTest(length=length):
                f = Fixture(generic_payload_bytes=length)
                if not accepted:
                    with self.assertRaises(MuseumError):
                        f.reader().snapshot()
                else:
                    result = loads(f.reader().snapshot(), maximum=source.MAX_SNAPSHOT, canonical=True)
                    row = next(item for item in result["records"] if item["value"][3] == v1.CURATORIAL)
                    self.assertEqual(row["payloadInfo"]["chunkCount"], str(chunks))

    def test_repeated_chunk_positions_are_retained_but_inventory_is_deduplicated(self):
        f = Fixture(generic_payload_bytes=None)
        repeated = b"r" * (source.CHUNK_BYTES * 2)
        f._replace_payload(2, repeated)
        f.install_v2_state()
        result = loads(f.reader().snapshot(), maximum=source.MAX_SNAPSHOT, canonical=True)
        row = next(item for item in result["records"] if item["value"][3] == v1.CURATORIAL)
        self.assertEqual(len(row["payloadChunks"]), 2)
        self.assertEqual(row["payloadChunks"][0]["chunkHash"], row["payloadChunks"][1]["chunkHash"])
        self.assertEqual(row["payloadChunks"][0]["pointer"], row["payloadChunks"][1]["pointer"])
        matches = [item for item in result["payloadPointers"]
                   if item["family"] == v1.FAMILY and item["contentHash"] == row["payloadChunks"][0]["chunkHash"]]
        self.assertEqual(len(matches), 1)

    def test_ordered_reconstruction_rejects_swapped_later_chunks(self):
        f = Fixture(generic_payload_bytes=24576)
        digest = f.rows[2][0]
        descriptors = f.descriptors[digest]
        f.descriptor(2, 1, descriptors[2])
        f.descriptor(2, 2, descriptors[1])
        with self.assertRaisesRegex(MuseumError, "full payload differs"):
            f.reader().snapshot()

    def test_missing_extra_and_malformed_descriptors_reject(self):
        for change in ("missing", "extra", "length", "pointer"):
            f = Fixture(generic_payload_bytes=16385)
            digest = f.rows[2][0]
            descriptors = f.descriptors[digest]
            if change == "missing":
                f.call("recordPayloadInfo(bytes32)", ("bytes32", "uint32", "uint32"),
                    (keccak256(f.rows[2][3]), len(f.rows[2][3]), 2), ("bytes32",), (digest,))
            elif change == "extra":
                f.call("recordPayloadInfo(bytes32)", ("bytes32", "uint32", "uint32"),
                    (keccak256(f.rows[2][3]), len(f.rows[2][3]), 4), ("bytes32",), (digest,))
            elif change == "length":
                f.descriptor(2, 1, (descriptors[1][0], descriptors[1][1], descriptors[1][2] - 1))
            else:
                f.descriptor(2, 0, (descriptors[0][0], a(999), descriptors[0][2]))
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.reader().snapshot()

    def test_full_getter_hash_and_first_pointer_are_exact(self):
        for change in ("full", "hash", "first"):
            f = Fixture(generic_payload_bytes=8193)
            digest, _, _, payload, _, _, _ = f.rows[2]
            first = f.descriptors[digest][0][1]
            if change == "full":
                f.call("recordPayload(bytes32)", ("address", "bytes"), (first, payload[:-1] + b"z"),
                    ("bytes32",), (digest,))
            elif change == "hash":
                f.call("recordPayloadInfo(bytes32)", ("bytes32", "uint32", "uint32"),
                    (h("wrong-full-hash"), len(payload), 2), ("bytes32",), (digest,))
            else:
                f.call("recordPayload(bytes32)", ("address", "bytes"), (f.descriptors[digest][1][1], payload),
                    ("bytes32",), (digest,))
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.reader().snapshot()

    def test_pointer_inventory_uses_real_chunk_hashes_and_is_complete(self):
        for change in ("full-hash", "missing", "extra", "duplicate"):
            f = Fixture(generic_payload_bytes=8193)
            digest, _, _, payload, _, _, _ = f.rows[2]
            items = list(f.pointers.items())
            if change == "full-hash":
                (family, _), pointer = next(item for item in items if item[0][0] == v1.FAMILY)
                f.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                    (pointer, family, keccak256(payload)), ("uint256", "uint256"), (7, 0))
            elif change == "missing":
                f.call("payloadPointerCount(uint256)", ("uint256",), (len(items) - 1,), ("uint256",), (7,))
            elif change == "extra":
                f.call("payloadPointerCount(uint256)", ("uint256",), (len(items) + 1,), ("uint256",), (7,))
                f.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                    (a(999), v1.FAMILY, h("extra")), ("uint256", "uint256"), (7, len(items)))
            else:
                first_key, first_pointer = items[0]
                f.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                    (first_pointer, first_key[0], first_key[1]), ("uint256", "uint256"), (7, 1))
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.reader().snapshot()

    def test_typed_and_native_artist_payloads_remain_bounded_to_8192(self):
        for row_index in (1, 3):
            f = Fixture(generic_payload_bytes=23)
            f._replace_payload(row_index, b"x" * 8193)
            f.install_v2_state()
            with self.subTest(row_index=row_index), self.assertRaisesRegex(MuseumError, "original wire"):
                f.reader().snapshot()

    def test_signature_bundle_and_v2_module_identity_are_required(self):
        for change in ("signature", "base-interface", "chunk-interface", "version", "schema"):
            f = Fixture()
            if change == "signature":
                digest, _, receipt, _, bundle, _, _ = f.rows[0]
                pointer = f.pointers[(v1.BUNDLE_FAMILY, receipt[10])]
                f.call("recordSignatureBundle(bytes32)", ("address", "bytes"),
                    (pointer, bundle + b"x"), ("bytes32",), (digest,))
            elif change == "base-interface":
                f.call("supportsInterface(bytes4)", ("bool",), (False,), ("bytes4",),
                    (source.BASE_INTERFACE_ID,))
            elif change == "chunk-interface":
                f.call("supportsInterface(bytes4)", ("bool",), (False,), ("bytes4",),
                    (source.PAYLOAD_CHUNKS_INTERFACE_ID,))
            elif change == "version":
                f.call("streamModuleVersion()", ("bytes32",), (schema_id("6529stream.general-attestations.v1"),))
            else:
                f.call("streamModuleSchemaHash()", ("bytes32",), (h("wrong-schema"),))
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.reader().snapshot()

    def test_artist_context_api_preserves_shared_anchor(self):
        from .test_artist_attestation_source import Fixture as ArtistFixture
        artist = ArtistFixture()
        f = Fixture(generic_payload_bytes=24576, artist_context=artist)
        result = loads(f.reader().snapshot(), maximum=source.MAX_SNAPSHOT, canonical=True)
        self.assertEqual(result["sourceState"]["blockHash"], artist.anchor["blockHash"])
        self.assertEqual(result["sourceState"]["core"], artist.anchor["core"])
        self.assertEqual(result["host"], a(70))


if __name__ == "__main__":
    unittest.main()
