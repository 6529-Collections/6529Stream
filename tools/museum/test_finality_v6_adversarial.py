"""Independent synthetic controls for the additive native-finality boundary."""
import copy
import unittest
from unittest.mock import patch

from . import acquisition_finality_v6 as assembly
from . import native_finality_wire as wire
from . import public_finality_capture as capture
from .canonical import MuseumError, loads
from .finality_v6_fixture import FinalityV6Fixture


def _position(log):
    return tuple(int(log[key], 16) for key in ("blockNumber", "transactionIndex", "logIndex"))


class FinalityV6AdversarialTests(unittest.TestCase):
    def test_concrete_chain_orders_completed_mint_leaf_root_and_finality(self):
        fixture = FinalityV6Fixture()
        snapshot = fixture.finality_result()
        logs = [row["log"] for row in snapshot["events"]]
        leaf = next(row for row in logs if row["topics"][0] == wire.EVENTS["checkpointLeaf"]
            and int(row["topics"][2], 16) == fixture.finality_target_index)
        root = next(row for row in logs if row["topics"][0] == wire.EVENTS["root"])
        finalized = next(row for row in logs if row["topics"][0] == wire.EVENTS["finalized"])
        self.assertLess(_position(fixture.transfer_rows[0]), _position(leaf))
        self.assertLess(_position(leaf), _position(root))
        self.assertLess(_position(root), _position(finalized))
        self.assertEqual(snapshot["identity"]["tokenId"], "41")
        self.assertEqual(snapshot["bundle"]["content"]["checkpoint"]["leaves"][2][0], "41")

    def test_missing_or_duplicate_original_event_fails_closed(self):
        for duplicate in (False, True):
            with self.subTest(duplicate=duplicate):
                fixture = FinalityV6Fixture()
                receipt = fixture.receipts[next(key for key, value in fixture.receipts.items()
                    if any(log["topics"][0] == wire.EVENTS["root"] for log in value["logs"]))]
                index = next(i for i, log in enumerate(receipt["logs"])
                    if log["topics"][0] == wire.EVENTS["root"])
                if duplicate:
                    receipt["logs"].insert(index + 1, copy.deepcopy(receipt["logs"][index]))
                else:
                    receipt["logs"].pop(index)
                with self.assertRaises(MuseumError): fixture.finality_source().snapshot()

    def test_capture_replays_offline_and_retains_partial_authority_boundary(self):
        fixture = FinalityV6Fixture(); result = fixture.finality_capture()
        with patch("socket.socket", side_effect=AssertionError("offline")):
            rebuilt = capture.verify(dict(result.files), result.manifest_hash)
        self.assertEqual(rebuilt.files, result.files)
        report = loads(dict(result.files)["capture/report.json"])
        self.assertFalse(report["claims"]["completeAuthority"])
        self.assertFalse(report["claims"]["batchCallMetadataVerified"])
        self.assertFalse(report["claims"]["executionTransactionInputCaptured"])

    def test_v6_retains_every_title_v5_byte_and_reconstructs(self):
        fixture = FinalityV6Fixture(); title, finality = fixture.finality_inputs()
        result = assembly.compose(title.files, title.manifest_hash, finality.files,
            finality.manifest_hash, disclosure="public")
        files, originals = dict(result.files), dict(title.files)
        self.assertEqual(files[assembly.ORIGINAL_MANIFEST], originals.pop("manifest.json"))
        for path, raw in originals.items():
            self.assertEqual(files[path], raw, path)
        with patch("socket.socket", side_effect=AssertionError("offline")):
            self.assertEqual(assembly.verify(files, result.manifest_hash).files, result.files)


if __name__ == "__main__":
    unittest.main()
