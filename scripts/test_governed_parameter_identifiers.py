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

    def _replace_after(
        self, root: Path, relative: Path, marker: str, old: str, new: str
    ) -> None:
        path = root / relative
        text = path.read_text(encoding="utf-8")
        marker_index = text.find(marker)
        self.assertGreaterEqual(marker_index, 0)
        prefix = text[:marker_index]
        suffix = text[marker_index:]
        self.assertIn(old, suffix)
        path.write_text(prefix + suffix.replace(old, new, 1), encoding="utf-8")

    def _wrap_section(
        self,
        root: Path,
        relative: Path,
        start: str,
        end: str,
        opening: str,
        closing: str,
    ) -> None:
        path = root / relative
        text = path.read_text(encoding="utf-8")
        start_index = text.find(start)
        self.assertGreaterEqual(start_index, 0)
        end_index = text.find(end, start_index + len(start))
        self.assertGreaterEqual(end_index, 0)
        end_index += len(end)
        path.write_text(
            text[:start_index]
            + opening
            + text[start_index:end_index]
            + closing
            + text[end_index:],
            encoding="utf-8",
        )

    def _indent_table(
        self,
        root: Path,
        relative: Path,
        section_start: str,
        section_end: str,
        table_header: str,
        indentation: str,
    ) -> None:
        path = root / relative
        text = path.read_text(encoding="utf-8")
        section_index = text.find(section_start)
        self.assertGreaterEqual(section_index, 0)
        header_index = text.find(table_header, section_index + len(section_start))
        self.assertGreaterEqual(header_index, 0)
        end_index = text.find(section_end, header_index + len(table_header))
        self.assertGreaterEqual(end_index, 0)
        table = "".join(
            indentation + line if line.strip() else line
            for line in text[header_index:end_index].splitlines(keepends=True)
        )
        path.write_text(
            text[:header_index] + table + text[end_index:],
            encoding="utf-8",
        )

    def _wrap_compact_html_block(
        self,
        root: Path,
        relative: Path,
        start: str,
        end: str,
        tag: str,
    ) -> None:
        path = root / relative
        text = path.read_text(encoding="utf-8")
        start_index = text.find(start)
        self.assertGreaterEqual(start_index, 0)
        end_index = text.find(end, start_index + len(start))
        self.assertGreaterEqual(end_index, 0)
        end_index += len(end)
        compact = "\n".join(
            line
            for line in text[start_index:end_index].splitlines()
            if line.strip()
        )
        path.write_text(
            text[:start_index]
            + f"<{tag}>\n"
            + compact
            + f"\n</{tag}>"
            + text[end_index:],
            encoding="utf-8",
        )

    def test_repository_passes(self) -> None:
        checker.validate_repository(ROOT)

    def test_aggregate_and_release_wiring_runs_identifier_gate(self) -> None:
        for relative in (Path("scripts/check.sh"), Path("scripts/check.ps1")):
            with self.subTest(wrapper=relative.as_posix()):
                text = (ROOT / relative).read_text(encoding="utf-8")
                positions = [
                    text.find("check_genesis_deployment_profile.py"),
                    text.find("test_governed_parameter_identifiers.py"),
                    text.find("check_governed_parameter_identifiers.py"),
                    text.find("test_system_manifest_payload_vector.py"),
                ]
                self.assertTrue(all(position >= 0 for position in positions))
                self.assertEqual(positions, sorted(positions))

        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        expected_prerequisites = {
            "release-manifest": {
                "external-call-gas-inventory-check",
                "abi-compatibility-check",
                "governed-parameter-identifiers-check",
                "system-manifest-payload-vector",
            },
            "release-manifest-check": {
                "external-call-gas-inventory-check",
                "abi-compatibility-check",
                "governed-parameter-identifiers-check",
                "system-manifest-payload-vector-check",
            },
        }
        for target, expected in expected_prerequisites.items():
            prerequisites = " ".join(
                row for row in makefile.splitlines() if row.startswith(f"{target}:")
            ).split()
            self.assertTrue(expected <= set(prerequisites))

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

    def test_rejects_target_owner_or_input_drift(self) -> None:
        for old, new in (
            ("| `StreamCore` | `1` |", "| arbitrary owner | `1` |"),
            (
                "GGP key; revenue spec `[RSR-GGP]`, `[RSR-2981-GAS]`",
                "GGP key; unreviewed input",
            ),
        ):
            with self.subTest(old=old):
                temporary, root = self._fixture()
                with temporary:
                    self._replace_after(
                        root,
                        checker.TARGET_ARCHITECTURE,
                        checker.TARGET_SECTION_START,
                        old,
                        new,
                    )
                    with self.assertRaises(checker.GovernedParameterIdentifierError):
                        checker.validate_repository(root)

    def test_rejects_malformed_or_extra_target_row(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            extra = (
                checker.TARGET_TABLE_SEPARATOR
                + "\n| `GGP_UNREVIEWED_EXTRA` | `6529STREAM_GGP_UNREVIEWED_EXTRA` | "
                + "not-a-hash | arbitrary owner | `999` | unreviewed input |"
            )
            self._replace_after(
                root,
                checker.TARGET_ARCHITECTURE,
                checker.TARGET_SECTION_START,
                checker.TARGET_TABLE_SEPARATOR,
                extra,
            )
            with self.assertRaises(checker.GovernedParameterIdentifierError):
                checker.validate_repository(root)

    def test_rejects_target_row_before_canonical_header(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            extra = (
                "| `GGP_UNREVIEWED_EXTRA` | `6529STREAM_GGP_UNREVIEWED_EXTRA` | "
                + ("0x" + "00" * 32)
                + " | arbitrary owner | `1` | unreviewed input |\n"
                + checker.TARGET_TABLE_HEADER
            )
            self._replace_after(
                root,
                checker.TARGET_ARCHITECTURE,
                checker.TARGET_SECTION_START,
                checker.TARGET_TABLE_HEADER,
                extra,
            )
            with self.assertRaises(checker.GovernedParameterIdentifierError):
                checker.validate_repository(root)

    def test_rejects_missing_target_section_heading(self) -> None:
        for replacement in (
            "### Unreviewed Identifier Mirror",
            f"<!-- {checker.TARGET_SECTION_START} -->",
        ):
            with self.subTest(replacement=replacement):
                temporary, root = self._fixture()
                with temporary:
                    self._replace(
                        root,
                        checker.TARGET_ARCHITECTURE,
                        checker.TARGET_SECTION_START,
                        replacement,
                    )
                    with self.assertRaises(checker.GovernedParameterIdentifierError):
                        checker.validate_repository(root)

    def test_rejects_catalog_sections_inside_html_comments(self) -> None:
        cases = (
            (
                checker.TARGET_ARCHITECTURE,
                checker.TARGET_SECTION_START,
                checker.TARGET_TABLE_END,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GGP_INVENTORY_START,
                checker.GGP_INVENTORY_END,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GTP_INVENTORY_START,
                checker.GTP_INVENTORY_END,
            ),
        )
        for relative, start, end in cases:
            with self.subTest(relative=relative.as_posix(), start=start):
                temporary, root = self._fixture()
                with temporary:
                    self._wrap_section(
                        root,
                        relative,
                        start,
                        end,
                        "<!--\n",
                        "\n-->",
                    )
                    with self.assertRaises(checker.GovernedParameterIdentifierError):
                        checker.validate_repository(root)

    def test_rejects_catalog_sections_inside_fenced_code(self) -> None:
        cases = (
            (
                checker.TARGET_ARCHITECTURE,
                checker.TARGET_SECTION_START,
                checker.TARGET_TABLE_END,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GGP_INVENTORY_START,
                checker.GGP_INVENTORY_END,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GTP_INVENTORY_START,
                checker.GTP_INVENTORY_END,
            ),
        )
        for opening, closing in (("```text\n", "\n```"), ("~~~text\n", "\n~~~")):
            for relative, start, end in cases:
                with self.subTest(
                    fence=opening[:3],
                    relative=relative.as_posix(),
                    start=start,
                ):
                    temporary, root = self._fixture()
                    with temporary:
                        self._wrap_section(
                            root,
                            relative,
                            start,
                            end,
                            opening,
                            closing,
                        )
                        with self.assertRaises(checker.GovernedParameterIdentifierError):
                            checker.validate_repository(root)

    def test_rejects_catalog_sections_inside_raw_html_blocks(self) -> None:
        cases = (
            (
                checker.TARGET_ARCHITECTURE,
                checker.TARGET_SECTION_START,
                checker.TARGET_TABLE_END,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GGP_INVENTORY_START,
                checker.GGP_INVENTORY_END,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GTP_INVENTORY_START,
                checker.GTP_INVENTORY_END,
            ),
        )
        for tag in ("pre", "script", "style", "textarea"):
            for relative, start, end in cases:
                with self.subTest(
                    tag=tag,
                    relative=relative.as_posix(),
                    start=start,
                ):
                    temporary, root = self._fixture()
                    with temporary:
                        self._wrap_section(
                            root,
                            relative,
                            start,
                            end,
                            f"<{tag}>\n",
                            f"\n</{tag}>",
                        )
                        with self.assertRaises(checker.GovernedParameterIdentifierError):
                            checker.validate_repository(root)

    def test_rejects_catalog_sections_inside_other_commonmark_html_blocks(self) -> None:
        cases = (
            (
                checker.TARGET_ARCHITECTURE,
                checker.TARGET_SECTION_START,
                checker.TARGET_TABLE_END,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GGP_INVENTORY_START,
                checker.GGP_INVENTORY_END,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GTP_INVENTORY_START,
                checker.GTP_INVENTORY_END,
            ),
        )
        wrappers = (
            ("processing-instruction", "<?audit\n", "\n?>"),
            ("declaration", "<!AUDIT\n", "\n>"),
            ("cdata", "<![CDATA[\n", "\n]]>"),
        )
        for label, opening, closing in wrappers:
            for relative, start, end in cases:
                with self.subTest(
                    block=label,
                    relative=relative.as_posix(),
                    start=start,
                ):
                    temporary, root = self._fixture()
                    with temporary:
                        self._wrap_section(
                            root,
                            relative,
                            start,
                            end,
                            opening,
                            closing,
                        )
                        with self.assertRaises(checker.GovernedParameterIdentifierError):
                            checker.validate_repository(root)

        for relative, start, end in cases:
            with self.subTest(
                block="compact-div",
                relative=relative.as_posix(),
                start=start,
            ):
                temporary, root = self._fixture()
                with temporary:
                    self._wrap_compact_html_block(
                        root,
                        relative,
                        start,
                        end,
                        "div",
                    )
                    with self.assertRaises(checker.GovernedParameterIdentifierError):
                        checker.validate_repository(root)

    def test_rejects_catalog_tables_inside_indented_code(self) -> None:
        cases = (
            (
                checker.TARGET_ARCHITECTURE,
                checker.TARGET_SECTION_START,
                checker.TARGET_TABLE_END,
                checker.TARGET_TABLE_HEADER,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GGP_INVENTORY_START,
                checker.GGP_INVENTORY_END,
                checker.GGP_TABLE_HEADER,
            ),
            (
                checker.LONG_TERM_ARCHITECTURE,
                checker.GTP_INVENTORY_START,
                checker.GTP_INVENTORY_END,
                checker.GTP_TABLE_HEADER,
            ),
        )
        for indentation in ("    ", "\t"):
            for relative, start, end, header in cases:
                with self.subTest(
                    indentation=repr(indentation),
                    relative=relative.as_posix(),
                    start=start,
                ):
                    temporary, root = self._fixture()
                    with temporary:
                        self._indent_table(
                            root,
                            relative,
                            start,
                            end,
                            header,
                            indentation,
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

    def test_rejects_lta_host_or_normative_home_drift(self) -> None:
        for marker, old, new in (
            (
                checker.GGP_INVENTORY_START,
                "| `ROYALTY_RESOLVER_GAS_LIMIT` | `StreamCore` |",
                "| `ROYALTY_RESOLVER_GAS_LIMIT` | arbitrary host |",
            ),
            (
                checker.GGP_INVENTORY_START,
                "[RSR-GGP], [RSR-2981-GAS] |",
                "[UNREVIEWED-HOME] |",
            ),
            (
                checker.GTP_INVENTORY_START,
                "[`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)",
                "[`docs/unreviewed.md`](unreviewed.md)",
            ),
        ):
            with self.subTest(old=old):
                temporary, root = self._fixture()
                with temporary:
                    self._replace_after(
                        root,
                        checker.LONG_TERM_ARCHITECTURE,
                        marker,
                        old,
                        new,
                    )
                    with self.assertRaises(checker.GovernedParameterIdentifierError):
                        checker.validate_repository(root)

    def test_rejects_plain_extra_gtp_member(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            extra = (
                "A fourth launch member ENTROPY_UNREVIEWED_BLOCKS is also governed.\n\n"
                + checker.GTP_INVENTORY_END
            )
            self._replace_after(
                root,
                checker.LONG_TERM_ARCHITECTURE,
                checker.GTP_INVENTORY_START,
                checker.GTP_INVENTORY_END,
                extra,
            )
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

    def test_rejects_commented_out_canonical_host_derivation(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            canonical = (
                'parameterId = keccak256(abi.encodePacked("6529STREAM_GGP_", config.name));'
            )
            replacement = (
                "// "
                + canonical
                + "\n        parameterId = keccak256("
                + 'abi.encodePacked("BAD_PREFIX_", config.name));'
            )
            self._replace(root, checker.GAS_HOST, canonical, replacement)
            with self.assertRaises(checker.GovernedParameterIdentifierError):
                checker.validate_repository(root)

    def test_rejects_string_embedded_canonical_host_derivation(self) -> None:
        temporary, root = self._fixture()
        with temporary:
            canonical = (
                'parameterId = keccak256(abi.encodePacked("6529STREAM_GGP_", config.name));'
            )
            replacement = (
                "string memory decoy = '"
                + canonical
                + "';\n        parameterId = keccak256("
                + 'abi.encodePacked("BAD_PREFIX_", config.name));'
            )
            self._replace(root, checker.GAS_HOST, canonical, replacement)
            with self.assertRaises(checker.GovernedParameterIdentifierError):
                checker.validate_repository(root)


if __name__ == "__main__":
    unittest.main()
