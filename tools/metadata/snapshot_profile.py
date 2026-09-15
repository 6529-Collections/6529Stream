"""Generate the closed native snapshot schema/profile and exact Solidity definition pins."""

import argparse
import json
import re
from pathlib import Path

from jsonschema import Draft202012Validator

from .work_profile import digest

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "STREAM_NATIVE_ONCHAIN_SNAPSHOT_V1"
PROFILE = "STREAM_NATIVE_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1"


def obj(fields):
    return {"type": "object", "properties": fields, "required": list(fields), "additionalProperties": False}


def schema():
    h = {"type": "string", "pattern": "^0x[0-9a-f]{64}$", "minLength": 66, "maxLength": 66}
    a = {"type": "string", "pattern": "^0x[0-9a-f]{40}$", "minLength": 42, "maxLength": 42}
    u = {"type": "string", "pattern": "^(0|[1-9][0-9]*)$", "maxLength": 78}
    text = {"type": "string"}
    def fields(names, kind=h):
        return {name: kind for name in names.split()}
    artist = obj({**fields("acceptanceRecordHash artistId bindingHash identityRecordHash registryCodeHash snapshotHash"),
                  **fields("acceptedAt bindingGeneration lockedAt", u), **fields("nominatedArtist registry", a)})
    checkpoint = obj({**fields("contentRoot inventoryHash leafChainHash planHash servingStateHash"), "tokenCount": u})
    leaves = obj({**fields("artifactHash coverageHash recordHash"), "byteLength": u})
    root = obj({**fields("artistConsent contentRoot manifestHash predecessor recordHash routeHash stateHash"),
                **fields("authorizationClass grantRevision leafCount publishedAt", u),
                "publisher": a, "manifestURI": text, "checkpoint": checkpoint, "leafManifest": leaves})
    policy = obj({**fields("componentDataHash deploymentManifestHash indexedCodeHash moduleManifestHash moduleSchemaHash moduleVersion policyHash salt"),
                  **fields("coordinator provider", a), **fields("epoch firstTokenIndex", u), "frozen": {"const": True}})
    result = obj({
        "chainId": u, "collectionId": u, "contentRoot": root, "dependencyReadProfile": h,
        "entropy": obj({"allFrozen": {"const": True}, "inventoryHash": h, "planId": h,
                        "policies": {"type": "array", "minItems": 1, "items": policy}, "policyChainHash": h, "policyCount": u}),
        "metadata": obj({"animationBaseURI": text, "artist": artist, "description": text, "imageURI": text,
                         "locks": obj({name: {"const": True} for name in ("artistIdentity", "baseURI", "dependencies", "displayMetadata", "media", "script")}), "name": text}),
        "profileHash": h,
        "publication": obj({**fields("authorizationClass displayAuthorizationClass displayGrantRevision effectiveAt grantRevision revision", u),
                            **fields("predecessor reasonHash snapshotId"), "manifestURI": text, "publisher": a}),
        "renderer": obj({**fields("context presentationProfile routerManifestHash routerVersion runtimeHash"), "address": a}),
        "schemaHash": h, "schemaId": h,
        "script": obj({"byteLength": u, "content": {"type": "string", "minLength": 1}, "contentHash": h, "mode": {"const": "ONCHAIN"}}),
        "sources": {"type": "array", "minItems": 9, "maxItems": 9,
                    "items": obj({"address": a, "role": u, "runtimeHash": h})},
        "subject": h, "version": {"const": 1},
    })
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": SCHEMA, **result}


def profile():
    return {
        "name": PROFILE, "schema": SCHEMA, "version": 1, "canonicalization": "RFC8785_JCS",
        "manifestBytesMaximum": 524288, "segmentBytes": 8192,
        "integerEncoding": "Exact unsigned decimal strings; only version is a JSON number.",
        "sourceRoles": ["Core", "Metadata", "schemas", "Store", "Router", "leafManifest", "checkpoint", "membership", "originalCoordinatorInventory"],
        "capturedFamily": "IDENTITY_DISPLAY",
        "authority": "Actual Metadata SNAPSHOT and IDENTITY_DISPLAY grants independently; collection class7 precedes global class8. Saved publisher and original grant revisions never become artist or archive authority.",
        "sourceRules": [
            "Exact current locked native Router source, immutable rendering profiles and nominated-artist presentation; current Core freeze is excluded from artwork bytes.",
            "Original content-root publication and its exact artist association, verified complete leaf manifest/checkpoint and archival references are attributed originals, not admin-authored statements of those families.",
            "Every coordinator in the complete original-at-mint inventory supplies its live native frozen policy; no current-pointer substitution and no seed, oracle truth or archival proof is inferred.",
            "All input strings retain exact valid UTF8 with no normalization; byte limits are name256, description2048, each source URI2048, script8192, publication URI2048.",
            "An opaque snapshotId labels one publication and is not its content hash. The own manifest/record hash is never embedded in its preimage.",
            "Publication predecessor/new revision are historical provenance; source comparison excludes snapshot selection and later snapshot/Core locks.",
            "effectiveAt is explicitly supplied, nonzero, at or before publication time; source values are observed at publication, not reconstructed at that historical effective time.",
            "Configured contract dependency read-set does not prove arbitrary script web/execution-environment closure.",
        ],
        "currentScope": "COLLECTION native ONCHAIN; other v1 scopes and media modes remain required separate profiles.",
        "remainingRequirements": ["Full metadata/custom-field/family export", "Complete browser/runtime dependency and archival coverage", "Reference-render evidence", "All v1 scopes and institutional acceptance"],
    }


def validate(raw):
    """Check declared self-consistency, not carrier authority or every live contract predicate."""
    def pairs(rows):
        value = {}
        for key, item in rows:
            if key in value:
                raise ValueError("duplicate JSON key")
            value[key] = item
        return value

    if not isinstance(raw, bytes) or not 0 < len(raw) <= 524288:
        raise ValueError("manifest byte bound")
    value = json.loads(raw.decode("utf8"), object_pairs_hook=pairs,
                       parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite")))
    Draft202012Validator(schema()).validate(value)
    if type(value["version"]) is not int or value["version"] != 1:
        raise ValueError("literal version")
    canonical = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf8")
    if canonical != raw:
        raise ValueError("canonical exact bytes")
    for key, expected in (("schemaId", digest(SCHEMA.encode())),
                          ("schemaHash", digest(generated()[f"schemas/records/{SCHEMA}.json"])),
                          ("profileHash", digest(generated()[f"schemas/records/{PROFILE}.json"]))):
        if value[key] != expected:
            raise ValueError("exact registered interpretation pin")
    def number(text, maximum=(1 << 256) - 1, nonzero=False):
        if not re.fullmatch(r"0|[1-9][0-9]*", text) or int(text) > maximum or (nonzero and int(text) == 0):
            raise ValueError("exact unsigned quantity")
        return int(text)
    def text_bound(text, maximum, nonempty=False):
        length = len(text.encode("utf8"))
        if length > maximum or (nonempty and length == 0):
            raise ValueError("source text byte bound")
        return length
    def nonzero_fields(row, names):
        for name in names.split():
            if int(row[name], 16) == 0:
                raise ValueError(f"required nonzero source field: {name}")

    script = value["script"]
    length = text_bound(script["content"], 8192, True)
    if number(script["byteLength"], 8192, True) != length or digest(script["content"].encode()) != script["contentHash"]:
        raise ValueError("exact script bytes")
    return validate_common(value)


def validate_common(value):
    """Shared source/authority/inventory checks after a profile-specific closed schema check."""
    def number(text, maximum=(1 << 256) - 1, nonzero=False):
        if not re.fullmatch(r"0|[1-9][0-9]*", text) or int(text) > maximum or (nonzero and int(text) == 0):
            raise ValueError("exact unsigned quantity")
        return int(text)
    def text_bound(text, maximum, nonempty=False):
        length = len(text.encode("utf8"))
        if length > maximum or (nonempty and length == 0):
            raise ValueError("source text byte bound")
        return length
    def nonzero_fields(row, names):
        for name in names.split():
            if int(row[name], 16) == 0:
                raise ValueError(f"required nonzero source field: {name}")

    chain_id = number(value["chainId"])
    collection_id = number(value["collectionId"], nonzero=True)
    metadata = value["metadata"]
    for key, cap in (("name", 256), ("description", 2048), ("imageURI", 2048), ("animationBaseURI", 2048)):
        text_bound(metadata[key], cap)
    artist = metadata["artist"]
    nonzero_fields(artist, "acceptanceRecordHash artistId bindingHash identityRecordHash registryCodeHash snapshotHash nominatedArtist registry")
    nonzero_fields(value["renderer"], "address runtimeHash")
    for key in ("acceptedAt", "bindingGeneration", "lockedAt"):
        number(artist[key], (1 << 64) - 1, True)
    root = value["contentRoot"]
    nonzero_fields(root, "artistConsent contentRoot manifestHash recordHash routeHash stateHash publisher")
    nonzero_fields(root["leafManifest"], "artifactHash coverageHash")
    nonzero_fields(root["checkpoint"], "inventoryHash leafChainHash planHash servingStateHash")
    count = number(root["leafCount"], (1 << 64) - 1, True)
    if root["contentRoot"] != root["checkpoint"]["contentRoot"] or number(root["checkpoint"]["tokenCount"]) != count:
        raise ValueError("complete checkpoint correspondence")
    number(root["leafManifest"]["byteLength"], 524288, True)
    number(root["publishedAt"], (1 << 64) - 1, True)
    text_bound(root["manifestURI"], 2048)
    for row in (value["publication"], root):
        if number(row["authorizationClass"]) not in (7, 8):
            raise ValueError("snapshot grant class")
        number(row["grantRevision"], (1 << 64) - 1, True)
    publication = value["publication"]
    nonzero_fields(publication, "publisher snapshotId reasonHash")
    if number(publication["displayAuthorizationClass"]) not in (7, 8):
        raise ValueError("display grant class")
    for key in ("displayGrantRevision", "revision", "effectiveAt"):
        number(publication[key], (1 << 64) - 1, True)
    text_bound(publication["manifestURI"], 2048)
    if [row["role"] for row in value["sources"]] != [str(i) for i in range(9)]:
        raise ValueError("ordered fixed source roles")
    for row in value["sources"]:
        nonzero_fields(row, "address runtimeHash")
    subject = digest(
        bytes.fromhex(digest(b"6529STREAM_SUBJECT_COLLECTION_V1")[2:])
        + chain_id.to_bytes(32, "big")
        + int(value["sources"][0]["address"], 16).to_bytes(32, "big")
        + collection_id.to_bytes(32, "big")
    )
    if value["subject"] != subject:
        raise ValueError("canonical collection subject")
    entropy = value["entropy"]
    if number(entropy["policyCount"]) != len(entropy["policies"]):
        raise ValueError("complete policy count")
    previous = -1; seen = set()
    for index, policy in enumerate(entropy["policies"]):
        first = number(policy["firstTokenIndex"])
        if first <= previous or first >= count or (index == 0 and first != 0) or policy["coordinator"] in seen:
            raise ValueError("ordered original coordinator inventory")
        previous = first; seen.add(policy["coordinator"])
        # These are explicit requirements of the pinned native policy reader,
        # not a general prohibition on zero hashes in other profiles.
        nonzero_fields(policy, "coordinator indexedCodeHash moduleVersion moduleManifestHash moduleSchemaHash deploymentManifestHash policyHash provider salt")
        number(policy["epoch"], (1 << 32) - 1, True)
    return value


def generated():
    documents = {f"schemas/records/{SCHEMA}.json": schema(), f"schemas/records/{PROFILE}.json": profile()}
    out = {path: (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode() for path, value in documents.items()}
    rows = [("SCHEMA", SCHEMA, out[f"schemas/records/{SCHEMA}.json"]),
            ("PROFILE", PROFILE, out[f"schemas/records/{PROFILE}.json"]),
            ("CANON", "RFC8785_JCS", (ROOT / "schemas/museum/account-profile/RFC8785_JCS.json").read_bytes())]
    lines = ["// SPDX-License-Identifier: MIT", "pragma solidity ^0.8.19;", "",
             "/// @notice Exact native snapshot interpretation bytes, independently registered before use.",
             "/// @dev Generated by python -m tools.metadata.snapshot_profile. Do not edit.",
             "library StreamSnapshotDefinitions {"]
    for label, name, raw in rows:
        declaration = f"    bytes32 internal constant {label}_ID = keccak256(\"{name}\");"
        lines.extend(([declaration] if len(declaration) <= 100 else
                      [f"    bytes32 internal constant {label}_ID =", f"        keccak256(\"{name}\");"]))
        lines.extend([f"    bytes32 internal constant {label}_HASH =",
                      f"        {digest(raw)};",
                      f"    uint256 internal constant {label}_BYTES = {len(raw)};"])
    out["smart-contracts/domains/records/StreamSnapshotDefinitions.sol"] = ("\n".join(lines + ["}", ""])).encode()
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for relative, raw in generated().items():
        path = ROOT / relative
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise SystemExit(f"Snapshot definition differs: {relative}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print("Native snapshot schema/profile and exact definition pins match.")


if __name__ == "__main__":
    main()
