"""Whole original VIEW inventory positives and contradictory supplied evidence."""
from copy import deepcopy
import socket
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256
from .chain_abi import encode
from . import view_preservation_inventory_types_v1 as t
from . import view_preservation_inventory_wire_v1 as w
from . import view_preservation_inventory_sources_v1 as sources
from . import view_preservation_reference_wire_v1 as reference
from .view_preservation_inventory_fixture_v1 import reference_inputs, H


class CompleteReferenceFixtureTests(unittest.TestCase):
    def test_all_original_member_bytes_reseal_entire_reference(self):
        for count,mode,burned in ((1,'disabled',False),(3,'not_required',True),(3,'finalized',False)):
            with self.subTest(count=count,mode=mode):
                ref,ctx,graph,members,registration,runtimes,documents=reference_inputs(count,mode,burned)
                result=reference.validate(ref,ctx,{k:graph[k] for k in reference.GRAPH_KEYS})
                self.assertEqual(result['recordCount'],'1')
                self.assertEqual(len(members),count)
                rows=ref['history'][0]['sourceProof']['bundle']['output']['checkpoint']['outputs']
                for row,member in zip(rows,members):
                    self.assertEqual(keccak256(hex_bytes(member['tokenData'])),row[6])
                    self.assertEqual(keccak256(hex_bytes(member['json'])),row[8])
                    self.assertEqual(keccak256(hex_bytes(member['html'])),row[9])
                self.assertEqual(len(documents),44)
                for role,pair in graph.items():
                    self.assertEqual(keccak256(hex_bytes(runtimes[pair['address']])),pair['runtimeHash'])
                self.assertFalse(result['claims']['finalityProven'])


class ViewPreservationInventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from .view_preservation_inventory_fixture_v1 import supplied
        cls.single=supplied()
        cls.multiple=supplied(3,'not_required',True)
        cls.finalized=supplied(3,'finalized')

    def value(self,which='single'):
        return deepcopy(getattr(self,which))

    def test_complete_twelve_stages_and_every_member_are_reconstructed_offline(self):
        for name,count in (('single',1),('multiple',3),('finalized',3)):
            with self.subTest(name=name):
                value,ctx,graph=self.value(name)
                with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
                    result=w.validate(value,ctx,graph)
                self.assertEqual(set(int(row['stage']) for row in value['segments']),set(range(12)))
                self.assertEqual(sum(row['stage']=='11' for row in value['segments']),count)
                self.assertTrue(result['claims']['completeMemberOutputBytesChecked'])
                self.assertTrue(result['claims']['completeTwelveStageInventoryChecked'])
                for claim in ('rpcProvenanceAuthenticated','nativeExecutionProven','historicalAuthorityReauthorized',
                              'archiveCurrentPairProven','browserExecutionProven','finalityProven','consensusProof'):
                    self.assertFalse(result['claims'][claim])

    def test_complete_consumer_report_preserves_explicit_missing_bundle(self):
        from . import view_preservation_inventory_v1 as consumer
        value,ctx,graph=self.value()
        raw=dumps({'profileHash':consumer.PROFILE_HASH,'context':ctx,'graph':graph,
            'inventory':value,'bundle':None})
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            report=consumer.verify(raw)
        self.assertIsNone(report['bundle'])
        self.assertEqual(report['inputHash'],keccak256(raw))
        self.assertEqual(report['inventory']['segmentCount'],str(len(value['segments'])))
        self.assertEqual(report['inventory']['provenance'],'synthetic_fixture')
        self.assertFalse(report['inventory']['claims']['archiveCurrentPairProven'])

    def test_middle_member_cannot_be_omitted_or_replaced_by_reference_samples(self):
        for mutation in ('omit','json','html','tokenData','outputReturn'):
            v,c,g=self.value('multiple')
            if mutation=='omit':v['members'].pop(1)
            else:v['members'][1][mutation]='0x'+b'changed unsampled member'.hex()
            with self.subTest(mutation=mutation),self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_original_renderer_registration_and_document_preimages_are_required(self):
        for mutation in ('registration','missing_doc','changed_doc','chunks'):
            v,c,g=self.value()
            if mutation=='registration':v['rendererRegistration'][2]=H('another schema')
            elif mutation=='missing_doc':v['documents'].pop(v['rendererRegistration'][4])
            elif mutation=='changed_doc':v['documents'][v['rendererRegistration'][5]]['chunks'][0]['bytes']='0x01'
            else:
                key=next(k for k,row in v['documents'].items() if len(row['chunks'])>1)
                v['documents'][key]['chunks'].reverse()
            with self.subTest(mutation=mutation),self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_every_native_definition_occurrence_and_global_document_facts_are_bound(self):
        v,c,g=self.value()
        self.assertEqual(sum(row['stage']=='7' for row in v['segments']),36)
        for mutation in ('missing','kind','status','hash'):
            v,c,g=self.value();key=t.definitions()[0]['id']
            if mutation=='missing':v['documents'].pop(key)
            elif mutation=='kind':v['documents'][key]['facts'][1]='1'
            elif mutation=='status':v['documents'][key]['facts'][2]='2'
            else:v['documents'][key]['facts'][3]=H('wrong native definition')
            with self.subTest(mutation=mutation),self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_runtime_preimages_and_dependency_configuration_are_bound(self):
        for mutation in ('runtime','dependency','dependency_hash','sourceRevision','profile'):
            v,c,g=self.value()
            if mutation=='runtime':v['runtimes'][g['preservationWorker']['address']]='0x01'
            elif mutation=='dependency':v['dependencies'][1][0]=H('different Core')
            elif mutation=='dependency_hash':v['dependencyHash']=H('different configuration')
            else:v[mutation]=H('different '+mutation)
            with self.subTest(mutation=mutation),self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_unused_graph_role_cannot_claim_an_empty_contract_runtime(self):
        v,c,g=self.value()
        pair=g['bundleCoverage'];pair['runtimeHash']=keccak256(b'')
        v['runtimes'][pair['address']]='0x'
        with self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_stage_occurrence_order_item_links_and_totals_are_not_sets(self):
        for mutation in ('omit','swap','repeat','link','plan','evidence'):
            v,c,g=self.value()
            if mutation=='omit':v['segments'].pop(0)
            elif mutation=='swap':v['segments'][0],v['segments'][1]=v['segments'][1],v['segments'][0]
            elif mutation=='repeat':v['segments'].insert(0,deepcopy(v['segments'][0]))
            elif mutation=='link':v['segments'][0]['segment'][1]=H('changed item link')
            elif mutation=='plan':v['plan'][1][7]=str(int(v['plan'][1][7])+1)
            else:v['evidence'][1][-1]=H('changed evidence')
            with self.subTest(mutation=mutation),self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_recorded_getters_require_full_ordered_original_answers(self):
        for mutation in ('omitted_repeat','result','scope','anchor','provenance'):
            v,c,g=self.value();source=v['recordedSource']
            if mutation=='omitted_repeat':source['calls'].pop()
            elif mutation=='result':source['calls'][0]['result']='0x'+bytes(32).hex()
            elif mutation=='scope':source['calls'][7]['calldata']=source['calls'][0]['calldata']
            elif mutation=='anchor':source['blockHash']=H('different block')
            else:source['provenance']='native_execution_verified'
            with self.subTest(mutation=mutation),self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_original_events_and_global_coordinates_are_required(self):
        for mutation in ('missing','payload','before_reference','position','blockhash'):
            v,c,g=self.value()
            if mutation=='missing':v['events'].pop()
            elif mutation=='payload':v['events'][1]['log']['data']='0x'
            elif mutation=='before_reference':v['events'][0]['log']['blockNumber']='0x1'
            elif mutation=='position':v['events'][1]['log']['logIndex']=v['events'][0]['log']['logIndex']
            else:v['events'][1]['log']['blockHash']=H('contradictory same block')
            with self.subTest(mutation=mutation),self.assertRaises(MuseumError):w.validate(v,c,g)


if __name__=='__main__':unittest.main()
