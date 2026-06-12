#!/usr/bin/env python3
"""Focused tests for the audit package checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_audit_package.py")
SPEC = importlib.util.spec_from_file_location("check_audit_package", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def minimal_valid_package() -> str:
    target_links = "\n".join(
        f"- [{target}](../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    return f"""# External Audit Package

This pre-audit local baseline is not production-ready and not a security claim.

## Maturity And Scope

The package covers the current local baseline only.

## Reviewer Entry Points

{target_links}

## Protocol Decisions

The ADR links above are required review inputs.

## Invariants And Test Evidence

Invariant test links above are required review inputs.

## Static Analysis

The Slither baseline link above is required review input.

## Deployment And Release Evidence

The release evidence links above are required review inputs.

## Known Blockers And Accepted Risks

Known blockers and accepted risks are separated by linked docs.

## Security Reporting

Use the linked security policy.

## Local Verification Commands

```sh
{commands}
```

## Package Maintenance

Refresh the package when audit scope changes.
"""


class AuditPackageTests(unittest.TestCase):
    def test_accepts_committed_audit_package(self) -> None:
        repo_root = Path.cwd()
        package_path = repo_root / checker.DEFAULT_PACKAGE

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root), "--package", str(package_path)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_package(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            package_path = root / checker.DEFAULT_PACKAGE
            write_text(package_path, minimal_valid_package())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    ["--repo-root", str(root), "--package", str(package_path)]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            package_path = root / checker.DEFAULT_PACKAGE
            text = minimal_valid_package().replace("## Static Analysis\n", "")
            write_text(package_path, text)

            with self.assertRaisesRegex(
                checker.AuditPackageError, "missing required headings"
            ):
                checker.validate_audit_package(root, package_path)

    def test_rejects_missing_maturity_language(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            package_path = root / checker.DEFAULT_PACKAGE
            text = minimal_valid_package().replace("not production-ready", "experimental")
            write_text(package_path, text)

            with self.assertRaisesRegex(
                checker.AuditPackageError, "missing required maturity language"
            ):
                checker.validate_audit_package(root, package_path)

    def test_rejects_missing_required_link(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            package_path = root / checker.DEFAULT_PACKAGE
            text = minimal_valid_package().replace(
                "- [README.md](../README.md)\n",
                "",
            )
            write_text(package_path, text)

            with self.assertRaisesRegex(checker.AuditPackageError, "missing required links"):
                checker.validate_audit_package(root, package_path)

    def test_rejects_missing_linked_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "README.md").unlink()
            package_path = root / checker.DEFAULT_PACKAGE
            write_text(package_path, minimal_valid_package())

            with self.assertRaisesRegex(checker.AuditPackageError, "linked target is missing"):
                checker.validate_audit_package(root, package_path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
