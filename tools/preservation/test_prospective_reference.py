"""Offline format/byte controls; mocked processes are never browser execution evidence."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools.museum.chain_abi import encode
from . import prospective_capture as c
from . import prospective_reference_profile as profile

def context():
    return {"chainId": 1, "core": "0x" + "00" * 19 + "02", "collectionId": 3,
        "sourceHash": "0x" + "00" * 31 + "04", "vector": {"name": "named", "seed": "0x" + "00" * 32, "input": "0x0001"},
        "scriptHex": "0x" + b"/* </ScRiPtX */".hex()}

class ProspectiveReferenceTests(unittest.TestCase):
    def test_literal_independent_tuple_vector_encoding(self):
        v = context()["vector"]
        literal = encode(("bytes32", ("string", "bytes32", "bytes")), ("0x" + c.kh(c.SIMULATION.encode()).hex(), (v["name"], "0x" + "00" * 32, b"\0\1")))
        self.assertEqual(c.vector_hash(v), c.kh(literal))

    def test_named_seed_and_input_changes_change_html(self):
        original = context(); html = c.simulation_html(original)
        for field, value in [("name", "other"), ("seed", "0x" + "11" * 32), ("input", "0x02")]:
            changed = copy.deepcopy(original); changed["vector"][field] = value
            self.assertNotEqual(html, c.simulation_html(changed))

    def test_exact_endtag_rule_and_absent_token_claims(self):
        html = c.simulation_html(context())
        self.assertIn(b"<\\/ScRiPtX", html)
        self.assertIn(b'data-stream-render-state="prospective"', html)
        for value in [b"tokenId", b"finalized", b"Coordinator", b"collectionSerial"]:
            self.assertNotIn(value, html)

    def test_closed_shapes_ranges_utf8_and_paths(self):
        for name in ["", "../x", "has space", "x" * 65, "<script>"]:
            data = context(); data["vector"]["name"] = name
            with self.assertRaises(ValueError): c.simulation_html(data)
        for field, value in [("chainId", True), ("collectionId", 0), ("scriptHex", "0xff"), ("sourceHash", "0x00")]:
            data = context(); data[field] = value
            with self.assertRaises(ValueError): c.simulation_html(data)
        data = context(); data["tokenId"] = 1
        with self.assertRaises(ValueError): c.simulation_html(data)

    def _capture(self, engine, html, width, height):
        png = b"\x89PNG\r\n\x1a\nsynthetic-unit-only"
        return png, {"profile": c.PROFILE, "sourceBytes": len(html), "sourceSha256": c.digest(html), "captureBytes": len(png), "captureSha256": c.digest(png)}

    def test_execution_nine_word_literal_and_source_drift(self):
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary) / "run"
            with patch.object(c, "capture_once", side_effect=self._capture), patch.object(c.time, "time", return_value=100):
                result = c.repeat_capture(Path("not-executed"), context(), 64, 64, run)
            raw = c.execution(run, "0x" + "aa" * 32)
            expected = encode(("bytes32",) * 7 + ("uint64", "uint32"), ("0x" + c.kh(c.SIMULATION.encode()).hex(), context()["sourceHash"], "0x" + c.vector_hash(context()["vector"]).hex(), "0x" + "aa" * 32, "0x" + result["htmlSha256"], "0x" + result["pngSha256"][0], "0x" + result["pngSha256"][1], 100, 0))
            self.assertEqual(raw, expected); self.assertEqual(len(raw), 288)
            data = context(); data["vector"]["name"] = "changed"
            (run / "context.json").write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaises(ValueError): c.execution(run, "0x" + "aa" * 32)

    def test_mismatched_repeat_retains_both_failed_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary) / "run"
            first = self._capture(None, b"x", 1, 1); second = (first[0] + b"changed", first[1])
            with patch.object(c, "capture_once", side_effect=[first, second]):
                with self.assertRaises(ValueError): c.repeat_capture(Path("not-executed"), context(), 1, 1, run)
            self.assertTrue((run / "capture-0.png").exists()); self.assertTrue((run / "capture-1.png").exists())
            self.assertFalse((run / "repeat.json").exists())

    def test_definition_documents_and_primitive_types_complete(self):
        schema = json.loads(profile.outputs()["schemas/preservation/prospective/STREAM_PROSPECTIVE_REFERENCE_ABI_V1.json"])
        def walk(node):
            if node["type"].startswith("tuple"):
                self.assertIn("components", node)
                for child in node["components"]: walk(child)
            else:
                self.assertNotIn(".", node["type"])
        for field in schema["payload"]: walk(field)
        walk(schema["receipt"]); walk(schema["execution"])
        for path, raw in profile.outputs().items(): self.assertEqual((profile.ROOT / path).read_bytes(), raw)

if __name__ == "__main__": unittest.main()
