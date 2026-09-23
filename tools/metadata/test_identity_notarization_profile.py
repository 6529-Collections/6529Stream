import copy
import json
import unittest

from tools.metadata import identity_notarization_profile as p


class IdentityNotarizationProfileTest(unittest.TestCase):
    def setUp(self):
        self.value = p.example()

    def valid(self, value=None, **context):
        value = self.value if value is None else value
        return p.validate(
            p.canonical(value),
            artist_id=context.get("artist_id", self.value["artistId"]),
            operative_identity_record_hash=context.get(
                "operative_identity_record_hash", self.value["operativeIdentityRecordHash"]
            ),
        )

    def bad(self, value=None, **context):
        with self.assertRaises(p.NotarizationError):
            self.valid(value, **context)

    def test_generated_schema_profile_and_complete_example_match(self):
        self.assertEqual(self.valid(), self.value)
        for path, raw in p.outputs().items():
            self.assertEqual((p.ROOT / path).read_bytes(), raw)
        self.assertEqual(p.SCHEMA_HASH, p.digest(p.SCHEMA_BYTES))
        self.assertEqual(p.PROFILE_HASH, p.digest(p.PROFILE_BYTES))

    def test_closed_required_fields_and_no_authority_markers(self):
        for key in self.value:
            changed = copy.deepcopy(self.value)
            del changed[key]
            self.bad(changed)
        for key in ("authority", "reviewer", "standing", "verified", "legalPerson"):
            changed = copy.deepcopy(self.value)
            changed[key] = True
            self.bad(changed)

    def test_exact_profile_artist_and_operative_identity_context(self):
        changed = copy.deepcopy(self.value)
        changed["profileHash"] = "0x" + "77" * 32
        self.bad(changed)
        self.bad(artist_id="0x" + "88" * 32)
        self.bad(operative_identity_record_hash="0x" + "99" * 32)
        for supplied in (p.ZERO, "0x" + "AA" * 32, 1, True, None):
            self.bad(artist_id=supplied)

    def test_all_six_hash_algorithms_and_exact_digest_shapes(self):
        field = "legalPersonRef"
        for algorithm in (1, 2, 3, 4, 5, 6):
            sizes = (1, 32, 128) if algorithm in (4, 5) else (32,)
            for size in sizes:
                changed = copy.deepcopy(self.value)
                changed[field]["hash"].update(algorithm=algorithm, digest="0x" + "00" * size)
                self.valid(changed)
            rejected = (0, 129) if algorithm in (4, 5) else (0, 31, 33, 128)
            for size in rejected:
                changed = copy.deepcopy(self.value)
                changed[field]["hash"].update(algorithm=algorithm, digest="0x" + "01" * size)
                self.bad(changed)
        for algorithm in (0, 7, 65535, "1", True):
            changed = copy.deepcopy(self.value)
            changed[field]["hash"]["algorithm"] = algorithm
            self.bad(changed)

    def test_every_reference_is_closed_and_uses_exact_content_uri(self):
        fields = (
            "legalPersonRef",
            "instrumentRef",
            "officiatingAuthorityIdentityRef",
            "verifyingInstitutionIdentityRef",
        )
        for field in fields:
            for uri in ("https://example.org/evidence", "ipfs://opaque", "ar://opaque"):
                changed = copy.deepcopy(self.value)
                changed[field]["uri"] = uri
                self.valid(changed)
            for uri in (
                "https://",
                "https:///bad",
                "https://?bad",
                "https://#bad",
                "http://example.org",
                "ipfs://",
                "ar://x\n",
            ):
                changed = copy.deepcopy(self.value)
                changed[field]["uri"] = uri
                self.bad(changed)
            changed = copy.deepcopy(self.value)
            changed[field]["claim"] = "verified"
            self.bad(changed)

    def test_hash_lexicals_nonzero_canonicalization_and_reference_caps(self):
        for key in ("canonicalizationId", "digest"):
            for invalid in ("0X" + "01" * 32, "0x" + "AB" * 32, "0x1"):
                changed = copy.deepcopy(self.value)
                changed["instrumentRef"]["hash"][key] = invalid
                self.bad(changed)
        changed = copy.deepcopy(self.value)
        changed["instrumentRef"]["hash"]["canonicalizationId"] = p.ZERO
        self.bad(changed)
        changed = copy.deepcopy(self.value)
        changed["instrumentRef"]["uri"] = "https://x/" + "🎨" * 511
        self.bad(changed)

    def test_duplicate_keys_invalid_unicode_numbers_and_noncanonical_bytes_reject(self):
        raw = p.canonical(self.value)
        duplicate = raw[:-1] + b',"version":1}'
        with self.assertRaises(p.NotarizationError):
            p.validate(
                duplicate,
                artist_id=self.value["artistId"],
                operative_identity_record_hash=self.value["operativeIdentityRecordHash"],
            )
        for raw in (
            json.dumps(self.value, indent=2).encode(),
            b'{"version":1.0}',
            b'{"version":NaN}',
            b'{"version":"\xed\xa0\x80"}',
        ):
            with self.assertRaises(p.NotarizationError):
                p.validate(
                    raw,
                    artist_id=self.value["artistId"],
                    operative_identity_record_hash=self.value["operativeIdentityRecordHash"],
                )

    def test_exact_complete_payload_bound(self):
        changed = copy.deepcopy(self.value)
        for field in (
            "legalPersonRef",
            "instrumentRef",
            "officiatingAuthorityIdentityRef",
            "verifyingInstitutionIdentityRef",
        ):
            remaining = p.MAX_PAYLOAD_BYTES - len(p.canonical(changed))
            capacity = 2048 - len(changed[field]["uri"].encode())
            changed[field]["uri"] += "a" * min(remaining, capacity)
        raw = p.canonical(changed)
        self.assertEqual(len(raw), p.MAX_PAYLOAD_BYTES)
        self.valid(changed)
        oversized = raw + b" "
        with self.assertRaises(p.NotarizationError):
            p.validate(
                oversized,
                artist_id=self.value["artistId"],
                operative_identity_record_hash=self.value["operativeIdentityRecordHash"],
            )


if __name__ == "__main__":
    unittest.main()
