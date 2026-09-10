#!/usr/bin/env python3
"""Behavioral tests for exporting an exact current deployment compilation."""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from tools.deployment import generate_current_stack_artifacts as exporter


def fixture(root: Path) -> tuple[Path, Path, dict]:
    contract = {"name": "Example", "source": "smart-contracts/core/Example.sol"}
    script = {"name": "Deploy", "source": "script/current/Deploy.sol"}
    config = {"schema_version": "6529stream.current-stack-targets.v1", "contracts": [contract], "interfaces": [], "deployment_script": script}
    config_path = root / "targets.json"
    config_path.write_bytes(exporter.encoded(config))
    settings = {
        "optimizer": {"enabled": True, "runs": 200},
        "viaIR": True,
        "evmVersion": "paris",
        "metadata": {"bytecodeHash": "none", "appendCBOR": False},
    }
    compiler_input = {"language": "Solidity", "sources": {}, "settings": settings}
    compiled = {}
    out = root / "out"
    for entry in (contract, script):
        source, name = entry["source"], entry["name"]
        content = f"pragma solidity ^0.8.19; contract {name} {{}}\n"
        path = root / source
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, newline="\n")
        compiler_input["sources"][source] = {"content": content}
        metadata = {"compiler": {"version": exporter.SOLC}, "settings": dict(settings, compilationTarget={source: name})}
        bytecode = {"object": "6001", "linkReferences": {}}
        compiled[source] = {name: {"abi": [], "metadata": json.dumps(metadata), "evm": {"bytecode": bytecode, "deployedBytecode": bytecode, "methodIdentifiers": {}}}}
        artifact = {"abi": [], "metadata": metadata, "bytecode": dict(bytecode, object="0x6001"), "deployedBytecode": dict(bytecode, object="0x6001"), "methodIdentifiers": {}}
        artifact_path = out / Path(source).name / f"{name}.json"
        artifact_path.parent.mkdir(parents=True)
        artifact_path.write_bytes(exporter.encoded(artifact))
    info = {"solcVersion": "0.8.19", "input": compiler_input, "output": {"contracts": compiled}}
    (out / "build-info").mkdir()
    (out / "build-info/one.json").write_bytes(exporter.encoded(info))
    return out, config_path, info


class CurrentStackArtifactTests(unittest.TestCase):
    def test_exact_full_compilation_exports_and_checks_without_rebuilding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, config, info = fixture(root)
            path = out / "Example.sol/Example.json"
            artifact = exporter.load(path)
            artifact["rawMetadata"] = json.dumps(artifact["metadata"])
            artifact["metadata"]["optional_foundry_field"] = None
            path.write_bytes(exporter.encoded(artifact))
            files = exporter.candidate_files(root, out, config)
            self.assertEqual(json.loads(files["compiler-input.json"]), info["input"])
            self.assertEqual(json.loads(files["manifest.json"])["targets"][0]["runtime_bytes"], 2)
            destination = root / "candidate"
            exporter.publish(files, destination, False)
            exporter.publish(files, destination, True)
            (destination / "artifacts/Example.json").write_bytes(b"wrong compilation")
            with self.assertRaisesRegex(exporter.CurrentArtifactError, "candidate is stale"):
                exporter.publish(files, destination, True)

    def test_target_isolated_or_mutated_artifact_cannot_substitute_for_full_build(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, config, info = fixture(root)
            info["output"]["contracts"].pop("script/current/Deploy.sol")
            (out / "build-info/one.json").write_bytes(exporter.encoded(info))
            with self.assertRaisesRegex(exporter.CurrentArtifactError, "no full build-info matches"):
                exporter.candidate_files(root, out, config)

    def test_legacy_settings_and_stale_source_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, config, info = fixture(root)
            changed = copy.deepcopy(info)
            changed["input"]["settings"]["viaIR"] = False
            (out / "build-info/one.json").write_bytes(exporter.encoded(changed))
            with self.assertRaisesRegex(exporter.CurrentArtifactError, "global viaIR"):
                exporter.candidate_files(root, out, config)
            (out / "build-info/one.json").write_bytes(exporter.encoded(info))
            (root / "smart-contracts/core/Example.sol").write_text("contract Changed {}")
            with self.assertRaisesRegex(exporter.CurrentArtifactError, "compiler source is stale"):
                exporter.candidate_files(root, out, config)

    def test_ambiguous_compilation_units_are_rejected_even_with_identical_runtime(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, config, info = fixture(root)
            info["input"]["sources"]["test/DifferentClosure.sol"] = {"content": "contract Different {}"}
            (out / "build-info/two.json").write_bytes(exporter.encoded(info))
            with self.assertRaisesRegex(exporter.CurrentArtifactError, "multiple distinct compiler inputs"):
                exporter.candidate_files(root, out, config)

    def test_runtime_limit_applies_to_selected_real_contract(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            out, config, info = fixture(root)
            oversized = "60" * (exporter.RUNTIME_LIMIT + 1)
            info["output"]["contracts"]["smart-contracts/core/Example.sol"]["Example"]["evm"]["deployedBytecode"] = {"object": oversized, "linkReferences": {}}
            (out / "build-info/one.json").write_bytes(exporter.encoded(info))
            path = out / "Example.sol/Example.json"
            artifact = exporter.load(path)
            artifact["deployedBytecode"]["object"] = "0x" + oversized
            path.write_bytes(exporter.encoded(artifact))
            with self.assertRaisesRegex(exporter.CurrentArtifactError, "EIP-170 limit"):
                exporter.candidate_files(root, out, config)


if __name__ == "__main__":
    unittest.main(verbosity=2)
