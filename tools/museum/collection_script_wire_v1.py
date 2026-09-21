"""Pure native correspondence for a supplied collection script manifest.

The caller supplies an explicit original-host context and observed getters.  A
source reader separately establishes whether the manifest is current-selected
or a retained raw saved bundle.  This module verifies native typed hashes and
reconstructs every available byte.  Unavailable getter
results remain explicit and never become asserted bytes, hashes, or absence.
No script or dependency is executed and no URI is fetched.
"""

import re
from copy import deepcopy

from .canonical import MuseumError, dumps, hex_bytes, keccak256
from .independent_wire import require


SOURCE_REVISION = "a6ba57c4cf9e6972db0eb19ce40d66eed5d1ee72"
SOURCE_BLOBS = {
    "smart-contracts/domains/metadata/StreamCollectionManifestExecution.sol": "91fc7fdf807fb5b509fd9e9b80df2a572ac266c9b8fb5362e8ba37cf8f50b01a",
    "smart-contracts/domains/metadata/StreamCollectionManifests.sol": "4bab3e7add6c98e39845f5eb29f5454190cc28c5c01a3295ad97f1e8d77bfd1f",
    "smart-contracts/domains/metadata/StreamMetadataRouter.sol": "cb751f8cdb5f6e54d4f824dadb0883b32d08030361c06410ee1f3c08a0f0eabb",
    "smart-contracts/domains/metadata/StreamMetadataRouterContent.sol": "330ec5d8c51a4097f00960da8b206a500b057c88ffbfbea24d644a7422997b50",
    "smart-contracts/domains/metadata/StreamMetadataRenderer.sol": "c57e7736cd31c276bd16a189cfb26edab75dd882ff7622f0d09f84609fe3b3a0",
    "smart-contracts/domains/metadata/StreamScriptBundles.sol": "39ec7ecaa166c54263a6e14914298e69d7ba5cb4a8890fb304dd066c7a28cc56",
    "smart-contracts/interfaces/stream/metadata/IStreamCollectionManifestReads.sol": "558687f83863884b3ce19fb527b2a68c645247863de35625a730a0db36eb0062",
    "smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol": "7a1edfb0b675c8db5cc551e517228d09212b5bf822cc1cc65a1937a518c25f0c",
    "smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol": "2e59593ad917a0a46fe6bd033cf3e917948bc52245a3f8e0192c84096299fd22",
}
ZERO = "0x" + "00" * 32
ZERO_ADDRESS = "0x" + "00" * 20
STABLE_PROFILE = keccak256(b"6529STREAM_ROUTER_STABLE_PRESENTATION_V1")
CHUNKED_PROFILE = keccak256(b"6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1")
STABLE_DOMAIN = keccak256(b"6529STREAM_CURRENT_SCRIPT_MANIFEST_V1")
CHUNKED_DOMAIN = keccak256(b"6529STREAM_CHUNKED_SCRIPT_MANIFEST_V1")
BUNDLE_DOMAIN = keccak256(b"6529STREAM_IMMUTABLE_SCRIPT_BUNDLE_V1")
REGISTRY_CHUNK_DOMAIN = keccak256(
    b"6529StreamDependencyScriptChunk(uint256 index,bytes32 chunkHash,uint256 byteLength)")
REGISTRY_CONTENT_DOMAIN = keccak256(
    b"6529StreamDependencyScript(bytes32 dependencyNameAndVersion,uint256 chunkCount,bytes32 chunksHash)")
SOURCE_TYPES = tuple(range(9))
INLINE_CHUNKS = 1
SSTORE2 = 2
DEPENDENCY_REGISTRY = 4
MAX_CHUNKS = 32
MAX_INLINE_CHUNK = 8192
MAX_SSTORE2_CHUNK = 24576
MAX_PAYLOAD = MAX_CHUNKS * MAX_SSTORE2_CHUNK
MAX_URI = 2048

QUALIFICATION = (
    "Exact supplied original-context getter and native hash correspondence. Current-selected "
    "versus retained raw-saved basis must be established by a separate source reader. Available bytes are "
    "reconstructed in logical chunk order and validated as one UTF-8 stream. Unavailable "
    "getter bytes remain unavailable. No execution, safety, authorship, external URI "
    "retrieval, latest dependency version, registry eligibility, complete selection "
    "history, consensus, or archival availability is established."
)
CLAIMS = {
    "nativeManifestHashChecked": True,
    "availablePayloadBytesChecked": True,
    "availableBundleIdPreimageChecked": True,
    "orderedChunkOccurrencesPreserved": True,
    "crossChunkUtf8CheckedWhenComplete": True,
    "dependencyTypedRegistryCommitmentCheckedWhenAvailable": True,
    "scriptExecuted": False,
    "dependencyExecuted": False,
    "externalUriRetrieved": False,
    "latestRegistryVersionProven": False,
    "registryEligibilityProven": False,
    "historyCompletenessProven": False,
    "profileRegistered": False,
}
PROFILE_BYTES = dumps({
    "name": "STREAM_MUSEUM_COLLECTION_SCRIPT_WIRE_V1",
    "version": "1",
    "status": "prospective_unregistered_supplied_evidence_profile",
    "sourceRevision": SOURCE_REVISION,
    "sourceSHA256": SOURCE_BLOBS,
    "scope": "One supplied stable manifest or immutable saved script bundle in its explicit original host context, with an optional one-level library dependency. Current selection is not established here.",
    "availability": "Every optional byte getter is available with exact bytes or explicitly unavailable; unavailable values never become asserted absence or content.",
    "registry": "Registry observations are pinned to the saved RegistrySource version. Current registry eligibility and latest version are outside scope.",
    "limits": {"logicalChunks": str(MAX_CHUNKS),
        "inlineChunkBytes": str(MAX_INLINE_CHUNK),
        "sstore2ChunkBytes": str(MAX_SSTORE2_CHUNK),
        "payloadBytes": str(MAX_PAYLOAD), "uriBytes": str(MAX_URI)},
    "claims": CLAIMS,
    "qualification": QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)

CONTEXT_KEYS = {
    "chainId", "core", "collectionId", "metadata", "metadataRuntimeHash",
    "router", "routerRuntimeHash",
}
MANIFEST_KEYS = {
    "scriptHash", "rendererCompatibility", "sourceType", "libraryURI",
    "scriptURI", "sourcePointer", "mimeType", "chunkCount", "executable",
}
FACT_KEYS = {
    "payloadHash", "libraryBundle", "totalBytes", "chunkCount", "sourceType",
    "libraryOnly", "finalized",
}
REGISTRY_KEYS = {"registry", "codeHash", "dependencyId", "version", "contentHash"}
DEPENDENCY_KEYS = {
    "dependencyId", "dependencyHash", "sourceType", "dependencyURI",
    "sourcePointer", "version", "mimeType", "useDependencyRegistry",
}
SCRIPT_MANIFEST_ABI = "(bytes32,bytes32,uint8,string,string,string,string,uint256,bool)"
DEPENDENCY_MANIFEST_ABI = "(bytes32,bytes32,uint8,string,string,string,string,bool)"
SCRIPT_FACTS_ABI = "(bytes32,bytes32,uint32,uint8,uint8,bool,bool)"
REGISTRY_SOURCE_ABI = "(address,bytes32,bytes32,uint256,bytes32)"
SELECTION_ABI = "(address,bytes32,bytes32)"
SIGNATURES = {
    "scriptManifestHash": ("scriptManifestHash(uint256)", "bytes32"),
    "scriptManifest": ("scriptManifest(uint256)", SCRIPT_MANIFEST_ABI),
    "scriptChunk": ("scriptChunk(uint256,uint256)", "bytes"),
    "recordedScriptBundle": ("recordedScriptBundle(bytes32)", "bytes32"),
    "scriptBundle": ("scriptBundle(bytes32)", SCRIPT_FACTS_ABI),
    "scriptBundleRegistry": ("scriptBundleRegistry(bytes32)", REGISTRY_SOURCE_ABI),
    "scriptBundleChunk": ("scriptBundleChunk(bytes32,uint256)", "bytes"),
    "dependencyManifest": ("dependencyManifest(bytes32)", DEPENDENCY_MANIFEST_ABI),
    "dependencyChunk": ("dependencyChunk(bytes32,uint256)", "bytes"),
    "collectionScriptBundle": ("collectionScriptBundle(uint256)", SELECTION_ABI),
    "registryCount": ("getDependencyScriptCountAtVersion(bytes32,uint256)", "uint256"),
    "registryChunkHash": ("getDependencyScriptChunkHashAtVersion(bytes32,uint256,uint256)", "bytes32"),
    "registryContentHash": ("getDependencyScriptContentHashAtVersion(bytes32,uint256)", "bytes32"),
    "registryChunk": ("getDependencyScriptAtVersion(bytes32,uint256,uint256)", "string"),
}


def _uint(value, bits=256):
    require(type(value) is str and re.fullmatch(r"0|[1-9][0-9]*", value) is not None,
        "script wire canonical decimal quantity")
    number = int(value)
    require(number < 1 << bits, "script wire quantity width")
    return number


def _hash(value, label="hash"):
    require(type(value) is str and re.fullmatch(r"0x[0-9a-f]{64}", value) is not None,
        "script wire " + label)
    return value


def _address(value, label="address"):
    require(type(value) is str and re.fullmatch(r"0x[0-9a-f]{40}", value) is not None,
        "script wire " + label)
    return value


def _word(value):
    if type(value) is bool:
        value = int(value)
    elif type(value) is str:
        value = int(value, 16) if value.startswith("0x") else int(value)
    require(type(value) is int and 0 <= value < 1 << 256, "script wire ABI word")
    return value.to_bytes(32, "big")


def _tuple(items):
    """ABI encode explicit static spans and dynamic payload encodings."""
    size = sum(32 if dynamic else len(raw) for dynamic, raw in items)
    head, tail = [], b""
    for dynamic, raw in items:
        if dynamic:
            head.append(_word(size + len(tail)))
            tail += raw
        else:
            head.append(raw)
    return b"".join(head) + tail


def _text(value):
    require(type(value) is str, "script wire text")
    try:
        raw = value.encode("utf-8")
    except UnicodeError as exc:
        raise MuseumError("script wire invalid Unicode text") from exc
    return _word(len(raw)) + raw + b"\0" * ((-len(raw)) % 32)


def _array(values):
    return _word(len(values)) + b"".join(_word(value) for value in values)


def _safe_content_uri(value, allow_empty=True):
    require(type(value) is str, "script wire URI type")
    try:
        raw = value.encode("utf-8")
    except UnicodeError as exc:
        raise MuseumError("script wire invalid URI Unicode") from exc
    require(len(raw) <= MAX_URI, "script wire URI byte bound")
    if not raw:
        require(allow_empty, "script wire URI required")
        return
    require(all(byte > 0x20 and byte != 0x7f for byte in raw), "script wire URI controls")
    valid = ((raw.startswith(b"https://") and len(raw) > 8 and raw[8] not in b"/?#")
        or (raw.startswith(b"ipfs://") and len(raw) > 7)
        or (raw.startswith(b"ar://") and len(raw) > 5))
    require(valid, "script wire unsafe content URI")


def _manifest(value):
    require(type(value) is dict and set(value) == MANIFEST_KEYS,
        "script wire manifest shape")
    _hash(value["scriptHash"], "script hash")
    _hash(value["rendererCompatibility"], "renderer profile")
    source_type = _uint(value["sourceType"], 8)
    require(source_type in SOURCE_TYPES, "script wire source type")
    count = _uint(value["chunkCount"])
    require(type(value["executable"]) is bool, "script wire executable flag")
    for name in ("libraryURI", "scriptURI"):
        _safe_content_uri(value[name], True)
    require(type(value["sourcePointer"]) is str and len(value["sourcePointer"].encode("utf-8")) <= MAX_URI,
        "script wire source pointer")
    require(type(value["mimeType"]) is str and len(value["mimeType"].encode("utf-8")) <= 128,
        "script wire MIME type")
    return source_type, count


def _manifest_abi(value):
    return _tuple([
        (False, _word(value["scriptHash"])),
        (False, _word(value["rendererCompatibility"])),
        (False, _word(value["sourceType"])),
        (True, _text(value["libraryURI"])),
        (True, _text(value["scriptURI"])),
        (True, _text(value["sourcePointer"])),
        (True, _text(value["mimeType"])),
        (False, _word(value["chunkCount"])),
        (False, _word(value["executable"])),
    ])


def _facts(value):
    require(type(value) is dict and set(value) == FACT_KEYS,
        "script wire Facts shape")
    _hash(value["payloadHash"], "payload hash")
    _hash(value["libraryBundle"], "library bundle")
    total = _uint(value["totalBytes"], 32)
    count = _uint(value["chunkCount"], 8)
    source_type = _uint(value["sourceType"], 8)
    require(1 <= count <= MAX_CHUNKS and source_type in (INLINE_CHUNKS, SSTORE2, DEPENDENCY_REGISTRY)
        and total > 0 and value["payloadHash"] != ZERO
        and type(value["libraryOnly"]) is bool and type(value["finalized"]) is bool,
        "script wire Facts values")
    return total, count, source_type


def _facts_abi(value):
    return b"".join(_word(value[key]) for key in (
        "payloadHash", "libraryBundle", "totalBytes", "chunkCount", "sourceType",
        "libraryOnly", "finalized"))


def _registry(value):
    require(type(value) is dict and set(value) == REGISTRY_KEYS,
        "script wire RegistrySource shape")
    _address(value["registry"], "registry address")
    for key in ("codeHash", "dependencyId", "contentHash"):
        _hash(value[key], "registry " + key)
    version = _uint(value["version"])
    zero = value["registry"] == ZERO_ADDRESS
    require((zero and value == {"registry": ZERO_ADDRESS, "codeHash": ZERO,
        "dependencyId": ZERO, "version": "0", "contentHash": ZERO})
        or (not zero and value["codeHash"] != ZERO and value["dependencyId"] != ZERO
            and version > 0 and value["contentHash"] != ZERO),
        "script wire RegistrySource zero/nonzero form")
    return zero


def _registry_abi(value):
    return b"".join(_word(value[key]) for key in (
        "registry", "codeHash", "dependencyId", "version", "contentHash"))


def _outcome(value, kind):
    require(type(value) is dict and value.get("status") in ("available", "unavailable"),
        "script wire observation status")
    if value["status"] == "available":
        require(set(value) == {"status", "value"}, "script wire available observation shape")
        if kind == "bytes":
            raw = hex_bytes(value["value"])
            require(value["value"] == "0x" + raw.hex(), "script wire canonical observed bytes")
            return raw
        if kind == "hash":
            return _hash(value["value"], "observed hash")
        if kind == "uint":
            _uint(value["value"])
            return value["value"]
        raise MuseumError("script wire observation kind")
    require(set(value) == {"status", "kind", "code"}
        and value["kind"] in ("transport_unavailable", "provider_error", "response_size",
            "not_read_runtime_mismatch")
        and ((value["kind"] == "provider_error" and type(value["code"]) is int
              and -(1 << 31) <= value["code"] < 1 << 31)
             or (value["kind"] != "provider_error" and value["code"] is None)),
        "script wire unavailable observation shape")
    return None


def _chunks(rows, count, source_type):
    require(type(rows) is list and len(rows) == count, "script wire complete chunk denominator")
    available, complete = [], True
    cap = MAX_SSTORE2_CHUNK if source_type == SSTORE2 else MAX_INLINE_CHUNK
    for index, row in enumerate(rows):
        require(type(row) is dict and set(row) == {"index", "outcome"}
            and row["index"] == str(index), "script wire ordered chunk occurrence")
        raw = _outcome(row["outcome"], "bytes")
        if raw is None:
            complete = False
        else:
            require(0 < len(raw) <= cap, "script wire logical chunk byte bound")
        available.append(raw)
    return available, complete


def registry_content_hash(dependency_id, chunks):
    """Return the native typed rolling registry content commitment."""
    dependency_id = _hash(dependency_id, "registry dependency ID")
    sequence = ZERO
    typed = []
    for index, raw in enumerate(chunks):
        digest = keccak256(raw)
        value = keccak256(_word(REGISTRY_CHUNK_DOMAIN) + _word(index)
            + _word(digest) + _word(len(raw)))
        typed.append(value)
        sequence = keccak256(_word(sequence) + _word(value))
    content = keccak256(_word(REGISTRY_CONTENT_DOMAIN) + _word(dependency_id)
        + _word(len(chunks)) + _word(sequence))
    return content, typed


def _registry_observations(value, source, chunks, complete):
    zero = source["registry"] == ZERO_ADDRESS
    require((zero and value is None) or (not zero and type(value) is dict
        and set(value) == {"count", "chunkTypedHashes", "contentHash", "chunks"}),
        "script wire registry observation presence")
    if zero:
        return {"status": "not_applicable", "complete": True}, [None] * len(chunks)
    count = _outcome(value["count"], "uint")
    content = _outcome(value["contentHash"], "hash")
    hashes = value["chunkTypedHashes"]
    observed_chunks = value["chunks"]
    require(type(hashes) is list and type(observed_chunks) is list
        and len(hashes) == len(chunks) and len(observed_chunks) == len(chunks),
        "script wire registry observation denominator")
    decoded_hashes, decoded_chunks = [], []
    for index in range(len(chunks)):
        for rows, kind, output in ((hashes, "hash", decoded_hashes),
                (observed_chunks, "bytes", decoded_chunks)):
            row = rows[index]
            require(type(row) is dict and set(row) == {"index", "outcome"}
                and row["index"] == str(index), "script wire registry ordered observation")
            output.append(_outcome(row["outcome"], kind))
    for raw in decoded_chunks:
        require(raw is None or 0 < len(raw) <= MAX_INLINE_CHUNK,
            "script wire registry chunk byte bound")
    if count is not None:
        require(_uint(count) == len(chunks), "script wire registry chunk count")
    for index in range(len(chunks)):
        if decoded_chunks[index] is not None and chunks[index] is not None:
            require(decoded_chunks[index] == chunks[index],
                "script wire registry/host chunk bytes differ")
        raw = decoded_chunks[index] if decoded_chunks[index] is not None else chunks[index]
        if raw is not None and decoded_hashes[index] is not None:
            expected = keccak256(_word(REGISTRY_CHUNK_DOMAIN) + _word(index)
                + _word(keccak256(raw)) + _word(len(raw)))
            require(decoded_hashes[index] == expected,
                "script wire available registry typed chunk differs")
    derived = [decoded_chunks[index] if decoded_chunks[index] is not None else chunks[index]
        for index in range(len(chunks))]
    if all(value is not None for value in decoded_hashes):
        sequence = ZERO
        for value in decoded_hashes:
            sequence = keccak256(_word(sequence) + _word(value))
        calculated = keccak256(_word(REGISTRY_CONTENT_DOMAIN)
            + _word(source["dependencyId"]) + _word(len(decoded_hashes))
            + _word(sequence))
        require(source["contentHash"] == calculated,
            "script wire saved registry typed commitment differs")
        require(content is None or content == calculated,
            "script wire registry typed content getter differs")
    if all(raw is not None for raw in derived):
        calculated, typed = registry_content_hash(source["dependencyId"], derived)
        require(source["contentHash"] == calculated,
            "script wire saved registry content commitment differs")
        for actual, expected in zip(decoded_hashes, typed):
            require(actual is None or actual == expected,
                "script wire registry typed commitment differs")
        require(content is None or content == calculated,
            "script wire registry content getter differs")
    elif content is not None:
        require(content == source["contentHash"],
            "script wire available registry content differs")
    fully_observed = count is not None and content is not None
    fully_observed = fully_observed and all(v is not None for v in decoded_hashes + decoded_chunks)
    return ({"status": "complete" if fully_observed else "unavailable",
        "complete": fully_observed}, decoded_chunks)


def _plan_abi(facts, chunks):
    hashes = _array([keccak256(raw) for raw in chunks])
    lengths = _array([len(raw) for raw in chunks])
    return _tuple([
        (False, _word(facts["payloadHash"])),
        (False, _word(facts["sourceType"])),
        (True, hashes),
        (True, lengths),
        (False, _word(facts["libraryBundle"])),
        (False, _word(facts["libraryOnly"])),
    ])


def bundle_id(context, facts, registry_source, chunks):
    """Recompute the immutable native bundle ID from complete logical chunks."""
    source_hash = (ZERO if registry_source["registry"] == ZERO_ADDRESS
        else keccak256(_registry_abi(registry_source)))
    return keccak256(_tuple([
        (False, _word(BUNDLE_DOMAIN)),
        (False, _word(context["chainId"])),
        (False, _word(context["metadata"])),
        (True, _plan_abi(facts, chunks)),
        (False, _word(source_hash)),
    ]))


def _dependency_manifest(value, bundle_id_, facts, registry_source):
    require(type(value) is dict and set(value) == DEPENDENCY_KEYS,
        "script wire dependency manifest shape")
    source_nonzero = registry_source["registry"] != ZERO_ADDRESS
    expected = {
        "dependencyId": bundle_id_, "dependencyHash": facts["payloadHash"],
        "sourceType": facts["sourceType"], "dependencyURI": "",
        "sourcePointer": bundle_id_,
        "version": registry_source["version"] if source_nonzero else "",
        "mimeType": "application/javascript", "useDependencyRegistry": source_nonzero,
    }
    require(value == expected, "script wire dependency manifest differs")


def _bundle(value, context, *, library):
    keys = {"bundleId", "facts", "registrySource", "chunks", "registryObservations"}
    if library:
        keys.add("dependencyManifest")
    require(type(value) is dict and set(value) == keys, "script wire bundle shape")
    identifier = _hash(value["bundleId"], "bundle ID")
    require(identifier != ZERO, "script wire nonzero bundle ID")
    facts = value["facts"]
    total, count, source_type = _facts(facts)
    cap = MAX_SSTORE2_CHUNK if source_type == SSTORE2 else MAX_INLINE_CHUNK
    require(count <= total <= count * cap
        and facts["finalized"] and facts["libraryOnly"] is library
        and (not library or facts["libraryBundle"] == ZERO),
        "script wire finalized/library facts")
    registry_source = value["registrySource"]
    registry_zero = _registry(registry_source)
    require((source_type == DEPENDENCY_REGISTRY) == (not registry_zero),
        "script wire registry source type")
    require(library or source_type != DEPENDENCY_REGISTRY,
        "script wire executable bundle cannot use dependency registry source")
    observed, complete = _chunks(value["chunks"], count, source_type)
    available_bytes = sum(len(raw) for raw in observed if raw is not None)
    missing = sum(raw is None for raw in observed)
    require(available_bytes + missing <= total <= available_bytes + missing * cap
        and total <= MAX_PAYLOAD, "script wire Facts total byte bound")
    registry_report, registry_chunks = _registry_observations(
        value["registryObservations"], registry_source, observed, complete)
    effective = [observed[index] if observed[index] is not None else registry_chunks[index]
        for index in range(count)]
    effective_bytes = sum(len(raw) for raw in effective if raw is not None)
    effective_missing = sum(raw is None for raw in effective)
    require(effective_bytes + effective_missing <= total
        <= effective_bytes + effective_missing * cap,
        "script wire effective payload total byte bound")
    bytes_complete = all(raw is not None for raw in effective)
    payload = None
    if bytes_complete:
        payload = b"".join(effective)
        require(len(payload) == total and keccak256(payload) == facts["payloadHash"],
            "script wire complete payload/Facts differ")
        try:
            payload.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise MuseumError("script wire assembled payload is not UTF-8") from exc
        require(bundle_id(context, facts, registry_source, effective) == identifier,
            "script wire immutable bundle ID differs")
    dependency_manifest = None
    if library:
        _dependency_manifest(value["dependencyManifest"], identifier, facts, registry_source)
        dependency_manifest = deepcopy(value["dependencyManifest"])
    return {"bundleId": identifier, "facts": deepcopy(facts),
        "registrySource": deepcopy(registry_source),
        "dependencyManifest": dependency_manifest,
        "payloadStatus": "complete" if bytes_complete else "unavailable",
        "payloadBytes": str(total), "availableBytes": str(available_bytes),
        "payloadHash": facts["payloadHash"], "utf8Verified": bytes_complete,
        "bundleIdPreimageVerified": bytes_complete,
        "hostChunkReadbackComplete": complete, "registry": registry_report,
        "payloadHex": None if payload is None else "0x" + payload.hex()}


def _stable_hash(context, manifest, source_hash):
    return keccak256(_tuple([
        (False, _word(STABLE_DOMAIN)), (False, _word(context["chainId"])),
        (False, _word(context["core"])), (False, _word(context["metadata"])),
        (False, _word(context["router"])), (False, _word(context["routerRuntimeHash"])),
        (False, _word(context["collectionId"])), (False, _word(source_hash)),
        (True, _manifest_abi(manifest)),
    ]))


def _chunked_hash(context, manifest, identifier, facts):
    return keccak256(_tuple([
        (False, _word(CHUNKED_DOMAIN)), (False, _word(context["chainId"])),
        (False, _word(context["core"])), (False, _word(context["metadata"])),
        (False, _word(context["router"])), (False, _word(context["routerRuntimeHash"])),
        (False, _word(context["collectionId"])), (False, _word(identifier)),
        (False, _facts_abi(facts)), (True, _manifest_abi(manifest)),
    ]))


def _context(value):
    require(type(value) is dict and set(value) == CONTEXT_KEYS,
        "script wire context shape")
    _uint(value["chainId"]); _uint(value["collectionId"])
    for key in ("core", "metadata", "router"):
        _address(value[key], "context " + key)
    for key in ("metadataRuntimeHash", "routerRuntimeHash"):
        _hash(value[key], "context " + key)


def _selection(value, context):
    require(type(value) is dict and set(value) == {"host", "codeHash", "manifestHash"}
        and value["host"] == context["metadata"]
        and value["codeHash"] == context["metadataRuntimeHash"],
        "script wire selected manifest host")
    _hash(value["manifestHash"], "selected manifest hash")


def validate(value, context):
    """Validate supplied native facts and every available payload byte."""
    try:
        _context(context)
        require(type(value) is dict and set(value) == {
            "selection", "manifest", "stable", "script", "library"},
            "script wire input shape")
        _selection(value["selection"], context)
        source_type, manifest_count = _manifest(value["manifest"])
        manifest = value["manifest"]
        if value["stable"] is not None:
            require(value["script"] is None and value["library"] is None
                and type(value["stable"]) is dict
                and set(value["stable"]) == {"servingScriptBytes", "chunkOutcome"},
                "script wire stable branch shape")
            payload = hex_bytes(value["stable"]["servingScriptBytes"])
            require(0 < len(payload) <= MAX_INLINE_CHUNK, "script wire stable payload bound")
            try:
                payload.decode("utf-8")
            except UnicodeDecodeError as exc:
                raise MuseumError("script wire stable payload is not UTF-8") from exc
            chunk = _outcome(value["stable"]["chunkOutcome"], "bytes")
            require(chunk is None or chunk == payload, "script wire stable chunk differs")
            source_hash = keccak256(payload)
            require(manifest == {**manifest, "scriptHash": source_hash,
                "rendererCompatibility": STABLE_PROFILE, "sourceType": "1",
                "libraryURI": "", "sourcePointer": "", "mimeType": "application/javascript",
                "chunkCount": "1", "executable": True},
                "script wire stable manifest facts")
            manifest_hash = _stable_hash(context, manifest, source_hash)
            require(value["selection"]["manifestHash"] == manifest_hash,
                "script wire stable manifest hash differs")
            return {"mode": "stable_inline", "manifestHash": manifest_hash,
                "selection": deepcopy(value["selection"]), "manifest": deepcopy(manifest),
                "script": {"payloadStatus": "complete", "payloadHash": source_hash,
                    "payloadBytes": str(len(payload)), "payloadHex": "0x" + payload.hex(),
                    "utf8Verified": True, "chunkReadbackVerified": chunk is not None},
                "dependency": {"status": "authenticated_empty", "bundleId": ZERO},
                "completeScriptBytes": True, "completeDependencyBytes": True,
                "claims": CLAIMS, "qualification": QUALIFICATION}

        require(value["stable"] is None and value["script"] is not None,
            "script wire chunked branch shape")
        script = _bundle(value["script"], context, library=False)
        facts = value["script"]["facts"]
        require(manifest["rendererCompatibility"] == CHUNKED_PROFILE
            and manifest["scriptHash"] == facts["payloadHash"]
            and source_type == _uint(facts["sourceType"], 8)
            and manifest_count == _uint(facts["chunkCount"], 8)
            and manifest["sourcePointer"] == script["bundleId"]
            and manifest["mimeType"] == "application/javascript"
            and manifest["executable"] is True and facts["libraryOnly"] is False,
            "script wire chunked manifest/Facts differ")
        manifest_hash = _chunked_hash(context, manifest, script["bundleId"], facts)
        require(value["selection"]["manifestHash"] == manifest_hash,
            "script wire chunked manifest hash differs")
        if facts["libraryBundle"] == ZERO:
            require(value["library"] is None and manifest["libraryURI"] == "",
                "script wire absent dependency differs")
            dependency = {"status": "authenticated_empty", "bundleId": ZERO}
            complete_dependency = True
        else:
            require(type(value["library"]) is dict
                and value["library"].get("bundleId") == facts["libraryBundle"],
                "script wire selected dependency bundle differs")
            dependency = _bundle(value["library"], context, library=True)
            dependency["status"] = ("complete" if dependency["payloadStatus"] == "complete"
                and dependency["registry"]["complete"] else "partial_unavailable")
            complete_dependency = dependency["status"] == "complete"
        return {"mode": "immutable_bundle", "manifestHash": manifest_hash,
            "selection": deepcopy(value["selection"]), "manifest": deepcopy(manifest),
            "script": script, "dependency": dependency,
            "completeScriptBytes": script["payloadStatus"] == "complete",
            "completeDependencyBytes": complete_dependency,
            "claims": CLAIMS, "qualification": QUALIFICATION}
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError,
            UnicodeError, RecursionError) as exc:
        raise MuseumError("malformed collection script wire input") from exc
