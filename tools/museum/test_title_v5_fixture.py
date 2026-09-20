"""Eleven-reader synthetic fixtures; no EVM execution or legal-title acceptance."""
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, loads, schema_id
from .independent_wire import ZERO_ADDRESS
from .title_v5_fixture import TitleV5Fixture, ACQUIRER, LATER_OWNER


class TitleV5FixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = TitleV5Fixture()
        with patch("socket.socket", side_effect=AssertionError("fixture must remain offline")):
            cls.preservation, cls.accession = cls.fixture.title_inputs()

    def test_baseline_is_actual_verified_preservation_and_accession(self):
        packet = loads(dict(self.preservation.files)["packet/acquisition-packet.json"], maximum=1048576)
        self.assertEqual(packet["sourceState"]["tokenId"], "41")
        self.assertEqual(packet["sourceState"]["collectionId"], "1")
        self.assertEqual(packet["sourceState"]["blockNumber"], "5")
        self.assertEqual(self.accession.report["selectedAccession"]["recordHash"], self.fixture.selected)
        self.assertEqual(self.accession.report["ownership"]["currentOwner"], LATER_OWNER)
        self.assertEqual([row["kind"] for row in self.accession.report["ownership"]["transitions"]],
            ["mint", "transfer", "transfer"])
        self.assertFalse(self.preservation.report["claims"]["actualChainAcceptance"])
        for claim in ("legalTitleProven", "institutionIdentityProven", "canonicalCurrentAccessionDerived"):
            self.assertFalse(self.accession.report["claims"][claim])

    def test_all_eleven_original_transcripts_have_identical_shared_answers(self):
        files = dict(self.preservation.files)
        paths = [path.removesuffix("anchor.json") for path in files if path.endswith("/source/anchor.json")]
        self.assertEqual(len(paths), 9)
        triplets = [{name: files[prefix + name] for name in ("anchor.json", "transcript.json", "snapshot.json")}
            for prefix in paths]
        originals = dict(self.accession.files)
        triplets.extend({name: originals["sources/" + role + "/" + name]
            for name in ("anchor.json", "transcript.json", "snapshot.json")} for role in ("owner", "ownership"))
        observed, overlaps = {}, 0
        for source in triplets:
            anchor = loads(source["anchor.json"], maximum=524288)
            for key in ("chainId", "core", "blockNumber", "blockHash", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash"):
                self.assertEqual(anchor[key], self.fixture.a[key])
            for call in loads(source["transcript.json"], maximum=33554432)["calls"]:
                key = dumps({"method": call["method"], "params": call["params"]})
                outcome = dumps({name: value for name, value in call.items() if name not in ("method", "params")})
                if key in observed:
                    overlaps += 1; self.assertEqual(observed[key], outcome)
                observed[key] = outcome
        self.assertGreater(overlaps, 50)

    def test_original_payloads_bundles_and_unsupported_later_occurrence_are_retained(self):
        files = dict(self.accession.files)
        for digest, record, _, bundle in self.fixture.typed_rows:
            prefix = "records/" + digest[2:] + "/"
            self.assertEqual(files[prefix + "payload.bin"], record[5])
            self.assertEqual(files[prefix + "signature-bundle.bin"], bundle)
        row = next(row for row in self.accession.report["records"] if row["recordHash"] == self.fixture.unsupported)
        self.assertEqual(row["interpretation"]["status"], "unsupported")
        self.assertNotEqual(self.fixture.selected, self.fixture.unsupported)
        self.assertEqual({row[2][11] for row in self.fixture.typed_rows},
            {schema_id("DIRECT"), schema_id("EIP712"), schema_id("ERC1271")})

    def test_later_supported_accession_and_burn_keep_selected_original(self):
        fixture = TitleV5Fixture(later_accession=True, burned=True)
        with patch("socket.socket", side_effect=AssertionError("offline")):
            preserved, accession = fixture.title_inputs()
        packet = loads(dict(preserved.files)["packet/acquisition-packet.json"], maximum=1048576)
        self.assertTrue(packet["sourceState"]["burned"])
        self.assertEqual(accession.report["ownership"]["currentOwner"], ZERO_ADDRESS)
        self.assertEqual(accession.report["ownership"]["transitions"][-1]["kind"], "burn")
        self.assertEqual(accession.report["selectedAccession"]["recordHash"], fixture.selected)
        later = next(row for row in accession.report["records"] if row["recordHash"] == fixture.later_accession)
        self.assertEqual(later["interpretation"]["status"], "typed_historical")
        self.assertEqual(later["titleBinding"]["status"], "matched_native_transfer")

    def test_self_transfer_does_not_replace_declared_title_hop(self):
        fixture = TitleV5Fixture(self_transfer_before_selected=True)
        result = fixture.accession_assembly(); selected = result.report["selectedAccession"]
        transitions = result.report["ownership"]["transitions"]
        self.assertEqual(selected["titleBinding"]["transferIndex"], "1")
        self.assertEqual(transitions[2]["from"], ACQUIRER)
        self.assertEqual(transitions[2]["to"], ACQUIRER)
        self.assertLess(int(transitions[2]["logIndex"]), int(selected["publication"]["logIndex"]))

    def test_coherent_original_wrong_receipt_owner_is_rejected(self):
        fixture = TitleV5Fixture(unsupported=False)
        value = fixture._accession_value(fixture.transfer_rows[-1], "wrong-author")
        fixture.selected = fixture.append_owner("ACCESSION", value, 5, ACQUIRER)
        fixture._title_lane_state()
        with self.assertRaisesRegex(MuseumError, "owner"):
            fixture.accession_assembly()

    def test_owner_receipt_discloses_omitted_self_transfer(self):
        fixture = TitleV5Fixture(self_transfer_before_selected=True)
        original_request = fixture.request
        omitted = fixture.transfer_rows[2]
        def request(method, params):
            result = original_request(method, params)
            if method == "eth_getLogs":
                return [row for row in result if not (row["transactionHash"] == omitted["transactionHash"]
                    and row["logIndex"] == omitted["logIndex"])]
            return result
        fixture.request = request
        with self.assertRaisesRegex(MuseumError, "receipt|union|filter"):
            fixture.accession_assembly()


if __name__ == "__main__":
    unittest.main()
