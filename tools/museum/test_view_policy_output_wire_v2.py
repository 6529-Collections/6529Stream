"""Independent synthetic VIEW row/carrier vectors; no renderer/native execution."""
from copy import deepcopy
import unittest
from . import view_policy_output_types_v2 as t, view_policy_output_wire_v2 as w
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
    cfg['manifestHash']=w.configuration_hash(t.OUTPUT_PROFILE,chain,pair('outputManifest')[0],t.MANIFEST_CONFIG,m,
        (pair('manifestReadWorker'),pair('manifestEncodingWorker')))
    b=w._v(t.VIEW_BINDING,adoption['policyBinding']);scope=w._v(t.SCOPE,adoption['scope'])
    source=w.source_context_hash(chain,pair('checkpoint')[0],c,scope,adoption['record'][3],adoption['record'][2],b)
    cp=value['checkpoint'];rows=tuple(w._v(t.OUTPUT,row) for row in cp['outputs']);count=len(rows)
    p=[scope,adoption['record'][3],source,b[8][5],b[11],count,count,ZERO,ZERO]
    cp['id']=w.checkpoint_id(chain,pair('checkpoint')[0],cfg['checkpointHash'],scope,source,count,cp['salt'])
    p[7]=w.row_chain(chain,pair('checkpoint')[0],cp['id'],p,rows)
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
        adoption={'profile':t.ADOPTION_PROFILE,'scope':json_values(scope),'record':json_values(record),
            'policyBinding':json_values(binding),'tokenIds':list(map(str,tokens)),'policies':json_values((rule,))}
    adoption=deepcopy(adoption);tokens=tuple(map(int,adoption['tokenIds']));count=len(tokens)
    rules=tuple(w._v(t.POLICY_ROW,x) for x in adoption['policies'])
    rows=[]
    for i,token in enumerate(tokens):
        rule=max((x for x in rules if x[2]<=i),key=lambda x:x[2]);p=rule[14]
        status=(1 if p[3]==0 else 2) if rule[13] and p[5]==1 else 5
        entropy=(rule[0],rule[1],rule[8],rule[13],p,status,ZERO if status!=5 else H('seed'),status==5,status!=5)
        rows.append((i,token,i+1,3 if burned and i==0 else 2,bool(burned and i==0),2 if burned and i==0 else 1,
            H('token data'+str(token)),entropy,H('JSON'+str(token)),H('HTML'+str(token)),200,400))
    c=(*pair('core'),*pair('router'),*pair('authority'),*pair('serving'),serving_configuration_hash or H('serving configuration'),int(context['chainId']),50000,500000)
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
        ('outputManifest','manifest',t.MANIFEST_CONFIG,t.OUTPUT_PROFILE,'outputProfile()',t.MANIFEST_INTERFACE)):
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


from .view_policy_output_source_reads_v2 import ViewPolicyOutputReads
class ReadHarness(ViewPolicyOutputReads):
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


class ViewPolicyOutputTests(unittest.TestCase):
    def reject(self,value,context,graph,adoption,phrase=None):
        with self.assertRaises(MuseumError) as caught:w.validate(value,context,graph,adoption)
        if phrase:self.assertIn(phrase,str(caught.exception))

    def test_exact_31_words_and_full_native_definitions(self):
        v,c,g,a=supplied();r=w.validate(v,c,g,a)
        row=w._v(t.OUTPUT,v['checkpoint']['outputs'][0])
        self.assertEqual(len(encode((t.OUTPUT,),(row,))),992)
        self.assertEqual(len(encode((t.ENTROPY,),(row[7],))),640)
        self.assertEqual(len(w.definitions()),4)
        self.assertEqual([len(x['bytes']) for x in w.definitions()],[813,826,844,796])
        self.assertEqual(t.CHECKPOINT_INTERFACE,'0x7103dbe5');self.assertEqual(t.MANIFEST_INTERFACE,'0xb3fbe33c')
        self.assertFalse(r['qualification']['finalityEvidence'])
        self.assertFalse(r['qualification']['renderedJSONHTMLBytesRetained'])

    def test_64_and_65_exact_part_boundary_and_canonical_offsets(self):
        for count in (1,64,65):
            v,c,g,a=supplied(count);r=w.validate(v,c,g,a)
            self.assertEqual([len(x) for x in r['partBytes']],[640+992*min(64,count-i) for i in range(0,count,64)])
            for raw in r['partBytes']:
                self.assertEqual(int.from_bytes(raw[576:608],'big'),608)
                self.assertEqual(encode(t.PART_ENVELOPE,decode(t.PART_ENVELOPE,raw,maximum=t.MAX_BYTES)),raw)
            self.assertEqual(len(r['indexBytes']),640+288*((count+63)//64))

    def test_finalized_terminal_not_required_legacy_and_burned(self):
        for mode in ('disabled','not_required','finalized','legacy'):
            for burned in (False,True):
                v,c,g,a=supplied(mode=mode,burned=burned);r=w.validate(v,c,g,a)
                row=r['outputs'][0];self.assertEqual(row[5],'2' if burned else '1')
                self.assertEqual(row[7][7],mode in ('finalized','legacy'))
                self.assertNotEqual(row[7][7],row[7][8])

    def test_later_current_adoption_never_replaces_original(self):
        v,c,g,a=supplied();a['head']=H('later head')
        self.assertEqual(w.validate(v,c,g,a)['adoptionRecord'],a['record'][3])
        a['record'][3]=a['head'];self.reject(v,c,g,a,'selected original')

    def test_worker_pairs_are_configuration_commitments(self):
        for worker in ('checkpointSourceWorker','checkpointTokenWorker','manifestReadWorker','manifestEncodingWorker'):
            v,c,g,a=supplied();g[worker]['address']=A(9999)
            self.reject(v,c,g,a,'linked configuration')
        v,c,g,a=supplied()
        g['otherOriginalRole']={'address':g['core']['address'],'runtimeHash':H('conflicting extra role')}
        self.reject(v,c,g,a,'runtime contradiction')

    def test_full_policy_words_and_terminal_claim_reject_even_after_rehash(self):
        for mutate in (lambda e:e[4].__setitem__(11,H('other consent')),lambda e:e.__setitem__(7,True),lambda e:e.__setitem__(6,H('fabricated seed'))):
            v,c,g,a=supplied();mutate(v['checkpoint']['outputs'][0][7]);reseal(v,c,g,a)
            self.reject(v,c,g,a)

    def test_exact_token_order_and_burn_semantics_after_rehash(self):
        for change in ('token','order','burn','serial'):
            v,c,g,a=supplied()
            rows=v['checkpoint']['outputs']
            if change=='token':rows[0][1]='999'
            elif change=='order':rows.reverse()
            elif change=='burn':rows[0][4]=True
            else:rows[1][2]=rows[0][2]
            reseal(v,c,g,a);self.reject(v,c,g,a)

    def test_missing_duplicated_reordered_part_or_index_descriptor_rejects(self):
        for change in ('missing','duplicate','reverse','descriptor','root'):
            v,c,g,a=supplied(65);parts=v['manifest']['parts']
            if change=='missing':parts.pop()
            elif change=='duplicate':parts[1]=deepcopy(parts[0])
            elif change=='reverse':parts.reverse()
            elif change=='descriptor':parts[1]['descriptor'][5]='0'
            else:v['checkpoint']['plan'][8]=H('STATIC Merkle root')
            self.reject(v,c,g,a)

    def test_full_covered_bytes_stop_size_hash_and_receipt_fields(self):
        for change in ('STOP','size','hash','bytes','family','time','artist','schema'):
            v,c,g,a=supplied();row=v['manifest']['parts'][0];chunk=row['chunks'][0]
            if change=='STOP':chunk['runtime']='0x01'+chunk['runtime'][4:];chunk['codeHash']=keccak256(hex_bytes(chunk['runtime']))
            elif change=='size':chunk['runtime']+='00';chunk['codeHash']=keccak256(hex_bytes(chunk['runtime']))
            elif change=='hash':chunk['codeHash']=H('wrong code')
            elif change=='bytes':chunk['runtime']=chunk['runtime'][:-2]+('01' if chunk['runtime'][-2:]!='01' else '02');chunk['codeHash']=keccak256(hex_bytes(chunk['runtime']))
            elif change=='family':row['coverage'][9]=row['coverage'][8]
            elif change=='time':row['coverage'][10]=str(int(c['timestamp'])+1)
            elif change=='artist':row['coverage'][2]=H('other artist')
            else:row['coverage'][3]=t.INDEX_SCHEMA
            self.reject(v,c,g,a)

    def test_cross_domain_and_non_view_scopes_reject(self):
        for key in ('chainId','collectionId','core'):
            v,c,g,a=supplied();c[key]=A(10001) if key=='core' else str(int(c[key])+1)
            self.reject(v,c,g,a)
        v,c,g,a=supplied();a['scope'][0]='2';self.reject(v,c,g,a,'exact adopted scope')

    def test_event_denominator_and_native_no_version_event_layout(self):
        v,c,g,a=supplied(65);w.validate(v,c,g,a);events=w.expected_events(v,c,g)
        counts={kind:sum(x['kind']==kind for x in events) for kind in {x['kind'] for x in events}}
        self.assertEqual(counts['view_checkpoint_appended'],65)
        self.assertEqual(counts['view_part_prepared'],2)
        self.assertEqual(counts['view_manifest_advanced'],2)
        sealed=next(x for x in events if x['kind']=='view_checkpoint_sealed')
        self.assertEqual(len(hex_bytes(sealed['data'])),64)
        final=next(x for x in events if x['kind']=='view_manifest_verified')
        self.assertEqual(final['data'],'0x')

    def test_bound_and_narrow_word_fail_closed(self):
        v,c,g,a=supplied();v['checkpoint']['plan'][5]='16385';self.reject(v,c,g,a)
        v,c,g,a=supplied();v['checkpoint']['outputs'][0][10]=str(2**32);self.reject(v,c,g,a)
        v,c,g,a=supplied();v['checkpoint']['outputs'][0][4]=1;self.reject(v,c,g,a)
        v,c,g,a=supplied();v['extra']='authority';self.reject(v,c,g,a)

    def test_source_read_mixin_roundtrip_65_rows_without_current_calls(self):
        v,c,g,a=supplied(65,coverage_timestamp=100)
        host=ReadHarness(v,c,g)
        actual=host._view_outputs(host._view_output_header(),a)
        self.assertEqual(actual,v)
        self.assertFalse(any('requireCurrent' in x or 'requireArtifactCoverage' in x or 'currentOutput' in x for x in host.calls))
        self.assertEqual(host.calls.count('outputAt(bytes32,uint256)'),65)
        self.assertEqual(host.calls.count('manifestPart(bytes32,uint256)'),2)

    def test_source_original_start_and_worker_observations_fail_closed(self):
        v,c,g,a=supplied()
        host=ReadHarness(v,c,g);host.logs=[]
        with self.assertRaisesRegex(MuseumError,'start denominator'):host._view_output_header()
        host=ReadHarness(v,c,g)
        host.add(g['checkpoint']['address'],'sourceWorkerCodeHash()',(),(),('bytes32',),(H('wrong worker'),))
        with self.assertRaisesRegex(MuseumError,'linked worker'):host._view_output_header()

if __name__=='__main__':unittest.main()
