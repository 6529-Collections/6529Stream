"""The local ERC20 fixture must not depend on or alter production build output."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.deployment import prepare_current_stack_test_token as token


class TestTokenPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve() / "repo"
        (self.root / token.SOURCE).parent.mkdir(parents=True)
        (self.root / token.SOURCE).write_bytes(b"pragma solidity ^0.8.19; contract MockStreamPaymentToken {}\n")
        self.production = self.root / "retained-out"
        self.production.mkdir()
        (self.production / "retained.json").write_bytes(b"retained production compilation\n")
        self.destination = Path(self.temporary.name).resolve() / "scenario/test-token-compilation"
        self.commands = []

    def compiler(self, command, **kwargs):
        self.commands.append(command)
        if command == ["forge", "--version"]:
            return subprocess.CompletedProcess(command, 0, "forge Version: 1.7.1\n")
        self.assertEqual(Path(kwargs["cwd"]), self.destination)
        self.assertNotIn("FOUNDRY_OUT", kwargs["env"])
        source = (self.destination / token.SOURCE).read_text(encoding="utf-8")
        evm = {"bytecode": {"object": "6000", "linkReferences": {}},
               "deployedBytecode": {"object": "6001", "linkReferences": {}, "immutableReferences": {}}}
        settings = {"optimizer": {"enabled": True, "runs": 200},
                    "metadata": {"useLiteralContent": False, "bytecodeHash": "none", "appendCBOR": False},
                    "evmVersion": "paris", "viaIR": True, "libraries": {}, "outputSelection": {}}
        info = {"solcVersion": "0.8.19", "input": {"language": "Solidity", "sources": {token.SOURCE: {"content": source}}, "settings": settings},
                "output": {"contracts": {token.SOURCE: {token.CONTRACT: {"abi": [], "evm": evm}}}}}
        artifact = {"abi": [], **{key: {**value, "object": "0x" + value["object"]} for key, value in evm.items()}}
        (self.destination / token.ARTIFACT).parent.mkdir(parents=True)
        (self.destination / token.ARTIFACT).write_bytes(token.encoded(artifact))
        (self.destination / "out/build-info").mkdir()
        (self.destination / "out/build-info/one.json").write_bytes(token.encoded(info))
        return subprocess.CompletedProcess(command, 0)

    def prepare(self):
        with mock.patch.object(token.subprocess, "run", side_effect=self.compiler):
            return token.prepare(self.root, self.destination, self.production)

    def test_missing_production_mock_prepares_and_reuses_isolated_source_bound_artifact(self):
        missing = self.production / f"{token.CONTRACT}.sol/{token.CONTRACT}.json"
        with self.assertRaises(FileNotFoundError):
            missing.read_bytes()  # The former scenario lookup fails on --skip test output.
        before = {p.name: p.read_bytes() for p in self.production.iterdir()}
        first = self.prepare()
        self.assertEqual(Path(first["artifact_path"]), self.destination / token.ARTIFACT)
        self.assertEqual(first, self.prepare())
        self.assertEqual(sum(command[1] == "build" for command in self.commands), 1)
        self.assertEqual({p.name: p.read_bytes() for p in self.production.iterdir()}, before)
        self.assertFalse(missing.exists())

    def test_source_drift_does_not_relabel_retained_compilation(self):
        self.prepare()
        original = (self.destination / "test-token-compilation.json").read_bytes()
        (self.root / token.SOURCE).write_bytes(b"contract Changed {}")
        with self.assertRaisesRegex(ValueError, "source differs"):
            self.prepare()
        self.assertEqual((self.destination / "test-token-compilation.json").read_bytes(), original)

    def test_artifact_or_provenance_tampering_rejects_reuse(self):
        self.prepare()
        artifact_path = self.destination / token.ARTIFACT
        original = artifact_path.read_bytes()
        artifact = json.loads(original)
        artifact["deployedBytecode"]["object"] = "0x6002"
        artifact_path.write_bytes(token.encoded(artifact))
        with self.assertRaisesRegex(ValueError, "bytecode differs"):
            self.prepare()
        artifact_path.write_bytes(original)
        manifest = self.destination / "test-token-compilation.json"
        data = json.loads(manifest.read_bytes())
        data["source_sha256"] = "0" * 64
        manifest.write_bytes(token.encoded(data))
        with self.assertRaisesRegex(ValueError, "binding differs"):
            self.prepare()

    def test_wrong_settings_and_extra_compiler_sources_reject(self):
        self.prepare()
        path = self.destination / "out/build-info/one.json"
        original = path.read_bytes()
        info = json.loads(original)
        info["input"]["settings"]["optimizer"]["runs"] = 201
        path.write_bytes(token.encoded(info))
        with self.assertRaisesRegex(ValueError, "settings differ"):
            self.prepare()
        info = json.loads(original)
        info["input"]["sources"]["other.sol"] = {"content": "contract Other {}"}
        path.write_bytes(token.encoded(info))
        with self.assertRaisesRegex(ValueError, "other sources"):
            self.prepare()

    def test_output_overlap_rejects_before_compiler_or_writes(self):
        for destination in (self.production, self.production / "nested", self.root):
            with mock.patch.object(token.subprocess, "run") as compiler:
                with self.assertRaisesRegex(ValueError, "overlaps"):
                    token.prepare(self.root, destination, self.production)
                compiler.assert_not_called()

    def test_child_environment_preserves_caller_and_excludes_foundry_overrides(self):
        with mock.patch.dict(os.environ, {"FOUNDRY_OUT": "retained", "FOUNDRY_PROFILE": "current", "DAPP_TEST": "other", "SCENARIO_TEST_MARKER": "keep"}):
            before = dict(os.environ)
            self.prepare()
            self.assertEqual(dict(os.environ), before)
            self.assertEqual(token.child_environment()["SCENARIO_TEST_MARKER"], "keep")
            self.assertNotIn("DAPP_TEST", token.child_environment())

    def test_failed_compile_retains_log_without_publishing_binding(self):
        def fail(command, **kwargs):
            if command[1] == "--version":
                return subprocess.CompletedProcess(command, 0, "forge Version: 1.7.1\n")
            kwargs["stdout"].write(b"precise compiler failure\n")
            return subprocess.CompletedProcess(command, 1)
        with mock.patch.object(token.subprocess, "run", side_effect=fail):
            with self.assertRaisesRegex(ValueError, "compilation failed"):
                token.prepare(self.root, self.destination, self.production)
        self.assertFalse((self.destination / "test-token-compilation.json").exists())
        self.assertEqual((self.destination / "build.log").read_bytes(), b"precise compiler failure\n")


if __name__ == "__main__":
    unittest.main()
