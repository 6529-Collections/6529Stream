"""Prospective General-account semantics using unchanged registered schemas.

This profile does not borrow native Artist or independent class-5 authority.
The original General receipt and the interpretation-document admission remain
separate commitments; generic General receipts have no profile definition hash.
"""

from pathlib import Path
from types import MappingProxyType

from .account_profile import (
    AccountProjectionProfile, JCS_ID, NAME as ACCOUNT_NAME, POLICY_NAME,
    PROFILE_SCHEMA_BYTES,
)
from .canonical import dumps, keccak256, loads
from .review import _validate
from .schemas import NAMES


NAME = "STREAM_MUSEUM_GENERAL_SEMANTIC_PROFILE_V1"
POLICY = "STREAM_MUSEUM_GENERAL_SEMANTIC_POLICY_V1"
CROSSWALK = "STREAM_MUSEUM_GENERAL_SEMANTIC_CROSSWALK_V1"
MODEL_ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
QUALIFICATION = (
    "Original General institutional and estate receipts retain account-signature "
    "authority; curatorial receipts retain the actual configured operator's "
    "authority, separately from the unsigned asserted attester and DID. Neither "
    "class establishes named institutions, legal persons, truth, independent "
    "review, current permission, physical custody, legal title or accession. "
    "Documentary references resolve to exact earlier Metadata payload bytes. "
    "Strict stored timestamp ordering is required; equal timestamps cannot "
    "establish cross-host publication order. Original schema, profile, source "
    "authority and selected assertions remain separate. Source provenance is "
    "caller-admitted, with no consensus or signature re-execution claim."
)
CLAIMS = {
    "historicalGeneralReceiptAuthorityRetained": True,
    "originalSourceBytesRetained": True,
    "documentaryPayloadCorrespondenceChecked": True,
    "strictEarlierDocumentaryTimestampRequired": True,
    "institutionalIdentityProven": False,
    "legalPersonhoodProven": False,
    "independentHumanReviewProven": False,
    "currentSigningAuthorityGranted": False,
    "signatureCurrentlyRevalidated": False,
    "physicalCustodyProven": False,
    "legalTitleProven": False,
    "museumAccessionProven": False,
    "genericReceiptCommitsInterpretationProfile": False,
    "crossHostTransactionOrderProven": False,
    "actualChainAcceptance": False,
    "consensusProof": False,
    "fullObjectDossierConformance": False,
}


class GeneralSemanticProfileV1:
    """Exact candidate document set; construction does not register it."""

    name = NAME

    def __init__(self, root=MODEL_ROOT):
        base = AccountProjectionProfile(Path(root))
        documents = dict(base.documents)
        for name in (ACCOUNT_NAME, POLICY_NAME, "STREAM_ACCOUNT_CROSSWALK_V1"):
            del documents[name]
        documents[POLICY] = (3, dumps({
            "name": POLICY, "version": "1",
            "source": "Complete concrete GeneralAttestationSourceV2 and MetadataCatalogSource at one admitted state.",
            "authority": "Generic institutional/estate SIGNER_VERIFIED/GENERAL_SIGNER_CLAIM rows use the original recorder=attester account. Curatorial OPERATOR_ASSERTED/CONFIGURED_OPERATOR_CLAIM rows use the actual recorder and exact CURATOR/class3 grant, never the unsigned asserted attester or DID.",
            "selectors": "Outer native_general_attestation selectors preserve General verificationClass and authorityQualification. Internal unchanged-schema sourceRecords are exact Metadata selectors; General classes are never recast as Metadata authorizationClass.",
            "profileBinding": "Original generic receipt.profileDefinitionHash remains zero. Original payload.profileHash, original receipt schema/canonicalization hashes and independently retained registered interpretation documents must agree.",
            "identity": "assertingAgent and declaringAgent equal the authenticated recorder's account IRI. Account IRIs cannot be declared entities. Names and DID text establish neither personhood nor institutional standing.",
            "evidence": "Every sourceRecords and entity sourceRecords selector resolves to exact complete original Metadata bytes with receipt.recordedAt strictly less than the General receipt's recordedAt. Evidence admits only documentary_evidence with exact algorithm1 payload hash/canonicalization and whole_document or resolving JSON Pointer. own_signed_statement, document_page and media_time are unsupported and reject a claimed supported profile.",
            "selection": "Only separately selected direct_statement assertions that are not disputed or withdrawn can be projected. All originals remain retained. Conflicting selected values have no recency winner; unselected assertions do not veto. Mapping/review fields are retained without reviewer-authority inference.",
            "projection": "Qualified attributed LinguisticObjects and exact field/provenance sidecars only. No physical event, institution, current owner, legal title or custody is inferred by this profile.",
            "claims": CLAIMS, "qualification": QUALIFICATION,
        }))
        documents[CROSSWALK] = (3, dumps({
            "name": CROSSWALK, "version": "1", "sourceSchema": NAMES[1],
            "target": "LinguisticObject",
            "content": "Exact selected original direct assertion and complete original payload retained without rewriting source text.",
            "authority": "Original General recorder/account and receipt class; no inherited Artist or independent class5 authority.",
            "documentaryEvidence": "Exact prior Metadata bytes and selectors, not instrument validity, external retrieval or legal effect.",
            "qualification": QUALIFICATION,
        }))

        def reference(name):
            raw = documents[name][1]
            return {"path": name + ".json", "contentHash": {"algorithm": "1",
                "digest": keccak256(raw), "canonicalizationId": JCS_ID},
                "byteLength": str(len(raw)), "mediaType": "application/json"}

        body = loads(base.profile_bytes)
        body["selectionRules"] = reference(POLICY)
        body["crosswalkDocuments"] = [reference(CROSSWALK)]
        self.profile_bytes = dumps(body)
        _validate(PROFILE_SCHEMA_BYTES, self.profile_bytes)
        self.profile_hash = keccak256(self.profile_bytes)
        documents[NAME] = (2, self.profile_bytes)
        self.documents = MappingProxyType(documents)
