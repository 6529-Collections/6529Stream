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
