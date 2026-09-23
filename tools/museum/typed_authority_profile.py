"""New account schema/profile version; old registered bytes remain immutable."""
from copy import deepcopy
from pathlib import Path
from types import MappingProxyType

from . import authority as authority_v1
from .account_profile import AccountProjectionProfile, JCS_ID, JCS_NAME, NAME as OLD_NAME
from .authority_v2 import BODY_SCHEMA_BYTES, DECLARATION_REF, NAME as BODY_NAME, PROFILE as RECONCILIATION_NAME, PROFILE_BYTES
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .dependencies import OfflineDocuments, Limits
from .identity import KINDS
from .independent_wire import RAW_BYTES
from .projection import CRM, ProjectionProfile
from .projection_v2 import ProjectionProfileV2
from .review import _validate
from .schemas import NAMES as OLD_NAMES, TEXT, schemas

NAME = "STREAM_MUSEUM_INDEPENDENT_ACCOUNT_PROFILE_V2"
NAMES = ("STREAM_MUSEUM_SEMANTIC_PROFILE_V2", "STREAM_SEMANTIC_ASSERTION_V2", "STREAM_SEMANTIC_EXPORT_V2")


def schema_documents():
    values = schemas(); result = {}
    for old, new in zip(OLD_NAMES, NAMES):
        value = deepcopy(values[old]); value.update(title=new)
        value["$id"] = "urn:6529stream:schema:" + new
        value["x-stream-schema-id"] = schema_id(new)
        value.setdefault("x-stream-profile", {})["supersedesSchemaId"] = schema_id(old)
        entity = value["$defs"]["entity"]
        entity["properties"]["kind"]["enum"].append("type")
        continuation = deepcopy(DECLARATION_REF)
        continuation["properties"]["rationale"] = dict(TEXT, minLength=1)
        continuation["required"].append("rationale")
        entity["properties"]["continuation"] = {"oneOf": [continuation, {"type": "null"}]}
        entity["required"].append("continuation")
        if "profileSchemaId" in value["properties"]:
            value["properties"]["profileSchemaId"] = {"const": schema_id(NAMES[0])}
        result[new] = dumps(value)
    return result


SCHEMAS = schema_documents()
ASSERTION_SCHEMA_BYTES = SCHEMAS[NAMES[1]]
POLICY_NAME = "STREAM_MUSEUM_INDEPENDENT_ACCOUNT_AUTHORITY_V2"
POLICY_BYTES = dumps({"version": "2", "authority": "Historical independent account only; no named-human, artist, curator or institutional qualification.",
    "review": "Explicit selected same-account SELF review of exact assertion revision, profile and mapping rule; never independent human review.",
    "declarations": "Type is a new supplemental entity kind. Continuations require exact prior selector/hash, stable ID/kind/account and a maximum of eight prior links. No implicit IRI reuse or kind conversion.",
    "authorityMappings": "V2 body binds a same-record entity pointer or an exact prior-record declaration; unsupported/ambiguous/weak claims remain attributed.",
    "oldVersions": "Old schema/profile documents remain byte-identical and are checked under their original hashes. Cross-version references do not upgrade their meaning.",
    "limits": {"selectedPayloadBytes": "8192", "records": "512", "continuationLinks": "8"}})
PREDECESSORS = {**{new: schema_id(old_name) for old_name, new in zip(OLD_NAMES, NAMES)},
    NAME: schema_id(OLD_NAME), POLICY_NAME: schema_id("STREAM_MUSEUM_INDEPENDENT_ACCOUNT_AUTHORITY_V1"),
    "STREAM_ACCOUNT_CROSSWALK_V2": schema_id("STREAM_ACCOUNT_CROSSWALK_V1"),
    "STREAM_ACCOUNT_DEPENDENCIES_V2": schema_id("STREAM_ACCOUNT_DEPENDENCIES_V1"),
    BODY_NAME: schema_id(authority_v1.NAME), RECONCILIATION_NAME: schema_id(authority_v1.PROFILE)}


class TypedAuthorityProfile(ProjectionProfileV2):
    version = "account-2"
    name = NAME
    profile_schema_name = NAMES[0]
    assertion_schema_name = NAMES[1]
    assertion_schema_bytes = ASSERTION_SCHEMA_BYTES
    entity_kinds = KINDS | {"type"}
    classes = ProjectionProfileV2.classes | {"type": ("Type", CRM + "E55_Type")}

    def __init__(self, root: Path, *, expected_hash=None):
        old = AccountProjectionProfile(root)
        self.old_profile_hash = old.profile_hash
        crosswalk = loads(old.crosswalk_bytes, canonical=True)
        crosswalk.update(version="account-2", scope="Versioned typed independent-account projection; no broader author authority.")
        for row in crosswalk["rules"]:
            row["additionalSourceSchemas"] = [{"schemaId": schema_id(NAMES[1]), "schemaHash": keccak256(ASSERTION_SCHEMA_BYTES)}]
        crosswalk["rules"].append(crosswalk["rules"][0] | {"rule": self.rule_prefix + "kind:type",
            "sourceSchemaId": schema_id(NAMES[1]), "sourceSchemaHash": keccak256(ASSERTION_SCHEMA_BYTES), "additionalSourceSchemas": [],
            "sourceSubjectKind": "type", "targetClass": CRM + "E55_Type", "targetPath": "/type",
            "transformation": "Explicit V2 Type declaration only; old entity schemas remain unchanged.",
            "positiveTest": "test_typed_profile_projects_declared_type", "negativeTest": "test_old_schema_rejects_type"})
        self.crosswalk_bytes = dumps(crosswalk); self.crosswalk_hash = keccak256(self.crosswalk_bytes)
        validation = (root / "linked-art-v2/validation-policy.json").read_bytes()
        vocabulary = (root / "standards/vocabulary-policy.json").read_bytes()
        ProjectionProfile.__init__(self, root, self.crosswalk_bytes, crosswalk_hash=self.crosswalk_hash,
            validation_hash=keccak256(validation), vocabulary_hash=keccak256(vocabulary))
        documents = dict(old.documents)
        documents[OLD_NAMES[2]] = (0, dumps(schemas()[OLD_NAMES[2]]))
        documents.update({authority_v1.NAME: (0, authority_v1.BODY_SCHEMA_BYTES), authority_v1.PROFILE: (3, authority_v1.PROFILE_BYTES)})
        documents.update({name: (0, raw) for name, raw in SCHEMAS.items()})
        documents.update({BODY_NAME: (0, BODY_SCHEMA_BYTES), RECONCILIATION_NAME: (3, PROFILE_BYTES),
            POLICY_NAME: (3, POLICY_BYTES), "STREAM_ACCOUNT_CROSSWALK_V2": (3, self.crosswalk_bytes)})
        canonicalizations = {name: RAW_BYTES if name == JCS_NAME else JCS_ID for name in documents}
        closure = []
        for subroot, index_path in ((root, "linked-art-v2/validation-index.json"), (root / "standards", "vocabulary-index.json")):
            index = loads((subroot / index_path).read_bytes(), maximum=524288, canonical=True)
            retained = OfflineDocuments(subroot, index)
            for row in index["documents"]:
                raw = retained.load(row["sourceUri"])
                name = "STREAM_MUSEUM_DEPENDENCY_" + keccak256(raw)[2:]
                documents[name] = (3, raw); canonicalizations[name] = RAW_BYTES
                closure.append({"sourceUri": row["sourceUri"], "revision": row["revision"], "retrievedAt": row["retrievedAt"],
                    "mediaType": row["mediaType"], "documentId": schema_id(name), "documentName": name,
                    "contentHash": {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": RAW_BYTES},
                    "byteLength": str(len(raw)), "dependencies": row.get("dependencies", [])})
        dependency_name = "STREAM_ACCOUNT_DEPENDENCIES_V2"
        registered_ids = {schema_id(name) for name in documents}
        if not set(PREDECESSORS.values()) <= registered_ids:
            raise MuseumError("typed authority predecessor closure is incomplete")
        documents[dependency_name] = (3, dumps({"version": "2", "documents": sorted(closure, key=lambda r: (r["sourceUri"], r["documentId"])),
            "registryPredecessors": PREDECESSORS,
            "interpretationDocuments": [{"name": name, "documentId": schema_id(name), "kind": str(kind),
                "contentHash": {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": canonicalizations[name]},
                "byteLength": str(len(raw))} for name, (kind, raw) in sorted(documents.items())],
            "retention": "Exact upstream bytes are registered through bounded document chunks; no live dependency resolution."}))
        canonicalizations[dependency_name] = JCS_ID
        def reference(name):
            raw = documents[name][1]
            return {"path": name + ".json", "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                "canonicalizationId": canonicalizations[name]}, "byteLength": str(len(raw)), "mediaType": "application/json"}
        body = loads(old.profile_bytes, canonical=True)
        body.update(dependencyIndex=reference(dependency_name), selectionRules=reference(POLICY_NAME),
            crosswalkDocuments=[reference("STREAM_ACCOUNT_CROSSWALK_V2"), reference(RECONCILIATION_NAME)],
            supersedesSchemaId=schema_id(OLD_NAME))
        body["validationDocuments"] += [reference(NAMES[1]), reference(NAMES[2]), reference(BODY_NAME)]
        self.profile_bytes = dumps(body); _validate(SCHEMAS[NAMES[0]], self.profile_bytes)
        self.profile_hash = keccak256(self.profile_bytes)
        if expected_hash is not None and self.profile_hash != expected_hash: raise MuseumError("typed authority profile pin mismatch")
        documents[NAME] = (2, self.profile_bytes); canonicalizations[NAME] = JCS_ID
        limits = Limits()
        if (len(documents) > limits.documents or sum(len(raw) for _, raw in documents.values()) > limits.aggregate_bytes
            or sum((len(raw) + 8191) // 8192 for _, raw in documents.values()) > limits.chunks
            or any(not 0 < len(raw) <= 524288 or len(name.encode()) > 128 for name, (_, raw) in documents.items())):
            raise MuseumError("typed authority registered closure bound")
        self.documents = MappingProxyType(documents)
        self.document_canonicalizations = MappingProxyType(canonicalizations)
        self.document_predecessors = MappingProxyType(PREDECESSORS)
        self.identity = dumps({**loads(self.identity), "accountAuthorityPolicyHash": keccak256(POLICY_BYTES),
            "registeredProfileContentHash": self.profile_hash})

    def assertion_rules(self):
        from .review import ASSERTION_SCHEMA_BYTES as old_assertion
        return {schema_id(OLD_NAMES[1]): (old_assertion, schema_id(OLD_NAMES[0]), self.old_profile_hash),
                schema_id(NAMES[1]): (ASSERTION_SCHEMA_BYTES, schema_id(NAMES[0]), self.profile_hash)}


def main():
    import argparse
    p = argparse.ArgumentParser(description=__doc__); p.add_argument("--check", action="store_true"); args = p.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum"; profile = TypedAuthorityProfile(root)
    target = root / "typed-account-profile"; old_names = AccountProjectionProfile(root).documents
    for name, (_, raw) in profile.documents.items():
        # Existing and upstream bytes are retained through their existing exact files and generated closure index.
        if name.startswith("STREAM_MUSEUM_DEPENDENCY_") or name in old_names: continue
        path = target / (name + ".json")
        if args.check:
            if path.read_bytes() != raw: raise MuseumError("typed profile document differs: " + name)
        else: target.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print(NAME, profile.profile_hash, len(profile.documents))


if __name__ == "__main__": main()
