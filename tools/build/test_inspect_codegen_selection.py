"""Pure JSON tests for the informational Solidity codegen selector inspector."""
from __future__ import annotations

import unittest

from tools.build.inspect_codegen_selection import SelectionError, inspect_selection


def definition(name, *, kind="contract", abstract=False, functions=()):
    return {
        "nodeType": "ContractDefinition",
        "name": name,
        "contractKind": kind,
        "abstract": abstract,
        "nodes": [
            {"nodeType": "FunctionDefinition", "visibility": visibility}
            for visibility in functions
        ],
    }


def inputs(nodes_by_source, selection):
    analysis_output = {
        "sources": {
            source: {"ast": {"nodes": nodes}}
            for source, nodes in nodes_by_source.items()
        }
    }
    codegen_input = {
        "sources": {source: {"content": "synthetic"} for source in nodes_by_source},
        "settings": {"outputSelection": selection},
    }
    return analysis_output, codegen_input


class SelectionInspectionTests(unittest.TestCase):
    def test_named_binary_target_and_ast_siblings(self):
        analysis, codegen = inputs(
            {"Core.sol": [
                definition("Core"),
                definition("Sibling"),
                definition("AbstractSibling", abstract=True),
                definition("MathLib", kind="library"),
            ]},
            {"Core.sol": {
                "": ["ast"],
                "Core": ["abi", "evm.bytecode"],
            }},
        )
        report = inspect_selection(analysis, codegen)
        row = report["sources"][0]
        self.assertEqual(row["namedBinarySelectors"], [
            {"name": "Core", "fields": ["abi", "evm.bytecode"]}
        ])
        self.assertEqual(row["implicitSiblingConcreteContractNames"], ["MathLib", "Sibling"])
        self.assertEqual(row["implicitSiblingCount"], 2)
        self.assertEqual(row["expandedConcreteHostCount"], 2)
        self.assertEqual(row["expandedLibraryCount"], 1)
        classifications = {
            item["name"]: item["classification"]
            for item in row["expandedDefinitions"]
        }
        self.assertEqual(classifications["Core"], "concrete-host")
        self.assertEqual(classifications["MathLib"], "implicit-internal-only-library")
        self.assertNotIn("AbstractSibling", classifications)

    def test_ast_expansion_excludes_abstract_contracts_and_interfaces(self):
        analysis, codegen = inputs(
            {"Types.sol": [
                definition("AbstractBase", abstract=True),
                definition("IThing", kind="interface"),
                definition("Concrete"),
            ]},
            {"Types.sol": {"": ["ast"]}},
        )
        row = inspect_selection(analysis, codegen)["sources"][0]
        self.assertEqual(row["implicitSiblingConcreteContractNames"], ["Concrete"])
        self.assertEqual(row["implicitSiblingCount"], 1)
        self.assertEqual(row["expandedConcreteHostCount"], 1)
        self.assertEqual([item["name"] for item in row["expandedDefinitions"]], ["Concrete"])

    def test_source_and_contract_wildcards_report_all_sources(self):
        analysis, codegen = inputs(
            {"A.sol": [definition("A")], "B.sol": [definition("B"), definition("B2")]},
            {"*": {"": ["ast"], "*": ["evm.bytecode"]}},
        )
        report = inspect_selection(analysis, codegen)
        self.assertEqual(report["requestedSourceSelector"], "*")
        self.assertEqual(report["sourceCount"], 2)
        self.assertEqual([row["source"] for row in report["sources"]], ["A.sol", "B.sol"])
        self.assertEqual([row["explicitContractNames"] for row in report["sources"]],
                         [["A"], ["B", "B2"]])
        self.assertTrue(all(not row["namedBinarySelectors"] for row in report["sources"]))
        self.assertTrue(all(row["wildcardBinaryFields"] == ["evm.bytecode"]
                            for row in report["sources"]))

    def test_named_contract_missing_from_analysis_ast_fails_explicitly(self):
        analysis, codegen = inputs(
            {"Core.sol": [definition("Core")]},
            {"Core.sol": {"Missing": ["evm.bytecode"]}},
        )
        with self.assertRaisesRegex(SelectionError, "requested contract absent"):
            inspect_selection(analysis, codegen)

    def test_malformed_contract_fields_fail_explicitly(self):
        analysis, codegen = inputs({"Core.sol": [definition("Core")]},
                                   {"Core.sol": {"Core": "evm.bytecode"}})
        with self.assertRaisesRegex(SelectionError, "invalid output fields"):
            inspect_selection(analysis, codegen)


if __name__ == "__main__":
    unittest.main()
