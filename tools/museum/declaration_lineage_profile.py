"""Additive account V3 definitions for authenticated declaration lineage.

Generating these documents does not register them or authenticate a capture.
"""
from copy import deepcopy
from pathlib import Path
from types import MappingProxyType

from .account_profile import JCS_ID
from .authority_v2 import DECLARATION_REF
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .dependencies import Limits
from .projection import ProjectionProfile
from .review import _validate
from .schemas import IRI, TEXT, arr, enum, obj
from .typed_authority_profile import TypedAuthorityProfile, SCHEMAS as V2_SCHEMAS, NAMES as V2_NAMES, NAME as V2_NAME

NAME = "STREAM_MUSEUM_INDEPENDENT_ACCOUNT_PROFILE_V3"
NAMES = ("STREAM_MUSEUM_SEMANTIC_PROFILE_V3", "STREAM_SEMANTIC_ASSERTION_V3", "STREAM_SEMANTIC_EXPORT_V3")
POLICY_NAME = "STREAM_MUSEUM_INDEPENDENT_ACCOUNT_AUTHORITY_V3"
CROSSWALK_NAME = "STREAM_ACCOUNT_CROSSWALK_V3"
DEPENDENCIES_NAME = "STREAM_ACCOUNT_DEPENDENCIES_V3"
LINEAGE = obj({"operation": enum("correction", "merge", "split"),
    "predecessors": arr(deepcopy(DECLARATION_REF), 1, 16), "successors": arr(IRI, 0, 16),
    "rationale": dict(TEXT, minLength=1)})


def schema_documents():
    result = {}
    for old, new in zip(V2_NAMES, NAMES):
        value = loads(V2_SCHEMAS[old], canonical=True)
        value.update(title=new)
        value["$id"] = "urn:6529stream:schema:" + new
        value["x-stream-schema-id"] = schema_id(new)
        value["x-stream-profile"]["supersedesSchemaId"] = schema_id(old)
        entity = value["$defs"]["entity"]
        entity["properties"]["continuation"] = {"type": "null"}
        entity["properties"]["lineage"] = {"oneOf": [deepcopy(LINEAGE), {"type": "null"}]}
        entity["required"].append("lineage")
        if "profileSchemaId" in value["properties"]:
            value["properties"]["profileSchemaId"] = {"const": schema_id(NAMES[0])}
        result[new] = dumps(value)
    return result


SCHEMAS = schema_documents()
ASSERTION_SCHEMA_BYTES = SCHEMAS[NAMES[1]]
POLICY_BYTES = dumps({"version": "3",
    "authority": "Historical independent account only. Each predecessor and successor must have the same authenticated declaring account and kind. No ownership, named-human, artist or institutional authority is inferred.",
    "review": "Original account-only selection rules apply. Lineage never redirects an assertion, a review, an authority mapping or its original profile/revision.",
    "correction": "One exact earlier declaration, same stable ID. Select the corrected declaration explicitly; competing selected declarations remain ambiguous.",
    "merge": "Two to sixteen distinct predecessor IDs become one new ID of the same kind. No equivalence inference or deletion of predecessors.",
    "split": "One predecessor becomes two to sixteen new IDs in one authenticated payload with identical reciprocal lineage and a complete unique successor cohort.",
    "evidence": "Every edge cites the exact earlier original selector and canonical declaration hash in entity and payload sourceRecords. Predecessor IDs exactly match those declarations. Original subjects, records, bytes, authority and publication positions are retained.",
    "oldVersions": "V1/V2 documents and their original profile hashes remain exact; V2 continuations retain their old meaning.",
    "limits": {"lineageDepth": "8", "lineageNodes": "512", "operationArity": "16", "payloadBytes": "8192"}})


class DeclarationLineageProfile(TypedAuthorityProfile):
    version = "account-3"
    name = NAME
    profile_schema_name = NAMES[0]
    assertion_schema_name = NAMES[1]
    assertion_schema_bytes = ASSERTION_SCHEMA_BYTES

    def __init__(self, root: Path, *, expected_hash=None):
        old = TypedAuthorityProfile(root)
        self._old_rules = old.assertion_rules()
        crosswalk = loads(old.crosswalk_bytes, maximum=524288, canonical=True)
        crosswalk.update(version=self.version, scope="Explicit account declaration corrections, merges and splits; original claims and predecessor identities remain attributed.")
        for row in crosswalk["rules"]:
            row.setdefault("additionalSourceSchemas", []).append({"schemaId": schema_id(NAMES[1]),
                "schemaHash": keccak256(ASSERTION_SCHEMA_BYTES)})
        self.crosswalk_bytes = dumps(crosswalk)
        self.crosswalk_hash = keccak256(self.crosswalk_bytes)
        ProjectionProfile.__init__(self, root, self.crosswalk_bytes, crosswalk_hash=self.crosswalk_hash,
            validation_hash=keccak256((root / "linked-art-v2/validation-policy.json").read_bytes()),
            vocabulary_hash=keccak256((root / "standards/vocabulary-policy.json").read_bytes()))
        documents = dict(old.documents)
        canonicalizations = dict(old.document_canonicalizations)
        predecessors = dict(old.document_predecessors)
        predecessors.update({**{new: schema_id(previous) for previous, new in zip(V2_NAMES, NAMES)},
            NAME: schema_id(V2_NAME), POLICY_NAME: schema_id("STREAM_MUSEUM_INDEPENDENT_ACCOUNT_AUTHORITY_V2"),
            CROSSWALK_NAME: schema_id("STREAM_ACCOUNT_CROSSWALK_V2"),
            DEPENDENCIES_NAME: schema_id("STREAM_ACCOUNT_DEPENDENCIES_V2")})
        documents.update({name: (0, raw) for name, raw in SCHEMAS.items()})
        documents.update({POLICY_NAME: (3, POLICY_BYTES), CROSSWALK_NAME: (3, self.crosswalk_bytes)})
        canonicalizations.update({name: JCS_ID for name in (*NAMES, POLICY_NAME, CROSSWALK_NAME)})
        old_index = loads(old.documents["STREAM_ACCOUNT_DEPENDENCIES_V2"][1], maximum=524288, canonical=True)
        documents[DEPENDENCIES_NAME] = (3, dumps({"version": "3", "documents": old_index["documents"],
            "registryPredecessors": predecessors,
            "interpretationDocuments": [{"name": name, "documentId": schema_id(name), "kind": str(kind),
                "contentHash": {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": canonicalizations[name]},
                "byteLength": str(len(raw))} for name, (kind, raw) in sorted(documents.items())],
            "retention": old_index["retention"]}))
        canonicalizations[DEPENDENCIES_NAME] = JCS_ID

        def reference(name):
            raw = documents[name][1]
            return {"path": name + ".json", "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                "canonicalizationId": canonicalizations[name]}, "byteLength": str(len(raw)), "mediaType": "application/json"}

        body = loads(old.profile_bytes, canonical=True)
        body.update(dependencyIndex=reference(DEPENDENCIES_NAME), selectionRules=reference(POLICY_NAME),
            crosswalkDocuments=[reference(CROSSWALK_NAME), *body["crosswalkDocuments"][1:]],
            supersedesSchemaId=schema_id(V2_NAME))
        body["validationDocuments"] += [reference(NAMES[1]), reference(NAMES[2])]
        self.profile_bytes = dumps(body)
        _validate(SCHEMAS[NAMES[0]], self.profile_bytes)
        self.profile_hash = keccak256(self.profile_bytes)
        if expected_hash is not None and expected_hash != self.profile_hash:
            raise MuseumError("declaration lineage profile pin mismatch")
        documents[NAME] = (2, self.profile_bytes)
        canonicalizations[NAME] = JCS_ID
        limits = Limits()
        if (len(documents) > limits.documents or sum(len(raw) for _, raw in documents.values()) > limits.aggregate_bytes
            or sum((len(raw) + 8191) // 8192 for _, raw in documents.values()) > limits.chunks
            or any(not 0 < len(raw) <= 524288 or len(name.encode()) > 128 for name, (_, raw) in documents.items())
            or not set(predecessors.values()) <= {schema_id(name) for name in documents}):
            raise MuseumError("declaration lineage registered closure bound")
        self.documents = MappingProxyType(documents)
        self.document_canonicalizations = MappingProxyType(canonicalizations)
        self.document_predecessors = MappingProxyType(predecessors)
        self.identity = dumps({**loads(self.identity), "accountAuthorityPolicyHash": keccak256(POLICY_BYTES),
            "registeredProfileContentHash": self.profile_hash})

    def assertion_rules(self):
        return {**self._old_rules,
            schema_id(NAMES[1]): (ASSERTION_SCHEMA_BYTES, schema_id(NAMES[0]), self.profile_hash)}


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum"
    profile = DeclarationLineageProfile(root)
    target = root / "declaration-lineage-profile"
    old_names = TypedAuthorityProfile(root).documents
    for name, (_, raw) in profile.documents.items():
        if name in old_names:
            continue
        path = target / (name + ".json")
        if args.check:
            if path.read_bytes() != raw:
                raise MuseumError("declaration lineage document differs: " + name)
        else:
            target.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(NAME, profile.profile_hash, len(profile.documents))


if __name__ == "__main__":
    main()
