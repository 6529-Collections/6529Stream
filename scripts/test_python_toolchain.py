#!/usr/bin/env python3
"""Focused regression tests for the Python toolchain policy."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_python_toolchain.py")
SPEC = importlib.util.spec_from_file_location("check_python_toolchain", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def hashed_entry(name: str, version: str, digest_character: str = "a") -> str:
    """Return one syntactically valid hashed lock entry."""

    return (
        f"{name}=={version} \\\n"
        f"    --hash=sha256:{digest_character * 64}\n"
    )


def valid_workflow() -> str:
    """Return the minimal workflow text accepted by the static policy."""

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
      {checker.SOLC_SELECT_INSTALL_COMMAND}
      {checker.SOLC_SELECT_USE_COMMAND}
      {checker.PLAYWRIGHT_INSTALL_COMMAND}
"""


def valid_multi_job_ci_workflow() -> str:
    """Return two isolated pinned toolchain jobs accepted for CI."""

    return f"""\
jobs:
  windows-wrapper:
    steps:
      - run: |
          echo windows-only
  slither-baseline:
    steps:
      - uses: actions/setup-python@{checker.SETUP_PYTHON_SHA}
        with:
          python-version: "{checker.PYTHON_VERSION}"
      - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}
        with:
          version: {checker.FOUNDRY_VERSION}
      - run: |
          {checker.LOCK_INSTALL_COMMAND}
          {checker.PIP_CHECK_COMMAND}
          {checker.SOLC_SELECT_INSTALL_COMMAND}
          {checker.SOLC_SELECT_USE_COMMAND}
  foundry:
    steps:
      - uses: actions/setup-python@{checker.SETUP_PYTHON_SHA}
        with:
          python-version: "{checker.PYTHON_VERSION}"
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
        """The committed lock and reviewed workflow inventory pass together."""

        errors, package_count = checker.check_repository(SCRIPT_PATH.parent.parent)
        self.assertEqual(errors, [])
        self.assertGreater(package_count, len(checker.EXPECTED_DIRECT_NAMES))
        direct = checker.parse_direct_requirements(
            (SCRIPT_PATH.parent.parent / checker.DIRECT_REQUIREMENTS_PATH).read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(direct["eth-abi"], "5.2.0")

    def test_direct_requirements_require_exact_expected_pins(self) -> None:
        """Range-based direct requirements fail closed."""

        with self.assertRaisesRegex(checker.ToolchainError, "exact name==version pin"):
            checker.parse_direct_requirements(
                "crytic-compile==0.3.11\neth-abi==5.2.0\n"
                "eth-hash>=0.8.0\nplaywright==1.60.0\n"
                "slither-analyzer==0.11.5\nsolc-select==1.2.0\n"
            )

    def test_direct_requirements_reject_index_urls(self) -> None:
        """Direct intent cannot persist an index or credential-bearing URL."""

        with self.assertRaisesRegex(checker.ToolchainError, "must not contain"):
            checker.parse_direct_requirements(
                "# --index-url https://user:secret@example.invalid/simple\n"
                "crytic-compile==0.3.11\neth-abi==5.2.0\n"
                "eth-hash==0.8.0\nplaywright==1.60.0\n"
                "slither-analyzer==0.11.5\nsolc-select==1.2.0\n"
            )

    def test_lock_requires_hash_for_every_package(self) -> None:
        """Every locked distribution requires at least one SHA-256 hash."""

        with self.assertRaisesRegex(checker.ToolchainError, "has no SHA-256 hash"):
            checker.parse_lock("eth-hash==0.8.0 \\\nplaywright==1.60.0 \\\n")

    def test_lock_rejects_index_or_credential_bearing_urls(self) -> None:
        """The release lock cannot persist package-index configuration."""

        with self.assertRaisesRegex(checker.ToolchainError, "must not contain"):
            checker.parse_lock(
                "--index-url https://user:secret@example.invalid/simple\n"
                + hashed_entry("eth-hash", "0.8.0")
            )

    def test_lock_must_match_direct_versions(self) -> None:
        """The resolved lock must retain each human-reviewed direct version."""

        direct = {"playwright": "1.60.0"}
        locked = checker.parse_lock(hashed_entry("playwright", "1.59.0"))
        self.assertEqual(
            checker.check_lock_matches_direct(direct, locked),
            ["requirements-tools.lock has playwright==1.59.0, expected direct pin 1.60.0"],
        )

    def test_lock_rejects_unreviewed_extra_distribution(self) -> None:
        """An extra exact hashed package still fails the reviewed closure."""

        locked = {
            name: ("1.0.0", frozenset({"a" * 64}))
            for name in checker.EXPECTED_LOCKED_NAMES
        }
        locked["unexpected-package"] = ("1.0.0", frozenset({"b" * 64}))
        self.assertEqual(
            checker.check_lock_closure(locked),
            [
                "requirements-tools.lock has unreviewed extra locked names: "
                "['unexpected-package']"
            ],
        )

    def test_minimal_workflow_passes(self) -> None:
        """The exact action and command forms remain accepted."""

        self.assertEqual(checker.check_workflow(Path("workflow.yml"), valid_workflow()), [])

    def test_two_isolated_ci_toolchain_jobs_pass(self) -> None:
        """Each CI job independently installs the same pinned environment."""

        self.assertEqual(
            checker.check_workflow(
                checker.CI_WORKFLOW_PATH,
                valid_multi_job_ci_workflow(),
            ),
            [],
        )

    def test_two_job_ci_rejects_one_unpinned_runtime(self) -> None:
        """Every isolated toolchain job requires the exact Python setup pin."""

        workflow = valid_multi_job_ci_workflow().replace(
            f"      - uses: actions/setup-python@{checker.SETUP_PYTHON_SHA}\n"
            "        with:\n"
            f'          python-version: "{checker.PYTHON_VERSION}"\n',
            "",
            1,
        )
        errors = checker.check_workflow(checker.CI_WORKFLOW_PATH, workflow)
        self.assertTrue(any("setup-python refs" in error for error in errors))
        self.assertTrue(any("Python runtime pins" in error for error in errors))

    def test_ci_rejects_toolchain_group_in_the_wrong_job(self) -> None:
        """Global counts cannot hide a toolchain installed in another CI job."""

        workflow = valid_multi_job_ci_workflow().replace(
            "  windows-wrapper:\n"
            "    steps:\n"
            "      - run: |\n"
            "          echo windows-only\n"
            "  slither-baseline:\n",
            "  windows-wrapper:\n",
        ).replace(
            "  foundry:\n",
            "  slither-baseline:\n"
            "    steps:\n"
            "      - run: |\n"
            "          echo no toolchain\n"
            "  foundry:\n",
        )
        errors = checker.check_workflow(checker.CI_WORKFLOW_PATH, workflow)
        self.assertTrue(any("non-toolchain job 'windows-wrapper'" in error for error in errors))
        self.assertTrue(any("job 'slither-baseline' must contain" in error for error in errors))

    def test_descriptive_name_and_literal_content_pass(self) -> None:
        """Names and literal shell content are not parsed as YAML policy keys."""

        workflow = valid_workflow().replace(
            "steps:",
            "steps:\n"
            "  - name: Install pip docs that use actions/cache\n"
            "    run: |\n"
            "      echo cache uses actions/cache\n"
            '      echo "run: > is shell text"\n'
            "      printf '\\u0041'",
        )
        self.assertEqual(checker.check_workflow(Path("workflow.yml"), workflow), [])

    def test_workflow_rejects_floating_or_divergent_install(self) -> None:
        """A floating pip upgrade and direct-file install both fail closed."""

        workflow = valid_workflow().replace(
            checker.LOCK_INSTALL_COMMAND,
            "python -m pip install --upgrade pip\n"
            "      python -m pip install -r requirements-tools.txt",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("unapproved install line" in error for error in errors))

    def test_workflow_rejects_additional_bare_pip_install(self) -> None:
        """A bare pip install cannot coexist with the canonical command."""

        workflow = valid_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            "pip install extra-package\n" f"      {checker.PIP_CHECK_COMMAND}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("unapproved install line" in error for error in errors))

    def test_workflow_rejects_additional_uv_pip_install(self) -> None:
        """A uv pip install cannot coexist with the canonical command."""

        workflow = valid_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            "uv pip install extra-package\n" f"      {checker.PIP_CHECK_COMMAND}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("unapproved install line" in error for error in errors))

    def test_workflow_rejects_wrapped_bare_pip_install(self) -> None:
        """Shell continuation cannot hide an extra pip install."""

        workflow = valid_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            "pip \\\n        install extra-package\n" f"      {checker.PIP_CHECK_COMMAND}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("unapproved install line" in error for error in errors))

    def test_workflow_rejects_additional_setup_python_runtime(self) -> None:
        """A second full-SHA Python setup and runtime pin still fail."""

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
        """Only the canonical locked-module browser installer is allowed."""

        workflow = valid_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            "playwright install chromium\n" f"      {checker.PIP_CHECK_COMMAND}",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(any("unapproved install line" in error for error in errors))

    def test_release_workflow_requires_branch_guard_before_tool_setup(self) -> None:
        """Release mode must reject an invalid ref before any tool download."""

        workflow = valid_workflow().replace(
            f"  - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}",
            f"  {checker.RELEASE_BRANCH_GUARD}\n"
            "    run: exit 0\n"
            f"  - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}",
        )
        errors = checker.check_workflow(checker.RELEASE_WORKFLOW_PATH, workflow)
        self.assertTrue(any("protected-default-branch guard" in error for error in errors))

    def test_workflow_requires_full_action_sha(self) -> None:
        """A mutable action tag is not an accepted uses form."""

        workflow = valid_workflow().replace(
            "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5",
            "actions/checkout@v6",
        )
        errors = checker.check_workflow(Path("workflow.yml"), workflow)
        self.assertTrue(
            any("every uses line must be a strict external" in error for error in errors)
        )

    def test_workflow_bypass_matrix_fails_closed(self) -> None:
        """Known YAML, wrapper, package-tool, and ordering bypasses are rejected."""

        base = valid_workflow()
        checkout = "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
        before_check = f"      {checker.PIP_CHECK_COMMAND}"
        continuation = "\\\n"
        quoted_continuation = (
            f'  - run: "p{continuation}'
            f'    ip i{continuation}'
            '    nstall extra-package"'
        )
        literal_continuation = (
            "  - run: |\n"
            f"      p{continuation}"
            f"      ip i{continuation}"
            "      nstall extra-package"
        )
        escaped_explicit_key = (
            f'  - ? "u{continuation}'
            '    ses"\n'
            "    : example/action@v1"
        )
        hidden_anchor_alias = (
            "env:\n"
            f'  HIDDEN_ACTION_KEY: &!k "u{continuation}'
            '    ses"\n'
            "steps:"
        )
        standalone_flow_uses = (
            "  -\n"
            f'    {{ ? "u{continuation}'
            '        ses"\n'
            "      : example/action@v1 }"
        )
        standalone_flow_run = (
            "  -\n"
            f'    {{ ? "r{continuation}'
            '        un"\n'
            '      : "pip install extra-package" }'
        )
        tagged_flow_uses = (
            "  -\n"
            f'    !!map {{ ? "u{continuation}'
            '        ses"\n'
            "      : example/action@v1 }"
        )
        self.assertIn(
            "pip install extra-package",
            checker.normalize_shell_continuations(quoted_continuation),
        )
        self.assertIn(
            "pip install extra-package",
            checker.normalize_shell_tokens("p''ip in''stall extra-package"),
        )
        self.assertIn(
            "pip install extra-package",
            checker.normalize_shell_tokens(r"p\ip i\nstall extra-package"),
        )
        cases = {
            "folded-split-install": base.replace("  - run: |", "  - run: >").replace(
                checker.LOCK_INSTALL_COMMAND,
                "python -m pip\n        install --require-hashes -r requirements-tools.lock",
            ),
            "folded-indent-chomp": base.replace("  - run: |", "  - run: >2-"),
            "unicode-escaped-uses-key": base.replace(
                f"  - uses: {checkout}",
                '  - "\\u0075ses": example/action@v1',
            ),
            "long-unicode-escaped-uses-key": base.replace(
                f"  - uses: {checkout}",
                '  - "\\U00000075ses": example/action@v1',
            ),
            "hex-escaped-install": base.replace(
                "  - run: |",
                '  - run: "p\\x69p \\x69nstall extra-package"\n  - run: |',
            ),
            "quoted-continuation-install": base.replace(
                "  - run: |",
                f"{quoted_continuation}\n  - run: |",
            ),
            "literal-continuation-install": base.replace(
                "  - run: |",
                f"{literal_continuation}\n  - run: |",
            ),
            "quoted-token-install": base.replace(
                before_check,
                f"      p''ip in''stall extra-package\n{before_check}",
            ),
            "escaped-token-install": base.replace(
                before_check,
                f"      p\\ip i\\nstall extra-package\n{before_check}",
            ),
            "shell-wrapper": base.replace(
                before_check,
                f"      $installer install extra-package\n{before_check}",
            ),
            "pip3": base.replace(
                before_check,
                f"      pip3 install extra-package\n{before_check}",
            ),
            "pip-main-module": base.replace(
                before_check,
                f"      python -m pip.__main__ install extra-package\n{before_check}",
            ),
            "pipx": base.replace(
                before_check,
                f"      pipx install extra-package\n{before_check}",
            ),
            "uv-tool": base.replace(
                before_check,
                f"      uv tool install extra-package\n{before_check}",
            ),
            "pip-global-option": base.replace(
                before_check,
                f"      python -m pip --isolated install extra-package\n{before_check}",
            ),
            "uv-global-option": base.replace(
                before_check,
                f"      uv --no-cache pip install extra-package\n{before_check}",
            ),
            "uses-trailing-comment": base.replace(checkout, f"{checkout} # mutable note"),
            "uses-spaced-colon": base.replace("uses: actions/checkout", "uses : actions/checkout"),
            "uses-inline-map": base.replace(
                f"  - uses: {checkout}",
                f"  - {{ uses: {checkout} }}",
            ),
            "uses-double-quoted-key": base.replace(
                f"  - uses: {checkout}",
                '  - "uses": example/action@v1',
            ),
            "uses-single-quoted-key": base.replace(
                f"  - uses: {checkout}",
                "  - 'uses': example/action@v1",
            ),
            "uses-flow-map-quoted-key": base.replace(
                f"  - uses: {checkout}",
                '  - { "uses": example/action@v1 }',
            ),
            "uses-explicit-key": base.replace(
                f"  - uses: {checkout}",
                "  - ? uses\n    : example/action@v1",
            ),
            "uses-continued-explicit-key": base.replace(
                f"  - uses: {checkout}",
                escaped_explicit_key,
            ),
            "uses-hidden-anchor-alias": base.replace(
                "steps:",
                hidden_anchor_alias,
            ).replace(
                f"  - uses: {checkout}",
                "  - *!k: example/action@v1",
            ),
            "uses-standalone-flow-map": base.replace(
                f"  - uses: {checkout}",
                standalone_flow_uses,
            ),
            "uses-tagged-flow-map": base.replace(
                f"  - uses: {checkout}",
                tagged_flow_uses,
            ),
            "uses-docker": base.replace(checkout, "docker://python:3.12.13"),
            "run-spaced-colon": base.replace("  - run: |", "  - run : echo bypass\n  - run: |"),
            "run-quoted-key": base.replace(
                "  - run: |",
                '  - "run": echo bypass\n  - run: |',
            ),
            "run-flow-map": base.replace(
                "  - run: |",
                "  - { run: echo bypass }\n  - run: |",
            ),
            "run-standalone-flow-map": base.replace(
                "  - run: |",
                f"{standalone_flow_run}\n  - run: |",
            ),
            "run-explicit-key": base.replace(
                "  - run: |",
                "  - ? run\n    : echo bypass\n  - run: |",
            ),
            "pip-check-before-install": base.replace(
                f"      {checker.LOCK_INSTALL_COMMAND}\n{before_check}",
                f"{before_check}\n      {checker.LOCK_INSTALL_COMMAND}",
            ),
        }
        for label, workflow in cases.items():
            with self.subTest(label=label):
                self.assertNotEqual(
                    checker.check_workflow(Path("workflow.yml"), workflow),
                    [],
                )

    def test_unreviewed_workflow_file_fails_inventory(self) -> None:
        """A newly added workflow cannot bypass the two reviewed files."""

        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            workflow_root = repo_root / checker.WORKFLOW_DIRECTORY
            workflow_root.mkdir(parents=True)
            for path in checker.WORKFLOW_PATHS:
                (repo_root / path).write_text("name: reviewed\n", encoding="utf-8")
            unexpected = workflow_root / "unreviewed.yaml"
            unexpected.write_text("name: unreviewed\n", encoding="utf-8")
            self.assertEqual(
                checker.check_workflow_inventory(repo_root),
                [
                    "unreviewed workflow file is not allowed: "
                    ".github/workflows/unreviewed.yaml"
                ],
            )

    def test_provenance_requires_every_toolchain_input(self) -> None:
        """Every toolchain policy input must remain checksum-covered."""

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
