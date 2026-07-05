#!/usr/bin/env python3
"""Focused tests for the domain constant recomputation checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_domain_constant_recomputation.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location(
    "check_domain_constant_recomputation", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)

from spec_conformance import keccak256_hex  # noqa: E402


TABLE_HEADER = (
    "| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |\n"
    "| --- | --- | --- | --- | --- | --- |\n"
)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def row(name: str, preimage: str, hash_value: str) -> str:
    return f"| `{name}` | `{preimage}` | {hash_value} | owner | `1` | inputs |\n"


class DomainRecomputationTests(unittest.TestCase):
    def test_committed_repo_recomputes(self) -> None:
        rows, solidity = checker.validate_repo(REPO_ROOT)
        self.assertGreater(rows, 300)
        self.assertGreaterEqual(solidity, 8)

    def test_accepts_matching_hashes_and_selectors(self) -> None:
        digest = keccak256_hex("6529STREAM_TEST_V1")
        selector = keccak256_hex("onTest(uint256)")[:10]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\n"
                + TABLE_HEADER
                + row("TEST_DOMAIN", "6529STREAM_TEST_V1", digest)
                + row("TEST_SELECTOR", "onTest(uint256)", selector),
            )
            rows, _ = checker.validate_repo(root)
            self.assertEqual(rows, 2)

    def test_rejects_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\n"
                + TABLE_HEADER
                + row("TEST_DOMAIN", "6529STREAM_TEST_V1", "0x" + "ab" * 32),
            )
            with self.assertRaises(checker.DomainRecomputationError) as ctx:
                checker.validate_repo(root)
            self.assertIn("hash drifted", str(ctx.exception))

    def test_rejects_unpinned_placeholder(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\n" + TABLE_HEADER + row("TEST_DOMAIN", "PRE", "TBD"),
            )
            with self.assertRaises(checker.DomainRecomputationError) as ctx:
                checker.validate_repo(root)
            self.assertIn("unpinned hash placeholder", str(ctx.exception))

    def test_rejects_cross_table_drift_for_one_name(self) -> None:
        digest = keccak256_hex("6529STREAM_TEST_V1")
        other = keccak256_hex("6529STREAM_TEST_V2")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "home.md",
                "# Home\n\n" + TABLE_HEADER + row("TEST_DOMAIN", "6529STREAM_TEST_V1", digest),
            )
            write(
                root / "docs" / "mirror.md",
                "# Mirror\n\n"
                + TABLE_HEADER
                + row("TEST_DOMAIN", "6529STREAM_TEST_V2", other),
            )
            with self.assertRaises(checker.DomainRecomputationError) as ctx:
                checker.validate_repo(root)
            self.assertIn("drifts between", str(ctx.exception))

    def test_referential_home_cell_defers_to_inline_mirror_row(self) -> None:
        digest = keccak256_hex("StreamThing(address a)")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "home.md",
                "# Home\n\n"
                + TABLE_HEADER
                + f"| `THING_TYPEHASH` | struct type string pinned in [X-A].2 | {digest} | o | `1` | i |\n",
            )
            write(
                root / "docs" / "mirror.md",
                "# Mirror\n\n" + TABLE_HEADER + row("THING_TYPEHASH", "StreamThing(address a)", digest),
            )
            checker.validate_repo(root)

    def test_rejects_solidity_preimage_drift(self) -> None:
        digest = keccak256_hex("6529STREAM_TEST_V1")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\n" + TABLE_HEADER + row("TEST_DOMAIN", "6529STREAM_TEST_V1", digest),
            )
            write(
                root / "smart-contracts" / "Thing.sol",
                "contract Thing {\n    bytes32 public constant TEST_DOMAIN =\n"
                '        keccak256("6529STREAM_TEST_V2");\n}\n',
            )
            with self.assertRaises(checker.DomainRecomputationError) as ctx:
                checker.validate_repo(root)
            self.assertIn("Solidity preimage", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
