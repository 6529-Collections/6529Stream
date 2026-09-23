"""Focused synthetic controls for the bounded geography projector."""

import copy
from pathlib import Path
import socket
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, loads
from .geography import (
    CLAIMS, MAX_PLACES, PLACE_CLASSES, PLACE_CLASS_PREFIX, PROFILE_BYTES,
    PROFILE_HASH, QUALIFICATION, ROLES, admit, fields, project,
)
from .preservation_graph import validator


ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


def H(value):
    return "0x" + f"{value:064x}"


def A(value):
    return "0x" + f"{value:040x}"


def selector(value):
    return {"recordHash": H(value), "subjectId": H(900), "schemaId": H(901),
        "schemaHash": H(902), "recordType": H(903), "host": A(1), "recorder": A(2),
        "authorizationClass": "OWNER_SIGNER", "pointer": "", "recordIndex": str(value),
        "recordChainHash": H(904 + value)}


def source(value, path):
    return {"record": selector(value), "path": path, "assertionId": f"urn:test:assertion:{value}"}


def date(expression="1900", early="1900-01-01T00:00:00Z", late="1900-12-31T23:59:59Z", precision="range"):
    return {"expression": expression, "precision": precision, "calendar": "gregorian",
        "timezone": "UTC", "earliest": early, "latest": late}


def document(value, path="evidence/source.json"):
    return {"path": path, "contentHash": {"algorithm": "1", "digest": H(value),
        "canonicalizationId": H(777)}, "byteLength": "123", "mediaType": "application/json"}


def named(value, text, *, historical=False):
    return {"value": text, "kind": "historical" if historical else "preferred",
        "language": "en", "applicableDate": date() if historical else None,
        "source": source(value, "/name")}


def classification(value, code):
    return {"code": code, "id": PLACE_CLASS_PREFIX + code, "label": PLACE_CLASSES[code],
        "applicableDate": None, "source": source(value, "/classification")}


def alignment(value, *, match="equivalent_entity", reviewed=True, disposition="active", supersedes=None):
    identifier = str(1000000 + value)
    return {"assertionId": f"urn:test:tgn-assertion:{value}", "entityId": "urn:test:place:milos",
        "authority": "GETTY_TGN", "identifier": identifier,
        "canonicalIri": "http://vocab.getty.edu/tgn/" + identifier,
        "focusIri": "http://vocab.getty.edu/tgn/" + identifier + "-place",
        "matchKind": match, "disposition": disposition, "supersedes": supersedes,
        "snapshotRef": document(300 + value, f"authority/tgn-{identifier}.json"),
        "retrievedAt": "2026-06-03T00:00:00Z", "authorityRevision": "not_supplied",
        "labelAtReview": named(310 + value, "Milos"),
        "snapshotValues": {"labels": [named(320 + value, "Milos")],
            "types": [{"path": "/type/0", "value": "island"}],
            "hierarchies": [{"identifier": "1000074", "relationship": "broader",
                "sourceValue": "Greece", "applicableDate": date("2026", "2026-01-01T00:00:00Z", "2026-12-31T23:59:59Z")}],
            "otherValues": [{"path": "/scopeNote", "value": "Snapshot value used during review"}],
            "sourceAttribution": "Synthetic Getty-shaped test snapshot", "reuseTerms": "Test fixture only"},
        "basis": {"rationale": "Synthetic type and geographic-context checks for projector testing",
            "evidenceSelectors": [source(330 + value, "/authority-match")],
            "author": "urn:test:mapper", "reviewer": "urn:test:reviewer" if reviewed else None,
            "status": "reviewed" if reviewed else "unreviewed", "origin": "human_mapping",
            "entityTypeChecked": reviewed, "geographicContextChecked": reviewed}}


def place(value, entity, text, code, *, nature="real", precision="broad_region"):
    return {"entityId": entity, "nature": nature, "publicPrecision": precision,
        "source": source(value + 4, "/place"),
        "preferredName": named(value, text), "alternateNames": [],
        "contexts": [{"value": text + " context as supplied", "language": "en",
            "applicableDate": None, "source": source(value + 1, "/context")}],
        "classifications": [classification(value + 2, code)],
        "sourceReferences": [document(value + 3, f"places/{value}.json")],
        "hierarchies": [], "geometry": None, "authorityAlignments": []}


def fixture():
    greece = place(1, "urn:test:place:greece", "Greece", "country")
    milos = place(10, "urn:test:place:milos", "Milos", "island", precision="geometry_as_supplied")
    milos["alternateNames"] = [named(14, "Melos", historical=True)]
    milos["contexts"].append({"value": "An island-level account; no beach or capture point is inferred.",
        "language": "en", "applicableDate": date("historical usage"), "source": source(15, "/context/1")})
    milos["hierarchies"] = [
        {"kind": "spatial_containment", "parentPlaceId": greece["entityId"],
            "context": "Island described as spatially within the named country-level place.",
            "applicableDate": date("2026"), "source": source(16, "/hierarchy/spatial")},
        {"kind": "catalog_hierarchy", "parentPlaceId": greece["entityId"],
            "context": "Copied catalog broader-place assertion.", "applicableDate": date("authority snapshot 2026"),
            "source": source(17, "/hierarchy/catalog")},
        {"kind": "political_affiliation", "parentPlaceId": greece["entityId"],
            "context": "Historically scoped political assertion, not timeless sovereignty.",
            "applicableDate": date("2026"), "source": source(18, "/hierarchy/political")},
    ]
    milos["geometry"] = {"kind": "centroid", "representation": "POINT(24.4 36.7)",
        "crs": "http://www.opengis.net/def/crs/OGC/1.3/CRS84",
        "precision": "coordinates supplied to one decimal degree",
        "uncertainty": "regional centroid; not the artist's capture position",
        "applicableDate": date("source statement 2026"), "source": source(19, "/geometry")}
    milos["authorityAlignments"] = [alignment(1), alignment(2, match="close_match", reviewed=False)]
    fictional = place(30, "urn:test:place:fictional", "The Glass Coast", "fictional_place",
        nature="fictional", precision="named_place")
    unknown = place(40, "urn:test:place:unknown", "Unidentified shore", "unidentified_place",
        nature="unidentified", precision="named_place")
    associations = []
    for index, role in enumerate(ROLES):
        subject_type = ("VisualItem" if role == "depicted_place" else
            "LinguisticObject" if role == "subject_place" else
            "Creation" if role == "creation_location" else
            "Production" if role == "production_location" else "Activity")
        associations.append({"associationId": f"urn:test:association:{role}",
            "placeId": milos["entityId"], "subjectId": f"urn:test:subject:{role}",
            "subjectType": subject_type, "role": role, "context": "Exact asserted role",
            "applicableDate": date("2026"), "source": source(100 + index, "/association")})
    return {"version": "1", "places": [greece, milos, fictional, unknown], "associations": associations}


class Geography(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = validator(ROOT)

    def projected(self, value=None):
        value = fixture() if value is None else value
        with patch.object(socket, "socket", side_effect=AssertionError("network forbidden")):
            return project(dumps(value), self.model)

    def resources(self, files):
        return [loads(raw) for path, raw in files.items() if path.startswith("geography/resources/")]

    def test_all_nine_roles_have_closed_typed_qualified_projection(self):
        files = self.projected()
        rows = loads(files["geography/relations.json"], maximum=MAX_PLACES * 16384)
        self.assertEqual({row["role"] for row in rows}, set(ROLES))
        for row in rows:
            if row["role"] == "depicted_place":
                self.assertEqual((row["subject"]["type"], row["property"]), ("VisualItem", "represents"))
            elif row["role"] == "subject_place":
                self.assertEqual((row["subject"]["type"], row["property"]), ("LinguisticObject", "about"))
            elif row["role"] == "creation_location":
                self.assertEqual((row["subject"]["type"], row["property"]), ("Creation", "took_place_at"))
            elif row["role"] == "production_location":
                self.assertEqual((row["subject"]["type"], row["property"]), ("Production", "took_place_at"))
            else:
                self.assertEqual((row["subject"]["type"], row["property"]), ("Activity", "took_place_at"))
            self.assertEqual(row["qualification"], QUALIFICATION)
            self.assertEqual(row["disposition"], "mapped")

    def test_local_identity_cannot_bypass_authority_or_entity_kind_boundaries(self):
        for identifier in ("http://vocab.getty.edu/tgn/7002327", "http://vocab.getty.edu/tgn/7002327-place",
            "https://vocab.getty.edu/tgn/7002327.json", "https://www.wikidata.org/entity/Q1", "eip155:1:0x01"):
            value = fixture(); value["places"][2]["entityId"] = identifier
            with self.subTest(identifier=identifier), self.assertRaises(MuseumError): self.projected(value)
        for identifier in ("urn:test:place:milos", PLACE_CLASS_PREFIX + "country"):
            value = fixture(); value["associations"][0]["subjectId"] = identifier
            with self.assertRaisesRegex(MuseumError, "subject kind"): self.projected(value)
        value = fixture(); value["associations"][1]["subjectId"] = value["associations"][0]["subjectId"]
        with self.assertRaisesRegex(MuseumError, "subject kind"): self.projected(value)

    def test_unsupported_typed_subject_role_is_retained_without_a_false_property(self):
        value = fixture()
        value["associations"][3]["subjectType"] = "DigitalObject"
        files = self.projected(value)
        row = next(item for item in loads(files["geography/relations.json"], maximum=65536)
            if item["role"] == "subject_place")
        self.assertEqual(row["subject"]["type"], "DigitalObject")
        self.assertIsNone(row["property"])
        self.assertEqual(row["disposition"], "retained_stream_only")
        self.assertIn("no faithful property", row["reason"])
        sidecar = loads(files["geography/sidecar.json"], maximum=MAX_PLACES * 65536)
        self.assertTrue(any(item["kind"] == "place_association" for item in sidecar["unsupported"]))

    def test_historical_names_context_and_hierarchy_meanings_remain_distinct(self):
        files = self.projected()
        milos = next(row for row in self.resources(files) if row["id"] == "urn:test:place:milos")
        self.assertEqual([row["content"] for row in milos["identified_by"]], ["Milos", "Melos"])
        self.assertEqual(milos["part_of"], [{"id": "urn:test:place:greece", "type": "Place"}])
        sidecar = loads(files["geography/sidecar.json"], maximum=MAX_PLACES * 65536)
        retained = sidecar["unsupported"]
        self.assertEqual({row["kind"] for row in retained if row["kind"].endswith("hierarchy") or row["kind"] == "political_affiliation"},
            {"catalog_hierarchy", "political_affiliation"})
        source_value = loads(files["geography/source.json"], maximum=524288)
        old_name = source_value["places"][1]["alternateNames"][0]
        self.assertEqual(old_name["value"], "Melos")
        self.assertEqual(old_name["applicableDate"]["expression"], "1900")
        self.assertIn("not timeless sovereignty", source_value["places"][1]["hierarchies"][2]["context"])

    def test_geometry_is_exact_public_stream_only_and_never_inferred(self):
        files = self.projected()
        sidecar = loads(files["geography/sidecar.json"], maximum=MAX_PLACES * 65536)
        geometry = next(row["value"] for row in sidecar["unsupported"] if row["kind"] == "geometry")
        self.assertEqual(geometry["representation"], "POINT(24.4 36.7)")
        self.assertEqual(geometry["crs"], "http://www.opengis.net/def/crs/OGC/1.3/CRS84")
        self.assertIn("not the artist's capture position", geometry["uncertainty"])
        resources = self.resources(files)
        self.assertFalse(any("defined_by" in row or "approximated_by" in row for row in resources))
        no_geometry = fixture(); no_geometry["places"][1]["geometry"] = None
        no_geometry["places"][1]["publicPrecision"] = "broad_region"
        no_geometry_files = self.projected(no_geometry)
        self.assertNotIn(b"POINT(24.4 36.7)", b"".join(no_geometry_files.values()))

    def test_self_declared_reviewed_tgn_never_projects_and_all_history_remains(self):
        value = fixture()
        value["places"][1]["authorityAlignments"][0]["basis"]["reviewer"] = "urn:test:mapper"
        old = alignment(3, disposition="superseded")
        old["focusIri"] = None
        old["supersedes"] = None
        value["places"][1]["authorityAlignments"].append(old)
        value["places"][1]["authorityAlignments"][0]["supersedes"] = old["assertionId"]
        files = self.projected(value)
        milos = next(row for row in self.resources(files) if row["id"] == "urn:test:place:milos")
        self.assertNotIn("equivalent", milos)
        sidecar = loads(files["geography/sidecar.json"], maximum=MAX_PLACES * 65536)
        retained = [row["value"] for row in sidecar["unsupported"] if row["kind"] == "authority_alignment"]
        self.assertEqual({row["assertionId"] for row in retained}, {
            "urn:test:tgn-assertion:1", "urn:test:tgn-assertion:2", "urn:test:tgn-assertion:3"})
        self.assertTrue(all(row["snapshotValues"]["sourceAttribution"] for row in retained))
        self.assertFalse(any(CLAIMS.values()))

    def test_every_source_leaf_has_one_exact_coverage_row(self):
        value = fixture(); files = self.projected(value)
        coverage = loads(files["geography/coverage.json"], maximum=16 * 1024 * 1024)
        expected = list(fields(loads(dumps(value), maximum=524288)))
        self.assertEqual([(row["sourcePath"], row["value"]) for row in coverage], expected)
        self.assertEqual(len({row["sourcePath"] for row in coverage}), len(coverage))
        self.assertEqual({row["disposition"] for row in coverage}, {"mapped", "retained_stream_only"})
        self.assertEqual(loads(files["geography/report.json"])["sourceValues"], str(len(expected)))
        provenance = loads(files["geography/provenance.json"], maximum=16 * 1024 * 1024)
        spatial = next(row for row in provenance
            if row["entity"] == "urn:test:place:milos" and row["path"] == "/part_of/0/id")
        historical = next(row for row in provenance
            if row["entity"] == "urn:test:place:milos" and row["path"] == "/identified_by/1/content")
        self.assertEqual(spatial["sourcePaths"], ["/places/1/hierarchies/0"])
        self.assertEqual(historical["sourcePaths"], ["/places/1/alternateNames/0"])
        self.assertTrue(all(row["sources"] and row["rule"] and row["qualification"] for row in provenance))

    def test_deterministic_offline_bytes_and_profile_commitment(self):
        first = self.projected(); second = self.projected()
        self.assertEqual(first, second)
        self.assertEqual(PROFILE_HASH, "0x" + __import__("Crypto.Hash.keccak", fromlist=["new"]).new(
            digest_bits=256, data=PROFILE_BYTES).hexdigest())
        self.assertTrue(all(isinstance(raw, bytes) for raw in first.values()))

    def test_false_equivalence_role_geometry_and_history_inputs_reject(self):
        mutations = []
        def bad_review(v): v["places"][1]["authorityAlignments"][0]["basis"]["entityTypeChecked"] = False
        def bad_iri(v): v["places"][1]["authorityAlignments"][0]["canonicalIri"] += ".json"
        def bad_fiction(v): v["places"][2]["authorityAlignments"] = [dict(alignment(9), entityId="urn:test:place:fictional")]
        def bad_precision(v): v["places"][1]["publicPrecision"] = "broad_region"
        def bad_date(v): v["places"][1]["alternateNames"][0]["applicableDate"]["latest"] = "1899-01-01T00:00:00Z"
        def bad_cycle(v): v["places"][0]["hierarchies"] = [{"kind":"spatial_containment", "parentPlaceId":"urn:test:place:milos", "context":"cycle", "applicableDate":None, "source":source(88,"/cycle") }]
        mutations += [bad_review, bad_iri, bad_fiction, bad_precision, bad_date, bad_cycle]
        for mutation in mutations:
            with self.subTest(mutation=mutation.__name__):
                value = fixture(); mutation(value)
                with self.assertRaises(MuseumError):
                    project(dumps(value), self.model)

    def test_invalid_bounds_duplicates_noncanonical_and_unsafe_evidence_reject(self):
        value = fixture()
        value["places"] = [copy.deepcopy(value["places"][0]) for _ in range(MAX_PLACES + 1)]
        with self.assertRaises(MuseumError): project(dumps(value), self.model)
        value = fixture(); value["places"][0]["sourceReferences"][0]["path"] = "../secret.json"
        with self.assertRaisesRegex(MuseumError, "archived document path"):
            project(dumps(value), self.model)
        value = fixture(); value["associations"].append(copy.deepcopy(value["associations"][0]))
        with self.assertRaisesRegex(MuseumError, "duplicate association"):
            project(dumps(value), self.model)
        raw = dumps(fixture()).replace(b'{"associations"', b'{ "associations"', 1)
        with self.assertRaisesRegex(MuseumError, "canonical JSON"):
            project(raw, self.model)
        with self.assertRaisesRegex(MuseumError, "input byte bound"):
            project(b" " * 524289, self.model)


if __name__ == "__main__":
    unittest.main()
