"""Independent closed-profile controls against an actual local-EVM snapshot artifact."""

import copy
import json
import unittest

from . import snapshot_profile as profile


class SnapshotProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = (profile.ROOT / "test/fixtures/metadata/snapshot-native-onchain.json").read_bytes()
        cls.value = json.loads(cls.raw)

    def mutated(self, change):
        value = copy.deepcopy(self.value)
        change(value)
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()

    def reject(self, change):
        with self.assertRaises(Exception):
            profile.validate(self.mutated(change))

    def test_actual_retained_canonical_document(self):
        value = profile.validate(self.raw)
        self.assertEqual(value["metadata"]["name"], "Artwork")
        self.assertEqual(value["script"]["content"], "draw();")
        self.assertEqual(value["entropy"]["policyCount"], "2")
        self.assertEqual(value["contentRoot"]["leafCount"], "2")

    def test_definition_generation_is_byte_exact(self):
        for path, raw in profile.generated().items():
            self.assertEqual((profile.ROOT / path).read_bytes(), raw, path)

    def test_unknown_missing_and_duplicate_keys_rejected(self):
        self.reject(lambda v: v.update(authority=True))
        self.reject(lambda v: v.pop("publication"))
        with self.assertRaises(ValueError):
            profile.validate(b'{"version":1,' + self.raw[1:])

    def test_whitespace_order_and_boolean_version_rejected(self):
        for raw in (self.raw + b"\n", b" " + self.raw, json.dumps(self.value).encode()):
            with self.assertRaises(ValueError):
                profile.validate(raw)
        self.reject(lambda v: v.update(version=True))

    def test_exact_schema_and_profile_pins(self):
        for field in ("schemaId", "schemaHash", "profileHash"):
            self.reject(lambda v, field=field: v.update({field: "0x" + "01" * 32}))

    def test_script_hash_length_and_empty_source_rejected(self):
        self.reject(lambda v: v["script"].update(content="draw(1);"))
        self.reject(lambda v: v["script"].update(byteLength="8"))
        self.reject(lambda v: v["script"].update(content=""))

    def test_text_bounds_count_utf8_bytes(self):
        self.reject(lambda v: v["metadata"].update(name="é" * 129))
        self.reject(lambda v: v["metadata"].update(description="x" * 2049))
        raw = self.mutated(lambda v: v["metadata"].update(name="é" * 128))
        self.assertEqual(profile.validate(raw)["metadata"]["name"], "é" * 128)

    def test_exact_uint_widths_no_rounding_and_no_newline(self):
        for text in ("01", "1\n", str(1 << 256), "1.0", "1e2", "-1"):
            self.reject(lambda v, text=text: v.update(collectionId=text))
        self.reject(lambda v: v["publication"].update(revision=str(1 << 64)))
        self.reject(lambda v: v["entropy"]["policies"][0].update(epoch=str(1 << 32)))

    def test_no_implicit_waiver_or_authority_from_empty_values(self):
        self.reject(lambda v: v["publication"].update(authorizationClass="1"))
        self.reject(lambda v: v["publication"].update(displayAuthorizationClass="8", displayGrantRevision="0"))
        self.reject(lambda v: v["metadata"]["artist"].update(acceptedAt="0"))
        self.reject(lambda v: v["metadata"]["locks"].update(script=False))

    def test_every_original_policy_and_order_retained(self):
        self.reject(lambda v: v["entropy"]["policies"].pop())
        self.reject(lambda v: v["entropy"]["policies"].reverse())
        self.reject(lambda v: v["entropy"]["policies"][1].update(coordinator=v["entropy"]["policies"][0]["coordinator"]))
        self.reject(lambda v: v["entropy"]["policies"][1].update(frozen=False))

    def test_fixed_sources_and_checkpoint_correspondence(self):
        self.reject(lambda v: v["sources"].reverse())
        self.reject(lambda v: v["contentRoot"]["checkpoint"].update(tokenCount="1"))
        self.reject(lambda v: v["contentRoot"]["checkpoint"].update(contentRoot="0x" + "01" * 32))

    def test_malformed_utf8_and_transport_bound(self):
        with self.assertRaises(ValueError):
            profile.validate(b"\xff")
        with self.assertRaises(ValueError):
            profile.validate(self.raw + b" " * 524288)

    def test_collection_subject_binds_declared_chain_core_and_collection(self):
        self.reject(lambda v: v.update(subject="0x" + "00" * 32))
        self.reject(lambda v: v.update(chainId=str(int(v["chainId"]) + 1)))
        self.reject(lambda v: v.update(collectionId="2"))
        self.reject(lambda v: v["sources"][0].update(address="0x" + "12" * 20))

    def test_explicit_nonzero_source_requirements(self):
        self.reject(lambda v: v["entropy"]["policies"][0].update(epoch="0"))
        cases = [
            (("sources", 4), "runtimeHash", 32),
            (("sources", 5), "address", 20),
            (("metadata", "artist"), "acceptanceRecordHash", 32),
            (("metadata", "artist"), "nominatedArtist", 20),
            (("renderer",), "runtimeHash", 32),
            (("contentRoot",), "artistConsent", 32),
            (("contentRoot", "checkpoint"), "inventoryHash", 32),
            (("contentRoot", "leafManifest"), "coverageHash", 32),
            (("publication",), "reasonHash", 32),
            (("entropy", "policies", 0), "provider", 20),
            (("entropy", "policies", 0), "moduleSchemaHash", 32),
            (("entropy", "policies", 0), "salt", 32),
        ]
        for path, field, width in cases:
            with self.subTest(path=path, field=field):
                def change(value):
                    for key in path:
                        value = value[key]
                    value[field] = "0x" + "00" * width
                self.reject(change)

    def test_zero_predecessors_index_and_optional_publication_uri_preserved(self):
        def change(value):
            value["publication"]["predecessor"] = "0x" + "00" * 32
            value["publication"]["manifestURI"] = ""
            value["contentRoot"]["predecessor"] = "0x" + "00" * 32
            value["contentRoot"]["manifestURI"] = ""
        value = profile.validate(self.mutated(change))
        self.assertEqual(value["entropy"]["policies"][0]["firstTokenIndex"], "0")
        self.assertEqual(value["publication"]["manifestURI"], "")
        self.assertEqual(value["contentRoot"]["manifestURI"], "")


if __name__ == "__main__":
    unittest.main()
