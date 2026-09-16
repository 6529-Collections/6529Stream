"""Focused controls for bounded offline RDF/JSON authority snapshots."""

from hashlib import sha256
import json
import unittest

from .authority_snapshot import (
    DCT_MODIFIED, FOAF_FOCUS, GVP, MAX_SUBJECTS, MAX_TERMS, OWL_VERSION_INFO,
    RAW_BYTES, RDF_TYPE, RDFS_LABEL, SKOS, SKOSXL, WIKIDATA_INSTANCE_OF,
    canonical_authority_iri, parse_snapshot,
)
from .canonical import MuseumError, dumps, keccak256


def descriptor(raw, authority="GETTY_TGN", identifier="7002327", algorithm="1", **changes):
    content_digest = (keccak256(raw) if algorithm == "1"
                      else "0x" + sha256(raw).hexdigest())
    value = {"version": "1", "authority": authority, "identifier": identifier,
             "canonicalIri": canonical_authority_iri(authority, identifier),
             "sourceUri": "https://example.test/retained-authority-record.rdf.json",
             "retrievedAt": "2026-09-16T12:34:56Z",
             "contentHash": {"algorithm": algorithm, "digest": content_digest,
                             "canonicalizationId": RAW_BYTES},
             "byteLength": str(len(raw)), "mediaType": "application/rdf+json",
             "attribution": "Authority attribution retained as supplied",
             "reuseTerms": "Reuse terms retained as supplied"}
    value.update(changes)
    encoded = dumps(value)
    return encoded, keccak256(encoded)


def parse(graph, **descriptor_changes):
    raw = dumps(graph)
    encoded, digest = descriptor(raw, **descriptor_changes)
    return parse_snapshot(encoded, raw, descriptor_hash=digest)


class AuthoritySnapshot(unittest.TestCase):
    def test_canonical_authority_iris_preserve_issued_forms(self):
        self.assertEqual(canonical_authority_iri("GETTY_TGN", "7002327"),
                         "http://vocab.getty.edu/tgn/7002327")
        self.assertEqual(canonical_authority_iri("GETTY_AAT", "300033618"),
                         "http://vocab.getty.edu/aat/300033618")
        self.assertEqual(canonical_authority_iri("GETTY_ULAN", "500115588"),
                         "http://vocab.getty.edu/ulan/500115588")
        self.assertEqual(canonical_authority_iri("VIAF", "24604287"),
                         "http://viaf.org/viaf/24604287")
        self.assertEqual(canonical_authority_iri("WIKIDATA", "Q42"),
                         "http://www.wikidata.org/entity/Q42")
        for authority, identifier in (("GETTY_TGN", "07002327"), ("GETTY_TGN", "0"),
                                      ("GETTY_TGN", "7002327.json"),
                                      ("WIKIDATA", "q42"), ("WIKIDATA", "Q042"),
                                      ("VIAF", "24604287/"), ("OTHER", "1")):
            with self.subTest(authority=authority, identifier=identifier), self.assertRaises(MuseumError):
                canonical_authority_iri(authority, identifier)

    def test_getty_snapshot_extracts_focus_labels_types_hierarchy_and_revision(self):
        root = canonical_authority_iri("GETTY_TGN", "7002327")
        focus = root + "-place"
        label = "_:preferred"
        graph = {
            root: {
                FOAF_FOCUS: [{"type": "uri", "value": focus}],
                SKOS + "prefLabel": [{"type": "literal", "value": "Milos", "lang": "en"}],
                RDFS_LABEL: [{"type": "literal", "value": "Milos (island)"}],
                SKOSXL + "altLabel": [{"type": "bnode", "value": label}],
                RDF_TYPE: [{"type": "uri", "value": GVP + "PhysPlaceConcept"}],
                SKOS + "broader": [{"type": "uri", "value": "http://vocab.getty.edu/tgn/1000074"}],
                GVP + "broaderPreferred": [{"type": "uri", "value": "http://vocab.getty.edu/tgn/1000003"}],
                DCT_MODIFIED: [{"type": "literal", "value": "2025-02-03"}],
                "urn:test:unknown": [{"type": "literal", "value": "retained"}],
            },
            focus: {RDF_TYPE: [{"type": "uri", "value": "http://www.w3.org/2003/01/geo/wgs84_pos#SpatialThing"}]},
            label: {SKOSXL + "literalForm": [{"type": "literal", "value": "Melos", "lang": "en"}]},
        }
        result = parse(graph)
        self.assertEqual(result["focusIri"], focus)
        self.assertCountEqual([(row["value"], row["language"]) for row in result["labels"]],
                              [("Milos", "en"), ("Milos (island)", None), ("Melos", "en")])
        self.assertEqual(len(result["typeFacts"]), 2)
        self.assertEqual(len(result["hierarchyFacts"]), 2)
        self.assertEqual(result["revisions"][0]["object"]["value"], "2025-02-03")
        self.assertEqual(len(result["triples"]), 11)
        self.assertTrue(all(row["sourcePointer"].startswith("/") for row in result["triples"]))
        milos = next(row for row in result["labels"] if row["value"] == "Milos")
        self.assertEqual(milos["sourcePointer"],
            "/http:~1~1vocab.getty.edu~1tgn~17002327/"
            "http:~1~1www.w3.org~12004~102~1skos~1core#prefLabel/0")
        self.assertEqual(result["descriptorHash"], keccak256(dumps(result["descriptor"])))
        self.assertEqual(result["contentHash"], result["descriptor"]["contentHash"])
        dumps(result)  # The adapter can hash the returned value without coercion.

    def test_wikidata_p31_and_absent_optional_facts_are_supported(self):
        root = canonical_authority_iri("WIKIDATA", "Q42")
        result = parse({root: {WIKIDATA_INSTANCE_OF: [
            {"type": "uri", "value": "http://www.wikidata.org/entity/Q5"}] }},
            authority="WIKIDATA", identifier="Q42")
        self.assertIsNone(result["focusIri"])
        self.assertEqual(result["labels"], [])
        self.assertEqual(result["hierarchyFacts"], [])
        self.assertEqual(result["typeFacts"][0]["object"]["value"],
                         "http://www.wikidata.org/entity/Q5")

    def test_noncanonical_rdf_json_and_sha256_raw_commitment_are_accepted(self):
        root = canonical_authority_iri("VIAF", "24604287")
        raw = json.dumps({root: {OWL_VERSION_INFO: [
            {"type": "literal", "value": " revision 7 "}] }}, indent=2).encode("utf-8")
        encoded, digest = descriptor(raw, authority="VIAF", identifier="24604287", algorithm="2")
        result = parse_snapshot(encoded, raw, descriptor_hash=digest)
        self.assertEqual(result["revisions"][0]["object"]["value"], " revision 7 ")
        self.assertEqual(result["contentHash"]["digest"], "0x" + sha256(raw).hexdigest())

    def test_descriptor_and_raw_commitments_are_exact(self):
        root = canonical_authority_iri("GETTY_AAT", "300033618")
        raw = dumps({root: {RDF_TYPE: [{"type": "uri", "value": GVP + "Concept"}]}})
        encoded, digest = descriptor(raw, authority="GETTY_AAT", identifier="300033618")
        with self.assertRaisesRegex(MuseumError, "descriptor hash"):
            parse_snapshot(encoded, raw, descriptor_hash="0x" + "00" * 32)
        changed = raw + b" "
        with self.assertRaisesRegex(MuseumError, "byte length"):
            parse_snapshot(encoded, changed, descriptor_hash=digest)
        value = json.loads(encoded)
        value["contentHash"]["canonicalizationId"] = "0x" + "00" * 32
        bad = dumps(value)
        with self.assertRaisesRegex(MuseumError, "raw bytes"):
            parse_snapshot(bad, raw, descriptor_hash=keccak256(bad))

    def test_descriptor_is_closed_and_source_claim_is_only_shape_checked(self):
        root = canonical_authority_iri("GETTY_ULAN", "500115588")
        raw = dumps({root: {}})
        encoded, _ = descriptor(raw, authority="GETTY_ULAN", identifier="500115588",
                                sourceUri="https://unverified.example/snapshot")
        value = json.loads(encoded); value["extra"] = "no"
        bad = dumps(value)
        with self.assertRaisesRegex(MuseumError, "closed"):
            parse_snapshot(bad, raw, descriptor_hash=keccak256(bad))
        for source in ("ftp://example.test/a", "https://user@example.test/a", "https://example.test/a#part"):
            encoded, digest = descriptor(raw, authority="GETTY_ULAN", identifier="500115588", sourceUri=source)
            with self.subTest(source=source), self.assertRaisesRegex(MuseumError, "source URI"):
                parse_snapshot(encoded, raw, descriptor_hash=digest)

    def test_duplicate_keys_unsupported_terms_and_focus_conflicts_reject(self):
        root = canonical_authority_iri("GETTY_TGN", "7002327")
        duplicate = ('{"%s":{"%s":[{"type":"literal","value":"a","value":"b"}]}}'
                     % (root, RDFS_LABEL)).encode()
        encoded, digest = descriptor(duplicate)
        with self.assertRaisesRegex(MuseumError, "duplicate"):
            parse_snapshot(encoded, duplicate, descriptor_hash=digest)
        for graph in (
            {root: {RDFS_LABEL: [{"type": "literal", "value": "x", "xml:lang": "en"}]}},
            {root: {RDF_TYPE: [{"type": "literal", "value": "not an IRI"}]}},
            {root: {"urn:test:bad|predicate": [{"type": "literal", "value": "x"}]}},
            {root: {FOAF_FOCUS: [{"type": "uri", "value": root + "-place"},
                                 {"type": "uri", "value": root + "-region"}]}},
            {root: {FOAF_FOCUS: [{"type": "uri", "value": root}]}},
        ):
            with self.subTest(graph=graph), self.assertRaises(MuseumError):
                parse(graph)

    def test_subject_and_term_bounds_reject_without_remote_work(self):
        root = canonical_authority_iri("GETTY_TGN", "7002327")
        too_many_subjects = {root: {}}
        too_many_subjects.update({f"urn:test:s:{index}": {} for index in range(MAX_SUBJECTS)})
        with self.assertRaisesRegex(MuseumError, "subject bound"):
            parse(too_many_subjects)
        graph = {root: {"urn:test:p": [
            {"type": "literal", "value": str(index)} for index in range(MAX_TERMS + 1)]}}
        with self.assertRaisesRegex(MuseumError, "term bound"):
            parse(graph)


if __name__ == "__main__":
    unittest.main()
