import copy
import hashlib
import tempfile
import unittest
from pathlib import Path

from tools.preservation.inventory_package_objects import member_abi, reconstruct
from tools.preservation.reference_package import _write_zip


class PackageObjectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "runtime.zip"
        self.files = [("empty.txt", b""), ("engine.bin", b"a" * (262144 * 2 + 17)), ("tool.py", b"abc")]
        _write_zip(self.path, self.files)
        self.anchor = hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.rows = [{"path": n, "byteSize": str(len(b)), "sha256Digest": "0x" + hashlib.sha256(b).hexdigest()} for n, b in self.files]

    def tearDown(self):
        self.temp.cleanup()

    def test_complete_uncompressed_members_and_explicit_empty(self):
        result = reconstruct(self.path, self.rows, self.anchor)
        self.assertEqual(result["memberCount"], 3)
        self.assertEqual(result["members"][0], {"index": 0, **self.rows[0], "kind": "EMPTY_PACKAGE_MEMBER"})
        self.assertEqual(result["members"][2]["contentHash"], "0x4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45")
        self.assertEqual(result["members"][1]["nativeChunkCount"], 3)
        self.assertFalse(result["storageInclusionEstablished"])
        self.assertFalse(result["receiptAuthorityEstablished"])

    def test_wrong_archive_anchor_rejected(self):
        with self.assertRaisesRegex(ValueError, "archive differs"):
            reconstruct(self.path, self.rows, "00" * 32)

    def test_missing_extra_reordered_or_duplicate_member_rejected(self):
        for rows in (self.rows[:-1], self.rows + [self.rows[-1]], list(reversed(self.rows))):
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                reconstruct(self.path, rows, self.anchor)

    def test_size_digest_empty_substitution_rejected(self):
        for index, key, value in ((0, "byteSize", "1"), (1, "byteSize", "0"), (2, "sha256Digest", "0x" + "00" * 32)):
            rows = copy.deepcopy(self.rows)
            rows[index][key] = value
            with self.subTest(index=index, key=key), self.assertRaisesRegex(ValueError, "bytes differ"):
                reconstruct(self.path, rows, self.anchor)

    def test_malformed_inventory_identity_rejected(self):
        for key, value in (("path", "../escape"), ("byteSize", "01"), ("byteSize", str(2**64)), ("sha256Digest", "bad")):
            rows = copy.deepcopy(self.rows)
            rows[0][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                reconstruct(self.path, rows, self.anchor)

    def test_middle_change_requires_new_original_member_identity(self):
        files = self.files.copy()
        changed = bytearray(files[1][1]); changed[262144 + 1] ^= 1
        files[1] = (files[1][0], bytes(changed))
        _write_zip(self.path, files)
        anchor = hashlib.sha256(self.path.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, "bytes differ"):
            reconstruct(self.path, self.rows, anchor)

    def test_member_abi_preserves_every_dynamic_field_and_empty_row(self):
        result = reconstruct(self.path, self.rows, self.anchor)
        wire = bytes.fromhex(result["membersABI"][2:])

        def integer(at):
            self.assertLessEqual(at + 32, len(wire))
            return int.from_bytes(wire[at:at + 32], "big")

        def dynamic(base, slot):
            start = base + integer(base + slot * 32)
            size = integer(start)
            end = start + 32 + size
            padded = end + (-size) % 32
            self.assertLessEqual(padded, len(wire))
            self.assertEqual(wire[end:padded], bytes(padded - end))
            return wire[start + 32:end], padded

        self.assertEqual(integer(0), 32)
        self.assertEqual(integer(32), len(self.files))
        array_base = 64
        previous_end = array_base + 32 * len(self.files)
        for i, member in enumerate(result["members"]):
            base = array_base + integer(array_base + 32 * i)
            self.assertEqual(base, previous_end)
            self.assertEqual(integer(base), 7 * 32)
            path, path_end = dynamic(base, 0)
            first, first_end = dynamic(base, 5)
            last, previous_end = dynamic(base, 6)
            self.assertEqual(base + integer(base + 5 * 32), path_end)
            self.assertEqual(base + integer(base + 6 * 32), first_end)
            self.assertEqual(path.decode("ascii"), member["path"])
            self.assertEqual(integer(base + 32), int(member["byteSize"]))
            self.assertEqual(wire[base + 96:base + 128].hex(), member["sha256Digest"][2:])
            self.assertEqual(first.hex(), member.get("firstDataPath", "0x")[2:])
            self.assertEqual(last.hex(), member.get("lastDataPath", "0x")[2:])
            if i == 0:
                self.assertEqual(wire[base + 64:base + 96].hex(), "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
                self.assertEqual(integer(base + 128), 0)
            else:
                self.assertEqual(wire[base + 64:base + 96].hex(), member["contentHash"][2:])
                self.assertEqual(wire[base + 128:base + 160].hex(), member["arweaveDataRoot"][2:])
        self.assertEqual(previous_end, len(wire))
        self.assertEqual(member_abi([]), "0x" + (bytes(31) + b"\x20" + bytes(32)).hex())


if __name__ == "__main__":
    unittest.main()
