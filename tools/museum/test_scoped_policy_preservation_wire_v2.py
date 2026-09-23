"""Synthetic original-byte vectors; no native or RPC execution evidence."""
from copy import deepcopy
import socket
import unittest
from unittest.mock import patch

from . import scoped_policy_preservation_wire_v2 as w
from . import scoped_policy_content_types_v2 as ct
from .canonical import MuseumError, keccak256, schema_id
from .chain_abi import encode
from .chain_abi import calldata, decode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .native_finality_wire import from_json, _hash
from .scoped_policy_preservation_types_v2 import *
from .public_prospective_reference_source import DEFINITIONS
from .scoped_policy_preservation_source_reads_v2 import ScopedPolicyPreservationSourceReads, SCOPE_SIGNATURE


def H(value): return schema_id('policy preservation synthetic ' + str(value))
def A(value): return '0x' + format(value, '040x')
def jsonify(v):
    if isinstance(v, dict): return {k: jsonify(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)): return [jsonify(x) for x in v]
    return json_values(v)


def seal_snapshot(group, context, graph):
    d = from_json(SNAPSHOT_DEPS, group['dependencies'])
    p, r, source = from_json(SNAPSHOT_PUBLICATION, group['publication']), list(from_json(SNAPSHOT_RECEIPT, group['receipt'])), from_json(SNAPSHOT_SOURCE, group['source'])
    p = list(p); p[6] = r[7] = w.source_hash(source, d, context, graph)
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


def supplied(count=3, mode='disabled', *, scope_type=2, context=None, graph=None, artist=None, membership=None):
    """Return bundle/context/graph/statement/content_result, explicitly synthetic."""
    context = deepcopy(context) if context else {'chainId':'31337', 'core':A(1), 'collectionId':'7', 'tokenId':'41', 'timestamp':'1000'}
    names = (*w.SNAPSHOT_KEYS, 'policySnapshot', 'policyReference', 'externalCoverage', 'coordinatorInventory', 'tokenInventory', 'artist', 'finality', 'provider', 'sourceFactory', 'terminalReadiness')
    graph = deepcopy(graph) if graph else {key:{'address':A(i+1), 'runtimeHash':H('code '+key)} for i,key in enumerate(names)}
    chain, cid = int(context['chainId']), int(context['collectionId'])
    scope = (scope_type,cid,int(context['tokenId']) if scope_type==1 else 0,ZERO if scope_type==1 else H('scope'+str(scope_type))); tokens = list(range(int(context['tokenId']),int(context['tokenId'])+count))
    deps = (tuple(graph[k]['address'] for k in w.SNAPSHOT_KEYS), tuple(graph[k]['runtimeHash'] for k in w.SNAPSHOT_KEYS), chain, 100000, 500000, 500000)
    pd = (tuple(graph[k]['address'] for k in w.POLICY_KEYS), tuple(graph[k]['runtimeHash'] for k in w.POLICY_KEYS), chain, 100000, 500000)
    facts = (w.scope_subject(scope,context), ZERO if scope_type==1 else H('membership manifest'), ZERO if scope_type==1 else H('membership record'), count,
        keccak256(encode(('uint256',)*count,tokens)), ZERO, 0, ZERO)
    facts = (*facts[:5], w.membership_hash(facts,scope,context,graph), *facts[6:])
    if membership is not None:
        from . import scoped_policy_membership_v2 as member_wire
        tokens = [int(value) for value in membership['tokens']]
        w.require(len(tokens) == count, 'synthetic supplied membership count')
        if scope_type != 1:
            scope = (scope_type,cid,0,_hash('6529STREAM_SCOPE_MEMBERSHIP_ID_V1',
                ('uint256','address','uint256','uint8','bytes32'),
                (chain,context['core'],cid,scope_type,membership['publication'][0])))
        facts = from_json(MEMBERSHIP_FACTS,membership['facts'])
        member_wire.validate(membership,context,graph,scope,facts,tokens)
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
    source = (scope,facts,artist,selection_plan,content,manifest,graph['sourceFactory']['address'],
        graph['sourceFactory']['runtimeHash'],keccak256(encode((POLICY_DEPS,),(pd,))),entropy)
    p = (scope,H('snapshot ID'),ZERO,0,H('output record'),entropy[0],ZERO,'ipfs://snapshot',200,H('snapshot reason'))
    r = (ZERO,w.scope_subject(scope,context),ZERO,1,ZERO,ZERO,0,ZERO,A(83),7,1,8,2,200,*w.SNAPSHOT_HASHES)
    snap = jsonify({'dependencies':deps,'entropyDependencies':pd,'publication':p,'receipt':r,'source':source,'payload':'0x',
        'history':[],'head':ZERO,'lock':(ZERO,1,H('snapshot lock'),210)})
    seal_snapshot(snap,context,graph)
    binding = (ct.ROOT_PROFILE,deps[0][8],deps[1][8],deps[0][7],deps[1][7],manifest[0],manifest[1],deps[0][10],deps[1][10],
        entropy[1],entropy[2],manifest[9],*(row['hash'] for row in w.content_wire.definitions()),*source[6:9],*w.SNAPSHOT_HASHES)
    root = ((scope,ZERO,snap['receipt'][0],1,'ipfs://policy-root'),graph['policySnapshot']['address'],graph['policySnapshot']['runtimeHash'],
        snap['receipt'][5],snap['receipt'][7],manifest[8],count,manifest[10],artist[3],artist[4],artist[5],
        A(82),7,1,w.content_wire.route_hash(chain,graph,scope),ZERO,H('Artist op17'),220)
    root = (*root[:15],w.content_wire.root_state_hash(chain,graph['router']['address'],context['core'],root,binding),*root[16:])
    aggregate = w.content_wire.next_aggregate(chain,graph['router']['address'],context['core'],(0,ZERO),root)
    root_hash = w.content_wire.root_hash(chain,graph['router']['address'],context['core'],root,binding,aggregate)
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
    rr = (w.scope_subject(scope,context),(ZERO,ZERO,cid,rp[1][1],ZERO,1,ZERO,0,ZERO,snap['receipt'][0],1,A(84),3,1,300,300,rp[1][11],*w.REFERENCE_HASHES))
    rs = (w.scope_subject(scope,context),from_json(SNAPSHOT_RECEIPT,snap['receipt']),source,root_hash,root,binding,environment_coverage,tuple(samples))
    ref = jsonify({'dependencies':rd,'publication':rp,'receipt':rr,'source':rs,'payload':'0x','environment':'0x'+env_raw.hex(),
        'objects':archive_objects,'history':[],'head':ZERO,'lock':(ZERO,1,H('reference lock'),310)})
    seal_reference(ref,snap,context,graph)
    result = jsonify({'contentPlan':content,'outputManifest':manifest,'selectedRoot':root,'selectedBinding':binding,'manifestRecordHash':p[4],'selectedRootHash':root_hash,
        'selectionPlan':selection_plan,'selectionRows':selection_rows,'tokenIds':tokens,'outputs':outputs})
    statement = jsonify((scope,H('Core facts'),manifest[8],count,ct.LEAF_SCHEMA,snap['receipt'][5],ref['receipt'][1][6],
        (root_hash,snap['receipt'][0],ref['receipt'][1][0],*(H('input'+str(i)) for i in range(7))),(),
        1,1,1))
    return {'snapshot':snap,'reference':ref},context,graph,statement,result


class ReadFixture(ScopedPolicyPreservationSourceReads):
    """Exact synthetic ABI responses for the real historical read mixin."""
    def __init__(self):
        self.bundle,self.a,self.graph,self.statement,self.content = supplied()
        self.a.update({key:row['address'] for key,row in self.graph.items()})
        self.responses,self.queries,self.history_queries,self.codes,self.pieces = {},[],[],{},{}
        self.reader = self
        # Install source-set/factory runtimes and update all dependent hashes before capture.
        for key in ('sourceFactory','entropySourceSet'):
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
            for index,part in enumerate(parts):
                digest=keccak256(part); pointer=A(1000+len(self.pieces)); self.pieces[digest]=part
                self.add(self.a['store'],'chunk(bytes32)',('address','uint32'),(pointer,len(part)),('bytes32',),(digest,))
            if family=='reference':
                source=from_json(REFERENCE_SOURCE,group['source'])
                self.add(host,'referenceSource(bytes32)',(REFERENCE_SOURCE,),(source,),('bytes32',),(key,))
        snap=self.bundle['snapshot']; source=from_json(SNAPSHOT_SOURCE,snap['source']); e=source[9]
        pd=from_json(POLICY_DEPS,snap['entropyDependencies']); host,factory=self.a['entropySourceSet'],self.a['sourceFactory']
        for signature,kind,value in (
            ('factory()','address',factory),('core()','address',self.a['core']),('coreCodeHash()','bytes32',self.graph['core']['runtimeHash']),
            ('SOURCE_SET_PROFILE()','bytes32',w.SOURCE_SET_PROFILE),('sourceScope()',SCOPE,source[0]),
            ('scopeMembershipFacts()',MEMBERSHIP_FACTS,source[1]),('inventoryPlan()','bytes32',e[0]),
            ('originalInventoryHash()','bytes32',e[1]),('originalPolicyChainHash()','bytes32',e[2]),('sourceCount()','uint256',e[3]),
            ('tokenInventory()','address',self.a['tokenInventory']),('tokenInventoryCodeHash()','bytes32',self.graph['tokenInventory']['runtimeHash'])):
            self.add(host,signature,(kind,),(value,))
        for index,row in enumerate(e[5]): self.add(host,'sourcePolicyAt(uint256)',(POLICY_ROW,),(row,),('uint256',),(index,))
        self.add(factory,'scopedPolicyFactoryProfile()',('bytes32',),(schema_id('6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2'),))
        self.add(factory,'dependencies()',(POLICY_DEPS,),(pd,))
        for signature,kind,value in (('sourceFactory()','address',factory),
            ('sourceFactoryCodeHash()','bytes32',source[7]),('factoryDependenciesHash()','bytes32',source[8])):
            self.add(self.a['policyContent'],signature,(kind,),(value,))
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
        for cov in [ref[6],*(sample[1][9] for sample in ref[7])]:
            self.add(self.a['externalCoverage'],'coverage(bytes32)',(EXTERNAL_COVERAGE,),(cov,),('bytes32',),(cov[0],))


class ScopedPolicyPreservationTests(unittest.TestCase):
    def test_fixture_accepts_actual_sealed_membership_before_sealing_sources(self):
        from .test_scoped_static_snapshot_wire import supplied as member_supplied
        _,c,g,_,_=supplied()
        g.update(staticContent={'address':A(10001),'runtimeHash':H('old content')},
                 scopedSnapshot={'address':A(10002),'runtimeHash':H('old snapshot')})
        membership=member_supplied(2,3,context=c,graph=g)[0]['membership']
        b,c,g,s,o=supplied(context=c,graph=g,membership=membership)
        self.assertEqual(w.validate(b,c,g,s,o)['snapshot']['membership'],membership['facts'])

    def test_three_scopes_and_explicit_entropy_branches_offline(self):
        with patch.object(socket, 'socket', side_effect=AssertionError('network forbidden')):
            for scope,count in ((1,1),(2,3),(3,3)):
                for mode in ('disabled','not_required','finalized','legacy'):
                    with self.subTest(scope=scope,mode=mode):
                        b,c,g,s,o=supplied(count,mode,scope_type=scope)
                        result=w.validate(b,c,g,s,o)
                        self.assertEqual(result['source'][0],s[0])
                        self.assertEqual(result['source'][6],g['sourceFactory']['address'])
                        self.assertTrue(result['claims']['completeOutputRowsJoined'])
                        self.assertFalse(result['claims']['currentnessVerified'])
                        self.assertFalse(result['claims']['terminalAdmissionPreimageVerified'])
                        self.assertEqual(len(w.expected_events(b,c,g)),4)

    def test_exact_new_definitions_and_no_collection_cast(self):
        from . import policy_preservation_types_v2 as old
        self.assertEqual([len(d['bytes']) for d in w.definitions()],
            [3617,1350,970,26018,2114,1412,2236,286,351,422])
        self.assertEqual(len(SNAPSHOT_SOURCE),10)
        self.assertEqual(len(old.SNAPSHOT_SOURCE),9)
        self.assertNotEqual(w.SNAPSHOT_HASHES[1],keccak256(old.SNAPSHOT_PROFILE_BYTES))
        self.assertEqual([d['id'] for d in w.definitions()], [schema_id(d['name']) for d in w.definitions()])
        b,c,g,s,o=supplied()
        b['snapshot']['receipt'][15]=keccak256(old.SNAPSHOT_PROFILE_BYTES)
        seal_snapshot(b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'definitions'): w.validate_snapshot(b['snapshot'],c,g)

    def test_collection_and_view_not_original_scoped_profile(self):
        for scope in (0,4):
            b,c,g,s,o=supplied(); b['snapshot']['publication'][0][0]=str(scope)
            with self.assertRaisesRegex(MuseumError,'scope unsupported'): w.validate_snapshot(b['snapshot'],c,g)

    def test_factory_identity_dependencies_and_current_authority_hash_fail_closed(self):
        for index,value in ((6,A(999)),(7,H('other code')),(8,H('CurrentAuthority recipe'))):
            b,c,g,s,o=supplied(); b['snapshot']['source'][index]=value
            seal_snapshot(b['snapshot'],c,g)
            with self.assertRaisesRegex(MuseumError,'factory identity'): w.validate_snapshot(b['snapshot'],c,g)

    def test_root_free_snapshot_uses_actual_output_record_key(self):
        b,c,g,s,o=supplied(); b['snapshot']['publication'][4]=b['snapshot']['receipt'][5]
        seal_snapshot(b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'actual output record'): w.validate_snapshot(b['snapshot'],c,g,o)

    def test_complete_policy_chain_and_first_occurrence(self):
        b,c,g,s,o=supplied(); b['snapshot']['source'][9][2]=H('V1 policy chain')
        seal_snapshot(b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'V2 chain hash'): w.validate_snapshot(b['snapshot'],c,g)
        b,c,g,s,o=supplied(); o['selectionRows'][1][6][3]=A(995)
        with self.assertRaisesRegex(MuseumError,'first-occurrence'): w.validate_snapshot(b['snapshot'],c,g,o)

    def test_rehashed_policy_content_state_and_terminal_status(self):
        b,c,g,s,o=supplied(); b['snapshot']['source'][9][5][0][14][9]=H('wrong state')
        seal_snapshot(b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'explicit V2'): w.validate_snapshot(b['snapshot'],c,g)
        for index,value in ((8,True),(9,H('fabricated seed')),(3,'5')):
            b,c,g,s,o=supplied(); b['reference']['source'][7][0][3][index]=value
            seal_reference(b['reference'],b['snapshot'],c,g)
            with self.assertRaisesRegex(MuseumError,'terminal status'): w.validate(b,c,g,None)

    def test_first_last_ordinal_and_exact_output_join(self):
        b,c,g,s,o=supplied(); b['reference']['source'][7][1][0]='1'
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'identity/ordinal'): w.validate(b,c,g,None)
        b,c,g,s,o=supplied(); o['outputs'][-1][0][5]=H('different token data')
        with self.assertRaisesRegex(MuseumError,'complete output join'): w.validate(b,c,g,s,o)

    def test_original_html_environment_and_external_object(self):
        b,c,g,s,o=supplied(); b['reference']['publication'][1][7][0][5]='0x626164'
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'sample byte'): w.validate(b,c,g,None)
        b,c,g,s,o=supplied(); b['reference']['environment']='0x7b7d'
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'environment bytes'): w.validate(b,c,g,None)
        b,c,g,s,o=supplied(); b['reference']['objects'][0]['identity'][7]=schema_id('IANA:image/png')
        with self.assertRaisesRegex(MuseumError,'archive object/role'): w.validate(b,c,g,None)

    def test_original_root_scope_factory_and_artist_are_not_current_substitutes(self):
        for field,value in ((8,H('other Artist')),(9,'2'),(10,H('other binding'))):
            b,c,g,s,o=supplied(); b['reference']['source'][4][field]=value
            seal_reference(b['reference'],b['snapshot'],c,g)
            with self.assertRaisesRegex(MuseumError,'scoped root/snapshot/Artist'): w.validate(b,c,g,None)
        b,c,g,s,o=supplied(); b['reference']['source'][5][17]=A(999)
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'interpretation/factory'): w.validate(b,c,g,None)

    def test_reference_root_uses_exact_content_root_profile(self):
        b,c,g,s,o=supplied()
        source=from_json(REFERENCE_SOURCE,b['reference']['source'])
        native=w.content_wire.binding_for(g,source[2][5][0],source[2][4],
            from_json(POLICY_DEPS,b['snapshot']['entropyDependencies']))
        self.assertEqual(source[5],native)
        w.validate(b,c,g,s,o)
        # Rebuild the root and reference hashes around the wrong but related
        # content profile; the profile identity itself must still be rejected.
        source=list(source); binding=list(source[5]); binding[0]=ct.PROFILE
        root=list(source[4]); root[15]=w.content_wire.root_state_hash(
            int(c['chainId']),g['router']['address'],c['core'],tuple(root),tuple(binding))
        aggregate=w.content_wire.next_aggregate(int(c['chainId']),g['router']['address'],
            c['core'],(0,ZERO),tuple(root))
        source[3]=w.content_wire.root_hash(int(c['chainId']),g['router']['address'],
            c['core'],tuple(root),tuple(binding),aggregate)
        source[4:6]=tuple(root),tuple(binding)
        b['reference']['source']=jsonify(source)
        seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'interpretation/factory'):
            w.validate(b,c,g,None)

    def test_native_publication_authority_classes_not_artist_classes(self):
        b,c,g,s,o=supplied(); b['snapshot']['receipt'][9]='1'; seal_snapshot(b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'authority'): w.validate_snapshot(b['snapshot'],c,g)
        b,c,g,s,o=supplied(); b['reference']['receipt'][1][12]='7'; seal_reference(b['reference'],b['snapshot'],c,g)
        with self.assertRaisesRegex(MuseumError,'authority'): w.validate(b,c,g,None)

    def test_head_lock_uri_and_exact_abi_payload(self):
        b,c,g,s,o=supplied(); b['snapshot']['head']=H('other head')
        with self.assertRaisesRegex(MuseumError,'current head'): w.validate_snapshot(b['snapshot'],c,g)
        b,c,g,s,o=supplied(); b['reference']['lock'][1]='2'
        with self.assertRaisesRegex(MuseumError,'lock/head/revision'): w.validate(b,c,g,None)
        b,c,g,s,o=supplied(); b['snapshot']['publication'][7]='file:///not-native'
        seal_snapshot(b['snapshot'],c,g)
        with self.assertRaises(MuseumError): w.validate_snapshot(b['snapshot'],c,g)
        b,c,g,s,o=supplied(); b['snapshot']['payload']+='00'
        with self.assertRaisesRegex(MuseumError,'payload/hash'): w.validate_snapshot(b['snapshot'],c,g)

    def test_original_component_preimages_bind_scope_and_factory_inventory(self):
        b,c,g,s,o=supplied(); out=w.validate(b,c,g,s,o)
        source=from_json(SNAPSHOT_SOURCE,b['snapshot']['source']); d=from_json(POLICY_DEPS,b['snapshot']['entropyDependencies'])
        inv,pin=g['tokenInventory']['address'],g['tokenInventory']['runtimeHash']; e=source[9]
        self.assertEqual(out['componentCommitments']['entropy']['dataHash'],keccak256(encode(
            ('bytes32',SCOPE,'bytes32','bytes32','bytes32',MEMBERSHIP_FACTS,'address','bytes32'),
            (w.SOURCE_SET_PROFILE,source[0],e[0],e[1],e[2],source[1],inv,pin))))
        receipt=from_json(REFERENCE_RECEIPT,b['reference']['receipt']); lock=from_json(REFERENCE_LOCK,b['reference']['lock'])
        expected=_hash('6529STREAM_LOCKED_SCOPED_POLICY_REFERENCE_COMPONENT_V2',
            ('uint256','address','address',SCOPE,REFERENCE_RECEIPT,REFERENCE_LOCK),
            (int(c['chainId']),g['policyReference']['address'],c['core'],source[0],receipt,lock))
        self.assertEqual(out['componentCommitments']['reference']['dataHash'],expected)


class ScopedPolicySourceReadTests(unittest.TestCase):
    def test_original_read_path_offline_uses_real_native_getters_only(self):
        f=ReadFixture()
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            self.assertEqual(f._preservation(f.statement,f.content),f.bundle)
        self.assertEqual(len(f.history_queries),2)
        self.assertGreater(len(f.pieces),2)
        forbidden=('requireCurrent','tokenEntropyReadiness','currentInventoryPlan','ChunkCount','ChunkAt')
        self.assertFalse(any(any(part in q for part in forbidden) for q in f.queries))

    def test_original_source_policy_and_current_head_conflicts(self):
        f=ReadFixture(); row=list(from_json(POLICY_ROW,f.bundle['snapshot']['source'][9][5][0])); row[8]=H('other policy')
        f.add(f.a['entropySourceSet'],'sourcePolicyAt(uint256)',(POLICY_ROW,),(tuple(row),),('uint256',),(0,))
        with self.assertRaisesRegex(MuseumError,'immutable policy differs'): f._preservation(f.statement,f.content)
        f=ReadFixture(); r=list(from_json(SNAPSHOT_RECEIPT,f.bundle['snapshot']['receipt'])); r[0]=H('other head')
        scope=from_json(SCOPE,f.statement[0]); f.add(f.a['policySnapshot'],'currentSnapshot('+SCOPE_SIGNATURE+')',
            (SNAPSHOT_RECEIPT,),(tuple(r),),(SCOPE,),(scope,))
        with self.assertRaisesRegex(MuseumError,'head differs'): f._preservation(f.statement,f.content)

    def test_payload_store_bytes_and_original_denominator(self):
        f=ReadFixture(); digest=next(iter(f.pieces)); f.pieces[digest]=b'other'
        with self.assertRaisesRegex(MuseumError,'Store chunk bytes'): f._preservation(f.statement,f.content)
        f=ReadFixture(); scope=from_json(SCOPE,f.statement[0])
        f.add(f.a['policySnapshot'],'snapshotCount('+SCOPE_SIGNATURE+')',('uint256',),(MAX_HISTORY+1,),(SCOPE,),(scope,))
        with self.assertRaisesRegex(MuseumError,'history bound'): f._preservation(f.statement,f.content)

    def test_factory_saved_pair_profile_and_checkpoint_bindings(self):
        f=ReadFixture(); e=f.bundle['snapshot']['source'][9]
        f.add(f.a['sourceFactory'],'sourceSetForPlan(bytes32)',('address','bytes32'),(A(999),H('other runtime')),('bytes32',),(e[0],))
        with self.assertRaisesRegex(MuseumError,'saved source-set'): f._preservation(f.statement,f.content)
        f=ReadFixture(); f.add(f.a['sourceFactory'],'scopedPolicyFactoryProfile()',('bytes32',),(H('CurrentAuthority variant'),))
        with self.assertRaisesRegex(MuseumError,'factory profile'): f._preservation(f.statement,f.content)
        f=ReadFixture(); f.add(f.a['policyContent'],'factoryDependenciesHash()',('bytes32',),(H('other deps'),))
        with self.assertRaisesRegex(MuseumError,'checkpoint original factory'): f._preservation(f.statement,f.content)

    def test_saved_component_and_archive_cannot_be_replaced(self):
        f=ReadFixture(); f.add(f.a['entropySourceSet'],'sourceSetDataHash()',('bytes32',),(H('other data'),))
        with self.assertRaisesRegex(MuseumError,'manifest/data preimages'): f._preservation(f.statement,f.content)
        f=ReadFixture(); cov=list(from_json(EXTERNAL_COVERAGE,f.bundle['reference']['source'][6])); key=cov[0]; cov[12]=H('other fixity')
        f.add(f.a['externalCoverage'],'coverage(bytes32)',(EXTERNAL_COVERAGE,),(tuple(cov),),('bytes32',),(key,))
        with self.assertRaisesRegex(MuseumError,'saved coverage differs'): f._preservation(f.statement,f.content)


if __name__ == '__main__': unittest.main()
