#!/usr/bin/env python3
"""Focused tests for the TypeScript artifact chain-config checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_typescript_artifact_chain_config.py")
SPEC = importlib.util.spec_from_file_location(
    "check_typescript_artifact_chain_config", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    return "\n".join(
        f"- [{target}](../../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_doc() -> str:
    headings = "\n\n".join(
        f"{'#' * level} {title}\n\nPlaceholder."
        for level, title in checker.REQUIRED_HEADINGS[1:]
    )
    phrases = "\n".join(checker.REQUIRED_PHRASES)
    code = "\n".join(checker.REQUIRED_CODE_TOKENS)
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    return f"""# TypeScript Artifact And Chain Config Snippets

{phrases}

## Maturity And Scope

Placeholder.

## Source Of Truth

{target_links()}

{headings.replace("## Maturity And Scope\n\nPlaceholder.\n\n", "").replace("## Source Of Truth\n\nPlaceholder.\n\n", "")}

```ts
{code}
```

## Validation Commands

```sh
{commands}
```
"""


class TypeScriptArtifactChainConfigTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])
        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])
            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_DOC,
                minimal_doc().replace("## Chain Config Builder\n", ""),
            )
            with self.assertRaisesRegex(
                checker.TypeScriptArtifactChainConfigError,
                "missing required headings",
            ):
                checker.validate_typescript_artifact_chain_config(
                    root, root / checker.DEFAULT_DOC
                )

    def test_rejects_missing_required_phrase(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_DOC, minimal_doc().replace("INT-013", ""))
            with self.assertRaisesRegex(
                checker.TypeScriptArtifactChainConfigError,
                "missing required content",
            ):
                checker.validate_typescript_artifact_chain_config(
                    root, root / checker.DEFAULT_DOC
                )

    def test_rejects_missing_required_snippet(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_DOC,
                minimal_doc().replace("loadAddressBook", ""),
            )
            with self.assertRaisesRegex(
                checker.TypeScriptArtifactChainConfigError,
                "missing required snippets",
            ):
                checker.validate_typescript_artifact_chain_config(
                    root, root / checker.DEFAULT_DOC
                )

    def test_rejects_missing_required_link(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_doc()
            text = original.replace(
                "- [release-artifacts/latest/release-manifest.json](../../../release-artifacts/latest/release-manifest.json)\n",
                "",
            )
            self.assertNotEqual(text, original)
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.TypeScriptArtifactChainConfigError,
                "missing required links",
            ):
                checker.validate_typescript_artifact_chain_config(
                    root, root / checker.DEFAULT_DOC
                )

    def test_rejects_missing_linked_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "release-artifacts/latest/release-manifest.json").unlink()
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with self.assertRaisesRegex(
                checker.TypeScriptArtifactChainConfigError,
                "linked targets are missing",
            ):
                checker.validate_typescript_artifact_chain_config(
                    root, root / checker.DEFAULT_DOC
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
