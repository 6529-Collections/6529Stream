"""Pure original scoped STATIC snapshot, selection and membership commitments.

Pinned producer bytes are retained literally. Validation establishes supplied
internal consistency, never source authenticity, re-rendering, historical roles,
currentness, archive availability or policy execution.
"""
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, subject_id, uint
from .chain_abi import Array, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, generic_hash, json_values, require
from .native_finality_wire import from_json, _hash
from .scoped_static_types import *
from .independent_wire import RECORD as METADATA_RECORD

SNAPSHOT_SCHEMA_BYTES = b'{"abi":[{"name":"domain","type":"bytes32"},{"name":"chainId","type":"uint256"},{"name":"snapshotHost","type":"address"},{"name":"targets","type":"address[11]"},{"name":"codeHashes","type":"bytes32[11]"},{"components":[{"components":[{"enum":"StreamFinalityScopeType","name":"scopeType","type":"StreamFinalityScopeType"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"name":"snapshotId","type":"bytes32"},{"name":"expectedHead","type":"bytes32"},{"name":"expectedRevision","type":"uint64"},{"name":"outputManifestRecord","type":"bytes32"},{"name":"coordinatorInventoryPlan","type":"bytes32"},{"name":"expectedSourceHash","type":"bytes32"},{"name":"manifestURI","type":"string"},{"name":"effectiveAt","type":"uint64"},{"name":"reasonHash","type":"bytes32"}],"name":"publication","type":"tuple"},{"components":[{"name":"recordHash","type":"bytes32"},{"name":"scopeSubject","type":"bytes32"},{"name":"predecessor","type":"bytes32"},{"name":"revision","type":"uint64"},{"name":"chainHash","type":"bytes32"},{"name":"manifestHash","type":"bytes32"},{"name":"manifestBytes","type":"uint32"},{"name":"sourceHash","type":"bytes32"},{"name":"publisher","type":"address"},{"name":"authorizationClass","type":"uint8"},{"name":"grantRevision","type":"uint64"},{"name":"displayAuthorizationClass","type":"uint8"},{"name":"displayGrantRevision","type":"uint64"},{"name":"recordedAt","type":"uint64"},{"name":"schemaHash","type":"bytes32"},{"name":"profileHash","type":"bytes32"},{"name":"canonicalizationHash","type":"bytes32"}],"name":"receipt","type":"tuple"},{"components":[{"components":[{"enum":"StreamFinalityScopeType","name":"scopeType","type":"StreamFinalityScopeType"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"components":[{"name":"scopeSubject","type":"bytes32"},{"name":"scopeManifestHash","type":"bytes32"},{"name":"sourceRecordHash","type":"bytes32"},{"name":"tokenCount","type":"uint256"},{"name":"tokenListHash","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"inventoryCount","type":"uint256"},{"name":"inventoryPrefixHash","type":"bytes32"}],"name":"membership","type":"tuple"},{"components":[{"name":"locked","type":"bool"},{"name":"registry","type":"address"},{"name":"registryCodeHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"bindingGeneration","type":"uint64"},{"name":"bindingHash","type":"bytes32"},{"name":"nominatedArtist","type":"address"},{"name":"identityRecordHash","type":"bytes32"},{"name":"acceptanceRecordHash","type":"bytes32"},{"name":"acceptedAt","type":"uint64"},{"name":"lockedAt","type":"uint64"},{"name":"snapshotHash","type":"bytes32"}],"name":"artist","type":"tuple"},{"components":[{"components":[{"enum":"StreamFinalityScopeType","name":"scopeType","type":"StreamFinalityScopeType"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"name":"membershipHash","type":"bytes32"},{"name":"collectionStateHash","type":"bytes32"},{"name":"tokenCount","type":"uint64"},{"name":"nextIndex","type":"uint64"},{"name":"selectionRoot","type":"bytes32"}],"name":"selection","type":"tuple"},{"components":[{"name":"selectionId","type":"bytes32"},{"name":"selectionHash","type":"bytes32"},{"components":[{"enum":"StreamFinalityScopeType","name":"scopeType","type":"StreamFinalityScopeType"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"name":"tokenCount","type":"uint64"},{"name":"nextIndex","type":"uint64"},{"name":"leafChainHash","type":"bytes32"},{"name":"contentRoot","type":"bytes32"},{"name":"outputRoot","type":"bytes32"}],"name":"content","type":"tuple"},{"components":[{"name":"checkpointHash","type":"bytes32"},{"name":"checkpointStateHash","type":"bytes32"},{"name":"artifactHash","type":"bytes32"},{"name":"coverageHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"contentRoot","type":"bytes32"},{"name":"outputRoot","type":"bytes32"},{"name":"manifestHash","type":"bytes32"},{"components":[{"enum":"StreamFinalityScopeType","name":"scopeType","type":"StreamFinalityScopeType"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"name":"tokenCount","type":"uint64"},{"name":"byteLength","type":"uint64"}],"name":"outputs","type":"tuple"},{"components":[{"name":"planId","type":"bytes32"},{"name":"inventoryHash","type":"bytes32"},{"name":"policyChainHash","type":"bytes32"},{"name":"policyCount","type":"uint256"},{"name":"allFrozen","type":"bool"},{"components":[{"name":"coordinator","type":"address"},{"name":"indexedCodeHash","type":"bytes32"},{"name":"firstTokenIndex","type":"uint256"},{"name":"frozen","type":"bool"},{"name":"moduleVersion","type":"bytes32"},{"name":"moduleManifestHash","type":"bytes32"},{"name":"moduleSchemaHash","type":"bytes32"},{"name":"deploymentManifestHash","type":"bytes32"},{"name":"policyHash","type":"bytes32"},{"name":"provider","type":"address"},{"name":"epoch","type":"uint32"},{"name":"salt","type":"bytes32"},{"name":"componentDataHash","type":"bytes32"}],"name":"policies","type":"tuple[]"}],"name":"entropy","type":"tuple"}],"name":"source","type":"tuple"}],"decode":"Canonical decode and re-encode must reproduce every byte. Complete original strings, arrays and tuple order are retained.","domain":"6529STREAM_SCOPED_SNAPSHOT_PAYLOAD_V1","encoding":"STREAM_SOLIDITY_ABI_V1","enums":{"StreamFinalityScopeType":{"COLLECTION":0,"RELEASE":2,"SEASON":3,"TOKEN":1,"VIEW":4}},"name":"STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1","normalization":{"publication.expectedSourceHash":"zero; the actual derived hash is receipt.sourceHash","receipt":"recordHash, chainHash, manifestHash, manifestBytes and recordedAt are zero; every other field is the original publication fact"},"version":1}'
SNAPSHOT_PROFILE_BYTES = b'{"authority":"Original selected Metadata SNAPSHOT and IDENTITY family grants: collection class7 first, otherwise scope-zero class8. Snapshot administration does not grant Artist content-root or finality authority.","history":"Scope-bound append-only receipt and full canonical bytes. Later parent mints do not replace a sealed RELEASE or SEASON membership. Source changes fail currentness without erasing history.","limits":["Output-row archive is hashes, not all output bytes.","Snapshot is not authoritative CONTENT_ROOT publication, reference-mode evidence, render-critical closure, Artist sanction or finality.","VIEW requires actual selected view payload and renderer adoption; membership alone is insufficient.","Original COLLECTION V1 bytes, domains and policy remain unchanged."],"lock":"Exact original canonical Executor class2 action binds this host, chain, full scope, current head and revision. Lock never supplies missing external evidence.","name":"STREAM_SCOPED_STATIC_SNAPSHOT_PROFILE_V1","schema":"STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1","schemaHash":"0x499f3da8e9edac9c6fc724c2416768ec04333b31a128aed36b16b5364d91c68f","scopes":["TOKEN","RELEASE","SEASON"],"sources":"Full authoritative scope membership; exact original locked Artist presentation; complete current STATIC selection/content checkpoint and archived output-row manifest; all original scoped entropy coordinators and frozen policies. No caller-owned token list.","version":1}'
SOLIDITY_ABI_BYTES = b'{"name":"STREAM_SOLIDITY_ABI_V1","rule":"Canonical Solidity0.8.19 ABI encoding of the exact ordered closed schema tuple. Decode then abi.encode must reproduce every byte; no trailing data or alternative offsets. No transformation of embedded bytes or strings.","version":1}\n'
MEMBERSHIP_SCHEMA_BYTES = b'{\n  "name": "STREAM_SCOPE_MEMBERSHIP_V1",\n  "version": 1,\n  "format": "flat Solidity ABI tuple",\n  "canonicalization": "STREAM_SCOPE_MEMBERSHIP_ABI_V1",\n  "fields": [\n    { "name": "version", "type": "uint16", "constant": 1 },\n    { "name": "chainId", "type": "uint256" },\n    { "name": "core", "type": "address", "nonzero": true },\n    { "name": "collectionId", "type": "uint256", "nonzero": true },\n    { "name": "scopeType", "type": "uint8", "values": { "RELEASE": 2, "SEASON": 3, "VIEW": 4 } },\n    { "name": "tokenCount", "type": "uint256" },\n    { "name": "tokenListHash", "type": "bytes32", "meaning": "Keccak-256 of the complete concatenation of ordered 32-byte unsigned token IDs" },\n    { "name": "chunkHashes", "type": "bytes32[]", "meaning": "ordered native document-store Keccak-256 chunk keys" }\n  ],\n  "scopeIdentity": "Keccak-256(abi.encode(Keccak-256(UTF8(6529STREAM_SCOPE_MEMBERSHIP_ID_V1)), chainId, core, collectionId, uint8(scopeType), exactMetadataRecordHash))",\n  "record": "An authenticated SCOPE_MEMBERSHIP collection-subject record under metadata-authorized IDENTITY family classes 7 or 8. The scopeId is derived after recording and is absent from this payload.",\n  "tokenList": "Strictly increasing token IDs. Every member must be an actual completed MINTED or BURNED Core identity of the collection with matching lifecycle/burn state and collection-inventory serial. Prepared and unallocated identities are invalid. The complete list is immutable after sealing; later mints do not enlarge it.",\n  "authority": "Membership provenance does not grant artist sanction, recovery authority or permission to alter view rendering. Distinct record provenance intentionally creates distinct scope identities, including for identical token sets.",\n  "validation": "These are normative binary-profile rules enforced by the typed consumer, not executable JSON Schema keywords. The exact registered definition and canonicalization bytes are pinned. Existing legacy IDs are never aliased. Empty lists convey no finality readiness."\n}\n'
MEMBERSHIP_CANON_BYTES = b'{\n  "name": "STREAM_SCOPE_MEMBERSHIP_ABI_V1",\n  "version": 1,\n  "grammar": "abi.encode(uint16 version,uint256 chainId,address core,uint256 collectionId,uint8 scopeType,uint256 tokenCount,bytes32 tokenListHash,bytes32[] chunkHashes)",\n  "headBytes": 256,\n  "arrayOffset": 256,\n  "totalBytes": "288 + 32 * chunkHashes.length",\n  "widths": "Integers and addresses have canonical zero-extended ABI words; version equals 1 and scopeType is 2, 3 or 4. There is no outer struct offset and no trailing data.",\n  "parts": "At most 64 native document-store chunks. Every nonfinal chunk is exactly 8192 bytes. A final nonempty chunk has 32 through 8192 bytes, divisible by 32. Each chunk key is nonzero and hashes the exact retained bytes. Chunk order is authoritative.",\n  "completeList": "Concatenate all chunk bytes in order. Its byte length is exactly 32 * tokenCount and its Keccak-256 equals tokenListHash. Each word is a big-endian unsigned uint256 token ID. Member IDs must be strictly increasing. Empty lists have zero chunks and tokenListHash equal to Keccak-256 of empty bytes.",\n  "bounds": "The encoded storage profile permits 0 through 16384 IDs. There is no smaller token-list cap. A partial prefix is not a complete membership list. Any schema, width, length, partition or ordering violation rejects."\n}\n'

SNAPSHOT_SCHEMA = schema_id('STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1')
SNAPSHOT_PROFILE = schema_id('STREAM_SCOPED_STATIC_SNAPSHOT_PROFILE_V1')
SOLIDITY_ABI = schema_id('STREAM_SOLIDITY_ABI_V1')
MEMBERSHIP_SCHEMA = schema_id('STREAM_SCOPE_MEMBERSHIP_V1')
MEMBERSHIP_CANON = schema_id('STREAM_SCOPE_MEMBERSHIP_ABI_V1')
SNAPSHOT_SCHEMA_HASH = keccak256(SNAPSHOT_SCHEMA_BYTES)
SNAPSHOT_PROFILE_HASH = keccak256(SNAPSHOT_PROFILE_BYTES)
SOLIDITY_ABI_HASH = keccak256(SOLIDITY_ABI_BYTES)
MEMBERSHIP_SCHEMA_HASH = keccak256(MEMBERSHIP_SCHEMA_BYTES)
MEMBERSHIP_CANON_HASH = keccak256(MEMBERSHIP_CANON_BYTES)
DEPENDENCY_KEYS = ('core', 'metadata', 'schemas', 'store', 'router', 'scopeMembership',
                   'staticSelection', 'staticContent', 'outputManifest', 'artifacts', 'coordinatorInventory')
MAX_PAYLOAD = 524288
QUALIFICATION = [
    'Supplied original snapshot, selection and membership commitments are checked; RPC origin and historical EVM execution are not proved.',
    'Selection rows retain immutable renderer versions and original source hashes. Full renderer/config/source preimages and complete rendered bytes are not reconstructed.',
    'Original policy V1 facts are receipt-bound; policy V2 and VIEW require distinct profiles.',
    'Original locked Artist presentation and Metadata class7/class8 publication are distinct from Artist root authority.',
    'Later burns and source changes do not rewrite the original snapshot; currentness is not asserted.',
]


def definitions():
    return tuple({'name': name, 'id': schema_id(name), 'kind': kind, 'hash': keccak256(raw), 'bytes': raw}
                 for name, kind, raw in (
                     ('STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1', 0, SNAPSHOT_SCHEMA_BYTES),
                     ('STREAM_SCOPED_STATIC_SNAPSHOT_PROFILE_V1', 2, SNAPSHOT_PROFILE_BYTES),
                     ('STREAM_SOLIDITY_ABI_V1', 1, SOLIDITY_ABI_BYTES),
                     ('STREAM_SCOPE_MEMBERSHIP_V1', 0, MEMBERSHIP_SCHEMA_BYTES),
                     ('STREAM_SCOPE_MEMBERSHIP_ABI_V1', 1, MEMBERSHIP_CANON_BYTES)))


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), label + ' fields')
    return value


def _number(value):
    return from_json('uint256', value)


def _address(graph, key):
    row = graph[key]
    _closed(row, ('address', 'runtimeHash'), 'scoped graph ' + key)
    encode(('address', 'bytes32'), (row['address'], row['runtimeHash']))
    require(row['address'] != ZERO_ADDRESS and row['runtimeHash'] != ZERO, 'scoped graph missing runtime')
    return row['address']


def _scope(scope, context):
    s = from_json(SCOPE, scope)
    require(s[0] in (1, 2, 3) and s[1] == _number(context['collectionId']) > 0,
            'scoped STATIC scope unsupported')
    require((s[0] == 1 and s[2] > 0 and s[3] == ZERO)
            or (s[0] in (2, 3) and s[2] == 0 and s[3] != ZERO), 'scoped scope shape')
    return s


def scope_subject(scope, context):
    s = _scope(scope, context)
    return subject_id('token' if s[0] == 1 else 'scope', str(_number(context['chainId'])),
                      context['core'], str(s[1]), token_id=str(s[2]), scope_type=str(s[0]), scope_id=s[3])


def membership_hash(facts, scope, context, graph):
    fields = (*facts[:5], *facts[6:])
    return _hash('6529STREAM_SCOPE_MEMBERSHIP_FACTS_V1',
                 ('uint256', 'address', 'address', 'address', SCOPE, 'bytes32'),
                 (_number(context['chainId']), context['core'], _address(graph, 'metadata'),
                  _address(graph, 'tokenInventory'), scope, keccak256(encode(MEMBERSHIP_FACTS[:5] + MEMBERSHIP_FACTS[6:], fields))))


def selection_id(plan, context, graph):
    return _hash('6529STREAM_STATIC_SELECTION_CHECKPOINT_V1',
                 ('uint256', 'address', 'address', 'address', 'address', SCOPE, 'bytes32', 'bytes32'),
                 (_number(context['chainId']), _address(graph, 'staticSelection'), context['core'],
                  _address(graph, 'router'), _address(graph, 'scopeMembership'), plan[0], plan[1], plan[2]))


def selection_row_hash(row, context, graph):
    return _hash('6529STREAM_STATIC_SELECTION_ROW_V1', ('uint256', 'address', 'address', SELECTION_ROW),
                 (_number(context['chainId']), context['core'], _address(graph, 'router'), row))


def source_hash(source, dependencies, context, graph):
    return _hash('6529STREAM_SCOPED_STATIC_SNAPSHOT_SOURCES_V1',
                 ('uint256', 'address', ADDRESS11, HASH11, SNAPSHOT_SOURCE),
                 (_number(context['chainId']), _address(graph, 'scopedSnapshot'), dependencies[0], dependencies[1], source))


def snapshot_hash(publication, receipt, context, graph):
    r = list(receipt)
    r[0] = r[4] = ZERO
    return _hash('6529STREAM_SCOPED_SNAPSHOT_RECORD_V1',
                 ('uint256', 'address', 'address', 'address', SNAPSHOT_PUBLICATION, SNAPSHOT_RECEIPT),
                 (_number(context['chainId']), _address(graph, 'scopedSnapshot'), context['core'],
                  _address(graph, 'metadata'), publication, tuple(r)))


def snapshot_chain(scope, previous, receipt, context, graph):
    return _hash('6529STREAM_SCOPED_SNAPSHOT_CHAIN_V1',
                 ('uint256', 'address', 'address', SCOPE, 'bytes32', 'uint64', 'bytes32'),
                 (_number(context['chainId']), _address(graph, 'scopedSnapshot'), context['core'],
                  scope, previous, receipt[3], receipt[0]))


def snapshot_payload(publication, receipt, source, dependencies, context, graph):
    p, r = list(publication), list(receipt)
    p[6] = ZERO
    for index in (0, 4, 5): r[index] = ZERO
    for index in (6, 13): r[index] = 0
    return encode(SNAPSHOT_ENVELOPE, (schema_id('6529STREAM_SCOPED_SNAPSHOT_PAYLOAD_V1'),
        _number(context['chainId']), _address(graph, 'scopedSnapshot'), dependencies[0], dependencies[1], tuple(p), tuple(r), source))


def _carrier(value, content):
    _closed(value, ('pointer', 'codeHash', 'runtime'), 'membership carrier')
    runtime = hex_bytes(value['runtime'])
    encode(('address', 'bytes32'), (value['pointer'], value['codeHash']))
    require(value['pointer'] != ZERO_ADDRESS and runtime == b'\x00' + content
            and keccak256(runtime) == value['codeHash'], 'membership carrier bytes/hash')


def _uri(value):
    raw = value.encode('utf-8')
    accepted = (raw.startswith(b'https://') and len(raw) > 8 and raw[8] not in b'/?#') or (
        raw.startswith(b'ipfs://') and len(raw) > 7) or (raw.startswith(b'ar://') and len(raw) > 5)
    require(len(raw) <= 2048 and (not raw or (accepted and all(b > 32 and b != 127 for b in raw))),
            'snapshot manifest URI')


def _membership(value, context, graph, scope):
    _closed(value, ('facts', 'publication', 'progress', 'metadataRecord', 'manifestBytes', 'parts',
                    'tokens', 'identities', 'lifecycles', 'inventoryTokens', 'progressHistory'), 'membership')
    facts = from_json(MEMBERSHIP_FACTS, value['facts'])
    require(type(value['tokens']) is list and 0 < len(value['tokens']) <= MAX_OUTPUTS, 'membership token bound')
    tokens = tuple(_number(v) for v in value['tokens'])
    require(list(tokens) == sorted(set(tokens)) and tokens[0] > 0, 'membership token ordering')
    require(facts[0] == scope_subject(scope, context) and facts[3] == len(tokens)
            and facts[6:] == (0, ZERO), 'membership facts/count')
    require(len(value['identities']) == len(tokens) == len(value['lifecycles'])
            and len(value['inventoryTokens']) == (0 if scope[0] == 1 else len(tokens)),
            'membership identity denominator')
    serials = set()
    for index, (token, identity, lifecycle) in enumerate(zip(tokens, value['identities'], value['lifecycles'])):
        identity = from_json(('bool', 'uint256', 'uint256', 'bool'), identity)
        lifecycle = from_json('uint8', lifecycle)
        require(identity[0] and identity[1] == scope[1] and identity[2] > 0
                and identity[2] not in serials and (lifecycle, identity[3]) in ((2, False), (3, True)),
                'membership Core identity/lifecycle')
        serials.add(identity[2])
        if scope[0] != 1:
            require(_number(value['inventoryTokens'][index]) == token, 'membership inventory serial lookup')
    require(_number(context['tokenId']) in tokens, 'target token outside scoped membership')
    require(type(value['parts']) is list and type(value['progressHistory']) is list, 'membership parts/progress list')
    if scope[0] == 1:
        require(tokens == (scope[2],) and facts[1:3] == (ZERO, ZERO)
                and facts[4] == keccak256(encode(('uint256',), (scope[2],))), 'TOKEN membership facts')
        require(all(value[key] is None for key in ('publication', 'progress', 'metadataRecord', 'manifestBytes'))
                and value['parts'] == value['progressHistory'] == [], 'TOKEN has no subset publication')
    else:
        raw = hex_bytes(value['manifestBytes'])
        require(len(raw) <= 2336, 'membership manifest byte bound')
        manifest = decode(MEMBERSHIP_MANIFEST, raw, maximum=2336)
        p = from_json(MEMBERSHIP_PUBLICATION, value['publication'])
        progress = from_json(MEMBERSHIP_PROGRESS, value['progress'])
        record = from_json(METADATA_RECORD, value['metadataRecord'])
        n = (len(tokens) * 32 + 8191) // 8192
        require(manifest[:6] == (1, _number(context['chainId']), context['core'], scope[1], scope[0], len(tokens))
                and len(manifest[7]) == n and len(value['parts']) == n, 'membership manifest fields')
        whole = encode(('uint256',) * len(tokens), tokens)
        require(manifest[6] == facts[4] == keccak256(whole), 'membership whole token list hash')
        for i, part in enumerate(value['parts']):
            content = whole[8192*i:8192*(i+1)]
            _carrier(part, content)
            require(keccak256(content) == manifest[7][i], 'membership chunk hash')
        require(facts[1:3] == (keccak256(raw), p[0]) and p[1:4] == (facts[1], MEMBERSHIP_SCHEMA, MEMBERSHIP_CANON),
                'membership publication hashes/schema')
        require(p[4] != ZERO_ADDRESS and p[5] == keccak256(b'\x00' + raw) and p[6] == record[7] > 0,
                'membership original payload pointer/effective time')
        receipt = p[7]
        require(receipt[0] == scope[1] and receipt[1] != ZERO_ADDRESS and receipt[2] in (7, 8)
                and 0 < receipt[3] <= _number(context['timestamp']) and receipt[5] != ZERO
                and receipt[6] == ZERO and receipt[7:] == (MEMBERSHIP_SCHEMA_HASH, MEMBERSHIP_CANON_HASH),
                'membership Metadata original authority/definitions')
        sid = subject_id('collection', str(_number(context['chainId'])), context['core'], str(scope[1]))
        require(record[:3] == (schema_id('SCOPE_MEMBERSHIP'), sid, (1, hex_bytes(facts[1]), MEMBERSHIP_CANON))
                and record[4:7] == (MEMBERSHIP_SCHEMA, ZERO, (0, b'', ZERO)), 'membership Metadata record shape')
        require(generic_hash(_number(context['chainId']), _address(graph, 'metadata'), context['core'],
                             scope[1], receipt[1], record) == p[0], 'membership Metadata record hash')
        scope_id = _hash('6529STREAM_SCOPE_MEMBERSHIP_ID_V1', ('uint256', 'address', 'uint256', 'uint8', 'bytes32'),
                         (_number(context['chainId']), context['core'], scope[1], scope[0], p[0]))
        require(scope[3] == scope_id, 'membership scope identifier')
        require(progress == (True, True, len(tokens), len(tokens), n, n), 'membership not fully sealed')
        previous = 0
        require(0 < len(value['progressHistory']) <= n, 'membership progress history bound')
        for observed in value['progressHistory']:
            parts, count = from_json(('uint256', 'uint256'), observed)
            require(previous < parts <= n and parts - previous <= 64 and count == min(parts * 256, len(tokens)),
                    'membership progress partition')
            previous = parts
        require(previous == n, 'membership progress incomplete')
    require(facts[5] == membership_hash(facts, scope, context, graph), 'membership facts hash')
    return facts, tokens


def _selection(value, context, graph, scope, facts, tokens):
    _closed(value, ('id', 'plan', 'rows'), 'STATIC selection')
    plan = from_json(SELECTION_PLAN, value['plan'])
    require(plan[:2] == (scope, facts[5]) and plan[2] != ZERO and plan[3:5] == (len(tokens), len(tokens)),
            'STATIC selection plan membership')
    require(value['id'] == selection_id(plan, context, graph), 'STATIC selection identifier')
    require(type(value['rows']) is list and len(value['rows']) == len(tokens), 'STATIC selection row denominator')
    rows = tuple(from_json(SELECTION_ROW, row) for row in value['rows'])
    folded, hashes, runtimes = ZERO, [], {}
    def pin(address, digest, optional=False):
        require((optional and address == ZERO_ADDRESS and digest == ZERO)
                or (address != ZERO_ADDRESS and digest != ZERO), 'STATIC selection dependency shape')
        if address == ZERO_ADDRESS: return
        require(address not in runtimes or runtimes[address] == digest, 'STATIC selection runtime contradiction')
        runtimes[address] = digest
    for index, (token, row) in enumerate(zip(tokens, rows)):
        require(row[0] == token and all(h != ZERO for h in row[1:5]), 'STATIC selection original row')
        selected = row[5]
        pin(selected[0], selected[1]); pin(selected[3], selected[4])
        require(all(selected[i] != ZERO for i in (2, 5, 6, 7, 8, 9, 10)), 'STATIC immutable renderer selection')
        require(row[6][:3] == (context['core'], _address(graph, 'router'), _address(graph, 'metadata')),
                'STATIC renderer source graph')
        for j, (address, digest) in enumerate(zip(row[6], row[7])): pin(address, digest, j >= 4)
        for j, key in enumerate(('core', 'router', 'metadata')):
            require(row[7][j] == graph[key]['runtimeHash'], 'STATIC renderer original runtime')
        h = selection_row_hash(row, context, graph)
        hashes.append(h)
        folded = _hash('6529STREAM_STATIC_SELECTION_CHAIN_V1', ('bytes32', 'uint256', 'bytes32'), (folded, index, h))
    require(folded == plan[5] != ZERO, 'STATIC ordered selection root')
    return plan, rows, hashes


def _policy(source, dependencies, context, graph):
    scope, facts, _, selection, _, _, e = source
    targets = tuple(dependencies[0][i] for i in (0, 1, 5, 10))
    pins = tuple(dependencies[1][i] for i in (0, 1, 5, 10))
    plan_id = _hash('6529STREAM_COORDINATOR_INVENTORY_PLAN_V1',
                    ('uint256', 'address', 'address', 'bytes32', 'address', 'bytes32', SCOPE, MEMBERSHIP_FACTS),
                    (_number(context['chainId']), targets[3], targets[0], pins[0], targets[2], pins[2], scope, facts))
    require(e[0] == plan_id and e[1] != ZERO and e[3] == len(e[5]) and 0 < e[3] <= facts[3]
            and e[4], 'snapshot original policy inventory')
    chain = _hash('6529STREAM_ORIGINAL_COORDINATOR_POLICIES_V1',
                  ('uint256', ('address',)*4, ('bytes32',)*4, SCOPE, 'bytes32', 'bytes32', 'uint256'),
                  (_number(context['chainId']), targets, pins, scope, e[0], e[1], e[3]))
    seen, previous = set(), -1
    for index, p in enumerate(e[5]):
        require(p[0] != ZERO_ADDRESS and p[0] not in seen and p[1] != ZERO and p[3]
                and (p[2] == 0 if index == 0 else previous < p[2]) and p[2] < facts[3]
                and all(p[i] != ZERO for i in (4, 5, 6, 7, 8, 11)) and p[9] != ZERO_ADDRESS and p[10] > 0,
                'snapshot policy V1 shape/order')
        seen.add(p[0]); previous = p[2]
        component = _hash('6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1',
                          ('uint256', 'address', 'address', SCOPE, 'bytes32', 'address', 'uint32', 'bytes32'),
                          (_number(context['chainId']), context['core'], p[0], scope, p[8], p[9], p[10], p[11]))
        require(p[12] == component, 'snapshot policy component hash')
        chain = _hash('6529STREAM_ORIGINAL_COORDINATOR_POLICY_APPEND_V1', ('bytes32', 'uint256', COORDINATOR_POLICY), (chain, index, p))
    require(e[2] == chain, 'snapshot policy chain hash')


def _source(source, dependencies, context, graph, recorded_at):
    scope, facts, artist, selected, content, outputs, entropy = source
    _scope(scope, context)
    require(facts[0] == scope_subject(scope, context) and 0 < facts[3] <= MAX_OUTPUTS
            and facts[5] == membership_hash(facts, scope, context, graph), 'snapshot source membership')
    require(artist[0] and artist[1] != ZERO_ADDRESS and artist[6] != ZERO_ADDRESS
            and all(artist[i] != ZERO for i in (2, 3, 5, 7, 8, 11)) and artist[4] > 0
            and 0 < artist[9] <= artist[10] <= recorded_at, 'snapshot original locked Artist')
    require(selected[0] == content[2] == outputs[8] == scope and selected[1] == facts[5]
            and selected[2] != ZERO and selected[3] == selected[4] == content[3] == content[4] == outputs[9] == facts[3]
            and selected[5] != ZERO, 'snapshot complete native source plans')
    require(content[0] == selection_id(selected, context, graph)
            and content[1] == keccak256(encode((SELECTION_PLAN,), (selected,)))
            and content[5] != ZERO and content[6:8] == outputs[5:7]
            and all(v != ZERO for v in outputs[:8]) and outputs[4] == artist[3]
            and outputs[1] == keccak256(encode((CONTENT_PLAN,), (content,)))
            and outputs[10] == 480 + 288 * facts[3], 'snapshot content/output commitments')
    _policy(source, dependencies, context, graph)


def validate(bundle, context, graph, statement, content_result=None):
    """Validate exact retained groups; return JSON-safe crossjoin facts, never source proof."""
    statement = from_json(STATEMENT, statement)
    scope = _scope(statement[0], context)
    require(_address(graph, 'core') == context['core'], 'snapshot Core graph')
    facts, tokens = _membership(bundle['membership'], context, graph, scope)
    plan, rows, row_hashes = _selection(bundle['selection'], context, graph, scope, facts, tokens)
    snap = _closed(bundle['snapshot'], ('dependencies', 'history', 'head', 'lock'), 'snapshot')
    deps = from_json(SNAPSHOT_DEPS, snap['dependencies'])
    require(deps[0] == tuple(_address(graph, key) for key in DEPENDENCY_KEYS)
            and deps[1] == tuple(graph[key]['runtimeHash'] for key in DEPENDENCY_KEYS)
            and deps[2] == _number(context['chainId']) and 50000 <= deps[3] <= (1 << 32)-1
            and deps[4] >= deps[3] and deps[3] <= deps[5] <= (1 << 32)-1, 'snapshot immutable dependencies')
    require(type(snap['history']) is list and 0 < len(snap['history']) <= MAX_HISTORY, 'snapshot history bound')
    previous, chain, timestamp, ids, selected = ZERO, ZERO, 0, set(), None
    for index, entry in enumerate(snap['history']):
        _closed(entry, ('publication', 'receipt', 'payload'), 'snapshot history row')
        p = from_json(SNAPSHOT_PUBLICATION, entry['publication'])
        r = from_json(SNAPSHOT_RECEIPT, entry['receipt'])
        raw = hex_bytes(entry['payload'])
        require(0 < len(raw) <= MAX_PAYLOAD, 'snapshot payload byte bound')
        payload = decode(SNAPSHOT_ENVELOPE, raw, maximum=MAX_PAYLOAD)
        source = payload[-1]
        require(p[0] == scope and p[1] != ZERO and p[1] not in ids and p[2:4] == (previous, index)
                and p[4] != ZERO and p[5] == source[-1][0] and p[6] == r[7]
                and p[9] != ZERO and 0 < p[8] <= r[13], 'snapshot original publication')
        _uri(p[7])
        ids.add(p[1])
        require(r[1:4] == (facts[0], previous, index+1) and r[8] != ZERO_ADDRESS
                and r[9] in (7, 8) and r[10] > 0 and r[11] in (7, 8) and r[12] > 0
                and timestamp <= r[13] <= _number(context['timestamp']) and r[13] > 0
                and r[14:] == (SNAPSHOT_SCHEMA_HASH, SNAPSHOT_PROFILE_HASH, SOLIDITY_ABI_HASH),
                'snapshot original receipt authority/time/definitions')
        _source(source, deps, context, graph, r[13])
        require(source[0] == scope and source[1] == facts, 'snapshot scope/membership source')
        require(r[7] == source_hash(source, deps, context, graph), 'snapshot original source hash')
        require(raw == snapshot_payload(p, r, source, deps, context, graph)
                and r[5:7] == (keccak256(raw), len(raw)), 'snapshot canonical payload/hash')
        require(r[0] == snapshot_hash(p, r, context, graph), 'snapshot record hash')
        require(r[4] == snapshot_chain(scope, chain, r, context, graph), 'snapshot revision chain')
        if r[0] == statement[7][1]: selected = (p, r, source)
        previous, chain, timestamp = r[0], r[4], r[13]
    require(snap['head'] == previous and selected is not None, 'snapshot original selection/history head')
    lock = from_json(SNAPSHOT_LOCK, snap['lock'])
    require(lock[0] == selected[1][0] == snap['head'] and lock[1] == selected[1][3]
            and lock[2] != ZERO and selected[1][13] <= lock[3] <= _number(context['timestamp']),
            'snapshot original locked revision')
    source = selected[2]
    # Original inventory de-duplicates coordinators by first occurrence, not by
    # contiguous ranges. A,B,A is therefore a valid three-token source order.
    originals = {}
    for index, row in enumerate(rows):
        originals.setdefault(row[6][3], (row[7][3], index))
    require([(p[0], p[1], p[2]) for p in source[6][5]] ==
            [(address, digest, index) for address, (digest, index) in originals.items()],
            'snapshot original coordinator inventory/selection join')
    require(source[3] == plan and source[4][0] == bundle['selection']['id']
            and statement[2:4] == (source[5][5], source[5][9]) and statement[5] == selected[1][5],
            'snapshot statement/content/selection join')
    # Result keys supplied by the independent output verifier bind the exact artifact and rows.
    if content_result is not None:
        require(content_result['contentPlan'] == json_values(source[4])
                and content_result['outputManifest'] == json_values(source[5])
                and content_result['manifestRecordHash'] == selected[0][4]
                and content_result['tokenIds'] == [str(token) for token in tokens]
                and content_result['selectionRowHashes'] == row_hashes, 'snapshot verified output join')
    return {'scope': json_values(scope), 'membershipHash': facts[5], 'tokens': [str(t) for t in tokens],
            'selectionId': bundle['selection']['id'], 'selectionRowHashes': row_hashes,
            'selectedReceipt': json_values(selected[1]), 'source': json_values(source),
            'qualification': list(QUALIFICATION), 'claims': {'suppliedCommitmentsVerified': True,
                'sourceAuthenticated': False, 'historicalExecutionVerified': False,
                'fullRenderedBytesReconstructed': False, 'currentnessVerified': False,
                'completeOutputRowsJoined': content_result is not None,
                'originalRendererSourcePreimagesReconstructed': False}}


def _type(kind):
    if isinstance(kind, Array): return _type(kind.item) + '[]'
    if isinstance(kind, tuple): return '(' + ','.join(_type(k) for k in kind) + ')'
    return kind


def _descriptor(kind, host, name, signature_types, topics, data_types, values):
    return {'kind': kind, 'address': host, 'topics': [schema_id(name + '(' + ','.join(_type(k) for k in signature_types) + ')'), *topics],
            'data': '0x' + encode(data_types, values).hex()}


def expected_events(bundle, context, graph, statement):
    """Exact event payloads; parent collector verifies receipts, coordinates and chronology."""
    scope = _scope(from_json(STATEMENT, statement)[0], context)
    m, selected, snapshot = bundle['membership'], bundle['selection'], bundle['snapshot']
    out = []
    if scope[0] != 1:
        p = from_json(MEMBERSHIP_PUBLICATION, m['publication'])
        facts = from_json(MEMBERSHIP_FACTS, m['facts'])
        record = from_json(METADATA_RECORD, m['metadataRecord'])
        out.append(_descriptor('membership_recorded', _address(graph, 'metadata'), 'CollectionRecordRecorded',
            ('uint256', 'bytes32', 'bytes32', METADATA_RECORD, 'bytes32', 'bytes32', 'address', 'bytes32', 'uint16'),
            ('0x'+encode(('uint256',), (scope[1],)).hex(), record[0], record[1]),
            (METADATA_RECORD, 'bytes32', 'bytes32', 'address', 'bytes32', 'uint16'),
            (record, p[0], p[7][5], p[7][1], '0x'+encode(('uint8',), (p[7][2],)).hex(), 1)))
        out.append(_descriptor('membership_admitted', _address(graph, 'scopeMembership'), 'ScopeMembershipAdmitted',
            ('bytes32', 'uint256', 'uint8', 'bytes32', 'bytes32', 'bytes32', 'uint256', 'address', 'uint8'),
            (scope[3], '0x'+encode(('uint256',), (scope[1],)).hex(), '0x'+encode(('uint8',), (scope[0],)).hex()),
            ('bytes32', 'bytes32', 'bytes32', 'uint256', 'address', 'uint8'), (p[0], p[1], facts[4], facts[3], p[7][1], p[7][2])))
        for row in m['progressHistory']:
            parts, count = from_json(('uint256', 'uint256'), row)
            out.append(_descriptor('membership_progressed', _address(graph, 'scopeMembership'), 'ScopeMembershipProgressed',
                ('bytes32', 'uint256', 'uint256'), (scope[3],), ('uint256', 'uint256'), (parts, count)))
        out.append(_descriptor('membership_sealed', _address(graph, 'scopeMembership'), 'ScopeMembershipSealed',
            ('bytes32', 'bytes32', 'uint256'), (scope[3],), ('bytes32', 'uint256'), (facts[5], facts[3])))
    plan = from_json(SELECTION_PLAN, selected['plan'])
    initial = (*plan[:4], 0, ZERO)
    out.append(_descriptor('selection_started', _address(graph, 'staticSelection'), 'StaticSelectionStarted',
        ('uint16', 'bytes32', SELECTION_PLAN), (selected['id'],), ('uint16', SELECTION_PLAN), (1, initial)))
    for index, row in enumerate(selected['rows']):
        row = from_json(SELECTION_ROW, row)
        out.append(_descriptor('selection_appended', _address(graph, 'staticSelection'), 'StaticSelectionAppended',
            ('uint16', 'bytes32', 'uint64', SELECTION_ROW, 'bytes32'),
            (selected['id'], '0x'+encode(('uint64',), (index,)).hex()), ('uint16', SELECTION_ROW, 'bytes32'),
            (1, row, selection_row_hash(row, context, graph))))
    out.append(_descriptor('selection_completed', _address(graph, 'staticSelection'), 'StaticSelectionCompleted',
        ('uint16', 'bytes32', 'bytes32', 'uint64'), (selected['id'],), ('uint16', 'bytes32', 'uint64'), (1, plan[5], plan[3])))
    for entry in snapshot['history']:
        p, r = from_json(SNAPSHOT_PUBLICATION, entry['publication']), from_json(SNAPSHOT_RECEIPT, entry['receipt'])
        out.append(_descriptor('snapshot_published', _address(graph, 'scopedSnapshot'), 'ScopedSnapshotPublished',
            ('uint16', 'bytes32', 'bytes32', 'bytes32', SNAPSHOT_PUBLICATION, SNAPSHOT_RECEIPT),
            (r[1], p[1], r[0]), ('uint16', SNAPSHOT_PUBLICATION, SNAPSHOT_RECEIPT), (1, p, r)))
    lock = from_json(SNAPSHOT_LOCK, snapshot['lock'])
    out.append(_descriptor('snapshot_locked', _address(graph, 'scopedSnapshot'), 'ScopedSnapshotLocked',
        ('uint16', 'bytes32', SNAPSHOT_LOCK), (scope_subject(scope, context),), ('uint16', SNAPSHOT_LOCK), (1, lock)))
    return out
