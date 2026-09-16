"""Byte-closure negatives plus an opt-in real restored Windows interpreter run.

Set STREAM_METRIC_RUNTIME_TEST=1 with the existing museum interpreter for the
native test. It copies only task-local runtime files; no installs or network.
"""
import copy
import contextlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tools.preservation import reference_metric as metric
from tools.preservation import reference_metric_package as p
from tools.preservation.test_reference_metric import png


def environment(rows, prerequisites=()):
    value = {"objectHash": "0x" + "a1" * 32, "coverageHash": "0x" + "b2" * 32,
             "packageFiles": rows, "platformPrerequisites": list(prerequisites)}
    # Explicit synthetic publication environment: no browser/capture/source authority claim.
    raw = p.canonical({"runtimeObjectHash": value["objectHash"],
                       "packageFiles": [{**r, "byteSize": str(r["byteSize"])} for r in rows],
                       "platformPrerequisites": [{**r, "byteSize": str(r["byteSize"])} for r in prerequisites]})
    value["manifestHash"] = p.keccak256(raw)
    return value, raw


def fixture_members(material):
    files = {p.SOURCE_ROOT + "/" + r["path"]: p.blob(r["content"]) for r in material["sources"]}
    files.update({p.SOURCE_ROOT + "/" + n: (p.ROOT / n).read_bytes() for n in p.SUPPORT})
    files.update({p.INDEX: p.blob(material["implementationIndex"]),
                  p.PARAMETERS: p.blob(material["parameters"]),
                  p.LAUNCHER: Path(p.__file__).with_name("metric_runtime_launcher.py").read_bytes(),
                  p.INTERPRETER: b"explicit byte-only test fixture, not an executable",
                  "metric/distributions.json": b"[]", "metric/python/python313._pth": b"python313.zip\nDLLs\n.\n"})
    return files


def coverage(archive, env):
    observed = p.inspect(archive)
    return {"objectHash": env["objectHash"], "coverageHash": env["coverageHash"],
            "byteSize": observed["byteSize"], "sha256Digest": "0x" + observed["sha256"],
            "contentHash": "0x" + observed["keccak256"], "arweaveDataRoot": "0x" + observed["arweaveDataRoot"]}


class MetricPackageTests(unittest.TestCase):
    def setUp(self):
        self.material = p.source_material()
        self.files = fixture_members(self.material)
        self.rows = [p.file_row(n, raw) for n, raw in sorted(self.files.items())]
        self.env, self.raw = environment(self.rows)
        self.supplement = p.bind(self.material, self.env, self.raw, metric.metric())

    def verify(self, supplement=None, env=None, raw=None):
        return p.verify_declaration(supplement or self.supplement, env or self.env,
                                    raw or self.raw, metric.metric())

    def test_original_metric_and_hash_preimages_round_trip_without_source_rewrite(self):
        self.assertEqual(self.verify(), p.runtime_hash(self.supplement["runtime"]))
        self.assertEqual(p.keccak256(p.blob(self.material["implementationIndex"])), metric.metric()[4])
        self.assertEqual(p.blob(self.material["parameters"]), metric.canonical(metric.PARAMETERS))
        self.assertEqual([r["path"] for r in self.material["sources"]], list(p.SOURCES))

    def test_missing_complete_source_refused_even_if_all_metric_hashes_present(self):
        candidate = copy.deepcopy(self.supplement)
        candidate["sources"].pop()
        with self.assertRaisesRegex(ValueError, "source shape"):
            self.verify(candidate)

    def test_changed_raw_source_line_endings_cannot_reuse_original_hash(self):
        candidate = copy.deepcopy(self.supplement)
        candidate["sources"][0]["content"] += "0d0a"
        with self.assertRaisesRegex(ValueError, "preimage"):
            self.verify(candidate)

    def test_parameter_bytes_and_canonicalization_are_required(self):
        for raw in (b"{}", p.blob(self.material["parameters"]) + b"\n"):
            candidate = copy.deepcopy(self.supplement)
            candidate["parameters"] = "0x" + raw.hex()
            with self.assertRaises(ValueError):
                self.verify(candidate)

    def test_implementation_index_order_is_exact_not_equivalent_json(self):
        candidate = copy.deepcopy(self.supplement)
        values = json.loads(p.blob(candidate["implementationIndex"]))
        candidate["implementationIndex"] = "0x" + json.dumps(values, indent=2).encode().hex()
        with self.assertRaisesRegex(ValueError, "preimage"):
            self.verify(candidate)

    def test_wrong_archive_environment_cannot_supply_otherwise_valid_members(self):
        candidate = copy.deepcopy(self.supplement)
        candidate["runtime"]["environmentObjectHash"] = "0x" + "c3" * 32
        with self.assertRaisesRegex(ValueError, "same publication"):
            self.verify(candidate)

    def test_metric_subtree_omission_cannot_hide_unlisted_native_dependency(self):
        candidate = copy.deepcopy(self.supplement)
        candidate["runtime"]["members"].pop()
        with self.assertRaisesRegex(ValueError, "complete same-package"):
            self.verify(candidate)

    def test_parameter_file_must_be_in_same_hashed_environment(self):
        rows = [r for r in self.rows if r["path"] != p.PARAMETERS]
        env, raw = environment(rows)
        with self.assertRaisesRegex(ValueError, "required metric bytes"):
            p.bind(self.material, env, raw, metric.metric())

    def test_host_paths_and_custom_launch_switches_are_refused(self):
        for key, value in (("interpreter", sys.executable), ("argv", ["-m", "pip"]),
                           ("sourceRoot", "../outside"), ("launcher", "other.py")):
            candidate = copy.deepcopy(self.supplement)
            candidate["runtime"][key] = value
            with self.assertRaisesRegex(ValueError, "closed isolated"):
                self.verify(candidate)

    def test_host_environment_opaque_hash_cannot_disagree_with_package_fields(self):
        changed = copy.deepcopy(self.env)
        changed["packageFiles"] = changed["packageFiles"][:-1]
        with self.assertRaisesRegex(ValueError, "hashed environment"):
            self.verify(env=changed)

    def test_duplicate_case_alias_and_traversal_fail_before_extraction(self):
        for name in ("../escape", "C:/escape", "metric/CON.py", "metric/a/../b"):
            with self.assertRaises(ValueError):
                p._rows([{"path": name, "byteSize": 1, "sha256Digest": "0x" + "11" * 32}])
        with self.assertRaisesRegex(ValueError, "canonical complete"):
            p._rows([p.file_row("metric/A", b"a"), p.file_row("metric/a", b"b")])

    def test_complete_zip_round_trip_and_missing_extra_or_changed_bytes_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "runtime.zip"
            p._write_zip(archive, sorted(self.files.items()))
            expected = coverage(archive, self.env)
            restored = Path(directory) / "restore"
            restored.mkdir()
            p.verify_archive(archive, self.env, expected, restored)
            self.assertEqual((restored / p.PARAMETERS).read_bytes(), p.blob(self.material["parameters"]))
            altered = dict(self.files)
            altered[p.PARAMETERS] = b"{}"
            wrong = Path(directory) / "wrong.zip"
            p._write_zip(wrong, sorted(altered.items()))
            with self.assertRaisesRegex(ValueError, "whole archive"):
                p.verify_archive(wrong, self.env, expected)
            with self.assertRaisesRegex(ValueError, "member bytes"):
                p.verify_archive(wrong, self.env, coverage(wrong, self.env))
            altered.pop(p.PARAMETERS)
            missing = Path(directory) / "missing.zip"
            p._write_zip(missing, sorted(altered.items()))
            with self.assertRaisesRegex(ValueError, "complete bounded"):
                p.verify_archive(missing, self.env, coverage(missing, self.env))

    def test_duplicate_json_fields_and_noncanonical_hex_refused(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            p.read_json(b'{"x":1,"x":2}')
        with self.assertRaisesRegex(ValueError, "noncanonical"):
            p.blob("0xAB")

    def test_unknown_supplement_field_is_not_silently_excluded_from_abi(self):
        candidate = {**self.supplement, "otherRuntime": "host installation"}
        with self.assertRaisesRegex(ValueError, "closed metric supplement"):
            self.verify(candidate)

    def test_store_chunks_preserve_original_abi_order_hash_and_zero_value_calls(self):
        payload = bytes(range(256)) * 65 + b"last"
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "chunks"
            record = p.chunk_payload(payload, output)
            self.assertEqual([r["byteSize"] for r in record["chunks"]], [8192, 8192, 260])
            restored = b"".join((output / r["path"]).read_bytes() for r in record["chunks"])
            self.assertEqual(restored, payload)
            self.assertEqual(record["payloadHash"], p.keccak256(restored))
            for row in record["chunks"]:
                raw = (output / row["path"]).read_bytes()
                call = p.blob(row["data"])
                self.assertEqual(call[:4], p.blob(p.keccak256(b"publishChunk(bytes)"))[:4])
                self.assertEqual(int.from_bytes(call[4:36], "big"), 32)
                self.assertEqual(int.from_bytes(call[36:68], "big"), len(raw))
                self.assertEqual(call[68:68 + len(raw)], raw)
                self.assertEqual(row["chunkHash"], p.keccak256(raw))
                self.assertEqual(row["value"], "0")

    def _attributed_receipt(self):
        # A deliberately synthetic execution assertion tests verification only;
        # it must never be counted as an actual process/native acceptance case.
        image = png([[(90, 90, 90)] * 11] * 11)
        inputs = {"contextHash": "0x" + "12" * 32, "environmentHash": p.keccak256(self.raw),
                  "threshold": 999999999, "evaluatedAt": 1,
                  "captures": [{"firstSha256": p.sha(image), "secondSha256": p.sha(image), "width": 11, "height": 11}]}
        report = metric.measure(inputs, self.raw, [(image, image)])
        receipt = {"runtimeHash": p.runtime_hash(self.supplement["runtime"]), "contextHash": inputs["contextHash"],
                   "reportHash": report["reportHash"], "inputsHash": p.keccak256(p.canonical(inputs)),
                   "inputManifest": "0x" + p.canonical(inputs).hex(), "executedAt": 2, "exitCode": 0}
        result = {"profile": "STREAM_METRIC_RESTORED_REPLAY_V1", "report": report,
                  "pythonModules": [{"name": "synthetic", "path": p.ENTRYPOINT, "origin": "file"}],
                  "nativeMembers": [p.INTERPRETER], "platformPrerequisites": [],
                  "disabledFallbackProbes": ["network", "process"], "qualification": "Synthetic attributed assertion; not executed."}
        transcript = {k: v for k, v in receipt.items() if k != "inputManifest"}
        transcript["result"] = result
        receipt["transcript"] = "0x" + p.wrap_transcript(receipt, p.canonical(transcript)).hex()
        return {**self.supplement, "replay": receipt}, inputs, report["reportHash"]

    def test_rehashed_cross_environment_assertion_cannot_reuse_original_report(self):
        supplement, inputs, report_hash = self._attributed_receipt()
        p.verify_replay_receipt(supplement, self.env, self.raw, metric.metric(), inputs, report_hash)
        original_preimage = json.loads(p.unwrap_transcript(supplement["replay"]))["result"]["report"]["reportPreimageABI"]
        inputs["environmentHash"] = "0x" + "99" * 32
        receipt = supplement["replay"]
        transcript = json.loads(p.unwrap_transcript(receipt))
        receipt["inputsHash"] = p.keccak256(p.canonical(inputs))
        receipt["inputManifest"] = "0x" + p.canonical(inputs).hex()
        transcript["inputsHash"] = receipt["inputsHash"]
        transcript["result"]["report"]["inputs"] = inputs
        receipt["transcript"] = "0x" + p.wrap_transcript(receipt, p.canonical(transcript)).hex()
        self.assertEqual(transcript["result"]["report"]["reportPreimageABI"], original_preimage)
        self.assertEqual(transcript["result"]["report"]["reportHash"], report_hash)
        with self.assertRaisesRegex(ValueError, "input/environment join"):
            p.verify_replay_receipt(supplement, self.env, self.raw, metric.metric(), inputs, report_hash)

    def test_transcript_envelope_cannot_shift_domain_identity_or_canonical_offsets(self):
        supplement, inputs, report_hash = self._attributed_receipt()
        for offset in (0, 32, 64, 96, 128, 224):
            candidate = copy.deepcopy(supplement)
            raw = bytearray(p.blob(candidate["replay"]["transcript"]))
            raw[offset + 31] ^= 1
            candidate["replay"]["transcript"] = "0x" + raw.hex()
            with self.assertRaises(ValueError):
                p.verify_replay_receipt(candidate, self.env, self.raw, metric.metric(), inputs, report_hash)

    def test_input_shape_and_integer_geometry_are_closed(self):
        supplement, inputs, report_hash = self._attributed_receipt()
        for candidate in ({**inputs, "unknown": 1}, {**inputs, "threshold": True},
                          {**inputs, "captures": [{**inputs["captures"][0], "width": 513}]}):
            with self.assertRaises(ValueError):
                p.verify_inputs(candidate, self.raw)


@unittest.skipUnless(os.name == "nt" and os.environ.get("STREAM_METRIC_RUNTIME_TEST") == "1",
                     "explicit restored Windows runtime acceptance")
class RestoredMetricRuntimeTests(unittest.TestCase):
    def test_actual_copied_interpreter_no_host_imports_and_exact_original_report(self):
        import importlib.metadata
        retained = os.environ.get("STREAM_METRIC_ACCEPTANCE_DIR")
        if retained:
            Path(retained).mkdir(parents=True, exist_ok=False)
        scope = contextlib.nullcontext(retained) if retained else tempfile.TemporaryDirectory(prefix="metric-runtime-acceptance-")
        with scope as directory:
            work = Path(directory)
            tree = work / "tree"
            tree.mkdir()
            site = Path(importlib.metadata.distribution("jsonschema").locate_file(""))
            material = p.stage(tree, Path(sys.base_prefix), site)
            files = [(name, path.read_bytes()) for name, path in p._files(tree)]
            rows = [p.file_row(name, raw) for name, raw in files]
            env, raw = environment(rows)
            supplement = p.bind(material, env, raw, metric.metric())
            pixels = [[((x * 13 + y * 7) % 256, (x * 9) % 256, (y * 17) % 256) for x in range(16)] for y in range(16)]
            image = png(pixels)
            second = png(pixels, 4)
            inputs = {"contextHash": "0x" + "12" * 32, "environmentHash": p.keccak256(raw),
                      "threshold": 990000000, "evaluatedAt": 1,
                      "captures": [{"firstSha256": p.sha(image), "secondSha256": p.sha(second), "width": 16, "height": 16}]}
            # Preparation-only observation of the explicit Windows prerequisites. This
            # output is not a completed supplement; final replay below requires their hashes.
            job = {"runtime": supplement["runtime"], "parameters": material["parameters"],
                   "implementationIndex": material["implementationIndex"], "manifest": inputs,
                   "environment": "0x" + raw.hex(), "pairs": [["0x" + image.hex(), "0x" + second.hex()]]}
            job_path = work / "probe.json"
            job_path.write_bytes(p.canonical(job))
            child_env = {"SystemRoot": os.environ["SystemRoot"], "WINDIR": os.environ["SystemRoot"],
                         "PATH": str(tree / "metric/python"), "TEMP": str(work), "TMP": str(work)}
            result = subprocess.run([str(tree / p.INTERPRETER), *p.ARGV, str(job_path)],
                                    cwd=tree, env=child_env, capture_output=True, timeout=120,
                                    creationflags=subprocess.CREATE_NO_WINDOW)
            self.assertEqual(result.returncode, 0, result.stderr.decode("utf8", "replace"))
            observation = json.loads(result.stdout)
            platform = [{"path": name, "byteSize": Path(name).stat().st_size,
                         "sha256Digest": p.sha(Path(name).read_bytes())} for name in observation["platformPaths"]]
            env, raw = environment(rows, platform)
            supplement = p.bind(material, env, raw, metric.metric())
            inputs["environmentHash"] = p.keccak256(raw)
            expected = metric.measure(inputs, raw, [(image, second)])
            archive = work / "environment.zip"
            p.pack(tree, archive)
            finished = p.replay(supplement, env, raw, metric.metric(), archive, coverage(archive, env),
                                inputs, [(image, second)], work / "result", expected["reportHash"])
            transcript = json.loads(p.unwrap_transcript(finished["replay"]))
            self.assertEqual(transcript["result"]["report"]["reportHash"], expected["reportHash"])
            self.assertEqual(transcript["result"]["disabledFallbackProbes"], ["network", "process"])
            self.assertTrue(all(not r["path"].startswith(("C:", "D:")) for r in transcript["result"]["pythonModules"]))
            self.assertLess((work / "result/supplement.abi").stat().st_size, p.MAX_SUPPLEMENT)
            replay_hash = p.verify_replay_receipt(finished, env, raw, metric.metric(), inputs, expected["reportHash"])
            context = {"environment": env, "environmentBytes": "0x" + raw.hex(), "metric": list(metric.metric()),
                       "coverage": coverage(archive, env), "inputs": inputs, "expectedReportHash": expected["reportHash"]}
            (work / "context.json").write_bytes(p.canonical(context))
            (work / "first.png").write_bytes(image)
            (work / "second.png").write_bytes(second)
            (work / "result/acceptance.json").write_bytes(p.canonical({
                "runtimeHash": finished["replay"]["runtimeHash"], "replayHash": replay_hash,
                "reportHash": expected["reportHash"], "archiveBytes": archive.stat().st_size,
                "supplementBytes": (work / "result/supplement.abi").stat().st_size,
                "transcriptBytes": len(p.blob(finished["replay"]["transcript"])),
                "packageMembers": len(rows), "pythonModules": len(transcript["result"]["pythonModules"]),
                "nativeMembers": len(transcript["result"]["nativeMembers"]), "platformPrerequisites": len(platform),
                "qualification": "Actual restored interpreter/metric execution; synthetic context and PNG; no chain/browser/archive-receipt authority."}))
            for key, value in (("runtimeHash", "0x" + "11" * 32), ("reportHash", "0x" + "22" * 32)):
                altered = copy.deepcopy(finished)
                altered["replay"][key] = value
                with self.assertRaisesRegex(ValueError, "receipt identity"):
                    p.verify_replay_receipt(altered, env, raw, metric.metric(), inputs, expected["reportHash"])
            # Same valid source/archive cannot be asserted against a different report.
            with self.assertRaisesRegex(ValueError, "original report"):
                p.replay(supplement, env, raw, metric.metric(), archive, coverage(archive, env),
                         inputs, [(image, second)], work / "wrong-result", "0x" + "ff" * 32)
            # A complete, rehashed archive missing an imported module must not use the
            # parent's installed Crypto package to complete its original source imports.
            missing_files = [(n, r) for n, r in files if n != "metric/vendor/Crypto/Hash/keccak.py"]
            self.assertEqual(len(missing_files), len(files) - 1)
            missing_rows = [p.file_row(n, r) for n, r in missing_files]
            missing_env, missing_raw = environment(missing_rows, platform)
            missing_supplement = p.bind(material, missing_env, missing_raw, metric.metric())
            missing_archive = work / "missing-import.zip"
            p._write_zip(missing_archive, missing_files)
            missing_inputs = {**inputs, "environmentHash": p.keccak256(missing_raw)}
            with self.assertRaisesRegex(ValueError, "restored metric failed"):
                p.replay(missing_supplement, missing_env, missing_raw, metric.metric(), missing_archive,
                         coverage(missing_archive, missing_env), missing_inputs, [(image, second)],
                         work / "missing-import-result", expected["reportHash"])


if __name__ == "__main__":
    unittest.main()
