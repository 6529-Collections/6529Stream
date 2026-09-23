from pathlib import Path
import unittest
from unittest.mock import patch

from . import rc1_ownership_recipe as recipe
from .canonical import MuseumError, dumps, keccak256, loads
from .public_history_rpc import PROFILE as RPC_PROFILE, VERSION, PublicReplayTransport
from .public_ownership_source import PublicOwnershipSource


class Rc1OwnershipRecipeTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[2] / recipe.EVIDENCE
        self.files = {name: (root / name).read_bytes() for name in recipe.PINS}

    def test_original_rc1_pins_produce_concrete_closed_public_anchor_without_network(self):
        with patch("socket.socket", side_effect=AssertionError("recipe must remain offline")):
            files = recipe.prepare(self.files, disclosure="public")
            empty = dumps({"version": VERSION, "profile": RPC_PROFILE, "calls": []})
            source = PublicOwnershipSource(files["anchor.json"], PublicReplayTransport(empty, keccak256(empty)), provenance="trusted_rpc")
        self.assertEqual(source.a["blockNumber"], "11678119")
        self.assertEqual(source.a["core"], "0x05914c6f62c819c861f01c5edd4b6b17e935e75b")
        self.assertEqual(source.a["coreRuntimeHash"], "0x6dd45e4e52993c3b5109cfd8f776a9b49232810f3d98a9374462a343bc31aade")
        value = loads(files["recipe.json"])
        self.assertEqual(value["anchorHash"], keccak256(files["anchor.json"]))
        self.assertFalse(value["networkReadsPerformed"])
        self.assertFalse(value["currentStackEntropySupported"])
        self.assertEqual(len(value["missingCurrentEntropyGetters"]), 4)

    def test_modified_or_extra_retained_evidence_is_not_readmitted(self):
        for path in recipe.PINS:
            files = dict(self.files); files[path] += b"\n"
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "immutable evidence pin"):
                recipe.prepare(files, disclosure="public")
        with self.assertRaisesRegex(MuseumError, "inventory"):
            recipe.prepare(self.files | {"hint.json": b"{}"}, disclosure="public")

    def test_public_disclosure_precedes_evidence_admission(self):
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            recipe.prepare({}, disclosure="private")


if __name__ == "__main__": unittest.main()
