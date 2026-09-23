"""Selector/capture unit tests with synthetic compiler JSON and no native execution."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

from tools.build import scoped_standard_json as scoped
from tools.build.prepare_current_graph import source_closure, validate_sources


FIELDS = ["abi", "metadata", "evm.bytecode", "evm.deployedBytecode"]


def fixture():
    """Small, explicitly synthetic AST/output boundary; not compiler evidence."""
    request = {
        "language": "Solidity",
        "sources": {
            "Base.sol": {"content": "pragma solidity 0.8.19; abstract contract Base { uint public immutable x; constructor(uint n) { x=n; } }"},
            "Child.sol": {"content": "pragma solidity 0.8.19; contract Child {}"},
            "Owner.sol": {"content": 'pragma solidity 0.8.19; import "./Base.sol"; import "./Child.sol"; contract Owner is Base { constructor() Base(1) {} function spawn() external returns(Child) { return new Child(); } } contract Sibling {}'},
            "Unused.sol": {"content": "pragma solidity 0.8.19; contract Unused {}"},
        },
        "settings": {
            "optimizer": {"enabled": True, "runs": 200},
            "viaIR": True,
            "evmVersion": "paris",
            "metadata": {"bytecodeHash": "none", "appendCBOR": False},
            "libraries": {},
            "outputSelection": {
                "*": {"": ["ast"]},
                "Base.sol": {"Base": ["abi"]},
                "Owner.sol": {"Owner": list(FIELDS)},
            },
        },
    }

    def contract(ident, name, *, abstract=False, dependencies=(), nodes=()):
        return {"id": ident, "nodeType": "ContractDefinition", "name": name,
                "abstract": abstract, "contractDependencies": list(dependencies), "nodes": list(nodes)}

    base = contract(10, "Base", abstract=True, nodes=[
        {"id": 11, "nodeType": "VariableDeclaration", "name": "x", "mutability": "immutable"}])
    owner = contract(20, "Owner", dependencies=[30])
    nodes = {"Base.sol": [base], "Child.sol": [contract(30, "Child")],
             "Owner.sol": [{"id": 22, "nodeType": "ImportDirective", "absolutePath": "Base.sol"},
                           {"id": 23, "nodeType": "ImportDirective", "absolutePath": "Child.sol"},
                           owner, contract(21, "Sibling")],
             "Unused.sol": [contract(40, "Unused")]}
    analysis_input, native_input = scoped.split_request(request, all_source_asts=False)
    analysis_output = {"sources": {
        name: {"id": ident, "ast": {"id": 100 + ident, "nodeType": "SourceUnit",
                                   "absolutePath": name, "nodes": copy.deepcopy(nodes[name])}}
        for ident, name in enumerate(sorted(nodes))}}
    native_output = {"sources": {
        name: copy.deepcopy(value) if name in ("Base.sol", "Owner.sol") else {"id": value["id"]}
        for name, value in analysis_output["sources"].items()},
        "contracts": {
            "Base.sol": {"Base": {"abi": []}},
            "Owner.sol": {"Owner": {
                "abi": [], "metadata": "{}", "evm": {
                    "bytecode": {"object": "00", "linkReferences": {}},
                    "deployedBytecode": {"object": "00" * 64, "linkReferences": {},
                                         "immutableReferences": {"11": [{"start": 16, "length": 32}]}}}}}}}
    return request, analysis_input, analysis_output, native_input, native_output


class SelectorTests(unittest.TestCase):
    def setUp(self):
        self.request, self.ai, self.ao, self.ni, self.no = fixture()

    def verify(self):
        return scoped.verify_pair(self.ai, self.ao, self.ni, self.no)

    def test_split_preserves_all_nonselection_inputs_without_aliasing(self):
        original = copy.deepcopy(self.request)
        analysis, native = scoped.split_request(self.request)
        for result in (analysis, native):
            self.assertEqual(scoped.without_selection(result), scoped.without_selection(original))
        self.assertEqual(analysis["settings"]["outputSelection"], {"*": {"": ["ast"]}})
        self.assertEqual(set(native["settings"]["outputSelection"]), {"Base.sol", "Owner.sol"})
        self.assertEqual(native["settings"]["outputSelection"]["Owner.sol"][""], ["ast"])
        native["sources"]["Base.sol"]["content"] = "changed"
        analysis["settings"]["optimizer"]["runs"] = 1
        self.assertEqual(self.request, original)
        self.assertNotEqual(native["sources"], analysis["sources"])

    def test_explicit_selection_retains_original_forge_request(self):
        request = copy.deepcopy(self.request)
        request["settings"]["outputSelection"] = {"*": {"": ["ast"], "*": list(FIELDS)}}
        original = copy.deepcopy(request)
        analysis, native = scoped.split_request(request, self.ni["settings"]["outputSelection"], all_source_asts=False)
        self.assertEqual(request, original)
        self.assertEqual(native, self.ni)
        self.assertEqual(analysis, self.ai)

    def test_implicit_and_wildcard_selections_refuse(self):
        cases = [
            {"*": {"*": list(FIELDS)}},
            {"Owner.sol": {"*": list(FIELDS)}},
            {"Owner.sol": {"Owner": ["*"]}},
            {"Owner.sol": {"Owner": ["ast"]}},
            {"Owner.sol": {"Owner": []}},
            {"Owner.sol": {"Owner": ["abi"]}},
            {"Unknown.sol": {"Unknown": list(FIELDS)}},
            {"Base.sol": {"": ["ast"]}},
            {"Base.sol": {}, "Owner.sol": {"Owner": list(FIELDS)}},
        ]
        for selection in cases:
            with self.subTest(selection=selection), self.assertRaises(ValueError):
                scoped.split_request(self.request, selection)

    def test_opt_in_native_ast_includes_unselected_base_without_extra_products(self):
        selection = {"Owner.sol": {"Owner": list(FIELDS)}}
        analysis, native = scoped.split_request(self.request, selection, all_source_asts=True)
        self.assertEqual({(s, n) for s, rows in native["settings"]["outputSelection"].items()
                          for n in rows if n}, {("Owner.sol", "Owner")})
        self.assertEqual(native["settings"]["outputSelection"]["Base.sol"], {"": ["ast"]})
        output = copy.deepcopy(self.no)
        output["sources"] = copy.deepcopy(self.ao["sources"])
        del output["contracts"]["Base.sol"]
        before = copy.deepcopy((analysis, native, output))
        report = scoped.verify_pair(analysis, self.ao, native, output)
        self.assertEqual(report["immutableJoins"][0]["declaration"], {"source": "Base.sol", "variable": "x"})
        self.assertEqual((analysis, native, output), before)
        del output["sources"]["Base.sol"]["ast"]
        with self.assertRaisesRegex(ValueError, "native AST roster"):
            scoped.verify_pair(analysis, self.ao, native, output)

    def test_opt_in_all_ast_selection_is_idempotent_and_keeps_fields_exact(self):
        analysis, native = scoped.split_request(self.request, all_source_asts=True)
        self.assertEqual(scoped.split_request(native), (analysis, native))
        for source, rows in self.ni["settings"]["outputSelection"].items():
            self.assertEqual(native["settings"]["outputSelection"][source], rows)

    def test_free_struct_source_accepts_ast_without_fictitious_contract(self):
        self.request["sources"]["Struct.sol"] = {"content": "pragma solidity 0.8.19; struct Value { uint n; }"}
        selected = {"Struct.sol": {"": ["ast"]}, "Owner.sol": {"Owner": list(FIELDS)}}
        _, native = scoped.split_request(self.request, selected)
        self.assertEqual(native["settings"]["outputSelection"]["Struct.sol"], {"": ["ast"]})
        self.assertEqual({(s, n) for s, rows in native["settings"]["outputSelection"].items()
                          for n in rows if n}, {("Owner.sol", "Owner")})

    def test_url_sources_refuse(self):
        self.request["sources"]["Base.sol"] = {"urls": ["Base.sol"]}
        with self.assertRaisesRegex(ValueError, "literal source"):
            scoped.split_request(self.request)

    def test_siblings_and_embedded_dependencies_are_distinct_from_outputs(self):
        before = copy.deepcopy((self.ai, self.ao, self.ni, self.no))
        report = self.verify()
        self.assertEqual(report["selectedContracts"], 2)
        self.assertEqual(report["scheduledDefinitions"], ["Base.sol:Base", "Owner.sol:Owner", "Owner.sol:Sibling"])
        self.assertEqual(report["dependencyClosure"], ["Base.sol:Base", "Child.sol:Child", "Owner.sol:Owner", "Owner.sol:Sibling"])
        self.assertEqual(report["immutableJoins"][0]["declaration"], {"source": "Base.sol", "variable": "x"})
        self.assertNotIn("ast", self.no["sources"]["Child.sol"])
        self.assertEqual((self.ai, self.ao, self.ni, self.no), before)

    def test_source_or_nonselector_setting_mismatch_refuses(self):
        for kind in ("source", "settings"):
            with self.subTest(kind=kind):
                changed = copy.deepcopy(self.ni)
                if kind == "source":
                    changed["sources"]["Child.sol"]["content"] += " "
                else:
                    changed["settings"]["optimizer"]["runs"] = 201
                with self.assertRaisesRegex(ValueError, "Source universe or compiler settings differ"):
                    scoped.verify_pair(self.ai, self.ao, changed, self.no)

    def test_all_source_ids_are_checked_including_unemitted_ast(self):
        for source in ("Owner.sol", "Child.sol"):
            with self.subTest(source=source):
                changed = copy.deepcopy(self.no)
                changed["sources"][source]["id"] = 99
                with self.assertRaisesRegex(ValueError, "Source ID differs"):
                    scoped.verify_pair(self.ai, self.ao, self.ni, changed)
        self.ao["sources"]["Child.sol"]["id"] = self.ao["sources"]["Base.sol"]["id"]
        self.no["sources"]["Child.sol"]["id"] = self.no["sources"]["Base.sol"]["id"]
        with self.assertRaisesRegex(ValueError, "duplicate source ID"):
            self.verify()

    def test_missing_source_id_roster_refuses(self):
        del self.no["sources"]["Unused.sol"]
        with self.assertRaisesRegex(ValueError, "Incomplete compiler source IDs"):
            self.verify()

    def test_native_ast_roster_and_codegen_annotation_mismatch_refuse(self):
        for change in ("missing", "unexpected", "annotation"):
            with self.subTest(change=change):
                changed = copy.deepcopy(self.no)
                if change == "missing":
                    del changed["sources"]["Owner.sol"]["ast"]
                elif change == "unexpected":
                    changed["sources"]["Child.sol"]["ast"] = copy.deepcopy(self.ao["sources"]["Child.sol"]["ast"])
                else:
                    changed["sources"]["Owner.sol"]["ast"]["internalFunctionIDs"] = {"999": 1}
                with self.assertRaisesRegex(ValueError, "native AST roster|Native AST differs"):
                    scoped.verify_pair(self.ai, self.ao, self.ni, changed)

    def test_missing_and_unexpected_contract_outputs_refuse(self):
        for unexpected in (False, True):
            with self.subTest(unexpected=unexpected):
                changed = copy.deepcopy(self.no)
                if unexpected:
                    changed["contracts"]["Owner.sol"]["Sibling"] = {"abi": []}
                else:
                    del changed["contracts"]["Owner.sol"]["Owner"]
                with self.assertRaisesRegex(ValueError, "contract outputs missing or unexpected"):
                    scoped.verify_pair(self.ai, self.ao, self.ni, changed)

    def test_missing_requested_evm_or_immutable_fields_refuse(self):
        for path in (("metadata",), ("evm",), ("evm", "deployedBytecode", "immutableReferences"),
                     ("evm", "bytecode", "linkReferences")):
            with self.subTest(path=path):
                changed = copy.deepcopy(self.no)
                value = changed["contracts"]["Owner.sol"]["Owner"]
                for key in path[:-1]:
                    value = value[key]
                del value[path[-1]]
                with self.assertRaisesRegex(ValueError, "Requested output missing|Incomplete native bytecode evidence"):
                    scoped.verify_pair(self.ai, self.ao, self.ni, changed)

    def test_missing_same_native_base_refuses_despite_analysis_declaration(self):
        del self.ni["settings"]["outputSelection"]["Base.sol"]
        del self.no["contracts"]["Base.sol"]
        del self.no["sources"]["Base.sol"]["ast"]
        self.assertEqual(self.ao["sources"]["Base.sol"]["ast"]["nodes"][0]["nodes"][0]["id"], 11)
        with self.assertRaisesRegex(ValueError, "Missing same-native immutable declaration 11"):
            self.verify()

    def test_immutable_reference_bounds_and_placeholders_refuse(self):
        for kind in ("unknown", "empty", "negative", "width", "outside", "nonzero"):
            with self.subTest(kind=kind):
                changed = copy.deepcopy(self.no)
                artifact = changed["contracts"]["Owner.sol"]["Owner"]["evm"]["deployedBytecode"]
                refs = artifact["immutableReferences"]
                if kind == "unknown":
                    refs["999"] = refs.pop("11")
                elif kind == "empty":
                    refs["11"] = []
                elif kind == "nonzero":
                    artifact["object"] = "ff" * 64
                else:
                    refs["11"] = [{"start": -1 if kind == "negative" else 48 if kind == "outside" else 16,
                                   "length": 31 if kind == "width" else 32}]
                with self.assertRaisesRegex(ValueError, "immutable|Immutable"):
                    scoped.verify_pair(self.ai, self.ao, self.ni, changed)

    def test_missing_dependency_definition_refuses(self):
        for output in (self.ao, self.no):
            output["sources"]["Owner.sol"]["ast"]["nodes"][2]["contractDependencies"] = [999]
        with self.assertRaisesRegex(ValueError, "Missing code-generation dependency AST ID"):
            self.verify()

    def test_errors_and_analysis_contract_outputs_refuse(self):
        for kind in ("analysis_error", "native_error", "analysis_contract"):
            with self.subTest(kind=kind):
                analysis, native = copy.deepcopy(self.ao), copy.deepcopy(self.no)
                if kind == "analysis_contract":
                    analysis["contracts"] = {"Base.sol": {"Base": {"abi": []}}}
                else:
                    (analysis if kind == "analysis_error" else native)["errors"] = [
                        {"severity": "error", "formattedMessage": "synthetic compiler failure"}]
                with self.assertRaisesRegex(ValueError, "Compiler errors|unexpectedly emitted contracts"):
                    scoped.verify_pair(self.ai, analysis, self.ni, native)


class ForgeTransportTests(unittest.TestCase):
    def setUp(self):
        _, self.ai, self.ao, self.ni, self.native = fixture()

    def test_observed_empty_transports_preserve_raw_native_evidence(self):
        owner = self.native["contracts"]["Owner.sol"]["Owner"]
        owner["storageLayout"] = {"storage": [], "types": None}
        owner["evm"]["bytecode"]["immutableReferences"] = {}
        serialized = copy.deepcopy(self.native)
        serialized["sources"]["Child.sol"]["ast"] = {}
        serialized["sources"]["Owner.sol"]["ast"]["nodes"][0]["nodes"] = []
        transformed = serialized["contracts"]["Owner.sol"]["Owner"]
        transformed["devdoc"] = {}; transformed["userdoc"] = {}
        del transformed["storageLayout"]
        del transformed["evm"]["bytecode"]["immutableReferences"]
        before = copy.deepcopy((self.native, serialized))
        changes = scoped.forge_output_transport(self.native, serialized)
        self.assertEqual(len(changes), 6)
        self.assertEqual((self.native, serialized), before)
        self.assertEqual(owner["evm"]["deployedBytecode"]["immutableReferences"],
                         {"11": [{"start": 16, "length": 32}]})

    def test_bytecode_source_id_nonempty_references_and_layout_changes_refuse(self):
        self.native["contracts"]["Owner.sol"]["Owner"]["storageLayout"] = {
            "storage": [{"label": "counter", "offset": 0, "slot": "0", "type": "t_uint256"}],
            "types": {"t_uint256": {"encoding": "inplace", "numberOfBytes": "32"}}}
        for kind in ("bytecode", "source_id", "immutable_offset", "immutable_omission", "layout_omission", "layout_slot"):
            with self.subTest(kind=kind):
                changed = copy.deepcopy(self.native)
                owner = changed["contracts"]["Owner.sol"]["Owner"]
                if kind == "bytecode":
                    owner["evm"]["bytecode"]["object"] = "ff"
                elif kind == "source_id":
                    changed["sources"]["Child.sol"]["id"] = 99
                elif kind == "immutable_offset":
                    owner["evm"]["deployedBytecode"]["immutableReferences"]["11"][0]["start"] = 17
                elif kind == "immutable_omission":
                    del owner["evm"]["deployedBytecode"]["immutableReferences"]
                elif kind == "layout_omission":
                    del owner["storageLayout"]
                else:
                    owner["storageLayout"]["storage"][0]["slot"] = "1"
                with self.assertRaisesRegex(ValueError, "Forge output differs"):
                    scoped.forge_output_transport(self.native, changed)

    def test_equal_valued_json_type_changes_in_source_ids_and_references_refuse(self):
        for kind in ("source_boolean", "reference_float"):
            with self.subTest(kind=kind):
                changed = copy.deepcopy(self.native)
                if kind == "source_boolean":
                    changed["sources"]["Base.sol"]["id"] = False
                else:
                    changed["contracts"]["Owner.sol"]["Owner"]["evm"]["deployedBytecode"]["immutableReferences"]["11"][0]["start"] = 16.0
                with self.assertRaisesRegex(ValueError, "Forge output differs"):
                    scoped.forge_output_transport(self.native, changed)

    def test_ast_transport_accepts_only_empty_children_on_existing_nodes(self):
        native = {"id": 1, "nodeType": "Identifier", "name": "x"}
        self.assertEqual(len(scoped.forge_ast_transport(native, {**native, "nodes": []})), 1)
        cases = [{**native, "id": 2}, {**native, "id": True}, {**native, "nodes": [{"id": 2}]},
                 {**native, "extra": []}, {"id": 1, "nodeType": "Identifier"}]
        for changed in cases:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                scoped.forge_ast_transport(native, changed)
        with self.assertRaisesRegex(ValueError, "added fields"):
            scoped.forge_ast_transport({"id": 1}, {"id": 1, "nodes": []})

    def test_storage_transport_never_normalizes_nonempty_layout(self):
        self.assertEqual(len(scoped.forge_storage_transport(
            {"storage": [], "types": None}, {"storage": [], "types": {}})), 1)
        native = {"storage": [{"offset": 0, "slot": "0"}], "types": {"t": {"numberOfBytes": "32"}}}
        self.assertEqual(scoped.forge_storage_transport(native, copy.deepcopy(native)), [])
        for kind in ("slot", "offset_type", "omission"):
            with self.subTest(kind=kind):
                changed = copy.deepcopy(native)
                if kind == "slot":
                    changed["storage"][0]["slot"] = "1"
                elif kind == "offset_type":
                    changed["storage"][0]["offset"] = False
                else:
                    changed = {"storage": [], "types": {}}
                with self.assertRaisesRegex(ValueError, "Forge storage layout differs"):
                    scoped.forge_storage_transport(native, changed)

    def test_closure_uses_analysis_only_after_pair_binding_without_ast_splice(self):
        build = {"solcVersion": "0.8.19", "input": self.ni, "output": self.native}
        analysis = {"solcVersion": "0.8.19", "input": self.ai, "output": self.ao}
        before = copy.deepcopy((build, analysis))
        self.assertEqual(source_closure(build, {"Owner.sol"}, analysis=analysis),
                         {"Owner.sol", "Base.sol", "Child.sol"})
        self.assertEqual((build, analysis), before)
        self.assertNotIn("ast", build["output"]["sources"]["Child.sol"])
        with self.assertRaisesRegex(ValueError, "Compiler AST missing: Child.sol"):
            source_closure(build, {"Owner.sol"})

    def test_closure_rejects_unbound_analysis_and_cannot_supply_native_immutables(self):
        build = {"solcVersion": "0.8.19", "input": self.ni, "output": self.native}
        analysis = {"solcVersion": "0.8.19", "input": self.ai, "output": self.ao}
        wrong = copy.deepcopy(analysis)
        wrong["input"]["sources"]["Child.sol"]["content"] += " "
        with self.assertRaisesRegex(ValueError, "Source universe or compiler settings differ"):
            source_closure(build, {"Owner.sol"}, analysis=wrong)
        del build["input"]["settings"]["outputSelection"]["Base.sol"]
        del build["output"]["sources"]["Base.sol"]["ast"]
        del build["output"]["contracts"]["Base.sol"]
        with self.assertRaisesRegex(ValueError, "Missing same-native immutable declaration"):
            source_closure(build, {"Owner.sol"}, analysis=analysis)

    def test_closure_selected_sources_are_still_checked_against_disk(self):
        build = {"solcVersion": "0.8.19", "input": self.ni, "output": self.native}
        analysis = {"solcVersion": "0.8.19", "input": self.ai, "output": self.ao}
        with tempfile.TemporaryDirectory(prefix="scoped-source-unit-") as directory:
            project = Path(directory)
            for name, source in self.ni["sources"].items():
                (project / name).write_bytes(source["content"].encode("utf-8"))
            self.assertEqual(validate_sources(project, build, source_roots={"Owner.sol"}, analysis=analysis), [])
            (project / "Child.sol").write_bytes(b"changed imported source")
            with self.assertRaisesRegex(ValueError, "Stale compiler source: Child.sol"):
                validate_sources(project, build, source_roots={"Owner.sol"}, analysis=analysis)


class FakeProcess:
    """Mock process lifecycle only; this class never launches an executable."""
    def __init__(self, failure=None):
        self.pid = 12345
        self.returncode = None
        self.failure = failure
        self.wait_count = 0
        self.kill_count = 0

    def wait(self, timeout=None):
        self.wait_count += 1
        if self.failure is not None:
            failure, self.failure = self.failure, None
            raise failure
        if self.returncode is None:
            self.returncode = 0
        return self.returncode

    def poll(self):
        return self.returncode

    def kill(self):
        self.kill_count += 1
        self.returncode = -9


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="scoped-json-unit-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.compiler = self.root / "synthetic-compiler-never-executed.bin"
        self.compiler.write_bytes(b"unit-test-only-not-an-executable")
        self.compiler_sha = scoped.sha(self.compiler.read_bytes())
        self.request, self.ai, self.ao, self.ni, self.no = fixture()
        self.ai, self.ni = scoped.split_request(self.request, all_source_asts=True)
        self.no["sources"] = copy.deepcopy(self.ao["sources"])
        self.processes = []

    def capture(self, name="capture", *, fail_at=None, failure=None, all_source_asts=True):
        outputs = [self.ao, self.no]
        self.processes = []

        def popen(command, *, stdin, stdout, stderr):
            index = len(self.processes)
            self.assertEqual(command, [str(self.compiler.resolve()), "--standard-json"])
            self.assertEqual(json.loads(stdin.read()), (self.ai, self.ni)[index])
            stdout.write(scoped.canonical(outputs[index])); stdout.flush()
            process = FakeProcess(failure if index == fail_at else None)
            self.processes.append(process)
            return process

        version = subprocess.CompletedProcess([], 0, scoped.VERSION.encode(), b"")
        with mock.patch.object(scoped.subprocess, "run", return_value=version), \
                mock.patch.object(scoped.subprocess, "Popen", side_effect=popen):
            return scoped.capture_pair(scoped.canonical(self.request), self.request["settings"]["outputSelection"],
                                       self.compiler, self.compiler_sha, self.root / name, timeout=0.1,
                                       all_source_asts=all_source_asts)

    def write_record(self, folder, record):
        (folder / "record.json").write_bytes(scoped.canonical(record))

    def rehash(self, folder, name):
        record = json.loads((folder / "record.json").read_bytes())
        record["files"][name] = scoped.sha((folder / name).read_bytes())
        self.write_record(folder, record)

    def test_mocked_capture_retains_separate_requests_and_process_records(self):
        record = self.capture()
        analysis, native, reread = scoped.read_capture(self.root / "capture")
        self.assertEqual(record, reread)
        self.assertEqual(record["status"], "VERIFIED")
        self.assertEqual(analysis["input"], self.ai)
        self.assertEqual(native["output"], self.no)
        self.assertIn("ast", analysis["output"]["sources"]["Child.sol"])
        self.assertIn("ast", native["output"]["sources"]["Child.sol"])
        for process in self.processes:
            self.assertEqual((process.wait_count, process.kill_count), (1, 0))
        for step in record["passes"].values():
            self.assertEqual((step["status"], step["exitCode"], step["pid"]), ("COMPLETE", 0, 12345))

    def test_explicit_partial_ast_policy_is_retained_and_never_supplies_missing_base(self):
        self.request, self.ai, self.ao, self.ni, self.no = fixture()
        record = self.capture(all_source_asts=False)
        self.assertIs(record["allSourceAsts"], False)
        _, native, _ = scoped.read_capture(self.root / "capture")
        self.assertNotIn("ast", native["output"]["sources"]["Child.sol"])
        record["allSourceAsts"] = True
        self.write_record(self.root / "capture", record)
        with self.assertRaisesRegex(ValueError, "request transformation differs"):
            scoped.read_capture(self.root / "capture")

    def test_changed_capture_bytes_or_hashes_refuse(self):
        for change in ("bytes", "hash", "extra"):
            with self.subTest(change=change):
                self.capture(change); folder = self.root / change
                if change == "bytes":
                    with (folder / "analysis-output.json").open("ab") as stream:
                        stream.write(b" ")
                elif change == "extra":
                    (folder / "unexpected.json").write_bytes(b"{}")
                else:
                    record = json.loads((folder / "record.json").read_bytes())
                    record["files"]["analysis-output.json"] = "0" * 64
                    self.write_record(folder, record)
                with self.assertRaisesRegex(ValueError, "Capture files changed"):
                    scoped.read_capture(folder)

    def test_capture_status_and_process_evidence_mismatch_refuse(self):
        for kind in ("status", "exit", "compiler", "command", "missing_pass"):
            with self.subTest(kind=kind):
                record = self.capture(kind); folder = self.root / kind
                if kind == "status":
                    record["status"] = "FAILED"
                elif kind == "missing_pass":
                    del record["passes"]["analysis"]
                elif kind == "exit":
                    record["passes"]["analysis"]["exitCode"] = 1
                elif kind == "compiler":
                    record["passes"]["analysis"]["compilerSha256"] = "0" * 64
                else:
                    record["passes"]["analysis"]["command"] = ["different"]
                self.write_record(folder, record)
                with self.assertRaisesRegex(ValueError, "not verified|Incomplete native passes|process evidence differs"):
                    scoped.read_capture(folder)

    def test_rehashed_malformed_output_still_refuses_semantic_validation(self):
        self.capture(); folder = self.root / "capture"
        changed = copy.deepcopy(self.no)
        del changed["contracts"]["Owner.sol"]["Owner"]["evm"]["deployedBytecode"]["immutableReferences"]
        (folder / "codegen-output.json").write_bytes(scoped.canonical(changed))
        self.rehash(folder, "codegen-output.json")
        with self.assertRaisesRegex(ValueError, "Incomplete native bytecode evidence"):
            scoped.read_capture(folder)

    def test_rehashed_requested_input_cannot_change_transformation(self):
        self.capture(); folder = self.root / "capture"
        self.request["sources"]["Child.sol"]["content"] += " "
        (folder / "requested-input.json").write_bytes(scoped.canonical(self.request))
        self.rehash(folder, "requested-input.json")
        with self.assertRaisesRegex(ValueError, "request transformation differs"):
            scoped.read_capture(folder)

    def test_wrong_compiler_pin_prevents_any_subprocess(self):
        with mock.patch.object(scoped.subprocess, "run") as run, \
                mock.patch.object(scoped.subprocess, "Popen") as popen:
            with self.assertRaisesRegex(ValueError, "Compiler executable hash differs"):
                scoped.capture_pair(scoped.canonical(self.request), self.request["settings"]["outputSelection"],
                                    self.compiler, "0" * 64, self.root / "bad-pin", timeout=1)
        run.assert_not_called(); popen.assert_not_called()
        self.assertFalse((self.root / "bad-pin").exists())

    def test_timeout_kills_reaps_and_preserves_terminal_failure(self):
        for index in (0, 1):
            with self.subTest(pass_index=index):
                name = "timeout-" + str(index)
                with self.assertRaisesRegex(ValueError, "native pass failed: TIMEOUT"):
                    self.capture(name, fail_at=index, failure=subprocess.TimeoutExpired("mock-solc", 0.1))
                failed = self.processes[index]
                self.assertEqual((failed.kill_count, failed.wait_count), (1, 2))
                self.assertEqual(len(self.processes), index + 1)
                record = json.loads((self.root / name / "record.json").read_bytes())
                self.assertEqual(record["status"], "FAILED")
                self.assertEqual(record["passes"][("analysis", "codegen")[index]]["status"], "TIMEOUT")
                with self.assertRaisesRegex(ValueError, "not verified"):
                    scoped.read_capture(self.root / name)

    def test_interruption_kills_reaps_and_never_starts_next_pass(self):
        for index in (0, 1):
            with self.subTest(pass_index=index):
                name = "interrupt-" + str(index)
                with self.assertRaises(KeyboardInterrupt):
                    self.capture(name, fail_at=index, failure=KeyboardInterrupt())
                self.assertEqual((self.processes[index].kill_count, self.processes[index].wait_count), (1, 2))
                self.assertEqual(len(self.processes), index + 1)
                record = json.loads((self.root / name / "record.json").read_bytes())
                self.assertEqual(record["status"], "FAILED")

    def test_pid_record_write_failure_still_reaps_native(self):
        original_write = Path.write_bytes
        injected = False

        def fail_once(path, raw):
            nonlocal injected
            if path.name == "record.json" and not injected:
                value = json.loads(raw)
                if "pid" in value.get("passes", {}).get("analysis", {}):
                    injected = True
                    raise OSError("synthetic PID record write failure")
            return original_write(path, raw)

        with mock.patch.object(Path, "write_bytes", new=fail_once):
            with self.assertRaisesRegex(OSError, "PID record write failure"):
                self.capture("save-error")
        self.assertTrue(injected)
        self.assertEqual(len(self.processes), 1)
        self.assertEqual((self.processes[0].kill_count, self.processes[0].wait_count), (1, 1))
        record = json.loads((self.root / "save-error" / "record.json").read_bytes())
        self.assertEqual(record["status"], "FAILED")

    def test_build_binding_keeps_forge_request_and_actual_native_input_distinct(self):
        self.capture(); folder = self.root / "capture"
        envelope = copy.deepcopy(self.request)
        envelope.update(version="0.8.19", allowPaths=["project"], basePath="project", includePaths=[])
        build = {"id": "synthetic-build", "solcVersion": "0.8.19", "input": envelope, "output": copy.deepcopy(self.no)}
        before = copy.deepcopy(build)
        files_before = {p.name: p.read_bytes() for p in folder.iterdir()}
        native, analysis, evidence = scoped.bind_build_capture(build, folder)
        self.assertEqual(build, before)
        self.assertEqual({p.name: p.read_bytes() for p in folder.iterdir()}, files_before)
        self.assertEqual(native["input"], self.ni)
        self.assertEqual(native["output"], self.no)
        self.assertEqual(analysis["input"], self.ai)
        self.assertEqual(evidence["forgeRequestedInputSha256"], scoped.sha(scoped.canonical(envelope)))
        self.assertEqual(evidence["nativeCompilerInputSha256"], scoped.sha(scoped.canonical(self.ni)))
        self.assertNotEqual(evidence["forgeRequestedInputSha256"], evidence["nativeCompilerInputSha256"])
        self.assertIn("ast", native["output"]["sources"]["Child.sol"])

    def test_build_binding_refuses_wrong_envelope_request_or_bytecode(self):
        self.capture(); folder = self.root / "capture"
        for kind in ("envelope", "version", "request", "bytecode"):
            with self.subTest(kind=kind):
                build = {"id": "synthetic-build", "solcVersion": "0.8.19",
                         "input": copy.deepcopy(self.request), "output": copy.deepcopy(self.no)}
                if kind == "envelope":
                    build["input"]["unexpected"] = True
                elif kind == "version":
                    build["input"]["version"] = "0.8.20"
                elif kind == "request":
                    build["input"]["settings"]["optimizer"]["runs"] = 201
                else:
                    build["output"]["contracts"]["Owner.sol"]["Owner"]["evm"]["bytecode"]["object"] = "ff"
                with self.assertRaises(ValueError):
                    scoped.bind_build_capture(build, folder)


if __name__ == "__main__":
    unittest.main()
