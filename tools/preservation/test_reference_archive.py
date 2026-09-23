import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.preservation.reference_archive import inspect, native_tree

ROOT = Path(__file__).resolve().parents[2]


class NativeObjectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "original.bin"

    def tearDown(self):
        self.temp.cleanup()

    def test_literal_upstream_boundaries_every_leaf_and_path(self):
        fixture = json.loads((ROOT / "test/fixtures/preservation/arweave-external-native-v1.json").read_bytes())
        self.assertEqual(fixture["sourceSha256"], "19c033264b8bf29c000ae98a90a5d09b46579aaca0a460a8ca70ee73e2ed80cd")
        for vector in fixture["vectors"]:
            with self.subTest(size=vector["size"]):
                raw = bytes((i * 17 + 29) % 256 for i in range(vector["size"]))
                self.path.write_bytes(raw)
                actual = native_tree(self.path)
                self.assertEqual(hashlib.sha256(raw).hexdigest(), vector["sha256"])
                self.assertEqual(actual["dataRoot"], vector["dataRoot"])
                self.assertEqual(actual["chunks"], vector["chunks"])
                self.assertEqual(actual["hasFinalZeroLeaf"], vector["size"] % 262144 == 0)

    def test_balanced_small_tail_preserves_all_original_bytes(self):
        self.path.write_bytes(b"a" * 262145)
        result = native_tree(self.path)
        self.assertEqual([(x["start"], x["end"]) for x in result["chunks"]], [(0, 131073), (131073, 262145)])
        self.assertFalse(result["hasFinalZeroLeaf"])

    def test_exact_multiple_root_has_zero_leaf_but_no_empty_upload_chunk(self):
        self.path.write_bytes(b"a" * 262144)
        result = native_tree(self.path)
        self.assertTrue(result["hasFinalZeroLeaf"])
        self.assertEqual(result["chunkCount"], 1)
        self.assertEqual(len(bytes.fromhex(result["firstPath"])), 160)
        self.assertEqual(result["firstPath"], result["lastPath"])

    def test_empty_object_rejected(self):
        self.path.write_bytes(b"")
        with self.assertRaises(ValueError):
            inspect(self.path)

    def test_flat_hashes_and_native_root_use_same_observed_bytes(self):
        self.path.write_bytes(b"abc")
        result = inspect(self.path)
        self.assertEqual(result["sha256"], "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        self.assertEqual(result["keccak256"], "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45")
        self.assertEqual(result["byteSize"], "3")
        self.assertNotEqual(result["arweaveDataRoot"], result["sha256"])
        self.assertFalse(result["storageInclusionEstablished"])
        self.assertFalse(result["receiptAuthorityEstablished"])

    def test_observer_receives_each_original_byte_once_in_order(self):
        raw = bytes(range(256)) * 2049
        self.path.write_bytes(raw)
        observed = []
        native_tree(self.path, observed.append)
        self.assertEqual(b"".join(observed), raw)

    def test_original_pinned_single_chunk_payload_matches_existing_root(self):
        row = json.loads((ROOT / "test/fixtures/preservation/arweave-single-chunk-v1.json").read_bytes())["first"]
        self.path.write_bytes(bytes.fromhex(row["payload"][2:]))
        actual = native_tree(self.path)
        self.assertEqual(actual["dataRoot"], row["dataRoot"][2:])
        self.assertEqual(actual["firstPath"], row["dataPath"][2:])

    def test_middle_mutation_changes_whole_identity_even_when_end_chunks_match(self):
        raw = bytearray(b"a" * (262144 * 3 + 17))
        self.path.write_bytes(raw)
        before = inspect(self.path)
        raw[262144 + 7] ^= 1
        self.path.write_bytes(raw)
        after = inspect(self.path)
        for key in ("sha256", "keccak256", "arweaveDataRoot"):
            self.assertNotEqual(before[key], after[key])
        for index in (0, -1):
            self.assertEqual(before["native"]["chunks"][index]["sha256"], after["native"]["chunks"][index]["sha256"])


if __name__ == "__main__":
    unittest.main()
