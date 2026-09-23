"""Synthetic collection-component and supplied-context controls; no chain evidence."""

import json
import random
import unittest
from unittest.mock import patch

import jsonschema

from . import collection_identity_profile as p


class CollectionIdentityProfileTests(unittest.TestCase):
    def setUp(self):
        self.value = p.examples()["artist-bound.json"]

    def context(self, value=None, **changes):
        value = self.value if value is None else value
        supplied = {"core_identity": (True, int(value["id"]), int(value["serial"]), False),
            "token_id": int(value["catalog_number"]), "collection_name": value["name"],
            "artist_display_line": value["artist"]}
        supplied.update(changes)
        return p.validate_context(value, **supplied)

    def test_exact_generated_canonical_schema_and_worked_examples(self):
        jsonschema.Draft202012Validator.check_schema(p.schema())
        self.assertEqual(p.SCHEMA_HASH, p.digest(p.SCHEMA_BYTES))
        self.assertEqual(p.canonical(json.loads(p.SCHEMA_BYTES)), p.SCHEMA_BYTES)
        self.assertFalse(p.SCHEMA_BYTES.endswith(b"\n"))
        for path, raw in p.outputs().items():
            self.assertEqual((p.ROOT / path).read_bytes(), raw)
        examples = p.examples()
        contexts = examples["worked-contexts.json"]
        self.assertEqual(contexts["status"], "prospective_unregistered")
        self.assertEqual(contexts["sourceObservation"]["revision"], p.SOURCE_REVISION)
        with patch("socket.socket", side_effect=AssertionError("offline component used network")):
            for row in contexts["examples"]:
                value = examples[row["componentFile"]]
                source = row["suppliedContext"]
                core = source["coreIdentity"]
                result = p.validate_context(value, core_identity=(core["mappingExists"],
                    int(core["collectionId"]), int(core["collectionSerial"]), core["burned"]),
                    token_id=int(source["tokenId"]), collection_name=source["typedCollectionName"],
                    artist_display_line=source["derivedArtistDisplayLine"])
                self.assertEqual(result, value)
                self.assertEqual(p.validate_bytes(p.canonical(value), canonical=True), value)

    def test_exact_five_string_members_no_wrapper_or_authority_flags(self):
        for key in p.FIELDS:
            changed = dict(self.value)
            del changed[key]
            with self.subTest(missing=key), self.assertRaises(p.CollectionIdentityError):
                p.validate(changed)
            for wrong in (None, False, 1, [], {}):
                with self.subTest(key=key, wrong=wrong), self.assertRaises(p.CollectionIdentityError):
                    p.validate(self.value | {key: wrong})
        for key in ("verified", "authority", "works_class", "artist_id", "version", "extra"):
            with self.subTest(extra=key), self.assertRaises(p.CollectionIdentityError):
                p.validate(self.value | {key: True})
        with self.assertRaises(p.CollectionIdentityError):
            p.validate({"properties": {"stream": {"collection": self.value}}})

    def test_unsigned_decimal_lexical_and_range_rules_are_in_json_schema(self):
        validator = jsonschema.Draft202012Validator(p.schema())
        invalid = ("", "00", "01", "+1", "-1", " 1", "1 ", "1\n", "1\r\n", "1.0",
            "1e3", "0x10", "１", "١", "NaN", str(p.MAX_UINT256 + 1), "9" * 78, "1" * 79)
        for key in p.NUMERIC_FIELDS:
            for number in invalid:
                changed = self.value | {key: number}
                with self.subTest(key=key, number=number):
                    self.assertFalse(validator.is_valid(changed))
                    with self.assertRaises(p.CollectionIdentityError):
                        p.validate(changed)
            for number in (0, 1, 2**53 - 1, 2**53, 2**53 + 1, p.MAX_UINT256):
                changed = self.value | {key: str(number)}
                self.assertTrue(validator.is_valid(changed))
                self.assertEqual(p.validate(changed)[key], str(number))

    def test_uint256_pattern_agrees_with_integer_range_near_every_decimal_boundary(self):
        validator = jsonschema.Draft202012Validator(p.schema())
        rng = random.Random(6529)
        samples = [rng.randrange(0, 2**257) for _ in range(128)]
        samples += [max(0, 10**power + offset) for power in range(79) for offset in (-1, 0, 1)]
        samples += [p.MAX_UINT256 + offset for offset in range(-10, 11)]
        for value in samples:
            with self.subTest(value=value):
                self.assertEqual(validator.is_valid(self.value | {"catalog_number": str(value)}),
                    0 <= value <= p.MAX_UINT256)

    def test_empty_text_unicode_and_non_normalization_remain_component_data(self):
        for name, artist in (("", ""), ("e\u0301", "é"), ("🖼️", "Artist \"A\"\n\t\x00")):
            changed = self.value | {"name": name, "artist": artist}
            self.assertEqual(p.validate(changed), changed)
            self.assertEqual(self.context(changed), changed)
            self.assertEqual(p.validate_bytes(p.canonical(changed)), changed)
        self.assertNotEqual(p.canonical(self.value | {"name": "e\u0301"}),
            p.canonical(self.value | {"name": "é"}))
        with self.assertRaises(p.CollectionIdentityError):
            p.validate(self.value | {"name": "\ud800"})

    def test_context_compares_every_member_and_preserves_burned_mapping(self):
        self.assertEqual(self.context(), self.value)
        self.assertEqual(self.context(core_identity=(True, 1, 23, True)), self.value)
        for changed in ({"core_identity": (True, 2, 23, False)},
                        {"core_identity": (True, 1, 24, False)}, {"token_id": 124},
                        {"collection_name": "Renamed"}, {"artist_display_line": "Someone else"}):
            with self.subTest(changed=changed), self.assertRaisesRegex(p.CollectionIdentityError, "differs"):
                self.context(**changed)
        large = self.value | {"id": str(2**53 + 1), "serial": str(p.MAX_UINT256),
            "catalog_number": str(p.MAX_UINT256)}
        self.assertEqual(self.context(large), large)

    def test_core_context_requires_exact_tuple_types_and_nonzero_mapped_identity(self):
        for core in ((False, 0, 0, False), (1, 1, 23, False), (True, 1, 23, 0),
                     (True, "1", 23, False), (True, True, 23, False),
                     (True, 1, "23", False), (True, 1, 23), (True, 1, 23, False, 5),
                     (True, 0, 23, False), (True, 1, 0, False),
                     (True, p.MAX_UINT256 + 1, 23, False), {"id": 1}, None):
            with self.subTest(core=core), self.assertRaises(p.CollectionIdentityError):
                self.context(core_identity=core)
        for token in (0, -1, "123", True, None, p.MAX_UINT256 + 1):
            with self.subTest(token=token), self.assertRaises(p.CollectionIdentityError):
                self.context(token_id=token)
        for key in ("collection_name", "artist_display_line"):
            with self.subTest(key=key), self.assertRaises(p.CollectionIdentityError):
                self.context(**{key: None})

    def test_platform_and_degraded_lines_are_explicit_never_inferred(self):
        for filename in ("platform-works-supplied.json", "degraded-supplied.json"):
            value = p.examples()[filename]
            self.assertEqual(self.context(value), value)
            for fabricated in ("Platform works", "attribution_unavailable", "Example Artist"):
                with self.subTest(filename=filename, fabricated=fabricated), self.assertRaises(p.CollectionIdentityError):
                    self.context(value, artist_display_line=fabricated)
        with self.assertRaises(TypeError):
            p.validate_context(self.value, core_identity=(True, 1, 23, False), token_id=123,
                collection_name="Example Collection")

    def test_rendered_json_order_is_accepted_and_canonical_mode_is_explicit(self):
        raw = json.dumps(self.value, ensure_ascii=False, indent=2).encode("utf-8")
        self.assertEqual(p.validate_bytes(raw), self.value)
        with self.assertRaisesRegex(p.CollectionIdentityError, "noncanonical"):
            p.validate_bytes(raw, canonical=True)
        self.assertEqual(p.validate_bytes(p.canonical(self.value), canonical=True), self.value)
        with self.assertRaises(p.CollectionIdentityError):
            p.validate_bytes(raw, canonical=1)

    def test_duplicate_numeric_invalid_unicode_and_malformed_json_reject(self):
        duplicate = p.canonical(self.value)[:-1] + b',"id":"1"}'
        with self.assertRaisesRegex(p.CollectionIdentityError, "duplicate"):
            p.validate_bytes(duplicate)
        for raw in (b'', b'{', b'null', b'[]', b'{"id":1}', b'{"id":1.0}', b'{"id":NaN}',
                    b'{"id":"\xed\xa0\x80"}', p.canonical(self.value) + b' trailing'):
            with self.subTest(raw=raw), self.assertRaises(p.CollectionIdentityError):
                p.validate_bytes(raw)
        with self.assertRaises(p.CollectionIdentityError):
            p.validate_bytes(p.canonical(self.value).decode())

    def test_interpreter_bound_is_exact_and_not_a_per_field_native_limit(self):
        value = self.value | {"name": ""}
        value["name"] = "x" * (p.MAX_COMPONENT_BYTES - len(p.canonical(value)))
        raw = p.canonical(value)
        self.assertEqual(len(raw), p.MAX_COMPONENT_BYTES)
        self.assertEqual(p.validate_bytes(raw), value)
        too_large = value | {"name": value["name"] + "x"}
        # The component schema has no invented native text cap; the interpreter is bounded.
        self.assertTrue(jsonschema.Draft202012Validator(p.schema()).is_valid(too_large))
        with self.assertRaisesRegex(p.CollectionIdentityError, "byte bound"):
            p.validate(too_large)
        with self.assertRaisesRegex(p.CollectionIdentityError, "byte bound"):
            p.validate_bytes(raw + b" ")


if __name__ == "__main__":
    unittest.main()
