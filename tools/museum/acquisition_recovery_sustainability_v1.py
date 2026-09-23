"""Offline original recovery schedules and native state-export history.

The input is externally pinned native RPC observations, not an asserted report.
Every used read is replayed from those observations at the exact source block.
Counts close the supplied Executor histories; they do not enumerate every past
Executor/companion or OwnerRecords deployment. No current role is substituted
for original execution authority. Funding and museum-drill release artifacts
are a separate, explicitly qualified supplied-data boundary.
"""
from dataclasses import dataclass
from fractions import Fraction

from . import canonical_citation_source as citation
from . import governance_transaction_wire as governance
from . import native_finality_wire as finality
from . import public_chain_history as history
from . import public_scoped_finality_rpc as rpc
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import quantity
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .public_governance_transaction_source import transaction_observation

SOURCE_REVISION = 'ec832e8674965a30c571d55cc39efdbd0db9e727'
PROFILE = 'STREAM_MUSEUM_ACQUISITION_RECOVERY_SUSTAINABILITY_V1'
MAX_BYTES, MAX_ACTIONS, MAX_EXPORTS, MAX_HOSTS, MAX_MEMBERS = 64 * 1024 * 1024, 256, 256, 8, 16384
STATE_KEYS = 'chainId core collectionId tokenId blockHash blockNumber timestamp stateRoot environment deploymentEvidenceHash'.split()
EXPORT = ('uint256', 'bytes32', 'bytes32', 'bytes32', 'string', 'uint256')
BOOTSTRAP = ('bool', 'bool', 'address', 'bytes32', 'address', 'bytes32', 'uint64', 'bytes32',
    'uint256', 'bytes32', 'uint64', 'address', 'bytes32', 'address', 'bytes32', 'bytes32',
    'uint256', 'bytes32', 'uint256', 'bytes32', 'bytes32', 'uint256', 'bytes32', 'uint256',
    'address', 'address', 'bytes32', 'bytes32', 'uint256')
MEMBERSHIP = ('bytes32', 'bytes32', 'bytes32', 'uint256', 'bytes32', 'bytes32', 'uint256', 'bytes32')
REQUEST_SIG = '((uint8,uint256,uint256,bytes32),bytes32,bytes32,bytes32,(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32),(string,bytes32,bytes32,bytes32,bytes32),bytes32,string)'
EXECUTE_SIGNATURE = 'executeFinalityRecovery(' + REQUEST_SIG + ')'
EXECUTE_SELECTOR = calldata(EXECUTE_SIGNATURE, (), ())[:10]
EVENTS = {
    'scheduled': finality.EVENTS['governanceScheduled'],
    'executed': finality.EVENTS['governanceExecuted'],
    'cancelled': schema_id('GovernanceActionCancelled(uint16,bytes32,uint8,address,bytes4,bytes32,bytes32,address,bytes32,string)'),
    'vetoed': schema_id('GovernanceActionVetoed(uint16,bytes32,uint8,address,bytes32,bytes32)'),
    'expired': schema_id('GovernanceActionExpired(uint16,bytes32,uint8,address)'),
    'export': schema_id('StateExportPublished(uint16,uint256,bytes32,bytes32,bytes32,string)'),
    'challenge': schema_id('StateExportChallenged(uint16,bytes32,bytes32,address,string)'),
    'supersede': schema_id('StateExportSuperseded(uint16,bytes32,bytes32,bytes32,string)'),
    'recovery': schema_id('FinalityRecoveryExecuted(uint16,uint256,bytes32,bytes32,bytes32,bool,bytes32,string)'),
    'scopedRecovery': schema_id('ScopedFinalityRecoveryExecuted(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,bytes32,bool,bytes32,string)'),
    'lineage': schema_id('FinalityRecoveryLineageRecorded(uint16,bytes32,bytes32,bytes32,uint64,bytes32,bytes32)'),
    'evidence': schema_id('FinalityRecoveryEvidenceSnapshotted(uint16,bytes32,uint8,bytes32,address,bytes32,uint8,uint64,bytes32,uint64,uint64,uint32,uint32)'),
}
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1', 'sourceReviewCommit': SOURCE_REVISION,
    'historyProfileHash': history.PROFILE_HASH, 'bounds': {'inputBytes': MAX_BYTES,
        'actionsPerExecutor': MAX_ACTIONS, 'exportsPerExecutor': MAX_EXPORTS, 'hostsPerFamily': MAX_HOSTS,
        'scopeMembers': MAX_MEMBERS},
    'denominators': 'Every scheduling event nonce exactly covers [0,governanceNonce); every export index exactly covers stateExportCount. Filtered event completeness and canonical mappings remain provider-trusted. Supplied host lists are not a protocol-wide host inventory.',
    'recovery': 'Original direct canonical schedule inputs and immutable scheduled calldata identify requests. Original stored status, execution receipt, lineage, 704-byte intent, route preimage and same-transaction events remain distinct from live route eligibility. Missing or unsupported original wrappers remain partial; independently observed executed records survive without an inferred call index or per-call transition preimage. Original finality/sanction record hashes remain commitments, not a replay of those separate source families. Optional original public OwnerCatalog triplets are replayed in full; every RECOVERY_RESPONSE occurrence is retained, supported original schema/profile/payloads join the exact scheduled action ID and manifest content hash. Owner responses are authored statements, never vetoes or current ownership proof. Supplied hosts do not close the global response inventory.',
    'export': 'Complete publisher-local indexed history, publication/challenge/supersession originals and latest getter. Age uses the exported state block timestamp; publication timestamp is retained separately. Bytes inside an export are not reconstructed from its commitment.',
    'releaseArtifacts': 'Optional closed release-evidence input is a prospective consumer format based on LTA-FUNDING and packet18. External release selection/hash links are checked, not authenticated. Exact original artifacts retained; commitments, costs and a genuine zero-signer drill are not independently authenticated.',
    'claims': {'nativeCountsChecked': True, 'originalBytesRetained': True, 'globalHostInventoryProven': False,
        'sourceProvenanceAuthenticated': False, 'historicalAuthorityReexecuted': False,
        'financialCommitmentsAuthenticated': False, 'museumDrillReexecuted': False,
        'fullCanonicalPacket': False, 'consensusVerified': False}})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Result:
    files: dict
    report: dict
    observations: list


class MissingObservation(MuseumError):
    """A required read is absent; parameters support offline capture preparation."""
    def __init__(self, method, params):
        super().__init__('recovery/export missing original observation')
        self.method, self.params = method, params


def _shape(value, keys, label):
    require(type(value) is dict and set(value) == set(keys.split()), label + ' shape')


def _nonzero(value, size=32):
    require(any(hex_bytes(value, size)), 'recovery/export zero identity')


def _topic(kind, value): return '0x' + encode((kind,), (value,)).hex()
def _pos(log): return history._position(log)
def _event(host, name, topics, types, values):
    return host, (EVENTS[name], *topics), '0x' + encode(types, values).hex()


class Observations:
    """Strict bounded observation map; no network or hidden fallback."""
    def __init__(self, anchor, graph, rows):
        self.a, self.graph = anchor, graph
        self.block = {'blockHash': anchor['blockHash'], 'requireCanonical': True}
        require(type(rows) is list and len(rows) <= 100000, 'recovery/export observation bound')
        self.rows, self.answers, self.used, self.getters = rows, {}, set(), []
        for row in rows:
            rpc._row(row)
            key = dumps([row['method'], row['params']])
            outcome = {key: row[key] for key in ('result', 'limit') if key in row}
            require(self.answers.setdefault(key, outcome) == outcome, 'recovery/export conflicting repeated observation')
            require(len(dumps(outcome)) <= 1048576, 'recovery/export response bound')
            if row['method'] in ('eth_call', 'eth_getCode'):
                require(row['params'][1] == self.block, 'recovery/export mixed source block')

    def request(self, method, params):
        key = dumps([method, params])
        if key not in self.answers: raise MissingObservation(method, params)
        self.used.add(key)
        answer = self.answers[key]
        if 'limit' in answer:
            from .public_history_rpc import PublicLimitError
            raise PublicLimitError(answer['limit'])
        return answer['result']

    def read(self, target, signature, outputs, inputs=(), values=(), maximum=65536):
        require(target in self.graph['codePins'], 'recovery/export unpinned getter target')
        data = calldata(signature, inputs, values)
        raw = self.request('eth_call', [{'to': target, 'data': data, 'gas': '0x1312d00'}, self.block])
        self.getters.append({'target': target, 'calldata': data, 'result': raw})
        return decode(outputs, hex_bytes(raw), maximum=maximum)

    def one(self, target, signature, output, inputs=(), values=(), maximum=65536):
        return self.read(target, signature, (output,), inputs, values, maximum)[0]

    def code(self, target):
        require(target in self.graph['codePins'], 'recovery/export unpinned runtime')
        raw = hex_bytes(self.request('eth_getCode', [target, self.block]))
        require(0 < len(raw) <= 24576 and keccak256(raw) == self.graph['codePins'][target], 'recovery/export runtime differs')
        return raw

    def block_header(self, number, digest):
        by_hash = self.request('eth_getBlockByHash', [digest, False])
        require(by_hash == self.request('eth_getBlockByNumber', [hex(number), False])
            and by_hash['hash'] == digest and quantity(by_hash['number']) == number,
            'recovery/export original block mapping differs')
        require(number <= uint(self.a['blockNumber']) and quantity(by_hash['timestamp']) <= uint(self.a['timestamp']),
            'recovery/export future original block')
        return by_hash

    def stamp(self, log):
        return quantity(self.block_header(quantity(log['blockNumber']), log['blockHash'])['timestamp'])

    def transaction(self, log):
        receipt = self.request('eth_getTransactionReceipt', [log['transactionHash']])
        value = self.request('eth_getTransactionByHash', [log['transactionHash']])
        return transaction_observation(value, receipt, log, self.a)['normalized']


def _matches(logs, host, name, digest=None):
    return [log for log in logs if log['address'] == host and log['topics'][0] == EVENTS[name]
        and (digest is None or (len(log['topics']) > 1 and log['topics'][1] == digest))]


def _exact(logs, descriptor, label):
    rows = [log for log in logs if finality.event_matches(descriptor, log)]
    require(len(rows) == 1, label + ' original event missing/duplicate')
    return rows[0]


def _scope(value):
    s = value; require(s[0] in range(5) and s[1] > 0, 'recovery scope enum/collection')
    require((s[0] == 0 and s[2] == 0 and s[3] == ZERO)
        or (s[0] == 1 and s[2] > 0 and s[3] == ZERO)
        or (s[0] in (2, 3, 4) and s[2] == 0 and s[3] != ZERO), 'recovery scope shape')


def _applicability(o, host, scope):
    a = o.a; _scope(scope)
    if scope[1] != uint(a['collectionId']): return {'status': 'other_collection', 'applies': False}
    if scope[0] < 2:
        return {'status': 'collection' if scope[0] == 0 else 'token',
            'applies': scope[0] == 0 or scope[2] == uint(a['tokenId'])}
    original = o.one(host, 'originalFinalityRegistry()', 'address')
    require(o.one(original, 'coreReads()', 'address') == a['core'], 'recovery original Core binding')
    provider = o.one(original, 'scopeEvidenceProvider()', 'address')
    require(o.one(original, 'scopeEvidenceProviderCodeHash()', 'bytes32') == o.graph['codePins'][provider], 'recovery scope provider pin')
    require(o.one(provider, 'core()', 'address') == a['core']
        and o.one(provider, 'coreCodeHash()', 'bytes32') == o.graph['codePins'][a['core']], 'recovery scope provider Core')
    membership = o.one(provider, 'scopeMembershipHost()', 'address')
    require(o.one(provider, 'scopeMembershipHostCodeHash()', 'bytes32') == o.graph['codePins'][membership], 'recovery membership runtime')
    metadata = o.one(provider, 'metadataHost()', 'address')
    require(o.one(provider, 'metadataHostCodeHash()', 'bytes32') == o.graph['codePins'][metadata]
        and o.one(original, 'metadataReads()', 'address') == metadata, 'recovery membership Metadata binding')
    require(o.one(membership, 'core()', 'address') == a['core']
        and o.one(membership, 'metadataHost()', 'address') == metadata, 'recovery membership native binding')
    inventory = o.one(membership, 'tokenInventory()', 'address')
    require(inventory in o.graph['codePins'], 'recovery membership inventory pin')
    facts = o.one(membership, 'requireScopeMembership(' + citation.SCOPE_SIG + ')', MEMBERSHIP, (citation.SCOPE,), (scope,))
    require(0 < facts[3] <= MAX_MEMBERS and facts[6:] == (0, ZERO), 'recovery complete scoped membership bound')
    tokens = [o.one(membership, 'scopeTokenAt(' + citation.SCOPE_SIG + ',uint256)', 'uint256',
        (citation.SCOPE, 'uint256'), (scope, i)) for i in range(facts[3])]
    require(tokens == sorted(set(tokens)) and tokens[0] > 0
        and keccak256(b''.join(encode(('uint256',), (token,)) for token in tokens)) == facts[4], 'recovery membership ordered token hash')
    expected_subject = subject_id('scope', a['chainId'], a['core'], str(scope[1]), scope_type=str(scope[0]), scope_id=scope[3])
    require(facts[0] == expected_subject and facts[1] != ZERO and facts[2] != ZERO, 'recovery membership subject/original')
    require(scope[3] == keccak256(encode(('bytes32', 'uint256', 'address', 'uint256', 'uint8', 'bytes32'),
        (schema_id('6529STREAM_SCOPE_MEMBERSHIP_ID_V1'), uint(a['chainId']), a['core'], scope[1], scope[0], facts[2]))), 'recovery membership scope ID')
    from .scoped_static_snapshot_wire import membership_hash
    require(facts[5] == membership_hash(facts, scope, a,
        {'metadata': {'address': metadata, 'runtimeHash': o.graph['codePins'][metadata]},
         'tokenInventory': {'address': inventory, 'runtimeHash': o.graph['codePins'][inventory]}}), 'recovery membership facts hash')
    return {'status': 'sealed_native_membership', 'applies': uint(a['tokenId']) in tokens,
        'host': membership, 'facts': json_values(facts), 'tokens': json_values(tokens)}


def _action(o, executor, scheduled, logs):
    data = decode(finality.GOVERNANCE_SCHEDULED_DATA, hex_bytes(scheduled['data']))
    require(len(scheduled['topics']) == 4 and data[0] == 1, 'recovery scheduling event shape')
    digest, nonce = scheduled['topics'][1], data[9]
    action = o.one(executor, 'governanceAction(bytes32)', finality.GOVERNANCE_ACTION, ('bytes32',), (digest,))
    require(action[0] in range(1, 6) and action[1] <= 5 and action[9] < action[10], 'recovery governance stored status/window')
    expected = _event(executor, 'scheduled', (digest, _topic('uint8', action[1]), _topic('address', action[2])),
        finality.GOVERNANCE_SCHEDULED_DATA, (1, *action[3:11], nonce, action[11], *action[15:]))
    require(finality.event_matches(expected, scheduled), 'recovery scheduling event/stored action differs')
    datas = o.one(executor, 'scheduledCallData(bytes32)', Array('bytes', governance.MAX_CALLS), ('bytes32',), (digest,))
    require(0 < len(datas) <= governance.MAX_CALLS, 'recovery original scheduled calldata count')
    pointer = o.one(executor, 'scheduledCallDataPointer(bytes32)', 'address', ('bytes32',), (digest,))
    code = o.code(pointer)
    require(code == b'\x00' + encode((Array('bytes', governance.MAX_CALLS),), (datas,)), 'recovery scheduled calldata carrier')
    schedule_tx = o.transaction(scheduled)
    decoded, gap = governance._transaction(schedule_tx, executor, 'schedule')
    calls = None
    if decoded is not None:
        calls = decoded['calls']; governance._pair(calls, datas, action[1])
        require(schedule_tx['from'] == action[11] and uint(schedule_tx['value']) == 0
            and decoded['context'] == (action[1], *action[6:11], *action[15:]), 'recovery original scheduling transaction differs')
        if decoded['callDatas'] is not None: require(decoded['callDatas'] == datas, 'recovery schedule calldata differs')
        aggregates = governance.transition_hashes(calls); digest_calls = governance.calls_hash(calls)
        require(action[2:9] == (calls[0][0], sum(c[1] for c in calls), calls[0][2], digest_calls, *aggregates), 'recovery action calls/aggregates')
        identity = (action[1], digest_calls, *aggregates, nonce, action[9], action[10], action[15], action[17])
        require(governance.action_id(o.a['chainId'], executor, identity) == digest, 'recovery original action ID')
    terminal = []
    for name in ('executed', 'cancelled', 'vetoed', 'expired'):
        terminal.extend((name, log) for log in _matches(logs, executor, name, digest))
    require(len(terminal) <= 1, 'recovery multiple terminal action events')
    status = ('none', 'scheduled', 'cancelled', 'executed', 'expired', 'vetoed')[action[0]]
    expected_terminal = {2: 'cancelled', 3: 'executed', 5: 'vetoed'}.get(action[0])
    require((expected_terminal is None or (len(terminal) == 1 and terminal[0][0] == expected_terminal))
        and (action[0] != 1 or not terminal) and (action[0] != 4 or not terminal or terminal[0][0] == 'expired'), 'recovery native status/event differs')
    if action[0] in (1, 4):
        require(action[12:15] == (ZERO_ADDRESS,) * 3 and (action[0] == 4) == (uint(o.a['timestamp']) > action[10]), 'recovery virtual expiration/actors')
    execution = None
    if terminal:
        name, log = terminal[0]
        require(_pos(scheduled) < _pos(log), 'recovery terminal event precedes schedule')
        if name == 'executed':
            require(action[12] != ZERO_ADDRESS and action[13:15] == (ZERO_ADDRESS, ZERO_ADDRESS)
                and action[9] <= o.stamp(log) <= action[10], 'recovery execution actor/window')
            _exact([log], _event(executor, name, expected[1][1:], finality.GOVERNANCE_EXECUTED_DATA,
                (1, *action[3:9], action[12], action[17])), 'recovery execution')
            execution = log
            transaction = o.transaction(log); executed, execution_gap = governance._transaction(transaction, executor, 'execution')
            if executed is not None:
                require(transaction['from'] == action[12] and uint(transaction['value']) == action[3]
                    and executed['actionId'] == digest and executed['callDatas'] == datas, 'recovery original execution transaction')
                if calls is not None: require(executed['calls'] == calls or (executed['calls'] is None and len(calls) == 1), 'recovery execution ordered calls')
            if execution_gap: gap = execution_gap if gap is None else gap + ';' + execution_gap
        elif name == 'cancelled':
            tail = decode(('uint16', 'bytes4', 'bytes32', 'bytes32', 'address', 'bytes32', 'string'), hex_bytes(log['data']))
            require(log['topics'][2:] == list(expected[1][2:]) and tail[:5] == (1, action[4], action[5], action[6], action[13])
                and action[13] != ZERO_ADDRESS and action[12] == action[14] == ZERO_ADDRESS and tail[6] == ''
                and o.stamp(log) <= action[10], 'recovery cancellation fields')
        elif name == 'vetoed':
            tail = decode(('uint16', 'bytes32', 'bytes32'), hex_bytes(log['data']))
            require(log['topics'][2:] == [_topic('uint8', action[1]), _topic('address', action[14])]
                and tail[:2] == (1, action[6]) and action[1] == 2 and action[14] != ZERO_ADDRESS
                and action[12:14] == (ZERO_ADDRESS, ZERO_ADDRESS), 'recovery veto fields')
        else:
            tail = decode(('uint16', 'address'), hex_bytes(log['data']))
            require(log['topics'][2:] == [_topic('uint8', action[1])] and tail[0] == 1 and tail[1] != ZERO_ADDRESS
                and o.stamp(log) > action[10], 'recovery expiration fields')
    return {'actionId': digest, 'nonce': str(nonce), 'status': status, 'storedAction': json_values(action),
        'scheduled': scheduled, 'terminal': None if not terminal else terminal[0][1],
        'transactionInputGap': gap, 'calls': None if calls is None else json_values(calls),
        'callDatas': json_values(datas)}, calls, datas, execution


def _recovery(o, host, executor, action, call_index, call, raw, execution, logs):
    record = o.one(host, 'finalityRecoveryRecord(bytes32)', citation.RECOVERY, ('bytes32',), (action['actionId'],))
    if call is None:
        require(raw is None and call_index is None and execution is not None and record[0],
            'recovery missing call requires actual original execution')
        request = (record[2], record[3], record[4], record[6], record[9], record[10], record[12], record[13])
    else:
        require(len(raw) <= 24575 and raw[:4] == hex_bytes(EXECUTE_SELECTOR, 4), 'recovery original request byte bound')
        request, = decode((citation.RECOVERY_REQUEST,), raw[4:], maximum=24575)
    _scope(request[0]); manifest = request[5]
    require(request[1] != ZERO and request[3] != ZERO and request[6] != ZERO
        and manifest[0] and manifest[1] == keccak256(manifest[0].encode())
        and all(h != ZERO for h in manifest[2:]), 'recovery request identity/manifest')
    require(o.one(host, 'core()', 'address') == o.a['core']
        and o.one(host, 'governanceAuthority()', 'address') == executor
        and o.one(host, 'streamModuleType()', 'bytes32') == schema_id('STREAM_ARTWORK_FINALITY_RECOVERY'), 'recovery native deployment binding')
    _nonzero(o.one(host, 'configurationHash()', 'bytes32'))
    shape_record = (False, action['actionId'], request[0], request[1], request[2], 0, request[3], ZERO,
        False, request[4], request[5], (0, ZERO, ZERO_ADDRESS, ZERO, 0, 0, ZERO, 0, 0, 0, 0), request[6], request[7], 0)
    intent = citation.recovery_intent(uint(o.a['chainId']), host, shape_record)
    require(len(intent) == 704 and keccak256(intent) == manifest[2], 'recovery original intent content hash')
    if call is not None:
        require(call[1] == 0 and call[4] == keccak256(encode(('bytes32', 'uint256', 'address', citation.SCOPE),
            (schema_id('6529STREAM_FINALITY_RECOVERY_SCOPE_V1'), uint(o.a['chainId']), host, request[0]))), 'recovery original scope transition/value')
    result = {'host': host, 'executor': executor, 'actionId': action['actionId'], 'callIndex': None if call_index is None else str(call_index),
        'requestSource': 'executed_native_record' if call is None else 'original_scheduled_calldata',
        'originalCallPreimagesReconstructed': call is not None,
        'scope': json_values(request[0]), 'request': json_values(request), 'intentBytes': '0x' + intent.hex(),
        'manifestHash': manifest[2], 'status': action['status'], 'artworkBytesChanged': None,
        'applicability': _applicability(o, host, request[0]), 'originalExecution': None,
        'record': None, 'ownerResponses': {'status': 'owner_catalogue_not_supplied'}}
    if execution is None:
        require(not record[0], 'recovery unexecuted action has executed record')
        return result
    require(uint(action['storedAction'][1]) == 2, 'recovery execution requires native terminal-freeze action class')
    require(record[0] and record[1] == action['actionId'] and record[2:5] == request[:3]
        and record[6] == request[3] and record[9:11] == request[4:6] and record[12:14] == request[6:8]
        and record[5] > 0 and record[8] and record[11][0] in (1, 2), 'recovery exact original executed record')
    require(record[14] == o.stamp(execution) and record[7] == citation.recovered_hash(uint(o.a['chainId']), host, record), 'recovery route/time preimage')
    e = record[11]
    require(e[1] != ZERO and e[3] != ZERO and e[6] != ZERO and e[7] > 0 and 0 < e[8] <= record[14],
        'recovery original evidence identity/owner deadline')
    require((e[0] == 1 and e[2] != ZERO_ADDRESS and e[4] in (1, 3) and e[5] == 0)
        or (e[0] == 2 and e[2] == ZERO_ADDRESS and e[4] == 0 and 0 < e[5] <= record[14]),
        'recovery original approval/unavailability evidence')
    saved = o.one(host, 'finalityRecoveryManifestBytes(bytes32)', 'bytes', ('bytes32',), (manifest[2],), maximum=1024)
    require(saved == intent, 'recovery retained original intent bytes')
    lineage = _exact(logs, _event(host, 'lineage', (record[1], record[4], record[3]),
        ('uint16', 'uint64', 'bytes32', 'bytes32'), (1, record[5], record[6], record[7])), 'recovery lineage')
    evidence = _exact(logs, _event(host, 'evidence', (record[1],), ('uint16', *citation.EVIDENCE), (1, *record[11])), 'recovery evidence')
    if record[2][0] == 0:
        original = _exact(logs, _event(host, 'recovery', (_topic('uint256', record[2][1]), record[1]),
            ('uint16', 'bytes32', 'bytes32', 'bool', 'bytes32', 'string'),
            (1, manifest[2], record[7], True, record[12], record[13])), 'recovery executed')
    else:
        original = _exact(logs, _event(host, 'scopedRecovery', (_topic('uint8', record[2][0]), _topic('uint256', record[2][1]), record[1]),
            ('uint16', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'bool', 'bytes32', 'string'),
            (1, record[2][2], record[2][3], manifest[2], record[7], True, record[12], record[13])), 'recovery scoped executed')
    require(all(log['transactionHash'] == execution['transactionHash'] for log in (lineage, evidence, original))
        and quantity(evidence['logIndex']) == quantity(lineage['logIndex']) + 1
        and quantity(original['logIndex']) == quantity(evidence['logIndex']) + 1 and _pos(original) < _pos(execution), 'recovery native execution event order')
    old_generation = record[5] - 1
    old_hash = keccak256(encode(('bytes32', 'bytes32', 'bytes32', 'bytes32', 'uint64', 'bytes32'),
        (schema_id('6529STREAM_FINALITY_RECOVERY_OLD_STATE_V1'), keccak256(encode(citation.SCOPE, request[0])),
         request[1], request[2], old_generation, request[3])))
    new_hash = keccak256(encode(('bytes32', 'uint256', 'address', 'uint64', citation.RECOVERY_REQUEST),
        (schema_id('6529STREAM_FINALITY_RECOVERY_NEW_STATE_V1'), uint(o.a['chainId']), host, record[5], request)))
    if call is not None:
        require(call[5:7] == (old_hash, new_hash), 'recovery original per-call transition preimages')
    result.update(record=json_values(record), artworkBytesChanged=True, originalExecution=original)
    return result


def _exports(o, host, logs):
    count = o.one(host, 'stateExportCount()', 'uint256'); require(count <= MAX_EXPORTS, 'state export count bound')
    published = _matches(logs, host, 'export'); require(len(published) == count, 'state export count/event denominator')
    rows, hashes = [], set()
    for index in range(count):
        digest = o.one(host, 'stateExportHashAt(uint256)', 'bytes32', ('uint256',), (index,))
        _nonzero(digest); require(digest not in hashes, 'state export repeated index'); hashes.add(digest)
        record, superseded = o.read(host, 'stateExport(bytes32)', (EXPORT, 'bytes32'), ('bytes32',), (digest,))
        require(record[2] == digest and record[5] == index + 1 and record[0] > 0
            and record[1] != ZERO and record[3] != ZERO and 0 < len(record[4].encode()) <= 2048, 'state export native record')
        log = _exact(published, _event(host, 'export', (_topic('uint256', record[0]), digest, record[3]),
            ('uint16', 'bytes32', 'string'), (1, record[1], record[4])), 'state export publication')
        require(0 < quantity(log['blockNumber']) - record[0] <= 256, 'state export original blockhash window')
        header = o.block_header(record[0], record[1]); stamp = quantity(header['timestamp'])
        require(stamp <= o.stamp(log), 'state export anchor after publication')
        if rows:
            previous = rows[-1]
            require(record[0] >= uint(previous['record'][0]) and (str(record[0]), record[1]) != tuple(previous['record'][:2])
                and _pos(previous['publication']) < _pos(log), 'state export append order')
        rows.append({'record': json_values(record), 'supersededBy': superseded, 'publication': log,
            'exportedStateTimestamp': str(stamp), 'publicationTimestamp': str(o.stamp(log)),
            'ageSeconds': str(uint(o.a['timestamp']) - stamp), 'challenges': [], 'supersession': None})
    by_hash = {r['record'][2]: r for r in rows}
    for log in _matches(logs, host, 'challenge'):
        require(len(log['topics']) == 4 and log['topics'][1] in by_hash, 'state export challenge target')
        digest, challenge = log['topics'][1:3]; _nonzero(challenge)
        actor, = decode(('address',), hex_bytes(log['topics'][3], 32)); _nonzero(actor, 20)
        version, uri = decode(('uint16', 'string'), hex_bytes(log['data']))
        require(version == 1 and 0 < len(uri.encode()) <= 2048 and _pos(by_hash[digest]['publication']) < _pos(log), 'state export challenge original')
        require(o.one(host, 'stateExportChallengeExists(bytes32,bytes32)', 'bool', ('bytes32', 'bytes32'), (digest, challenge)), 'state export challenge getter')
        require(challenge not in [r['challengeHash'] for r in by_hash[digest]['challenges']], 'state export duplicate challenge')
        by_hash[digest]['challenges'].append({'challengeHash': challenge, 'challenger': actor, 'uri': uri, 'publication': log})
    for log in _matches(logs, host, 'supersede'):
        require(len(log['topics']) == 4, 'state export supersession topics')
        old, new, reason = log['topics'][1:]; _nonzero(reason)
        version, uri = decode(('uint16', 'string'), hex_bytes(log['data']))
        require(old in by_hash and new in by_hash and version == 1 and 0 < len(uri.encode()) <= 2048
            and uint(by_hash[old]['record'][5]) < uint(by_hash[new]['record'][5])
            and by_hash[old]['supersededBy'] == new and by_hash[old]['supersession'] is None
            and _pos(by_hash[new]['publication']) < _pos(log), 'state export supersession original')
        by_hash[old]['supersession'] = {'reasonHash': reason, 'reasonURI': uri, 'publication': log}
    require(all((r['supersededBy'] == ZERO) == (r['supersession'] is None) for r in rows), 'state export supersession getter/event denominator')
    latest = o.read(host, 'latestStateExport()', EXPORT[:5])
    require(latest == (tuple(finality.from_json(EXPORT, rows[-1]['record']))[:5] if rows else (0, ZERO, ZERO, ZERO, '')), 'state export latest indexed record differs')
    return {'host': host, 'count': str(count), 'records': rows, 'latest': rows[-1] if rows else None}


def _release(value, documents):
    """Typed release commitments; evidence authenticity is deliberately separate."""
    if value is None: return {'status': 'current_release_evidence_not_supplied', 'funding': None, 'museumDrill': None}
    _shape(value, 'releaseManifestHash fundingManifestHash museumDrillHash releaseSelection', 'release evidence')
    for key in ('releaseManifestHash', 'fundingManifestHash', 'museumDrillHash'):
        _nonzero(value[key]); require(value[key] in documents, 'release original artifact missing')
    release = loads(documents[value['releaseManifestHash']], canonical=True)
    _shape(release, 'profile releaseId environment fundingManifestHash museumDrillHash', 'release manifest evidence')
    require(release['profile'] == 'STREAM_MUSEUM_RELEASE_EVIDENCE_V1'
        and release['environment'] in ('testnet', 'mainnet', 'synthetic_fixture')
        and type(release['releaseId']) is str and 0 < len(release['releaseId']) <= 256
        and release['fundingManifestHash'] == value['fundingManifestHash']
        and release['museumDrillHash'] == value['museumDrillHash'], 'release exact artifact commitments')
    # A supplied selection identifies the claimed release, never proves it current.
    _shape(value['releaseSelection'], 'releaseId sourceCommit evidenceHash', 'release selection')
    require(value['releaseSelection']['releaseId'] == release['releaseId']
        and len(value['releaseSelection']['sourceCommit']) == 40, 'release selection identity')
    int(value['releaseSelection']['sourceCommit'], 16); _nonzero(value['releaseSelection']['evidenceHash'])
    require(value['releaseSelection']['evidenceHash'] in documents, 'release selection original evidence missing')
    funding = loads(documents[value['fundingManifestHash']], canonical=True)
    _shape(funding, 'profile currency unitScale secondsPerYear committedSources annualObligations viabilityFloorSeconds', 'funding evidence')
    require(funding['profile'] == 'STREAM_MUSEUM_FUNDING_EVIDENCE_V1' and type(funding['currency']) is str
        and 0 < len(funding['currency']) <= 32, 'funding evidence profile/unit')
    scale, year = uint(funding['unitScale']), uint(funding['secondsPerYear'])
    require(scale > 0 and 0 < year <= 366 * 86400, 'funding unit/year')
    totals = []
    for name, amount_key in (('committedSources', 'amountUnits'), ('annualObligations', 'annualCostUnits')):
        rows = funding[name]; require(type(rows) is list and 0 < len(rows) <= 128, 'funding source/obligation bound')
        seen, total = set(), 0
        for row in rows:
            _shape(row, 'id ' + amount_key + ' evidenceHash', 'funding original row')
            require(type(row['id']) is str and 0 < len(row['id']) <= 256 and row['id'] not in seen, 'funding row identity')
            seen.add(row['id']); total += uint(row[amount_key]); _nonzero(row['evidenceHash'])
            require(row['evidenceHash'] in documents, 'funding original commitment/cost evidence missing')
        totals.append(total)
    require(totals[1] > 0, 'funding annual obligations must be positive')
    horizon = int(Fraction(totals[0] * year, totals[1])); floor = uint(funding['viabilityFloorSeconds'], 64)
    require(floor > 0 and horizon < 1 << 64, 'funding horizon/floor bound')
    drill = loads(documents[value['museumDrillHash']], canonical=True)
    _shape(drill, 'profile releaseId performedAt signerCount reportHash', 'museum drill evidence')
    require(drill['profile'] == 'STREAM_MUSEUM_ZERO_SIGNER_DRILL_EVIDENCE_V1'
        and drill['releaseId'] == release['releaseId'] and uint(drill['performedAt'], 64) > 0
        and uint(drill['signerCount']) == 0 and drill['reportHash'] in documents, 'museum drill original report identity')
    return {'status': 'supplied_release_artifact_links_checked', 'release': value,
        'environment': release['environment'], 'releaseSelectionAuthenticated': False,
        'funding': {'manifestHash': value['fundingManifestHash'], 'coverageHorizonSeconds': str(horizon),
            'viabilityFloorSeconds': str(floor), 'horizonStatus': 'meets_floor' if horizon >= floor else 'below_floor',
            'committedAmountUnits': str(totals[0]), 'aggregateAnnualCostUnits': str(totals[1]),
            'financialCommitmentsAuthenticated': False},
        'museumDrill': {'manifestHash': value['museumDrillHash'], **drill, 'executionIndependentlyVerified': False}}


def validate(raw, expected_hash):
    """Verify exact retained input bytes and return independently computed rows."""
    try: return _validate(raw, expected_hash)
    except MuseumError: raise
    except (ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed recovery/sustainability evidence') from exc


def _owner_responses(values, anchor, provenance, recoveries):
    """Replay whole original catalogues before interpreting any response payload."""
    from ..metadata import owner_notice_profile as notice
    from . import acquisition_accession as accession
    from .dossier_gather_records import JCS_HASH, JCS_ID
    require(type(values) is list and len(values) <= MAX_HOSTS, 'recovery owner source bound')
    files, observations, hosts, responses = {}, [], set(), []
    schema_raw, profile_raw = dumps(notice.schema(notice.RESPONSE)), dumps(notice.profile(notice.RESPONSE))
    for supplied in values:
        _shape(supplied, 'files pins', 'recovery owner source')
        require(type(supplied['files']) is dict and set(supplied['files']) == accession.INPUTS,
            'recovery owner original source triplet')
        original = {name: hex_bytes(encoded) for name, encoded in supplied['files'].items()}
        source, snapshot = accession._capture('owner', original, supplied['pins'])
        a, host = source.a, source.a['host']
        require(host not in hosts and all(a[key] == anchor[key] for key in STATE_KEYS if key in a),
            'recovery owner duplicate host/source state differs')
        require((source.provenance == 'synthetic_fixture') == (provenance == 'synthetic_fixture'),
            'recovery owner provenance differs')
        hosts.add(host); prefix = 'owner-sources/' + host[2:] + '/'
        files.update({prefix + name: payload for name, payload in original.items()})
        files[prefix + 'pins.json'] = dumps(supplied['pins'])
        observations.append({'kind': 'rpc', 'name': 'recovery-owner-' + host, 'anchor': a,
            'transcript': loads(original['transcript.json'], maximum=MAX_BYTES, canonical=True),
            'runtimePins': source.pins, 'provenance': source.provenance})
        for row in snapshot['records']:
            r, receipt = row['record'], row['receipt']
            if r[0] != schema_id('RECOVERY_RESPONSE'): continue
            item = {'host': host, 'recordHash': row['recordHash'], 'record': r, 'receipt': receipt,
                'publication': row['publication'], 'authority': row['authority'], 'matches': [],
                'status': 'unsupported_original_schema', 'statementTruthEstablished': False,
                'currentOwnerProven': False, 'responseIsVeto': False}
            if r[2] == schema_id(notice.RESPONSE) and receipt[9] == keccak256(schema_raw):
                item['status'] = 'unsupported_original_canonicalization_or_payload'
                if r[3][2] == JCS_ID and receipt[10] == JCS_HASH and row['payloadCorrespondence'] in (
                        'embedded_keccak256_verified', 'embedded_sha256_verified'):
                    try:
                        payload = notice.validate(hex_bytes(r[5]), notice.RESPONSE)
                        require(payload['profileHash'] == keccak256(profile_raw)
                            and payload['subjectId'] == r[1] == snapshot['subjectId'],
                            'recovery response original profile/subject differs')
                    except (ValueError, MuseumError):
                        item['status'] = 'invalid_supported_payload'
                    else:
                        item.update(status='typed_historical', payload=payload)
                        for recovery in recoveries:
                            if recovery['actionId'] != payload['recoveryId'] or recovery['manifestHash'] != payload['recoveryManifestHash']:
                                continue
                            executed = recovery['originalExecution']
                            before = None if executed is None else tuple(uint(row['publication'][k]) for k in (
                                'blockNumber', 'transactionIndex', 'logIndex')) < _pos(executed)
                            item['matches'].append({'host': recovery['host'], 'executor': recovery['executor'],
                                'actionId': recovery['actionId'], 'callIndex': recovery['callIndex'],
                                'beforeExecution': before})
            responses.append(item)
    if values:
        files['definitions/recovery-response-schema.json'] = schema_raw
        files['definitions/recovery-response-profile.json'] = profile_raw
    for recovery in recoveries:
        matched = [{'host': row['host'], 'recordHash': row['recordHash']} for row in responses
            if any(match['host'] == recovery['host'] and match['actionId'] == recovery['actionId']
                and match['callIndex'] == recovery['callIndex'] for match in row['matches'])]
        recovery['ownerResponses'] = {'status': 'supplied_host_catalogues_checked' if values else 'owner_catalogue_not_supplied',
            'records': matched, 'globalHostCompleteness': False}
    return {'hosts': sorted(hosts), 'records': responses, 'suppliedHostLanesComplete': bool(values),
        'globalHostCompleteness': False}, files, observations


def _validate(raw, expected_hash):
    require(type(raw) is bytes and keccak256(raw) == expected_hash, 'recovery/export external evidence hash')
    value = loads(raw, maximum=MAX_BYTES, canonical=True)
    _shape(value, 'profile anchor graph provenance calls documents releaseEvidence ownerSources', 'recovery/export envelope')
    require(value['profile'] == PROFILE and value['provenance'] in ('synthetic_fixture', 'externally_admitted_rpc'), 'recovery/export profile/provenance')
    a, g = value['anchor'], value['graph']; _shape(a, ' '.join(STATE_KEYS), 'recovery/export anchor')
    for key in ('chainId', 'collectionId', 'tokenId'): require(uint(a[key]) > 0, 'recovery/export positive token identity')
    uint(a['blockNumber'], 64); uint(a['timestamp'], 64); _nonzero(a['core'], 20)
    for key in ('blockHash', 'stateRoot', 'deploymentEvidenceHash'): _nonzero(a[key])
    require(a['environment'] in ('local_evm_fixture', 'public_chain'), 'recovery/export environment')
    _shape(g, 'executors recoveryHosts stateExportPublisher codePins', 'recovery/export graph')
    require(type(g['codePins']) is dict and len(g['codePins']) <= 1024, 'recovery/export pin bound')
    for address, digest in g['codePins'].items(): _nonzero(address, 20); _nonzero(digest)
    for key in ('executors', 'recoveryHosts'):
        require(type(g[key]) is list and len(g[key]) <= MAX_HOSTS and len(set(g[key])) == len(g[key]), 'recovery/export host bound/duplicate')
        for host in g[key]: require(host in g['codePins'], 'recovery/export missing host runtime pin')
    require(g['executors'] and g['stateExportPublisher'] in g['executors'] and a['core'] in g['codePins'], 'recovery/export required bound hosts')
    o = Observations(a, g, value['calls'])
    filters = [{'address': host, 'topics': [[EVENTS[k] for k in ('scheduled', 'executed', 'cancelled', 'vetoed', 'expired', 'export', 'challenge', 'supersede')]]} for host in g['executors']]
    filters += [{'address': host, 'topics': [[EVENTS[k] for k in ('recovery', 'scopedRecovery', 'lineage', 'evidence')]]} for host in g['recoveryHosts']]
    observed = history.scan_public_history(o, a, filters=filters); logs = observed['logs']
    for address in g['codePins']: o.code(address)
    identity = o.read(a['core'], 'tokenCollectionIdentity(uint256)', ('bool', 'uint256', 'uint256', 'bool'), ('uint256',), (uint(a['tokenId']),))
    lifecycle = o.one(a['core'], 'tokenLifecycle(uint256)', 'uint8', ('uint256',), (uint(a['tokenId']),))
    require(identity[0] and identity[1] == uint(a['collectionId']) and identity[2] > 0
        and lifecycle in (2, 3) and identity[3] == (lifecycle == 3), 'recovery/export actual token identity')
    pointer = o.one(a['core'], 'getSatellitePointer(bytes32)', citation.POINTER, ('bytes32',), (schema_id('STATE_EXPORT_PUBLISHER'),))
    require(pointer[0] == g['stateExportPublisher'] and pointer[1] == g['codePins'][pointer[0]]
        and pointer[3] == schema_id('GOVERNANCE_LAYER') and pointer[4] == '0x77faad4f', 'state export selected native publisher')
    bindings = []
    for host in g['recoveryHosts']:
        authority = o.one(host, 'governanceAuthority()', 'address')
        original = o.one(host, 'originalFinalityRegistry()', 'address')
        config = o.one(host, 'configurationHash()', 'bytes32'); _nonzero(config)
        require(authority in g['executors'] and original in g['codePins']
            and o.one(host, 'core()', 'address') == a['core']
            and o.one(original, 'coreReads()', 'address') == a['core']
            and o.one(host, 'streamModuleType()', 'bytes32') == schema_id('STREAM_ARTWORK_FINALITY_RECOVERY')
            and o.one(host, 'streamModuleVersion()', 'bytes32') == schema_id('6529stream.artwork-finality-recovery.v1')
            and o.one(host, 'streamModuleInterfaceId()', 'bytes4') == '0x83685f5c', 'recovery admitted original host bindings')
        for interface, expected in (('0x01ffc9a7', True), ('0x83685f5c', True), ('0xffffffff', False)):
            require(o.one(host, 'supportsInterface(bytes4)', 'bool', ('bytes4',), (interface,)) == expected, 'recovery native interface support')
        bindings.append({'host': host, 'executor': authority, 'originalFinalityRegistry': original, 'configurationHash': config})
    actions, recoveries, exports, gaps = [], [], [], []
    for host in g['executors']:
        binding = o.read(host, 'systemManifestBootstrapState()', BOOTSTRAP)
        require(binding[0] and binding[11] == a['core'] and binding[12] == g['codePins'][a['core']], 'recovery/export Executor original Core binding')
        count = o.one(host, 'governanceNonce()', 'uint256'); require(count <= MAX_ACTIONS, 'recovery governance nonce bound')
        schedules = _matches(logs, host, 'scheduled'); require(len(schedules) == count, 'recovery governance nonce/event denominator')
        nonces, ids = set(), set()
        for expected_nonce, scheduled in enumerate(schedules):
            action, calls, datas, execution = _action(o, host, scheduled, logs)
            nonce = uint(action['nonce']); require(nonce == expected_nonce and nonce not in nonces and nonce < count and action['actionId'] not in ids, 'recovery duplicate/missing scheduling nonce')
            nonces.add(nonce); ids.add(action['actionId']); actions.append({'executor': host, **action})
            if calls is None: gaps.append({'executor': host, 'actionId': action['actionId'], 'reason': action['transactionInputGap']}); continue
            for index, (call, data) in enumerate(zip(calls, datas)):
                if call[2] != EXECUTE_SELECTOR: continue
                if call[0] not in g['recoveryHosts']:
                    gaps.append({'executor': host, 'actionId': action['actionId'], 'target': call[0], 'reason': 'recovery_selector_target_not_in_admitted_host_set'}); continue
                recoveries.append(_recovery(o, call[0], host, action, index, call, data, execution, logs))
        for name in ('executed', 'cancelled', 'vetoed', 'expired'):
            require(all(log['topics'][1] in ids for log in _matches(logs, host, name)), 'recovery terminal event lacks scheduled original')
        exports.append(_exports(o, host, logs))
    # Missing or wrapped transaction input does not erase independently retained
    # execution records. It also cannot supply the original call index/folds.
    for host in g['recoveryHosts']:
        for log in _matches(logs, host, 'recovery') + _matches(logs, host, 'scopedRecovery'):
            digest = log['topics'][2] if log['topics'][0] == EVENTS['recovery'] else log['topics'][3]
            if any(row['host'] == host and row['actionId'] == digest for row in recoveries): continue
            matches = [row for row in actions if row['actionId'] == digest]
            require(len(matches) == 1 and matches[0]['status'] == 'executed' and matches[0]['calls'] is None,
                'recovery observed execution lacks original scheduled action')
            action = matches[0]
            recoveries.append(_recovery(o, host, action['executor'], action, None, None, None, action['terminal'], logs))
    executed = [r for r in recoveries if r['record'] is not None]
    for host in g['recoveryHosts']:
        actual = _matches(logs, host, 'recovery') + _matches(logs, host, 'scopedRecovery')
        expected = [r['originalExecution'] for r in executed if r['host'] == host]
        require(sorted(actual, key=_pos) == sorted(expected, key=_pos), 'recovery full executed event denominator')
        for name in ('lineage', 'evidence'):
            require(len(_matches(logs, host, name)) == len(expected), 'recovery complete original companion event denominator')
        grouped = {}
        for row in sorted((r for r in executed if r['host'] == host), key=lambda r: _pos(r['originalExecution'])):
            record = finality.from_json(citation.RECOVERY, row['record']); key = dumps(row['scope']); prior = grouped.get(key)
            require((prior is None and record[4] == ZERO and record[5] == 1)
                or (prior is not None and record[4] == prior[1] and record[5] == prior[5] + 1 and record[3] == prior[3]), 'recovery complete exact-scope lineage')
            grouped[key] = record
        scopes = {dumps(r['scope']): finality.from_json(citation.SCOPE, r['scope']) for r in recoveries if r['host'] == host}
        for scope in ((0, uint(a['collectionId']), 0, ZERO), (1, uint(a['collectionId']), uint(a['tokenId']), ZERO)):
            scopes[dumps(json_values(scope))] = scope
        for key, scope in scopes.items():
            head = o.read(host, 'activeFinalityRecovery(' + citation.SCOPE_SIG + ')', citation.HEAD, (citation.SCOPE,), (scope,))
            prior = grouped.get(key); require(head == ((prior[1], prior[7], prior[5]) if prior else (ZERO, ZERO, 0)), 'recovery current exact head/event history')
    documents = value['documents']; require(type(documents) is dict and len(documents) <= 128, 'release documents bound')
    decoded_documents = {}
    for digest, encoded in documents.items():
        payload = hex_bytes(encoded); require(len(payload) <= 1048576 and keccak256(payload) == digest, 'release original document hash/bound')
        decoded_documents[digest] = payload
    require(sum(map(len, decoded_documents.values())) <= 16 * 1024 * 1024, 'release document aggregate bound')
    release = _release(value['releaseEvidence'], decoded_documents)
    if release.get('museumDrill') is not None:
        require(uint(release['museumDrill']['performedAt'], 64) <= uint(a['timestamp']), 'museum drill is after source block')
    require(o.used == set(o.answers), 'recovery/export unused observations')
    owner, owner_files, owner_observations = _owner_responses(value['ownerSources'], a, value['provenance'], recoveries)
    current_export = next(row for row in exports if row['host'] == g['stateExportPublisher'])
    report = {'profile': PROFILE, 'profileHash': PROFILE_HASH, 'sourceReviewCommit': SOURCE_REVISION,
        'sourceState': a, 'provenance': value['provenance'], 'hostBindings': bindings, 'identity': {'collectionSerial': str(identity[2]),
            'burned': identity[3], 'lifecycle': str(lifecycle)}, 'governanceActions': actions,
        'recoveries': {'records': recoveries, 'applicableRecords': [r for r in recoveries if r['applicability']['applies']],
            'undecodedActions': gaps, 'listedExecutorSchedulesComplete': True,
            'listedExecutorRecoveryInputsComplete': not gaps, 'globalRecoveryHostUniverseProven': False,
            'ownerResponseInventoryComplete': False, 'ownerResponseCatalogues': owner, 'noProtocolRecoveriesClaimed': False},
        'stateExports': exports, 'currentStateExport': current_export,
        'sustainability': release, 'historyCoverage': observed['coverage'],
        'remaining': ['historical_executor_and_recovery_host_universe', 'global_owner_recovery_response_host_inventory',
            'original_finality_sanction_and_owner_notice_source_authentication']
            + (['current_release_funding_commitment', 'genuine_zero_signer_museum_drill'] if value['releaseEvidence'] is None else ['release_selection_and_artifact_authenticity']),
        'claims': {'nativeGetterEventAndPreimageJoinsChecked': True, 'sourceProvenanceAuthenticated': False,
            'exportContentsVerified': False, 'historicalExecutionReexecuted': False, 'consensusVerified': False,
            'completePacket17': False, 'completePacket18': False}}
    transcript = {'profile': PROFILE, 'version': 1, 'calls': value['calls']}
    observations = [{'kind': 'rpc', 'name': 'recovery-sustainability', 'anchor': a,
        'transcript': transcript, 'runtimePins': g['codePins'], 'provenance': value['provenance']}]
    observations.extend(owner_observations)
    if owner_observations:
        from .canonical_composition_observations_v1 import reconcile
        report['ownerSourceReconciliation'] = reconcile(a, observations)
    files = {'source/evidence.json': raw, 'source/anchor.json': dumps(a), 'source/transcript.json': dumps(transcript),
        'profile.json': PROFILE_BYTES, 'report.json': dumps(report)}
    files.update(owner_files)
    files.update({'documents/' + digest[2:] + '.bin': payload for digest, payload in decoded_documents.items()})
    require(sum(map(len, files.values())) <= MAX_BYTES, 'recovery/export retained output bound')
    return Result(files, report, observations)
