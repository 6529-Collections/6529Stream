"""Finite current/saved collection-script reads at one admitted EIP-1898 block.

Successful malformed ABI is an interpretation error, never unavailability or
absence. Optional call failures retain only the transport's sanitized category.
Historical bundle getters are followed only through an admitted original host.
"""
from . import collection_script_wire_v1 as wire
from . import script_dependency_rpc_v1 as rpc
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode
from .chain_rpc import quantity
from .dossier_hosts_source import POINTER
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require


PROFILE = 'STREAM_MUSEUM_COLLECTION_SCRIPT_SOURCE_V1'
SOURCE_REVISION = wire.SOURCE_REVISION
SOURCE_BLOBS = dict(wire.SOURCE_BLOBS, **{
    'smart-contracts/core/StreamCore.sol': '490bf780d048455bbbc8a9b55ccb5efd601439bc2403e3e73e09035d9cfd1c43',
    'smart-contracts/interfaces/stream/core/IStreamCorePointers.sol': 'd3971717024317891effbb623d6ee4351427d7ba7e6ceed0f79630b5565d3a55',
    'smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol': '88f99b04d0451fe3517bc88e12bbdf0447575ab56394bf055bb3f295a9760f16',
    'smart-contracts/domains/metadata/StreamMetadataBundleRenderer.sol': '7add522a014d68cc331ab0c102c59a1188a394923ca9558dd4ebf4b35c8e2c3b',
    'smart-contracts/domains/metadata/StreamMetadataRouterCollectionReads.sol': '8faa3ad1fcaabdddcfae45aa2c1d46672a862c052dba473b62e4c70bdf936e13',
    'smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol': 'cdaafe9f3856710374ac08d43b11aab07f6dab908e2d9af8441412d0552c3ff8',
})
COMMON = ('chainId', 'core', 'collectionId', 'blockHash', 'blockNumber', 'timestamp',
    'stateRoot', 'environment', 'deploymentEvidenceHash')
MAX_ANCHOR = 65536
MAX_ABI = 65536
MAX_RUNTIME = 24576
MAX_SNAPSHOT = 32 * 1024 * 1024
SELECTION = ('address', 'bytes32', 'bytes32')
BUNDLE_SELECTION = ('address', 'bytes32', 'bytes32', 'bytes32')
FACTS = ('bytes32', 'bytes32', 'uint32', 'uint8', 'uint8', 'bool', 'bool')
REGISTRY = ('address', 'bytes32', 'bytes32', 'uint256', 'bytes32')
MANIFEST = ('bytes32', 'bytes32', 'uint8', 'string', 'string', 'string', 'string', 'uint256', 'bool')
DEPENDENCY = ('bytes32', 'bytes32', 'uint8', 'string', 'string', 'string', 'string', 'bool')
SERVING_SOURCE = ('string',) * 5
SERVING_FACTS = ('bytes32', 'bool', 'bytes32', 'address', 'bytes32', 'bytes32', 'uint32',
    'bytes32', 'bytes32', 'bool', 'bool', 'bool', 'bool', 'bool', 'bool', 'bool')
NAMES = {
    'selection': ('host', 'codeHash', 'manifestHash'),
    'rawBundle': ('host', 'codeHash', 'bundleId', 'manifestHash'),
    'manifest': ('scriptHash', 'rendererCompatibility', 'sourceType', 'libraryURI', 'scriptURI',
        'sourcePointer', 'mimeType', 'chunkCount', 'executable'),
    'facts': ('payloadHash', 'libraryBundle', 'totalBytes', 'chunkCount', 'sourceType', 'libraryOnly', 'finalized'),
    'registry': ('registry', 'codeHash', 'dependencyId', 'version', 'contentHash'),
    'dependency': ('dependencyId', 'dependencyHash', 'sourceType', 'dependencyURI', 'sourcePointer',
        'version', 'mimeType', 'useDependencyRegistry'),
    'servingSource': ('name', 'description', 'imageURI', 'animationBaseURI', 'script'),
    'servingFacts': ('presentationProfile', 'configured', 'mode', 'renderer', 'rendererCodeHash',
        'scriptHash', 'scriptBytes', 'imageURIHash', 'animationBaseURIHash', 'scriptLocked',
        'mediaLocked', 'baseURILocked', 'dependenciesLocked', 'artistIdentityLocked',
        'displayMetadataLocked', 'coreFrozen'),
}
CLAIMS = {'currentCorePointerAndImmutableGraphChecked': True,
    'currentAndSavedRoutesReadSeparately': True, 'orderedOptionalCallOutcomesRetained': True,
    'runtimeBridgeContentsVerified': False, 'currentModuleRegistryEligibilityProven': False,
    'completeSelectionHistoryProven': False, 'physicalStorageCarrierProven': False,
    'sourceOriginAuthenticated': False, 'consensusVerified': False, 'scriptExecuted': False,
    'dependencyLatestVersionProven': False, 'uriRetrieved': False}
QUALIFICATION = ('One admitted block, current Core Metadata/Router/Store bindings and separate current '
    'selection, raw saved bundle and serving observations. Stored Core pointer Registry commitments '
    'are retained without a present ACTIVE or eligibility gate. Original Metadata hosts require an '
    'external runtime pin; immutable RegistrySource code hashes are compared with observed runtime. '
    'Changed Registry code causes explicit not-read runtime mismatch, not fabricated RPC failure. '
    'Unavailable calls never establish absence; successful empty bytes remain available and malformed '
    'ABI fails interpretation. No event/history completeness, storage carrier proof, JavaScript '
    'execution, URI delivery, current authority, runtime bridge authentication or consensus is claimed.')
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1', 'sourceRevision': SOURCE_REVISION,
    'nativeSourceBlobs': SOURCE_BLOBS, 'wireProfileHash': wire.PROFILE_HASH,
    'transportProfileHash': rpc.PROFILE_HASH, 'claims': CLAIMS, 'qualification': QUALIFICATION,
    'limits': {'anchorBytes': str(MAX_ANCHOR), 'abiBytes': str(MAX_ABI),
        'runtimeBytes': str(MAX_RUNTIME), 'snapshotBytes': str(MAX_SNAPSHOT), 'codePins': '64'}})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def named(label, values):
    return dict(zip(NAMES[label], json_values(values)))


class CollectionScriptSource:
    def __init__(self, anchor_raw, transport, *, provenance='synthetic_fixture'):
        require(provenance in ('synthetic_fixture', 'trusted_rpc') and
            (provenance != 'trusted_rpc' or type(transport) in (rpc.RpcTransport, rpc.ReplayTransport)),
            'script source provenance')
        a = loads(anchor_raw, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) |
            {'profile', 'coreRuntimeHash', 'codePins', 'runtimeAdmission'} and a['profile'] == PROFILE,
            'script source anchor shape/profile')
        require(uint(a['chainId']) > 0 and uint(a['collectionId']) > 0 and
            uint(a['blockNumber']) >= 0 and 0 < uint(a['timestamp']) < 1 << 64 and
            a['environment'] in ('local_evm_fixture', 'public_chain') and any(hex_bytes(a['core'], 20)),
            'script source state')
        for key in ('blockHash', 'stateRoot', 'deploymentEvidenceHash', 'coreRuntimeHash'):
            require(any(hex_bytes(a[key], 32)), 'script source zero commitment')
        admission = a['runtimeAdmission']
        require(type(admission) is dict and set(admission) == {'sourceCommit', 'kind', 'artifactHash'} and
            admission['sourceCommit'] == SOURCE_REVISION and admission['kind'] ==
            ('synthetic_fixture' if provenance == 'synthetic_fixture' else 'externally_admitted_runtime')
            and any(hex_bytes(admission['artifactHash'], 32)), 'script source runtime admission')
        require(type(a['codePins']) is list and 4 <= len(a['codePins']) <= 64, 'script source pin bound')
        self.pins = {}
        for row in a['codePins']:
            require(type(row) is dict and set(row) == {'address', 'runtimeHash'} and
                row['address'] not in self.pins and any(hex_bytes(row['address'], 20)) and
                any(hex_bytes(row['runtimeHash'], 32)), 'script source duplicate/invalid pin')
            self.pins[row['address']] = row['runtimeHash']
        require(self.pins.get(a['core']) == a['coreRuntimeHash'], 'script Core pin differs')
        self.a, self.anchor_bytes, self.provenance = a, bytes(anchor_raw), provenance
        self.reader = rpc.RecordingReader(transport, a['blockHash'])
        self.runtime_pins, self.runtime_observations, self.observations = {}, [], []
        self._snapshot, self._started = None, False

    def _read(self, host, signature, output, inputs=(), args=()):
        raw = hex_bytes(self.reader.call(host, calldata(signature, inputs, args)))
        return decode((output,), raw, maximum=MAX_ABI)[0]

    def _optional(self, label, host, signature, output, inputs=(), args=(), names=None):
        outcome = self.reader.call_outcome(host, calldata(signature, inputs, args))
        row = {'label': label, 'target': host, 'signature': signature, 'arguments': json_values(args),
            'outcome': outcome, 'decoded': None}
        self.observations.append(row)
        if outcome['status'] == 'unavailable':
            return dict(outcome)
        value = decode((output,), hex_bytes(outcome['result']), maximum=MAX_ABI)[0]
        value = named(names, value) if names else json_values(value)
        row['decoded'] = value
        return {'status': 'available', 'value': value}

    def _runtime(self, address, expected=None, *, mandatory=False):
        raw = hex_bytes(self.reader.code(address))
        require(len(raw) <= MAX_RUNTIME, 'script runtime byte bound')
        digest = keccak256(raw)
        require(address not in self.runtime_pins or self.runtime_pins[address] == digest,
            'script contradictory runtime observations')
        self.runtime_pins[address] = digest
        matched = bool(raw) and (expected is None or digest == expected)
        self.runtime_observations.append({'address': address, 'observedRuntimeHash': digest,
            'byteLength': str(len(raw)), 'expectedRuntimeHash': expected, 'matchesExpected': matched})
        require(not mandatory or matched, 'script required runtime differs')
        return matched

    def _pin(self, address):
        require(address in self.pins, 'script required external runtime pin missing')
        self._runtime(address, self.pins[address], mandatory=True)

    def _state(self):
        a = self.a
        require(quantity(self.reader.request('eth_chainId', [])) == uint(a['chainId']), 'script chain differs')
        h = self.reader.request('eth_getBlockByHash', [a['blockHash'], False])
        n = self.reader.request('eth_getBlockByNumber', [hex(uint(a['blockNumber'])), False])
        require(dumps(h) == dumps(n) and type(h) is dict and h.get('hash') == a['blockHash'] and
            h.get('stateRoot') == a['stateRoot'] and quantity(h.get('number')) == uint(a['blockNumber'])
            and quantity(h.get('timestamp')) == uint(a['timestamp']), 'script block anchor differs')
        self._pin(a['core'])
        require(self._read(a['core'], 'collectionExists(uint256)', 'bool', ('uint256',),
            (uint(a['collectionId']),)), 'script collection does not exist')

    def _graph(self):
        a = self.a; pointers = {}; graph = {'core': {'address': a['core'], 'runtimeHash': a['coreRuntimeHash']}}
        for role, kind in (('metadata', 'COLLECTION_METADATA'), ('router', 'METADATA_ROUTER')):
            p = self._read(a['core'], 'getSatellitePointer(bytes32)', POINTER, ('bytes32',), (schema_id(kind),))
            require(p[0] != ZERO_ADDRESS and p[1] != ZERO and p[3] == schema_id(kind) and
                p[4] != '0x00000000' and p[5] != ZERO_ADDRESS and p[6] == 1 and p[7] != ZERO and
                p[8] != ZERO and p[9] > 0, 'script stored Core pointer admission differs')
            self._pin(p[0]); require(self.pins[p[0]] == p[1], 'script pointer runtime differs')
            require(self._read(p[0], 'core()', 'address') == a['core'], 'script reciprocal Core differs')
            pointers[role] = json_values(p); graph[role] = {'address': p[0], 'runtimeHash': p[1]}
        host = graph['metadata']['address']
        require(self._read(host, 'coreCodeHash()', 'bytes32') == a['coreRuntimeHash'], 'script Metadata Core pin differs')
        store = self._read(host, 'chunkStore()', 'address')
        store_hash = self._read(host, 'chunkStoreCodeHash()', 'bytes32')
        self._pin(store); require(self.pins[store] == store_hash, 'script Store binding differs')
        graph['store'] = {'address': store, 'runtimeHash': store_hash}
        return graph, pointers

    def _bundle(self, host, identifier, library=False):
        prefix = ('library:' if library else 'script:') + identifier
        facts = self._optional(prefix + ':facts', host, 'scriptBundle(bytes32)', FACTS,
            ('bytes32',), (identifier,), 'facts')
        registry = self._optional(prefix + ':registry', host, 'scriptBundleRegistry(bytes32)', REGISTRY,
            ('bytes32',), (identifier,), 'registry')
        if facts['status'] != 'available' or registry['status'] != 'available':
            return None
        f, r = facts['value'], registry['value']
        count = uint(f['chunkCount'])
        require(1 <= count <= wire.MAX_CHUNKS and f['finalized'] and f['libraryOnly'] == library and
            0 < uint(f['totalBytes']) <= wire.MAX_PAYLOAD, 'script saved bundle facts bound/kind')
        chunks = [{'index': str(i), 'outcome': self._optional(prefix + ':chunk:' + str(i), host,
            'dependencyChunk(bytes32,uint256)' if library else 'scriptBundleChunk(bytes32,uint256)',
            'bytes', ('bytes32', 'uint256'), (identifier, i))} for i in range(count)]
        result = {'bundleId': identifier, 'facts': f, 'registrySource': r, 'chunks': chunks,
            'registryObservations': None}
        if r['registry'] != ZERO_ADDRESS:
            matched = self._runtime(r['registry'], r['codeHash'])
            require(matched or all(row['outcome']['status'] == 'unavailable' for row in chunks),
                'script Registry runtime mismatch contradicts available host chunks')
            skip = {'status': 'unavailable', 'kind': 'not_read_runtime_mismatch', 'code': None}
            def get(label, sig, output, index=None):
                if not matched: return dict(skip)
                inputs = ('bytes32', 'uint256') + (() if index is None else ('uint256',))
                args = (r['dependencyId'], uint(r['version'])) + (() if index is None else (index,))
                return self._optional(prefix + ':version:' + label, r['registry'], sig, output, inputs, args)
            result['registryObservations'] = {
                'count': get('count', 'getDependencyScriptCountAtVersion(bytes32,uint256)', 'uint256'),
                'contentHash': get('content', 'getDependencyScriptContentHashAtVersion(bytes32,uint256)', 'bytes32'),
                'chunkTypedHashes': [{'index': str(i), 'outcome': get('hash:' + str(i),
                    'getDependencyScriptChunkHashAtVersion(bytes32,uint256,uint256)', 'bytes32', i)} for i in range(count)],
                # ABI string/bytes have identical layout. Preserve split UTF-8 codepoints as bytes.
                'chunks': [{'index': str(i), 'outcome': get('bytes:' + str(i),
                    'getDependencyScriptAtVersion(bytes32,uint256,uint256)', 'bytes', i)} for i in range(count)]}
        if library:
            m = self._optional(prefix + ':manifest', host, 'dependencyManifest(bytes32)', DEPENDENCY,
                ('bytes32',), (identifier,), 'dependency')
            if m['status'] != 'available': return None
            result['dependencyManifest'] = m['value']
        return result

    def _interpret(self, basis, selection, serving, bundle_id=None):
        host, digest = selection['host'], selection['manifestHash']
        admitted = self._runtime(host, selection['codeHash'])
        require(admitted, 'script successful selection contradicts original host runtime')
        if host not in self.pins:
            return None, 'original_host_runtime_not_admitted'
        require(self.pins[host] == selection['codeHash'], 'script original host external pin differs')
        require(self._read(host, 'core()', 'address') == self.a['core'] and
            self._read(host, 'coreCodeHash()', 'bytes32') == self.a['coreRuntimeHash'],
            'script original host Core binding differs')
        m = self._optional(basis + ':manifest', host, 'recordedScriptManifest(bytes32)', MANIFEST,
            ('bytes32',), (digest,), 'manifest')
        b = self._optional(basis + ':bundle', host, 'recordedScriptBundle(bytes32)', 'bytes32',
            ('bytes32',), (digest,))
        if m['status'] != 'available': return None, 'manifest_unavailable'
        manifest = m['value']
        c = {key: self.a[key] for key in ('chainId', 'core', 'collectionId')}
        c.update(metadata=host, metadataRuntimeHash=selection['codeHash'],
            router=self.graph['router']['address'], routerRuntimeHash=self.graph['router']['runtimeHash'])
        value = {'selection': selection, 'manifest': manifest, 'stable': None, 'script': None, 'library': None}
        if manifest['rendererCompatibility'] == wire.STABLE_PROFILE:
            require(bundle_id is None and (b['status'] != 'available' or b['value'] == ZERO),
                'script stable manifest has saved bundle')
            if serving['status'] != 'available': return None, 'serving_source_unavailable'
            payload = serving['value']['script'].encode('utf-8')
            value['stable'] = {'servingScriptBytes': '0x' + payload.hex(), 'chunkOutcome': self._optional(
                basis + ':stable_chunk', host, 'scriptChunk(uint256,uint256)', 'bytes',
                ('uint256', 'uint256'), (uint(self.a['collectionId']), 0))}
        else:
            if b['status'] != 'available': return None, 'bundle_identifier_unavailable'
            require(b['value'] != ZERO and (bundle_id is None or b['value'] == bundle_id),
                'script saved bundle identifier differs')
            value['script'] = self._bundle(host, b['value'])
            if value['script'] is None: return None, 'bundle_facts_unavailable'
            library = value['script']['facts']['libraryBundle']
            if library != ZERO:
                value['library'] = self._bundle(host, library, True)
                if value['library'] is None: return None, 'library_facts_unavailable'
        report = wire.validate(value, c)
        return {'basis': basis, 'host': host, 'manifestHash': digest, 'context': c,
            'value': value, 'report': report}, 'interpreted'

    def _capture(self):
        self._state(); self.graph, pointers = self._graph()
        router = self.graph['router']['address']; cid = uint(self.a['collectionId'])
        selection = self._optional('current_selection', router, 'selectedCollectionManifest(uint256,uint8)',
            SELECTION, ('uint256', 'uint8'), (cid, 2), 'selection')
        raw = self._optional('raw_saved_bundle', router, 'collectionScriptBundle(uint256)',
            BUNDLE_SELECTION, ('uint256',), (cid,), 'rawBundle')
        serving = self._optional('serving_source', router, 'collectionServingSource(uint256)',
            SERVING_SOURCE, ('uint256',), (cid,), 'servingSource')
        facts = self._optional('serving_facts', router, 'collectionServingFacts(uint256)',
            SERVING_FACTS, ('uint256',), (cid,), 'servingFacts')
        for outcome, tail in ((selection, None), (raw, 'bundleId')):
            if outcome['status'] != 'available': continue
            s = outcome['value']
            if s['manifestHash'] == ZERO:
                require(s['host'] == ZERO_ADDRESS and s['codeHash'] == ZERO and
                    (tail is None or s[tail] == ZERO), 'script malformed zero selection')
            else:
                require(s['host'] != ZERO_ADDRESS and s['codeHash'] != ZERO and
                    (tail is None or s[tail] != ZERO), 'script malformed nonzero selection')
        if selection['status'] == 'available' and selection['value']['manifestHash'] != ZERO:
            require(selection['value']['host'] == self.graph['metadata']['address'] and
                selection['value']['codeHash'] == self.graph['metadata']['runtimeHash'],
                'script current selection differs from current Metadata')
        if selection['status'] == raw['status'] == 'available' and raw['value']['bundleId'] != ZERO:
            require(all(selection['value'][key] == raw['value'][key] for key in NAMES['selection']),
                'script current and saved selection differ')
        if serving['status'] == 'available':
            require(all(len(serving['value'][key].encode('utf-8')) <= bound for key, bound in
                zip(NAMES['servingSource'], (256, 2048, 2048, 2048, 8192))), 'script serving byte bound')
        if raw['status'] == serving['status'] == 'available' and raw['value']['bundleId'] != ZERO:
            require(serving['value']['script'] == '', 'script inactive animationScript exposed as current')
        serving_class = 'unavailable' if facts['status'] != 'available' else 'unsupported_profile'
        if facts['status'] == 'available':
            f = facts['value']
            self._runtime(f['renderer'], f['rendererCodeHash'])
            require(self.runtime_pins[f['renderer']] == f['rendererCodeHash'],
                'script serving renderer runtime differs')
            if f['presentationProfile'] == wire.CHUNKED_PROFILE:
                require(f['mode'] == schema_id('ONCHAIN') and f['dependenciesLocked'] == f['scriptLocked'],
                    'script chunked serving mode/locks differ')
                serving_class = 'chunked_bundle'
            elif f['presentationProfile'] == wire.STABLE_PROFILE:
                require(f['dependenciesLocked'], 'script stable dependency lock differs')
                serving_class = 'stable_source_unavailable'
            if raw['status'] == 'available':
                require(f['presentationProfile'] == (wire.STABLE_PROFILE if raw['value']['bundleId'] == ZERO
                    else wire.CHUNKED_PROFILE), 'script saved route serving profile differs')
        if facts['status'] == serving['status'] == 'available':
            f, s = facts['value'], serving['value']
            require(f['imageURIHash'] == keccak256(s['imageURI'].encode()) and
                f['animationBaseURIHash'] == keccak256(s['animationBaseURI'].encode()),
                'script serving URI facts differ')
            if f['presentationProfile'] == wire.STABLE_PROFILE:
                require(f['scriptHash'] == keccak256(s['script'].encode()) and
                    uint(f['scriptBytes']) == len(s['script'].encode()) and
                    f['mode'] == schema_id('ONCHAIN' if s['script'] else 'OFFCHAIN'),
                    'script stable serving facts differ')
                serving_class = 'stable_inline' if s['script'] else 'stable_empty_source'
            elif f['presentationProfile'] == wire.CHUNKED_PROFILE:
                require(s['script'] == '', 'script chunked serving source is not empty')
        interpretations, availability = [], {}
        for basis, outcome in (('current_manifest', selection), ('raw_saved_bundle', raw)):
            if outcome['status'] != 'available': availability[basis] = 'call_unavailable'; continue
            if outcome['value']['manifestHash'] == ZERO:
                availability[basis] = 'zero_selection'; continue
            selected = {key: outcome['value'][key] for key in NAMES['selection']}
            result, status = self._interpret(basis, selected, serving,
                outcome['value']['bundleId'] if basis == 'raw_saved_bundle' else None)
            availability[basis] = status
            if result is not None: interpretations.append(result)
        availability['servingSource'] = serving['status']; availability['servingFacts'] = facts['status']
        availability['servingClassification'] = serving_class
        availability['unmanifestedInlineScript'] = (bool(selection['value']['manifestHash'] == ZERO and
            serving['value']['script']) if selection['status'] == serving['status'] == 'available' else None)
        # Current facts cannot label an original bundle as absent or substitute its bytes.
        for row in interpretations:
            if row['basis'] == 'current_manifest' and row['report']['mode'] == 'immutable_bundle' and raw['status'] == 'available':
                require(raw['value']['bundleId'] == row['value']['script']['bundleId'],
                    'script zero/different raw route contradicts current bundle')
            if row['report']['mode'] == 'immutable_bundle' and facts['status'] == 'available':
                f = facts['value']; sf = row['value']['script']['facts']
                require(f['presentationProfile'] == wire.CHUNKED_PROFILE and
                    f['scriptHash'] == sf['payloadHash'] and f['scriptBytes'] == sf['totalBytes'],
                    'script current bundle serving facts differ')
        return {'profile': PROFILE, 'profileHash': PROFILE_HASH, 'version': '1',
            'sourceReviewCommit': SOURCE_REVISION, 'anchorHash': keccak256(self.anchor_bytes),
            'transcriptHash': keccak256(self.transcript()), 'provenance': self.provenance,
            'sourceState': {key: self.a[key] for key in COMMON}, 'graph': self.graph,
            'pointerAdmissions': pointers, 'observations': self.observations,
            'runtimeObservations': self.runtime_observations, 'interpretations': interpretations,
            'availability': availability, 'claims': CLAIMS, 'qualification': QUALIFICATION}

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, 'script source cannot resume failed capture')
        self._started = True
        try:
            value = self._capture(); raw = dumps(value)
            require(len(raw) <= MAX_SNAPSHOT, 'script snapshot byte bound')
            if type(self.reader.transport) is rpc.ReplayTransport: self.reader.transport.finish()
            self._snapshot = raw
            return raw
        except MuseumError: raise
        except (ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
            raise MuseumError('malformed collection script source evidence') from exc

    def transcript(self):
        return self.reader.transcript()
