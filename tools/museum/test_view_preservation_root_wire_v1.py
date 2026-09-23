"""Original VIEW binding and shared Router root history vectors, without authority execution."""
from copy import deepcopy
import unittest

from . import view_preservation_root_wire_v1 as w, view_preservation_snapshot_types_v1 as t
from .canonical import MuseumError, hex_bytes, keccak256
from .chain_abi import encode
from .independent_wire import ZERO, json_values
from .native_finality_wire import from_json
from .test_view_preservation_snapshot_wire_v1 import base, supplied as snapshot_supplied, A, H


def reseal(value,context,graph):
    previous=ZERO;heads={}
    for index,row in enumerate(value['history']):
        r=row['record'];scope=tuple(r[0][0]);r[0][1]=heads.get(scope,ZERO)
        if row['binding'] is not None:r[15]=w.state_hash(r,row['binding'],context,graph)
        row['aggregate']=json_values(w.next_aggregate(r,previous,index+1,context,graph))
        row['recordHash']=w.record_hash(r,row['aggregate'],context,graph)
        heads[scope]=row['recordHash'];previous=row['aggregate'][1]
    chosen=next(row for row in value['history'] if row['binding'] is not None)
    value['selectedRecordHash']=chosen['recordHash'];value['head']=heads[tuple(chosen['record'][0][0])]
    value['aggregate']=deepcopy(value['history'][-1]['aggregate'])
    return value


def supplied(*,context=None,graph=None,snapshot_value=None,output_value=None,published_at=109,foreign=False):
    """Return root/context/graph/snapshot/output; accepts already coherent native groups."""
    if output_value is None:
        output_value,context,graph,adopted,members=base(context=context,graph=graph)
        snapshot_value,_,_=snapshot_supplied(context=context,graph=graph,output_value=output_value,
            adoption=adopted,membership=members)
    snap=next(row for row in snapshot_value['history'] if row['receipt'][0]==snapshot_value['selectedRecordHash'])
    s,r=snap['source'],snap['receipt'];scope=s[0]
    p=[scope,ZERO,r[0],r[3],'ipfs://original-view-content-root']
    record=[p,graph['viewSnapshot']['address'],graph['viewSnapshot']['runtimeHash'],r[5],r[7],
        s[5][0][9],s[1][3],s[5][1][3],*s[2][3:6],A(78902),'7','2',w.route_hash(context,graph),
        ZERO,H('original Artist CONTENT_ROOT consent'),str(published_at)]
    binding=json_values(w.binding_for(s,output_value['configuration']['checkpoint'],context,graph))
    row={'recordHash':ZERO,'record':record,'aggregate':['0',ZERO],'binding':binding}
    history=[]
    if foreign:
        other=deepcopy(row);other['record'][0][0]=['2',context['collectionId'],'0',H('foreign release')]
        other['record'][0][2]=H('foreign STATIC snapshot');other['record'][15]=H('original STATIC state hash')
        other['record'][17]=str(published_at-1);other['binding']=None;history.append(other)
    history.append(row)
    value={'selectedRecordHash':ZERO,'head':ZERO,'aggregate':['0',ZERO],'history':history}
    reseal(value,context,graph)
    return value,context,graph,snapshot_value,output_value


def install_root_reads(fixture,value,context,graph):
    host=graph['router']['address']
    for row in value['history']:
        key=row['recordHash'];record=from_json(t.ROOT_RECORD,row['record'])
        fixture.add(host,'scopedContentRootRecord(bytes32)',('bytes32',),(key,),(t.ROOT_RECORD,),(record,))
        binding=from_json(t.ROOT_BINDING,row['binding']) if row['binding'] is not None else tuple(
            '0x'+'00'*20 if kind=='address' else ZERO for kind in t.ROOT_BINDING)
        fixture.add(host,'viewPreservationContentRootBinding(bytes32)',('bytes32',),(key,),(t.ROOT_BINDING,),(binding,))
    selected=next(row for row in value['history'] if row['recordHash']==value['selectedRecordHash'])
    scope=from_json(t.SCOPE,selected['record'][0][0])
    fixture.add(host,'scopedContentRootHead((uint8,uint256,uint256,bytes32))',(t.SCOPE,),(scope,),('bytes32',),(value['head'],))
    fixture.add(host,'scopedContentRootAggregate(uint256)',('uint256',),(int(context['collectionId']),),
        (t.AGGREGATE,),(from_json(t.AGGREGATE,value['aggregate']),))


class ReadHarness(w.ViewPreservationRootReads):
    def __init__(self,v,x,g):
        self.a={**x,'rootRecordHash':v['selectedRecordHash'],'scope':next(row['record'][0][0]
            for row in v['history'] if row['recordHash']==v['selectedRecordHash'])}
        self.graph=g;self.responses={};self.calls=[]
        self.logs=[{'address':row['address'],'topics':list(row['topics']),'data':row['data']}
            for row in w.expected_events(v,x,g)]
        install_root_reads(self,v,x,g)
    def add(self,host,sig,inputs,args,outputs,values):self.responses[(host,sig,encode(inputs,args))]=values
    def _one(self,host,sig,output,inputs=(),values=(),**kwargs):
        self.calls.append(sig);return self.responses[(host,sig,encode(inputs,values))][0]
    def _history(self,host,topics):return {'logs':[row for row in self.logs if row['topics'][:len(topics)]==topics]}


class ViewPreservationRootTests(unittest.TestCase):
    def test_exact_native_definitions_and_binding_width(self):
        self.assertEqual([(len(row['bytes']),row['hash']) for row in w.definitions()],[(4738,
            '0x71b098d934ddbb3cabec5596e8062caafe5ae9dfed667070ec1de6756bf52d3e'),(833,
            '0x4f00c5f5b949500583ddd0e68c30ed863c4496e76dca14b44c963c443eca8103')])
        v,x,g,s,o=supplied();self.assertEqual(len(encode((t.ROOT_BINDING,),
            (from_json(t.ROOT_BINDING,v['history'][0]['binding']),))),28*32)
        w.validate(v,x,g,snapshot_value=s,output_value=o)
    def test_foreign_scoped_originals_remain_in_shared_aggregate(self):
        v,x,g,s,o=supplied(foreign=True)
        result=w.validate(v,x,g,snapshot_value=s,output_value=o)
        self.assertEqual(result['aggregate'][0],'2');self.assertIsNone(v['history'][0]['binding'])
        v['history'].pop(0)
        with self.assertRaisesRegex(MuseumError,'hash/collection aggregate'):w.validate(v,x,g)
    def test_rehashed_state_must_include_full_new_binding(self):
        v,x,g,s,o=supplied();v['history'][0]['binding'][17]=H('changed preservation configuration')
        with self.assertRaisesRegex(MuseumError,'binding/state'):w.validate(v,x,g)
        reseal(v,x,g)
        with self.assertRaisesRegex(MuseumError,'route/output binding'):w.validate(v,x,g,snapshot_value=s,output_value=o)
    def test_coherently_rehashed_root_cannot_rewrite_snapshot_content_or_artist(self):
        for index in (5,8,10):
            with self.subTest(field=index):
                v,x,g,s,o=supplied();v['history'][0]['record'][index]=H('different native field');reseal(v,x,g)
                with self.assertRaisesRegex(MuseumError,'snapshot identity/content/Artist'):
                    w.validate(v,x,g,snapshot_value=s,output_value=o)
    def test_selected_original_and_later_root_head_remain_distinct(self):
        v,x,g,s,o=supplied();later=deepcopy(v['history'][0]);later['record'][17]='110'
        later['record'][16]=H('later CONTENT_ROOT consent');v['history'].append(later);reseal(v,x,g)
        self.assertNotEqual(v['selectedRecordHash'],v['head'])
        w.validate(v,x,g,snapshot_value=s,output_value=o)
        v['head']=v['selectedRecordHash']
        with self.assertRaisesRegex(MuseumError,'scope/head'):w.validate(v,x,g)
    def test_nonselected_view_binding_requires_actual_nonzero_shape_and_leaf_schema(self):
        for index,value in ((22,H('wrong leaf schema')),(8,ZERO),(18,'0x'+'00'*20)):
            v,x,g,s,o=supplied();later=deepcopy(v['history'][0]);later['record'][17]='110'
            later['binding'][index]=value;v['history'].append(later);reseal(v,x,g)
            with self.assertRaisesRegex(MuseumError,'typed binding/state'):w.validate(v,x,g)
    def test_original_grants_cannot_be_artist_class_projection(self):
        v,x,g,s,o=supplied();v['history'][0]['record'][12]='1';reseal(v,x,g)
        with self.assertRaisesRegex(MuseumError,'authority/source/time'):w.validate(v,x,g)
    def test_historical_reads_do_not_request_current_root_eligibility(self):
        v,x,g,s,o=supplied(foreign=True);h=ReadHarness(v,x,g)
        self.assertEqual(h._view_preservation_root(),v)
        self.assertFalse(any('requireCurrent' in sig for sig in h.calls))
    def test_reader_rejects_selected_original_from_another_queried_view(self):
        v,x,g,s,o=supplied();h=ReadHarness(v,x,g);scope=deepcopy(h.a['scope']);scope[3]=H('other VIEW')
        with self.assertRaisesRegex(MuseumError,'queried scope differs'):h._view_preservation_root(v['selectedRecordHash'],scope)
    def test_reader_rejects_record_event_with_different_subject(self):
        v,x,g,s,o=supplied();h=ReadHarness(v,x,g);h.logs[0]['topics'][2]=H('different topic subject')
        with self.assertRaisesRegex(MuseumError,'event subject'):h._view_preservation_root()
    def test_reader_requires_bijective_original_binding_event_denominator(self):
        for extra in (False,True):
            v,x,g,s,o=supplied();h=ReadHarness(v,x,g)
            if extra:
                later=deepcopy(v['history'][0]);later['record'][17]='110'
                later['record'][16]=H('unreported CONTENT_ROOT consent');v['history'].append(later);reseal(v,x,g)
                row=w.expected_events(v,x,g)[-1]
                h.logs.append({'address':row['address'],'topics':list(row['topics']),'data':row['data']})
            else:h.logs=[row for row in h.logs if row['topics'][0]!=w.BINDING_PUBLISHED]
            with self.assertRaisesRegex(MuseumError,'complete binding event history'):h._view_preservation_root()
    def test_reader_binding_event_order_matches_shared_outer_publications(self):
        v,x,g,s,o=supplied();later=deepcopy(v['history'][0]);later['record'][17]='110'
        later['record'][16]=H('later CONTENT_ROOT consent');v['history'].append(later);reseal(v,x,g)
        h=ReadHarness(v,x,g)
        bindings=[row for row in h.logs if row['topics'][0]==w.BINDING_PUBLISHED]
        h.logs=[row for row in h.logs if row['topics'][0]!=w.BINDING_PUBLISHED]+list(reversed(bindings))
        with self.assertRaisesRegex(MuseumError,'complete binding event history'):h._view_preservation_root()


if __name__=='__main__':unittest.main()
