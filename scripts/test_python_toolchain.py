#!/usr/bin/env python3
"""Focused regression tests for the Python toolchain policy."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_python_toolchain.py")
SPEC = importlib.util.spec_from_file_location("check_python_toolchain", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def hashed_entry(name: str, version: str, digest_character: str = "a") -> str:
    return (
        f"{name}=={version} \\\n"
        f"    --hash=sha256:{digest_character * 64}\n"
    )


def valid_workflow() -> str:
    return f"""\
steps:
  - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
  - uses: actions/setup-python@{checker.SETUP_PYTHON_SHA}
    with:
      python-version: \"{checker.PYTHON_VERSION}\"
  - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}
    with:
      version: {checker.FOUNDRY_VERSION}
  - run: |
      {checker.LOCK_INSTALL_COMMAND}
      {checker.PIP_CHECK_COMMAND}
      {checker.PLAYWRIGHT_INSTALL_COMMAND}
"""


class PythonToolchainTests(unittest.TestCase):
    def test_committed_repository_passes(self) -> None:
        errors, package_count = checker.check_repository(SCRIPT_PATH.parent.parent)
        self.assertEqual(errors, [])
        self.assertGreater(package_count, len(checker.EXPECTED_DIRECT_NAMES))

    def test_direct_requirements_require_exact_expected_pins(self) -> None:
        with self.assertRaisesRegex(checker.ToolchainError, "exact name==version pin"):
            checker.parse_direct_requirements(
                "eth-hash>=0.8.0\nplaywright==1.60.0\n"
                "slither-analyzer==0.11.5\nsolc-select==1.2.0\n"
            )

    def test_direct_requirements_reject_index_urls(self) -> None:
        with self.assertRaisesRegex(checker.ToolchainError, "must not contain"):
            checker.parse_direct_requirements(
                "# --index-url https://user:secret@example.invalid/simple\n"
                "eth-hash==0.8.0\nplaywright==1.60.0\n"
                "slither-analyzer==0.11.5\nsolc-select==1.2.0\n"
            )

    def test_lock_requires_hash_for_every_package(self) -> None:
        with self.assertRaisesRegex(checker.ToolchainError, "has no SHA-256 hash"):
            checker.parse_lock("eth-hash==0.8.0 \\\nplaywright==1.60.0 \\\n")

    def test_lock_rejects_index_or_credential_bearing_urls(self) -> None:
        with self.assertRaisesRegex(checker.ToolchainError, "must not contain"):
            checker.parse_lock(
                "--index-url https://user:secret@example.invalid/simple\n"
                + hashed_entry("eth-hash", "0.8.0")
            )

    def test_lock_must_match_direct_versions(self) -> None:
        direct = {"playwright": "1.60.0"}
        locked = checker.parse_lock(hashed_entry("playwright", "1.59.0"))
        self.assertEqual(
            checker.check_lock_matches_direct(direct, locked),
            ["requirements-tools.lock has playwright==1.59.0, expected direct pin 1.60.0"],
        )

    def test_workflow_rejects_floating_or_divergent_install(self) -> None:
        workflow = valid_workflow().replace(
            checker.LOCK_INSTALL_COMMAND,
            "python -m pip install --upgrade pip\n"
            "      python -m pip install -r requirements-tools.txt",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("pip install commands" in error for error in errors))

    def test_workflow_rejects_additional_bare_pip_install(self) -> None:
        workflow = valid_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            "pip install extra-package\n" f"      {checker.PIP_CHECK_COMMAND}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("pip install commands" in error for error in errors))

    def test_workflow_rejects_additional_uv_pip_install(self) -> None:
        workflow = valid_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            "uv pip install extra-package\n" f"      {checker.PIP_CHECK_COMMAND}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("pip install commands" in error for error in errors))

    def test_workflow_rejects_wrapped_bare_pip_install(self) -> None:
        workflow = valid_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            "pip \\\n        install extra-package\n" f"      {checker.PIP_CHECK_COMMAND}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("pip install commands" in error for error in errors))

    def test_workflow_rejects_additional_setup_python_runtime(self) -> None:
        workflow = valid_workflow().replace(
            f"  - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}",
            "  - uses: actions/setup-python@1111111111111111111111111111111111111111\n"
            "    with:\n"
            "      python-version: \"3.11.9\"\n"
            f"  - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("setup-python refs" in error for error in errors))
        self.assertTrue(any("Python runtime pins" in error for error in errors))

    def test_workflow_rejects_additional_browser_installer(self) -> None:
        workflow = valid_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            "playwright install chromium\n" f"      {checker.PIP_CHECK_COMMAND}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("Playwright install commands" in error for error in errors))

    def test_release_workflow_requires_branch_guard_before_tool_setup(self) -> None:
        workflow = valid_workflow().replace(
            f"  - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}",
            f"  {checker.RELEASE_BRANCH_GUARD}\n"
            "    run: exit 0\n"
            f"  - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}",
        )
        errors = checker.check_workflow(checker.RELEASE_WORKFLOW_PATH, workflow)
        self.assertTrue(any("protected-default-branch guard" in error for error in errors))

    def test_workflow_requires_full_action_sha(self) -> None:
        workflow = valid_workflow().replace(
            "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5",
            "actions/checkout@v6",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertIn(
            "workflow.yml action actions/checkout@v6 is not pinned to a full SHA",
            errors,
        )

    def test_provenance_requires_every_toolchain_input(self) -> None:
        coverage = "\n".join(
            f'Path("{path.as_posix()}")' for path in checker.PROVENANCE_PATHS[:-1]
        )
        errors = checker.check_provenance_coverage(coverage)
        self.assertEqual(
            errors,
            [
                "scripts/generate_release_checksums.py must checksum-cover "
                "scripts/test_python_toolchain.py"
            ],
        )


if __name__ == "__main__":
    unittest.main()
