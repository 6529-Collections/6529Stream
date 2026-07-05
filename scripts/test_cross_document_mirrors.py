#!/usr/bin/env python3
"""Focused tests for the cross-document mirror checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_cross_document_mirrors.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_cross_document_mirrors", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def fixture_repo(
    root: Path,
    mirror_field: str = "artist_id",
    cmc_fields: str = "`core`, `nonce`",
    struct_fields: str = "address core,\n    uint256 nonce",
) -> None:
    write(
        root / "docs" / "metadata-router-and-renderer.md",
        "# Router\n\nAttribution disclosure requirements [MRR-ATTRIBUTION]:\n\n"
        f"1. Default token JSON carries `{mirror_field}` and `works_class`; flat\n"
        "   `attribution_status` fields are nonconformant.\n"
        "2. Other rule.\n",
    )
    write(
        root / "docs" / "stream-artist-authority.md",
        "# Artist\n\n## Attribution Display And Token JSON [AA-DISPLAY]\n\n"
        "```text\nartist_id: string\nworks_class: string\n```\n\n"
        "## State-Bound Artist Attestations [AA-ATTEST]\n\n"
        "```text\nStreamArtistAttestation(\n    " + struct_fields + "\n)\n```\n",
    )
    write(
        root / "docs" / "collection-metadata-contract.md",
        "# CMC\n\nAttestation rules [CMC-ARTIST-ATTESTATION]:\n\n"
        f"1. The type has a full field inventory ({cmc_fields}) owned by\n"
        "   [AA-ATTEST].\n",
    )


class CrossDocumentMirrorTests(unittest.TestCase):
    def test_committed_repo_mirrors_hold(self) -> None:
        legs, note = checker.validate_repo(REPO_ROOT)
        self.assertEqual(legs, 2)
        self.assertIn("event catalog", note)

    def test_accepts_matching_mirrors(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            checker.validate_repo(root)

    def test_rejects_attribution_field_missing_at_home(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, mirror_field="artist_display_rank")
            with self.assertRaises(checker.CrossDocumentMirrorError) as ctx:
                checker.validate_repo(root)
            self.assertIn("artist_display_rank", str(ctx.exception))

    def test_rejects_attestation_inventory_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, cmc_fields="`core`, `deadline`")
            with self.assertRaises(checker.CrossDocumentMirrorError) as ctx:
                checker.validate_repo(root)
            self.assertIn("field inventory drifted", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
