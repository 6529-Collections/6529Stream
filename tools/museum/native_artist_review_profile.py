"""Additive native Artist review documents; no registration or source admission."""

from copy import deepcopy
from pathlib import Path
from types import MappingProxyType

from .account_profile import JCS_ID, JCS_NAME
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .dependencies import Limits, OfflineDocuments
from .independent_wire import RAW_BYTES
from .native_attribution_profile import (
    CROSSWALK as OLD_CROSSWALK, DEFAULT_ROOT, NAME as OLD_NAME,
    POLICY as OLD_POLICY, NativeAttributionProfile,
)
from .review import BODY_SCHEMA_NAME as OLD_BODY_NAME, _validate
from .schemas import ADDRESS, HEX32, IRI, UINT, NAMES as OLD_NAMES, definitions, enum, obj, schemas

NAME = "STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_PROFILE_V1"
NAMES = ("STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_PROFILE_SCHEMA_V1",
         OLD_NAMES[1], "STREAM_NATIVE_ARTIST_REVIEW_EXPORT_V1")
# Native Metadata admits only this original Artist assertion schema. Its exact
# bytes also fix the enclosing assertion's profileSchemaId to the original ID;
# the new interpretation is opt-in through profileHash, not a schema rewrite.
ASSERTION_PROFILE_SCHEMA_ID = schema_id(OLD_NAMES[0])
BODY_NAME = "STREAM_NATIVE_ARTIST_REVIEW_BODY_V1"
POLICY_NAME = "STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_POLICY_V1"
CROSSWALK_NAME = "STREAM_NATIVE_ARTIST_REVIEW_CROSSWALK_V1"
DEPENDENCY_NAME = "STREAM_NATIVE_ARTIST_REVIEW_DEPENDENCIES_V1"
REVIEW_RELATION = "urn:6529stream:semantic-review:v1"
REVIEW_DATATYPE = "urn:6529stream:datatype:semantic-review:v1"
REVIEW_MAPPING_RULE = "urn:6529stream:museum:mapping:native-artist-review-v1"
ARTIST_RECORD_TYPE = schema_id("ARTIST_SEMANTIC_ASSERTION")
MAX_DOCUMENT_BYTES = 524288
QUALIFICATION = (
    "This is an explicit prospective interpretation profile, not a registered-source or chain-acceptance claim. "
    "Historical native Artist identities, signers and operation evidence must be authenticated separately. "
    "Same Artist ID or signer is SELF review and requires explicit opt-in. Distinct Artist IDs and signers permit "
    "only explicitly selected reviewer-account evidence; they establish neither independent humans nor institutional "
    "standing. Current authority, legal effect, professional qualification and a protocol veto are not established. "
    "Full original bytes remain retained. Shared envelope and registered/native definition gates remain mandatory; "
    "semantic admission is individual to each exact /assertions/N pointer and does not claim whole-document "
    "semantic conformance. Malformed unselected sibling assertions or reviews, including duplicate assertion IDs, "
    "cannot veto a valid assertion selected by its complete original selector and pointer."
)
CLAIMS = {
    "newProfileOptInRequiredForBothRecords": True,
    "originalNativeAttributionDocumentsUnchanged": True,
    "originalNativeAssertionSchemaUnchanged": True,
    "v1EntityLayoutRetained": True,
    "typedContinuationSupported": False,
    "wholeDocumentSemanticConformance": False,
    "humanIndependenceProven": False,
    "institutionalStandingProven": False,
    "currentAuthorityProven": False,
    "reviewCreatesProtocolVeto": False,
    "actualChainAcceptance": False,
    "fullObjectDossierConformance": False,
}


def schema_documents():
    result = {}
    for old, new in zip(OLD_NAMES, NAMES):
        if old == new:
            result[new] = dumps(schemas()[old])
            continue
        value = deepcopy(schemas()[old])
        value.update(title=new)
        value["$id"] = "urn:6529stream:schema:" + new
        value["x-stream-schema-id"] = schema_id(new)
        value.setdefault("x-stream-profile", {})["supersedesSchemaId"] = schema_id(old)
        if "profileSchemaId" in value["properties"]:
            value["properties"]["profileSchemaId"] = {"const": schema_id(NAMES[0])}
        result[new] = dumps(value)
    return result


SCHEMAS = schema_documents()
PROFILE_SCHEMA_BYTES = SCHEMAS[NAMES[0]]
ASSERTION_SCHEMA_BYTES = SCHEMAS[NAMES[1]]
EXPORT_SCHEMA_BYTES = SCHEMAS[NAMES[2]]
_selector = deepcopy(definitions()["selector"])
_selector["properties"].update(
    authorizationClass={"const": "ARTIST_SIGNER"}, recordType={"const": ARTIST_RECORD_TYPE},
    pointer={"type": "string", "pattern": "^/assertions/(0|[1-9][0-9]*)$", "maxLength": 32},
)
BODY_SCHEMA = dict(obj({
    "assertionRecord": _selector, "assertionRevisionHash": HEX32, "profileHash": HEX32,
    "mappingRule": IRI, "disposition": enum("reviewed", "rejected"),
    "sourceScope": obj({"chainId": UINT, "core": ADDRESS, "collectionId": UINT,
        "artistRegistry": ADDRESS, "host": ADDRESS}),
    "assertionAuthority": obj({"artistId": HEX32, "signer": ADDRESS,
        "authorityClass": enum("1", "2", "3", "4"), "bindingHash": HEX32,
        "bindingGeneration": dict(UINT, maxLength=20, **{"x-stream-unsigned-bits": 64}),
        "attestationRecordHash": HEX32, "operationEvidenceId": HEX32, "operationEvidenceHash": HEX32,
        "actor": ADDRESS, "grantRecordHash": HEX32}),
}), **{"$schema": "https://json-schema.org/draft/2020-12/schema",
       "$id": "urn:6529stream:schema:" + BODY_NAME, "title": BODY_NAME,
       "x-stream-schema-id": schema_id(BODY_NAME), "x-stream-document-status": "candidate_unregistered",
       "x-stream-semantic-checks": "Shape only: exact native source, authority, scope, opt-in and publication joins are required separately."})
BODY_SCHEMA_BYTES = dumps(BODY_SCHEMA)


def review_literal(body):
    """Encode a strict canonical body; this does not authenticate its assertions."""
    raw = dumps(body)
    _validate(BODY_SCHEMA_BYTES, raw)
    return {"lexicalValue": raw.decode("utf-8"), "datatype": REVIEW_DATATYPE,
            "language": None, "unit": None, "precision": None}


POLICY_BYTES = dumps({"name": POLICY_NAME, "version": "1",
    "nativeRecordType": ARTIST_RECORD_TYPE,
    "optIn": {"bothRecords": "Both original and reviewer records require the exact original STREAM_SEMANTIC_ASSERTION_V1 schema and its original profileSchemaId, with this new profileHash and its separately admitted profile-schema/document closure.",
        "assertionProfileSchemaId": ASSERTION_PROFILE_SCHEMA_ID,
        "interpretationProfileSchemaId": schema_id(NAMES[0]),
        "profileSchemaRole": "The new profile schema describes the separately registered interpretation profile document; it does not replace the original assertion envelope's profileSchemaId.",
        "nativeCompatibility": "ARTIST_SEMANTIC_ASSERTION remains the original native record type. The assertion schema bytes and embedded profileSchemaId are unchanged; no new assertion schema is published or substituted.",
        "oldRecords": "Retain old schemas/profile bytes and their original semantics; no old review literal is promoted into this profile."},
    "source": "Authenticate every original native Metadata Artist record, immutable operation evidence and exact historical authority before semantic selection.",
    "body": {"document": BODY_NAME, "relation": REVIEW_RELATION, "datatype": REVIEW_DATATYPE,
        "mappingRule": REVIEW_MAPPING_RULE,
        "binding": "Exact whole Metadata selector, assertion revision/profile/rule, source scope and all historical authority fields; no shortened or name-only selectors."},
    "reviewer": {"SELF": "same original artistId OR same original signer; explicit allowSelfReview is required, including signer rotations and shared accounts.",
        "distinct": "Both original artistId and signer differ; only explicit selected reviewer account evidence is permitted. This is not independent human or institutional review."},
    "publicationOrder": "Original authenticated blockNumber, transactionIndex and logIndex must precede the selected review lexicographically; createdAt is not publication order.",
    "selection": {"denominator": "Retain every authenticated original before selection, including unsupported or invalid semantic interpretations.",
        "sharedGates": "The complete shared envelope, exact registered definitions and native original/authority joins remain checked before per-assertion admission.",
        "perAssertion": "Each exact /assertions/N pointer has individual original-schema, historical signer and evidence eligibility; admission of one assertion does not claim whole-document semantic conformance.",
        "unselected": "Malformed or hostile unselected sibling assertions and semantic review bodies, targets and revisions are retained diagnostics only and cannot veto a valid selection in the same original document.",
        "selected": "Invalid selected assertions, reviewer bodies or target/revision/scope/authority joins fail selection.",
        "identity": "Complete original selectors and /assertions/N pointers disambiguate duplicate assertion IDs. An unselected duplicate ID cannot poison a selected pointer; ID-only selection is not supported.",
        "conflicts": "Only exact selected source and reviewer sets influence admission; no recency winner or unselected veto.",
        "directStatements": "Direct statements do not acquire an invented reviewer requirement.",
        "disposition": "reviewed or rejected remains the selected account's recorded statement, not a protocol or legal veto."},
    "currentness": "Current identity, signer, binding, dispute or revocation observations are separate qualifications and never replace historical authority.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
CROSSWALK_BYTES = dumps({"name": CROSSWALK_NAME, "version": "1", "sourceSchema": NAMES[1],
    "sourceSchemaHash": keccak256(ASSERTION_SCHEMA_BYTES), "bodySchema": BODY_NAME,
    "bodySchemaHash": keccak256(BODY_SCHEMA_BYTES), "target": "LinguisticObject",
    "content": "Exact original canonical assertion text and field coverage; review disposition stays attributed to its historical signer account.",
    "identity": "Stable Artist ID, signer account, actor and grant are distinct original protocol fields; none is an inferred Person, Group or institution.",
    "entityLayout": "Unchanged V1 entity kinds and fields; no typed continuation semantics.",
    "qualification": QUALIFICATION})
PREDECESSORS = {
    **{new: schema_id(old) for old, new in zip(OLD_NAMES, NAMES) if old != new},
    NAME: schema_id(OLD_NAME), BODY_NAME: schema_id(OLD_BODY_NAME),
    POLICY_NAME: schema_id(OLD_POLICY), CROSSWALK_NAME: schema_id(OLD_CROSSWALK),
    DEPENDENCY_NAME: schema_id("STREAM_ACCOUNT_DEPENDENCIES_V1"),
}


class NativeArtistReviewProfile(NativeAttributionProfile):
    name = NAME
    version = "native-artist-review-1"
    profile_schema_name = NAMES[0]
    assertion_schema_name = NAMES[1]
    assertion_schema_bytes = ASSERTION_SCHEMA_BYTES

    def __init__(self, root=DEFAULT_ROOT, expected_hash=None):
        root = Path(root)
        old = NativeAttributionProfile(root)
        documents = dict(old.documents)
        # The old export schema was not in the original document set. Its exact
        # unchanged bytes are needed to close the new schema predecessor edge.
        documents[OLD_NAMES[2]] = (0, dumps(schemas()[OLD_NAMES[2]]))
        documents.update({name: (0, raw) for name, raw in SCHEMAS.items()})
        documents.update({BODY_NAME: (0, BODY_SCHEMA_BYTES), POLICY_NAME: (3, POLICY_BYTES),
                          CROSSWALK_NAME: (3, CROSSWALK_BYTES)})
        canonicalizations = {name: RAW_BYTES if name == JCS_NAME else JCS_ID for name in documents}
        closure = []
        for subroot, index_path in ((root, "linked-art-v2/validation-index.json"),
                                   (root / "standards", "vocabulary-index.json")):
            index = loads((subroot / index_path).read_bytes(), maximum=MAX_DOCUMENT_BYTES, canonical=True)
            retained = OfflineDocuments(subroot, index)
            for row in index["documents"]:
                raw = retained.load(row["sourceUri"])
                name = "STREAM_MUSEUM_DEPENDENCY_" + keccak256(raw)[2:]
                documents[name] = (3, raw)
                canonicalizations[name] = RAW_BYTES
                closure.append({"sourceUri": row["sourceUri"], "revision": row["revision"],
                    "retrievedAt": row["retrievedAt"], "mediaType": row["mediaType"],
                    "documentName": name, "documentId": schema_id(name),
                    "contentHash": {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": RAW_BYTES},
                    "byteLength": str(len(raw)), "dependencies": row.get("dependencies", [])})
        if not set(PREDECESSORS.values()) <= {schema_id(name) for name in documents}:
            raise MuseumError("native Artist review predecessor closure incomplete")
        documents[DEPENDENCY_NAME] = (3, dumps({"name": DEPENDENCY_NAME, "version": "1",
            "documents": sorted(closure, key=lambda row: (row["sourceUri"], row["documentId"])),
            "registryPredecessors": PREDECESSORS,
            "interpretationDocuments": [{"name": name, "documentId": schema_id(name), "kind": str(kind),
                "contentHash": {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": canonicalizations[name]},
                "byteLength": str(len(raw))} for name, (kind, raw) in sorted(documents.items())],
            "retention": "Exact inherited documents and original upstream bytes; current dependency index and parent profile are excluded from their own commitments."}))
        canonicalizations[DEPENDENCY_NAME] = JCS_ID

        def reference(name):
            raw = documents[name][1]
            return {"path": name + ".json", "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                "canonicalizationId": canonicalizations[name]}, "byteLength": str(len(raw)), "mediaType": "application/json"}

        body = loads(old.profile_bytes, canonical=True)
        body.update(dependencyIndex=reference(DEPENDENCY_NAME), selectionRules=reference(POLICY_NAME),
                    crosswalkDocuments=[reference(CROSSWALK_NAME)], supersedesSchemaId=schema_id(OLD_NAME))
        body["validationDocuments"] += [reference(NAMES[0]), reference(NAMES[1]), reference(NAMES[2]), reference(BODY_NAME)]
        self.profile_bytes = dumps(body)
        _validate(PROFILE_SCHEMA_BYTES, self.profile_bytes)
        self.profile_hash = keccak256(self.profile_bytes)
        if expected_hash is not None and expected_hash != self.profile_hash:
            raise MuseumError("native Artist review profile pin mismatch")
        documents[NAME] = (2, self.profile_bytes)
        canonicalizations[NAME] = JCS_ID
        limits = Limits()
        if (len(documents) > limits.documents or sum(len(raw) for _, raw in documents.values()) > limits.aggregate_bytes
                or sum((len(raw) + limits.chunk_bytes - 1) // limits.chunk_bytes for _, raw in documents.values()) > limits.chunks
                or any(not 0 < len(raw) <= MAX_DOCUMENT_BYTES or len(name.encode("utf-8")) > 128
                       for name, (_, raw) in documents.items())):
            raise MuseumError("native Artist review registered closure bound")
        self.documents = MappingProxyType(documents)
        self.document_canonicalizations = MappingProxyType(canonicalizations)
        self.document_predecessors = MappingProxyType(PREDECESSORS)


def generated_documents(root=DEFAULT_ROOT):
    """Only new candidates; inherited and upstream source files stay untouched."""
    profile = NativeArtistReviewProfile(root)
    names = (NAMES[0], NAMES[2], BODY_NAME, POLICY_NAME, CROSSWALK_NAME, DEPENDENCY_NAME, NAME)
    return {name + ".json": profile.documents[name][1] for name in names}


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    destination = DEFAULT_ROOT / "native-artist-review-profile"
    documents = generated_documents()
    for name, raw in documents.items():
        path = destination / name
        if args.check:
            if not path.is_file() or path.read_bytes() != raw:
                raise MuseumError("native Artist review document differs: " + name)
        else:
            destination.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    profile = NativeArtistReviewProfile()
    print(NAME, profile.profile_hash, len(profile.documents), "prospective documents; no registration or source admission")


if __name__ == "__main__":
    main()
