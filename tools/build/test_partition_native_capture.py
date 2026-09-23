"""Synthetic partition-intake boundaries; these tests never invoke solc or Forge."""
from __future__ import annotations

import copy
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools.build import partition_native_capture as intake
from tools.build import scoped_standard_json as scoped
from tools.build.test_scoped_standard_json import fixture


class PartitionIntakeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.parent = self.root / "parent"
        self.native = self.root / "native"
        self.part = self.native / "part-000"
        self.parent.mkdir(); self.part.mkdir(parents=True)
        self.compiler = self.root / "compiler-not-executable"
        self.compiler.write_bytes(b"synthetic compiler identity; never executed")
        self.tool = self.root / "old-verifier-not-executable.py"
        self.tool.write_bytes(b"synthetic historical tool identity; never executed")
        self.request, self.ai, self.ao, self.original, self.no = fixture()
        owner = next(n for n in self.ao["sources"]["Owner.sol"]["ast"]["nodes"]
                     if n.get("name") == "Owner")
        owner["linearizedBaseContracts"] = [20, 10]
        self.no["sources"]["Owner.sol"] = copy.deepcopy(self.ao["sources"]["Owner.sol"])
        self.products = ["Owner.sol:Owner"]
        self.selection = intake._selection(self.original, self.ao, self.products)
        _, self.ni = scoped.split_request(self.original, self.selection)
        del self.no["contracts"]["Base.sol"]
        self.command = [str(self.compiler), "--standard-json"]
        for name, value in {"analysis-input.json": self.ai, "analysis-output.json": self.ao,
                            "codegen-input.json": self.original, "requested-input.json": self.request,
                            "selection.json": self.original["settings"]["outputSelection"]}.items():
            self.save(self.parent / name, value)
        for name in ("analysis-stderr.log", "codegen-output.json", "codegen-stderr.log", "version.stderr"):
            (self.parent / name).write_bytes(b"")
        (self.parent / "version.stdout").write_bytes(scoped.VERSION.encode())
        self.parent_record = {"schema": 1, "status": "FAILED", "allSourceAsts": False,
            "compiler": str(self.compiler), "compilerSha256": self.digest(self.compiler),
            "arguments": ["--standard-json"], "toolSha256": self.digest(self.tool),
            "passes": {"analysis": {"status": "COMPLETE", "exitCode": 0,
                "command": self.command, "compilerSha256": self.digest(self.compiler)},
                "codegen": {"status": "TIMEOUT", "exitCode": None}},
            "files": self.table(self.parent)}
        self.save(self.parent / "record.json", self.parent_record)
        self.plan = {"schema": 1, "kind": "DISJOINT_NATIVE_PARTITIONS", "capture": str(self.parent),
            "captureRecordSha256": self.digest(self.parent / "record.json"),
            "originalInputSha256": self.digest(self.parent / "codegen-input.json"),
            "analysisInputSha256": self.digest(self.parent / "analysis-input.json"),
            "analysisOutputSha256": self.digest(self.parent / "analysis-output.json"),
            "semanticContextSha256": scoped.sha(scoped.canonical(scoped.without_selection(self.original))),
            "compiler": str(self.compiler), "compilerSha256": self.digest(self.compiler),
            "arguments": ["--standard-json"], "verifier": str(self.tool),
            "verifierSha256": self.digest(self.tool), "workers": 1, "timeoutSeconds": 60,
            "partitions": [{"id": "part-000", "products": self.products, "selection": self.selection,
                            "inputSha256": scoped.sha(scoped.canonical(self.ni))}],
            "productCount": 1, "automaticRetries": 0}
        self.plan_path = self.root / "plan.json"
        self.save(self.plan_path, self.plan); self.save(self.native / "plan.json", self.plan)
        self.save(self.part / "input.json", self.ni); self.save(self.part / "output.json", self.no)
        (self.part / "stderr.log").write_bytes(b"")
        self.save(self.part / "verification.json", {"historical": "retained independently; not current schema"})
        self.record = {"id": "part-000", "status": "VERIFIED_NATIVE_PARTITION", "exitCode": 0,
            "attempt": 1, "command": self.command, "compilerSha256": self.digest(self.compiler),
            "planSha256": self.digest(self.plan_path), "inputSha256": self.digest(self.part / "input.json"),
            "timeoutSeconds": 60, "semanticContextSha256": self.plan["semanticContextSha256"],
            "products": self.products, "files": self.table(self.part)}
        self.index_path = self.native / "index.json"
        self.descriptor = self.root / "provenance.json"
        self.seal_record()
        self.build = {"solcVersion": "0.8.19", "solcLongVersion": "0.8.19",
                      "input": copy.deepcopy(self.ni), "output": copy.deepcopy(self.no)}

    @staticmethod
    def save(path, value):
        path.write_bytes(scoped.canonical(value))

    @staticmethod
    def digest(path):
        return scoped.sha(path.read_bytes())

    def table(self, path):
        return {p.name: self.digest(p) for p in path.iterdir() if p.is_file() and p.name != "record.json"}

    def seal_record(self):
        self.record["files"] = self.table(self.part)
        self.save(self.part / "record.json", self.record)
        self.index = {"schema": 1, "status": "VERIFIED_PARTITION_SET",
            "planSha256": self.digest(self.plan_path), "semanticContextSha256": self.plan["semanticContextSha256"],
            "partitions": [self.record], "products": {"Owner.sol:Owner": {
                "partition": "part-000", "inputSha256": self.record["inputSha256"],
                "outputSha256": self.digest(self.part / "output.json"),
                "recordSha256": self.digest(self.part / "record.json")}}}
        self.save(self.index_path, self.index)
        self.refresh_descriptor()

    def refresh_descriptor(self):
        self.save(self.descriptor, {"schema": 1, "kind": "partition-native", "partitionId": "part-000",
            "plan": {"path": str(self.plan_path), "sha256": self.digest(self.plan_path)},
            "index": {"path": str(self.index_path), "sha256": self.digest(self.index_path)},
            "recordSha256": self.digest(self.part / "record.json")})

    def bind(self):
        return intake.bind_partition_build_capture(self.build, self.part, provenance=self.descriptor)

    def test_separate_original_analysis_and_native_output_preserved(self):
        before = copy.deepcopy(self.build)
        build, analysis, evidence = self.bind()
        self.assertEqual(build["output"], self.no)
        self.assertEqual(analysis["output"], self.ao)
        self.assertNotIn("ast", build["output"]["sources"]["Child.sol"])
        self.assertEqual(evidence["parentCaptureStatus"], "FAILED")
        self.assertEqual(evidence["currentVerification"]["selectedContracts"], 1)
        self.assertEqual(before, self.build)

    def test_record_hash_mutation_refused(self):
        (self.part / "record.json").write_bytes((self.part / "record.json").read_bytes() + b" ")
        with self.assertRaisesRegex(ValueError, "hash differs"):
            self.bind()

    def test_original_analysis_mutation_refused(self):
        (self.parent / "analysis-output.json").write_bytes(b"{}")
        with self.assertRaisesRegex(ValueError, "hash differs"):
            self.bind()

    def test_compiler_and_historical_tool_mutations_refused(self):
        for path in (self.compiler, self.tool):
            original = path.read_bytes(); path.write_bytes(b"changed")
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "hash differs"):
                self.bind()
            path.write_bytes(original)

    def test_unknown_extra_capture_file_refused(self):
        (self.part / "borrowed-ast.json").write_bytes(b"{}")
        with self.assertRaisesRegex(ValueError, "roster differs"):
            self.bind()

    def test_native_status_exit_attempt_command_refused(self):
        for key, value in [("status", "FAILED"), ("exitCode", 1), ("exitCode", False),
                           ("attempt", 2), ("command", [str(self.compiler), "--version"]),
                           ("planSha256", "0" * 64)]:
            original = self.record[key]; self.record[key] = value; self.seal_record()
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                self.bind()
            self.record[key] = original; self.seal_record()

    def test_actual_input_sources_and_settings_cannot_be_changed(self):
        for key in ("source", "settings"):
            changed = copy.deepcopy(self.ni)
            if key == "source": changed["sources"]["Base.sol"]["content"] += " "
            else: changed["settings"]["viaIR"] = False
            self.save(self.part / "input.json", changed); self.seal_record()
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "hash differs"):
                self.bind()
            self.save(self.part / "input.json", self.ni); self.seal_record()

    def test_own_native_ast_cannot_be_borrowed_from_analysis(self):
        for source in ("Owner.sol", "Base.sol"):
            changed = copy.deepcopy(self.no); del changed["sources"][source]["ast"]
            self.save(self.part / "output.json", changed); self.seal_record()
            with self.subTest(source=source), self.assertRaisesRegex(ValueError, "native AST roster"):
                self.bind()
            self.save(self.part / "output.json", self.no); self.seal_record()

    def test_native_immutable_id_cannot_be_reassigned(self):
        changed = copy.deepcopy(self.no)
        changed["contracts"]["Owner.sol"]["Owner"]["evm"]["deployedBytecode"]["immutableReferences"] = {"999": [{"start":16,"length":32}]}
        self.save(self.part / "output.json", changed); self.seal_record()
        with self.assertRaises(ValueError): self.bind()

    def test_native_error_and_extra_output_refused(self):
        for kind in ("error", "extra"):
            changed = copy.deepcopy(self.no)
            if kind == "error": changed["errors"] = [{"severity": "error", "message": "synthetic"}]
            else: changed["contracts"]["Owner.sol"]["Sibling"] = {}
            self.save(self.part / "output.json", changed); self.seal_record()
            with self.subTest(kind=kind), self.assertRaises(ValueError): self.bind()
            self.save(self.part / "output.json", self.no); self.seal_record()

    def test_forge_output_bytes_abi_and_ast_must_match(self):
        for kind in ("code", "abi", "ast"):
            self.build["output"] = copy.deepcopy(self.no)
            if kind == "code": self.build["output"]["contracts"]["Owner.sol"]["Owner"]["evm"]["bytecode"]["object"] = "01"
            elif kind == "abi": self.build["output"]["contracts"]["Owner.sol"]["Owner"]["abi"] = [{"type":"receive"}]
            else: self.build["output"]["sources"]["Base.sol"]["ast"]["id"] += 1
            with self.subTest(kind=kind), self.assertRaises(ValueError): self.bind()

    def test_forge_original_full_selection_not_substituted_for_partition(self):
        self.build["input"] = copy.deepcopy(self.original)
        with self.assertRaisesRegex(ValueError, "Forge request differs"):
            self.bind()

    def test_forge_parent_request_envelope_retains_actual_partition_identity(self):
        self.build["input"] = copy.deepcopy(self.request)
        build, _, evidence = self.bind()
        self.assertEqual(build["input"], self.ni)
        self.assertNotEqual(build["input"], self.build["input"])
        self.assertEqual(evidence["forgeRequestKind"], "original-parent-request")

    def test_compiler_version_envelope_refused(self):
        self.build["solcLongVersion"] = "0.8.20"
        with self.assertRaisesRegex(ValueError, "long compiler version"):
            self.bind()

    def test_unknown_descriptor_field_and_duplicate_json_refused(self):
        value = intake.strict_json(self.descriptor.read_bytes()); value["admission"] = "not-supported"
        self.save(self.descriptor, value)
        with self.assertRaisesRegex(ValueError, "provenance descriptor"):
            self.bind()
        self.descriptor.write_bytes(b'{"schema":1,"schema":1}')
        with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
            self.bind()

    def test_index_cannot_reassign_product_owner(self):
        self.index["products"]["Owner.sol:Owner"]["partition"] = "part-001"
        self.save(self.index_path, self.index); self.refresh_descriptor()
        with self.assertRaisesRegex(ValueError, "Indexed product owner differs"):
            self.bind()

    def test_original_directory_cannot_be_replaced_by_copy(self):
        with self.assertRaisesRegex(ValueError, "indexed original owner"):
            intake.bind_partition_build_capture(self.build, self.root / "copy", provenance=self.descriptor)

    def test_end_of_intake_rechecks_all_authenticated_files(self):
        original = scoped.forge_output_transport
        def mutate(native, serialized):
            result = original(native, serialized)
            (self.part / "stderr.log").write_bytes(b"changed during intake")
            return result
        with mock.patch.object(intake, "forge_output_transport", side_effect=mutate):
            with self.assertRaisesRegex(ValueError, "changed during intake"):
                self.bind()

    def test_narrow_forge_empty_field_transport_retains_native(self):
        self.build["output"]["sources"]["Child.sol"]["ast"] = {}
        build, _, evidence = self.bind()
        self.assertNotIn("ast", build["output"]["sources"]["Child.sol"])
        self.assertTrue(any("absent AST" in x for x in evidence["forgeOutputTransports"]))


if __name__ == "__main__":
    unittest.main()
