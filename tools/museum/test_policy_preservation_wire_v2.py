"""Synthetic original-byte vectors; no native or RPC execution evidence."""
from copy import deepcopy
import socket
import unittest
from unittest.mock import patch

from . import policy_preservation_wire_v2 as w
from . import policy_content_types_v2 as ct
from .canonical import MuseumError, keccak256, schema_id
from .chain_abi import encode
from .chain_abi import calldata, decode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .native_finality_wire import from_json, _hash
from .policy_preservation_types_v2 import *
from .public_prospective_reference_source import DEFINITIONS
from .policy_preservation_source_reads_v2 import PolicyPreservationSourceReads, SCOPE_SIGNATURE


def H(value): return schema_id('policy preservation synthetic ' + str(value))
def A(value): return '0x' + format(value, '040x')
def jsonify(v):
    if isinstance(v, dict): return {k: jsonify(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)): return [jsonify(x) for x in v]
    return json_values(v)


def seal_snapshot(group, context, graph):
    d = from_json(SNAPSHOT_DEPS, group['dependencies'])
    p, r, source = from_json(SNAPSHOT_PUBLICATION, group['publication']), list(from_json(SNAPSHOT_RECEIPT, group['receipt'])), from_json(SNAPSHOT_SOURCE, group['source'])
    p = list(p); p[7] = r[7] = w.source_hash(source, d, context, graph)
    raw = w.snapshot_payload(tuple(p), tuple(r), source, d, context, graph)
    r[5:7] = [keccak256(raw), len(raw)]
    r[0] = w.snapshot_hash(tuple(p), tuple(r), context, graph)
    previous = ZERO if p[3] == 0 else from_json(SNAPSHOT_RECEIPT, group['history'][p[3]-1]['receipt'])[4]
    r[4] = w.snapshot_chain(p[0], previous, tuple(r), context, graph)
    group.update(publication=jsonify(p), receipt=jsonify(r), source=jsonify(source), payload='0x'+raw.hex(), head=r[0])
    row = {'publication': group['publication'], 'receipt': group['receipt']}
    if len(group['history']) > p[3]: group['history'][p[3]] = deepcopy(row)
    else: group['history'].append(deepcopy(row))
    if group.get('lock') and group['lock'][2] != ZERO:
        group['lock'][0:2] = [r[0], str(r[3])]


def seal_reference(group, snapshot, context, graph):
    d = from_json(REFERENCE_DEPS, group['dependencies'])
    p, r, s = from_json(REFERENCE_PUBLICATION, group['publication']), from_json(REFERENCE_RECEIPT, group['receipt']), from_json(REFERENCE_SOURCE, group['source'])
    source = list(s); source[1] = from_json(SNAPSHOT_RECEIPT, snapshot['receipt']); source[2] = from_json(SNAPSHOT_SOURCE, snapshot['source'])
    source[3] = snapshot['publication'][5]; source[4] = source[2][6]
    o, rr = list(p[1]), list(r[1]); o[4:6] = source[1][0], source[1][3]; rr[9:11] = o[4:6]
    o[6] = rr[8] = w.reference_source_hash(tuple(source), d, context, graph)
    p, r = (p[0], tuple(o)), (r[0], tuple(rr))
    environment = bytes.fromhex(group['environment'][2:])
    raw = w.reference_payload(p, r, tuple(source), environment, context, graph)
    rr[6:8] = keccak256(raw), len(raw); r = (r[0], tuple(rr))
    rr[0] = w.reference_hash(p, r, context, graph); r = (r[0], tuple(rr))
    previous = ZERO if o[3] == 0 else from_json(REFERENCE_RECEIPT, group['history'][o[3]-1]['receipt'])[1][1]
    rr[1] = w.reference_chain(previous, r, context, graph); r = (r[0], tuple(rr))
    group.update(publication=jsonify(p), receipt=jsonify(r), source=jsonify(source), payload='0x'+raw.hex(), head=rr[0])
    row = {'publication': group['publication'], 'receipt': group['receipt']}
    if len(group['history']) > o[3]: group['history'][o[3]] = deepcopy(row)
    else: group['history'].append(deepcopy(row))
    if group.get('lock') and group['lock'][2] != ZERO:
        group['lock'][0:2] = [rr[0], str(rr[5])]


def supplied(count=3, mode='disabled', *, context=None, graph=None, artist=None):
    """Return bundle/context/graph/statement/content_result, explicitly synthetic."""
    context = deepcopy(context) if context else {'chainId':'31337', 'core':A(1), 'collectionId':'7', 'tokenId':'41', 'timestamp':'1000'}
    names = (*w.SNAPSHOT_KEYS, 'policySnapshot', 'policyReference', 'externalCoverage', 'coordinatorInventory', 'tokenInventory', 'artist', 'finality', 'provider', 'entropyFactory', 'terminalReadiness')
    graph = deepcopy(graph) if graph else {key:{'address':A(i+1), 'runtimeHash':H('code '+key)} for i,key in enumerate(names)}
    chain, cid = int(context['chainId']), int(context['collectionId'])
    scope = (0,cid,0,ZERO); tokens = list(range(int(context['tokenId']),int(context['tokenId'])+count))
    deps = (tuple(graph[k]['address'] for k in w.SNAPSHOT_KEYS), tuple(graph[k]['runtimeHash'] for k in w.SNAPSHOT_KEYS), chain, 100000, 500000, 500000)
    pd = (tuple(graph[k]['address'] for k in w.POLICY_KEYS), tuple(graph[k]['runtimeHash'] for k in w.POLICY_KEYS), chain, 100000, 500000)
    facts = (w._subject(context), ZERO, ZERO, count, ZERO, ZERO, count, H('inventory prefix'))
    facts = (*facts[:5], w.membership_hash(facts,scope,context,graph), *facts[6:])
    coordinator, code, policy_hash = A(90), H('coordinator runtime'), H('policy config commitment')
    explicit = mode != 'legacy'; mode_number = 0 if mode == 'disabled' else 2
    render = 1 if mode in ('disabled','not_required') else 0
    policy = (True,True,True,mode_number,0,render,1,1,policy_hash,
        _hash('6529STREAM_ENTROPY_CONFIGURATION_V1',('bytes32','bool'),(policy_hash,True)),H('policy action'),H('policy consent'))
    if not explicit: policy = (False,False,False,0,0,0,0,0,ZERO,ZERO,ZERO,ZERO)
    row = (coordinator,code,0,True,H('module'),H('manifest'),H('schema'),H('deployment'),policy_hash,
        ZERO_ADDRESS if explicit else A(91),0 if explicit else 1,ZERO if explicit else H('salt'),ZERO,explicit,policy)
    row = (*row[:12],w.policy_component(row,scope,context),*row[13:])
    entropy = (w.policy_plan(scope,facts,pd,context),H('inventory completion'),ZERO,1,True,(row,))
    entropy = (*entropy[:2],w.policy_chain(entropy,scope,pd,context),*entropy[3:])
    selected = (A(80),H('renderer registry runtime'),H('renderer key'),A(81),H('renderer runtime'),
        schema_id('6529STREAM_RENDERER_V1'),schema_id('6529STREAM_STATIC_RENDERER_V1'),H('render context'),H('render schema'),H('readset'),H('registration'))
    selection_rows = [(token,H('config'+str(token)),H('config hash'+str(token)),H('raw'+str(token)),H('raw hash'+str(token)),selected,
        (context['core'],graph['router']['address'],graph['metadata']['address'],coordinator,ZERO_ADDRESS,ZERO_ADDRESS),
        (graph['core']['runtimeHash'],graph['router']['runtimeHash'],graph['metadata']['runtimeHash'],code,ZERO,ZERO)) for token in tokens]
    selection_plan = (scope,facts[5],H('collection state'),count,count,H('selection root'))
    content = (w.selection_id(selection_plan,context,graph),keccak256(encode((SELECTION_PLAN,),(selection_plan,))),
        entropy[1],entropy[2],scope,count,count,H('leaf chain'),H('content root'),H('output root'))
    artist = tuple(artist) if artist else (True,graph['artist']['address'],graph['artist']['runtimeHash'],H('Artist'),1,H('binding'),A(93),H('identity'),H('acceptance'),100,110,H('Artist snapshot'))
    manifest = (H('checkpoint'),keccak256(encode((CONTENT_PLAN,),(content,))),deps[0][10],entropy[1],entropy[2],H('artifact'),H('artifact coverage'),
        artist[3],content[8],content[9],H('output bytes'),scope,count,576+640*count)
    binding = (ct.PROFILE,deps[0][8],deps[1][8],deps[0][7],deps[1][7],manifest[0],manifest[1],deps[0][10],deps[1][10],
        entropy[1],entropy[2],manifest[9],*(row['hash'] for row in w.content_wire.definitions()))
    root = ((cid,ZERO,H('output record'),'ipfs://policy-root'),manifest[8],count,manifest[10],artist[3],artist[4],artist[5],
        A(82),7,1,w.content_wire.route_hash(chain,graph),ZERO,H('Artist op17'),150)
    root = (*root[:11],w.content_wire.root_state_hash(chain,graph['router']['address'],root,binding),*root[12:])
    root_hash = _hash('6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2',('uint256','address',ROOT_RECORD,ROOT_BINDING),(chain,graph['router']['address'],root,binding))
    source = (scope,facts,artist,selection_plan,content,manifest,root,binding,entropy)
    p = (scope,H('snapshot ID'),ZERO,0,root[0][2],root_hash,entropy[0],ZERO,'ipfs://snapshot',200,H('snapshot reason'))
    r = (ZERO,w._subject(context),ZERO,1,ZERO,ZERO,0,ZERO,A(83),7,1,8,2,200,*w.SNAPSHOT_HASHES)
    snap = jsonify({'dependencies':deps,'entropyDependencies':pd,'publication':p,'receipt':r,'source':source,'payload':'0x',
        'history':[],'head':ZERO,'lock':(ZERO,1,H('snapshot lock'),210)})
    seal_snapshot(snap,context,graph)
    archive_objects = []
    def coverage(label, role, sha_digest=None):
        o = (artist[3],DEFINITIONS[5 if role=='zip' else 4][0],schema_id('RAW_BYTES'),H(label+' bytes'),sha_digest or H(label+' sha'),
            H(label+' arweave'),99,schema_id('IANA:application/zip' if role=='zip' else 'IANA:image/png'),DEFINITIONS[6][0],DEFINITIONS[6][2])
        oh = _hash('6529STREAM_EXTERNAL_OBJECT_V1',('uint256','address','address',EXTERNAL_OBJECT),(chain,graph['externalCoverage']['address'],context['core'],o))
        c = (ZERO,oh,artist[3],*o[3:7],*(H(label+' evidence'+str(i)) for i in range(7)),schema_id('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1'))
        c = (_hash('6529STREAM_EXTERNAL_COVERAGE_V1',('uint256','address',EXTERNAL_COVERAGE),(chain,graph['externalCoverage']['address'],c)),*c[1:])
        archive_objects.append({'objectHash':oh,'identity':o}); return c
    environment_coverage = coverage('environment','zip')
    env = (environment_coverage[1],environment_coverage[0],ZERO,0,'Synthetic engine','1',H('engine sha'),'Synthetic tool','1',H('tool sha'),
        'engine.exe','tool.py',(('engine.exe',1,H('engine sha')),('tool.py',1,H('tool sha'))),
        (('C:/Windows/synthetic.dll',1,H('platform sha')),),'Windows','synthetic','AMD64',800,600,1,'srgb',True,
        schema_id('STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1'),'No native browser execution claim')
    env_raw = w.environment_bytes(env); env = (*env[:2],keccak256(env_raw),len(env_raw),*env[4:])
    terminal = mode in ('disabled','not_required'); status = 1 if mode=='disabled' else 2 if terminal else 5
    readiness = (coordinator,code,policy_hash,status,mode_number,0,render,terminal,not terminal,ZERO if terminal else H('finalized seed'))
    captures, samples, outputs = [],[],[]
    for index, token in enumerate(tokens):
        html = ('<html>synthetic '+str(token)+'</html>').encode(); html_hash = keccak256(html)
        metadata_hash, data_hash = H('metadata'+str(token)),H('tokenData'+str(token))
        row_hash = _hash('6529STREAM_STATIC_SELECTION_ROW_V1',('uint256','address','address',SELECTION_ROW),(chain,context['core'],graph['router']['address'],selection_rows[index]))
        admission = H('terminal admission'+str(token)) if terminal else ZERO
        outputs.append(((token,metadata_hash,H('image'),html_hash,ZERO,data_hash),row_hash,H('source facts'),html_hash,readiness,admission))
        if index not in (0,count-1): continue
        png = H('PNG'+str(token)); cov = coverage('capture'+str(token),'png',png)
        captures.append((token,index+5,metadata_hash,html_hash,len(html),html,cov[1],cov[0],'0x'+w.sha256(html).hexdigest(),(png,png),env[2],250))
        sf = (token,index+5,coordinator,readiness[9],data_hash,3,metadata_hash,html_hash,len(html),cov)
        samples.append((index,sf,selection_rows[index],readiness,admission))
    rd = (tuple(graph[k]['address'] for k in w.REFERENCE_KEYS),tuple(graph[k]['runtimeHash'] for k in w.REFERENCE_KEYS),chain,100000,500000,1000000,100000)
    rp = (scope,(cid,H('reference ID'),ZERO,0,snap['receipt'][0],1,ZERO,tuple(captures),env,'ipfs://reference',300,H('reference reason')))
    rr = (w._subject(context),(ZERO,ZERO,cid,rp[1][1],ZERO,1,ZERO,0,ZERO,snap['receipt'][0],1,A(84),3,1,300,300,rp[1][11],*w.REFERENCE_HASHES))
    rs = (w._subject(context),from_json(SNAPSHOT_RECEIPT,snap['receipt']),source,root_hash,root,environment_coverage,tuple(samples))
    ref = jsonify({'dependencies':rd,'publication':rp,'receipt':rr,'source':rs,'payload':'0x','environment':'0x'+env_raw.hex(),
        'objects':archive_objects,'history':[],'head':ZERO,'lock':(ZERO,1,H('reference lock'),310)})
    seal_reference(ref,snap,context,graph)
    result = jsonify({'contentPlan':content,'outputManifest':manifest,'selectedRoot':root,'selectedBinding':binding,'manifestRecordHash':root[0][2],
        'selectionPlan':selection_plan,'selectionRows':selection_rows,'tokenIds':tokens,'outputs':outputs})
    statement = jsonify((scope,H('Core facts'),manifest[8],count,ct.LEAF_SCHEMA,snap['receipt'][5],ref['receipt'][1][6],
        (root_hash,snap['receipt'][0],ref['receipt'][1][0],*(H('input'+str(i)) for i in range(7))),(),
        (deps[0][10],deps[1][10],w.SOURCE_SET_PROFILE,entropy[0],entropy[1],entropy[2],1,w.SNAPSHOT_HASHES[1],w.REFERENCE_HASHES[1]),1,1))
    return {'snapshot':snap,'reference':ref},context,graph,statement,result


class PolicyPreservationTests(unittest.TestCase):
    def test_original_component_preimages_include_full_native_fields(self):
        b,c,g,s,o = supplied()
        result = w.validate(b,c,g,s,o)['componentCommitments']
        source = from_json(SNAPSHOT_SOURCE,b['snapshot']['source'])
        d = from_json(POLICY_DEPS,b['snapshot']['entropyDependencies'])
        inventory,pin = g['tokenInventory']['address'],g['tokenInventory']['runtimeHash']
        expected_manifest = keccak256(encode(('bytes32',POLICY_DEPS,'address','bytes32'),
            (w.SOURCE_SET_PROFILE,d,inventory,pin)))
        expected_data = keccak256(encode(('bytes32',SCOPE,'bytes32','bytes32','bytes32',MEMBERSHIP_FACTS,'address','bytes32'),
            (w.SOURCE_SET_PROFILE,source[0],source[8][0],source[8][1],source[8][2],source[1],inventory,pin)))
        self.assertEqual(result['entropy'],{'moduleVersion':w.SOURCE_SET_PROFILE,
            'manifestHash':expected_manifest,'dataHash':expected_data})
        r = from_json(REFERENCE_RECEIPT,b['reference']['receipt'])
        lock = from_json(REFERENCE_LOCK,b['reference']['lock'])
        expected_reference = keccak256(encode(('bytes32','uint256','address','address',SCOPE,REFERENCE_RECEIPT,REFERENCE_LOCK),
            (schema_id('6529STREAM_LOCKED_POLICY_REFERENCE_COMPONENT_V2'),int(c['chainId']),
             g['policyReference']['address'],c['core'],source[0],r,lock)))
        self.assertEqual(result['reference']['dataHash'],expected_reference)
        changed = deepcopy(g); changed['tokenInventory']['runtimeHash'] = H('different original inventory')
        self.assertNotEqual(w.source_set_commitments(source,d,changed)['dataHash'],expected_data)
        self.assertNotEqual(w.reference_component(r,(*lock[:2],H('different original lock action'),lock[3]),
            source[0],c,g)['dataHash'],expected_reference)

    def test_complete_originals_all_policy_statuses_offline(self):
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            for mode in ('disabled','not_required','finalized','legacy'):
                with self.subTest(mode=mode):
                    b,c,g,s,o = supplied(mode=mode)
                    result = w.validate(b,c,g,s,o)
                    self.assertTrue(result['claims']['completeOutputRowsJoined'])
                    self.assertFalse(result['claims']['terminalAdmissionPreimageVerified'])
                    self.assertFalse(result['claims']['currentnessVerified'])
                    self.assertEqual(len(w.expected_events(b,c,g,s)),4)

    def test_exact_native_definition_bytes_and_distinct_v1_domains(self):
        self.assertEqual([len(d['bytes']) for d in w.definitions()],[13761,995,853,25617,1465,921,2236,286,351,422])
        b,c,g,s,o = supplied(1)
        b['snapshot']['receipt'][15] = H('V1 profile')
        seal_snapshot(b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'definitions'): w.validate_snapshot(b['snapshot'],c,g,o)

    def test_rehashed_explicit_policy_content_state_rejected(self):
        b,c,g,s,o = supplied(); b['snapshot']['source'][8][5][0][14][9] = H('wrong content state')
        seal_snapshot(b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'explicit V2'): w.validate_snapshot(b['snapshot'],c,g)

    def test_legacy_row_cannot_claim_explicit_policy_or_terminal(self):
        b,c,g,s,o = supplied(mode='legacy')
        b['reference']['source'][6][0][3][7] = True
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'terminal status'): w.validate(b,c,g,None)

    def test_terminal_seed_and_request_semantics_not_finalization(self):
        for field,value in ((8,True),(9,H('fabricated seed')),(3,'5')):
            b,c,g,s,o = supplied(); b['reference']['source'][6][0][3][field] = value
            seal_reference(b['reference'],b['snapshot'],c,g)
            with self.assertRaisesRegex(MuseumError,'terminal status'): w.validate(b,c,g,None)

    def test_complete_policy_chain_not_v1_or_truncated(self):
        b,c,g,s,o = supplied(); b['snapshot']['source'][8][2] = H('other policy chain')
        seal_snapshot(b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'V2 chain'): w.validate_snapshot(b['snapshot'],c,g)

    def test_current_head_and_locked_original_revision(self):
        b,c,g,s,o = supplied(); b['snapshot']['head'] = H('unrelated head')
        with self.assertRaisesRegex(MuseumError,'current head'): w.validate_snapshot(b['snapshot'],c,g)
        b,c,g,s,o = supplied(); b['reference']['lock'][1] = '2'
        with self.assertRaisesRegex(MuseumError,'lock/head/revision'): w.validate(b,c,g,s,o)

    def test_wrong_family_authority_and_scope_fail_after_rehash(self):
        for cls in (1,7):
            b,c,g,s,o = supplied(); b['reference']['receipt'][1][12] = str(cls)
            seal_reference(b['reference'],b['snapshot'],c,g)
            with self.assertRaisesRegex(MuseumError,'authority'): w.validate(b,c,g,None)
        b,c,g,s,o = supplied(); b['snapshot']['publication'][0][0] = '1'
        with self.assertRaisesRegex(MuseumError,'COLLECTION'): w.validate_snapshot(b['snapshot'],c,g)

    def test_reference_exact_html_and_environment_bytes(self):
        b,c,g,s,o = supplied(); b['reference']['publication'][1][7][0][5] = '0x626164'
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'sample byte'): w.validate(b,c,g,None)
        b,c,g,s,o = supplied(); b['reference']['environment'] += '20'
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'environment bytes'): w.validate(b,c,g,None)

    def test_snapshot_canonical_abi_rejects_tail(self):
        b,c,g,s,o = supplied(); b['snapshot']['payload'] += '00'
        with self.assertRaisesRegex(MuseumError,'exact payload'): w.validate_snapshot(b['snapshot'],c,g)

    def test_first_last_membership_ordinal_and_original_serial(self):
        b,c,g,s,o = supplied(); self.assertEqual(b['reference']['source'][6][1][0],'2')
        self.assertEqual(b['reference']['source'][6][1][1][1],'7')
        b['reference']['source'][6][1][0] = '1'
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'ordinal'): w.validate(b,c,g,None)

    def test_coherent_native_objects_still_must_be_correct_capture_role(self):
        b,c,g,s,o = supplied(); b['reference']['objects'][1]['identity'][1] = DEFINITIONS[5][0]
        with self.assertRaisesRegex(MuseumError,'object/role'): w.validate(b,c,g,None)

    def test_samples_must_match_complete_outputs_and_source_set(self):
        b,c,g,s,o = supplied(); o['outputs'][0][5] = H('different terminal admission')
        with self.assertRaisesRegex(MuseumError,'complete output join'): w.validate(b,c,g,s,o)
        b,c,g,s,o = supplied(); o['selectionRows'][1][6][3] = A(99)
        with self.assertRaisesRegex(MuseumError,'first-occurrence'): w.validate(b,c,g,s,o)

    def test_no_lock_preserves_partial_original_semantics(self):
        b,c,g,s,o = supplied()
        b['snapshot']['lock'] = [ZERO,'0',ZERO,'0']; b['reference']['lock'] = [ZERO,'0',ZERO,'0']
        self.assertEqual(w.validate(b,c,g,s,o)['snapshot']['lock'],b['snapshot']['lock'])

    def test_all_output_policy_rows_not_only_reference_endpoints(self):
        b,c,g,s,o = supplied()
        o['outputs'][1][4][5] = '1'
        with self.assertRaisesRegex(MuseumError,'mode/security/render'): w.validate(b,c,g,s,o)

    def test_finality_full_entropy_tuple_cannot_be_v1_or_different_profile(self):
        b,c,g,s,o = supplied(); s[9][8] = H('V1 reference')
        with self.assertRaisesRegex(MuseumError,'full entropy/profile'): w.validate(b,c,g,s,o)


class ReadFixture(PolicyPreservationSourceReads):
    """Exact synthetic ABI responses for the real historical read mixin."""
    def __init__(self):
        self.bundle,self.a,self.graph,self.statement,self.content = supplied()
        self.a.update({key:row['address'] for key,row in self.graph.items()})
        self.responses,self.queries,self.history_queries,self.codes,self.pieces = {},[],[],{},{}
        self.reader = self
        # Install source-set/factory runtimes and update all dependent hashes before capture.
        for key in ('entropyFactory','entropySourceSet'):
            raw = ('synthetic '+key).encode(); self.codes[self.a[key]] = raw
            self.graph[key]['runtimeHash'] = keccak256(raw)
        self.bundle,self.context,self.graph,self.statement,self.content = supplied(context=self.a,graph=self.graph)
        self.a.update(self.context)
        self._install()

    def add(self,host,signature,outputs,values,inputs=(),args=()):
        self.responses[(host,calldata(signature,inputs,args))] = encode(outputs,values)

    def _read(self,host,signature,outputs,inputs=(),values=(),*,maximum=65536):
        self.queries.append(signature)
        raw = self.responses[(host,calldata(signature,inputs,values))]
        if len(raw)>maximum: raise MuseumError('synthetic response bound')
        return decode(outputs,raw,maximum=maximum)

    def _one(self,host,signature,output,inputs=(),values=(),*,maximum=65536):
        return self._read(host,signature,(output,),inputs,values,maximum=maximum)[0]

    def _chunk(self,digest): return self.pieces[digest]
    def code(self,address): return '0x'+self.codes[address].hex()
    def _history(self,address,topics):
        self.history_queries.append((address,topics)); return {'logs':[]}

    def _install(self):
        for family,role,pub_type,rec_type,deps_type,envelope in (
            ('snapshot','policySnapshot',SNAPSHOT_PUBLICATION,SNAPSHOT_RECEIPT,SNAPSHOT_DEPS,SNAPSHOT_ENVELOPE),
            ('reference','policyReference',REFERENCE_PUBLICATION,REFERENCE_RECEIPT,REFERENCE_DEPS,REFERENCE_ENVELOPE)):
            group=self.bundle[family]; host=self.a[role]
            p,r,d=from_json(pub_type,group['publication']),from_json(rec_type,group['receipt']),from_json(deps_type,group['dependencies'])
            scope=p[0]; key=r[0] if family=='snapshot' else r[1][0]
            raw=bytes.fromhex(group['payload'][2:]); parts=[raw[i:i+8192] for i in range(0,len(raw),8192)]
            self.add(host,'dependencies()',(deps_type,),(d,))
            self.add(host,family+'Count('+SCOPE_SIGNATURE+')',('uint256',),(1,),(SCOPE,),(scope,))
            self.add(host,family+'At('+SCOPE_SIGNATURE+',uint256)',('bytes32',),(key,),(SCOPE,'uint256'),(scope,0))
            self.add(host,family+'Record(bytes32)',(pub_type,rec_type),(p,r),('bytes32',),(key,))
            self.add(host,family+'Payload(bytes32)',('bytes',),(raw,),('bytes32',),(key,))
            self.add(host,'current'+family.title()+'('+SCOPE_SIGNATURE+')',(rec_type,),(r,),(SCOPE,),(scope,))
            self.add(host,family+'Lock('+SCOPE_SIGNATURE+')',(SNAPSHOT_LOCK,),(from_json(SNAPSHOT_LOCK,group['lock']),),(SCOPE,),(scope,))
            self.add(host,family+'ChunkCount(bytes32)',('uint256',),(len(parts),),('bytes32',),(key,))
            for index,part in enumerate(parts):
                digest=keccak256(part); pointer=A(1000+len(self.pieces)); self.pieces[digest]=part
                self.add(host,family+'ChunkAt(bytes32,uint256)',('address','bytes32','uint32'),(pointer,digest,len(part)),('bytes32','uint256'),(key,index))
                self.add(self.a['store'],'chunk(bytes32)',('address','uint32'),(pointer,len(part)),('bytes32',),(digest,))
            if family=='reference':
                source=from_json(REFERENCE_SOURCE,group['source'])
                self.add(host,'referenceSource(bytes32)',(REFERENCE_SOURCE,),(source,),('bytes32',),(key,))
        snap=self.bundle['snapshot']; source=from_json(SNAPSHOT_SOURCE,snap['source']); e=source[8]
        pd=from_json(POLICY_DEPS,snap['entropyDependencies']); host,factory=self.a['entropySourceSet'],self.a['entropyFactory']
        for signature,kind,value in (
            ('factory()','address',factory),('core()','address',self.a['core']),('coreCodeHash()','bytes32',self.graph['core']['runtimeHash']),
            ('SOURCE_SET_PROFILE()','bytes32',w.SOURCE_SET_PROFILE),('sourceScope()',SCOPE,source[0]),
            ('scopeMembershipFacts()',MEMBERSHIP_FACTS,source[1]),('inventoryPlan()','bytes32',e[0]),
            ('originalInventoryHash()','bytes32',e[1]),('originalPolicyChainHash()','bytes32',e[2]),('sourceCount()','uint256',e[3]),
            ('tokenInventory()','address',self.a['tokenInventory']),('tokenInventoryCodeHash()','bytes32',self.graph['tokenInventory']['runtimeHash'])):
            self.add(host,signature,(kind,),(value,))
        for index,row in enumerate(e[5]): self.add(host,'sourcePolicyAt(uint256)',(POLICY_ROW,),(row,),('uint256',),(index,))
        self.add(factory,'policyFactoryProfile()',('bytes32',),(schema_id('6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2'),))
        self.add(factory,'dependencies()',(POLICY_DEPS,),(pd,))
        for signature,key in (('core()','core'),('metadataHost()','metadata'),('scopeMembershipHost()','scopeMembership'),('coordinatorInventory()','coordinatorInventory')):
            self.add(factory,signature,('address',),(self.a[key],))
        self.add(factory,'sourceSetForPlan(bytes32)',('address','bytes32'),(host,self.graph['entropySourceSet']['runtimeHash']),('bytes32',),(e[0],))
        inv,pin=self.a['tokenInventory'],self.graph['tokenInventory']['runtimeHash']
        self.add(host,'sourceSetManifestHash()',('bytes32',),(keccak256(encode(('bytes32',POLICY_DEPS,'address','bytes32'),(w.SOURCE_SET_PROFILE,pd,inv,pin))),))
        self.add(host,'sourceSetDataHash()',('bytes32',),(keccak256(encode(('bytes32',SCOPE,'bytes32','bytes32','bytes32',MEMBERSHIP_FACTS,'address','bytes32'),
            (w.SOURCE_SET_PROFILE,source[0],e[0],e[1],e[2],source[1],inv,pin))),))
        ref=from_json(REFERENCE_SOURCE,self.bundle['reference']['source'])
        for obj in self.bundle['reference']['objects']:
            self.add(self.a['externalCoverage'],'objectIdentity(bytes32)',(EXTERNAL_OBJECT,),(from_json(EXTERNAL_OBJECT,obj['identity']),),('bytes32',),(obj['objectHash'],))
        for cov in [ref[5],*(sample[1][9] for sample in ref[6])]:
            self.add(self.a['externalCoverage'],'coverage(bytes32)',(EXTERNAL_COVERAGE,),(cov,),('bytes32',),(cov[0],))


class PolicySourceReadTests(unittest.TestCase):
    def test_exact_original_histories_chunk_partition_and_no_current_substitution(self):
        f=ReadFixture()
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            self.assertEqual(f._preservation(f.statement,f.content),f.bundle)
        self.assertEqual(len(f.history_queries),2)
        self.assertGreater(len(f.pieces),2)
        self.assertFalse(any('requireCurrent' in q or 'tokenEntropyReadiness' in q or 'currentInventoryPlan' in q for q in f.queries))

    def test_source_set_policy_cannot_be_replaced_with_current_policy(self):
        f=ReadFixture(); row=list(from_json(POLICY_ROW,f.bundle['snapshot']['source'][8][5][0])); row[8]=H('changed policy')
        f.add(f.a['entropySourceSet'],'sourcePolicyAt(uint256)',(POLICY_ROW,),(tuple(row),),('uint256',),(0,))
        with self.assertRaisesRegex(MuseumError,'immutable policy differs'): f._preservation(f.statement,f.content)

    def test_store_pointer_must_match_original_payload_descriptor(self):
        f=ReadFixture(); digest=next(iter(f.pieces))
        f.add(f.a['store'],'chunk(bytes32)',('address','uint32'),(A(9999),len(f.pieces[digest])),('bytes32',),(digest,))
        with self.assertRaisesRegex(MuseumError,'Store pointer'): f._preservation(f.statement,f.content)

    def test_current_head_cannot_hide_original_history(self):
        f=ReadFixture(); r=list(from_json(SNAPSHOT_RECEIPT,f.bundle['snapshot']['receipt'])); r[0]=H('wrong head')
        scope=from_json(SCOPE,f.statement[0])
        f.add(f.a['policySnapshot'],'currentSnapshot('+SCOPE_SIGNATURE+')',(SNAPSHOT_RECEIPT,),(tuple(r),),(SCOPE,),(scope,))
        with self.assertRaisesRegex(MuseumError,'head differs'): f._preservation(f.statement,f.content)

    def test_factory_saved_source_and_hash_preimages_are_checked(self):
        f=ReadFixture(); e=f.bundle['snapshot']['source'][8]
        f.add(f.a['entropyFactory'],'sourceSetForPlan(bytes32)',('address','bytes32'),(A(9999),H('foreign runtime')),('bytes32',),(e[0],))
        with self.assertRaisesRegex(MuseumError,'saved source-set'): f._preservation(f.statement,f.content)
        f=ReadFixture(); f.add(f.a['entropySourceSet'],'sourceSetDataHash()',('bytes32',),(H('wrong data preimage'),))
        with self.assertRaisesRegex(MuseumError,'manifest/data preimages'): f._preservation(f.statement,f.content)


if __name__ == '__main__': unittest.main()
