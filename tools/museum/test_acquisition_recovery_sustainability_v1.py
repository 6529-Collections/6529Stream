"""Synthetic original native ABI histories; no EVM, chain or release authority."""
import copy
import unittest
from unittest.mock import patch

from . import acquisition_recovery_sustainability_v1 as w
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, calldata, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .test_public_chain_history import PublicHistoryFixture
from .test_public_history_rpc import A, H


def _zero(kind):
    if isinstance(kind, tuple): return tuple(_zero(item) for item in kind)
    if kind == 'bool': return False
    if kind == 'address': return ZERO_ADDRESS
    if kind == 'string': return ''
    if kind == 'bytes': return b''
    if kind.startswith('bytes'): return '0x' + '00' * int(kind[5:])
    return 0


class RecoverySustainabilityFixture(PublicHistoryFixture):
    """Build before any other capture; optional base shares real fixture headers.

    `.envelope()` returns original canonical input, `.result()` verifies it.
    `source_state` is the exact common ten-field context. `base` may be an
    existing Title/finality fixture, installed before its original captures.
    Empty mode adds no receipts and supports a minimally intrusive shared case.
    """
    def __init__(self, *, source_state=None, base=None, graph=None, runtime_bytes=None,
                 mode='mixed', scope_type=0, burned=False, release=False):
        super().__init__(end=100)
        self.base = base
        if source_state is None:
            source_state = {**self.anchor, 'core': A(60000), 'collectionId': '1', 'tokenId': '41',
                'environment': 'local_evm_fixture', 'deploymentEvidenceHash': H(60000)}
        self.a = copy.deepcopy(source_state); self.anchor = self.a
        self.core = self.a['core']
        self.executor = graph['executors'][0] if graph is not None else A(60001)
        self.recovery = graph['recoveryHosts'][0] if graph is not None else A(60002)
        if base is not None:
            self.blocks = {row['hash']: row for row in base.blocks.values()}
            self.receipts = base.receipts
        else: self.blocks, self.receipts = {}, {}
        self.logs = []
        self.end = int(self.a['blockNumber'])
        self.getters, self.transactions, self.codes = {}, {}, {}
        self.codes[self.core] = base.codes[self.core] if base is not None else b'synthetic Core ec832'
        self.codes[self.executor] = b'synthetic Executor ec832'
        self.codes[self.recovery] = b'synthetic original recovery ec832'
        self.original_finality = A(60300)
        self.codes[self.original_finality] = ('synthetic dependency ' + self.original_finality).encode()
        if runtime_bytes is not None:
            self.codes.update(copy.deepcopy(runtime_bytes))
        if graph is not None:
            assert len(graph['executors']) == len(graph['recoveryHosts']) == 1
            assert graph['stateExportPublisher'] == self.executor
            assert all(keccak256(self.codes[address]) == digest for address, digest in graph['codePins'].items())
        self.graph = {'executors': [self.executor], 'recoveryHosts': [self.recovery],
            'stateExportPublisher': self.executor, 'codePins': {}}
        self.action_rows, self.recovery_rows, self.export_rows = [], [], []
        self.documents, self.release_evidence, self.owner_sources = {}, None, []
        self.header(self.end)
        self.put(self.core, 'tokenCollectionIdentity(uint256)', ('bool', 'uint256', 'uint256', 'bool'),
            (True, int(self.a['collectionId']), 3, burned), ('uint256',), (int(self.a['tokenId']),))
        self.put(self.core, 'tokenLifecycle(uint256)', ('uint8',), (3 if burned else 2,), ('uint256',), (int(self.a['tokenId']),))
        if base is not None:
            for sig, outs in (('tokenCollectionIdentity(uint256)', ('bool', 'uint256', 'uint256', 'bool')), ('tokenLifecycle(uint256)', ('uint8',))):
                data = calldata(sig, ('uint256',), (int(self.a['tokenId']),))
                self.getters[(self.core, data)] = base.request('eth_call', [{'to': self.core, 'data': data, 'gas': '0x1312d00'},
                    {'blockHash': self.a['blockHash'], 'requireCanonical': True}])
        self.put(self.core, 'getSatellitePointer(bytes32)', (w.citation.POINTER,),
            ((self.executor, keccak256(self.codes[self.executor]), False, schema_id('GOVERNANCE_LAYER'),
                '0x77faad4f', A(60003), 1, H(60003), H(60004), 1),), ('bytes32',), (schema_id('STATE_EXPORT_PUBLISHER'),))
        bootstrap = list(_zero(w.BOOTSTRAP)); bootstrap[0:2] = [True, True]
        bootstrap[11:13] = [self.core, keccak256(self.codes[self.core])]
        self.put(self.executor, 'systemManifestBootstrapState()', w.BOOTSTRAP, bootstrap)
        self.put(self.recovery, 'core()', ('address',), (self.core,))
        self.put(self.recovery, 'governanceAuthority()', ('address',), (self.executor,))
        self.put(self.recovery, 'streamModuleType()', ('bytes32',), (schema_id('STREAM_ARTWORK_FINALITY_RECOVERY'),))
        self.put(self.recovery, 'configurationHash()', ('bytes32',), (H(60005),))
        self.put(self.recovery, 'originalFinalityRegistry()', ('address',), (self.original_finality,))
        self.put(self.original_finality, 'coreReads()', ('address',), (self.core,))
        self.put(self.recovery, 'streamModuleVersion()', ('bytes32',), (schema_id('6529stream.artwork-finality-recovery.v1'),))
        self.put(self.recovery, 'streamModuleInterfaceId()', ('bytes4',), ('0x83685f5c',))
        for interface, supported in (('0x01ffc9a7', True), ('0x83685f5c', True), ('0xffffffff', False)):
            self.put(self.recovery, 'supportsInterface(bytes4)', ('bool',), (supported,), ('bytes4',), (interface,))
        if mode != 'empty':
            self.add_action('executed', scope_type=scope_type, block=1, execute_block=2)
            self.add_action('scheduled', scope_type=1, block=3)
            if mode == 'mixed':
                self.add_action('cancelled', scope_type=1, block=3, execute_block=4)
                self.add_action('expired', scope_type=1, block=3)
                self.add_action('vetoed', scope_type=1, block=3, execute_block=4)
            self.add_export(anchor_block=1, published_block=3)
            self.add_export(anchor_block=2, published_block=4)
            self.add_export_annotations()
        self._seal_getters()
        if release: self.release_artifacts()

    def header(self, number):
        if not hasattr(self, 'a'): return super().header(number)
        if number == int(self.a['blockNumber']):
            return self.blocks.setdefault(self.a['blockHash'], {'hash': self.a['blockHash'], 'number': hex(number),
                'stateRoot': self.a['stateRoot'], 'timestamp': hex(int(self.a['timestamp'])),
                'parentHash': H(99999999 + number) if number else ZERO, 'transactions': []})
        existing = [row for row in self.blocks.values() if int(row['number'], 16) == number]
        if existing: return existing[0]
        digest = H(100000000 + number)
        return self.blocks.setdefault(digest, {'hash': digest, 'number': hex(number),
            'stateRoot': H(200000000 + number), 'timestamp': hex(int(self.a['timestamp']) - self.end + number),
            'parentHash': H(99999999 + number) if number else ZERO, 'transactions': []})

    def put(self, host, sig, outs, values, ins=(), args=()):
        self.getters[(host, calldata(sig, ins, args))] = '0x' + encode(outs, values).hex()

    def event(self, block, descriptor, *, same_transaction=False):
        host, topics, data = descriptor
        row = super().add(block, address=host, topics=list(topics), same_transaction=same_transaction)
        row['data'] = data
        return row

    def tx(self, log, who, data, to=None):
        self.transactions[log['transactionHash']] = {'hash': log['transactionHash'],
            **{key: log[key] for key in ('blockHash', 'blockNumber', 'transactionIndex')},
            'from': who, 'to': to or self.executor, 'value': '0x0', 'input': data,
            'chainId': hex(int(self.a['chainId']))}

    def add_action(self, status, *, scope_type, block, execute_block=None, action_class=2):
        nonce = len(self.action_rows); cid, token = int(self.a['collectionId']), int(self.a['tokenId'])
        scope = (scope_type, cid, token if scope_type == 1 else 0, ZERO if scope_type < 2 else H(70000 + nonce))
        if scope_type >= 2: scope = self.membership(scope)
        manifest_uri, reason_uri = 'ipfs://recovery-intent', 'urn:reason:exact-original'
        manifest = (manifest_uri, keccak256(manifest_uri.encode()), ZERO, H(60100), H(60101))
        component = (H(60102), A(60103), '0x12345678', H(60104), H(60105), H(60106), H(60107))
        record = [True, ZERO, scope, H(60108), ZERO, 1, H(60109), ZERO, True, component, manifest,
            (1, H(60110), A(60111), H(60112), 1, 0, H(60113), 1,
                int(self.header(block)['timestamp'], 16), 1, 0), H(60114), reason_uri,
            int(self.header(execute_block or block)['timestamp'], 16)]
        intent = w.citation.recovery_intent(int(self.a['chainId']), self.recovery, record)
        manifest = (*manifest[:2], keccak256(intent), *manifest[3:]); record[10] = manifest
        request = (scope, record[3], record[4], record[6], component, manifest, record[12], reason_uri)
        data = hex_bytes(calldata(w.EXECUTE_SIGNATURE, (w.citation.RECOVERY_REQUEST,), (request,)))
        scope_hash = keccak256(encode(('bytes32', 'uint256', 'address', w.citation.SCOPE),
            (schema_id('6529STREAM_FINALITY_RECOVERY_SCOPE_V1'), int(self.a['chainId']), self.recovery, scope)))
        old = keccak256(encode(('bytes32', 'bytes32', 'bytes32', 'bytes32', 'uint64', 'bytes32'),
            (schema_id('6529STREAM_FINALITY_RECOVERY_OLD_STATE_V1'), keccak256(encode(w.citation.SCOPE, scope)), record[3], ZERO, 0, record[6])))
        new = keccak256(encode(('bytes32', 'uint256', 'address', 'uint64', w.citation.RECOVERY_REQUEST),
            (schema_id('6529STREAM_FINALITY_RECOVERY_NEW_STATE_V1'), int(self.a['chainId']), self.recovery, 1, request)))
        call = (self.recovery, 0, w.EXECUTE_SELECTOR, keccak256(data), scope_hash, old, new)
        start = int(self.header(block)['timestamp'], 16)
        expiry = int(self.a['timestamp']) - 1 if status == 'expired' else int(self.a['timestamp']) + 100
        folds, calls_hash = w.governance.transition_hashes((call,)), w.governance.calls_hash((call,))
        action = [dict(scheduled=1, cancelled=2, executed=3, expired=4, vetoed=5)[status], action_class,
            self.recovery, 0, w.EXECUTE_SELECTOR, calls_hash, *folds, start, expiry, A(60120),
            A(60121) if status == 'executed' else ZERO_ADDRESS, A(60122) if status == 'cancelled' else ZERO_ADDRESS,
            A(60123) if status == 'vetoed' else ZERO_ADDRESS, H(60124), 'original schedule reason', H(60125)]
        digest = w.governance.action_id(self.a['chainId'], self.executor,
            (action_class, calls_hash, *folds, nonce, start, expiry, action[15], action[17]))
        record[1] = digest; record[7] = w.citation.recovered_hash(int(self.a['chainId']), self.recovery, record)
        topics = (digest, w._topic('uint8', action_class), w._topic('address', self.recovery))
        scheduled = self.event(block, w._event(self.executor, 'scheduled', topics,
            w.finality.GOVERNANCE_SCHEDULED_DATA, (1, *action[3:11], nonce, action[11], *action[15:])))
        schedule_input = w.governance.SELECTORS['schedule_batch'] + encode(w.governance.SCHEDULE_BATCH,
            (action_class, (call,), *action[6:11], *action[15:])).hex()
        self.tx(scheduled, action[11], schedule_input)
        if status == 'executed':
            self.event(execute_block, w._event(self.recovery, 'lineage', (digest, ZERO, record[3]),
                ('uint16', 'uint64', 'bytes32', 'bytes32'), (1, 1, record[6], record[7])))
            self.event(execute_block, w._event(self.recovery, 'evidence', (digest,),
                ('uint16', *w.citation.EVIDENCE), (1, *record[11])), same_transaction=True)
            if scope_type == 0:
                self.event(execute_block, w._event(self.recovery, 'recovery', (w._topic('uint256', cid), digest),
                    ('uint16', 'bytes32', 'bytes32', 'bool', 'bytes32', 'string'),
                    (1, manifest[2], record[7], True, record[12], reason_uri)), same_transaction=True)
            else:
                self.event(execute_block, w._event(self.recovery, 'scopedRecovery', (w._topic('uint8', scope_type), w._topic('uint256', cid), digest),
                    ('uint16', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'bool', 'bytes32', 'string'),
                    (1, scope[2], scope[3], manifest[2], record[7], True, record[12], reason_uri)), same_transaction=True)
            executed = self.event(execute_block, w._event(self.executor, 'executed', topics,
                w.finality.GOVERNANCE_EXECUTED_DATA, (1, *action[3:9], action[12], action[17])), same_transaction=True)
            self.tx(executed, action[12], w.governance.SELECTORS['execute_batch'] + encode(w.governance.EXECUTE_BATCH,
                (digest, (call,), (data,))).hex())
            self.recovery_rows.append(record)
        elif status == 'cancelled':
            self.event(execute_block, w._event(self.executor, 'cancelled', topics,
                ('uint16', 'bytes4', 'bytes32', 'bytes32', 'address', 'bytes32', 'string'),
                (1, action[4], action[5], action[6], action[13], H(60126), '')))
        elif status == 'vetoed':
            self.event(execute_block, w._event(self.executor, 'vetoed', (digest, w._topic('uint8', action_class), w._topic('address', action[14])),
                ('uint16', 'bytes32', 'bytes32'), (1, action[6], H(60127))))
        pointer = A(60200 + nonce); self.codes[pointer] = b'\0' + encode((Array('bytes', 64),), ((data,),))
        self.put(self.executor, 'governanceAction(bytes32)', (w.finality.GOVERNANCE_ACTION,), (action,), ('bytes32',), (digest,))
        self.put(self.executor, 'scheduledCallData(bytes32)', (Array('bytes', 64),), ((data,),), ('bytes32',), (digest,))
        self.put(self.executor, 'scheduledCallDataPointer(bytes32)', ('address',), (pointer,), ('bytes32',), (digest,))
        self.put(self.recovery, 'finalityRecoveryRecord(bytes32)', (w.citation.RECOVERY,),
            (record if status == 'executed' else _zero(w.citation.RECOVERY),), ('bytes32',), (digest,))
        self.put(self.recovery, 'finalityRecoveryManifestBytes(bytes32)', ('bytes',), (intent,), ('bytes32',), (manifest[2],))
        self.action_rows.append({'id': digest, 'record': action, 'request': request, 'scheduled': scheduled, 'carrier': pointer})

    def membership(self, scope):
        original, provider, member, metadata, inventory = (A(60300 + i) for i in range(5))
        for target in (original, provider, member, metadata, inventory): self.codes[target] = ('synthetic dependency ' + target).encode()
        self.put(self.recovery, 'originalFinalityRegistry()', ('address',), (original,))
        for host, sig, address in ((original, 'coreReads()', self.core), (original, 'scopeEvidenceProvider()', provider),
                (original, 'metadataReads()', metadata), (provider, 'core()', self.core), (provider, 'metadataHost()', metadata),
                (provider, 'scopeMembershipHost()', member), (member, 'core()', self.core), (member, 'metadataHost()', metadata),
                (member, 'tokenInventory()', inventory)):
            self.put(host, sig, ('address',), (address,))
        for host, sig, address in ((original, 'scopeEvidenceProviderCodeHash()', provider), (provider, 'coreCodeHash()', self.core),
                (provider, 'metadataHostCodeHash()', metadata), (provider, 'scopeMembershipHostCodeHash()', member)):
            self.put(host, sig, ('bytes32',), (keccak256(self.codes[address]),))
        record_hash = H(60310)
        scope = (*scope[:3], keccak256(encode(('bytes32', 'uint256', 'address', 'uint256', 'uint8', 'bytes32'),
            (schema_id('6529STREAM_SCOPE_MEMBERSHIP_ID_V1'), int(self.a['chainId']), self.core, scope[1], scope[0], record_hash))))
        from .canonical import subject_id
        from .scoped_static_snapshot_wire import membership_hash
        tokens = (int(self.a['tokenId']), int(self.a['tokenId']) + 3)
        facts = (subject_id('scope', self.a['chainId'], self.core, self.a['collectionId'], scope_type=str(scope[0]), scope_id=scope[3]),
            H(60311), record_hash, len(tokens), keccak256(b''.join(encode(('uint256',), (t,)) for t in tokens)), ZERO, 0, ZERO)
        facts = (*facts[:5], membership_hash(facts, scope, self.a,
            {'metadata': {'address': metadata, 'runtimeHash': keccak256(self.codes[metadata])},
             'tokenInventory': {'address': inventory, 'runtimeHash': keccak256(self.codes[inventory])}}), 0, ZERO)
        self.put(member, 'requireScopeMembership(' + w.citation.SCOPE_SIG + ')', (w.MEMBERSHIP,), (facts,), (w.citation.SCOPE,), (scope,))
        for i, token in enumerate(tokens):
            self.put(member, 'scopeTokenAt(' + w.citation.SCOPE_SIG + ',uint256)', ('uint256',), (token,), (w.citation.SCOPE, 'uint256'), (scope, i))
        return scope

    def add_export(self, *, anchor_block, published_block):
        digest, manifest = H(60400 + len(self.export_rows)), H(60410 + len(self.export_rows))
        record = (anchor_block, self.header(anchor_block)['hash'], digest, manifest, 'ipfs://export-' + digest[2:], len(self.export_rows) + 1)
        log = self.event(published_block, w._event(self.executor, 'export',
            (w._topic('uint256', anchor_block), digest, manifest), ('uint16', 'bytes32', 'string'), (1, record[1], record[4])))
        self.export_rows.append({'record': record, 'superseded': ZERO, 'event': log})

    def add_export_annotations(self):
        old, new = self.export_rows[0]['record'][2], self.export_rows[1]['record'][2]
        self.export_rows[0]['superseded'] = new
        self.event(5, w._event(self.executor, 'supersede', (old, new, H(60420)), ('uint16', 'string'), (1, 'urn:supersession')))
        self.event(5, w._event(self.executor, 'challenge', (new, H(60421), w._topic('address', A(60422))), ('uint16', 'string'), (1, 'urn:challenge')))
        self.put(self.executor, 'stateExportChallengeExists(bytes32,bytes32)', ('bool',), (True,), ('bytes32', 'bytes32'), (new, H(60421)))

    def _seal_getters(self):
        self.put(self.executor, 'governanceNonce()', ('uint256',), (len(self.action_rows),))
        scopes = {(0, int(self.a['collectionId']), 0, ZERO), (1, int(self.a['collectionId']), int(self.a['tokenId']), ZERO)}
        scopes |= {r['request'][0] for r in self.action_rows}
        for scope in scopes:
            records = [r for r in self.recovery_rows if r[2] == scope]
            head = (records[-1][1], records[-1][7], records[-1][5]) if records else (ZERO, ZERO, 0)
            self.put(self.recovery, 'activeFinalityRecovery(' + w.citation.SCOPE_SIG + ')', w.citation.HEAD, head, (w.citation.SCOPE,), (scope,))
        self.put(self.executor, 'stateExportCount()', ('uint256',), (len(self.export_rows),))
        for i, row in enumerate(self.export_rows):
            digest = row['record'][2]
            self.put(self.executor, 'stateExportHashAt(uint256)', ('bytes32',), (digest,), ('uint256',), (i,))
            self.put(self.executor, 'stateExport(bytes32)', (w.EXPORT, 'bytes32'), (row['record'], row['superseded']), ('bytes32',), (digest,))
        self.put(self.executor, 'latestStateExport()', w.EXPORT[:5], self.export_rows[-1]['record'][:5] if self.export_rows else (0, ZERO, ZERO, ZERO, ''))
        self.graph['codePins'] = {host: keccak256(raw) for host, raw in self.codes.items()}

    def release_artifacts(self):
        def retain(data):
            raw = data if type(data) is bytes else dumps(data); digest = keccak256(raw)
            self.documents[digest] = '0x' + raw.hex(); return digest
        source, cost = retain(b'synthetic commitment: not a real fund'), retain(b'synthetic cost worksheet')
        funding = retain({'profile': 'STREAM_MUSEUM_FUNDING_EVIDENCE_V1', 'currency': 'USD', 'unitScale': '100',
            'secondsPerYear': '31536000', 'committedSources': [{'id': 'source-1', 'amountUnits': '100000', 'evidenceHash': source}],
            'annualObligations': [{'id': 'archive', 'annualCostUnits': '10000', 'evidenceHash': cost}], 'viabilityFloorSeconds': '315360000'})
        drill = retain({'profile': 'STREAM_MUSEUM_ZERO_SIGNER_DRILL_EVIDENCE_V1', 'releaseId': 'synthetic-candidate',
            'performedAt': self.a['timestamp'], 'signerCount': '0', 'reportHash': retain(b'synthetic drill retained original; never executed')})
        manifest = retain({'profile': 'STREAM_MUSEUM_RELEASE_EVIDENCE_V1', 'releaseId': 'synthetic-candidate',
            'environment': 'synthetic_fixture', 'fundingManifestHash': funding, 'museumDrillHash': drill})
        self.release_evidence = {'releaseManifestHash': manifest, 'fundingManifestHash': funding, 'museumDrillHash': drill,
            'releaseSelection': {'releaseId': 'synthetic-candidate', 'sourceCommit': w.SOURCE_REVISION,
                'evidenceHash': retain(b'synthetic release-selection evidence')}}

    def request(self, method, params):
        if method == 'eth_call': return self.getters[(params[0]['to'], params[0]['data'])]
        if method == 'eth_getCode': return '0x' + self.codes[params[0]].hex()
        if method == 'eth_getTransactionByHash': return copy.deepcopy(self.transactions[params[0]])
        if method == 'eth_getLogs':
            f = params[0]
            return copy.deepcopy([log for receipt in self.receipts.values() for log in receipt['logs']
                if int(f['fromBlock'], 16) <= int(log['blockNumber'], 16) <= int(f['toBlock'], 16) and w.history._matches(log, f)])
        return super().request(method, params)

    def envelope(self):
        value = {'profile': w.PROFILE, 'anchor': self.a, 'graph': self.graph, 'provenance': 'synthetic_fixture',
            'calls': [], 'documents': self.documents, 'releaseEvidence': self.release_evidence, 'ownerSources': self.owner_sources}
        for _ in range(10000):
            raw = dumps(value)
            try:
                w.validate(raw, keccak256(raw)); return raw
            except w.MissingObservation as missing:
                value['calls'].append({'method': missing.method, 'params': missing.params,
                    'result': self.request(missing.method, missing.params)})
        raise AssertionError('fixture capture did not converge')

    def result(self):
        raw = self.envelope(); return w.validate(raw, keccak256(raw))


def owner_response(base, payload, *, supported=True):
    """Add a real original OwnerRecords lane before either capture is made."""
    from ..metadata import owner_notice_profile as notice
    from . import owner_catalog_source as native
    from .canonical import record_chain, subject_id
    from .dossier_gather_records import JCS_ID, JCS_HASH
    token, family = 41, schema_id('RECOVERY_RESPONSE')
    raw = dumps(payload); host, owner = base.title_host, A(28002)
    lane = [row for row in base.typed_rows if row[1][0] == family]
    record = (family, subject_id('token', base.a['chainId'], base.core, '0', token_id=str(token)),
        schema_id(notice.RESPONSE if supported else 'UNSUPPORTED_RECOVERY_RESPONSE'),
        (1, hex_bytes(keccak256(raw)), JCS_ID), 'ipfs://synthetic-recovery-response', raw, 1)
    bundle = encode(('bytes32', 'address', 'bytes32'), (schema_id('DIRECT'), owner, keccak256(raw)))
    receipt = [token, owner, int(base.a['timestamp']), len(lane), ZERO, False, ZERO, 0, 0,
        keccak256(dumps(notice.schema(notice.RESPONSE))), JCS_HASH, schema_id('DIRECT'), keccak256(bundle)]
    digest = native.native_hash(int(base.a['chainId']), host, base.core, record, receipt)
    receipt[4] = record_chain(base.a['chainId'], host, str(token), family,
        lane[-1][2][4] if lane else ZERO, digest, str(receipt[3])); receipt = tuple(receipt)
    base.typed_rows.append((digest, record, receipt, bundle))
    pointer = base._carrier(bundle)
    base.add(host, 'ownerRecord(bytes32)', ('bytes32',), (digest,), (native.OWNER_RECORD, native.RECEIPT), (record, receipt))
    base.add(host, 'ownerRecordSignatureBundle(bytes32)', ('bytes32',), (digest,), ('address', 'bytes'), (pointer, bundle))
    base.add(host, 'recordHashAt(uint256,bytes32,uint256)', ('uint256', 'bytes32', 'uint256'),
        (token, family, receipt[3]), ('bytes32',), (digest,))
    base.owner_events[digest] = base.event(int(base.a['blockNumber']), host,
        [native.RECORD_EVENT, base.topic('uint256', token), family, base.topic('address', owner)],
        (native.OWNER_RECORD, 'bytes32', 'bytes32', 'bool', 'uint16'), (record, digest, receipt[4], False, 1))
    base._title_lane_state()
    return digest


class RecoverySustainabilityTests(unittest.TestCase):
    def verify(self, value):
        raw = dumps(value); return w.validate(raw, keccak256(raw))

    def test_original_scheduled_executed_cancelled_virtual_expired_and_vetoed(self):
        result = RecoverySustainabilityFixture().result()
        self.assertEqual([r['status'] for r in result.report['recoveries']['applicableRecords']],
            ['executed', 'scheduled', 'cancelled', 'expired', 'vetoed'])
        self.assertTrue(result.report['recoveries']['listedExecutorRecoveryInputsComplete'])
        self.assertFalse(result.report['recoveries']['globalRecoveryHostUniverseProven'])
        self.assertEqual(result.report['recoveries']['records'][0]['artworkBytesChanged'], True)
        self.assertIsNone(result.report['recoveries']['records'][1]['artworkBytesChanged'])
        self.assertEqual(result.report['sustainability']['status'], 'current_release_evidence_not_supplied')

    def test_state_export_all_indices_supersession_challenge_and_age_from_state_block(self):
        result = RecoverySustainabilityFixture().result(); exports = result.report['currentStateExport']
        self.assertEqual(exports['count'], '2')
        self.assertEqual(exports['records'][0]['supersededBy'], exports['records'][1]['record'][2])
        self.assertEqual(len(exports['latest']['challenges']), 1)
        self.assertEqual(exports['latest']['ageSeconds'], '98')
        self.assertNotEqual(exports['latest']['exportedStateTimestamp'], exports['latest']['publicationTimestamp'])

    def test_empty_local_denominators_do_not_claim_protocol_absence(self):
        result = RecoverySustainabilityFixture(mode='empty').result()
        self.assertEqual(result.report['recoveries']['records'], [])
        self.assertIsNone(result.report['currentStateExport']['latest'])
        self.assertFalse(result.report['recoveries']['noProtocolRecoveriesClaimed'])

    def test_bound_host_checked_even_for_empty_history(self):
        f = RecoverySustainabilityFixture(mode='empty')
        f.put(f.recovery, 'core()', ('address',), (A(99),))
        with self.assertRaisesRegex(MuseumError, 'original host bindings'): f.result()

    def test_coherent_nonterminal_freeze_recovery_execution_rejects(self):
        f = RecoverySustainabilityFixture(mode='empty')
        f.add_action('executed', scope_type=0, block=1, execute_block=2, action_class=3)
        f._seal_getters()
        with self.assertRaisesRegex(MuseumError, 'terminal-freeze action class'): f.result()

    def test_title_fixture_common_state_core_and_header_are_original_observations(self):
        from .title_v5_fixture import TitleV5Fixture
        from .canonical_composition_observations_v1 import reconcile
        base = TitleV5Fixture()
        state = {key: base.title_ownership_anchor[key] for key in w.STATE_KEYS}
        f = RecoverySustainabilityFixture(source_state=state, base=base, mode='empty')
        result = f.result()
        self.assertEqual(result.report['sourceState'], state)
        self.assertEqual(result.observations[0]['runtimePins'][base.core], base.pins[base.core])
        self.assertEqual(result.report['identity']['collectionSerial'], '3')
        reconcile(state, result.observations)

    def _owner_case(self):
        from .title_v5_fixture import TitleV5Fixture
        from ..metadata import owner_notice_profile as notice
        from .canonical import subject_id
        base = TitleV5Fixture()
        state = {key: base.title_ownership_anchor[key] for key in w.STATE_KEYS}
        f = RecoverySustainabilityFixture(source_state=state, base=base, mode='simple')
        row = f.recovery_rows[0]
        payload = dict(notice.examples()['recovery-objected.json'],
            subjectId=subject_id('token', state['chainId'], state['core'], '0', token_id=state['tokenId']),
            recoveryId=row[1], recoveryManifestHash=row[10][2])
        typed = owner_response(base, payload)
        unmatched = owner_response(base, dict(payload, recoveryId=H(9899)))
        unsupported = owner_response(base, {'retained': 'opaque schema'}, supported=False)
        # The base appends to its existing first transaction. The new recovery
        # fixture also has later transactions at this height, so finalize their
        # global log coordinates before any reader captures original bytes.
        for header in f.blocks.values():
            index = 0
            for transaction in header['transactions']:
                for log in f.receipts[transaction]['logs']:
                    log['logIndex'] = hex(index); index += 1
        originals, pins = base.owner_capture()
        f.owner_sources.append({'files': {name: '0x' + raw.hex() for name, raw in originals.items()}, 'pins': pins})
        return f, originals, typed, unmatched, unsupported

    def test_owner_response_complete_lane_exact_original_join_and_unsupported_retention(self):
        f, originals, typed, unmatched, unsupported = self._owner_case()
        with patch('socket.socket', side_effect=AssertionError('offline concrete source replay')):
            result = f.result()
        catalog = result.report['recoveries']['ownerResponseCatalogues']
        rows = {row['recordHash']: row for row in catalog['records']}
        self.assertEqual(set(rows), {typed, unmatched, unsupported})
        self.assertEqual(len(rows[typed]['matches']), 1)
        self.assertFalse(rows[typed]['matches'][0]['beforeExecution'])
        self.assertEqual(rows[unmatched]['matches'], [])
        self.assertEqual(rows[unsupported]['status'], 'unsupported_original_schema')
        self.assertFalse(rows[typed]['responseIsVeto'])
        self.assertTrue(catalog['suppliedHostLanesComplete'])
        self.assertFalse(catalog['globalHostCompleteness'])
        self.assertEqual(len(result.observations), 2)
        for name, raw in originals.items():
            self.assertEqual(result.files['owner-sources/' + f.base.title_host[2:] + '/' + name], raw)

    def test_owner_capture_pins_and_coherent_cross_source_getter_conflict_reject(self):
        f, _, _, _, _ = self._owner_case(); value = loads(f.envelope(), maximum=w.MAX_BYTES)
        value['ownerSources'][0]['pins']['snapshotHash'] = H(9911)
        with self.assertRaisesRegex(MuseumError, 'original source pin'): self.verify(value)
        # Both sources remain individually replayable, but one original shared
        # Core code observation now contradicts the complete owner source.
        f, _, _, _, _ = self._owner_case()
        f.codes[f.core] = b'different admitted same-block Core'
        f.graph['codePins'][f.core] = keccak256(f.codes[f.core])
        bootstrap = list(_zero(w.BOOTSTRAP)); bootstrap[:2] = [True, True]
        bootstrap[11:13] = [f.core, f.graph['codePins'][f.core]]
        f.put(f.executor, 'systemManifestBootstrapState()', w.BOOTSTRAP, bootstrap)
        with self.assertRaisesRegex(MuseumError, 'conflicting runtime'): f.result()

    def test_external_state_and_runtime_fixture_arguments_rebuild_all_preimages(self):
        source = RecoverySustainabilityFixture(mode='empty')
        state = copy.deepcopy(source.a); state['chainId'] = '31337'; state['core'] = A(60500)
        codes = {state['core']: b'other Core runtime', A(60501): b'other Executor runtime', A(60502): b'other recovery runtime'}
        graph = {'executors': [A(60501)], 'recoveryHosts': [A(60502)], 'stateExportPublisher': A(60501),
            'codePins': {host: keccak256(raw) for host, raw in codes.items()}}
        f = RecoverySustainabilityFixture(source_state=state, graph=graph, runtime_bytes=codes, mode='simple')
        result = f.result(); self.assertEqual(result.report['recoveries']['records'][0]['host'], A(60502))
        self.assertEqual(result.report['hostBindings'][0]['executor'], A(60501))

    def test_release_costed_horizon_exact_artifact_links_and_qualified_drill(self):
        result = RecoverySustainabilityFixture(mode='empty', release=True).result()
        funding = result.report['sustainability']['funding']
        self.assertEqual(funding['coverageHorizonSeconds'], '315360000')
        self.assertEqual(funding['horizonStatus'], 'meets_floor')
        self.assertFalse(funding['financialCommitmentsAuthenticated'])
        self.assertFalse(result.report['sustainability']['museumDrill']['executionIndependentlyVerified'])
        self.assertTrue(any(path.startswith('documents/') for path in result.files))

    def test_full_sealed_release_season_view_membership_and_burned_target(self):
        for scope in (2, 3, 4):
            with self.subTest(scope=scope):
                result = RecoverySustainabilityFixture(mode='simple', scope_type=scope, burned=True).result()
                membership = result.report['recoveries']['records'][0]['applicability']
                self.assertTrue(membership['applies']); self.assertEqual(membership['tokens'], ['41', '44'])
                self.assertTrue(result.report['identity']['burned'])

    def test_offline_original_bytes_observations_and_external_pin(self):
        raw = RecoverySustainabilityFixture(mode='empty').envelope()
        with patch('socket.socket', side_effect=AssertionError('no network')): result = w.validate(raw, keccak256(raw))
        self.assertEqual(result.files['source/evidence.json'], raw)
        self.assertEqual(result.observations[0]['transcript']['calls'], loads(raw, maximum=w.MAX_BYTES)['calls'])
        with self.assertRaisesRegex(MuseumError, 'external evidence hash'): w.validate(raw, H(99))

    def test_nonce_count_missing_event_cannot_be_concealed_by_rehash(self):
        f = RecoverySustainabilityFixture(); f.put(f.executor, 'governanceNonce()', ('uint256',), (6,))
        with self.assertRaisesRegex(MuseumError, 'nonce/event denominator'): f.result()

    def test_changed_action_id_or_stored_call_commitment_rejects(self):
        f = RecoverySustainabilityFixture(); row = f.action_rows[1]; action = list(row['record']); action[5] = H(999)
        f.put(f.executor, 'governanceAction(bytes32)', (w.finality.GOVERNANCE_ACTION,), (action,), ('bytes32',), (row['id'],))
        with self.assertRaisesRegex(MuseumError, 'event/stored action differs'): f.result()

    def test_changed_original_execution_calldata_rejects(self):
        f = RecoverySustainabilityFixture(); key = next(key for key, row in f.transactions.items()
            if row['input'].startswith(w.governance.SELECTORS['execute_batch']))
        decoded = w.governance.decode_execution(f.transactions[key]['input'])
        inputs = list(decoded['callDatas']); inputs[0] = inputs[0][:-1] + b'\x01'
        f.transactions[key]['input'] = w.governance.SELECTORS['execute_batch'] + encode(w.governance.EXECUTE_BATCH,
            (decoded['actionId'], decoded['calls'], tuple(inputs))).hex()
        with self.assertRaisesRegex(MuseumError, 'execution transaction'): f.result()

    def test_unavailable_original_schedule_retained_partial_for_nonrecovery_action(self):
        f = RecoverySustainabilityFixture(mode='empty')
        f.add_action('scheduled', scope_type=1, block=1); f._seal_getters()
        f.transactions[f.action_rows[0]['scheduled']['transactionHash']] = None
        result = f.result()
        self.assertFalse(result.report['recoveries']['listedExecutorRecoveryInputsComplete'])
        self.assertIn('schedule_transaction_unavailable', result.report['recoveries']['undecodedActions'][0]['reason'])

    def test_missing_or_wrapped_schedule_preserves_actual_executed_native_record(self):
        for wrapped in (False, True):
            with self.subTest(wrapped=wrapped):
                f = RecoverySustainabilityFixture(mode='simple')
                transaction = f.action_rows[0]['scheduled']['transactionHash']
                if wrapped:
                    f.transactions[transaction]['to'] = A(99901)
                else:
                    f.transactions[transaction] = None
                result = f.result(); row = next(row for row in result.report['recoveries']['records'] if row['status'] == 'executed')
                self.assertEqual(row['record'], json_values(f.recovery_rows[0]))
                self.assertEqual(row['requestSource'], 'executed_native_record')
                self.assertIsNone(row['callIndex'])
                self.assertFalse(row['originalCallPreimagesReconstructed'])
                self.assertEqual(row['status'], 'executed')
                self.assertFalse(result.report['recoveries']['listedExecutorRecoveryInputsComplete'])
                # An opaque scheduling transaction cannot excuse a corrupted
                # immutable original executed record or hide its current head.
                changed = list(f.recovery_rows[0]); changed[7] = H(98989)
                f.put(f.recovery, 'finalityRecoveryRecord(bytes32)', (w.citation.RECOVERY,), (changed,),
                    ('bytes32',), (changed[1],))
                with self.assertRaisesRegex(MuseumError, 'route/time preimage'): f.result()

    def test_missing_schedule_still_rejects_impossible_empty_saved_call_data(self):
        f = RecoverySustainabilityFixture(mode='simple'); action = f.action_rows[0]
        f.transactions[action['scheduled']['transactionHash']] = None
        transaction = next(log['transactionHash'] for log in f.logs
            if log['topics'][0] == w.EVENTS['executed'] and log['topics'][1] == action['id'])
        f.transactions[transaction] = None
        f.put(f.executor, 'scheduledCallData(bytes32)', (Array('bytes', 64),), ((),), ('bytes32',), (action['id'],))
        f.codes[action['carrier']] = b'\0' + encode((Array('bytes', 64),), ((),))
        f.graph['codePins'][action['carrier']] = keccak256(f.codes[action['carrier']])
        with self.assertRaisesRegex(MuseumError, 'scheduled calldata count'): f.result()

    def test_native_head_cannot_hide_original_execution(self):
        f = RecoverySustainabilityFixture()
        f.put(f.recovery, 'activeFinalityRecovery(' + w.citation.SCOPE_SIG + ')', w.citation.HEAD,
            (ZERO, ZERO, 0), (w.citation.SCOPE,), ((0, 1, 0, ZERO),))
        with self.assertRaisesRegex(MuseumError, 'current exact head/event history'): f.result()

    def test_export_latest_index_and_block_window_contradictions_reject(self):
        f = RecoverySustainabilityFixture()
        f.put(f.executor, 'latestStateExport()', w.EXPORT[:5], f.export_rows[0]['record'][:5])
        with self.assertRaisesRegex(MuseumError, 'latest indexed record'): f.result()
        f = RecoverySustainabilityFixture(); f.put(f.executor, 'stateExportCount()', ('uint256',), (1,))
        with self.assertRaisesRegex(MuseumError, 'count/event denominator'): f.result()

    def test_conflicting_repeated_getter_wrong_chain_and_unused_rows_reject(self):
        original = loads(RecoverySustainabilityFixture(mode='empty').envelope())
        changed = copy.deepcopy(original); row = next(r for r in changed['calls'] if r['method'] == 'eth_chainId')
        changed['calls'].append({**row, 'result': '0x1'})
        with self.assertRaisesRegex(MuseumError, 'conflicting repeated'): self.verify(changed)
        changed = copy.deepcopy(original); next(r for r in changed['calls'] if r['method'] == 'eth_chainId')['result'] = '0x1'
        with self.assertRaisesRegex(MuseumError, 'chain differs'): self.verify(changed)
        changed = copy.deepcopy(original); changed['calls'].append({'method': 'eth_getTransactionByHash', 'params': [H(99999)], 'result': None})
        with self.assertRaisesRegex(MuseumError, 'unused observations'): self.verify(changed)

    def test_receipt_log_omission_and_cross_chain_transaction_reject(self):
        f = RecoverySustainabilityFixture(); raw = loads(f.envelope(), maximum=w.MAX_BYTES)
        receipt = next(row for row in raw['calls'] if row['method'] == 'eth_getTransactionReceipt')
        receipt['result']['logs'] = []
        with self.assertRaises(MuseumError): self.verify(raw)
        f = RecoverySustainabilityFixture(); tx = next(iter(f.transactions.values())); tx['chainId'] = '0x1'
        with self.assertRaisesRegex(MuseumError, 'chain differs'): f.result()


if __name__ == '__main__': unittest.main()
