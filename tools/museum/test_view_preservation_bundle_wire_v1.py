"""Independent ABI preimages for synthetic recorded VIEW archival admissions."""
from copy import deepcopy
import hashlib
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from . import view_preservation_bundle_wire_v1 as w
from . import view_preservation_inventory_types_v1 as t
from .canonical import MuseumError, dumps, loads, hex_bytes, keccak256 as K, schema_id as D, subject_id
from .chain_abi import calldata, encode, decode
from .independent_wire import ZERO as Z, ZERO_ADDRESS as ZA, json_values


def A(n): return '0x'+format(n,'040x')
def H(k,v): return K(encode(k,v))
def DH(label,k,v): return H(('bytes32',*k),(D(label),*v))
def raw(k,v): return '0x'+encode(k,v).hex()
def sha(data): return '0x'+hashlib.sha256(data).hexdigest()
def zero(kind): return tuple(zero(k) for k in kind) if isinstance(kind,tuple) else (ZA if kind=='address' else Z if kind=='bytes32' else False if kind=='bool' else 0)


def checkpoint(key,external,*,transaction_id=None,data_root=None,data_size=3,payload_digest=None,content_hash=None):
    cp=(D('ARWEAVE_MAINNET'),b'block',1,D('txroot'),max(99,data_size),transaction_id or D('tx'),
        data_root or D('root'),data_size,0,data_size,80,D('config'))
    record=(key,cp,D('first'),D('last'),b'transaction',b'data',b'last',((A(901),b'certificate'),),90) if external else (
        key,cp,payload_digest or D('payload'),content_hash or D('content'),b'transaction',b'data',((A(901),b'certificate'),),90)
    value={'verifier':A(900),'runtimeHash':D('verifier runtime'),
        'record':raw((w.EXTERNAL_NATIVE if external else w.ARCHIVE_NATIVE,),(record,))}
    digest=H(('address','bytes32','bytes32','bytes'),(value['verifier'],value['runtimeHash'],key,hex_bytes(value['record'])))
    return value,digest


def signed_pair(host,external,artist,content,first,second,object_key=None,data=b'abc'):
    object_key=object_key or D('object' if external else 'envelope')
    receipt_keys=[];receipts=[];fixity_keys=[];fixities=[];hashes=[]
    for i,family in enumerate((first,second)):
        locator=hex_bytes(D('original locator')) if i==0 else b'original locator'+bytes([i])
        r=(object_key,family,K(locator),D('CONTENT_ADDRESSED_INCLUSION' if i==0 else 'ATTESTED_POSSESSION'),
            D('profile'),D('checkpoint') if i==0 else D('proof'),A(800+i),70,i,200)
        label='6529STREAM_EXTERNAL_RECEIPT_V1' if external else '6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1'
        key=DH(label,('uint256','address',w.RECEIPT),(31337,host,r));receipt_keys.append(key)
        body=encode((w.RECEIPT,'bytes','bytes'),(r,locator,b'original signature'))
        receipts.append('0x'+body.hex());hashes.append(H(('bytes32','bytes'),(key,body)))
    for i in range(2):
        locator=hex_bytes(D('original locator')) if i==0 else b'original locator'+bytes([i])
        f=(receipt_keys[i],object_key,(first,second)[i],K(locator),D('profile'),sha(data),sha(data),
            content,content,D('data root'),D('data root'),len(data),len(data),80,1,D('report'),Z,Z,A(820+i),i,200) if external else (
            receipt_keys[i],object_key,(first,second)[i],sha(data),sha(data),len(data),80,1,D('report'),Z,Z,A(820+i),i,200)
        kind=w.EXTERNAL_FIXITY if external else w.ARCHIVE_FIXITY
        label='6529STREAM_EXTERNAL_FIXITY_V1' if external else '6529STREAM_ARCHIVAL_FIXITY_RECORD_V1'
        key=DH(label,('uint256','address',kind),(31337,host,f));fixity_keys.append(key)
        body=encode((kind,'bytes'),(f,b'original fixity signature'));fixities.append('0x'+body.hex())
        hashes.append(H(('bytes32','bytes'),(key,body)))
    native,native_hash=checkpoint(D('checkpoint'),external,transaction_id=D('original locator'),
        data_root=D('data root'),data_size=len(data),payload_digest=sha(data),content_hash=content)
    hashes.append(native_hash)
    return receipt_keys,fixity_keys,receipts,fixities,native,hashes


def item(kind,source,digest=b'',size=0,algorithm=0,canon=Z,uri=''):
    return (kind,D('role'+str(kind)),source,D('source'+str(kind)),1,algorithm,canon,digest,uri,size,Z,Z,Z,Z,Z,Z,D('provenance'))


def supplied():
    roles=(*w.DEPENDENCY_ROLES,'bundleCoverage')
    graph={role:{'address':A(index+1),'runtimeHash':D(role+' runtime')} for index,role in enumerate(roles)}
    context={'chainId':'31337','core':graph['core']['address'],'collectionId':'1','blockNumber':'100',
        'blockHash':D('source block'),'timestamp':'200'}
    d=(tuple(graph[k]['address'] for k in w.DEPENDENCY_ROLES),tuple(graph[k]['runtimeHash'] for k in w.DEPENDENCY_ROLES),31337,50000,500000)
    artist=D('artist');ec=zero(t.ADMISSION[3]);oc=zero(t.ADMISSION[4]);rows=[]
    # Explicit intrinsic applicability, with a distinct repeated occurrence.
    for kind,digest,algo,canon,uri in ((7,b'',0,Z,''),(9,hex_bytes(K(b'')),1,w.RAW,''),
            (11,hashlib.sha256(b'').digest(),2,w.RAW,'empty.txt'),
            (8,hashlib.sha256(b'platform').digest(),2,w.RAW,'C:\\runtime.dll')):
        i=item(kind,graph['metadata']['address'],digest,8 if kind==8 else 0,algo,canon,uri)
        admission=((0,Z,Z),DH('EXPLICIT_INVENTORY_APPLICABILITY',(t.ITEM,),(i,)),Z,ec,oc)
        rows.append({'item':json_values(i),'admission':json_values(admission),'sourceEvidence':None})
    # Retained Artist original state with full STOP bytes.
    payload=b'original Artist authorization';runtime=b'\0'+payload;pointer=A(400)
    i=item(6,graph['artistArchive']['address'],hex_bytes(K(payload)),len(payload),1,w.RAW)
    meta=(K(payload),pointer,len(payload),30)
    parts=H(('address','bytes32','bytes32','address','bytes32','bytes32','uint32','uint64'),
        (i[2],graph['artistArchive']['runtimeHash'],i[3],pointer,K(runtime),*meta[0:1],meta[2],meta[3]))
    admission=((0,Z,Z),DH('STATE_RETAINED_ORIGINAL_AUTHORIZATION',(t.ITEM,'bytes32'),(i,parts)),parts,ec,oc)
    rows.append({'item':json_values(i),'admission':json_values(admission),'sourceEvidence':{
        'payload':'0x'+payload.hex(),'metadata':json_values(meta),'runtime':'0x'+runtime.hex(),
        'sourceRuntimeHash':graph['artistArchive']['runtimeHash']}})
    # External object: declarations/recorded observations only; no fetched bytes.
    host=d[0][4];first,second=D('family one'),D('family two');data=b'abc';content=K(data)
    obj=(artist,Z,w.RAW,content,sha(data),D('data root'),3,Z,Z,Z)
    object_key=DH('6529STREAM_EXTERNAL_OBJECT_V1',('uint256','address','address',w.OBJECT),(31337,host,d[0][0],obj))
    rkeys,fkeys,receipts,fixities,native,hashes=signed_pair(host,True,artist,content,first,second,object_key)
    c=(Z,object_key,artist,content,sha(data),D('data root'),3,first,second,*rkeys,*fkeys,D('checkpoint'),w.EXTERNAL_PROFILE)
    c=(DH('6529STREAM_EXTERNAL_COVERAGE_V1',('uint256','address',t.ADMISSION[3]),(31337,host,c)),*c[1:])
    i=item(5,graph['metadata']['address'],hex_bytes(sha(data)),3,2,w.RAW)
    bundle=H(('address','bytes32',t.ADMISSION[3],('bytes32',)*5),(host,d[1][4],c,tuple(hashes)))
    rows.append({'item':json_values(i),'admission':json_values(((1,c[0],c[1]),bundle,Z,c,oc)),
        'sourceEvidence':{'object':json_values(obj),'receipts':receipts,'fixities':fixities,'checkpoint':native}})
    # Exact whole-object one-chunk archive, including original small-object bundles.
    host=A(500);hostcode=D('archive runtime');rkeys,fkeys,receipts,fixities,native,hashes=signed_pair(host,False,artist,content,first,second)
    ac=(Z,D('envelope'),artist,content,first,second,*rkeys,*fkeys,D('checkpoint'),w.ARCHIVE_PROFILE)
    ac=(DH('6529STREAM_ARCHIVAL_COVERAGE_RECORD_V1',('uint256','address',w.ARCHIVE_COVERAGE),(31337,host,ac)),*ac[1:])
    env=(artist,content,Z,w.RAW,2,sha(data),3,1,D('custody'))
    envraw=encode((w.ENVELOPE,'bytes'),(env,data));hashes.append(K(envraw))
    ab=H(('address','bytes32',w.ARCHIVE_COVERAGE,('bytes32',)*6),(host,hostcode,ac,tuple(hashes)))
    artifact=(artist,Z,w.RAW,1,content,3,(content,),(3,));pointer=A(510);runtime=b'\0'+data
    artifact_key=DH('6529STREAM_FINALITY_ARTIFACT_V1',('uint256','address','address',w.ARTIFACT),
        (31337,d[0][3],d[0][0],artifact))
    c=(D('whole coverage'),artifact_key,artist,Z,w.RAW,content,3,1,first,second,1,D('coverage chain'))
    parts=H(('bytes32','uint32','address','bytes32','bytes32','uint32'),(Z,0,pointer,K(runtime),content,3))
    bundles=H(('bytes32','uint32','bytes32'),(Z,0,ab))
    bundle=H(('address','bytes32',t.ADMISSION[4],w.ARTIFACT,'bytes32','bytes32'),(d[0][3],d[1][3],c,artifact,parts,bundles))
    i=item(10,graph['metadata']['address'],hex_bytes(content),3,1,w.RAW)
    rows.append({'item':json_values(i),'admission':json_values(((2,c[0],c[1]),bundle,parts,ec,c)),
        'sourceEvidence':{'artifact':json_values(artifact),'chunks':[{'pointer':pointer,'runtime':'0x'+runtime.hex(),
            'archive':{'host':host,'runtimeHash':hostcode,'coverage':json_values(ac),'receipts':receipts,
                'fixities':fixities,'checkpoint':native,'envelope':'0x'+envraw.hex()}}]}})
    rows.append(deepcopy(rows[0]))
    value={'profile':w.PROFILE,'dependencies':json_values(d),'dependencyHash':H((t.BUNDLE_DEPENDENCIES,),(d,)),
        'evidence':None,'progress':None,'admissions':rows,
        'sourceBindings':{'blockHash':context['blockHash'],'provenance':'synthetic_fixture',
            'calls':binding_reads(rows,graph)}}
    inventory={'scope':[4,1,0,D('VIEW')],'dependencyHash':D('source inventory deps'),
        'items':[row['item'] for row in rows],'segments':[],'evidence':None,'provenance':'synthetic_fixture'}
    reseal(value,inventory,context,graph)
    return value,context,graph,inventory


def binding_reads(rows,graph):
    calls=[]
    def add(host,signature,address):calls.append({'target':host,'calldata':calldata(signature,(),()),
        'result':'0x'+encode(('address',),(address,)).hex()})
    for row in rows:
        backend=int(row['admission'][0][0]);source=row['sourceEvidence']
        if backend==1:add(graph['externalCoverage']['address'],'checkpointVerifier()',source['checkpoint']['verifier'])
        elif backend==2:
            for chunk in source['chunks']:
                archive=chunk['archive']
                add(graph['coverage']['address'],'archivalCoverage()',archive['host'])
                add(archive['host'],'checkpointVerifier()',archive['checkpoint']['verifier'])
    return calls


def reseal(value,inventory,context,graph):
    scope=w._v(t.SCOPE,inventory['scope']);items=inventory['items'];plan=D('plan');key=D('segment')
    link=Z
    for index in range(len(items)-1,-1,-1):
        link=DH('6529STREAM_PRESERVATION_ITEM_LINK_V1',('bytes32','uint64','uint64','bytes32','bytes32'),
            (key,len(items),index,DH('6529STREAM_PRESERVATION_ITEM_V1',(t.ITEM,),(w._v(t.ITEM,items[index]),)),link))
    segment=(key,len(items),link,D('source witness'));inventory['segments']=[json_values(segment)]
    segment_chain=DH('6529STREAM_PRESERVATION_SEGMENT_V1',('bytes32','uint64',t.SEGMENT),(Z,0,segment))
    body=[plan,1,subject_id('scope','31337',context['core'],'1',scope_type='4',scope_id=scope[3]),D('artist'),(D('original'),)*8,
        D('source context'),D('tokens'),3,1,len(items),segment_chain,Z]
    body[11]=DH('6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1',
        ('uint256','address','bytes32',t.INVENTORY_EVIDENCE),
        (31337,graph['inventory']['address'],inventory['dependencyHash'],(scope,tuple(body))))
    full=(scope,tuple(body));inventory['evidence']=json_values(full);chain=Z
    for index,row in enumerate(value['admissions']):
        chain=DH('6529STREAM_VIEW_PRESERVATION_BUNDLE_COVERED_ITEM_V1',
            ('bytes32','bytes32','uint64','bytes32',t.ADMISSION),
            (chain,plan,index,DH('6529STREAM_PRESERVATION_ITEM_V1',(t.ITEM,),(w._v(t.ITEM,row['item']),)),w._v(t.ADMISSION,row['admission'])))
    e=(scope,(plan,body[11],len(items),chain,Z))
    digest=DH('6529STREAM_VIEW_PRESERVATION_BUNDLE_ARCHIVE_COVERAGE_V1',
        ('uint256','address','bytes32','bytes32',t.INVENTORY_EVIDENCE,t.BUNDLE_EVIDENCE),
        (31337,graph['bundleCoverage']['address'],value['dependencyHash'],w.PROFILE,full,e))
    value['evidence']=json_values((scope,(*e[1][:4],digest)))
    value['progress']=json_values((1,0,len(items),Z,segment_chain,chain,Z,True))


def recommit_original(row,context,graph):
    """Independently rehash retained records without repairing semantic joins."""
    d=tuple(graph[k]['address'] for k in w.DEPENDENCY_ROLES)
    pins=tuple(graph[k]['runtimeHash'] for k in w.DEPENDENCY_ROLES)
    def signed_hashes(source,external):
        hashes=[];rkeys=[];fkeys=[]
        host=source.get('host',d[4])
        for group,kind,receipt in (('receipts',w.RECEIPT,True),
                ('fixities',w.EXTERNAL_FIXITY if external else w.ARCHIVE_FIXITY,False)):
            for body in source[group]:
                raw_=hex_bytes(body);record=decode((kind,'bytes','bytes') if receipt else (kind,'bytes'),raw_,maximum=65536)[0]
                domain=('6529STREAM_EXTERNAL_RECEIPT_V1' if receipt else '6529STREAM_EXTERNAL_FIXITY_V1') if external else (
                    '6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1' if receipt else '6529STREAM_ARCHIVAL_FIXITY_RECORD_V1')
                key=DH(domain,('uint256','address',kind),(int(context['chainId']),host,record))
                (rkeys if receipt else fkeys).append(key);hashes.append(H(('bytes32','bytes'),(key,raw_)))
        cp=source['checkpoint'];native=decode((w.EXTERNAL_NATIVE if external else w.ARCHIVE_NATIVE,),hex_bytes(cp['record']),maximum=65536)[0]
        hashes.append(H(('address','bytes32','bytes32','bytes'),(cp['verifier'],cp['runtimeHash'],native[0],hex_bytes(cp['record']))))
        return rkeys,fkeys,hashes
    source=row['sourceEvidence'];admission=list(w._v(t.ADMISSION,row['admission']))
    if admission[0][0]==1:
        c=list(admission[3]);obj=w._v(w.OBJECT,source['object'])
        c[1]=DH('6529STREAM_EXTERNAL_OBJECT_V1',('uint256','address','address',w.OBJECT),
            (int(context['chainId']),d[4],d[0],obj))
        rkeys,fkeys,hashes=signed_hashes(source,True);c[9:13]=rkeys+fkeys;c[0]=Z
        c[0]=DH('6529STREAM_EXTERNAL_COVERAGE_V1',('uint256','address',t.ADMISSION[3]),
            (int(context['chainId']),d[4],tuple(c)))
        admission[0]=(1,c[0],c[1]);admission[3]=tuple(c)
        admission[1]=H(('address','bytes32',t.ADMISSION[3],('bytes32',)*5),(d[4],pins[4],tuple(c),tuple(hashes)))
    else:
        a=w._v(w.ARTIFACT,source['artifact']);c=list(admission[4]);part_chain=bundle_chain=Z
        c[1]=DH('6529STREAM_FINALITY_ARTIFACT_V1',('uint256','address','address',w.ARTIFACT),
            (int(context['chainId']),d[3],d[0],a))
        for index,chunk in enumerate(source['chunks']):
            ar=chunk['archive'];ac=list(w._v(w.ARCHIVE_COVERAGE,ar['coverage']))
            rkeys,fkeys,hashes=signed_hashes(ar,False);ac[6:10]=rkeys+fkeys;ac[0]=Z
            ac[0]=DH('6529STREAM_ARCHIVAL_COVERAGE_RECORD_V1',('uint256','address',w.ARCHIVE_COVERAGE),
                (int(context['chainId']),ar['host'],tuple(ac)))
            ar['coverage']=json_values(ac);hashes.append(K(hex_bytes(ar['envelope'])))
            original=H(('address','bytes32',w.ARCHIVE_COVERAGE,('bytes32',)*6),
                (ar['host'],ar['runtimeHash'],tuple(ac),tuple(hashes)))
            runtime=hex_bytes(chunk['runtime'])
            part_chain=H(('bytes32','uint32','address','bytes32','bytes32','uint32'),
                (part_chain,index,chunk['pointer'],K(runtime),a[6][index],a[7][index]))
            bundle_chain=H(('bytes32','uint32','bytes32'),(bundle_chain,index,original))
        admission[0]=(2,c[0],c[1]);admission[4]=tuple(c);admission[2]=part_chain
        admission[1]=H(('address','bytes32',t.ADMISSION[4],w.ARTIFACT,'bytes32','bytes32'),
            (d[3],pins[3],tuple(c),a,part_chain,bundle_chain))
    row['admission']=json_values(admission)


class ViewPreservationBundleTests(unittest.TestCase):
    def test_rehashed_checkpoint_must_describe_original_locator_and_object(self):
        for index,field in ((5,'transaction'),(5,'root'),(5,'size'),(5,'first'),(5,'last'),
                (5,'network'),(6,'transaction'),(6,'size'),(6,'digest'),(6,'content')):
            value,c,g,i=supplied();row=value['admissions'][index]
            source=row['sourceEvidence'] if index==5 else row['sourceEvidence']['chunks'][0]['archive']
            kind=w.EXTERNAL_NATIVE if index==5 else w.ARCHIVE_NATIVE
            record=list(decode((kind,),hex_bytes(source['checkpoint']['record']),maximum=65536)[0])
            cp=list(record[1])
            if field=='transaction':cp[5]=D('wrong transaction')
            elif field=='root':cp[6]=D('wrong data root')
            elif field=='size':cp[7]+=1
            elif field=='network':cp[0]=D('wrong network')
            elif field in ('first','last'):record[2 if field=='first' else 3]=Z
            else:record[2 if field=='digest' else 3]=D('wrong original bytes')
            record[1]=tuple(cp);source['checkpoint']['record']=raw((kind,),(tuple(record),))
            recommit_original(row,c,g);reseal(value,i,c,g)
            with self.subTest(index=index,field=field),self.assertRaisesRegex(MuseumError,'checkpoint .*correspondence'):
                w.validate(value,c,g,i)

    def test_coverage_profile_and_two_distinct_nonzero_families(self):
        for kind,change in (('external','profile'),('external','zero'),('external','same'),
                ('archive','profile'),('whole','zero'),('whole','same')):
            value,c,g,i=supplied();row=value['admissions'][5 if kind=='external' else 6]
            if kind=='archive':
                row['sourceEvidence']['chunks'][0]['archive']['coverage'][11]=D('unrelated profile')
            else:
                cov=row['admission'][3 if kind=='external' else 4];first=7 if kind=='external' else 8
                if change=='profile':cov[14]=D('unrelated profile')
                else:cov[first+1]=Z if change=='zero' else cov[first]
            recommit_original(row,c,g);reseal(value,i,c,g)
            with self.subTest(kind=kind,change=change),self.assertRaisesRegex(MuseumError,'original .*coverage'):
                w.validate(value,c,g,i)

    def test_consumer_gas_bound_is_exact_and_not_a_native_maximum_claim(self):
        for gas,accepted in ((64000000,True),(64000001,False)):
            value,c,g,i=supplied();value['dependencies'][3:5]=[str(gas),str(gas)]
            value['dependencyHash']=H((t.BUNDLE_DEPENDENCIES,),(w._v(t.BUNDLE_DEPENDENCIES,value['dependencies']),))
            reseal(value,i,c,g)
            if accepted:self.assertTrue(w.validate(value,c,g,i)['originalAdmissionPreimagesChecked'])
            else:
                with self.assertRaisesRegex(MuseumError,'dependency/profile'):w.validate(value,c,g,i)

    def test_exact_original_dependency_getter_evidence_is_mandatory(self):
        for change in ('absent','hash','provenance','result','order','omitted'):
            value,c,g,i=supplied()
            if change=='absent':value.pop('sourceBindings')
            elif change=='hash':value['sourceBindings']['blockHash']=D('other block')
            elif change=='provenance':value['sourceBindings']['provenance']='externally_admitted_rpc'
            elif change=='result':value['sourceBindings']['calls'][0]['result']='0x'+encode(('address',),(A(999),)).hex()
            elif change=='order':value['sourceBindings']['calls'].reverse()
            else:value['sourceBindings']['calls'].pop()
            with self.subTest(change=change),self.assertRaisesRegex(MuseumError,'evidence shape|dependency getter evidence'):
                w.validate(value,c,g,i)

    def test_recommitted_positive_original_hashes_are_independent_of_validator(self):
        value,c,g,i=supplied()
        for index in (5,6):
            before=deepcopy(value['admissions'][index]);recommit_original(value['admissions'][index],c,g)
            self.assertEqual(before,value['admissions'][index])
        self.assertTrue(w.validate(value,c,g,i)['originalAdmissionPreimagesChecked'])

    def test_rehashed_artifact_cannot_claim_unrelated_whole_bytes(self):
        value,c,g,i=supplied();row=value['admissions'][6]
        fake=K(b'abd');row['sourceEvidence']['artifact'][4]=fake;row['admission'][4][5]=fake
        row['item'][7]='0x'+hex_bytes(fake).hex();i['items'][6]=deepcopy(row['item'])
        recommit_original(row,c,g);reseal(value,i,c,g)
        with self.assertRaisesRegex(MuseumError,'whole artifact bytes'):w.validate(value,c,g,i)

    def test_rehashed_artifact_schema_or_canonicalization_must_match_original_coverage(self):
        for index in (1,2):
            value,c,g,i=supplied();row=value['admissions'][6]
            row['sourceEvidence']['artifact'][index]=D('different schema/canon')
            recommit_original(row,c,g);reseal(value,i,c,g)
            with self.assertRaisesRegex(MuseumError,'complete original artifact'):w.validate(value,c,g,i)

    def test_original_external_and_artifact_identifiers_are_not_arbitrary_labels(self):
        for index,field in ((5,0),(5,1),(6,1)):
            value,c,g,i=supplied();row=value['admissions'][index]
            slot=3 if index==5 else 4
            row['admission'][slot][field]=D('arbitrary label');row['admission'][0][1+field]=D('arbitrary label')
            reseal(value,i,c,g)
            with self.assertRaisesRegex(MuseumError,'identity/coverage hash|artifact hash'):w.validate(value,c,g,i)

    def test_rehashed_signed_originals_cannot_change_object_family_or_fixity_result(self):
        for index,group,field in ((5,'receipts',0),(5,'receipts',1),(5,'fixities',1),(5,'fixities',2),
                (5,'fixities',3),(5,'fixities',6),(5,'fixities',14),(6,'receipts',0),(6,'receipts',1),
                (6,'fixities',1),(6,'fixities',2),(6,'fixities',4),(6,'fixities',7)):
            value,c,g,i=supplied();row=value['admissions'][index]
            original=row['sourceEvidence'] if index==5 else row['sourceEvidence']['chunks'][0]['archive']
            receipt=group=='receipts';kind=w.RECEIPT if receipt else w.EXTERNAL_FIXITY if index==5 else w.ARCHIVE_FIXITY
            layout=(kind,'bytes','bytes') if receipt else (kind,'bytes')
            decoded=list(decode(layout,hex_bytes(original[group][0]),maximum=65536));record=list(decoded[0])
            record[field]=2 if (not receipt and field in (7,14)) else D('contradictory original')
            decoded[0]=tuple(record);original[group][0]=raw(layout,tuple(decoded))
            recommit_original(row,c,g);reseal(value,i,c,g)
            with self.subTest(index=index,group=group,field=field),self.assertRaisesRegex(MuseumError,'signed record correspondence'):
                w.validate(value,c,g,i)

    def test_all_native_admission_branches_and_repeated_occurrence(self):
        value,c,g,i=supplied();result=w.validate(value,c,g,i)
        self.assertEqual(result['itemCount'],'8')
        self.assertEqual(result['bundleCoverageHash'],value['evidence'][1][4])
        self.assertTrue(result['originalAdmissionPreimagesChecked'])
        self.assertEqual(result['coverageTrust'],'retained_native_admission_observations')
        for key in ('currentLivenessVerified','nativeExecutionProven','historicalSignaturesVerified','archiveConsensusVerified'):
            self.assertFalse(result[key])

    def test_source_inventory_cannot_be_omitted_or_replaced(self):
        value,c,g,i=supplied()
        for bad in (None,{}, {'scope':i['scope']}, {**i,'dependencyHash':D('wrong')}, {**i,'items':i['items'][:-1]}):
            with self.assertRaises(MuseumError):w.validate(value,c,g,bad)
        i['items'][0],i['items'][1]=i['items'][1],i['items'][0]
        with self.assertRaises(MuseumError):w.validate(value,c,g,i)

    def test_original_source_evidence_is_required_for_every_nonintrinsic_row(self):
        for index in (4,5,6):
            value,c,g,i=supplied();value['admissions'][index]['sourceEvidence']=None
            with self.subTest(index=index),self.assertRaises(MuseumError):w.validate(value,c,g,i)

    def test_rehashed_outer_coverage_cannot_hide_original_bundle_change(self):
        for index in (4,5,6):
            value,c,g,i=supplied();value['admissions'][index]['admission'][1]=D('fake original bundle')
            reseal(value,i,c,g)
            with self.subTest(index=index),self.assertRaisesRegex(MuseumError,'admission preimage'):
                w.validate(value,c,g,i)

    def test_exact_closed_view_profile_domain_and_source_scope(self):
        for change in ('profile','chain','host','scope'):
            value,c,g,i=supplied()
            if change=='profile':value['profile']=D('6529STREAM_SCOPED_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1')
            elif change=='chain':c['chainId']='1'
            elif change=='host':g['bundleCoverage']['address']=A(990)
            else:i['scope'][0]=2
            with self.subTest(change=change),self.assertRaises(MuseumError):w.validate(value,c,g,i)

    def test_state_payload_pointer_runtime_and_metadata_commitments(self):
        for field in ('payload','runtime','metadata','sourceRuntimeHash'):
            value,c,g,i=supplied();s=value['admissions'][4]['sourceEvidence']
            if field=='metadata':s[field][3]='0'
            elif field=='sourceRuntimeHash':s[field]=D('wrong runtime')
            else:s[field]='0x00'
            with self.subTest(field=field),self.assertRaises(MuseumError):w.validate(value,c,g,i)

    def test_original_external_signed_bytes_and_checkpoint_required(self):
        for field in ('receipts','fixities','checkpoint'):
            value,c,g,i=supplied();s=value['admissions'][5]['sourceEvidence']
            if field=='checkpoint':s[field]['record']='0x00'
            else:s[field][0]='0x00'
            with self.subTest(field=field),self.assertRaises(MuseumError):w.validate(value,c,g,i)

    def test_onchain_full_stop_bytes_archive_envelope_and_original_bundle(self):
        for mode in ('runtime','envelope','signature','missing_chunk','artifact'):
            value,c,g,i=supplied();s=value['admissions'][6]['sourceEvidence']
            if mode=='missing_chunk':s['chunks']=[]
            elif mode=='artifact':s['artifact'][7][0]='2'
            elif mode=='runtime':s['chunks'][0]['runtime']='0x00616264'
            elif mode=='envelope':s['chunks'][0]['archive']['envelope']='0x00'
            else:s['chunks'][0]['archive']['receipts'][0]+='00'
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.validate(value,c,g,i)

    def test_rehashed_proof_backend_and_intrinsic_fields_reject(self):
        for index in (0,4,5,6):
            value,c,g,i=supplied();value['admissions'][index]['admission'][0][0]='3'
            reseal(value,i,c,g)
            with self.subTest(index=index),self.assertRaises(MuseumError):w.validate(value,c,g,i)

    def test_complete_progress_and_admission_denominator(self):
        for mode in ('progress','missing','extra','swapped'):
            value,c,g,i=supplied()
            if mode=='progress':value['progress'][7]=False
            elif mode=='missing':value['admissions'].pop()
            elif mode=='extra':value['admissions'].append(deepcopy(value['admissions'][-1]))
            else:value['admissions'][0],value['admissions'][1]=value['admissions'][1],value['admissions'][0]
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.validate(value,c,g,i)

    def test_current_environment_is_not_invented_from_original_completion(self):
        value,c,g,i=supplied();value['progress'][6]=D('retained original environment')
        self.assertFalse(w.validate(value,c,g,i)['currentLivenessVerified'])
        d=w._v(t.BUNDLE_DEPENDENCIES,value['dependencies'])
        expected=DH('6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1',
            (t.BUNDLE_DEPENDENCIES,'bytes32','uint64','bytes32','uint64'),(d,D('onchain'),1,D('external'),0))
        self.assertEqual(w.environment_hash(d,D('onchain'),1,D('external'),0),expected)
        self.assertNotEqual(w.refresh_id(D('plan'),expected,value['dependencyHash'],'31337',g['bundleCoverage']['address']),
                            w.refresh_id(D('plan'),D('later'),value['dependencyHash'],'31337',g['bundleCoverage']['address']))

    def test_runtime_alias_and_closed_original_shapes(self):
        value,c,g,i=supplied();s=value['admissions'][6]['sourceEvidence']['chunks'][0]['archive']
        s['checkpoint']['verifier']=s['host']
        with self.assertRaisesRegex(MuseumError,'runtime conflict'):w.validate(value,c,g,i)
        value,c,g,i=supplied();value['admissions'][5]['sourceEvidence']['currentPair']={}
        with self.assertRaises(MuseumError):w.validate(value,c,g,i)


class FullInventoryBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from .view_preservation_bundle_fixture_v1 import supplied as complete
        cls.original=complete()

    def test_complete_source_inventory_bundle_and_actual_offline_cli(self):
        from . import view_preservation_inventory_v1 as consumer
        inventory,bundle,context,graph=deepcopy(self.original)
        raw_=dumps({'profileHash':consumer.PROFILE_HASH,'inventory':inventory,'bundle':bundle,
            'context':context,'graph':graph})
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            report=consumer.verify(raw_)
        self.assertEqual(report['inventory']['itemCount'],report['bundle']['itemCount'])
        self.assertEqual(report['bundle']['bundleCoverageHash'],bundle['evidence'][1][4])
        self.assertTrue(report['inventory']['claims']['completeTwelveStageInventoryChecked'])
        self.assertEqual(report['bundle']['sourceProvenance'],'synthetic_fixture')
        self.assertFalse(report['bundle']['archiveConsensusVerified'])
        self.assertFalse(report['bundle']['currentLivenessVerified'])
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'originals.json';path.write_bytes(raw_)
            # Run the actual module entrypoint with sockets disabled in the child.
            command='import socket,runpy,ssl; socket.socket=lambda *a,**k: (_ for _ in ()).throw(AssertionError("network forbidden")); runpy.run_module("tools.museum.view_preservation_inventory_v1",run_name="__main__")'
            result=subprocess.run([sys.executable,'-c',command,'verify',str(path)],
                capture_output=True,timeout=30,check=False)
            self.assertEqual(result.returncode,0,result.stderr.decode('utf-8'))
            self.assertEqual(result.stdout.strip(),dumps(report))
            self.assertEqual(path.read_bytes(),raw_)

    def test_rehashed_bundle_cannot_replace_verified_inventory_occurrence(self):
        from . import view_preservation_inventory_v1 as consumer
        from . import view_preservation_inventory_wire_v1 as inventory_wire
        inventory,bundle,context,graph=deepcopy(self.original)
        verified=inventory_wire.validate(inventory,context,graph)
        row=next(row for row in bundle['admissions'] if int(row['item'][0])==7)
        row['item'][16]=D('other original provenance')
        row['admission'][1]=DH('EXPLICIT_INVENTORY_APPLICABILITY',(t.ITEM,),(w._v(t.ITEM,row['item']),))
        body=verified['evidence'][1];chain=Z
        for index,admitted in enumerate(bundle['admissions']):
            chain=w.covered_item(chain,body[0],index,admitted['item'],admitted['admission'])
        bundle['progress'][5]=chain;bundle['evidence'][1][3]=chain
        bundle['evidence'][1][4]=w.coverage_hash(bundle['evidence'],verified['evidence'],
            bundle['dependencies'],context['chainId'],graph['bundleCoverage']['address'])
        raw_=dumps({'profileHash':consumer.PROFILE_HASH,'inventory':inventory,'bundle':bundle,
            'context':context,'graph':graph})
        with self.assertRaisesRegex(MuseumError,'original item occurrence differs'):consumer.verify(raw_)


if __name__=='__main__':unittest.main()
