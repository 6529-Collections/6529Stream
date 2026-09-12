"""Generate candidate canonical schema documents; never register them onchain."""

import argparse
from pathlib import Path

from .canonical import dumps, schema_id

ROOT = Path(__file__).resolve().parents[2]
NAMES = ("STREAM_MUSEUM_SEMANTIC_PROFILE_V1", "STREAM_SEMANTIC_ASSERTION_V1",
         "STREAM_SEMANTIC_EXPORT_V1")


def obj(properties, required=None):
    return {"type": "object", "properties": properties, "additionalProperties": False,
            "required": list(properties) if required is None else required}


def arr(items, minimum=0, maximum=512):
    return {"type": "array", "items": items, "minItems": minimum, "maxItems": maximum}


def ref(name):
    return {"$ref": "#/$defs/" + name}


TEXT = {"type": "string", "maxLength": 16384}
IRI = {"type": "string", "pattern": "^[A-Za-z][A-Za-z0-9+.-]*:[^\\s]+$", "maxLength": 2048}
HEX32 = {"type": "string", "pattern": "^0x[0-9a-f]{64}$"}
ADDRESS = {"type": "string", "pattern": "^0x[0-9a-f]{40}$"}
UINT = {"type": "string", "pattern": "^(0|[1-9][0-9]*)$", "maxLength": 78,
        "x-stream-unsigned-bits": 256}
TIME = {"type": "string", "format": "date-time"}


def enum(*values):
    return {"enum": list(values)}


def definitions():
    return {
        "hashRef": obj({"algorithm": dict(UINT, maxLength=5, **{"x-stream-unsigned-bits": 16}),
                        "digest": {"type": "string", "pattern": "^0x(?:[0-9a-f]{2}){1,128}$"},
                        "canonicalizationId": HEX32}),
        "subject": obj({"kind": enum("collection", "token", "media", "scope"),
                        "subjectId": HEX32}),
        "selector": obj({"recordHash": HEX32, "subjectId": HEX32, "schemaId": HEX32,
                         "schemaHash": HEX32, "recordType": HEX32, "host": ADDRESS, "recorder": ADDRESS,
                         "authorizationClass": enum("ARTIST_SIGNER", "OWNER_SIGNER", "CURATOR_SIGNER",
                                                    "INSTITUTION_SIGNER", "INDEPENDENT_ATTESTOR",
                                                    "PRESERVATION_ADMIN", "METADATA_ADMIN", "GLOBAL_ADMIN"),
                         "pointer": {"type": "string", "pattern": "^(/([^~]|~[01])*)*$"},
                         "recordIndex": dict(UINT, maxLength=20, **{"x-stream-unsigned-bits": 64}),
                         "recordChainHash": HEX32}),
        "document": obj({"path": {"type": "string", "maxLength": 1024},
                         "contentHash": ref("hashRef"), "byteLength": UINT,
                         "mediaType": TEXT}),
        "evidence": obj({"source": ref("hashRef"),
                         "selectorType": enum("json_pointer", "document_page", "media_time", "whole_document"),
                         "selector": TEXT,
                         "basis": enum("documentary_evidence", "own_signed_statement")}),
        "date": obj({"expression": TEXT, "precision": enum("exact", "range", "approximate", "unknown"),
                     "calendar": TEXT, "timezone": {"type": ["string", "null"]},
                     "earliest": {"type": ["string", "null"]},
                     "latest": {"type": ["string", "null"]}}),
        "name": obj({"value": TEXT, "language": {"type": ["string", "null"]},
                     "kind": enum("preferred", "alternate", "historical", "identifier")}),
        "entity": obj({"id": IRI, "kind": enum("abstract_work", "visual_content", "information_object",
                           "token", "digital_object", "physical_object", "realization", "person", "group",
                           "place", "event", "statement", "set"),
                       "names": arr(ref("name")), "declaringAgent": IRI,
                       "sourceRecords": arr(ref("selector"), 1),
                       "predecessors": arr(IRI)}),
        "literal": obj({"lexicalValue": TEXT, "datatype": IRI,
                        "language": {"type": ["string", "null"]},
                        "unit": {"type": ["string", "null"]},
                        "precision": {"type": ["string", "null"]}}),
        "review": obj({"reviewRecord": ref("selector"), "assertionRecord": ref("selector"), "assertionRevisionHash": HEX32,
                       "profileHash": HEX32, "mappingRule": IRI, "reviewer": IRI,
                       "reviewedAt": TIME, "selfReview": {"type": "boolean"}}),
        "assertion": obj({"id": IRI, "subject": IRI, "relation": IRI,
                          "object": {"oneOf": [obj({"entity": IRI}), obj({"literal": ref("literal")})]},
                          "assertingAgent": IRI, "createdAt": TIME,
                          "evidence": arr(ref("evidence"), 1),
                          "origin": enum("direct_statement", "human_mapping", "automated_mapping", "derived_projection"),
                          "reviewStatus": enum("unreviewed", "reviewed", "disputed", "withdrawn"),
                          "mappingRule": IRI, "rationale": TEXT,
                          "effectiveDate": ref("date"), "reviewEvidence": arr(ref("review")),
                          "corrects": arr(IRI), "disputes": arr(IRI)},
                         ["id", "subject", "relation", "object", "assertingAgent", "createdAt", "evidence",
                          "origin", "reviewStatus", "mappingRule", "rationale", "reviewEvidence", "corrects", "disputes"]),
        "alignment": obj({"entityId": IRI, "authority": enum("GETTY_TGN", "GETTY_AAT", "GETTY_ULAN", "VIAF", "WIKIDATA"),
                          "identifier": TEXT, "canonicalIri": IRI,
                          "focusIri": {"type": ["string", "null"]},
                          "matchKind": enum("equivalent_entity", "close_match", "related_reference"),
                          "snapshotRef": ref("document"), "retrievedAt": TIME,
                          "authorityRevision": TEXT, "labelAtReview": ref("name"),
                          "basis": TEXT, "assertionId": IRI}),
        "sourceState": obj({"chainId": UINT, "core": ADDRESS, "collectionId": UINT,
                            "tokenId": {"oneOf": [UINT, {"type": "null"}]},
                            "anchorSubject": ref("subject"), "canonicalCitation": TEXT,
                            "blockNumber": UINT, "blockHash": HEX32,
                            "finalityQualifier": TEXT, "recordHeads": arr(ref("selector")),
                            "disclosurePolicyHash": HEX32}),
        "crosswalk": obj({"id": IRI, "sourceSchemaId": HEX32, "sourceSchemaHash": HEX32,
                          "sourceSelector": TEXT, "subjectKind": TEXT,
                          "targetClass": IRI, "propertyPath": arr(IRI), "cardinality": TEXT,
                          "transformation": IRI, "authorityRule": IRI,
                          "controlledTerms": arr(IRI), "uncertaintyRule": IRI,
                          "reverseCorrespondence": TEXT, "positiveTest": TEXT, "negativeTest": TEXT}),
    }


def schemas():
    common = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$defs": definitions()}
    profile = obj({"standards": obj({"cidocCrm": {"const": "7.1.3"},
                                     "linkedArtModel": {"const": "1.0.0"}, "jsonLd": {"const": "1.1"}}),
                   "dependencyIndex": ref("document"), "crosswalkDocuments": arr(ref("document"), 1),
                   "selectionRules": ref("document"), "validationDocuments": arr(ref("document"), 1),
                   "classPropertyTables": arr(ref("document"), 1), "termCatalogs": arr(ref("document")),
                   "limits": obj({"recordPayloadBytes": {"const": "24576"},
                                  "sstore2DataBytes": {"const": "24575"},
                                  "rawChunkBytes": {"const": "8192"}, "documents": {"const": "512"},
                                  "chunks": {"const": "4096"}, "aggregateBytes": {"const": "16777216"},
                                  "referenceDepth": {"const": "8"}, "jsonDepth": {"const": "64"}}),
                   "supersedesSchemaId": {"oneOf": [HEX32, {"type": "null"}]}})
    assertion = obj({"profileSchemaId": {"const": schema_id(NAMES[0])}, "profileHash": HEX32,
                     "anchorSubject": ref("subject"), "entities": arr(ref("entity")),
                     "assertions": arr(ref("assertion"), 1), "sourceRecords": arr(ref("selector"), 1),
                     "authorityAlignments": arr(ref("alignment"))})
    export = obj({"profileSchemaId": {"const": schema_id(NAMES[0])}, "profileHash": HEX32,
                  "sourceState": ref("sourceState"), "selectionPolicyHash": HEX32,
                  "sourceAuthoritySet": arr(ref("selector")), "reviewerAuthoritySet": arr(ref("selector")),
                  "components": obj({k: ref("document") for k in ("entityIndex", "assertions", "provenance",
                      "authoritySnapshots", "dependencyLock", "coverage", "validation", "identityCorrespondence")}),
                  "resources": arr(ref("document")),
                  "completeness": enum("complete_for_profile", "complete_with_stream_extensions", "incomplete"),
                  "conformance": obj({"streamProfile": enum("pass", "fail", "not_evaluated"),
                                      "linkedArtModel": enum("pass", "fail", "not_evaluated"),
                                      "linkedArtApi": enum("pass", "fail", "not_claimed")}),
                  "previousExport": {"oneOf": [ref("document"), {"type": "null"}]}})
    results = {}
    for name, body in zip(NAMES, (profile, assertion, export)):
        results[name] = dict(common, **body, title=name, **{
            "$id": "urn:6529stream:schema:" + name,
            "x-stream-schema-id": schema_id(name),
            "x-stream-document-status": "candidate_unregistered",
            "x-stream-semantic-checks": "Shape validation does not establish authority, hash joins or conformance."})
    results[NAMES[0]]["x-stream-profile"] = {
        "standardVersions": {"cidocCrm": "7.1.3", "linkedArtModel": "1.0.0", "jsonLd": "1.1"},
        "interpretationDocuments": "Pinned document commitments are required before registration; candidate incomplete.",
        "hashGraph": "No committed dependency may contain its parent profileHash.",
        "gateStatus": {"MSM-" + str(i).zfill(2): "pending" for i in range(1, 13)}}
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    destination = ROOT / "schemas/museum"
    destination.mkdir(parents=True, exist_ok=True)
    for name, schema in schemas().items():
        path = destination / (name + ".json")
        data = dumps(schema)
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                raise SystemExit("stale museum schema: " + name)
        else:
            path.write_bytes(data)
        print(name, schema_id(name), len(data))


if __name__ == "__main__":
    main()
