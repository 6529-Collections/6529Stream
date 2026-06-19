#!/usr/bin/env python3
"""Focused tests for the deployment rehearsal gate parity checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_deployment_rehearsal_gate.py")
SPEC = importlib.util.spec_from_file_location("check_deployment_rehearsal_gate", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text with stable line endings."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def makefile_text(
    commands: list[str] | None = None,
    *,
    include_standalone_target: bool = True,
) -> str:
    """Build a minimal valid Makefile fixture."""
    selected = commands or [command for _, command in checker.REHEARSAL_COMMANDS]
    standalone_target = "deploy-rehearsal-standalone:\n" if include_standalone_target else ""
    standalone_commands = "\n".join(f"\t{command}" for command in selected[1:])
    return (
        "deploy-rehearsal:\n"
        f"\t{selected[0]}\n\n"
        f"{standalone_target}"
        f"{standalone_commands}\n"
    )


def wrapper_text(commands: list[str] | None = None) -> str:
    """Build a minimal shell/PowerShell wrapper fixture."""
    selected = commands or [command for _, command in checker.REHEARSAL_COMMANDS]
    return "\n".join(selected) + "\n"


def ci_text(
    commands: list[str] | None = None,
    logs: list[str] | None = None,
) -> str:
    """Build a minimal CI fixture with commands and retained log names."""
    selected_commands = commands or [command for _, command in checker.REHEARSAL_COMMANDS]
    selected_logs = logs or [log for _, log in checker.CI_REHEARSAL_LOGS]
    lines = [
        "name: fixture",
        "jobs:",
        "  foundry:",
        "    steps:",
        "      - name: Deployment rehearsal",
        "        run: |",
        "          set -o pipefail",
        "          mkdir -p ci-logs",
    ]
    for index, command in enumerate(selected_commands):
        log = (
            selected_logs[index]
            if index < len(selected_logs)
            else f"ci-logs/unexpected-rehearsal-{index}.log"
        )
        lines.append(f"          {command} 2>&1 | tee {log}")
    return "\n".join(lines) + "\n"


def write_gate_tree(
    root: Path,
    *,
    makefile_commands: list[str] | None = None,
    include_standalone_target: bool = True,
    shell_commands: list[str] | None = None,
    powershell_commands: list[str] | None = None,
    ci_commands: list[str] | None = None,
    ci_logs: list[str] | None = None,
) -> None:
    """Write a minimal repository tree consumed by the checker."""
    write_text(
        root / "Makefile",
        makefile_text(
            makefile_commands,
            include_standalone_target=include_standalone_target,
        ),
    )
    write_text(root / "scripts" / "check.sh", wrapper_text(shell_commands))
    write_text(root / "scripts" / "check.ps1", wrapper_text(powershell_commands))
    write_text(root / ".github" / "workflows" / "ci.yml", ci_text(ci_commands, ci_logs))


class DeploymentRehearsalGateTests(unittest.TestCase):
    """Regression coverage for rehearsal gate parity."""

    def test_accepts_committed_repo_wiring(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_gate_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_gate_tree(root)

            checker.validate_deployment_rehearsal_gate(root)

    def test_rejects_missing_makefile_standalone_target(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_gate_tree(root, include_standalone_target=False)

            with self.assertRaisesRegex(
                checker.DeploymentRehearsalGateError,
                "missing deployment rehearsal targets",
            ):
                checker.validate_deployment_rehearsal_gate(root)

    def test_rejects_missing_wrapper_command(self) -> None:
        commands = [command for _, command in checker.REHEARSAL_COMMANDS]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_gate_tree(root, shell_commands=commands[:-1])

            with self.assertRaisesRegex(
                checker.DeploymentRehearsalGateError,
                "scripts/check.sh is missing required deployment rehearsal commands",
            ):
                checker.validate_deployment_rehearsal_gate(root)

    def test_rejects_missing_ci_log(self) -> None:
        logs = [log for _, log in checker.CI_REHEARSAL_LOGS]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_gate_tree(root, ci_logs=logs[:-1])

            with self.assertRaisesRegex(
                checker.DeploymentRehearsalGateError,
                r"\.github/workflows/ci\.yml is missing required CI command/log pairs",
            ):
                checker.validate_deployment_rehearsal_gate(root)

    def test_rejects_duplicate_actual_ci_log_target(self) -> None:
        logs = [log for _, log in checker.CI_REHEARSAL_LOGS]
        duplicate_logs = [logs[0], logs[0], *logs[2:]]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_gate_tree(root, ci_logs=duplicate_logs)

            with self.assertRaisesRegex(
                checker.DeploymentRehearsalGateError,
                "duplicate deployment rehearsal CI log targets",
            ):
                checker.validate_deployment_rehearsal_gate(root)

    def test_rejects_swapped_ci_command_log_pair(self) -> None:
        logs = [log for _, log in checker.CI_REHEARSAL_LOGS]
        swapped_logs = [logs[1], logs[0], *logs[2:]]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_gate_tree(root, ci_logs=swapped_logs)

            with self.assertRaisesRegex(
                checker.DeploymentRehearsalGateError,
                r"\.github/workflows/ci\.yml is missing required CI command/log pairs",
            ):
                checker.validate_deployment_rehearsal_gate(root)

    def test_rejects_out_of_order_commands(self) -> None:
        commands = [command for _, command in checker.REHEARSAL_COMMANDS]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_gate_tree(root, powershell_commands=[commands[1], commands[0], *commands[2:]])

            with self.assertRaisesRegex(
                checker.DeploymentRehearsalGateError,
                "scripts/check.ps1 has required deployment rehearsal commands out of order",
            ):
                checker.validate_deployment_rehearsal_gate(root)


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
