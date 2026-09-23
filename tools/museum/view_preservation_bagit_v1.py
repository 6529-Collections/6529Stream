"""Closed BagIt transport for one retained full VIEW preservation inventory.

This profile packages already verified evidence bytes.  Transport rebuilding
checks only the declared byte inventory and BagIt tags; semantic replay belongs
to the caller and no source, archive, authority, currentness or finality claim
follows from this module.
"""

from .bagit import _build_bag, _common_description, _keys
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import require
from .package import MAX_BYTES, MAX_FILES, MAX_MANIFEST


MODE = "stream_museum_view_preservation_bagit_package"
INPUT_MODE = "stream_museum_view_preservation_bagit_input"
NAME = "STREAM_MUSEUM_VIEW_PRESERVATION_BAGIT_PROFILE_V1"

PROFILE = {
    "id": NAME,
    "version": "1",
    "status": "prospective_unregistered_implementation_profile",
    "transport": (
        "Existing BagIt 1.0 exact payload/tag layout with 8192-file, 96-MiB "
        "aggregate and 2-MiB manifest bounds; every declared payload is embedded."
    ),
    "identity": (
        "Stable VIEW scope identity is chain, Core, collection and scopeId. The "
        "external identifier additionally fixes the retained source block hash."
    ),
    "semantics": (
        "A separate caller must replay the complete retained VIEW inventory before "
        "accepting this transport. This module performs no semantic replay."
    ),
    "provenance": (
        "synthetic_fixture and externally_admitted_rpc remain explicit caller "
        "admissions and are never upgraded by packaging."
    ),
    "claims": {
        "registered": False,
        "sourceAuthority": False,
        "currentness": False,
        "archiveAcceptance": False,
        "finality": False,
        "fullDossierConformance": False,
        "institutionalIngest": False,
        "networkFetch": False,
    },
}
PROFILE_BYTES = dumps(PROFILE)
PROFILE_HASH = keccak256(PROFILE_BYTES)

_DESCRIPTION_FIELDS = (
    "mode version bundleKind sourceMode disclosure externalIdentifier scope "
    "baggingDate bundleManifest schema recordChainHeads tool predecessor payloads "
    "semanticPackages"
)
_SCOPE_FIELDS = "chainId core collectionId scopeId blockNumber blockHash"


def _scope(value):
    _keys(value, _SCOPE_FIELDS, "VIEW preservation BagIt scope")
    chain_id = uint(value["chainId"])
    collection_id = uint(value["collectionId"])
    block_number = uint(value["blockNumber"])
    core = hex_bytes(value["core"], 20)
    scope_id = hex_bytes(value["scopeId"], 32)
    block_hash = hex_bytes(value["blockHash"], 32)
    require(
        chain_id > 0
        and collection_id > 0
        and block_number > 0
        and any(core)
        and any(scope_id)
        and any(block_hash),
        "VIEW preservation BagIt scope is zero",
    )
    return value


def identity(scope, identifier):
    """Return the stable VIEW scope identity after checking the state identifier."""
    scope = _scope(scope)
    stable = (
        "urn:6529stream:view-scope:"
        + scope["chainId"]
        + ":"
        + scope["core"]
        + ":"
        + scope["collectionId"]
        + ":"
        + scope["scopeId"]
    )
    require(identifier == stable + "@block:" + scope["blockHash"],
            "VIEW preservation BagIt external identifier differs")
    return stable


def external_identifier(scope):
    """Return the source-block-qualified identifier for a valid VIEW scope."""
    scope = _scope(scope)
    stable = (
        "urn:6529stream:view-scope:"
        + scope["chainId"]
        + ":"
        + scope["core"]
        + ":"
        + scope["collectionId"]
        + ":"
        + scope["scopeId"]
    )
    return stable + "@block:" + scope["blockHash"]


def description(raw):
    """Decode and validate the closed VIEW preservation packaging input."""
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    _keys(value, _DESCRIPTION_FIELDS, "VIEW preservation BagIt input")
    require(
        value["mode"] == INPUT_MODE
        and value["version"] == "1"
        and value["bundleKind"] == "VIEW_PRESERVATION_EVIDENCE_V1"
        and value["sourceMode"] in ("synthetic_fixture", "externally_admitted_rpc")
        and value["disclosure"] == "public",
        "VIEW preservation BagIt profile/disclosure differs",
    )
    identity(value["scope"], value["externalIdentifier"])
    _common_description(value)
    require(
        all(row["delivery"] == {"kind": "embedded"} for row in value["payloads"]),
        "VIEW preservation BagIt requires all payloads embedded",
    )
    return value


def build_bag(raw, payloads):
    """Build deterministic BagIt bytes after validating the closed input."""
    value = description(raw)
    return _build_bag(
        value,
        payloads,
        profile_bytes=PROFILE_BYTES,
        profile_hash=PROFILE_HASH,
        mode=MODE,
        identifier=value["externalIdentifier"],
    )


def verify_files_transport(files, expected_manifest_hash):
    """Rebuild exact transport bytes without invoking the semantic consumer."""
    require(
        type(files) is dict
        and all(type(name) is str and type(content) is bytes for name, content in files.items()),
        "VIEW preservation BagIt file map",
    )
    files = dict(files)
    require(
        len(files) <= MAX_FILES and sum(map(len, files.values())) <= MAX_BYTES,
        "VIEW preservation BagIt aggregate bound",
    )
    expected = hex_bytes(expected_manifest_hash, 32)
    require(any(expected), "VIEW preservation BagIt manifest pin is zero")
    raw = files.get("stream-manifest.json", b"")
    require(
        len(raw) <= MAX_MANIFEST and keccak256(raw) == expected_manifest_hash,
        "VIEW preservation BagIt external manifest pin differs",
    )
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(
        type(value) is dict and value.get("mode") == MODE and "input" in value,
        "VIEW preservation BagIt package mode differs",
    )
    rebuilt = build_bag(
        dumps(value["input"]),
        {name[5:]: content for name, content in files.items() if name.startswith("data/")},
    )
    require(
        rebuilt.manifest == raw and dict(rebuilt.files) == files,
        "VIEW preservation BagIt transport reconstruction differs",
    )
    return rebuilt
