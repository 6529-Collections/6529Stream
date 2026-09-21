"""Coherent original native captures; no live service, C2PA or examination claims."""
from copy import deepcopy
from dataclasses import asdict, replace
import unittest
from unittest.mock import patch

from . import acquisition_work_condition_v1 as w
from . import metadata_catalog_source as metadata
from . import public_condition_capture as condition_capture
from . import artist_c2pa as c2pa
from . import artist_c2pa_conflicts as conflicts
from . import work_lido_source as work
from .canonical import MuseumError,dumps,loads,hex_bytes,keccak256,schema_id,record_chain
from .chain_abi import calldata,decode,encode
from .independent_wire import ZERO,ZERO_ADDRESS,RAW_BYTES,RAW_DEFINITION,json_values
from .native_finality_wire import from_json
from .test_metadata_catalog_source import Transport
from .test_public_condition_source import PublicConditionFixture
from .test_artist_c2pa import Fixture as C2PAFixture
from tools.metadata import work_profile


def A(n):return '0x'+format(n,'040x')
def H(label):return keccak256(str(label).encode())
def hx(raw):return '0x'+raw.hex()
def native(value):
    if isinstance(value,bytes):return hx(value)
    if isinstance(value,dict):return {k:native(v) for k,v in value.items()}
    if isinstance(value,(tuple,list)):return [native(v) for v in value]
    if type(value) is int:return str(value)
    return value


class MetadataFixture:
    def __init__(self,state,graph,runtimes,rows,policies=None,*,block=None,deployment_hash=None,pointer_for=None):
        self.responses={};self.state=state;self.graph=graph;self.host=graph['metadata']['address']
        self.block=block or {'hash':state['blockHash'],'number':hex(int(state['blockNumber'])),
            'timestamp':hex(int(state['timestamp'])),'stateRoot':state['stateRoot']}
        self.block_ref={'blockHash':state['blockHash'],'requireCanonical':True}
        self.anchor={'profile':metadata.PROFILE,**{k:v for k,v in state.items() if k!='tokenId'},
            'deploymentEvidenceHash':deployment_hash or H('admitted fixture deployment'), 'host':self.host,
            'schemas':graph['schemas']['address'],'store':graph['store']['address'],'artistRegistry':graph['artist']['address'],
            'codePins':[graph[k] for k in ('metadata','core','schemas','store','artist')]}
        self.put('eth_chainId',[],hex(int(state['chainId'])))
        self.put('eth_getBlockByHash',[state['blockHash'],False],self.block)
        for role in ('metadata','core','schemas','store','artist'):
            self.put('eth_getCode',[graph[role]['address'],self.block_ref],runtimes[graph[role]['address']])
        for role,getter in (('core','core'),('schemas','schemaRegistry'),('store','chunkStore'),('artist','artistRegistry')):
            self.call(getter+'()',('address',),(graph[role]['address'],))
            self.call(getter+'CodeHash()',('bytes32',),(graph[role]['runtimeHash'],))
        self.call('chunkStore()',('address',),(graph['store']['address'],),host=graph['schemas']['address'])
        self.call('streamModuleType()',('bytes32',),(schema_id('COLLECTION_METADATA'),))
        self.call('streamModuleVersion()',('bytes32',),(schema_id('6529stream.collection-metadata.full-bytes.v1'),))
        cid=int(state['collectionId']);self.call('collectionExists(uint256)',('bool',),(True,),('uint256',),(cid,),host=state['core'])
        policies=dict(policies or {metadata.WORK:(metadata.CURATOR,(1<<1)|(1<<3)|(1<<8),True),
            schema_id('C2PA_VALIDATION'):(schema_id('6529STREAM_RECORD_FAMILY_C2PA_V1'),(1<<4)|(1<<6)|(1<<8),True),
            schema_id('C2PA_REFERENCE'):(schema_id('6529STREAM_RECORD_FAMILY_C2PA_V1'),(1<<4)|(1<<6)|(1<<8),True)})
        if {r[1][0] for r in rows}-set(policies):raise MuseumError('fixture needs original Metadata policy for every retained type')
        self.call('recordTypeCount()',('uint256',),(len(policies),))
        pointers={}
        for i,(rt,policy) in enumerate(policies.items()):
            self.call('recordTypeAt(uint256)',('bytes32',),(rt,),('uint256',),(i,))
            self.call('recordPolicy(bytes32)',(metadata.POLICY,),(policy,),('bytes32',),(rt,))
            lane=sorted((r for r in rows if r[1][0]==rt),key=lambda r:r[2][4])
            self.call('recordChainHash(uint256,bytes32)',('bytes32','uint64'),(lane[-1][2][5] if lane else ZERO,len(lane)),('uint256','bytes32'),(cid,rt))
            latest={}
            for digest,record,receipt,payload in lane:
                index=receipt[4];latest[(record[1],receipt[1])]=digest
                self.call('recordHashAt(uint256,bytes32,uint256)',('bytes32',),(digest,),('uint256','bytes32','uint256'),(cid,rt,index))
                self.call('collectionRecord(bytes32)',(metadata.RECORD,metadata.RECEIPT),(record,receipt),('bytes32',),(digest,))
                self.call('collectionRecordReceipt(bytes32)',(metadata.RECEIPT,),(receipt,),('bytes32',),(digest,))
                pointer=pointers.setdefault((policy[0],keccak256(payload)),pointer_for(payload) if pointer_for else A(20000+len(pointers)))
                self.call('recordPayload(bytes32)',('address','bytes'),(pointer,payload),('bytes32',),(digest,))
                self.call('chunk(bytes32)',('address','uint32'),(pointer,len(payload)),('bytes32',),(keccak256(payload),),host=graph['store']['address'])
                self.put('eth_getCode',[pointer,self.block_ref],hx(b'\0'+payload))
                if receipt[8]!=ZERO:self.call('consumedArtistAuthorization(bytes32)',('bool',),(True,),('bytes32',),(receipt[8],))
            for (sid,recorder),digest in latest.items():self.call('latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)',('bytes32',),(digest,),('uint256','bytes32','bytes32','address'),(cid,rt,sid,recorder))
        self.call('payloadPointerCount(uint256)',('uint256',),(len(pointers),),('uint256',),(cid,))
        for i,((family,digest),pointer) in enumerate(pointers.items()):self.call('payloadPointerAt(uint256,uint256)',('address','bytes32','bytes32'),(pointer,family,digest),('uint256','uint256'),(cid,i))

    def put(self,method,params,result):self.responses[dumps([method,params])]=result
    def call(self,sig,outputs,values,inputs=(),args=(),host=None):
        self.put('eth_call',[{'to':host or self.host,'data':calldata(sig,inputs,args),'gas':'0x1312d00'},self.block_ref],hx(encode(outputs,values)))
    def capture(self):
        source=metadata.MetadataCatalogSource(dumps(self.anchor),Transport(self.responses));snapshot=source.snapshot()
        files={'anchor.json':source.anchor_bytes,'transcript.json':source.transcript(),'snapshot.json':snapshot,'profile.json':metadata.PROFILE_BYTES}
        pins={'profileHash':metadata.PROFILE_HASH,'anchorHash':keccak256(source.anchor_bytes),'snapshotHash':keccak256(snapshot),
            'transcriptHash':keccak256(source.transcript()),'provenance':'synthetic_fixture','actualChainAcceptance':False}
        files['pins.json']=dumps(pins);return files,pins


def _scope():
    return {'current':hx(encode((c2pa.SELECTION,),(w._zero(c2pa.SELECTION),))), 'selections':[],
        'display':hx(encode((c2pa.DISPLAY,),(w._zero(c2pa.DISPLAY),))), 'reports':[],
        'standing':hx(encode((conflicts.STANDING,),(conflicts.EMPTY_STANDING,))), 'history':[],'acknowledgements':[]}


def events(e):
    result=[];descriptors=w.expected_events(e);groups={};conflict_times={}
    for lane in ('collection','token'):
        for row in e['c2pa'][lane]['history']:
            r=decode((conflicts.CONFLICT,),hex_bytes(row['record']))[0];conflict_times[r[6]]=str(r[11])
    for i,desc in enumerate(descriptors):
        topic=desc['topics'][0];key=('other',i)
        if topic==schema_id('C2PAReconciliationSelected(uint256,bytes32,bytes32,'+w.signature(c2pa.SELECTION)+')') or topic==schema_id('C2PAAttributionDivergence(uint256,bytes32,bytes32,bytes32,bytes32)'):
            key=('adopt',desc['topics'][3])
        elif topic==schema_id('C2PAConflictRecorded(bytes32,uint256,bytes32,'+w.signature(conflicts.CONFLICT)+')'):
            key=('adopt',decode((conflicts.CONFLICT,),hex_bytes(desc['data']))[0][6])
        tx_index=groups.setdefault(key,len(groups))
        stamp=desc['timestamp'] or conflict_times.get(key[1],e['sourceState']['timestamp'])
        block=int(e['sourceState']['blockNumber'])-(int(e['sourceState']['timestamp'])-int(stamp))
        block=max(0,block)
        block_hash=e['sourceState']['blockHash'] if block==int(e['sourceState']['blockNumber']) else H('condition-block-'+str(block))
        result.append({'timestamp':stamp,'log':{'address':desc['address'],'topics':desc['topics'],'data':desc['data'],
            'blockNumber':hex(block),'blockHash':block_hash,
            'transactionHash':H('work-c2pa event '+str(tx_index)),'transactionIndex':hex(tx_index),'logIndex':hex(i)}})
    e['events']=sorted(result,key=lambda x:(int(x['log']['blockNumber'],16),int(x['log']['transactionIndex'],16),int(x['log']['logIndex'],16)))
    counts={}
    for row in e['events']:
        block=row['log']['blockNumber'];index=counts.setdefault(block,0);row['log']['logIndex']=hex(index);counts[block]+=1


def supplied(*,tombstone=False,empty=False,c2pa_present=False,condition=True,unsupported=False,
        source_state=None,graph=None,runtime_bytes=None,original_metadata_rows=(),original_metadata_policies=None,
        condition_capture_input=None):
    cf=PublicConditionFixture(unsupported_newest=unsupported)
    cs=cf.source();cs.snapshot();cond=condition_capture.replay(cs.anchor_bytes,keccak256(cs.anchor_bytes),condition_capture._source().PROFILE_HASH,
        cs.transcript(),keccak256(cs.transcript()),provenance='synthetic_fixture',disclosure='public')
    state=deepcopy(source_state) if source_state is not None else {k:cf.a[k] for k in w.STATE_KEYS}
    roles={'core':cf.core,'metadata':A(100),'schemas':cf.schemas,'store':cf.store,'artist':A(101),
        'work':A(102),'c2pa':A(103),'router':A(104),'verifier':A(105),'attribution':A(106)}
    if graph is not None:
        graph=deepcopy(graph);roles={k:graph[k]['address'] for k in w.GRAPH_KEYS}
        if runtime_bytes is None:raise MuseumError('custom graph requires original runtime bytes')
        codes={address:runtime_bytes[address] for address in roles.values()}
    else:
        roles['core']=state['core']
        codes={address:cf.codes.get(address,b'synthetic work/C2PA '+role.encode()) for role,address in roles.items()}
        graph={role:{'address':address,'runtimeHash':keccak256(codes[address])} for role,address in roles.items()}
    runtimes={address:hx(raw) for address,raw in codes.items()}
    pointer=(roles['metadata'],graph['metadata']['runtimeHash'],False,schema_id('COLLECTION_METADATA'),'0x01020304',A(999),1,H('manifest'),H('deployment'),1)
    e={'profileHash':w.PROFILE_HASH,'sourceReviewCommit':w.SOURCE_REVISION,'sourceState':state,'graph':graph,'runtimes':runtimes,
        'metadataPointer':json_values(pointer),'identity':[True,state['collectionId'],'1',False],
        'work':{lane:{'current':hx(encode((w.WORK_SELECTION,),(w._zero(w.WORK_SELECTION),))),'history':[]} for lane in ('collection','token')},
        'c2pa':{'collection':_scope(),'token':_scope(),'artists':[],'identityDocuments':{}},
        'sourceBindings':{'blockHash':state['blockHash'],'provenance':'synthetic_fixture','calls':[]},'events':[]}
    rows=deepcopy(list(original_metadata_rows));stamp=int(state['timestamp'])
    if stamp<3:raise MuseumError('synthetic fixture requires timestamp >=3')
    if not empty:
        sid=w._subject(state,'token');meaning=deepcopy(work_profile.examples()[1 if tombstone else 0]);meaning.update(subjectId=sid,predecessor=None,profileHash=work.WORK_PROFILE_HASH)
        payload=dumps(meaning);record=(metadata.WORK,sid,(1,hex_bytes(keccak256(payload)),schema_id('RFC8785_JCS')),'ipfs://original-work',schema_id('STREAM_WORK_DESCRIPTION_V1'),ZERO,(0,b'',ZERO),stamp-2)
        digest=metadata.generic_hash(int(state['chainId']),roles['metadata'],state['core'],int(state['collectionId']),A(110),record)
        lane=sorted((r for r in rows if r[1][0]==metadata.WORK),key=lambda r:r[2][4]);index=len(lane)
        receipt=(int(state['collectionId']),A(110),3,stamp-1,index,record_chain(state['chainId'],roles['metadata'],state['collectionId'],metadata.WORK,lane[-1][2][5] if lane else ZERO,digest,str(index)),work.WORK_SCHEMA_HASH,w.work_native.WORK_CANON_HASH,ZERO)
        rows.append((digest,record,receipt,payload))
        selected=list(w._zero(w.WORK_SELECTION));selected[:17]=[digest,ZERO,keccak256(payload),A(111),1,int(state['collectionId']),1,1,index,receipt[5],stamp,3,A(110),3,int(tombstone),0 if tombstone else 1,(ZERO,ZERO,0,ZERO)]
        selected[21]=keccak256(encode(('bytes32','uint256',*('address',)*5,'uint256','bytes32',w.WORK_SELECTION),
            (schema_id('6529STREAM_WORK_SELECTION_V1'),int(state['chainId']),roles['work'],*(roles[k] for k in ('core','metadata','schemas','store')),int(state['collectionId']),sid,tuple(selected))))
        raw=hx(encode((w.WORK_SELECTION,),(tuple(selected),)))
        e['work']['token']={'current':raw,'history':[{'selection':raw,'catalog':None,'artistPublication':None}]}
    if c2pa_present:
        f=C2PAFixture();f.subject=w._subject(state,'token')
        f.context=c2pa.Context(int(state['chainId']),roles['c2pa'],state['core'],roles['metadata'],roles['artist'],roles['router'],roles['verifier'],int(state['collectionId']),f.subject,int(state['blockNumber']),state['blockHash'])
        report=f.report(ZERO,keccak256(dumps(f.identity['c2paCredentials'])))
        lane=sorted((r for r in rows if r[1][0]==schema_id('C2PA_VALIDATION')),key=lambda r:r[2][4]);index=len(lane)
        raw,original,selected=f.selection(report,index=index)
        record,receipt=decode((metadata.RECORD,metadata.RECEIPT),original.record);receipt=list(receipt)
        receipt[3]=stamp-1;receipt[5]=record_chain(state['chainId'],roles['metadata'],state['collectionId'],record[0],lane[-1][2][5] if lane else ZERO,selected[0],str(index));receipt=tuple(receipt)
        original=replace(original,record=encode((metadata.RECORD,metadata.RECEIPT),(record,receipt)))
        rows.append((selected[0],record,receipt,original.payload))
        scope=e['c2pa']['token'];scope.update(current=hx(raw),selections=[hx(raw)],display=hx(f.display(selected)),reports=[native(asdict(original))])
        e['c2pa']['artists']=[{'artistId':f.artist,'currentHead':hx(encode((c2pa.HEAD,),(w._zero(c2pa.HEAD),))),'history':[],'personhood':hx(f.empty_personhood())}]
        e['c2pa']['identityDocuments']={f.identity_hash:hx(f.identity_raw)}
    files,pins=MetadataFixture(state,graph,runtimes,rows,original_metadata_policies,
        deployment_hash=cf.a['deploymentEvidenceHash'],
        block=deepcopy(cf.blocks[int(state['blockNumber'])]) if source_state is None else None).capture();events(e)
    if condition_capture_input is not None:cond=condition_capture_input
    elif source_state is not None and condition:raise MuseumError('custom source state requires matching original condition capture or condition=False')
    kwargs={'metadata_files':files,'metadata_pins':pins,'condition_files':dict(cond.files) if condition else None,'condition_manifest_hash':cond.manifest_hash if condition else None}
    e['sourceBindings']['calls']=w.expected_calls(e,**kwargs)
    return e,kwargs


def from_captures(*,metadata_files,metadata_pins,condition_files,condition_manifest_hash,
        source_state,graph,runtime_bytes,metadata_pointer,identity,work_evidence,c2pa_evidence,event_rows):
    """Assemble explicit native seam evidence over unchanged coherent captures."""
    e={'profileHash':w.PROFILE_HASH,'sourceReviewCommit':w.SOURCE_REVISION,'sourceState':deepcopy(source_state),
        'graph':deepcopy(graph),'runtimes':{a:hx(runtime_bytes[a]) for a in {p['address'] for p in graph.values()}},
        'metadataPointer':json_values(metadata_pointer),'identity':json_values(identity),
        'work':deepcopy(work_evidence),'c2pa':deepcopy(c2pa_evidence),'events':deepcopy(event_rows),
        'sourceBindings':{'blockHash':source_state['blockHash'],'provenance':'synthetic_fixture' if metadata_pins['provenance']=='synthetic_fixture' else 'externally_admitted_rpc','calls':[]}}
    kwargs={'metadata_files':metadata_files,'metadata_pins':metadata_pins,'condition_files':condition_files,'condition_manifest_hash':condition_manifest_hash}
    e['sourceBindings']['calls']=w.expected_calls(e,**kwargs)
    return e,kwargs


def _rows(kwargs):
    snap=loads(kwargs['metadata_files']['snapshot.json'],maximum=w.MAX_BYTES)
    return [(r['recordHash'],from_json(metadata.RECORD,r['record']),from_json(metadata.RECEIPT,r['receipt']),hex_bytes(r['payloadHex'])) for r in snap['records']]


def _recapture(e,kwargs,rows,*,derive=True):
    files=kwargs['metadata_files'];snap=loads(files['snapshot.json'],maximum=w.MAX_BYTES)
    policies={r['recordType']:(r['family'],int(r['authorizationMask']),r['admitted']) for r in snap['catalog']}
    anchor=loads(files['anchor.json']);old=loads(files['transcript.json'],maximum=w.MAX_BYTES)
    block=next(r['result'] for r in old['calls'] if r['method']=='eth_getBlockByHash')
    files,pins=MetadataFixture(e['sourceState'],e['graph'],e['runtimes'],rows,policies,
        block=block,deployment_hash=anchor['deploymentEvidenceHash']).capture()
    kwargs.update(metadata_files=files,metadata_pins=pins);events(e)
    if derive:e['sourceBindings']['calls']=w.expected_calls(e,**kwargs)


def artist_work(e,kwargs,*,named=False,identity=H('operative work identity'),publication_binding=None,derive=True):
    """Rebuild original Metadata and retained Artist publication before selection."""
    rows=_rows(kwargs);state=e['sourceState'];cid=int(state['collectionId']);stamp=int(state['timestamp'])
    old=decode((w.WORK_SELECTION,),hex_bytes(e['work']['token']['current']))[0]
    old_row=next(r for r in rows if r[0]==old[0]);meaning=loads(old_row[3]);aid,binding,generation=H('work Artist'),H('work binding'),2
    if not named:meaning['creator']={'kind':'artist','artistId':aid,'association':{'bindingHash':binding,'bindingGeneration':str(generation)}}
    payload=dumps(meaning);record=list(old_row[1]);record[2]=(1,hex_bytes(keccak256(payload)),schema_id('RFC8785_JCS'));record=tuple(record)
    digest=metadata.generic_hash(int(state['chainId']),e['graph']['metadata']['address'],state['core'],cid,A(110),record)
    authorization=H('work original op24');receipt=list(old_row[2]);receipt[2]=1;receipt[8]=authorization
    receipt[5]=record_chain(state['chainId'],e['graph']['metadata']['address'],state['collectionId'],metadata.WORK,ZERO,digest,'0');receipt=tuple(receipt)
    publication=(e['graph']['metadata']['address'],receipt[1],cid,record[1],record[0],record[4],record[2][2],1,keccak256(payload),keccak256(record[3].encode()),record[7],digest)
    evidence=(authorization,aid,publication_binding or binding,generation,receipt[1],1,1,stamp-2,keccak256(encode((w.artist_native.PUBLICATION,),(publication,))))
    saved=(publication,evidence,e['graph']['metadata']['runtimeHash']);statement=encode(('uint16',w.artist_native.PUBLICATION),(1,publication))
    att=(authorization,ZERO,schema_id('6529STREAM_ARTIST_RECORD_PUBLICATION_V1'),keccak256(statement),generation,stamp-2,receipt[1])
    s=list(old);s[0]=digest;s[2]=keccak256(payload);s[9]=receipt[5];s[13]=1;s[15]=1 if named else 0
    s[16]=(ZERO,ZERO,0,ZERO) if named else (aid,binding,generation,identity)
    s[17]=evidence;s[18]=keccak256(encode((w.artist_native.PUBLICATION_RECORD,),(saved,)));s[21]=ZERO
    s[21]=keccak256(encode(('bytes32','uint256',*('address',)*5,'uint256','bytes32',w.WORK_SELECTION),
        (schema_id('6529STREAM_WORK_SELECTION_V1'),int(state['chainId']),e['graph']['work']['address'],
         *(e['graph'][k]['address'] for k in ('core','metadata','schemas','store')),cid,record[1],tuple(s))))
    raw=hx(encode((w.WORK_SELECTION,),(tuple(s),)));e['work']['token']['current']=raw
    e['work']['token']['history'][0].update(selection=raw,artistPublication={'publication':json_values(saved),'attestation':json_values(att),'statement':hx(statement)})
    _recapture(e,kwargs,[(digest,record,receipt,payload) if r[0]==old[0] else r for r in rows],derive=derive)


def append_work(e,kwargs,*,tombstone=False,catalog=False):
    rows=_rows(kwargs);old=decode((w.WORK_SELECTION,),hex_bytes(e['work']['token']['current']))[0]
    state=e['sourceState'];cid=int(state['collectionId']);sid=w._subject(state,'token');stamp=int(state['timestamp'])
    examples=work_profile.examples();meaning=deepcopy(examples[1 if tombstone else 2 if catalog else 0])
    meaning.update(predecessor=old[0],profileHash=work.WORK_PROFILE_HASH,subjectId=sid)
    cat=dumps(examples[3]) if catalog else None
    if catalog:meaning['creator']={'kind':'named','name':'Explicit catalog creator'}
    payload=dumps(meaning);r=(metadata.WORK,sid,(1,hex_bytes(keccak256(payload)),schema_id('RFC8785_JCS')),
        'ipfs://second-original-work',schema_id('STREAM_WORK_DESCRIPTION_V1'),ZERO,(0,b'',ZERO),stamp-1)
    digest=metadata.generic_hash(int(state['chainId']),e['graph']['metadata']['address'],state['core'],cid,A(110),r)
    lane=sorted((r for r in rows if r[1][0]==metadata.WORK),key=lambda r:r[2][4]);index=len(lane)
    receipt=(cid,A(110),3,stamp,index,record_chain(state['chainId'],e['graph']['metadata']['address'],state['collectionId'],metadata.WORK,lane[-1][2][5],digest,str(index)),work.WORK_SCHEMA_HASH,w.work_native.WORK_CANON_HASH,ZERO)
    rows.append((digest,r,receipt,payload));s=list(old)
    s[0:3]=[digest,old[0],keccak256(payload)];s[7:11]=[old[7]+1,index,receipt[5],stamp]
    s[14:17]=[int(tombstone),0 if tombstone else 1,(ZERO,ZERO,0,ZERO)]
    s[19:21]=[meaning['format']['catalog']['documentId'],keccak256(cat)] if catalog else [ZERO,ZERO];s[21]=ZERO
    s[21]=keccak256(encode(('bytes32','uint256',*('address',)*5,'uint256','bytes32',w.WORK_SELECTION),
        (schema_id('6529STREAM_WORK_SELECTION_V1'),int(state['chainId']),e['graph']['work']['address'],
            *(e['graph'][k]['address'] for k in ('core','metadata','schemas','store')),cid,sid,tuple(s))))
    raw=hx(encode((w.WORK_SELECTION,),(tuple(s),)));e['work']['token']['current']=raw
    e['work']['token']['history'].append({'selection':raw,'catalog':None if cat is None else hx(cat),'artistPublication':None})
    _recapture(e,kwargs,rows)


def add_adverse_c2pa_history(e,kwargs):
    from .test_artist_c2pa_conflicts import Fixture as ConflictFixture
    state=e['sourceState'];g=e['graph'];stamp=int(state['timestamp']);f=C2PAFixture();f.subject=w._subject(state,'token')
    f.context=c2pa.Context(int(state['chainId']),g['c2pa']['address'],state['core'],g['metadata']['address'],g['artist']['address'],
        g['router']['address'],g['verifier']['address'],int(state['collectionId']),f.subject,int(state['blockNumber']),state['blockHash'])
    fixture=ConflictFixture(constant_recorded_at=stamp-1);fixture.base=f
    rows=_rows(kwargs);previous=ZERO;selections=[];reports=[];history=[]
    for index,adverse in enumerate((True,False)):
        report=f.report(ZERO,keccak256(dumps(f.identity['c2paCredentials'])),claimHash=H('adverse claim '+str(index)),
            authorship=2 if adverse else 1,assertsAuthorship=True)
        raw,evidence,s=f.selection(report,previous=previous,revision=index+1,index=index)
        record,receipt=decode((metadata.RECORD,metadata.RECEIPT),evidence.record);receipt=list(receipt)
        receipt[3]=stamp-1;receipt[5]=record_chain(state['chainId'],g['metadata']['address'],state['collectionId'],record[0],
            next((r[2][5] for r in reversed(rows) if r[1][0]==record[0]),ZERO),s[0],str(index));receipt=tuple(receipt)
        evidence=replace(evidence,record=encode((metadata.RECORD,metadata.RECEIPT),(record,receipt)))
        rows.append((s[0],record,receipt,evidence.payload));selections.append(hx(raw));reports.append(native(asdict(evidence)));previous=s[2]
        if adverse:
            conflict=fixture.conflict(s,1,ZERO,ZERO)
            history.append(native(asdict(conflicts.ConflictEvidence(encode(('bytes32',),(conflict[0],)),encode((conflicts.CONFLICT,),(conflict,)),
                encode((conflicts.RESOLUTION,),(conflicts.EMPTY_RESOLUTION,)),encode(('bytes',),(fixture.narrative(conflict),))))))
    standing=(conflict[0],conflict[9],conflict[6],conflict[7],1,1)
    e['c2pa']['token'].update(current=selections[-1],selections=selections,reports=reports,history=history,
        display=hx(f.display(s,current=False,validation=0,authorship=0)),standing=hx(encode((conflicts.STANDING,),(standing,))))
    e['c2pa']['artists']=[{'artistId':f.artist,'currentHead':hx(encode((c2pa.HEAD,),(w._zero(c2pa.HEAD),))),'history':[],'personhood':hx(f.empty_personhood())}]
    e['c2pa']['identityDocuments']={f.identity_hash:hx(f.identity_raw)}
    _recapture(e,kwargs,rows)


def title_case(base=None):
    """Build before capture on one TitleV5 response map; condition is explicitly missing.

    Return (verified title Assembly, evidence dict, verify keyword arguments).
    The eleven title source histories are untouched; Metadata catalogue reads
    preserve their originals and add a new native WORK selection before capture.
    """
    from .title_v5_fixture import TitleV5Fixture
    from . import acquisition_title_v5 as title
    f=base if base is not None else TitleV5Fixture();state={**{k:f.a[k] for k in w.STATE_KEYS if k in f.a},'tokenId':'41'}
    # Build an actual native Metadata policy before any capture. The frozen
    # old Master source retains this row with its stricter eligibility warning.
    f.add(A(1),'recordPolicy(bytes32)',('bytes32',),(schema_id('MEDIA_RELATIONSHIP'),),
        (metadata.POLICY,),((schema_id('6529STREAM_RECORD_FAMILY_MEDIA_RELATIONSHIP_V1'),(1<<6)|(1<<7),True),))
    graph_roles={'core':f.core,'metadata':A(1),'schemas':A(3),'store':A(4),'router':A(5),
        'artist':decode(('address',),hex_bytes(f.responses[(A(1),calldata('artistRegistry()'))]))[0],
        'work':A(81001),'c2pa':A(81002),'verifier':A(81003),'attribution':A(81004)}
    for role,address in graph_roles.items():
        if address not in f.codes:f.codes[address]=b'synthetic title WORK/C2PA '+role.encode();f.pins[address]=keccak256(f.codes[address])
    graph={role:{'address':a,'runtimeHash':keccak256(f.codes[a])} for role,a in graph_roles.items()}
    rows=[];policies={}
    selector=calldata('collectionRecord(bytes32)',('bytes32',),(ZERO,))[:10]
    for (host,call),answer in list(f.responses.items()):
        if host!=A(1) or not call.startswith(selector):continue
        digest=call[10:];digest='0x'+digest
        record,receipt=decode((metadata.RECORD,metadata.RECEIPT),hex_bytes(answer))
        indexed=f.responses.get((A(1),calldata('recordHashAt(uint256,bytes32,uint256)',('uint256','bytes32','uint256'),(int(state['collectionId']),record[0],receipt[4]))))
        if indexed is not None and decode(('bytes32',),hex_bytes(indexed))[0]!=digest:continue
        chunk=f.responses[(A(4),calldata('chunk(bytes32)',('bytes32',),(keccak256(bytes(record[2][1])) if record[2][0]!=1 else hx(record[2][1]),)))]
        pointer,_=decode(('address','uint32'),hex_bytes(chunk));payload=f.codes[pointer][1:]
        rows.append((digest,record,receipt,payload))
        policy=f.responses.get((A(1),calldata('recordPolicy(bytes32)',('bytes32',),(record[0],))))
        fallback=metadata.ARTIST if record[0] in metadata.ARTIST_SCHEMAS and record[0]!=metadata.WORK else schema_id('6529STREAM_RECORD_FAMILY_RIGHTS_V1') if record[0]==schema_id('RIGHTS_STATEMENT') else metadata.CURATOR
        policies[record[0]]=decode((metadata.POLICY,),hex_bytes(policy))[0] if policy else (fallback,1<<receipt[2],True)
    for rt,policy in ((metadata.WORK,(metadata.CURATOR,(1<<1)|(1<<3)|(1<<8),True)),
            *( (rt,(schema_id('6529STREAM_RECORD_FAMILY_C2PA_V1'),(1<<4)|(1<<6)|(1<<8),True)) for rt in w.C2PA_TYPES)):
        policies.setdefault(rt,policy)
    e,kw=supplied(condition=False,source_state=state,graph=graph,runtime_bytes=f.codes,
        original_metadata_rows=rows,original_metadata_policies=policies)
    # Reuse actual Store pointers and full original header, never a second header projection.
    snap=loads(kw['metadata_files']['snapshot.json'],maximum=w.MAX_BYTES)
    all_rows=[(r['recordHash'],from_json(metadata.RECORD,r['record']),from_json(metadata.RECEIPT,r['receipt']),hex_bytes(r['payloadHex'])) for r in snap['records']]
    def pointer_for(raw):
        digest=f.chunk(raw)
        return decode(('address','uint32'),hex_bytes(f.responses[(A(4),calldata('chunk(bytes32)',('bytes32',),(digest,)))]))[0]
    mf=MetadataFixture(state,graph,e['runtimes'],all_rows,policies,
        block=deepcopy(f.blocks[state['blockHash']]),deployment_hash=f.a['deploymentEvidenceHash'],pointer_for=pointer_for)
    for rawkey,answer in mf.responses.items():
        method,params=loads(rawkey)
        if method=='eth_call':
            key=(params[0]['to'],params[0]['data'])
            if key in f.responses and f.responses[key]!=answer:raise MuseumError('title fixture existing getter would change: '+str(key))
            f.responses[key]=answer
        elif method=='eth_getCode':
            code=hex_bytes(answer)
            if params[0] in f.codes and f.codes[params[0]]!=code:raise MuseumError('title fixture existing runtime would change')
            f.codes[params[0]]=code
    pointer=decode((w.POINTER,),hex_bytes(f.responses[(f.core,calldata('getSatellitePointer(bytes32)',('bytes32',),(w.COLLECTION_METADATA,)))]))[0]
    identity=decode(('bool','uint256','uint256','bool'),hex_bytes(f.responses[(f.core,calldata('tokenCollectionIdentity(uint256)',('uint256',),(41,)))]))
    e['metadataPointer']=json_values(pointer);e['identity']=json_values(identity)
    e['events']=[]
    for desc in w.expected_events(e):
        log=f.event(5,desc['address'],desc['topics'],(),())
        log['data']=desc['data'];e['events'].append({'log':{k:v for k,v in log.items() if k!='removed'},'timestamp':state['timestamp']})
    mf.block=deepcopy(f.blocks[state['blockHash']]);mf.put('eth_getBlockByHash',[state['blockHash'],False],mf.block)
    files,pins=mf.capture();kw={'metadata_files':files,'metadata_pins':pins,'condition_files':None,'condition_manifest_hash':None}
    e['sourceBindings']['calls']=w.expected_calls(e,**kw)
    for row in e['sourceBindings']['calls']:
        key=(row['target'],row['calldata'])
        if key in f.responses and f.responses[key]!=row['result']:raise MuseumError('title native seam would change existing getter')
        f.responses[key]=row['result']
    prior,accession=f.title_inputs()
    package=title.compose(dict(prior.files),prior.manifest_hash,dict(accession.files),accession.manifest_hash,disclosure='public')
    title.verify(dict(package.files),package.manifest_hash)
    w.verify(dumps(e),**kw)
    return package,e,kw


class WorkConditionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.baseline=supplied(c2pa_present=True)

    def test_replay_all_three_sources_and_preserve_authorities(self):
        e,kwargs=deepcopy(self.baseline)
        with patch('socket.socket',side_effect=AssertionError('offline')):result=w.verify(dumps(e),**kwargs)
        self.assertEqual(len(result.observations['rpcSources']),2)
        self.assertFalse(result.report['claims']['c2paCryptographyVerified'])
        self.assertEqual(result.report['items']['14']['applicableRecords'],'1')
        condition=loads(result.files['work-condition/condition.json'],maximum=w.MAX_BYTES)
        self.assertEqual(len(condition['records']),5)
        self.assertEqual(condition['selections']['owner']['status'],'present')
        refs=loads(result.files['work-condition/reference-occurrences.json'],maximum=w.MAX_BYTES)
        self.assertTrue(any('/render/acceptance/referenceRender' in r['jsonPointer'] for r in refs))
        self.assertTrue(any('/protocolState/observation' in r['jsonPointer'] for r in refs))

    def test_authored_tombstone_is_distinct_from_absent_selection(self):
        for empty,tombstone,status in ((False,True,'description_absent'),(True,False,'none_selected')):
            e,kwargs=supplied(empty=empty,tombstone=tombstone)
            result=w.verify(dumps(e),**kwargs)
            self.assertEqual(result.report['items']['12']['token'],status)
            self.assertEqual(result.report['items']['14']['status'],'none_in_complete_pinned_scopes')

    def test_unsupported_latest_condition_stays_selected_and_missing_stays_missing(self):
        for kwargs_fixture in ({'unsupported':True},{'condition':False}):
            e,kwargs=supplied(**kwargs_fixture);result=w.verify(dumps(e),**kwargs)
            value=loads(result.files['work-condition/condition.json'],maximum=w.MAX_BYTES)
            if kwargs_fixture.get('unsupported'):self.assertEqual(value['selections']['owner']['status'],'selected_unresolved')
            else:self.assertEqual(value['status'],'source_missing')

    def test_rehashed_work_hash_does_not_override_original_receipt(self):
        e,kwargs=deepcopy(self.baseline);s=list(decode((w.WORK_SELECTION,),hex_bytes(e['work']['token']['current']))[0])
        s[13]=8;s[21]=ZERO
        s[21]=keccak256(encode(('bytes32','uint256',*('address',)*5,'uint256','bytes32',w.WORK_SELECTION),
            (schema_id('6529STREAM_WORK_SELECTION_V1'),int(e['sourceState']['chainId']),e['graph']['work']['address'],
             *(e['graph'][k]['address'] for k in ('core','metadata','schemas','store')),int(e['sourceState']['collectionId']),w._subject(e['sourceState'],'token'),tuple(s))))
        e['work']['token']['current']=e['work']['token']['history'][0]['selection']=hx(encode((w.WORK_SELECTION,),(tuple(s),)))
        events(e)
        with self.assertRaisesRegex(MuseumError,'receipt/payload'):w.expected_calls(e,**kwargs)

    def test_complete_head_and_event_denominators_cannot_be_omitted(self):
        for mode in ('history','event','getter','c2pa_history','original','event_slot','identity','runtime','provenance'):
            e,kwargs=deepcopy(self.baseline)
            if mode=='history':e['work']['token']['history']=[]
            elif mode=='event':e['events'].pop()
            elif mode=='getter':e['sourceBindings']['calls'].pop()
            elif mode=='c2pa_history':e['c2pa']['token']['selections']=[];e['c2pa']['token']['reports']=[]
            elif mode=='original':e['c2pa']['token']['reports'][0]['payload']=hx(b'other bytes')
            elif mode=='event_slot':e['events'][1]['log'].update({k:e['events'][0]['log'][k] for k in ('blockNumber','blockHash','transactionHash','transactionIndex','logIndex')})
            elif mode=='identity':e['identity'][1]='999'
            elif mode=='runtime':e['runtimes'][e['graph']['core']['address']]=hx(b'contradictory core')
            else:e['sourceBindings']['provenance']='externally_admitted_rpc'
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.verify(dumps(e),**kwargs)

    def test_condition_and_metadata_bytes_are_replayed_not_rehashed_assertions(self):
        e,kwargs=deepcopy(self.baseline)
        snapshot=loads(kwargs['metadata_files']['snapshot.json'],maximum=w.MAX_BYTES);snapshot['records'].pop()
        kwargs['metadata_files']['snapshot.json']=dumps(snapshot);kwargs['metadata_pins']['snapshotHash']=keccak256(dumps(snapshot))
        kwargs['metadata_files']['pins.json']=dumps(kwargs['metadata_pins'])
        with self.assertRaisesRegex(MuseumError,'Metadata replay'):w.verify(dumps(e),**kwargs)

    def test_same_header_hash_cannot_hide_conflicting_original_rpc_bytes(self):
        e,kwargs=deepcopy(self.baseline);files=kwargs['metadata_files']
        snapshot=loads(files['snapshot.json'],maximum=w.MAX_BYTES);anchor=loads(files['anchor.json'])
        transcript=loads(files['transcript.json'],maximum=w.MAX_BYTES)
        block=deepcopy(next(r['result'] for r in transcript['calls'] if r['method']=='eth_getBlockByHash'))
        block['transactions']=[H('different original transaction list')]
        policies={r['recordType']:(r['family'],int(r['authorizationMask']),r['admitted']) for r in snapshot['catalog']}
        new_files,pins=MetadataFixture(e['sourceState'],e['graph'],e['runtimes'],_rows(kwargs),policies,
            block=block,deployment_hash=anchor['deploymentEvidenceHash']).capture()
        kwargs.update(metadata_files=new_files,metadata_pins=pins)
        with self.assertRaisesRegex(MuseumError,'original RPC observation conflict'):w.verify(dumps(e),**kwargs)

    def test_artist_creator_and_publication_share_original_association(self):
        e,kwargs=supplied(condition=False);artist_work(e,kwargs)
        result=w.verify(dumps(e),**kwargs)
        value=loads(result.files['work-condition/work.json'],maximum=w.MAX_BYTES)
        self.assertEqual(value['token']['history'][0]['semantic']['creator']['kind'],'artist')
        self.assertFalse(result.report['claims']['workArtistOwnerRuntimeAuthenticated'])
        for changes,reason in (({'named':True},'creator/publication'),({'identity':ZERO},'creator association'),
                ({'publication_binding':H('other original binding')},'creator/publication')):
            bad,kw=supplied(condition=False);artist_work(bad,kw,derive=False,**changes)
            with self.subTest(changes=changes),self.assertRaisesRegex(MuseumError,reason):w.expected_calls(bad,**kw)

    def test_work_history_catalog_and_tombstone_preserve_original_meaning(self):
        e,kwargs=supplied(condition=False);append_work(e,kwargs,catalog=True)
        result=w.verify(dumps(e),**kwargs);value=loads(result.files['work-condition/work.json'],maximum=w.MAX_BYTES)
        self.assertEqual(len(value['token']['history']),2)
        self.assertEqual(value['token']['history'][1]['catalog'],work_profile.examples()[3])
        refs=loads(result.files['work-condition/reference-occurrences.json'],maximum=w.MAX_BYTES)
        self.assertTrue(any('/catalog/entries/1/mapping/specification' in r['jsonPointer'] for r in refs))
        append_work(e,kwargs,tombstone=True);result=w.verify(dumps(e),**kwargs)
        value=loads(result.files['work-condition/work.json'],maximum=w.MAX_BYTES)
        self.assertEqual(value['token']['status'],'description_absent')
        self.assertEqual(len(value['token']['history']),3)
        changed=deepcopy(e);changed['events'][0],changed['events'][1]=changed['events'][1],changed['events'][0]
        for original,reordered in zip(e['events'],changed['events']):
            for key in ('blockNumber','blockHash','transactionHash','transactionIndex','logIndex'):reordered['log'][key]=original['log'][key]
        with self.assertRaisesRegex(MuseumError,'revision event order'):w.verify(dumps(changed),**kwargs)

    def test_unselected_c2pa_original_is_not_absence(self):
        e,kwargs=deepcopy(self.baseline)
        e['c2pa']={'collection':_scope(),'token':_scope(),'artists':[],'identityDocuments':{}}
        events(e);e['sourceBindings']['calls']=w.expected_calls(e,**kwargs)
        result=w.verify(dumps(e),**kwargs);value=loads(result.files['work-condition/c2pa.json'],maximum=w.MAX_BYTES)
        self.assertEqual(value['token']['status'],'none_selected')
        self.assertEqual(value['absence'],'not_absent')
        self.assertEqual(len(value['unselectedApplicableOccurrences']),1)

    def test_stale_later_c2pa_report_keeps_original_adverse_conflict(self):
        e,kwargs=supplied(condition=False);add_adverse_c2pa_history(e,kwargs)
        result=w.verify(dumps(e),**kwargs);value=loads(result.files['work-condition/c2pa.json'],maximum=w.MAX_BYTES)
        reconciled=value['token']['reconciliation']
        self.assertEqual(reconciled['standing']['unresolvedCount'],'1')
        self.assertEqual(len(reconciled['conflictHistory']),1)
        self.assertFalse(reconciled['reconciliation']['displayObservation']['current'])
        bad=deepcopy(e);bad['c2pa']['token']['history']=[]
        bad['c2pa']['token']['standing']=hx(encode((conflicts.STANDING,),(conflicts.EMPTY_STANDING,)))
        events(bad)
        with self.assertRaises(MuseumError):w.expected_calls(bad,**kwargs)

    def test_c2pa_divergence_is_adjacent_to_its_selection_and_conflict(self):
        e,kwargs=supplied(condition=False);add_adverse_c2pa_history(e,kwargs)
        topic=schema_id('C2PAAttributionDivergence(uint256,bytes32,bytes32,bytes32,bytes32)')
        for mode in ('gap','different_transaction','after_conflict'):
            bad=deepcopy(e);index=next(i for i,r in enumerate(bad['events']) if r['log']['topics'][0]==topic)
            d=bad['events'][index]
            if mode=='gap':
                for row in bad['events'][index:]:row['log']['logIndex']=hex(int(row['log']['logIndex'],16)+1)
            elif mode=='different_transaction':
                d['log']['transactionHash']=H('other divergent transaction');d['log']['transactionIndex']='0xff';d['log']['logIndex']='0xff'
            else:
                d['log']['logIndex'],bad['events'][index+1]['log']['logIndex']=bad['events'][index+1]['log']['logIndex'],d['log']['logIndex']
            bad['events'].sort(key=lambda row:tuple(int(row['log'][k],16) for k in ('blockNumber','transactionIndex','logIndex')))
            with self.subTest(mode=mode),self.assertRaisesRegex(MuseumError,'divergence adoption adjacency'):w.verify(dumps(bad),**kwargs)

    def test_event_anchor_and_publication_chronology_cannot_be_rewritten(self):
        for mode in ('block_hash','reverse_anchor','timestamp','transaction_reuse','global_log_order','before_publication'):
            e,kwargs=deepcopy(self.baseline)
            if mode=='block_hash':
                for row in e['events']:row['log']['blockHash']=H('forged same height header')
            elif mode=='reverse_anchor':
                row=e['events'][1];row['log']['blockNumber']=hex(int(e['sourceState']['blockNumber'])-1)
                row['timestamp']=str(int(e['sourceState']['timestamp'])-1)
                e['events'].sort(key=lambda r:int(r['log']['blockNumber'],16))
            elif mode=='timestamp':
                for row in e['events']:row['timestamp']=str(int(e['sourceState']['timestamp'])-1)
            elif mode=='transaction_reuse':e['events'][1]['log']['transactionHash']=e['events'][0]['log']['transactionHash']
            elif mode=='global_log_order':
                e['events'][0]['log']['logIndex']='0x64';e['events'][1]['log']['logIndex']='0x5'
            else:
                event=e['events'][1];event['timestamp']=str(int(e['sourceState']['timestamp'])-2)
                event['log']['blockNumber']=hex(int(e['sourceState']['blockNumber'])-2);event['log']['blockHash']=H('older admissible header')
                e['events'].sort(key=lambda r:int(r['log']['blockNumber'],16))
            with self.subTest(mode=mode),self.assertRaises(MuseumError):w.verify(dumps(e),**kwargs)

    def test_parametrized_native_state_and_existing_capture_inputs(self):
        e,kwargs=supplied(condition=False)
        state=deepcopy(e['sourceState']);state.update(chainId='9988',collectionId='9',tokenId='99',core=A(99000),blockHash=H('other source'),stateRoot=H('other root'))
        graph=deepcopy(e['graph']);graph['core']={'address':state['core'],'runtimeHash':H('other core code')}
        runtime={a:hex_bytes(code) for a,code in e['runtimes'].items()};runtime[state['core']]=b'other core code'
        other,k=supplied(condition=False,source_state=state,graph=graph,runtime_bytes=runtime)
        result=w.verify(dumps(other),**k)
        self.assertEqual(result.report['sourceState'],state)
        self.assertNotEqual(other['work']['token']['current'],e['work']['token']['current'])
        copied,kk=from_captures(**k,source_state=state,graph=graph,runtime_bytes=runtime,
            metadata_pointer=from_json(w.POINTER,other['metadataPointer']),identity=(True,9,1,False),
            work_evidence=other['work'],c2pa_evidence=other['c2pa'],event_rows=other['events'])
        self.assertEqual(w.verify(dumps(copied),**kk).files,result.files)

    def test_shared_title_fixture_retains_native_catalogue_without_relabeling(self):
        package,e,kwargs=title_case();result=w.verify(dumps(e),**kwargs)
        snapshot=loads(kwargs['metadata_files']['snapshot.json'],maximum=w.MAX_BYTES)
        self.assertGreater(len(snapshot['records']),1)
        self.assertEqual(result.report['items']['15']['status'],'source_missing')
        self.assertTrue('title/acquisition-packet.json' in dict(package.files))


if __name__=='__main__':unittest.main()
