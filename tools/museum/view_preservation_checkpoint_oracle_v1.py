"""A bounded native trace oracle for the original VIEW preservation checkpoint.

Forge's decoded structs are deliberately ignored. Raw library returndata is
decoded with the frozen consumer ABI, then joined to emitted hash commitments.
This checks one pinned native test, not deployment, Registry admission, a
snapshot, a Router CONTENT_ROOT, or the complete dependency graph.
"""
from hashlib import sha256
import re

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import decode, encode
from .independent_wire import require
from . import view_preservation_output_types_v1 as t
from . import view_preservation_output_wire_v1 as wire
from . import view_policy_adoption_wire_v2 as adoption_wire

FORMAT = 'STREAM_VIEW_PRESERVATION_CHECKPOINT_NATIVE_VECTOR_V1'
TRACE_SHA256 = '413d02da1865cec080d7d43b7e979e636223626ceaf61c497817112a804f241c'
TRACE_BYTES = 1635046
NATIVE_REVISION = '7701ad897c27257e5f082b310d62a6e35526cd0a'
CONSUMER_REVISION = 'e8a569b36927ed7f711a14a30ce5b09690694dd0'
MAX_TRACE, MAX_VECTOR = 2 * 1024 * 1024, 256 * 1024
TEST = 'testCompleteThreeRowsBindLiteralRootAndExplicitRetainedBurnedMember'
FIXTURE_CONFIGURATION = {
    'sourcePath': 'test/helpers/ViewPreservationCheckpointFixtureV1.sol',
    'gitBlobSha1': 'c4cf8ecd2931236713f15899825d9a6f059c458a',
    'firstLine': '171', 'lastLine': '184', 'authority': 'core',
    'readGas': '1000000', 'servingGas': '10000000',
}
QUALIFICATION = (
    'This is one successful native unit-test trace with actual preservation producer and checkpoint execution; '
    'the surrounding authority, Core, membership and policy endpoints include typed test replies. '
    'The original 7701 Registry predates the e8 preservation Registry: its admission is supplied through a '
    'typed boundary, not an actual native e8 registration. Raw Source5 and token-worker Output31/JSON/HTML '
    'returns are retained; Forge pretty-printed Plan and Output structs are not ABI evidence. '
    'The checkpoint configuration is reconstructed from raw producer/configuration/admission facts and '
    'the pinned test fixture literals, not captured as raw checkpoint constructor or getter bytes. '
    'The row chain and completed Plan are derived and bound by the emitted outputRoot, not a raw Plan return. '
    'No snapshot, Router root, complete graph, historical authority, deployment, consensus or full packet is verified.'
)
_HEX = r'0x[0-9a-fA-F]+'
_HASH = r'0x[0-9a-fA-F]{64}'
_CALL = re.compile(r'^([ │]*)(?:├─|└─) \[\d+\] (.+)$')
_RETURN = re.compile(r'^([ │]*)└─ ← \[(Return|Stop|Revert)\](?: (.*))?$')


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), 'checkpoint oracle ' + label + ' fields')


def _lines(raw):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_TRACE, 'checkpoint oracle trace byte bound')
    try:
        rows, offset = [], 0
        for index, line in enumerate(raw.splitlines(keepends=True)):
            rows.append((line.decode('utf-8').rstrip('\r\n'), offset, index + 1))
            offset += len(line)
        return rows
    except UnicodeDecodeError as exc:
        raise MuseumError('checkpoint oracle trace UTF-8') from exc


def _returns(lines, label):
    """Pair exact call labels with same-frame raw returns using tree depth."""
    found = {}
    for start, (line, _, call_line) in enumerate(lines):
        call = _CALL.fullmatch(line)
        if not call or not call[2].startswith(label):
            continue
        for text, offset, return_line in lines[start + 1:]:
            end = _RETURN.fullmatch(text)
            if end and len(end[1]) == len(call[1]) + 4:
                require(end[2] == 'Return' and re.fullmatch(_HEX, end[3] or '') is not None,
                    'checkpoint oracle raw returndata required: ' + label)
                value = end[3].lower()
                require(len(value) % 2 == 0, 'checkpoint oracle hex width')
                position = offset + len(text[:text.index(end[3])].encode('utf-8'))
                occurrence = {'callLine': str(call_line), 'returnLine': str(return_line),
                    'start': str(position), 'length': str(len(end[3]))}
                found.setdefault(value, []).append(occurrence)
                break
            sibling = _CALL.fullmatch(text)
            require(not sibling or len(sibling[1]) > len(call[1]), 'checkpoint oracle unclosed trace frame')
        else:
            raise MuseumError('checkpoint oracle missing raw return: ' + label)
    require(found, 'checkpoint oracle missing call: ' + label)
    return [{'hex': key, 'occurrences': occurrences} for key, occurrences in found.items()]


def _text_rows(lines, needle):
    return [{'line': str(index), 'start': str(offset), 'length': str(len(text.encode('utf-8'))), 'text': text}
        for text, offset, index in lines if needle in text]


def extract_trace(raw):
    """Return canonical extracted vector bytes, only from the exact pinned trace."""
    require(type(raw) is bytes and len(raw) == TRACE_BYTES and sha256(raw).hexdigest() == TRACE_SHA256,
        'checkpoint oracle original trace SHA-256/size differs')
    lines = _lines(raw)
    require(sum('[PASS] ' + TEST + '()' in row[0] for row in lines) == 1
        and '1 tests passed, 0 failed, 0 skipped' in lines[-1][0], 'checkpoint oracle successful native test')
    returns = {
        'source': _returns(lines, 'StreamViewPreservationCheckpointSourceV1::current()'),
        'observation': _returns(lines, 'StreamViewPreservationCheckpointTokenV1::observe('),
        'producerConfiguration': _returns(lines, 'StreamViewPreservationRendererV1::configuration()'),
        'producerConfigurationHash': _returns(lines, 'StreamViewPreservationRendererV1::configurationHash()'),
        'checkpointConfigurationHash': _returns(lines, 'StreamViewPreservationContentCheckpointV1::configurationHash()'),
        'preservationAdmission': _returns(lines, 'PolicyViewWire::fallback(0x8a5c7789'),
    }
    value = {'format': FORMAT, 'version': '1', 'traceSha256': TRACE_SHA256, 'traceBytes': str(len(raw)),
        'nativeSourceRevision': NATIVE_REVISION, 'consumerSourceRevision': CONSUMER_REVISION,
        'fixtureConfiguration': FIXTURE_CONFIGURATION,
        'checkpointDeployment': _text_rows(lines, 'new StreamViewPreservationContentCheckpointV1@'),
        'producerDeployment': _text_rows(lines, 'new StreamViewPreservationRendererV1@'),
        'returns': returns, 'events': {name: _text_rows(lines, 'emit ' + event + '(') for name, event in
            (('started', 'ViewCheckpointStarted'), ('appended', 'ViewCheckpointAppended'), ('sealed', 'ViewCheckpointSealed'))}}
    vector = dumps(value)
    require(len(vector) <= MAX_VECTOR, 'checkpoint oracle vector byte bound')
    verify_vector(vector)
    return vector


def _raw_return(value, count=None):
    require(type(value) is list and value and (count is None or len(value) == count),
        'checkpoint oracle distinct raw return denominator')
    result = []
    for row in value:
        _closed(row, ('hex', 'occurrences'), 'raw return')
        body = hex_bytes(row['hex'])
        require(0 < len(body) <= 32768 and type(row['occurrences']) is list and row['occurrences'],
            'checkpoint oracle raw return bounds')
        previous = 0
        for occurrence in row['occurrences']:
            _closed(occurrence, ('callLine', 'returnLine', 'start', 'length'), 'raw return provenance')
            first, last = uint(occurrence['callLine']), uint(occurrence['returnLine'])
            start, length = uint(occurrence['start']), uint(occurrence['length'])
            require(0 < previous < first < last if previous else 0 < first < last,
                'checkpoint oracle call/return order')
            require(length == len(row['hex']) and start + length <= TRACE_BYTES,
                'checkpoint oracle raw byte span')
            previous = last
        result.append(body)
    return result


def _texts(rows, count):
    require(type(rows) is list and len(rows) == count, 'checkpoint oracle event/deployment denominator')
    result = []
    prior = 0
    for row in rows:
        _closed(row, ('line', 'start', 'length', 'text'), 'trace text provenance')
        require(type(row['text']) is str and len(row['text'].encode('utf-8')) == uint(row['length'])
            and uint(row['start']) + uint(row['length']) <= TRACE_BYTES
            and prior < uint(row['line']), 'checkpoint oracle text byte span/order')
        prior = uint(row['line']); result.append(row['text'])
    return result


def _match(pattern, text, label):
    value = re.search(pattern, text)
    require(value is not None, 'checkpoint oracle ' + label + ' shape')
    return value.groups()


def verify_vector(raw):
    """Check supplied vector consistency; only verify_trace rechecks its raw provenance."""
    try:
        return _verify_vector(raw)
    except MuseumError:
        raise
    except (TypeError, KeyError, ValueError, IndexError, OverflowError) as exc:
        raise MuseumError('malformed checkpoint oracle vector') from exc


def _verify_vector(raw):
    value = loads(raw, maximum=MAX_VECTOR, canonical=True)
    _closed(value, ('format', 'version', 'traceSha256', 'traceBytes', 'nativeSourceRevision',
        'consumerSourceRevision', 'fixtureConfiguration', 'checkpointDeployment', 'producerDeployment',
        'returns', 'events'), 'vector')
    require(value['format'] == FORMAT and value['version'] == '1'
        and value['traceSha256'] == TRACE_SHA256 and uint(value['traceBytes']) == TRACE_BYTES
        and value['nativeSourceRevision'] == NATIVE_REVISION and value['consumerSourceRevision'] == CONSUMER_REVISION
        and value['fixtureConfiguration'] == FIXTURE_CONFIGURATION, 'checkpoint oracle provenance/configuration pins')
    ret = value['returns']
    _closed(ret, ('source', 'observation', 'producerConfiguration', 'producerConfigurationHash',
        'checkpointConfigurationHash', 'preservationAdmission'), 'returns')
    source, = decode((t.SOURCE,), _raw_return(ret['source'], 1)[0])
    producer_config, = decode((t.PRESERVATION_CONFIG,), _raw_return(ret['producerConfiguration'], 1)[0])
    producer_hash, = decode(('bytes32',), _raw_return(ret['producerConfigurationHash'], 1)[0])
    config_hash, = decode(('bytes32',), _raw_return(ret['checkpointConfigurationHash'], 1)[0])
    producer_binding, admission = decode((t.PRODUCER_BINDING, t.ADMISSION), _raw_return(ret['preservationAdmission'], 1)[0])
    cp_line = _texts(value['checkpointDeployment'], 1)[0]
    checkpoint, = _match(r'new StreamViewPreservationContentCheckpointV1@(0x[0-9a-fA-F]{40})$', cp_line, 'checkpoint deployment')
    producer_line = _texts(value['producerDeployment'], 1)[0]
    producer, = _match(r'new StreamViewPreservationRendererV1@(0x[0-9a-fA-F]{40})$', producer_line, 'producer deployment')
    checkpoint, producer = checkpoint.lower(), producer.lower()
    require(producer_binding[:3] == (producer, producer_binding[1], t.OUTPUT_PROFILE)
        and source[2] == producer_binding[3:] and source[3] == admission
        and source[2][:2] == (producer_config[0], producer_config[2])
        and source[2][4:] == producer_config[4:6]
        and admission[:3] == source[0][1][2][:3], 'checkpoint oracle original producer/admission binding')
    chain, core = producer_config[6], producer_config[0]
    config = (*producer_config[:4], *producer_config[:2], producer, producer_binding[1], producer_hash,
        chain, uint(FIXTURE_CONFIGURATION['readGas']), uint(FIXTURE_CONFIGURATION['servingGas']))
    scope = source[0][0][0]
    require(source[1][0:2] == producer_config[:2] and source[1][6] == chain
        and source[1][7] == scope and source[1][8] == source[0][1][1], 'checkpoint oracle Source5 identity')
    require(adoption_wire.source_hash(t.ADOPTION_PROFILE, chain, producer_config[2], source[0], source[1]) == source[0][2]
        and adoption_wire.record_hash(t.ADOPTION_PROFILE, chain, producer_config[2], core, source[0]) == source[0][3],
        'checkpoint oracle original adoption source/record hashes')
    require(wire.source_context_hash(chain, checkpoint, config, scope, source[0][3], source[0][2],
        source[1], source[2], source[3]) == source[4], 'checkpoint oracle Source5 context hash')
    events = value['events']; _closed(events, ('started', 'appended', 'sealed'), 'events')
    started = _texts(events['started'], 1)[0]
    key, adopted, salt = _match(r'emit ViewCheckpointStarted\(id: (' + _HASH + r'), adoptionRecord: (' + _HASH
        + r'), salt: (' + _HASH + r')\)$', started, 'started event')
    count = source[0][1][1][3]
    require(count == 3 and adopted == source[0][3] and wire.checkpoint_id(chain, checkpoint, config_hash,
        scope, source[4], count, salt) == key, 'checkpoint oracle native checkpoint ID')
    observations = [decode((t.OUTPUT, 'bytes', 'bytes'), body) for body in _raw_return(ret['observation'], count)]
    rows = tuple(item[0] for item in observations)
    require(tuple(row[0] for row in rows) == tuple(range(count))
        and all(rows[i][1] < rows[i+1][1] for i in range(count-1)), 'checkpoint oracle complete ordered rows')
    for row, json_raw, html in observations:
        require(row[8:] == (keccak256(json_raw), keccak256(html), len(json_raw), len(html)),
            'checkpoint oracle native JSON/HTML bytes differ')
        require((row[3], row[4], row[5]) in ((2, False, 1), (3, True, 2)), 'checkpoint oracle retained lifecycle')
    hashes = [wire.row_hash(chain, checkpoint, key, row) for row in rows]
    for index, text in enumerate(_texts(events['appended'], count)):
        event_key, ordinal, token, digest = _match(r'emit ViewCheckpointAppended\(id: (' + _HASH
            + r'), index: (\d+), tokenId: (\d+), rowHash: (' + _HASH + r')\)$', text, 'appended event')
        require((event_key, int(ordinal), int(token), digest) == (key, index, rows[index][1], hashes[index]),
            'checkpoint oracle original appended row hash')
    sealed = _texts(events['sealed'], 1)[0]
    event_key, out_root, tree_root, sealed_count = _match(r'emit ViewCheckpointSealed\(id: (' + _HASH
        + r'), outputRoot: (' + _HASH + r'), contentRoot: (' + _HASH + r'), tokenCount: (\d+)\)$', sealed, 'sealed event')
    require(event_key == key and int(sealed_count) == count, 'checkpoint oracle sealed identity')
    leaves = [wire.leaf_hash(chain, core, scope, adopted, row) for row in rows]
    require(wire.content_root(leaves) == tree_root, 'checkpoint oracle native contentRoot')
    plan = [scope, adopted, source[4], source[0][1][1][5], source[1][11], count, count, None, out_root, tree_root]
    plan[7] = wire.row_chain(chain, checkpoint, key, plan, rows)
    require(wire.output_root(chain, checkpoint, config_hash, key, plan) == out_root,
        'checkpoint oracle native outputRoot/row chain')
    require(uint(events['started'][0]['line']) < uint(events['appended'][0]['line'])
        and uint(events['appended'][-1]['line']) < uint(events['sealed'][0]['line']), 'checkpoint oracle event chronology')
    return {'format': FORMAT, 'traceSha256': TRACE_SHA256, 'traceBytes': str(TRACE_BYTES),
        'vectorKeccak256': keccak256(raw), 'checkpoint': checkpoint, 'chainId': str(chain), 'core': core,
        'checkpointId': key, 'sourceContextHash': source[4], 'checkpointConfigurationHash': config_hash,
        'rowCount': str(count), 'rowAbiBytes': str(len(encode((t.OUTPUT,), (rows[0],)))),
        'tokenIds': [str(row[1]) for row in rows], 'retainedBurnedTokenIds': [str(row[1]) for row in rows if row[4]],
        'sourceAbiBytes': str(len(encode((t.SOURCE,), (source,)))), 'rowHashes': hashes,
        'leafHashes': leaves, 'derivedRowChain': plan[7], 'outputRoot': out_root, 'contentRoot': tree_root,
        'sourceOccurrences': str(len(ret['source'][0]['occurrences'])),
        'rowObservationOccurrences': [str(len(row['occurrences'])) for row in ret['observation']],
        'claims': {'rawTraceRechecked': False, 'rawABIAndEmittedCommitmentsChecked': True,
            'nativeJSONHTMLBytesHashMatched': True, 'rawCheckpointConfigurationCaptured': False,
            'rawCheckpointPlanCaptured': False, 'nativePreservationRegistryRegistrationProven': False,
            'snapshotVerified': False, 'routerRootVerified': False, 'completeGraphVerified': False,
            'deploymentOrConsensusVerified': False, 'completePacket': False}, 'qualification': QUALIFICATION}


def verify_trace(raw):
    """Authenticate the supplied trace digest, then verify its extracted native vectors."""
    report = verify_vector(extract_trace(raw))
    report['claims']['rawTraceRechecked'] = True
    return report
