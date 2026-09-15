"""Offline input and codec regressions; these tests do not stand for receipt capture."""
import unittest
from .canonical import MuseumError, loads, schema_id
from .chain_abi import encode, decode
from .current_native_fixture import abi_kind, abi_name
from .current_rights_capture import fixture_rights, create_address, CurrentRightsFixture, METADATA
from .independent_wire import ZERO, ZERO_ADDRESS


class RightsCaptureInputs(unittest.TestCase):
    def test_explicit_fixture_licenses_have_no_invented_instrument_or_artist_identity(self):
        sid = schema_id("source collection")
        for cls, status in ((7, "denied"), (8, "granted")):
            value = loads(fixture_rights(sid, cls), canonical=True)
            self.assertEqual(value["subjectId"], sid)
            self.assertEqual(value["grants"]["reproduction"]["status"], status)
            self.assertEqual(len(value["grants"]), 6)
            self.assertIsNone(value["instrument"])
            self.assertIsNone(value["licensor"]["instrumentDigest"])
            self.assertIn("test-fixture", value["licensor"]["identity"]["name"])
            self.assertEqual(value["basis"], "unspecified")

    def test_native_fixed_address_array_is_three_words_without_length_word(self):
        row = {"type": "address[3]"}; address = "0x" + "11" * 20
        kind = abi_kind(row)
        raw = encode((kind,), ((address,)*3,))
        self.assertEqual(raw, (bytes(12)+bytes.fromhex("11"*20))*3)
        self.assertEqual(decode((kind,), raw), ((address,)*3,))
        self.assertEqual(abi_name(row), "address[3]")
        with self.assertRaises(MuseumError): encode((kind,), ((address,)*2,))

    def test_fixed_dynamic_tuple_array_has_canonical_offsets_and_selector_spelling(self):
        row = {"type": "tuple[2]", "components": [{"type": "uint8"}, {"type": "string"}]}
        kind = abi_kind(row); values = (((7,"first"),(8,"second")),)
        self.assertEqual(abi_name(row), "(uint8,string)[2]")
        self.assertEqual(decode((kind,), encode((kind,), values)), values)
        for bad in ("address[0]", "address[65]", "address[x]"):
            with self.assertRaises(MuseumError): abi_kind({"type": bad})

    def test_original_module_manifest_and_flat_core_tuple_are_preserved_by_planner(self):
        class Planner(CurrentRightsFixture):
            def __init__(self):
                self.addresses = {"StreamCore": "0x"+"11"*20, "StreamModuleRegistry": "0x"+"22"*20, METADATA: "0x"+"33"*20}
                self.deployment = schema_id("deployment"); self.actions = []; self.classes = []
                self.pointer = (ZERO_ADDRESS, ZERO, False, ZERO, "0x00000000", ZERO_ADDRESS, 0, ZERO, ZERO, 0)
            def rpc(self, method, params):
                self.assert_rpc = (method, params)
                return "0x6000"
            def call(self, name, function, values=()):
                if function == "streamModuleType": return (schema_id("COLLECTION_METADATA"),)
                if function == "streamModuleVersion": return (schema_id("version"),)
                if function == "streamModuleInterfaceId": return ("0x12345678",)
                if function == "streamModuleManifest": return ("urn:original:manifest", schema_id("module manifest"))
                if function == "registrationChainHash": return (ZERO, 0)
                if function == "getSatellitePointer": return self.pointer
                if function == "pointerStateHash":
                    self.pending_pointer = values[1]
                    return (schema_id(str(values)),)
                raise AssertionError(function)
            def governed(self, name, function, values, transition):
                self.actions.append((name, function, values, transition))
                self.classes.append(1)
            def data(self, name, function, values): return "0x12345678"
            def manifest_payload(self, value): return "0x"+"44"*20, schema_id("manifest payload")
            def publication(self, pointer, digest, *, collection_metadata=None):
                assert collection_metadata == self.addresses[METADATA]
                return (self.addresses["StreamCore"], 0, "0xabcdefab", ZERO, ZERO, ZERO, ZERO), b"tail"
            def govern(self, action_class, calls, datas):
                assert len(calls) == 2 and datas[-1] == b"tail"
                self.classes.append(action_class)
                self.actions.append(("StreamCore", "updateSatellitePointer", (), ()))
                self.pointer = self.pending_pointer
        probe = Planner(); probe.select_metadata()
        self.assertEqual([r[1] for r in probe.actions], ["registerModule", "updateSatellitePointer"])
        item = probe.actions[0][2][0]
        self.assertEqual(item[7:], (schema_id("module manifest"), "urn:original:manifest"))
        self.assertEqual(probe.pointer[0], probe.addresses[METADATA])
        self.assertEqual(probe.pointer[3:7], (schema_id("COLLECTION_METADATA"), "0x12345678", probe.addresses["StreamModuleRegistry"], 1))
        self.assertEqual(probe.pointer[-1], 1)
        self.assertEqual(probe.classes, [1, 3])

    def test_create_coordinate_known_ethereum_vectors_and_nonce_boundary(self):
        self.assertEqual(create_address("0x6ac7ea33f8831ea9dcc53393aaa88b25a785dbf0", 0), "0xcd234a471b72ba2f1ccf0a70fcaba648a5eecd8d")
        self.assertEqual(create_address("0x6ac7ea33f8831ea9dcc53393aaa88b25a785dbf0", 1), "0x343c43a37d37dff08ae8c4a11544c718abb4fcf8")
        for nonce in (-1, True, 2**64):
            with self.assertRaises(MuseumError): create_address("0x"+"11"*20, nonce)


if __name__ == "__main__": unittest.main()
