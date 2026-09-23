"""Synthetic native token-resolution controls; no deployed-chain claim."""
from copy import deepcopy
import unittest

from . import policy_static_components_v2 as static
from . import script_dependency_rpc_v1 as rpc
from . import token_script_capture_v1 as capture
from . import token_script_interpretation_v1 as interpretation
from . import token_script_registry_source_v1 as registry_source
from . import token_script_registered_capture_v1 as registered_capture
from . import token_script_source_v1 as source
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import Array, calldata, encode
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, ZERO, ZERO_ADDRESS
from .publication import KINDS
from .test_collection_script_source_v1 import CollectionScriptFixture, A, H


class TokenScriptFixture(CollectionScriptFixture):
    def __init__(self, mode='stable', *, override=True, frozen=True,
            collection_override=False, foreign_override=False, offchain=False,
            global_mismatch=None, context_overrides=None, source_state=None,
            runtime_overrides=None, history_offset=0):
        super().__init__(mode, context_overrides=context_overrides,
            source_state=source_state, runtime_overrides=runtime_overrides)
        self.token = 41
        self.registry = A(10)
        self.codes[self.registry] = b'synthetic renderer registry'
        self.pins[self.registry] = keccak256(self.codes[self.registry])
        self.put('eth_getCode', [self.registry, self.block_ref],
            '0x' + self.codes[self.registry].hex())
        cid = int(self.context['collectionId'])
        self.add(self.core, 'tokenCollectionIdentity(uint256)', source.IDENTITY,
            (True, cid, 3, False), ('uint256',), (self.token,))
        selection = (self.registry, self.pins[self.registry], H('version'), A(8),
            self.pins[A(8)], H('renderer-id'), H('renderer-version'),
            H('context-version'), H('schema'), H('read-set'), H('registration'))
        base_config = (0 if offchain else 1, A(8), '', '', 0, False)
        config = (0 if offchain else 1, A(8), '', '', 0, frozen)
        manifest = tuple(self.value['selection'][key] for key in
            ('host', 'codeHash', 'manifestHash')) if mode not in ('inline', 'empty') else (
                ZERO_ADDRESS, ZERO, ZERO)
        raw = (31337, True, 'Synthetic collection', '', 'ipfs://image', '',
            '' if mode in ('chunked', 'empty') else
                bytes.fromhex(self.value['stable']['servingScriptBytes'][2:]).decode(),
            manifest, (ZERO_ADDRESS, ZERO, ZERO))
        global_record = [ZERO, ZERO, 0, 0, 1, 1, 0, ZERO,
            selection, base_config]
        if global_mismatch == 'selection':
            altered = list(selection); altered[2] = H('other-version')
            global_record[8] = tuple(altered)
        elif global_mismatch == 'config':
            global_record[9] = (2, A(8), '', '', 0, False)
        elif global_mismatch == 'revision':
            global_record[4] = global_record[5] = 2
        elif global_mismatch is not None:
            raise ValueError('unknown global default mismatch')
        global_record[0] = static._record_hash(self.core, self.router,
            tuple(global_record))
        self.global_record = tuple(global_record)
        previous = self.global_record[0]
        activation_record = [ZERO, previous, cid, 0, 1, 1, 3, ZERO,
            selection, base_config]
        activation_record[0] = static._record_hash(self.core, self.router,
            tuple(activation_record))
        base = list(activation_record)
        if collection_override:
            base = [ZERO, ZERO, cid, 0, 2, 1, 1, ZERO, selection, base_config]
            base[0] = static._record_hash(self.core, self.router, tuple(base))
        selected = [ZERO, ZERO, cid, self.token, 3 if collection_override else 2, 1, 2,
            static._source_snapshot_hash(raw) if frozen else ZERO, selection, config]
        selected[0] = static._record_hash(self.core, self.router, tuple(selected))
        self.activation_record = tuple(activation_record)
        self.base, self.selected, self.raw = tuple(base), tuple(selected), raw
        active = self.selected if override else self.base
        if not override:
            self.raw = raw
            config = base_config
        self.foreign = None
        if foreign_override:
            foreign = [ZERO, ZERO, cid, 99, (self.selected[4] if override
                else self.base[4]) + 1, 1, 2, ZERO, selection, base_config]
            foreign[0] = static._record_hash(self.core, self.router, tuple(foreign))
            self.foreign = tuple(foreign)
        for row in (self.global_record, self.activation_record, self.base, self.selected,
                *((self.foreign,) if self.foreign else ())):
            self.add(self.router, 'metadataConfigRecord(bytes32)', static.CONFIG_RECORD,
                row, ('bytes32',), (row[0],))
            self.add(self.router, 'metadataConfigAuthorization(bytes32)', source.AUTHORIZATION,
                (self.metadata, self.pins[self.metadata], A(9), 7, cid, 1),
                ('bytes32',), (row[0],))
        self.add(self.router, 'resolvedMetadataConfig(uint256)', static.CONFIG_RECORD,
            active, ('uint256',), (self.token,))
        self.add(self.router, 'collectionMetadataConfig(uint256)', static.CONFIG_RECORD,
            self.base, ('uint256',), (cid,))
        head = ZERO
        if collection_override:
            head = keccak256(encode(('bytes32', 'bytes32', 'uint256', 'uint256',
                'bytes32', 'uint64'), (source.OVERRIDES_DOMAIN, head, cid,
                0, self.base[0], self.base[4])))
        if override:
            head = keccak256(encode(('bytes32', 'bytes32', 'uint256', 'uint256',
                'bytes32', 'uint64'), (source.OVERRIDES_DOMAIN, head, cid,
                self.token, self.selected[0], self.selected[4])))
        if self.foreign:
            head = keccak256(encode(('bytes32', 'bytes32', 'uint256', 'uint256',
                'bytes32', 'uint64'), (source.OVERRIDES_DOMAIN, head, cid,
                99, self.foreign[0], self.foreign[4])))
        self.add(self.router, 'staticMetadataActivation(uint256)', source.ACTIVATION,
            (previous, 1, head), ('uint256',), (cid,))
        self.add(self.router, 'staticRenderSourceForConfig(uint256,bytes32)',
            (static.RAW_SOURCE, static.METADATA_CONFIG), (self.raw, config),
            ('uint256', 'bytes32'), (cid, active[0]))
        self.anchor.update(profile=source.PROFILE, tokenId=str(self.token),
            codePins=[{'address': host, 'runtimeHash': pin} for host, pin in self.pins.items()])
        self.anchor_raw = dumps(self.anchor)
        self.history_headers, self.history_receipts = {}, {}
        topic = lambda value: '0x' + f'{value:064x}'
        auth = (self.metadata, self.pins[self.metadata], A(9), 7, cid, 1)
        authorization = lambda row: (source.AUTHORIZATION_EVENT,
            [row[0], '0x' + '00' * 12 + A(9)[2:]],
            (source.AUTHORIZATION,), (auth,))
        self._history(10 + history_offset, [authorization(self.activation_record), (source.RECORDED_EVENT,
            [topic(cid), topic(0), self.activation_record[0]],
            ('uint16', static.CONFIG_RECORD), (1, self.activation_record)),
            (source.ACTIVATED_EVENT, [topic(cid), previous], ('uint16', 'bytes32'),
                (1, H('family-state')))])
        if collection_override:
            self._history(11 + history_offset, [authorization(self.base), (source.RECORDED_EVENT,
                [topic(cid), topic(0), self.base[0]],
                ('uint16', static.CONFIG_RECORD), (1, self.base))])
        if override:
            self._history((12 if collection_override else 11) + history_offset,
                [authorization(self.selected), (source.RECORDED_EVENT,
                [topic(cid), topic(self.token), self.selected[0]],
                ('uint16', static.CONFIG_RECORD), (1, self.selected))])
        if self.foreign:
            self._history((13 if collection_override else 12) + history_offset,
                [authorization(self.foreign), (source.RECORDED_EVENT,
                [topic(cid), topic(99), self.foreign[0]],
                ('uint16', static.CONFIG_RECORD), (1, self.foreign))])

    def _history(self, block, events):
        digest, tx = H('config-header-' + str(block)), H('config-tx-' + str(block))
        header = {'hash': digest, 'number': hex(block), 'timestamp': hex(60 + block),
            'stateRoot': H('config-state-' + str(block)),
            'parentHash': H('config-header-' + str(block - 1)), 'transactions': [tx]}
        receipt = {'transactionHash': tx, 'blockHash': digest, 'blockNumber': hex(block),
            'transactionIndex': '0x0', 'status': '0x1', 'logs': []}
        for index, (signature, topics, kinds, values) in enumerate(events):
            receipt['logs'].append({key: receipt[key] for key in
                ('transactionHash', 'blockHash', 'blockNumber', 'transactionIndex')} |
                {'address': self.router, 'topics': [signature, *topics],
                'data': '0x' + encode(kinds, values).hex(), 'logIndex': hex(index),
                'removed': False})
        self.history_headers[digest] = header
        self.history_receipts[tx] = receipt

    def request(self, method, params):
        if method == 'eth_getLogs':
            self.calls.append((method, deepcopy(params)))
            query = params[0]
            rows = [log for receipt in self.history_receipts.values()
                for log in receipt['logs'] if log['address'] == query['address'] and
                int(query['fromBlock'], 16) <= int(log['blockNumber'], 16) <=
                int(query['toBlock'], 16) and all(term is None or
                    log['topics'][index] in (term if type(term) is list else [term])
                    for index, term in enumerate(query['topics']))]
            return deepcopy(rows)
        if method == 'eth_getBlockByHash' and params[0] in self.history_headers:
            self.calls.append((method, deepcopy(params)))
            return deepcopy(self.history_headers[params[0]])
        if method == 'eth_getBlockByNumber':
            rows = [row for row in self.history_headers.values() if row['number'] == params[0]]
            if rows:
                self.calls.append((method, deepcopy(params)))
                return deepcopy(rows[0])
        if method == 'eth_getTransactionReceipt' and params[0] in self.history_receipts:
            self.calls.append((method, deepcopy(params)))
            return deepcopy(self.history_receipts[params[0]])
        return super().request(method, params)

    def source(self):
        return source.TokenScriptSource(self.anchor_raw, self)

    def install_registry(self, *, missing=False, mismatched=False,
            schemas_address=None, runtime_overrides=None):
        """Add real getter/Store responses for four exact documents to this RPC map."""
        from .genesis_registry_source_v1 import DOCUMENT_FACTS, MODULE_RECORD, SOURCE_REVISION
        self.schemas, self.governance = schemas_address or A(11), A(12)
        for address, raw in ((self.module_registry, b'synthetic module Registry'),
                (self.schemas, b'synthetic SchemaRegistry'),
                (self.governance, b'synthetic governance executor')):
            raw = (runtime_overrides or {}).get(address, raw)
            self.codes[address] = raw; self.pins[address] = keccak256(raw)
            self.put('eth_getCode', [address, self.block_ref], '0x' + raw.hex())
        cid = int(self.context['collectionId'])
        kind = source.schema_id('COLLECTION_METADATA')
        module = (1, kind, H('metadata version'), '0x12345678', 0,
            self.pins[self.metadata], H('metadata deployment'),
            H('metadata manifest'), '', 1, 1, 1)
        self.add(self.module_registry, 'moduleRecord(address)', MODULE_RECORD,
            module, ('address',), (self.metadata,))
        self.add(self.module_registry, 'isModuleEligible(address,bytes32,bytes4)',
            'bool', True, ('address', 'bytes32', 'bytes4'),
            (self.metadata, kind, '0x12345678'))
        for signature, output, value in (
                ('schemaRegistry()', 'address', self.schemas),
                ('schemaRegistryCodeHash()', 'bytes32', self.pins[self.schemas]),
                ('governanceAuthority()', 'address', self.governance),
                ('executorCodeHash()', 'bytes32', self.pins[self.governance])):
            self.add(self.metadata, signature, output, value)
        for signature, output, value in (
                ('chunkStore()', 'address', self.store),
                ('governanceAuthority()', 'address', self.governance),
                ('governanceAuthorityCodeHash()', 'bytes32', self.pins[self.governance]),
                ('MAX_DOCUMENT_CHUNKS()', 'uint256', 64),
                ('CHUNK_BYTES()', 'uint256', 8192),
                ('MAX_DOCUMENT_BYTES()', 'uint256', 524288),
                ('RAW_BYTES()', 'bytes32', RAW_BYTES)):
            self.add(self.schemas, signature, output, value)
        self.add(self.store, 'MAX_CHUNK_BYTES()', 'uint256', 8192)
        for index, expected in enumerate(interpretation.documents()):
            identifier = source.schema_id(expected.name)
            if missing and index == 2:
                from .genesis_registry_source_v1 import ZERO_DOCUMENT, ZERO_FACTS
                self.put('eth_call', [{'to': self.schemas,
                    'data': calldata('document(bytes32)', ('bytes32',), (identifier,)),
                    'gas': '0x1312d00'}, self.block_ref],
                    '0x' + encode((DOCUMENT,), (ZERO_DOCUMENT,)).hex())
                self.add(self.schemas, 'documentFacts(bytes32)', DOCUMENT_FACTS,
                    ZERO_FACTS, ('bytes32',), (identifier,))
                continue
            content = b'{"wrong":"script interpretation"}' if mismatched and index == 3 else expected.content
            chunks = tuple(content[start:start + 8192]
                for start in range(0, len(content), 8192))
            hashes = tuple(keccak256(chunk) for chunk in chunks)
            spec = (expected.name, KINDS[expected.kind], keccak256(content),
                expected.canonicalization_id, expected.supersedes_id,
                expected.uri, len(content))
            declaration = keccak256(encode((DOCUMENT_SPEC, Array('bytes32')),
                (spec, hashes)))
            document = (True, 0, declaration, spec, hashes)
            facts = (True, KINDS[expected.kind], 0, spec[2], spec[3],
                spec[4], spec[6], len(hashes), declaration)
            self.put('eth_call', [{'to': self.schemas,
                'data': calldata('document(bytes32)', ('bytes32',), (identifier,)),
                'gas': '0x1312d00'}, self.block_ref],
                '0x' + encode((DOCUMENT,), (document,)).hex())
            self.add(self.schemas, 'documentFacts(bytes32)', DOCUMENT_FACTS,
                facts, ('bytes32',), (identifier,))
            self.add(self.schemas, 'documentBytes(bytes32)', 'bytes',
                '0x' + content.hex(), ('bytes32',), (identifier,))
            for chunk_index, (digest, raw) in enumerate(zip(hashes, chunks)):
                pointer = A(1000 + int(digest[2:10], 16) % 100000)
                self.add(self.schemas, 'documentChunkHashAt(bytes32,uint256)',
                    'bytes32', digest, ('bytes32', 'uint256'), (identifier, chunk_index))
                self.add(self.store, 'chunk(bytes32)', ('address', 'uint32'),
                    (pointer, len(raw)), ('bytes32',), (digest,))
                self.add(self.store, 'readChunk(bytes32)', 'bytes', '0x' + raw.hex(),
                    ('bytes32',), (digest,))
                self.put('eth_getCode', [pointer, self.block_ref], '0x' + (b'\0' + raw).hex())
        self.registry_anchor = {key: self.anchor[key] for key in
            ('chainId', 'core', 'blockHash', 'blockNumber', 'timestamp',
                'stateRoot', 'environment', 'deploymentEvidenceHash')}
        self.registry_anchor.update(profile=registry_source.PROFILE,
            coreRuntimeHash=self.pins[self.core], codePins=[
                {'address': address, 'runtimeHash': self.pins[address]} for address in
                (self.core, self.metadata, self.module_registry, self.schemas,
                    self.store, self.governance)],
            runtimeAdmission={'sourceCommit': SOURCE_REVISION,
                'kind': 'synthetic_fixture', 'artifactHash': H('script registry bridge')})
        self.registry_anchor_raw = dumps(self.registry_anchor)
        return registry_source.TokenScriptRegistrySource(self.registry_anchor_raw, self)


class TokenScriptSourceTests(unittest.TestCase):
    def test_public_capture_compose_and_offline_verify(self):
        fixture = TokenScriptFixture('chunked')
        reader = fixture.source(); reader.snapshot(); transcript = reader.transcript()
        package = capture.replay(fixture.anchor_raw, keccak256(fixture.anchor_raw),
            transcript, keccak256(transcript), fixture.runtime_bridge_raw,
            keccak256(fixture.runtime_bridge_raw), provenance='synthetic_fixture',
            disclosure='public')
        files = dict(package.files)
        self.assertEqual(package.report['workClass'], 'script')
        self.assertFalse(package.report['claims']['registeredInterpretationProven'])
        self.assertEqual(capture.verify(files, package.manifest_hash).manifest_hash,
            package.manifest_hash)
        files['payloads/script.bin'] += b'altered'
        with self.assertRaises(MuseumError): capture.verify(files, package.manifest_hash)

    def test_exact_registered_interpretation_joins_same_native_source_map(self):
        fixture = TokenScriptFixture('stable', collection_override=True)
        token = fixture.source(); token_raw = token.snapshot(); token_transcript = token.transcript()
        token_package = capture.replay(fixture.anchor_raw, keccak256(fixture.anchor_raw),
            token_transcript, keccak256(token_transcript), fixture.runtime_bridge_raw,
            keccak256(fixture.runtime_bridge_raw), provenance='synthetic_fixture',
            disclosure='public')
        registry = fixture.install_registry(); registry_raw = registry.snapshot()
        registry_transcript = registry.transcript()
        joined = registered_capture.compose(dict(token_package.files), token_package.manifest_hash,
            fixture.registry_anchor_raw, keccak256(fixture.registry_anchor_raw),
            registry_transcript, keccak256(registry_transcript), disclosure='public')
        self.assertEqual(joined.report['currentVerifiedCodes'], ['OD-SCRIPT-MANIFEST'])
        self.assertEqual(registered_capture.verify(dict(joined.files),
            joined.manifest_hash).manifest_hash, joined.manifest_hash)
        token_state = loads(token_raw, maximum=rpc.MAX_TRANSCRIPT)['sourceState']
        registry_state = loads(registry_raw,
            maximum=registry_source.genesis.MAX_OUTPUT)['sourceState']
        self.assertEqual({key: token_state[key] for key in registry_state},
            registry_state)
        self.assertTrue(loads(token_raw,
            maximum=rpc.MAX_TRANSCRIPT)['positiveScriptClassification'])
        self.assertEqual(len(loads(registry_raw,
            maximum=registry_source.genesis.MAX_OUTPUT)['documents']), 4)
        for options in ({'missing': True}, {'mismatched': True}):
            with self.subTest(options=options):
                negative = TokenScriptFixture('stable', collection_override=True)
                reader = negative.install_registry(**options)
                with self.assertRaises(MuseumError): reader.snapshot()

    def test_token_override_and_frozen_source_replay(self):
        for mode, collection_override in (('stable', False), ('chunked', False),
                ('stable', True), ('chunked', True)):
            with self.subTest(mode=mode, collection_override=collection_override):
                fixture = TokenScriptFixture(mode, collection_override=collection_override)
                reader = fixture.source(); raw = reader.snapshot()
                result = loads(raw, maximum=rpc.MAX_TRANSCRIPT)
                self.assertEqual(result['workClass'], 'script')
                self.assertTrue(result['positiveScriptClassification'])
                self.assertEqual(result['resolvedRecord'][3], '41')
                self.assertEqual(result['interpretation']['report']['completeScriptBytes'], True)
                transcript = reader.transcript()
                replay = source.TokenScriptSource(fixture.anchor_raw,
                    rpc.ReplayTransport(transcript, keccak256(transcript)))
                self.assertEqual(replay.snapshot(), raw)

    def test_zero_selection_remains_unknown(self):
        fixture = TokenScriptFixture('empty')
        result = loads(fixture.source().snapshot(), maximum=rpc.MAX_TRANSCRIPT)
        self.assertEqual(result['workClass'], 'unknown')
        self.assertFalse(result['positiveScriptClassification'])

    def test_exact_registered_documents_do_not_promote_empty_selection(self):
        fixture = TokenScriptFixture('empty')
        token = fixture.source(); token.snapshot(); token_transcript = token.transcript()
        token_package = capture.replay(fixture.anchor_raw, keccak256(fixture.anchor_raw),
            token_transcript, keccak256(token_transcript), fixture.runtime_bridge_raw,
            keccak256(fixture.runtime_bridge_raw), provenance='synthetic_fixture',
            disclosure='public')
        registry = fixture.install_registry(); registry.snapshot()
        transcript = registry.transcript()
        joined = registered_capture.compose(dict(token_package.files),
            token_package.manifest_hash, fixture.registry_anchor_raw,
            keccak256(fixture.registry_anchor_raw), transcript, keccak256(transcript),
            disclosure='public')
        self.assertEqual(joined.report['currentVerifiedCodes'], [])
        self.assertEqual(joined.report['workClass'], 'unknown')
        self.assertEqual(registered_capture.verify(dict(joined.files),
            joined.manifest_hash).manifest_hash, joined.manifest_hash)

    def test_incomplete_nonempty_library_keeps_script_but_not_registered_requirement(self):
        fixture = TokenScriptFixture('chunked')
        bundle_id = fixture.value['library']['bundleId']
        fixture.fail(fixture.metadata, 'dependencyChunk(bytes32,uint256)',
            ('bytes32', 'uint256'), (bundle_id, 0))
        token = fixture.source(); snapshot_raw = token.snapshot()
        snapshot = loads(snapshot_raw, maximum=rpc.MAX_TRANSCRIPT)
        self.assertEqual(snapshot['workClass'], 'script')
        self.assertTrue(snapshot['interpretation']['report']['completeScriptBytes'])
        self.assertFalse(snapshot['interpretation']['report']['completeDependencyBytes'])
        self.assertEqual(snapshot['interpretation']['report']['dependency']['status'],
            'partial_unavailable')
        transcript = token.transcript()
        token_package = capture.replay(fixture.anchor_raw, keccak256(fixture.anchor_raw),
            transcript, keccak256(transcript), fixture.runtime_bridge_raw,
            keccak256(fixture.runtime_bridge_raw), provenance='synthetic_fixture',
            disclosure='public')
        registry = fixture.install_registry(); registry.snapshot()
        registry_transcript = registry.transcript()
        joined = registered_capture.compose(dict(token_package.files),
            token_package.manifest_hash, fixture.registry_anchor_raw,
            keccak256(fixture.registry_anchor_raw), registry_transcript,
            keccak256(registry_transcript), disclosure='public')
        self.assertEqual(joined.report['workClass'], 'script')
        self.assertEqual(joined.report['currentVerifiedCodes'], [])
        self.assertIsNone(joined.report['scriptRequirement'])
        self.assertEqual(registered_capture.verify(dict(joined.files),
            joined.manifest_hash).manifest_hash, joined.manifest_hash)

    def test_complete_chunked_library_earns_registered_requirement(self):
        fixture = TokenScriptFixture('chunked')
        token = fixture.source(); token.snapshot(); transcript = token.transcript()
        token_package = capture.replay(fixture.anchor_raw, keccak256(fixture.anchor_raw),
            transcript, keccak256(transcript), fixture.runtime_bridge_raw,
            keccak256(fixture.runtime_bridge_raw), provenance='synthetic_fixture',
            disclosure='public')
        registry = fixture.install_registry(); registry.snapshot()
        registry_transcript = registry.transcript()
        joined = registered_capture.compose(dict(token_package.files),
            token_package.manifest_hash, fixture.registry_anchor_raw,
            keccak256(fixture.registry_anchor_raw), registry_transcript,
            keccak256(registry_transcript), disclosure='public')
        self.assertEqual(joined.report['currentVerifiedCodes'], ['OD-SCRIPT-MANIFEST'])
        self.assertEqual(registered_capture.verify(dict(joined.files),
            joined.manifest_hash).manifest_hash, joined.manifest_hash)

    def test_offchain_mode_still_has_positive_script_and_later_default_does_not_rewrite_activation(self):
        fixture = TokenScriptFixture('stable', offchain=True, foreign_override=True,
            collection_override=True)
        later_default = [ZERO, fixture.global_record[0], 0, 0, 2, 2, 0,
            ZERO, fixture.global_record[8], (2, A(8), '', '', 0, False)]
        later_default[0] = static._record_hash(fixture.core, fixture.router,
            tuple(later_default))
        fixture.add(fixture.router, 'metadataConfigRecord(bytes32)',
            static.CONFIG_RECORD, tuple(later_default), ('bytes32',),
            (later_default[0],))
        fixture.add(fixture.router, 'defaultMetadataConfig()', static.CONFIG_RECORD,
            tuple(later_default))
        value = loads(fixture.source().snapshot(), maximum=rpc.MAX_TRANSCRIPT)
        self.assertEqual(value['workClass'], 'script')
        self.assertEqual(value['resolvedRecord'][9][0], '0')
        self.assertEqual(value['activationRecord'][1], fixture.global_record[0])
        self.assertEqual(value['retainedDefaultRecord'][0], fixture.global_record[0])
        self.assertNotEqual(value['retainedDefaultRecord'][0], later_default[0])
        self.assertEqual(len([row for row in value['lineageEvents'] if
            row['topics'][0] == source.RECORDED_EVENT]), 4)

    def test_retained_global_default_missing_or_semantically_different_rejects(self):
        fixture = TokenScriptFixture()
        fixture.fail(fixture.router, 'metadataConfigRecord(bytes32)',
            ('bytes32',), (fixture.global_record[0],))
        with self.assertRaises(MuseumError): fixture.source().snapshot()
        for field in ('selection', 'config', 'revision'):
            with self.subTest(field=field):
                fixture = TokenScriptFixture(global_mismatch=field)
                with self.assertRaisesRegex(MuseumError,
                        'retained default/activation differs'):
                    fixture.source().snapshot()

    def test_foreign_token_history_omission_and_event_order_reject(self):
        fixture = TokenScriptFixture(foreign_override=True)
        original = fixture.request
        def omit(method, params):
            rows = original(method, params)
            if method == 'eth_getLogs':
                return [row for row in rows if not (row['topics'][0] == source.RECORDED_EVENT
                    and row['topics'][2] == '0x' + f'{99:064x}')]
            return rows
        fixture.request = omit
        with self.assertRaises(MuseumError): fixture.source().snapshot()
        fixture = TokenScriptFixture(foreign_override=True)
        receipt = fixture.history_receipts[H('config-tx-12')]
        receipt['logs'][0], receipt['logs'][1] = receipt['logs'][1], receipt['logs'][0]
        for index, row in enumerate(receipt['logs']): row['logIndex'] = hex(index)
        with self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_wrong_token_or_record_rejects(self):
        fixture = TokenScriptFixture()
        fixture.add(fixture.core, 'tokenCollectionIdentity(uint256)', source.IDENTITY,
            (False, 0, 0, False), ('uint256',), (42,))
        fixture.anchor['tokenId'] = '42'; fixture.anchor_raw = dumps(fixture.anchor)
        with self.assertRaisesRegex(MuseumError, 'identity differs'):
            fixture.source().snapshot()
        fixture = TokenScriptFixture()
        fixture.selected = tuple([H('wrong'), *fixture.selected[1:]])
        fixture.add(fixture.router, 'resolvedMetadataConfig(uint256)', static.CONFIG_RECORD,
            fixture.selected, ('uint256',), (fixture.token,))
        with self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_frozen_source_and_runtime_tamper_reject(self):
        fixture = TokenScriptFixture()
        raw = list(fixture.raw); raw[6] = 'wrong original source'
        fixture.add(fixture.router, 'staticRenderSourceForConfig(uint256,bytes32)',
            (static.RAW_SOURCE, static.METADATA_CONFIG), (tuple(raw), fixture.selected[9]),
            ('uint256', 'bytes32'), (int(fixture.context['collectionId']), fixture.selected[0]))
        with self.assertRaisesRegex(MuseumError, 'frozen source'):
            fixture.source().snapshot()
        fixture = TokenScriptFixture()
        fixture.put('eth_getCode', [A(8), fixture.block_ref], '0x6000')
        with self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_reordered_native_script_chunks_reject(self):
        fixture = TokenScriptFixture('chunked')
        chunks = fixture.value['script']['chunks']
        bundle_id = fixture.value['script']['bundleId']
        for index in (0, 1):
            fixture.add(fixture.metadata, 'scriptBundleChunk(bytes32,uint256)',
                'bytes', chunks[1 - index]['outcome']['value'],
                ('bytes32', 'uint256'), (bundle_id, index))
        with self.assertRaises(MuseumError): fixture.source().snapshot()


if __name__ == '__main__': unittest.main()
