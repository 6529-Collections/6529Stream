"""fd861 stage-derivation vectors, not native execution or complete inventory proof.

The base is an actual retained reference fixture. Extra byte preimages below
exercise the six projection functions in isolation; changing them does not
pretend to recreate the enclosing adoption/reference authority or signatures.
The outer inventory validator separately requires that complete source proof.
"""
import base64
from copy import deepcopy
from hashlib import sha256
import socket
import unittest
from unittest.mock import patch

from . import view_preservation_inventory_sources_v1 as source
from . import view_preservation_inventory_items_v1 as items
from . import view_preservation_inventory_types_v1 as t
from . import view_policy_adoption_wire_v2 as adoption
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import Array, decode, encode
from .current_rights_source import DOCUMENT_FACTS
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .test_view_preservation_reference_wire_v1 import supplied as reference_fixture
from .view_preservation_fixture_v1 import ViewPreservationFixtureV1


def H(label):return schema_id('inventory stage test '+label)
def A(n):return '0x'+n.to_bytes(20,'big').hex()


def zero(kind):
    if isinstance(kind,tuple):return tuple(zero(x) for x in kind)
    if isinstance(kind,Array):return ()
    if kind=='bool':return False
    if kind=='address':return ZERO_ADDRESS
    if kind=='bytes32':return ZERO
    if kind=='string':return ''
    if kind=='bytes':return b''
    return 0


def cid(raw=b'actual image bytes'):
    return 'ipfs://b'+base64.b32encode(b'\x01\x55\x12\x20'+sha256(raw).digest()).decode().lower().rstrip('=')


def original_document(raw):
    chunks=[raw[i:i+8192] for i in range(0,len(raw),8192)]
    facts=(True,0,1,keccak256(raw),schema_id('RAW_BYTES'),ZERO,len(raw),len(chunks),H('document sequence'))
    return {'facts':json_values(facts),'chunks':[
        {'hash':keccak256(chunk),'bytes':'0x'+chunk.hex()} for chunk in chunks]}


def projection_fixture(count=3,*,burned=False):
    """Source-stage inputs with explicit byte preimages, not a resealed capture."""
    ref,context,graph=reference_fixture(count=count,burned=burned)
    f=ViewPreservationFixtureV1(count=count,burned=burned)
    runtimes={address:'0x'+raw.hex() for address,raw in f.codes.items()}
    for role,label in (('viewReference','reference runtime'),('externalCoverage','external coverage runtime')):
        runtimes[graph[role]['address']]='0x'+('synthetic VIEW '+label).encode().hex()
    roles=('core','metadata','schemas','store','router','viewSnapshot','viewReference',
        'work','rights','conservation','coverage','externalCoverage')
    artist_roles=('artist','artistCoordinator','artistIdentity','artistAttribution','artistArchive')
    for i,role in enumerate((*roles,*artist_roles,'artistContentOwner')):
        if role not in graph:
            raw=('inventory stage runtime '+role).encode();address=A(81000+i)
            graph[role]={'address':address,'runtimeHash':keccak256(raw)}
            runtimes[address]='0x'+raw.hex()
    pair=lambda role:(graph[role]['address'],graph[role]['runtimeHash'])
    d=(tuple(pair(k)[0] for k in roles),tuple(pair(k)[1] for k in roles),
        tuple(pair(k)[0] for k in artist_roles),tuple(pair(k)[1] for k in artist_roles),
        *pair('artistContentOwner'),int(context['chainId']),100000,1000000,1000000)
    row,bundle,adopted,snap=source.selected(ref)
    facts=source.typed(source.r.SOURCE,row['source']);saved=facts[2]
    c=list(zero(t.CONTEXT));c[0]=facts[2][0];c[1]=facts[0];c[2]=saved[2][3]
    c[3]=facts[1];c[4]=source.typed(source.r.RECEIPT,row['receipt']);c[9]=facts[3]
    c[11]=bundle['output']['checkpoint']['id'];c[12]=bundle['output']['manifest']['recordHash']
    c[13]=saved[3][0][3];c[20]=count
    for i,policy in enumerate(saved[6][5]):
        raw=('VIEW membership test coordinator code'+str(i)).encode()
        assert keccak256(raw)==policy[1]
        runtimes[policy[0]]='0x'+raw.hex()

    # Preserve the canonical native payload field bounds and raw-CID image mode.
    payload=list(decode((source.v.PAYLOAD,),hex_bytes(adopted['declaration']['viewPayload']))[0])
    payload[3]=cid();adopted['declaration']['viewPayload']='0x'+encode((source.v.PAYLOAD,),(payload,)).hex()

    # Supply actual registered bytes corresponding to all five original renderer
    # documents and the three separately admitted preservation documents.
    documents={}
    def doc(label,raw):
        identifier=H(label);documents[identifier]=original_document(raw);return identifier
    observed=adopted['declaration']['renderer'];manifest=source.typed(source.v.RENDERER_MANIFEST,observed['manifest'])
    registry=bundle['adoption']['preservation']['registry']
    ids=(doc('renderer schema',adoption.V2_OUTPUT_SCHEMA_BYTES),doc('renderer context',b'context bytes'),
        doc('renderer manifest',b'VIEW adoption test renderer manifest'),
        doc('renderer analysis',b'VIEW preservation adoption test original analysis'),
        doc('renderer golden',b'VIEW preservation adoption test original golden'))
    selection=adopted['record'][1][2]
    registration=(selection[3],manifest,*ids)
    targets=source.typed(source.a.TARGETS,registry['targets'])
    reads=source.typed(source.a.READS,registry['originalReads'])
    digest=keccak256(encode(('bytes32','uint256','address','address','bytes32','bytes32',
        source.RENDERER_REGISTRATION,source.a.READS),(schema_id('6529STREAM_RENDERER_REGISTRATION_V1'),
        d[6],selection[0],d[0][2],d[1][2],keccak256(encode((source.a.TARGETS,),(targets,))),registration,reads)))
    selection[10]=registry['version'][4]=digest
    reg=registry['record']
    reg[0][2:5]=[doc('preservation schema',b'preservation schema bytes'),
        doc('preservation analysis',b'VIEW preservation adoption test analysis bytes'),
        doc('preservation golden',b'VIEW preservation adoption test golden bytes')]

    observations=[]
    for output in bundle['output']['checkpoint']['outputs']:
        token=output[1];data=('token data '+token).encode();js=('{"token":"'+token+'"}').encode()
        html=('<html>original synthetic token '+token+'</html>').encode()
        output[6]=keccak256(data);output[8:12]=[keccak256(js),keccak256(html),str(len(js)),str(len(html))]
        observations.append({'outputReturn':'0x'+encode((source.o.OUTPUT,),
            (source.typed(source.o.OUTPUT,output),)).hex(),'tokenData':'0x'+data.hex(),
            'json':'0x'+js.hex(),'html':'0x'+html.hex()})
    return {'reference':ref,'context':tuple(c),'dependencies':d,'runtimes':runtimes,
        'documents':documents,'registration':json_values(registration),'members':observations,
        'chainContext':context,'graph':graph}


def bytes_row(kind,role,host,key,index,raw):
    """Independent native Items.bytesItem tuple oracle."""
    return (9 if kind==0 and not raw else kind,schema_id(role),host,key,index,1,
        schema_id('RAW_BYTES'),hex_bytes(keccak256(raw)),'',len(raw),*(ZERO,)*7)


class ViewPreservationInventorySourcesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.base=projection_fixture()

    def fixture(self):return deepcopy(self.base)

    def test_native_order_denominator_original_bytes_and_object_roles(self):
        f=self.fixture();c,d,ref=f['context'],f['dependencies'],f['reference']
        row,bundle,adopted,snap=source.selected(ref)
        rows=source.native_rows(c,d,ref,f['runtimes'])
        policies=row['source'][2][6][5];parts=bundle['output']['manifest']['parts']
        self.assertEqual(len(rows),41+2*len(policies)+2*len(parts))
        raw=encode((source.s.PUBLICATION,source.s.RECEIPT),
            (source.typed(source.s.PUBLICATION,snap['publication']),c[3]))
        self.assertEqual(rows[0],bytes_row(0,'ORIGINAL_VIEW_PRESERVATION_SNAPSHOT_RECORD',d[0][5],c[3][0],0,raw))
        self.assertEqual(rows[5],bytes_row(0,'ORIGINAL_POLICY_VIEW_ADOPTION',d[0][4],c[13],0,
            encode((source.v.RECORD,),(source.typed(source.r.SOURCE,row['source'])[2][3][0],))))
        self.assertEqual([x[1] for x in rows[13:25]],[schema_id('VIEW_INVENTORY_DEPENDENCY_RUNTIME')]*12)
        self.assertEqual(rows[11][0],10);self.assertEqual(rows[11][6],source.o.INDEX_CANON)
        self.assertEqual(rows[-1][0],10);self.assertEqual(rows[-1][6],source.o.PART_CANON)
        self.assertEqual(rows[-1][14:16],source.typed(source.o.PART,parts[-1]['record'])[1][:2])

    def test_native_65_rows_preserve_two_distinct_part_occurrences(self):
        f=projection_fixture(65);rows=source.native_rows(f['context'],f['dependencies'],f['reference'],f['runtimes'])
        self.assertEqual([x[4] for x in rows[-4:]],[0,0,1,1])
        self.assertNotEqual(rows[-3][3],rows[-1][3])
        ref=f['reference'];source.selected(ref)[1]['output']['manifest']['parts'].pop()
        with self.assertRaisesRegex(MuseumError,'part denominator'):
            source.native_rows(f['context'],f['dependencies'],ref,f['runtimes'])

    def test_native_rejects_dependency_role_pin_and_policy_count_changes(self):
        for change in ('role','runtime','policy_count'):
            f=self.fixture();d=list(f['dependencies'])
            if change=='role':d[0]=(*d[0][:1],d[0][2],*d[0][2:])
            elif change=='runtime':f['runtimes'][d[0][0]]='0x01'
            else:source.selected(f['reference'])[0]['source'][2][6][3]='2'
            with self.assertRaises(MuseumError):source.native_rows(f['context'],d,f['reference'],f['runtimes'])

    def test_reference_rows_preserve_complete_declared_files_and_capture_pair_order(self):
        f=self.fixture();c,d=f['context'],f['dependencies'];ref=f['reference']
        row=source.selected(ref)[0];p=source.typed(source.r.PUBLICATION,row['publication'])[1]
        rows=source.reference_rows(c,d,ref)
        self.assertEqual(len(rows),3+len(p[8][12])+len(p[8][13])+2*len(p[7]))
        self.assertEqual(rows[1],bytes_row(0,'REFERENCE_ENVIRONMENT_DECLARATION',d[0][6],c[4][1][0],0,
            encode((source.r.ENVIRONMENT,),(p[8],))))
        self.assertEqual([x[8] for x in rows[3:6]],['engine.exe','tool.py','C:/Windows/synthetic.dll'])
        self.assertEqual([x[0] for x in rows[3:6]],[4,4,8])
        self.assertEqual([x[1] for x in rows[-4:]],[schema_id(x) for x in
            ('REFERENCE_CAPTURE','REFERENCE_CAPTURE_DECLARATION')]*2)

    def test_reference_empty_member_is_explicit_and_wrong_digest_rejected(self):
        f=self.fixture();entry=source.selected(f['reference'])[0]['publication'][1][8][12][0]
        entry[1]='0';entry[2]='0x'+sha256(b'').hexdigest()
        rows=source.reference_rows(f['context'],f['dependencies'],f['reference'])
        self.assertEqual(rows[3][0],11);self.assertEqual(rows[3][5],2);self.assertEqual(rows[3][9],0)
        entry[2]=H('not empty')
        with self.assertRaisesRegex(MuseumError,'empty member digest'):
            source.reference_rows(f['context'],f['dependencies'],f['reference'])

    def test_artwork_all_seven_roles_and_raw_cid_correspondence(self):
        f=self.fixture();rows=source.artwork_rows(f['context'],f['dependencies'],f['reference'])
        self.assertEqual(len(rows),7)
        self.assertEqual([x[1] for x in rows],[schema_id(x) for x in ('ORIGINAL_VIEW_DECLARATION_RECORD',
            'ORIGINAL_VIEW_DECLARATION_MANIFEST','COMPLETE_ADOPTED_VIEW_PAYLOAD','COMPLETE_ADOPTED_VIEW_SCRIPT',
            'EXACT_ADOPTED_VIEW_IMAGE_URI','VIEW_CONTENT_ADDRESSED_IMAGE','VIEW_EXTERNAL_LIBRARY_BUNDLE')])
        self.assertEqual(rows[5][5:9],(2,schema_id('RAW_BYTES'),sha256(b'actual image bytes').digest(),cid()))
        self.assertEqual(rows[6][0],7);self.assertEqual(rows[2][10],schema_id('STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2'))

    def test_native_valid_large_artwork_payload_uses_complete_decoder_bound(self):
        f=self.fixture();decl=source.selected(f['reference'])[2]['declaration']
        payload=(source.v.V2_CONTEXT,'n'*128,'d'*8192,cid(),b's'*24576)
        raw=encode((source.v.PAYLOAD,),(payload,));self.assertGreater(len(raw),32768)
        self.assertLessEqual(len(raw),source.v.MAX_PAYLOAD);adoption._payload(raw,source.v.V2_PROFILE)
        decl['viewPayload']='0x'+raw.hex();rows=source.artwork_rows(f['context'],f['dependencies'],f['reference'])
        self.assertEqual(rows[2][9],len(raw));self.assertEqual(rows[3][9],24576)
        self.assertEqual(rows[3][7],hex_bytes(keccak256(payload[4])))

    def test_media_does_not_promote_https_arweave_or_noncanonical_cid(self):
        for uri in ('https://example/image','ar://opaque','ipfs://image',cid().upper(),
                cid()[:-1]+'z',cid().replace('bafk','bafy',1)):
            with self.subTest(uri=uri),self.assertRaises(MuseumError):items.media(A(1),H('media'),uri)
        self.assertEqual(items.media(A(1),H('media'),'')[0],7)

    def test_renderer_complete_registration_documents_and_runtime_provenance(self):
        f=self.fixture();d=f['dependencies'];ref=f['reference']
        rows=source.renderer_rows(f['context'],d,ref,f['registration'],f['runtimes'],f['documents'])
        _,bundle,adopted,_=source.selected(ref);saved=bundle['adoption']['preservation']['registry']
        targets=source.typed(source.a.TARGETS,saved['targets']);selection=adopted['record'][1][2]
        self.assertEqual(len(rows),18+len(targets));self.assertEqual([x[0] for x in rows[9:14]],[3]*5)
        self.assertEqual(rows[1],bytes_row(0,'RENDERER_REGISTRATION',selection[0],selection[2],0,
            encode((source.RENDERER_REGISTRATION,),(source.typed(source.RENDERER_REGISTRATION,f['registration']),))))
        self.assertEqual([x[4] for x in rows[14:18]],[0,1,2,3])
        for item,target in zip(rows[18:],targets):
            self.assertEqual(item[1],target[2]);self.assertEqual(item[16],keccak256(encode(
                ('address','bytes32',source.a.TARGET),(selection[0],selection[2],target))))

    def test_renderer_wrong_original_preimage_runtime_or_document_bytes_fails(self):
        for change in ('registration','runtime','document','typed'):
            f=self.fixture()
            if change=='registration':f['registration'][2]=H('another registered schema')
            elif change=='runtime':f['runtimes'][f['registration'][0]]='0x01'
            elif change=='typed':f['registration'].pop()
            else:f['documents'][f['registration'][2]]['chunks'][0]['bytes']='0x01'
            with self.assertRaises(MuseumError):source.renderer_rows(f['context'],f['dependencies'],f['reference'],
                f['registration'],f['runtimes'],f['documents'])

    def test_preservation_admission_retains_separate_registration_and_three_documents(self):
        f=self.fixture();rows=source.admission_rows(f['context'],f['dependencies'],f['reference'],f['runtimes'],f['documents'])
        _,bundle,_,_=source.selected(f['reference']);p=bundle['adoption']['preservation']
        self.assertEqual(len(rows),14+len(p['registry']['targets']))
        self.assertEqual([x[0] for x in rows[5:9]],[1]*4);self.assertEqual([x[0] for x in rows[11:14]],[3]*3)
        self.assertEqual(rows[0][7],hex_bytes(keccak256(encode((source.a.PRESERVATION_RECORD,),
            (source.typed(source.a.PRESERVATION_RECORD,p['registry']['record']),)))))
        changed=deepcopy(f['runtimes']);changed[p['worker']]='0x00'
        with self.assertRaisesRegex(MuseumError,'runtime pin'):
            source.admission_rows(f['context'],f['dependencies'],f['reference'],changed,f['documents'])

    def test_every_token_exact_bytes_full_output_and_original_burn_identity(self):
        for burned in (False,True):
            f=projection_fixture(1,burned=burned)
            groups=source.token_rows(f['context'],f['dependencies'],f['reference'],f['members'],f['runtimes'])
            self.assertEqual(len(groups),1);self.assertEqual(len(groups[0]),6)
            output=source.typed(source.o.OUTPUT,source.selected(f['reference'])[1]['output']['checkpoint']['outputs'][0])
            identity=encode(('uint256','uint256','uint256','bool','uint8','uint64'),
                (output[1],f['context'][0][1],output[2],burned,3 if burned else 2,0))
            self.assertEqual(groups[0][0][7],hex_bytes(keccak256(identity)))
            self.assertEqual(groups[0][2][9],992)
            self.assertEqual(groups[0][2][7],hex_bytes(keccak256(hex_bytes(f['members'][0]['outputReturn']))))

    def test_token_rows_reject_omission_reorder_and_independent_byte_mutations(self):
        for change in ('omit','swap','return','data','json','html','length','index','coordinator'):
            f=self.fixture();members=f['members'];rows=source.selected(f['reference'])[1]['output']['checkpoint']['outputs']
            if change=='omit':members.pop()
            elif change=='swap':members[0],members[1]=members[1],members[0]
            elif change in ('return','data','json','html'):
                key={'return':'outputReturn','data':'tokenData'}.get(change,change)
                members[0][key]=members[0][key][:-2]+'ff'
            elif change=='coordinator':f['runtimes'][rows[0][7][0]]='0x01'
            else:
                rows[0][10 if change=='length' else 0]='99'
                members[0]['outputReturn']='0x'+encode((source.o.OUTPUT,),(source.typed(source.o.OUTPUT,rows[0]),)).hex()
            with self.subTest(change=change),self.assertRaises(MuseumError):
                source.token_rows(f['context'],f['dependencies'],f['reference'],members,f['runtimes'])

    def test_document_repeated_chunk_occurrences_and_complete_order_are_preserved(self):
        raw=b'a'*8192+b'a'*8192+b'tail';identifier=H('chunked document');docs={identifier:original_document(raw)}
        row=items.document(identifier,keccak256(raw),A(4),docs)
        self.assertEqual(row[7],hex_bytes(keccak256(raw)));self.assertEqual(row[9],len(raw))
        self.assertEqual(row[16],keccak256(encode((DOCUMENT_FACTS,),
            (source.typed(DOCUMENT_FACTS,docs[identifier]['facts']),))))
        for change in ('missing','swap','inactive','size','hash'):
            changed=deepcopy(docs);d=changed[identifier]
            if change=='missing':d['chunks'].pop(0)
            elif change=='swap':d['chunks'][0],d['chunks'][2]=d['chunks'][2],d['chunks'][0]
            elif change=='inactive':d['facts'][2]='2'
            elif change=='size':d['facts'][6]=str(len(raw)-1)
            else:d['facts'][3]=H('other doc')
            with self.assertRaises(MuseumError):items.document(identifier,keccak256(raw),A(4),changed)

    def test_all_six_stage_functions_run_without_socket_or_authority_decisions(self):
        f=self.fixture();c,d,r=f['context'],f['dependencies'],f['reference']
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            rows=(source.native_rows(c,d,r,f['runtimes']),source.reference_rows(c,d,r),source.artwork_rows(c,d,r),
                source.renderer_rows(c,d,r,f['registration'],f['runtimes'],f['documents']),
                source.admission_rows(c,d,r,f['runtimes'],f['documents']),
                source.token_rows(c,d,r,f['members'],f['runtimes']))
        self.assertTrue(all(rows));self.assertTrue(all(type(x) is tuple for x in rows))


if __name__=='__main__':unittest.main()
