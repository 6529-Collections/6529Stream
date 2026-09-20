"""Compare the frozen native manifest trace with the original preservation codec.

This is a component byte oracle, not a public capture or finality verifier.
Forge's pretty tuple decoder is deliberately unused: overloaded selectors can
display an unrelated Plan type while raw library returndata stays intact.
"""
from hashlib import sha256
import re

from . import view_preservation_output_types_v1 as t
from . import view_preservation_output_wire_v1 as wire
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import Array, decode
from .independent_wire import require

NATIVE_SOURCE = '7701ad897c27257e5f082b310d62a6e35526cd0a'
CONSUMER_SOURCE = t.SOURCE_REVISION
TRACE_SHA256 = 'da3f59481edfa2c3fea7ca73c434de0e5323dc272585527630566161c7228924'
TRACE_BYTES = 256386
TRACE_LINES = 525
MAX_TRACE = 4 * 1024 * 1024
MAX_VECTOR = 128 * 1024
FORMAT = 'view_preservation_native_manifest_oracle_v1'


def _returns(lines, qualified):
    result = []
    for index, line in enumerate(lines):
        if qualified + '(' not in line:
            continue
        markers = [line.find(marker) for marker in ('├─', '└─') if marker in line]
        require(markers, 'native oracle trace call framing')
        level = min(markers)
        candidates = []
        for offset in range(index + 1, len(lines)):
            current = lines[offset]
            if current.find('└─ ← [Return]') == level + 4:
                candidates.append((offset + 1, current.split('← [Return]', 1)[1].strip()))
                break
            next_markers = [current.find(marker) for marker in ('├─', '└─') if marker in current]
            if next_markers and min(next_markers) <= level:
                break
        require(len(candidates) == 1, 'native oracle missing exact call return')
        result.append(candidates[0])
    require(result, 'native oracle required call absent')
    return result


def _unique_hex(rows):
    result = []
    for line, value in rows:
        require(re.fullmatch(r'0x[0-9a-fA-F]*', value) is not None,
            'native oracle needs raw hex, not decoded tuple displays')
        value = value.lower()
        if value not in result:
            result.append(value)
    return result


def extract_trace(raw):
    require(type(raw) is bytes and len(raw) == TRACE_BYTES
        and sha256(raw).hexdigest() == TRACE_SHA256, 'native manifest external trace pin/bound')
    lines = raw.decode('utf-8').splitlines()
    require(lines[0] == 'No files changed, compilation skipped'
        and any('1 tests passed, 0 failed' in line for line in lines), 'native manifest successful cached case')
    calls = {
        'partReturn': 'StreamViewPreservationManifestEncodingV1::part',
        'indexReturns': 'StreamViewPreservationManifestEncodingV1::index',
        'headerReturn': 'StreamViewPreservationManifestReadsV1::header',
        'rowsReturn': 'StreamViewPreservationManifestReadsV1::rows',
        'carrierReturns': 'StreamViewPreservationManifestReadsV1::carrier',
        'configurationHashReturn': 'StreamViewPreservationOutputManifestV1::configurationHash',
    }
    vector = {'format': FORMAT, 'nativeSource': NATIVE_SOURCE,
        'consumerSource': CONSUMER_SOURCE, 'traceSha256': TRACE_SHA256, 'lineNumbers': {}}
    for key, name in calls.items():
        rows = _returns(lines, name)
        values = _unique_hex(rows)
        vector['lineNumbers'][key] = [str(number) for number, _ in rows]
        multiple = key in ('carrierReturns', 'indexReturns')
        require(len(values) == (2 if multiple else 1), 'native manifest return denominator')
        if key == 'indexReturns':
            require([value.lower() for _, value in rows] == [values[0], values[1], values[0], values[0]],
                'native manifest complete/empty-preview index sequence')
        vector[key] = values if multiple else values[0]
    stored = [re.search(r'StreamSchemaDocumentStore::publishChunk\((0x[0-9a-fA-F]+)\)', line)
        for line in lines]
    vector['storePayloads'] = [match.group(1).lower() for match in stored if match is not None]
    vm = _returns(lines, 'VM::getRecordedLogs')
    require(len(vm) == 1, 'native manifest recorded log denominator')
    pattern = r'\(\[([0-9a-fA-Fx, ]+)\], (0x[0-9a-fA-F]*), (0x[0-9a-fA-F]{40})\)'
    logs = re.findall(pattern, vm[0][1])
    require(len(logs) == 2, 'native manifest raw recorded logs')
    vector['logs'] = [{'topics': [item.strip().lower() for item in topics.split(',')],
        'data': data.lower(), 'address': address.lower()} for topics, data, address in logs]
    vector['lineNumbers']['recordedLogs'] = [str(vm[0][0])]
    result = dumps(vector)
    verify_vector(result)
    return result


def verify_vector(raw):
    try:
        return _verify_vector(loads(raw, maximum=MAX_VECTOR, canonical=True))
    except MuseumError:
        raise
    except (ValueError, TypeError, IndexError, KeyError, OverflowError) as exc:
        raise MuseumError('malformed native manifest oracle vector') from exc


def _verify_vector(v):
    require(type(v) is dict and set(v) == {'format', 'nativeSource', 'consumerSource', 'traceSha256',
        'lineNumbers', 'partReturn', 'indexReturns', 'headerReturn', 'rowsReturn', 'carrierReturns',
        'configurationHashReturn', 'storePayloads', 'logs'}, 'native manifest closed vector')
    require(v['format'] == FORMAT and v['nativeSource'] == NATIVE_SOURCE
        and v['consumerSource'] == CONSUMER_SOURCE and v['traceSha256'] == TRACE_SHA256,
        'native manifest source/trace identity')
    counts = {'partReturn': 2, 'indexReturns': 4, 'headerReturn': 5, 'rowsReturn': 1,
        'carrierReturns': 8, 'configurationHashReturn': 2, 'recordedLogs': 1}
    require(type(v['lineNumbers']) is dict and set(v['lineNumbers']) == set(counts),
        'native manifest provenance line groups')
    for key, count in counts.items():
        lines = v['lineNumbers'][key]
        require(type(lines) is list and len(lines) == count, 'native manifest provenance line count')
        numbers = [uint(item) for item in lines]
        require(all(0 < item <= TRACE_LINES for item in numbers)
            and all(left < right for left, right in zip(numbers, numbers[1:])),
            'native manifest provenance line bounds/order')
    part = decode(('bytes',), hex_bytes(v['partReturn']), maximum=t.MAX_BYTES)[0]
    require(type(v['indexReturns']) is list and len(v['indexReturns']) == 2,
        'native manifest complete/preview index denominator')
    index, preview = [decode(('bytes',), hex_bytes(raw), maximum=t.MAX_BYTES)[0]
        for raw in v['indexReturns']]
    p = decode(t.PART_ENVELOPE, part, maximum=t.MAX_BYTES)
    ix = decode(t.INDEX_ENVELOPE, index, maximum=t.MAX_BYTES)
    header = decode((t.HEADER,), hex_bytes(v['headerReturn']))[0]
    rows = decode((Array(t.OUTPUT, t.PART_ROWS),), hex_bytes(v['rowsReturn']))[0]
    require(p[0] == t.PART_SCHEMA and ix[0] == t.INDEX_SCHEMA and p[1:6] == ix[1:6]
        and p[5] == header and p[7] == rows and p[6] == 0 and len(rows) == header[7] == 3,
        'native manifest complete header/row bytes differ')
    require(tuple(row[0] for row in rows) == (0, 1, 2)
        and tuple(row[1] for row in rows) == (11, 14, 17)
        and tuple(row[4] for row in rows) == (False, True, False), 'native manifest fixture identity/burn rows')
    require(len(part) == 672 + 992 * len(rows) and len(index) == 672 + 288,
        'native manifest canonical byte lengths')
    require(v['storePayloads'] == ['0x'+part.hex(), '0x'+index.hex()],
        'native manifest production encoding/Store payload differs')
    # These are the four actual envelope inputs used by the consumer encoders.
    # This does not reconstruct the other manifest configuration fields.
    projected = [None] * 12
    projected[0], projected[2], projected[4], projected[9] = p[2], p[3], p[4], p[1]
    require(wire.part_bytes(projected, header, p[6], rows) == part
        and wire.index_bytes(projected, header, ix[6], ix[7]) == index,
        'native manifest consumer byte grammar differs')
    empty_descriptor = ('0x' + '00'*32,) * 4 + (0,) * 5
    require(preview == wire.index_bytes(projected, header, ix[6], (empty_descriptor,))
        and preview[:672] == index[:672] and preview != index,
        'native manifest beginManifest empty-descriptor preview differs')
    require(type(v['carrierReturns']) is list and len(v['carrierReturns']) == 2,
        'native manifest carrier denominator')
    carrier_pairs = [decode((t.CARRIER, 'bytes'), hex_bytes(raw), maximum=t.MAX_BYTES)
        for raw in v['carrierReturns']]
    carriers = [pair[0] for pair in carrier_pairs]
    require(tuple(pair[1] for pair in carrier_pairs) == (part, index),
        'native manifest carrier raw bytes differ')
    require(len(carriers) == 2 and carriers[0][2] == carriers[1][2] == ix[6]
        and tuple(c[3:] for c in carriers) == ((keccak256(part),len(part)),(keccak256(index),len(index))),
        'native manifest original carrier/content hashes differ')
    advanced, verified = v['logs']
    require(set(advanced) == set(verified) == {'topics', 'data', 'address'}
        and advanced['address'] == verified['address'] and any(hex_bytes(advanced['address'], 20))
        and len(advanced['topics']) == 2 and len(verified['topics']) == 3
        and advanced['topics'][0] == wire.EVENTS['manifest_advanced']
        and verified['topics'][0] == wire.EVENTS['manifest_verified'] and verified['data'] == '0x'
        and advanced['topics'][1] == verified['topics'][2], 'native manifest exact raw event ABI')
    ordinal, part_key = decode(('uint16','bytes32'), hex_bytes(advanced['data']))
    config_hash = decode(('bytes32',), hex_bytes(v['configurationHashReturn']))[0]
    native_part = (header, carriers[0], 0, len(rows), rows[0][1], rows[-1][1])
    require(ordinal == 0 and len(ix[7]) == 1
        and wire.part_hash(p[1], advanced['address'], config_hash, native_part) == part_key
        and wire.descriptor(part_key,native_part) == ix[7][0], 'native manifest part hash/descriptor differs')
    plan = wire.manifest_plan_hash(p[1], advanced['address'], config_hash, header, carriers[1])
    chain = wire.part_chain(plan, header, ix[7])
    record = wire.manifest_record_hash(p[1], advanced['address'], config_hash, plan, chain)
    require(plan == advanced['topics'][1] and record == verified['topics'][1],
        'native manifest plan/part-chain/record hash differs')
    return {'nativeSource': NATIVE_SOURCE, 'consumerSource': CONSUMER_SOURCE,
        'traceSha256': TRACE_SHA256, 'rows': '3', 'partBytes': str(len(part)), 'indexBytes': str(len(index)),
        'partHash': part_key, 'planHash': plan, 'recordHash': record,
        'partContentHash': keccak256(part), 'indexContentHash': keccak256(index),
        'rawTraceRechecked': False, 'emptyDescriptorPreviewChecked': True,
        'rawNativeGrammarAndHashesMatch': True, 'fullConsumerCaptureVerified': False,
        'nativeSnapshotRootOrFinalityVerified': False,
        'qualification': 'Actual native manifest/encoding/Store/ArtifactCoverage with typed checkpoint, Archive and Finality boundaries. Header roots are supplied by that typed checkpoint; this lane does not prove their tree or renderer origins. Compact vector provenance requires the separately pinned full trace.'}


def verify_trace(raw):
    report = verify_vector(extract_trace(raw))
    report['rawTraceRechecked'] = True
    return report
