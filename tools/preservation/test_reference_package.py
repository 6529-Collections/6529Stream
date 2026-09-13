import hashlib
import json
import random
import tempfile
import unittest
from pathlib import Path

from tools.preservation.reference_package import (
    PART_BYTES, canonical, package_tree, restore, safe_name, sha,
)
from tools.preservation.reference_capture import check_inspection


class ReferencePackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        self.source.mkdir()
        (self.source / "engine.exe").write_bytes(random.Random(6529).randbytes(PART_BYTES + 713))
        (self.source / "tool.py").write_bytes(b"# exact tool bytes\r\nprint('capture')\r\n")
        self.package = self.root / "package"
        self.manifest = package_tree(self.source, self.package, {"profile": "test only", "licenseBasis": "undetermined"})
        self.anchor = sha((self.package / "parts.json").read_bytes())

    def tearDown(self):
        self.temporary.cleanup()

    def rewrite(self, mutation):
        value = json.loads((self.package / "parts.json").read_bytes())
        mutation(value)
        raw = canonical(value) + b"\n"
        (self.package / "parts.json").write_bytes(raw)
        return sha(raw)

    def reject(self, anchor=None):
        with self.assertRaises((ValueError, FileNotFoundError)):
            restore(self.package, self.root / "restored", anchor or self.anchor)
        self.assertFalse((self.root / "restored").exists())

    def test_roundtrip_preserves_every_original_file(self):
        result = restore(self.package, self.root / "restored", self.anchor)
        self.assertGreaterEqual(len(result["parts"]), 2)
        for path in self.source.iterdir():
            self.assertEqual(path.read_bytes(), (self.root / "restored" / path.name).read_bytes())
        self.assertEqual(sum(p["bytes"] for p in result["parts"]), result["archiveBytes"])
        self.assertTrue(all(p["bytes"] <= 524288 for p in result["parts"]))

    def test_second_package_is_byte_identical(self):
        other = self.root / "package-second"
        package_tree(self.source, other, self.manifest["declaration"])
        self.assertEqual((self.package / "runtime.zip").read_bytes(), (other / "runtime.zip").read_bytes())
        self.assertEqual((self.package / "parts.json").read_bytes(), (other / "parts.json").read_bytes())

    def test_external_anchor_cannot_come_from_mutated_package(self):
        self.rewrite(lambda m: m["declaration"].update(profile="other"))
        self.reject()

    def test_rehashed_missing_part_is_not_complete(self):
        anchor = self.rewrite(lambda m: m["parts"].pop())
        self.reject(anchor)

    def test_rehashed_swapped_parts_rejected(self):
        anchor = self.rewrite(lambda m: m["parts"].reverse())
        self.reject(anchor)

    def test_rehashed_duplicate_part_rejected(self):
        anchor = self.rewrite(lambda m: m["parts"].append(m["parts"][0].copy()))
        self.reject(anchor)

    def test_rehashed_boolean_index_does_not_alias_zero(self):
        anchor = self.rewrite(lambda m: m["parts"][0].update(index=False))
        self.reject(anchor)

    def test_rehashed_boolean_part_width_is_not_one(self):
        anchor = self.rewrite(lambda m: m["parts"][0].update(bytes=True))
        self.reject(anchor)

    def test_rehashed_path_escape_is_not_opened(self):
        anchor = self.rewrite(lambda m: m["parts"][0].update(path="../engine.exe"))
        self.reject(anchor)

    def test_rehashed_missing_file_inventory_rejected(self):
        anchor = self.rewrite(lambda m: m["files"].pop())
        self.reject(anchor)

    def test_rehashed_changed_full_archive_identity_rejected(self):
        anchor = self.rewrite(lambda m: m.update(archiveSha256="00" * 32))
        self.reject(anchor)

    def test_original_part_corruption_rejected_before_extraction(self):
        path = self.package / "part-000000.bin"
        raw = bytearray(path.read_bytes())
        raw[-1] ^= 1
        path.write_bytes(raw)
        self.reject()

    def test_exact_path_vocabulary_rejects_native_aliases(self):
        for name in ["../escape", "/root", "a//b", "a/./b", "a/../b", "C:/a", "a\\b",
                     "CON.txt", "a/NUL", "COM1", "a/last.", "a/last ", "a\nb", "café",
                     "a<b", "a>b", 'a"b', "a|b", "a?b", "a*b"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                safe_name(name)
        self.assertEqual(safe_name("engine/152.0.7977.83/chrome.dll"), "engine/152.0.7977.83/chrome.dll")

    def test_rehashed_illegal_inventory_name_rejected_before_restore_writes(self):
        anchor = self.rewrite(lambda m: m["files"][0].update(path="bad?native-name.exe"))
        with self.assertRaisesRegex(ValueError, "noncanonical package path"):
            restore(self.package, self.root / "restored", anchor)
        self.assertFalse((self.root / "restored").exists())

    def test_nested_output_cannot_capture_itself(self):
        with self.assertRaises(ValueError):
            package_tree(self.source, self.source / "archive", {})

    def test_original_runtime_is_not_replaced_by_its_manifest(self):
        self.assertGreater(self.manifest["archiveBytes"], PART_BYTES)
        self.assertEqual(self.manifest["files"][0]["sha256"], hashlib.sha256((self.source / "engine.exe").read_bytes()).hexdigest())
        self.assertNotEqual(self.manifest["archiveSha256"], self.manifest["manifestSha256"])


class CaptureProfileTests(unittest.TestCase):
    def observation(self):
        return {"unsupported": [], "animations": 0, "resources": [], "text": "",
                "nodes": ["SCRIPT", "CANVAS"], "width": 64, "height": 64, "ratio": 1,
                "canvas": [{"width": 64, "height": 64, "x": 0, "y": 0,
                            "displayWidth": 64, "displayHeight": 64}]}

    def test_explicit_profile_shape_positive(self):
        check_inspection(self.observation(), 64, 64)

    def test_observed_animation_resources_and_text_rejected(self):
        for key, value in [("unsupported", ["Math.random"]), ("animations", 1),
                           ("resources", ["https://example.invalid/image.png"]),
                           ("text", "a font-dependent work"), ("nodes", ["SCRIPT", "VIDEO"])]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                row = self.observation()
                row[key] = value
                check_inspection(row, 64, 64)

    def test_canvas_count_crop_and_device_scale_mismatch_rejected(self):
        for key, value in [("ratio", 2), ("width", 63), ("canvas", []),
                           ("canvas", self.observation()["canvas"] * 2)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                row = self.observation()
                row[key] = value
                check_inspection(row, 64, 64)


if __name__ == "__main__":
    unittest.main()
