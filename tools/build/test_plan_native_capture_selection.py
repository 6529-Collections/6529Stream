"""Pure analysis tests for the informational native-capture selection planner."""
from __future__ import annotations

import copy
import unittest

from tools.build.inspect_codegen_selection import SelectionError
from tools.build.plan_native_capture_selection import plan_selection


def definition(ident, name, *, kind="contract", abstract=False, dependencies=(), bases=None,
               immutable=False):
    nodes = []
    if immutable:
        nodes.append({"nodeType": "VariableDeclaration", "id": ident + 1000,
                      "name": "pin", "mutability": "immutable"})
    return {
        "nodeType": "ContractDefinition", "id": ident, "name": name,
        "contractKind": kind, "abstract": abstract,
        "contractDependencies": list(dependencies),
        "linearizedBaseContracts": list(bases if bases is not None else [ident]),
        "nodes": nodes,
    }


def fixture():
    analysis = {"sources": {
        "src/Root.sol": {"ast": {"nodes": [
            definition(1, "Root", dependencies=[2], bases=[1, 3]),
            definition(4, "Sibling"),
        ]}},
        "src/Child.sol": {"ast": {"nodes": [
            definition(2, "Child", dependencies=[5]),
        ]}},
        "src/Base.sol": {"ast": {"nodes": [
            definition(3, "Base", abstract=True, immutable=True),
        ]}},
        "src/Grandchild.sol": {"ast": {"nodes": [
            definition(5, "Grandchild", kind="library"),
        ]}},
    }}
    codegen = {
        "language": "Solidity",
        "sources": {source: {"content": "synthetic"} for source in analysis["sources"]},
        "settings": {"outputSelection": {
            "src/Root.sol": {"Root": ["abi", "evm.bytecode.object"]},
        }},
    }
    return analysis, codegen


class NativeCaptureSelectionPlanTests(unittest.TestCase):
    def test_recursive_embedded_creation_closure_and_immutable_c3_owner(self):
        analysis, codegen = fixture()
        report = plan_selection(analysis, codegen, ["src/Root.sol:Root"])
        self.assertEqual(report["selectedRootProducts"], ["src/Root.sol:Root"])
        self.assertEqual(report["selectedProducts"], [
            "src/Child.sol:Child", "src/Grandchild.sol:Grandchild", "src/Root.sol:Root"])
        self.assertEqual(report["dependencyProducts"], [
            "src/Child.sol:Child", "src/Grandchild.sol:Grandchild"])
        self.assertEqual(report["nativeAstSources"], [
            "src/Base.sol", "src/Child.sol", "src/Grandchild.sol", "src/Root.sol"])
        selection = report["outputSelection"]
        self.assertEqual(selection["src/Root.sol"]["Root"], ["abi", "evm.bytecode.object"])
        self.assertEqual(selection["src/Child.sol"]["Child"], ["abi", "evm.bytecode.object"])
        self.assertEqual(selection["src/Grandchild.sol"]["Grandchild"],
                         ["abi", "evm.bytecode.object"])
        self.assertEqual(selection["src/Base.sol"], {"": ["ast"]})
        self.assertEqual(report["unselectedConcreteDefinitionsInAstSources"], [
            {"coordinate": "src/Root.sol:Sibling", "contractKind": "contract"}])
        self.assertIn("extracting tiny boundaries", report["sourceAstExpansionWarning"])

    def test_output_and_source_order_are_deterministic(self):
        analysis, codegen = fixture()
        reverse = copy.deepcopy(analysis)
        reverse["sources"] = dict(reversed(list(reverse["sources"].items())))
        reverse["sources"]["src/Root.sol"]["ast"]["nodes"].reverse()
        forward = plan_selection(analysis, codegen, ["src/Root.sol:Root"])
        backward = plan_selection(reverse, codegen, ["src/Root.sol:Root"])
        self.assertEqual(forward, backward)

    def test_duplicate_and_unknown_selected_coordinates_fail_closed(self):
        analysis, codegen = fixture()
        for selected in (["src/Root.sol:Root", "src/Root.sol:Root"],
                         ["src/Root.sol:Missing"], ["Root"]):
            with self.subTest(selected=selected), self.assertRaises(SelectionError):
                plan_selection(analysis, codegen, selected)

    def test_duplicate_unknown_ids_and_duplicate_coordinates_fail_closed(self):
        analysis, codegen = fixture()
        duplicated_id = copy.deepcopy(analysis)
        duplicated_id["sources"]["src/Child.sol"]["ast"]["nodes"][0]["id"] = 1
        with self.assertRaisesRegex(SelectionError, "duplicate contract declaration ID"):
            plan_selection(duplicated_id, codegen, ["src/Root.sol:Root"])

        unknown_dependency = copy.deepcopy(analysis)
        unknown_dependency["sources"]["src/Child.sol"]["ast"]["nodes"][0]["contractDependencies"] = [999]
        with self.assertRaisesRegex(SelectionError, "unknown dependency declaration ID"):
            plan_selection(unknown_dependency, codegen, ["src/Root.sol:Root"])

        duplicate_coordinate = copy.deepcopy(analysis)
        duplicate_coordinate["sources"]["src/Root.sol"]["ast"]["nodes"].append(
            definition(6, "Root"))
        with self.assertRaisesRegex(SelectionError, "duplicate contract coordinate"):
            plan_selection(duplicate_coordinate, codegen, ["src/Root.sol:Root"])

    def test_invalid_dependency_and_c3_references_fail_closed(self):
        analysis, codegen = fixture()
        abstract_child = copy.deepcopy(analysis)
        abstract_child["sources"]["src/Child.sol"]["ast"]["nodes"][0]["abstract"] = True
        with self.assertRaisesRegex(SelectionError, "contractDependency is not concrete"):
            plan_selection(abstract_child, codegen, ["src/Root.sol:Root"])

        missing_base = copy.deepcopy(analysis)
        missing_base["sources"]["src/Root.sol"]["ast"]["nodes"][0]["linearizedBaseContracts"] = [1, 999]
        with self.assertRaisesRegex(SelectionError, "unknown C3 base"):
            plan_selection(missing_base, codegen, ["src/Root.sol:Root"])


if __name__ == "__main__":
    unittest.main()
