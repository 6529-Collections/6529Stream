import base64
from copy import deepcopy
from hashlib import sha256
import json
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps
from .dossier_media import requirements, validate_media
from .iiif import FIELDS as IF
from .iiif_model import XSD
from .premis import FIELDS as PF


ENTITY = "urn:test:media:image"
WORK = "urn:test:work"
RAW = b"exact local media bytes"
DIGEST = sha256(RAW).hexdigest()
URI = "ipfs://b" + base64.b32encode(bytes.fromhex("01551220" + DIGEST)).decode("ascii").lower().rstrip("=")


def selector(index):
    word = format(index + 1, "064x")
    return {"authorizationClass": "INDEPENDENT_ATTESTOR", "host": "0x" + "22" * 20,
        "pointer": "/assertions/0", "recordChainHash": "0x" + word,
        "recordHash": "0x" + word, "recordIndex": str(index), "recordType": "0x" + "33" * 32,
        "recorder": "0x" + "44" * 20, "schemaHash": "0x" + "55" * 32,
        "schemaId": "0x" + "66" * 32, "subjectId": "0x" + "77" * 32}


def selected(relation, value, index, *, entity=False, datatype=XSD + "string"):
    obj = {"entity": value} if entity else {"literal": {"lexicalValue": value,
        "datatype": datatype, "language": None, "unit": None, "precision": None}}
    assertion = {"id": "urn:test:assertion:" + str(index), "subject": ENTITY,
        "relation": relation, "object": obj, "assertingAgent": "urn:test:account",
        "createdAt": "2026-09-16T00:00:00Z", "evidence": [], "origin": "direct_statement",
        "reviewStatus": "unreviewed", "mappingRule": "urn:test:rule", "rationale": "fixture",
        "reviewEvidence": [], "corrects": [], "disputes": []}
    return {"assertion": assertion, "basis": "direct_account_statement",
        "projectionReason": "retained typed assertion", "reviewEvidence": [], "selector": selector(index)}


def fixture(*, duplicate=None, include_presentation=True, digest=DIGEST, size=None, uri=URI):
    rows = []
    if include_presentation:
        rows.append(selected(IF["presentation-of"], WORK, 0, entity=True))
    rows.extend((selected(IF["presentation-type"], "Image", 1),
        selected(IF["mime"], "image/png", 2),
        selected(IF["content-uri"], uri, 3, datatype=XSD + "anyURI"),
        selected(PF["size"], str(len(RAW)) if size is None else size, 4,
                 datatype=XSD + "nonNegativeInteger"),
        selected(PF["digest"], digest, 5),
        selected(IF["rights"], "http://creativecommons.org/publicdomain/zero/1.0/", 6,
                 datatype=XSD + "anyURI")))
    if duplicate is not None:
        original = next(r for r in rows if r["assertion"]["relation"] == duplicate)
        repeated = deepcopy(original); repeated["assertion"]["id"] += ":duplicate"
        repeated["selector"] = selector(20)
        rows.append(repeated)
    sidecar = {"base": {"mode": "recorded", "diagnostics": [], "extensionEntities": [],
        "externalEntities": [], "publicSources": [], "selectedClaims": rows, "withheldClaims": []},
        "authority": {}}
    index = [{"id": ENTITY, "kind": "linked_art", "type": "DigitalObject",
        "path": "semantic/resources/image.json"},
        {"id": WORK, "kind": "linked_art", "type": "PropositionalObject",
         "path": "semantic/resources/work.json"}]
    return {"semantic/assertions.json": dumps(sidecar), "semantic/entityIndex.json": dumps(index)}


class DossierMediaTests(unittest.TestCase):
    def test_selected_presentation_yields_exact_stable_provenance_and_validates_bytes(self):
        files = fixture()
        with patch("socket.socket", side_effect=AssertionError("media adapter used network")):
            first = requirements(files); second = requirements(files)
            embedded = validate_media(first, {DIGEST + ".bin": RAW})
        self.assertEqual(first, second)
        self.assertEqual(len(first), 1)
        row = first[0]
        self.assertEqual(row["entity"], ENTITY)
        self.assertEqual(row["presentationOf"], WORK)
        self.assertEqual(row["sha256"], DIGEST)
        self.assertEqual(row["byteLength"], str(len(RAW)))
        self.assertEqual(row["mediaType"], "image/png")
        self.assertEqual(row["uri"], URI)
        self.assertTrue(row["renderCritical"])
        self.assertEqual(row["path"], "media/" + DIGEST + ".bin")
        retained = {r["assertion"]["relation"] for r in row["admittedClaims"]}
        self.assertEqual(retained, {IF["presentation-of"], IF["presentation-type"], IF["mime"],
            IF["content-uri"], IF["rights"], PF["size"], PF["digest"]})
        self.assertEqual(embedded, {"media/" + DIGEST + ".bin": RAW})

    def test_shared_digest_deduplicates_payload_without_losing_entity_bindings(self):
        files = fixture(); sidecar = deepcopy(json.loads(files["semantic/assertions.json"]))
        index = deepcopy(json.loads(files["semantic/entityIndex.json"]))
        other = "urn:test:media:other"
        for row in deepcopy(sidecar["base"]["selectedClaims"]):
            row["assertion"]["subject"] = other
            row["assertion"]["id"] += ":other"
            row["selector"]["recordIndex"] = str(int(row["selector"]["recordIndex"]) + 100)
            sidecar["base"]["selectedClaims"].append(row)
        index.append({"id": other, "kind": "linked_art", "type": "DigitalObject",
                      "path": "semantic/resources/other.json"})
        rows = requirements({"semantic/assertions.json": dumps(sidecar),
            "semantic/entityIndex.json": dumps(index)})
        self.assertEqual([r["entity"] for r in rows], [ENTITY, other])
        self.assertEqual(validate_media(rows, {DIGEST + ".bin": RAW}),
                         {"media/" + DIGEST + ".bin": RAW})

    def test_missing_extra_and_mismatched_local_supply_fail_closed(self):
        rows = requirements(fixture())
        cases = ({}, {DIGEST + ".bin": RAW, "extra.bin": b"x"},
                 {DIGEST + ".bin": RAW + b"!"},
                 {DIGEST + ".bin": b"!" * len(RAW)}, {DIGEST + ".bin": "not bytes"})
        for supplied in cases:
            with self.subTest(supplied=supplied), self.assertRaises(MuseumError):
                validate_media(rows, supplied)

    def test_missing_or_duplicate_selected_media_facts_fail_closed(self):
        for relation in (IF["presentation-of"], IF["presentation-type"], IF["mime"],
                         IF["content-uri"], PF["size"], PF["digest"]):
            with self.subTest(relation=relation), self.assertRaisesRegex(MuseumError, "exactly one"):
                requirements(fixture(duplicate=relation))
        files = fixture(); value = json.loads(files["semantic/assertions.json"])
        value["base"]["selectedClaims"] = [r for r in value["base"]["selectedClaims"]
            if r["assertion"]["relation"] != PF["digest"]]
        with self.assertRaisesRegex(MuseumError, "exactly one"):
            requirements(files | {"semantic/assertions.json": dumps(value)})

    def test_declared_hash_size_uri_and_type_mime_are_checked(self):
        wrong_digest = "0" * 64 if DIGEST != "0" * 64 else "1" * 64
        cases = ((fixture(digest=wrong_digest), "CID differs"),
                 (fixture(size="01"), "noncanonical unsigned"),
                 (fixture(uri="https://example.org/media"), "content-addressed"))
        for files, message in cases:
            with self.subTest(message=message), self.assertRaisesRegex(MuseumError, message):
                requirements(files)
        files = fixture(); value = json.loads(files["semantic/assertions.json"])
        next(r for r in value["base"]["selectedClaims"] if r["assertion"]["relation"] == IF["mime"])["assertion"]["object"]["literal"]["lexicalValue"] = "audio/mpeg"
        with self.assertRaisesRegex(MuseumError, "type/MIME"):
            requirements(files | {"semantic/assertions.json": dumps(value)})

    def test_withheld_media_conflict_is_not_silently_ignored(self):
        files = fixture(); value = json.loads(files["semantic/assertions.json"])
        conflict = deepcopy(next(r for r in value["base"]["selectedClaims"]
            if r["assertion"]["relation"] == IF["content-uri"]))
        conflict["assertion"]["id"] += ":withheld"
        value["base"]["withheldClaims"] = [conflict]
        with self.assertRaisesRegex(MuseumError, "withheld"):
            requirements(files | {"semantic/assertions.json": dumps(value)})

    def test_role_or_metadata_annotations_never_select_media(self):
        files = fixture(include_presentation=False)
        value = json.loads(files["semantic/assertions.json"])
        value["base"]["selectedClaims"].append(selected(
            "urn:6529stream:museum:preservation-object:v1:objectRole", "SOURCE_MASTER", 30))
        self.assertEqual(requirements(files | {"semantic/assertions.json": dumps(value)}), [])

    def test_non_digital_or_ambiguous_entity_declaration_is_rejected(self):
        files = fixture(); index = json.loads(files["semantic/entityIndex.json"])
        index[0]["type"] = "PropositionalObject"
        with self.assertRaisesRegex(MuseumError, "DigitalObject"):
            requirements(files | {"semantic/entityIndex.json": dumps(index)})
        index[0]["type"] = "DigitalObject"; index.append(deepcopy(index[0]))
        with self.assertRaisesRegex(MuseumError, "DigitalObject"):
            requirements(files | {"semantic/entityIndex.json": dumps(index)})


if __name__ == "__main__":
    unittest.main()
