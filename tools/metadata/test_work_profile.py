"""Independent full-object, lexical and cross-field WORK profile regressions."""

import copy
import json
import unittest

import jsonschema
from . import work_profile as w


class WorkProfileTests(unittest.TestCase):
    def setUp(self):
        self.simple, self.absent, self.complete, self.catalog = w.examples()

    def check(self, value, catalog=None):
        return w.validate_payload(w.canonical(value), catalog_bytes=None if catalog is None else w.canonical(catalog))

    def rejects(self, value, catalog=None):
        with self.assertRaises(w.WorkError):
            self.check(value, catalog)

    def test_complete_definitions_are_valid_closed_schema_and_exact_outputs(self):
        jsonschema.Draft202012Validator.check_schema(w.schema())
        jsonschema.Draft202012Validator.check_schema(w.catalog_schema())
        for name, value in w.outputs().items():
            self.assertEqual((w.ROOT / name).read_bytes(), w.canonical(value))
        self.check(self.simple)
        self.check(self.absent)
        self.check(self.complete, self.catalog)

    def test_literal_jcs_escaping_control_astral_and_non_normalization(self):
        s = copy.deepcopy(self.simple)
        s["title"] = '"/\\\n\x01🎨e\u0301'
        raw = w.canonical(s)
        self.assertIn(b'"title":"\\"/\\\\\\n\\u0001\xf0\x9f\x8e\xa8e\xcc\x81"', raw)
        self.assertEqual(self.check(s)["title"], s["title"])
        s["title"] = '"/\\\n\x01🎨é'
        self.assertNotEqual(w.canonical(s), raw)

    def test_unknown_missing_duplicate_and_noncanonical_objects(self):
        for key in self.simple:
            v = copy.deepcopy(self.simple); del v[key]; self.rejects(v)
        v = copy.deepcopy(self.simple); v["ignored"] = "anything"; self.rejects(v)
        for raw in [b'{"version":1,"version":1}', w.canonical(self.simple) + b" ", b" " + w.canonical(self.simple),
                    b'\xef\xbb\xbf' + w.canonical(self.simple), b'{}', b'[]', b'{"version":NaN}', b'{"version":1.0}']:
            with self.assertRaises(w.WorkError): w.validate_payload(raw)

    def test_explicit_absence_never_mixes_full_or_defaults_reason_date(self):
        for key in ["title", "medium", "creator", "measurements", "inscription", "languageVariants"]:
            v = copy.deepcopy(self.absent); v[key] = self.simple.get(key, "x"); self.rejects(v)
        for key in ["reason", "date"]:
            v = copy.deepcopy(self.absent); del v["absence"][key]; self.rejects(v)
        v = copy.deepcopy(self.absent); v["absence"]["reason"] = ""; self.rejects(v)
        v = copy.deepcopy(self.simple); v["absence"] = self.absent["absence"]; self.rejects(v)

    def test_zero_hashes_uppercase_and_newline_hash_are_not_aliases(self):
        for key in ["subjectId", "profileHash", "predecessor"]:
            for wrong in [w.ZERO, "0x" + "A" * 64, "0x" + "1" * 64 + "\n"]:
                v = copy.deepcopy(self.simple); v[key] = wrong; self.rejects(v)

    def test_creator_named_and_exact_registry_association_are_distinct(self):
        for bad in [{"kind": "named", "name": ""}, {"kind": "named", "name": "n", "artistId": "0x" + "1" * 64},
                    {"kind": "artist", "artistId": "0x" + "1" * 64},
                    {**self.complete["creator"], "name": "ignored"}]:
            v = copy.deepcopy(self.simple); v["creator"] = bad; self.rejects(v)
        for word in ["0", "01", str(1 << 64), "1\n"]:
            v = copy.deepcopy(self.complete); v["creator"]["association"]["bindingGeneration"] = word; self.rejects(v, self.catalog)

    def test_gregorian_leap_days_exact_endpoints_and_range_order(self):
        for date in ["0000-01-01", "1900-02-29", "2023-02-29", "2026-04-31", "2026-13-01", "2026-09-12\n", "2026", "~2026-01-01"]:
            v = copy.deepcopy(self.simple); v["creation"]["date"] = date; self.rejects(v)
        for date in ["0001-01-01", "2000-02-29", "9999-12-31"]:
            v = copy.deepcopy(self.simple); v["creation"]["date"] = date; self.check(v)
        v = copy.deepcopy(self.simple); v["creation"] = {"kind": "range", "start": "2026-09-12", "end": "2026-09-11"}; self.rejects(v)
        v["creation"]["end"] = "2026-09-12"; self.check(v)
        v["creation"]["end"] = None; self.rejects(v)

    def test_all_seven_measurement_combinations_preserve_units(self):
        for mask in range(1, 8):
            v = copy.deepcopy(self.simple); v["measurements"] = {"kind": "measured"}
            for bit, key in [(1, "pixels"), (2, "aspectRatio"), (4, "durationSeconds")]:
                if mask & bit: v["measurements"][key] = self.complete["measurements"][key]
            self.check(v)
        v["measurements"] = {"kind": "measured"}; self.rejects(v)
        v["measurements"] = {"kind": "dimensionless_generative", "pixels": self.complete["measurements"]["pixels"]}; self.rejects(v)
        v["measurements"] = {"kind": "measured", "pixels": {"width": "1", "height": "1", "unit": "cm"}}; self.rejects(v)

    def test_rationals_and_serial_keep_uint256_without_reduction(self):
        v = copy.deepcopy(self.complete)
        self.check(v, self.catalog)
        self.assertEqual(v["measurements"]["aspectRatio"], {"numerator": "2", "denominator": "4"})
        for wrong in ["0", "01", "-1", "1.0", "1e3", str(1 << 256), "1\n", 1, True]:
            v = copy.deepcopy(self.complete); v["measurements"]["durationSeconds"]["denominator"] = wrong; self.rejects(v, self.catalog)
        v = copy.deepcopy(self.complete); v["edition"]["number"] = v["edition"]["total"]; self.check(v, self.catalog)
        v["edition"]["total"] = "1"; self.rejects(v, self.catalog)

    def test_unique_and_open_series_have_no_inactive_serial_values(self):
        v = copy.deepcopy(self.simple); v["edition"] = {"kind": "open_series", "statement": "Authored ongoing series"}; self.check(v)
        for wrong in [{"kind": "open_series", "statement": ""}, {"kind": "unique", "number": "0"},
                      {"kind": "serial", "number": "1", "total": "2", "statement": "ignored"}]:
            v["edition"] = wrong; self.rejects(v)

    def test_pronom_literal_keccak_derivation_and_lexical_profiles(self):
        for puid in ["fmt/199", "x-fmt/1"]:
            v = copy.deepcopy(self.simple); v["format"] = {"kind": "pronom", "puid": puid, "formatId": w.digest(("PRONOM:" + puid).encode())}; self.check(v)
            v["format"]["formatId"] = "0x" + "1" * 64; self.rejects(v)
        for puid in ["fmt/0", "fmt/01", "FMT/1", "fmt/1\n", "video/mp4"]:
            v["format"] = {"kind": "pronom", "puid": puid, "formatId": w.digest(("PRONOM:" + puid).encode())}; self.rejects(v)

    def test_complete_catalog_required_with_actual_selected_mapping(self):
        self.rejects(self.complete)
        self.rejects(self.simple, self.catalog)
        self.rejects(self.absent, self.catalog)
        for key in ["documentHash", "documentId"]:
            v = copy.deepcopy(self.complete); v["format"]["catalog"][key] = "0x" + "1" * 64; self.rejects(v, self.catalog)
        v = copy.deepcopy(self.complete); v["format"]["mapping"] = self.catalog["entries"][0]["mapping"]; self.rejects(v, self.catalog)
        v["format"]["formatId"] = self.catalog["entries"][0]["entryId"]; self.check(v, self.catalog)

    def test_unselected_catalog_change_requires_new_whole_document_commitment(self):
        cat = copy.deepcopy(self.catalog); cat["entries"][0]["mapping"]["puid"] = "fmt/200"
        self.rejects(self.complete, cat)
        v = copy.deepcopy(self.complete); v["format"]["catalog"]["documentHash"] = w.digest(w.canonical(cat)); self.check(v, cat)
        self.assertNotEqual(w.canonical(v), w.canonical(self.complete))

    def test_rehashed_catalog_duplicate_missing_and_invalid_unselected_reject(self):
        for mode in ["duplicate", "missing", "invalid_unselected", "extra_entry_field"]:
            cat = copy.deepcopy(self.catalog)
            if mode == "duplicate": cat["entries"][0]["entryId"] = cat["entries"][1]["entryId"]
            if mode == "missing": cat["entries"].pop()
            if mode == "invalid_unselected": cat["entries"][0]["mapping"]["puid"] = "fmt/01"
            if mode == "extra_entry_field": cat["entries"][0]["opaque"] = "ignored"
            v = copy.deepcopy(self.complete); v["format"]["catalog"]["documentHash"] = w.digest(w.canonical(cat)); self.rejects(v, cat)

    def test_catalog_uri_policy_matches_pinned_content_reader_without_fetching(self):
        for uri in ["ipfs://exact-é", "ar://x", "https://example.org/p?a=b", 'ipfs://literal"quote']:
            cat = copy.deepcopy(self.catalog); cat["entries"][1]["mapping"]["specification"]["uri"] = uri
            v = copy.deepcopy(self.complete); v["format"]["mapping"] = cat["entries"][1]["mapping"]
            v["format"]["catalog"]["documentHash"] = w.digest(w.canonical(cat)); self.check(v, cat)
        for uri in ["https:///x", "https://?x", "https://#x", "https://", "ipfs://", "ar://", "https://x\n", "http://example.org"]:
            cat = copy.deepcopy(self.catalog); cat["entries"][1]["mapping"]["specification"]["uri"] = uri
            v = copy.deepcopy(self.complete); v["format"]["mapping"] = cat["entries"][1]["mapping"]
            v["format"]["catalog"]["documentHash"] = w.digest(w.canonical(cat)); self.rejects(v, cat)

    def test_languages_preserve_case_and_supported_targets_only(self):
        for tag in ["fr", "und", "FR", "en-Latn", "sr-Latn-RS", "es-419", "en-Latn-001"]:
            v = copy.deepcopy(self.simple); v["languageVariants"] = [{"field": "creatorName", "language": tag, "value": "Exact translation"}]
            self.assertEqual(self.check(v)["languageVariants"][0]["language"], tag)
        for tag in ["", "en\n", "en_US", "english", "en-x-private", "en-Latn-1234", "a", "123"]:
            v["languageVariants"][0]["language"] = tag; self.rejects(v)
        v["languageVariants"][0]["language"] = "en"; v["languageVariants"][0]["field"] = "inscription"; self.rejects(v)
        v = copy.deepcopy(self.complete); v["languageVariants"][0]["field"] = "creatorName"; self.rejects(v, self.catalog)

    def test_optional_array_order_duplicates_indices_and_omissions_are_observable(self):
        v = copy.deepcopy(self.complete); self.check(v, self.catalog)
        self.assertEqual(v["alternateTitles"], ["Titre", "Titre"])
        v["authorityReferences"].reverse(); self.check(v, self.catalog)
        self.assertNotEqual(w.canonical(v), w.canonical(self.complete))
        v["languageVariants"][-1]["alternateTitleIndex"] = "2"; self.rejects(v, self.catalog)
        v = copy.deepcopy(self.simple); v["inscription"] = ""; self.rejects(v)
        for key, n in [("alternateTitles", 9), ("authorityReferences", 17), ("languageVariants", 9)]:
            v = copy.deepcopy(self.complete); v[key] = [copy.deepcopy(v[key][0]) for _ in range(n)]; self.rejects(v, self.catalog)

    def test_authority_id_grammars_and_roles_are_literal_not_uri_aliases(self):
        for index, wrong in [(0, "0500115588"), (1, "012"), (2, "q42"), (2, "Q042"), (2, "Q42\n"), (3, "https://vocab.getty.edu/aat/300264849")]:
            v = copy.deepcopy(self.complete); v["authorityReferences"][index]["identifier"] = wrong; self.rejects(v, self.catalog)
        for index, role in [(0, "medium"), (3, "creator")]:
            v = copy.deepcopy(self.complete); v["authorityReferences"][index]["role"] = role; self.rejects(v, self.catalog)

    def test_utf8_byte_limit_is_not_character_count(self):
        v = copy.deepcopy(self.simple); v["title"] = "é" * 256; self.check(v)
        v["title"] += "é"; self.rejects(v)
        with self.assertRaises(w.WorkError):
            w.validate_payload(w.canonical(self.simple).replace(b'"Exact work title"', b'"\\ud800"'))

    def test_encoded_8192_boundary_then_single_byte_overflow(self):
        v = copy.deepcopy(self.simple)
        v["languageVariants"] = [{"field": "title", "language": "en", "value": "x" * 800} for _ in range(8)]
        length = len(w.canonical(v)); self.assertGreater(length, 7000); self.assertLess(length, 8192)
        v["creditLine"] = "x" * (len(v["creditLine"]) + 8192 - length)
        self.assertEqual(len(w.canonical(v)), 8192); self.check(v)
        v["creditLine"] += "x"; self.rejects(v)


if __name__ == "__main__":
    unittest.main()
