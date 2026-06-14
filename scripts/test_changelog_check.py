"""Focused tests for the release changelog gate."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_changelog.py")
SPEC = importlib.util.spec_from_file_location("check_changelog", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


VALID_CHANGELOG = """# Changelog

## Unreleased

### Added

- Added release change approval policy and changelog gate.

## v0.1.0 - Initial Local Baseline

### Added

- Established the first local release-artifact baseline.
"""


class ChangelogGateTests(unittest.TestCase):
    def test_no_release_impacting_paths_pass_without_changelog(self) -> None:
        errors, impacted = checker.validate_changelog_state(
            ["docs/metadata.md", "ops/AUTONOMOUS_RUN.md"],
            None,
        )

        self.assertEqual(errors, [])
        self.assertEqual(impacted, [])

    def test_release_impacting_path_requires_changelog_file(self) -> None:
        errors, impacted = checker.validate_changelog_state(
            ["smart-contracts/StreamCore.sol"],
            None,
        )

        self.assertEqual(impacted, [("smart-contracts/StreamCore.sol", "contracts")])
        self.assertIn("CHANGELOG.md must be updated", "\n".join(errors))
        self.assertIn("CHANGELOG.md is missing", "\n".join(errors))

    def test_release_impacting_path_requires_changelog_in_changed_files(self) -> None:
        errors, _ = checker.validate_changelog_state(
            ["release-artifacts/latest/abi-checksums.json"],
            VALID_CHANGELOG,
        )

        self.assertIn("CHANGELOG.md must be updated", "\n".join(errors))

    def test_placeholder_unreleased_entry_fails(self) -> None:
        placeholder_entries = [
            "TBD",
            "TODO: fill later",
            "TBD - pending",
            "n/a",
            "_none_",
            "Placeholder until release",
        ]

        for placeholder_entry in placeholder_entries:
            with self.subTest(placeholder_entry=placeholder_entry):
                placeholder = f"""# Changelog

## Unreleased

### Added

- {placeholder_entry}
"""

                errors, _ = checker.validate_changelog_state(
                    ["CHANGELOG.md", "deployments/config/anvil.json"],
                    placeholder,
                )

                self.assertIn("non-placeholder Unreleased bullet", "\n".join(errors))

    def test_missing_unreleased_section_fails(self) -> None:
        errors, _ = checker.validate_changelog_state(
            ["CHANGELOG.md", "docs/release-policy.md"],
            "# Changelog\n\n## v0.1.0\n\n- Initial release.\n",
        )

        self.assertIn("## Unreleased", "\n".join(errors))

    def test_valid_unreleased_entry_passes(self) -> None:
        errors, impacted = checker.validate_changelog_state(
            [
                "CHANGELOG.md",
                ".github/workflows/ci.yml",
                "scripts/check_changelog.py",
                "scripts/check_solidity_formatting.py",
                "scripts/test_solidity_formatting.py",
            ],
            VALID_CHANGELOG,
        )

        self.assertEqual(errors, [])
        self.assertEqual(
            impacted,
            [
                (".github/workflows/ci.yml", "release-tooling"),
                ("scripts/check_changelog.py", "release-tooling"),
                ("scripts/check_solidity_formatting.py", "release-tooling"),
                ("scripts/test_solidity_formatting.py", "release-tooling"),
            ],
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
