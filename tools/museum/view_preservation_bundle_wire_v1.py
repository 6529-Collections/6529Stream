"""Original VIEW inventory coverage commitments, never current archive liveness.

The caller must first validate the complete source-derived inventory. Recorded
coverage facts remain trusted native observations: this helper checks their
retained preimages, not signatures, quorum consensus, or external possession.
"""
import hashlib

from . import view_preservation_inventory_types_v1 as t
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, subject_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import from_json

SOURCE_REVISION = 'fd861f3fd79dccc87646412603b6907d020c2917'
PROFILE = schema_id('6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1')
RAW, JCS = schema_id('RAW_BYTES'), schema_id('RFC8785_JCS')
MAX_TOTAL = 64*1024*1024
MAX_ITEMS = 16384
MAX_GAS = 64000000
EXTERNAL_PROFILE = schema_id('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1')
ARCHIVE_PROFILE = schema_id('6529STREAM_PUBLIC_DUAL_FAMILY_ARCHIVAL_V1')
DEPENDENCY_ROLES = ('core', 'metadata', 'inventory', 'coverage', 'externalCoverage', 'artistArchive')
OBJECT = ('bytes32',)*6+('uint64',)+('bytes32',)*3
RECEIPT = ('bytes32',)*6+('address','uint64','uint256','uint64')
EXTERNAL_FIXITY = ('bytes32',)*11+('uint64','uint64','uint64','uint8')+('bytes32',)*3+('address','uint256','uint64')
ARCHIVE_FIXITY = ('bytes32',)*5+('uint64','uint64','uint8')+('bytes32',)*3+('address','uint256','uint64')
CHECKPOINT = ('bytes32','bytes','uint64','bytes32','uint256','bytes32','bytes32','uint64','uint256','uint256','uint64','bytes32')
CERTIFICATE = Array(('address','bytes'),2048)
EXTERNAL_NATIVE = ('bytes32',CHECKPOINT,'bytes32','bytes32','bytes','bytes','bytes',CERTIFICATE,'uint64')
ARCHIVE_NATIVE = ('bytes32',CHECKPOINT,'bytes32','bytes32','bytes','bytes',CERTIFICATE,'uint64')
ARCHIVE_COVERAGE = ('bytes32',)*12
ENVELOPE = ('bytes32',)*4+('uint16','bytes32','uint64','uint8','bytes32')
ARTIFACT = ('bytes32','bytes32','bytes32','uint16','bytes32','uint64',Array('bytes32',128),Array('uint32',128))
STATE_METADATA = ('bytes32','address','uint32','uint64')


def _v(kind,value): return from_json(kind,value)
def _hash(kinds,values): return keccak256(encode(kinds,values))
def _domain(name,kinds,values): return _hash(('bytes32',*kinds),(schema_id(name),*values))
def _closed(value,keys,label):
    require(type(value) is dict and set(value)==set(keys),'VIEW bundle '+label+' shape')
def _zero(kind):
    if isinstance(kind,tuple): return tuple(_zero(k) for k in kind)
    if kind=='bool': return False
    if kind=='address': return ZERO_ADDRESS
    if kind=='bytes32': return ZERO
    return 0


def item_hash(item):
    return _domain('6529STREAM_PRESERVATION_ITEM_V1',(t.ITEM,),(_v(t.ITEM,item),))


def external_object_hash(value,chain,host,core):
    return _domain('6529STREAM_EXTERNAL_OBJECT_V1',('uint256','address','address',OBJECT),
        (_v('uint256',chain),host,core,_v(OBJECT,value)))


def external_coverage_hash(value,chain,host):
    c=_v(t.ADMISSION[3],value)
    return _domain('6529STREAM_EXTERNAL_COVERAGE_V1',('uint256','address',t.ADMISSION[3]),
        (_v('uint256',chain),host,(ZERO,*c[1:])))


def archive_coverage_hash(value,chain,host):
    c=_v(ARCHIVE_COVERAGE,value)
    return _domain('6529STREAM_ARCHIVAL_COVERAGE_RECORD_V1',('uint256','address',ARCHIVE_COVERAGE),
        (_v('uint256',chain),host,(ZERO,*c[1:])))


def artifact_hash(value,chain,host,core):
    return _domain('6529STREAM_FINALITY_ARTIFACT_V1',('uint256','address','address',ARTIFACT),
        (_v('uint256',chain),host,core,_v(ARTIFACT,value)))


def covered_item(previous,plan,index,item,admission):
    return _domain('6529STREAM_VIEW_PRESERVATION_BUNDLE_COVERED_ITEM_V1',
        ('bytes32','bytes32','uint64','bytes32',t.ADMISSION),
        (previous,plan,index,item_hash(item),_v(t.ADMISSION,admission)))


def coverage_hash(evidence,inventory,dependencies,chain,host):
    e=list(_v(t.BUNDLE_EVIDENCE,evidence)); body=list(e[1]);body[4]=ZERO;e[1]=tuple(body)
    return _domain('6529STREAM_VIEW_PRESERVATION_BUNDLE_ARCHIVE_COVERAGE_V1',
        ('uint256','address','bytes32','bytes32',t.INVENTORY_EVIDENCE,t.BUNDLE_EVIDENCE),
        (uint(chain),host,_hash((t.BUNDLE_DEPENDENCIES,),(_v(t.BUNDLE_DEPENDENCIES,dependencies),)),
         PROFILE,_v(t.INVENTORY_EVIDENCE,inventory),tuple(e)))


def environment_hash(dependencies,onchain_hash,epoch,external_hash,revision):
    require(onchain_hash!=ZERO and epoch>0 and external_hash!=ZERO,'VIEW bundle environment observations')
    return _domain('6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1',
        (t.BUNDLE_DEPENDENCIES,'bytes32','uint64','bytes32','uint64'),
        (_v(t.BUNDLE_DEPENDENCIES,dependencies),onchain_hash,epoch,external_hash,revision))


def refresh_id(plan,environment,dependency_hash,chain,host):
    return _domain('6529STREAM_VIEW_PRESERVATION_BUNDLE_REFRESH_V1',
        ('uint256','address','bytes32','bytes32','bytes32'),(uint(chain),host,dependency_hash,plan,environment))


def observation_hash(previous,index,item,observation):
    return _domain('6529STREAM_VIEW_PRESERVATION_BUNDLE_CURRENT_OBSERVATION_V1',
        ('bytes32','uint64','bytes32','bytes32'),(previous,index,item_hash(item),observation))


class _Originals:
    def __init__(self,context,graph):
        self.chain=uint(context['chainId']);self.context=context;self.pins={};self.total=0
        self.calls=[];self.answers={}
        for row in graph.values(): self.pin(row['address'],row['runtimeHash'])

    def address_read(self,host,signature,address):
        data=calldata(signature,(),())
        result='0x'+encode(('address',),(address,)).hex()
        require(self.answers.setdefault((host,data),result)==result,
            'VIEW bundle conflicting retained binding getter')
        self.calls.append({'target':host,'calldata':data,'result':result})

    def pin(self,address,digest):
        require(any(hex_bytes(address,20)) and any(hex_bytes(digest,32))
            and self.pins.setdefault(address,digest)==digest,'VIEW bundle original runtime conflict')

    def raw(self,value,maximum):
        require(type(value) is str and len(value)<=maximum*2+2,'VIEW bundle original byte bound')
        raw=hex_bytes(value);self.total+=len(raw)
        require(self.total<=MAX_TOTAL,'VIEW bundle aggregate original byte bound')
        return raw

    def signed(self,host,key,value,kind,domain,maximum,receipt=False,expected=()):
        raw=self.raw(value,maximum)
        parts=decode((kind,'bytes','bytes') if receipt else (kind,'bytes'),raw,maximum=maximum)
        record=parts[0]
        require(record[6 if receipt else -3]!=ZERO_ADDRESS
            and (not receipt or record[2]==keccak256(parts[1]))
            and key==_domain(domain,('uint256','address',kind),(self.chain,host,record)),
            'VIEW bundle original signed record preimage')
        require(all(record[index]==original for index,original in expected),
            'VIEW bundle original signed record correspondence')
        return _hash(('bytes32','bytes'),(key,raw))

    def native(self,value,key,external,host,locator,content,size,digest):
        _closed(value,('verifier','runtimeHash','record'),'checkpoint original')
        self.address_read(host,'checkpointVerifier()',value['verifier'])
        self.pin(value['verifier'],value['runtimeHash'])
        raw=self.raw(value['record'],65536)
        record=decode((EXTERNAL_NATIVE if external else ARCHIVE_NATIVE,),raw,maximum=65536)[0]
        require(key!=ZERO and record[0]==key and record[-1]>0 and len(record[-2])>0,
            'VIEW bundle original native checkpoint')
        checkpoint=record[1]
        require(len(locator)==32 and checkpoint[5]=='0x'+locator.hex() and checkpoint[7]==size
            and checkpoint[0]==schema_id('ARWEAVE_MAINNET') and checkpoint[11]!=ZERO,
            'VIEW bundle original checkpoint object correspondence')
        require((checkpoint[6]==digest and record[2]!=ZERO and record[3]!=ZERO) if external else
            (record[2]==digest and record[3]==content),
            'VIEW bundle original checkpoint content correspondence')
        return _hash(('address','bytes32','bytes32','bytes'),(value['verifier'],value['runtimeHash'],key,raw))

    def archive(self,value,artist,content,first,second):
        _closed(value,('host','runtimeHash','coverage','receipts','fixities','checkpoint','envelope'),'chunk archive')
        self.pin(value['host'],value['runtimeHash']);host=value['host']
        c=_v(ARCHIVE_COVERAGE,value['coverage'])
        require(c[0]!=ZERO and c[2:6]==(artist,content,first,second)
            and first!=ZERO and second!=ZERO and first!=second and c[11]==ARCHIVE_PROFILE,
            'VIEW bundle original chunk coverage')
        require(c[0]==archive_coverage_hash(c,self.chain,host),'VIEW bundle original archive coverage hash')
        raw=self.raw(value['envelope'],16384);e,payload=decode((ENVELOPE,'bytes'),raw,maximum=16384)
        require(e[0]==artist and e[1]==content and e[6]==len(payload)
            and keccak256(payload)==content and '0x'+hashlib.sha256(payload).hexdigest()==e[5],
            'VIEW bundle original archive envelope bytes')
        require(type(value['receipts']) is list and len(value['receipts'])==2
            and type(value['fixities']) is list and len(value['fixities'])==2,'VIEW bundle archival originals denominator')
        hashes=[self.signed(host,c[6+i],raw,RECEIPT,'6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1',16384,True,
                    ((0,c[1]),(1,c[4+i]),(3,schema_id('CONTENT_ADDRESSED_INCLUSION' if i==0 else 'ATTESTED_POSSESSION')))
                     + (((5,c[10]),) if i==0 else ()))
                for i,raw in enumerate(value['receipts'])]
        hashes += [self.signed(host,c[8+i],raw,ARCHIVE_FIXITY,'6529STREAM_ARCHIVAL_FIXITY_RECORD_V1',16384,
                    expected=((0,c[6+i]),(1,c[1]),(2,c[4+i]),(3,e[5]),(4,e[5]),(5,e[6]),(7,1)))
                   for i,raw in enumerate(value['fixities'])]
        locator=decode((RECEIPT,'bytes','bytes'),hex_bytes(value['receipts'][0]),maximum=16384)[1]
        hashes.append(self.native(value['checkpoint'],c[10],False,host,locator,e[1],e[6],e[5]))
        hashes.append(keccak256(raw))
        return _hash(('address','bytes32',ARCHIVE_COVERAGE,('bytes32',)*6),(host,value['runtimeHash'],c,tuple(hashes)))


def _correspondence(item,keccak_hash,sha_hash,canon,size):
    require(len(item[7])==32 and item[6]==canon and size>0 and (item[9]==0 or item[9]==size),
        'VIEW bundle original content correspondence')
    require(item[0] in (5,10) or canon in (RAW,JCS),'VIEW bundle unsupported content canonicalization')
    digest=keccak_hash if item[5]==1 else sha_hash if item[5]==2 else ZERO
    require(digest!=ZERO and item[7]==hex_bytes(digest,32),'VIEW bundle original digest differs')


def _applicability(item):
    require(all(item[i]==ZERO for i in (10,11,12,13,14,15)),'VIEW bundle explicit applicability object fields')
    empty_sha=hashlib.sha256(b'').digest()
    if item[0]==7:
        require(item[9]==item[5]==0 and item[6]==ZERO and not item[7] and not item[8],'VIEW bundle absent')
    elif item[0]==9:
        require(item[9]==0 and item[5]==1 and item[6]==RAW and not item[8]
            and item[7]==hex_bytes(keccak256(b'')),'VIEW bundle empty bytes')
    elif item[0]==11:
        require(item[9]==0 and item[5]==2 and item[6]==RAW and item[8]
            and item[7]==empty_sha,'VIEW bundle empty package member')
    else:
        require(item[0]==8 and item[5]==2 and item[6]==RAW and len(item[7])==32 and item[8]
            and (item[9]!=0 or item[7]==empty_sha),'VIEW bundle OS prerequisite')


def _admission(item,admission,evidence,d,artist,originals):
    proof,bundle,parts,external,onchain=admission
    require(item[0]<=11 and item[1]!=ZERO and item[2]!=ZERO_ADDRESS and item[3]!=ZERO,
        'VIEW bundle admitted original item')
    empty_external=_zero(t.ADMISSION[3]);empty_onchain=_zero(t.ADMISSION[4])
    if item[0] in (7,8,9,11):
        require(proof==(0,ZERO,ZERO) and parts==ZERO and external==empty_external and onchain==empty_onchain
            and evidence is None,'VIEW bundle applicability has no archive proof')
        _applicability(item)
        expected=_domain('EXPLICIT_INVENTORY_APPLICABILITY',(t.ITEM,),(item,))
    elif item[0]==6:
        _closed(evidence,('payload','metadata','runtime','sourceRuntimeHash'),'state originals')
        require(proof==(0,ZERO,ZERO) and external==empty_external and onchain==empty_onchain
            and item[2]==d[0][5] and item[4]==1 and item[5]==1 and item[6]==RAW,
            'VIEW bundle original Artist state scope')
        originals.pin(item[2],evidence['sourceRuntimeHash'])
        require(evidence['sourceRuntimeHash']==d[1][5],'VIEW bundle original Archive runtime')
        payload=originals.raw(evidence['payload'],65536)
        meta=_v(STATE_METADATA,evidence['metadata']);runtime=originals.raw(evidence['runtime'],65537)
        _correspondence(item,keccak256(payload),ZERO,RAW,len(payload))
        require(meta[0]==keccak256(payload) and meta[2]==len(payload) and meta[3]>0
            and runtime==b'\0'+payload,'VIEW bundle original state carrier')
        originals.pin(meta[1],keccak256(runtime))
        expected_parts=_hash(('address','bytes32','bytes32','address','bytes32','bytes32','uint32','uint64'),
            (item[2],evidence['sourceRuntimeHash'],item[3],meta[1],keccak256(runtime),meta[0],meta[2],meta[3]))
        require(parts==expected_parts,'VIEW bundle original state parts hash')
        expected=_domain('STATE_RETAINED_ORIGINAL_AUTHORIZATION',(t.ITEM,'bytes32'),(item,parts))
    elif proof[0]==1 and item[0]!=10:
        _closed(evidence,('object','receipts','fixities','checkpoint'),'external originals')
        require(parts==ZERO and onchain==empty_onchain,'VIEW bundle external-only admission')
        obj=_v(OBJECT,evidence['object']);c=external
        _correspondence(item,obj[3],obj[4],obj[2],obj[6])
        require(obj[0]==artist and (item[10]==ZERO or item[10]==obj[1])
            and (item[11]==ZERO or item[11]==obj[7]) and (item[0]==3 or item[12]==ZERO
                or item[12:14]==obj[8:10]),'VIEW bundle external original object identity')
        require(c[0:3]==(proof[1],proof[2],artist) and c[3:7]==obj[3:7]
            and all(c[i]!=ZERO for i in (7,8,9,10,11,12)) and c[7]!=c[8]
            and c[14]==EXTERNAL_PROFILE,'VIEW bundle external original coverage')
        require(c[1]==external_object_hash(obj,d[2],d[0][4],d[0][0])
            and c[0]==external_coverage_hash(c,d[2],d[0][4]),'VIEW bundle original external identity/coverage hash')
        require(type(evidence['receipts']) is list and len(evidence['receipts'])==2
            and type(evidence['fixities']) is list and len(evidence['fixities'])==2,
            'VIEW bundle external originals denominator')
        hashes=[originals.signed(d[0][4],c[9+i],raw,RECEIPT,'6529STREAM_EXTERNAL_RECEIPT_V1',65536,True,
                    ((0,c[1]),(1,c[7+i]),(3,schema_id('CONTENT_ADDRESSED_INCLUSION' if i==0 else 'ATTESTED_POSSESSION')))
                     + (((5,c[13]),) if i==0 else ()))
                for i,raw in enumerate(evidence['receipts'])]
        hashes += [originals.signed(d[0][4],c[11+i],raw,EXTERNAL_FIXITY,'6529STREAM_EXTERNAL_FIXITY_V1',65536,
                    expected=((0,c[9+i]),(1,c[1]),(2,c[7+i]),
                        (3,decode((RECEIPT,'bytes','bytes'),hex_bytes(evidence['receipts'][i]),maximum=65536)[0][2]),
                        (5,obj[4]),(6,obj[4]),(7,obj[3]),
                        (8,obj[3]),(9,obj[5]),(10,obj[5]),(11,obj[6]),(12,obj[6]),(14,1)))
                   for i,raw in enumerate(evidence['fixities'])]
        locator=decode((RECEIPT,'bytes','bytes'),hex_bytes(evidence['receipts'][0]),maximum=65536)[1]
        hashes.append(originals.native(evidence['checkpoint'],c[13],True,d[0][4],locator,obj[3],obj[6],obj[5]))
        expected=_hash(('address','bytes32',t.ADMISSION[3],('bytes32',)*5),(d[0][4],d[1][4],c,tuple(hashes)))
    elif proof[0]==2 and item[0]!=5:
        _closed(evidence,('artifact','chunks'),'onchain originals')
        require(external==empty_external,'VIEW bundle onchain-only admission')
        c=onchain;a=_v(ARTIFACT,evidence['artifact'])
        require(c[:3]==(proof[1],proof[2],artist) and item[5]==1
            and c[8]!=ZERO and c[9]!=ZERO and c[8]!=c[9]
            and (item[10]==ZERO or item[10]==c[3]),'VIEW bundle original whole-object coverage')
        _correspondence(item,c[5],ZERO,c[4],c[6])
        require(a[0]==artist and a[1:3]==c[3:5] and a[3]==1 and a[4:6]==(c[5],c[6])
            and len(a[6])==len(a[7])==c[7] and 0<c[7]<=64
            and len(encode((ARTIFACT,),(a,)))<=8192
            and type(evidence['chunks']) is list and len(evidence['chunks'])==c[7],
            'VIEW bundle complete original artifact/chunks')
        require(c[1]==artifact_hash(a,d[2],d[0][3],d[0][0]),'VIEW bundle original artifact hash')
        total=0;part_chain=ZERO;bundle_chain=ZERO;whole=[]
        for index,chunk in enumerate(evidence['chunks']):
            _closed(chunk,('pointer','runtime','archive'),'original artifact chunk')
            runtime=originals.raw(chunk['runtime'],8193);digest=keccak256(runtime)
            require(len(runtime)==a[7][index]+1 and runtime[:1]==b'\0'
                and 0<a[7][index]<=8192 and (index+1==c[7] or a[7][index]==8192)
                and keccak256(runtime[1:])==a[6][index],'VIEW bundle original STOP chunk')
            originals.pin(chunk['pointer'],digest);total+=len(runtime)-1
            whole.append(runtime[1:])
            part_chain=_hash(('bytes32','uint32','address','bytes32','bytes32','uint32'),
                (part_chain,index,chunk['pointer'],digest,a[6][index],a[7][index]))
            originals.address_read(d[0][3],'archivalCoverage()',chunk['archive']['host'])
            original=originals.archive(chunk['archive'],artist,a[6][index],c[8],c[9])
            bundle_chain=_hash(('bytes32','uint32','bytes32'),(bundle_chain,index,original))
        require(total==c[6] and parts==part_chain,'VIEW bundle original immutable parts/length')
        require(keccak256(b''.join(whole))==c[5],'VIEW bundle original whole artifact bytes')
        expected=_hash(('address','bytes32',t.ADMISSION[4],ARTIFACT,'bytes32','bytes32'),
            (d[0][3],d[1][3],c,a,part_chain,bundle_chain))
    else:
        raise MuseumError('VIEW bundle unsupported proof backend/kind')
    if proof[0] in (1,2):
        require(proof[1]!=ZERO and proof[2]!=ZERO and (item[14]==ZERO or item[14]==proof[2])
            and (item[15]==ZERO or item[15]==proof[1]),'VIEW bundle original proof identity')
    require(expected==bundle!=ZERO,'VIEW bundle original admission preimage differs')


def validate(value,context,graph,inventory):
    """Require a fully source-validated inventory result; no optional shortcut."""
    try: return _validate(value,context,graph,inventory)
    except MuseumError: raise
    except (KeyError,TypeError,ValueError,IndexError,OverflowError) as exc:
        raise MuseumError('malformed original VIEW bundle coverage') from exc


def _validate(value,context,graph,inventory):
    _closed(value,('profile','dependencies','dependencyHash','evidence','progress','admissions','sourceBindings'),'evidence')
    require(type(inventory) is dict and all(key in inventory for key in
        ('scope','evidence','dependencyHash','items','segments')),'VIEW bundle validated source inventory required')
    d=_v(t.BUNDLE_DEPENDENCIES,value['dependencies']);full=_v(t.INVENTORY_EVIDENCE,inventory['evidence'])
    scope,body=full;e=_v(t.BUNDLE_EVIDENCE,value['evidence']);p=_v(t.BUNDLE_PROGRESS,value['progress'])
    require(value['profile']==PROFILE and d[0]==tuple(graph[k]['address'] for k in DEPENDENCY_ROLES)
        and d[1]==tuple(graph[k]['runtimeHash'] for k in DEPENDENCY_ROLES)
        and d[2]==uint(context['chainId']) and 50000<=d[3]<=d[4]<=MAX_GAS
        and value['dependencyHash']==_hash((t.BUNDLE_DEPENDENCIES,),(d,)), 'VIEW bundle original dependency/profile')
    require(scope==_v(t.SCOPE,inventory['scope']) and scope[0]==4 and scope[1]==uint(context['collectionId'])
        and scope[2]==0 and scope[3]!=ZERO and body[0]!=ZERO and body[1]==scope[1]
        and body[2]==subject_id('scope',context['chainId'],context['core'],context['collectionId'],
            scope_type='4',scope_id=scope[3])
        and body[3]!=ZERO and body[5]!=ZERO and body[6]!=ZERO and body[7]>0 and body[8]>0
        and body[9]>0 and body[10]!=ZERO and body[11]!=ZERO,'VIEW bundle complete original VIEW inventory')
    cleared=list(body);cleared[11]=ZERO
    require(inventory['dependencyHash']!=ZERO and body[11]==_domain(
        '6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1',
        ('uint256','address','bytes32',t.INVENTORY_EVIDENCE),
        (d[2],d[0][2],inventory['dependencyHash'],(scope,tuple(cleared)))),
        'VIEW bundle original source inventory evidence hash')
    require(type(inventory['items']) is list and 0<len(inventory['items'])==body[9]<=MAX_ITEMS
        and type(inventory['segments']) is list and len(inventory['segments'])==body[8]
        and type(value['admissions']) is list and len(value['admissions'])==body[9],
        'VIEW bundle complete source/admission denominator')
    # Source inventory validation owns item derivation and each segment's links.
    # This boundary also checks the exact ordered segment commitment/count.
    segment_chain=ZERO;count=0
    for index,row in enumerate(inventory['segments']):
        segment=_v(t.SEGMENT,row);start=count;count+=segment[1]
        require(segment[0]!=ZERO and segment[3]!=ZERO and (segment[1]==0)==(segment[2]==ZERO),
            'VIEW bundle source segment applicability')
        segment_chain=_domain('6529STREAM_PRESERVATION_SEGMENT_V1',('bytes32','uint64',t.SEGMENT),
            (segment_chain,index,segment))
        require(count<=len(inventory['items']),'VIEW bundle source segment item count')
        link=ZERO
        for offset in range(segment[1]-1,-1,-1):
            link=_domain('6529STREAM_PRESERVATION_ITEM_LINK_V1',
                ('bytes32','uint64','uint64','bytes32','bytes32'),
                (segment[0],segment[1],offset,item_hash(inventory['items'][start+offset]),link))
        require(link==segment[2],'VIEW bundle source segment item links')
    require(count==body[9] and segment_chain==body[10],'VIEW bundle original source segment chain')
    originals=_Originals(context,graph);chain=ZERO
    for index,row in enumerate(value['admissions']):
        _closed(row,('item','admission','sourceEvidence'),'admitted original')
        item=_v(t.ITEM,row['item']);admission=_v(t.ADMISSION,row['admission'])
        require(item==_v(t.ITEM,inventory['items'][index]),'VIEW bundle original item occurrence differs')
        _admission(item,admission,row['sourceEvidence'],d,body[3],originals)
        chain=covered_item(chain,body[0],index,item,admission)
    bindings=value['sourceBindings']
    _closed(bindings,('blockHash','provenance','calls'),'original dependency reads')
    require(bindings['blockHash']==context['blockHash']
        and bindings['provenance'] in ('synthetic_fixture','externally_admitted_rpc')
        and bindings['provenance']==inventory.get('provenance')
        and bindings['calls']==originals.calls,'VIEW bundle exact retained dependency getter evidence')
    require(p[0:6]==(body[8],0,body[9],ZERO,body[10],chain) and p[7],
        'VIEW bundle completed progress differs')
    require(e[0]==scope and e[1][:4]==(body[0],body[11],body[9],chain)
        and e[1][4]==coverage_hash(e,full,d,context['chainId'],graph['bundleCoverage']['address']),
        'VIEW bundle original completed coverage hash')
    return {'scope':json_values(scope),'evidence':json_values(e),'progress':json_values(p),
        'bundleCoverageHash':e[1][4],'renderCriticalEvidenceHash':body[11],'itemCount':str(body[9]),
        'originalAdmissionPreimagesChecked':True,'coverageTrust':'retained_native_admission_observations',
        'originalDependencyGetterEvidenceChecked':True,'sourceProvenance':bindings['provenance'],
        'originalEnvironmentHash':p[6],'originalEnvironmentPreimageVerified':False,
        'currentLivenessVerified':False,'nativeExecutionProven':False,'historicalSignaturesVerified':False,
        'archiveConsensusVerified':False,'qualification':
            'Complete source inventory and retained admission commitment correspondence only. '
            'Recorded coverage and checkpoint observations retain their original native trust; no '
            'current receipt pair, refresh, external possession, signature or consensus proof is inferred.'}
