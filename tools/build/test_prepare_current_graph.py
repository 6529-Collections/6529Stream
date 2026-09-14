"""Reject stale or ambiguous native graph input before producing fixture files."""
import copy
import os
import tempfile
import unittest
from pathlib import Path

from tools.build.prepare_current_graph import CAMPAIGN_HOSTS, CREATION_NAME, CREATION_SOURCE, check_campaign_owner, select_build, validate_sources


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

    def test_campaign_uses_executed_host_context_instead_of_unrelated_current_suite(self):
        source, name = CAMPAIGN_HOSTS[0]
        cache = {"files": {source: {"artifacts": {name: {"0.8.19": {
            "current": {"path": Path(source).name + "/" + name + ".json", "build_id": "campaign"}}}}},
            "test/current/StreamCurrentStack.t.sol": {"artifacts": {
                "StreamCurrentStackTest": {"0.8.19": {"current": {
                    "path": "StreamCurrentStack.t.sol/StreamCurrentStackTest.json", "build_id": "unrelated"}}}}}}}
        self.assertEqual(select_build(cache), "unrelated")
        self.assertEqual(select_build(cache, CAMPAIGN_HOSTS), "campaign")
        del cache["files"][source]
        with self.assertRaises(ValueError):
            select_build(cache, CAMPAIGN_HOSTS)

    def test_only_the_active_campaign_child_can_prepare_shared_inputs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            lease = root / "cache/current-graph.campaign.lock"
            lease.parent.mkdir()
            check_campaign_owner(root, False)
            lease.write_text(str(os.getppid()), encoding="ascii")
            check_campaign_owner(root, True)
            with self.assertRaises(ValueError):
                check_campaign_owner(root, False)
            lease.write_text("different-owner", encoding="ascii")
            with self.assertRaises(ValueError):
                check_campaign_owner(root, True)

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
