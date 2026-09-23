"""Version-local V7 pairing and cross-capture tests.

The joined chain is an explicit synthetic fixture.  Passing these checks does
not authenticate RPC provenance or prove historical execution.
"""
import copy
from pathlib import Path
import unittest
from unittest.mock import patch

from . import acquisition_packet_v5 as v5
from . import acquisition_packet_v6 as v6
from . import acquisition_packet_v7 as v7
from . import acquisition_scoped_static_finality_v1 as scoped
from tools.museum import acquisition_finality_v7 as assembly
from tools.museum.canonical import MuseumError, dumps, keccak256, loads
from tools.museum.scoped_static_finality_fixture import ScopedStaticFinalityFixture


def composed(scope_type=1, *, burned=False):
    fixture = ScopedStaticFinalityFixture(scope_type=scope_type, burned=burned)
    previous, captured = fixture.scoped_inputs()
    result = assembly.compose(previous.files, previous.manifest_hash, captured.files, captured.manifest_hash,
        disclosure="public")
    packet = loads(dict(result.files)[assembly.PACKET_PATH], maximum=assembly.MAX_BYTES, canonical=True)
    return fixture, previous, captured, result, packet


class AcquisitionPacketV7Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = composed(1, burned=True)

    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught:
            v7.validate(dumps(value))
        if message:
            self.assertIn(message, str(caught.exception))

    def test_all_three_scopes_form_exact_paired_v7_exports(self):
        cases = [self.baseline]
        cases.extend(composed(scope_type) for scope_type in (2, 3))
        for scope_type, (_, _, _, result, packet) in zip((1, 2, 3), cases):
            with self.subTest(scope_type=scope_type), patch("socket.socket", side_effect=AssertionError("offline")):
                self.assertEqual(v7.validate(dumps(packet)), packet)
                self.assertEqual(packet["finality"]["fragment"]["bundle"]["scope"][0], str(scope_type))
                self.assertEqual(packet["contentRootProof"], scoped.token_proof(packet["finality"]["fragment"]))
                self.assertEqual(assembly.verify(result.files, result.manifest_hash).files, result.files)
        self.assertTrue(cases[0][4]["sourceState"]["burned"])
        self.assertEqual(cases[0][4]["finality"]["fragment"]["identity"]["lifecycle"], "3")

    def test_native_scoped_finality_and_proof_are_an_exact_pair(self):
        packet = copy.deepcopy(self.baseline[4])
        packet["contentRootProof"]["leafIndex"] = "1"
        self.reject(packet, "proof")
        packet = copy.deepcopy(self.baseline[4])
        packet["contentRootProof"]["scope"][0] = "2"
        self.reject(packet, "proof")
        packet = copy.deepcopy(self.baseline[4])
        packet["finality"]["fragment"]["schema"] = "STREAM_OTHER_SCOPED_FINALITY_V1"
        self.reject(packet)

    def test_current_burn_and_original_membership_cannot_diverge(self):
        packet = copy.deepcopy(self.baseline[4])
        packet["finality"]["fragment"]["identity"].update(burned=False, lifecycle="2")
        self.reject(packet)
        packet = copy.deepcopy(self.baseline[4])
        packet["sourceState"]["burned"] = False
        self.reject(packet)

    def test_cross_source_state_pins_must_match_even_when_fragment_is_self_consistent(self):
        for key in ("deploymentEvidenceHash", "stateRoot"):
            packet = copy.deepcopy(self.baseline[4])
            packet["finality"]["fragment"]["sourceState"][key] = keccak256(("other " + key).encode())
            # These are supplied capture identity fields, not native hash
            # preimages.  The standalone fragment remains internally valid;
            # V7 must reject the contradiction with its other source captures.
            scoped.validate(dumps(packet["finality"]["fragment"]))
            with self.subTest(key=key):
                self.reject(packet, "source")

    def test_native_record_alias_and_original_event_observation_conflicts_reject(self):
        packet = copy.deepcopy(self.baseline[4])
        fragment = packet["finality"]["fragment"]
        packet["tombstone"]["record"].update(host=fragment["graph"]["finality"]["address"],
            recordHash=fragment["bundle"]["finality"]["record"][2])
        self.reject(packet, "cannot be relabeled")
        packet = copy.deepcopy(self.baseline[4])
        packet["finality"]["fragment"]["events"][0]["log"]["data"] += "00"
        self.reject(packet)

    def test_v5_and_v6_definition_bytes_remain_frozen(self):
        self.assertEqual(keccak256(v5.PACKET_SCHEMA_BYTES),
            "0xe1cf0c01c6aa7b841635a43274aa26b6c13c01140e1dfcecf55a14fab0789020")
        self.assertEqual(keccak256(v6.PACKET_SCHEMA_BYTES),
            "0x6302f0e0d3fafd5cc5ffba389860291ae14ca36e6a6d26853114143bba5faa64")
        for module in (v5, v6):
            path = Path(module.ROOT) / "schemas" / "records" / (module.PACKET + ".json")
            self.assertEqual(path.read_bytes(), module.PACKET_SCHEMA_BYTES)


if __name__ == "__main__":
    unittest.main()
