"""Actual retained account-package replay establishes absence, not positive alignment."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .authority import PROFILE_HASH
from .authority_package import build_authority_package, verify_authority_package
from .canonical import MuseumError, dumps, keccak256, loads
from .package import write_package
from .package_recorded import build_recorded_package
from .package_v2 import verify_package
from .test_package import changed
from .test_package_recorded import inputs, pins
from .test_recorded_account import ROOT, FIXTURE


class AuthorityPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins())
        cls.selection = (FIXTURE / "selection.json").read_bytes()
        cls.requests = dumps({"version": "1", "requests": [{"entityId": "urn:test:place:no-authority-match", "entityKind": "Place",
            "authority": "GETTY_TGN", "sourceText": "Exact original local place; no eligible recorded alignment."}]})

    def test_actual_replay_absence_complete_retention_and_tampered_resolution(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); write_package(self.original, root / "source")
            with patch("socket.socket", side_effect=AssertionError("offline")):
                package = build_authority_package(root / "source", self.original.manifest_hash, self.requests, self.selection, {},
                    request_hash=keccak256(self.requests), selection_hash=keccak256(self.selection), profile_hash=PROFILE_HASH, disclosure="public")
                write_package(package, root / "export")
                self.assertEqual(verify_package(root / "export", package.manifest_hash), package)
            files = dict(package.files)
            for name, raw in self.original.files: self.assertEqual(files["source/" + name], raw)
            report = loads(files["authority/report.json"])
            self.assertEqual(report["results"][0]["status"], "unresolved")
            self.assertEqual(report["sourceAuthentication"], "historical_independent_account")
            self.assertFalse(any(report["claims"].values()))
            report["results"][0]["status"] = "resolved"
            tampered = changed(package, "authority/report.json", dumps(report)); write_package(tampered, root / "tampered")
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
                verify_authority_package(root / "tampered", tampered.manifest_hash)

    def test_source_selection_pin_and_disclosure_cannot_be_omitted(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); write_package(self.original, root / "source")
            base = dict(request_hash=keccak256(self.requests), selection_hash=keccak256(self.selection), profile_hash=PROFILE_HASH, disclosure="public")
            for updates in ({"selection_hash": "0x" + "99" * 32}, {"disclosure": "restricted"}, {"profile_hash": "0x" + "99" * 32}):
                with self.assertRaises(MuseumError):
                    build_authority_package(root / "source", self.original.manifest_hash, self.requests, self.selection, {}, **(base | updates))


if __name__ == "__main__": unittest.main()
