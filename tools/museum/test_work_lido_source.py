"""Whole typed-WORK inventory, before LIDO mapping or publication claims."""

import copy
import unittest
from unittest.mock import patch

from tools.metadata import work_profile as work
from .canonical import MuseumError, loads as _loads
from .work_lido_source import load_work_source, WORK_PROFILE_HASH, MAX_INVENTORY_BYTES


def loads(raw):
    return _loads(raw, maximum=MAX_INVENTORY_BYTES, canonical=True)


class WorkLidoSourceTests(unittest.TestCase):
    def setUp(self):
        self.simple, self.absent, self.complete, self.catalog = work.examples()
        for value in (self.simple, self.absent, self.complete):
            value["profileHash"] = WORK_PROFILE_HASH

    def source(self, value, catalog=None):
        return load_work_source(work.canonical(value), expected_subject_id=value["subjectId"],
                                catalog=None if catalog is None else work.canonical(catalog))

    def test_all_original_bytes_are_retained_and_only_applicable_fields_count(self):
        source = self.source(self.simple)
        self.assertEqual(source.payload, work.canonical(self.simple))
        fields = loads(source.inventory)["fields"]
        by_path = {x["pointer"]: x for x in fields}
        self.assertEqual(by_path["/inscription"]["presence"], "absent")
        self.assertNotIn("/absence", by_path)
        self.assertNotIn("/creator/artistId", by_path)
        self.assertEqual(by_path["/creator/name"]["exactHex"], "0x" + b'"Declared creator"'.hex())
        self.assertEqual(by_path["/alternateTitles"]["exactHex"], "0x" + b'"0"'.hex())

    def test_absence_has_no_manufactured_full_title_creator_or_catalog(self):
        source = self.source(self.absent)
        by_path = {x["pointer"]: x for x in loads(source.inventory)["fields"]}
        self.assertNotIn("/title", by_path)
        self.assertNotIn("/creator", by_path)
        self.assertEqual(by_path["/absence/reason"]["exactHex"], "0x" + work.canonical(self.absent["absence"]["reason"]).hex())

    def test_every_actual_leaf_in_complete_work_and_catalog_has_exact_inventory(self):
        source = self.source(self.complete, self.catalog)
        rows = {(r["source"], r["pointer"]): r for r in loads(source.inventory)["fields"]}
        def visit(value, name, pointer=""):
            self.assertIn((name, pointer), rows)
            if isinstance(value, dict):
                for k, v in value.items(): visit(v, name, pointer + "/" + k)
            elif isinstance(value, list):
                for i, v in enumerate(value): visit(v, name, pointer + "/" + str(i))
            else:
                self.assertEqual(rows[name, pointer]["exactHex"], "0x" + work.canonical(value).hex())
        visit(self.complete, "work"); visit(self.catalog, "catalog")
        self.assertIn(("catalog", "/entries/0/mapping/puid"), rows)
        self.assertEqual(source.catalog, work.canonical(self.catalog))

    def test_measurement_branch_evidence_preserves_all_three_present_checks(self):
        inventory = loads(self.source(self.complete, self.catalog).inventory)
        any_of = [r for r in inventory["branches"] if r["pointer"] == "/measurements" and r["keyword"] == "anyOf"]
        self.assertEqual(len(any_of), 1)
        self.assertEqual(len(any_of[0]["applicable"]), 3)
        self.assertTrue(all(p.startswith("#/oneOf/0/properties/measurements/oneOf/1/anyOf/") for p in any_of[0]["applicable"]))

    def test_duplicate_array_values_retain_separate_positions(self):
        fields = loads(self.source(self.complete, self.catalog).inventory)["fields"]
        rows = {r["pointer"]: r for r in fields if r["source"] == "work"}
        self.assertEqual(rows["/alternateTitles/0"]["exactHex"], rows["/alternateTitles/1"]["exactHex"])
        self.assertNotEqual(rows["/alternateTitles/0"]["pointer"], rows["/alternateTitles/1"]["pointer"])

    def test_invalid_whole_work_and_stale_catalog_reject_before_inventory(self):
        v = copy.deepcopy(self.complete); v["edition"]["number"] = "0"
        with self.assertRaises(MuseumError): self.source(v, self.catalog)
        cat = copy.deepcopy(self.catalog); cat["entries"][0]["mapping"]["puid"] = "fmt/200"
        with self.assertRaises(MuseumError): self.source(self.complete, cat)

    def test_wrong_profile_subject_and_changed_definition_never_promote(self):
        v = copy.deepcopy(self.simple); v["profileHash"] = "0x" + "1" * 64
        with self.assertRaises(MuseumError): self.source(v)
        with self.assertRaises(MuseumError):
            load_work_source(work.canonical(self.simple), expected_subject_id="0x" + "1" * 64)
        with patch.object(work, "profile", return_value={"name": "changed"}):
            with self.assertRaises(MuseumError): self.source(self.simple)

    def test_control_and_large_numbers_remain_exact_before_xml_admission(self):
        source = self.source(self.complete, self.catalog)
        rows = {r["pointer"]: r for r in loads(source.inventory)["fields"] if r["source"] == "work"}
        self.assertEqual(rows["/title"]["exactHex"], "0x" + work.canonical(self.complete["title"]).hex())
        self.assertEqual(rows["/edition/total"]["exactHex"], "0x" + ('"' + str((1 << 256) - 1) + '"').encode().hex())
        self.assertFalse(loads(source.inventory)["claims"]["actualRecordAuthority"])


if __name__ == "__main__":
    unittest.main()
