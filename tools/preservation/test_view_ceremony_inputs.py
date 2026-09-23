"""Offline transport tests; all local capture reports below are synthetic controls.

They never execute a browser, deploy contracts, or claim an actual ceremony.
ZIPs, PNG streams, native chunk paths and ABI bytes are real locally generated
bytes so corruption checks exercise the transport rather than mocked hashing.
"""
import base64
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zlib

from tools.preservation import reference_capture as capture
from tools.preservation import view_ceremony_inputs as inputs
from tools.preservation.inventory_package_objects import reconstruct
from tools.preservation.reference_archive import MAX_CHUNK, MIN_CHUNK
from tools.preservation.reference_package import _write_zip, canonical


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()


def png(pixel):
    def chunk(kind, data):
        return len(data).to_bytes(4, "big") + kind + data + zlib.crc32(kind + data).to_bytes(4, "big")
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", bytes.fromhex("00000001000000010806000000"))
            + chunk(b"IDAT", zlib.compress(b"\x00" + pixel)) + chunk(b"IEND", b""))


class ViewInputsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.runtime = self.root / "runtime.zip"
        self.runtime_root = (self.root / "restored").resolve()
        self.export = self.root / "export"
        self.export.mkdir()
        tool = Path(capture.__file__).read_bytes()
        self.files = [("PACKAGE.json", b'{"test":"synthetic transport only"}'),
                      ("capture.py", tool), ("empty.txt", b""), ("engine.exe", b"synthetic engine fixture")]
        _write_zip(self.runtime, self.files)
        inventory = [{"path": name, "byteSize": str(len(raw)), "sha256Digest": "0x" + digest(raw)}
                     for name, raw in self.files]
        self.environment = {
            "objectHash": inputs.ZERO, "coverageHash": inputs.ZERO, "manifestHash": inputs.ZERO,
            "manifestBytes": "0", "engineName": "Chromium", "engineVersion": "test-version",
            "engineExecutableSha256": inventory[3]["sha256Digest"], "toolchainName": "reference_capture.py",
            "toolchainVersion": "test-source", "toolchainSha256": inventory[1]["sha256Digest"],
            "engineExecutablePath": "engine.exe", "toolchainPath": "capture.py", "packageFiles": inventory,
            "platformPrerequisites": [{"path": "C:/Windows/test.dll", "byteSize": "3", "sha256Digest": "0x" + digest(b"dll")}],
            "operatingSystem": "Windows", "operatingSystemVersion": "test-os", "architecture": "AMD64",
            "viewportWidth": "1", "viewportHeight": "1", "devicePixelRatio": "1", "colorSpace": "srgb",
            "softwareRasterization": True, "captureProfile": inputs._kh(capture.PROFILE.encode()),
            "licenseNote": "Synthetic test declaration; no execution or licensing claim.",
        }
        self.endpoints = self.root / "endpoints"
        reconstruct(self.runtime, inventory, digest(self.runtime.read_bytes()), endpoint_dir=self.endpoints)
        self.manifest = self.endpoints / "manifest.json"
        # The existing producer returns the actual filename; do not assume one.
        if not self.manifest.exists():
            self.manifest = next(p for p in self.endpoints.glob("*.json") if not p.name.startswith("member-"))
        self.revision = "0x" + "12" * 20
        h = "0x" + "34" * 32
        publication = {key: h for key in inputs.PUBLICATION_IDS}
        widths = {"basicBindingABI": 1376, "completeBindingABI": 416, "rootBindingABI": 896}
        publication.update({key: "0x" + (b"\x01" * widths.get(key, 32)).hex() for key in inputs.PUBLICATION_ABIS})
        self.source = {
            "schema": "STREAM_VIEW_CEREMONY_SOURCE_EXPORT_V1", "schemaVersion": 1,
            "fixture": {"host": "0x" + "11" * 20, "runtimeHash": h, "sourceRevision": self.revision,
                        "chainId": "31337", "initialBlockNumber": "1", "initialTimestamp": "1700000000", "deploymentHash": h},
            # Genuine protocol distinction: this membership ID is NOT viewId.
            "scope": {"scopeType": 4, "collectionId": "1", "tokenId": "0", "scopeId": "0x" + "56" * 32},
            "graph": [{"role": role, "target": "0x" + f"{index + 1:040x}", "runtimeHash": h}
                      for index, role in enumerate(inputs.GRAPH_ROLES)],
            "publication": publication, "members": [],
        }
        self.capture_dirs = []
        for index in range(2):
            token = 100 + index
            html = f"<html><head></head><body><script>/*synthetic test {token}*/</script></body></html>".encode()
            metadata = canonical({"animation_url": "data:text/html;base64," + base64.b64encode(html).decode(), "name": str(token)})
            token_data = bytes([index])
            words = [bytes(32) for _ in range(31)]
            for at, value in ((0, index), (1, token), (2, index + 1), (3, 1), (5, 1), (29, len(metadata)), (30, len(html))):
                words[at] = value.to_bytes(32, "big")
            for at, raw in ((6, token_data), (27, metadata), (28, html)):
                words[at] = bytes.fromhex(inputs._kh(raw)[2:])
            member = {"index": str(index), "tokenId": str(token), "collectionSerial": str(index + 1)}
            for key, suffix, raw in (("json", "json", metadata), ("html", "html", html),
                                      ("outputReturn", "output.abi", b"".join(words)), ("tokenData", "token-data.bin", token_data)):
                name = f"member-{index:020d}.{suffix}"
                (self.export / name).write_bytes(raw)
                member[key] = {"path": name, "keccak256": inputs._kh(raw), "sha256": "0x" + digest(raw), "byteLength": str(len(raw))}
            self.source["members"].append(member)
            directory = self.root / f"capture-{index}"
            directory.mkdir()
            self.capture_dirs.append(directory)
            self._report(directory, html, png(bytes([index, 0, 0, 255])))
        self._save_source()

    def _report(self, directory, html, image):
        (directory / "original.html").write_bytes(html)
        facts = {
            "profile": capture.PROFILE, "browser": {"product": "Chrome/test-version"},
            "engineSha256": self.environment["engineExecutableSha256"][2:],
            "gpu": {"featureStatus": {"gpu_compositing": "disabled_software", "rasterization": "disabled_software"},
                    "auxAttributes": {"sandboxed": True}},
            "command": [str(self.runtime_root / "engine.exe"), *capture.FLAGS],
            "os": {"platform": "win32", "version": "test-os", "machine": "AMD64"},
            "viewport": {"width": 1, "height": 1, "deviceScaleFactor": 1},
            "locale": "en-US", "timezone": "UTC", "colorSpace": "srgb", "guardsSha256": digest(capture.GUARDS.encode()),
            "inspection": {"unsupported": [], "nodes": ["SCRIPT", "CANVAS"], "text": "", "canvas": [
                {"width": 1, "height": 1, "x": 0, "y": 0, "displayWidth": 1, "displayHeight": 1}],
                "animations": 0, "width": 1, "height": 1, "ratio": 1, "resources": []},
            "sourceBytes": len(html), "sourceSha256": digest(html), "captureBytes": len(image), "captureSha256": digest(image),
            "loadedModules": [{"path": str(self.runtime_root / "engine.exe"), "bytes": len(self.files[3][1]),
                               "sha256": digest(self.files[3][1])}, {"path": "C:/Windows/test.dll", "bytes": 3, "sha256": digest(b"dll")}],
        }
        for index in range(2):
            (directory / f"capture-{index}.png").write_bytes(image)
            (directory / f"capture-{index}.json").write_bytes(canonical(facts) + b"\n")
        repeat = {"profile": capture.PROFILE, "acceptanceMode": "BYTE_EXACT", "captureClass": "still",
                  "sourceSha256": digest(html), "captureSha256": digest(image), "independentProcessCount": 2,
                  "recordAuthorityEstablished": False, "archiveCoverageEstablished": False}
        (directory / "repeat.json").write_bytes(canonical(repeat) + b"\n")

    def _save_source(self):
        self.source.pop("sourceHash", None)
        self.source["sourceHash"] = inputs._kh(compact(self.source))
        raw = compact(self.source)
        (self.export / "source.json").write_bytes(raw)
        self.anchor = digest(raw)

    def _assemble(self):
        return inputs.assemble(self.export, self.anchor, self.revision, self.capture_dirs,
                               self.environment, self.runtime, self.runtime_root, self.manifest)

    def test_complete_roundtrip_preserves_distinct_view_membership_and_raw_bytes(self):
        result = self._assemble()
        self.assertNotEqual(self.source["scope"]["scopeId"], self.source["publication"]["viewId"])
        self.assertEqual(set(result), {"environment", "browser", "captures", "audit"})
        self.assertEqual(result["audit"]["sourceSha256"], self.anchor)
        self.assertFalse(result["audit"]["browserExecutionIndependentlyEstablished"])
        self.assertFalse(result["audit"]["onchainAcceptanceEstablished"])
        for index in range(2):
            value = result["captures"][f"capture{index + 1}"]
            self.assertEqual((value["tokenId"], value["collectionSerial"]), (100 + index, index + 1))
            self.assertEqual(bytes.fromhex(value["html"][2:]), (self.capture_dirs[index] / "original.html").read_bytes())
            self.assertEqual(value["repeatCapture0Sha256"], value["repeatCapture1Sha256"])
            self.assertEqual(value["sha256Digest"], "0x" + digest((self.capture_dirs[index] / "capture-0.png").read_bytes()))
        self.assertEqual(len(result["audit"]["packageProofPaths"]), 3)  # Empty original entry has no object.

    def test_environment_standard_abi_offsets_and_original_field_order(self):
        encoded = inputs.encode_environment(self.environment)
        raw = bytes.fromhex(encoded["environmentABI"][2:])
        word = lambda at: int.from_bytes(raw[at:at + 32], "big")
        self.assertEqual(word(0), 32)
        self.assertEqual(raw[32:160], bytes(128))
        cursor = 32 + 24 * 32
        for slot, name in enumerate(inputs.ENV_FIELDS):
            if name in inputs.TEXT_BOUNDS:
                start = 32 + word(32 + slot * 32)
                self.assertEqual(start, cursor)
                size = word(start)
                self.assertEqual(raw[start + 32:start + 32 + size].decode(), self.environment[name])
                cursor = start + 32 + size + (-size) % 32
                self.assertEqual(raw[start + 32 + size:cursor], bytes((-size) % 32))
            elif name in ("packageFiles", "platformPrerequisites"):
                start = 32 + word(32 + slot * 32)
                self.assertEqual(start, cursor)
                rows = self.environment[name]
                self.assertEqual(word(start), len(rows))
                base = start + 32
                cursor = base + 32 * len(rows)
                for i, row in enumerate(rows):
                    item = base + word(base + 32 * i)
                    self.assertEqual(item, cursor)
                    self.assertEqual(word(item), 96)
                    self.assertEqual(word(item + 32), int(row["byteSize"]))
                    self.assertEqual(raw[item + 64:item + 96].hex(), row["sha256Digest"][2:])
                    size = word(item + 96)
                    self.assertEqual(raw[item + 128:item + 128 + size].decode(), row["path"])
                    cursor = item + 128 + size + (-size) % 32
        self.assertEqual(cursor, len(raw))
        self.assertEqual(word(32 + 17 * 32), 1)
        self.assertEqual(word(32 + 21 * 32), 1)
        inputs.require_environment_abi(self.environment, encoded)

    def test_environment_rejects_all_nonzero_initial_fields_and_extra_missing(self):
        for key, value in (("objectHash", "0x" + "01" * 32), ("coverageHash", "0x" + "01" * 32),
                           ("manifestHash", "0x" + "01" * 32), ("manifestBytes", "1"), ("unexpected", True)):
            changed = copy.deepcopy(self.environment)
            changed[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                inputs.encode_environment(changed)
        changed = copy.deepcopy(self.environment)
        del changed["manifestHash"]
        with self.assertRaises(ValueError):
            inputs.encode_environment(changed)

    def test_environment_rejects_malformed_types_widths_inventory_order_and_aliases(self):
        for key, value in (("manifestBytes", 0), ("viewportWidth", "01"), ("viewportWidth", "65536"),
                           ("viewportHeight", "4097"), ("softwareRasterization", 1), ("devicePixelRatio", "2"),
                           ("captureProfile", "0x" + "00" * 32), ("licenseNote", "x" * 16385)):
            changed = copy.deepcopy(self.environment)
            changed[key] = value
            with self.subTest(key=key, value=str(value)[:20]), self.assertRaises(ValueError):
                inputs.encode_environment(changed)
        for rows in (list(reversed(self.environment["packageFiles"])), self.environment["packageFiles"][:-1],
                     [*self.environment["packageFiles"], self.environment["packageFiles"][-1]]):
            changed = copy.deepcopy(self.environment)
            changed["packageFiles"] = rows
            with self.assertRaises(ValueError):
                inputs.encode_environment(changed)

    def test_abi_rejects_trailing_bytes_wrong_offsets_and_padding(self):
        original = bytes.fromhex(inputs.encode_environment(self.environment)["environmentABI"][2:])
        bad_offset = bytearray(original); bad_offset[31] = 64
        bad_padding = bytearray(original); bad_padding[-1] ^= 1
        for raw in (original + bytes(32), bytes(bad_offset), bytes(bad_padding), original[:-1]):
            with self.assertRaisesRegex(ValueError, "Environment ABI"):
                inputs.require_environment_abi(self.environment, {"environmentABI": "0x" + raw.hex()})

    def test_native_endpoint_exact_multiple_zero_leaf_and_tail_rebalance(self):
        for size in (MAX_CHUNK, 2 * MAX_CHUNK, MAX_CHUNK + 1, MAX_CHUNK + MIN_CHUNK - 1):
            with self.subTest(size=size):
                raw = bytes(range(251)) * (size // 251) + bytes(range(size % 251))
                path = self.root / "object.bin"
                path.write_bytes(raw)
                with patch.object(Path, "read_bytes", side_effect=AssertionError("whole-object read forbidden")):
                    value = inputs.object_endpoints(path)
                self.assertEqual(value["sha256Digest"], "0x" + digest(raw))
                self.assertEqual(value["contentHash"], inputs._kh(raw))
                first = bytes.fromhex(value["firstChunkRaw"][2:])
                last = bytes.fromhex(value["lastChunkRaw"][2:])
                self.assertEqual(first, raw[:len(first)])
                self.assertEqual(last, raw[-len(last):])
                if size == MAX_CHUNK + 1:
                    self.assertEqual((len(first), len(last)), ((size + 1) // 2, size // 2))
                for which, offset, chunk in (("first", 0, first), ("last", size - 1, last)):
                    proof = bytes.fromhex(value[which + "DataPath"][2:])
                    expected_id = bytes.fromhex(value["arweaveDataRoot"][2:])
                    while len(proof) > 64:
                        left, right, split = proof[:32], proof[32:64], proof[64:96]
                        self.assertEqual(hashlib.sha256(hashlib.sha256(left).digest() + hashlib.sha256(right).digest()
                                                       + hashlib.sha256(split).digest()).digest(), expected_id)
                        expected_id = left if offset < int.from_bytes(split, "big") else right
                        proof = proof[96:]
                    self.assertEqual(proof[:32], hashlib.sha256(chunk).digest())
                    self.assertEqual(hashlib.sha256(hashlib.sha256(proof[:32]).digest()
                                                   + hashlib.sha256(proof[32:]).digest()).digest(), expected_id)
                self.assertEqual(int.from_bytes(bytes.fromhex(value["lastDataPath"][2:])[-32:], "big"), size)

    def test_crossed_or_truncated_chunks_cannot_reuse_real_membership_paths(self):
        path = self.root / "chunks.bin"
        path.write_bytes(b"a" * MAX_CHUNK + b"b" * MAX_CHUNK)
        baseline = inputs.object_endpoints(path)
        inputs.require_object_endpoints(path, baseline)
        for field in ("firstChunkRaw", "lastChunkRaw", "firstDataPath", "lastDataPath"):
            bad = copy.deepcopy(baseline)
            bad[field] = baseline[("last" if field.startswith("first") else "first") + field[5 if field.startswith("first") else 4:]]
            with self.subTest(field=field), self.assertRaises(ValueError):
                inputs.require_object_endpoints(path, bad)
        (self.root / "empty.bin").write_bytes(b"")
        with self.assertRaises(ValueError):
            inputs.object_endpoints(self.root / "empty.bin")

    def _rewrite_proof(self, index, change):
        manifest = inputs.load_json(self.manifest)
        entry = next(row for row in manifest["files"] if row["packageIndex"] == index)
        path = self.endpoints / entry["path"]
        proof = inputs.load_json(path)
        change(proof)
        raw = canonical(proof) + b"\n"
        path.write_bytes(raw)
        entry["sha256"] = digest(raw)
        self.manifest.write_bytes(canonical(manifest) + b"\n")

    def test_wrong_member_index_rejected_even_with_updated_manifest_hash(self):
        self._rewrite_proof(1, lambda p: p.update(packageIndex=0))
        with self.assertRaisesRegex(ValueError, "member identity"):
            self._assemble()

    def test_missing_member_endpoint_rejected_before_output(self):
        (self.endpoints / "member-00000000000000000001.json").unlink()
        with self.assertRaises(FileNotFoundError):
            self._assemble()

    def test_crossed_member_chunk_rejected_after_transport_hash_rebinding(self):
        first = inputs.load_json(self.endpoints / "member-00000000000000000000.json")
        self._rewrite_proof(1, lambda p: p.update(firstChunkRaw=first["firstChunkRaw"]))
        with self.assertRaisesRegex(ValueError, "endpoints differ"):
            self._assemble()

    def test_source_external_sha_revision_and_aggregate_are_independent(self):
        with self.assertRaisesRegex(ValueError, "source SHA256"):
            inputs.validate_source(self.export, "00" * 32, self.revision)
        with self.assertRaisesRegex(ValueError, "source revision"):
            inputs.validate_source(self.export, self.anchor, "0x" + "13" * 20)
        self.source["fixture"]["initialTimestamp"] = "1700000001"
        raw = compact(self.source)
        (self.export / "source.json").write_bytes(raw)
        with self.assertRaisesRegex(ValueError, "aggregate"):
            inputs.validate_source(self.export, digest(raw), self.revision)

    def test_source_export_strict_wire_order_and_complete_roles(self):
        original = copy.deepcopy(self.source)
        for change in (lambda: self.source["graph"].pop(),
                       lambda: self.source["graph"].reverse(),
                       lambda: self.source["publication"].update(extra=inputs.ZERO),
                       lambda: self.source["fixture"].update(chainId="031337"),
                       lambda: self.source["members"][1].update(index="0")):
            self.source = copy.deepcopy(original)
            change(); self._save_source()
            with self.assertRaises(ValueError):
                inputs.validate_source(self.export, self.anchor, self.revision)

    def test_fixed_binding_abis_reject_trailing_whole_word(self):
        for key in ("basicBindingABI", "completeBindingABI", "rootBindingABI"):
            previous = self.source["publication"][key]
            self.source["publication"][key] += "00" * 32
            self._save_source()
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "exact width"):
                inputs.validate_source(self.export, self.anchor, self.revision)
            self.source["publication"][key] = previous

    def test_actual_output_identity_not_replaced_by_json_labels(self):
        self.source["members"][0]["tokenId"] = "99"
        self._save_source()
        with self.assertRaisesRegex(ValueError, "output ABI/member identity"):
            inputs.validate_source(self.export, self.anchor, self.revision)

    def test_exported_raw_token_data_is_still_required_and_hashed(self):
        path = self.export / self.source["members"][1]["tokenData"]["path"]
        path.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "raw bytes"):
            self._assemble()

    def test_capture_order_original_html_and_repeat_raw_png_cannot_be_crossed(self):
        self.capture_dirs.reverse()
        with self.assertRaisesRegex(ValueError, "original HTML"):
            self._assemble()
        self.capture_dirs.reverse()
        target = self.capture_dirs[0] / "capture-1.png"
        target.write_bytes((self.capture_dirs[1] / "capture-1.png").read_bytes())
        with self.assertRaisesRegex(ValueError, "repeat PNG"):
            self._assemble()

    def test_report_controls_and_unretained_dependencies_reject(self):
        path = self.capture_dirs[0] / "capture-0.json"
        original = inputs.load_json(path)
        for change in (lambda r: r.update(sourceSha256="00" * 32),
                       lambda r: r.update(guardsSha256="00" * 32),
                       lambda r: r["command"].append("--no-sandbox"),
                       lambda r: r["loadedModules"][0].update(path="C:/unknown.dll"),
                       lambda r: r.update(loadedModules=[])):
            report = copy.deepcopy(original); change(report)
            path.write_bytes(canonical(report))
            with self.assertRaises(ValueError):
                self._assemble()

    def test_two_samples_required_no_synthetic_second_capture(self):
        self.capture_dirs.pop()
        with self.assertRaisesRegex(ValueError, "directory count"):
            self._assemble()
        self.source["members"].pop(); self._save_source()
        with self.assertRaisesRegex(ValueError, "exactly two"):
            self._assemble()

    def test_duplicate_json_field_rejected_even_with_correct_external_sha(self):
        raw = (self.export / "source.json").read_bytes()
        raw = raw.replace(b'"schemaVersion":1', b'"schemaVersion":1,"schemaVersion":1')
        (self.export / "source.json").write_bytes(raw)
        with self.assertRaisesRegex(ValueError, "duplicate JSON"):
            inputs.validate_source(self.export, digest(raw), self.revision)

    def test_cli_roundtrip_and_failed_assembly_never_emits_documents(self):
        env = self.root / "environment-fields.json"
        env.write_bytes(canonical(self.environment))
        args = ["assemble", "--export", str(self.export), "--expected-source-sha256", self.anchor,
                "--expected-source-revision", self.revision, "--environment", str(env),
                "--runtime-zip", str(self.runtime), "--runtime-root", str(self.runtime_root),
                "--member-manifest", str(self.manifest)]
        for directory in self.capture_dirs:
            args += ["--capture-directory", str(directory)]
        destination = self.root / "inputs"
        inputs.main(args + ["--output-directory", str(destination)])
        self.assertEqual({p.name for p in destination.iterdir()}, {"environment.json", "browser.json", "captures.json", "audit.json"})
        self.assertEqual(inputs.load_json(destination / "captures.json")["capture2"]["tokenId"], 101)
        bad = self.root / "bad-inputs"
        (self.capture_dirs[0] / "repeat.json").unlink()
        with self.assertRaises(FileNotFoundError):
            inputs.main(args + ["--output-directory", str(bad)])
        self.assertFalse(bad.exists())

    def test_export_schema_roster_and_fields_match_parser(self):
        schema_path = Path(__file__).resolve().parents[2] / "test/fixtures/preservation-view/ceremony-source-export-v1.schema.json"
        schema = inputs.load_json(schema_path)
        self.assertEqual([row["properties"]["role"]["const"] for row in schema["properties"]["graph"]["prefixItems"]], inputs.GRAPH_ROLES)
        self.assertEqual(schema["properties"]["publication"]["required"], inputs.PUBLICATION_IDS + inputs.PUBLICATION_ABIS)


if __name__ == "__main__":
    unittest.main()
