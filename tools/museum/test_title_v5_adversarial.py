"""Adversarial tests for the synthetic eleven-source native title export.

The fixtures replay native-shaped evidence.  They do not prove EVM execution,
chain consensus, legal title, institutional identity, or custody.
"""
import unittest

from . import acquisition_title_v5 as title
from . import native_title_v5 as native
from .canonical import MuseumError, keccak256, loads
from .independent_wire import ZERO_ADDRESS
from .title_v5_fixture import ACQUIRER, LATER_OWNER, MINT_RECIPIENT, TitleV5Fixture


MAX_PACKET = 16 * 1024 * 1024


def compose(fixture):
    packet, accession = fixture.title_inputs()
    result = title.compose(packet.files, packet.manifest_hash,
        accession.files, accession.manifest_hash, disclosure="public")
    return packet, accession, title.verify(result.files, result.manifest_hash)


def packet(result):
    return loads(dict(result.files)[title.PACKET_PATH], maximum=MAX_PACKET)


def position(value):
    return tuple(int(value[key]) for key in ("blockNumber", "transactionIndex", "logIndex"))


class TitleV5AdversarialTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = TitleV5Fixture()
        cls.previous, cls.accession, cls.result = compose(cls.fixture)
        cls.packet = packet(cls.result)

    def test_native_receipt_owner_and_complete_transfer_order_are_distinct_authorities(self):
        transfers = self.packet["ownershipProvenance"]["transfers"]
        self.assertEqual(transfers, [
            {key: row[key] for key in ("from", "to", "blockNumber", "transactionHash", "logIndex")}
            for row in loads(dict(self.accession.files)["sources/ownership/snapshot.json"],
                maximum=MAX_PACKET)["transitions"]])
        self.assertEqual(self.packet["ownershipProvenance"]["currentOwner"], LATER_OWNER)
        for binding in self.result.report["nativeTitleDerivation"]["titleBindings"]:
            record = binding["record"]
            authority = record["authority"]
            self.assertNotIn("authorityClass", record)
            self.assertEqual(authority["kind"], "native_owner_receipt")
            self.assertEqual(authority["receipt"]["owner"], authority["ownerState"]["transfer"]["to"])
            self.assertLess(position(authority["ownerState"]["transfer"]), position(authority["publication"]))
            declared = transfers[int(binding["transferIndex"])]
            self.assertTrue(all(binding[key] == declared[key]
                for key in ("from", "to", "transactionHash")))

    def test_explicit_original_does_not_become_a_canonical_latest_claim(self):
        fixture = TitleV5Fixture(later_accession=True)
        _, _, result = compose(fixture)
        derived = result.report["nativeTitleDerivation"]
        self.assertEqual(derived["selectedAccession"], {
            "recordHash": fixture.selected,
            "selectionBasis": "explicit_original_accession",
            "canonicalCurrentAccession": False})
        self.assertTrue(any(row["record"]["recordHash"] == fixture.later_accession
            for row in derived["titleBindings"]))
        self.assertEqual(packet(result)["legalInstrument"]["accession"]["recordHash"], fixture.selected)
        self.assertFalse(derived["coverage"]["canonicalCurrentAccession"])
        self.assertFalse(result.report["claims"]["canonicalLatestAccessionInferred"])

    def test_receipt_owner_state_uses_latest_prior_transfer_not_declared_title_hop(self):
        fixture = TitleV5Fixture(self_transfer_before_selected=True)
        _, _, result = compose(fixture)
        selected = next(row for row in result.report["nativeTitleDerivation"]["titleBindings"]
            if row["record"]["recordHash"] == fixture.selected)
        self.assertEqual(selected["transferIndex"], "1")
        state = selected["record"]["authority"]["ownerState"]
        self.assertEqual(state["transferIndex"], "2")
        self.assertEqual((state["transfer"]["from"], state["transfer"]["to"]), (ACQUIRER, ACQUIRER))
        self.assertEqual(selected["to"], ACQUIRER)

    def test_shared_core_runtime_contradiction_rejects_before_derivation(self):
        fixture = TitleV5Fixture()
        changed = b"different synthetic Core runtime for accession sources"
        fixture.codes[fixture.core] = changed
        fixture.pins[fixture.core] = keccak256(changed)
        fixture.add(fixture.title_host, "coreCodeHash()", (), (), ("bytes32",),
            (fixture.pins[fixture.core],))
        for row in fixture.title_owner_anchor["codePins"]:
            if row["address"] == fixture.core: row["runtimeHash"] = fixture.pins[fixture.core]
        fixture.title_ownership_anchor["coreRuntimeHash"] = fixture.pins[fixture.core]
        conflicting = fixture.accession_assembly()
        with self.assertRaisesRegex(MuseumError, "cross-source runtime"):
            title.compose(self.previous.files, self.previous.manifest_hash,
                conflicting.files, conflicting.manifest_hash, disclosure="public")

    def test_individually_replayable_accession_anchor_identity_mismatch_rejects(self):
        fixture = TitleV5Fixture()
        changed = keccak256(b"different accession deployment evidence")
        fixture.title_owner_anchor["deploymentEvidenceHash"] = changed
        fixture.title_ownership_anchor["deploymentEvidenceHash"] = changed
        conflicting = fixture.accession_assembly()
        with self.assertRaisesRegex(MuseumError, "common source state"):
            title.compose(self.previous.files, self.previous.manifest_hash,
                conflicting.files, conflicting.manifest_hash, disclosure="public")

    def test_individually_replayable_full_receipt_difference_rejects(self):
        fixture = TitleV5Fixture()
        shared = next(receipt for receipt in fixture.receipts.values()
            if any(log["address"] == fixture.title_host for log in receipt["logs"]))
        shared["effectiveGasPrice"] = "0x2"
        conflicting = fixture.accession_assembly()
        with self.assertRaisesRegex(MuseumError,
                "repeated RPC outcome differs|shared receipt|receipt differs"):
            title.compose(self.previous.files, self.previous.manifest_hash,
                conflicting.files, conflicting.manifest_hash, disclosure="public")

    def test_receipt_log_visible_only_to_accession_sources_rejects_union(self):
        fixture = TitleV5Fixture()
        # Block 3 already contains the retained DIRECT/mint receipt and the first
        # Owner record.  This later self-transfer is valid for the accession pair
        # but absent from the previously captured nine-source full receipt.
        fixture.append_transfer(3, MINT_RECIPIENT, MINT_RECIPIENT)
        conflicting = fixture.accession_assembly()
        with self.assertRaisesRegex(MuseumError,
                "repeated RPC outcome differs|query/receipt|shared receipt|matching logs"):
            title.compose(self.previous.files, self.previous.manifest_hash,
                conflicting.files, conflicting.manifest_hash, disclosure="public")

    def test_original_packages_are_byte_exact_and_new_packet_has_qualified_claims(self):
        files = dict(self.result.files)
        for path, raw in self.previous.files:
            if path == "manifest.json":
                self.assertEqual(files[title.ORIGINAL_MANIFEST], raw)
            else:
                self.assertEqual(files[path], raw)
        for path, raw in self.accession.files:
            self.assertEqual(files[title.ACCESSION_PREFIX + path], raw)
        self.assertNotEqual(files[title.PACKET_PATH], files["packet/acquisition-packet.json"])
        self.assertEqual(self.result.report["packetHash"], keccak256(files[title.PACKET_PATH]))
        self.assertFalse(self.result.report["claims"]["legalTitleProven"])
        self.assertFalse(self.result.report["claims"]["institutionIdentityProven"])
        self.assertFalse(self.result.report["claims"]["custodyTransferred"])
        self.assertFalse(self.result.report["sourceReconciliation"]["sourceConsensusVerified"])
        self.assertEqual(len(self.result.report["sourceReconciliation"]["inputs"]), 11)

    def test_burn_retains_historical_title_while_current_owner_is_zero(self):
        fixture = TitleV5Fixture(burned=True, unsupported=False)
        _, _, result = compose(fixture)
        value = packet(result)
        self.assertTrue(value["sourceState"]["burned"])
        self.assertEqual(value["ownershipProvenance"]["currentOwner"], ZERO_ADDRESS)
        self.assertEqual(value["ownershipProvenance"]["transfers"][-1]["to"], ZERO_ADDRESS)
        self.assertEqual(value["legalInstrument"]["accession"]["recordHash"], fixture.selected)

    def test_native_derivation_profile_never_promotes_unresolved_source_scope(self):
        join = self.result.report["nativeTitleDerivation"]
        self.assertEqual(join["coverage"], native.COVERAGE)
        self.assertEqual(join["coverage"]["otherOwnerHosts"], "not_enumerated")
        self.assertEqual(join["coverage"]["protocolEventArchive"], "supplied_unverified")
        self.assertFalse(join["coverage"]["completeItem10"])
        self.assertTrue(any(row["reason"] == "unsupported_original_title_schema"
            for row in join["unresolved"]))


if __name__ == "__main__":
    unittest.main()
