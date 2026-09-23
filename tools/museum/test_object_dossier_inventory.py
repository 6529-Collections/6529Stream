"""Closed denominator and typed-evidence tests for object-dossier requirements."""
from pathlib import Path
import unittest

from .canonical import MuseumError, dumps
from .object_dossier_inventory import (QUALIFICATION, REQUIREMENTS, REQUIREMENTS_BYTES,
    REQUIREMENTS_HASH, EvidenceRef, assess)

ROOT = Path(__file__).resolve().parents[2]
SCRIPT_ONLY = {"OD-SCRIPT-MANIFEST", "OD-SCRIPT-DRILL"}


def ref(code, number=1):
    digest = "0x" + number.to_bytes(32, "big").hex()
    return EvidenceRef("adapter:object-dossier-v1", digest, "/" + code)


def all_verified(*, omit=()):
    omitted = set(omit)
    return {row["code"]: (ref(row["code"], index + 1),)
        for index, row in enumerate(REQUIREMENTS) if row["code"] not in omitted}


class ObjectDossierInventoryTests(unittest.TestCase):
    def test_canonical_requirements_file_retains_the_complete_fixed_inventory(self):
        path = ROOT / "schemas/museum/object-dossier/requirements.json"
        self.assertEqual(path.read_bytes(), REQUIREMENTS_BYTES)
        value = __import__("tools.museum.canonical", fromlist=["loads"]).loads(
            REQUIREMENTS_BYTES, maximum=524288, canonical=True)
        self.assertEqual(value["requirements"], list(REQUIREMENTS))
        self.assertEqual(len(REQUIREMENTS), 49)
        self.assertEqual(len({row["code"] for row in REQUIREMENTS}), 49)
        self.assertEqual({row["code"] for row in REQUIREMENTS if row["applicability"] == "script"},
            SCRIPT_ONLY)
        required = {"identity", "OD-CONTENT-ROOT-PROOF", "OD-ENTROPY-PROVENANCE",
            "OD-DEPENDENCY-MANIFEST", "OD-MEDIA-MANIFEST", "OD-ARTIST-INTENT-OR-WAIVER",
            "OD-INTERVIEW", "OD-RIGHTS-COLLECTION", "OD-RIGHTS-TOKEN", "OD-C2PA", "OD-IIIF",
            "OD-SIGNIFICANT-PROPERTIES", "OD-TOKEN-LANE-COMPLETE", "OD-TOKEN-LANE-HEADS",
            "OD-OWNER-LANE-COMPLETE", "OD-OWNER-LANE-HEADS", "OD-INDEPENDENT-LANE-COMPLETE",
            "OD-INDEPENDENT-LANE-HEADS", "OD-TRANSFER-PROVENANCE", "OD-TOMBSTONE",
            "OD-ATTRIBUTION", "OD-RENDER-INVENTORY", "PKG-AUTHORITATIVE-RENDER-BYTES",
            "SEM-EXPANDED-PACKAGE",
            "PKG-PROFILE-REGISTRATION", "OD-TOOL-SOURCE-ARCHIVE",
            "OD-OPERATOR-INDEPENDENT-REGEN"}
        self.assertTrue(required <= {row["code"] for row in REQUIREMENTS})

    def test_empty_unknown_assessment_keeps_the_whole_denominator_and_conditionals_unresolved(self):
        report = assess("unknown", {}, {})
        self.assertFalse(report["complete"])
        self.assertFalse(report["conformanceClaimed"])
        self.assertFalse(report["releaseReadinessClaimed"])
        self.assertEqual(report["requirementsHash"], REQUIREMENTS_HASH)
        self.assertEqual(report["qualification"], QUALIFICATION)
        self.assertEqual(report["counts"], {"total": 49, "applicable": 47,
            "unresolvedApplicability": 2, "verified": 0, "suppliedUnverified": 0,
            "missing": 49, "notApplicable": 0})
        self.assertEqual(len(report["results"]), 49)
        self.assertEqual({row["code"] for row in report["results"]
            if row["applicability"] == "unresolved"}, SCRIPT_ONLY)

    def test_supplied_hashes_are_retained_but_never_become_verified(self):
        digest = "0x" + "11" * 32
        report = assess("script", {}, {"identity": (digest,)})
        row = next(row for row in report["results"] if row["code"] == "identity")
        self.assertEqual(row["state"], "supplied_unverified")
        self.assertEqual(row["suppliedHashes"], [digest])
        self.assertEqual(row["evidenceRefs"], [])
        self.assertEqual(report["counts"]["suppliedUnverified"], 1)
        self.assertFalse(report["complete"])

    def test_script_requires_every_row_verified_for_coverage_completion(self):
        report = assess("script", all_verified(), {})
        self.assertTrue(report["complete"])
        self.assertFalse(report["conformanceClaimed"])
        self.assertEqual(report["counts"]["applicable"], 49)
        self.assertEqual(report["counts"]["verified"], 49)
        self.assertTrue(all(row["state"] == "verified" for row in report["results"]))

    def test_non_script_can_exempt_only_script_manifest_and_drill(self):
        report = assess("non_script", all_verified(omit=SCRIPT_ONLY), {})
        self.assertTrue(report["complete"])
        self.assertEqual(report["counts"]["applicable"], 47)
        self.assertEqual(report["counts"]["notApplicable"], 2)
        self.assertEqual({row["code"] for row in report["results"]
            if row["state"] == "not_applicable"}, SCRIPT_ONLY)
        missing_dependency = assess("non_script",
            all_verified(omit=SCRIPT_ONLY | {"OD-DEPENDENCY-MANIFEST"}), {})
        self.assertFalse(missing_dependency["complete"])
        self.assertEqual(next(row for row in missing_dependency["results"]
            if row["code"] == "OD-DEPENDENCY-MANIFEST")["state"], "missing")

    def test_unknown_work_class_never_resolves_conditional_requirements(self):
        report = assess("unknown", all_verified(), {})
        self.assertFalse(report["complete"])
        self.assertEqual(report["counts"]["verified"], 49)
        self.assertEqual(report["counts"]["unresolvedApplicability"], 2)

    def test_allowed_empty_policy_does_not_suppress_an_omitted_requirement(self):
        report = assess("script", all_verified(omit={"OD-C2PA"}), {})
        row = next(row for row in report["results"] if row["code"] == "OD-C2PA")
        self.assertEqual(row["allowedAbsence"], "verified_empty_lane_inventory_only")
        self.assertEqual(row["state"], "missing")
        self.assertFalse(report["complete"])

    def test_authenticated_absence_and_waiver_policies_still_require_evidence(self):
        report = assess("script", all_verified(omit={"OD-INTERVIEW", "OD-TOMBSTONE",
            "OD-SCRIPT-DRILL"}), {})
        rows = {row["code"]: row for row in report["results"]}
        self.assertEqual(rows["OD-INTERVIEW"]["allowedAbsence"], "authenticated_absence_only")
        self.assertEqual(rows["OD-TOMBSTONE"]["allowedAbsence"], "authenticated_absence_only")
        self.assertEqual(rows["OD-SCRIPT-DRILL"]["allowedAbsence"],
            "work_class_non_script_or_authenticated_never_drilled_only")
        self.assertTrue(all(rows[code]["state"] == "missing" for code in (
            "OD-INTERVIEW", "OD-TOMBSTONE", "OD-SCRIPT-DRILL")))
        self.assertFalse(report["complete"])

    def test_unknown_overlapping_or_boolean_markers_are_rejected(self):
        good = (ref("identity"),)
        with self.assertRaisesRegex(MuseumError, "unknown requirement"):
            assess("script", {"FORGED": good}, {})
        with self.assertRaisesRegex(MuseumError, "keys overlap"):
            assess("script", {"identity": good},
                {"identity": ("0x" + "11" * 32,)})
        with self.assertRaisesRegex(MuseumError, "nonempty tuple"):
            assess("script", {"identity": True}, {})
        with self.assertRaisesRegex(MuseumError, "nonempty tuple"):
            assess("script", {}, {"identity": True})

    def test_strict_reference_and_hash_types_reject_forged_shapes(self):
        with self.assertRaisesRegex(MuseumError, "reference type"):
            assess("script", {"identity": ({"contentHash": "0x" + "11" * 32},)}, {})
        with self.assertRaisesRegex(MuseumError, "canonical 32-byte hash"):
            assess("script", {"identity": (
                EvidenceRef("adapter:test", "0x" + "AA" * 32, "/x"),)}, {})
        with self.assertRaisesRegex(MuseumError, "nonzero"):
            assess("script", {}, {"identity": ("0x" + "00" * 32,)})
        with self.assertRaisesRegex(MuseumError, "sorted and unique"):
            assess("script", {}, {"identity": ("0x" + "22" * 32,
                "0x" + "11" * 32)})
        with self.assertRaisesRegex(MuseumError, "work_class"):
            assess(True, {}, {})

    def test_verified_reference_accepts_retained_path_but_rejects_traversal(self):
        digest = "0x" + "11" * 32
        report = assess("script", {"identity": (
            EvidenceRef("source/retained/inputs.json.gz", digest,
                "tokenSourceBlockViews/tokenCollectionIdentity"),)}, {})
        self.assertEqual(report["results"][0]["state"], "verified")
        with self.assertRaisesRegex(MuseumError, "reference fields"):
            assess("script", {"identity": (
                EvidenceRef("source/../inputs.json.gz", digest, "/identity"),)}, {})

    def test_assessment_is_deterministic_across_mapping_order(self):
        rows = list(REQUIREMENTS[:3])
        forward = {row["code"]: (ref(row["code"], index + 1),)
            for index, row in enumerate(rows)}
        reverse = dict(reversed(list(forward.items())))
        self.assertEqual(dumps(assess("script", forward, {})),
            dumps(assess("script", reverse, {})))


if __name__ == "__main__": unittest.main()
