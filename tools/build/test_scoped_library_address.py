"""Synthetic library-self-address and terminal-admission regression boundaries.

No fixture here is native compiler evidence, and no test invokes a compiler.
"""
from __future__ import annotations

import copy
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

from tools.build import scoped_standard_json as scoped
from tools.build import prepare_current_graph as graph
from tools.build.test_scoped_standard_json import fixture


SYNTHETIC_ID = "library_deploy_address"


def library_fixture():
    values = fixture()
    request, analysis_input, analysis_output, native_input, native_output = values
    source = ('pragma solidity 0.8.19; import "./Base.sol"; import "./Child.sol"; '
              'library Owner { function spawn() external returns (Child) { return new Child(); } } '
              'contract Sibling {}')
    for native_request in (request, analysis_input, native_input):
        native_request["sources"]["Owner.sol"]["content"] = source
    for output in (analysis_output, native_output):
        for node in output["sources"]["Owner.sol"]["ast"]["nodes"]:
            if node.get("nodeType") == "ContractDefinition":
                node["contractKind"] = "library" if node["name"] == "Owner" else "contract"
    runtime = native_output["contracts"]["Owner.sol"]["Owner"]["evm"]["deployedBytecode"]
    runtime["object"] = "307f" + "00" * 32 + "14"
    runtime["immutableReferences"] = {SYNTHETIC_ID: [{"start": 2, "length": 32}]}
    return values


class LibraryAddressTests(unittest.TestCase):
    def setUp(self):
        self.request, self.ai, self.ao, self.ni, self.no = library_fixture()

    def verify(self):
        return scoped.verify_pair(self.ai, self.ao, self.ni, self.no)

    def runtime(self):
        return self.no["contracts"]["Owner.sol"]["Owner"]["evm"]["deployedBytecode"]

    def kind(self, value, *, native_only=False):
        for output in ((self.no,) if native_only else (self.ao, self.no)):
            for node in output["sources"]["Owner.sol"]["ast"]["nodes"]:
                if node.get("name") == "Owner":
                    if value is None:
                        node.pop("contractKind", None)
                    else:
                        node["contractKind"] = value

    def test_exact_synthetic_library_runtime_has_separate_join_and_no_mutation(self):
        before = copy.deepcopy((self.ai, self.ao, self.ni, self.no))
        report = self.verify()
        self.assertEqual(report["selectedContracts"], 2)
        self.assertEqual(report["immutableJoins"], [])
        self.assertEqual(len(report["librarySelfAddressJoins"]), 1)
        self.assertEqual((self.ai, self.ao, self.ni, self.no), before)

    def test_numeric_only_reports_keep_original_shape(self):
        _, ai, ao, ni, no = fixture()
        report = scoped.verify_pair(ai, ao, ni, no)
        self.assertNotIn("librarySelfAddressJoins", report)
        self.assertEqual(report["immutableJoins"][0]["id"], "11")

    def test_valid_sites_are_not_tied_to_one_runtime_offset(self):
        for padding in (0, 5, 55, 278):
            with self.subTest(padding=padding):
                self.runtime()["object"] = "00" * padding + "307f" + "00" * 32 + "14"
                self.runtime()["immutableReferences"][SYNTHETIC_ID] = [
                    {"start": padding + 2, "length": 32}]
                self.assertEqual(len(self.verify()["librarySelfAddressJoins"]), 1)

    def test_address_comparison_also_accepts_reversed_operand_order(self):
        self.runtime()["object"] = "7f" + "00" * 32 + "3014"
        self.runtime()["immutableReferences"][SYNTHETIC_ID] = [{"start": 1, "length": 32}]
        self.assertEqual(len(self.verify()["librarySelfAddressJoins"]), 1)

    def test_ordinary_contract_interface_or_missing_kind_refuses(self):
        self.verify()
        for kind in ("contract", "interface", None, "Library"):
            with self.subTest(kind=kind):
                self.kind(kind)
                with self.assertRaises(ValueError):
                    self.verify()
                self.kind("library")
                self.verify()

    def test_library_kind_in_analysis_cannot_replace_same_native_ast(self):
        self.verify()
        self.kind("contract", native_only=True)
        with self.assertRaisesRegex(ValueError, "Native AST differs"):
            self.verify()

    def test_library_sibling_cannot_authorize_selected_ordinary_contract(self):
        self.verify()
        self.kind("contract")
        for output in (self.ao, self.no):
            for node in output["sources"]["Owner.sol"]["ast"]["nodes"]:
                if node.get("name") == "Sibling":
                    node["contractKind"] = "library"
        with self.assertRaises(ValueError):
            self.verify()

    def test_synthetic_reference_in_creation_refuses(self):
        self.verify()
        evm = self.no["contracts"]["Owner.sol"]["Owner"]["evm"]
        evm["bytecode"] = copy.deepcopy(self.runtime())
        self.runtime()["immutableReferences"] = {}
        with self.assertRaises(ValueError):
            self.verify()

    def test_other_synthetic_names_still_require_ast_declarations(self):
        self.verify()
        for key in ("library_deploy_address_typo", "library_deploy_address ", "LIBRARY_DEPLOY_ADDRESS", "other"):
            with self.subTest(key=key):
                self.runtime()["immutableReferences"] = {key: [{"start": 2, "length": 32}]}
                with self.assertRaisesRegex(ValueError, "Missing same-native immutable declaration"):
                    self.verify()

    def test_numeric_immutable_missing_ast_is_not_waived_by_synthetic_join(self):
        self.verify()
        self.runtime()["immutableReferences"]["999"] = [{"start": 2, "length": 32}]
        with self.assertRaisesRegex(ValueError, "Missing same-native immutable declaration 999"):
            self.verify()

    def test_numeric_and_synthetic_joins_remain_separate(self):
        self.runtime()["object"] += "00" * 32
        self.runtime()["immutableReferences"]["11"] = [{"start": 35, "length": 32}]
        report = self.verify()
        self.assertEqual(len(report["librarySelfAddressJoins"]), 1)
        self.assertEqual(report["immutableJoins"][0]["declaration"], {"source": "Base.sol", "variable": "x"})

    def test_nonzero_placeholder_refuses(self):
        self.verify()
        self.runtime()["object"] = "307f01" + "00" * 31 + "14"
        with self.assertRaises(ValueError):
            self.verify()

    def test_invalid_ranges_and_empty_sites_refuse(self):
        self.verify()
        bad = [[], [{"start": -1, "length": 32}], [{"start": 4, "length": 32}],
               [{"start": 2, "length": 31}], [{"start": 2, "length": 33}],
               [{"start": 2.0, "length": 32}], [{"start": 2, "length": 32.0}],
               [{"start": True, "length": 32}], [{"start": 2, "length": True}]]
        for sites in bad:
            with self.subTest(sites=sites):
                self.runtime()["immutableReferences"] = {SYNTHETIC_ID: sites}
                with self.assertRaises(ValueError):
                    self.verify()

    def test_address_push32_eq_pattern_is_required(self):
        self.verify()
        for code in ("317f" + "00" * 32 + "14", "307e" + "00" * 32 + "14",
                     "307f" + "00" * 32 + "15", "307f" + "00" * 32):
            with self.subTest(code=code):
                self.runtime()["object"] = code
                with self.assertRaises(ValueError):
                    self.verify()

    def test_pattern_inside_push_immediate_is_not_an_instruction_sequence(self):
        self.verify()
        self.runtime()["object"] = "62" + "307f" + "00" * 32 + "14"
        self.runtime()["immutableReferences"][SYNTHETIC_ID] = [{"start": 3, "length": 32}]
        with self.assertRaises(ValueError):
            self.verify()


class CompletedCaptureAdmissionTests(unittest.TestCase):
    """All process records are explicitly synthetic; subprocesses are forbidden."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.capture = self.root / "capture"
        self.capture.mkdir()
        self.admission = self.root / "admission.json"
        self.replay_receipt = self.root / "replay.json"
        request, ai, ao, ni, no = library_fixture()
        values = {"requested-input.json": request, "selection.json": ni["settings"]["outputSelection"],
                  "analysis-input.json": ai, "analysis-output.json": ao,
                  "codegen-input.json": ni, "codegen-output.json": no}
        for name, value in values.items():
            (self.capture / name).write_bytes(scoped.canonical(value))
        (self.capture / "version.stdout").write_bytes(scoped.VERSION.encode() + b"\n")
        for name in ("version.stderr", "analysis-stderr.log", "codegen-stderr.log"):
            (self.capture / name).write_bytes(b"")
        self.arguments = ["--base-path", str(self.root), "--standard-json"]
        self.record = {
            "schema": 1, "status": "FAILED", "toolSha256": scoped.LEGACY_SELECTOR_TOOL,
            "compiler": str(self.root / "SYNTHETIC-NOT-AN-EXECUTABLE"),
            "compilerSha256": "12" * 32, "arguments": self.arguments, "timeoutSecondsPerPass": 30,
            "error": "Missing same-native immutable declaration library_deploy_address for Owner.sol:Owner; explicitly select its source",
            "passes": {},
            "files": {p.name: scoped.sha(p.read_bytes()) for p in self.capture.iterdir()},
        }
        for index, name in enumerate(("analysis", "codegen")):
            self.record["passes"][name] = {
                "status": "COMPLETE", "exitCode": 0, "pid": index + 1, "seconds": 0.001,
                "compilerSha256": self.record["compilerSha256"],
                "command": [self.record["compiler"], *self.arguments],
            }
        self.write_record()
        for method in ("run", "Popen"):
            patcher = mock.patch.object(scoped.subprocess, method, side_effect=AssertionError("No compiler invocation authorized"))
            patcher.start()
            self.addCleanup(patcher.stop)

    def write_record(self):
        (self.capture / "record.json").write_bytes(scoped.canonical(self.record))

    def snapshot(self):
        return {p.name: p.read_bytes() for p in self.capture.iterdir() if p.is_file()}

    def admit(self):
        return scoped.admit_completed_capture(self.capture, self.admission)

    def replay(self, *, raw=None, arguments=None, out=None):
        if raw is None:
            raw = (self.capture / "requested-input.json").read_bytes()
        stdout = out if out is not None else io.BytesIO()
        stderr = io.BytesIO()
        with mock.patch.object(scoped.sys, "stdin", SimpleNamespace(buffer=io.BytesIO(raw))), \
                mock.patch.object(scoped.sys, "stdout", SimpleNamespace(buffer=stdout)), \
                mock.patch.object(scoped.sys, "stderr", SimpleNamespace(buffer=stderr)):
            result = scoped.replay_capture(self.capture, self.admission, self.replay_receipt,
                                           self.arguments if arguments is None else arguments)
        return result, stdout.getvalue(), stderr.getvalue()

    def test_admission_binds_failed_record_files_tool_and_fresh_verification(self):
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "not verified"):
            scoped.read_capture(self.capture)
        admitted = self.admit()
        self.assertEqual(admitted["status"], "VERIFIED_TERMINAL_NATIVE")
        self.assertEqual(admitted["originalCaptureStatus"], "FAILED")
        self.assertEqual(admitted["originalCaptureRecordSha256"], scoped.sha(before["record.json"]))
        self.assertEqual(admitted["originalCaptureFiles"], self.record["files"])
        self.assertEqual(admitted["verifierSha256"], scoped.sha(Path(scoped.__file__).read_bytes()))
        self.assertEqual(len(admitted["verification"]["librarySelfAddressJoins"]), 1)
        analysis, native, record = scoped.read_capture(self.capture, admission=self.admission)
        self.assertEqual(record["status"], "FAILED")
        self.assertEqual(record["readmission"]["sha256"], scoped.sha(self.admission.read_bytes()))
        self.assertEqual(analysis["input"], json.loads(before["analysis-input.json"]))
        self.assertEqual(native["output"], json.loads(before["codegen-output.json"]))
        self.assertEqual(self.snapshot(), before)

    def test_admission_is_explicit_external_and_exclusive(self):
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "outside original capture"):
            scoped.admit_completed_capture(self.capture, self.capture / "admission.json")
        self.assertEqual(self.snapshot(), before)
        self.admit()
        receipt = self.admission.read_bytes()
        with self.assertRaises(FileExistsError):
            self.admit()
        self.assertEqual(self.admission.read_bytes(), receipt)
        self.assertEqual(self.snapshot(), before)

    def test_unknown_failure_status_tool_or_error_cannot_be_readmitted(self):
        original = copy.deepcopy(self.record)
        for field, value in (("status", "RUNNING"), ("status", "TIMEOUT"),
                             ("toolSha256", "00" * 32), ("error", "Different validation failure")):
            with self.subTest(field=field, value=value):
                self.record = copy.deepcopy(original)
                self.record[field] = value
                self.write_record()
                with self.assertRaises(ValueError):
                    self.admit()
                self.assertFalse(self.admission.exists())

    def test_incomplete_nonzero_or_different_process_evidence_refuses(self):
        original = copy.deepcopy(self.record)
        for stage in ("analysis", "codegen"):
            for field, value in (("status", "TIMEOUT"), ("exitCode", 1), ("exitCode", None),
                                 ("compilerSha256", "00" * 32), ("command", ["different"])):
                with self.subTest(stage=stage, field=field):
                    self.record = copy.deepcopy(original)
                    self.record["passes"][stage][field] = value
                    self.write_record()
                    with self.assertRaises(ValueError):
                        self.admit()
                    self.assertFalse(self.admission.exists())

    def test_boolean_exit_code_is_not_integer_zero_process_evidence(self):
        self.record["passes"]["codegen"]["exitCode"] = False
        self.write_record()
        with self.assertRaises(ValueError):
            self.admit()

    def test_boolean_schema_is_not_integer_schema_one(self):
        self.record["schema"] = True
        self.write_record()
        with self.assertRaises(ValueError):
            self.admit()

    def test_changed_missing_or_extra_capture_file_refuses(self):
        path = self.capture / "codegen-output.json"
        original = path.read_bytes()
        for mode in ("changed", "missing", "extra"):
            with self.subTest(mode=mode):
                if mode == "changed":
                    path.write_bytes(original + b" ")
                elif mode == "missing":
                    path.unlink()
                else:
                    (self.capture / "unexpected.json").write_bytes(b"{}")
                with self.assertRaisesRegex(ValueError, "Capture files changed"):
                    self.admit()
                path.write_bytes(original)
                if mode == "extra":
                    (self.capture / "unexpected.json").unlink()

    def test_old_error_label_does_not_replace_revalidation_of_actual_output(self):
        path = self.capture / "codegen-output.json"
        output = json.loads(path.read_bytes())
        output["contracts"]["Owner.sol"]["Owner"]["evm"]["deployedBytecode"]["immutableReferences"]["999"] = [
            {"start": 2, "length": 32}]
        path.write_bytes(scoped.canonical(output))
        self.record["files"][path.name] = scoped.sha(path.read_bytes())
        self.write_record()
        with self.assertRaisesRegex(ValueError, "Missing same-native immutable declaration 999"):
            self.admit()

    def test_altered_admission_or_original_record_refuses(self):
        self.admit()
        original_receipt = self.admission.read_bytes()
        for field, value in (("verifierSha256", "00" * 32), ("originalCaptureRecordSha256", "00" * 32),
                             ("verification", {})):
            with self.subTest(field=field):
                receipt = json.loads(original_receipt)
                receipt[field] = value
                self.admission.write_bytes(scoped.canonical(receipt))
                with self.assertRaisesRegex(ValueError, "Readmission receipt differs"):
                    scoped.read_capture(self.capture, admission=self.admission)
        self.admission.write_bytes(original_receipt)
        self.record["passes"]["codegen"]["seconds"] = 9
        self.write_record()
        with self.assertRaisesRegex(ValueError, "Readmission receipt differs"):
            scoped.read_capture(self.capture, admission=self.admission)

    def test_build_binding_requires_explicit_admission_and_retains_it_in_evidence(self):
        self.admit()
        build = {
            "solcVersion": "0.8.19", "id": "synthetic-build",
            "input": json.loads((self.capture / "requested-input.json").read_bytes()),
            "output": json.loads((self.capture / "codegen-output.json").read_bytes()),
        }
        before = copy.deepcopy(build)
        with self.assertRaisesRegex(ValueError, "not verified"):
            scoped.bind_build_capture(build, self.capture)
        context, analysis, evidence = scoped.bind_build_capture(build, self.capture, admission=self.admission)
        self.assertEqual(build, before)
        self.assertEqual(context["input"], json.loads((self.capture / "codegen-input.json").read_bytes()))
        self.assertEqual(analysis["input"], json.loads((self.capture / "analysis-input.json").read_bytes()))
        self.assertEqual(evidence["readmission"]["sha256"], scoped.sha(self.admission.read_bytes()))
        self.assertEqual(evidence["captureRecordSha256"], scoped.sha((self.capture / "record.json").read_bytes()))

    def test_replay_returns_only_original_bytes_once_and_preserves_capture(self):
        self.admit()
        before = self.snapshot()
        result, stdout, stderr = self.replay()
        self.assertEqual(result, 0)
        self.assertEqual(stdout, before["codegen-output.json"])
        self.assertEqual(stderr, before["codegen-stderr.log"])
        receipt = json.loads(self.replay_receipt.read_bytes())
        self.assertEqual(receipt["status"], "COMPLETE")
        self.assertEqual(receipt["nativeInvocations"], 0)
        self.assertEqual(receipt["nativeOutputSha256"], scoped.sha(stdout))
        self.assertEqual(receipt["admissionSha256"], scoped.sha(self.admission.read_bytes()))
        self.assertEqual(receipt["arguments"], self.arguments)
        second_stdout = io.BytesIO()
        with self.assertRaises(FileExistsError):
            self.replay(out=second_stdout)
        self.assertEqual(second_stdout.getvalue(), b"")
        self.assertEqual(self.snapshot(), before)

    def test_replay_changed_request_or_arguments_refuses_before_output(self):
        self.admit()
        original = json.loads((self.capture / "requested-input.json").read_bytes())
        changes = []
        source = copy.deepcopy(original)
        source["sources"]["Owner.sol"]["content"] += " "
        changes.append(source)
        settings = copy.deepcopy(original)
        settings["settings"]["optimizer"]["runs"] = 201
        changes.append(settings)
        selection = copy.deepcopy(original)
        selection["settings"]["outputSelection"] = {"*": {"*": ["evm.bytecode"]}}
        changes.append(selection)
        for changed in changes:
            with self.subTest(changed=changed), self.assertRaisesRegex(ValueError, "requested input differs"):
                self.replay(raw=scoped.canonical(changed))
            self.assertFalse(self.replay_receipt.exists())
        with self.assertRaisesRegex(ValueError, "arguments differ"):
            self.replay(arguments=["--standard-json"])
        self.assertFalse(self.replay_receipt.exists())

    def test_version_replay_uses_retained_bytes_without_consuming_standard_json_receipt(self):
        self.admit()
        result, stdout, stderr = self.replay(arguments=["--version"])
        self.assertEqual(result, 0)
        self.assertEqual(stdout, (self.capture / "version.stdout").read_bytes())
        self.assertEqual(stderr, (self.capture / "version.stderr").read_bytes())
        self.assertFalse(self.replay_receipt.exists())
        self.assertEqual(self.replay()[0], 0)

    def test_failed_output_stream_retains_failed_receipt_and_consumes_attempt(self):
        class BrokenOutput(io.BytesIO):
            def write(self, value):
                raise BrokenPipeError("synthetic closed Forge stream")

        self.admit()
        before = self.snapshot()
        with self.assertRaises(BrokenPipeError):
            self.replay(out=BrokenOutput())
        self.assertEqual(json.loads(self.replay_receipt.read_bytes())["status"], "FAILED")
        with self.assertRaises(FileExistsError):
            self.replay()
        self.assertEqual(self.snapshot(), before)


class AdmissionMappingTests(unittest.TestCase):
    def test_admission_without_capture_mapping_refuses_before_project_io(self):
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary) / "not-created"
            with self.assertRaisesRegex(ValueError, "[Aa]dmission"), \
                    mock.patch.object(graph.os, "open", side_effect=AssertionError("Invalid mapping must precede preparation lock")):
                graph.prepare(project, project / "products.json",
                              compiler_admissions={"build-a": Path(temporary) / "admission.json"})
            self.assertFalse(project.exists())

    def test_unknown_admission_build_id_does_not_borrow_another_capture(self):
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary) / "not-created"
            with self.assertRaisesRegex(ValueError, "[Aa]dmission"), \
                    mock.patch.object(graph.os, "open", side_effect=AssertionError("Invalid mapping must precede preparation lock")):
                graph.prepare(project, project / "products.json",
                              compiler_captures={"build-a": Path(temporary) / "capture"},
                              compiler_admissions={"build-b": Path(temporary) / "admission.json"})
            self.assertFalse(project.exists())


if __name__ == "__main__":
    unittest.main()
