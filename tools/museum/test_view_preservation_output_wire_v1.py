"""Independent synthetic VIEW row/carrier vectors; no renderer/native execution."""
from copy import deepcopy
import unittest
from . import view_preservation_output_types_v1 as t, view_preservation_output_wire_v1 as w
from .canonical import MuseumError, keccak256, schema_id, hex_bytes
from .chain_abi import encode, decode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values


def A(n):return '0x'+int(n).to_bytes(20,'big').hex()
def H(s):return schema_id('synthetic VIEW '+str(s))
def zero_policy():return (False,False,False,0,0,0,0,0,ZERO,ZERO,ZERO,ZERO)

def make_rule(mode='disabled'):
    explicit=mode!='legacy';digest=H('policy '+mode)
    p=zero_policy()
    if explicit:
        policy_mode=0 if mode=='disabled' else 2
        p=(True,True,True,policy_mode,0,0 if mode=='finalized' else 1,1,1,digest,
            keccak256(encode(('bytes32','bytes32','bool'),(t.POLICY_FAMILY,digest,True))),H('action'),H('consent'))
    return (A(9100),H('coordinator code'),0,True,H('module'),H('manifest'),H('schema'),H('deployment'),
        digest,ZERO_ADDRESS if explicit else A(9101),0 if explicit else 1,ZERO if explicit else H('salt'),H('component'),explicit,p)

def carrier(raw,artist,schema,canon,label,stamp):
    artifact,coverage=H('artifact '+label+keccak256(raw)),H('coverage '+label+keccak256(raw))
    saved=(artifact,coverage,artist,keccak256(raw),len(raw))
    chunks=[]
    for i in range(0,len(raw),8192):
        runtime=b'\0'+raw[i:i+8192];digest=keccak256(runtime)
        chunks.append({'pointer':'0x'+digest[-40:],'codeHash':digest,'runtime':'0x'+runtime.hex()})
    receipt=(coverage,artifact,artist,schema,canon,saved[3],len(raw),len(chunks),H('archive family1'),H('archive family2'),stamp,H('chunk receipt chain'))
    return saved,{'coverage':json_values(receipt),'chunks':chunks}

def reseal(value,context,graph,adoption,*,coverage_timestamp=None):
    """Recompute only output commitments; never assert new adoption/archive authority."""
    pair=lambda k:(graph[k]['address'],graph[k]['runtimeHash'])
    chain=int(context['chainId']);cfg=value['configuration']
    c=w._v(t.CHECKPOINT_CONFIG,cfg['checkpoint']);m=list(w._v(t.MANIFEST_CONFIG,cfg['manifest']))
    cfg['checkpointHash']=w.configuration_hash(t.PROFILE,chain,pair('checkpoint')[0],t.CHECKPOINT_CONFIG,c,
        (pair('checkpointSourceWorker'),pair('checkpointTokenWorker')))
    m[4]=cfg['checkpointHash'];cfg['manifest']=json_values(m)
    cfg['manifestHash']=w.configuration_hash(t.MANIFEST_PROFILE,chain,pair('outputManifest')[0],t.MANIFEST_CONFIG,m,
        (pair('manifestReadWorker'),pair('manifestEncodingWorker')))
    b=w._v(t.VIEW_BINDING,adoption['policyBinding']);scope=w._v(t.SCOPE,adoption['scope'])
    source=w.source_context_hash(chain,pair('checkpoint')[0],c,scope,adoption['record'][3],adoption['record'][2],b,w._v(t.PRESERVATION_BINDING,adoption['preservation']['binding']),w._v(t.ADMISSION,adoption['preservation']['admission']))
    cp=value['checkpoint'];rows=tuple(w._v(t.OUTPUT,row) for row in cp['outputs']);count=len(rows)
    p=[scope,adoption['record'][3],source,b[8][5],b[11],count,count,ZERO,ZERO,ZERO]
    cp['source']=json_values(w.original_source(adoption,source))
    cp['id']=w.checkpoint_id(chain,pair('checkpoint')[0],cfg['checkpointHash'],scope,source,count,cp['salt'])
    p[7]=w.row_chain(chain,pair('checkpoint')[0],cp['id'],p,rows)
    p[9]=w.content_root(tuple(w.leaf_hash(chain,pair('core')[0],scope,p[1],row) for row in rows))
    p[8]=w.output_root(chain,pair('checkpoint')[0],cfg['checkpointHash'],cp['id'],p)
    cp['plan']=json_values(p);header=w.header(cp['id'],p)
    parts=[];descriptors=[];artist=H('archive artist label')
    stamp=int(coverage_timestamp) if coverage_timestamp is not None else int(context['timestamp'])-1
    for index,first in enumerate(range(0,count,64)):
        group=rows[first:first+64];raw=w.part_bytes(m,header,first,group)
        saved,evidence=carrier(raw,artist,t.PART_SCHEMA,t.PART_CANON,'part'+str(index),stamp)
        part=(header,saved,first,len(group),group[0][1],group[-1][1])
        key=w.part_hash(chain,pair('outputManifest')[0],cfg['manifestHash'],part);desc=w.descriptor(key,part)
        parts.append({'recordHash':key,'record':json_values(part),'descriptor':json_values(desc),**evidence});descriptors.append(desc)
    raw=w.index_bytes(m,header,artist,descriptors)
    saved,evidence=carrier(raw,artist,t.INDEX_SCHEMA,t.INDEX_CANON,'index',stamp)
    key=w.manifest_plan_hash(chain,pair('outputManifest')[0],cfg['manifestHash'],header,saved)
    pc=w.part_chain(key,header,descriptors)
    record=w.manifest_record_hash(chain,pair('outputManifest')[0],cfg['manifestHash'],key,pc)
    plan=(header,saved,len(parts),len(parts),count,rows[-1][1],pc,record)
    value['manifest']={'planHash':key,'recordHash':record,'plan':json_values(plan),'parts':parts,**evidence}
    return value

def supplied(count=3,mode='disabled',burned=False,*,context=None,graph=None,adoption=None,serving_configuration_hash=None,coverage_timestamp=None):
    """Caller-admitted synthetic adoption projection; use real adoption helper for integrated evidence."""
    context=deepcopy(context) if context is not None else {'chainId':'11155111','core':A(9000),'collectionId':'1','timestamp':'1000'}
    if graph is None:
        graph={role:{'address':context['core'] if role=='core' else A(9000+i),'runtimeHash':H('runtime '+role)} for i,role in enumerate(t.GRAPH_KEYS)}
    graph=deepcopy(graph);pair=lambda k:(graph[k]['address'],graph[k]['runtimeHash'])
    rule=make_rule(mode)
    if adoption is None:
        scope=(4,int(context['collectionId']),0,H('scope'));tokens=tuple(range(41,41+count))
        facts=(H('scope subject'),H('membership manifest'),H('membership record'),count,
            keccak256(encode(('uint256',)*count,tokens)),H('membership'),0,ZERO)
        binding=(*pair('core'),A(9300),H('factory'),A(9301),H('source set'),int(context['chainId']),scope,facts,H('inventory plan'),H('inventory'),H('policy chain'),1)
        route=(*pair('core'),*pair('router'),A(9310),H('artist runtime'),A(9311),H('finality runtime'),A(9312),H('provider runtime'),A(9313),H('metadata runtime'),*pair('schemas'),A(9314),H('store runtime'),(A(9315),H('views runtime'),A(9316),H('membership runtime'),50000,100000))
        selection=(A(9320),H('registry runtime'),H('renderer key'),A(9321),H('renderer runtime'),H('renderer family'),H('capability'),H('module'),H('module manifest'),H('module schema'),H('record'))
        source=(route,facts,selection,*[H('source field'+str(i)) for i in range(6)],0,(ZERO_ADDRESS,)*5,(ZERO,)*5)
        record=((scope,H('viewId'),H('view declaration'),ZERO,selection[0],selection[2],H('sourceHash')),source,H('sourceHash'),H('adoptionRecord'),1,A(9330),1,0,0,H('consent'),900,(1,H('aggregate')))
        adoption={'profile':H('supplied preservation evidence'),'adoptionProfile':t.ADOPTION_PROFILE,'scope':json_values(scope),'record':json_values(record),
            'policyBinding':json_values(binding),'tokenIds':list(map(str,tokens)),'policies':json_values((rule,))}
    adoption=deepcopy(adoption)
    if 'preservation' not in adoption:
        r=adoption['record'][1][2]
        binding=(pair('core')[0],pair('router')[0],r[3],r[4],*pair('preservationAttribution'))
        admission=(*r[:3],H('preservation registration'),H('preservation reads'),H('preservation analysis'),H('preservation golden'))
        producer=(*pair('preservationRenderer'),t.OUTPUT_PROFILE,pair('core')[0],pair('router')[0],r[3],r[4],*pair('preservationAttribution'))
        configuration=(*pair('core'),*pair('router'),*pair('preservationAttribution'),int(context['chainId']),100000,100000)
        adoption['preservation']={'configuration':json_values(configuration),'configurationHash':H('serving configuration'),
            'binding':json_values(binding),'admission':json_values(admission),'producerBinding':json_values(producer)}
    tokens=tuple(map(int,adoption['tokenIds']));count=len(tokens)
    rules=tuple(w._v(t.POLICY_ROW,x) for x in adoption['policies'])
    rows=[]
    for i,token in enumerate(tokens):
        rule=max((x for x in rules if x[2]<=i),key=lambda x:x[2]);p=rule[14]
        status=(1 if p[3]==0 else 2) if rule[13] and p[5]==1 else 5
        entropy=(rule[0],rule[1],rule[8],rule[13],p,status,ZERO if status!=5 else H('seed'),status==5,status!=5)
        rows.append((i,token,i+1,3 if burned and i==0 else 2,bool(burned and i==0),2 if burned and i==0 else 1,
            H('token data'+str(token)),entropy,H('JSON'+str(token)),H('HTML'+str(token)),200,400))
    c=(*pair('core'),*pair('router'),*pair('authority'),*pair('preservationRenderer'),serving_configuration_hash or adoption['preservation']['configurationHash'],int(context['chainId']),50000,500000)
    m=(*pair('core'),*pair('checkpoint'),ZERO,*pair('coverage'),*pair('schemas'),int(context['chainId']),50000,1000000)
    value={'configuration':{'checkpoint':json_values(c),'checkpointHash':ZERO,'manifest':json_values(m),'manifestHash':ZERO},
        'checkpoint':{'id':ZERO,'salt':H('checkpoint salt'),'plan':None,'outputs':json_values(rows)},'manifest':None}
    reseal(value,context,graph,adoption,coverage_timestamp=coverage_timestamp)
    return value,context,graph,adoption


def install_output_reads(fixture,value,context,graph):
    """Populate exact historical getters/codes; caller installs all event coordinates."""
    def put(role,signature,outputs,values,inputs=(),args=()):
        fixture.add(graph[role]['address'],signature,inputs,args,outputs,values)
    cfg=value['configuration'];cp=value['checkpoint'];m=value['manifest']
    for role,key,kind,profile,getter,interface in (
        ('checkpoint','checkpoint',t.CHECKPOINT_CONFIG,t.PROFILE,'checkpointProfile()',t.CHECKPOINT_INTERFACE),
        ('outputManifest','manifest',t.MANIFEST_CONFIG,t.MANIFEST_PROFILE,'outputProfile()',t.MANIFEST_INTERFACE)):
        put(role,'configuration()',(kind,),(w._v(kind,cfg[key]),))
        put(role,'configurationHash()',('bytes32',),(cfg[key+'Hash'],))
        put(role,getter,('bytes32',),(profile,))
        for selector,expected in ((interface,True),('0x01ffc9a7',True),('0xffffffff',False)):
            put(role,'supportsInterface(bytes4)',('bool',),(expected,),('bytes4',),(selector,))
    for role,getter,worker in (
        ('checkpoint','sourceWorkerCodeHash()','checkpointSourceWorker'),('checkpoint','tokenWorkerCodeHash()','checkpointTokenWorker'),
        ('outputManifest','readWorkerCodeHash()','manifestReadWorker'),('outputManifest','encodingWorkerCodeHash()','manifestEncodingWorker')):
        put(role,getter,('bytes32',),(graph[worker]['runtimeHash'],))
    put('checkpoint','checkpoint(bytes32)',(t.CHECKPOINT_PLAN,),(w._v(t.CHECKPOINT_PLAN,cp['plan']),),('bytes32',),(cp['id'],))
    for index,row in enumerate(cp['outputs']):
        put('checkpoint','outputAt(bytes32,uint256)',(t.OUTPUT,),(w._v(t.OUTPUT,row),),('bytes32','uint256'),(cp['id'],index))
    mp=w._v(t.MANIFEST_PLAN,m['plan'])
    put('outputManifest','manifestRecord(bytes32)',(t.MANIFEST_PLAN,),(mp,),('bytes32',),(m['recordHash'],))
    put('outputManifest','manifestPlan(bytes32)',(t.MANIFEST_PLAN,),(mp,),('bytes32',),(m['planHash'],))
    for index,row in enumerate(m['parts']):
        put('outputManifest','manifestPart(bytes32,uint256)',(t.DESCRIPTOR,),(w._v(t.DESCRIPTOR,row['descriptor']),),('bytes32','uint256'),(m['recordHash'],index))
        put('outputManifest','partRecord(bytes32)',(t.PART,),(w._v(t.PART,row['record']),),('bytes32',),(row['recordHash'],))
    for row in (*m['parts'],m):
        f=w._v(t.COVERAGE,row['coverage'])
        put('coverage','coverage(bytes32)',(t.COVERAGE,),(f,),('bytes32',),(f[0],))
        for index,chunk in enumerate(row['chunks']):
            put('coverage','artifactChunk(bytes32,uint32)',('address','bytes32'),(chunk['pointer'],chunk['codeHash']),('bytes32','uint32'),(f[1],index))
            runtime=hex_bytes(chunk['runtime'])
            assert chunk['pointer'] not in fixture.codes or fixture.codes[chunk['pointer']]==runtime
            fixture.codes[chunk['pointer']]=runtime;fixture.pins[chunk['pointer']]=chunk['codeHash']


from .view_preservation_output_source_reads_v1 import ViewPreservationOutputReads
class ReadHarness(ViewPreservationOutputReads):
    def __init__(self,value,context,graph):
        self.a={**context,'checkpointId':value['checkpoint']['id'],'manifestRecordHash':value['manifest']['recordHash']}
        self.graph=graph;self.responses={};self.codes={};self.pins={};self.calls=[]
        self.logs=[{'address':x['address'],'topics':list(x['topics']),'data':x['data']} for x in w.expected_events(value,context,graph)]
        install_output_reads(self,value,context,graph)
    def add(self,address,signature,inputs,args,outputs,values):
        from .chain_abi import calldata
        self.responses[address,calldata(signature,inputs,args)]=encode(outputs,values)
    def _read(self,address,signature,outputs,inputs=(),values=(),maximum=65536):
        from .chain_abi import calldata
        self.calls.append(signature)
        return decode(outputs,self.responses[address,calldata(signature,inputs,values)],maximum=maximum)
    def _one(self,address,signature,kind,inputs=(),values=(),maximum=65536):return self._read(address,signature,(kind,),inputs,values,maximum)[0]
    def _history(self,address,topics):return {'logs':[x for x in self.logs if x['address']==address and x['topics'][:len(topics)]==topics]}
    def _carrier(self,pointer,digest,maximum):
        raw=self.codes[pointer]
        w.require(len(raw)<=maximum+1 and raw[0]==0 and keccak256(raw)==digest,'synthetic carrier mismatch')
        return raw[1:]


class ViewPreservationOutputTests(unittest.TestCase):
    def reject(self,value,context,graph,adoption,phrase=None):
        with self.assertRaises(MuseumError) as caught:w.validate(value,context,graph,adoption)
        if phrase:self.assertIn(phrase,str(caught.exception))

    def test_exact_native_widths_profiles_definitions_and_interfaces(self):
        v,c,g,a=supplied();r=w.validate(v,c,g,a)
        self.assertEqual(len(encode((t.OUTPUT,),(w._v(t.OUTPUT,v['checkpoint']['outputs'][0]),))),992)
        self.assertEqual(len(encode((t.CHECKPOINT_PLAN,),(w._v(t.CHECKPOINT_PLAN,v['checkpoint']['plan']),))),416)
        self.assertEqual(len(encode((t.HEADER,),(w._v(t.HEADER,r['header']),))),416)
        self.assertEqual(len(encode((t.MANIFEST_PLAN,),(w._v(t.MANIFEST_PLAN,v['manifest']['plan']),))),768)
        self.assertEqual(t.CHECKPOINT_INTERFACE,'0xc5a3fffa')
        self.assertEqual(t.MANIFEST_INTERFACE,'0xb3fbe33c')
        self.assertEqual([len(x['bytes']) for x in w.definitions()],[931,852,849,810,755])
        self.assertEqual([x['kind'] for x in w.definitions()],[0,1,0,1,0])
        self.assertEqual(len({x['id'] for x in w.definitions()}),5)
        from . import view_policy_output_types_v2 as old
        for key in ('PROFILE','OUTPUT_PROFILE','SOURCE_DOMAIN','ROW_DOMAIN','PLAN_DOMAIN','CHAIN_DOMAIN',
                    'ROOT_DOMAIN','PART_DOMAIN','MANIFEST_PLAN_DOMAIN','PART_CHAIN_DOMAIN','RECORD_DOMAIN'):
            self.assertNotEqual(getattr(t,key),getattr(old,key),key)
        self.assertFalse(r['qualification']['finalityEvidence'])
        self.assertFalse(r['qualification']['renderedJSONHTMLBytesRetained'])

    def test_independent_leaf_node_odd_promotion_and_output_root_preimages(self):
        v,c,g,a=supplied();r=w.validate(v,c,g,a);p=w._v(t.CHECKPOINT_PLAN,v['checkpoint']['plan'])
        rows=[w._v(t.OUTPUT,row) for row in v['checkpoint']['outputs']]
        leaves=[keccak256(encode(('bytes32','bytes32','uint256','address',t.SCOPE,'bytes32',t.OUTPUT),
            (schema_id('6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1'),t.OUTPUT_PROFILE,int(c['chainId']),
             c['core'],p[0],p[1],row))) for row in rows]
        def node(left,right):return keccak256(encode(('bytes32','bytes32','bytes32'),
            (schema_id('6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1'),left,right)))
        root=node(node(leaves[0],leaves[1]),leaves[2])
        self.assertEqual(r['contentRoot'],root)
        self.assertNotEqual(root,node(node(leaves[0],leaves[1]),node(leaves[2],leaves[2])))
        self.assertEqual(r['outputRoot'],keccak256(encode(
            ('bytes32','uint256','address','bytes32','bytes32',t.SCOPE,'bytes32','bytes32','uint64','bytes32','bytes32','bytes32'),
            (t.ROOT_DOMAIN,int(c['chainId']),g['checkpoint']['address'],v['configuration']['checkpointHash'],
             v['checkpoint']['id'],p[0],p[1],p[2],p[5],p[7],root,t.OUTPUT_PROFILE))))

    def test_target_proof_oriented_by_actual_index_no_sorted_pairs_or_tail(self):
        v,c,g,a=supplied(5);c['tokenId']='45';r=w.validate(v,c,g,a)
        p=r['targetProof'];self.assertEqual((p['leafIndex'],p['leafCount']),('4','5'))
        self.assertEqual(len(p['proof']),1)
        self.assertEqual(w.target_proof(v,c,4),p)
        for index in range(5):
            p=w.proof(r['leafHashes'],index)
            w.verify_proof(p['leafHash'],index,5,p['proof'],p['root'])
            with self.assertRaises(MuseumError):w.verify_proof(p['leafHash'],index,5,p['proof']+[H('tail')],p['root'])
        p=w.proof(r['leafHashes'],1)
        with self.assertRaises(MuseumError):w.verify_proof(p['leafHash'],0,5,p['proof'],p['root'])
        with self.assertRaises(MuseumError):w.verify_proof(p['leafHash'],1,5,p['proof'][:-1],p['root'])

    def test_exact_64_65_parts_offsets_and_complete_source(self):
        for count in (1,64,65):
            with self.subTest(count=count):
                v,c,g,a=supplied(count);r=w.validate(v,c,g,a)
                self.assertEqual(len(r['partBytes']), (count+63)//64)
                self.assertEqual([len(x) for x in r['partBytes']],
                    [672+992*min(64,count-first) for first in range(0,count,64)])
                self.assertEqual(len(r['indexBytes']),672+288*((count+63)//64))
                for raw in (*r['partBytes'],r['indexBytes']):
                    self.assertEqual(int.from_bytes(raw[19*32:20*32],'big'),640)
                self.assertEqual(r['source'],v['checkpoint']['source'])
                self.assertEqual(r['source'][2],a['preservation']['binding'])
                self.assertEqual(r['source'][3],a['preservation']['admission'])

    def test_status_and_original_burn_variants_preserve_full_policy(self):
        for mode,status,finalized,terminal in (('disabled',1,False,True),('not_required',2,False,True),
                ('finalized',5,True,False),('legacy',5,True,False)):
            for burned in (False,True):
                with self.subTest(mode=mode,burned=burned):
                    v,c,g,a=supplied(mode=mode,burned=burned);r=w.validate(v,c,g,a)
                    row=w._v(t.OUTPUT,r['outputs'][0]);e=row[7]
                    self.assertEqual((e[5],e[7],e[8]),(status,finalized,terminal))
                    self.assertEqual((row[3],row[4],row[5]),(3,True,2) if burned else (2,False,1))
                    self.assertEqual(e[4],w._v(t.POLICY_ROW,a['policies'][0])[14])

    def test_terminal_is_not_finalized_even_after_rehash(self):
        v,c,g,a=supplied();v['checkpoint']['outputs'][0][7][7]=True
        reseal(v,c,g,a);self.reject(v,c,g,a,'terminal is not finalized')

    def test_source5_admission_binding_and_context_cannot_be_substituted(self):
        for field in (0,1,2,3,4):
            v,c,g,a=supplied()
            if field==0:v['checkpoint']['source'][0][3]=H('another original adoption')
            elif field==1:v['checkpoint']['source'][1][11]=H('another policy')
            elif field==2:v['checkpoint']['source'][2][3]=H('another renderer')
            elif field==3:v['checkpoint']['source'][3][3]=H('another admission')
            else:v['checkpoint']['source'][4]=H('another context')
            with self.subTest(field=field):self.reject(v,c,g,a,'saved source preimage')
        v,c,g,a=supplied();a['preservation']['admission'][3]=H('later registration')
        self.reject(v,c,g,a)

    def test_source_context_domain_independently_includes_preservation_and_admission(self):
        v,c,g,a=supplied();p=w._v(t.CHECKPOINT_PLAN,v['checkpoint']['plan']);s=w._v(t.SOURCE,v['checkpoint']['source'])
        expected=keccak256(encode(('bytes32','bytes32','uint256','address',t.CHECKPOINT_CONFIG,t.SCOPE,
                'bytes32','bytes32',t.VIEW_BINDING,'bytes32',t.PRESERVATION_BINDING,t.ADMISSION),
            (t.SOURCE_DOMAIN,t.PROFILE,int(c['chainId']),g['checkpoint']['address'],
             w._v(t.CHECKPOINT_CONFIG,v['configuration']['checkpoint']),p[0],s[0][3],s[0][2],s[1],t.OUTPUT_PROFILE,s[2],s[3])))
        self.assertEqual(p[2],expected)

    def test_rehashed_producer_registry_and_gas_contradictions_rejected(self):
        for mode in ('producer','registry','renderer','gas','configuration'):
            v,c,g,a=supplied()
            if mode=='producer':a['preservation']['producerBinding'][0]=A(999)
            elif mode=='registry':a['preservation']['admission'][0]=A(999)
            elif mode=='renderer':a['preservation']['binding'][2]=A(999)
            elif mode=='gas':v['configuration']['checkpoint'][11]='151587'
            else:v['configuration']['checkpoint'][8]=H('not original serving configuration')
            reseal(v,c,g,a)
            with self.subTest(mode=mode):self.reject(v,c,g,a)

    def test_linked_workers_and_shared_runtime_pins_are_required(self):
        v,c,g,a=supplied();g['checkpointSourceWorker']['runtimeHash']=H('replacement worker')
        self.reject(v,c,g,a,'linked configuration hash')
        v,c,g,a=supplied();g['unusedObservation']={'address':g['core']['address'],'runtimeHash':H('conflict')}
        self.reject(v,c,g,a,'runtime contradiction')

    def test_content_root_and_row_chain_independently_checked(self):
        for index in (7,8,9):
            v,c,g,a=supplied();v['checkpoint']['plan'][index]=H('wrong root')
            with self.subTest(index=index):self.reject(v,c,g,a)
        v,c,g,a=supplied();v['checkpoint']['outputs'][1][8]=H('changed JSON commitment')
        self.reject(v,c,g,a,'content root')

    def test_duplicate_token_index_and_invalid_output_hash_rehash_reject(self):
        for mode in ('token','index','hash','burn'):
            v,c,g,a=supplied()
            if mode=='token':v['checkpoint']['outputs'][1][1]=v['checkpoint']['outputs'][0][1]
            elif mode=='index':v['checkpoint']['outputs'][1][0]='0'
            elif mode=='hash':v['checkpoint']['outputs'][1][8]=ZERO
            else:v['checkpoint']['outputs'][1][4]=True
            reseal(v,c,g,a)
            with self.subTest(mode=mode):self.reject(v,c,g,a)

    def test_parts_order_complete_bytes_and_stop_prefix(self):
        for mode in ('missing','order','byte','prefix'):
            v,c,g,a=supplied(65)
            if mode=='missing':v['manifest']['parts'].pop()
            elif mode=='order':v['manifest']['parts'].reverse()
            else:
                chunk=v['manifest']['parts'][0]['chunks'][0]
                raw=bytearray(hex_bytes(chunk['runtime']));raw[1 if mode=='byte' else 0]^=1
                chunk['runtime']='0x'+raw.hex();chunk['codeHash']=keccak256(bytes(raw))
            with self.subTest(mode=mode):self.reject(v,c,g,a)

    def test_old_output_cannot_be_relabelled_as_preservation(self):
        from .test_view_policy_output_wire_v2 import supplied as old
        v,c,g,a=supplied();old_value=old()[0]
        v['checkpoint']['plan']=old_value['checkpoint']['plan']
        self.reject(v,c,g,a)
        v,c,g,a=supplied();v['configuration']['manifestHash']=old_value['configuration']['manifestHash']
        self.reject(v,c,g,a,'linked configuration hash')

    def test_source_roundtrip_requires_saved_source_never_current_getter(self):
        v,c,g,a=supplied(65);h=ReadHarness(v,c,g)
        header=h._view_preservation_header()
        observed=h._view_preservation_outputs(header,a,v['checkpoint']['source'])
        self.assertEqual(observed,v)
        self.assertNotIn('currentSource((uint8,uint256,uint256,bytes32))',h.calls)
        self.assertFalse(any('requireCurrent' in signature or 'requireArtifact' in signature for signature in h.calls))
        missing=deepcopy(v['checkpoint']['source']);missing[4]=H('wrong original source')
        with self.assertRaises(MuseumError):h._view_preservation_outputs(header,a,missing)

    def test_exact_sealed_event_includes_both_roots(self):
        v,c,g,a=supplied();events=w.expected_events(v,c,g)
        sealed=next(e for e in events if e['kind']=='view_checkpoint_sealed')
        self.assertEqual(sealed['topics'][0],schema_id('ViewCheckpointSealed(bytes32,bytes32,bytes32,uint64)'))
        self.assertEqual(decode(('bytes32','bytes32','uint64'),hex_bytes(sealed['data'])),
            (v['checkpoint']['plan'][8],v['checkpoint']['plan'][9],3))


if __name__=='__main__':unittest.main()
