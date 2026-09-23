"""Prospective General-target review wire; old Metadata-shaped schemas stay exact."""
from copy import deepcopy
from pathlib import Path
from types import MappingProxyType

from .account_profile import JCS_ID
from .canonical import dumps, keccak256, schema_id
from .general_semantic_profile_v1 import GeneralSemanticProfileV1
from .review import REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION, _validate
from .schemas import ADDRESS, HEX32, IRI, UINT, definitions, enum, obj, schemas, NAMES as OLD_NAMES

NAME = "STREAM_MUSEUM_GENERAL_SEMANTIC_REVIEW_PROFILE_V1"
PROFILE_SCHEMA_NAME = "STREAM_MUSEUM_GENERAL_SEMANTIC_REVIEW_SCHEMA_V1"
ASSERTION_NAME = "STREAM_GENERAL_SEMANTIC_ASSERTION_V1"
BODY_NAME = "STREAM_GENERAL_SEMANTIC_REVIEW_BODY_V1"
CROSSWALK_NAME = "STREAM_MUSEUM_GENERAL_REVIEW_CROSSWALK_V1"
POLICY_NAME = "STREAM_MUSEUM_GENERAL_REVIEW_POLICY_V1"
QUALIFICATION = (
    "Historical General receipt principals only: signed institutional/estate recorder=attester, "
    "or actual curatorial recorder with the original enabled CURATOR/class3 grant event. "
    "Names, DID labels and distinct accounts do not prove persons, institutions or independent humans. "
    "Publication order is receipt/log position in parent-linked trusted-RPC headers, not timestamps, "
    "receipt-trie proofs or consensus verification. Selection is an explicit dossier policy, "
    "not protocol authority, renderer input, truth, current permission, custody, title or accession.")
CLAIMS = {"originalGeneralReceiptAuthorityRetained": True, "originalBytesRetained": True,
    "receiptPublicationOrderChecked": True, "independentHumanReviewProven": False,
    "namedInstitutionIdentityProven": False, "currentAuthorityGranted": False,
    "signatureCurrentlyRevalidated": False, "consensusProof": False,
    "cryptographicReceiptProof": False, "actualChainAcceptance": False,
    "fullMuseumConformance": False}

GENERAL_SELECTOR = obj({"kind": {"const": "native_general_attestation"}, "chainId": UINT,
    "host": ADDRESS, "recordHash": HEX32, "subjectId": HEX32, "recordType": HEX32,
    "schemaId": HEX32, "schemaHash": HEX32, "canonicalizationId": HEX32,
    "recorder": ADDRESS, "verificationClass": enum("SIGNER_VERIFIED", "OPERATOR_ASSERTED"),
    "authorityQualification": enum("GENERAL_SIGNER_CLAIM", "CONFIGURED_OPERATOR_CLAIM", "NATIVE_ARTIST_HISTORY"),
    "recordIndex": dict(UINT, maxLength=20, **{"x-stream-unsigned-bits": 64}),
    "recordChainHash": HEX32, "pointer": {"type": "string", "pattern": "^(/([^~]|~[01])*)*$"}})
AUTHORITY = obj({"principal": IRI, "collectionId": UINT, "subjectId": HEX32,
    "recordType": HEX32, "verificationClass": GENERAL_SELECTOR["properties"]["verificationClass"],
    "authorityQualification": GENERAL_SELECTOR["properties"]["authorityQualification"],
    "grantRevision": UINT})

def document(name, body):
    return dict(body, **{"$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:6529stream:schema:" + name, "x-stream-schema-id": schema_id(name),
        "x-stream-document-status": "candidate_unregistered"})

BODY_SCHEMA_BYTES = dumps(document(BODY_NAME, obj({"assertionRecord": GENERAL_SELECTOR,
    "assertionRevisionHash": HEX32, "profileHash": HEX32, "mappingRule": IRI,
    "targetAuthority": AUTHORITY, "disposition": enum("reviewed", "rejected")})))
assertion_schema = deepcopy(schemas()[OLD_NAMES[1]])
assertion_schema["$defs"]["selector"] = GENERAL_SELECTOR
assertion_schema["$defs"]["review"]["properties"]["targetAuthority"] = AUTHORITY
assertion_schema["$defs"]["review"]["required"].append("targetAuthority")
assertion_schema["properties"]["profileSchemaId"] = {"const": schema_id(PROFILE_SCHEMA_NAME)}
ASSERTION_SCHEMA_BYTES = dumps(document(ASSERTION_NAME, assertion_schema))
PROFILE_SCHEMA_BYTES = dumps(document(PROFILE_SCHEMA_NAME, deepcopy(schemas()[OLD_NAMES[0]])))


def review_literal(body):
    raw = dumps(body); _validate(BODY_SCHEMA_BYTES, raw)
    return {"lexicalValue": raw.decode(), "datatype": REVIEW_DATATYPE,
        "language": None, "unit": None, "precision": None}


class GeneralSemanticReviewProfileV1:
    name = NAME
    def __init__(self, root=Path(__file__).resolve().parents[2] / "schemas/museum"):
        base = GeneralSemanticProfileV1(root)
        documents = dict(base.documents)
        documents[PROFILE_SCHEMA_NAME] = (0, PROFILE_SCHEMA_BYTES)
        documents[ASSERTION_NAME] = (0, ASSERTION_SCHEMA_BYTES)
        documents[BODY_NAME] = (0, BODY_SCHEMA_BYTES)
        documents[POLICY_NAME] = (3, dumps({"name": POLICY_NAME, "version": "1",
            "input": "Complete concrete General V2 source, exact new assertion wire and immutable registered profile documents.",
            "authority": "Every source/reviewer admission binds exact General selector, original principal, family, collection, subject, verification class, authority qualification and grant revision.",
            "reviews": "Separate later direct statement with original semantic-review:v1 relation/datatype and this profile's General-specific body. Exact target assertion revision/profile/mapping/authority and identical original native subject scope; no Metadata-shaped coercion. Writer-supplied semantic JSON/envelope/identity/evidence errors are retained as record diagnostics; assertion/review/backlink errors are isolated per selector where the envelope is valid. Invalid semantics are ineligible and cannot veto unrelated selections; native/header/definition authentication still fails closed. Withdrawn/disputed reviews cannot qualify; selected rejecting reviews withhold without recency preference.",
            "selection": "Eligible direct claims and positively reviewed mappings only; author self-review requires explicit opt-in. Distinct qualified accounts never imply independent humans. Conflicting selected single-valued assertions all withheld; unselected records cannot veto.",
            "evidence": "Exact prior General documentary bytes/pointers only in this cohort. General to other-family review/evidence and own_signed_statement remain separate composition work.",
            "qualification": QUALIFICATION, "claims": CLAIMS}))
        documents[CROSSWALK_NAME] = (3, dumps({"name": CROSSWALK_NAME, "version": "1",
            "sourceSchema": ASSERTION_NAME, "target": "LinguisticObject",
            "selection": "Exact eligible direct statements and authenticated admitted reviewed mappings; withheld/unselected originals remain retained.",
            "content": "Original assertion bytes and exact review/receipt provenance; no object, person or event truth inferred.",
            "qualification": QUALIFICATION}))
        from .canonical import loads
        body = loads(base.profile_bytes)
        def reference(name):
            raw = documents[name][1]
            return {"path": name + ".json", "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                "canonicalizationId": JCS_ID}, "byteLength": str(len(raw)), "mediaType": "application/json"}
        body["selectionRules"] = reference(POLICY_NAME)
        body["crosswalkDocuments"] = [reference(CROSSWALK_NAME)]
        body["validationDocuments"] += [reference(ASSERTION_NAME), reference(BODY_NAME)]
        self.profile_bytes = dumps(body); _validate(PROFILE_SCHEMA_BYTES, self.profile_bytes)
        self.profile_hash = keccak256(self.profile_bytes)
        documents[NAME] = (2, self.profile_bytes)
        self.documents = MappingProxyType(documents)


def main():
    import argparse
    parser = argparse.ArgumentParser(); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(); profile = GeneralSemanticReviewProfileV1()
    target = Path(__file__).resolve().parents[2] / "schemas/museum/general-review-v1"
    for name in (PROFILE_SCHEMA_NAME, ASSERTION_NAME, BODY_NAME, POLICY_NAME, CROSSWALK_NAME, NAME):
        raw = profile.documents[name][1]; path = target / (name + ".json")
        if args.check:
            if not path.exists() or path.read_bytes() != raw: raise SystemExit("stale General review document " + name)
        else:
            target.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
    print(NAME, profile.profile_hash)

if __name__ == "__main__": main()
