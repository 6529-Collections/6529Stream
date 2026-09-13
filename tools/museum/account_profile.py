"""Explicit account-authored interpretation, separate from original fixture profiles."""

import copy
from pathlib import Path
from types import MappingProxyType

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .projection_v2 import ProjectionProfileV2, crosswalk_v2_document
from .review import ASSERTION_SCHEMA_BYTES, BODY_SCHEMA_BYTES
from .schema_inventory import EVALUATION_PROFILE_BYTES
from .schemas import NAMES, schemas


NAME = "STREAM_MUSEUM_INDEPENDENT_ACCOUNT_PROFILE_V1"
ACCOUNT_PREFIX = "urn:6529stream:account:eip155:"
JCS_NAME = "RFC8785_JCS"
JCS_ID = schema_id(JCS_NAME)
JCS_BYTES = dumps({"name": JCS_NAME, "version": "1", "standard": "https://www.rfc-editor.org/rfc/rfc8785",
    "input": "Valid I-JSON values; duplicate properties and invalid Unicode reject.",
    "output": "RFC 8785 JSON Canonicalization Scheme UTF-8 bytes without a byte-order mark.",
    "sourceRule": "Original bytes must already equal the canonical encoding; do not repair or normalize them."})
POLICY_NAME = "STREAM_MUSEUM_INDEPENDENT_ACCOUNT_AUTHORITY_V1"
POLICY_BYTES = dumps({"version": "1", "accountIri": ACCOUNT_PREFIX + "<canonical uint256 chainId>:<lowercase 0x address20>",
    "authority": "Exact historical class5 attestor; no Person, Group or operator authority inference.",
    "source": "Exact complete selectors and original schema/profile/payload bytes; direct statements in this account's voice.",
    "review": "Same-account self review only when explicitly enabled; never independent review. Cross-account review is unsupported.",
    "conflicts": "Withhold contradictory admitted single-valued claims; no recency preference or unselected veto.",
    "accountEntity": "External account reference only; cannot be declared or coerced into a Person/Group.",
    "supportedInputLimits": {"recordBytes": "8192", "records": "512", "jsonDepth": "64",
        "numbers": "JSON decimals unsupported in this profile; wide protocol integers are canonical typed strings."}})
PROFILE_SCHEMA_BYTES = dumps(schemas()[NAMES[0]])


def account_iri(chain, address):
    uint(chain)
    if hex_bytes(address, 20) == bytes(20):
        raise MuseumError("zero semantic attestor account")
    return ACCOUNT_PREFIX + chain + ":" + address


def _crosswalk():
    value = copy.deepcopy(crosswalk_v2_document())
    value["version"] = "account-1"
    value["scope"] = "Registered account-authored independent input; finite v2 model rules, no human-identity or full Museum claim."
    for rule in value["rules"]:
        rule["authorityRule"] = "exact_registered_account_profile_and_historical_attestor"
    return dumps(value)


CROSSWALK_BYTES = _crosswalk()
CROSSWALK_HASH = keccak256(CROSSWALK_BYTES)


class AccountProjectionProfile(ProjectionProfileV2):
    version = "account-1"
    crosswalk_bytes = CROSSWALK_BYTES
    crosswalk_hash = CROSSWALK_HASH

    def __init__(self, root: Path, *, expected_hash=None):
        validation = (root / "linked-art-v2/validation-policy.json").read_bytes()
        vocabulary = (root / "standards/vocabulary-policy.json").read_bytes()
        super().__init__(root, CROSSWALK_BYTES, crosswalk_hash=CROSSWALK_HASH,
            validation_hash=keccak256(validation), vocabulary_hash=keccak256(vocabulary))
        # The registered index commits to the actual complete local model and vocabulary indices.
        # Their existing loaders independently reconstruct every pinned original chunk and reference.
        dependency = dumps({"version": "1", "mode": "account_profile_offline_dependency_closure",
            "linkedArt": loads((root / "linked-art-v2/validation-index.json").read_bytes(), maximum=524288),
            "vocabulary": loads((root / "standards/vocabulary-index.json").read_bytes(), maximum=524288),
            "originalByteRule": "Retain exact indexed source bytes; registry profile admission is not upstream endorsement."})
        documents = {
            NAMES[0]: (0, PROFILE_SCHEMA_BYTES), NAMES[1]: (0, ASSERTION_SCHEMA_BYTES),
            "STREAM_SEMANTIC_REVIEW_BODY_V1": (0, BODY_SCHEMA_BYTES),
            POLICY_NAME: (3, POLICY_BYTES), "STREAM_ACCOUNT_CROSSWALK_V1": (3, CROSSWALK_BYTES),
            "STREAM_ACCOUNT_MODEL_VALIDATION_V1": (3, validation),
            "STREAM_ACCOUNT_VOCABULARY_V1": (3, vocabulary),
            "STREAM_ACCOUNT_SCHEMA_EVALUATION_V1": (3, EVALUATION_PROFILE_BYTES),
            "STREAM_ACCOUNT_DEPENDENCIES_V1": (3, dependency),
        }
        def reference(name):
            raw = documents[name][1]
            return {"path": name + ".json", "contentHash": {"algorithm": "1", "digest": keccak256(raw),
                "canonicalizationId": JCS_ID}, "byteLength": str(len(raw)), "mediaType": "application/json"}
        limits = schemas()[NAMES[0]]["properties"]["limits"]["properties"]
        body = {"standards": {"cidocCrm": "7.1.3", "linkedArtModel": "1.0.0", "jsonLd": "1.1"},
            "dependencyIndex": reference("STREAM_ACCOUNT_DEPENDENCIES_V1"),
            "crosswalkDocuments": [reference("STREAM_ACCOUNT_CROSSWALK_V1")],
            "selectionRules": reference(POLICY_NAME),
            "validationDocuments": [reference("STREAM_ACCOUNT_MODEL_VALIDATION_V1"), reference("STREAM_ACCOUNT_SCHEMA_EVALUATION_V1")],
            "classPropertyTables": [reference("STREAM_ACCOUNT_VOCABULARY_V1")], "termCatalogs": [],
            "limits": {key: value["const"] for key, value in limits.items()}, "supersedesSchemaId": None}
        self.profile_bytes = dumps(body)
        from .review import _validate
        _validate(PROFILE_SCHEMA_BYTES, self.profile_bytes)
        self.profile_hash = keccak256(self.profile_bytes)
        if expected_hash is not None and self.profile_hash != expected_hash:
            raise MuseumError("registered account profile pin mismatch")
        documents[NAME] = (2, self.profile_bytes)
        documents[JCS_NAME] = (1, JCS_BYTES)
        self.documents = MappingProxyType(documents)
        self.identity = dumps({**loads(self.identity), "accountAuthorityPolicyHash": keccak256(POLICY_BYTES),
                               "registeredProfileContentHash": self.profile_hash})


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate/check the account interpretation documents; no chain registration.")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum"
    profile = AccountProjectionProfile(root)
    target = root / "account-profile"
    for name, (kind, raw) in profile.documents.items():
        path = target / (name + ".json")
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise MuseumError("account profile document differs: " + name)
        else:
            target.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(NAME, profile.profile_hash, "prospective documents; registration checked per anchored capture")


if __name__ == "__main__":
    main()
