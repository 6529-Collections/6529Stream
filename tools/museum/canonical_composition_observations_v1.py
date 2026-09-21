"""Cross-family observations after each concrete source consumer has succeeded.

This internal join never admits a source from a report or a completeness flag.
Original evidence must be replayed before constructing these observation rows.
"""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, uint
from .chain_rpc import quantity
from .independent_wire import require
from . import public_chain_history as history
from . import public_scoped_finality_rpc as rpc
from . import view_preservation_reference_wire_v1 as events_wire

PROFILE = 'STREAM_MUSEUM_CANONICAL_COMPOSITION_OBSERVATIONS_V1'
STATE_KEYS = ('chainId', 'core', 'collectionId', 'tokenId', 'blockHash',
    'blockNumber', 'timestamp', 'stateRoot', 'environment', 'deploymentEvidenceHash')
REQUIRED_ANCHOR = ('chainId', 'core', 'blockHash', 'blockNumber', 'timestamp')
MAX_BYTES, MAX_ROWS, MAX_SOURCES = 128 * 1024 * 1024, 100000, 256
MAX_MATCH_CHECKS = 4194304
PROVENANCE = ('synthetic_fixture', 'trusted_rpc', 'externally_admitted_rpc')
CLAIMS = {'concreteSourceVerificationRequired': True, 'commonDeclaredStateChecked': True,
    'sharedRuntimeAndSuccessfulGetterResultsChecked': True,
    'retainedEventCoordinatesChecked': True, 'originalSourceQualificationsPreserved': True,
    'retainedMatchingLogOmissionsChecked': True,
    'sourceProvenanceAuthenticated': False, 'globalHistoryCompletenessProven': False,
    'missingSourceFieldsInferred': False, 'consensusVerified': False}
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1', 'stateKeys': STATE_KEYS,
    'bounds': {'bytes': MAX_BYTES, 'rows': MAX_ROWS, 'sources': MAX_SOURCES},
    'inputs': 'Only observations derived by concrete successful source consumers.',
    'queries': 'Exact RPC outcomes and successful getter answers agree across gas budgets. '
        'Native descriptors bind the same target/calldata at the common block.',
    'history': 'Retained events, headers and receipts agree where observed. Missing reciprocal '
        'headers, ancestors, queries, receipts and source fields are never manufactured.',
    'claims': CLAIMS})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _nonzero(value, size):
    require(any(hex_bytes(value, size)), 'canonical composition zero identity')


def _state(reference):
    require(type(reference) is dict and set(reference) == set(STATE_KEYS),
        'canonical composition exact reference state')
    for key in ('chainId', 'collectionId', 'tokenId'):
        require(uint(reference[key]) > 0, 'canonical composition positive identity')
    uint(reference['blockNumber'], 64); uint(reference['timestamp'], 64)
    _nonzero(reference['core'], 20)
    for key in ('blockHash', 'stateRoot', 'deploymentEvidenceHash'):
        _nonzero(reference[key], 32)
    require(reference['environment'] in ('local_evm_fixture', 'public_chain'),
        'canonical composition environment')


def reconcile(reference, sources):
    """Join computed RPC/native rows; this function does not verify their sources.

    RPC rows: kind/name/anchor/transcript/runtimePins/provenance. Native rows:
    kind/name/context/calls/events/runtimePins/provenance. Runtime pins are a
    dictionary from address to code hash. All objects are read without mutation.
    """
    try:
        return _reconcile(reference, sources)
    except MuseumError:
        raise
    except (KeyError, IndexError, ValueError, TypeError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed canonical composition observations') from exc


def _reconcile(reference, sources):
    _state(reference)
    require(type(sources) is list and 0 < len(sources) <= MAX_SOURCES,
        'canonical composition source bound')
    require(len(dumps(sources)) <= MAX_BYTES, 'canonical composition observation byte bound')
    names, pins, getters, queries, headers, receipts = set(), {}, {}, {}, {}, {}
    event_rows, native_events, source_rows, all_rpc = [], [], [], []
    heights, placements = {}, {}
    count = 0

    def pin(address, digest):
        _nonzero(address, 20); _nonzero(digest, 32)
        require(pins.setdefault(address, digest) == digest,
            'canonical composition conflicting runtime')

    def getter(target, data, result):
        _nonzero(target, 20); hex_bytes(data); hex_bytes(result)
        require(target in pins, 'canonical composition unpinned getter target')
        require(getters.setdefault((target, data), result) == result,
            'canonical composition conflicting getter')

    # Seed every concrete source's pins before comparing any source's reads.
    for source in sources:
        require(type(source) is dict and source.get('kind') in ('rpc', 'native'),
            'canonical composition source kind')
        expected = {'kind', 'name', 'runtimePins', 'provenance'} | (
            {'anchor', 'transcript'} if source['kind'] == 'rpc' else {'context', 'calls', 'events'})
        require(set(source) == expected and type(source['name']) is str
            and 0 < len(source['name']) <= 256 and source['name'] not in names,
            'canonical composition source shape/name')
        names.add(source['name'])
        require(source['provenance'] in PROVENANCE and type(source['runtimePins']) is dict,
            'canonical composition provenance/pins')
        for address, digest in source['runtimePins'].items(): pin(address, digest)

    for source in sources:
        anchor = source['anchor'] if source['kind'] == 'rpc' else source['context']
        require(type(anchor) is dict and all(key in anchor for key in REQUIRED_ANCHOR),
            'canonical composition source anchor identity')
        for key in STATE_KEYS:
            require(key not in anchor or anchor[key] == reference[key],
                'canonical composition source state differs: ' + key)
        source_rows.append({'name': source['name'], 'kind': source['kind'],
            'provenance': source['provenance'], 'observationHash': keccak256(dumps(source)),
            'undeclaredAnchorFields': [key for key in STATE_KEYS if key not in anchor]})
        if source['kind'] == 'native':
            require(type(source['calls']) is list and type(source['events']) is list,
                'canonical composition native observations shape')
            count += len(source['calls']) + len(source['events'])
            require(count <= MAX_ROWS, 'canonical composition observation row bound')
            for call in source['calls']:
                require(type(call) is dict and set(call) == {'target', 'calldata', 'result'},
                    'canonical composition native call shape')
                getter(call['target'], call['calldata'], call['result'])
            native_events.extend(source['events'])
            continue
        transcript = source['transcript']
        require(type(transcript) is dict and type(transcript.get('calls')) is list,
            'canonical composition RPC transcript shape')
        # Concrete replay owns its exact transcript profile/version. Retain it.
        rows = transcript['calls']; count += len(rows); all_rpc.extend(rows)
        require(count <= MAX_ROWS, 'canonical composition observation row bound')
        for row in rows:
            rpc._row(row)
            key = dumps([row['method'], row['params']])
            outcome = dumps({key: row[key] for key in ('result', 'limit') if key in row})
            require(queries.setdefault(key, outcome) == outcome,
                'canonical composition conflicting exact RPC outcome')
            method, params = row['method'], row['params']
            if method in ('eth_call', 'eth_getCode'):
                require(params[1]['blockHash'] == reference['blockHash'],
                    'canonical composition getter block differs')
                if method == 'eth_call': getter(params[0]['to'], params[0]['data'], row['result'])
                else: pin(params[0], keccak256(hex_bytes(row['result'])))
            elif method == 'eth_chainId':
                require(quantity(row['result']) == uint(reference['chainId']),
                    'canonical composition RPC chain differs')
            elif method in ('eth_getBlockByHash', 'eth_getBlockByNumber'):
                header = row['result']; digest = header['hash']
                number, stamp = quantity(header['number']), quantity(header['timestamp'])
                _nonzero(digest, 32); _nonzero(header['stateRoot'], 32)
                require(number <= uint(reference['blockNumber'])
                    and stamp <= uint(reference['timestamp'])
                    and ((method == 'eth_getBlockByHash' and params[0] == digest)
                        or (method == 'eth_getBlockByNumber' and quantity(params[0]) == number)),
                    'canonical composition header request/time differs')
                require(headers.setdefault(digest, header) == header,
                    'canonical composition conflicting header')
                require(heights.setdefault(number, digest) == digest,
                    'canonical composition conflicting header height')
                require(type(header['transactions']) is list
                    and len(set(header['transactions'])) == len(header['transactions']),
                    'canonical composition header transaction list')
                for index, transaction in enumerate(header['transactions']):
                    _nonzero(transaction, 32)
                    require(placements.setdefault(transaction, (digest, index)) == (digest, index),
                        'canonical composition conflicting transaction placement')
                if digest == reference['blockHash']:
                    require(number == uint(reference['blockNumber'])
                        and stamp == uint(reference['timestamp'])
                        and header['stateRoot'] == reference['stateRoot'],
                        'canonical composition source header differs')
            elif method == 'eth_getTransactionReceipt':
                receipt = row['result']; digest = receipt['transactionHash']
                require(receipts.setdefault(digest, receipt) == receipt,
                    'canonical composition conflicting receipt')
    require(count <= MAX_ROWS, 'canonical composition observation row bound')
    provenances = {source['provenance'] for source in sources}
    require('synthetic_fixture' not in provenances or provenances == {'synthetic_fixture'},
        'canonical composition synthetic/observed sources mixed')
    previous = None
    for number, digest in sorted(heights.items()):
        header = headers[digest]
        if previous is not None:
            require(quantity(previous['timestamp']) <= quantity(header['timestamp']),
                'canonical composition header time regression')
            if quantity(previous['number']) + 1 == number:
                require(header['parentHash'] == previous['hash'],
                    'canonical composition adjacent parent differs')
        previous = header
    for transaction, receipt in receipts.items():
        require(receipt['status'] == '0x1'
            and placements.get(transaction) == (receipt['blockHash'], quantity(receipt['transactionIndex']))
            and heights.get(quantity(receipt['blockNumber'])) == receipt['blockHash'],
            'canonical composition receipt/header differs')

    for row in all_rpc:
        if row['method'] == 'eth_getLogs' and 'result' in row:
            logs = row['result']
        elif row['method'] == 'eth_getTransactionReceipt':
            logs = row['result']['logs']
        else:
            continue
        for log in logs:
            normalized = history._log(dict(log, removed=log.get('removed', False)))
            normalized['removed'] = False
            header = headers.get(log['blockHash'])
            require(header is not None, 'canonical composition retained log header missing')
            event_rows.append({'log': normalized, 'timestamp': str(quantity(header['timestamp']))})
    for event in native_events:
        require(type(event) is dict and set(event) == {'log', 'timestamp'},
            'canonical composition native event shape')
        log = event['log']
        normalized = history._log(dict(log, removed=log.get('removed', False)))
        normalized['removed'] = False
        event_rows.append({'log': normalized, 'timestamp': event['timestamp']})
    for event in event_rows:
        log = event['log']; number = quantity(log['blockNumber'])
        require(number <= uint(reference['blockNumber'])
            and uint(event['timestamp'], 64) <= uint(reference['timestamp'], 64),
            'canonical composition future event')
        header = headers.get(log['blockHash'])
        if header is not None:
            index = quantity(log['transactionIndex'])
            require(quantity(header['number']) == number
                and quantity(header['timestamp']) == uint(event['timestamp'])
                and index < len(header['transactions'])
                and header['transactions'][index] == log['transactionHash'],
                'canonical composition event/header differs')
    events_wire._event_coherence(event_rows, reference)
    unique_events = {dumps(event['log']): event['log'] for event in event_rows}
    checks = 0
    for row in all_rpc:
        if row['method'] not in ('eth_getLogs', 'eth_getTransactionReceipt') or 'result' not in row:
            continue
        is_query = row['method'] == 'eth_getLogs'
        supplied = row['result'] if is_query else row['result']['logs']
        retained = {dumps(history._log(dict(log, removed=log.get('removed', False)))) for log in supplied}
        for log in unique_events.values():
            checks += 1
            require(checks <= MAX_MATCH_CHECKS, 'canonical composition log join bound')
            if is_query:
                query = row['params'][0]; number = quantity(log['blockNumber'])
                matches = quantity(query['fromBlock']) <= number <= quantity(query['toBlock'])
                matches = matches and history._matches(log, query)
            else:
                matches = log['transactionHash'] == row['result']['transactionHash']
            require(not matches or dumps(history._log(log)) in retained,
                'canonical composition retained matching log omitted')
    return {'profileHash': PROFILE_HASH, 'sourceState': dict(reference), 'sources': source_rows,
        'runtimePinCount': len(pins), 'successfulGetterCount': len(getters),
        'exactRpcQueryCount': len(queries), 'eventOccurrences': len(event_rows),
        'claims': dict(CLAIMS)}
