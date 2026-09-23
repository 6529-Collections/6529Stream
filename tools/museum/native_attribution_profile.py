"""Prospective native Artist attribution interpretation; old profiles stay exact."""
from pathlib import Path
from types import MappingProxyType

from .account_profile import AccountProjectionProfile, JCS_ID, NAME as ACCOUNT_NAME, POLICY_NAME, PROFILE_SCHEMA_BYTES
from .canonical import dumps, keccak256, loads
from .review import _validate
from .schemas import NAMES

NAME = "STREAM_MUSEUM_NATIVE_ATTRIBUTION_PROFILE_V1"
POLICY = "STREAM_MUSEUM_NATIVE_ATTRIBUTION_POLICY_V1"
CROSSWALK = "STREAM_MUSEUM_NATIVE_ATTRIBUTION_CROSSWALK_V1"
DEFAULT_ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
QUALIFICATION = (
    "Native receipts authenticate historical protocol identities and accounts, not named people or institutions. "
    "Current identity, binding, rotation and dispute observations do not rewrite earlier signatures. "
    "A same-artist review remains SELF review across signer rotation. Different accounts or artist IDs do not prove "
    "independent human review. Original profile, schema, payload and reviewer statements remain separately committed."
)
CLAIMS = {"historicalNativeAuthorityRetained": True, "originalSourceBytesRetained": True,
    "personhoodProven": False, "institutionalIdentityProven": False, "independentHumanReviewProven": False,
    "currentSigningAuthorityGranted": False, "reviewCreatesProtocolVeto": False,
    "actualChainAcceptance": False, "fullObjectDossierConformance": False}


class NativeAttributionProfile:
    """New registered-document candidate using unchanged assertion/review schemas."""

    name = NAME

    def __init__(self, root=DEFAULT_ROOT):
        base = AccountProjectionProfile(Path(root))
        documents = dict(base.documents)
        for name in (ACCOUNT_NAME, POLICY_NAME, "STREAM_ACCOUNT_CROSSWALK_V1"):
            del documents[name]
        documents[POLICY] = (3, dumps({"name": POLICY, "version": "1",
            "source": "Exact native Metadata Artist receipt joined to original op24 evidence; historical signer account is assertingAgent.",
            "identity": "artistId is a protocol identity, never an inferred Person/Group; exact original identity documents retain their own names and references.",
            "review": "Selected original review literal binds exact assertion selector/revision/profile/rule and follows publication. Same artistId or same signing account is SELF; explicit opt-in is required. Human independence cannot be satisfied here.",
            "selection": "Only exact selected source/reviewer sets influence admission; direct statements need no reviewer and unselected disputes cannot suppress them. Conflicting eligible values have no recency winner.",
            "current": "Current disputed, revoked, rotated or replaced identity observations are separate qualifications; historical signatures do not become current authorization.",
            "projection": "Original statements become LinguisticObjects, with exact field coverage. No named-entity equivalence, verified institution, legal title or human identity is created.",
            "claims": CLAIMS, "qualification": QUALIFICATION}))
        documents[CROSSWALK] = (3, dumps({"name": CROSSWALK, "version": "1",
            "sourceSchema": NAMES[1], "target": "LinguisticObject",
            "content": "Exact original canonical payload text; every original field retained in sidecar.",
            "authority": "Historical native signer, stable artistId and binding remain separate from current status.",
            "review": "Authenticated attributed statement only; selected SELF confirmation never independent human review.",
            "qualification": QUALIFICATION}))

        def reference(name):
            raw = documents[name][1]
            return {"path": name + ".json", "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                "canonicalizationId": JCS_ID}, "byteLength": str(len(raw)), "mediaType": "application/json"}

        value = loads(base.profile_bytes)
        value["selectionRules"] = reference(POLICY)
        value["crosswalkDocuments"] = [reference(CROSSWALK)]
        self.profile_bytes = dumps(value)
        _validate(PROFILE_SCHEMA_BYTES, self.profile_bytes)
        self.profile_hash = keccak256(self.profile_bytes)
        documents[NAME] = (2, self.profile_bytes)
        self.documents = MappingProxyType(documents)
