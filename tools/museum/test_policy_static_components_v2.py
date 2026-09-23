import copy
import unittest
from unittest import mock

from . import policy_static_components_v2 as p
from .canonical import MuseumError, keccak256, schema_id
from .chain_abi import encode
from .independent_wire import ZERO
from .native_finality_wire import INDEPENDENT_FAMILIES
from .policy_content_types_v2 import STATEMENT


def H(value):
    return keccak256(str(value).encode())


def A(value):
    return "0x" + value.to_bytes(20, "big").hex()


class Fixture:
    """Synthetic retained checkpoint; hashes below are independent of p.validate."""

    def __init__(self, count=2):
        self.context = {"chainId": "31337", "core": A(1), "metadata": A(2), "router": A(3),
                        "routerCodeHash": H("router code"), "selection": A(4),
                        "selectionCodeHash": H("selection code"),
                        "routerModuleVersion": H("module version"),
                        "routerModuleManifestHash": H("manifest"),
                        "adapters": [{"family": family, "address": A(20 + index),
                                      "runtimeHash": H("adapter " + str(index))}
                                     for index, family in enumerate(p.FAMILIES)]}
        self.scope = (0, 7, 0, ZERO)
        self.selected = (A(5), H("registry code"), H("version"), A(6), H("renderer code"),
                         H("renderer id"), H("renderer version"), H("context"), H("schema"),
                         H("reads"), H("registration"))
        self.config = (1, A(6), "ipfs://base/", "ipfs://pending", 0, True)
        self.source = (31337, True, "Collection", "Description", "ipfs://image", "ipfs://animation",
                       "return token;", (A(7), H("script host"), H("script manifest")),
                       (A(8), H("media host"), H("media manifest")))
        snapshot = keccak256(encode(("bytes32", p.RAW_SOURCE), (p.SOURCE_SNAPSHOT_DOMAIN, self.source)))
        seed = (ZERO, H("previous"), 7, 0, 1, 1, 1, snapshot, self.selected, self.config)
        record_hash = keccak256(encode(("bytes32", "address", "address", p.CONFIG_RECORD),
                                       (p.CONFIG_RECORD_DOMAIN, A(1), A(3), seed)))
        self.record = (record_hash, *seed[1:])
        self.sources = (A(1), A(3), A(2), A(9), A(10), A(11))
        self.source_hashes = tuple(H("source " + str(i)) for i in range(6))
        self.rows = []
        for i in range(count):
            row = (41 + i, record_hash, keccak256(encode((p.CONFIG_RECORD,), (self.record,))), snapshot,
                   keccak256(encode((p.RAW_SOURCE,), (self.source,))), self.selected,
                   self.sources, self.source_hashes)
            self.rows.append(row)
        root = ZERO
        for i, row in enumerate(self.rows):
            selected = keccak256(encode(("bytes32", "uint256", "address", "address", p.SELECTION_ROW),
                                         (p.SELECTION_ROW_DOMAIN, 31337, A(1), A(3), row)))
            root = keccak256(encode(("bytes32", "bytes32", "uint256", "bytes32"),
                                    (p.SELECTION_CHAIN_DOMAIN, root, i, selected)))
        self.artist = (True, A(12), H("artist registry"), H("artist"), 3, H("binding"), A(13),
                       H("identity"), H("acceptance"), 100, 101, H("artist snapshot"))
        self.authenticated = (self.scope, H("source profile"), H("selection id"), H("membership"),
                              root, count, self.artist[11])
        self.plan = (self.scope, self.authenticated[3], H("collection state"), count, count, root)
        self.originals = [{"configRecordHash": record_hash, "configRecord": self.record,
                           "rawSource": self.source, "selectedConfig": self.config}]
        self.expectations = self._expectations()

    def _field(self, family, row):
        s, c, raw = self.selected, self.config, self.source
        if family == p.RENDERER:
            return keccak256(encode(("address", "bytes32", "bytes32", "address", "bytes32", "bytes32",
                                     "bytes32", "bytes32"), (s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[10])))
        if family == p.RENDER_CONTEXT:
            return keccak256(encode(("bytes32", "bytes32", p.METADATA_CONFIG), (s[7], s[8], c)))
        if family == p.DEPENDENCY_SOURCE:
            return keccak256(encode(("address", "bytes32", "bytes32", "bytes32", "bytes32",
                                     ("address",) * 6, ("bytes32",) * 6, p.MANIFEST_SELECTION),
                                    (s[0], s[1], s[2], s[9], s[10], row[6], row[7], raw[7])))
        if family == p.SCRIPT_SOURCE:
            return keccak256(encode(("bytes32", p.MANIFEST_SELECTION),
                                    (keccak256(raw[6].encode()), raw[7])))
        if family == p.MEDIA_MANIFEST:
            return keccak256(encode(("bytes32", "bytes32", p.MANIFEST_SELECTION, "bytes32", "bytes32", "uint8"),
                                    (keccak256(raw[4].encode()), keccak256(raw[5].encode()), raw[8],
                                     keccak256(c[2].encode()), keccak256(c[3].encode()), c[4])))
        return keccak256(encode(("bytes32", "bytes32", "bool", "uint8"),
                                (keccak256(raw[2].encode()), keccak256(raw[3].encode()), raw[1], c[0])))

    def _expectations(self):
        values = []
        for family in p.FAMILIES:
            identity = keccak256(encode(("bytes32", "bytes32", "uint256", "address", "address", "address",
                                         "address", "bytes32", p.AUTHENTICATED_SELECTION),
                                        (p.DOMAIN, family, 31337, A(1), A(2), A(3), A(4),
                                         H("selection code"), self.authenticated)))
            folded = ZERO
            for index, row in enumerate(self.rows):
                component = keccak256(encode(("bytes32", "bytes32", "bytes32", "uint256", "uint256",
                                              "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"),
                                             (p.ROW_DOMAIN, identity, family, index, row[0], row[1], row[2],
                                              row[3], row[4], self._field(family, row))))
                folded = keccak256(encode(("bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint256", "bytes32"),
                                          (p.FOLD_DOMAIN, identity, family, folded, index, row[0], component)))
            if family == p.METADATA_ROUTER:
                folded = keccak256(encode(("bytes32", "bytes32", "bytes32", "bytes32", p.ARTIST_PRESENTATION),
                                          (p.FOLD_DOMAIN, identity, family, folded, self.artist)))
            digest = keccak256(encode(("bytes32", "bytes32", "bytes32", "uint64", "bytes32"),
                                      (p.DOMAIN, identity, family, len(self.rows), folded)))
            adapter = self.context["adapters"][p.FAMILIES.index(family)]
            values.append((family, adapter["address"], "0x12345678", adapter["runtimeHash"],
                           H("module version"), H("manifest"), digest))
        return values

    def value(self):
        return {"context": copy.deepcopy(self.context), "authenticated": self.authenticated,
                "plan": self.plan, "rows": copy.deepcopy(self.rows),
                "originals": copy.deepcopy(self.originals), "artistPresentation": self.artist,
                "componentExpectations": copy.deepcopy(self.expectations)}

    def mixin_inputs(self):
        extras = [(family, A(30 + index), "0x12345678", H("other code" + str(index)),
                   H("other version" + str(index)), H("other manifest" + str(index)), H("other data" + str(index)))
                  for index, family in enumerate(sorted(set(INDEPENDENT_FAMILIES) - set(p.FAMILIES)))]
        components = sorted([*self.expectations, *extras], key=lambda row: row[0])
        content = (self.authenticated[2], H("selection hash"), H("inventory"), H("policy chain"),
                   self.scope, len(self.rows), len(self.rows), H("leaf chain"), H("content root"), H("output root"))
        entropy = (A(50), H("entropy code"), H("entropy profile"), H("entropy plan"), H("entropy inventory"),
                   H("entropy chain"), 1, H("snapshot profile"), H("reference profile"))
        statement = (self.scope, H("core facts"), H("root"), len(self.rows), H("leaf schema"),
                     H("snapshot manifest"), H("reference manifest"), tuple(H("input" + str(i)) for i in range(10)),
                     tuple(components), entropy, 1, 1)
        source = [self.scope, (), self.artist, self.plan, content, (), (), (), ()]
        receipt = [H("receipt") for _ in range(17)]; receipt[15] = H("source profile")
        return {"source": source, "receipt": receipt}, {
            "contentPlan": content, "selectionPlan": self.plan, "selectionRows": self.rows}, statement


class ReadHarness(p.PolicyStaticReads):
    def __init__(self, fixture):
        self.f = fixture
        self.a = {"chainId": "31337"}
        self.graph = {"core": {"address": A(1), "runtimeHash": H("core code")},
                      "metadata": {"address": A(2), "runtimeHash": H("metadata code")},
                      "router": {"address": A(3), "runtimeHash": H("router code")},
                      "staticSelection": {"address": A(4), "runtimeHash": H("selection code")},
                      "provider": {"address": A(14), "runtimeHash": H("provider code")}}
        self.provider_evidence = {"adapters": [
            {"family": row["family"], "address": row["address"], "runtimeHash": row["runtimeHash"]}
            for row in fixture.context["adapters"]]}
        self.calls = []

    def _one(self, target, signature, output, inputs=(), values=(), maximum=32768):
        self.calls.append((target, signature, values))
        if signature == "checkpoint(bytes32)": return self.f.plan
        if signature == "selectionAt(bytes32,uint256)": return self.f.rows[values[1]]
        if signature == "metadataConfigRecord(bytes32)": return self.f.record
        if signature == "routerModuleVersion()": return H("module version")
        if signature == "routerModuleManifestHash()": return H("manifest")
        raise AssertionError(signature)

    def _read(self, target, signature, outputs, inputs=(), values=(), maximum=32768):
        self.calls.append((target, signature, values))
        if signature == "staticRenderSourceForConfig(uint256,bytes32)":
            return self.f.source, self.f.config
        raise AssertionError(signature)


class PolicyStaticComponentsTests(unittest.TestCase):
    def test_complete_stored_checkpoint_reproduces_all_six_families_and_dedupes_original(self):
        value = Fixture().value()
        report = p.validate(value)
        self.assertEqual(report["tokenCount"], "2")
        self.assertEqual(report["uniqueConfigRecords"], "1")
        self.assertEqual([row["family"] for row in report["families"]], list(p.FAMILIES))
        self.assertTrue(all(row["expectationMatched"] for row in report["families"]))
        self.assertEqual(report["historicalSourceMode"], "immutable_frozen_source_snapshot")
        self.assertFalse(report["currentSelectionRevalidated"])
        self.assertFalse(report["currentSourceRevalidated"])

    def test_live_source_fallback_and_current_state_fields_are_rejected(self):
        f = Fixture(); value = f.value()
        record = list(value["originals"][0]["configRecord"]); record[7] = ZERO
        record[0] = p._record_hash(f.context["core"], f.context["router"], tuple(record))
        value["originals"][0]["configRecordHash"] = record[0]
        value["originals"][0]["configRecord"] = tuple(record)
        with self.assertRaisesRegex(MuseumError, "frozen ONCHAIN"):
            p.validate(value)
        value = f.value(); value["currentSelection"] = {"ignored": True}
        with self.assertRaisesRegex(MuseumError, "evidence shape"):
            p.validate(value)
        value = f.value(); record = list(value["originals"][0]["configRecord"]); record[6] = 0
        record[0] = p._record_hash(f.context["core"], f.context["router"], tuple(record))
        value["originals"][0]["configRecordHash"] = record[0]; value["originals"][0]["configRecord"] = tuple(record)
        with self.assertRaisesRegex(MuseumError, "frozen ONCHAIN"):
            p.validate(value)

    def test_config_record_and_raw_source_commitments_fail_independently(self):
        f = Fixture()
        variants = []
        value = f.value(); value["rows"][0] = (*value["rows"][0][:2], H("wrong config"), *value["rows"][0][3:]); variants.append(value)
        value = f.value(); value["rows"][0] = (*value["rows"][0][:4], H("wrong raw"), *value["rows"][0][5:]); variants.append(value)
        value = f.value(); source = list(value["originals"][0]["rawSource"]); source[2] = "Changed"; value["originals"][0]["rawSource"] = tuple(source); variants.append(value)
        value = f.value(); record = list(value["originals"][0]["configRecord"]); record[1] = H("changed predecessor"); value["originals"][0]["configRecord"] = tuple(record); variants.append(value)
        for value in variants:
            with self.subTest(index=variants.index(value)), self.assertRaises(MuseumError):
                p.validate(value)

    def test_original_denominator_is_exact_and_unique(self):
        f = Fixture()
        for originals in ([], f.originals + copy.deepcopy(f.originals)):
            value = f.value(); value["originals"] = originals
            with self.subTest(count=len(originals)), self.assertRaisesRegex(MuseumError, "original"):
                p.validate(value)
        value = f.value(); value["originals"].append({**copy.deepcopy(f.originals[0]), "configRecordHash": H("extra")})
        with self.assertRaises(MuseumError):
            p.validate(value)

    def test_selection_order_count_and_root_are_exact(self):
        f = Fixture(); value = f.value(); value["rows"].reverse()
        with self.assertRaisesRegex(MuseumError, "selection root"):
            p.validate(value)
        value = f.value(); value["rows"].pop()
        with self.assertRaisesRegex(MuseumError, "complete selection rows"):
            p.validate(value)
        value = f.value(); plan = list(value["plan"]); plan[4] -= 1; value["plan"] = tuple(plan)
        with self.assertRaisesRegex(MuseumError, "stored selection plan"):
            p.validate(value)

    def test_six_expectations_are_required_unique_and_exact(self):
        f = Fixture()
        value = f.value(); value["componentExpectations"].pop()
        with self.assertRaisesRegex(MuseumError, "expectation count|denominator"):
            p.validate(value)
        value = f.value(); value["componentExpectations"][-1] = value["componentExpectations"][0]
        with self.assertRaisesRegex(MuseumError, "duplicate"):
            p.validate(value)
        value = f.value(); row = list(value["componentExpectations"][0]); row[6] = H("wrong data"); value["componentExpectations"][0] = tuple(row)
        with self.assertRaisesRegex(MuseumError, "data hash"):
            p.validate(value)
        value = f.value(); row = list(value["componentExpectations"][0]); row[4] = H("wrong module"); value["componentExpectations"][0] = tuple(row)
        with self.assertRaisesRegex(MuseumError, "source/module identity"):
            p.validate(value)
        value = f.value(); row = list(value["componentExpectations"][0]); row[1] = f.context["router"]; value["componentExpectations"][0] = tuple(row)
        with self.assertRaisesRegex(MuseumError, "source/module identity"):
            p.validate(value)
        value = f.value(); value["context"]["adapters"][0]["runtimeHash"] = H("other adapter")
        with self.assertRaisesRegex(MuseumError, "source/module identity"):
            p.validate(value)

    def test_locked_artist_presentation_is_exactly_joined(self):
        f = Fixture()
        value = f.value(); value["artistPresentation"] = None
        with self.assertRaisesRegex(MuseumError, "presentation missing"):
            p.validate(value)
        value = f.value(); artist = list(value["artistPresentation"]); artist[11] = H("other snapshot"); value["artistPresentation"] = tuple(artist)
        with self.assertRaisesRegex(MuseumError, "locked Artist"):
            p.validate(value)

    def test_source_bindings_and_aggregate_unique_byte_limit_fail_closed(self):
        f = Fixture(); value = f.value(); row = list(value["rows"][0]); sources = list(row[6]); sources[0] = A(99); row[6] = tuple(sources); value["rows"][0] = tuple(row)
        with self.assertRaisesRegex(MuseumError, "source bindings"):
            p.validate(value)
        value = f.value()
        with mock.patch.object(p, "MAX_UNIQUE_SOURCE_BYTES", 1):
            with self.assertRaisesRegex(MuseumError, "byte bound"):
                p.validate(value)
        value = f.value()
        with mock.patch.object(p, "MAX_GETTER_SOURCE_BYTES", 1):
            with self.assertRaisesRegex(MuseumError, "getter byte bound"):
                p.validate(value)

    def test_row_cap_and_collection_scope_are_explicit_support_limits(self):
        f = Fixture(); value = f.value(); auth = list(value["authenticated"]); auth[5] = p.MAX_ROWS + 1; value["authenticated"] = tuple(auth)
        with self.assertRaisesRegex(MuseumError, "authenticated selection"):
            p.validate(value)
        value = f.value(); auth = list(value["authenticated"]); auth[0] = (1, 7, 41, ZERO); value["authenticated"] = tuple(auth)
        with self.assertRaisesRegex(MuseumError, "COLLECTION scope"):
            p.validate(value)

    def test_read_mixin_uses_stored_plan_rows_and_one_frozen_original(self):
        fixture = Fixture(); snapshot, content, statement = fixture.mixin_inputs(); reader = ReadHarness(fixture)
        value = reader._static_components(snapshot, content, statement)
        self.assertEqual(p.validate(value)["uniqueConfigRecords"], "1")
        self.assertEqual(sum(call[1] == "metadataConfigRecord(bytes32)" for call in reader.calls), 1)
        self.assertEqual(sum(call[1] == "staticRenderSourceForConfig(uint256,bytes32)" for call in reader.calls), 1)
        self.assertFalse(any("artistPresentation" in call[1] for call in reader.calls))
        self.assertEqual(value["artistPresentation"], p.json_values(fixture.artist))

    def test_read_mixin_rejects_stored_plan_or_original_drift(self):
        fixture = Fixture(); snapshot, content, statement = fixture.mixin_inputs(); reader = ReadHarness(fixture)
        plan = list(reader.f.plan); plan[2] = H("changed collection state"); reader.f.plan = tuple(plan)
        with self.assertRaisesRegex(MuseumError, "stored checkpoint plan"):
            reader._static_components(snapshot, content, statement)
        fixture = Fixture(); snapshot, content, statement = fixture.mixin_inputs(); reader = ReadHarness(fixture)
        reader.f.source = (*reader.f.source[:2], "changed", *reader.f.source[3:])
        with self.assertRaisesRegex(MuseumError, "original row hashes"):
            reader._static_components(snapshot, content, statement)


if __name__ == "__main__":
    unittest.main()
