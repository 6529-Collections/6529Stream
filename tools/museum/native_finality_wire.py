"""Frozen collection inline-ONCHAIN finality ABI and pure commitment checks.

These routines validate supplied native bytes, not RPC origin, current authority,
historical EVM execution, archive availability, or an arbitrary governance batch.
"""
from copy import deepcopy

from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id, subject_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

SOURCE_REVISION = "e031ce6f5f7a79f8c098d4ad0242ee02ce1b0116"
MAX_LEAVES, MAX_CHUNKS, CHUNK_BYTES = 2729, 64, 8192
MAX_MANIFEST, MAX_CALLDATA, MAX_ROOT_HISTORY = 8192, 32768, 256
SCOPE = ("uint8", "uint256", "uint256", "bytes32")
COMPONENT = ("bytes32", "address", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32")
MANIFEST_REF = ("string", "bytes32", "bytes32", "bytes32", "bytes32")
FINALITY_RECORD = ("bool", "bytes32", "bytes32", "bytes32", "string", "bytes32", "address", "uint64")
INPUTS = ("bytes32",) * 10
STATEMENT = (SCOPE, "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bytes32", INPUTS,
    Array(COMPONENT, 9), "uint8", "uint8", "uint8")
INPUT_ENVELOPE = ("bytes32", "bytes32", "uint256", "address", "address", "address", STATEMENT)
ROOT_PUBLICATION = ("uint256", "bytes32", "bytes32", "string")
ROOT_RECORD = (ROOT_PUBLICATION, "bytes32", "uint64", "bytes32", "bytes32", "uint64", "bytes32",
    "address", "uint8", "uint64", "bytes32", "bytes32", "bytes32", "uint64")
LEAF = ("uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32")
CHECKPOINT = ("uint256", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32")
LEAF_MANIFEST = ("bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64")
LEAF_PLAN = (LEAF_MANIFEST, "uint64", "bytes32")
LEAF_ENVELOPE = ("bytes32", "uint256", "address", "address", "bytes32", "uint256", "bytes32", "uint64", Array(LEAF, MAX_LEAVES))
ARTIFACT = ("bytes32", "bytes32", "bytes32", "uint16", "bytes32", "uint64", Array("bytes32", MAX_CHUNKS), Array("uint32", MAX_CHUNKS))
COVERAGE = ("bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint32", "bytes32", "bytes32", "uint64", "bytes32")
EXECUTION_WITNESS = ("bytes32", "address", "bytes32", "bytes32", "uint64")
ARCHIVE_PROOF = ("bytes32", "bytes32", "bytes32")
ARCHIVE_WITNESS = ("bytes32", ARCHIVE_PROOF)
GOVERNANCE_ACTION = ("uint8", "uint8", "address", "uint256", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32",
    "uint64", "uint64", "address", "address", "address", "address", "bytes32", "string", "bytes32")
FINALIZE_TYPES = ("uint256", Array(COMPONENT, 32), "bytes32", MANIFEST_REF, ARCHIVE_PROOF)
FINALIZE_SIGNATURE = "finalizeCollectionArtworkWithArchive(uint256,(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32)[],bytes32,(string,bytes32,bytes32,bytes32,bytes32),(bytes32,bytes32,bytes32))"
INLINE_PROFILE = schema_id("6529STREAM_CONTENT_INLINE_ONCHAIN_V1")
INPUT_SCHEMA = schema_id("6529STREAM_FINALITY_INPUT_MANIFEST_V1")
INPUT_CANON = schema_id("6529STREAM_FINALITY_INPUT_MANIFEST_ABI_V1")
LEAF_SCHEMA = schema_id("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1")
LEAF_CANON = schema_id("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1")
ROOT_SCHEMA = schema_id("STREAM_TOKEN_CONTENT_ROOT_RECORD_V1")
ROOT_CANON = schema_id("STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1")
LEAF_DOMAIN = "0x61d75cd1a57d24657b860f99f77c15e5f8556fb725b56a96dd770205f9352b0d"
NODE_DOMAIN = "0x7239fc0713b7ccc92b7eef3087150a1f32037aff6ab05f5bf78db4f8ab71a6ea"
SANCTION = schema_id("ARTIST_SANCTION")
INDEPENDENT_FAMILIES = tuple(sorted(schema_id(name) for name in ("METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT",
    "MEDIA_MANIFEST", "SCRIPT_SOURCE", "DEPENDENCY_SOURCE", "COLLECTION_METADATA", "ENTROPY_COORDINATOR", "REFERENCE_RENDER")))
INTERFACES = {"root": "0x73664e57", "leafManifest": "0x11ccc495", "checkpoint": "0x0149fb44", "inventory": "0x055d86c0"}
FIELDS = {
    "finalityRecord": "finalized finalityRecordHash manifestContentHash manifestURIHash finalityManifestURI componentsHash manifestPointer finalizedAt".split(),
    "component": "componentType component interfaceId codeHash moduleVersion manifestHash dataHash".split(),
    "manifestRef": "uri uriHash contentHash schemaId canonicalizationHash".split(),
    "inputs": "rootRecordHash snapshotRecordHash referenceRenderRecordHash intentRecordHash intentWaiverRecordHash interviewEvidenceHash rightsStatementRecordHash workDescriptionRecordHash renderCriticalEvidenceHash bundleCoverageHash".split(),
    "statement": "scope coreFactsHash contentRoot leafCount contentRootSchemaId snapshotManifestHash referenceRenderManifestHash inputs nonSanctionComponents entropyPolicy postFreezePolicy sanctionPolicy".split(),
    "rootPublication": "collectionId expectedPredecessor verifiedManifestRecordHash manifestURI".split(),
    "rootRecord": "publication contentRoot leafCount manifestHash artistId bindingGeneration bindingHash publisher authorizationClass grantRevision routeHash stateHash artistConsent publishedAt".split(),
    "leaf": "tokenId metadataHash imageHash animationHash contentHash tokenDataHash".split(),
    "checkpoint": "collectionId tokenCount nextIndex inventoryHash servingStateHash contentRoot leafChainHash".split(),
    "leafManifest": "checkpointHash artifactHash coverageHash artistId contentRoot manifestHash collectionId tokenCount byteLength".split(),
    "artifact": "artistId schemaId canonicalizationId hashAlgorithm contentHash byteLength chunkHashes chunkLengths".split(),
    "coverage": "completionHash artifactHash artistId schemaId canonicalizationId contentHash byteLength chunkCount firstFamilyRecordHash secondFamilyRecordHash validationEpoch evidenceChainHash".split(),
    "executionWitness": "actionId proposer reasonHash roleMutationHash roleRevision".split(),
}


def from_json(kind, value):
    """Convert canonical JSON ABI mirrors, rejecting ambiguous numeric/bool forms."""
    if isinstance(kind, Array):
        require(type(value) in (tuple, list) and len(value) <= kind.maximum, "finality array bound")
        return tuple(from_json(kind.item, item) for item in value)
    if isinstance(kind, tuple):
        require(type(value) in (tuple, list) and len(value) == len(kind), "finality tuple shape")
        return tuple(from_json(item, field) for item, field in zip(kind, value))
    if kind.startswith("uint"):
        return uint(value, int(kind[4:])) if type(value) is str else _integer(value, int(kind[4:]))
    if kind == "bytes":
        return hex_bytes(value) if type(value) is str else value
    encode((kind,), (value,))
    return value


def _integer(value, bits=256):
    require(type(value) is int and 0 <= value < 1 << bits, "finality unsigned integer")
    return value


def _hash(name, kinds, values):
    return keccak256(encode(("bytes32", *kinds), (schema_id(name), *values)))


def components_hash(components):
    return _hash("6529STREAM_FINALITY_COMPONENTS_V1", (Array(COMPONENT, 32),), (components,))


def finality_hash(chain, core, collection, core_facts_hash, components, manifest):
    return _hash("6529STREAM_FINALITY_V1", ("uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"),
        (chain, core, collection, core_facts_hash, components, manifest[1], manifest[2], manifest[3], manifest[4]))


def inputs_hash(chain, core, metadata, scope, inputs):
    return _hash("6529STREAM_FINALITY_SCOPE_INPUTS_V1", ("uint256", "address", "address", SCOPE, INPUTS), (chain, core, metadata, scope, inputs))


def root_hash(chain, router, record):
    return _hash("6529STREAM_CONTENT_ROOT_RECORD_V1", ("uint256", "address", ROOT_RECORD), (chain, router, record))


def root_state_hash(chain, router, record):
    value = list(record); value[11], value[12], value[13] = ZERO, ZERO, 0
    return _hash("6529STREAM_CONTENT_ROOT_STATE_V1", ("uint256", "address", ROOT_RECORD), (chain, router, value))


def route_hash(chain, targets, hashes):
    return _hash("6529STREAM_CONTENT_ROOT_ROUTE_V1", ("uint256", ("address",) * 2, ("address",) * 10, ("bytes32",) * 10),
        (chain, (targets[0], targets[1]), targets, hashes))


def checkpoint_hash(chain, checkpoint, core, router, inventory, plan, profile=INLINE_PROFILE):
    return _hash("6529STREAM_CONTENT_CHECKPOINT_V1", ("uint256", "address", "bytes32", "address", "address", "address", "uint256", "uint256", "bytes32", "bytes32"),
        (chain, checkpoint, profile, core, router, inventory, plan[0], plan[1], plan[3], plan[4]))


def manifest_plan_hash(chain, host, core, checkpoint, artifacts, manifest):
    return _hash("6529STREAM_CONTENT_LEAF_MANIFEST_PLAN_V1", ("uint256", "address", "address", "address", "address", LEAF_MANIFEST),
        (chain, host, core, checkpoint, artifacts, manifest))


def manifest_record_hash(plan_hash):
    return _hash("6529STREAM_CONTENT_LEAF_MANIFEST_VERIFIED_V1", ("bytes32",), (plan_hash,))


def artifact_hash(chain, host, core, artifact):
    return _hash("6529STREAM_FINALITY_ARTIFACT_V1", ("uint256", "address", "address", ARTIFACT), (chain, host, core, artifact))


def archive_evidence_hash(chain, core, finality, artifacts, proof):
    return _hash("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1", ("uint256", "address", "address", "address", ARCHIVE_PROOF),
        (chain, core, finality, artifacts, proof))


def leaf_hash(chain, core, leaf):
    return keccak256(encode(("bytes32", "uint256", "address", *LEAF), (LEAF_DOMAIN, chain, core, *leaf)))


def node_hash(left, right):
    return keccak256(encode(("bytes32", "bytes32", "bytes32"), (NODE_DOMAIN, left, right)))


def _leaves(chain, core, leaves):
    require(0 < len(leaves) <= MAX_LEAVES, "finality complete leaf bound")
    previous = 0; result = []
    for leaf in leaves:
        encode((LEAF,), (leaf,))
        require(leaf[0] > previous and leaf[1] != ZERO, "finality leaf order/identity")
        previous = leaf[0]; result.append(leaf_hash(chain, core, leaf))
    return result


def tree_root(chain, core, leaves):
    level = _leaves(chain, core, leaves)
    while len(level) > 1:
        level = [node_hash(level[i], level[i + 1]) if i + 1 < len(level) else level[i] for i in range(0, len(level), 2)]
    return level[0]


def proof_for(chain, core, leaves, index):
    level = _leaves(chain, core, leaves); _integer(index)
    require(index < len(level), "finality leaf index bound")
    proof = []
    while len(level) > 1:
        if index ^ 1 < len(level): proof.append(level[index ^ 1])
        level = [node_hash(level[i], level[i + 1]) if i + 1 < len(level) else level[i] for i in range(0, len(level), 2)]
        index //= 2
    return tuple(proof)


def verify_proof(leaf_digest, index, count, proof, root):
    _integer(index); _integer(count)
    require(0 < count <= MAX_LEAVES and index < count and type(proof) in (tuple, list), "finality proof index/count")
    current, used = leaf_digest, 0
    hex_bytes(current, 32); hex_bytes(root, 32)
    while count > 1:
        if index ^ 1 < count:
            require(used < len(proof), "finality missing proof sibling")
            sibling = proof[used]; hex_bytes(sibling, 32); used += 1
            current = node_hash(sibling, current) if index & 1 else node_hash(current, sibling)
        index //= 2; count = (count + 1) // 2
    require(used == len(proof) and current == root, "finality proof/root differs")
    return True


def leaf_chain(chain, core, leaves):
    current = ZERO
    for index, digest in enumerate(_leaves(chain, core, leaves)):
        current = _hash("6529STREAM_CONTENT_CHECKPOINT_LEAVES_V1", ("bytes32", "uint256", "bytes32"), (current, index, digest))
    return current


# Exact RAW_BYTES definitions extracted from the frozen native source above.
_DEFINITION_TEXT = (
    ('STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1', 0, '{"name":"STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1","version":1,"format":"Solidity ABI","profile":"6529STREAM_CONTENT_INLINE_ONCHAIN_V1","leaves":"Every completed Core token, including burns, in checkpoint order; original entropy finalized","fields":["uint256 tokenId","bytes32 metadataHash","bytes32 imageHash","bytes32 animationHash","bytes32 contentHash","bytes32 tokenDataHash"],"hash":"Keccak-256 of exact complete bytes","metadata":"Complete deterministic Stream JSON with exact field order and integer precision; not JCS","image":"Decoded canonical inline image bytes; zero only if absent","animation":"Complete served HTML; required and nonzero","content":"No separate content asset in this profile; zero","tokenData":"Exact Core bytes, including empty bytes; hash is never an absence marker","root":"CMC-CONTENT-ROOT ordered domain-separated tree; odd node promoted without sorting or duplication"}'),
    ('STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1', 1, '{"name":"STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1","version":1,"encoding":"abi.encode(bytes32 schemaId,uint256 chainId,address core,address checkpoint,bytes32 checkpointHash,uint256 collectionId,bytes32 contentRoot,uint64 tokenCount,StreamTokenContentLeaf[] leaves)","schemaId":"keccak256(STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1)","headBytes":288,"arrayOffset":288,"headerBytesIncludingArrayCount":320,"leafBytes":192,"length":"320+192*tokenCount","arrayCount":"Exactly tokenCount; positive","words":"32-byte big-endian unsigned integers; addresses and uint64 values zero-extended","trailingBytes":"Forbidden","alternateOffsets":"Forbidden","leafOrder":"Exact checkpoint order"}'),
    ('STREAM_TOKEN_CONTENT_ROOT_RECORD_V1', 0, '{"name":"STREAM_TOKEN_CONTENT_ROOT_RECORD_V1","version":1,"format":"Solidity ABI","publication":"Artist-approved collection root backed by complete current inline-ONCHAIN checkpoint and preserved leaf manifest","tuple":"IStreamContentRootPublication.Record","fields":["Publication(uint256 collectionId,bytes32 expectedPredecessor,bytes32 verifiedManifestRecordHash,string manifestURI)","bytes32 contentRoot","uint64 leafCount","bytes32 manifestHash","bytes32 artistId","uint64 bindingGeneration","bytes32 bindingHash","address publisher","uint8 authorizationClass","uint64 grantRevision","bytes32 routeHash","bytes32 stateHash","bytes32 artistConsent","uint64 publishedAt"],"authority":"SNAPSHOT family class7 at collection or class8 at global0; nonzero governed grant revision","artist":"Exact current accepted association and operation17 CONTENT_ROOT consent","lineage":"Expected predecessor equals previous authoritative record; append-only history","scope":"Collection; other profiles and scopes are separate"}'),
    ('STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1', 1, '{"name":"STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1","version":1,"encoding":"abi.encode(IStreamContentRootPublication.Record)","strings":"Exact validated UTF-8 URI bytes; no normalization","recordHash":"keccak256(abi.encode(keccak256(6529STREAM_CONTENT_ROOT_RECORD_V1),chainId,router,record))","stateHash":"keccak256(abi.encode(keccak256(6529STREAM_CONTENT_ROOT_STATE_V1),chainId,router,recordWithStateHashConsentAndPublishedAtZero))","history":"Record includes the actual consent and publication timestamp; neither alters approved content state","trailingBytes":"Forbidden","alternateOffsets":"Forbidden"}'),
    ('6529STREAM_FINALITY_INPUT_MANIFEST_V1', 0, '{"name":"6529STREAM_FINALITY_INPUT_MANIFEST_V1","version":1,"format":"Solidity ABI","profile":"native ONCHAIN artist-bound COLLECTION","statement":"StreamFinalityInputManifestTypes.Statement","fields":["StreamFinalityScope scope","bytes32 coreFactsHash","bytes32 contentRoot","uint64 leafCount","bytes32 contentRootSchemaId","bytes32 snapshotManifestHash","bytes32 referenceRenderManifestHash","StreamFinalityScopeInputs inputs","StreamFinalityComponentExpectation[] nonSanctionComponents","uint8 entropyPolicy","uint8 postFreezePolicy","uint8 sanctionPolicy"],"inputOrder":["rootRecordHash","snapshotRecordHash","referenceRenderRecordHash","intentRecordHash","intentWaiverRecordHash","interviewEvidenceHash","rightsStatementRecordHash","workDescriptionRecordHash","renderCriticalEvidenceHash","bundleCoverageHash"],"components":"Exactly the nine required independent families in ascending family order; all seven original expectation fields retained","policies":{"entropyPolicy":1,"postFreezePolicy":1,"sanctionPolicy":1},"policyMeaning":"All members have terminal entropy; no artwork-byte mutation exceptions; actual artist sanction and its archival proof are separate execution requirements","originalEvidence":"Root and original snapshot/reference records resolve full source, renderer, context, media, native policies, runtime environment and receipt identities","excluded":"Own content hash, finality record, sanction record and signature; no mutable fixity head is substituted into original evidence","authority":"Only the fixed provider rederives and validates current facts; encoding or byte publication grants no authority or readiness"}'),
    ('6529STREAM_FINALITY_INPUT_MANIFEST_ABI_V1', 1, '{"name":"6529STREAM_FINALITY_INPUT_MANIFEST_ABI_V1","version":1,"encoding":"abi.encode(bytes32 schemaId,bytes32 canonicalizationId,uint256 chainId,address core,address metadataHost,address finalityRegistry,StreamFinalityInputManifestTypes.Statement statement)","schemaId":"keccak256(6529STREAM_FINALITY_INPUT_MANIFEST_V1)","canonicalizationId":"keccak256(6529STREAM_FINALITY_INPUT_MANIFEST_ABI_V1)","scope":"COLLECTION=0, nonzero collectionId, zero tokenId and scopeId","scopeTuple":["uint8 scopeType","uint256 collectionId","uint256 tokenId","bytes32 scopeId"],"inputTuple":["bytes32 rootRecordHash","bytes32 snapshotRecordHash","bytes32 referenceRenderRecordHash","bytes32 intentRecordHash","bytes32 intentWaiverRecordHash","bytes32 interviewEvidenceHash","bytes32 rightsStatementRecordHash","bytes32 workDescriptionRecordHash","bytes32 renderCriticalEvidenceHash","bytes32 bundleCoverageHash"],"componentTuple":["bytes32 componentType","address component","bytes4 interfaceId","bytes32 codeHash","bytes32 moduleVersion","bytes32 manifestHash","bytes32 dataHash"],"expandedEnvelope":"(bytes32,bytes32,uint256,address,address,address,((uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,bytes32,bytes32,bytes32,(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32)[],uint8,uint8,uint8))","componentCount":9,"componentWords":7,"words":"Solidity 0.8.19 canonical ABI; uint64/uint8 and addresses zero extended, bytes4 right padded","arrays":"Exact fixed family order, no duplicate or omitted family","trailingBytes":"Forbidden","alternateOffsets":"Forbidden","maximumBytes":8192,"hash":"Keccak-256 of all exact bytes","scopeInputCommitment":"Existing 6529STREAM_FINALITY_SCOPE_INPUTS_V1 domain with chainId, actual Core, actual generic metadataHost, scope and ten inputs; never provider address","retention":"The actual schema Store and original Registry staging must both retain identical complete bytes under this content hash"}'),
)


def definitions():
    return tuple({"name": name, "id": schema_id(name), "kind": kind, "hash": keccak256(text.encode("utf-8")),
        "bytes": text.encode("utf-8")} for name, kind, text in _DEFINITION_TEXT)


GRAPH_KEYS = ("core", "artist", "router", "finality", "provider", "metadata", "schemas", "leafManifest",
    "checkpoint", "artifacts", "inventory", "store", "executor", "roles")
ROUTE_KEYS = GRAPH_KEYS[:10]
FINALITY_KEYS = {"record", "components", "manifestRef", "manifestBytes", "executionWitness", "archiveWitness", "inputsHash"}
CONTENT_KEYS = {"selectedRootHash", "rootHead", "rootHistory", "manifest", "checkpoint", "artifact"}
EXECUTION_KEYS = {"action", "callDataPointer", "callDatas", "runtime"}


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), "finality " + label + " shape")


def _v(kind, value):
    result = from_json(kind, value)
    encode((kind,), (result,))
    return result


def _bytes(value, maximum, label):
    require(type(value) in (bytes, str), "finality " + label + " bytes")
    if type(value) is str:
        require(len(value) <= 2 + maximum * 2, "finality " + label + " bound")
        value = hex_bytes(value)
    require(len(value) <= maximum, "finality " + label + " bound")
    return value


def _context(context, graph):
    _closed(graph, GRAPH_KEYS, "graph")
    address_hashes = {}
    for key, row in graph.items():
        _closed(row, ("address", "runtimeHash"), "graph row")
        require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32)), "finality empty graph pin")
        require(row["address"] not in address_hashes or address_hashes[row["address"]] == row["runtimeHash"],
            "finality conflicting shared runtime pin")
        address_hashes[row["address"]] = row["runtimeHash"]
    chain, collection, token = (uint(context[key]) for key in ("chainId", "collectionId", "tokenId"))
    timestamp = uint(context["timestamp"], 64); uint(context["blockNumber"])
    require(chain > 0 and collection > 0 and token > 0 and context["core"] == graph["core"]["address"], "finality source identity")
    return chain, collection, token, timestamp


def execution_context(chain, finality, core, metadata, statement, record_hash, components_digest, archive_digest):
    scope = statement[0]
    scope_hash = _hash("6529STREAM_FINALITY_EXECUTION_SCOPE_V1", ("uint256", "address", SCOPE), (chain, finality, scope))
    inputs_digest = inputs_hash(chain, core, metadata, scope, statement[7])
    old = _hash("6529STREAM_FINALITY_EXECUTION_OLD_V1", ("bytes32", "bool", "bytes32", "bytes32", "bytes32"),
        (scope_hash, False, statement[1], components_digest, inputs_digest))
    new = _hash("6529STREAM_FINALITY_EXECUTION_ARCHIVED_NEW_V1", ("bytes32", "bool", "bytes32", "bytes32"),
        (scope_hash, True, record_hash, archive_digest))
    return {"scopeHash": scope_hash, "oldValueHash": old, "newValueHash": new, "finalityRecordHash": record_hash,
        "coreFactsHash": statement[1], "componentsHash": components_digest, "inputsHash": inputs_digest}


def validate_finality(value, context, graph):
    """Exact original receipt/manifest/sanction commitments; no current fact substitution."""
    chain, collection, _, timestamp = _context(context, graph)
    _closed(value, FINALITY_KEYS, "record group")
    r = _v(FINALITY_RECORD, value["record"])
    components = _v(Array(COMPONENT, 32), value["components"])
    manifest = _v(MANIFEST_REF, value["manifestRef"])
    witness = _v(EXECUTION_WITNESS, value["executionWitness"])
    archive = _v(ARCHIVE_WITNESS, value["archiveWitness"])
    raw = _bytes(value["manifestBytes"], MAX_MANIFEST, "input manifest")
    envelope = decode(INPUT_ENVELOPE, raw, maximum=MAX_MANIFEST)
    core, host, metadata = (graph[key]["address"] for key in ("core", "finality", "metadata"))
    require(envelope[:6] == (INPUT_SCHEMA, INPUT_CANON, chain, core, metadata, host), "finality input manifest original domain")
    statement = envelope[6]; independent = statement[8]
    require(statement[0] == (0, collection, 0, ZERO) and statement[1] != ZERO and statement[2] != ZERO
        and 0 < statement[3] <= MAX_LEAVES and statement[4] == LEAF_SCHEMA
        and statement[5] != ZERO and statement[6] != ZERO and statement[9:] == (1, 1, 1),
        "finality unsupported input manifest profile")
    inputs = statement[7]
    require(all(inputs[index] != ZERO for index in (0, 1, 2, 5, 6, 7, 8, 9))
        and ((inputs[3] == ZERO) != (inputs[4] == ZERO)), "finality input commitments")
    require(len(independent) == 9 and tuple(row[0] for row in independent) == INDEPENDENT_FAMILIES,
        "finality independent component families")
    require(len(components) == 10 and tuple(row[0] for row in components) == tuple(sorted((*INDEPENDENT_FAMILIES, SANCTION)))
        and tuple(row for row in components if row[0] != SANCTION) == independent,
        "finality complete artist component set")
    for row in components:
        require(row[1] != ZERO_ADDRESS and row[2] != "0x00000000" and all(row[index] != ZERO for index in (0, 3, 4, 5, 6)),
            "finality empty component commitment")
    sanction = next(row for row in components if row[0] == SANCTION)
    require(sanction[1] == graph["artist"]["address"] and sanction[3] == graph["artist"]["runtimeHash"]
        and sanction[6] == archive[1][0] and all(item != ZERO for item in archive[1]), "finality original sanction/archive join")
    require(archive[0] == archive_evidence_hash(chain, core, host, graph["artifacts"]["address"], archive[1]),
        "finality archive evidence hash")
    require(manifest[1] == keccak256(manifest[0].encode("utf-8")) and manifest[2] == keccak256(raw)
        and manifest[3:] == (INPUT_SCHEMA, INPUT_CANON), "finality manifest reference differs")
    digest = components_hash(components)
    expected = finality_hash(chain, core, collection, statement[1], digest, manifest)
    require(r == (True, expected, manifest[2], manifest[1], manifest[0], digest, host, r[7])
        and 0 < r[7] <= timestamp, "finality stored collection receipt differs")
    require(witness[0] != ZERO and witness[1] != ZERO_ADDRESS and witness[2] != ZERO and witness[3] != ZERO
        and witness[4] > 0, "finality execution witness shape")
    execution = execution_context(chain, host, core, metadata, statement, expected, digest, archive[0])
    require(value["inputsHash"] == execution["inputsHash"], "finality original scope-input hash")
    return {"statement": statement, "record": r, "components": components, "manifestRef": manifest,
        "executionWitness": witness, "archiveWitness": archive, "executionContext": execution,
        "historicalCoreFacts": {"status": "hash_only", "hash": statement[1], "preimage": None}}


def _root_record(chain, router, collection, timestamp, digest, record):
    r = _v(ROOT_RECORD, record); uri = r[0][3].encode("utf-8")
    require(r[0][0] == collection and r[0][2] != ZERO and r[1] != ZERO and 0 < r[2] <= MAX_LEAVES
        and all(r[index] != ZERO for index in (3, 4, 6, 10, 11, 12)) and r[5] > 0 and r[7] != ZERO_ADDRESS
        and r[8] in (7, 8) and r[9] > 0 and 0 < r[13] <= timestamp, "finality native root fields")
    valid_uri = (uri.startswith(b"https://") and len(uri) > 8 and uri[8] not in b"/?#") or (
        uri.startswith(b"ipfs://") and len(uri) > 7) or (uri.startswith(b"ar://") and len(uri) > 5)
    require(0 < len(uri) <= 2048 and valid_uri and all(byte > 32 and byte != 127 for byte in uri), "finality native root URI")
    require(digest == root_hash(chain, router, r) and r[11] == root_state_hash(chain, router, r), "finality root/state hash")
    return r


def validate_content(value, context, graph, finality):
    chain, collection, token, timestamp = _context(context, graph)
    _closed(value, CONTENT_KEYS, "content group")
    core, router = graph["core"]["address"], graph["router"]["address"]
    history = value["rootHistory"]
    require(type(history) is list and 0 < len(history) <= MAX_ROOT_HISTORY, "finality root history bound")
    previous, previous_time, records = ZERO, 0, {}
    for row in history:
        _closed(row, ("recordHash", "record"), "root history row")
        digest = row["recordHash"]; require(digest not in records, "finality duplicate root history")
        r = _root_record(chain, router, collection, timestamp, digest, row["record"])
        require(r[0][1] == previous and r[13] >= previous_time, "finality root lineage/time differs")
        records[digest] = r; previous, previous_time = digest, r[13]
    require(value["rootHead"] == previous and value["selectedRootHash"] in records
        and value["selectedRootHash"] == finality["statement"][7][0], "finality original root/head differs")
    selected = records[value["selectedRootHash"]]
    require(selected[13] <= finality["record"][7], "finality root published after finality")
    targets = tuple(graph[key]["address"] for key in ROUTE_KEYS)
    hashes = tuple(graph[key]["runtimeHash"] for key in ROUTE_KEYS)
    require(selected[10] == route_hash(chain, targets, hashes), "finality original root route differs")

    manifest, checkpoint, artifact = (value[key] for key in ("manifest", "checkpoint", "artifact"))
    _closed(manifest, ("recordHash", "planHash", "record", "plan"), "leaf manifest")
    _closed(checkpoint, ("planHash", "profile", "plan", "leaves"), "checkpoint")
    _closed(artifact, ("artifactHash", "artifact", "coverage", "chunks"), "artifact")
    m, mp = _v(LEAF_MANIFEST, manifest["record"]), _v(LEAF_PLAN, manifest["plan"])
    p = _v(CHECKPOINT, checkpoint["plan"]); leaves = _v(Array(LEAF, MAX_LEAVES), checkpoint["leaves"])
    require(checkpoint["profile"] == INLINE_PROFILE and p[0] == collection and 0 < p[1] <= MAX_LEAVES
        and p[2] == p[1] == len(leaves) and all(p[index] != ZERO for index in (3, 4, 5, 6)), "finality checkpoint completion/profile")
    require(checkpoint["planHash"] == checkpoint_hash(chain, graph["checkpoint"]["address"], core, router,
        graph["inventory"]["address"], p), "finality checkpoint plan hash")
    for leaf in leaves:
        require(leaf[3] != ZERO and leaf[4] == ZERO and leaf[5] != ZERO, "finality inline leaf semantics")
    require(p[5] == tree_root(chain, core, leaves) and p[6] == leaf_chain(chain, core, leaves), "finality checkpoint root/chain")
    require(m[0] == checkpoint["planHash"] and m[1] == artifact["artifactHash"] and m[2] != ZERO
        and m[3] == selected[4] and m[4] == p[5] == selected[1] and m[5] == selected[3]
        and m[6] == collection and m[7] == p[1] == selected[2] and m[8] == 320 + 192 * m[7],
        "finality leaf manifest/checkpoint/root fields")
    expected_plan = manifest_plan_hash(chain, graph["leafManifest"]["address"], core,
        graph["checkpoint"]["address"], graph["artifacts"]["address"], m)
    require(manifest["planHash"] == expected_plan and manifest["recordHash"] == manifest_record_hash(expected_plan)
        and selected[0][2] == manifest["recordHash"] and mp == (m, m[7], manifest["recordHash"]),
        "finality verified leaf manifest hash/plan")
    a = _v(ARTIFACT, artifact["artifact"]); coverage = _v(COVERAGE, artifact["coverage"])
    require(artifact["artifactHash"] == artifact_hash(chain, graph["artifacts"]["address"], core, a)
        and a[:6] == (m[3], LEAF_SCHEMA, LEAF_CANON, 1, m[5], m[8]), "finality leaf artifact hash/identity")
    count = (m[8] + CHUNK_BYTES - 1) // CHUNK_BYTES
    require(len(a[6]) == len(a[7]) == count and count <= MAX_CHUNKS, "finality complete artifact chunk count")
    require(coverage[:8] == (m[2], artifact["artifactHash"], m[3], LEAF_SCHEMA, LEAF_CANON, m[5], m[8], count)
        and coverage[8] != ZERO and coverage[9] != ZERO and coverage[8] != coverage[9]
        and coverage[10] > 0 and coverage[11] != ZERO, "finality original artifact coverage differs")
    require(type(artifact["chunks"]) is list and len(artifact["chunks"]) == count, "finality artifact part denominator")
    parts, pointers = [], {}
    for index, chunk in enumerate(artifact["chunks"]):
        _closed(chunk, ("pointer", "codeHash", "runtime"), "artifact chunk")
        runtime = _bytes(chunk["runtime"], CHUNK_BYTES + 1, "chunk runtime")
        expected_length = min(CHUNK_BYTES, m[8] - index * CHUNK_BYTES)
        require(any(hex_bytes(chunk["pointer"], 20)) and len(runtime) == expected_length + 1 and runtime[0] == 0
            and a[7][index] == expected_length and keccak256(runtime) == chunk["codeHash"]
            and keccak256(runtime[1:]) == a[6][index], "finality original chunk bytes/hash")
        require(chunk["pointer"] not in pointers or pointers[chunk["pointer"]] == runtime, "finality contradictory shared carrier")
        pointers[chunk["pointer"]] = runtime; parts.append(runtime[1:])
    whole = b"".join(parts)
    expected = encode(LEAF_ENVELOPE, (LEAF_SCHEMA, chain, core, graph["checkpoint"]["address"], m[0], collection, m[4], m[7], leaves))
    require(whole == expected and len(whole) == m[8] and keccak256(whole) == m[5], "finality complete leaf bytes differ")
    statement = finality["statement"]
    require(statement[2:5] == (m[4], m[7], LEAF_SCHEMA), "finality manifest content root differs")
    indices = [index for index, leaf in enumerate(leaves) if leaf[0] == token]
    require(len(indices) == 1, "finality original token absent/duplicated in complete leaves")
    index = indices[0]; leaf = leaves[index]; proof = proof_for(chain, core, leaves, index)
    return {"selectedRoot": selected, "leafManifestBytes": whole, "targetProof": {"leafIndex": str(index),
        "leafCount": str(len(leaves)), "leaf": json_values(leaf), "leafHash": leaf_hash(chain, core, leaf),
        "root": m[4], "proof": list(proof), "rootRecordHash": value["selectedRootHash"], "manifestHash": m[5]},
        "artifactCoverage": {"originalReceiptRetained": True, "coverageHash": m[2], "perChunkArchivePreimagesReconstructed": False}}


def validate_execution(value, context, graph, finality):
    _closed(value, EXECUTION_KEYS, "execution group")
    action = _v(GOVERNANCE_ACTION, value["action"])
    witness = finality["executionWitness"]; stamp = finality["record"][7]
    require(action[0] == 3 and action[1] == 2 and action[2] != ZERO_ADDRESS and action[4] != "0x00000000"
        and all(action[index] != ZERO for index in (5, 6, 7, 8)) and action[9] <= stamp <= action[10]
        and action[11] == witness[1] and action[12] != ZERO_ADDRESS and action[15] == witness[2],
        "finality original executed action/witness differs")
    require(type(value["callDatas"]) in (list, tuple) and 0 < len(value["callDatas"]) <= 64, "finality scheduled call-data bound")
    calls = tuple(_bytes(raw, MAX_CALLDATA, "scheduled call") for raw in value["callDatas"])
    expected = calldata(FINALIZE_SIGNATURE, FINALIZE_TYPES, (uint(context["collectionId"]), finality["components"],
        finality["record"][1], finality["manifestRef"], finality["archiveWitness"][1]))
    expected = hex_bytes(expected)
    require(len(expected) <= MAX_CALLDATA and calls.count(expected) == 1, "finality exact scheduled finalize data missing/duplicate")
    payload = encode((Array("bytes", 64),), (calls,)); runtime = _bytes(value["runtime"], 24576, "scheduled calldata carrier")
    require(any(hex_bytes(value["callDataPointer"], 20)) and runtime == b"\0" + payload, "finality scheduled bytes carrier differs")
    return {"matchedCallIndex": str(calls.index(expected)), "callDataKey": keccak256(b"".join(hex_bytes(keccak256(raw)) for raw in calls)),
        "callDataHash": keccak256(expected), "carrierCodeHash": keccak256(runtime), "governanceCallMetadataReconstructed": False,
        "actionIdPreimageReconstructed": False, "historicalProposerRoleRevalidated": False}


def validate_bundle(bundle, context, graph):
    """Validate all supplied native commitments. Publication coordinates remain a separate join."""
    _closed(bundle, ("finality", "content", "execution"), "bundle")
    finality = validate_finality(bundle["finality"], context, graph)
    content = validate_content(bundle["content"], context, graph, finality)
    execution = validate_execution(bundle["execution"], context, graph, finality)
    return {"statement": json_values(finality["statement"]), "executionContext": finality["executionContext"],
        "historicalCoreFacts": finality["historicalCoreFacts"], "selectedRoot": json_values(content["selectedRoot"]),
        "targetProof": content["targetProof"], "artifactCoverage": content["artifactCoverage"], "execution": execution,
        "historicalExecutionReenacted": False, "actualChainAcceptance": False}


def abi_signature(kind):
    if isinstance(kind, Array): return abi_signature(kind.item) + "[]"
    if isinstance(kind, tuple): return "(" + ",".join(abi_signature(item) for item in kind) + ")"
    return kind


EVENT_SIGNATURES = {
    "root": "TokenContentRootPublished(uint16,uint256,bytes32,bytes32," + abi_signature(ROOT_RECORD) + ")",
    "checkpointStarted": "ContentCheckpointStarted(bytes32," + abi_signature(CHECKPOINT) + ")",
    "checkpointLeaf": "ContentCheckpointLeafVerified(bytes32,uint64," + abi_signature(LEAF) + ",bytes32)",
    "checkpointCompleted": "ContentCheckpointCompleted(bytes32,bytes32,uint64)",
    "manifestStarted": "LeafManifestStarted(bytes32," + abi_signature(LEAF_MANIFEST) + ")",
    "manifestAdvanced": "LeafManifestAdvanced(bytes32,uint64,uint64)",
    "manifestVerified": "LeafManifestVerified(bytes32,bytes32," + abi_signature(LEAF_MANIFEST) + ")",
    "artifactRecorded": "FinalityArtifactRecorded(uint16,bytes32," + abi_signature(ARTIFACT) + ")",
    "coverageCompleted": "FinalityArtifactCoverageCompleted(uint16,bytes32,bytes32," + abi_signature(COVERAGE) + ")",
    "finalized": "CollectionArtworkFinalized(uint16,uint256,bytes32,address,bytes32,bytes32,string)",
    "manifestPointer": "FinalityManifestPointerRecorded(uint16,bytes32,address,bytes32)",
    "terminalExecuted": "ArtworkTerminalFreezeExecuted(uint16,bytes32,bytes32,address)",
    "executionWitness": "FinalityExecutionWitnessRecorded(uint16,bytes32,bytes32,address,bytes32,bytes32,uint64,bytes32)",
    "archiveWitness": "FinalitySanctionArchiveWitnessRecorded(uint16,bytes32,bytes32,bytes32,bytes32,bytes32)",
    "governanceScheduled": "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)",
    "governanceExecuted": "GovernanceActionExecuted(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,address,bytes32)",
    "governanceCalldataPublished": "GovernanceCallDataPublished(uint16,bytes32,address,address)",
}
EVENTS = {name: schema_id(signature) for name, signature in EVENT_SIGNATURES.items()}
EVENT_KINDS = {"root": "root_published", "checkpointStarted": "checkpoint_started", "checkpointLeaf": "leaf_verified",
    "checkpointCompleted": "checkpoint_completed", "manifestStarted": "manifest_started", "manifestAdvanced": "manifest_advanced",
    "manifestVerified": "manifest_verified", "artifactRecorded": "artifact_recorded", "coverageCompleted": "coverage_completed",
    "finalized": "finality_finalized", "manifestPointer": "pointer_recorded", "terminalExecuted": "freeze_executed",
    "executionWitness": "execution_witness", "archiveWitness": "archive_witness"}
GOVERNANCE_SCHEDULED_DATA = ("uint16", "uint256", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint64", "uint256", "address", "bytes32", "string", "bytes32")
GOVERNANCE_EXECUTED_DATA = ("uint16", "uint256", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32")
GOVERNANCE_CALLDATA_DATA = ("uint16", "address", "address")


def _topic(kind, value):
    return "0x" + encode((kind,), (value,)).hex()


def expected_events(bundle, context, graph):
    """Deterministic event payloads as closed kind/address/topics/data descriptors.

    A None topic is an unknown original coverage-plan hash, which must be a
    nonzero bytes32 in the observed event. Original scheduling nonce is not in
    stored action metadata, so its event uses validate_governance_events below.
    Manifest advancement batching and observation coordinates are caller joins.
    """
    f = validate_finality(bundle["finality"], context, graph)
    chain, cid, _, _ = _context(context, graph); content = bundle["content"]
    address = lambda name: graph[name]["address"]
    result = []
    def add(host, name, topics, types, values):
        result.append({"kind": EVENT_KINDS[name], "address": address(host), "topics": (EVENTS[name], *topics),
            "data": "0x" + encode(types, values).hex()})
    subject = subject_id("collection", str(chain), address("core"), str(cid))
    for row in content["rootHistory"]:
        record = _v(ROOT_RECORD, row["record"])
        add("router", "root", (_topic("uint256", cid), subject, row["recordHash"]), ("uint16", ROOT_RECORD), (1, record))
    checkpoint = content["checkpoint"]; plan = _v(CHECKPOINT, checkpoint["plan"]); key = checkpoint["planHash"]
    initial = (plan[0], plan[1], 0, plan[3], plan[4], ZERO, ZERO)
    add("checkpoint", "checkpointStarted", (key,), (CHECKPOINT,), (initial,))
    for index, raw in enumerate(checkpoint["leaves"]):
        leaf = _v(LEAF, raw)
        add("checkpoint", "checkpointLeaf", (key, _topic("uint64", index)), (LEAF, "bytes32"), (leaf, leaf_hash(chain, address("core"), leaf)))
    add("checkpoint", "checkpointCompleted", (key,), ("bytes32", "uint64"), (plan[5], plan[1]))
    manifest = content["manifest"]; record = _v(LEAF_MANIFEST, manifest["record"])
    add("leafManifest", "manifestStarted", (manifest["planHash"],), (LEAF_MANIFEST,), (record,))
    add("leafManifest", "manifestVerified", (manifest["recordHash"], manifest["planHash"]), (LEAF_MANIFEST,), (record,))
    artifact = content["artifact"]
    add("artifacts", "artifactRecorded", (artifact["artifactHash"],), ("uint16", ARTIFACT), (1, _v(ARTIFACT, artifact["artifact"])))
    coverage = _v(COVERAGE, artifact["coverage"])
    add("artifacts", "coverageCompleted", (coverage[0], None), ("uint16", COVERAGE), (1, coverage))
    r, w, a = f["record"], f["executionWitness"], f["archiveWitness"]
    add("finality", "finalized", (_topic("uint256", cid), r[1], _topic("address", address("executor"))),
        ("uint16", "bytes32", "bytes32", "string"), (1, r[5], r[2], r[4]))
    add("finality", "manifestPointer", (r[1],), ("uint16", "address", "bytes32"), (1, address("finality"), r[2]))
    scope_key = keccak256(encode(SCOPE, (0, cid, 0, ZERO)))
    add("finality", "terminalExecuted", (scope_key, r[1]), ("uint16", "address"), (1, address("executor")))
    add("finality", "executionWitness", (r[1], w[0], _topic("address", w[1])),
        ("uint16", "bytes32", "bytes32", "uint64", "bytes32"), (1, w[2], w[3], w[4], bundle["finality"]["inputsHash"]))
    add("finality", "archiveWitness", (r[1], a[0], a[1][0]), ("uint16", "bytes32", "bytes32"), (1, a[1][1], a[1][2]))
    return tuple(result)


def event_matches(expected, observed):
    if type(expected) is dict:
        address, topics, data = (expected[key] for key in ("address", "topics", "data"))
    else:
        address, topics, data = expected
    actual = observed["topics"]
    return observed["address"] == address and observed["data"] == data and len(actual) == len(topics) and all(
        topic == actual[index] if topic is not None else bool(any(hex_bytes(actual[index], 32)))
        for index, topic in enumerate(topics))


def validate_governance_events(bundle, context, graph, scheduled, executed):
    """Check stored original action event values; never pretend to recover GovernanceCall[]."""
    action = _v(GOVERNANCE_ACTION, bundle["execution"]["action"])
    witness = _v(EXECUTION_WITNESS, bundle["finality"]["executionWitness"])
    topics = (witness[0], _topic("uint8", action[1]), _topic("address", action[2]))
    original = decode(GOVERNANCE_SCHEDULED_DATA, _bytes(scheduled["data"], MAX_CALLDATA, "scheduled event"), maximum=MAX_CALLDATA)
    nonce = original[9]
    values = (1, *action[3:11], nonce, action[11], action[15], action[16], action[17])
    require(event_matches((graph["executor"]["address"], (EVENTS["governanceScheduled"], *topics),
        "0x" + encode(GOVERNANCE_SCHEDULED_DATA, values).hex()), scheduled), "finality governance scheduling fields")
    values = (1, *action[3:9], action[12], action[17])
    require(event_matches((graph["executor"]["address"], (EVENTS["governanceExecuted"], *topics),
        "0x" + encode(GOVERNANCE_EXECUTED_DATA, values).hex()), executed), "finality governance execution fields")
    return {"nonce": str(nonce), "actionIdPreimageReconstructed": False}


def validate_calldata_publication(bundle, context, graph, log):
    """Bind the original carrier event without identifying publisher as proposer."""
    finality = validate_finality(bundle["finality"], context, graph)
    execution = validate_execution(bundle["execution"], context, graph, finality)
    version, pointer, publisher = decode(GOVERNANCE_CALLDATA_DATA,
        _bytes(log["data"], 96, "calldata publication event"), maximum=96)
    require(version == 1 and pointer == bundle["execution"]["callDataPointer"]
        and publisher != ZERO_ADDRESS and event_matches((graph["executor"]["address"],
        (EVENTS["governanceCalldataPublished"], execution["callDataKey"]), log["data"]), log),
        "finality original calldata publication differs")
    return {"callDataKey": execution["callDataKey"], "pointer": pointer, "publisher": publisher}


# Fixed reciprocal reads. Each entry names source graph row, selector, destination
# graph row, and whether the expected result is its address or saved runtime hash.
BINDINGS = (
    ("finality", "coreReads()", "core", "address"),
    ("finality", "metadataReads()", "metadata", "address"),
    ("finality", "scopeEvidenceProvider()", "provider", "address"),
    ("finality", "scopeEvidenceProviderCodeHash()", "provider", "runtimeHash"),
    ("finality", "sanctionReads()", "artist", "address"),
    ("finality", "artifactCoverage()", "artifacts", "address"),
    ("finality", "governanceAuthority()", "executor", "address"),
    ("finality", "finalityRoleRegistry()", "roles", "address"),
    ("executor", "roleRegistry()", "roles", "address"),
    ("roles", "owner()", "executor", "address"),
    ("provider", "core()", "core", "address"),
    ("provider", "coreCodeHash()", "core", "runtimeHash"),
    ("provider", "metadataHost()", "metadata", "address"),
    ("provider", "metadataHostCodeHash()", "metadata", "runtimeHash"),
    ("provider", "metadataRouter()", "router", "address"),
    ("provider", "metadataRouterCodeHash()", "router", "runtimeHash"),
    ("provider", "schemaRegistry()", "schemas", "address"),
    ("provider", "schemaRegistryCodeHash()", "schemas", "runtimeHash"),
    ("provider", "contentLeafManifest()", "leafManifest", "address"),
    ("provider", "contentLeafManifestCodeHash()", "leafManifest", "runtimeHash"),
    ("metadata", "core()", "core", "address"), ("metadata", "schemaRegistry()", "schemas", "address"),
    ("schemas", "chunkStore()", "store", "address"),
    ("leafManifest", "core()", "core", "address"), ("leafManifest", "contentCheckpoint()", "checkpoint", "address"),
    ("leafManifest", "checkpointCodeHash()", "checkpoint", "runtimeHash"),
    ("leafManifest", "artifactCoverage()", "artifacts", "address"), ("leafManifest", "coverageCodeHash()", "artifacts", "runtimeHash"),
    ("checkpoint", "core()", "core", "address"), ("checkpoint", "coreCodeHash()", "core", "runtimeHash"),
    ("checkpoint", "metadataRouter()", "router", "address"), ("checkpoint", "routerCodeHash()", "router", "runtimeHash"),
    ("checkpoint", "tokenInventory()", "inventory", "address"), ("checkpoint", "inventoryCodeHash()", "inventory", "runtimeHash"),
    ("inventory", "core()", "core", "address"), ("inventory", "coreCodeHash()", "core", "runtimeHash"),
    ("artifacts", "core()", "core", "address"), ("artifacts", "schemaRegistry()", "schemas", "address"),
    ("artifacts", "chunkStore()", "store", "address"), ("artifacts", "finalityRegistry()", "finality", "address"),
)


def validate_event_join(bundle, context, graph, events):
    """Join supplied original event bytes, positions and native chronology.

    This checks the required immutable-event subset, not omitted receipts,
    checkpoint transactions, governance batch metadata or chain authenticity.
    """
    from .chain_history import LOG_FIELDS
    from .chain_rpc import quantity
    require(type(events) is list and 0 < len(events) <= 8192, "finality event bound")
    expected = list(expected_events(bundle, context, graph))
    source_number, source_time = uint(context["blockNumber"], 64), uint(context["timestamp"], 64)
    numbers, hashes, times = {source_number: context["blockHash"]}, {context["blockHash"]: source_number}, {source_number: source_time}
    transactions, transaction_slots, log_slots, by_kind = {}, {}, {}, {}
    previous = None
    extras = {EVENTS[key]: key for key in ("governanceScheduled", "governanceExecuted", "governanceCalldataPublished")}
    for row in events:
        _closed(row, ("log", "timestamp"), "event observation")
        log = row["log"]; _closed(log, LOG_FIELDS, "event log")
        for key, size in (("address", 20), ("blockHash", 32), ("transactionHash", 32)):
            require(any(hex_bytes(log[key], size)), "finality zero event identity")
        require(type(log["topics"]) is list and 1 <= len(log["topics"]) <= 4, "finality event topics")
        for topic in log["topics"]: hex_bytes(topic, 32)
        _bytes(log["data"], 65536, "event data")
        n, i, j = (quantity(log[key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
        require(n < 1 << 64 and i < 1 << 256 and j < 1 << 256, "finality event coordinate bound")
        stamp = uint(row["timestamp"], 64); h, tx = log["blockHash"], log["transactionHash"]
        position = (n, i, j)
        require(previous is None or previous < position, "finality event order differs")
        previous = position
        require(n <= source_number and stamp <= source_time, "finality event beyond source")
        require(numbers.setdefault(n, h) == h and hashes.setdefault(h, n) == n, "finality event block mapping differs")
        require(times.setdefault(n, stamp) == stamp, "finality event timestamp differs")
        require(transactions.setdefault(tx, (h, i)) == (h, i) and transaction_slots.setdefault((h, i), tx) == tx,
            "finality event transaction mapping differs")
        require((h, j) not in log_slots, "finality duplicate event position")
        log_slots[h, j] = i
        matches = [index for index, descriptor in enumerate(expected) if event_matches(descriptor, log)]
        if matches:
            require(len(matches) == 1, "finality ambiguous event payload")
            descriptor = expected.pop(matches[0]); kind = descriptor["kind"]
        else:
            kind = extras.get(log["topics"][0])
            require(kind is not None and kind not in by_kind, "finality unexpected/duplicate original event")
        by_kind.setdefault(kind, []).append(row)
    require(not expected, "finality missing original event")
    require(all(key in by_kind for key in extras.values()), "finality missing governance event")
    require([times[n] for n in sorted(times)] == sorted(times.values()), "finality event timestamp regresses")
    for h in hashes:
        indices = [index for (block, _), index in sorted(log_slots.items()) if block == h]
        require(indices == sorted(indices), "finality event transaction/log order differs")

    def one(kind):
        rows = by_kind[kind]
        require(len(rows) == 1, "finality event kind cardinality")
        return rows[0]
    def pos(row): return tuple(quantity(row["log"][key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
    def before(a, b): require(pos(a) < pos(b), "finality native event chronology differs")
    def same_transaction(a, b):
        require(all(a["log"][key] == b["log"][key] for key in ("blockHash", "transactionHash", "transactionIndex")),
            "finality native event transaction differs")

    scheduled, executed = one("governanceScheduled"), one("governanceExecuted")
    published = one("governanceCalldataPublished")
    validate_governance_events(bundle, context, graph, scheduled["log"], executed["log"])
    validate_calldata_publication(bundle, context, graph, published["log"])
    before(published, scheduled)
    start, completed = one("checkpoint_started"), one("checkpoint_completed")
    leaf_events = by_kind["leaf_verified"]
    require([int.from_bytes(hex_bytes(row["log"]["topics"][2], 32), "big") for row in leaf_events] == list(range(len(leaf_events))),
        "finality checkpoint leaf event order differs")
    before(start, leaf_events[0]); before(leaf_events[-1], completed)
    same_transaction(leaf_events[-1], completed)
    require(quantity(completed["log"]["logIndex"]) == quantity(leaf_events[-1]["log"]["logIndex"]) + 1,
        "finality checkpoint completion event adjacency differs")
    manifest_start, verified = one("manifest_started"), one("manifest_verified")
    artifact, coverage = one("artifact_recorded"), one("coverage_completed")
    before(artifact, coverage); before(coverage, manifest_start); before(completed, manifest_start); before(manifest_start, verified)
    roots = by_kind["root_published"]
    require([row["log"]["topics"][3] for row in roots] == [row["recordHash"] for row in bundle["content"]["rootHistory"]],
        "finality root publication lineage order differs")
    for row, original in zip(roots, bundle["content"]["rootHistory"]):
        require(uint(row["timestamp"], 64) == _v(ROOT_RECORD, original["record"])[13], "finality root publication timestamp differs")
    selected = next(row for row in roots if row["log"]["topics"][3] == bundle["content"]["selectedRootHash"])
    require(selected == roots[-1], "finality original selected root is not the final root head")
    before(verified, selected)
    terminal = [one(kind) for kind in ("finality_finalized", "pointer_recorded", "freeze_executed", "execution_witness", "archive_witness")]
    finalized = terminal[0]
    before(roots[-1], finalized); before(scheduled, finalized)
    stamp = _v(FINALITY_RECORD, bundle["finality"]["record"])[7]
    for index, row in enumerate(terminal):
        require(uint(row["timestamp"], 64) == stamp, "finality finalized publication timestamp differs")
        same_transaction(finalized, row)
        require(quantity(row["log"]["logIndex"]) == quantity(finalized["log"]["logIndex"]) + index,
            "finality terminal event adjacency differs")
    same_transaction(finalized, executed); before(terminal[-1], executed)
    return {"requiredEvents": str(len(events)), "originalChronologyChecked": True,
        "allBlockReceiptsVerified": False, "batchCallMetadataVerified": False,
        "executionTransactionInputCaptured": False, "sourceAuthenticated": False}
