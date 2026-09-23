"""Concrete synthetic source map; no network, native execution or validator mocks."""
from copy import deepcopy
import unittest

from . import collection_script_source_v1 as source
from . import collection_script_wire_v1 as wire
from . import script_dependency_rpc_v1 as rpc
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads as canonical_loads, schema_id
from .chain_abi import calldata, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .test_collection_script_wire_v1 import stable_fixture, chunked_fixture, zero_registry


def H(value): return keccak256(str(value).encode())
def A(number): return '0x' + number.to_bytes(20, 'big').hex()
def loads(raw): return canonical_loads(raw, maximum=rpc.MAX_TRANSCRIPT)


def native(kind, value):
    if isinstance(kind, tuple): return tuple(native(t, v) for t, v in zip(kind, value))
    if kind.startswith('uint'): return int(value)
    if kind == 'bytes': return hex_bytes(value)
    return value


class CollectionScriptFixture:
    """Generic pinned Registry getter fixture, not that Registry's publication path."""
    def __init__(self, mode='stable', *, registry=False, unavailable=False,
                 registry_mismatch=False, replaced=False,
                 context_overrides=None, source_state=None, runtime_overrides=None):
        require_mode = mode in ('stable', 'chunked', 'inline', 'empty')
        if not require_mode: raise ValueError('unknown script fixture mode')
        self.mode, self.responses, self.calls = mode, {}, []
        self.value, self.context = chunked_fixture(registry=registry) if mode == 'chunked' else stable_fixture()
        if context_overrides: self.context.update(context_overrides)
        self.core, self.metadata, self.router = (self.context[k] for k in ('core', 'metadata', 'router'))
        self.store, self.module_registry = (self.context.get('store', A(5)),
            self.context.get('moduleRegistry', A(6)))
        self.codes = {host: b'synthetic script ' + role.encode() for host, role in (
            (self.core, 'core'), (self.metadata, 'metadata'), (self.router, 'router'),
            (self.store, 'store'), (A(8), 'renderer'))}
        if registry: self.codes[self.value['library']['registrySource']['registry']] = b'generic pinned Registry'
        if runtime_overrides: self.codes.update(runtime_overrides)
        self.pins = {host: keccak256(raw) for host, raw in self.codes.items()}
        self.context.update(metadataRuntimeHash=self.pins[self.metadata], routerRuntimeHash=self.pins[self.router])
        self.value['selection']['host'] = self.metadata
        if mode == 'chunked':
            library, script = self.value['library'], self.value['script']
            if registry: library['registrySource']['codeHash'] = self.pins[library['registrySource']['registry']]
            raws = [hex_bytes(row['outcome']['value']) for row in library['chunks']]
            library['bundleId'] = wire.bundle_id(self.context, library['facts'], library['registrySource'], raws)
            library['dependencyManifest'].update(dependencyId=library['bundleId'], sourcePointer=library['bundleId'])
            script['facts']['libraryBundle'] = library['bundleId']
            raws = [hex_bytes(row['outcome']['value']) for row in script['chunks']]
            script['bundleId'] = wire.bundle_id(self.context, script['facts'], script['registrySource'], raws)
            self.value['manifest']['sourcePointer'] = script['bundleId']
            digest = wire._chunked_hash(self.context, self.value['manifest'], script['bundleId'], script['facts'])
        else:
            digest = wire._stable_hash(self.context, self.value['manifest'], self.value['manifest']['scriptHash'])
        self.value['selection'].update(codeHash=self.pins[self.metadata], manifestHash=digest)
        self.current_metadata = self.metadata
        if replaced:
            if mode != 'chunked': raise ValueError('replacement fixture needs chunked mode')
            self.current_metadata = A(9); self.codes[self.current_metadata] = b'synthetic replacement Metadata'
            self.pins[self.current_metadata] = keccak256(self.codes[self.current_metadata])
        source_state = source_state or {}
        self.block = {'hash': source_state.get('blockHash', H('script block')),
            'number': hex(int(source_state.get('blockNumber', '42'))),
            'timestamp': hex(int(source_state.get('timestamp', '100'))),
            'stateRoot': source_state.get('stateRoot', H('state')),
            'parentHash': H('parent'), 'transactions': []}
        self.block_ref = {'blockHash': self.block['hash'], 'requireCanonical': True}
        self.runtime_bridge_raw = dumps({'kind': 'synthetic_fixture', 'note': 'admitted opaque runtime bridge'})
        self.anchor = {'profile': source.PROFILE, 'chainId': self.context['chainId'], 'core': self.core,
            'collectionId': self.context['collectionId'], 'blockHash': self.block['hash'],
            'blockNumber': str(int(self.block['number'], 16)),
            'timestamp': str(int(self.block['timestamp'], 16)), 'stateRoot': self.block['stateRoot'],
            'environment': source_state.get('environment', 'local_evm_fixture'),
            'deploymentEvidenceHash': source_state.get('deploymentEvidenceHash', H('deployment')),
            'coreRuntimeHash': self.pins[self.core],
            'codePins': [{'address': host, 'runtimeHash': pin} for host, pin in self.pins.items()],
            'runtimeAdmission': {'sourceCommit': source.SOURCE_REVISION, 'kind': 'synthetic_fixture',
                'artifactHash': keccak256(self.runtime_bridge_raw)}}
        self.anchor_raw = dumps(self.anchor)
        self.put('eth_chainId', [], hex(int(self.context['chainId'])))
        self.put('eth_getBlockByHash', [self.block['hash'], False], self.block)
        self.put('eth_getBlockByNumber', [self.block['number'], False], self.block)
        for host, code in self.codes.items(): self.put('eth_getCode', [host, self.block_ref], '0x' + code.hex())
        cid = int(self.context['collectionId'])
        self.add(self.core, 'collectionExists(uint256)', 'bool', True, ('uint256',), (cid,))
        for host in set((self.current_metadata, self.metadata, self.router)):
            self.add(host, 'core()', 'address', self.core)
        for host in set((self.metadata, self.current_metadata)):
            self.add(host, 'coreCodeHash()', 'bytes32', self.pins[self.core])
            self.add(host, 'chunkStore()', 'address', self.store)
            self.add(host, 'chunkStoreCodeHash()', 'bytes32', self.pins[self.store])
        for role, host, label in (('metadata', self.current_metadata, 'COLLECTION_METADATA'),
                                 ('router', self.router, 'METADATA_ROUTER')):
            row = (host, self.pins[host], False, schema_id(label), '0x12345678', self.module_registry,
                1, H(role + ' manifest'), H(role + ' deployment'), 1)
            self.add(self.core, 'getSatellitePointer(bytes32)', source.POINTER, row, ('bytes32',), (schema_id(label),))
        selected = tuple(self.value['selection'][k] for k in source.NAMES['selection'])
        if mode in ('inline', 'empty'): selected = (ZERO_ADDRESS, ZERO, ZERO)
        self.add(self.router, 'selectedCollectionManifest(uint256,uint8)', source.SELECTION, selected,
            ('uint256', 'uint8'), (cid, 2))
        raw = (self.metadata, self.pins[self.metadata], self.value['script']['bundleId'], digest) if mode == 'chunked' else (
            ZERO_ADDRESS, ZERO, ZERO, ZERO)
        self.add(self.router, 'collectionScriptBundle(uint256)', source.BUNDLE_SELECTION, raw, ('uint256',), (cid,))
        payload = '' if mode in ('chunked', 'empty') else hex_bytes(self.value['stable']['servingScriptBytes']).decode()
        serving = ('Synthetic collection', '', 'ipfs://image', '', payload)
        self.add(self.router, 'collectionServingSource(uint256)', source.SERVING_SOURCE, serving, ('uint256',), (cid,))
        f = self.value['script']['facts'] if mode == 'chunked' else None
        sf = (wire.CHUNKED_PROFILE if f else wire.STABLE_PROFILE, True, H('ONCHAIN' if f or payload else 'OFFCHAIN'),
            A(8), self.pins[A(8)], f['payloadHash'] if f else keccak256(payload.encode()),
            int(f['totalBytes']) if f else len(payload.encode()), keccak256(serving[2].encode()),
            keccak256(b''), False, False, False, not bool(f), False, False, False)
        self.add(self.router, 'collectionServingFacts(uint256)', source.SERVING_FACTS, sf, ('uint256',), (cid,))
        self.add(self.metadata, 'recordedScriptManifest(bytes32)', source.MANIFEST,
            tuple(self.value['manifest'][k] for k in source.NAMES['manifest']), ('bytes32',), (digest,))
        self.add(self.metadata, 'recordedScriptBundle(bytes32)', 'bytes32', raw[2], ('bytes32',), (digest,))
        if mode == 'chunked':
            for name in ('script', 'library'): self.install_bundle(self.value[name], name == 'library')
        else:
            self.add(self.metadata, 'scriptChunk(uint256,uint256)', 'bytes',
                self.value['stable']['servingScriptBytes'], ('uint256', 'uint256'), (cid, 0))
        if replaced:
            self.fail(self.router, 'selectedCollectionManifest(uint256,uint8)', ('uint256', 'uint8'), (cid, 2))
        if unavailable:
            if mode != 'chunked': raise ValueError('unavailable fixture needs chunked mode')
            if unavailable == 'registry':
                r = self.value['library']['registrySource']
                self.fail(r['registry'], 'getDependencyScriptContentHashAtVersion(bytes32,uint256)',
                    ('bytes32', 'uint256'), (r['dependencyId'], int(r['version'])))
            elif unavailable != 'host':
                self.fail(self.metadata, 'scriptBundleChunk(bytes32,uint256)', ('bytes32', 'uint256'),
                    (self.value['script']['bundleId'], 0))
            if unavailable != 'registry':
                self.fail(self.metadata, 'dependencyChunk(bytes32,uint256)', ('bytes32', 'uint256'),
                    (self.value['library']['bundleId'], 0))
                if registry and unavailable != 'host':
                    r = self.value['library']['registrySource']
                    self.fail(r['registry'], 'getDependencyScriptAtVersion(bytes32,uint256,uint256)',
                        ('bytes32', 'uint256', 'uint256'), (r['dependencyId'], int(r['version']), 0))
        if registry_mismatch:
            r = self.value['library']['registrySource']
            self.put('eth_getCode', [r['registry'], self.block_ref], '0x60006000')
            for i in range(int(self.value['library']['facts']['chunkCount'])):
                self.fail(self.metadata, 'dependencyChunk(bytes32,uint256)', ('bytes32', 'uint256'),
                    (self.value['library']['bundleId'], i))

    def put(self, method, params, value): self.responses[dumps([method, params])] = value

    def add(self, host, signature, output, value, inputs=(), args=()):
        self.put('eth_call', [{'to': host, 'data': calldata(signature, inputs, args), 'gas': '0x1312d00'},
            self.block_ref], '0x' + encode((output,), (native(output, value),)).hex())

    def fail(self, host, signature, inputs=(), args=()):
        self.put('eth_call', [{'to': host, 'data': calldata(signature, inputs, args), 'gas': '0x1312d00'},
            self.block_ref], rpc.CallUnavailable('provider_error', -32000))

    def install_bundle(self, value, library):
        bid = value['bundleId']
        self.add(self.metadata, 'scriptBundle(bytes32)', source.FACTS,
            tuple(value['facts'][k] for k in source.NAMES['facts']), ('bytes32',), (bid,))
        self.add(self.metadata, 'scriptBundleRegistry(bytes32)', source.REGISTRY,
            tuple(value['registrySource'][k] for k in source.NAMES['registry']), ('bytes32',), (bid,))
        for row in value['chunks']:
            self.add(self.metadata, 'dependencyChunk(bytes32,uint256)' if library else 'scriptBundleChunk(bytes32,uint256)',
                'bytes', row['outcome']['value'], ('bytes32', 'uint256'), (bid, int(row['index'])))
        if library:
            self.add(self.metadata, 'dependencyManifest(bytes32)', source.DEPENDENCY,
                tuple(value['dependencyManifest'][k] for k in source.NAMES['dependency']), ('bytes32',), (bid,))
        obs, r = value['registryObservations'], value['registrySource']
        if obs is not None:
            args = (r['dependencyId'], int(r['version'])); inputs = ('bytes32', 'uint256')
            self.add(r['registry'], 'getDependencyScriptCountAtVersion(bytes32,uint256)', 'uint256',
                obs['count']['value'], inputs, args)
            self.add(r['registry'], 'getDependencyScriptContentHashAtVersion(bytes32,uint256)', 'bytes32',
                obs['contentHash']['value'], inputs, args)
            for key, sig, out in (('chunkTypedHashes', 'getDependencyScriptChunkHashAtVersion(bytes32,uint256,uint256)', 'bytes32'),
                                 ('chunks', 'getDependencyScriptAtVersion(bytes32,uint256,uint256)', 'bytes')):
                for row in obs[key]: self.add(r['registry'], sig, out, row['outcome']['value'],
                    inputs + ('uint256',), args + (int(row['index']),))

    def request(self, method, params):
        self.calls.append((method, deepcopy(params)))
        key = dumps([method, params])
        if key not in self.responses: raise MuseumError('unprepared script fixture request: ' + method + ' ' + str(params))
        value = self.responses[key]
        if isinstance(value, rpc.CallUnavailable): raise rpc.CallUnavailable(value.kind, value.code)
        return deepcopy(value)

    def source(self): return source.CollectionScriptSource(self.anchor_raw, self)
    def capture(self):
        reader = self.source(); return reader.snapshot(), reader.transcript()


class CollectionScriptSourceV1Tests(unittest.TestCase):
    def test_modes_and_full_ordered_replay(self):
        for mode in ('stable', 'chunked', 'inline', 'empty'):
            with self.subTest(mode=mode):
                f = CollectionScriptFixture(mode); snap, transcript = f.capture()
                replay = rpc.ReplayTransport(transcript, keccak256(transcript))
                reader = source.CollectionScriptSource(f.anchor_raw, replay)
                self.assertEqual(reader.snapshot(), snap); self.assertEqual(reader.transcript(), transcript)
                value = loads(snap)
                self.assertEqual(len(value['interpretations']), 2 if mode == 'chunked' else 1 if mode == 'stable' else 0)
                self.assertEqual(value['availability']['unmanifestedInlineScript'], mode == 'inline')

    def test_registry_split_utf8_and_unavailable_independent_getter(self):
        f = CollectionScriptFixture('chunked', registry=True)
        value = loads(f.capture()[0]); self.assertTrue(value['interpretations'][0]['report']['completeDependencyBytes'])
        f = CollectionScriptFixture('chunked', registry=True, unavailable='registry')
        row = loads(f.capture()[0])['interpretations'][0]['report']
        self.assertFalse(row['completeDependencyBytes']); self.assertIsNotNone(row['dependency']['payloadHex'])

    def test_unavailable_chunk_retains_original_commitments(self):
        f = CollectionScriptFixture('chunked', unavailable=True); raw, transcript = f.capture()
        value = loads(raw); self.assertFalse(value['interpretations'][0]['report']['completeScriptBytes'])
        self.assertEqual(value['interpretations'][0]['value']['script']['facts'], f.value['script']['facts'])
        self.assertTrue(any('unavailable' in row for row in loads(transcript)['calls']))

    def test_changed_registry_runtime_retains_facts_without_direct_reads(self):
        f = CollectionScriptFixture('chunked', registry=True, registry_mismatch=True)
        value = loads(f.capture()[0]); row = value['interpretations'][0]
        self.assertEqual(row['value']['library']['registrySource'], f.value['library']['registrySource'])
        self.assertFalse(row['report']['completeDependencyBytes'])
        address = f.value['library']['registrySource']['registry']
        self.assertFalse(any(method == 'eth_call' and params[0]['to'] == address for method, params in f.calls))

    def test_replaced_metadata_keeps_original_saved_bundle(self):
        f = CollectionScriptFixture('chunked', replaced=True)
        value = loads(f.capture()[0]); self.assertEqual(value['availability']['current_manifest'], 'call_unavailable')
        self.assertEqual([r['basis'] for r in value['interpretations']], ['raw_saved_bundle'])
        self.assertEqual(value['interpretations'][0]['context']['metadata'], f.metadata)
        self.assertEqual(value['graph']['metadata']['address'], f.current_metadata)

    def test_stale_inline_is_not_chunked_fallback(self):
        f = CollectionScriptFixture('chunked', unavailable=True)
        f.add(f.router, 'collectionServingSource(uint256)', source.SERVING_SOURCE,
            ('Synthetic collection', '', 'ipfs://image', '', 'stale()'), ('uint256',), (7,))
        with self.assertRaisesRegex(MuseumError, 'inactive animationScript'): f.capture()

    def test_essential_failure_or_malformed_optional_success_rejects(self):
        f = CollectionScriptFixture(); f.fail(f.metadata, 'core()')
        with self.assertRaises(MuseumError): f.capture()
        f = CollectionScriptFixture()
        f.put('eth_call', [{'to': f.router, 'data': calldata('collectionScriptBundle(uint256)', ('uint256',), (7,)),
            'gas': '0x1312d00'}, f.block_ref], '0x')
        with self.assertRaises(MuseumError): f.capture()

    def test_missing_external_host_pin_and_source_pins(self):
        f = CollectionScriptFixture('chunked', replaced=True)
        f.anchor['codePins'] = [p for p in f.anchor['codePins'] if p['address'] != f.metadata]
        f.anchor_raw = dumps(f.anchor)
        value = loads(f.capture()[0]); self.assertEqual(value['interpretations'], [])
        self.assertEqual(value['availability']['raw_saved_bundle'], 'original_host_runtime_not_admitted')
        f = CollectionScriptFixture('chunked', replaced=True)
        next(p for p in f.anchor['codePins'] if p['address'] == f.metadata)['runtimeHash'] = H('wrong original host pin')
        f.anchor_raw = dumps(f.anchor)
        with self.assertRaisesRegex(MuseumError, 'original host external pin differs'): f.capture()
        f = CollectionScriptFixture(); f.put('eth_getCode', [f.router, f.block_ref], '0x00')
        with self.assertRaises(MuseumError): f.capture()

    def test_no_current_module_registry_or_latest_dependency_gate(self):
        f = CollectionScriptFixture('chunked', registry=True); f.capture()
        self.assertFalse(any(method == 'eth_call' and p[0]['to'] == f.module_registry for method, p in f.calls))
        data = {p[0]['data'][:10] for method, p in f.calls if method == 'eth_call'}
        self.assertNotIn(calldata('getDependencyScriptCount(bytes32)', ('bytes32',), (H('id'),))[:10], data)

    def test_full_consumption_provenance_and_empty_success(self):
        f = CollectionScriptFixture('empty'); snap, transcript = f.capture()
        self.assertEqual(loads(snap)['availability']['servingSource'], 'available')
        with self.assertRaises(MuseumError): source.CollectionScriptSource(f.anchor_raw, f, provenance='trusted_rpc')
        changed = loads(transcript); changed['calls'].append(deepcopy(changed['calls'][-1])); extra = dumps(changed)
        with self.assertRaises(MuseumError):
            source.CollectionScriptSource(f.anchor_raw, rpc.ReplayTransport(extra, keccak256(extra))).snapshot()

    def test_unavailable_observation_does_not_become_false_absence(self):
        f = CollectionScriptFixture('inline')
        f.fail(f.router, 'selectedCollectionManifest(uint256,uint8)', ('uint256', 'uint8'), (7, 2))
        f.fail(f.router, 'collectionServingFacts(uint256)', ('uint256',), (7,))
        value = loads(f.capture()[0])
        self.assertIsNone(value['availability']['unmanifestedInlineScript'])
        self.assertEqual(value['availability']['servingClassification'], 'unavailable')
        self.assertEqual(value['interpretations'], [])

    def test_serving_facts_and_renderer_contradictions_reject(self):
        for field, wrong in ((2, H('wrong mode')), (4, H('wrong renderer')), (5, H('wrong script')),
                             (6, 1), (12, False)):
            f = CollectionScriptFixture('stable')
            key = dumps(['eth_call', [{'to': f.router,
                'data': calldata('collectionServingFacts(uint256)', ('uint256',), (7,)),
                'gas': '0x1312d00'}, f.block_ref]])
            from .chain_abi import decode
            values = list(decode((source.SERVING_FACTS,), hex_bytes(f.responses[key]))[0]); values[field] = wrong
            f.add(f.router, 'collectionServingFacts(uint256)', source.SERVING_FACTS, values, ('uint256',), (7,))
            with self.subTest(field=field), self.assertRaises(MuseumError): f.capture()

    def test_raw_zero_contradicts_current_chunked_even_facts_unavailable(self):
        f = CollectionScriptFixture('chunked')
        f.add(f.router, 'collectionScriptBundle(uint256)', source.BUNDLE_SELECTION,
            (ZERO_ADDRESS, ZERO, ZERO, ZERO), ('uint256',), (7,))
        f.fail(f.router, 'collectionServingFacts(uint256)', ('uint256',), (7,))
        with self.assertRaisesRegex(MuseumError, 'zero/different raw route'): f.capture()

    def test_registry_runtime_mismatch_cannot_keep_successful_host_chunks(self):
        f = CollectionScriptFixture('chunked', registry=True)
        registry = f.value['library']['registrySource']['registry']
        f.put('eth_getCode', [registry, f.block_ref], '0x60006000')
        with self.assertRaisesRegex(MuseumError, 'contradicts available host chunks'): f.capture()

    def test_successful_saved_route_cannot_report_changed_original_host_runtime(self):
        for raw in ('0x', '0x60006000'):
            f = CollectionScriptFixture('chunked', replaced=True)
            f.put('eth_getCode', [f.metadata, f.block_ref], raw)
            with self.subTest(raw=raw), self.assertRaisesRegex(MuseumError, 'contradicts original host runtime'):
                f.capture()

    def test_registry_bytes_can_recover_host_readback_without_rewriting_outcome(self):
        f = CollectionScriptFixture('chunked', registry=True, unavailable='host')
        row = loads(f.capture()[0])['interpretations'][0]
        self.assertEqual(row['value']['library']['chunks'][0]['outcome']['status'], 'unavailable')
        self.assertTrue(row['report']['completeDependencyBytes'])
        self.assertFalse(row['report']['dependency']['hostChunkReadbackComplete'])


if __name__ == '__main__': unittest.main()
