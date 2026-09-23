"""Diagnostic snapshots retain public context and cannot count as a fresh capture."""
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest

from .canonical import MuseumError, loads
from .current_token_capture import CurrentTokenFixture
from .token_diagnostic import checkpoint, restore


class TokenDiagnosticTests(unittest.TestCase):
    def fixture(self):
        def rpc(method, params):
            return {"eth_getBlockByNumber": {"hash": "0x" + "11" * 32, "number": "0x5"},
                "anvil_dumpState": "0x1234", "eth_chainId": "0x7a69", "eth_blockNumber": "0x0"}[method]
        return SimpleNamespace(rpc=rpc, manifest_raw=b"{}", addresses={}, receipts=[],
            token_primary_policy="0x" + "22" * 32, token_suite=(), unrelated_private_material="must never be serialized")

    def test_closed_public_field_inventory_excludes_unrelated_runtime_attributes(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "checkpoint"
            checkpoint(self.fixture(), directory)
            context = loads((directory / "context.json").read_bytes(), canonical=True)
            self.assertNotIn("unrelated_private_material", context)
            manifest = loads((directory / "manifest.json").read_bytes(), canonical=True)
            self.assertFalse(manifest["acceptanceEvidence"])

    def test_changed_state_is_rejected_before_restore_rpc(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "checkpoint"
            pin = checkpoint(self.fixture(), directory)
            (directory / "state.json").write_bytes(b"{}")
            with self.assertRaisesRegex(MuseumError, "input pin differs"):
                restore(self.fixture(), directory, pin)

    def test_restored_diagnostic_context_cannot_run_fresh_capture(self):
        with self.assertRaisesRegex(MuseumError, "cannot establish a fresh capture"):
            CurrentTokenFixture.build_media(SimpleNamespace(diagnostic_restore="pinned checkpoint"))


if __name__ == "__main__": unittest.main()
