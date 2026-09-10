#!/usr/bin/env python3
"""Focused regression tests for the Python toolchain policy."""

from __future__ import annotations

import importlib.util
import hashlib
import os
import shutil
import subprocess
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
    """Return four pinned Python jobs and the independent client job."""

    return f"""\
jobs:
  current-stack:
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
  windows-wrapper:
    steps:
      - uses: actions/setup-python@{checker.SETUP_PYTHON_SHA}
        with:
          python-version: "{checker.WINDOWS_PYTHON_VERSION}"
      - uses: foundry-rs/foundry-toolchain@{checker.FOUNDRY_TOOLCHAIN_SHA}
        with:
          version: {checker.FOUNDRY_VERSION}
      - run: |
          {checker.LOCK_INSTALL_COMMAND}
          {checker.PIP_CHECK_COMMAND}
          {checker.SOLC_SELECT_INSTALL_COMMAND}
          {checker.SOLC_SELECT_USE_COMMAND}
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
  stream-client:
    steps:
      - uses: actions/setup-node@249970729cb0ef3589644e2896645e5dc5ba9c38
        with:
          node-version: "24.16.0"
      - run: |
          npm --prefix packages/stream-client ci --ignore-scripts
          npm --prefix packages/stream-client test
"""


class PythonToolchainTests(unittest.TestCase):
    def test_committed_repository_passes(self) -> None:
        """The committed lock and reviewed workflow inventory pass together."""

        errors, package_count = checker.check_repository(SCRIPT_PATH.parent.parent.parent)
        self.assertEqual(errors, [])
        self.assertGreater(package_count, len(checker.EXPECTED_DIRECT_NAMES))
        direct = checker.parse_direct_requirements(
            (SCRIPT_PATH.parent.parent.parent / checker.DIRECT_REQUIREMENTS_PATH).read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(direct["eth-abi"], "5.2.0")
        self.assertEqual(direct["jsonschema"], "4.25.1")
        self.assertEqual(direct["pywin32"], "312")

    def test_windows_transitive_pin_requires_exact_marker(self) -> None:
        """The Windows-only closure cannot become unconditional or cross-platform."""

        direct_text = (
            SCRIPT_PATH.parent.parent.parent / checker.DIRECT_REQUIREMENTS_PATH
        ).read_text(encoding="utf-8")
        with self.assertRaisesRegex(checker.ToolchainError, "marker for pywin32"):
            checker.parse_direct_requirements(
                direct_text.replace(
                    'pywin32==312 ; sys_platform == "win32"',
                    "pywin32==312",
                )
            )

        valid_lock_entry = (
            'pywin32==312 ; sys_platform == "win32" \\\n'
            f'    --hash=sha256:{"a" * 64}\n'
        )
        self.assertEqual(
            checker.parse_lock(valid_lock_entry)["pywin32"][0],
            "312",
        )
        with self.assertRaisesRegex(checker.ToolchainError, "marker for pywin32"):
            checker.parse_lock(valid_lock_entry.replace(' ; sys_platform == "win32"', ""))

    def test_direct_requirements_require_exact_expected_pins(self) -> None:
        """Range-based direct requirements fail closed."""

        with self.assertRaisesRegex(checker.ToolchainError, "exact name==version pin"):
            checker.parse_direct_requirements(
                "crytic-compile==0.3.11\neth-abi==5.2.0\n"
                "eth-hash>=0.8.0\njsonschema==4.25.1\n"
                "playwright==1.60.0\n"
                "slither-analyzer==0.11.5\nsolc-select==1.2.0\n"
            )

    def test_direct_requirements_reject_index_urls(self) -> None:
        """Direct intent cannot persist an index or credential-bearing URL."""

        with self.assertRaisesRegex(checker.ToolchainError, "must not contain"):
            checker.parse_direct_requirements(
                "# --index-url https://user:secret@example.invalid/simple\n"
                "crytic-compile==0.3.11\neth-abi==5.2.0\n"
                "eth-hash==0.8.0\njsonschema==4.25.1\n"
                "playwright==1.60.0\n"
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

    def test_four_isolated_ci_toolchain_jobs_pass(self) -> None:
        """Each CI job independently installs the same pinned environment."""

        self.assertEqual(
            checker.check_workflow(
                checker.CI_WORKFLOW_PATH,
                valid_multi_job_ci_workflow(),
            ),
            [],
        )

    def test_ci_rejects_linux_runtime_pin_in_windows_job(self) -> None:
        """The native Windows job requires its final supported 3.12 binary."""

        workflow = valid_multi_job_ci_workflow().replace(
            f'          python-version: "{checker.WINDOWS_PYTHON_VERSION}"',
            f'          python-version: "{checker.PYTHON_VERSION}"',
            1,
        )
        errors = checker.check_workflow(checker.CI_WORKFLOW_PATH, workflow)
        self.assertTrue(any("Python runtime pins" in error for error in errors))
        self.assertTrue(
            any("job 'windows-wrapper'" in error for error in errors)
        )

    def test_three_job_ci_rejects_one_unpinned_runtime(self) -> None:
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
            "  windows-wrapper:\n",
            "  unreviewed-wrapper:\n",
            1,
        )
        errors = checker.check_workflow(checker.CI_WORKFLOW_PATH, workflow)
        self.assertTrue(any("job names must be exactly" in error for error in errors))
        self.assertTrue(any("non-toolchain job 'unreviewed-wrapper'" in error for error in errors))

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

    def test_ci_accepts_exact_verified_foundry_retry(self) -> None:
        """The existing attested native installer may retry its pinned version in CI."""
        workflow = valid_multi_job_ci_workflow().replace(
            checker.PIP_CHECK_COMMAND,
            checker.PIP_CHECK_COMMAND + '\n          if "$foundryup" --install 1.7.1; then\n            exit 0\n          fi',
            1,
        )
        self.assertEqual(checker.check_workflow(checker.CI_WORKFLOW_PATH, workflow), [])

    def test_foundry_retry_allowance_is_ci_and_exact_version_only(self) -> None:
        """Other workflows, versions and verification-bypass flags remain rejected."""
        command = 'if "$foundryup" --install 1.7.1; then'
        cases = [
            (Path("workflow.yml"), valid_workflow(), command),
            (checker.CI_WORKFLOW_PATH, valid_multi_job_ci_workflow(), command.replace('"', "")),
            (checker.CI_WORKFLOW_PATH, valid_multi_job_ci_workflow(), command.replace('"', "").replace("--install", '--in""stall')),
            (checker.CI_WORKFLOW_PATH, valid_multi_job_ci_workflow(), command.replace('"', "").replace("--install", "--in\\stall")),
            (checker.CI_WORKFLOW_PATH, valid_multi_job_ci_workflow(), command.replace('"', "").replace("--install", "--in\\\n          stall")),
            (checker.CI_WORKFLOW_PATH, valid_multi_job_ci_workflow(), command.replace("1.7.1", "1.7.2")),
            (checker.CI_WORKFLOW_PATH, valid_multi_job_ci_workflow(), command.replace("; then", " --force; then")),
        ]
        for path, source, retry in cases:
            with self.subTest(path=path, retry=retry):
                workflow = source.replace(checker.PIP_CHECK_COMMAND, checker.PIP_CHECK_COMMAND + "\n          " + retry, 1)
                errors = checker.check_workflow(path, workflow)
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

    def test_ci_accepts_only_reviewed_cache_subactions(self) -> None:
        workflow = valid_multi_job_ci_workflow().replace(
            "    steps:\n",
            "    steps:\n"
            f"      - uses: actions/cache/restore@{checker.CACHE_ACTION_SHA}\n"
            f"      - uses: actions/cache/save@{checker.CACHE_ACTION_SHA}\n",
            1,
        )
        self.assertEqual(checker.check_workflow(checker.CI_WORKFLOW_PATH, workflow), [])

    def test_cache_subaction_allowance_rejects_other_refs_and_spellings(self) -> None:
        approved = f"actions/cache/restore@{checker.CACHE_ACTION_SHA}"
        spellings = (
            f"actions/cache/restore@{'1' * 40}",
            "actions/cache/restore@v4",
            approved.replace("actions/cache", "another/cache"),
            approved.replace("/restore@", "/lookup@"),
            approved.replace("/restore@", "/restore/extra@"),
            approved.replace("/restore@", "/Restore@"),
            f'"{approved}"',
            approved + " --force",
            "actions/cache/restore@${{ github.sha }}",
            approved.replace("/restore@", "/\n        restore@"),
        )
        for spelling in spellings:
            with self.subTest(spelling=spelling):
                workflow = valid_multi_job_ci_workflow().replace(
                    "    steps:\n", f"    steps:\n      - uses: {spelling}\n", 1
                )
                self.assertTrue(any(
                    "every uses line must be a strict external" in error
                    for error in checker.check_workflow(checker.CI_WORKFLOW_PATH, workflow)
                ))

    def test_cache_subactions_are_not_allowed_outside_ci(self) -> None:
        for action in ("restore", "save"):
            with self.subTest(action=action):
                workflow = valid_workflow() + (
                    f"  - uses: actions/cache/{action}@{checker.CACHE_ACTION_SHA}\n"
                )
                self.assertTrue(any(
                    "every uses line must be a strict external" in error
                    for error in checker.check_workflow(Path("workflow.yml"), workflow)
                ))

    def test_compiler_cache_keeps_build_test_and_fresh_release_boundaries(self) -> None:
        workflow = (SCRIPT_PATH.parents[2] / checker.CI_WORKFLOW_PATH).read_text(
            encoding="utf-8"
        )
        jobs = checker.workflow_job_blocks(workflow)
        for profile, job, build_name, test_command in (
            ("current", "current-stack", "Build current compilation", "make current-stack-check"),
            ("default", "foundry", "Build", "forge test -vvv"),
        ):
            with self.subTest(profile=profile):
                block = jobs[job]
                restore = block.index(f"- name: Restore {profile} compiler outputs")
                build = block.index(f"- name: {build_name}\n")
                save = block.index(f"- name: Save {profile} compiler outputs")
                self.assertLess(restore, build)
                self.assertLess(build, save)
                self.assertLess(save, block.index(test_command))
                restore_step = block[restore:build]
                prefix = "${{ runner.os }}-${{ runner.arch }}-forge-1.7.1-solc-0.8.19-" + profile + "-v2-${{ hashFiles('foundry.toml') }}-"
                fallback = restore_step.split("          restore-keys: |\n", 1)[1]
                self.assertEqual(fallback.strip().splitlines(), [prefix])
                self.assertEqual(block.count("restore-keys:"), 1)
                self.assertIn("          key: " + prefix + "${{ steps." + profile + "_compiler_inputs.outputs.digest }}", restore_step)
                build_step = block[build:save]
                self.assertNotIn("        if:", build_step)
                self.assertIn("forge build", build_step)
                self.assertIn(
                    f"fromJSON(steps.{profile}_compiler_cache.outputs.cache-hit || 'false') == false",
                    block,
                )
                self.assertIn(f"steps.{profile}_compiler_cache.outputs.cache-primary-key", block)
                identity = block[:restore]
                self.assertIn("git ls-files --stage -z --", identity)
                for source_input in (
                    "foundry.toml", ".github/workflows/ci.yml", ".gitattributes",
                    ".gitmodules", "foundry.lock", "remappings.txt",
                    "smart-contracts", "test", "script", "lib",
                ):
                    self.assertIn(source_input, identity)
                self.assertIn(f"steps.{profile}_compiler_inputs.outputs.digest", block[restore:build])
                self.assertIn(f"-forge-1.7.1-solc-0.8.19-{profile}-v2-", block)
        current = jobs["current-stack"]
        before_save = current[:current.index("- name: Save current compiler outputs")]
        self.assertIn("FOUNDRY_PROFILE=current forge build", before_save)
        self.assertIn("--output-dir ci-logs/current-candidate --check", before_save)
        self.assertIn("CACHE_MATCHED_KEY: ${{ steps.current_compiler_cache.outputs.cache-matched-key }}", before_save)
        self.assertIn("CACHE_EXACT_HIT: ${{ steps.current_compiler_cache.outputs.cache-hit }}", before_save)
        self.assertEqual(before_save.count("forge build --force"), 1)
        self.assertIn('if [ -z "$CACHE_MATCHED_KEY" ] || [ "$CACHE_EXACT_HIT" = "true" ]; then', before_save)
        self.assertIn("tee ci-logs/current-stack-export.log", before_save)
        self.assertIn("tee -a ci-logs/current-stack-export.log", before_save)
        self.assertEqual(current.count("            out/current\n"), 2)
        self.assertEqual(current.count("            cache/current\n"), 2)
        self.assertLess(
            jobs["foundry"].index("- name: Save default compiler outputs"),
            jobs["foundry"].index("- name: Aggregate size and warning diagnostic"),
        )
        self.assertIn("- name: Canonical release build", jobs["foundry"])

    def test_current_cache_recovery_runs_once_only_after_fallback_export_failure(self) -> None:
        git_bash = Path("C:/Program Files/Git/bin/bash.exe")
        bash = str(git_bash) if git_bash.is_file() else shutil.which("bash")
        if not bash:
            self.skipTest("Bash is required to execute the CI command regression")
        workflow = (SCRIPT_PATH.parents[2] / checker.CI_WORKFLOW_PATH).read_text(encoding="utf-8")
        current = checker.workflow_job_blocks(workflow)["current-stack"]
        build = current.split("      - name: Build current compilation\n", 1)[1].split(
            "      - name: Save current compiler outputs\n", 1
        )[0]
        commands = "\n".join(
            line[10:] for line in build.split("        run: |\n", 1)[1].splitlines()
        )
        # Execute the actual workflow shell with fake compiler/exporter functions.
        # Failure modes exercise pipeline exit status, retry count and the final check.
        stubs = r"""
forge() {
  printf 'forge %s\n' "$*" >> calls.log
  case "$*" in
    *--force*) [ "$FORCE_FAILURE" != true ] ;;
    *) [ "$BUILD_FAILURE" != true ] ;;
  esac
}
python() {
  printf 'python %s\n' "$*" >> calls.log
  case " $* " in
    *" --check "*) [ "$CHECK_FAILURE" != true ]; return $? ;;
  esac
  if [ "$EXPORT_MODE" = always ]; then return 1; fi
  if [ "$EXPORT_MODE" = once ] && [ ! -f first-export ]; then
    touch first-export
    return 1
  fi
  return 0
}
"""
        cases = [
            # fallback, export mode, build/forced/check failure, success, force/check counts
            ("false", "once", "false", "false", "false", False, 0, 0),
            ("exact", "once", "false", "false", "false", False, 0, 0),
            ("true", "once", "false", "false", "false", True, 1, 1),
            ("true", "never", "false", "false", "false", True, 0, 1),
            ("false", "never", "false", "false", "false", True, 0, 1),
            ("true", "once", "false", "true", "false", False, 1, 0),
            ("true", "always", "false", "false", "false", False, 1, 0),
            ("true", "never", "false", "false", "true", False, 0, 1),
            ("true", "never", "true", "false", "false", False, 0, 0),
        ]
        for fallback, mode, build_fail, force_fail, check_fail, success, forces, checks in cases:
            with self.subTest(fallback=fallback, mode=mode, build=build_fail, force=force_fail, check=check_fail):
                with tempfile.TemporaryDirectory() as directory:
                    env = dict(os.environ, CACHE_MATCHED_KEY="same-profile-key" if fallback != "false" else "",
                               CACHE_EXACT_HIT="true" if fallback == "exact" else "false", EXPORT_MODE=mode,
                               BUILD_FAILURE=build_fail, FORCE_FAILURE=force_fail, CHECK_FAILURE=check_fail)
                    result = subprocess.run([bash, "-c", stubs + commands], cwd=directory,
                                            env=env, capture_output=True, text=True)
                    calls = (Path(directory) / "calls.log").read_text(encoding="utf-8").splitlines()
                    self.assertEqual(result.returncode == 0, success, result.stderr)
                    self.assertEqual(calls.count("forge build --force"), forces)
                    self.assertEqual(sum(line.endswith(" --check") for line in calls), checks)
                    self.assertEqual(calls[0], "forge build")

    def test_git_compiler_identity_changes_for_same_content_path_rename(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            subprocess.run(["git", "init", "--quiet", str(root)], check=True)
            source = root / "smart-contracts" / "Before.sol"
            source.parent.mkdir()
            source.write_bytes(b"pragma solidity 0.8.19; contract Example {}\n")
            subprocess.run(["git", "-C", str(root), "add", "smart-contracts"], check=True)
            before = subprocess.check_output(
                ["git", "-C", str(root), "ls-files", "--stage", "-z", "--", "smart-contracts"]
            )
            source.rename(source.with_name("After.sol"))
            subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
            after = subprocess.check_output(
                ["git", "-C", str(root), "ls-files", "--stage", "-z", "--", "smart-contracts"]
            )
            self.assertEqual(before.split()[1], after.split()[1])
            self.assertNotEqual(hashlib.sha256(before).digest(), hashlib.sha256(after).digest())

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
                "tools/release/generate_release_checksums.py must checksum-cover "
                "tools/development/test_python_toolchain.py"
            ],
        )


if __name__ == "__main__":
    unittest.main()
