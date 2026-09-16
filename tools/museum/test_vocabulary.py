"""Pinned model relation tests; separate from source selection and JSON-LD."""

from pathlib import Path
import copy
import unittest

from .canonical import MuseumError, loads
from .dependencies import OfflineDocuments
from .vocabulary import Vocabulary

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum/standards"
CRM = "http://www.cidoc-crm.org/cidoc-crm/"
DIG = "http://www.ics.forth.gr/isl/CRMdig/"
LA = "https://linked.art/ns/terms/"


class PinnedVocabulary(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = loads((ROOT / "vocabulary-index.json").read_bytes(), maximum=65536)
        cls.documents = OfflineDocuments(ROOT, cls.index)
        cls.policy = loads((ROOT / "vocabulary-policy.json").read_bytes())
        cls.vocabulary = Vocabulary(cls.documents, cls.policy)

    def test_explicit_six_augmentations_preserve_both_sources_independent_of_order(self):
        v = self.vocabulary
        expected = {
            "E8_Acquisition": (CRM + "E7_Activity", LA + "Transfer"),
            "E9_Move": (CRM + "E7_Activity", LA + "Transfer"),
            "E10_Transfer_of_Custody": (CRM + "E7_Activity", LA + "Transfer"),
            "E74_Group": (CRM + "E39_Actor", LA + "Set"),
            "E85_Joining": (CRM + "E7_Activity", LA + "Addition"),
            "E86_Leaving": (CRM + "E7_Activity", LA + "Removal"),
        }
        self.assertEqual(len(self.policy["classAugmentations"]), 6)
        for identifier, parents in expected.items():
            term = v.terms[CRM + identifier]
            self.assertEqual(term.parents, parents)
            self.assertEqual(tuple(d.source_uri for d in term.declarations), (
                "https://cidoc-crm.org/rdfs/7.1.3/CIDOC_CRM_v7.1.3.rdf", "https://linked.art/ns/terms/"))
            for parent in parents:
                self.assertTrue(v.is_subclass(CRM + identifier, parent))
        reversed_policy = copy.deepcopy(self.policy)
        reversed_policy["documents"].reverse()
        reversed_policy["classAugmentations"].reverse()
        for rule in reversed_policy["classAugmentations"]:
            rule["declarations"].reverse()
        self.assertEqual(v.terms, Vocabulary(self.documents, reversed_policy).terms)

    def test_unapproved_or_changed_duplicate_source_and_parent_fail_closed(self):
        for index in range(6):
            p = copy.deepcopy(self.policy)
            p["classAugmentations"][index]["declarations"][0]["parents"] = [CRM + "E53_Place"]
            with self.subTest(index=index), self.assertRaises(MuseumError):
                Vocabulary(self.documents, p)
        for mutation in ("absent", "unused", "source_hash", "duplicate_source", "source_identity"):
            p = copy.deepcopy(self.policy)
            if mutation == "absent":
                p["classAugmentations"].pop()
            elif mutation == "unused":
                p["classAugmentations"].append(dict(p["classAugmentations"][0], identifier="urn:unused"))
            elif mutation == "source_hash":
                p["documents"][0]["sha256"] = "0x" + "00" * 32
            elif mutation == "duplicate_source":
                p["documents"].append(p["documents"][0])
            else:
                p["classAugmentations"][0]["declarations"][0]["sourceUri"] = "urn:foreign"
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                Vocabulary(self.documents, p)

    def test_official_version_and_three_byte_pins(self):
        raw = self.documents.load("https://cidoc-crm.org/rdfs/7.1.3/CIDOC_CRM_v7.1.3.rdf")
        self.assertIn(b"RDFs Implementation (February 2024) of CIDOC-CRM 7.1.3", raw)
        self.assertIn(b"CC BY 4.0", raw)
        self.assertEqual(len(self.index["documents"]), 3)
        self.assertEqual(sum(len(r["chunks"]) for r in self.index["documents"]), 58)

    def test_physical_and_digital_carriers_remain_distinct(self):
        v = self.vocabulary
        v.require_relation(CRM + "E22_Human-Made_Object", CRM + "P65_shows_visual_item", CRM + "E36_Visual_Item")
        v.require_relation(DIG + "D1_Digital_Object", LA + "digitally_shows", CRM + "E36_Visual_Item")
        with self.assertRaises(MuseumError):
            v.require_relation(DIG + "D1_Digital_Object", CRM + "P65_shows_visual_item", CRM + "E36_Visual_Item")
        with self.assertRaises(MuseumError):
            v.require_relation(CRM + "E22_Human-Made_Object", LA + "digitally_shows", CRM + "E36_Visual_Item")

    def test_sound_information_is_not_visual_or_linguistic_content(self):
        v = self.vocabulary
        self.assertFalse(v.is_subclass(CRM + "E73_Information_Object", CRM + "E36_Visual_Item"))
        self.assertFalse(v.is_subclass(CRM + "E73_Information_Object", CRM + "E33_Linguistic_Object"))
        with self.assertRaises(MuseumError):
            v.require_relation(DIG + "D1_Digital_Object", LA + "digitally_shows", CRM + "E73_Information_Object")

    def test_creation_and_production_are_not_interchangeable(self):
        v = self.vocabulary
        v.require_relation(DIG + "D1_Digital_Object", CRM + "P94i_was_created_by", CRM + "E65_Creation")
        v.require_relation(CRM + "E22_Human-Made_Object", CRM + "P108i_was_produced_by", CRM + "E12_Production")
        with self.assertRaises(MuseumError):
            v.require_relation(DIG + "D1_Digital_Object", CRM + "P108i_was_produced_by", CRM + "E12_Production")

    def test_event_location_and_depiction_use_different_domains(self):
        v = self.vocabulary
        v.require_relation(CRM + "E7_Activity", CRM + "P7_took_place_at", CRM + "E53_Place")
        v.require_relation(CRM + "E36_Visual_Item", CRM + "P138_represents", CRM + "E53_Place")
        with self.assertRaises(MuseumError):
            v.require_relation(CRM + "E36_Visual_Item", CRM + "P7_took_place_at", CRM + "E53_Place")


if __name__ == "__main__":
    unittest.main()
