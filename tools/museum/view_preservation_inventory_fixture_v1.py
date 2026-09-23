"""Complete synthetic original VIEW bytes for the fd861 inventory reader.

All commitments are rebuilt from retained bytes. This is an offline fixture,
not a renderer execution, native deployment, or source authentication claim.
"""
from copy import deepcopy
from hashlib import sha256

from .canonical import dumps, hex_bytes, keccak256, schema_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, generic_hash, json_values
from .native_finality_wire import from_json
from . import view_preservation_inventory_types_v1 as t
from . import view_preservation_inventory_wire_v1 as w
from . import view_preservation_inventory_sources_v1 as sources
from . import view_preservation_inventory_items_v1 as items
from . import view_preservation_adoption_types_v1 as at
from . import view_preservation_adoption_wire_v1 as aw
from . import view_policy_adoption_types_v2 as vt
from . import view_policy_adoption_wire_v2 as vw
from . import view_policy_membership_v2 as mw
from . import view_preservation_reference_types_v1 as rt
from . import view_preservation_reference_wire_v1 as rw
from .test_view_preservation_reference_wire_v1 import supplied as reference_supplied, reseal as seal_reference
from .test_view_preservation_adoption_wire_v1 import _bind_original_registry
from .test_view_preservation_output_wire_v1 import reseal as seal_output
from .test_view_preservation_snapshot_wire_v1 import supplied as snapshot_supplied
from .test_view_preservation_root_wire_v1 import supplied as root_supplied
from .test_view_preservation_root_wire_v1 import reseal as seal_root
from .view_preservation_fixture_v1 import ViewPreservationFixtureV1
from .test_public_chain_history import PublicHistoryFixture
from .object_inventory_source import reconstruct_segment, append_segment


def A(number): return '0x' + format(number, '040x')
def H(label): return schema_id('complete VIEW inventory fixture ' + str(label))


def document(raw, kind=0):
    chunks = [raw[i:i+8192] for i in range(0, len(raw), 8192)]
    return {'facts': json_values((True, kind, 1, keccak256(raw), schema_id('RAW_BYTES'),
        ZERO, len(raw), len(chunks), H('document sequence'))),
        'chunks': [{'hash': keccak256(chunk), 'bytes': '0x'+chunk.hex()} for chunk in chunks]}


def _empty_image(row, context, graph):
    """Reseal the actual retained declaration and source, not only its locator."""
    d = row['declaration']; record = row['record']; source = record[1]
    payload = list(decode((vt.PAYLOAD,), hex_bytes(d['viewPayload']))[0]); payload[3] = ''
    raw = encode((vt.PAYLOAD,), (tuple(payload),))
    d['viewPayload'] = '0x'+raw.hex(); d['manifest'][3] = keccak256(raw)
    manifest_raw = encode(('uint256', 'uint64', 'bytes32', vt.VIEW_MANIFEST),
        (int(context['collectionId']), int(d['receipt'][2]), d['receipt'][3],
         from_json(vt.VIEW_MANIFEST, d['manifest'])))
    d['manifestPayload'] = '0x'+manifest_raw.hex()
    d['manifestCarrier'].update(runtime='0x'+(b'\0'+manifest_raw).hex(), codeHash=keccak256(b'\0'+manifest_raw))
    d['record'][2][1] = keccak256(manifest_raw)
    record[0][2] = generic_hash(int(context['chainId']), graph['views']['address'], context['core'],
        int(context['collectionId']), d['receipt'][4], from_json(vt.COLLECTION_RECORD, d['record']))
    source[6], source[8], source[9] = keccak256(manifest_raw), keccak256(raw), str(len(raw))
    parts = [raw[i:i+8192] for i in range(0, len(raw), 8192)]
    assert len(parts) == len(d['payloadChunks'])
    for index, (part, carrier) in enumerate(zip(parts, d['payloadChunks'])):
        carrier.update(runtime='0x'+(b'\0'+part).hex(), codeHash=keccak256(b'\0'+part))
        source[11][index] = keccak256(part)


def _registration(adoption, context, graph, documents):
    """Give the original renderer and preservation admission real doc preimages."""
    selected = next(row for row in adoption['history'] if row['record'][3] == adoption['selectedRecordHash'])
    manifest = selected['declaration']['renderer']['manifest']
    renderer_docs = (
        ('STREAM_ADOPTED_POLICY_VIEW_OUTPUT_V2', vw.V2_OUTPUT_SCHEMA_BYTES),
        ('fixture renderer compatibility', b'{"compatibility":"synthetic original"}'),
        ('fixture renderer manifest', b'{"renderer":"synthetic original"}'),
        ('fixture renderer analysis', b'{"analysis":"supplied fixture only"}'),
        ('fixture renderer golden', b'{"golden":"supplied fixture only"}'))
    for name, raw in renderer_docs: documents[schema_id(name)] = document(raw)
    manifest[7] = keccak256(renderer_docs[2][1])
    for row in adoption['history']:
        if row['profile'] == vt.V2_PROFILE:
            row['declaration']['renderer']['manifest'] = deepcopy(manifest)
    registry = adoption['preservation']['registry']
    registration = (selected['record'][1][2][3], from_json(vt.RENDERER_MANIFEST, manifest),
        *(schema_id(name) for name, raw in renderer_docs))
    raw_hash = keccak256(encode(('bytes32','uint256','address','address','bytes32','bytes32',
        sources.RENDERER_REGISTRATION, at.READS), (schema_id('6529STREAM_RENDERER_REGISTRATION_V1'),
        int(context['chainId']), graph['rendererRegistry']['address'], graph['schemas']['address'],
        graph['schemas']['runtimeHash'], registry['targetSetHash'], registration,
        from_json(at.READS, registry['originalReads']))))
    registry['version'][4] = raw_hash
    registry['version'][6:8] = [keccak256(renderer_docs[i][1]) for i in (3,4)]
    _bind_original_registry(adoption, context, graph, raw_hash, registry['version'][5])
    preservation = adoption['preservation']; saved = registry['record']
    extra = (('fixture preservation schema', b'{"preservation":"schema"}'),
        ('fixture preservation analysis', b'{"preservation":"analysis"}'),
        ('fixture preservation golden', b'{"preservation":"golden"}'))
    for name, raw in extra: documents[schema_id(name)] = document(raw)
    saved[0][2:5] = [schema_id(name) for name, raw in extra]
    saved[3:5] = [keccak256(extra[i][1]) for i in (1,2)]
    saved[1] = aw.registration_hash(int(context['chainId']), graph['rendererRegistry']['address'],
        graph['schemas']['address'], graph['schemas']['runtimeHash'], registry['targetSetHash'],
        raw_hash, from_json(at.PRESERVATION_RECORD[0], saved[0]), from_json(at.READS, registry['reads']))
    preservation['admission'][3:] = deepcopy(saved[1:5])
    return json_values(registration)


def _source_events(bundle, context, graph):
    """Use the existing exact event builder on a fresh synthetic receipt map."""
    fixture = ViewPreservationFixtureV1.__new__(ViewPreservationFixtureV1)
    PublicHistoryFixture.__init__(fixture, end=int(context['blockNumber']))
    fixture.context, fixture.graph, fixture.bundle = context, {k:graph[k] for k in at.GRAPH_KEYS}, bundle
    fixture.adoption_value = bundle['adoption']; fixture.member_value = bundle['membership']
    fixture.output_value = bundle['output']; fixture.snapshot_value = bundle['snapshot']
    fixture.root_value = bundle['root']
    fixture._events()
    return fixture.view_events


def reference_inputs(count=1, mode='disabled', burned=False):
    """Return reference/context/graph and all original byte preimages."""
    value, context, graph = reference_supplied(count, mode, burned)
    documents = {row['id']: document(row['bytes'], row['kind']) for row in t.definitions()}
    proof = value['history'][0]['sourceProof']; bundle = proof['bundle']; adopted = bundle['adoption']
    for row in adopted['history']:
        if row['profile'] == vt.V2_PROFILE: _empty_image(row, context, graph)
    registration = _registration(adopted, context, graph, documents)
    a = aw.validate(adopted, context, {k:graph[k] for k in at.GRAPH_KEYS})
    chosen = next(row for row in adopted['history'] if row['record'][3] == adopted['selectedRecordHash'])
    m = mw.validate(bundle['membership'], context, graph, chosen['policyBinding'])
    a.update(tokenIds=m['tokenIds'], policies=m['policies'])
    members = []
    for output in bundle['output']['checkpoint']['outputs']:
        token = output[1]
        data = dumps({'tokenId':token,'kind':'synthetic exact token data'})
        js = dumps({'name':'Original synthetic token '+token,'image':''})
        html = ('<html>original synthetic token '+token+'</html>').encode()
        output[6] = keccak256(data)
        output[8:12] = [keccak256(js),keccak256(html),str(len(js)),str(len(html))]
        members.append({'outputReturn':'0x'+encode((rt.OUTPUT,), (from_json(rt.OUTPUT,output),)).hex(),
            'tokenData':'0x'+data.hex(),'json':'0x'+js.hex(),'html':'0x'+html.hex()})
    seal_output(bundle['output'], context, graph, a, coverage_timestamp=106)
    bundle['snapshot'], _, _ = snapshot_supplied(context=context, graph=graph,
        output_value=bundle['output'], adoption=a, membership=m, recorded_at=107)
    bundle['root'], *_ = root_supplied(context=context, graph=graph,
        snapshot_value=bundle['snapshot'], output_value=bundle['output'], published_at=109)
    proof['events'] = _source_events(bundle, context, graph)
    row = value['history'][0]; snap = bundle['snapshot']['history'][0]; root = bundle['root']['history'][-1]
    row['publication'][1][4] = snap['receipt'][0]; row['receipt'][1][9] = snap['receipt'][0]
    row['source'][1:6] = deepcopy([snap['receipt'],snap['source'],root['recordHash'],root['record'],root['binding']])
    for sample, capture in zip(row['source'][7],row['publication'][1][7]):
        index = int(sample[0]); sample[1] = deepcopy(bundle['output']['checkpoint']['outputs'][index])
        body = hex_bytes(members[index]['html']); output = sample[1]
        capture[2:6] = [output[8],output[9],str(len(body)),'0x'+body.hex()]
        capture[8] = '0x'+sha256(body).hexdigest()
    seal_reference(value,context,graph)
    rw.validate(value,context,graph)
    runtimes = {}
    for role, pair in graph.items():
        labels = ('synthetic VIEW '+role, 'synthetic VIEW '+('reference runtime' if role=='viewReference' else 'external coverage runtime'))
        raw = next((label.encode() for label in labels if keccak256(label.encode())==pair['runtimeHash']), None)
        if raw is None: raise AssertionError('fixture runtime preimage '+role)
        runtimes[pair['address']] = '0x'+raw.hex()
    for index, policy in enumerate(m['policies']):
        raw = ('VIEW membership test coordinator code'+str(index)).encode()
        assert keccak256(raw)==policy[1]
        runtimes[policy[0]] = '0x'+raw.hex()
    for index, role in enumerate(w.GRAPH_KEYS):
        if role not in graph:
            raw = ('synthetic complete VIEW inventory '+role).encode(); address = A(81000+index)
            graph[role] = {'address':address,'runtimeHash':keccak256(raw)}
            runtimes[address] = '0x'+raw.hex()
    return value, context, graph, members, registration, runtimes, documents


def base_value(count=1, mode='disabled', burned=False):
    """Complete byte-bearing inputs before the original fixed-stage records."""
    ref, context, graph, members, registration, runtimes, documents = reference_inputs(count, mode, burned)
    deps = (tuple(graph[k]['address'] for k in w.DEPENDENCY_ROLES),
        tuple(graph[k]['runtimeHash'] for k in w.DEPENDENCY_ROLES),
        tuple(graph[k]['address'] for k in w.ARTIST_ROLES),
        tuple(graph[k]['runtimeHash'] for k in w.ARTIST_ROLES),
        graph['artistContentOwner']['address'], graph['artistContentOwner']['runtimeHash'],
        int(context['chainId']), 100000, 8000000, 8000000, 8000000, 8000000)
    value = {'sourceRevision':t.SOURCE_REVISION,'profile':t.PROFILE,
        'dependencies':json_values(deps),'dependencyHash':keccak256(encode((t.DEPENDENCIES,),(deps,))),
        'context':None,'plan':None,'evidence':None,'segments':[],
        'recordedSource':None,'reference':ref,'members':members,'rendererRegistration':registration,
        'runtimes':runtimes,'documents':documents,'events':[]}
    return value, context, graph


def set_context(value, descriptions, conservation, interview_hash):
    row, _, _, snap = sources.selected(value['reference'])
    f = from_json(rt.SOURCE, row['source']); ss = f[2]
    value['context'] = json_values((ss[0], f[0], ss[2][3], f[1],
        from_json(rt.RECEIPT, row['receipt']), descriptions, conservation, interview_hash,
        keccak256(encode((rt.SNAPSHOT_SOURCE,),(ss,))), f[3], ss[1][5], ss[5][0][0],
        ss[5][7], ss[3][0][3], ss[3][0][0][1], ss[3][0][1][8], ss[3][4],
        ss[6][2], ss[4][8], ss[5][1][3], ss[1][3]))


def bind_root_consent(value, context, graph, consent):
    """Replace the fixture's original op17 consent before deriving inventory."""
    ref = value['reference']; row, bundle, _, _ = sources.selected(ref)
    root = bundle['root']
    selected = next(entry for entry in root['history'] if entry['recordHash']==root['selectedRecordHash'])
    selected['record'][16] = consent
    seal_root(root,context,graph)
    selected = next(entry for entry in root['history'] if entry['recordHash']==root['selectedRecordHash'])
    row['source'][3:6] = deepcopy([selected['recordHash'],selected['record'],selected['binding']])
    row['sourceProof']['events'] = _source_events(bundle,context,graph)
    seal_reference(ref,context,graph)
    return selected


def seal(value, context, graph, fixed_stages):
    """Reconstruct every segment and the exact recorded getter/event transcript.

    fixed_stages are original typed source entries produced by the independently
    checked stages2..6 fixture; none of their validation is bypassed here.
    """
    c, d = from_json(t.CONTEXT,value['context']), from_json(t.DEPENDENCIES,value['dependencies'])
    identifier = w.plan_id(d[6],graph['inventory']['address'],value['dependencyHash'],c)
    rows = w._stage_rows(value,c,d); entries = []
    def append(stage,index,actual,witness,source=None):
        actual = tuple(actual)
        segment = reconstruct_segment(w.segment_key(identifier,len(entries)),witness,actual)
        entries.append({'stage':str(stage),'index':str(index),'segment':json_values(segment),
            'items':json_values(actual),'source':deepcopy(source)})
    for stage in (0,1):
        for index in range(0,len(rows[stage]),64):
            witness = keccak256(encode(('bytes32','uint64','uint64'),
                (keccak256(encode((t.CONTEXT,),(c,))) if stage==0 else c[4][1][6],index,len(rows[stage]))))
            append(stage,index,rows[stage][index:index+64],witness)
    assert [int(entry['stage']) for entry in fixed_stages]==list(range(2,7))
    for entry in fixed_stages:
        append(int(entry['stage']),int(entry.get('index',0)),
            tuple(from_json(t.ITEM,row) for row in entry['items']),entry['sourceWitnessHash'],entry['source'])
    for index, definition in enumerate(t.definitions()):
        actual = items.document(definition['id'],definition['hash'],d[0][2],value['documents'])
        append(7,index,(actual,),keccak256(encode(('bytes32',t.ITEM),(definition['id'],actual))))
    append(8,0,rows[8],w.output_witness(c,8,0,len(rows[8])))
    for stage in (9,10):
        for index, row in enumerate(rows[stage]):
            append(stage,index,(row,),w.output_witness(c,stage,index,len(rows[stage])))
    for index, group in enumerate(rows[11]): append(11,index,group,w.output_witness(c,11,index,len(group)))
    value['segments'] = entries
    segments = [from_json(t.SEGMENT,entry['segment']) for entry in entries]
    chain = ZERO
    for index, segment in enumerate(segments): chain = append_segment(chain,index,segment)
    total = sum(len(entry['items']) for entry in entries)
    original = (c[9],c[3][0],c[4][1][0],c[6][0][0] if c[6][0][1]==0 else ZERO,
        c[6][0][0] if c[6][0][1]==1 else ZERO,c[7],c[5][2],c[5][1])
    context_hash = keccak256(encode((t.CONTEXT,),(c,)))
    body = (identifier,c[0][1],c[1],c[2],original,context_hash,c[10],c[20],len(entries),total,chain,ZERO)
    digest = w.evidence_hash(d[6],graph['inventory']['address'],value['dependencyHash'],(c[0],body))
    e = (c[0],(*body[:-1],digest))
    progress = (c[0][1],c[1],c[2],context_hash,c[20],c[20],len(entries),total,chain,11,digest)
    p = (c[0],progress,len(rows[0]),len(rows[0]),len(rows[1]),len(rows[1]))
    value.update(plan=json_values(p),evidence=json_values(e))
    value['recordedSource'] = {'blockHash':context['blockHash'],'provenance':'synthetic_fixture',
        'calls':w.expected_reads(value,context,graph,c,d,p,e,segments)}
    value['events'] = [{'timestamp':'135','log':{'address':desc['address'],'topics':list(desc['topics']),
        'data':desc['data'],'blockNumber':'0x23','blockHash':H('inventory block35'),
        'transactionHash':H('inventory tx35'),'transactionIndex':'0x0','logIndex':hex(index),'removed':False}}
        for index,desc in enumerate(w.expected_events(value,context,graph))]
    return value


def supplied(count=1, mode='disabled', burned=False, *, reference_mutator=None):
    """Return a fully validated (inventory, context, graph) synthetic vector.

    The optional pre-sealing callback is for constructing complete original
    archive evidence in the bundle fixture. It cannot skip any validator.
    """
    from .test_view_preservation_inventory_stages_v1 import build_fixed_stages
    value, context, graph = base_value(count,mode,burned)
    if reference_mutator is not None: reference_mutator(value,context,graph)
    fixed = build_fixed_stages(value,context,graph)
    set_context(value,from_json(t.DESCRIPTIONS,fixed['descriptions']),
        from_json(t.CONSERVATION,fixed['conservation']),fixed['interviewHash'])
    seal(value,context,graph,fixed['entries'])
    w.validate(value,context,graph)
    return value,context,graph
