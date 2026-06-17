#!/usr/bin/env python3
"""Focused tests for the TypeScript EIP-712 drop authorization checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_typescript_eip712_drop_authorization.py")
SPEC = importlib.util.spec_from_file_location(
    "check_typescript_eip712_drop_authorization", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required guide link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_doc() -> str:
    """Build the smallest TypeScript EIP-712 guide accepted by the checker."""
    sections = []
    for level, title in checker.REQUIRED_HEADINGS[1:]:
        if title in {"Maturity And Scope", "Source Of Truth", "Validation Commands"}:
            continue
        sections.append(f"{'#' * level} {title}\n\nPlaceholder.")
    headings = "\n\n".join(sections)
    phrases = "\n".join(checker.REQUIRED_PHRASES)
    code = "\n".join(checker.REQUIRED_CODE_TOKENS)
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    return f"""# TypeScript EIP-712 Drop Authorization Snippets

{phrases}

## Maturity And Scope

Placeholder.

## Source Of Truth

{target_links()}

{headings}

```ts
{code}
```

## Validation Commands

```sh
{commands}
```
"""


class TypeScriptEip712DropAuthorizationTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed TypeScript EIP-712 guide satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])
        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete TypeScript EIP-712 guide passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])
            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_DOC,
                minimal_doc().replace("## Drop Id Derivation\n", ""),
            )
            with self.assertRaisesRegex(
                checker.TypeScriptEip712DropAuthorizationError,
                "missing required headings",
            ):
                checker.validate_typescript_eip712_drop_authorization(
                    root, root / checker.DEFAULT_DOC
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing required safety language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_DOC, minimal_doc().replace("INT-014", ""))
            with self.assertRaisesRegex(
                checker.TypeScriptEip712DropAuthorizationError,
                "missing required content",
            ):
                checker.validate_typescript_eip712_drop_authorization(
                    root, root / checker.DEFAULT_DOC
                )

    def test_rejects_missing_required_snippet(self) -> None:
        """Missing required TypeScript snippets are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_DOC,
                minimal_doc().replace("makeAuctionAuthorization", ""),
            )
            with self.assertRaisesRegex(
                checker.TypeScriptEip712DropAuthorizationError,
                "missing required snippets",
            ):
                checker.validate_typescript_eip712_drop_authorization(
                    root, root / checker.DEFAULT_DOC
                )

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_doc()
            text = original.replace(
                "- [smart-contracts/StreamDrops.sol](../../../smart-contracts/StreamDrops.sol)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.TypeScriptEip712DropAuthorizationError,
                "missing required links",
            ):
                checker.validate_typescript_eip712_drop_authorization(
                    root, root / checker.DEFAULT_DOC
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "smart-contracts/StreamDrops.sol").unlink()
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with self.assertRaisesRegex(
                checker.TypeScriptEip712DropAuthorizationError,
                "linked targets are missing",
            ):
                checker.validate_typescript_eip712_drop_authorization(
                    root, root / checker.DEFAULT_DOC
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
