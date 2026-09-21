"""Concrete new-profile inventories; no mocked validator or legacy cast."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import view_preservation_retrieval_inventory_v1 as w
from . import view_preservation_retrieval_wire_v1 as retrieval
from . import view_preservation_retrieval_types_v1 as t
from . import view_preservation_inventory_fixture_v1 as fixture
from . import view_preservation_inventory_wire_v1 as old
from . import view_preservation_inventory_types_v1 as it
from . import view_preservation_inventory_items_v1 as items
from . import view_preservation_inventory_sources_v1 as sources
from . import view_preservation_reference_wire_v1 as reference
from . import view_preservation_reference_types_v1 as rt
from . import view_preservation_adoption_wire_v1 as adoption
from . import view_policy_membership_v2 as membership
from . import view_policy_adoption_types_v2 as at
from . import view_preservation_bundle_wire_v1 as archive
from .canonical import MuseumError, dumps, hex_bytes, keccak256 as K, schema_id as H
from .chain_abi import encode, decode
from .independent_wire import ZERO as Z, json_values
from .native_finality_wire import from_json
from .object_inventory_source import reconstruct_segment, append_segment
from .view_preservation_locator_fixture_v1 import _replace_uri, AR_URI
from .test_view_preservation_inventory_stages_v1 import build_fixed_stages
from .test_view_preservation_adoption_wire_v1 import _bind_original_registry
from .test_view_preservation_output_wire_v1 import reseal as seal_output
from .test_view_preservation_snapshot_wire_v1 import supplied as snapshot
from .test_view_preservation_root_wire_v1 import supplied as root
from .test_view_preservation_reference_wire_v1 import reseal as seal_reference


def A(number):return '0x'+format(number,'040x')


def _uri(value,context,graph,uri):
    row,bundle,_,_=sources.selected(value['reference']);adopted=bundle['adoption']
    for entry in adopted['history']:
        if entry['profile']==at.V2_PROFILE:_replace_uri(entry,context,graph,uri)
    version=adopted['preservation']['registry']['version']
    _bind_original_registry(adopted,context,graph,version[4],version[5])
    admitted=adoption.validate(adopted,context,{key:graph[key] for key in adoption.t.GRAPH_KEYS})
    members=membership.validate(bundle['membership'],context,graph,admitted['policyBinding'])
    admitted.update(tokenIds=members['tokenIds'],policies=members['policies'])
    for output,member in zip(bundle['output']['checkpoint']['outputs'],value['members']):
        js=dumps({'name':'Original synthetic token '+output[1],'image':uri})
        output[8],output[10]=K(js),str(len(js))
        member['json']='0x'+js.hex();member['outputReturn']='0x'+encode((rt.OUTPUT,),(from_json(rt.OUTPUT,output),)).hex()
    seal_output(bundle['output'],context,graph,admitted,coverage_timestamp=106)
    bundle['snapshot'],_,_=snapshot(context=context,graph=graph,output_value=bundle['output'],
        adoption=admitted,membership=members,recorded_at=107)
    bundle['root'],*_=root(context=context,graph=graph,snapshot_value=bundle['snapshot'],output_value=bundle['output'],published_at=109)
    row['sourceProof']['events']=fixture._source_events(bundle,context,graph)
    sr=bundle['snapshot']['history'][0];rr=bundle['root']['history'][-1]
    row['publication'][1][4]=row['receipt'][1][9]=sr['receipt'][0]
    row['source'][1:6]=deepcopy([sr['receipt'],sr['source'],rr['recordHash'],rr['record'],rr['binding']])
    for sample,capture in zip(row['source'][7],row['publication'][1][7]):
        output=bundle['output']['checkpoint']['outputs'][int(sample[0])]
        sample[1]=deepcopy(output);capture[2:4]=output[8:10]
    seal_reference(value['reference'],context,graph)


def seal(value,context,graph,fixed):
    """Assemble the actual new rows, links and recorded reads before validation."""
    c=from_json(it.CONTEXT,value['context']);d=from_json(it.DEPENDENCIES,value['dependencies'])
    identifier=old.plan_id(d[6],graph['inventory']['address'],value['dependencyHash'],c)
    rows=w.stage_rows(value,c,d);entries=[]
    def add(stage,index,actual,witness,source=None):
        actual=tuple(actual);segment=reconstruct_segment(old.segment_key(identifier,len(entries)),witness,actual)
        entries.append({'stage':str(stage),'index':str(index),'segment':json_values(segment),
            'items':json_values(actual),'source':deepcopy(source)})
    for stage in (0,1):
        for index in range(0,len(rows[stage]),64):
            witness=K(encode(('bytes32','uint64','uint64'),
                (K(encode((it.CONTEXT,),(c,))) if stage==0 else c[4][1][6],index,len(rows[stage]))))
            add(stage,index,rows[stage][index:index+64],witness)
    for entry in fixed:add(int(entry['stage']),int(entry.get('index',0)),
        tuple(from_json(it.ITEM,row) for row in entry['items']),entry['sourceWitnessHash'],entry['source'])
    for index,definition in enumerate(it.definitions()):
        row=items.document(definition['id'],definition['hash'],d[0][2],value['documents'])
        add(7,index,(row,),K(encode(('bytes32',it.ITEM),(definition['id'],row))))
    add(8,0,rows[8],old.output_witness(c,8,0,len(rows[8])))
    for stage in (9,10):
        for index,row in enumerate(rows[stage]):add(stage,index,(row,),old.output_witness(c,stage,index,len(rows[stage])))
    for index,group in enumerate(rows[11]):add(11,index,group,old.output_witness(c,11,index,len(group)))
    value['segments']=entries
    reseal(value,context,graph)


def reseal(value,context,graph):
    """Rehash outer plan/segments/events without correcting source-derived rows."""
    c=from_json(it.CONTEXT,value['context']);d=from_json(it.DEPENDENCIES,value['dependencies'])
    identifier=old.plan_id(d[6],graph['inventory']['address'],value['dependencyHash'],c)
    chain=Z;segments=[]
    for index,entry in enumerate(value['segments']):
        segment=reconstruct_segment(old.segment_key(identifier,index),entry['segment'][3],
            tuple(from_json(it.ITEM,row) for row in entry['items']))
        entry['segment']=json_values(segment);segments.append(segment);chain=append_segment(chain,index,segment)
    count=sum(len(row['items']) for row in value['segments'])
    original=(c[9],c[3][0],c[4][1][0],c[6][0][0] if c[6][0][1]==0 else Z,
        c[6][0][0] if c[6][0][1]==1 else Z,c[7],c[5][2],c[5][1]);context_hash=K(encode((it.CONTEXT,),(c,)))
    body=(identifier,c[0][1],c[1],c[2],original,context_hash,c[10],c[20],len(segments),count,chain,Z)
    digest=old.evidence_hash(d[6],graph['inventory']['address'],value['dependencyHash'],(c[0],body));e=(c[0],(*body[:-1],digest))
    progress=(c[0][1],c[1],c[2],context_hash,c[20],c[20],len(segments),count,chain,11,digest)
    native_count=sum(len(x['items']) for x in value['segments'] if x['stage']=='0')
    ref_count=sum(len(x['items']) for x in value['segments'] if x['stage']=='1')
    p=(c[0],progress,native_count,native_count,ref_count,ref_count)
    value.update(plan=json_values(p),evidence=json_values(e))
    value['recordedSource']={'blockHash':context['blockHash'],'provenance':'synthetic_fixture',
        'calls':w.expected_reads(value,context,graph,c,d,p,e,segments)}
    value['events']=[{'timestamp':'135','log':{'address':desc['address'],'topics':list(desc['topics']),
        'data':desc['data'],'blockNumber':'0x23','blockHash':H('retrieval inventory block35'),
        'transactionHash':H('retrieval inventory tx35'),'transactionIndex':'0x0','logIndex':hex(index),'removed':False}}
        for index,desc in enumerate(old.expected_events(value,context,graph))]


def supplied(uri='https://example.invalid/image%20one.png',*,count=1,burned=False):
    """Return inventory/context/graph/witness/configuration for the new profile."""
    value,context,graph=fixture.base_value(count,burned=burned);_uri(value,context,graph,uri)
    value.update(sourceRevision=t.SOURCE_REVISION,profile=t.INVENTORY_PROFILE)
    raw=b'synthetic immutable retrieval companion';witness={'address':A(98001),'runtimeHash':K(raw),'interfaceId':t.WITNESS_INTERFACE_ID}
    value['runtimes'][witness['address']]='0x'+raw.hex()
    fixed=build_fixed_stages(value,context,graph)
    fixture.set_context(value,from_json(it.DESCRIPTIONS,fixed['descriptions']),
        from_json(it.CONSERVATION,fixed['conservation']),fixed['interviewHash'])
    seal(value,context,graph,fixed['entries'])
    configuration=tuple(x for role in ('core','router','checkpoint','externalCoverage')
        for x in (graph[role]['address'],graph[role]['runtimeHash']))+(int(context['chainId']),100000,8000000,8000000,90000)
    bundle=sources.selected(value['reference'])[1]
    binding={'address':graph['inventory']['address'],'runtimeHash':graph['inventory']['runtimeHash'],
        'profile':t.INVENTORY_PROFILE,'dependencies':deepcopy(value['dependencies']),
        'dependencyHash':value['dependencyHash'],'retrievalWitnessBinding':[witness['address'],witness['runtimeHash']],
        'snapshotDependencies':deepcopy(bundle['snapshot']['dependencies']),'sourceBindings':None}
    checkpoint=from_json(w.ot.CHECKPOINT_CONFIG,bundle['output']['configuration']['checkpoint'])
    binding['sourceBindings']={'blockHash':context['blockHash'],'provenance':'synthetic_fixture',
        'calls':w.binding_reads(binding,context,graph,witness,configuration,checkpoint)}
    inventory={'value':value,'binding':binding}
    w.validate(inventory,context,graph,witness,configuration)
    return inventory,context,graph,witness,configuration


def item_case(args,*,epoch=2,presentation_hash=None):
    """Coordinate-layer vector; the caller independently owns Archive proof validation."""
    inventory,c,g,wi,config=args;_,result=w.validate(inventory,c,g,wi,config)
    source=list(result['retrievalSource'])
    if presentation_hash is not None:source[11]=presentation_hash
    source=tuple(source);item=retrieval.obligation_item(source)
    index=result['items'].index(retrieval.obligation_item(result['retrievalSource']))
    obj=H('observed original external object');coverage=H('observed original external coverage')
    external=(coverage,obj,source[10],H('content'),H('sha256'),H('Arweave root'),101,
        *(H('archive original '+str(i)) for i in range(7)),archive.EXTERNAL_PROFILE)
    from .test_view_preservation_bundle_wire_v1 import zero
    admission=((1,coverage,obj),H('checked original Archive bundle'),Z,external,zero(it.ADMISSION[4]))
    receipt=(Z,retrieval.source_key(source),H('original observation hash'),obj,coverage,A(98003),136,H('original payload bytes'),1024)
    receipt=(retrieval.record_hash(config,wi['address'],receipt),*receipt[1:])
    current=H('verified current pair observation')
    operative={'source':source,'receipt':receipt,'admission':admission,'currentObservation':current}
    transformed=w._hash(('bytes32','bytes32','address','bytes32','bytes32','bytes32','bytes32'),
        (t.ADMITTED_BUNDLE_DOMAIN,admission[1],wi['address'],wi['runtimeHash'],retrieval.configuration_hash(config),receipt[0],receipt[7]))
    deps=(tuple(g[k]['address'] for k in archive.DEPENDENCY_ROLES),tuple(g[k]['runtimeHash'] for k in archive.DEPENDENCY_ROLES),
        int(c['chainId']),100000,8000000)
    environment={'dependencies':json_values(deps),'artifact':[H('artifact environment'),'1'],'external':[H('external environment'),'7']}
    old_environment=archive.environment_hash(deps,environment['artifact'][0],1,environment['external'][0],7)
    row={'planId':result['planId'],'index':str(index),'item':json_values(item),'witnessRecordHash':receipt[0],
        'savedAdmission':json_values((admission[0],transformed,*admission[2:])),
        'originalEnvironment':old_environment,'environmentHash':retrieval.environment_hash(old_environment,wi['address'],wi['runtimeHash'],source[0],epoch),
        'currentObservation':current,'environment':environment,'sourceBindings':None}
    row['sourceBindings']={'blockHash':c['blockHash'],'provenance':result['provenance'],
        'calls':w.item_binding_reads(row,result,c,g,wi,epoch)}
    return row,result,operative


class RetrievalInventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.args=supplied()

    def test_new_profile_full_inventory_and_actual_retrieval_row(self):
        inventory,c,g,witness,configuration=deepcopy(self.args)
        with patch('socket.socket',side_effect=AssertionError('offline only')):
            _,result=w.validate(inventory,c,g,witness,configuration)
        selected=next(row for row in result['items'] if row[1]==t.ROLE)
        self.assertEqual(selected,retrieval.obligation_item(result['retrievalSource']))
        self.assertEqual(selected[16],retrieval.source_key(result['retrievalSource']))
        self.assertEqual(selected[5],0);self.assertEqual(selected[7],b'');self.assertEqual(selected[9],0)
        self.assertEqual(len({row['stage'] for row in inventory['value']['segments']}),12)
        self.assertFalse(result['claims']['nativeExecutionProven'])
        with self.assertRaisesRegex(MuseumError,'closed native profile'):old.validate(inventory['value'],c,g)

    def test_old_profile_cannot_be_relabelled_at_outer_binding(self):
        inventory,c,g,wi,config=deepcopy(self.args)
        inventory['value']['profile']=it.PROFILE;inventory['value']['sourceRevision']=it.SOURCE_REVISION
        with self.assertRaisesRegex(MuseumError,'distinct native profile'):w.validate(inventory,c,g,wi,config)

    def test_unchanged_raw_cid_absent_and_locator_rows_remain_exact(self):
        # Use a canonical raw SHA256 CID, never a made-up codec identifier.
        import base64
        rawcid='ipfs://b'+base64.b32encode(b'\x01\x55\x12\x20'+bytes(range(32))).decode().lower().rstrip('=')
        for uri in ('',rawcid,'https://example.invalid/image.png',AR_URI):
            inventory,c,g,wi,config=supplied(uri)
            _,result=w.validate(inventory,c,g,wi,config)
            image=next(row for row in inventory['value']['segments'] if row['stage']=='8')['items'][5]
            self.assertEqual(from_json(it.ITEM,image),retrieval.obligation_item(result['retrievalSource']))
            self.assertNotEqual(image[1],t.ROLE)

    def test_coherently_rehashed_image_source_artist_uri_and_missing_rows_reject(self):
        for mode in ('artist_hash','source_record','uri','digest','remove_stage','remove_member'):
            inventory,c,g,wi,config=deepcopy(self.args);value=inventory['value']
            row=next(x for x in value['segments'] if x['stage']=='8')['items'][5]
            if mode=='artist_hash':row[16]=H('truncated Artist identity only')
            elif mode=='source_record':row[3]=H('different original adoption')
            elif mode=='uri':row[8]='https://different.invalid/image?x=1'
            elif mode=='digest':row[5]='1';row[7]=H('fabricated URI digest')
            elif mode=='remove_stage':value['segments']=[x for x in value['segments'] if x['stage']!='7']
            else:value['segments']=[x for x in value['segments'] if x['stage']!='11']
            reseal(value,c,g)
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.validate(inventory,c,g,wi,config)

    def test_companion_checkpoint_snapshot_getters_and_repeated_answers(self):
        for mode in ('witness','snapshot','configuration','missing','changed','runtime'):
            inventory,c,g,wi,config=deepcopy(self.args);binding=inventory['binding']
            if mode=='witness':binding['retrievalWitnessBinding'][0]=A(98002)
            elif mode=='snapshot':binding['snapshotDependencies'][0][6]=A(98003)
            elif mode=='configuration':config=(*config[:4],A(98004),*config[5:])
            elif mode=='missing':binding['sourceBindings']['calls'].pop()
            elif mode=='changed':binding['sourceBindings']['calls'][0]['result']='0x'+encode(('bool',),(False,)).hex()
            else:inventory['value']['runtimes'][wi['address']]='0x1234'
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.validate(inventory,c,g,wi,config)
        inventory,c,g,wi,config=deepcopy(self.args);shared=archive._Originals(c,g)
        call=inventory['binding']['sourceBindings']['calls'][0]
        shared.answers[(call['target'],call['calldata'])]='0x'+encode(('bool',),(False,)).hex()
        with self.assertRaisesRegex(MuseumError,'conflicting original getter'):w.validate(inventory,c,g,wi,config,originals=shared)

    def test_actual_plan_flat_index_dedicated_host_and_scope_epoch(self):
        args=deepcopy(self.args);_,c,g,wi,config=args;row,result,operative=item_case(args)
        shared=archive._Originals(c,g);w.validate(*args,originals=shared)
        checked=w.validate_item_binding(row,result,c,g,wi,config,operative,2,originals=shared)
        self.assertEqual(checked['index'],row['index'])
        call=next(x for x in checked['calls'] if x['calldata'].startswith(K(b'retrievalWitnessForItem(bytes32,uint64)')[:10]))
        self.assertEqual(call['target'],g['bundleCoverage']['address'])
        self.assertTrue(any(x['calldata'].startswith(K(b'currentArtifactEnvironment()')[:10]) for x in checked['calls']))
        for mode in ('plan','index','item','witness','admission','source','artist','epoch','original_env','observation','missing','host','block','provenance'):
            row,result,operative=item_case(args);epoch=2
            if mode=='plan':row['planId']=H('unrelated actual plan')
            elif mode=='index':row['index']=str(int(row['index'])+1)
            elif mode=='item':row['item'][16]=H('other source hash')
            elif mode=='witness':row['witnessRecordHash']=H('other record')
            elif mode=='admission':row['savedAdmission'][1]=operative['admission'][1]
            elif mode in ('source','artist'):
                source=list(operative['source']);source[3 if mode=='source' else 11]=H('other original source');operative['source']=tuple(source)
            elif mode=='epoch':epoch=3
            elif mode=='original_env':row['originalEnvironment']=H('free scalar environment')
            elif mode=='observation':row['currentObservation']=H('other pair observation')
            elif mode=='missing':row['sourceBindings']['calls'].pop()
            elif mode=='host':row['sourceBindings']['calls'][-3]['target']=g['inventory']['address']
            elif mode=='block':row['sourceBindings']['blockHash']=H('different block')
            else:row['sourceBindings']['provenance']='externally_admitted_rpc'
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.validate_item_binding(row,result,c,g,wi,config,operative,epoch)

    def test_full_presentation_binds_retrieval_role_without_overrestricting_locator(self):
        args=supplied('https://example.invalid/image.png');_,c,g,wi,config=args
        row,result,operative=item_case(args,presentation_hash=H('later full presentation same Artist'))
        w.validate_item_binding(row,result,c,g,wi,config,operative,2)
        row,result,operative=item_case(deepcopy(self.args),presentation_hash=H('later full presentation same Artist'))
        _,c,g,wi,config=self.args
        with self.assertRaisesRegex(MuseumError,'actual plan/item/source'):w.validate_item_binding(row,result,c,g,wi,config,operative,2)

    def test_original_environment_preimages_and_shared_getter_conflicts(self):
        args=deepcopy(self.args);_,c,g,wi,config=args
        for mode in ('artifact','external','dependencies','zero_epoch','source_conflict'):
            row,result,operative=item_case(args);shared=archive._Originals(c,g)
            if mode=='artifact':row['environment']['artifact'][0]=H('different artifact environment')
            elif mode=='external':row['environment']['external'][1]='8'
            elif mode=='dependencies':row['environment']['dependencies'][0][2]=A(98099)
            elif mode=='zero_epoch':row['environment']['artifact'][1]='0'
            else:
                call=row['sourceBindings']['calls'][-3]
                shared.answers[(call['target'],call['calldata'])]='0x'+encode(('bytes32',),(H('other dedicated witness'),)).hex()
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.validate_item_binding(row,result,c,g,wi,config,operative,2,originals=shared)

    def test_three_member_burned_inventory_stays_complete(self):
        args=supplied(count=3,burned=True);_,result=w.validate(*args)
        self.assertEqual(result['context'][20],3)
        groups=[x for x in args[0]['value']['segments'] if x['stage']=='11']
        self.assertEqual(len(groups),3)
        self.assertEqual([len(x['items']) for x in groups],[6,6,6])


if __name__=='__main__':unittest.main()
