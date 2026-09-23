"""Complete original conservation captures and admitted archival preimages."""
from copy import deepcopy
import base64
import hashlib
import unittest
from unittest.mock import patch
from blake3 import blake3

from . import conservation_archive_v1 as w
from . import conservation_dossier_v1 as dossier
from . import view_preservation_bundle_wire_v1 as archive
from .canonical import MuseumError, dumps, hex_bytes, keccak256 as K, loads, schema_id as H
from .chain_abi import decode, encode
from .independent_wire import ZERO as Z, json_values
from .test_conservation_dossier_v1 import captured, fixtures
from .test_public_conservation_source import PublicConservationFixture, conservation, conservation_profile, DOCUMENT_FACTS
from .test_view_preservation_bundle_wire_v1 import A, checkpoint, zero, recommit_original


def material_digest(raw, algorithm):
    if algorithm==1:return K(raw)
    if algorithm==2:return '0x'+hashlib.sha256(raw).hexdigest()
    if algorithm==3:return '0x'+blake3(raw).hexdigest()
    if algorithm==4:return '0x'+(b'\x12\x20'+hashlib.sha256(raw).digest()).hex()
    if algorithm==5:return '0x'+(b'\x01\x55\x12\x20'+hashlib.sha256(raw).digest()).hex()
    if algorithm==6:return H('transaction '+K(raw))
    raise ValueError('fixture algorithm')


class MaterialFixture(PublicConservationFixture):
    def __init__(self, *, algorithm=1, fixture_kind='written', canonicalization=archive.RAW,
            material_size=0,parent_algorithm=None,parent_mismatch=False,opaque=False):
        self.materials = {}; self.algorithm = algorithm; self.canonicalization=canonicalization
        self.material_size=material_size;self.parent_algorithm=parent_algorithm;self.parent_mismatch=parent_mismatch
        self.opaque=opaque
        super().__init__(empty=True)
        interview = self.append_interview(block=1,catalog=fixture_kind=='av')
        self.append_intent(block=2, interview=interview,origin=1 if fixture_kind=='av' else 0)
        self.update_heads()

    def _materialize(self, value):
        def replace(node, path=()):
            if isinstance(node, dict):
                if set(node) == {'hash','uri'}:
                    if path == ('interview','payload'): return
                    if node['hash']['digest'] in self.materials: return
                    raw = dumps({'original': '/'.join(map(str,path)), 'statement': 'x'*self.material_size or 'exact original reference'})
                    digest = material_digest(raw,self.algorithm)
                    if self.opaque:digest='0x'+b'opaque'.hex()+hex_bytes(K(raw)).hex()
                    node['hash'] = {'algorithm':self.algorithm,'canonicalizationId':self.canonicalization,'digest':digest}
                    self.materials[digest] = raw
                else:
                    for key, item in node.items(): replace(item,path+(key,))
            elif isinstance(node,list):
                for i,item in enumerate(node): replace(item,path+(i,))
        replace(value)

    def _add_original(self, value, kind, scope, origin, block, **kwargs):
        value = deepcopy(value);self._materialize(value)
        if kind==0 and self.parent_algorithm is not None:
            reference=value['interview']['payload'];raw=self.materials[reference['hash']['digest']]
            if self.parent_mismatch:raw=dumps({'different':'fully archived but not the actual original interview'})
            digest=material_digest(raw,self.parent_algorithm);self.materials[digest]=raw
            reference['hash'].update(algorithm=self.parent_algorithm,digest=digest)
        row = super()._add_original(value,kind,scope,origin,block,**kwargs)
        self.materials[K(row['payload'])] = row['payload']
        # Transaction IDs can intentionally repeat only for the same bytes.
        return row

    def append_interview(self, scope='collection', *, origin=0, block=1, catalog=False):
        if not catalog: return super().append_interview(scope,origin=origin,block=block)
        examples=conservation_profile.examples();document=deepcopy(examples['format-catalog.json'])
        self._materialize(document);raw=dumps(document);name='CONSERVATION_EXAMPLE_FORMATS_V1';key=H(name)
        value=deepcopy(examples['interview-derivative-av.json'])
        value.update(subjectId=self.subject(scope),profileHash=K(conservation.DEFINITIONS[
            conservation_profile.PROFILES[conservation_profile.INTERVIEW]]),predecessor=None)
        def formats(node):
            if isinstance(node,dict):
                if node.get('kind')=='catalog' and 'formatId' in node:
                    node['catalog']['documentHash']=K(raw)
                    node['mapping']=deepcopy(next(e['mapping'] for e in document['entries'] if e['entryId']==node['formatId']))
                for item in node.values():formats(item)
            elif isinstance(node,list):
                for item in node:formats(item)
        formats(value)
        original=self._add_original(value,2,scope,origin,block)
        chunks=[self.chunk(raw[i:i+8192]) for i in range(0,len(raw),8192)]
        facts=(True,2,0,K(raw),conservation.JCS_ID,Z,len(raw),len(chunks),K(b'synthetic catalog registration'))
        self.add(A(3),'documentFacts(bytes32)',('bytes32',),(key,),(DOCUMENT_FACTS,),(facts,))
        for index,digest in enumerate(chunks):
            self.add(A(3),'documentChunkHashAt(bytes32,uint256)',('bytes32','uint256'),(key,index),('bytes32',),(digest,))
        original['catalogPins']=[(key,K(raw),len(raw)),(key,K(raw),len(raw))]
        return original

    def append_intent(self, scope='collection', **kwargs):
        original=super().append_intent(scope,**kwargs)
        if self.parent_algorithm is not None:
            value=loads(original['payload']);reference=value['interview']['payload'];h=reference['hash']
            row=list(original['selection']);row[5]=K(encode((conservation.REFERENCE,),
                ((h['algorithm'],h['canonicalizationId'],hex_bytes(h['digest']),reference['uri']),)))
            row[6]=h['algorithm'] if h['algorithm'] in (1,2) else 0
            row[12]=conservation.selection_hash(self.a,self.subject(scope),tuple(row))
            original['selection']=tuple(row);self.selections[(scope,kwargs.get('origin',0))][-1]=tuple(row)
            for receipt in self.receipts.values():
                for log in receipt['logs']:
                    if log['topics'][0]==conservation.SELECTED_EVENT and log['topics'][3]==original['recordHash']:
                        log['data']='0x'+encode((conservation.SELECTION,),(tuple(row),)).hex()
        return original


def signed_pair(host,external,artist,content,first,second,object_key=None,data=b'abc'):
    object_key=object_key or H('envelope '+content);cpkey=H('checkpoint '+content)
    receipts=[];fixities=[];rkeys=[];fkeys=[];hashes=[]
    sha='0x'+hashlib.sha256(data).hexdigest();root=H('data root '+content)
    for i,family in enumerate((first,second)):
        locator=hex_bytes(H('transaction '+content)) if i==0 else (
            b'https://archive.invalid/'+content.encode() if external else b'\x01\x55\x12\x20'+hex_bytes(sha))
        record=(object_key,family,K(locator),H('CONTENT_ADDRESSED_INCLUSION' if i==0 else 'ATTESTED_POSSESSION'),
            H('profile'),cpkey if i==0 else H('proof'),A(800+i),70,i,200)
        if i==1:
            record=(*record[:4],H('STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1' if external
                else '6529STREAM_RAW_CID_SHA256_POSSESSION_V1'),*record[5:])
            kinds=('uint256','address','bytes32','bytes32','bytes32')
            values=(31337,host,object_key,family,K(locator))
            if external:kinds+=('bytes32',);values+=(record[4],)
            possession=archive._domain('6529STREAM_EXTERNAL_OBJECT_POSSESSION_V1' if external else '6529STREAM_ARCHIVAL_POSSESSION_V1',
                (*kinds,'address','uint64'),(*values,record[6],record[7]))
            record=(*record[:5],possession,*record[6:])
        key=archive._domain('6529STREAM_EXTERNAL_RECEIPT_V1' if external else '6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1',
            ('uint256','address',archive.RECEIPT),(31337,host,record))
        body=encode((archive.RECEIPT,'bytes','bytes'),(record,locator,b'original signature'))
        receipts.append('0x'+body.hex());rkeys.append(key);hashes.append(archive._hash(('bytes32','bytes'),(key,body)))
    for i in range(2):
        r=decode((archive.RECEIPT,'bytes','bytes'),hex_bytes(receipts[i]))[0]
        f=(rkeys[i],object_key,(first,second)[i],r[2],H('STREAM_EXTERNAL_OBJECT_FIXITY_V1'),sha,sha,content,content,root,root,
            len(data),len(data),80,1,H('report'),Z,Z,A(820+i),i,200) if external else (
            rkeys[i],object_key,(first,second)[i],sha,sha,len(data),80,1,H('report'),Z,Z,A(820+i),i,200)
        kind=archive.EXTERNAL_FIXITY if external else archive.ARCHIVE_FIXITY
        key=archive._domain('6529STREAM_EXTERNAL_FIXITY_V1' if external else '6529STREAM_ARCHIVAL_FIXITY_RECORD_V1',
            ('uint256','address',kind),(31337,host,f))
        body=encode((kind,'bytes'),(f,b'original fixity signature'))
        fixities.append('0x'+body.hex());fkeys.append(key);hashes.append(archive._hash(('bytes32','bytes'),(key,body)))
    native,nativehash=checkpoint(cpkey,external,transaction_id=H('transaction '+content),data_root=root,
        data_size=len(data),payload_digest=sha,content_hash=content)
    hashes.append(nativehash)
    return rkeys,fkeys,receipts,fixities,native,hashes


def _proof(data, canon, artist, graph, *, backend, form=None, schema=Z):
    first, second = H('original family one'), H('original family two')
    content = K(data); sha = '0x'+hashlib.sha256(data).hexdigest()
    if backend == 'external':
        host = graph['externalCoverage']['address']
        catalog = form.get('catalog') if form else None
        obj = (artist,schema if schema!=Z else H('original media schema'),canon,content,sha,H('data root '+content),
            len(data),form['formatId'] if form else H('original media format'),
            catalog['documentId'] if catalog else H('archive independent catalog'),
            catalog['documentHash'] if catalog else H('archive independent catalog content'))
        object_key = archive.external_object_hash(obj,31337,host,A(2))
        r,f,receipts,fixities,native,hashes = signed_pair(host,True,artist,content,first,second,object_key,data)
        c = (Z,object_key,artist,content,sha,H('data root '+content),len(data),first,second,*r,*f,H('checkpoint '+content),archive.EXTERNAL_PROFILE)
        c = (archive.external_coverage_hash(c,31337,host),*c[1:])
        original = archive._hash(('address','bytes32',archive.t.ADMISSION[3],('bytes32',)*5),
            (host,graph['externalCoverage']['runtimeHash'],c,tuple(hashes)))
        return {'backend':backend,'coverage':json_values(c),'sourceEvidence':{'object':json_values(obj),
            'receipts':receipts,'fixities':fixities,'checkpoint':native},'originalBundleHash':original,'partsHash':Z}
    host = A(62000); runtime = H('original archival runtime');chunks=[];archives=[]
    pieces=[data[i:i+8192] for i in range(0,len(data),8192)]
    for part in pieces:
        digest=K(part);pointer='0x'+digest[-40:];code=b'\0'+part
        env=(artist,digest,w.CHUNK_SCHEMA,w.BINARY,2,'0x'+hashlib.sha256(part).hexdigest(),len(part),1,Z)
        envelope_hash=archive._domain('6529STREAM_ARCHIVAL_CHUNK_ENVELOPE_V1',
            ('uint256','address',archive.ENVELOPE,'address','bytes32'),(31337,host,env,pointer,K(code)))
        r,f,receipts,fixities,native,hashes=signed_pair(host,False,artist,digest,first,second,object_key=envelope_hash,data=part)
        ac=(Z,envelope_hash,artist,digest,first,second,*r,*f,H('checkpoint '+digest),archive.ARCHIVE_PROFILE)
        ac=(archive.archive_coverage_hash(ac,31337,host),*ac[1:])
        envraw=encode((archive.ENVELOPE,'bytes'),(env,part));hashes.append(K(envraw))
        ab=archive._hash(('address','bytes32',archive.ARCHIVE_COVERAGE,('bytes32',)*6),(host,runtime,ac,tuple(hashes)))
        archives.append((ac,ab))
        chunks.append({'pointer':pointer,'runtime':'0x'+code.hex(),'archive':{'host':host,'runtimeHash':runtime,
            'coverage':json_values(ac),'receipts':receipts,'fixities':fixities,'checkpoint':native,
            'envelope':'0x'+envraw.hex(),'envelopePointer':{'address':pointer,'runtimeHash':K(code)}}})
    artifact = (artist,schema if schema!=Z else H('original media schema'),canon,1,content,len(data),
        tuple(K(part) for part in pieces),tuple(map(len,pieces)))
    artifact_hash = archive.artifact_hash(artifact,31337,graph['coverage']['address'],A(2))
    environment=H('original archive environment')
    plan_hash=archive._domain('6529STREAM_FINALITY_ARTIFACT_COVERAGE_PLAN_V1',
        ('uint256','address','bytes32','bytes32','bytes32','bytes32','uint64'),
        (31337,graph['coverage']['address'],artifact_hash,first,second,environment,1))
    chain=archive._domain('6529STREAM_FINALITY_ARTIFACT_COVERAGE_CHAIN_V1',('bytes32',),(plan_hash,))
    parts=bundles=Z
    for index,(chunk,part,(ac,ab)) in enumerate(zip(chunks,pieces,archives)):
        pointer=chunk['pointer'];code=hex_bytes(chunk['runtime']);digest=K(part)
        chain=archive._domain('6529STREAM_FINALITY_ARTIFACT_COVERED_PART_V1',
            ('bytes32','bytes32','uint32','bytes32','uint32','address','bytes32',archive.ARCHIVE_COVERAGE),
            (chain,plan_hash,index,digest,len(part),pointer,K(code),ac))
        parts=archive._hash(('bytes32','uint32','address','bytes32','bytes32','uint32'),
            (parts,index,pointer,K(code),digest,len(part)))
        bundles=archive._hash(('bytes32','uint32','bytes32'),(bundles,index,ab))
    completion=archive._domain('6529STREAM_FINALITY_ARTIFACT_COVERAGE_COMPLETE_V1',
        ('bytes32','bytes32','uint64','bytes32','uint32'),(plan_hash,artifact_hash,1,chain,len(pieces)))
    c = (completion,artifact_hash,artist,artifact[1],canon,content,len(data),len(pieces),first,second,1,chain)
    plan=(artifact_hash,first,second,environment,1,len(pieces),chain,completion)
    original = archive._hash(('address','bytes32',archive.t.ADMISSION[4],archive.ARTIFACT,'bytes32','bytes32'),
        (graph['coverage']['address'],graph['coverage']['runtimeHash'],c,artifact,parts,bundles))
    return {'backend':backend,'coverage':json_values(c),'sourceEvidence':{'artifact':json_values(artifact),
        'planHash':plan_hash,'plan':json_values(plan),
        'chunks':chunks},
        'originalBundleHash':original,'partsHash':parts}


def bind_reads(files, envelope, materials):
    snapshot, doc, occurrences, transcript = w._load(files)
    originals = w._Originals(snapshot,transcript,envelope['graph'])
    for row, occurrence in zip(envelope['occurrences'],occurrences):
        if row['archive'] is None: continue
        artists, form, original = w._reference_context(doc,occurrence)
        raw = materials[row['materialPath']]; p = row['archive']
        if p['backend'] == 'external':
            w._external(p,raw,occurrence['hash']['canonicalizationId'],artists,form,
                original if occurrence['relation'] == 'interview_payload' else None,originals,envelope['graph'])
        else: w._onchain(p,raw,occurrence['hash']['canonicalizationId'],artists,originals,envelope['graph'])
    envelope['sourceBindings']['calls'] = originals.calls
    return dumps(envelope)


def complete_case(backend='external', *, algorithm=1, fixture_kind='written', canonicalization=archive.RAW,
        material_size=0,parent_algorithm=None,parent_mismatch=False,check=True,opaque=False):
    f = MaterialFixture(algorithm=algorithm,fixture_kind=fixture_kind,canonicalization=canonicalization,
        material_size=material_size,parent_algorithm=parent_algorithm,parent_mismatch=parent_mismatch,opaque=opaque)
    captured_source,_ = captured(f)
    result = dossier.build(dict(captured_source.files),captured_source.manifest_hash,disclosure='public')
    files = dict(result.files); envelope = loads(w.template(files),maximum=w.MAX_BYTES)
    envelope['graph'] = {role:{'address':A(61000+i),'runtimeHash':H(role+' original runtime')}
        for i,role in enumerate(('externalCoverage','coverage'))}
    _,doc,occurrences,_ = w._load(files); materials = {}
    for row,occurrence in zip(envelope['occurrences'],occurrences):
        data = f.materials[occurrence['hash']['digest']]
        path = 'materials/'+K(data)[2:]+'.bin'; materials[path]=data
        artists,form,original = w._reference_context(doc,occurrence)
        schema = original['semantic']['interview']['record']['schemaId'] if occurrence['relation']=='interview_payload' else Z
        row.update(materialPath=path,archive=_proof(data,occurrence['hash']['canonicalizationId'],artists[0],
            envelope['graph'],backend=backend,form=form,schema=schema))
    raw = bind_reads(files,envelope,materials)
    if check:w.verify(files,raw,K(raw),materials)
    return result,raw,materials


def reseal(row,context,graph):
    p = row['archive']; backend = p['backend']; c = p['coverage']
    expanded = {role:{'address':A(63000+i),'runtimeHash':H(role)} for i,role in enumerate(archive.DEPENDENCY_ROLES)}
    expanded.update(graph);expanded['core']['address']=context['core']
    admission = ((1 if backend=='external' else 2,c[0],c[1]),p['originalBundleHash'],p['partsHash'],
        archive._v(archive.t.ADMISSION[3],c) if backend=='external' else zero(archive.t.ADMISSION[3]),
        archive._v(archive.t.ADMISSION[4],c) if backend=='onchain' else zero(archive.t.ADMISSION[4]))
    intermediate={'admission':json_values(admission),'sourceEvidence':p['sourceEvidence']}
    recommit_original(intermediate,context,expanded)
    a=intermediate['admission'];p.update(coverage=a[3 if backend=='external' else 4],originalBundleHash=a[1],partsHash=a[2])


class ConservationArchiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.external=complete_case();cls.onchain=complete_case('onchain')

    def test_complete_external_and_onchain_replay_exact_original_occurrences(self):
        for package,raw,materials in (self.external,self.onchain):
            with patch('socket.socket',side_effect=AssertionError('offline evidence only')):
                files=w.verify(dict(package.files),raw,K(raw),materials)
            report=w.require_complete(files)
            self.assertGreater(int(report['occurrenceCount']),10)
            rows=loads(files[w.OUTPUTS[1]],maximum=w.MAX_BYTES)['occurrences']
            self.assertTrue(all(r['originalHashRefChecked'] and r['archive'] for r in rows))
            self.assertTrue(all(r['status']=='complete' for r in rows))
            self.assertTrue(all(report['claims'][k] is False for k in ('archiveDeliveryProven','currentAvailabilityProven',
                'historicalSignaturesVerified','archiveConsensusVerified','completeM10Proven')))

    def test_no_materials_keeps_entire_av_catalog_denominator_and_refuses_complete(self):
        cap,_=captured(fixtures()['av']);package=dossier.build(dict(cap.files),cap.manifest_hash,disclosure='public')
        files=w.verify(dict(package.files));rows=loads(files[w.OUTPUTS[1]],maximum=w.MAX_BYTES)['occurrences']
        original=loads(dict(package.files)['conservation/reference-occurrences.json'],maximum=w.MAX_BYTES)['occurrences']
        self.assertEqual([r['occurrence'] for r in rows],original)
        self.assertTrue(any(r['occurrence']['sourceKind']=='catalog_document' for r in rows))
        self.assertEqual(len([r for r in rows if r['occurrence']['relation']=='capture_content']),2)
        with self.assertRaises(MuseumError):w.require_complete(files)

    def test_omission_order_extra_bytes_and_wrong_external_pins_fail(self):
        package,raw,materials=self.external
        for mode in ('omit','swap','extra','pin','source','profile','calls'):
            e=loads(raw,maximum=w.MAX_BYTES);m=dict(materials)
            if mode=='omit':e['occurrences'].pop()
            elif mode=='swap':e['occurrences'][0],e['occurrences'][1]=e['occurrences'][1],e['occurrences'][0]
            elif mode=='extra':m['extra']=b'x'
            elif mode=='source':e['context']['blockHash']=H('other block')
            elif mode=='profile':e['profileHash']=H('different profile')
            elif mode=='calls':e['sourceBindings']['calls'].pop()
            changed=dumps(e)
            with self.subTest(mode=mode),self.assertRaises(MuseumError):
                w.verify(dict(package.files),changed,H('wrong pin') if mode=='pin' else K(changed),m)

    def test_all_six_algorithms_and_fixed_blake3_vectors(self):
        for data,digest in ((b'','af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262'),
                (b'abc','6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85')):
            ref={'algorithm':3,'canonicalizationId':archive.RAW,'digest':'0x'+digest}
            self.assertTrue(w._hashref(data,ref,True,None)[0])
            with self.assertRaisesRegex(MuseumError,'reference digest differs'):w._hashref(data+b'x',ref,True,None)
        for algorithm in range(2,7):
            with self.subTest(algorithm=algorithm):
                p,r,m=complete_case(algorithm=algorithm);result=w.verify(dict(p.files),r,K(r),m)
                w.require_complete(result)
                rows=loads(result[w.OUTPUTS[1]],maximum=w.MAX_BYTES)['occurrences']
                self.assertTrue(any(row['occurrence']['hash']['algorithm']==algorithm for row in rows))
        p,r,m=complete_case(algorithm=3,canonicalization=archive.JCS)
        self.assertTrue(w.require_complete(w.verify(dict(p.files),r,K(r),m))['complete'])

    def test_complete_av_catalog_keeps_duplicate_specs_and_exact_format(self):
        p,r,m=complete_case(fixture_kind='av');result=w.verify(dict(p.files),r,K(r),m);w.require_complete(result)
        rows=loads(result[w.OUTPUTS[1]],maximum=w.MAX_BYTES)['occurrences']
        catalog=[x for x in rows if x['occurrence']['sourceKind']=='catalog_document']
        self.assertTrue(catalog);self.assertTrue(all(x['status']=='complete' for x in catalog))
        selected=[x for x in rows if x['occurrence']['relation']=='capture_content']
        self.assertEqual(len(selected),2)
        self.assertTrue(all(x['declaredFormat']['kind']=='catalog' for x in selected))
        # Source occurrences stay separate even when identical bytes/archive are reused.
        self.assertLess(len(m),len(rows))
        for field in (7,8,9):
            e=loads(r,maximum=w.MAX_BYTES);index=selected[0]['occurrence']['occurrence']
            e['occurrences'][index]['archive']['sourceEvidence']['object'][field]=H('other declared format')
            reseal(e['occurrences'][index],e['context'],e['graph']);changed=dumps(e)
            with self.subTest(field=field),self.assertRaisesRegex(MuseumError,'declared format/catalog'):
                w.verify(dict(p.files),changed,K(changed),m)
        direct=loads(w.verify(dict(self.external[0].files),self.external[1],K(self.external[1]),self.external[2])[w.OUTPUTS[1]],maximum=w.MAX_BYTES)
        self.assertTrue(any(x['declaredFormat'] and x['declaredFormat']['kind']=='pronom' for x in direct['occurrences']))

    def test_opaque_encodings_unknown_canon_and_missing_transaction_stay_unresolved(self):
        for kwargs,reason in (({'algorithm':4,'opaque':True},'unsupported_multihash_encoding'),
                ({'algorithm':5,'opaque':True},'unsupported_cid_encoding'),
                ({'canonicalization':H('uninterpreted native canonicalization')},'unsupported_canonicalization'),
                ({'backend':'onchain','algorithm':6},'original_external_transaction_identity_required')):
            p,r,m=complete_case(**kwargs);result=w.verify(dict(p.files),r,K(r),m)
            rows=loads(result[w.OUTPUTS[1]],maximum=w.MAX_BYTES)['occurrences']
            self.assertTrue(any(reason in x['reasons'] for x in rows));self.assertTrue(all(x['archive'] for x in rows))
            with self.assertRaises(MuseumError):w.require_complete(result)

    def test_jcs_exact_bytes_cid_text_and_supported_digest_mismatch(self):
        self.assertTrue(w._canonical(b'{"a":1.5,"b":[true,null]}',archive.JCS))
        for raw in (b'{ "a":1}',b'{"a":1,"a":1}',b'{"a":NaN}',b'{"a":1.0}'):
            with self.subTest(raw=raw),self.assertRaises((MuseumError,ValueError)):w._canonical(raw,archive.JCS)
        data=b'original arbitrary bytes';cid=b'b'+base64.b32encode(b'\x01\x55\x12\x20'+hashlib.sha256(data).digest()).lower().rstrip(b'=')
        self.assertTrue(w._hashref(data,{'algorithm':5,'digest':'0x'+cid.hex()},True,None)[0])
        for algorithm in (1,2,3,4,5,6):
            reference={'algorithm':algorithm,'digest':material_digest(data,algorithm)}
            archived={'backend':'external','transactionId':H('different original transaction')} if algorithm==6 else None
            with self.subTest(algorithm=algorithm),self.assertRaises(MuseumError):w._hashref(data+b'changed',reference,True,archived)

    def test_parent_interview_exact_bytes_required_for_algorithms_four_five_six(self):
        for algorithm in (4,5,6):
            p,r,m=complete_case(parent_algorithm=algorithm);w.require_complete(w.verify(dict(p.files),r,K(r),m))
            p,r,m=complete_case(parent_algorithm=algorithm,parent_mismatch=True,check=False)
            with self.subTest(algorithm=algorithm),self.assertRaisesRegex(MuseumError,'original interview payload bytes'):
                w.verify(dict(p.files),r,K(r),m)

    def test_rehashed_signed_rows_cannot_contradict_native_profiles_times_and_verifiers(self):
        for backend,case in (('external',self.external),('onchain',self.onchain)):
            p,r,m=case
            for mode in ('fixity_profile','fixity_before','empty_report','same_writer','fixity_deadline',
                    'receipt_deadline','possession_profile','future_fixity'):
                if backend=='onchain' and mode=='fixity_profile':continue
                e=loads(r,maximum=w.MAX_BYTES);row=e['occurrences'][0];proof=row['archive']
                source=proof['sourceEvidence'] if backend=='external' else proof['sourceEvidence']['chunks'][0]['archive']
                receipt_mode=mode in ('receipt_deadline','possession_profile')
                kind=archive.RECEIPT if receipt_mode else archive.EXTERNAL_FIXITY if backend=='external' else archive.ARCHIVE_FIXITY
                group='receipts' if receipt_mode else 'fixities';index=1 if mode=='possession_profile' else 0
                types=(kind,'bytes','bytes') if receipt_mode else (kind,'bytes')
                decoded=list(decode(types,hex_bytes(source[group][index])));record=list(decoded[0])
                if mode=='fixity_profile':record[4]=H('wrong fixity profile')
                elif mode=='fixity_before':record[13 if backend=='external' else 6]=69
                elif mode=='empty_report':record[15 if backend=='external' else 8]=Z
                elif mode=='same_writer':record[18 if backend=='external' else 11]=decode((archive.RECEIPT,'bytes','bytes'),hex_bytes(source['receipts'][0]))[0][6]
                elif mode=='fixity_deadline':record[-1]=79
                elif mode=='receipt_deadline':record[-1]=69
                elif mode=='possession_profile':record[4]=H('other possession profile')
                elif mode=='future_fixity':record[13 if backend=='external' else 6]=int(e['context']['timestamp'])+1;record[-1]=2**63
                decoded[0]=tuple(record);source[group][index]='0x'+encode(types,tuple(decoded)).hex()
                reseal(row,e['context'],e['graph']);changed=dumps(e)
                with self.subTest(backend=backend,mode=mode),self.assertRaisesRegex(MuseumError,
                        'fixity profile|fixity precedes|independent fixity|signed deadline|possession profile|future original'):
                    w.verify(dict(p.files),changed,K(changed),m)

    def test_rehashed_external_object_checkpoint_family_and_source_runtime_conflicts(self):
        p,r,m=self.external
        for mode in ('object_schema_zero','object_catalog_zero','same_family','checkpoint_transaction','checkpoint_future','source_runtime'):
            e=loads(r,maximum=w.MAX_BYTES);row=e['occurrences'][0];proof=row['archive'];source=proof['sourceEvidence']
            if mode=='object_schema_zero':source['object'][1]=Z
            elif mode=='object_catalog_zero':source['object'][8]=Z
            elif mode=='same_family':proof['coverage'][8]=proof['coverage'][7]
            elif mode in ('checkpoint_transaction','checkpoint_future'):
                cp=list(decode((archive.EXTERNAL_NATIVE,),hex_bytes(source['checkpoint']['record']))[0])
                if mode=='checkpoint_future':cp[-1]=int(e['context']['timestamp'])+1
                else:
                    native=list(cp[1]);native[5]=H('different actual transaction');cp[1]=tuple(native)
                source['checkpoint']['record']='0x'+encode((archive.EXTERNAL_NATIVE,),(tuple(cp),)).hex()
            else:source['checkpoint']['verifier']=e['context']['core']
            reseal(row,e['context'],e['graph']);changed=dumps(e)
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.verify(dict(p.files),changed,K(changed),m)

    def test_complete_multichunk_and_native_envelope_pointer_plan_correspondence(self):
        p,r,m=complete_case('onchain',material_size=9000);w.require_complete(w.verify(dict(p.files),r,K(r),m))
        original=loads(r,maximum=w.MAX_BYTES)
        self.assertGreater(len(original['occurrences'][0]['archive']['sourceEvidence']['chunks']),1)
        for mode in ('reorder','pointer','schema','canon','plan','completion','chunk','artifact_schema'):
            e=deepcopy(original);row=e['occurrences'][0];proof=row['archive'];source=proof['sourceEvidence'];chunk=source['chunks'][0]
            if mode=='reorder':source['chunks'].reverse()
            elif mode=='pointer':chunk['archive']['envelopePointer']['address']=A(65000)
            elif mode in ('schema','canon'):
                env,data=decode((archive.ENVELOPE,'bytes'),hex_bytes(chunk['archive']['envelope']));env=list(env)
                env[2 if mode=='schema' else 3]=w.ESTATE_SCHEMA if mode=='schema' else archive.RAW
                chunk['archive']['envelope']='0x'+encode((archive.ENVELOPE,'bytes'),(tuple(env),data)).hex()
            elif mode=='plan':source['plan'][3]=H('different initial environment')
            elif mode=='completion':proof['coverage'][0]=H('different completed coverage')
            elif mode=='chunk':chunk['runtime']=chunk['runtime'][:-2]+'fe'
            else:source['artifact'][1]=Z
            reseal(row,e['context'],e['graph']);changed=dumps(e)
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.verify(dict(p.files),changed,K(changed),m)

    def test_retained_bytes_and_projection_cannot_be_replaced(self):
        p,r,m=self.external
        for mode in ('material','dossier','transcript'):
            files=dict(p.files);materials=dict(m)
            if mode=='material':materials[next(iter(materials))]+=b'x'
            elif mode=='dossier':
                path='conservation/dossier.json';doc=loads(files[path],maximum=w.MAX_BYTES)
                next(x['semantic'] for x in doc['records'] if x['family']=='interview')['languages'].append('fr');files[path]=dumps(doc)
            else:
                path='input/source/transcript.json';doc=loads(files[path],maximum=w.MAX_BYTES)
                doc['calls'].pop();files[path]=dumps(doc)
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.verify(files,r,K(r),materials)

    def test_source_carrier_runtime_and_repeated_original_getter_answers_are_shared(self):
        p,r,m=self.external;files=dict(p.files);snapshot,_,_,transcript=w._load(files)
        anchor_pins={row['address'] for row in snapshot['source']['codePins']}
        carrier=next(row for row in transcript['calls'] if row['method']=='eth_getCode'
            and row['params'][0] not in anchor_pins and row.get('result','').startswith('0x00'))
        e=loads(r,maximum=w.MAX_BYTES);proof=e['occurrences'][0]['archive'];cp=proof['sourceEvidence']['checkpoint']
        cp['verifier']=carrier['params'][0];reseal(e['occurrences'][0],e['context'],e['graph']);changed=dumps(e)
        with self.assertRaisesRegex(MuseumError,'runtime'):w.verify(files,changed,K(changed),m)
        for row in e['occurrences']:
            cp=row['archive']['sourceEvidence']['checkpoint']
            cp['verifier']=carrier['params'][0];cp['runtimeHash']=K(hex_bytes(carrier['result']))
            reseal(row,e['context'],e['graph'])
        changed=bind_reads(files,e,m);w.require_complete(w.verify(files,changed,K(changed),m))
        p,r,m=complete_case(fixture_kind='av');e=loads(r,maximum=w.MAX_BYTES);seen={};duplicate=None
        for row in e['occurrences']:
            if row['materialPath'] in seen:duplicate=row;break
            seen[row['materialPath']]=row
        self.assertIsNotNone(duplicate)
        original=duplicate['archive']['sourceEvidence'];rec,locator,signature=decode((archive.RECEIPT,'bytes','bytes'),hex_bytes(original['receipts'][0]))
        original['receipts'][0]='0x'+encode((archive.RECEIPT,'bytes','bytes'),(rec,locator,signature+b' changed')).hex()
        reseal(duplicate,e['context'],e['graph']);changed=dumps(e)
        with self.assertRaisesRegex(MuseumError,'conflicting original getter'):w.verify(dict(p.files),changed,K(changed),m)


if __name__=='__main__':unittest.main()
