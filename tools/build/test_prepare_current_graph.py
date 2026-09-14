"""Reject stale or ambiguous native graph input before producing fixture files."""
import copy
import tempfile
import unittest
from pathlib import Path

from tools.build.prepare_current_graph import CREATION_NAME, CREATION_SOURCE, select_build, validate_sources


class CurrentGraphInputsTests(unittest.TestCase):
    def test_cache_selects_current_graph_host_instead_of_unchanged_creation_library(self):
        source = "test/current/StreamNativeFinalityAssembly.t.sol"
        name = "StreamNativeFinalityAssemblyTest"
        entries = {"default": {"path": "StreamNativeFinalityAssembly.t.sol/" + name + ".json", "build_id": "a1"}}
        cache = {"files": {source: {"artifacts": {name: {"0.8.19": entries}}},
                           CREATION_SOURCE: {"artifacts": {CREATION_NAME: {"0.8.19": {"default": {
                               "path": "StreamNativeAssemblyCreation.sol/StreamNativeAssemblyCreation.json",
                               "build_id": "old"}}}}}}}
        self.assertEqual(select_build(cache), "a1")
        entries["other"] = dict(entries["default"], build_id="b2")
        with self.assertRaises(ValueError):
            select_build(cache)
        del cache["files"][source]
        with self.assertRaises(ValueError):
            select_build(cache)

    def test_changed_source_cannot_reuse_a_passing_old_build(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "Product.sol").write_bytes(b"original\n")
            build = {"solcVersion": "0.8.19", "input": {
                "settings": {"viaIR": True, "evmVersion": "paris", "optimizer": {"enabled": True, "runs": 200}},
                "sources": {"Product.sol": {"content": "original\n"}}}}
            self.assertEqual(validate_sources(root, build), [])
            (root / "Product.sol").write_bytes(b"changed\n")
            with self.assertRaises(ValueError):
                validate_sources(root, build)
            (root / "Product.sol").write_bytes(b"original\r\n")
            self.assertEqual(validate_sources(root, build), ["Product.sol"])
            wrong = copy.deepcopy(build)
            wrong["input"]["settings"]["viaIR"] = False
            with self.assertRaises(ValueError):
                validate_sources(root, wrong)
            wrong = copy.deepcopy(build)
            wrong["input"]["sources"] = {"../Product.sol": {"content": "original\n"}}
            with self.assertRaises(ValueError):
                validate_sources(root, wrong)


if __name__ == "__main__":
    unittest.main()
