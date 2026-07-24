#!/usr/bin/env python3
"""Regression tests for check_governed_parameter_identifiers.py."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import check_governed_parameter_identifiers as checker


ROOT = Path(__file__).resolve().parents[1]
INPUTS = (
    checker.TARGET_ARCHITECTURE,
    checker.LONG_TERM_ARCHITECTURE,
    checker.GAS_HOST,
    checker.TIME_HOST,
)


class GovernedParameterIdentifierTests(unittest.TestCase):
    def _fixture(self) -> tuple[tempfile.TemporaryDirectory[str], Path]:
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        for relative in INPUTS:
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, destination)
        return temporary, root

    def _replace(self, root: Path, relative: Path, old: str, new: str) -> None:
        path = root / relative
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def test_repository_passes(self) -> None:
        checker.validate_repository(ROOT)

    def test_rejects_hash_drift(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            self._replace(
                root,
                checker.TARGET_ARCHITECTURE,
                "0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda",
                "0x" + ("00" * 32),
            )
            with self.assertRaises(checker.GovernedParameterIdentifierError):
                checker.validate_repository(root)

    def test_rejects_inventory_deletion_even_when_target_row_remains(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            path = root / checker.LONG_TERM_ARCHITECTURE
            lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
            lines = [
                line
                for line in lines
                if not line.startswith("| `FINALITY_COMPONENT_READ_GAS` |")
            ]
            path.write_text("".join(lines), encoding="utf-8")
            with self.assertRaises(checker.GovernedParameterIdentifierError):
                checker.validate_repository(root)

    def test_rejects_coordinated_catalog_deletion(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            for relative, prefix in (
                (checker.TARGET_ARCHITECTURE, "| `GGP_FINALITY_COMPONENT_READ_GAS` |"),
                (checker.LONG_TERM_ARCHITECTURE, "| `FINALITY_COMPONENT_READ_GAS` |"),
            ):
                path = root / relative
                lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
                path.write_text(
                    "".join(line for line in lines if not line.startswith(prefix)),
                    encoding="utf-8",
                )
            with self.assertRaises(checker.GovernedParameterIdentifierError):
                checker.validate_repository(root)

    def test_rejects_host_prefix_drift(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            self._replace(
                root,
                checker.GAS_HOST,
                '"6529STREAM_GGP_"',
                '"6529STREAM_GGP2_"',
            )
            with self.assertRaises(checker.GovernedParameterIdentifierError):
                checker.validate_repository(root)


if __name__ == "__main__":
    unittest.main()
