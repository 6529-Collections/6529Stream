import copy
import hashlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.preservation.inventory_package_objects import main, member_abi, reconstruct
from tools.preservation.reference_archive import MAX_CHUNK, inspect
from tools.preservation.reference_package import _write_zip, canonical


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

    def test_endpoint_export_preserves_default_result_and_complete_manifest(self):
        original = reconstruct(self.path, self.rows, self.anchor)
        directory = Path(self.temp.name) / "endpoints"
        result = reconstruct(self.path, self.rows, self.anchor, endpoint_dir=directory)
        proof_paths = result.pop("packageProofPaths")
        manifest_path = Path(result.pop("endpointManifest"))
        self.assertEqual(result, original)
        self.assertEqual(canonical(result), canonical(original))
        self.assertEqual(len(proof_paths), 2)
        manifest = json.loads(manifest_path.read_bytes())
        self.assertTrue(manifest["complete"])
        self.assertEqual(manifest["packageProofPaths"], proof_paths)
        self.assertEqual(manifest["archiveSha256"], self.anchor)
        self.assertEqual(manifest["inventorySha256"], original["inventorySha256"])
        self.assertEqual((manifest["memberCount"], manifest["nonemptyMemberCount"]), (3, 2))
        self.assertFalse(manifest["storageInclusionEstablished"])
        self.assertFalse(manifest["receiptAuthorityEstablished"])
        self.assertFalse((directory / "manifest.pending").exists())
        expected_fields = {"packageIndex", "path", "contentHash", "sha256Digest",
                           "arweaveDataRoot", "byteSize", "firstDataPath", "lastDataPath",
                           "firstChunkRaw", "lastChunkRaw"}
        for index, (proof_path, entry) in enumerate(zip(proof_paths, manifest["files"]), 1):
            raw = Path(proof_path).read_bytes()
            proof = json.loads(raw)
            self.assertEqual(set(proof), expected_fields)
            self.assertEqual(proof["packageIndex"], index)
            self.assertEqual(proof["path"], self.files[index][0])
            self.assertIs(type(proof["byteSize"]), int)
            self.assertEqual(proof["byteSize"], len(self.files[index][1]))
            for key in ("contentHash", "sha256Digest", "arweaveDataRoot", "firstDataPath", "lastDataPath"):
                self.assertEqual(proof[key], original["members"][index][key])
            self.assertTrue(Path(proof_path).is_absolute())
            self.assertEqual(Path(proof_path).parent, directory.resolve())
            self.assertEqual(entry, {"packageIndex": index, "path": Path(proof_path).name,
                                     "sha256": hashlib.sha256(raw).hexdigest()})
        self.assertNotIn("firstChunkRaw", original["members"][1])
        self.assertNotIn("lastChunkRaw", original["members"][1])

    def test_native_endpoint_intervals_include_exact_multiple_zero_leaf_rules(self):
        cases = [(MAX_CHUNK - 1, MAX_CHUNK - 1, MAX_CHUNK - 1, 1),
                 (MAX_CHUNK, MAX_CHUNK, MAX_CHUNK, 1),
                 (MAX_CHUNK * 2, MAX_CHUNK, MAX_CHUNK, 2),
                 (MAX_CHUNK + 17, 131081, 131080, 2),
                 (MAX_CHUNK * 2 + 17, MAX_CHUNK, 131080, 3)]
        for size, first_size, last_size, count in cases:
            with self.subTest(size=size):
                raw = (bytes(range(251)) * ((size + 250) // 251))[:size]
                path = Path(self.temp.name) / f"native-{size}.zip"
                _write_zip(path, [("engine.bin", raw)])
                row = {"path": "engine.bin", "byteSize": str(size),
                       "sha256Digest": "0x" + hashlib.sha256(raw).hexdigest()}
                result = reconstruct(path, [row], hashlib.sha256(path.read_bytes()).hexdigest(),
                                     endpoint_dir=Path(self.temp.name) / f"native-{size}")
                proof = json.loads(Path(result["packageProofPaths"][0]).read_bytes())
                first = bytes.fromhex(proof["firstChunkRaw"][2:])
                last = bytes.fromhex(proof["lastChunkRaw"][2:])
                self.assertEqual(first, raw[:first_size])
                self.assertEqual(last, raw[-last_size:])
                self.assertEqual(result["members"][0]["nativeChunkCount"], count)
                for payload, field, end in ((first, "firstDataPath", first_size),
                                             (last, "lastDataPath", size)):
                    data_path = bytes.fromhex(proof[field][2:])
                    self.assertEqual(data_path[-64:-32], hashlib.sha256(payload).digest())
                    self.assertEqual(int.from_bytes(data_path[-32:], "big"), end)
                    self.assertGreater(len(payload), 0)
                if size == MAX_CHUNK:
                    self.assertEqual(proof["firstDataPath"], proof["lastDataPath"])

    def test_empty_index_gaps_and_proof_path_order_preserve_original_inventory(self):
        files = [(f"nested/{i:02d}.bin", b"" if i in (0, 2, 12) else bytes([i])) for i in range(14)]
        _write_zip(self.path, files)
        rows = [{"path": name, "byteSize": str(len(raw)),
                 "sha256Digest": "0x" + hashlib.sha256(raw).hexdigest()} for name, raw in files]
        directory = Path(self.temp.name) / "ordered"
        result = reconstruct(self.path, rows, hashlib.sha256(self.path.read_bytes()).hexdigest(),
                             endpoint_dir=directory)
        proofs = [json.loads(Path(path).read_bytes()) for path in result["packageProofPaths"]]
        indices = [i for i, (_, raw) in enumerate(files) if raw]
        self.assertEqual([proof["packageIndex"] for proof in proofs], indices)
        self.assertEqual([proof["path"] for proof in proofs], [files[i][0] for i in indices])
        self.assertEqual(result["packageProofPaths"], sorted(result["packageProofPaths"]))
        self.assertFalse((directory / "nested").exists())
        self.assertEqual(len(list(directory.glob("member-*.json"))), len(indices))

    def test_late_member_identity_failure_leaves_only_unmarked_partial_files(self):
        rows = copy.deepcopy(self.rows)
        rows[-1]["sha256Digest"] = "0x" + "00" * 32
        directory = Path(self.temp.name) / "partial"
        with self.assertRaisesRegex(ValueError, "original member bytes differ"):
            reconstruct(self.path, rows, self.anchor, endpoint_dir=directory)
        self.assertEqual(len(list(directory.glob("member-*.json"))), 1)
        self.assertFalse((directory / "manifest.json").exists())
        self.assertFalse((directory / "manifest.pending").exists())
        # A failed directory cannot silently become a new export on retry.
        with self.assertRaises(FileExistsError):
            reconstruct(self.path, self.rows, self.anchor, endpoint_dir=directory)

    def test_missing_member_and_malformed_identity_never_publish_completion(self):
        malformed = copy.deepcopy(self.rows)
        malformed[0]["byteSize"] = "01"
        for name, rows in (("missing", self.rows[:-1]), ("malformed", malformed)):
            directory = Path(self.temp.name) / name
            with self.subTest(name=name), self.assertRaises(ValueError):
                reconstruct(self.path, rows, self.anchor, endpoint_dir=directory)
            self.assertFalse((directory / "manifest.json").exists())
            self.assertEqual(list(directory.glob("member-*.json")), [])

    def test_existing_directory_or_file_is_refused_without_overwrite(self):
        for name, is_directory in (("existing-dir", True), ("existing-file", False)):
            path = Path(self.temp.name) / name
            if is_directory:
                path.mkdir()
                sentinel = path / "manifest.json"
            else:
                sentinel = path
            sentinel.write_bytes(b"existing owner content")
            with self.subTest(name=name), self.assertRaises(FileExistsError):
                reconstruct(self.path, self.rows, self.anchor, endpoint_dir=path)
            self.assertEqual(sentinel.read_bytes(), b"existing owner content")

    def test_same_size_archive_change_with_restored_timestamp_cannot_mark_complete(self):
        directory = Path(self.temp.name) / "changed"
        before = self.path.stat()
        calls = 0

        def inspect_and_change(path):
            nonlocal calls
            result = inspect(path)
            calls += 1
            if calls == 2:
                changed = bytearray(self.path.read_bytes())
                changed[-1] ^= 1
                self.path.write_bytes(changed)
                os.utime(self.path, ns=(before.st_atime_ns, before.st_mtime_ns))
            return result

        with patch("tools.preservation.inventory_package_objects.inspect", side_effect=inspect_and_change):
            with self.assertRaisesRegex(ValueError, "archive changed during endpoint reconstruction"):
                reconstruct(self.path, self.rows, self.anchor, endpoint_dir=directory)
        self.assertEqual(len(list(directory.glob("member-*.json"))), 2)
        self.assertFalse((directory / "manifest.json").exists())

    def test_cli_opt_in_exports_paths_without_overwriting_export_files(self):
        inventory = Path(self.temp.name) / "inventory.json"
        output = Path(self.temp.name) / "result.json"
        directory = Path(self.temp.name) / "cli-endpoints"
        inventory.write_bytes(canonical(self.rows))
        arguments = ["inventory_package_objects", "--archive", str(self.path), "--inventory", str(inventory),
                     "--expected-zip-sha256", self.anchor, "--output", str(output),
                     "--endpoint-dir", str(directory)]
        with patch("sys.argv", arguments), patch("sys.stdout", new_callable=io.StringIO):
            main()
        result = json.loads(output.read_bytes())
        self.assertEqual(len(result["packageProofPaths"]), 2)
        bad_directory = Path(self.temp.name) / "reserved"
        arguments[-1] = str(bad_directory)
        arguments[arguments.index("--output") + 1] = str(bad_directory / "manifest.json")
        with patch("sys.argv", arguments), self.assertRaisesRegex(ValueError, "outside the fresh"):
            main()
        self.assertFalse(bad_directory.exists())


if __name__ == "__main__":
    unittest.main()
