"""Synthetic original-wire controls; actual recorded-source absence is a separate case."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from .account_profile import JCS_BYTES
from .canonical import MuseumError,dumps,hex_bytes,keccak256,loads,record_chain,schema_id,subject_id
from .chain_abi import Array,encode
from .chain_rpc import ReplayTransport
from .independent_wire import DOCUMENT,DOCUMENT_SPEC,RAW_BYTES,RAW_DEFINITION,ZERO,generic_hash
from .owner_record_source import OwnerRecordSource,OWNER_RECORD,RECEIPT,PROFILE as SOURCE_PROFILE,domain,words,verify_wire
from .loans import NAME,SCHEMA_BYTES,PROFILE_BYTES,PROFILE_HASH,JCS_ID,admit,render,project_loans,validator
from .exhibitions import fields
from .test_exhibitions import reference,date
from .test_preservation_resources import RightsFixture,A,H
from .test_recorded_account import ROOT,load_source
from .test_package_recorded import inputs,pins
from .package_recorded import build_recorded_package
from .package import write_package
from .package_v2 import verify_package
from .test_package import changed
from .loan_package import build_loan_package


def party(name,identifier,kind='Group'):
    return {'entityId':'urn:test:'+identifier,'kind':kind,'identity':{'kind':'did','value':'did:example:'+identifier},
        'name':{'value':name,'language':'en'},'reference':reference(8)}


def loan():
    return {'version':'1','loanId':'urn:test:loan','tokenId':'41','status':'completed','title':{'value':'Exact loan dossier Δ','language':None},
        'lender':party('Lender, as recorded','lender'),'borrower':party('Borrower, as recorded','borrower'),
        'opening':date(),'closing':date('2026-09-15T18:00:00Z'),'insuranceValuation':None,'outboundConditionReport':None,
        'returnConditionReport':None,'conditionReferences':[reference(5)],
        'returnConditions':{'text':'Return under the recorded agreement\r\n<no enforcement>','reference':reference(6)}}


class OwnerFixture:
    """Declared synthetic RPC responses using original owner wire; never a deployed fixture."""
    add=RightsFixture.add
    chunk=RightsFixture.chunk
    def __init__(self,*,relayed=None,edit=None,anchor=None):
        self.responses,self.codes,self.counter={}, {},100
        self.evidence=dumps({'mode':'synthetic_owner_wire_control','notAnActualDeployment':True})
        self.a=dict(profile=SOURCE_PROFILE,chainId='31337',blockHash=H(21),blockNumber='20',timestamp='1790000000',stateRoot=H(22),
            environment='local_evm_fixture',deploymentEvidenceHash=keccak256(self.evidence),host=A(1),core=A(2),schemas=A(3),store=A(4),records=[])
        if anchor:
            for k in ('chainId','core','blockHash','blockNumber','timestamp','stateRoot'):self.a[k]=anchor[k]
        for n,k in enumerate(('host','core','schemas','store'),1):self.codes[self.a[k]]=bytes([96,n,0])
        self.a['codePins']=[{'address':a,'runtimeHash':keccak256(c)} for a,c in self.codes.items()]
        self.pins={v['address']:v['runtimeHash'] for v in self.a['codePins']}
        self.documents={}
        for name,kind,raw,canon in [('RAW_BYTES',1,RAW_DEFINITION,RAW_BYTES),('RFC8785_JCS',1,JCS_BYTES,RAW_BYTES),
                (NAME,0,SCHEMA_BYTES,JCS_ID),('STREAM_VALUATION_V1',0,dumps({'type':'object'}),JCS_ID),
                ('STREAM_CONDITION_REPORT_V1',0,dumps({'type':'object','additionalProperties':True}),JCS_ID)]:
            chunks=[self.chunk(raw[i:i+8192]) for i in range(0,len(raw),8192)]
            spec=(name,kind,keccak256(raw),canon,ZERO,'',len(raw))
            doc=(True,0,keccak256(encode((DOCUMENT_SPEC,Array('bytes32')),(spec,chunks))),spec,chunks)
            self.add(self.a['schemas'],'document(bytes32)',('bytes32',),(schema_id(name),),(DOCUMENT,),(doc,));self.documents[name]=raw
        for field,getter in [('core','core()'),('schemas','schemaRegistry()'),('store','chunkStore()')]:
            self.add(self.a['host'],getter,(),(),('address',),(self.a[field],))
        for field,getter in [('core','coreCodeHash()'),('schemas','schemaRegistryCodeHash()'),('store','chunkStoreCodeHash()')]:
            self.add(self.a['host'],getter,(),(),('bytes32',),(self.pins[self.a[field]],))
        self.add(self.a['schemas'],'chunkStore()',(),(),('address',),(self.a['store'],))
        for getter,value in [('streamModuleType()',schema_id('OWNER_RECORDS')),('streamModuleVersion()',schema_id('6529stream.owner-records.v1'))]:
            self.add(self.a['host'],getter,(),(),('bytes32',),(value,))
        self.rows={};self.lanes={};self.relayed=relayed
        valuation=self.append('VALUATION','STREAM_VALUATION_V1',{'description':'Opaque public valuation instrument commitment, no figure'},None)
        outbound=self.append('CONDITION_REPORT','STREAM_CONDITION_REPORT_V1',{'description':'Opaque outbound declaration'},None)
        returned=self.append('CONDITION_REPORT','STREAM_CONDITION_REPORT_V1',{'description':'Opaque return declaration'},None)
        value=loan()
        for field,h in [('insuranceValuation',valuation),('outboundConditionReport',outbound),('returnConditionReport',returned)]:
            r=self.rows[h][0];value[field]={'recordHash':h,'uri':'https://example.invalid/'+field,
                'hash':{'algorithm':'1','digest':'0x'+r[3][1].hex(),'canonicalizationId':JCS_ID}}
        if edit:edit(value)
        self.value=value;self.loan_hash=self.append('LOAN',NAME,value,relayed)

    def append(self,family,schema,value,relayed=None):
        token=int(value.get('tokenId','41'));rt=schema_id(family);raw=dumps(value);payload_hash=keccak256(raw)
        sid=subject_id('token',self.a['chainId'],self.a['core'],'0',token_id=str(token))
        record=(rt,sid,schema_id(schema),(1,hex_bytes(payload_hash),JCS_ID),'ipfs://original-owner-record',raw,1)
        prior=self.lanes.get((token,rt),[]);stamp=int(self.a['timestamp'])-1
        receipt=[token,A(9),stamp,len(prior),ZERO,relayed is not None,ZERO,0,0,keccak256(self.documents[schema]),keccak256(JCS_BYTES),schema_id('DIRECT' if relayed is None else relayed),ZERO]
        if relayed is None:bundle=encode(('bytes32','address','bytes32'),(schema_id('DIRECT'),A(9),payload_hash))
        else:
            receipt[7],receipt[8]=37,stamp+100;body=words(record,receipt);d=domain(int(self.a['chainId']),self.a['host'])
            signature=bytes.fromhex('12'*65) if relayed=='EIP712' else b'explicit synthetic ERC1271 bytes'
            from .chain_abi import decode
            ws=decode(('bytes32',)*14,body)
            bundle=encode(('bytes32',('bytes32',)*14,'bytes'),(d,ws,signature))
            receipt[6]=keccak256(b'\x19\x01'+hex_bytes(d)+hex_bytes(keccak256(body)))
            self.add(self.a['host'],'isOwnerRecordNonceUsed(address,uint256)',('address','uint256'),(A(9),37),('bool',),(True,))
        receipt[12]=keccak256(bundle)
        generic=(rt,sid,record[3],record[4],record[2],receipt[11],(1,hex_bytes(receipt[12]),RAW_BYTES),record[6])
        h=generic_hash(int(self.a['chainId']),self.a['host'],self.a['core'],token,A(9),generic)
        previous=ZERO if not prior else self.rows[prior[-1]][1][4]
        receipt[4]=record_chain(self.a['chainId'],self.a['host'],str(token),rt,previous,h,str(len(prior)))
        self.rows[h]=(record,tuple(receipt),bundle);self.lanes.setdefault((token,rt),[]).append(h)
        self.chunk(raw);bundle_hash=self.chunk(bundle);pointer=self.chunks_pointer(bundle_hash)
        self.add(self.a['host'],'ownerRecord(bytes32)',('bytes32',),(h,),(OWNER_RECORD,RECEIPT),(record,tuple(receipt)))
        self.add(self.a['host'],'ownerRecordSignatureBundle(bytes32)',('bytes32',),(h,),('address','bytes'),(pointer,bundle))
        self.add(self.a['host'],'recordHashAt(uint256,bytes32,uint256)',('uint256','bytes32','uint256'),(token,rt,receipt[3]),('bytes32',),(h,))
        self.a['records'].append({'recordHash':h,'tokenId':str(token)})
        return h

    def chunks_pointer(self,digest):
        for address,code in reversed(list(self.codes.items())):
            if code[:1]==b'\0' and keccak256(code[1:])==digest:return address
        raise AssertionError(digest)

    def request(self,method,params):
        if method=='eth_chainId':return hex(int(self.a['chainId']))
        if method=='eth_getBlockByHash':return dict(hash=self.a['blockHash'],stateRoot=self.a['stateRoot'],number=hex(int(self.a['blockNumber'])),timestamp=hex(int(self.a['timestamp'])))
        if method=='eth_getCode':return '0x'+self.codes[params[0]].hex()
        if method=='eth_call':return self.responses[(params[0]['to'],params[0]['data'])]
        raise AssertionError(method)

    def adapter(self):return OwnerRecordSource(dumps(self.a),self)
    def replay(self):
        synthetic=self.adapter();synthetic.snapshot();transcript=synthetic.reader.transcript()
        source=OwnerRecordSource(dumps(self.a),ReplayTransport(transcript,keccak256(transcript)),provenance='trusted_rpc')
        return source,{'anchor.json':dumps(self.a),'transcript.json':transcript,'deployment-evidence.json':self.evidence},synthetic


class LoanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.model=validator(ROOT)
    def projected(self,**kw):
        f=OwnerFixture(**kw);s=f.adapter();s.snapshot();return f,s,render(admit(s,[f.loan_hash]),self.model)
    def test_original_direct_receipt_payload_schema_and_chain_checked(self):
        f,s,files=self.projected();self.assertEqual(loads(s.snapshot(),maximum=2097152)['mode'],'synthetic_fixture')
        self.assertEqual(len(s.records),4);self.assertEqual(s.records[f.loan_hash]['receipt'][11],schema_id('DIRECT'))
        self.assertFalse(any(loads(files['loans/report.json'])['claims'].values()))
        self.assertEqual((ROOT/'loan'/ (NAME+'.json')).read_bytes(),SCHEMA_BYTES)
        self.assertEqual((ROOT/'loan/profile.json').read_bytes(),PROFILE_BYTES)
    def test_relayed_original_eoa_and_safe_bundles_and_nonce(self):
        for scheme in ('EIP712','ERC1271'):
            f,s,_=self.projected(relayed=scheme);self.assertEqual(s.records[f.loan_hash]['receipt'][11],schema_id(scheme))
            self.assertTrue(s.records[f.loan_hash]['receipt'][5])
        f=OwnerFixture(relayed='ERC1271');f.add(f.a['host'],'isOwnerRecordNonceUsed(address,uint256)',('address','uint256'),(A(9),37),('bool',),(False,))
        with self.assertRaisesRegex(MuseumError,'nonce'):f.adapter().snapshot()
    def test_signed_domain_direct_flags_and_payload_tampering_reject(self):
        for mode in (None,'ERC1271'):
            f=OwnerFixture(relayed=mode);r,t,b=f.rows[f.loan_hash]
            for index,value in ((0,99),(1,A(77)),(2,0),(9,ZERO),(12,H(99))):
                bad=list(t);bad[index]=value
                with self.assertRaises(MuseumError):verify_wire(31337,A(1),A(2),1790000000,f.loan_hash,41,r,bad,b)
            with self.assertRaises(MuseumError):verify_wire(31337,A(77),A(2),1790000000,f.loan_hash,41,r,t,b)
        f=OwnerFixture();r,t,b=f.rows[f.loan_hash];bad=list(t);bad[7]=1
        with self.assertRaisesRegex(MuseumError,'direct'):verify_wire(31337,A(1),A(2),1790000000,f.loan_hash,41,r,bad,b)
    def test_owner_runtime_schema_bundle_chain_and_foreign_token_controls(self):
        for mutate in (lambda f:f.codes.update({A(1):b'changed'}),
            lambda f:f.add(A(1),'recordHashAt(uint256,bytes32,uint256)',('uint256','bytes32','uint256'),(41,schema_id('LOAN'),0),('bytes32',),(H(77),)),
            lambda f:f.add(A(1),'schemaRegistryCodeHash()',(),(),('bytes32',),(H(77),))):
            f=OwnerFixture();mutate(f)
            with self.assertRaises(MuseumError):f.adapter().snapshot()
        f=OwnerFixture();f.a['records'][-1]['tokenId']='42'
        with self.assertRaisesRegex(MuseumError,'subject'):f.adapter().snapshot()
    def test_uri_only_and_unsupported_payload_hash_profiles_fail_explicitly(self):
        f=OwnerFixture();r,t,b=f.rows[f.loan_hash]
        for payload,content in ((b'',r[3]),(r[5],(2,r[3][1],r[3][2])),(r[5],(1,r[3][1],ZERO))):
            bad=list(r);bad[3]=content;bad[5]=payload
            with self.assertRaisesRegex(MuseumError,'embedded keccak'):
                verify_wire(31337,A(1),A(2),1790000000,f.loan_hash,41,bad,t,b)

    def test_explicit_public_classification_and_plan_pins(self):
        plan=dumps({'version':'1','ownerSourceHash':None,'records':[]})
        with self.assertRaisesRegex(MuseumError,'public classification'):
            build_loan_package(Path('unused'),H(1),plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,disclosure='restricted')
        for plan_hash,profile_hash in ((H(1),PROFILE_HASH),(keccak256(plan),H(2))):
            with self.assertRaisesRegex(MuseumError,'profile/plan'):
                project_loans(None,plan,plan_hash=plan_hash,profile_hash=profile_hash,source_hash=None,model=self.model)

    def test_named_roles_generic_activity_and_full_reference_dossier(self):
        f,s,files=self.projected();resources=[loads(raw) for p,raw in files.items() if p.startswith('loans/resources/')]
        self.assertEqual(sorted(r['type'] for r in resources),['Activity','Group','Group'])
        event=next(r for r in resources if r['type']=='Activity');self.assertEqual(event['id'],'urn:test:loan')
        self.assertEqual(len(event['participant']),2);self.assertNotIn('transferred_custody_of',event)
        roles=loads(files['loans/participant-roles.json']);self.assertEqual([r['role'] for r in roles],['lender','borrower'])
        dossier=loads(files['loans/dossiers.json'],maximum=2097152)[0]
        self.assertEqual(dossier['loan'],f.value);self.assertEqual(len(dossier['references']),3)
        self.assertTrue(all(not r['operativeAtLoanPublicationProven'] for r in dossier['references']))
        coverage=loads(files['loans/coverage.json'],maximum=2097152)
        self.assertEqual({r['sourcePath']:r['value'] for r in coverage},dict(fields(f.value)))
    def test_missing_selected_documents_and_return_conditions_remain_explicit(self):
        f=OwnerFixture(edit=lambda v:v.update(returnConditionReport=None));s=f.adapter();s.snapshot()
        files=render(admit(s,[f.loan_hash]),self.model)
        self.assertIn('returnConditionReport_not_recorded',loads(files['loans/report.json'])['dispositions'][0]['missingFacts'])
        f=OwnerFixture();f.a['records']=[f.a['records'][-1]];s=f.adapter();s.snapshot()
        report=loads(render(admit(s,[f.loan_hash]),self.model)['loans/report.json'])
        self.assertEqual(report['status'],'incomplete');self.assertEqual(len(report['dispositions'][0]['missingFacts']),3)
    def test_registered_loan_schema_requires_original_jcs_binding(self):
        f=OwnerFixture();raw=SCHEMA_BYTES
        chunks=[keccak256(raw[i:i+8192]) for i in range(0,len(raw),8192)]
        spec=(NAME,0,keccak256(raw),RAW_BYTES,ZERO,'',len(raw))
        doc=(True,0,keccak256(encode((DOCUMENT_SPEC,Array('bytes32')),(spec,chunks))),spec,chunks)
        f.add(f.a['schemas'],'document(bytes32)',('bytes32',),(schema_id(NAME),),(DOCUMENT,),(doc,))
        s=f.adapter();s.snapshot()
        with self.assertRaisesRegex(MuseumError,'schema/JCS'):admit(s,[f.loan_hash])

    def test_linked_reference_hash_family_and_subject_cannot_be_substituted(self):
        for mutate in (lambda v:v['insuranceValuation']['hash'].update(digest=H(77)),
            lambda v:v.update(insuranceValuation=v['outboundConditionReport']),
            lambda v:v.update(tokenId='42')):
            f=OwnerFixture(edit=mutate);s=f.adapter();s.snapshot()
            with self.assertRaisesRegex(MuseumError,'linked reference'):admit(s,[f.loan_hash])
    def test_planned_cancelled_unknown_and_missing_names_never_fabricate_completed_event(self):
        for status in ('planned','cancelled','unknown'):
            f,s,files=self.projected(edit=lambda v:v.update(status=status))
            self.assertEqual(loads(files['loans/index.json'])['resources'],[])
        f,s,files=self.projected(edit=lambda v:v['borrower'].update(name=None))
        self.assertEqual(loads(files['loans/report.json'])['dispositions'][0]['disposition'],'unsupported')
    def test_exact_party_reuse_keeps_roles_and_rejects_cross_kind_conflicts(self):
        f=OwnerFixture();v=copy.deepcopy(f.value);v['loanId']='urn:test:loan-2';second=f.append('LOAN',NAME,v)
        s=f.adapter();s.snapshot();files=render(admit(s,[f.loan_hash,second]),self.model)
        self.assertEqual(len(loads(files['loans/index.json'])['resources']),4)
        f=OwnerFixture(edit=lambda v:v['borrower'].update(entityId='urn:test:loan'));s=f.adapter();s.snapshot()
        with self.assertRaisesRegex(MuseumError,'cross-kind'):admit(s,[f.loan_hash])
    def test_production_requires_exact_source_plan_and_never_promotes_synthetic_transport(self):
        f=OwnerFixture();s=f.adapter();raw=s.snapshot();plan=dumps({'version':'1','ownerSourceHash':keccak256(raw),'records':[f.loan_hash]})
        with self.assertRaisesRegex(MuseumError,'concrete recorded'):project_loans(s,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,source_hash=keccak256(raw),model=self.model)
        with self.assertRaisesRegex(MuseumError,'provenance'):OwnerRecordSource(dumps(f.a),f,provenance='trusted_rpc')
        source,_,_=f.replay();raw=source.snapshot();plan=dumps({'version':'1','ownerSourceHash':keccak256(raw),'records':[f.loan_hash]})
        with patch('socket.socket',side_effect=AssertionError('offline')):
            self.assertTrue(project_loans(source,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,source_hash=keccak256(raw),model=self.model))
    def test_actual_recorded_package_replays_explicit_absent_owner_source(self):
        original=build_recorded_package(inputs(),root=ROOT,disclosure='public',**pins());plan=dumps({'version':'1','ownerSourceHash':None,'records':[]})
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);write_package(original,root/'source')
            with patch('socket.socket',side_effect=AssertionError('offline')):
                result=build_loan_package(root/'source',original.manifest_hash,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,disclosure='public')
                self.assertEqual(loads(dict(result.files)['loans/report.json'])['reasonCode'],'owner_receipt_source_missing')
                for name,raw in original.files:self.assertEqual(dict(result.files)['source/'+name],raw)
                write_package(result,root/'export');self.assertEqual(verify_package(root/'export',result.manifest_hash),result)
            altered=changed(result,'loans/report.json',dumps({'custodyTransferred':True}));write_package(altered,root/'changed')
            with self.assertRaisesRegex(MuseumError,'semantic reconstruction'):verify_package(root/'changed',altered.manifest_hash)
    def test_explicit_synthetic_owner_transcript_package_replays_and_rejects_pin_drift(self):
        actual=load_source();f=OwnerFixture(anchor=actual.anchor);source,owner_inputs,_=f.replay();raw=source.snapshot()
        owner_pins={'anchorHash':keccak256(owner_inputs['anchor.json']),'transcriptHash':keccak256(owner_inputs['transcript.json']),'sourceHash':keccak256(raw)}
        plan=dumps({'version':'1','ownerSourceHash':keccak256(raw),'records':[f.loan_hash]})
        original=build_recorded_package(inputs(),root=ROOT,disclosure='public',**pins())
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);write_package(original,root/'source')
            with patch('socket.socket',side_effect=AssertionError('offline')):
                result=build_loan_package(root/'source',original.manifest_hash,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,owner_inputs=owner_inputs,owner_pins=owner_pins,disclosure='public')
                self.assertEqual(dict(result.files)['owner-records/deployment-evidence.json'],f.evidence)
                write_package(result,root/'export');self.assertEqual(verify_package(root/'export',result.manifest_hash),result)
            for key in owner_pins:
                bad={**owner_pins,key:H(88)}
                with self.assertRaises(MuseumError):build_loan_package(root/'source',original.manifest_hash,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,owner_inputs=owner_inputs,owner_pins=bad,disclosure='public')


if __name__=='__main__':unittest.main()
