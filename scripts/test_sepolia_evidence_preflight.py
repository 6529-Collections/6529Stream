#!/usr/bin/env python3
"""Focused tests for the Sepolia evidence preflight checker."""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).with_name("check_sepolia_evidence_preflight.py")
SPEC = importlib.util.spec_from_file_location(
    "check_sepolia_evidence_preflight", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def copy_required_tree(target: Path) -> None:
    """Copy the committed preflight prerequisites into a temporary repo."""
    source_root = checker.DEFAULT_REPO_ROOT
    for relative_path in checker.REQUIRED_PATHS.values():
        source = source_root / relative_path
        destination = target / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)


def full_env() -> dict[str, str]:
    """Return complete fake operator environment values."""
    return {name: f"secret-value-for-{name}" for name in checker.REQUIRED_ENV_NAMES}


class SepoliaEvidencePreflightTests(unittest.TestCase):
    """Checker behavior for Sepolia preflight readiness."""

    def test_committed_preflight_passes_without_operator_env(self) -> None:
        """The committed repo prerequisites pass without secret env values."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_default_reports_missing_env_without_failing(self) -> None:
        """Default mode is CI-safe and reports missing operator env names."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)

            report = checker.validate_preflight(repo_root, env={})

        self.assertEqual(report["readiness"], "operator_env_missing")
        self.assertIn("SEPOLIA_RPC_URL", report["missing_environment_variables"])
        self.assertEqual(report["blockers"], [])

    def test_require_env_fails_when_operator_env_is_missing(self) -> None:
        """Operator mode fails closed when required env names are absent."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)

            with self.assertRaisesRegex(
                checker.SepoliaEvidencePreflightError,
                "missing required operator environment",
            ):
                checker.validate_preflight(repo_root, require_env=True, env={})

    def test_require_env_passes_with_complete_env(self) -> None:
        """Operator mode passes with all required names present."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)

            report = checker.validate_preflight(
                repo_root,
                require_env=True,
                env=full_env(),
            )

        self.assertEqual(report["readiness"], "ready")
        self.assertEqual(report["missing_environment_variables"], [])

    def test_report_never_emits_environment_values(self) -> None:
        """Redacted JSON reports include presence, never values."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)
            secret_env = full_env()
            secret_env["SEPOLIA_RPC_URL"] = "https://sepolia.example/token"
            report_path = repo_root / "tmp" / "preflight.json"
            stdout = StringIO()
            stderr = StringIO()

            with patch.dict("os.environ", secret_env, clear=True), redirect_stdout(
                stdout
            ), redirect_stderr(stderr):
                result = checker.main(
                    [
                        "--repo-root",
                        str(repo_root),
                        "--require-env",
                        "--output-json",
                        str(report_path),
                    ]
                )

            text = report_path.read_text(encoding="utf-8")
            captured_output = stdout.getvalue() + stderr.getvalue()

        self.assertEqual(result, 0)
        self.assertNotIn("https://sepolia.example/token", text)
        for value in secret_env.values():
            self.assertNotIn(value, text)
            self.assertNotIn(value, captured_output)
        report = json.loads(text)
        self.assertFalse(report["redaction"]["environment_values_emitted"])
        self.assertTrue(
            next(
                row
                for row in report["environment"]
                if row["name"] == "SEPOLIA_RPC_URL"
            )["present"]
        )

    def test_missing_required_path_fails(self) -> None:
        """Repository prerequisites cannot silently disappear."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)
            (repo_root / checker.CONFIG_PATH).unlink()

            with self.assertRaisesRegex(
                checker.SepoliaEvidencePreflightError,
                "sepolia_config_template",
            ):
                checker.validate_preflight(repo_root, env={})

    def test_required_path_symlink_fails(self) -> None:
        """Committed prerequisite paths must be regular files, not symlinks."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)
            config_path = repo_root / checker.CONFIG_PATH
            real_config_path = config_path.with_name(config_path.name + ".real")
            config_path.rename(real_config_path)
            try:
                os.symlink(real_config_path, config_path)
            except OSError as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")

            with self.assertRaisesRegex(
                checker.SepoliaEvidencePreflightError,
                "not a symlink",
            ):
                checker.validate_preflight(repo_root, env={})

    def test_wrong_chain_id_fails(self) -> None:
        """The config template must remain pinned to Sepolia."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)
            config_path = repo_root / checker.CONFIG_PATH
            config = json.loads(config_path.read_text(encoding="utf-8"))
            config["manifest"]["network"]["chain_id"] = 1
            write_text(config_path, json.dumps(config, indent=2))

            with self.assertRaisesRegex(
                checker.SepoliaEvidencePreflightError,
                "network.chain_id",
            ):
                checker.validate_preflight(repo_root, env={})

    def test_missing_required_env_declaration_fails(self) -> None:
        """The config template must list every required operator env name."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)
            config_path = repo_root / checker.CONFIG_PATH
            config = json.loads(config_path.read_text(encoding="utf-8"))
            rows = config["operator_inputs"]["required_environment_variables"]
            config["operator_inputs"]["required_environment_variables"] = [
                row for row in rows if row["name"] != "ETHERSCAN_API_KEY"
            ]
            write_text(config_path, json.dumps(config, indent=2))

            with self.assertRaisesRegex(
                checker.SepoliaEvidencePreflightError,
                "ETHERSCAN_API_KEY",
            ):
                checker.validate_preflight(repo_root, env={})

    def test_missing_runbook_command_fails(self) -> None:
        """The runbooks must keep the canonical validation commands visible."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            copy_required_tree(repo_root)
            deployment_doc = repo_root / "docs/deployment.md"
            write_text(
                deployment_doc,
                deployment_doc.read_text(encoding="utf-8").replace(
                    "python scripts/check_public_beta_evidence.py",
                    "",
                ),
            )
            non_local_doc = repo_root / "docs/non-local-release-evidence.md"
            write_text(
                non_local_doc,
                non_local_doc.read_text(encoding="utf-8").replace(
                    "python scripts/check_public_beta_evidence.py",
                    "",
                ),
            )

            with self.assertRaisesRegex(
                checker.SepoliaEvidencePreflightError,
                "check_public_beta_evidence",
            ):
                checker.validate_preflight(repo_root, env={})


if __name__ == "__main__":
    unittest.main()
