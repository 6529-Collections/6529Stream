"""Hostile capture and opcode tests; synthetic fixtures are not compiler evidence."""
from __future__ import annotations

import contextlib
import copy
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.build import check_instant_provider_runtime as checker


class InstantProviderRuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.dependency = "smart-contracts/interfaces/stream/entropy/IStreamInstantEntropyProvider.sol"
        contents = {checker.SOURCE: 'pragma solidity ^0.8.19;\ncontract StreamEntropyProviderInstant {}\n',
                    self.dependency: 'pragma solidity ^0.8.19;\ninterface IStreamInstantEntropyProvider {}\n'}
        for name, content in contents.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content.encode())
        settings = {"viaIR": True, "optimizer": {"enabled": True, "runs": 200},
                    "evmVersion": "paris", "metadata": {"bytecodeHash": "none", "appendCBOR": False}}
        self.input = {"language": "Solidity", "settings": copy.deepcopy(settings),
                      "sources": {name: {"content": content} for name, content in contents.items()}}
        self.metadata = {"language": "Solidity", "compiler": {"version": checker.COMPILER},
                         "settings": {**settings, "compilationTarget": {checker.SOURCE: checker.CONTRACT}},
                         "sources": {name: {"keccak256": "0x" + checker.keccak256(content.encode()).hex()}
                                     for name, content in contents.items()}}
        self.artifact = {"metadata": json.dumps(self.metadata), "evm": {"deployedBytecode": {
            "object": "60003560005260206000f3", "linkReferences": {}, "immutableReferences": {}}}}
        self.output = {"contracts": {checker.SOURCE: {checker.CONTRACT: self.artifact}}, "errors": []}

    def validate(self) -> dict:
        return checker.validate(self.input, self.output, self.root)

    def refresh_metadata(self) -> None:
        self.artifact["metadata"] = json.dumps(self.metadata)

    @staticmethod
    def runtime(code: str, refs: dict | None = None) -> dict:
        return {"object": code, "linkReferences": {}, "immutableReferences": refs or {}}

    def test_exact_capture_binds_current_sources_metadata_profile_and_runtime(self) -> None:
        report = self.validate()
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["target"], checker.TARGET)
        self.assertEqual(report["input_source_count"], 2)
        self.assertEqual(report["verified_source_count"], 2)
        self.assertEqual(report["metadata_source_count"], 2)
        self.assertEqual(report["runtime_bytes"], 11)
        self.assertEqual(report["instructions"], 7)
        self.assertEqual(checker.keccak256(b"").hex(),
                         "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")

    def test_each_external_write_create_log_opcode_is_rejected_even_after_stop(self) -> None:
        for opcode, name in checker.FORBIDDEN.items():
            with self.subTest(opcode=name):
                with self.assertRaisesRegex(checker.RuntimeCheckError, f"Forbidden {name}.*byte 1"):
                    checker.scan_runtime(self.runtime("00" + bytes([opcode]).hex()))

    def test_every_push_width_skips_immediate_opcodes_without_skipping_next_instruction(self) -> None:
        forbidden = bytes(checker.FORBIDDEN)
        for width in range(1, 33):
            with self.subTest(width=width):
                data = (forbidden * 3)[:width]
                code = bytes([0x5F + width]) + data + b"\x00"
                report = checker.scan_runtime(self.runtime(code.hex()))
                self.assertEqual(report["instructions"], 2)
                with self.assertRaisesRegex(checker.RuntimeCheckError, "Forbidden CALL"):
                    checker.scan_runtime(self.runtime((code + b"\xf1").hex()))

    def test_truncated_push_and_non_paris_opcodes_fail_closed(self) -> None:
        for code in ("60", "6100", "7f" + "00" * 31):
            with self.subTest(code=code), self.assertRaisesRegex(checker.RuntimeCheckError, "Truncated PUSH"):
                checker.scan_runtime(self.runtime(code))
        for opcode in (0x0C, 0x49, 0x4A, 0x5C, 0x5E, 0x5F):
            with self.subTest(opcode=opcode), self.assertRaisesRegex(checker.RuntimeCheckError, "Non-Paris"):
                checker.scan_runtime(self.runtime(bytes([opcode]).hex()))

    def test_immutable_data_changes_only_masked_hash_and_is_never_scanned_as_code(self) -> None:
        refs = {"12": [{"start": 1, "length": 32}]}
        first = checker.scan_runtime(self.runtime("7f" + "f1" * 32 + "00", refs))
        second = checker.scan_runtime(self.runtime("7f" + "55" * 32 + "00", refs))
        self.assertNotEqual(first["runtime_sha256"], second["runtime_sha256"])
        self.assertEqual(first["immutable_masked_runtime_sha256"], second["immutable_masked_runtime_sha256"])
        self.assertEqual(first["instructions"], 2)

    def test_immutable_ranges_cannot_mask_opcode_span_pushes_or_overlap(self) -> None:
        code = "6001600200"
        bad = [
            {"1": [{"start": 0, "length": 1}]},
            {"1": [{"start": 1, "length": 3}]},
            {"1": [{"start": 4, "length": 1}]},
            {"1": [{"start": 5, "length": 1}]},
            {"1": [{"start": -1, "length": 1}]},
            {"1": [{"start": 1, "length": 0}]},
            {"1": [{"start": True, "length": 1}]},
            {"1": [{"start": 1, "length": 1}], "2": [{"start": 1, "length": 1}]},
            {"1": []}, {"not-an-ast-id": [{"start": 1, "length": 1}]},
        ]
        for refs in bad:
            with self.subTest(refs=refs), self.assertRaises(checker.RuntimeCheckError):
                checker.scan_runtime(self.runtime(code, refs))
        with self.assertRaisesRegex(checker.RuntimeCheckError, "Forbidden SSTORE"):
            checker.scan_runtime(self.runtime("600155", {"1": [{"start": 2, "length": 1}]}))

    def test_absent_runtime_links_and_nonhex_cannot_substitute_for_exact_artifact(self) -> None:
        for code in ("", "0x00", "0", "zz", "__" + "x" * 36 + "__", "__$" + "a" * 34 + "$__"):
            with self.subTest(code=code), self.assertRaises(checker.RuntimeCheckError):
                checker.scan_runtime(self.runtime(code))
        for field in ("linkReferences", "immutableReferences"):
            value = self.runtime("00")
            del value[field]
            with self.subTest(field=field), self.assertRaises(checker.RuntimeCheckError):
                checker.scan_runtime(value)
        value = self.runtime("00")
        value["linkReferences"] = {"Lib.sol": {"Lib": [{"start": 0, "length": 20}]}}
        with self.assertRaisesRegex(checker.RuntimeCheckError, "link references"):
            checker.scan_runtime(value)

    def test_crlf_transport_is_explicit_and_whitespace_or_dependency_changes_reject(self) -> None:
        for name in self.input["sources"]:
            path = self.root / name
            path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        self.assertEqual({row["transport"] for row in self.validate()["sources"]}, {"CRLF-to-LF"})
        for name in (checker.SOURCE, self.dependency):
            path = self.root / name
            original = path.read_bytes()
            path.write_bytes(original + b" ")
            with self.subTest(name=name), self.assertRaisesRegex(checker.RuntimeCheckError, "Stale or changed"):
                self.validate()
            path.write_bytes(original)

    def test_nonproject_paths_and_url_sources_reject(self) -> None:
        for name in ("../secret.sol", "/secret.sol", "C:/secret.sol", "smart-contracts/../x.sol", "a\\b.sol"):
            with self.subTest(name=name):
                self.input["sources"][name] = {"content": ""}
                self.metadata["sources"][name] = {"keccak256": "0x" + checker.keccak256(b"").hex()}
                self.refresh_metadata()
                with self.assertRaisesRegex(checker.RuntimeCheckError, "Non-project source"):
                    self.validate()
                del self.input["sources"][name]
                del self.metadata["sources"][name]
                self.refresh_metadata()
        self.input["sources"][self.dependency] = {"urls": ["https://example.invalid/source.sol"]}
        with self.assertRaisesRegex(checker.RuntimeCheckError, "Literal source"):
            self.validate()

    def test_compiler_errors_abi_only_and_wrong_artifact_target_reject(self) -> None:
        self.output["errors"] = [{"severity": "warning"}]
        self.validate()
        self.output["errors"] = [{"severity": "error", "message": "source failed"}]
        with self.assertRaisesRegex(checker.RuntimeCheckError, "contains errors"):
            self.validate()
        self.output["errors"] = []
        saved = self.artifact.pop("evm")
        with self.assertRaisesRegex(checker.RuntimeCheckError, "artifact.evm"):
            self.validate()
        self.artifact["evm"] = saved
        self.metadata["settings"]["compilationTarget"] = {checker.SOURCE: "MockInstant"}
        self.refresh_metadata()
        with self.assertRaisesRegex(checker.RuntimeCheckError, "compilation target"):
            self.validate()

    def test_wrong_compiler_and_profile_drift_in_either_input_or_metadata_reject(self) -> None:
        self.metadata["compiler"]["version"] = "0.8.20+commit.a1b79de6"
        self.refresh_metadata()
        with self.assertRaisesRegex(checker.RuntimeCheckError, "Compiler must"):
            self.validate()
        self.metadata["compiler"]["version"] = checker.COMPILER
        for origin in (self.input, self.metadata):
            original = copy.deepcopy(origin["settings"])
            changes = {"viaIR": False, "evmVersion": "shanghai", "debug": {"revertStrings": "strip"},
                       "optimizer": {"enabled": True, "runs": 201},
                       "metadata": {"bytecodeHash": "ipfs", "appendCBOR": True},
                       "libraries": {"Lib.sol": {"Lib": "0x" + "01" * 20}}}
            for key, value in changes.items():
                with self.subTest(origin="input" if origin is self.input else "metadata", key=key):
                    origin["settings"] = {**copy.deepcopy(original), key: value}
                    self.refresh_metadata()
                    with self.assertRaises(checker.RuntimeCheckError):
                        self.validate()
            origin["settings"] = original
            self.refresh_metadata()

    def test_metadata_must_bind_target_and_each_reported_source(self) -> None:
        original = copy.deepcopy(self.metadata["sources"])
        for name in original:
            self.metadata["sources"][name]["keccak256"] = "0x" + "00" * 32
            self.refresh_metadata()
            with self.subTest(name=name), self.assertRaisesRegex(checker.RuntimeCheckError, "source binding"):
                self.validate()
            self.metadata["sources"] = copy.deepcopy(original)
        del self.metadata["sources"][checker.SOURCE]
        self.refresh_metadata()
        with self.assertRaisesRegex(checker.RuntimeCheckError, "omits approved"):
            self.validate()
        self.metadata["sources"] = original
        self.refresh_metadata()
        del self.input["sources"][self.dependency]
        with self.assertRaisesRegex(checker.RuntimeCheckError, "Metadata source absent from compiler input"):
            self.validate()

    def test_strict_json_rejects_duplicate_members_nonjson_numbers_and_invalid_utf8(self) -> None:
        for raw in (b'{"language":"Solidity","language":"Yul"}', b'{"n":NaN}', b'{"n":Infinity}',
                    b'\xff', '{"language":"Solidity"}'.encode("utf-16")):
            with self.subTest(raw=raw), self.assertRaises(checker.RuntimeCheckError):
                checker._json(raw, "test capture")

    def test_capture_file_hashes_and_cli_json_exit_codes_without_writing_capture(self) -> None:
        input_path, output_path = self.root / "input.json", self.root / "output.json"
        input_path.write_text(json.dumps(self.input), encoding="utf-8")
        output_path.write_text(json.dumps(self.output), encoding="utf-8")
        raw_input, raw_output = input_path.read_bytes(), output_path.read_bytes()
        report = checker.check_capture(input_path, output_path, self.root)
        self.assertEqual(report["input_sha256"], checker._sha(raw_input))
        self.assertEqual(report["output_sha256"], checker._sha(raw_output))
        with mock.patch.object(checker, "check_capture", return_value=report), contextlib.redirect_stdout(io.StringIO()) as stream:
            self.assertEqual(checker.main(["--input", str(input_path), "--output", str(output_path)]), 0)
            self.assertEqual(json.loads(stream.getvalue())["status"], "passed")
        with mock.patch.object(checker, "check_capture", side_effect=checker.RuntimeCheckError("forbidden")), contextlib.redirect_stdout(io.StringIO()) as stream:
            self.assertEqual(checker.main(["--input", str(input_path), "--output", str(output_path)]), 1)
            self.assertEqual(json.loads(stream.getvalue())["error"], "forbidden")
        self.assertEqual(input_path.read_bytes(), raw_input)
        self.assertEqual(output_path.read_bytes(), raw_output)

    def foundry_capture(self) -> tuple[Path, Path, Path, Path]:
        out, cache = self.root / "out", self.root / "cache"
        (out / "build-info").mkdir(parents=True)
        cache.mkdir()
        relative = Path(checker.SOURCE).name + "/" + checker.CONTRACT + ".json"
        cache_value = {"files": {checker.SOURCE: {"artifacts": {checker.CONTRACT: {"0.8.19": {
            "current": {"path": relative, "build_id": "a123"}}}}}}}
        (cache / "solidity-files-cache.json").write_text(json.dumps(cache_value), encoding="utf-8")
        build_file = out / "build-info/a123.json"
        build = {"id": "a123", "solcVersion": "0.8.19", "input": self.input, "output": self.output}
        build_file.write_text(json.dumps(build), encoding="utf-8")
        artifact_file = out / relative
        artifact_file.parent.mkdir()
        artifact = {"deployedBytecode": copy.deepcopy(self.artifact["evm"]["deployedBytecode"]),
                    "rawMetadata": self.artifact["metadata"], "metadata": self.metadata}
        artifact["deployedBytecode"]["object"] = "0x" + artifact["deployedBytecode"]["object"]
        artifact_file.write_text(json.dumps(artifact), encoding="utf-8")
        return out, cache, build_file, artifact_file

    def test_foundry_selects_cache_owner_not_newer_emission_and_binds_exact_artifact(self) -> None:
        out, cache, build, artifact = self.foundry_capture()
        (out / "build-info/ffff.json").write_text('{"id":"ffff","input":{}}', encoding="utf-8")
        report = checker.check_foundry(out, cache, self.root)
        self.assertEqual(report["build_id"], "a123")
        self.assertEqual(report["build_info_sha256"], checker._sha(build.read_bytes()))
        self.assertEqual(report["artifact_sha256"], checker._sha(artifact.read_bytes()))
        with mock.patch.object(checker, "check_foundry", return_value=report), contextlib.redirect_stdout(io.StringIO()) as stream:
            self.assertEqual(checker.main(["--out", str(out), "--cache-path", str(cache)]), 0)
            self.assertEqual(json.loads(stream.getvalue())["build_id"], "a123")

    def test_unused_compiler_context_edits_are_allowed_but_target_dependencies_remain_current(self) -> None:
        unrelated = "test/Unrelated.t.sol"
        self.input["sources"][unrelated] = {"content": "old unrelated source\n"}
        path = self.root / unrelated
        path.parent.mkdir()
        path.write_bytes(b"new unrelated source\n")
        out, cache, build_file, _ = self.foundry_capture()
        before = build_file.read_bytes()
        report = checker.check_foundry(out, cache, self.root)
        self.assertEqual(report["input_source_count"], 3)
        self.assertEqual(report["verified_source_count"], 2)
        self.assertEqual({row["path"] for row in report["sources"]}, {checker.SOURCE, self.dependency})
        self.assertEqual(report["build_info_sha256"], checker._sha(before))
        for name in (checker.SOURCE, self.dependency):
            selected = self.root / name
            original = selected.read_bytes()
            selected.write_bytes(original + b"// changed\n")
            with self.subTest(name=name), self.assertRaisesRegex(checker.RuntimeCheckError, "Stale or changed"):
                checker.check_foundry(out, cache, self.root)
            selected.write_bytes(original)
        self.assertEqual(build_file.read_bytes(), before)

    def test_missing_stale_ambiguous_and_misbound_cache_builds_reject(self) -> None:
        out, cache, build_file, _ = self.foundry_capture()
        cache_file = cache / "solidity-files-cache.json"
        original = json.loads(cache_file.read_bytes())
        bad = copy.deepcopy(original)
        entries = bad["files"][checker.SOURCE]["artifacts"][checker.CONTRACT]["0.8.19"]
        entries["default"] = dict(entries["current"], build_id="ffff")
        cache_file.write_text(json.dumps(bad), encoding="utf-8")
        with self.assertRaisesRegex(checker.RuntimeCheckError, "unambiguous"):
            checker.check_foundry(out, cache, self.root)
        cache_file.write_text('{"files":{}}', encoding="utf-8")
        with self.assertRaisesRegex(checker.RuntimeCheckError, "Cannot select"):
            checker.check_foundry(out, cache, self.root)
        cache_file.write_text(json.dumps(original), encoding="utf-8")
        build = json.loads(build_file.read_bytes())
        for field, value in (("id", "ffff"), ("solcVersion", "0.8.20")):
            with self.subTest(field=field):
                bad_build = {**build, field: value}
                build_file.write_text(json.dumps(bad_build), encoding="utf-8")
                with self.assertRaises(checker.RuntimeCheckError):
                    checker.check_foundry(out, cache, self.root)
        build_file.write_text(json.dumps(build), encoding="utf-8")
        (self.root / self.dependency).write_bytes(b"changed dependency")
        with self.assertRaisesRegex(checker.RuntimeCheckError, "Stale or changed"):
            checker.check_foundry(out, cache, self.root)

    def test_cache_artifact_runtime_immutable_links_and_metadata_must_equal_owner(self) -> None:
        out, cache, _, artifact_file = self.foundry_capture()
        original = json.loads(artifact_file.read_bytes())
        changes = (("object", "0x00"), ("immutableReferences", {"1": [{"start": 1, "length": 1}]}),
                   ("linkReferences", {"Lib": {}}))
        for field, value in changes:
            with self.subTest(field=field):
                artifact = copy.deepcopy(original)
                artifact["deployedBytecode"][field] = value
                artifact_file.write_text(json.dumps(artifact), encoding="utf-8")
                with self.assertRaisesRegex(checker.RuntimeCheckError, "Cached artifact"):
                    checker.check_foundry(out, cache, self.root)
        artifact = copy.deepcopy(original)
        artifact["rawMetadata"] = "{}"
        artifact_file.write_text(json.dumps(artifact), encoding="utf-8")
        with self.assertRaisesRegex(checker.RuntimeCheckError, "Cached artifact metadata"):
            checker.check_foundry(out, cache, self.root)

    def test_foundry_lossy_parsed_metadata_accepts_omissions_but_not_wrong_target_or_raw(self) -> None:
        self.metadata["settings"].update({"libraries": {}, "remappings": []})
        self.metadata["output"] = {"abi": [], "devdoc": {
            "kind": "dev", "methods": {}, "version": 1, "details": "Provider documentation"}}
        self.refresh_metadata()
        out, cache, _, artifact_file = self.foundry_capture()
        artifact = json.loads(artifact_file.read_bytes())
        parsed = artifact["metadata"]
        del parsed["settings"]["libraries"]
        del parsed["settings"]["remappings"]
        del parsed["output"]["devdoc"]["details"]
        artifact_file.write_text(json.dumps(artifact), encoding="utf-8")
        self.assertEqual(checker.check_foundry(out, cache, self.root)["status"], "passed")
        parsed["settings"]["compilationTarget"] = {checker.SOURCE: "OtherProvider"}
        artifact_file.write_text(json.dumps(artifact), encoding="utf-8")
        with self.assertRaisesRegex(checker.RuntimeCheckError, "parsed metadata compilation target"):
            checker.check_foundry(out, cache, self.root)
        parsed["settings"]["compilationTarget"] = {checker.SOURCE: checker.CONTRACT}
        raw = json.loads(artifact["rawMetadata"])
        raw["sources"][checker.SOURCE]["keccak256"] = "0x" + "00" * 32
        artifact["rawMetadata"] = json.dumps(raw)
        artifact_file.write_text(json.dumps(artifact), encoding="utf-8")
        with self.assertRaisesRegex(checker.RuntimeCheckError, "Cached artifact metadata differs"):
            checker.check_foundry(out, cache, self.root)

    def test_cli_requires_exactly_one_complete_capture_mode(self) -> None:
        for args in (["--input", "input.json"], ["--out", "out"],
                     ["--input", "i", "--output", "o", "--cache-path", "cache"],
                     ["--out", "out", "--cache-path", "cache", "--output", "o"]):
            with self.subTest(args=args), contextlib.redirect_stdout(io.StringIO()) as stream:
                self.assertEqual(checker.main(args), 1)
                self.assertEqual(json.loads(stream.getvalue())["status"], "failed")
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as result:
            checker.main(["--input", "i", "--output", "o", "--out", "out", "--cache-path", "cache"])
        self.assertEqual(result.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
