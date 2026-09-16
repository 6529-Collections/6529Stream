"""Closed scoped evidence-dossier profile reusing the existing BagIt byte layout."""
from .bagit import (MAX_MANIFEST, _build_bag, _common_description, _keys, _citation)
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from .independent_wire import require
from .review import _validate
from .typed_authority_profile import NAMES, SCHEMAS

MODE = "stream_museum_dossier_bagit_package"
INPUT_MODE = "stream_museum_dossier_bagit_input"
NAME = "STREAM_MUSEUM_SCOPED_DOSSIER_BAGIT_PROFILE_V1"
PROFILE = {"name": NAME, "version": "1", "status": "prospective_unregistered_implementation_profile",
    "transport": "Existing BagIt 1.0 exact payload/tag layout and bounded path/hash validation; all embedded, no fetch instructions.",
    "identity": "Token scope retains its original canonical work citation. Collection scope uses urn:6529stream:subject:<canonical subjectId>@block:<source blockHash>, explicitly not a token citation. OCFL retains the same identity without the state qualifier.",
    "scope": "Exact source state from a replayed V3 semantic export. Distinct semantic evidence dossier, never an OBJECT_DOSSIER_V1 or STATE_EXPORT conformance claim.",
    "media": "Every media object required by the admitted bounded selection is locally supplied and hash/size checked before build. Full token render inventory, archival redundancy and institutional acceptance remain separate evidence.",
    "semantics": "Generic transport fixity is separate from dossier verification, which reconstructs the original authenticated semantic export, derived media requirements and all dossier contents offline.",
    "claims": {"genesisBagItProfile": False, "fullObjectDossierConformance": False, "registered": False,
        "authoritativeRenderInventory": False, "institutionalIngest": False, "networkFetch": False}}
PROFILE_BYTES = dumps(PROFILE)
PROFILE_HASH = keccak256(PROFILE_BYTES)
_EXPORT = loads(SCHEMAS[NAMES[2]], maximum=524288, canonical=True)
_SCOPE_SCHEMA = dumps({"$schema": _EXPORT["$schema"], "$defs": _EXPORT["$defs"], **_EXPORT["$defs"]["sourceState"]})


def external_identifier(scope):
    if scope["anchorSubject"]["kind"] == "token": return scope["canonicalCitation"]
    return "urn:6529stream:subject:" + scope["anchorSubject"]["subjectId"] + "@block:" + scope["blockHash"]


def identity(scope, identifier):
    _validate(_SCOPE_SCHEMA, dumps(scope))
    chain, collection = scope["chainId"], scope["collectionId"]
    require(uint(chain) > 0 and uint(collection) > 0 and any(hex_bytes(scope["core"], 20)), "dossier source scope")
    uint(scope["blockNumber"]); require(any(hex_bytes(scope["blockHash"], 32)), "dossier source block")
    kind = scope["anchorSubject"]["kind"]
    require(kind in ("collection", "token"), "dossier collection/token scope required")
    token = scope["tokenId"]
    if kind == "collection":
        require(token is None and scope["canonicalCitation"] == "", "collection dossier cannot invent token citation")
        expected = subject_id("collection", chain, scope["core"], collection)
        stable = "urn:6529stream:subject:" + expected
    else:
        require(isinstance(token, str) and uint(token) > 0, "dossier token identity")
        expected = subject_id("token", chain, scope["core"], collection, token_id=token)
        from .citations import parse_citation
        parsed = parse_citation(scope["canonicalCitation"], require_state=True)
        require((parsed["chainId"], parsed["core"], parsed["tokenId"]) == (chain, scope["core"], token), "dossier original token citation differs")
        stable = _citation(scope["canonicalCitation"])
    require(scope["anchorSubject"]["subjectId"] == expected and identifier == external_identifier(scope), "dossier canonical subject/identifier differs")
    return stable


def description(raw):
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    _keys(value, "mode version bundleKind sourceMode disclosure externalIdentifier scope baggingDate bundleManifest schema recordChainHeads tool predecessor payloads semanticPackages", "scoped dossier input")
    require(value["mode"] == INPUT_MODE and value["version"] == "1"
        and value["bundleKind"] == "MUSEUM_SEMANTIC_EVIDENCE_DOSSIER_V1"
        and value["sourceMode"] == "externally_admitted_records" and value["disclosure"] == "public", "scoped dossier profile/disclosure differs")
    identity(value["scope"], value["externalIdentifier"])
    _common_description(value)
    require(all(row["delivery"] == {"kind": "embedded"} for row in value["payloads"]), "scoped dossier requires complete embedded payloads")
    return value


def build_bag(raw, payloads):
    value = description(raw)
    return _build_bag(value, payloads, profile_bytes=PROFILE_BYTES, profile_hash=PROFILE_HASH,
        mode=MODE, identifier=value["externalIdentifier"])


def verify_files(files, expected_manifest_hash):
    files = dict(files); raw = files.get("stream-manifest.json", b"")
    require(keccak256(raw) == expected_manifest_hash, "scoped dossier bag external pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(value.get("mode") == MODE, "scoped dossier bag mode differs")
    rebuilt = build_bag(dumps(value["input"]), {name[5:]: content for name, content in files.items() if name.startswith("data/")})
    require(rebuilt.manifest == raw and dict(rebuilt.files) == files, "scoped dossier transport reconstruction differs")
    return rebuilt
