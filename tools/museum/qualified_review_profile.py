"""Prospective registered account-review profile; prior documents keep their meaning.

Document construction is not registration, source authentication or selection.
The separate resolver must authenticate every selected original and review.
"""

from pathlib import Path
from types import MappingProxyType

from .account_profile import JCS_ID
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .dependencies import Limits
from .projection import ProjectionProfile
from .review import _validate
from . import typed_authority_profile as typed


NAME = "STREAM_MUSEUM_QUALIFIED_ACCOUNT_REVIEW_PROFILE_V1"
NAMES = (
    "STREAM_MUSEUM_QUALIFIED_REVIEW_PROFILE_SCHEMA_V1",
    "STREAM_QUALIFIED_REVIEW_ASSERTION_V1",
    "STREAM_QUALIFIED_REVIEW_EXPORT_V1",
)
POLICY_NAME = "STREAM_MUSEUM_QUALIFIED_ACCOUNT_REVIEW_POLICY_V1"
CROSSWALK_NAME = "STREAM_QUALIFIED_ACCOUNT_REVIEW_CROSSWALK_V1"
DEPENDENCY_NAME = "STREAM_QUALIFIED_ACCOUNT_REVIEW_DEPENDENCIES_V1"
SELECTION_MODE = "qualified_recorded_account_selection"
MODEL_ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
DIRECTORY = "qualified-account-review-profile"

QUALIFICATION = (
    "Authenticated historical accounts qualified only by the selected dossier policy. "
    "Distinct accounts do not establish distinct or independent humans, professional "
    "competence, institutional standing or current signing authority. This prospective "
    "document set proves no registration, source capture, chain acceptance or full Museum conformance."
)
POLICY_BYTES = dumps({
    "name": POLICY_NAME, "version": "1", "selectionMode": SELECTION_MODE,
    "qualificationMode": "authenticated_account_under_selected_policy",
    "source": "Exact original independent-lane class5 records at one authenticated chain/Core/collection/source anchor; complete selectors, payloads, schemas, profiles and historical receipts remain separate commitments.",
    "authority": "Manifest-bound sourceAuthoritySet/reviewerAuthoritySet selectors have exact sourceAdmissions/reviewAdmissions binding original family/class, authenticated principal and complete scope. Merely listing an address, a name, an IRI or reviewed status creates no authority. Profile registration grants no authority over source content.",
    "newProfileRequiredForMappingsAndReviews": True,
    "review": "A qualifying review is the reviewer's separately published direct statement using the unchanged semantic-review V1 relation, datatype, mapping rule and canonical literal. It binds the complete original selector and pointer, exact assertion revision hash, original profile hash and mapping rule. Original authenticated publication must precede review publication; createdAt never substitutes for that order.",
    "selfReview": "Derive SELF from authenticated account principals and require explicit selection-policy opt-in. Label it author-confirmed SELF review. Neither SELF nor different-account review satisfies independent-human review.",
    "independentHumanReview": "unsupported; an independent-human requirement must refuse rather than infer independence from account separation",
    "selection": "Omit withdrawn claims from selection and withhold self-declared disputed claims. Only eligible direct statements and mappings with an admitted authenticated approval enter the default graph. Withdrawn or disputed reviews remain retained but cannot qualify mappings. Qualified means admitted under this exact dossier policy, not a professional or human identity credential.",
    "conflicts": "Opposing admitted dispositions withhold, including rejection-only outcomes. Conflicting eligible single-valued claims withhold within exact chain/Core/host/collection/subject/token/media scope plus entity/relation; no recency winner. Unselected opaque records are not interpreted, and their disputes retain original bytes and attribution in the sidecar and report but cannot veto. A later disposition needs its own exact admission under the selected policy.",
    "declarations": "Retain the typed V2 continuation layout and exact same-account prior selector/hash/ID/kind checks. A declaration continuation never redirects an old assertion review or transfers its approval.",
    "oldVersions": "Retain V1/V2 documents, hashes and assertion rules byte-for-byte. Their original SELF-only and cross-account restrictions remain. New mappings and qualifying reviews opt into this new profile; older records remain evidence or direct attributed sources without upgraded meaning.",
    "firewall": "Dossier selection only: no write authority, independent-lane gate, protocol veto, record mutation or tokenURI/renderer change.",
    "limits": {"selectedPayloadBytes": "8192", "records": "512", "continuationLinks": "8"},
    "qualification": QUALIFICATION,
})


def schema_documents():
    result = {}
    for previous, name in zip(typed.NAMES, NAMES):
        value = loads(typed.SCHEMAS[previous], canonical=True)
        value.update(title=name)
        value["$id"] = "urn:6529stream:schema:" + name
        value["x-stream-schema-id"] = schema_id(name)
        value.setdefault("x-stream-profile", {})["supersedesSchemaId"] = schema_id(previous)
        if "profileSchemaId" in value["properties"]:
            value["properties"]["profileSchemaId"] = {"const": schema_id(NAMES[0])}
        result[name] = dumps(value)
    return result


SCHEMAS = schema_documents()
ASSERTION_SCHEMA_BYTES = SCHEMAS[NAMES[1]]
PREDECESSORS = {
    **{name: schema_id(previous) for previous, name in zip(typed.NAMES, NAMES)},
    NAME: schema_id(typed.NAME), POLICY_NAME: schema_id(typed.POLICY_NAME),
    CROSSWALK_NAME: schema_id("STREAM_ACCOUNT_CROSSWALK_V2"),
    DEPENDENCY_NAME: schema_id("STREAM_ACCOUNT_DEPENDENCIES_V2"),
}


class QualifiedAccountReviewProfile(typed.TypedAuthorityProfile):
    name = NAME
    version = "qualified-account-review-1"
    profile_schema_name = NAMES[0]
    assertion_schema_name = NAMES[1]
    assertion_schema_bytes = ASSERTION_SCHEMA_BYTES

    def __init__(self, root=MODEL_ROOT, *, expected_hash=None):
        root = Path(root)
        super().__init__(root)
        # Capture inherited rules BEFORE replacing self.profile_hash; using the
        # inherited method afterwards would relabel the V2 rule with our hash.
        self._retained_assertion_rules = MappingProxyType(dict(super().assertion_rules()))
        self.typed_profile_hash = self.profile_hash
        documents = dict(self.documents)
        canonicalizations = dict(self.document_canonicalizations)
        predecessors = dict(self.document_predecessors) | PREDECESSORS
        old_index = loads(documents["STREAM_ACCOUNT_DEPENDENCIES_V2"][1], maximum=524288, canonical=True)
        body = loads(self.profile_bytes, canonical=True)
        crosswalk = loads(self.crosswalk_bytes, maximum=524288, canonical=True)
        crosswalk.update(version=self.version,
            scope="Policy-qualified historical independent-account review; old source profiles retain their exact restrictions. No independent-human or full Museum claim.")
        admitted = {"schemaId": schema_id(NAMES[1]), "schemaHash": keccak256(ASSERTION_SCHEMA_BYTES)}
        for row in crosswalk["rules"]:
            row["additionalSourceSchemas"] = [*row.get("additionalSourceSchemas", []), dict(admitted)]
            row["authorityRule"] = "exact_registered_source_profile_and_manifest_bound_authenticated_account_review_policy"
        self.crosswalk_bytes = dumps(crosswalk)
        self.crosswalk_hash = keccak256(self.crosswalk_bytes)
        validation = (root / "linked-art-v2/validation-policy.json").read_bytes()
        vocabulary = (root / "standards/vocabulary-policy.json").read_bytes()
        ProjectionProfile.__init__(self, root, self.crosswalk_bytes, crosswalk_hash=self.crosswalk_hash,
            validation_hash=keccak256(validation), vocabulary_hash=keccak256(vocabulary))
        documents.update({name: (0, raw) for name, raw in SCHEMAS.items()})
        documents[POLICY_NAME] = (3, POLICY_BYTES)
        documents[CROSSWALK_NAME] = (3, self.crosswalk_bytes)
        canonicalizations.update({name: JCS_ID for name in (*NAMES, POLICY_NAME, CROSSWALK_NAME)})
        if not set(predecessors.values()) <= {schema_id(name) for name in documents}:
            raise MuseumError("qualified review predecessor closure is incomplete")
        # The parent profile and its dependency index are ordinary retained
        # documents. This index excludes itself and its dependent new profile.
        documents[DEPENDENCY_NAME] = (3, dumps({
            "version": "1", "documents": old_index["documents"],
            "registryPredecessors": predecessors,
            "interpretationDocuments": [{"name": name, "documentId": schema_id(name), "kind": str(kind),
                "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                    "canonicalizationId": canonicalizations[name]}, "byteLength": str(len(raw))}
                for name, (kind, raw) in sorted(documents.items())],
            "retention": "Complete inherited original-byte dependency closure plus new profile documents; no live resolution and no old-profile reinterpretation.",
        }))
        canonicalizations[DEPENDENCY_NAME] = JCS_ID

        def reference(name):
            raw = documents[name][1]
            return {"path": name + ".json", "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                "canonicalizationId": canonicalizations[name]}, "byteLength": str(len(raw)), "mediaType": "application/json"}

        body.update(dependencyIndex=reference(DEPENDENCY_NAME), selectionRules=reference(POLICY_NAME),
            crosswalkDocuments=[reference(CROSSWALK_NAME), reference(typed.RECONCILIATION_NAME)],
            supersedesSchemaId=schema_id(typed.NAME))
        body["validationDocuments"] += [reference(NAMES[1]), reference(NAMES[2])]
        self.profile_bytes = dumps(body)
        _validate(SCHEMAS[NAMES[0]], self.profile_bytes)
        self.profile_hash = keccak256(self.profile_bytes)
        if expected_hash is not None and expected_hash != self.profile_hash:
            raise MuseumError("qualified review profile pin mismatch")
        documents[NAME] = (2, self.profile_bytes)
        canonicalizations[NAME] = JCS_ID
        limits = Limits()
        if (len(documents) > limits.documents
            or sum(len(raw) for _, raw in documents.values()) > limits.aggregate_bytes
            or sum((len(raw) + limits.chunk_bytes - 1) // limits.chunk_bytes for _, raw in documents.values()) > limits.chunks
            or any(not 0 < len(raw) <= 524288 or len(name.encode("utf-8")) > 128 for name, (_, raw) in documents.items())):
            raise MuseumError("qualified review registered closure bound")
        self.documents = MappingProxyType(documents)
        self.document_canonicalizations = MappingProxyType(canonicalizations)
        self.document_predecessors = MappingProxyType(predecessors)
        self.identity = dumps({**loads(self.identity), "accountAuthorityPolicyHash": keccak256(POLICY_BYTES),
            "registeredProfileContentHash": self.profile_hash,
            "retainedTypedProfileHash": self.typed_profile_hash})

    def assertion_rules(self):
        return {**self._retained_assertion_rules,
            schema_id(NAMES[1]): (ASSERTION_SCHEMA_BYTES, schema_id(NAMES[0]), self.profile_hash)}


def generated_documents(profile):
    """Only the seven new documents; never rewrite retained registered bytes."""
    return {name: profile.documents[name][1] for name in (*NAMES, POLICY_NAME, CROSSWALK_NAME, DEPENDENCY_NAME, NAME)}


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    profile = QualifiedAccountReviewProfile()
    target = MODEL_ROOT / DIRECTORY
    for name, raw in generated_documents(profile).items():
        path = target / (name + ".json")
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise MuseumError("qualified review profile document differs: " + name)
        else:
            target.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(NAME, profile.profile_hash, len(profile.documents), "prospective; no chain registration")


if __name__ == "__main__":
    main()
