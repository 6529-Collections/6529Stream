#!/usr/bin/env python3
"""Codec-only checks for the actual local resume driver; no chain or compiler."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from eth_abi import encode

MODULE = Path(__file__).with_name("test_current_graph_resume.py")
spec = importlib.util.spec_from_file_location("current_resume", MODULE)
resume = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resume)


class ResumeCodecTest(unittest.TestCase):
    def test_tuple_text_nested_strings_and_empty_arrays(self):
        actual = resume.TupleText('(3, (false, "x,[]()\\\"y"), [0x1234, 0xabcd], [])').parse()
        self.assertEqual(actual, [3, [False, 'x,[]()"y'], ["0x1234", "0xabcd"], []])

    def test_tuple_rejects_truncation_extra_and_expressions(self):
        for raw in ["(1", "(1,,2)", "(true]","(1) trailing", "__import__(0)", "(1e9)", "('x')"]:
            with self.subTest(raw=raw), self.assertRaises(RuntimeError):
                resume.TupleText(raw).parse()

    def test_abi_tuple_uses_names_and_retains_repeated_occurrences(self):
        parameter = {"type": "tuple[]", "components": [
            {"name": "id", "type": "uint64"}, {"name": "pair", "type": "tuple",
                "components": [{"name": "actor", "type": "address"}, {"name": "raw", "type": "bytes"}]}]}
        row = {"pair": {"raw": "0x1234", "actor": "0x" + "12" * 20}, "id": 7}
        encoded = resume.typed(parameter, [row, row])
        self.assertEqual(resume.canonical(parameter), "(uint64,(address,bytes))[]")
        self.assertEqual(encoded, [(7, ("0x" + "12" * 20, b"\x12\x34"))] * 2)
        self.assertEqual(resume.typed(parameter, encoded, named=True)[0]["id"], 7)

    def test_typed_rejects_missing_fields_wrong_scalar_and_fixed_lengths(self):
        parameter = {"type": "tuple", "components": [{"name": "a", "type": "uint64"}]}
        for value in [{"b": 1}, {"a": 1, "b": 2}, [True], []]:
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                resume.typed(parameter, value)
        for parameter, value in [({"type": "bool"}, 1), ({"type": "bytes4"}, "0x12"),
                                 ({"type": "address"}, "0x12"), ({"type": "uint8[2]"}, [1])]:
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                resume.typed(parameter, value)

    def abi(self, root, output):
        folder = Path(root) / "out/DeployCurrentStack.sol"
        folder.mkdir(parents=True)
        abi = [{"type": "function", "name": "run", "inputs": [], "outputs": output}]
        (folder / "DeployCurrentStack.json").write_text(json.dumps({"abi": abi}), encoding="utf-8")
        return resume.ABI(Path(root), Path(root) / "out")

    def test_named_and_unnamed_forge_results(self):
        parameter = {"name": "staged", "type": "tuple", "components": [
            {"name": "phase", "type": "uint8"}, {"name": "operator", "type": "address"}]}
        for named in [True, False]:
            with tempfile.TemporaryDirectory() as root:
                p = dict(parameter, name="staged" if named else "")
                abi = self.abi(root, [p])
                key = p["name"] or "0"
                text = 'ordinary log\n' + json.dumps({"returns": {key: {
                    "internal_type": "struct Whatever", "value": "(1, 0x" + "12" * 20 + ")"}}})
                result = abi.script_result(text, "run")
                self.assertEqual(result, [{"phase": 1, "operator": "0x" + "12" * 20}])

    def test_raw_return_requires_canonical_complete_bytes(self):
        with tempfile.TemporaryDirectory() as root:
            abi = self.abi(root, [{"name": "result", "type": "bytes"}])
            raw = encode(["bytes"], [b"retained"])
            self.assertEqual(abi.script_result(json.dumps({"returned": resume.hx(raw)}), "run"), [b"retained"])
            with self.assertRaises(RuntimeError):
                abi.result("DeployCurrentStack", "run", raw + bytes(32))

    def test_json_log_records_do_not_evaluate_noise(self):
        text = 'noise {bad}\n{"returns":{"x":{"value":"(3)"}}}\n{"finished":true}'
        self.assertEqual(list(resume.output_records(text)), [
            {"returns": {"x": {"value": "(3)"}}}, {"finished": True}])

    def test_inventory_excludes_artifact_directories_named_sol(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            files = ["foundry.toml", "smart-contracts/vendor/openzeppelin/Address.sol",
                     "out/current/Address.sol/Address.json",
                     "artifacts/current-graph/compiled/manifest.json"]
            for relative in files:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"retained input")
            rehearsal = resume.Rehearsal.__new__(resume.Rehearsal)
            rehearsal.project = root
            rehearsal.args = resume.argparse.Namespace(out="out/current")
            inventory = rehearsal.inventory()
            self.assertEqual(set(inventory), set(files))
            self.assertEqual(inventory["smart-contracts/vendor/openzeppelin/Address.sol"],
                             resume.sha(root / "smart-contracts/vendor/openzeppelin/Address.sol"))

    def test_receipt_waits_for_mining_and_does_not_retry_reverts(self):
        from unittest.mock import patch
        rehearsal = resume.Rehearsal.__new__(resume.Rehearsal)
        for replies, expected_polls in [([None, {"status": "0x1"}], 2), ([{"status": "0x0"}], 1)]:
            iterator = iter(replies)
            rehearsal.rpc = lambda method, params: next(iterator)
            with patch.object(resume.time, "sleep", return_value=None):
                receipt, polls = rehearsal.transaction_receipt("0x" + "12" * 32)
            self.assertEqual(receipt, replies[-1])
            self.assertEqual(polls, expected_polls)

    def test_standard_ethereum_selector_and_domain_use_keccak(self):
        self.assertEqual(resume.domain("transfer(address,uint256)")[:4].hex(), "a9059cbb")
        self.assertEqual(resume.domain("").hex(), "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")


if __name__ == "__main__":
    unittest.main(verbosity=2)
