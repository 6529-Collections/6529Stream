"""Behavioral rejection controls for the fixture-only artifact projector."""

import copy
import json
from pathlib import Path
import tempfile
import unittest

from native_assembly_artifacts import project


class ArtifactProjectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)
        self.source = "smart-contracts/Product.sol"
        self.ast = {"absolutePath": self.source, "nodes": [
            {"nodeType": "ContractDefinition", "name": "Product", "nodes": [
                {"nodeType": "VariableDeclaration", "mutability": "immutable", "name": "owner", "id": 7}
            ]}
        ]}
        code = {"object": "00" * 32, "linkReferences": {}}
        runtime = dict(code, immutableReferences={"7": [{"start": 0, "length": 32}]})
        metadata = {"settings": {"compilationTarget": {self.source: "Product"}}}
        self.contract = {"abi": [], "metadata": json.dumps(metadata), "storageLayout": {},
                         "evm": {"bytecode": code, "deployedBytecode": runtime, "methodIdentifiers": {}}}
        self.build = {"solcVersion": "0.8.19", "input": {"sources": {self.source: {"content": "original"}}},
                      "output": {"sources": {self.source: {"ast": self.ast}},
                                 "contracts": {self.source: {"Product": self.contract}}}}
        self.artifact = {"abi": [], "metadata": metadata, "rawMetadata": json.dumps(metadata),
                         "storageLayout": {}, "methodIdentifiers": {},
                         "ast": copy.deepcopy(self.ast), "bytecode": copy.deepcopy(code),
                         "deployedBytecode": copy.deepcopy(runtime)}

    def run_projection(self):
        build = self.root / "build.json"
        build.write_text(json.dumps(self.build), encoding="utf-8")
        out = self.root / "out" / "Product.sol"
        out.mkdir(parents=True)
        (out / "Product.json").write_text(json.dumps(self.artifact), encoding="utf-8")
        return project(build, self.root / "out", self.root / "projected", {"Product": self.source})

    def test_exact_creation_runtime_ranges_and_qualified_declaration(self):
        report = self.run_projection()
        projected = json.loads((self.root / "projected" / "Product.json").read_bytes())
        self.assertEqual(projected["bytecode"]["object"], "0x" + "00" * 32)
        self.assertEqual(projected["deployedBytecode"]["immutableReferences"],
                         {"7": [{"start": 0, "length": 32}]})
        declaration = projected["immutableDeclarations"]["7"]
        self.assertEqual((declaration["source"], declaration["contractName"], declaration["variable"]),
                         (self.source, "Product", "owner"))
        self.assertEqual(declaration["compilationHash"], report["compilerInputSha256"])

    def test_altered_complete_bytecode_rejects(self):
        self.artifact["bytecode"]["object"] = "ff" + "00" * 31
        with self.assertRaises(AssertionError):
            self.run_projection()

    def test_altered_link_ranges_reject(self):
        self.artifact["bytecode"]["linkReferences"] = {"Lib.sol": {"Lib": [{"start": 0, "length": 20}]}}
        with self.assertRaises(AssertionError):
            self.run_projection()

    def test_unresolved_native_immutable_rejects(self):
        self.contract["evm"]["deployedBytecode"]["immutableReferences"] = {"8": [{"start": 0, "length": 32}]}
        self.artifact["deployedBytecode"] = copy.deepcopy(self.contract["evm"]["deployedBytecode"])
        with self.assertRaises(AssertionError):
            self.run_projection()

    def test_overlapping_native_immutable_ranges_reject(self):
        self.contract["evm"]["deployedBytecode"]["immutableReferences"]["7"].append({"start": 0, "length": 32})
        self.artifact["deployedBytecode"] = copy.deepcopy(self.contract["evm"]["deployedBytecode"])
        with self.assertRaises(AssertionError):
            self.run_projection()

    def test_duplicate_native_declarations_reject(self):
        self.ast["nodes"][0]["nodes"].append(copy.deepcopy(self.ast["nodes"][0]["nodes"][0]))
        with self.assertRaises(AssertionError):
            self.run_projection()

    def test_mixed_compilation_physical_ast_rejects(self):
        self.artifact["ast"]["nodes"][0]["nodes"][0]["id"] = 99
        with self.assertRaises(AssertionError):
            self.run_projection()

    def test_wrong_original_target_rejects(self):
        self.artifact["metadata"]["settings"]["compilationTarget"] = {self.source: "Other"}
        with self.assertRaises(AssertionError):
            self.run_projection()

    def test_oversized_production_runtime_rejects(self):
        self.contract["evm"]["deployedBytecode"]["object"] = "00" * 24577
        with self.assertRaises(AssertionError):
            self.run_projection()


if __name__ == "__main__":
    unittest.main()
