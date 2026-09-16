"""Fixed-catalogue and pointer-closure tests for independent scope capture."""
import copy
from pathlib import Path
import tempfile
import unittest

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import calldata, decode, encode
from .independent_catalog_source import (CATALOG, PAYLOAD_FAMILY, PROFILE, PROFILE_HASH,
    PROFILE_BYTES, SIGNATURE_FAMILY, IndependentCatalogSource, definitions, replay)
from .independent_wire import RECORD_TYPES, ZERO


FIXTURE = Path(__file__).resolve().parents[2] / "schemas/museum/independent-source/local-fixture"


class CatalogTransport:
    """Synthetic lookup over the old fixture plus new fixed-catalogue views."""

    def __init__(self, rows, capture, scope, *, type_failure=None, wrong_module=False,
                 pointer_mode=None, empty_head=None):
        self.rows = copy.deepcopy(rows)
        self.scope = scope
        self.type_failure = type_failure
        self.wrong_module = wrong_module
        self.pointer_mode = pointer_mode
        self.empty_head = empty_head
        self.used = []
        records = [row for row in capture["records"] if row["receipt"][0] == str(scope)]
        pointers, seen = [], set()
        for row in records:
            for family, field, pointer in ((PAYLOAD_FAMILY, "payloadHex", row["pointers"][0]),
                                           (SIGNATURE_FAMILY, "signatureBundleHex", row["pointers"][1])):
                digest = keccak256(hex_bytes(row[field])); key = (family, digest)
                if key not in seen:
                    seen.add(key); pointers.append((pointer, family, digest))
        self.pointers = pointers

    @staticmethod
    def _arguments(data, kinds):
        return decode(kinds, hex_bytes(data)[4:])

    @staticmethod
    def _result(kinds, values):
        return "0x" + encode(kinds, values).hex()

    def request(self, method, params):
        self.used.append((method, copy.deepcopy(params)))
        if method == "eth_call":
            data = params[0]["data"]
            if data.startswith(calldata("streamModuleType()")[:10]):
                value = ZERO if self.wrong_module else keccak256(b"COLLECTION_ATTESTATIONS")
                return self._result(("bytes32",), (value,))
            if data.startswith(calldata("streamModuleVersion()")[:10]):
                return self._result(("bytes32",),
                    (keccak256(b"6529stream.collection-attestations.independent.v1"),))
            if data.startswith(calldata("streamModuleInterfaceId()")[:10]):
                return self._result(("bytes4",), ("0x771b2917",))
            if data.startswith(calldata("isIndependentRecordType(bytes32)")[:10]):
                record_type, = self._arguments(data, ("bytes32",))
                accepted = record_type in RECORD_TYPES and record_type != self.type_failure
                return self._result(("bool",), (accepted,))
            if data.startswith(calldata("payloadPointerCount(uint256)")[:10]):
                scope, = self._arguments(data, ("uint256",))
                if scope != self.scope: raise MuseumError("wrong synthetic pointer scope")
                count = len(self.pointers)
                if self.pointer_mode == "omit": count -= 1
                if self.pointer_mode == "extra": count += 1
                return self._result(("uint256",), (count,))
            if data.startswith(calldata("payloadPointerAt(uint256,uint256)")[:10]):
                scope, index = self._arguments(data, ("uint256", "uint256"))
                if scope != self.scope: raise MuseumError("wrong synthetic pointer scope")
                if index >= len(self.pointers):
                    value = ("0x" + "99" * 20, PAYLOAD_FAMILY, "0x" + "98" * 32)
                else:
                    value = self.pointers[index]
                    if self.pointer_mode == "family" and index == 0:
                        value = (value[0], SIGNATURE_FAMILY if value[1] == PAYLOAD_FAMILY
                                 else PAYLOAD_FAMILY, value[2])
                return self._result(("address", "bytes32", "bytes32"), value)
            if data.startswith(calldata("recordChainHash(uint256,bytes32)")[:10]):
                scope, record_type = self._arguments(data, ("uint256", "bytes32"))
                existing = next((row for row in self.rows
                    if row["method"] == method and row["params"] == params), None)
                if existing is not None:
                    return copy.deepcopy(existing["result"])
                if scope == self.scope:
                    head = "0x" + "97" * 32 if record_type == self.empty_head else ZERO
                    return self._result(("bytes32", "uint64"), (head, 0))
        for row in self.rows:
            if row["method"] == method and row["params"] == params:
                return copy.deepcopy(row["result"])
        raise MuseumError("catalogue fixture call is absent")


class IndependentCatalogSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        old_anchor = loads((FIXTURE / "anchor.json").read_bytes(), canonical=True)
        cls.rows = loads((FIXTURE / "transcript.json").read_bytes(), maximum=1048576,
            canonical=True)["calls"]
        cls.capture = loads((FIXTURE / "source-capture.json").read_bytes(), maximum=1048576,
            canonical=True)
        cls.common = {key: value for key, value in old_anchor.items()
            if key not in ("profile", "lanes")}

    def anchor(self, scope=1, **changes):
        value = self.common | {"profile": PROFILE, "scopeKey": str(scope)} | changes
        return dumps(value)

    def adapter(self, scope=1, **transport_options):
        transport = CatalogTransport(self.rows, self.capture, scope, **transport_options)
        return IndependentCatalogSource(self.anchor(scope), transport), transport

    def test_fixed_eight_lane_scope_includes_authenticated_empty_heads(self):
        adapter, transport = self.adapter()
        result = loads(adapter.snapshot(), maximum=16777216, canonical=True)
        self.assertEqual(result["profileHash"], PROFILE_HASH)
        self.assertEqual(result["sourceState"], {"chainId": self.common["chainId"],
            "core": self.common["core"], "scopeKey": "1", "blockHash": self.common["blockHash"],
            "blockNumber": self.common["blockNumber"]})
        self.assertEqual(result["scopeKey"], "1")
        self.assertEqual(result["catalog"], [{"name": name, "recordType": record_type}
            for name, record_type in CATALOG])
        self.assertEqual(len(result["lanes"]), 8)
        self.assertEqual([lane["recordType"] for lane in result["lanes"]], list(RECORD_TYPES))
        populated = [lane for lane in result["lanes"] if lane["count"] != "0"]
        empty = [lane for lane in result["lanes"] if lane["count"] == "0"]
        self.assertEqual([(lane["recordType"], lane["count"], lane["status"])
            for lane in populated], [(RECORD_TYPES[-1], "5", "complete_history")])
        self.assertTrue(all(lane["chainHash"] == ZERO
            and lane["status"] == "authenticated_empty" for lane in empty))
        self.assertEqual(len(empty), 7)
        self.assertEqual(len(result["records"]), 5)
        self.assertTrue(result["claims"]["fixedCatalogueComplete"])
        self.assertTrue(result["claims"]["independentScopeInventoryComplete"])
        self.assertFalse(result["claims"]["cryptographicStateProof"])
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        self.assertFalse(result["claims"]["fullObjectDossierConformance"])
        self.assertEqual(result["mode"], "synthetic_fixture")
        catalogue_calls = [call for call in transport.used if call[0] == "eth_call"
            and call[1][0]["data"].startswith(calldata("isIndependentRecordType(bytes32)")[:10])]
        self.assertEqual(len(catalogue_calls), 9)
        self.assertEqual(adapter.transcript(), adapter.reader.transcript())
        self.assertEqual(adapter.snapshot(), adapter.snapshot())

    def test_scope_zero_is_exact_deployment_scope_not_an_inferred_token_lane(self):
        adapter, _ = self.adapter(0)
        result = loads(adapter.snapshot(), maximum=16777216, canonical=True)
        self.assertEqual(result["scopeKey"], "0")
        self.assertEqual(next(lane for lane in result["lanes"]
            if lane["recordType"] == RECORD_TYPES[-1])["count"], "1")
        self.assertEqual(len(result["records"]), 1)
        self.assertEqual(result["records"][0]["subject"][1], "0")
        self.assertTrue(all(lane["scopeKey"] == "0" for lane in result["lanes"]))

    def test_pointer_inventory_is_complete_and_deduplicated_by_family_and_hash(self):
        adapter, transport = self.adapter()
        result = loads(adapter.snapshot(), maximum=16777216, canonical=True)
        expected = transport.pointers
        self.assertEqual(len(result["payloadPointers"]), len(expected))
        self.assertEqual([(row["pointer"], row["family"], row["contentHash"])
            for row in result["payloadPointers"]], expected)
        self.assertEqual(len({(row["family"], row["contentHash"])
            for row in result["payloadPointers"]}), len(result["payloadPointers"]))
        self.assertLessEqual(len(result["payloadPointers"]), 2 * len(result["records"]))

    def test_omitted_extra_wrong_family_and_false_empty_head_reject(self):
        failures = ({"pointer_mode": "omit"}, {"pointer_mode": "extra"},
            {"pointer_mode": "family"}, {"empty_head": RECORD_TYPES[1]})
        for options in failures:
            with self.subTest(options=options), self.assertRaises(MuseumError):
                self.adapter(**options)[0].snapshot()

    def test_anchor_has_scope_only_and_rejects_external_lane_declarations(self):
        value = loads(self.anchor(), canonical=True)
        self.assertIn("scopeKey", value); self.assertNotIn("lanes", value)
        value["lanes"] = [{"scopeKey": "1", "recordType": RECORD_TYPES[0]}]
        with self.assertRaisesRegex(MuseumError, "anchor shape"):
            IndependentCatalogSource(dumps(value), CatalogTransport(self.rows, self.capture, 1))
        value = loads(self.anchor(), canonical=True); del value["scopeKey"]
        with self.assertRaisesRegex(MuseumError, "anchor shape"):
            IndependentCatalogSource(dumps(value), CatalogTransport(self.rows, self.capture, 1))

    def test_all_native_types_and_module_identity_are_mandatory(self):
        for options in ({"type_failure": RECORD_TYPES[-1]}, {"wrong_module": True}):
            with self.subTest(options=options), self.assertRaises(MuseumError):
                self.adapter(**options)[0].snapshot()

    def test_synthetic_transport_cannot_claim_recorded_state(self):
        transport = CatalogTransport(self.rows, self.capture, 1)
        with self.assertRaisesRegex(MuseumError, "synthetic transport"):
            IndependentCatalogSource(self.anchor(), transport, provenance="trusted_rpc")

    def test_offline_replay_requires_external_pins_and_writes_closed_output(self):
        adapter, _ = self.adapter()
        snapshot = adapter.snapshot(); transcript = adapter.reader.transcript(); anchor = self.anchor()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); anchor_path = root / "anchor.json"; transcript_path = root / "transcript.json"
            anchor_path.write_bytes(anchor); transcript_path.write_bytes(transcript)
            output = root / "output"
            pins = replay(anchor_path, keccak256(anchor), transcript_path, keccak256(transcript), output)
            self.assertEqual((output / "snapshot.json").read_bytes(), snapshot)
            self.assertEqual(loads((output / "pins.json").read_bytes(), canonical=True), pins)
            self.assertFalse(pins["actualChainAcceptance"])
            with self.assertRaisesRegex(MuseumError, "external anchor pin"):
                replay(anchor_path, "0x" + "99" * 32, transcript_path,
                    keccak256(transcript), root / "wrong")
            with self.assertRaises(FileExistsError):
                replay(anchor_path, keccak256(anchor), transcript_path,
                    keccak256(transcript), output)

    def test_checked_in_profile_is_exact_and_generator_check_is_read_only(self):
        directory = Path(__file__).resolve().parents[2] / "schemas/museum/object-dossier"
        self.assertEqual((directory / "independent-catalog-profile.json").read_bytes(), PROFILE_BYTES)
        self.assertEqual(definitions(directory, check=True), PROFILE_HASH)


if __name__ == "__main__": unittest.main()
