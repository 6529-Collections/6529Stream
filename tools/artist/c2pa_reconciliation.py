"""Exact ART38 reconciliation over an explicit verifier's observation.

Does not execute a C2PA cryptographic validator or authenticate RPC/signatures.
The companion admits only the selected verifier's original class4/6 receipt.
Byte correspondence does not prove trust quality, human identity or availability.
"""
from tools.museum.canonical import MuseumError, dumps, loads, keccak256, hex_bytes, schema_id, uint
from tools.museum.chain_abi import Array, encode, decode

PROFILE = schema_id("6529STREAM_C2PA_RECONCILIATION_V1")
IDENTITY_PROFILE = "6529STREAM_ARTIST_C2PA_KEY_HISTORY_JSON_V1"
OBSERVATION_PROFILE = "6529STREAM_C2PA_VALIDATOR_OBSERVATION_V1"
ZERO = "0x" + "00" * 32
CREDENTIAL = ("uint8", "bytes32", "bytes32", "uint64", "uint64")
PAYLOAD = ("uint16", "bytes32", "bytes32", "bytes32", Array(CREDENTIAL, 48))
REPORT_FIELDS = (
    "version", "profile", "collectionId", "subjectId", "artistId", "bindingHash", "generation",
    "identityRecordHash", "credentialRecordHash", "identityDocumentHash", "publicKeyHistoryHash",
    "credentialEnumerationHash", "selectedMediaManifestHash", "mediaSlot", "mediaHash", "claimAssetHash",
    "manifestHash", "claimHash", "claimSignatureHash", "signerKind", "signerFingerprint", "signerKeyFingerprint",
    "keyId", "signedAt", "validation", "authorship", "assertsAuthorship", "validatorIdentityHash",
    "softwareVersionHash", "validationReportHash", "trustAnchorsHash", "reportURI")
REPORT = ("uint16", "bytes32", "uint256", "bytes32", "bytes32", "bytes32", "uint64", "bytes32", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
    "uint8", "bytes32", "bytes32", "bytes32", "uint64", "uint8", "uint8", "bool", "bytes32", "bytes32", "bytes32", "bytes32", "string")
CONTEXT_FIELDS = {"collectionId", "subjectId", "artistId", "bindingHash", "generation", "identityRecordHash",
    "credentialRecordHash", "selectedMediaManifestHash", "mediaSlot", "mediaHash", "reportURI"}
OBSERVATION_FIELDS = {"profile", "manifestHash", "claimHash", "claimSignatureHash", "assetHash", "signerKind",
    "signerFingerprint", "signerKeyFingerprint", "keyId", "signedAt", "validationStatus", "assertsAuthorship",
    "validatorIdentityHash", "softwareVersionHash", "trustAnchorsHash", "cryptoTrustProfile"}


def report_schema_definition():
    return dumps({"name": "6529STREAM_C2PA_RECONCILIATION_REPORT_V1", "version": "1",
        "encoding": "abi.encode(Report)", "fields": [{"name": name, "type": kind} for name, kind in zip(REPORT_FIELDS, REPORT)],
        "semantics": "Selected verifier observation; validation and authorship are separate. Zero is unevaluated. No authority is conferred."})


def require(test, reason):
    if not test:
        raise MuseumError(reason)


def _hash(value, zero=False):
    require(len(hex_bytes(value, 32)) == 32 and (zero or value != ZERO), "nonzero exact hash required")
    return value


def _credential(row):
    require(type(row) is dict and set(row) == {"kind", "fingerprint", "keyId", "validFrom", "validUntil"}, "credential keys")
    kind, start, end = uint(row["kind"], 8), uint(row["validFrom"], 64), uint(row["validUntil"], 64)
    require(kind != 0 and (end == 0 or end > start), "credential validity")
    return (kind, _hash(row["fingerprint"]), _hash(row["keyId"]), start, end)


def credential_statement(artist_id, identity_hash, previous_record, credentials):
    """Original subject10 bytes; does not sign or publish op24."""
    rows = [_credential(row) for row in credentials]
    rows.sort(key=lambda row: keccak256(encode(CREDENTIAL, row)))
    require(len({keccak256(encode(CREDENTIAL, row)) for row in rows}) == len(rows), "duplicate credential")
    return encode((PAYLOAD,), ((1, _hash(artist_id), _hash(identity_hash), _hash(previous_record, True), rows),))


def _window(start, end, at):
    return start <= at and (end == 0 or at < end)


def build_report(context, identity_bytes, statement, observation_bytes, trust_anchor_bytes, media_bytes):
    """Prepare typed bytes, without treating supplied context as chain evidence.

    A zero credential head selects identity-document enumeration. A nonzero head
    requires its exact original ABI statement; empty/latest never falls back.
    The actual companion independently binds context to current onchain state.
    """
    require(type(context) is dict and set(context) == CONTEXT_FIELDS, "context keys")
    for key in CONTEXT_FIELDS - {"collectionId", "generation", "mediaSlot", "reportURI"}:
        _hash(context[key], key == "credentialRecordHash")
    collection, generation, slot = uint(context["collectionId"]), uint(context["generation"], 64), uint(context["mediaSlot"], 8)
    require(collection > 0 and generation > 0 and slot in (1, 2, 3), "context identity")
    require(type(context["reportURI"]) is str and 0 < len(context["reportURI"].encode("utf-8")) <= 2048, "report URI")
    identity = loads(identity_bytes, maximum=8192, canonical=True)
    require(keccak256(identity_bytes) == context["identityRecordHash"], "operative identity byte hash")
    required = {"schema", "displayName", "biographicalRefs", "publicKeyHistory", "c2paCredentials", "payoutAccounts"}
    require(type(identity) is dict and required <= set(identity) and set(identity) <= required | {"extensions"}, "identity shape")
    require(identity["schema"] == "6529STREAM_ARTIST_IDENTITY_V1", "identity schema")
    require(type(identity["publicKeyHistory"]) is list and type(identity["c2paCredentials"]) is list, "identity histories")
    require(type(identity.get("extensions", {})) is dict, "identity extensions")
    history_hash = keccak256(dumps(identity["publicKeyHistory"]))
    supported_identity = identity.get("extensions", {}).get("c2paReconciliationProfile") == IDENTITY_PROFILE
    if context["credentialRecordHash"] == ZERO:
        require(statement is None, "unexpected credential statement with no head")
        credentials = [_credential(row) for row in identity["c2paCredentials"]] if supported_identity else []
        enumeration_hash = keccak256(dumps(identity["c2paCredentials"]))
    else:
        require(type(statement) is bytes, "latest credential statement required")
        payload, = decode((PAYLOAD,), statement, maximum=8192)
        version, artist_id, identity_hash, _, credentials = payload
        require(version == 1 and artist_id == context["artistId"] and identity_hash == context["identityRecordHash"], "credential identity")
        keys = []
        for row in credentials:
            require(row[0] != 0 and row[1] != ZERO and row[2] != ZERO and (row[4] == 0 or row[4] > row[3]), "credential shape")
            keys.append(keccak256(encode(CREDENTIAL, row)))
        require(keys == sorted(set(keys)), "credential ordering")
        enumeration_hash = keccak256(statement)
    observation = loads(observation_bytes, maximum=8192, canonical=True)
    require(type(observation) is dict and set(observation) == OBSERVATION_FIELDS, "validator observation keys")
    require(observation["profile"] == OBSERVATION_PROFILE, "validator observation profile")
    for key in ("manifestHash", "claimHash", "claimSignatureHash", "assetHash", "signerFingerprint", "signerKeyFingerprint", "keyId",
                "validatorIdentityHash", "softwareVersionHash", "trustAnchorsHash"):
        _hash(observation[key])
    require(0 < len(trust_anchor_bytes) <= 8192 and keccak256(trust_anchor_bytes) == observation["trustAnchorsHash"], "exact retained trust-anchor bytes")
    require(type(media_bytes) is bytes and keccak256(media_bytes) == context["mediaHash"], "exact committed media bytes")
    kind, signed_at = uint(observation["signerKind"], 8), uint(observation["signedAt"], 64)
    require(signed_at != 0 and type(observation["assertsAuthorship"]) is bool, "validator signer shape")
    require(observation["validationStatus"] in ("unevaluated", "valid", "invalid"), "validator status")
    require(type(observation["cryptoTrustProfile"]) is str, "crypto/trust profile")
    validation = {"unevaluated": 0, "valid": 1, "invalid": 2}[observation["validationStatus"]]
    if observation["cryptoTrustProfile"] != "SELECTED_VERIFIER_ARCHIVED_TRUST_V1":
        validation = 0
    if observation["assetHash"] != context["mediaHash"]:
        validation = 2
    require(kind != 1 or observation["signerFingerprint"] == observation["signerKeyFingerprint"], "SPKI signer mismatch")
    authorship = 0
    if validation == 1 and observation["assertsAuthorship"] and supported_identity and kind in (1, 2) and credentials:
        key_matches = False
        key_ids = set()
        for key in identity["publicKeyHistory"]:
            require(type(key) is dict and set(key) == {"keyId", "spkiSha256", "validFrom", "validUntil"}, "supported key-history shape")
            key_id, spki = _hash(key["keyId"]), _hash(key["spkiSha256"])
            require(key_id not in key_ids, "duplicate key-history identity")
            key_ids.add(key_id)
            start, end = uint(key["validFrom"], 64), uint(key["validUntil"], 64)
            require(end == 0 or end > start, "key-history validity")
            if key_id == observation["keyId"] and spki == observation["signerKeyFingerprint"] and _window(start, end, signed_at):
                key_matches = True
        match = any(row[0] == kind and row[1] == observation["signerFingerprint"] and row[2] == observation["keyId"]
                    and _window(row[3], row[4], signed_at) for row in credentials)
        authorship = 1 if match and key_matches else (0 if any(row[0] not in (1, 2) for row in credentials) else 2)
    report = {
        "version": 1, "profile": PROFILE, "collectionId": collection, "subjectId": context["subjectId"],
        "artistId": context["artistId"], "bindingHash": context["bindingHash"], "generation": generation,
        "identityRecordHash": context["identityRecordHash"], "credentialRecordHash": context["credentialRecordHash"],
        "identityDocumentHash": keccak256(identity_bytes), "publicKeyHistoryHash": history_hash,
        "credentialEnumerationHash": enumeration_hash, "selectedMediaManifestHash": context["selectedMediaManifestHash"],
        "mediaSlot": slot, "mediaHash": context["mediaHash"], "claimAssetHash": observation["assetHash"],
        "manifestHash": observation["manifestHash"], "claimHash": observation["claimHash"], "claimSignatureHash": observation["claimSignatureHash"],
        "signerKind": kind, "signerFingerprint": observation["signerFingerprint"], "signerKeyFingerprint": observation["signerKeyFingerprint"],
        "keyId": observation["keyId"], "signedAt": signed_at, "validation": validation, "authorship": authorship,
        "assertsAuthorship": observation["assertsAuthorship"], "validatorIdentityHash": observation["validatorIdentityHash"],
        "softwareVersionHash": observation["softwareVersionHash"], "validationReportHash": keccak256(observation_bytes),
        "trustAnchorsHash": observation["trustAnchorsHash"], "reportURI": context["reportURI"]}
    encoded = encode((REPORT,), (tuple(report[key] for key in REPORT_FIELDS),))
    require(len(encoded) <= 8192, "typed report bound")
    return report, encoded
