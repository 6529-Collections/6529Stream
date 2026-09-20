"""Original VIEW snapshot bytes and writer receipts; supplied-data consistency only."""
from . import view_preservation_snapshot_types_v1 as t
from . import view_policy_adoption_wire_v2 as adoption_wire
from . import view_policy_membership_v2 as member_wire
from . import view_policy_output_wire_v2 as policy_wire
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import from_json, _closed
from .scoped_static_snapshot_wire import _uri, _type

_DOCS = (
    ('STREAM_VIEW_PRESERVATION_SNAPSHOT_ABI_V1', 0, t.SNAPSHOT_SCHEMA_BYTES),
    ('STREAM_VIEW_PRESERVATION_SNAPSHOT_PROFILE_V1', 2, t.SNAPSHOT_PROFILE_BYTES),
    ('STREAM_ABI_VIEW_PRESERVATION_SNAPSHOT_V1', 1, t.SNAPSHOT_CANON_BYTES),
)
SCHEMA_HASH, PROFILE_HASH, CANON_HASH = map(keccak256,
    (t.SNAPSHOT_SCHEMA_BYTES, t.SNAPSHOT_PROFILE_BYTES, t.SNAPSHOT_CANON_BYTES))
QUALIFICATION = (
    'Original grants are retained as native classes 7/8; historical authorization is not reexecuted.',
    'Stored head and optional lock are observations, not a current source or renderer eligibility check.',
    'Historical renderer execution and full rendered JSON/HTML remain outside this supplied-data validation.',
    'A root-free snapshot is not reference evidence, Artist CONTENT_ROOT consent, or VIEW finality.',
)


def definitions():
    return tuple({'name': name, 'id': schema_id(name), 'kind': kind,
        'hash': keccak256(raw), 'bytes': raw} for name, kind, raw in _DOCS)


def _v(kind, value):
    return from_json(kind, value)


def source_hash(source, dependencies, context, graph):
    d, s = _v(t.DEPENDENCIES, dependencies), _v(t.SOURCE, source)
    return keccak256(encode(('bytes32', 'uint256', 'address', ('address',) * 10,
        ('bytes32',) * 10, t.SOURCE), (t.SOURCE_DOMAIN, uint(context['chainId']),
        graph['viewSnapshot']['address'], d[0], d[1], s)))


def payload(publication, receipt, source, dependencies, context, graph):
    p, r = list(_v(t.PUBLICATION, publication)), list(_v(t.RECEIPT, receipt))
    d = _v(t.DEPENDENCIES, dependencies)
    p[6] = ZERO
    for i in (0, 4, 5): r[i] = ZERO
    r[6], r[13] = 0, 0
    return encode(t.ENVELOPE, (t.PAYLOAD_DOMAIN, uint(context['chainId']),
        graph['viewSnapshot']['address'], d[0], d[1], tuple(p), tuple(r), _v(t.SOURCE, source)))


def record_hash(publication, receipt, context, graph):
    r = list(_v(t.RECEIPT, receipt)); r[0] = r[4] = ZERO
    return keccak256(encode(('bytes32', 'uint256', 'address', 'address', 'address', t.PUBLICATION, t.RECEIPT),
        (t.RECORD_DOMAIN, uint(context['chainId']), graph['viewSnapshot']['address'], context['core'],
        graph['metadata']['address'], _v(t.PUBLICATION, publication), tuple(r))))


def chain_hash(previous, publication, receipt, context, graph):
    p, r = _v(t.PUBLICATION, publication), _v(t.RECEIPT, receipt)
    return keccak256(encode(('bytes32', 'uint256', 'address', 'address', t.SCOPE, 'bytes32', 'uint64', 'bytes32'),
        (t.CHAIN_DOMAIN, uint(context['chainId']), graph['viewSnapshot']['address'], context['core'],
        p[0], previous, r[3], r[0])))


def _source(s, p, context, graph):
    scope = member_wire.scope_value(s[0], context)
    require(scope == p[0], 'VIEW snapshot source scope')
    facts, artist, observed, checkpoint, outputs, entropy = s[1:]
    original, policy, preservation, admission, context_hash = observed
    require(facts[0] == member_wire.scope_subject(scope, context) and 0 < facts[3] <= 16384
        and all(facts[i] != ZERO for i in (1, 2, 4, 5)) and facts[6:] == (0, ZERO),
        'VIEW snapshot original membership')
    require(artist[0] and artist[1] != ZERO_ADDRESS and artist[2] != ZERO
        and artist[3] != ZERO and artist[4] > 0 and artist[5] != ZERO and artist[6] != ZERO_ADDRESS
        and artist[7] != ZERO and artist[8] != ZERO and 0 < artist[9] <= artist[10]
        and artist[10] <= uint(context['timestamp'], 64) and artist[11] != ZERO,
        'VIEW snapshot locked Artist original')
    route = original[1][0]
    for offset, role in ((0, 'core'), (2, 'router'), (10, 'metadata'), (12, 'schemas'), (14, 'store')):
        require(route[offset:offset+2] == (graph[role]['address'], graph[role]['runtimeHash']),
            'VIEW snapshot adoption route differs')
    require(route[4:6] == artist[1:3] and route[16][:4] == (
        graph['views']['address'], graph['views']['runtimeHash'],
        graph['scopeMembership']['address'], graph['scopeMembership']['runtimeHash']),
        'VIEW snapshot original Artist/membership route')
    require(original[0][0] == scope and original[1][1] == facts
        and original[3] == p[5] != ZERO and original[2] != ZERO,
        'VIEW snapshot original adoption scope/record')
    require(original[2] == adoption_wire.source_hash(adoption_wire.t.V2_PROFILE,
        uint(context['chainId']), graph['router']['address'], original, policy)
        and original[3] == adoption_wire.record_hash(adoption_wire.t.V2_PROFILE,
        uint(context['chainId']), graph['router']['address'], context['core'], original),
        'VIEW snapshot native adoption hashes')
    require(policy[:2] == (context['core'], graph['core']['runtimeHash'])
        and policy[6] == uint(context['chainId']) and policy[7] == scope and policy[8] == facts
        and entropy[:4] == policy[9:13] and entropy[4]
        and 0 < entropy[3] == len(entropy[5]) <= min(t.MAX_POLICIES, facts[3]),
        'VIEW snapshot full original entropy binding')
    seen, prior = set(), -1
    for row in entropy[5]:
        policy_wire._rule(row)
        require(row[0] not in seen and prior < row[2] < facts[3]
            and row[12] == member_wire.policy_component(row, scope, context),
            'VIEW snapshot policy order/component')
        seen.add(row[0]); prior = row[2]
    require(entropy[5][0][2] == 0, 'VIEW snapshot first coordinator index')
    h = outputs[0]
    require(checkpoint[0] == scope and checkpoint[1] == original[3]
        and checkpoint[2] == context_hash != ZERO and checkpoint[3] == facts[5]
        and checkpoint[4] == entropy[2] and checkpoint[5] == checkpoint[6] == facts[3]
        and all(checkpoint[i] != ZERO for i in (7, 8, 9)), 'VIEW snapshot complete checkpoint')
    require(h[1] == keccak256(encode((t.CHECKPOINT_PLAN,), (checkpoint,)))
        and h[2:] == (scope, checkpoint[1], checkpoint[2], checkpoint[3], checkpoint[4],
            checkpoint[5], checkpoint[8], checkpoint[9])
        and h[0] != ZERO and outputs[1][2] == artist[3] and outputs[1][3] != ZERO
        and outputs[2] == outputs[3] == (facts[3]+63)//64 and outputs[4] == facts[3]
        and outputs[5] > 0 and outputs[6] != ZERO and outputs[7] == p[4] != ZERO,
        'VIEW snapshot exact complete output manifest')
    require(preservation[:2] == (context['core'], graph['router']['address'])
        and preservation[2:4] == original[1][2][3:5]
        and preservation[4:] == (graph['preservationAttribution']['address'], graph['preservationAttribution']['runtimeHash'])
        and admission[:3] == original[1][2][:3]
        and admission[0] != ZERO_ADDRESS and all(value != ZERO for value in admission[1:]),
        'VIEW snapshot preservation producer originals')


def validate(value, context, graph, *, adoption=None, membership=None, output_value=None):
    try:
        return _validate(value, context, graph, adoption=adoption, membership=membership, output_value=output_value)
    except MuseumError: raise
    except (KeyError, ValueError, TypeError, IndexError, OverflowError) as exc:
        raise MuseumError('malformed original VIEW snapshot') from exc


def _validate(value, context, graph, *, adoption, membership, output_value):
    _closed(value, ('dependencies', 'selectedRecordHash', 'current', 'history', 'lock'), 'VIEW snapshot')
    d = _v(t.DEPENDENCIES, value['dependencies'])
    require(d[:2] == (tuple(graph[k]['address'] for k in t.DEPENDENCY_ROLES),
        tuple(graph[k]['runtimeHash'] for k in t.DEPENDENCY_ROLES)) and d[2] == uint(context['chainId'])
        and 50000 <= d[3] <= (1 << 32)-1 and d[3] <= d[4] <= 16777216
        and d[3] <= d[5] <= 16777216, 'VIEW snapshot dependency graph/budgets')
    require(type(value['history']) is list and 0 < len(value['history']) <= t.MAX_HISTORY,
        'VIEW snapshot bounded full history')
    pins = {}
    for row in graph.values():
        address, digest = row['address'], row['runtimeHash']
        require(address != ZERO_ADDRESS and digest != ZERO and pins.setdefault(address, digest) == digest,
            'VIEW snapshot runtime conflict')
    selected, previous, previous_chain, previous_time, ids, scope = None, ZERO, ZERO, 0, set(), None
    total = 0
    for index, row in enumerate(value['history']):
        _closed(row, ('publication', 'receipt', 'source', 'payload', 'chunks'), 'VIEW snapshot original')
        p, r, s = _v(t.PUBLICATION, row['publication']), _v(t.RECEIPT, row['receipt']), _v(t.SOURCE, row['source'])
        current_scope = member_wire.scope_value(p[0], context)
        if scope is None: scope = current_scope
        require(current_scope == scope and p[1] != ZERO and p[1] not in ids and p[2] == previous
            and p[3] == index and r[2] == previous and r[3] == index+1
            and r[1] == member_wire.scope_subject(scope, context), 'VIEW snapshot lineage/snapshot ID')
        ids.add(p[1]); _uri(p[7])
        require(r[8] != ZERO_ADDRESS and r[9] in (7, 8) and r[11] in (7, 8)
            and r[10] > 0 and r[12] > 0 and 0 < p[8] <= r[13] <= uint(context['timestamp'], 64)
            and previous_time <= r[13] and p[9] != ZERO and r[14:] == (SCHEMA_HASH, PROFILE_HASH, CANON_HASH),
            'VIEW snapshot original writer grants/definitions/time')
        _source(s, p, context, graph)
        require(s[2][10] <= r[13] and s[3][0][10] <= r[13], 'VIEW snapshot source publication time')
        require(r[7] == p[6] == source_hash(s, d, context, graph), 'VIEW snapshot source commitment')
        raw = hex_bytes(row['payload']); total += len(raw)
        require(0 < len(raw) <= t.MAX_PAYLOAD and total <= 16*1024*1024
            and r[5] == keccak256(raw) and r[6] == len(raw)
            and raw == payload(p, r, s, d, context, graph), 'VIEW snapshot canonical original payload')
        require(r[0] == record_hash(p, r, context, graph)
            and r[4] == chain_hash(previous_chain, p, r, context, graph), 'VIEW snapshot record/chain hashes')
        require(type(row['chunks']) is list and len(row['chunks']) == (len(raw)+8191)//8192,
            'VIEW snapshot original chunk denominator')
        for offset, chunk in enumerate(row['chunks']):
            _closed(chunk, ('pointer', 'chunkHash', 'byteLength', 'runtime'), 'VIEW snapshot chunk')
            body = raw[offset*8192:(offset+1)*8192]; runtime = hex_bytes(chunk['runtime'])
            digest = keccak256(runtime); address = chunk['pointer']
            require(address != ZERO_ADDRESS and runtime == b'\0'+body and chunk['chunkHash'] == keccak256(body)
                and uint(chunk['byteLength'], 32) == len(body) and pins.setdefault(address, digest) == digest,
                'VIEW snapshot original Store carrier')
        if r[0] == value['selectedRecordHash']: selected = row
        previous, previous_chain, previous_time = r[0], r[4], r[13]
    require(selected is not None and _v(t.RECEIPT, value['current']) == _v(t.RECEIPT, value['history'][-1]['receipt']),
        'VIEW snapshot selected original/stored head')
    lock = _v(t.LOCK, value['lock'])
    require(lock == (ZERO, 0, ZERO, 0) or (lock[0] == previous and lock[1] == len(value['history'])
        and lock[2] != ZERO and previous_time <= lock[3] <= uint(context['timestamp'], 64)),
        'VIEW snapshot retained lock/head')
    s = _v(t.SOURCE, selected['source'])
    if adoption is not None:
        require(s[3][0] == _v(adoption_wire.t.RECORD, adoption['record'])
            and s[3][1] == _v(member_wire.VIEW_BINDING, adoption['policyBinding']), 'VIEW snapshot selected adoption differs')
    if membership is not None:
        require(s[1] == _v(t.MEMBERSHIP_FACTS, membership['facts'])
            and s[6] == _v(t.EVIDENCE, membership['evidence']), 'VIEW snapshot selected membership/policies differ')
    if output_value is not None:
        require(s[3] == _v(t.ADOPTION_SOURCE, output_value['checkpoint']['source'])
            and s[4] == _v(t.CHECKPOINT_PLAN, output_value['checkpoint']['plan'])
            and s[5] == _v(t.MANIFEST_PLAN, output_value['manifest']['plan']), 'VIEW snapshot selected outputs differ')
    return {'scope': json_values(scope), 'recordHash': value['selectedRecordHash'],
        'publication': selected['publication'], 'receipt': selected['receipt'], 'source': selected['source'],
        'head': previous, 'lock': value['lock'], 'qualification': list(QUALIFICATION)}


def _event(name, kinds):
    return schema_id(name+'('+','.join(_type(k) for k in kinds)+')')


PUBLISHED = _event('ViewPreservationSnapshotPublished', ('uint16', 'bytes32', 'bytes32', 'bytes32', t.PUBLICATION, t.RECEIPT))
LOCKED = _event('ViewPreservationSnapshotLocked', ('uint16', 'bytes32', t.LOCK))


def expected_events(value, context, graph):
    result = []
    for row in value['history']:
        p, r = _v(t.PUBLICATION, row['publication']), _v(t.RECEIPT, row['receipt'])
        result.append({'kind': 'view_snapshot_published', 'address': graph['viewSnapshot']['address'],
            'topics': (PUBLISHED, r[1], p[1], r[0]),
            'data': '0x'+encode(('uint16', t.PUBLICATION, t.RECEIPT), (1, p, r)).hex()})
    lock = _v(t.LOCK, value['lock'])
    if lock[2] != ZERO:
        result.append({'kind': 'view_snapshot_locked', 'address': graph['viewSnapshot']['address'],
            'topics': (LOCKED, value['current'][1]), 'data': '0x'+encode(('uint16', t.LOCK), (1, lock)).hex()})
    return tuple(result)
