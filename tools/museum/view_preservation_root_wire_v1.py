"""Original Router VIEW root binding in the shared scoped history, not finality."""
from . import view_preservation_snapshot_types_v1 as t, view_preservation_snapshot_wire_v1 as snapshot
from . import view_preservation_output_types_v1 as output_types
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_abi import encode, decode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import event_matches, from_json, _closed
from .scoped_static_snapshot_wire import _uri, _type, scope_subject as scoped_subject
from .view_policy_membership_v2 import scope_subject as view_subject


def scope_subject(scope, context):
    return view_subject(scope, context) if scope[0] == 4 else scoped_subject(scope, context)


def definitions():
    return tuple({'name': name, 'id': schema_id(name), 'kind': kind, 'hash': keccak256(raw), 'bytes': raw}
        for name, kind, raw in (('STREAM_VIEW_PRESERVATION_CONTENT_ROOT_V1', 0, t.ROOT_SCHEMA_BYTES),
        ('STREAM_ABI_VIEW_PRESERVATION_CONTENT_ROOT_V1', 1, t.ROOT_CANON_BYTES)))


def state_hash(record, binding, context, graph):
    r = list(from_json(t.ROOT_RECORD, record)); r[15] = r[16] = ZERO; r[17] = 0
    return keccak256(encode(('bytes32', 'uint256', 'address', 'address', t.ROOT_RECORD, t.ROOT_BINDING),
        (t.ROOT_STATE_DOMAIN, uint(context['chainId']), graph['router']['address'], context['core'],
         tuple(r), from_json(t.ROOT_BINDING, binding))))


def record_hash(record, aggregate, context, graph):
    return keccak256(encode(('bytes32', 'uint256', 'address', 'address', t.ROOT_RECORD, t.AGGREGATE),
        (t.ROOT_RECORD_DOMAIN, uint(context['chainId']), graph['router']['address'], context['core'],
        from_json(t.ROOT_RECORD, record), from_json(t.AGGREGATE, aggregate))))


def next_aggregate(record, previous, revision, context, graph):
    r = from_json(t.ROOT_RECORD, record); scope = r[0][0]
    return (revision, keccak256(encode(('bytes32', 'uint256', 'address', 'address', 'uint256',
        'bytes32', 'uint64', 'bytes32', 'bytes32', 'bytes32'), (t.ROOT_CHAIN_DOMAIN, uint(context['chainId']),
        graph['router']['address'], context['core'], scope[1], previous, revision,
        scope_subject(scope, context), r[0][1], r[15]))))


def route_hash(context, graph):
    roles = ('core', 'artist', 'router', 'finality', 'provider', 'viewSnapshot')
    return keccak256(encode(('bytes32', 'uint256', ('address',)*6, ('bytes32',)*6, 'address', 'bytes32'),
        (t.ROOT_ROUTE_DOMAIN, uint(context['chainId']), tuple(graph[k]['address'] for k in roles),
        tuple(graph[k]['runtimeHash'] for k in roles), graph['metadata']['address'], graph['metadata']['runtimeHash'])))


def binding_for(source, configuration, context, graph):
    from .view_preservation_output_wire_v1 import definitions as output_definitions
    s = from_json(t.SOURCE, source); c = from_json(output_types.CHECKPOINT_CONFIG, configuration)
    h = s[5][0]
    leaf = next(row['hash'] for row in output_definitions() if row['id'] == output_types.LEAF_SCHEMA)
    pair = lambda role: (graph[role]['address'], graph[role]['runtimeHash'])
    return (t.ROOT_PROFILE, output_types.OUTPUT_PROFILE, s[3][0][3], output_types.ADOPTION_PROFILE,
        s[1][5], s[6][2], *pair('checkpoint'), h[0], h[1], *pair('outputManifest'),
        s[5][7], s[5][1][3], s[5][6], c[6], c[7], c[8], *s[3][2][2:6],
        leaf, keccak256(t.ROOT_SCHEMA_BYTES), keccak256(t.ROOT_CANON_BYTES),
        snapshot.SCHEMA_HASH, snapshot.PROFILE_HASH, snapshot.CANON_HASH)


def validate(value, context, graph, *, snapshot_value=None, output_value=None):
    try:
        return _validate(value, context, graph, snapshot_value=snapshot_value, output_value=output_value)
    except MuseumError: raise
    except (KeyError, ValueError, TypeError, IndexError, OverflowError) as exc:
        raise MuseumError('malformed original VIEW content root') from exc


def _validate(value, context, graph, *, snapshot_value, output_value):
    _closed(value, ('selectedRecordHash', 'head', 'aggregate', 'history'), 'VIEW root history')
    require(type(value['history']) is list and 0 < len(value['history']) <= 1024, 'VIEW root complete history bound')
    previous, heads, selected, prior_time = ZERO, {}, None, 0
    originals = {}
    if snapshot_value is not None:
        snapshot.validate(snapshot_value, context, graph)
        originals = {row['receipt'][0]: row for row in snapshot_value['history']}
    for index, row in enumerate(value['history']):
        _closed(row, ('recordHash', 'record', 'aggregate', 'binding'), 'VIEW root original')
        r, aggregate = from_json(t.ROOT_RECORD, row['record']), from_json(t.AGGREGATE, row['aggregate'])
        p, scope = r[0], r[0][0]
        require(scope[1] == uint(context['collectionId']) and scope[0] in (1, 2, 3, 4)
            and ((scope[0] == 1 and scope[2] > 0 and scope[3] == ZERO)
                or (scope[0] != 1 and scope[2] == 0 and scope[3] != ZERO)), 'VIEW root shared collection scope')
        require(p[1] == heads.get(scope, ZERO) and p[2] != ZERO and p[3] > 0 and p[4], 'VIEW root lineage/publication')
        _uri(p[4])
        require(r[1] != ZERO_ADDRESS and r[2] != ZERO and all(r[i] != ZERO for i in (3,4,5,7,8,10,14,15,16))
            and r[6] > 0 and r[9] > 0 and r[11] != ZERO_ADDRESS and r[12] in (7,8) and r[13] > 0
            and prior_time <= r[17] <= uint(context['timestamp'],64) and r[17] > 0,
            'VIEW root original authority/source/time')
        require(aggregate == next_aggregate(r, previous, index+1, context, graph)
            and row['recordHash'] == record_hash(r, aggregate, context, graph), 'VIEW root original hash/collection aggregate')
        if scope[0] == 4:
            b = from_json(t.ROOT_BINDING, row['binding'])
            from .view_preservation_output_wire_v1 import definitions as output_definitions
            leaf_hash = next(item['hash'] for item in output_definitions() if item['id'] == output_types.LEAF_SCHEMA)
            require(b[0] == t.ROOT_PROFILE and b[1] == output_types.OUTPUT_PROFILE
                and b[3] == output_types.ADOPTION_PROFILE and b[22] == leaf_hash
                and all(b[i] != ZERO_ADDRESS for i in (6,10,15,18,20))
                and all(b[i] != ZERO for i in (2,4,5,7,8,9,11,12,13,14,16,17,19,21))
                and b[23:] == (keccak256(t.ROOT_SCHEMA_BYTES),
                keccak256(t.ROOT_CANON_BYTES), snapshot.SCHEMA_HASH, snapshot.PROFILE_HASH, snapshot.CANON_HASH)
                and r[15] == state_hash(r,b,context,graph), 'VIEW root typed binding/state hash')
            if p[2] in originals:
                saved = originals[p[2]]; s = from_json(t.SOURCE,saved['source']); sr = from_json(t.RECEIPT,saved['receipt'])
                require(s[0] == scope and sr[3] == p[3] and sr[13] <= r[17]
                    and r[1:5] == (graph['viewSnapshot']['address'], graph['viewSnapshot']['runtimeHash'], sr[5], sr[7])
                    and r[5:11] == (s[5][0][9],s[1][3],s[5][1][3],s[2][3],s[2][4],s[2][5]),
                    'VIEW root original snapshot identity/content/Artist')
        else:
            require(row['binding'] is None, 'VIEW root foreign scoped binding must remain unprojected')
        if row['recordHash'] == value['selectedRecordHash']: selected = row
        heads[scope], previous, prior_time = row['recordHash'], aggregate[1], r[17]
    require(selected is not None and from_json(t.AGGREGATE,value['aggregate']) == aggregate,
        'VIEW root selected original/aggregate denominator')
    r = from_json(t.ROOT_RECORD, selected['record']); b = from_json(t.ROOT_BINDING,selected['binding'])
    require(r[0][0][0] == 4 and value['head'] == heads[r[0][0]], 'VIEW root selected scope/head')
    if snapshot_value is not None:
        require(r[0][2] == snapshot_value['selectedRecordHash'], 'VIEW root selected snapshot differs')
    if output_value is not None:
        require(snapshot_value is not None, 'VIEW root output join needs original snapshot')
        s = originals[r[0][2]]['source']
        require(b == binding_for(s,output_value['configuration']['checkpoint'],context,graph)
            and r[14] == route_hash(context,graph), 'VIEW root exact original route/output binding')
    return {'selectedRecordHash': value['selectedRecordHash'], 'record': selected['record'],
        'binding': selected['binding'], 'aggregate': selected['aggregate'], 'head': value['head'],
        'qualification': ['Original CONTENT_ROOT consent hash is retained, not reauthorized.',
            'Foreign scoped roots retain original outer records and state commitments for the shared aggregate.',
            'No reference, finality, current root eligibility, or consensus is inferred.']}


PUBLISHED = schema_id('ScopedContentRootPublished('+','.join(_type(k) for k in
    ('uint16','uint256','bytes32','bytes32',t.ROOT_RECORD,t.AGGREGATE))+')')
BINDING_PUBLISHED = schema_id('ViewPreservationContentRootBindingPublished('+','.join(_type(k) for k in
    ('uint16','uint256','bytes32','bytes32',t.ROOT_BINDING))+')')


def expected_events(value, context, graph):
    result = []
    for row in value['history']:
        r, ag = from_json(t.ROOT_RECORD,row['record']),from_json(t.AGGREGATE,row['aggregate'])
        topics = ('0x'+encode(('uint256',),(r[0][0][1],)).hex(),scope_subject(r[0][0],context),row['recordHash'])
        result.append({'kind':'view_root_published','address':graph['router']['address'],
            'topics':(PUBLISHED,*topics),'data':'0x'+encode(('uint16',t.ROOT_RECORD,t.AGGREGATE),(1,r,ag)).hex()})
        if row['binding'] is not None:
            result.append({'kind':'view_root_binding_published','address':graph['router']['address'],
                'topics':(BINDING_PUBLISHED,*topics),'data':'0x'+encode(('uint16',t.ROOT_BINDING),
                    (1,from_json(t.ROOT_BINDING,row['binding']))).hex()})
    return tuple(result)


class ViewPreservationRootReads:
    def _view_preservation_root(self, record_hash=None, scope=None):
        a, graph = self.a,self.graph
        scope = from_json(t.SCOPE,a['scope'] if scope is None else scope)
        record_hash = a['rootRecordHash'] if record_hash is None else record_hash
        host = graph['router']['address']
        history = self._history(host,[PUBLISHED,'0x'+encode(('uint256',),(uint(a['collectionId']),)).hex()])
        require(0 < len(history['logs']) <= 1024,'VIEW root complete collection event bound')
        rows = []
        for log in history['logs']:
            version,r,ag = decode(('uint16',t.ROOT_RECORD,t.AGGREGATE),hex_bytes(log['data']),maximum=8192)
            require(version == 1 and len(log['topics']) == 4,'VIEW root original event shape')
            key = log['topics'][3]
            require(log['address'] == host and log['topics'] == [PUBLISHED,
                '0x'+encode(('uint256',),(uint(a['collectionId']),)).hex(),scope_subject(r[0][0],a),key],
                'VIEW root original event subject')
            require(key != record_hash or r[0][0] == scope, 'VIEW root queried scope differs from original')
            require(self._one(host,'scopedContentRootRecord(bytes32)',t.ROOT_RECORD,('bytes32',),(key,),maximum=8192) == r,
                'VIEW root event/getter differs')
            binding = self._one(host,'viewPreservationContentRootBinding(bytes32)',t.ROOT_BINDING,('bytes32',),(key,))
            if r[0][0][0] != 4:
                require(encode((t.ROOT_BINDING,),(binding,)) == bytes(28*32),'VIEW foreign root has unexpected binding')
            rows.append({'recordHash':key,'record':json_values(r),'aggregate':json_values(ag),
                'binding':json_values(binding) if r[0][0][0] == 4 else None})
        current = self._one(host,'scopedContentRootHead((uint8,uint256,uint256,bytes32))','bytes32',(t.SCOPE,),(scope,))
        aggregate = self._one(host,'scopedContentRootAggregate(uint256)',t.AGGREGATE,('uint256',),(uint(a['collectionId']),))
        value = {'selectedRecordHash':record_hash,'head':current,'aggregate':json_values(aggregate),'history':rows}
        validate(value,a,graph)
        bindings = self._history(host,[BINDING_PUBLISHED,
            '0x'+encode(('uint256',),(uint(a['collectionId']),)).hex()])['logs']
        originals = [row for row in expected_events(value,a,graph)
            if row['kind'] == 'view_root_binding_published']
        require(len(bindings) == len(originals) and all(event_matches(
            (row['address'],row['topics'],row['data']), log)
            for row,log in zip(originals,bindings)), 'VIEW root complete binding event history differs')
        return value
