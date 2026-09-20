"""V9 full supplied-data joins, using explicit synthetic source captures."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

from . import acquisition_packet_v5 as v5
from . import acquisition_packet_v6 as v6
from . import acquisition_packet_v7 as v7
from . import acquisition_packet_v9 as v9
from . import acquisition_scoped_policy_finality_v2 as native
from tools.museum import acquisition_scoped_policy_finality_v9 as assembly
from tools.museum.canonical import MuseumError, dumps, keccak256, loads
from tools.museum.scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2


def composed(*, burned=False):
    fixture = ScopedPolicyFinalityFixtureV2(burned=burned)
    previous, captured = fixture.policy_inputs()
    result = assembly.compose(previous.files, previous.manifest_hash, captured.files, captured.manifest_hash,
        disclosure="public")
    packet = loads(dict(result.files)[assembly.PACKET_PATH], maximum=assembly.MAX_BYTES, canonical=True)
    return fixture, previous, captured, result, packet


class AcquisitionPacketV9Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.baseline = composed()

    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught: v9.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_exact_native_branches_preserve_all_other_nineteen_groups(self):
        _, previous, _, result, packet = self.baseline
        with patch("socket.socket", side_effect=AssertionError("offline")):
            self.assertEqual(v9.validate(dumps(packet)), packet)
        original = loads(dict(previous.files)[assembly.previous.PACKET_PATH], maximum=assembly.MAX_BYTES, canonical=True)
        for key in original:
            if key not in {"schema", "version", "finality", "contentRootProof", "citation"}:
                self.assertEqual(packet[key], original[key], key)
        self.assertEqual(packet["contentRootProof"], native.token_proof(packet["finality"]["fragment"]))
        self.assertFalse(result.report["sourceCoverageComplete"])
        self.assertEqual(len(result.report["items"]), 19)

    def test_exact_proof_and_discriminator_pairing(self):
        for edit in (lambda p: p["contentRootProof"].update(leafIndex="1"),
                lambda p: p["contentRootProof"].update(kind="native_token_content_proof"),
                lambda p: p["finality"].update(kind="native_collection_finality")):
            packet = deepcopy(self.baseline[4]); edit(packet)
            with self.subTest(edit=edit): self.reject(packet)

    def test_individually_valid_source_state_cannot_conflict_with_other_fragments(self):
        for key in ("deploymentEvidenceHash", "stateRoot"):
            packet = deepcopy(self.baseline[4]); fragment = packet["finality"]["fragment"]
            fragment["sourceState"][key] = keccak256(("different " + key).encode())
            native.validate(dumps(fragment))
            with self.subTest(key=key): self.reject(packet, "source")

    def test_target_readiness_is_not_the_supplied_packet_current_seed_by_assumption(self):
        packet = deepcopy(self.baseline[4])
        packet["entropy"]["leaf"]["seed"] = keccak256(b"different packet seed")
        packet["entropy"]["leafHash"] = v9.v1._entropy_hash(packet["entropy"]["leaf"])
        self.reject(packet, "original readiness")

    def test_native_receipt_cannot_be_cast_as_generic_authority(self):
        fragment = self.baseline[4]["finality"]["fragment"]
        keys = [(fragment["graph"]["finality"]["address"], fragment["bundle"]["finality"]["record"][2])]
        keys.extend((fragment["graph"]["policySnapshot"]["address"], row["receipt"][0])
            for row in fragment["bundle"]["snapshot"]["history"])
        keys.extend((fragment["graph"]["policyReference"]["address"], row["receipt"][1][0])
            for row in fragment["bundle"]["reference"]["history"])
        for host, digest in keys:
            packet = deepcopy(self.baseline[4]); packet["tombstone"]["record"].update(host=host, recordHash=digest)
            with self.subTest(host=host, digest=digest): self.reject(packet, "cannot be relabeled")

    def test_non_finality_group_semantics_still_enforced(self):
        packet = deepcopy(self.baseline[4]); packet["platformSustainability"]["horizonStatus"] = "below_floor"
        if packet["platformSustainability"]["horizonStatus"] == self.baseline[4]["platformSustainability"]["horizonStatus"]:
            packet["platformSustainability"]["horizonStatus"] = "meets_floor"
        self.reject(packet, "funding horizon")
        packet = deepcopy(self.baseline[4]); packet["ownershipProvenance"]["currentOwner"] = v9.ZERO_ADDRESS
        self.reject(packet, "owner")

    def test_previous_schema_bytes_stay_identical(self):
        for module in (v5, v6, v7):
            path = Path(module.ROOT) / "schemas" / "records" / (module.PACKET + ".json")
            self.assertEqual(path.read_bytes(), module.PACKET_SCHEMA_BYTES)
        self.assertEqual(v5.PACKET_SCHEMA_HASH, "0xe1cf0c01c6aa7b841635a43274aa26b6c13c01140e1dfcecf55a14fab0789020")
        self.assertEqual(v6.PACKET_SCHEMA_HASH, "0x6302f0e0d3fafd5cc5ffba389860291ae14ca36e6a6d26853114143bba5faa64")

    def test_previous_v8_embedded_branch_definitions_are_unchanged(self):
        from . import acquisition_packet_v8 as old
        previous,new=old.definitions(),v9.definitions()
        for key,value in previous.items():
            if key not in ("packet","finality","proof"):
                self.assertEqual(new[key],value,key)
        self.assertEqual(new["previousFinalityV8"],previous["finality"])
        self.assertEqual(new["previousProofV8"],previous["proof"])


if __name__ == "__main__": unittest.main()
