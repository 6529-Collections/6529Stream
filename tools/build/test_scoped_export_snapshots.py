"""Synthetic scope-snapshot regressions; no compiler or actual capture mutation."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools.build import scoped_standard_json as scoped


def contract(ident, name):
    return {"id": ident, "nodeType": "ContractDefinition", "name": name,
            "contractKind": "contract", "abstract": False, "contractDependencies": [], "nodes": []}


def imported(ident, target, source_unit, *, aliases=(), unit=""):
    return {"id": ident, "nodeType": "ImportDirective", "absolutePath": target,
            "sourceUnit": source_unit, "symbolAliases": copy.deepcopy(list(aliases)), "unitAlias": unit}


def alias(ident, foreign, declaration, local=None):
    result = {"foreign": {"id": ident, "name": foreign, "nodeType": "Identifier",
                          "referencedDeclaration": declaration, "overloadedDeclarations": []}}
    if local is not None:
        result["local"] = local
    return result


def cycle_fixture():
    """Literal independent oracle: A/B cycle changes Host's inherited Alias only."""
    asts = {
        "A.sol": {"id": 100, "nodeType": "SourceUnit", "absolutePath": "A.sol", "nodes": [
            imported(101, "B.sol", 200), contract(10, "A")]},
        "B.sol": {"id": 200, "nodeType": "SourceUnit", "absolutePath": "B.sol", "nodes": [
            imported(201, "A.sol", 100),
            imported(202, "C.sol", 300, aliases=[alias(203, "C", 30, "Alias"), alias(204, "C", 30)]),
            imported(70, "C.sol", 300, unit="Ns"), contract(20, "B")]},
        "C.sol": {"id": 300, "nodeType": "SourceUnit", "absolutePath": "C.sol", "nodes": [contract(30, "C")]},
        "Host.sol": {"id": 400, "nodeType": "SourceUnit", "absolutePath": "Host.sol", "nodes": [
            imported(401, "C.sol", 300, aliases=[alias(402, "C", 30)]),
            imported(403, "A.sol", 100), contract(40, "Host")]},
    }
    all_exports = {
        "A.sol": {"A": [10], "B": [20], "Ns": [70], "Alias": [30], "C": [30]},
        "B.sol": {"B": [20], "Ns": [70], "A": [10], "Alias": [30], "C": [30]},
        "C.sol": {"C": [30]},
        "Host.sol": {"Host": [40], "C": [30], "A": [10], "B": [20], "Ns": [70], "Alias": [30]},
    }
    selected_exports = copy.deepcopy(all_exports)
    selected_exports["A.sol"] = {"A": [10], "B": [20], "Ns": [70]}
    del selected_exports["Host.sol"]["Alias"]
    for source, ast in asts.items():
        ast["exportedSymbols"] = copy.deepcopy(all_exports[source])
    return asts, all_exports, selected_exports


def pair_fixture():
    asts, _, selected_exports = cycle_fixture()
    request = {"language": "Solidity", "sources": {
        source: {"content": "pragma solidity 0.8.19; // SYNTHETIC " + source}
        for source in asts}, "settings": {
            "viaIR": True, "optimizer": {"enabled": True, "runs": 200}, "evmVersion": "paris",
            "outputSelection": {"B.sol": {"B": ["abi", "evm.bytecode", "evm.deployedBytecode"]},
                                "Host.sol": {"Host": ["abi", "evm.bytecode", "evm.deployedBytecode"]}}}}
    ai, ni = scoped.split_request(request)
    ao = {"sources": {s: {"id": i, "ast": copy.deepcopy(ast)} for i, (s, ast) in enumerate(asts.items())}}
    no = {"sources": {s: {"id": row["id"]} for s, row in ao["sources"].items()}, "contracts": {}}
    for source, name in (("B.sol", "B"), ("Host.sol", "Host")):
        no["sources"][source]["ast"] = copy.deepcopy(asts[source])
        no["sources"][source]["ast"]["exportedSymbols"] = copy.deepcopy(selected_exports[source])
        no["contracts"][source] = {name: {"abi": [], "evm": {
            "bytecode": {"object": "00", "linkReferences": {}},
            "deployedBytecode": {"object": "00", "linkReferences": {}, "immutableReferences": {}}}}}
    return ai, ao, ni, no


class SourceOrderExportsTests(unittest.TestCase):
    def setUp(self):
        self.asts, self.all_exports, self.selected_exports = cycle_fixture()

    def test_sorted_all_roots_reproduce_literal_cycle_snapshot(self):
        before = copy.deepcopy(self.asts)
        self.assertEqual(scoped.source_order_exports(self.asts, set(self.asts)), self.all_exports)
        self.assertEqual(self.asts, before)

    def test_selected_roots_reverse_cycle_and_snapshot_once(self):
        result = scoped.source_order_exports(self.asts, {"B.sol", "Host.sol"})
        self.assertEqual(result, self.selected_exports)
        self.assertNotIn("Alias", result["A.sol"])
        self.assertIn("Alias", result["B.sol"])
        self.assertNotIn("Alias", result["Host.sol"])

    def test_root_and_source_mapping_insertion_orders_do_not_change_cpp_map_order(self):
        reversed_asts = dict(reversed(list(self.asts.items())))
        self.assertEqual(scoped.source_order_exports(reversed_asts, ["Host.sol", "B.sol"]), self.selected_exports)

    def test_alias_names_can_legitimately_share_one_declaration_id(self):
        result = scoped.source_order_exports(self.asts, set(self.asts))
        self.assertEqual(result["Host.sol"]["C"], [30])
        self.assertEqual(result["Host.sol"]["Alias"], [30])

    def test_repeated_same_alias_import_does_not_duplicate_id_within_value(self):
        self.asts["B.sol"]["nodes"].insert(2, imported(205, "C.sol", 300, aliases=[alias(206, "C", 30, "Alias")]))
        self.assertEqual(scoped.source_order_exports(self.asts, set(self.asts)), self.all_exports)

    def test_unit_alias_registers_import_id_without_flattening_target(self):
        asts = {"C.sol": self.asts["C.sol"], "Unit.sol": {
            "id": 500, "nodeType": "SourceUnit", "absolutePath": "Unit.sol",
            "nodes": [imported(501, "C.sol", 300, unit="OnlyNamespace"), contract(50, "Unit")]}}
        result = scoped.source_order_exports(asts, {"Unit.sol"})
        self.assertEqual(result["Unit.sol"], {"OnlyNamespace": [501], "Unit": [50]})

    def test_unknown_root_or_import_target_refuses(self):
        with self.assertRaises(ValueError):
            scoped.source_order_exports(self.asts, {"Unknown.sol"})
        self.asts["A.sol"]["nodes"][0]["absolutePath"] = "Unknown.sol"
        with self.assertRaises(ValueError):
            scoped.source_order_exports(self.asts, set(self.asts))

    def test_source_unit_id_must_match_exact_import_target(self):
        self.asts["A.sol"]["nodes"][0]["sourceUnit"] = 300
        with self.assertRaises(ValueError):
            scoped.source_order_exports(self.asts, set(self.asts))

    def test_named_alias_reference_id_must_match_resolved_declaration(self):
        self.asts["B.sol"]["nodes"][1]["symbolAliases"][0]["foreign"]["referencedDeclaration"] = 20
        with self.assertRaises(ValueError):
            scoped.source_order_exports(self.asts, set(self.asts))

    def test_unknown_named_foreign_symbol_refuses(self):
        self.asts["B.sol"]["nodes"][1]["symbolAliases"][0]["foreign"]["name"] = "Unknown"
        with self.assertRaises(ValueError):
            scoped.source_order_exports(self.asts, set(self.asts))

    def test_different_declarations_colliding_under_one_alias_refuse(self):
        self.asts["B.sol"]["nodes"].append(contract(21, "Alias"))
        with self.assertRaises(ValueError):
            scoped.source_order_exports(self.asts, set(self.asts))

    def test_unknown_top_level_node_kind_refuses(self):
        self.asts["C.sol"]["nodes"].append({"id": 31, "nodeType": "FutureDeclaration", "name": "Unknown"})
        with self.assertRaises(ValueError):
            scoped.source_order_exports(self.asts, set(self.asts))


class ExportSnapshotPairTests(unittest.TestCase):
    def setUp(self):
        self.ai, self.ao, self.ni, self.no = pair_fixture()

    def verify(self):
        return scoped.verify_pair(self.ai, self.ao, self.ni, self.no)

    def test_exact_reproduced_difference_has_report_without_ast_replacement(self):
        before = copy.deepcopy((self.ai, self.ao, self.ni, self.no))
        result = self.verify()
        self.assertTrue(result["exportedSymbolSnapshots"])
        self.assertEqual((self.ai, self.ao, self.ni, self.no), before)
        self.assertNotIn("Alias", self.no["sources"]["Host.sol"]["ast"]["exportedSymbols"])
        self.assertEqual(result["immutableJoins"], [])

    def test_equal_asts_retain_old_report_shape(self):
        for source, row in self.no["sources"].items():
            if "ast" in row:
                row["ast"] = copy.deepcopy(self.ao["sources"][source]["ast"])
        self.assertNotIn("exportedSymbolSnapshots", self.verify())

    def test_arbitrary_removed_export_is_not_a_general_waiver(self):
        self.verify()
        del self.no["sources"]["Host.sol"]["ast"]["exportedSymbols"]["Host"]
        with self.assertRaises(ValueError):
            self.verify()

    def test_shared_symbol_changed_value_refuses(self):
        self.verify()
        self.no["sources"]["Host.sol"]["ast"]["exportedSymbols"]["C"] = [20]
        with self.assertRaises(ValueError):
            self.verify()

    def test_fabricated_analysis_only_alias_refuses(self):
        self.verify()
        self.ao["sources"]["Host.sol"]["ast"]["exportedSymbols"]["MadeUp"] = [30]
        with self.assertRaises(ValueError):
            self.verify()

    def test_analysis_alias_wrong_id_refuses(self):
        self.verify()
        self.ao["sources"]["Host.sol"]["ast"]["exportedSymbols"]["Alias"] = [20]
        with self.assertRaises(ValueError):
            self.verify()

    def test_extra_duplicate_id_in_export_value_refuses(self):
        self.verify()
        self.no["sources"]["Host.sol"]["ast"]["exportedSymbols"]["C"] = [30, 30]
        with self.assertRaises(ValueError):
            self.verify()

    def test_analysis_table_in_unselected_source_is_also_authenticated(self):
        self.verify()
        self.ao["sources"]["C.sol"]["ast"]["exportedSymbols"]["C"] = [20]
        with self.assertRaises(ValueError):
            self.verify()

    def test_changed_native_import_alias_or_node_id_refuses(self):
        self.verify()
        for field, value in (("id", 999), ("sourceUnit", 999), ("absolutePath", "B.sol")):
            original = copy.deepcopy(self.no)
            with self.subTest(field=field):
                self.no["sources"]["Host.sol"]["ast"]["nodes"][0][field] = value
                with self.assertRaises(ValueError):
                    self.verify()
                self.no = original

    def test_other_source_unit_metadata_change_refuses(self):
        self.verify()
        self.no["sources"]["Host.sol"]["ast"]["experimentalSolidity"] = True
        with self.assertRaises(ValueError):
            self.verify()

    def test_both_ast_local_changes_cannot_escape_recomputed_exports(self):
        self.verify()
        for output in (self.ao, self.no):
            output["sources"]["Host.sol"]["ast"]["nodes"][-1]["id"] = 99
        with self.assertRaises(ValueError):
            self.verify()

    def test_matching_wrong_alias_ref_in_both_asts_still_refuses(self):
        self.verify()
        for output in (self.ao, self.no):
            output["sources"]["B.sol"]["ast"]["nodes"][1]["symbolAliases"][0]["foreign"]["referencedDeclaration"] = 20
        with self.assertRaises(ValueError):
            self.verify()

    def test_import_snapshot_analysis_cannot_supply_native_immutable_declaration(self):
        self.verify()
        self.ao["sources"]["C.sol"]["ast"]["nodes"][0]["nodes"].append({
            "nodeType": "VariableDeclaration", "id": 31, "name": "onlyAnalysis", "mutability": "immutable"})
        runtime = self.no["contracts"]["Host.sol"]["Host"]["evm"]["deployedBytecode"]
        runtime["object"] = "00" * 32
        runtime["immutableReferences"] = {"31": [{"start": 0, "length": 32}]}
        with self.assertRaisesRegex(ValueError, "Missing same-native immutable declaration 31"):
            self.verify()


class AstFailureAdmissionTests(unittest.TestCase):
    """Synthetic failed-capture readmission; all subprocess entry points forbidden."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.capture = self.root / "capture"
        self.capture.mkdir()
        self.receipt = self.root / "admission.json"
        ai, ao, ni, no = pair_fixture()
        values = {"requested-input.json": ni, "selection.json": ni["settings"]["outputSelection"],
                  "analysis-input.json": ai, "analysis-output.json": ao,
                  "codegen-input.json": ni, "codegen-output.json": no}
        for name, value in values.items():
            (self.capture / name).write_bytes(scoped.canonical(value))
        (self.capture / "version.stdout").write_bytes(scoped.VERSION.encode())
        for name in ("version.stderr", "analysis-stderr.log", "codegen-stderr.log"):
            (self.capture / name).write_bytes(b"")
        self.record = {"schema": 1, "status": "FAILED", "toolSha256": scoped.LEGACY_SELECTOR_TOOL,
                       "error": "Native AST differs from analysis: Host.sol",
                       "compiler": str(self.root / "SYNTHETIC-NOT-EXECUTABLE"),
                       "compilerSha256": "12" * 32, "arguments": ["--standard-json"], "passes": {}}
        for name in ("analysis", "codegen"):
            self.record["passes"][name] = {"status": "COMPLETE", "exitCode": 0,
                "compilerSha256": self.record["compilerSha256"],
                "command": [self.record["compiler"], "--standard-json"]}
        self.rehash_record()
        for method in ("run", "Popen"):
            patcher = mock.patch.object(scoped.subprocess, method, side_effect=AssertionError("No compiler authorized"))
            patcher.start()
            self.addCleanup(patcher.stop)

    def rehash_record(self):
        self.record["files"] = {p.name: scoped.sha(p.read_bytes()) for p in self.capture.iterdir()
                                if p.is_file() and p.name != "record.json"}
        (self.capture / "record.json").write_bytes(scoped.canonical(self.record))

    def snapshot(self):
        return {p.name: p.read_bytes() for p in self.capture.iterdir() if p.is_file()}

    def mutate_native(self, change):
        path = self.capture / "codegen-output.json"
        output = json.loads(path.read_bytes())
        change(output)
        path.write_bytes(scoped.canonical(output))
        # Deliberately update the synthetic file hash: this tests semantic
        # revalidation, rather than merely exercising changed-file rejection.
        self.rehash_record()

    def test_explicit_old_ast_failure_admits_reproduced_snapshots_without_mutation(self):
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "not verified"):
            scoped.read_capture(self.capture)
        receipt = scoped.admit_completed_capture(self.capture, self.receipt)
        self.assertEqual(receipt["originalCaptureStatus"], "FAILED")
        self.assertEqual(receipt["originalError"], self.record["error"])
        self.assertEqual(len(receipt["verification"]["exportedSymbolSnapshots"]["differences"]), 1)
        analysis, native, record = scoped.read_capture(self.capture, admission=self.receipt)
        self.assertEqual(record["status"], "FAILED")
        self.assertIn("Alias", analysis["output"]["sources"]["Host.sol"]["ast"]["exportedSymbols"])
        self.assertNotIn("Alias", native["output"]["sources"]["Host.sol"]["ast"]["exportedSymbols"])
        self.assertEqual(self.snapshot(), before)

    def test_old_ast_error_cannot_admit_wrong_export_table(self):
        def change(output):
            output["sources"]["Host.sol"]["ast"]["exportedSymbols"]["C"] = [20]
        self.mutate_native(change)
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "Native exported-symbol snapshot differs"):
            scoped.admit_completed_capture(self.capture, self.receipt)
        self.assertFalse(self.receipt.exists())
        self.assertEqual(self.snapshot(), before)

    def test_old_ast_error_cannot_admit_non_export_ast_change(self):
        def change(output):
            output["sources"]["Host.sol"]["ast"]["nodes"][-1]["id"] = 99
        self.mutate_native(change)
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "Native AST differs from analysis"):
            scoped.admit_completed_capture(self.capture, self.receipt)
        self.assertFalse(self.receipt.exists())
        self.assertEqual(self.snapshot(), before)

    def test_error_label_without_actual_snapshot_difference_cannot_admit(self):
        analysis = json.loads((self.capture / "analysis-output.json").read_bytes())
        def change(output):
            output["sources"]["Host.sol"]["ast"] = copy.deepcopy(analysis["sources"]["Host.sol"]["ast"])
        self.mutate_native(change)
        with self.assertRaisesRegex(ValueError, "Known compiler verifier difference was not verified"):
            scoped.admit_completed_capture(self.capture, self.receipt)
        self.assertFalse(self.receipt.exists())


if __name__ == "__main__":
    unittest.main()
