"""Bounded original VIEW reference bytes and source joins, not a live capture.

The caller supplies retained facts. Complete preservation proof is mandatory;
neither a SourceFacts tuple nor the two samples can replace its full denominator.
"""
from hashlib import sha256

from . import view_preservation_reference_types_v1 as t
from . import native_view_preservation_wire_v1 as preservation
from . import view_preservation_snapshot_types_v1 as snapshot_types
from . import view_preservation_reference_inventory_v1 as inventory
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id, uint
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import from_json, _closed, _bytes, event_matches
from .public_prospective_reference_source import environment_bytes
from .view_policy_membership_v2 import scope_subject
from .scoped_static_snapshot_wire import _type
from .chain_rpc import quantity

MAX_HISTORY = 16
MAX_PAYLOAD = 524288
MAX_EVIDENCE = 64 * 1024 * 1024
DEPENDENCY_ROLES = ('core', 'metadata', 'schemas', 'store', 'router', 'viewSnapshot', 'externalCoverage')
GRAPH_KEYS = (*preservation.GRAPH_KEYS, 'viewReference', 'externalCoverage')
PREFIX = '6529STREAM_VIEW_PRESERVATION_REFERENCE_'
PUBLISHED = schema_id('ViewPreservationReferencePublished('+','.join(_type(k) for k in
    ('uint16','bytes32','bytes32','bytes32',t.RECEIPT,'string'))+')')
LOCKED = schema_id('ViewPreservationReferenceLocked('+','.join(_type(k) for k in
    ('uint16','bytes32',t.LOCK))+')')
CLAIMS = {'originalRecordPreimagesChecked': True, 'completePreservationProofRequired': True,
    'exactFirstLastSamplesChecked': True, 'originalEnvironmentInventoryBytesChecked': True,
    'rpcProvenanceAuthenticated': False, 'historicalAuthorityReauthorized': False,
    'freshNativeObservationProven': False, 'browserExecutionProven': False,
    'zipMembershipVerified': False, 'archiveCurrentPairProven': False,
    'governanceExecutionProven': False, 'finalityProven': False, 'completeAcquisition': False}


def _v(kind, value):
    result = from_json(kind, value)
    encode((kind,), (result,))
    return result


def _hash(name, kinds, values):
    return keccak256(encode(('bytes32', *kinds), (schema_id(name), *values)))


def source_hash(source, dependencies, context, graph):
    d = _v(t.DEPENDENCIES, dependencies)
    return _hash(PREFIX+'SOURCES_V1', ('uint256','address',('address',)*7,('bytes32',)*7,t.SOURCE),
        (uint(context['chainId']), graph['viewReference']['address'], d[0], d[1], _v(t.SOURCE,source)))


def payload(publication, receipt, source, environment, context, graph):
    p, r = _v(t.PUBLICATION, publication), _v(t.RECEIPT, receipt)
    o, fields = list(p[1]), list(r[1]); o[6] = ZERO
    for index in (0, 1, 6): fields[index] = ZERO
    for index in (7, 15): fields[index] = 0
    return encode(t.PAYLOAD, (schema_id(PREFIX+'PAYLOAD_V1'), uint(context['chainId']),
        graph['viewReference']['address'], (p[0],tuple(o)), (r[0],tuple(fields)),
        _v(t.SOURCE, source), environment))


def record_hash(publication, receipt, context, graph):
    r = _v(t.RECEIPT, receipt); fields = list(r[1]); fields[0] = fields[1] = ZERO
    return _hash(PREFIX+'RECORD_V1', ('uint256','address','address','address',t.PUBLICATION,t.RECEIPT),
        (uint(context['chainId']), graph['viewReference']['address'], context['core'],
         graph['metadata']['address'], _v(t.PUBLICATION,publication), (r[0],tuple(fields))))


def chain_hash(previous, receipt, context, graph):
    r = _v(t.RECEIPT, receipt)
    return _hash(PREFIX+'CHAIN_V1', ('uint256','address','address','bytes32','bytes32','uint64','bytes32'),
        (uint(context['chainId']), graph['viewReference']['address'], context['core'], r[0],previous,r[1][5],r[1][0]))


def lock_transition(scope, receipt, context, graph):
    s,r = _v(t.SCOPE,scope),_v(t.RECEIPT,receipt)
    action = _hash(PREFIX+'LOCK_SCOPE_V1', ('uint256','address','address',t.SCOPE,'bytes32'),
        (uint(context['chainId']),graph['viewReference']['address'],context['core'],s,r[0]))
    return (action, *(keccak256(encode(('bytes32','bytes32','uint64','bool'),
        (action,r[1][0],r[1][5],flag))) for flag in (False,True)))


def component_hash(scope, receipt, lock, context, graph):
    return _hash('6529STREAM_LOCKED_VIEW_PRESERVATION_REFERENCE_COMPONENT_V1',
        ('uint256','address','address',t.SCOPE,t.RECEIPT,t.LOCK),
        (uint(context['chainId']),graph['viewReference']['address'],context['core'],
         _v(t.SCOPE,scope),_v(t.RECEIPT,receipt),_v(t.LOCK,lock)))


def decode_record_return(raw):
    return decode((t.PUBLICATION,t.RECEIPT), _bytes(raw,524960,'VIEW reference record return'),maximum=524960)


def decode_source_return(raw):
    return decode((t.SOURCE,), _bytes(raw,MAX_PAYLOAD,'VIEW reference source return'),maximum=MAX_PAYLOAD)[0]


def decode_payload(raw):
    return decode(t.PAYLOAD, _bytes(raw,MAX_PAYLOAD,'VIEW reference payload'),maximum=MAX_PAYLOAD)


def _definitions(rows):
    definitions = t.definitions()
    require(type(rows) is list and len(rows) == len(definitions), 'VIEW reference definition denominator')
    by_id = {}
    for row in rows:
        _closed(row, ('id','kind','status','hash','bytes'), 'VIEW reference definition')
        require(row['id'] not in by_id, 'VIEW reference duplicate definition')
        by_id[row['id']] = row
    for expected in definitions:
        row = by_id.get(expected['id'])
        require(row is not None and uint(row['kind'],8) == expected['kind'] and row['status'] == '1'
            and row['hash'] == expected['hash'] and _bytes(row['bytes'],MAX_PAYLOAD,'definition') == expected['bytes'],
            'VIEW reference exact ACTIVE native definition')


def _coverage(c, identity, context, graph, artist, role):
    """Original external-object domains shared by native reference producers."""
    definitions={row['name']:row for row in t.definitions()}
    schema=definitions['STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1' if role=='zip' else 'STREAM_REFERENCE_PNG_OBJECT_V1']
    formats=definitions['STREAM_REFERENCE_NATIVE_FORMATS_V1']
    host=graph['externalCoverage']['address'];chain=uint(context['chainId'])
    require(all(v != ZERO for i,v in enumerate(c) if i != 6) and c[6] > 0
        and c[2] == artist and c[7] != c[8] and c[9] != c[10]
        and c[14] == schema_id('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1')
        and c[0] == _hash('6529STREAM_EXTERNAL_COVERAGE_V1',('uint256','address',t.COVERAGE),
            (chain,host,(ZERO,*c[1:]))), 'VIEW reference original external coverage hash')
    obj=identity
    require(obj[0] == artist and obj[1] == schema['id'] and obj[2] == schema_id('RAW_BYTES')
        and c[2:7] == (obj[0],obj[3],obj[4],obj[5],obj[6])
        and obj[7] == schema_id('IANA:application/zip' if role=='zip' else 'IANA:image/png')
        and obj[8:] == (formats['id'],formats['hash'])
        and c[1] == _hash('6529STREAM_EXTERNAL_OBJECT_V1',('uint256','address','address',t.OBJECT),
            (chain,host,context['core'],obj)), 'VIEW reference original Archive object/role')


def _position(event):
    return tuple(quantity(event['log'][key]) for key in ('blockNumber','transactionIndex','logIndex'))


def _event_coherence(events, context):
    source_number,source_stamp=uint(context['blockNumber'],64),uint(context['timestamp'],64)
    blocks={source_number:(context['blockHash'],source_stamp)}
    hashes={context['blockHash']:source_number};slots={};transactions={};positions={};block_logs={}
    for event in events:
        log=event['log'];pos=_position(event);stamp=uint(event['timestamp'],64)
        identity=(log['address'],tuple(log['topics']),log['data'],log['blockHash'],log['transactionHash'],log['removed'])
        require(blocks.setdefault(pos[0],(log['blockHash'],stamp)) == (log['blockHash'],stamp)
            and hashes.setdefault(log['blockHash'],pos[0]) == pos[0]
            and slots.setdefault(pos[:2],log['transactionHash']) == log['transactionHash']
            and transactions.setdefault(log['transactionHash'],(pos[:2],log['blockHash'])) == (pos[:2],log['blockHash'])
            and positions.setdefault(pos,identity) == identity and block_logs.setdefault((pos[0],pos[2]),pos) == pos,
            'VIEW reference global source/publication block or transaction conflict')
    times=[entry[1] for _,entry in sorted(blocks.items())]
    require(times == sorted(times), 'VIEW reference global source/publication timestamp order')
    last={}
    for pos in sorted(positions):
        require(last.get(pos[0],-1) < pos[2], 'VIEW reference global block log order')
        last[pos[0]]=pos[2]


def _source_proof(row, p, r, f, context, graph, publication_event, source_events, adoption_rows):
    proof = row['sourceProof']
    _closed(proof, ('bundle','events'), 'VIEW reference complete source proof')
    subgraph = {role:graph[role] for role in preservation.GRAPH_KEYS}
    result = preservation.validate_bundle(proof['bundle'],context,subgraph)
    preservation.validate_event_join(proof['bundle'],context,subgraph,proof['events'])
    snap,root = result['snapshot'],result['root']
    require(_v(snapshot_types.RECEIPT,snap['receipt']) == f[1]
        and _v(snapshot_types.SOURCE,snap['source']) == f[2]
        and root['selectedRecordHash'] == f[3]
        and _v(snapshot_types.ROOT_RECORD,root['record']) == f[4]
        and _v(snapshot_types.ROOT_BINDING,root['binding']) == f[5],
        'VIEW reference exact original snapshot/root source proof')
    require(tuple(proof['bundle']['scope']) == tuple(json_values(p[0]))
        and f[1][0] == p[1][4] and f[1][3] == p[1][5]
        and f[1][13] <= f[4][17] <= r[1][15], 'VIEW reference original snapshot/root sequence')
    # Exact event positions distinguish same-block publications. The complete
    # supplied history is still not an authenticated historical RPC capture.
    from .view_preservation_snapshot_wire_v1 import PUBLISHED as SNAPSHOT_PUBLISHED
    from .view_preservation_root_wire_v1 import PUBLISHED as ROOT_PUBLISHED
    prior = [event for event in source_events if _position(event) < _position(publication_event)]
    for signature,host,scope_topic,record_topic,expected,label in (
            (SNAPSHOT_PUBLISHED,graph['viewSnapshot']['address'],1,3,f[1][0],'snapshot'),
            (ROOT_PUBLISHED,graph['router']['address'],2,3,f[3],'root')):
        eligible = [event for event in prior if event['log']['address'] == host
            and event['log']['topics'][0] == signature and event['log']['topics'][scope_topic] == f[0]]
        require(eligible and eligible[-1]['log']['topics'][record_topic] == expected,
            'VIEW reference '+label+' missing or superseded before publication')
    chosen = f[2][3][0][3]
    adopted = {item['record'][3] for item in adoption_rows
        if _v(t.SCOPE,item['record'][0][0]) == p[0]}
    eligible = [event for event in prior if event['log']['address'] == graph['router']['address']
        and len(event['log']['topics']) == 4 and event['log']['topics'][3] in adopted]
    require(eligible and eligible[-1]['log']['topics'][3] == chosen,
        'VIEW reference adoption superseded before publication')
    return proof['bundle']['output']['checkpoint']['outputs']


def _samples(row, p, r, f, outputs, context, graph):
    captures,env,samples = p[1][7],p[1][8],f[7]
    count,artist = f[2][1][3],f[2][2][3]
    require(len(outputs) == count and len(samples) == len(captures) == (1 if count == 1 else 2),
        'VIEW reference complete output/first-last denominator')
    require(type(row['objects']) is list and len(row['objects']) <= 3, 'VIEW reference bounded archive objects')
    objects = {}
    for item in row['objects']:
        _closed(item, ('objectHash','identity'), 'VIEW reference archive object')
        require(item['objectHash'] not in objects, 'VIEW reference duplicate archive object')
        objects[item['objectHash']] = _v(t.OBJECT,item['identity'])
    _coverage(f[6],objects[f[6][1]],context,graph,artist,'zip')
    require(f[6][:2] == (env[1],env[0]), 'VIEW reference environment archive binding')
    used = {f[6][1]}
    from .view_preservation_output_types_v1 import OUTPUT
    for ordinal,(capture,sample) in enumerate(zip(captures,samples)):
        index,output,coverage = sample
        expected = 0 if ordinal == 0 else count-1
        require(index == expected and output == _v(OUTPUT,outputs[index]),
            'VIEW reference sample differs from complete checkpoint row')
        require(output[:3] == (index,capture[0],capture[1]) and output[8:10] == capture[2:4]
            and output[11] == capture[4] and 0 < len(capture[5]) == capture[4] <= 262144
            and keccak256(capture[5]) == capture[3]
            and '0x'+sha256(capture[5]).hexdigest() == capture[8]
            and capture[9][0] != ZERO and capture[9][0] == capture[9][1]
            and capture[10] == env[2] and 0 < capture[11] <= r[1][15],
            'VIEW reference exact original HTML/sample facts')
        require(coverage[:2] == (capture[7],capture[6]) and coverage[4] == capture[9][0],
            'VIEW reference PNG/repeat capture binding')
        _coverage(coverage,objects[coverage[1]],context,graph,artist,'png');used.add(coverage[1])
    require(used == set(objects), 'VIEW reference archive object denominator')
    _closed(row['fileInventories'], ('package','platform'), 'VIEW reference file inventories')
    for name,relative,rows in (('package',True,env[12]),('platform',False,env[13])):
        item = row['fileInventories'][name]
        inventory.validate(item,context,graph['viewReference']['address'])
        require(item['relative'] is relative and _v(t.ENVIRONMENT, p[1][8])[12 if relative else 13]
            == _v(inventory.FILES,item['rows']), 'VIEW reference environment file inventory join')


def validate(value, context, graph):
    try:
        require(len(dumps(value)) <= MAX_EVIDENCE, 'VIEW reference total evidence bound')
        return _validate(value,context,graph)
    except MuseumError: raise
    except (KeyError,ValueError,TypeError,IndexError,OverflowError) as exc:
        raise MuseumError('malformed VIEW preservation reference evidence') from exc


def _validate(value, context, graph):
    _closed(value, ('sourceRevision','dependencies','definitions','scope','selectedRecordHash','current','history','lock','events'),
        'VIEW reference evidence')
    require(value['sourceRevision'] == t.SOURCE_REVISION and set(graph) == set(GRAPH_KEYS),
        'VIEW reference exact revision/graph')
    preservation.context_graph(context,{role:graph[role] for role in preservation.GRAPH_KEYS})
    pins = {}
    for pair in graph.values():
        _closed(pair, ('address','runtimeHash'), 'VIEW reference graph pin')
        require(any(hex_bytes(pair['address'],20)) and any(hex_bytes(pair['runtimeHash'],32))
            and pins.setdefault(pair['address'],pair['runtimeHash']) == pair['runtimeHash'],
            'VIEW reference graph runtime identity')
    d = _v(t.DEPENDENCIES,value['dependencies'])
    require(d[:2] == (tuple(graph[k]['address'] for k in DEPENDENCY_ROLES),
        tuple(graph[k]['runtimeHash'] for k in DEPENDENCY_ROLES)) and d[2] == uint(context['chainId'])
        and 50000 <= d[3] <= d[4] <= d[5] <= 16777216 and d[3] <= d[6] <= 16777216,
        'VIEW reference exact dependencies/bounded gas')
    _definitions(value['definitions'])
    scope = preservation.scope_value(value['scope']);subject = scope_subject(scope,context)
    require(scope[1] == uint(context['collectionId']), 'VIEW reference collection')
    require(type(value['history']) is list and 0 < len(value['history']) <= MAX_HISTORY,
        'VIEW reference bounded complete history')
    events = validate_event_join(value,context,graph)
    source_events=[event for row in value['history'] for event in row['sourceProof']['events']]
    _event_coherence([*value['events'],*source_events],context)
    source_events=sorted({_position(event):event for event in source_events}.values(),key=_position)
    adoption_rows=[item for row in value['history'] for item in row['sourceProof']['bundle']['adoption']['history']]
    previous,chain,stamp,ids,selected,total = ZERO,ZERO,0,set(),None,0
    for index,row in enumerate(value['history']):
        _closed(row, ('publication','receipt','source','recordReturn','sourceReturn','payload','environment',
            'objects','fileInventories','sourceProof'), 'VIEW reference original')
        p,r,f = _v(t.PUBLICATION,row['publication']),_v(t.RECEIPT,row['receipt']),_v(t.SOURCE,row['source'])
        o,s = p[1],r[1]
        require(decode_record_return(row['recordReturn']) == (p,r)
            and decode_source_return(row['sourceReturn']) == f, 'VIEW reference original getter bytes')
        require(p[0] == scope and r[0] == f[0] == subject and o[0] == s[2] == scope[1]
            and o[1] == s[3] != ZERO and o[1] not in ids and o[2] == s[4] == previous
            and o[3] == index and s[5] == index+1 and o[4:7] == (s[9],s[10],s[8]),
            'VIEW reference original lineage/receipt identity')
        require(s[9] != ZERO and s[10] > 0 and s[11] != ZERO_ADDRESS and s[12] in (3,8) and s[13] > 0
            and o[10] == s[14] and 0 < s[14] <= s[15] <= uint(context['timestamp'],64)
            and stamp <= s[15] and o[11] == s[16] != ZERO
            and s[17:] == (t.SCHEMA_HASH,t.PROFILE_HASH,t.CANON_HASH),
            'VIEW reference original authority/time/definitions')
        from .public_prospective_reference_source import safe_uri
        require(safe_uri(o[9]), 'VIEW reference manifest URI')
        require(s[8] == source_hash(f,d,context,graph), 'VIEW reference original source hash')
        env = _bytes(row['environment'],MAX_PAYLOAD,'VIEW reference environment')
        require(environment_bytes(o[8]) == env and keccak256(env) == o[8][2] and len(env) == o[8][3],
            'VIEW reference exact canonical environment')
        raw = _bytes(row['payload'],MAX_PAYLOAD,'VIEW reference payload');total += len(raw)
        require(total <= 8*1024*1024 and raw == payload(p,r,f,env,context,graph)
            and s[6:8] == (keccak256(raw),len(raw)), 'VIEW reference original canonical payload')
        decode_payload(raw)
        require(s[0] == record_hash(p,r,context,graph) and s[1] == chain_hash(chain,r,context,graph),
            'VIEW reference original record/chain hashes')
        outputs = _source_proof(row,p,r,f,context,graph,events[index],source_events,adoption_rows)
        _samples(row,p,r,f,outputs,context,graph)
        if s[0] == value['selectedRecordHash']: selected = row
        previous,chain,stamp = s[0],s[1],s[15];ids.add(o[1])
    require(selected is not None and _v(t.RECEIPT,value['current']) == r, 'VIEW reference selected record/current head')
    lock = _v(t.LOCK,value['lock'])
    require(lock == (ZERO,0,ZERO,0) or (lock[:2] == (previous,len(value['history']))
        and lock[2] != ZERO and stamp <= lock[3] <= uint(context['timestamp'],64)), 'VIEW reference lock/head/time')
    return {'sourceRevision':t.SOURCE_REVISION,'scope':value['scope'],'selectedRecordHash':value['selectedRecordHash'],
        'head':previous,'recordChainHash':chain,'recordCount':str(len(value['history'])),
        'lock':value['lock'],'componentDataHash':component_hash(scope,r,lock,context,graph) if lock[2] != ZERO else None,
        'claims':dict(CLAIMS),'qualification':'Supplied original bytes and complete preservation proofs are checked offline. '
            'Definition ACTIVE states and runtime pins are supplied facts; no RPC, historical authority, fresh native '
            'observation, current Archive pair, browser/ZIP execution, governance or full finality is authenticated. '
            'The separate native component traces are not joined to this reference evidence.'}


def expected_events(value, context, graph):
    result = []
    for row in value['history']:
        p,r = _v(t.PUBLICATION,row['publication']),_v(t.RECEIPT,row['receipt'])
        result.append({'address':graph['viewReference']['address'],'topics':(PUBLISHED,r[0],p[1][1],r[1][0]),
            'data':'0x'+encode(('uint16',t.RECEIPT,'string'),(1,r,p[1][9])).hex()})
    lock = _v(t.LOCK,value['lock'])
    if lock[2] != ZERO:
        result.append({'address':graph['viewReference']['address'],'topics':(LOCKED,value['current'][0]),
            'data':'0x'+encode(('uint16',t.LOCK),(1,lock)).hex()})
    return result


def validate_event_join(value, context, graph):
    expected = expected_events(value,context,graph)
    events = value['events']
    require(type(events) is list and len(events) == len(expected), 'VIEW reference event denominator')
    previous,blocks,txs,slots,last_block_log = None,{uint(context['blockNumber']):(context['blockHash'],uint(context['timestamp']))}, {},{},{}
    for index,(event,descriptor) in enumerate(zip(events,expected)):
        _closed(event, ('log','timestamp'), 'VIEW reference event wrapper')
        log=event['log'];pos=_position(event);stamp=uint(event['timestamp'],64)
        require((previous is None or previous < pos) and pos[0] <= uint(context['blockNumber'],64)
            and log['removed'] is False and any(hex_bytes(log['blockHash'],32))
            and any(hex_bytes(log['transactionHash'],32))
            and event_matches((descriptor['address'],descriptor['topics'],descriptor['data']),log),
            'VIEW reference exact publication/lock log and order')
        require(blocks.setdefault(pos[0],(log['blockHash'],stamp)) == (log['blockHash'],stamp)
            and txs.setdefault(log['transactionHash'],(pos[:2],log['blockHash'])) == (pos[:2],log['blockHash'])
            and slots.setdefault(pos[:2],log['transactionHash']) == log['transactionHash']
            and last_block_log.get(pos[0],-1) < pos[2], 'VIEW reference event block/transaction conflict')
        wanted = uint(value['history'][index]['receipt'][1][15]) if index<len(value['history']) else uint(value['lock'][3])
        require(stamp == wanted <= uint(context['timestamp'],64), 'VIEW reference event receipt time')
        previous=pos;last_block_log[pos[0]]=pos[2]
    return events[:len(value['history'])]
