#!/usr/bin/env python3
"""Exercise the developer entry point without compiling or using deployment keys."""

from __future__ import annotations

from contextlib import redirect_stdout, redirect_stderr
from io import StringIO
import os
import json
from types import SimpleNamespace
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts import dev


class DeveloperCommands(unittest.TestCase):
    def _campaign(self, root, arguments, *, exit_code=0, missing_suite=False, mutate_source=False, config_change=None):
        source = root / "smart-contracts" / "Example.sol"
        source.parent.mkdir(exist_ok=True)
        source.write_text("contract Example {}", encoding="utf-8")
        captured = {}
        def run(command, **kwargs):
            env = kwargs.get("env", {})
            if command[-1] == "--version":
                return SimpleNamespace(returncode=0, stdout="forge Version: 1.7.1")
            if command[1:3] == ["config", "--json"]:
                cfg = dict(dev.CURRENT_SETTINGS, invariant={
                    "runs": int(env["FOUNDRY_INVARIANT_RUNS"]), "depth": int(env["FOUNDRY_INVARIANT_DEPTH"]),
                    "fail_on_revert": True, "show_metrics": True, "check_interval": 1,
                    "failure_persist_dir": env["FOUNDRY_INVARIANT_FAILURE_PERSIST_DIR"],
                }, fuzz={"seed": env["FOUNDRY_FUZZ_SEED"], "runs": int(env["FOUNDRY_FUZZ_RUNS"]), "fail_on_revert": env["FOUNDRY_FUZZ_FAIL_ON_REVERT"] == "true"})
                if config_change:
                    config_change(cfg)
                return SimpleNamespace(returncode=0, stdout=json.dumps(cfg))
            return SimpleNamespace(returncode=0, stdout="a" * 40)
        def popen(command, **kwargs):
            captured.update(command=command, env=kwargs["env"])
            suites = {}
            for key, prefix in dev.CAMPAIGN_SUITES.items():
                kind = {"Fuzz": {"runs": int(kwargs["env"]["FOUNDRY_FUZZ_RUNS"])}} if prefix == "testFuzz" else {"Invariant": {"runs": int(kwargs["env"]["FOUNDRY_INVARIANT_RUNS"]), "calls": int(kwargs["env"]["FOUNDRY_INVARIANT_RUNS"]) * int(kwargs["env"]["FOUNDRY_INVARIANT_DEPTH"]), "reverts": 0}}
                suites[key] = {"test_results": {prefix + "property()": {"status": "Failure" if exit_code else "Success", "reason": "example failure" if exit_code else None, "kind": kind}}}
            if missing_suite:
                suites.pop(next(iter(suites)))
            kwargs["stdout"].write(json.dumps(suites))
            corpus = Path(kwargs["env"]["FOUNDRY_INVARIANT_FAILURE_PERSIST_DIR"])
            if exit_code:
                corpus.mkdir(parents=True, exist_ok=True)
                (corpus / "sequence.json").write_text('["retained failure"]', encoding="utf-8")
            if mutate_source:
                source.write_text("contract Changed {}", encoding="utf-8")
            return SimpleNamespace(wait=lambda: exit_code, terminate=lambda: None)
        with patch.object(dev, "ROOT", root), patch.object(dev.shutil, "which", return_value="forge"), patch.object(dev.subprocess, "run", side_effect=run), patch.object(dev.subprocess, "Popen", side_effect=popen), redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = dev.main(["campaign", *arguments])
        return result, captured

    def test_campaign_retains_exact_seed_settings_both_suites_and_raw_source_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            code, child = self._campaign(root, ["--mode", "extended", "--seed", "0xABCD", "--artifacts", "result"])
            self.assertEqual(code, 0)
            report = json.loads((root / "result/campaign.json").read_text())
            self.assertEqual((report["runs"], report["depth"], report["fuzzRuns"]), (256, 256, 4096))
            self.assertEqual(report["seed"], "0x" + "0" * 60 + "abcd")
            self.assertEqual(child["env"]["FOUNDRY_PROFILE"], "current")
            self.assertIn("--json", child["command"])
            self.assertEqual(len(report["tests"]), 2)
            self.assertIn("smart-contracts/Example.sol", report["sources"])
            self.assertIn("out/campaigns/extended-", report["out"].replace("\\", "/"))
            self.assertFalse(list((root / "cache").rglob("*.lock")))

    def test_campaign_empty_filter_cannot_be_reported_as_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            code, _ = self._campaign(root, ["--artifacts", "result"], missing_suite=True)
            self.assertEqual(code, 1)
            self.assertEqual(json.loads((root / "result/campaign.json").read_text())["status"], "ERROR")
            self.assertTrue((root / "result/forge.log").is_file())

    def test_failed_campaign_preserves_corpus_and_replay_copies_without_modifying_original(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            code, _ = self._campaign(root, ["--artifacts", "first"], exit_code=7)
            self.assertEqual(code, 7)
            previous = (root / "first/invariant-failures/sequence.json").read_bytes()
            code, child = self._campaign(root, ["--artifacts", "second", "--replay-from", "first", "--reuse-current"])
            self.assertEqual(code, 0)
            self.assertEqual((root / "second/invariant-failures/sequence.json").read_bytes(), previous)
            self.assertEqual((root / "first/invariant-failures/sequence.json").read_bytes(), previous)
            self.assertEqual(Path(child["env"]["FOUNDRY_OUT"]), root / "out/current")

    def test_campaign_rejects_existing_artifacts_input_drift_and_compiler_overrides(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "existing").mkdir()
            code, child = self._campaign(root, ["--artifacts", "existing"])
            self.assertEqual(code, 1)
            self.assertFalse(child)
            code, _ = self._campaign(root, ["--artifacts", "drift"], mutate_source=True)
            self.assertEqual(code, 1)
            self.assertIn("changed during campaign", json.loads((root / "drift/campaign.json").read_text())["error"])
            code, child = self._campaign(root, ["--artifacts", "settings"], config_change=lambda cfg: cfg.update(solc="0.8.20"))
            self.assertEqual(code, 1)
            self.assertFalse(child)

    def test_campaign_rejects_truncation_overrides_and_concurrent_cache_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            code, child = self._campaign(root, ["--artifacts", "timeout"], config_change=lambda cfg: cfg["invariant"].update(timeout=1))
            self.assertEqual(code, 1)
            self.assertFalse(child)
            lock = root / "cache/current.campaign.lock"
            lock.parent.mkdir(parents=True, exist_ok=True)
            lock.write_text("active owner", encoding="utf-8")
            code, child = self._campaign(root, ["--artifacts", "locked", "--reuse-current"])
            self.assertEqual(code, 1)
            self.assertFalse(child)
            self.assertEqual(lock.read_text(), "active owner")

    def test_campaign_rejects_ambiguous_seed_and_forge_overrides(self):
        for arguments in (["--seed", "123"], ["--seed", "0x" + "1" * 65], ["--no-match-test", "invariant"]):
            with self.subTest(arguments=arguments), redirect_stderr(StringIO()), patch.object(dev, "campaign") as campaign:
                with self.assertRaises(SystemExit):
                    dev.main(["campaign", *arguments])
                campaign.assert_not_called()

    def test_campaign_rejects_hidden_filters_and_skipped_invariant_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for key in ("match_test", "no_match_test", "match_contract", "no_match_contract", "match_path", "no_match_path"):
                with self.subTest(key=key):
                    code, child = self._campaign(root, ["--artifacts", key], config_change=lambda cfg: cfg.update({key: "testFuzzOne|invariant_"}))
                    self.assertEqual(code, 1)
                    self.assertFalse(child)
            code, child = self._campaign(root, ["--artifacts", "interval"], config_change=lambda cfg: cfg["invariant"].update(check_interval=2))
            self.assertEqual(code, 1)
            self.assertFalse(child)

    def test_successful_but_truncated_properties_do_not_satisfy_campaign_budget(self):
        cases = [
            {"suite::testFuzzOne()": {"status": "Success", "kind": {"Fuzz": {"runs": 1}}}},
            {"suite::invariant_one()": {"status": "Success", "kind": {"Invariant": {"runs": 32, "calls": 1, "reverts": 0}}}},
            {"suite::invariant_one()": {"status": "Success", "kind": {"Invariant": {"runs": 32, "calls": 2048, "reverts": 1}}}},
        ]
        for results in cases:
            with self.subTest(results=results), self.assertRaises(ValueError):
                dev.campaign_budget(results, 32, 64, 256)
        dev.campaign_budget({"suite::invariant_one()": {"status": "Failure", "kind": {}}}, 32, 64, 256)

    def test_current_test_is_the_default_and_forge_filters_are_forwarded(self):
        with patch.object(dev, "run", return_value=0) as run:
            self.assertEqual(dev.main(["test", "--match-test", "testPaidMint"]), 0)
        run.assert_called_once_with(
            ["forge", "test", "-vv", "--match-test", "testPaidMint"], profile="current"
        )

    def test_legacy_suite_is_explicit(self):
        with patch.object(dev, "run", return_value=0) as run:
            self.assertEqual(dev.main(["test", "--suite", "legacy"]), 0)
        self.assertEqual(run.call_args.kwargs["profile"], "default")
        self.assertIn("test/regression/legacy/**/*.t.sol", run.call_args.args[0])

    def test_profile_selection_does_not_mutate_the_parent_environment(self):
        with patch.dict(os.environ, {"FOUNDRY_PROFILE": "custom-user-profile"}):
            env = dev.environment("current")
            self.assertEqual(env["FOUNDRY_PROFILE"], "current")
            self.assertEqual(os.environ["FOUNDRY_PROFILE"], "custom-user-profile")

    def test_path_filter_narrows_the_suite_without_duplicate_forge_options(self):
        with patch.object(dev, "run", return_value=0) as run:
            self.assertEqual(dev.main(["test", "--suite", "unit", "--match-path", "test/unit/entropy/*.t.sol"]), 0)
        command = run.call_args.args[0]
        self.assertEqual(command.count("--match-path"), 1)
        self.assertEqual(command[-1], "test/unit/entropy/*.t.sol")

    def test_path_filter_cannot_silently_select_a_different_suite(self):
        with patch.object(dev, "run") as run, redirect_stderr(StringIO()):
            with self.assertRaises(SystemExit) as error:
                dev.main(["test", "--suite", "unit", "--match-path", "test/regression/**/*.t.sol"])
        self.assertEqual(error.exception.code, 2)
        run.assert_not_called()

    def test_doctor_rejects_incompatible_compiler_overrides(self):
        config = dict(dev.CURRENT_SETTINGS, solc="0.8.20", optimizer_runs=999)
        responses = [SimpleNamespace(returncode=0, stdout="Version: 1.7.1") for _ in range(2)]
        responses.append(SimpleNamespace(returncode=0, stdout=json.dumps(config)))
        output = StringIO()
        with patch.object(dev.sys, "version_info", (3, 12)), patch.object(dev.shutil, "which", return_value="tool"), patch.object(dev.subprocess, "run", side_effect=responses), redirect_stdout(output), redirect_stderr(output):
            self.assertEqual(dev.doctor(), 1)
        self.assertIn("optimizer_runs", output.getvalue())
        self.assertNotIn("Ready.", output.getvalue())

    def test_doctor_rejects_an_incompatible_foundry_version(self):
        output = StringIO()
        with patch.object(dev.sys, "version_info", (3, 12)), patch.object(dev.shutil, "which", return_value="tool"), patch.object(dev.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="Version: 1.6.0")), redirect_stdout(output), redirect_stderr(output):
            self.assertEqual(dev.doctor(), 1)
        self.assertIn("expected 1.7.1", output.getvalue())

    def test_failed_check_stops_before_later_commands(self):
        with patch.object(dev, "run", side_effect=[0, 19]) as run:
            self.assertEqual(dev.main(["check"]), 19)
        self.assertEqual(run.call_count, 2)

    def test_clean_preserves_broadcast_receipts_and_deployment_state(self):
        with tempfile.TemporaryDirectory(prefix="stream-dev-clean-") as directory:
            root = Path(directory)
            for name in ("out", "out-release", "cache", "broadcast", "deployments"):
                (root / name).mkdir()
                (root / name / "record.json").write_text("preserve me", encoding="utf-8")
            with patch.object(dev, "ROOT", root), redirect_stdout(StringIO()):
                self.assertEqual(dev.clean(), 0)
            for name in ("out", "out-release", "cache"):
                self.assertFalse((root / name).exists())
            for name in ("broadcast", "deployments"):
                self.assertEqual((root / name / "record.json").read_text(), "preserve me")

    def test_clean_refuses_linked_output_before_deleting_anything(self):
        with tempfile.TemporaryDirectory(prefix="stream-dev-link-") as directory:
            parent = Path(directory)
            root, external = parent / "repo", parent / "external"
            root.mkdir()
            external.mkdir()
            (root / "out").mkdir()
            (root / "out" / "sentinel").write_text("keep", encoding="utf-8")
            (external / "sentinel").write_text("keep", encoding="utf-8")
            try:
                (root / "cache").symlink_to(external, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"Host cannot create directory symlinks: {exc}")
            with patch.object(dev, "ROOT", root), redirect_stderr(StringIO()):
                self.assertEqual(dev.clean(), 1)
            self.assertTrue((root / "out" / "sentinel").exists())
            self.assertTrue((external / "sentinel").exists())

    def test_release_uses_the_full_default_profile_gate(self):
        with patch.object(dev, "run", return_value=0) as run:
            self.assertEqual(dev.main(["release"]), 0)
        self.assertEqual(run.call_args.kwargs["profile"], "default")
        self.assertNotIn("-CurrentStack", run.call_args.args[0])


if __name__ == "__main__":
    unittest.main()
