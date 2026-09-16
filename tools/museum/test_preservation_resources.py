"""Synthetic typed/ABI controls and separate actual-source missing-evidence replay."""
import copy
import contextlib
from datetime import datetime, timezone
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.metadata import rights_profile
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import Array, calldata, encode
from .chain_rpc import ReplayTransport
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, RECORD, ZERO, generic_hash
from .metadata_rights_source import (MetadataRightsSource, PROFILE as SOURCE_PROFILE, SCHEMA_NAME, SCHEMA_BYTES,
    SCHEMA_HASH, PROFILE_NAME, PROFILE_BYTES as RIGHTS_PROFILE, PROFILE_HASH as RIGHTS_HASH, JCS_ID, RECEIPT, POINTER, RECORD_TYPE, validate_rights)
from .preservation_resources import (PROFILE_HASH, PROFILE_BYTES, SCHEMAS, MODE, OBJECT_NAME, RIGHT_NAME, FAMILY,
    ROLES, admit_objects, admit_rights, render, project_resources)
from .premis import NS, PinnedPremis, PROFILE_BYTES as XSD_PROFILE, PROFILE_HASH as XSD_HASH
from .review import _selector
from .source import RecordSelector, RetainedSourceRecord
from .test_recorded_account import ROOT, load_source
from .test_package_recorded import inputs, pins
from .package_recorded import build_recorded_package
from .package import write_package
from .package_v2 import verify_package
from .resource_package import build_resource_package
from .test_package import changed

H = lambda n: '0x' + format(n, '064x')
A = lambda n: '0x' + format(n, '040x')


class RightsFixture:
    """Declared synthetic native-response fixture, never an actual captured deployment."""
    def __init__(self, *, basis='contract', status='granted_with_conditions', cls=7, token=False, edit=None):
        self.responses, self.codes, self.counter = {}, {}, 100
        self.a = dict(profile=SOURCE_PROFILE, chainId='31337', blockHash=H(21), blockNumber='20', timestamp='1790000000',
            stateRoot=H(22), environment='local_evm_fixture', deploymentEvidenceHash=keccak256(b'explicit synthetic fixture'),
            host=A(1), core=A(2), schemas=A(3), store=A(4), records=[])
        for n in range(1,5): self.codes[A(n)] = bytes([96,n,0])
        self.a['codePins'] = [{'address': a, 'runtimeHash': keccak256(c)} for a,c in self.codes.items()]
        self.pins = {v['address']:v['runtimeHash'] for v in self.a['codePins']}
        self.documents = {}
        for name,kind,raw,canon in [('RAW_BYTES',1,RAW_DEFINITION,RAW_BYTES), ('RFC8785_JCS',1,JCS_BYTES,RAW_BYTES),
                (SCHEMA_NAME,0,SCHEMA_BYTES,JCS_ID),(PROFILE_NAME,2,RIGHTS_PROFILE,JCS_ID)]:
            chunks=[self.chunk(raw[i:i+8192]) for i in range(0,len(raw),8192)]
            spec=(name,kind,keccak256(raw),canon,ZERO,'',len(raw))
            doc=(True,0,keccak256(encode((DOCUMENT_SPEC,Array('bytes32')),(spec,chunks))),spec,chunks)
            self.add(A(3),'document(bytes32)',('bytes32',),(schema_id(name),),(DOCUMENT,),(doc,))
        for field,getter in [('core','core()'),('schemas','schemaRegistry()'),('store','chunkStore()')]:
            self.add(A(1),getter,(),(),('address',),(self.a[field],))
        for field,getter in [('core','coreCodeHash()'),('schemas','schemaRegistryCodeHash()'),('store','chunkStoreCodeHash()')]:
            self.add(A(1),getter,(),(),('bytes32',),(self.pins[self.a[field]],))
        self.add(A(3),'chunkStore()',(),(),('address',),(A(4),))
        pointer=('0x'+'00'*12+A(1)[2:],self.pins[A(1)],ZERO,schema_id('COLLECTION_METADATA'),ZERO,ZERO,H(1),ZERO,ZERO,ZERO)
        self.add(A(2),'getSatellitePointer(bytes32)',('bytes32',),(schema_id('COLLECTION_METADATA'),),(POINTER,),(pointer,))
        kind='token' if token else 'collection'; tid='41' if token else '0'
        subject=subject_id(kind,'31337',A(2),'1',token_id=tid)
        value=rights_profile.examples()[0]
        value.update(subjectId=subject,profileHash=RIGHTS_HASH,basis=basis)
        value['effectiveDates']={'start':'2026-09-12','end':'2026-12-31'}
        value['grants']={use:{'status':status,'conditions':{'kind':'text','text':'Explicit source condition'} if status=='granted_with_conditions' else None,'extension':'preservation distinct from collector use'} for use in rights_profile.USES}
        if edit: edit(value)
        self.payload=dumps(value); self.value=value
        self.chunk(self.payload)
        self.record=(RECORD_TYPE,subject,(1,hex_bytes(keccak256(self.payload)),JCS_ID),'ipfs://rights-statement',schema_id(SCHEMA_NAME),ZERO,(0,b'',ZERO),1780000000)
        self.record_hash=generic_hash(31337,A(1),A(2),1,A(9),self.record)
        chain=record_chain('31337',A(1),'1',RECORD_TYPE,ZERO,self.record_hash,'0')
        self.receipt=(1,A(9),cls,1780000000,0,chain,SCHEMA_HASH,keccak256(JCS_BYTES),ZERO)
        self.add(A(1),'collectionRecord(bytes32)',('bytes32',),(self.record_hash,),(RECORD,RECEIPT),(self.record,self.receipt))
        self.add(A(1),'recordHashAt(uint256,bytes32,uint256)',('uint256','bytes32','uint256'),(1,RECORD_TYPE,0),('bytes32',),(self.record_hash,))
        self.a['records']=[dict(recordHash=self.record_hash,collectionId='1',kind=kind,tokenId=tid)]

    def chunk(self,raw):
        digest=keccak256(raw);self.counter+=1;address=A(self.counter);self.codes[address]=b'\0'+raw
        self.add(A(4),'chunk(bytes32)',('bytes32',),(digest,),('address','uint32'),(address,len(raw)))
        return digest

    def add(self,target,signature,kinds,values,outputs,result):
        self.responses[(target,calldata(signature,kinds,values))]='0x'+encode(outputs,result).hex()

    def request(self,method,params):
        if method=='eth_chainId': return '0x7a69'
        if method=='eth_getBlockByHash': return dict(hash=H(21),stateRoot=H(22),number='0x14',timestamp=hex(1790000000))
        if method=='eth_getCode': return '0x'+self.codes[params[0]].hex()
        if method=='eth_call': return self.responses[(params[0]['to'],params[0]['data'])]
        raise AssertionError(method)

    def adapter(self): return MetadataRightsSource(dumps(self.a),self)


class ObjectControl:
    def __init__(self,fixture):
        self.anchor={'chainId':'31337','core':A(2),'blockHash':H(21)}
        self.records,self.canonicalizations={},{}
        self.fixture=fixture;self.objects=[]
        for n,role in [(31,'SOURCE_MASTER'),(32,'DISPLAY_DERIVATIVE')]:
            body={'version':'1','collectionId':'1','object':{'objectId':H(n),'objectRole':schema_id(role),'uri':'ipfs://object'+str(n),
                'contentHash':H(51),'mimeType':'image/png','byteSize':'3','formatId':schema_id('PRONOM:fmt/11'),'schemaId':ZERO},
                'hashAlgorithm':'SHA256','format':{'kind':'pronom','puid':'fmt/11'},
                'significantProperties':[{'type':'urn:explicit:property:colour','value':'Exact recorded colour \u0394'}],
                'relationships':[] if n==31 else [{'type':'derivation','subtype':'urn:explicit:is-derived-from','objectId':H(31)}]}
            sid=subject_id('media','31337',A(2),'1',object_id=H(n))
            self.objects.append(self.add(OBJECT_NAME,body,sid))
        body={'version':'1','metadataRecordHash':fixture.record_hash,
            'rights':{'rightsId':H(61),'rightsBasis':schema_id(fixture.value['basis']),'rightsURI':fixture.record[3],
                'rightsHash':keccak256(fixture.payload),'validFrom':str(int(datetime(2026,9,12,tzinfo=timezone.utc).timestamp())),
                'validUntil':'0' if fixture.value['effectiveDates']['end'] is None else str(int(datetime(2026,12,31,tzinfo=timezone.utc).timestamp()))},'objectIds':[H(31),H(32)]}
        self.right=self.add(RIGHT_NAME,body,fixture.value['subjectId'])

    def add(self,name,body,subject):
        raw=dumps(body);h=keccak256(raw);schema=SCHEMAS[name]
        selector=RecordSelector(A(8),h,subject,schema_id(name),keccak256(schema),FAMILY,A(9),'INDEPENDENT_ATTESTOR',str(len(self.records)),H(81))
        record=RetainedSourceRecord(selector,raw,h,schema,dumps({'mode':'synthetic_control','authorizationClass':'INDEPENDENT_ATTESTOR'}),'public')
        self.records[h]=record;self.canonicalizations[h]=JCS_ID
        return _selector(record,'')

    def record(self,selector):
        record=self.records[selector['recordHash']]
        if selector != _selector(record,selector['pointer']): raise MuseumError('test exact selector')
        return record


class PreservationResources(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.schema=PinnedPremis(ROOT,XSD_PROFILE,profile_hash=XSD_HASH)

    def prepared(self,**options):
        fixture=RightsFixture(**options);adapter=fixture.adapter();adapter.snapshot()
        source=ObjectControl(fixture);objects=admit_objects(source,source.objects)
        rows=admit_rights(source,[source.right],adapter,objects)
        return fixture,adapter,source,objects,rows

    def test_actual_original_schema_bytes_and_definitions_are_reused(self):
        self.assertEqual((ROOT.parent/'records/STREAM_RIGHTS_V1.json').read_bytes(),SCHEMA_BYTES)
        self.assertEqual((ROOT.parent/'records/STREAM_RIGHTS_JSON_PROFILE_V1.json').read_bytes(),RIGHTS_PROFILE)
        root=ROOT/'preservation-resources'
        self.assertEqual((root/'profile.json').read_bytes(),PROFILE_BYTES)
        for name,raw in SCHEMAS.items(): self.assertEqual((root/(name+'.json')).read_bytes(),raw)

    def test_canonical_media_objects_roles_relationships_hash_and_original_properties(self):
        _,_,_,objects,rights=self.prepared()
        xml,issues,maps,evidence=render(objects,rights,self.schema)
        self.assertFalse(issues);root=self.schema.validate(xml)
        self.assertEqual(len(root.findall('{'+NS+'}object')),2)
        for row in objects: self.assertIn(row['subject'].encode(),xml)
        self.assertIn(b'6529STREAM_SUBJECT',xml);self.assertIn(b'SOURCE_MASTER',xml)
        self.assertIn('Exact recorded colour \u0394'.encode(),xml)
        self.assertEqual(len(root.findall('.//{'+NS+'}relationship')),1)
        self.assertEqual({m["objectId"]:m["subjectId"] for m in maps if m["kind"]=="object"}, {r["value"]["object"]["objectId"]:r["subject"] for r in objects})
        self.assertEqual(evidence[0]['authority']['mode'],'synthetic_control')

    def test_six_rights_bases_four_statuses_exact_grants_licensor_and_dates(self):
        for basis in ('copyright','license','statute','public_domain','contract','unspecified'):
            for status in rights_profile.STATUS:
                with self.subTest(basis=basis,status=status):
                    _,_,_,objects,rows=self.prepared(basis=basis,status=status)
                    xml,issues,_,_=render(objects,rows,self.schema);self.assertFalse(issues)
                    root=self.schema.validate(xml);self.assertEqual(root.findtext('.//{'+NS+'}rightsBasis'),basis)
                    grants=root.findall('.//{'+NS+'}rightsGranted');self.assertEqual(len(grants),6)
                    self.assertEqual({n.findtext('{'+NS+'}act') for n in grants},set(rights_profile.USES))
                    self.assertEqual({n.findtext('{'+NS+'}restriction') for n in grants},{status})
                    self.assertIn(b'rightsHolder',xml);self.assertIn(b'2026-09-12',xml)
                    self.assertNotIn(b'<premis:agentType>person',xml)

    def test_all_original_object_roles_and_keccak_have_explicit_xml_values(self):
        fixture=RightsFixture();source=ObjectControl(fixture)
        base=loads(source.record(source.objects[0]).payload)
        for role in ROLES:
            body=copy.deepcopy(base);body['object']['objectRole']=schema_id(role);body['hashAlgorithm']='KECCAK256'
            selector=source.add(OBJECT_NAME,body,source.objects[0]['subjectId'])
            xml,issues,_,_=render(admit_objects(source,[selector]),[],self.schema)
            self.assertFalse(issues);self.assertIn(role.encode(),xml);self.assertIn(b'Keccak-256',xml)

    def test_original_licensor_variants_instrument_conditions_and_open_dates(self):
        identities=[{'kind':'artist','artistId':H(3)},{'kind':'address','address':A(9)},
            {'kind':'estate','name':'Explicit estate'}, {'kind':'institution','name':'Recorded institution'}]
        for identity in identities:
            def edit(value):
                document={'hash':{'algorithm':1,'canonicalizationId':RAW_BYTES,'digest':H(92)},'uri':'ipfs://instrument'}
                value['instrument']=document;value['licensor']={'identity':identity,'instrumentDigest':H(92)}
                value['grants']['reproduction']['conditions']={'kind':'document','document':document}
                value['effectiveDates']['end']=None
            _,_,_,objects,rows=self.prepared(edit=edit)
            xml,issues,maps,_=render(objects,rows,self.schema);self.assertFalse(issues)
            self.assertIn(b'ipfs://instrument',xml);self.assertIn(H(92).encode(),xml)
            self.assertNotIn(b'<premis:endDate>',xml)
            self.assertEqual(next(m for m in maps if m['kind']=='rights')['validUntil'],'0')

    def test_same_named_licensors_remain_scoped_to_each_selected_statement(self):
        def edit(value):
            value['licensor']={'identity':{'kind':'institution','name':'Same asserted name'},'instrumentDigest':None}
            value['instrument']=None
        _,_,_,objects,rows=self.prepared(edit=edit)
        # Serializer-only synthetic rows: receipt admission is tested separately.
        second={**rows[0], 'link':copy.deepcopy(rows[0]['link']), 'saved':{**rows[0]['saved'], 'recordHash':H(94)}}
        second['link']['rights']['rightsId']=H(62)
        xml,issues,maps,_=render(objects,[rows[0],second],self.schema)
        self.assertFalse(issues)
        root=self.schema.validate(xml)
        agents=root.findall('{'+NS+'}agent')
        self.assertEqual(len(agents),2)
        self.assertEqual([a.findtext('{'+NS+'}agentName') for a in agents],['Same asserted name']*2)
        holders={m['rightsHolder'] for m in maps if m['kind']=='rights'}
        self.assertEqual(len(holders),2)
        for row in (rows[0],second):
            expected='urn:6529stream:reported-licensor:'+keccak256(dumps({
                'recordHash':row['saved']['recordHash'], 'identity':row['saved']['value']['licensor']['identity']}))
            self.assertIn(expected,holders)

    def test_selected_nonfirst_receipt_joins_the_actual_admitted_previous_chain(self):
        fixture=RightsFixture();old_hash=fixture.record_hash
        value=copy.deepcopy(fixture.value);value['predecessor']=old_hash;value['grants']['print']['status']='denied'
        raw=dumps(value);fixture.chunk(raw)
        record=list(fixture.record);record[2]=(1,hex_bytes(keccak256(raw)),JCS_ID);record=tuple(record)
        h=generic_hash(31337,A(1),A(2),1,A(9),record)
        receipt=list(fixture.receipt);receipt[4]=1;receipt[5]=record_chain('31337',A(1),'1',RECORD_TYPE,fixture.receipt[5],h,'1');receipt=tuple(receipt)
        fixture.add(A(1),'collectionRecord(bytes32)',('bytes32',),(h,),(RECORD,RECEIPT),(record,receipt))
        fixture.add(A(1),'recordHashAt(uint256,bytes32,uint256)',('uint256','bytes32','uint256'),(1,RECORD_TYPE,1),('bytes32',),(h,))
        fixture.a['records'][0]['recordHash']=h
        source=fixture.adapter();source.snapshot()
        self.assertEqual(source.records[h]['value']['predecessor'],old_hash)
        prior=list(fixture.receipt);prior[5]=H(93)
        fixture.add(A(1),'collectionRecord(bytes32)',('bytes32',),(old_hash,),(RECORD,RECEIPT),(fixture.record,tuple(prior)))
        with self.assertRaisesRegex(MuseumError,'receipt chain'): fixture.adapter().snapshot()

    def test_original_class_and_family_cannot_be_replaced_by_independent_text(self):
        for cls in (1,5,6,9):
            with self.subTest(cls=cls),self.assertRaisesRegex(MuseumError,'original receipt'):
                RightsFixture(cls=cls).adapter().snapshot()
        fixture=RightsFixture(cls=8,token=True);adapter=fixture.adapter();snapshot=loads(adapter.snapshot(),maximum=1048576)
        self.assertEqual(snapshot['mode'],'synthetic_fixture')
        self.assertFalse(snapshot['claims']['currentRightsSelection'])
        self.assertEqual(next(iter(adapter.records.values()))['authority']['authorizationClass'],'8')
        with self.assertRaisesRegex(MuseumError,'provenance'):
            MetadataRightsSource(dumps(fixture.a),fixture,provenance='trusted_rpc')

    def test_metadata_anchor_runtime_record_hash_index_chain_and_payload_tampering_reject(self):
        for kind in ('runtime','receipt','index','chain','payload','subject','schema_kind'):
            fixture=RightsFixture()
            if kind=='runtime': fixture.codes[A(1)]=b'wrong'
            if kind in ('receipt','chain'):
                receipt=list(fixture.receipt);receipt[2 if kind=='receipt' else 5]=5 if kind=='receipt' else H(987)
                fixture.add(A(1),'collectionRecord(bytes32)',('bytes32',),(fixture.record_hash,),(RECORD,RECEIPT),(fixture.record,tuple(receipt)))
            if kind=='index': fixture.add(A(1),'recordHashAt(uint256,bytes32,uint256)',('uint256','bytes32','uint256'),(1,RECORD_TYPE,0),('bytes32',),(H(2),))
            if kind=='payload':
                key=next(k for k,v in fixture.codes.items() if v==b'\0'+fixture.payload);fixture.codes[key]=b'\1'+fixture.payload
            if kind=='subject': fixture.a['records'][0].update(kind='token',tokenId='1')
            if kind=='schema_kind':
                key=(A(3),calldata('document(bytes32)',('bytes32',),(schema_id(PROFILE_NAME),)))
                raw=bytearray(hex_bytes(fixture.responses[key]));raw[95]=3;fixture.responses[key]='0x'+raw.hex()
            with self.subTest(kind=kind),self.assertRaises(MuseumError): fixture.adapter().snapshot()

    def test_exact_one_block_transcript_replay_requires_external_pins_and_all_calls(self):
        fixture,adapter,_,_,_=self.prepared()
        raw=adapter.reader.transcript()
        replay=MetadataRightsSource(dumps(fixture.a),ReplayTransport(raw,keccak256(raw)),provenance='trusted_rpc')
        # Replay machinery control only: these underlying responses remain explicitly synthetic.
        result=loads(replay.snapshot(),maximum=1048576)
        self.assertEqual(result['records'],loads(adapter.snapshot(),maximum=1048576)['records'])
        with self.assertRaisesRegex(MuseumError,'external commitment'): ReplayTransport(raw,H(3))
        data=loads(raw,maximum=1048576);data['calls'].append(data['calls'][-1]);extra=dumps(data)
        with self.assertRaisesRegex(MuseumError,'unconsumed'):
            MetadataRightsSource(dumps(fixture.a),ReplayTransport(extra,keccak256(extra)),provenance='trusted_rpc').snapshot()

    def test_present_rights_cross_field_date_uri_and_conditional_errors_reject(self):
        base=RightsFixture().value
        for change in (lambda v:v['effectiveDates'].update(start='2026-02-30'),
                lambda v:v['effectiveDates'].update(end='2025-01-01'),
                lambda v:v['grants']['reproduction'].update(conditions=None),
                lambda v:v['licensor'].update(instrumentDigest=H(5)),
                lambda v:v.update(AI_TRAINING_PERMISSION='denied')):
            value=copy.deepcopy(base);change(value)
            with self.assertRaises(MuseumError): validate_rights(dumps(value),base['subjectId'])

    def test_object_scope_format_duplicates_width_and_missing_relationship(self):
        fixture=RightsFixture();source=ObjectControl(fixture)
        body=loads(source.record(source.objects[0]).payload)
        for change in (lambda b:b['object'].update(formatId=H(1)),lambda b:b['object'].update(objectId=H(99)),
                lambda b:b.update(collectionId='2')):
            value=copy.deepcopy(body);change(value);selected=source.add(OBJECT_NAME,value,source.objects[0]['subjectId'])
            with self.assertRaises(MuseumError): admit_objects(source,[selected])
        with self.assertRaisesRegex(MuseumError,'repeats'): admit_objects(source,[source.objects[0]]*2)
        for mutation,reason in ((lambda b:b.update(format={'kind':'unavailable'}),'registered_format_mapping_unavailable'),
                (lambda b:b['object'].update(byteSize=str(1<<255)),'premis_size_outside_xs_long'),
                (lambda b:b.update(relationships=[{'type':'structural','subtype':'urn:missing','objectId':H(99)}]),'related_object_not_selected')):
            value=copy.deepcopy(body);mutation(value);selected=source.add(OBJECT_NAME,value,source.objects[0]['subjectId'])
            xml,issues,_,_=render(admit_objects(source,[selected]),[],self.schema)
            self.assertIsNone(xml);self.assertEqual(issues[0]['reasonCode'],reason)

    def test_independent_rights_link_cannot_change_actual_basis_hash_dates_or_object_scope(self):
        _,adapter,source,objects,_=self.prepared()
        base=loads(source.record(source.right).payload)
        for mutation in (lambda b:b['rights'].update(rightsHash=H(9)),lambda b:b['rights'].update(rightsBasis=H(9)),
                lambda b:b['rights'].update(validUntil='0'),lambda b:b['rights'].update(validFrom='1700000000'),
                lambda b:b.update(objectIds=[H(99)])):
            body=copy.deepcopy(base);mutation(body);selector=source.add(RIGHT_NAME,body,source.right['subjectId'])
            with self.assertRaises(MuseumError): admit_rights(source,[selector],adapter,objects)

    def test_real_retained_source_missing_objects_and_offline_cli_replay_stays_honest(self):
        source=load_source()
        plan=dumps({'mode':MODE,'version':'1','sourceStateHash':source.state.commitment,'accountProfileHash':source.profile_hash,
            'resourceProfileHash':PROFILE_HASH,'rightsSourceHash':None,'objects':[],'rights':[]})
        result=project_resources(source,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,
            rights_source=None,rights_source_hash=None,premis_schema=self.schema)
        self.assertIsNone(result.xml);self.assertEqual(loads(result.report)['issues'],[{'reasonCode':'no_selected_preservation_objects'}])
        from .recorded_premis import PROFILE_HASH as FILE_PROFILE
        file_plan=(ROOT/'premis-recorded/missing-file-plan.json').read_bytes()
        original=build_recorded_package(inputs(),root=ROOT,disclosure='public',**pins(),premis_plan_bytes=file_plan,
            premis_plan_hash=keccak256(file_plan),premis_profile_hash=FILE_PROFILE)
        with tempfile.TemporaryDirectory() as temp:
            src=Path(temp)/'source';write_package(original,src)
            result=build_resource_package(src,original.manifest_hash,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,disclosure='public')
            self.assertEqual(dict(result.files)['source/manifest.json'],original.manifest)
            target=Path(temp)/'output';write_package(result,target)
            with patch('socket.socket',side_effect=AssertionError('network')): self.assertEqual(verify_package(target,result.manifest_hash),result)
            bad=changed(result,'premis-resources/provenance.json',b'[] ');altered=Path(temp)/'bad';write_package(bad,altered)
            with self.assertRaisesRegex(MuseumError,'reconstruction'): verify_package(altered,bad.manifest_hash)
            from .resource_package import main
            plan_path=Path(temp)/'plan.json';plan_path.write_bytes(plan)
            argv=['resource_package','build',str(src),str(plan_path),str(Path(temp)/'cli'),'--source-manifest-hash',original.manifest_hash,
                '--plan-hash',keccak256(plan),'--profile-hash',PROFILE_HASH,'--disclosure','public']
            with patch.object(sys,'argv',argv),contextlib.redirect_stdout(io.StringIO()): self.assertEqual(main(),0)
            with self.assertRaisesRegex(MuseumError,'public'):
                build_resource_package(src,original.manifest_hash,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,disclosure='restricted')


if __name__=='__main__': unittest.main()