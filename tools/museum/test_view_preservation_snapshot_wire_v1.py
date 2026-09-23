"""Coherent synthetic originals for the independent root-free VIEW snapshot codec."""
from copy import deepcopy
import unittest

from . import view_preservation_snapshot_types_v1 as t, view_preservation_snapshot_wire_v1 as w
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import encode
from .independent_wire import ZERO, json_values
from .native_finality_wire import from_json
from .test_view_policy_output_wire_v2 import A, H
from .view_preservation_snapshot_source_reads_v1 import ViewPreservationSnapshotReads, SCOPE_SIGNATURE


def base(count=3, *, context=None, graph=None):
    from .test_view_policy_membership_v2 import supplied as members
    from .test_view_policy_adoption_wire_v2 import supplied as adopted
    from .view_policy_adoption_wire_v2 import validate as validate_adoption
    from .view_policy_membership_v2 import validate as validate_members
    from .test_view_preservation_output_wire_v1 import supplied as outputs
    from .native_view_policy_output_wire_v2 import GRAPH_KEYS
    roles = [k for k in GRAPH_KEYS if k not in ('serving', 'servingWorker')]
    roles += ['preservationRenderer', 'preservationAttribution', 'preservationWorker', 'preservationEncoding', 'viewSnapshot']
    context = deepcopy(context) if context is not None else {'chainId':'31337','core':A(76000),
        'collectionId':'1','tokenId':'41','timestamp':'140','blockNumber':'40','blockHash':H('block40')}
    graph = deepcopy(graph) if graph is not None else {role:{'address':context['core'] if role=='core' else A(76000+i),
        'runtimeHash':H('preservation runtime '+role)} for i,role in enumerate(roles)}
    member, _, _, binding = members(count, modes=('disabled',), context=context, graph=graph, recorded_at=101)
    # The unchanged adoption fixture needs its unrelated old live-serving fixture
    # fields. They are never projected into this preservation graph or evidence.
    fixture_graph = {**{k:graph[k] for k in GRAPH_KEYS if k not in ('serving','servingWorker')}, 'serving':{'address':A(78990),'runtimeHash':H('fixture live serving')},
        'servingWorker':{'address':A(78991),'runtimeHash':H('fixture live worker')}}
    original = adopted(context=context, graph=fixture_graph, policy_binding=binding,
        adopted_at=103, later_head=False, include_v1=False)
    a = validate_adoption(original, context, fixture_graph)
    m = validate_members(member, context, graph, binding)
    a = {**a, 'adoptionProfile':a['profile'], 'tokenIds':m['tokenIds'], 'policies':m['policies']}
    out, _, _, a = outputs(count, context=context, graph=graph, adoption=a, coverage_timestamp=106)
    return out, context, graph, a, m


def reseal(value, context, graph):
    previous, chain = ZERO, ZERO
    for index,row in enumerate(value['history']):
        p, r = row['publication'],row['receipt']
        p[2:4] = [previous,str(index)]; r[2:4] = [previous,str(index+1)]
        p[6] = r[7] = w.source_hash(row['source'],value['dependencies'],context,graph)
        raw = w.payload(p,r,row['source'],value['dependencies'],context,graph)
        r[5],r[6] = keccak256(raw),str(len(raw))
        r[0] = w.record_hash(p,r,context,graph)
        r[4] = w.chain_hash(chain,p,r,context,graph)
        row['payload'] = '0x'+raw.hex();row['chunks'] = []
        for offset in range(0,len(raw),8192):
            body=raw[offset:offset+8192];runtime=b'\0'+body
            row['chunks'].append({'pointer':'0x'+keccak256(runtime)[-40:],'chunkHash':keccak256(body),
                'byteLength':str(len(body)),'runtime':'0x'+runtime.hex()})
        previous,chain=r[0],r[4]
    value['current']=deepcopy(value['history'][-1]['receipt'])
    value['selectedRecordHash']=value['history'][0]['receipt'][0]
    if value['lock'][2] != ZERO:value['lock'][:2]=[previous,str(len(value['history']))]
    return value


def supplied(count=3, *, context=None, graph=None, output_value=None, adoption=None,
             membership=None, recorded_at=107, locked=True):
    """Return (snapshot,context,graph); external actual output/member joins supported."""
    if output_value is None:
        output_value,context,graph,adoption,membership=base(count,context=context,graph=graph)
    else:
        context,graph=deepcopy(context),deepcopy(graph)
    source = output_value['checkpoint']['source']
    scope = source[0][0][0]
    facts = source[1][8]
    artist = [True,graph['artist']['address'],graph['artist']['runtimeHash'],
        output_value['manifest']['plan'][1][2],'1',H('Artist binding'),A(78900),H('identity'),
        H('acceptance'),'102','104',H('Artist presentation snapshot')]
    entropy = membership['evidence']
    s = [scope,facts,artist,source,output_value['checkpoint']['plan'],output_value['manifest']['plan'],entropy]
    d = [[graph[k]['address'] for k in t.DEPENDENCY_ROLES],
        [graph[k]['runtimeHash'] for k in t.DEPENDENCY_ROLES],context['chainId'],'100000','8000000','8000000']
    p = [scope,H('snapshot ID'),ZERO,'0',output_value['manifest']['recordHash'],source[0][3],ZERO,
        'ipfs://original-view-snapshot',str(recorded_at),H('reason')]
    r = [ZERO,facts[0],ZERO,'1',ZERO,ZERO,'0',ZERO,A(78901),'7','1','8','2',str(recorded_at),
        w.SCHEMA_HASH,w.PROFILE_HASH,w.CANON_HASH]
    value = {'dependencies':d,'selectedRecordHash':ZERO,'current':r,'history':[{
        'publication':p,'receipt':r,'source':deepcopy(s),'payload':'0x','chunks':[]}],
        'lock':[ZERO,'0',H('class2 lock action') if locked else ZERO,str(recorded_at+1) if locked else '0']}
    reseal(value,context,graph)
    return value,context,graph


def install_snapshot_reads(fixture,value,context,graph):
    host=graph['viewSnapshot']['address'];scope=from_json(t.SCOPE,value['history'][0]['publication'][0])
    def put(sig,outputs,values,inputs=(),args=()):fixture.add(host,sig,inputs,args,outputs,values)
    put('core()',('address',),(context['core'],));put('metadataHost()',('address',),(graph['metadata']['address'],))
    put('dependencies()',(t.DEPENDENCIES,),(from_json(t.DEPENDENCIES,value['dependencies']),))
    put('governanceAuthority()',('address',),(graph['authority']['address'],))
    put('authorityCodeHash()',('bytes32',),(graph['authority']['runtimeHash'],))
    put('snapshotCount('+SCOPE_SIGNATURE+')',('uint256',),(len(value['history']),),(t.SCOPE,),(scope,))
    for index,row in enumerate(value['history']):
        p,r=from_json(t.PUBLICATION,row['publication']),from_json(t.RECEIPT,row['receipt']);key=r[0]
        put('snapshotAt('+SCOPE_SIGNATURE+',uint256)',('bytes32',),(key,),(t.SCOPE,'uint256'),(scope,index))
        put('snapshotRecord(bytes32)',(t.PUBLICATION,t.RECEIPT),(p,r),('bytes32',),(key,))
        put('snapshotPayload(bytes32)',('bytes',),(hex_bytes(row['payload']),),('bytes32',),(key,))
        put('snapshotChunkCount(bytes32)',('uint256',),(len(row['chunks']),),('bytes32',),(key,))
        for offset,chunk in enumerate(row['chunks']):
            pointer,digest,length=chunk['pointer'],chunk['chunkHash'],int(chunk['byteLength'])
            put('snapshotChunkAt(bytes32,uint256)',('address','bytes32','uint32'),(pointer,digest,length),('bytes32','uint256'),(key,offset))
            fixture.add(graph['store']['address'],'chunk(bytes32)',('bytes32',),(digest,),('address','uint32'),(pointer,length))
            runtime=hex_bytes(chunk['runtime']);fixture.codes[pointer]=runtime;fixture.pins[pointer]=keccak256(runtime)
    put('currentSnapshot('+SCOPE_SIGNATURE+')',(t.RECEIPT,),(from_json(t.RECEIPT,value['current']),),(t.SCOPE,),(scope,))
    put('snapshotLock('+SCOPE_SIGNATURE+')',(t.LOCK,),(from_json(t.LOCK,value['lock']),),(t.SCOPE,),(scope,))


class ReadHarness(ViewPreservationSnapshotReads):
    def __init__(self,value,context,graph):
        self.a={**context,'scope':value['history'][0]['publication'][0],'snapshotRecordHash':value['selectedRecordHash']}
        self.graph=graph;self.responses={};self.codes={};self.pins={};self.calls=[];self.histories=[]
        self.logs=[{'address':row['address'],'topics':list(row['topics']),'data':row['data']}
            for row in w.expected_events(value,context,graph)]
        install_snapshot_reads(self,value,context,graph)
    def add(self,host,sig,inputs,args,outputs,values):self.responses[(host,sig,encode(inputs,args))]=values
    def _read(self,host,sig,outputs,inputs=(),values=(),**kwargs):
        self.calls.append(sig);return self.responses[(host,sig,encode(inputs,values))]
    def _one(self,*args,**kwargs):return self._read(*args,**kwargs)[0]
    def _carrier(self,pointer,digest,maximum):
        raw=self.codes[pointer];assert keccak256(raw)==digest and raw[0]==0 and len(raw)-1<=maximum;return raw[1:]
    def _history(self,host,topics):
        self.histories.append((host,topics))
        return {'logs':[row for row in self.logs if row['address']==host and row['topics'][:len(topics)]==topics]}


class ViewPreservationSnapshotTests(unittest.TestCase):
    def test_exact_original_definition_pins(self):
        self.assertEqual([(len(r['bytes']),r['hash']) for r in w.definitions()],[(19553,'0x93318b938a22ba634ffc52b9f726deefd427b96a849d86bf6ed18c6827561b2e'),
            (1099,'0x2ca42835d28a332a6607518127b566a8ce427f955fb08f7650c00180e15969f4'),(833,'0xa749d9fc1982426d543e3efb2fdf7782fb2cf2a5f4ce723c3b1848f094efc032')])
    def test_original_payload_grants_optional_lock_and_crossjoins(self):
        out,x,g,a,m=base()
        for locked in (False,True):
            value,_,_=supplied(context=x,graph=g,output_value=out,adoption=a,membership=m,locked=locked)
            result=w.validate(value,x,g,adoption=a,membership=m,output_value=out)
            self.assertEqual(result['source'][3],out['checkpoint']['source'])
            self.assertEqual(len(w.expected_events(value,x,g)),2 if locked else 1)
    def test_history_preserves_selected_original_and_later_head(self):
        v,x,g=supplied(locked=False);second=deepcopy(v['history'][0]);second['publication'][1]=H('second snapshot')
        second['publication'][8]=second['receipt'][13]='109';v['history'].append(second);reseal(v,x,g)
        self.assertNotEqual(w.validate(v,x,g)['recordHash'],v['current'][0])
        bad=deepcopy(v);bad['history'].pop();
        with self.assertRaisesRegex(MuseumError,'stored head'):w.validate(bad,x,g)
    def test_wrong_zeroing_or_payload_bytes_rejected(self):
        v,x,g=supplied();v['history'][0]['payload']+='00'
        with self.assertRaisesRegex(MuseumError,'canonical original payload'):w.validate(v,x,g)
    def test_rehashed_authority_and_profile_substitution_rejected(self):
        for index,value in ((9,'1'),(11,'3'),(14,H('different schema'))):
            v,x,g=supplied();v['history'][0]['receipt'][index]=value;reseal(v,x,g)
            with self.assertRaisesRegex(MuseumError,'writer grants/definitions'):w.validate(v,x,g)
    def test_rehashed_source_adoption_and_policy_corruption_rejected(self):
        for change in ('adoption','policy'):
            v,x,g=supplied();s=v['history'][0]['source']
            if change=='adoption':s[3][0][3]=H('different adoption')
            else:s[6][5][0][12]=H('different policy component')
            reseal(v,x,g)
            with self.assertRaises(MuseumError):w.validate(v,x,g)
    def test_store_carrier_and_complete_chunk_denominator(self):
        v,x,g=supplied();v['history'][0]['chunks'].pop()
        with self.assertRaisesRegex(MuseumError,'chunk denominator'):w.validate(v,x,g)
        v,x,g=supplied();v['history'][0]['chunks'][0]['runtime']='0x01'+v['history'][0]['chunks'][0]['runtime'][4:]
        with self.assertRaisesRegex(MuseumError,'Store carrier'):w.validate(v,x,g)
    def test_noncanonical_uri_and_lock_conflict(self):
        v,x,g=supplied();v['history'][0]['publication'][7]='http://invalid';reseal(v,x,g)
        with self.assertRaisesRegex(MuseumError,'URI'):w.validate(v,x,g)
        v,x,g=supplied();v['lock'][0]=H('other locked record')
        with self.assertRaisesRegex(MuseumError,'lock/head'):w.validate(v,x,g)
    def test_offline_original_getter_roundtrip(self):
        v,x,g=supplied();h=ReadHarness(v,x,g)
        self.assertEqual(h._view_preservation_snapshot(),v)
        self.assertFalse(any('requireCurrent' in s or 'currentSource' in s for s in h.calls))
        self.assertEqual(len(h.histories),2)
    def test_nonselected_history_cannot_reassign_original_admission(self):
        v,x,g=supplied(locked=False);second=deepcopy(v['history'][0])
        second['publication'][1]=H('second snapshot');second['publication'][8]=second['receipt'][13]='109'
        second['source'][3][3][2]=H('different original admission version')
        v['history'].append(second);reseal(v,x,g)
        with self.assertRaisesRegex(MuseumError,'preservation producer originals'):w.validate(v,x,g)
    def test_reader_rejects_returned_original_from_other_view_scope(self):
        v,x,g=supplied();h=ReadHarness(v,x,g);scope=deepcopy(h.a['scope']);scope[3]=H('other VIEW scope')
        native=from_json(t.SCOPE,scope);host=g['viewSnapshot']['address'];key=v['selectedRecordHash']
        h.add(host,'snapshotCount('+SCOPE_SIGNATURE+')',(t.SCOPE,),(native,),('uint256',),(1,))
        h.add(host,'snapshotAt('+SCOPE_SIGNATURE+',uint256)',(t.SCOPE,'uint256'),(native,0),('bytes32',),(key,))
        with self.assertRaisesRegex(MuseumError,'indexed original/scope'):h._view_preservation_snapshot(key,scope)
    def test_reader_rejects_omitted_publication_tail_despite_matching_getter_head(self):
        v,x,g=supplied(locked=False);h=ReadHarness(v,x,g)
        second=deepcopy(v['history'][0]);second['publication'][1]=H('hidden second snapshot')
        second['publication'][8]=second['receipt'][13]='109';v['history'].append(second);reseal(v,x,g)
        row=w.expected_events(v,x,g)[1]
        h.logs.append({'address':row['address'],'topics':list(row['topics']),'data':row['data']})
        with self.assertRaisesRegex(MuseumError,'complete publication/lock event history'):
            h._view_preservation_snapshot()
    def test_reader_rejects_missing_or_unreported_lock_events(self):
        for recorded in (False,True):
            v,x,g=supplied(locked=recorded);h=ReadHarness(v,x,g)
            if recorded:h.logs=[row for row in h.logs if row['topics'][0]!=w.LOCKED]
            else:
                locked,_,_=supplied(context=x,graph=g,locked=True)
                row=w.expected_events(locked,x,g)[-1]
                h.logs.append({'address':row['address'],'topics':list(row['topics']),'data':row['data']})
            with self.assertRaisesRegex(MuseumError,'complete publication/lock event history'):
                h._view_preservation_snapshot()


if __name__=='__main__':unittest.main()
