"""Exact synthetic native observations; no deployment, EVM or archive signatures."""
from copy import deepcopy
from hashlib import sha256
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from . import preserved_tool_release_v1 as w
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import encode, calldata
from .independent_wire import ZERO, json_values
from .test_public_chain_history import PublicHistoryFixture
from .test_public_history_rpc import A, H


class PreservedToolReleaseFixture(PublicHistoryFixture):
    """Install before any captures; exact optional source state and shared base.

    .envelope() collects only actually requested observations. `archive_hash`
    is the real tool packager's ZIP Keccak for integration tests. An opaque
    prior native manifest is deliberately retained without invented catalogs.
    """
    def __init__(self, archive_hash=H(8900), *, source_state=None, base=None,
                 histories=2, payload_bytes=None):
        super().__init__(end=100)
        if source_state is None:
            source_state = {**self.anchor, 'chainId': '31337', 'core': A(2), 'collectionId': '1',
                'tokenId': '41', 'environment': 'local_evm_fixture', 'deploymentEvidenceHash': H(8901)}
        self.a = deepcopy(source_state); self.anchor = self.a
        self.base = base; self.host = A(8910); self.executor = A(8911); self.registry = A(8912)
        self.codes = {self.a['core']: base.codes[self.a['core']] if base else b'synthetic Core',
            self.host: b'synthetic StreamSystemManifest aa8ce49e', self.executor: b'synthetic Executor',
            self.registry: b'synthetic ModuleRegistry'}
        if base is not None:
            self.blocks = {row['hash']: deepcopy(row) for row in base.blocks.values()}
            self.receipts = deepcopy(base.receipts)
        else: self.blocks, self.receipts = {}, {}
        self.logs = []; self.getters = {}; self.rows = []; self.bodies = []
        self.header(int(self.a['blockNumber']))
        self.graph = {'systemManifest': self.host, 'executor': self.executor, 'codePins': {}}
        self.archives = {'graph': {}, 'toolArchive': None, 'deploymentManifest': None}
        self.pointer = (self.host, keccak256(self.codes[self.host]), True, w.MODULE_TYPE, w.INTERFACE,
            self.registry, 1, H(8913), H(8914), 1)
        self.put(self.a['core'], 'getSatellitePointer(bytes32)', (w.POINTER,), (self.pointer,),
            ('bytes32',), (schema_id('SYSTEM_MANIFEST'),))
        self.put(self.host, 'core()', ('address',), (self.a['core'],))
        self.put(self.host, 'governanceExecutor()', ('address',), (self.executor,))
        for interface, value in (('0x01ffc9a7', True), (w.INTERFACE, True), ('0xffffffff', False)):
            self.put(self.host, 'supportsInterface(bytes4)', ('bool',), (value,), ('bytes4',), (interface,))
        for i in range(histories):
            body = (payload_bytes if payload_bytes is not None else dumps({'synthetic': 'native payload',
                'revision': i+1, 'archiveHash': archive_hash})) if i+1 == histories else b'opaque original payload'
            self.append(body, i+1)
        latest = self.rows[-1]
        modules = [A(9000+i) for i in range(11)]; modules[7] = self.executor; modules[9] = self.registry
        self.aggregate = (latest[1], 'urn:synthetic:release', *modules,
            *(H(9100+i) for i in range(6)), archive_hash, histories)
        self.put(self.host, 'streamSystemManifest()', w.AGGREGATE, self.aggregate)
        self.put(self.host, 'streamSystemManifestPointerCount()', ('uint256',), (histories,))
        self.put(self.host, 'streamSystemManifestPointer()', ('address',), (latest[0],))
        self.repin()

    def header(self, number):
        if not hasattr(self, 'a'): return super().header(number)
        found = next((row for row in self.blocks.values() if int(row['number'], 16) == number), None)
        if found is not None: return found
        a = self.a; end = int(a['blockNumber'])
        digest = a['blockHash'] if number == end else H(100000000+number)
        row = {'hash': digest, 'number': hex(number), 'stateRoot': a['stateRoot'] if number == end else H(200000000+number),
            'timestamp': hex(int(a['timestamp']) - end + number),
            'parentHash': H(99999999+number) if number else ZERO, 'transactions': []}
        self.blocks[digest] = row; return row

    def put(self, host, signature, outputs, values, inputs=(), arguments=()):
        self.getters[(host, calldata(signature, inputs, arguments))] = '0x'+encode(outputs, values).hex()

    def repin(self): self.graph['codePins'] = {address: keccak256(raw) for address, raw in self.codes.items()}

    def append(self, payload, block):
        i = len(self.rows); parts = [payload[n:n+24575] for n in range(0, len(payload), 24575)]
        chunks = []
        for index, part in enumerate(parts):
            address = A(10000+i*40+index); self.codes[address] = b'\0'+part
            chunks.append((address, len(part), keccak256(part)))
        pointer = A(20000+i); digest = w.payload_hash(parts)
        self.codes[pointer] = b'\0'+encode(w.DESCRIPTOR, (w.MAGIC, 1, w.SCHEMA, w.JCS, len(payload), len(parts), tuple(chunks)))
        log = self.add(block, address=self.host, topics=[w.PUBLISHED, digest,
            '0x'+encode(('address',), (pointer,)).hex(), H(21000+i)])
        log['data'] = '0x'+encode(('uint16',), (1,)).hex()
        row = (pointer, digest, int(self.header(block)['timestamp'], 16))
        self.rows.append(row); self.bodies.append(payload)
        self.put(self.host, 'streamSystemManifestPointerAt(uint256)', ('address', 'bytes32', 'uint64'), row, ('uint256',), (i,))

    def request(self, method, params):
        if method == 'eth_call': return self.getters[(params[0]['to'], params[0]['data'])]
        if method == 'eth_getCode': return '0x'+self.codes[params[0]].hex()
        if method == 'eth_getLogs':
            f = params[0]
            return deepcopy([log for receipt in self.receipts.values() for log in receipt['logs']
                if int(f['fromBlock'], 16) <= int(log['blockNumber'], 16) <= int(f['toBlock'], 16)
                and w.history._matches(log, f)])
        return super().request(method, params)

    def envelope(self, *, materials=None):
        value = {'profile': w.PROFILE, 'anchor': self.a, 'graph': self.graph, 'provenance': 'synthetic_fixture',
            'calls': [], 'archives': self.archives}
        for _ in range(10000):
            try:
                o, _, _, _, files, _ = w._source(value)
                if materials is not None: w._archives(self.archives, o, materials)
                return dumps(value)
            except w.MissingObservation as e:
                value['calls'].append({'method': e.method, 'params': e.params, 'result': self.request(e.method, e.params)})
        raise AssertionError('source fixture did not converge')

    def source(self): return w._source(loads(self.envelope(), maximum=w.MAX_BYTES))

    def archive_materials(self, tool_raw, *, backend='external'):
        from .test_conservation_archive_v1 import _proof
        artist = schema_id('synthetic original archival Artist identity; not release authority')
        role = 'externalCoverage' if backend == 'external' else 'coverage'
        self.codes[A(9300)] = b'synthetic archival coverage host'
        self.codes[A(900)] = b'verifier runtime'
        graph = {role: {'address': A(9300), 'runtimeHash': keccak256(self.codes[A(9300)])}}
        self.archives['graph'] = graph
        materials = {'toolArchive': tool_raw, 'deploymentManifest': self.bodies[-1]}
        for name, body in materials.items():
            proof = _proof(body, w.archive.archive.RAW, artist, graph, backend=backend)
            self.archives[name] = {'artistId': artist, 'proof': proof}
            if backend == 'onchain':
                self.codes[A(62000)] = b'original archival runtime'
                for chunk in proof['sourceEvidence']['chunks']:
                    self.codes[chunk['pointer']] = hex_bytes(chunk['runtime'])
        self.repin()
        source = {**self.a, 'codePins': [{'address': a, 'runtimeHash': h} for a,h in self.graph['codePins'].items()]}
        originals = w.archive._Originals({'source': source}, {'calls': []}, graph)
        for name, body in materials.items():
            proof = self.archives[name]['proof']
            if backend == 'external':
                w.archive._external(proof, body, w.archive.archive.RAW, [artist], None, None, originals, graph)
            else:
                w.archive._onchain(proof, body, w.archive.archive.RAW, [artist], originals, graph)
        for address, digest in originals.pins.items():
            assert keccak256(self.codes[address]) == digest
        for row in originals.calls: self.getters[(row['target'],row['calldata'])] = row['result']
        return materials


class NativeToolReleaseTests(unittest.TestCase):
    def test_complete_native_pointer_history_retains_opaque_original(self):
        f = PreservedToolReleaseFixture(); _, aggregate, _, rows, files, coverage = f.source()
        self.assertEqual(aggregate[19], H(8900)); self.assertEqual(len(rows), 2)
        self.assertEqual(files[rows[0]['payload']['path']], b'opaque original payload')
        self.assertNotEqual(rows[0]['manifestHash'], rows[0]['payload']['keccak256'])
        self.assertEqual(coverage['startBlock'], '0')

    def test_native_chunk_root_known_independent_generator_vector(self):
        path = Path(__file__).parents[2] / 'release-artifacts/system-manifest-payload-vector.json'
        vector = loads(path.read_bytes(), maximum=8*1024*1024)
        # The committed generator carries an independently implemented recipe.
        chunks = [hex_bytes(row['segment_hex']) for row in vector['chunks']]
        self.assertEqual(w.payload_hash(chunks), vector['commitments']['manifest_hash'])

    def test_multichunk_native_payload_exact_original_bytes(self):
        f = PreservedToolReleaseFixture(payload_bytes=b'x'*50000); _, _, _, rows, files, _ = f.source()
        self.assertEqual(len(rows[-1]['carrier']['descriptor'][-1]), 3)
        self.assertEqual(files[rows[-1]['payload']['path']], b'x'*50000)

    def test_current_pointer_must_be_frozen_selected_core_host(self):
        for index, replacement in ((0, A(77)), (1, H(77)), (2, False), (6, 2), (9, 0)):
            f = PreservedToolReleaseFixture(); row = list(f.pointer); row[index] = replacement
            f.put(f.a['core'], 'getSatellitePointer(bytes32)', (w.POINTER,), (tuple(row),), ('bytes32',), (schema_id('SYSTEM_MANIFEST'),))
            with self.subTest(index=index), self.assertRaisesRegex(MuseumError, 'frozen active Core'): f.source()

    def test_history_omission_count_and_reordering_reject(self):
        f = PreservedToolReleaseFixture(); f.rows[0], f.rows[1] = f.rows[1], f.rows[0]
        for i, row in enumerate(f.rows):
            f.put(f.host, 'streamSystemManifestPointerAt(uint256)', ('address','bytes32','uint64'), row, ('uint256',), (i,))
        with self.assertRaisesRegex(MuseumError, 'pointer/publication'): f.source()
        f = PreservedToolReleaseFixture(); f.receipts.pop(f.logs[0]['transactionHash'])
        with self.assertRaisesRegex(MuseumError, 'event denominator'): f.source()

    def test_current_head_cannot_choose_older_original(self):
        f = PreservedToolReleaseFixture()
        f.put(f.host, 'streamSystemManifestPointer()', ('address',), (f.rows[0][0],))
        with self.assertRaisesRegex(MuseumError, 'current head'): f.source()

    def test_rehashed_chunk_runtime_still_must_match_descriptor(self):
        f = PreservedToolReleaseFixture(); address = A(10000)
        f.codes[address] = b'\0' + b'changed original bytes'; f.repin()
        with self.assertRaisesRegex(MuseumError, 'original chunk bytes'): f.source()

    def test_immutable_core_and_original_timestamp_must_agree(self):
        f = PreservedToolReleaseFixture(); f.put(f.host, 'core()', ('address',), (A(4),))
        with self.assertRaisesRegex(MuseumError, 'immutable bindings'): f.source()
        f = PreservedToolReleaseFixture(); p, h, time = f.rows[0]
        f.put(f.host, 'streamSystemManifestPointerAt(uint256)', ('address','bytes32','uint64'), (p,h,time+1), ('uint256',), (0,))
        with self.assertRaisesRegex(MuseumError, 'pointer/publication'): f.source()

    def test_repeated_source_observation_conflict_rejects(self):
        value = loads(PreservedToolReleaseFixture().envelope()); row = deepcopy(next(r for r in value['calls'] if r['method']=='eth_call'))
        row['result'] = '0x'; value['calls'].append(row)
        with self.assertRaisesRegex(MuseumError, 'conflicting repeated'): w._source(value)

    def test_public_disclosure_precedes_package_read(self):
        with patch.object(Path, 'read_bytes', side_effect=AssertionError('must not read')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                w.validate(b'', ZERO, package='missing', expected_parts_sha256='0'*64, disclosure='restricted')

    def test_actual_source_header_compatible_with_title_base(self):
        from .title_v5_fixture import TitleV5Fixture
        base = TitleV5Fixture(); state = {key: base.title_ownership_anchor[key] for key in w.STATE_KEYS}
        f = PreservedToolReleaseFixture(source_state=state, base=base)
        o, _, _, _, _, _ = f.source()
        self.assertEqual(o.a, state)
        self.assertEqual(f.codes[state['core']], base.codes[state['core']])

    def test_both_native_archive_backends_require_exact_original_getters(self):
        for backend in ('external', 'onchain'):
            f = PreservedToolReleaseFixture(); materials = f.archive_materials(b'original tool archive material', backend=backend)
            value = loads(f.envelope(materials=materials), maximum=w.MAX_BYTES)
            o, _, _, _, _, _ = w._source(value)
            report = w._archives(value['archives'], o, materials)
            self.assertEqual(set(o.answers), o.used)
            self.assertEqual(report['toolArchive']['status'], 'original_dual_family_correspondence_checked')
            self.assertFalse(report['toolArchive']['releaseAuthorityInferred'])
            self.assertEqual(len(report['toolArchive']['families']), 2)

    def test_archive_material_substitution_cannot_be_repinned_as_native(self):
        f = PreservedToolReleaseFixture(); materials = f.archive_materials(b'original tool material')
        value = loads(f.envelope(materials=materials), maximum=w.MAX_BYTES); o, *_ = w._source(value)
        with self.assertRaisesRegex(MuseumError, 'external material correspondence'):
            w._archives(value['archives'], o, {**materials, 'toolArchive': b'other tool material'})

    def test_archive_getter_conflict_and_absent_getter_are_not_trusted_reports(self):
        f = PreservedToolReleaseFixture(); materials = f.archive_materials(b'tool original')
        value = loads(f.envelope(materials=materials), maximum=w.MAX_BYTES)
        row = next(r for r in value['calls'] if r['method'] == 'eth_call' and r['params'][0]['to'] == A(9300))
        changed = deepcopy(value); changed['calls'][value['calls'].index(row)]['result'] = '0x'
        o, *_ = w._source(changed)
        with self.assertRaisesRegex(MuseumError, 'conflicting original getter|original getter differs'):
            w._archives(changed['archives'], o, materials)
        changed = deepcopy(value); changed['calls'].remove(row); o, *_ = w._source(changed)
        with self.assertRaises(w.MissingObservation): w._archives(changed['archives'], o, materials)

    def test_archive_receipt_cannot_change_artist_release_authority(self):
        f = PreservedToolReleaseFixture(); materials = f.archive_materials(b'tool original')
        value = loads(f.envelope(materials=materials), maximum=w.MAX_BYTES)
        value['archives']['toolArchive']['artistId'] = H(42); o, *_ = w._source(value)
        with self.assertRaisesRegex(MuseumError, 'material correspondence'): w._archives(value['archives'], o, materials)


class PackagedToolReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from . import preserved_tool_source_v1 as source
        from . import preserved_tool_replay_v1 as replay
        from .test_preserved_tool_source_v1 import declarations
        from .test_acquisition_canonical_v10 import composed_inputs, v
        prior, native, pin = composed_inputs()
        packet = v.compose(prior.files, prior.manifest_hash, native, pin, disclosure='public')
        vectors = replay.vector_inputs([{'id': 'actual-packet', 'kind': 'packet_v10',
            'files': dict(packet.files), 'manifestHash': packet.manifest_hash}])
        cls.temporary = tempfile.TemporaryDirectory(prefix='stream-native-tool-release-')
        cls.package = Path(cls.temporary.name) / 'package'
        pins, prerequisites = declarations()
        repository = Path(__file__).resolve().parents[2]
        revision = source._git(repository, 'rev-parse', 'HEAD').decode('ascii').strip()
        cls.tool = source.build(repository, cls.package, source_revision=revision,
            vectors=vectors, external_pins=pins, licenses=[], prerequisites=prerequisites)
        cls.parts_pin = sha256((cls.package/'parts.json').read_bytes()).hexdigest()
        cls.fixture = PreservedToolReleaseFixture(keccak256(cls.tool.archive_bytes))
        cls.materials = cls.fixture.archive_materials(cls.tool.archive_bytes)
        cls.raw = cls.fixture.envelope(materials=cls.materials)

    @classmethod
    def tearDownClass(cls): cls.temporary.cleanup()

    def verify(self, raw=None, pin=None, package=None):
        raw = self.raw if raw is None else raw
        return w.validate(raw, keccak256(raw), package=self.package if package is None else package,
            expected_parts_sha256=self.parts_pin if pin is None else pin)

    def test_real_preserved_tool_and_both_original_archive_objects_offline(self):
        with patch('socket.socket', side_effect=AssertionError('no network')):
            result = self.verify()
        self.assertEqual(result.report['reconstructionClientHash'], keccak256(self.tool.archive_bytes))
        self.assertEqual(result.report['toolPackage']['vectorCaseCount'], '1')
        self.assertTrue(result.report['toolPackage']['actualClosureVerified'])
        for name in ('toolArchive','deploymentManifest'):
            self.assertEqual(result.report['archive'][name]['status'], 'original_dual_family_correspondence_checked')
        self.assertFalse(result.report['claims']['toolExecutionPerformed'])
        self.assertFalse(result.report['claims']['sourceProvenanceAuthenticated'])
        self.assertEqual(result.files['source/evidence.json'], self.raw)
        self.assertEqual({p.removeprefix('tool-package/'): b for p,b in result.files.items()
            if p.startswith('tool-package/')}, dict(self.tool.files))

    def test_actual_package_transport_hash_does_not_substitute_native_zip_hash(self):
        value = loads(self.raw, maximum=w.MAX_BYTES)
        key = calldata('streamSystemManifest()', (), ())
        row = next(r for r in value['calls'] if r['method']=='eth_call' and r['params'][0]['data']==key)
        changed = list(self.fixture.aggregate); changed[19] = '0x' + self.parts_pin
        row['result'] = '0x' + encode(w.AGGREGATE, changed).hex()
        with self.assertRaisesRegex(MuseumError, 'reconstructionClientHash'): self.verify(dumps(value))

    def test_external_pins_and_changed_package_bytes_reject(self):
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            self.verify(pin='ff'*32)
        with self.assertRaisesRegex(MuseumError, 'external evidence hash'):
            w.validate(self.raw, ZERO, package=self.package, expected_parts_sha256=self.parts_pin)
        with tempfile.TemporaryDirectory(prefix='stream-native-tool-change-') as directory:
            target = Path(directory)
            for path, body in self.tool.files: (target/path).write_bytes(body)
            path = target/'part-000000.bin'; body = bytearray(path.read_bytes()); body[-1] ^= 1; path.write_bytes(body)
            with self.assertRaisesRegex(MuseumError, 'part bytes'): self.verify(package=target)

    def test_source_only_missing_archive_remains_explicit(self):
        f = PreservedToolReleaseFixture(keccak256(self.tool.archive_bytes))
        result = self.verify(f.envelope())
        self.assertEqual(result.report['archive']['toolArchive']['status'], 'original_dual_family_evidence_not_supplied')
        self.assertIn('toolArchive_dual_family_archive', result.report['remaining'])

    def test_rehashed_original_rpc_contradiction_is_fatal(self):
        value = loads(self.raw, maximum=w.MAX_BYTES)
        call = next(r for r in value['calls'] if r['method']=='eth_call' and r['params'][0]['to']==A(9300))
        call['result'] = '0x'
        with self.assertRaisesRegex(MuseumError, 'conflicting original getter|original getter differs'):
            self.verify(dumps(value))

    def test_unconsumed_observation_is_not_silently_retained(self):
        value = loads(self.raw, maximum=w.MAX_BYTES)
        value['calls'].append({'method':'eth_call', 'params':[{'to': self.fixture.host,
            'data': '0x12345678', 'gas':'0x1312d00'},
            {'blockHash':self.fixture.a['blockHash'],'requireCanonical':True}], 'result':'0x'})
        with self.assertRaisesRegex(MuseumError, 'unused original observations'): self.verify(dumps(value))


if __name__ == '__main__': unittest.main()
