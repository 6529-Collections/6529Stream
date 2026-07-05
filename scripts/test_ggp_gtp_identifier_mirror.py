#!/usr/bin/env python3
"""Focused tests for the GGP/GTP identifier mirror checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_ggp_gtp_identifier_mirror.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_ggp_gtp_identifier_mirror", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def fixture_repo(root: Path, mirror_rows: str, solidity: str | None = None) -> None:
    write(
        root / "docs" / "stream-long-term-architecture.md",
        "# Umbrella\n\n## Governed Gas Parameters [LTA-GGP]\n\n"
        "| Parameter | Host | Normative home |\n| --- | --- | --- |\n"
        "| `A_GAS_LIMIT` | core | [`docs/a.md`](a.md) [A-GGP] |\n",
    )
    write(
        root / "docs" / "stream-entropy-coordinator.md",
        "# Coordinator\n\nRequirements [EC-TIME]:\n\n"
        "1. `ENTROPY_REQUEST_TIMEOUT_BLOCKS` is a coordinator-hosted GTP.\n",
    )
    write(
        root / "docs" / "launch-v1-target-architecture.md",
        "# Protocol v1\n\n### Governed Gas Parameter Identifier Mirror Rows\n\n"
        "| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |\n"
        "| --- | --- | --- | --- | --- | --- |\n" + mirror_rows,
    )
    if solidity:
        write(root / "smart-contracts" / "Host.sol", solidity)


GOOD_ROWS = (
    "| `GGP_A_GAS_LIMIT` | `6529STREAM_GGP_A_GAS_LIMIT` | 0x11 | core | `1` | GGP key |\n"
    "| `GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS` | `6529STREAM_GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS` | 0x22 | c | `1` | GTP key |\n"
)


class GgpIdentifierMirrorTests(unittest.TestCase):
    def test_committed_repo_mirror_is_complete(self) -> None:
        ggp, gtp, _ = checker.validate_repo(REPO_ROOT)
        self.assertEqual(ggp, 22)
        self.assertEqual(gtp, 3)

    def test_accepts_bijective_mirror(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, GOOD_ROWS)
            self.assertEqual(checker.validate_repo(root)[:2], (1, 1))

    def test_rejects_missing_and_orphan_rows(self) -> None:
        rows = (
            "| `GGP_B_GAS_LIMIT` | `6529STREAM_GGP_B_GAS_LIMIT` | 0x11 | core | `1` | GGP key |\n"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, rows)
            with self.assertRaises(checker.GgpIdentifierMirrorError) as ctx:
                checker.validate_repo(root)
            message = str(ctx.exception)
            self.assertIn("A_GAS_LIMIT has no GGP_A_GAS_LIMIT mirror row", message)
            self.assertIn("orphan mirror row GGP_B_GAS_LIMIT", message)

    def test_rejects_nonuniform_preimage(self) -> None:
        rows = (
            "| `GGP_A_GAS_LIMIT` | `6529STREAM_GGP_A_GAS_LIMIT_ID` | 0x11 | core | `1` | GGP key |\n"
            "| `GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS` | `6529STREAM_GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS` | 0x22 | c | `1` | GTP key |\n"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, rows)
            with self.assertRaises(checker.GgpIdentifierMirrorError) as ctx:
                checker.validate_repo(root)
            self.assertIn("preimage drifted", str(ctx.exception))

    def test_rejects_solidity_identifier_drift(self) -> None:
        solidity = (
            "contract Host {\n    bytes32 public constant GGP_A_GAS_LIMIT =\n"
            '        keccak256("6529STREAM_GGP_WRONG");\n}\n'
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, GOOD_ROWS, solidity)
            with self.assertRaises(checker.GgpIdentifierMirrorError) as ctx:
                checker.validate_repo(root)
            self.assertIn("Solidity identifier constant", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
