"""Focused tests for the broad prospective PREMIS v3 crosswalk."""

import copy
import hashlib
import unittest

import jsonschema

from tools.metadata import genesis_premis_profile as profile
from tools.museum.canonical import MuseumError, dumps, keccak256


class GenesisPremisProfileTest(unittest.TestCase):
    def changed(self):
        return copy.deepcopy(profile.example())

    def reject(self, value):
        with self.assertRaises(MuseumError):
            profile.validate(dumps(value))

    def test_generated_schema_commits_complete_profile_and_example(self):
        outputs = profile.outputs()
        self.assertEqual(set(outputs), {
            "schemas/records/STREAM_PREMIS_V3_PROFILE.json",
            "schemas/records/examples/genesis-premis/premis-v3-profile.json",
        })
        for relative, raw in outputs.items():
            self.assertEqual((profile.ROOT / relative).read_bytes(), raw)
        schema = profile.schema()
        self.assertEqual(schema["const"], profile.example())
        jsonschema.Draft202012Validator.check_schema(schema)
        self.assertEqual(profile.validate(profile.EXAMPLE_BYTES), profile.example())

    def test_all_six_structures_and_every_field_are_explicit(self):
        expected = {
            "CollectionRecord": {"recordType", "subjectId", "contentHash.algorithm", "contentHash.digest",
                "contentHash.canonicalizationId", "uri", "schemaId", "signatureScheme",
                "signatureHash.algorithm", "signatureHash.digest", "signatureHash.canonicalizationId", "effectiveAt"},
            "PreservationObjectRef": {"objectId", "objectRole", "uri", "contentHash", "mimeType", "byteSize", "formatId", "schemaId"},
            "PreservationEventRef": {"eventId", "eventType", "outcome", "eventURI", "eventHash", "eventTime", "schemaId"},
            "PreservationAgentRef": {"agentId", "agentRole", "account", "did", "uri", "agentHash"},
            "PreservationRightsRef": {"rightsId", "rightsBasis", "rightsURI", "rightsHash", "validFrom", "validUntil"},
            "FixityCheckRef": {"objectId", "algorithm", "digest", "byteSize", "checkedAt", "outcome", "agentId", "reportURI", "reportHash"},
        }
        rows = profile.example()["structureMappings"]
        self.assertEqual({row["structure"] for row in rows}, set(expected))
        for row in rows:
            fields = [field["sourceField"] for field in row["fields"]]
            self.assertEqual(set(fields), expected[row["structure"]])
            self.assertEqual(len(fields), len(set(fields)))

    def test_closed_roles_events_outcomes_and_fixity_algorithms(self):
        value = profile.example()
        self.assertEqual([row["source"] for row in value["objectRoles"]], list(profile.OBJECT_ROLES))
        self.assertEqual({row["source"]: row["target"] for row in value["eventTypes"]}, profile.EVENT_TYPES)
        self.assertEqual({row["source"]: row["target"] for row in value["outcomes"]}, profile.OUTCOMES)
        self.assertEqual({row["source"] for row in value["fixityAlgorithms"]},
            {"SHA256", "SHA512", "KECCAK256", "BLAKE3", "IPFS_CID_V1", "ARWEAVE_TX_ID"})
        for row in value["eventTypes"]:
            self.assertEqual(row["profileLocal"], row["source"] in profile.LOCAL_EVENT_TYPES)
            if row["source"] in profile.EVENT_CODES:
                self.assertEqual(row["valueUri"], profile.EVENT_AUTHORITY + "/" + profile.EVENT_CODES[row["source"]])
                self.assertEqual(row["termResolution"], "official_code_verified")
            elif row["profileLocal"]:
                self.assertIsNone(row["valueUri"])
                self.assertEqual(row["termResolution"], "profile_local")
            else:
                self.assertIsNone(row["valueUri"])
                self.assertEqual(row["termResolution"], "unresolved_authority_term_uri")
        for row in value["outcomes"]:
            self.assertEqual(row["profileLocal"], row["source"] in profile.LOCAL_OUTCOMES)
            self.assertEqual(row["detailRequired"], row["source"] in profile.LOCAL_OUTCOMES)

    def test_rights_crosswalk_is_complete_and_bound_to_existing_schema(self):
        rights = profile.example()["rights"]
        self.assertEqual(rights["sourceSchemaHash"], keccak256(profile.RIGHTS_SCHEMA_BYTES))
        self.assertEqual([row["source"] for row in rights["uses"]], list(profile.USES))
        self.assertEqual([row["source"] for row in rights["statuses"]], list(profile.STATUSES))
        self.assertFalse(next(row for row in rights["statuses"] if row["source"] == "denied")["isGrant"])
        self.assertFalse(next(row for row in rights["statuses"] if row["source"] == "unspecified")["isGrant"])

    def test_signature_commitments_and_format_ids_are_not_misstated(self):
        structures = {row["structure"]: row["fields"] for row in profile.example()["structureMappings"]}
        collection = {row["sourceField"]: row for row in structures["CollectionRecord"]}
        for name in ("signatureScheme", "signatureHash.algorithm", "signatureHash.digest",
                     "signatureHash.canonicalizationId"):
            self.assertIn("significantProperties", collection[name]["targetPath"])
            self.assertNotIn("signatureValue", collection[name]["targetPath"])
        object_fields = {row["sourceField"]: row for row in structures["PreservationObjectRef"]}
        self.assertIn("significantProperties", object_fields["formatId"]["targetPath"])
        self.assertEqual(profile.example()["format"]["pronom"]["targetRegistryKey"],
                         "the exact <PUID>, never its hash")

    def test_local_pinned_xsd_is_exact(self):
        raw = profile._local_xsd()
        self.assertEqual(len(raw), profile.XSD_BYTES)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), profile.XSD_SHA256)
        target = profile.example()["target"]
        self.assertEqual(target["xsd"], {"uri": profile.XSD_URI,
            "sha256": "0x" + profile.XSD_SHA256, "byteLength": str(profile.XSD_BYTES)})
        self.assertIn("No LoC vocabulary snapshot is retained", target["vocabularyRetention"])

    def test_mapping_omission_addition_or_change_rejects(self):
        value = self.changed()
        value["structureMappings"][0]["fields"].pop()
        self.reject(value)
        value = self.changed()
        value["structureMappings"][1]["fields"][0]["targetPath"] = "object/wrong"
        self.reject(value)
        value = self.changed()
        value["structureMappings"].append(copy.deepcopy(value["structureMappings"][0]))
        self.reject(value)

    def test_vocabulary_and_rights_mutations_reject(self):
        for key in ("objectRoles", "eventTypes", "outcomes", "fixityAlgorithms", "significantProperties"):
            value = self.changed()
            value[key].pop()
            self.reject(value)
        value = self.changed()
        value["rights"]["uses"][0]["targetAct"] = "other"
        self.reject(value)
        value = self.changed()
        value["rights"]["statuses"][3]["isGrant"] = True
        self.reject(value)

    def test_xsd_and_profile_identity_mutations_reject(self):
        for mutate in (
                lambda value: value.update(profileId="OTHER"),
                lambda value: value["target"]["xsd"].update(sha256="0x" + "00" * 32),
                lambda value: value["canonicalization"].update(canonicalizationId="0x" + "00" * 32)):
            value = self.changed()
            mutate(value)
            self.reject(value)

    def test_exact_canonical_and_bounded_input(self):
        with self.assertRaises(MuseumError):
            profile.validate(b" " + profile.EXAMPLE_BYTES)
        with self.assertRaises(MuseumError):
            profile.validate(profile.EXAMPLE_BYTES[:-1] + b',"version":1}')
        with self.assertRaises(MuseumError):
            profile.validate(b"x" * 524289)
        with self.assertRaises(MuseumError):
            profile.validate("not bytes")

    def test_definition_does_not_claim_export_or_ingest_conformance(self):
        gate = profile.example()["roundTripGate"]
        self.assertTrue(gate["required"])
        self.assertFalse(gate["thisDefinitionImplementsExporter"])
        self.assertFalse(gate["thisDefinitionProvesRepositoryIngest"])
        self.assertFalse(gate["institutionalConformance"])


if __name__ == "__main__":
    unittest.main()
