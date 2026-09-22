"""Original observation joins after concrete V4 family verification.

This internal helper never verifies a package from its report. The caller must
first replay every concrete family. Different source states remain distinct;
contradictory observations of the same chain and block cannot be hidden by a
different host configuration, provenance label, or semantic selection.
"""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from .chain_rpc import quantity
from .independent_wire import require
from . import canonical_composition_observations_v1 as old
from . import canonical_packet_inputs_v1 as packet_inputs
from . import public_scoped_finality_rpc as rpc
from . import public_chain_history as history

NAME = 'STREAM_MUSEUM_CANONICAL_DOSSIER_OBSERVATIONS_V4'
COMMON = ('chainId', 'core', 'collectionId', 'blockHash', 'blockNumber',
    'timestamp', 'stateRoot', 'environment')
CONFIGURATION = ('metadata', 'schemas', 'store', 'artistRegistry')
MAX_BYTES, MAX_ROWS, MAX_SOURCES = old.MAX_BYTES, old.MAX_ROWS, old.MAX_SOURCES
MAX_MATCH_CHECKS = old.MAX_MATCH_CHECKS
CLAIMS = {'concreteFamilyVerificationRequired': True,
    'allSuppliedSourceOccurrencesRetained': True,
    'sameAnchorPositiveObservationContradictionsRejected': True,
    'matchingObservedLogOmissionsChecked': True,
    'differentSourceStatesRetainedSeparately': True,
    'hostDeploymentEvidenceMerged': False, 'missingHeaderFieldsInferred': False,
    'sharedCanonicalHistoryProven': False, 'sourceOriginAuthenticated': False,
    'tokenAuthorityInferredFromCollectionOrMediaScope': False,
    'currentAuthorityOrLegalTitleEstablished': False}
QUALIFICATION = (
    'Only already replayed concrete family observations may enter this helper. '
    'Equality of admitted observations is not consensus or source-origin proof. '
    'Host-specific deployment artifacts remain separate. Different declared '
    'states, configurations, or synthetic/observed provenance classes remain '
    'unjoined; all positive observations at the same chain and block are still '
    'compared. Missing original header, receipt, placement, or state fields are '
    'reported rather than manufactured. Collection and media statements remain '
    'documentary evidence, not token authority. Model/dependency closure and '
    'original semantic selection are checked by the enclosing concrete wrapper.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '4', 'commonStateFields': COMMON,
    'configurationFields': CONFIGURATION,
    'bounds': {'bytes': MAX_BYTES, 'rows': MAX_ROWS, 'sources': MAX_SOURCES,
        'logMatchChecks': MAX_MATCH_CHECKS},
    'originals': 'Exact canonical semantic V2/V3 sources plus original Artist, '
        'General, Metadata and semantic transcripts. No old source profile is rewritten.',
    'positiveOutcomes': 'Successful getters agree across gas budgets; actual '
        'header fields agree on intersection. Sanitized query limits and null '
        'unreturned transactions are not positive absence observations.',
    'receipts': 'Successful and failed originals retained; failed receipts must '
        'have empty logs. All observed reciprocal coordinates are compared.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _sub(files, prefix):
    result = {path.removeprefix(prefix): raw for path, raw in dict(files).items()
        if path.startswith(prefix)}
    require(result, 'dossier V4 original family missing: ' + prefix)
    return result


def _configuration(anchor):
    return {key: anchor['host' if key == 'metadata' else key] for key in CONFIGURATION}


def _rpc(files, name, anchor_path, transcript_path, provenance, configuration):
    anchor, transcript = _json(files, anchor_path), _json(files, transcript_path)
    return {'kind': 'rpc', 'name': name, 'anchor': anchor, 'transcript': transcript,
        'runtimePins': packet_inputs._pins(anchor, transcript), 'provenance': provenance,
        'configuration': dict(configuration)}


def _general_sources(files, name):
    provenance = _json(files, 'manifest.json')['provenance']
    configuration = _configuration(_json(files, 'sources/metadata/anchor.json'))
    return [_rpc(files, name + '/' + part, anchor, transcript, provenance, configuration)
        for part, anchor, transcript in (
            ('metadata', 'sources/metadata/anchor.json', 'sources/metadata/transcript.json'),
            ('general', 'sources/general/anchor.json', 'sources/general/transcript.json'),
            ('semantics', 'sources/general/anchor.json', 'semantics/transcript.json'))]


def _general_alias(general_files, transfer_files):
    if general_files is not None and transfer_files is not None:
        require(dict(general_files) == _sub(transfer_files, 'sources/general-dossier/'),
            'dossier V4 General alias differs from retained transfer original')
        return None
    return general_files


def sources(base_files, *, production_files=None, general_files=None, transfer_files=None):
    """Extract originals from verified canonical semantic V2 and supplements.

    No replay is duplicated here. In particular the V10 source-observations
    file is accepted only because the caller has reconstructed its V3/V2
    package. Conservation Archive descriptors are reconstructed from their
    original preimages, as in the frozen V3 consumer.
    """
    try:
        general_files = _general_alias(general_files, transfer_files)
        base = _sub(base_files, 'input/')
        configuration = _configuration(_json(base, 'acquisition/inputs/work/metadata/anchor.json'))
        result = []
        for row in _json(base, 'acquisition/source-observations.json'):
            result.append(dict(row, name='base/' + row['name'], configuration=dict(configuration)))
        if 'conservation/manifest.json' in base:
            from .canonical_object_dossier_v3 import _conservation_sources
            conserved = _sub(base, 'conservation/')
            provenance = _json(conserved, 'report.json')['sourceProvenance']
            for row in _conservation_sources(conserved, provenance):
                result.append(dict(row, name='base/' + row['name'], configuration=dict(configuration)))
        if production_files is not None:
            files = _sub(production_files, 'sources/attribution/')
            manifest = _json(files, 'manifest.json')
            config = _configuration(_json(files, 'sources/metadata/anchor.json'))
            for part, path in (('metadata', 'sources/metadata/transcript.json'),
                    ('artist', 'artist/transcript.json'), ('semantics', 'semantics/transcript.json')):
                result.append(_rpc(files, 'production/' + part, 'sources/metadata/anchor.json',
                    path, manifest['provenance'], config))
            if manifest['components']['general']:
                result.append(_rpc(files, 'production/general', 'sources/general/anchor.json',
                    'sources/general/transcript.json', manifest['provenance'], config))
        if general_files is not None:
            result.extend(_general_sources(dict(general_files), 'general'))
        if transfer_files is not None:
            result.extend(_general_sources(_sub(transfer_files, 'sources/general-dossier/'), 'transfer'))
        require(0 < len(result) <= MAX_SOURCES and len(dumps(result)) <= MAX_BYTES,
            'dossier V4 observation extraction bound')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed verified dossier V4 source input') from exc


def _nonzero(value, size):
    require(any(hex_bytes(value, size)), 'dossier V4 zero identity')


def _anchor(value):
    require(type(value) is dict and all(key in value for key in old.REQUIRED_ANCHOR),
        'dossier V4 original anchor missing identity')
    for key in ('chainId', 'collectionId', 'tokenId'):
        if key in value: require(uint(value[key]) > 0, 'dossier V4 anchor positive identity')
    for key in ('blockNumber', 'timestamp'): uint(value[key], 64)
    _nonzero(value['core'], 20); _nonzero(value['blockHash'], 32)
    for key in ('stateRoot', 'deploymentEvidenceHash'):
        if key in value: _nonzero(value[key], 32)
    if 'environment' in value:
        require(value['environment'] in ('local_evm_fixture', 'public_chain'),
            'dossier V4 original environment')


def _same(mapping, key, value, label):
    require(mapping.setdefault(key, value) == value, 'dossier V4 conflicting ' + label)


def _merge(mapping, key, value, label):
    existing = mapping.setdefault(key, {})
    for field, item in value.items(): _same(existing, field, item, label + ' ' + field)


def _log(value):
    return history._log(dict(value, removed=value.get('removed', False)))


def _group(rows, *, with_actual=False, match_budget=None):
    """Compare one exact chain/block, including unjoined source configurations."""
    pins, getters, queries, headers, receipts, heights, placements = {}, {}, {}, {}, {}, {}, {}
    logs, timestamps, block_numbers, log_sources, rpc_rows, native_events = {}, {}, {}, {}, [], []
    occurrence_count = failed_count = limited_count = 0
    partial_headers = []
    reference = rows[0]['anchor'] if rows[0]['kind'] == 'rpc' else rows[0]['context']
    tip, tip_time = uint(reference['blockNumber']), uint(reference['timestamp'])
    if match_budget is None: match_budget = MAX_MATCH_CHECKS
    require(type(match_budget) is int and 0 <= match_budget <= MAX_MATCH_CHECKS,
        'dossier V4 matching log budget')

    def pin(address, digest):
        _nonzero(address, 20); _nonzero(digest, 32)
        _same(pins, address, digest, 'same-block runtime')

    def getter(target, data, result):
        _nonzero(target, 20); hex_bytes(data); hex_bytes(result)
        require(target in pins, 'dossier V4 getter target has no actual runtime pin')
        _same(getters, (target, data), result, 'same-block successful getter')

    def header(value):
        require(type(value) is dict, 'dossier V4 header shape')
        digest = value['hash']; _nonzero(digest, 32)
        number, stamp = quantity(value['number']), quantity(value['timestamp'])
        require(number <= tip and stamp <= tip_time, 'dossier V4 future header')
        _nonzero(value['stateRoot'], 32)
        _same(heights, number, digest, 'header height')
        _same(block_numbers, digest, number, 'header hash height')
        _same(timestamps, digest, stamp, 'block timestamp')
        _merge(headers, digest, value, 'header')
        if 'parentHash' in value: hex_bytes(value['parentHash'], 32)
        if 'transactions' in value:
            txs = value['transactions']
            require(type(txs) is list and len(txs) <= 8192 and len(set(txs)) == len(txs),
                'dossier V4 header transaction denominator')
            for index, transaction in enumerate(txs):
                _nonzero(transaction, 32)
                _same(placements, transaction, (digest, index), 'transaction placement')

    for source in rows:
        anchor = source['anchor'] if source['kind'] == 'rpc' else source['context']
        # Anchor facts seed reciprocal joins without manufacturing RPC headers.
        _same(heights, uint(anchor['blockNumber']), anchor['blockHash'], 'anchor height')
        _same(block_numbers, anchor['blockHash'], uint(anchor['blockNumber']), 'anchor hash height')
        _same(timestamps, anchor['blockHash'], uint(anchor['timestamp']), 'anchor timestamp')
        require(uint(anchor['blockNumber']) == tip and uint(anchor['timestamp']) == tip_time,
            'dossier V4 same-block anchor coordinates differ')
        for address, digest in source['runtimePins'].items(): pin(address, digest)
    roots = {s['anchor' if s['kind'] == 'rpc' else 'context']['stateRoot'] for s in rows
        if 'stateRoot' in s['anchor' if s['kind'] == 'rpc' else 'context']}
    require(len(roots) <= 1, 'dossier V4 same-block anchor state root differs')

    for source in rows:
        if source['kind'] == 'native':
            require(type(source['calls']) is list and type(source['events']) is list,
                'dossier V4 native observations shape')
            for call in source['calls']:
                require(type(call) is dict and set(call) == {'target', 'calldata', 'result'},
                    'dossier V4 native getter shape')
                getter(call['target'], call['calldata'], call['result'])
            native_events.extend((source['name'], event) for event in source['events'])
            continue
        transcript = source['transcript']
        require(type(transcript) is dict and type(transcript.get('calls')) is list,
            'dossier V4 original transcript shape')
        for call_index, row in enumerate(transcript['calls']):
            rpc._row(row)
            method, params = row['method'], row['params']
            rpc_rows.append((source['name'], row))
            if 'limit' in row:
                limited_count += 1
                continue
            value = row['result']
            if value is None:
                require(method == 'eth_getTransactionByHash', 'dossier V4 unavailable essential observation')
                continue
            if method in ('eth_getBlockByHash', 'eth_getBlockByNumber'):
                require((method == 'eth_getBlockByHash' and params[0] == value['hash'])
                    or (method == 'eth_getBlockByNumber' and quantity(params[0]) == quantity(value['number'])),
                    'dossier V4 header request differs')
                header(value)
                missing_fields = [key for key in ('parentHash', 'transactions') if key not in value]
                if missing_fields:
                    partial_headers.append({'source': source['name'], 'callIndex': str(call_index),
                        'blockHash': value['hash'], 'undeclaredFields': missing_fields})
                continue  # Different original header surfaces compare on present fields.
            if method == 'eth_getTransactionReceipt':
                require(type(value) is dict and value['transactionHash'] == params[0]
                    and value['status'] in ('0x0', '0x1') and type(value['logs']) is list
                    and len(value['logs']) <= 4096
                    and (value['status'] == '0x1' or not value['logs']),
                    'dossier V4 failed receipt or receipt identity')
                normalized = dict(value, logs=[_log(log) for log in value['logs']])
                _merge(receipts, params[0], normalized, 'receipt')
                failed_count += value['status'] == '0x0'
                continue
            normalized = [_log(log) for log in value] if method == 'eth_getLogs' else value
            _same(queries, dumps([method, params]), dumps(normalized), 'positive RPC outcome')
            if method in ('eth_call', 'eth_getCode'):
                require(params[1]['blockHash'] == reference['blockHash'],
                    'dossier V4 original read block differs')
                if method == 'eth_call': getter(params[0]['to'], params[0]['data'], value)
                else: pin(params[0], keccak256(hex_bytes(value)))
            elif method == 'eth_chainId':
                require(quantity(value) == uint(reference['chainId']), 'dossier V4 chain observation differs')

    for digest, value in headers.items():
        if digest == reference['blockHash']:
            require(quantity(value['number']) == tip and quantity(value['timestamp']) == tip_time
                and (not roots or value['stateRoot'] in roots), 'dossier V4 source header differs')
    previous = None
    for number, digest in sorted(heights.items()):
        stamp = timestamps[digest]
        if previous is not None:
            require(previous[2] <= stamp, 'dossier V4 historical timestamp regression')
            if previous[0] + 1 == number and 'parentHash' in headers.get(digest, {}):
                require(headers[digest]['parentHash'] == previous[1], 'dossier V4 adjacent parent differs')
        previous = (number, digest, stamp)

    def position(transaction, block, number, index):
        _nonzero(transaction, 32); _nonzero(block, 32)
        require(number <= tip, 'dossier V4 future transaction')
        _same(heights, number, block, 'receipt/event block height')
        _same(block_numbers, block, number, 'receipt/event block hash height')
        _same(placements, transaction, (block, index), 'receipt/event transaction placement')
        observed = headers.get(block)
        if observed and 'transactions' in observed:
            require(index < len(observed['transactions']) and observed['transactions'][index] == transaction,
                'dossier V4 reciprocal header transaction slot differs')

    slots = {}
    for transaction, receipt in receipts.items():
        block, number, index = receipt['blockHash'], quantity(receipt['blockNumber']), quantity(receipt['transactionIndex'])
        position(transaction, block, number, index)
        _same(slots, (block, index), transaction, 'receipt slot')
        for log in receipt['logs']:
            require(all(log[key] == receipt[key] for key in
                ('blockHash', 'blockNumber', 'transactionHash', 'transactionIndex')),
                'dossier V4 receipt log coordinates differ')

    def event(source_name, value, timestamp=None):
        nonlocal occurrence_count
        log = _log(value); block = log['blockHash']
        number, index, log_index = (quantity(log[key]) for key in ('blockNumber', 'transactionIndex', 'logIndex'))
        position(log['transactionHash'], block, number, index)
        _same(slots, (block, index), log['transactionHash'], 'event transaction slot')
        _same(logs, (block, log_index), log, 'event coordinate')
        log_sources.setdefault((block, log_index), set()).add(source_name)
        if timestamp is not None:
            stamp = uint(timestamp, 64)
            require(stamp <= tip_time, 'dossier V4 future event timestamp')
            _same(timestamps, block, stamp, 'event timestamp')
        occurrence_count += 1
        require(occurrence_count <= MAX_ROWS, 'dossier V4 event occurrence bound')

    for name, row in rpc_rows:
        if 'result' not in row: continue
        if row['method'] == 'eth_getLogs':
            query = row['params'][0]
            for log in row['result']:
                require(quantity(query['fromBlock']) <= quantity(log['blockNumber']) <= quantity(query['toBlock'])
                    and history._matches(log, query), 'dossier V4 log outside original query')
                event(name, log)
        elif row['method'] == 'eth_getTransactionReceipt':
            for log in row['result']['logs']: event(name, log)
    for name, row in native_events:
        require(type(row) is dict and set(row) == {'log', 'timestamp'}, 'dossier V4 native event shape')
        event(name, row['log'], row['timestamp'])

    last_stamp = None
    for number, block in sorted(heights.items()):
        if block not in timestamps: continue
        stamp = timestamps[block]
        require(last_stamp is None or last_stamp <= stamp, 'dossier V4 observed event/header time regression')
        last_stamp = stamp

    # Sparse observations need not prove a complete log sequence, but retained
    # event order cannot contradict transaction order within the same block.
    previous = {}
    for (block, index), log in sorted(logs.items()):
        tx_index = quantity(log['transactionIndex'])
        require(previous.get(block, -1) <= tx_index, 'dossier V4 event transaction order differs')
        previous[block] = tx_index
    checks = 0
    for _, row in rpc_rows:
        if 'result' not in row or row['method'] not in ('eth_getLogs', 'eth_getTransactionReceipt'): continue
        query = row['method'] == 'eth_getLogs'
        supplied = row['result'] if query else row['result']['logs']
        retained = {dumps(_log(log)) for log in supplied}
        for log in logs.values():
            checks += 1
            require(checks <= match_budget, 'dossier V4 matching log join bound')
            if query:
                f = row['params'][0]
                matches = quantity(f['fromBlock']) <= quantity(log['blockNumber']) <= quantity(f['toBlock']) and history._matches(log, f)
            else: matches = log['transactionHash'] == row['result']['transactionHash']
            require(not matches or dumps(log) in retained, 'dossier V4 matching retained log omitted')

    missing = {'headersWithoutTransactionLists': sorted(key for key, value in headers.items() if 'transactions' not in value),
        'headersWithoutParentHash': sorted(key for key, value in headers.items() if 'parentHash' not in value),
        'receiptBlocksWithoutObservedHeaders': sorted({value['blockHash'] for value in receipts.values()} - set(headers)),
        'eventBlocksWithoutObservedHeaders': sorted({key[0] for key in logs} - set(headers)),
        'eventTransactionsWithoutObservedReceipts': sorted({log['transactionHash'] for log in logs.values()} - set(receipts)),
        'eventBlocksWithoutObservedTimestamp': sorted({key[0] for key in logs} - set(timestamps))}
    report = {'chainId': reference['chainId'], 'blockHash': reference['blockHash'],
        'sourceNames': [row['name'] for row in rows], 'runtimePinCount': len(pins),
        'successfulGetterCount': len(getters), 'positiveRpcQueryCount': len(queries),
        'headerCount': len(headers), 'receiptCount': len(receipts),
        'failedReceiptOccurrences': failed_count, 'limitedQueryOccurrences': limited_count,
        'matchingLogChecks': checks, 'partialHeaderOccurrences': partial_headers,
        'eventOccurrences': occurrence_count, 'uniqueEventCount': len(logs), 'missingObservationDetail': missing,
        'events': [{'log': log, 'timestamp': str(timestamps[key[0]]) if key[0] in timestamps else None,
            'sources': sorted(log_sources[key])} for key, log in sorted(logs.items())]}
    if not with_actual: return report
    return report, {'headers': headers, 'receipts': receipts, 'logs': logs,
        'timestamps': timestamps, 'anchors': [row['anchor' if row['kind'] == 'rpc' else 'context'] for row in rows]}


def _overlaps(groups):
    """Compare actual identical historical blocks across distinct tip cohorts.

    Different hashes at the same height may be separate admitted histories.
    Range queries are deliberately not applied across those histories. An
    actual identical block/transaction, however, cannot have different bytes.
    """
    headers, receipts, logs, slots, positions, timestamps = {}, {}, {}, {}, {}, {}
    for chain, observed in groups:
        for anchor in observed['anchors']:
            value = {'hash': anchor['blockHash'], 'number': hex(uint(anchor['blockNumber'])),
                'timestamp': hex(uint(anchor['timestamp']))}
            if 'stateRoot' in anchor: value['stateRoot'] = anchor['stateRoot']
            _merge(headers, (chain, anchor['blockHash']), value, 'cross-tip anchor/header')
        for block, header in observed['headers'].items():
            _merge(headers, (chain, block), header, 'cross-tip same-block header')
        for block, stamp in observed['timestamps'].items():
            _same(timestamps, (chain, block), stamp, 'cross-tip same-block timestamp')
        for tx, receipt in observed['receipts'].items():
            _merge(receipts, (chain, receipt['blockHash'], tx), receipt, 'cross-tip same-block receipt')
        for (block, index), log in observed['logs'].items():
            _same(logs, (chain, block, index), log, 'cross-tip same-block log')

    def placement(chain, block, tx, index, number=None):
        _same(slots, (chain, block, index), tx, 'cross-tip same-block transaction slot')
        _same(positions, (chain, block, tx), index, 'cross-tip same-block transaction position')
        header = headers.get((chain, block))
        if header:
            if number is not None:
                require(quantity(header['number']) == number, 'dossier V4 cross-tip block number differs')
            if 'transactions' in header:
                require(index < len(header['transactions']) and header['transactions'][index] == tx,
                    'dossier V4 cross-tip reciprocal transaction slot differs')

    for (chain, block), header in headers.items():
        if (chain, block) in timestamps:
            require(quantity(header['timestamp']) == timestamps[(chain, block)],
                'dossier V4 cross-tip header/event timestamp differs')
        for index, tx in enumerate(header.get('transactions', [])):
            placement(chain, block, tx, index)
    receipt_logs = {key: {dumps(log) for log in receipt['logs']} for key, receipt in receipts.items()}
    for (chain, block, tx), receipt in receipts.items():
        placement(chain, block, tx, quantity(receipt['transactionIndex']), quantity(receipt['blockNumber']))
    for (chain, block, _), log in logs.items():
        tx = log['transactionHash']
        placement(chain, block, tx, quantity(log['transactionIndex']), quantity(log['blockNumber']))
        receipt = receipts.get((chain, block, tx))
        if receipt is not None:
            # Both observations explicitly name the same immutable block and tx;
            # this does not apply another tip's range query to a possible fork.
            require(dumps(log) in receipt_logs[(chain, block, tx)],
                'dossier V4 cross-tip same-block receipt omitted retained log')
    return {'sameBlockHeadersAndAnchors': len(headers), 'sameBlockReceipts': len(receipts),
        'sameBlockEvents': len(logs), 'differentHashSameHeightCompared': False,
        'rangeQueriesAppliedAcrossDifferentTips': False}


def reconcile(reference, rows):
    """Return a joined/unjoined ledger; never reinterpret original provenance."""
    try:
        old._state(reference)
        require(type(rows) is list and 0 < len(rows) <= MAX_SOURCES and len(dumps(rows)) <= MAX_BYTES,
            'dossier V4 original observation bounds')
        names, groups, ledger, count = set(), {}, [], 0
        base = [row for row in rows if row.get('name', '').startswith('base/')]
        require(base, 'dossier V4 canonical base observations required')
        base_provenance = {row['provenance'] == 'synthetic_fixture' for row in base}
        require(len(base_provenance) == 1, 'dossier V4 canonical base provenance class differs')
        config = base[0].get('configuration', {})
        require(all(row.get('configuration', {}) == config for row in base), 'dossier V4 base configuration differs')
        for row in rows:
            require(type(row) is dict and row.get('kind') in ('rpc', 'native'), 'dossier V4 source kind')
            expected = {'kind', 'name', 'runtimePins', 'provenance'} | (
                {'anchor', 'transcript'} if row['kind'] == 'rpc' else {'context', 'calls', 'events'})
            require(set(row) in (expected, expected | {'configuration'}) and type(row['name']) is str
                and 0 < len(row['name']) <= 256 and row['name'] not in names,
                'dossier V4 source shape/name')
            names.add(row['name'])
            require(row['provenance'] in old.PROVENANCE and type(row['runtimePins']) is dict,
                'dossier V4 source provenance/runtime pins')
            anchor = row['anchor'] if row['kind'] == 'rpc' else row['context']; _anchor(anchor)
            configuration = row.get('configuration', {})
            require(type(configuration) is dict and set(configuration) <= set(CONFIGURATION),
                'dossier V4 source configuration shape')
            for address in configuration.values(): _nonzero(address, 20)
            if row['kind'] == 'rpc': count += len(row['transcript']['calls'])
            else: count += len(row['calls']) + len(row['events'])
            require(count <= MAX_ROWS, 'dossier V4 observation row bound')
            reasons = ['state_differs:' + key for key in COMMON if key in anchor and anchor[key] != reference[key]]
            if 'tokenId' in anchor and anchor['tokenId'] != reference['tokenId']:
                reasons.append('state_differs:tokenId')
            reasons += ['state_undeclared:' + key for key in COMMON if key not in anchor]
            reasons += ['configuration_differs:' + key for key in CONFIGURATION
                if key in configuration and key in config and configuration[key] != config[key]]
            if (row['provenance'] == 'synthetic_fixture') not in base_provenance:
                reasons.append('provenance_class_differs')
            ledger.append({'name': row['name'], 'kind': row['kind'], 'status': 'unjoined' if reasons else 'joined',
                'reasons': reasons, 'provenance': row['provenance'], 'originalAnchor': anchor,
                'originalConfiguration': configuration, 'observationHash': keccak256(dumps(row)),
                'hostDeploymentEvidenceHash': anchor.get('deploymentEvidenceHash'),
                'undeclaredStateFields': [key for key in COMMON if key not in anchor],
                'tokenIdDeclared': anchor.get('tokenId')})
            groups.setdefault((anchor['chainId'], anchor['blockHash']), []).append(row)
        evidence, overlaps, matching_checks = [], [], 0
        for (chain, _), group in sorted(groups.items()):
            report, actual = _group(group, with_actual=True,
                match_budget=MAX_MATCH_CHECKS - matching_checks)
            evidence.append(report); overlaps.append((chain, actual))
            matching_checks += report['matchingLogChecks']
        require(matching_checks <= MAX_MATCH_CHECKS, 'dossier V4 aggregate matching log join bound')
        overlap_report = _overlaps(overlaps)
        return {'profileHash': PROFILE_HASH, 'sourceState': dict(reference), 'sources': ledger,
            'joinedSourceCount': sum(row['status'] == 'joined' for row in ledger),
            'unjoinedSourceCount': sum(row['status'] == 'unjoined' for row in ledger),
            'matchingLogChecks': matching_checks,
            'observationEvidence': evidence, 'crossTipOverlapChecks': overlap_report,
            'claims': dict(CLAIMS), 'qualification': QUALIFICATION}
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed dossier V4 observation join') from exc


def subjects(reference, *, production_files=None, general_files=None, transfer_files=None):
    """Classify original selected/withheld assertions without changing selection.

    Subject agreement is separate from source-state agreement and cannot confer
    authority. Collection/media assertions never become token assertions.
    """
    try:
        old._state(reference)
        general_files = _general_alias(general_files, transfer_files)
        candidates = []
        if production_files is not None:
            files = _sub(production_files, 'sources/attribution/')
            dossier = _json(files, 'dossier.json')
            candidates.append(('production', files, dossier['semanticEvidence'], dossier['selection'], False))
        if general_files is not None:
            files = dict(general_files)
            candidates.append(('general', files, _json(files, 'semantics/snapshot.json'), _json(files, 'graph/selection.json'), True))
        if transfer_files is not None:
            files = _sub(transfer_files, 'sources/general-dossier/')
            candidates.append(('transfer', files, _json(files, 'semantics/snapshot.json'), _json(files, 'graph/selection.json'), True))
        result = []
        for family, files, snapshot, selection, general in candidates:
            anchor = _json(files, 'sources/general/anchor.json' if general else 'sources/metadata/anchor.json')
            statements = {}
            for original in snapshot['statements']:
                if original['status'] != 'supported': continue
                for index, _ in enumerate(original['value']['assertions']):
                    selector = dict(original['source'], pointer='/assertions/' + str(index))
                    key = dumps(selector)
                    require(key not in statements, 'dossier V4 duplicate exact original assertion occurrence')
                    statements[key] = original
            for disposition in ('selected', 'withheld'):
                for selected in selection[disposition]:
                    source = selected['source']; key = dumps(source)
                    require(key in statements, 'dossier V4 selected exact original assertion absent')
                    original = statements[key]
                    scope = original['value']['anchorSubject']
                    native_subject = original['original']['subject'] if general else None
                    if general:
                        require(type(native_subject) is list and len(native_subject) == 4,
                            'dossier V4 General original subject shape')
                        kind, collection, token, object_id = native_subject
                        kind = uint(kind, 8)
                        require(kind in (0, 1, 2) and collection == anchor['collectionId']
                            and scope['kind'] == ('collection', 'token', 'media')[kind]
                            and scope['subjectId'] == subject_id(scope['kind'], anchor['chainId'],
                                anchor['core'], collection, token_id=token, object_id=object_id),
                            'dossier V4 General original subject preimage differs')
                    state_matches = all(anchor[key] == reference[key] for key in ('chainId', 'core', 'collectionId'))
                    expected = subject_id('token', reference['chainId'], reference['core'],
                        reference['collectionId'], token_id=reference['tokenId'])
                    if not state_matches: status = 'different_source_identity'
                    elif scope['kind'] == 'token':
                        status = 'exact_token_subject' if scope['subjectId'] == expected else 'different_token_subject'
                        if general and status == 'exact_token_subject':
                            require(native_subject[2] == reference['tokenId'], 'dossier V4 explicit native token differs')
                    elif scope['kind'] == 'collection': status = 'collection_documentary_scope'
                    else: status = 'media_documentary_scope'
                    result.append({'family': family, 'source': source, 'selectionDisposition': disposition,
                        'anchorSubject': scope, 'nativeGeneralSubject': native_subject,
                        'status': status, 'tokenAuthorityEstablished': False,
                        'sourceStateJoinedHere': False})
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed dossier V4 original subject inventory') from exc
