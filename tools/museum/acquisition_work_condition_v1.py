"""Replay-backed WORK, C2PA and condition contributions for packet items 12/14/15.

Current native heads are admitted observations at one exact source state. They
are not reconstructed from whichever original records a caller chooses. All
Metadata lanes and the canonical condition source catalogue are replayed first.
"""
from dataclasses import dataclass, fields

from . import metadata_catalog_source as metadata
from . import public_condition_capture as condition_capture
from . import condition as condition_meaning
from . import artist_c2pa as c2pa
from . import artist_c2pa_conflicts as conflicts
from . import work_lido_source as work
from . import view_preservation_inventory_stages_v1 as work_native
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_abi import calldata, decode, encode
from . import artist_attestation_source as artist_native
from .chain_rpc import ReplayTransport
from .dossier_hosts_source import POINTER, COLLECTION_METADATA
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import _closed, from_json
from .view_preservation_inventory_types_v1 import signature
from .public_history_rpc import quantity

SOURCE_REVISION = 'ec832e8674965a30c571d55cc39efdbd0db9e727'
NAME = 'STREAM_MUSEUM_ACQUISITION_WORK_CONDITION_V1'
MAX_BYTES = 128 * 1024 * 1024
MAX_HISTORY = 256
STATE_KEYS = ('chainId','core','collectionId','tokenId','blockNumber','blockHash','timestamp','stateRoot','environment')
GRAPH_KEYS = ('core','metadata','schemas','store','work','c2pa','artist','router','verifier','attribution')
WORK_SELECTION = work_native.WORK_SELECTION
C2PA_TYPES = (schema_id('C2PA_REFERENCE'), schema_id('C2PA_VALIDATION'))
CLAIMS = {'metadataCatalogueReplayed':True,'completeCurrentCompanionRevisionsChecked':True,
    'allApplicableMetadataOccurrencesRetained':True,'originalAuthorityPreserved':True,
    'nativeHeadNotInferredFromLatestRecord':True,'sameSourceStateChecked':True,
    'sourceConsensusVerified':False,'companionDiscoveryComplete':False,
    'historicalArtistSignaturesReauthorized':False,'workCurrentEligibilityReexecuted':False,
    'nativeCompanionSuccessfulReceiptsAuthenticated':False,'workArtistOwnerRuntimeAuthenticated':False,
    'c2paHistoricalCredentialOwnerAuthenticated':False,'workCatalogRegistrationAuthenticated':False,
    'c2paCryptographyVerified':False,'c2paTrustAnchorsValidated':False,
    'examinerIndependenceProven':False,'actualExaminationProven':False,
    'renderExecutionProven':False,'recoveryExecutionProven':False,'completeAcquisitionPacket':False}
QUALIFICATION = ('Original catalogue/capture bytes are replayed; new native getter results remain externally '
    'admitted or synthetic observations, not consensus evidence. WORK is the exact raw selected head, '
    'including an authored description_absent tombstone; current consuming eligibility is not inferred. '
    'C2PA absence covers only both exact subjects at the pinned selected Metadata and admitted companion. '
    'All original C2PA occurrences remain visible even if unselected. Validation/authorship/display and '
    'condition examination, render and recovery results remain attributed claims. Other historical '
    'Metadata hosts, companion discovery, successful native companion receipts, historical Artist owner '
    'runtime and op24 archives, WORK catalog registration and examination execution '
    'require separately composed evidence. No network object is fetched.')
PROFILE_BYTES = dumps({'name':NAME,'version':'1','sourceReviewCommit':SOURCE_REVISION,
    'metadataProfileHash':metadata.PROFILE_HASH,'conditionCaptureProfileHash':condition_capture.PROFILE_HASH,
    'workSchemaHash':work.WORK_SCHEMA_HASH,'workProfileHash':work.WORK_PROFILE_HASH,
    'c2paProfileHash':keccak256(c2pa.profile_bytes()),'conflictProfileHash':keccak256(conflicts.profile_bytes()),
    'denominator':'Complete replayed Metadata catalogue, both native collection/token companion histories, and every retained canonical condition source.',
    'claims':CLAIMS,'qualification':QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Result:
    files: dict
    report: dict
    observations: dict


def _raw(value, maximum=32768):
    raw=hex_bytes(value);require(len(raw)<=maximum,'work/condition byte bound');return raw


def _typed(kind,value):return from_json(kind,value)


def _record_call(calls,host,signature,inputs=(),arguments=(),outputs=(),values=(),raw=None):
    row={'target':host,'calldata':calldata(signature,inputs,arguments),
        'result':'0x'+(encode(outputs,values) if raw is None else raw).hex()}
    calls.append(row);return row


def _same(state,anchor):
    require(all(state[key]==anchor[key] for key in STATE_KEYS if key in anchor),'work/condition same source state')


def _metadata(files,pins):
    require(type(files) is dict and set(files)=={'anchor.json','transcript.json','snapshot.json','pins.json','profile.json'},
        'work/condition complete Metadata capture files')
    _closed(pins,('profileHash','anchorHash','snapshotHash','transcriptHash','provenance','actualChainAcceptance'),'Metadata capture pins')
    require(files['profile.json']==metadata.PROFILE_BYTES and loads(files['pins.json'],canonical=True)==pins
        and pins['profileHash']==metadata.PROFILE_HASH and pins['actualChainAcceptance'] is False,
        'work/condition exact Metadata capture profile')
    for key in ('anchor','snapshot','transcript'):
        require(keccak256(files[key+'.json'])==pins[key+'Hash'],'work/condition external Metadata pin')
    source=metadata.MetadataCatalogSource(files['anchor.json'],ReplayTransport(files['transcript.json'],pins['transcriptHash']),
        provenance=pins['provenance'])
    require(source.snapshot()==files['snapshot.json'],'work/condition Metadata replay differs')
    return source.a,loads(files['snapshot.json'],maximum=MAX_BYTES,canonical=True)


def _observations(files,anchor,provenance):
    return {'anchor':anchor,'anchorBytes':files['anchor.json'],'transcriptBytes':files['transcript.json'],
        'provenance':provenance,'runtimePins':anchor['codePins']}


def _seed(observations):
    """One source-block code/call answer cannot differ between original captures."""
    answers,codes,queries={},{},{}
    common={}
    for source in observations:
        a=source['anchor']
        for key in (*STATE_KEYS,'deploymentEvidenceHash'):
            if key in a:require(common.setdefault(key,a[key])==a[key],'work/condition original capture state differs')
        for row in a['codePins']:
            key=(a['blockHash'],row['address']);require(codes.setdefault(key,row['runtimeHash'])==row['runtimeHash'],'work/condition runtime conflict')
        transcript=loads(source['transcriptBytes'],maximum=MAX_BYTES,canonical=True)
        for row in transcript['calls']:
            query=dumps([row['method'],row['params']]);outcome=dumps({k:row[k] for k in ('result','limit') if k in row})
            require(queries.setdefault(query,outcome)==outcome,'work/condition original RPC observation conflict')
            if row['method']=='eth_call':
                params=row['params'];key=(params[1]['blockHash'],params[0]['to'],params[0]['data'])
                require(answers.setdefault(key,row['result'])==row['result'],'work/condition shared getter conflict')
            elif row['method']=='eth_getCode':
                key=(row['params'][1]['blockHash'],row['params'][0]);digest=keccak256(hex_bytes(row['result']))
                require(codes.setdefault(key,digest)==digest,'work/condition carrier runtime conflict')
    return answers,codes


def _bindings(e,a,calls,codes):
    state=e['sourceState'];_same(state,a)
    require(set(state)==set(STATE_KEYS),'work/condition closed source state')
    for key in ('chainId','collectionId','tokenId'):require(uint(state[key])>0,'work/condition positive identity')
    uint(state['blockNumber']);uint(state['timestamp'],64)
    require(set(e['graph'])==set(GRAPH_KEYS),'work/condition closed graph')
    graph=e['graph']
    for role,pin in graph.items():
        _closed(pin,('address','runtimeHash'),'work/condition graph pin')
        require(any(hex_bytes(pin['address'],20)) and any(hex_bytes(pin['runtimeHash'],32)),'work/condition nonzero graph')
        raw=_raw(e['runtimes'][pin['address']],24576)
        require(raw and keccak256(raw)==pin['runtimeHash'],'work/condition runtime bytes')
        key=(state['blockHash'],pin['address']);require(codes.setdefault(key,pin['runtimeHash'])==pin['runtimeHash'],'work/condition runtime conflict')
    require(set(e['runtimes'])=={p['address'] for p in graph.values()},'work/condition exact runtime denominator')
    for role,key in (('core','core'),('metadata','host'),('schemas','schemas'),('store','store'),('artist','artistRegistry')):
        require(graph[role]['address']==a[key],'work/condition Metadata graph differs')
    pointer=_typed(POINTER,e['metadataPointer'])
    require(pointer[0:2]==(a['host'],graph['metadata']['runtimeHash']) and pointer[3]==COLLECTION_METADATA
        and pointer[6] in (1,2) and pointer[9]>0,'work/condition current Metadata pointer')
    _record_call(calls,a['core'],'getSatellitePointer(bytes32)',('bytes32',),(COLLECTION_METADATA,),(POINTER,),(pointer,))
    identity=_typed(('bool','uint256','uint256','bool'),e['identity'])
    require(identity[0] and identity[1]==uint(state['collectionId']) and identity[2]>0,'work/condition permanent token identity')
    _record_call(calls,a['core'],'tokenCollectionIdentity(uint256)',('uint256',),(uint(state['tokenId']),),('bool','uint256','uint256','bool'),identity)
    host=graph['work']['address']
    for role,getter in (('core','core'),('metadata','metadata'),('schemas','schemaRegistry'),('store','chunkStore')):
        _record_call(calls,host,getter+'()',outputs=('address',),values=(graph[role]['address'],))
        _record_call(calls,host,getter+'CodeHash()',outputs=('bytes32',),values=(graph[role]['runtimeHash'],))
    _record_call(calls,host,'deploymentChainId()',outputs=('uint256',),values=(uint(state['chainId']),))
    for role,getter in (('core','core'),('metadata','metadata'),('artist','artist'),('router','router'),('store','chunkStore'),('verifier','verifier')):
        _record_call(calls,graph['c2pa']['address'],getter+'()',outputs=('address',),values=(graph[role]['address'],))
    _record_call(calls,graph['c2pa']['address'],'sourceChainId()',outputs=('uint256',),values=(uint(state['chainId']),))
    _record_call(calls,graph['c2pa']['address'],'sourceCodeHashes()',outputs=(('bytes32',)*5,),
        values=(tuple(graph[k]['runtimeHash'] for k in ('core','metadata','artist','router','store')),))
    return graph


def _subject(state,lane):
    return subject_id(lane,state['chainId'],state['core'],state['collectionId'],
        **({'token_id':state['tokenId']} if lane=='token' else {}))


def _work(e,snapshot,calls):
    state,graph=e['sourceState'],e['graph'];cid=uint(state['collectionId']);host=graph['work']['address']
    require(set(e['work'])=={'collection','token'},'work both applicable subject histories')
    originals={r['recordHash']:r for r in snapshot['records']};result={}
    for lane in ('collection','token'):
        value=e['work'][lane];_closed(value,('current','history'),'work subject history')
        sid=_subject(state,lane);tip=decode((WORK_SELECTION,),_raw(value['current']))[0]
        require(len(value['history'])<=MAX_HISTORY and tip[7]==len(value['history']),'work revision denominator')
        _record_call(calls,host,'currentWork(uint256,bytes32)',('uint256','bytes32'),(cid,sid),raw=_raw(value['current']))
        previous=ZERO;prior_index=-1;prior_time=0;rows=[]
        for revision,row in enumerate(value['history'],1):
            _closed(row,('selection','catalog','artistPublication'),'work original selection')
            s=decode((WORK_SELECTION,),_raw(row['selection']))[0];blank=s[:21]+(ZERO,)
            expected=keccak256(encode(('bytes32','uint256',*('address',)*5,'uint256','bytes32',WORK_SELECTION),
                (schema_id('6529STREAM_WORK_SELECTION_V1'),uint(state['chainId']),host,
                 *(graph[k]['address'] for k in ('core','metadata','schemas','store')),cid,sid,blank)))
            require(s[0]!=ZERO and s[1]==previous and s[7]==revision and s[8]>prior_index
                and prior_time<=s[10]<=uint(state['timestamp']) and s[10]>0 and s[21]==expected
                and s[3]!=ZERO_ADDRESS and s[4] in (0,1),'work original selection hash/order')
            require((s[4]==0 and s[5:7]==(0,0) and s[11]==0 and s[13]==1)
                or (s[4]==1 and s[5] in (0,cid) and s[6]>0 and s[11] in (3,8)), 'work original selection authority')
            require(s[0] in originals,'work selected original missing from complete catalogue')
            original=originals[s[0]];record=_typed(metadata.RECORD,original['record']);receipt=_typed(metadata.RECEIPT,original['receipt'])
            raw=hex_bytes(original['payloadHex']);cat=None if row['catalog'] is None else _raw(row['catalog'],8192)
            interpreted=work.load_work_source(raw,expected_subject_id=sid,catalog=cat);meaning=loads(raw,canonical=True)
            require(record[0]==metadata.WORK and record[1]==sid and record[4]==schema_id('STREAM_WORK_DESCRIPTION_V1')
                and record[2][2]==schema_id('RFC8785_JCS') and s[2]==keccak256(raw)
                and (s[8],s[9],s[12],s[13])==(receipt[4],receipt[5],receipt[1],receipt[2])
                and receipt[3]<=s[10] and receipt[6]==work.WORK_SCHEMA_HASH and receipt[7]==work_native.WORK_CANON_HASH
                and receipt[8]==s[17][0] and (meaning['predecessor'] or ZERO)==s[1], 'work original receipt/payload binding')
            absent=meaning['form']=='description_absent'
            require(s[14]==int(absent),'work exact native form')
            if absent:
                require(s[15]==0 and s[16]==(ZERO,ZERO,0,ZERO) and s[19:21]==(ZERO,ZERO),'work tombstone cannot invent creator/catalog')
            else:
                creator=meaning['creator'];artist=creator['kind']=='artist'
                require(s[15]==(0 if artist else 1),'work native creator kind')
                if artist:require((creator['artistId'],creator['association']['bindingHash'],uint(creator['association']['bindingGeneration']))==s[16][:3]
                    and s[16][3]!=ZERO, 'work exact creator association')
                else:require(s[16]==(ZERO,ZERO,0,ZERO),'work named creator native association')
                if receipt[2]==1:require(artist and s[16][:3]==s[17][1:4], 'work creator/publication association differs')
                catalog=meaning['format'].get('catalog')
                require(s[19:21]==((catalog['documentId'],catalog['documentHash']) if catalog else (ZERO,ZERO)), 'work catalog selection commitment')
            if s[17][0]==ZERO:
                require(s[17]==_zero(WORK_SELECTION[17]) and s[18]==ZERO and receipt[2] in (3,8)
                    and row['artistPublication'] is None,'work absent Artist evidence')
            else:
                original_artist=row['artistPublication'];_closed(original_artist,('publication','attestation','statement'),'work original Artist publication')
                saved=_typed(artist_native.PUBLICATION_RECORD,original_artist['publication'])
                att=_typed(artist_native.ATTESTATION_RECORD,original_artist['attestation'])
                publication=(graph['metadata']['address'],receipt[1],cid,sid,record[0],record[4],record[2][2],1,
                    keccak256(raw),keccak256(record[3].encode()),record[7],s[0])
                statement=encode(('uint16',artist_native.PUBLICATION),(1,publication))
                require(receipt[2]==1 and s[17][4]==receipt[1] and s[17][5] in (1,3) and s[17][6]==1
                    and 0<s[17][7]<=receipt[3] and s[17][8]==keccak256(encode((artist_native.PUBLICATION,),(publication,)))
                    and saved==(publication,s[17],graph['metadata']['runtimeHash'])
                    and s[18]==keccak256(encode((artist_native.PUBLICATION_RECORD,),(saved,)))
                    and att==(s[17][0],ZERO,schema_id('6529STREAM_ARTIST_RECORD_PUBLICATION_V1'),keccak256(statement),s[17][3],s[17][7],receipt[1])
                    and _raw(original_artist['statement'])==statement,'work retained Artist evidence')
                for getter,kind,actual in (('publicationAttestation',artist_native.PUBLICATION_RECORD,saved),('attestationRecord',artist_native.ATTESTATION_RECORD,att)):
                    _record_call(calls,graph['attribution']['address'],getter+'(bytes32)',('bytes32',),(s[17][0],),(kind,),(actual,))
                _record_call(calls,graph['attribution']['address'],'statementBytes(bytes32)',('bytes32',),(keccak256(statement),),('bytes',),(statement,))
            _record_call(calls,host,'workSelectionAt(uint256,bytes32,uint64)',('uint256','bytes32','uint64'),(cid,sid,revision),raw=_raw(row['selection']))
            rows.append({'selection':json_values(s),'original':original,'semantic':meaning,
                'catalogBytes':row['catalog'],'catalog':None if cat is None else loads(cat,canonical=True),
                'catalogRegistrationAuthenticated':False,'fieldInventory':loads(interpreted.inventory,maximum=MAX_BYTES),
                'originalArtistPublication':row['artistPublication'],'originalArtistArchiveReplayed':False})
            previous,prior_index,prior_time=s[0],s[8],s[10]
        require((not rows and tip==_zero(WORK_SELECTION)) or (rows and value['history'][-1]['selection']==value['current']),'work exact current head')
        result[lane]={'subjectId':sid,'status':'none_selected' if not rows else ('description_absent' if tip[14]==1 else 'full'),
            'current':json_values(tip),'history':rows,'currentEligibility':'not_reexecuted'}
    result['allOriginalWorkRecords']=[r for r in snapshot['records'] if r['record'][0]==metadata.WORK]
    result['effective']={'status':'separate_scopes_retained','precedenceInferred':False}
    return result


def _zero(kind):
    if isinstance(kind,tuple):return tuple(_zero(x) for x in kind)
    return False if kind=='bool' else '' if kind=='string' else b'' if kind=='bytes' else ZERO_ADDRESS if kind=='address' else ZERO if kind=='bytes32' else 0


def _dataclass(cls,row):
    require(type(row) is dict and set(row)=={f.name for f in fields(cls)},'C2PA complete original evidence fields')
    converted={}
    for key,value in row.items():
        if key in ('conflict_id',):converted[key]=value
        elif key in ('block_number','block_timestamp'):converted[key]=uint(value)
        elif key=='block_hash':converted[key]=value
        elif key=='current_head' and value is None:converted[key]=None
        else:converted[key]=_raw(value)
    return cls(**converted)


def _c2pa(e,snapshot,calls):
    state,graph=e['sourceState'],e['graph'];cid=uint(state['collectionId']);host=graph['c2pa']['address']
    _closed(e['c2pa'],('collection','token','artists','identityDocuments'),'C2PA complete scopes')
    originals={r['recordHash']:r for r in snapshot['records']};reports=[];result={};all_artists=[]
    for artist in e['c2pa']['artists']:
        _closed(artist,('artistId','currentHead','history','personhood'),'C2PA Artist original history')
        history=tuple(_dataclass(c2pa.CredentialEvidence,x) for x in artist['history'])
        all_artists.append(c2pa.ArtistEvidence(artist['artistId'],_raw(artist['currentHead']),history,_raw(artist['personhood'])))
    require(len(all_artists)<=MAX_HISTORY and len({x.artist_id for x in all_artists})==len(all_artists),'C2PA Artist history bound/duplicates')
    documents={key:_raw(raw,8192) for key,raw in e['c2pa']['identityDocuments'].items()}
    used_artists=set();used_documents=set()
    for lane in ('collection','token'):
        value=e['c2pa'][lane]
        _closed(value,('current','selections','display','reports','standing','history','acknowledgements'),'C2PA exact scope')
        context=c2pa.Context(uint(state['chainId']),host,state['core'],graph['metadata']['address'],graph['artist']['address'],
            graph['router']['address'],graph['verifier']['address'],cid,_subject(state,lane),uint(state['blockNumber']),state['blockHash'])
        scope=conflicts.ScopeEvidence(context,c2pa.report_schema_definition(),_raw(value['current']),tuple(_raw(x) for x in value['selections']),
            _raw(value['display']),tuple(_dataclass(c2pa.ReportEvidence,x) for x in value['reports']),_raw(value['standing']),
            tuple(_dataclass(conflicts.ConflictEvidence,x) for x in value['history']),
            tuple(_dataclass(conflicts.Acknowledgement,x) for x in value['acknowledgements']),graph['attribution']['address'],graph['store']['address'])
        consumed=conflicts.consume(scope);selected=consumed['reconciliation']['selectionHistory']
        ids={r['report']['artistId'] for r in selected};docs={r['report']['identityRecordHash'] for r in selected}
        used_artists|=ids;used_documents|=docs
        joined=c2pa.consume(context,scope.definition,scope.current,scope.selections,scope.display,scope.reports,
            tuple(a for a in all_artists if a.artist_id in ids),{k:v for k,v in documents.items() if k in docs})
        for row in selected:
            require(row['recordHash'] in originals,'C2PA selected Metadata original missing')
            original=originals[row['recordHash']]
            require(row['recordWire']==original['record'] and row['receiptWire']==original['receipt']
                and row['report']['original']['bytesHex']==original['payloadHex'],'C2PA original catalogue correspondence')
            reports.append(row['recordHash'])
        for signature,raw in (('currentSelection',scope.current),('display',scope.display),('standingConflict',scope.standing)):
            _record_call(calls,host,signature+'(uint256,bytes32)',('uint256','bytes32'),(cid,context.subject_id),raw=raw)
        for revision,raw in enumerate(scope.selections,1):
            _record_call(calls,host,'selectionAt(uint256,bytes32,uint64)',('uint256','bytes32','uint64'),(cid,context.subject_id,revision),raw=raw)
        for revision,row in enumerate(scope.history,1):
            key=decode(('bytes32',),row.at)[0]
            _record_call(calls,host,'conflictAt(uint256,bytes32,uint64)',('uint256','bytes32','uint64'),(cid,context.subject_id,revision),raw=row.at)
            for getter,raw in (('conflictRecord',row.record),('conflictResolution',row.resolution),('resolutionNarrative',row.narrative)):
                _record_call(calls,host,getter+'(bytes32)',('bytes32',),(key,),raw=raw)
        result[lane]={'status':'none_selected' if not selected else 'selected_report',
            'reconciliation':consumed,'originalCredentials':joined,'historicalAcknowledgementSourceAuthentication':False}
    require(used_artists=={a.artist_id for a in all_artists} and used_documents==set(documents),'C2PA exact referenced Artist/document denominator')
    for a in all_artists:
        _record_call(calls,graph['artist']['address'],'c2paCredentialHead(bytes32)',('bytes32',),(a.artist_id,),raw=a.current_head)
        _record_call(calls,graph['artist']['address'],'personhoodAttestation(uint256,bytes32)',('uint256','bytes32'),(cid,a.artist_id),raw=a.personhood)
        for h in a.history:
            head=decode((c2pa.HEAD,),h.head)[0]
            _record_call(calls,graph['artist']['address'],'c2paCredentialRecord(bytes32)',('bytes32',),(head[1],),raw=h.head)
            # Head.sourceRegistry is retained verbatim. This profile does not guess
            # its historical owner[4] from today's facade or invent a getter there.
    subjects={_subject(state,x) for x in ('collection','token')}
    occurrences=[r for r in snapshot['records'] if r['record'][0] in C2PA_TYPES]
    applicable=[r for r in occurrences if r['subjectId'] in subjects]
    result['allMetadataOccurrences']=occurrences
    result['applicableOccurrences']=applicable
    result['unselectedApplicableOccurrences']=[r['recordHash'] for r in applicable if r['recordHash'] not in reports]
    result['absence']='none_in_complete_pinned_scopes' if not applicable and not reports else 'not_absent'
    return result


def _references(value,source,pointer='',out=None):
    out=[] if out is None else out
    if isinstance(value,dict):
        if 'uri' in value and isinstance(value.get('hash'),dict):
            out.append({'occurrence':str(len(out)),'source':source,'jsonPointer':pointer,
                'reference':value,'byteCorrespondence':'not_supplied','actualRetrieval':False})
        for key,child in value.items():_references(child,source,pointer+'/'+key.replace('~','~0').replace('/','~1'),out)
    elif isinstance(value,list):
        for index,child in enumerate(value):_references(child,source,pointer+'/'+str(index),out)
    return out


def expected_events(e):
    """Exact native emission payloads; positions still require observed receipts."""
    state=e['sourceState'];cid=uint(state['collectionId']);rows=[]
    topic=lambda kind,value:'0x'+encode((kind,),(value,)).hex()
    for lane in ('collection','token'):
        sid=_subject(state,lane)
        for row in e['work'][lane]['history']:
            s=decode((WORK_SELECTION,),_raw(row['selection']))[0]
            rows.append({'address':e['graph']['work']['address'],
                'topics':[schema_id('WorkRecordSelected(uint256,bytes32,bytes32,'+signature(WORK_SELECTION)+')'),topic('uint256',cid),sid,s[0]],
                'data':'0x'+encode((WORK_SELECTION,),(s,)).hex(),'timestamp':str(s[10])})
        value=e['c2pa'][lane];host=e['graph']['c2pa']['address']
        for raw in value['selections']:
            s=decode((c2pa.SELECTION,),_raw(raw))[0]
            rows.append({'address':host,'topics':[schema_id('C2PAReconciliationSelected(uint256,bytes32,bytes32,'+signature(c2pa.SELECTION)+')'),topic('uint256',cid),sid,s[0]],
                'data':'0x'+encode((c2pa.SELECTION,),(s,)).hex(),'timestamp':None})
            if s[6][26] and s[6][25]==2:
                rows.append({'address':host,'topics':[schema_id('C2PAAttributionDivergence(uint256,bytes32,bytes32,bytes32,bytes32)'),topic('uint256',cid),sid,s[0]],
                    'data':'0x'+encode(('bytes32','bytes32'),(s[1],s[2])).hex(),'timestamp':None})
        for row in value['history']:
            r=decode((conflicts.CONFLICT,),_raw(row['record']))[0]
            rows.append({'address':host,'topics':[schema_id('C2PAConflictRecorded(bytes32,uint256,bytes32,'+signature(conflicts.CONFLICT)+')'),r[0],topic('uint256',cid),sid],
                'data':'0x'+encode((conflicts.CONFLICT,),(r,)).hex(),'timestamp':str(r[11])})
            resolution=decode((conflicts.RESOLUTION,),_raw(row['resolution']))[0]
            if resolution[0]!=ZERO:
                rows.append({'address':host,'topics':[schema_id('C2PAConflictCleared(bytes32,bytes32,'+signature(conflicts.RESOLUTION)+')'),r[0],resolution[0]],
                    'data':'0x'+encode((conflicts.RESOLUTION,),(resolution,)).hex(),'timestamp':str(resolution[4])})
    return rows


def _events(e):
    require(type(e['events']) is list and len(e['events'])<=4096,'work/condition event bound')
    expected=expected_events(e);actual=[];slots=set();headers={};hashes={};txs={};tx_positions={};last=(-1,-1,-1)
    anchor=e['sourceState'];headers[uint(anchor['blockNumber'])]=(anchor['blockHash'],uint(anchor['timestamp']))
    hashes[anchor['blockHash']]=uint(anchor['blockNumber'])
    for row in e['events']:
        _closed(row,('log','timestamp'),'work/condition original event')
        log=row['log'];_closed(log,('address','topics','data','blockNumber','blockHash','transactionHash','transactionIndex','logIndex'),'work/condition native log')
        b,t,l=(quantity(log[k]) for k in ('blockNumber','transactionIndex','logIndex'))
        stamp=uint(row['timestamp'],64)
        require((b,t,l)>last and b<=uint(e['sourceState']['blockNumber']) and stamp<=uint(e['sourceState']['timestamp']), 'work/condition native event order/bound')
        last=(b,t,l)
        require(any(hex_bytes(log['blockHash'],32)) and any(hex_bytes(log['transactionHash'],32)), 'work/condition nonzero event identity')
        require(headers.setdefault(b,(log['blockHash'],stamp))==(log['blockHash'],stamp)
            and hashes.setdefault(log['blockHash'],b)==b
            and txs.setdefault((b,t),log['transactionHash'])==log['transactionHash']
            and tx_positions.setdefault(log['transactionHash'],(b,t))==(b,t)
            and (b,l) not in slots,'work/condition event reciprocal coordinates')
        slots.add((b,l));actual.append((log,row['timestamp']))
    for b in headers:
        positions=sorted((quantity(log['logIndex']),quantity(log['transactionIndex'])) for log,_ in actual if quantity(log['blockNumber'])==b)
        require(all(x[1]<=y[1] for x,y in zip(positions,positions[1:])), 'work/condition transaction/global log order')
    ordered_headers=sorted(headers.items())
    require(all(x[1][1]<=y[1][1] for x,y in zip(ordered_headers,ordered_headers[1:])), 'work/condition header time order')
    require(len(actual)==len(expected),'work/condition exact event denominator')
    positions={}
    for desc in expected:
        matches=[i for i,(log,stamp) in enumerate(actual) if all(log[k]==desc[k] for k in ('address','topics','data'))
            and (desc['timestamp'] is None or stamp==desc['timestamp'])]
        require(len(matches)==1,'work/condition original event payload/time')
        log,_=actual.pop(matches[0]);positions[(desc['address'],tuple(desc['topics']),desc['data'])]=(quantity(log['blockNumber']),quantity(log['transactionIndex']),quantity(log['logIndex']))
    # Each native revision lane is append-only. A single adoption emits its
    # selection, optional divergence and conflict in that transaction and order.
    for lane in ('collection','token'):
        sid=_subject(anchor,lane)
        lane_events=[d for d in expected if len(d['topics'])>2 and d['topics'][2]==sid]
        for host,topic in ((e['graph']['work']['address'],schema_id('WorkRecordSelected(uint256,bytes32,bytes32,'+signature(WORK_SELECTION)+')')),
                (e['graph']['c2pa']['address'],schema_id('C2PAReconciliationSelected(uint256,bytes32,bytes32,'+signature(c2pa.SELECTION)+')'))):
            ordered=[positions[(d['address'],tuple(d['topics']),d['data'])] for d in lane_events if d['address']==host and d['topics'][0]==topic]
            require(all(x<y for x,y in zip(ordered,ordered[1:])), 'work/condition native revision event order')
        host=e['graph']['c2pa']['address'];previous=None
        for row in e['c2pa'][lane]['history']:
            r=decode((conflicts.CONFLICT,),_raw(row['record']))[0]
            conflict=next(d for d in expected if d['address']==host and d['topics'][0]==schema_id('C2PAConflictRecorded(bytes32,uint256,bytes32,'+signature(conflicts.CONFLICT)+')') and d['topics'][1]==r[0])
            p=positions[(host,tuple(conflict['topics']),conflict['data'])]
            selected=next(d for d in lane_events if d['address']==host and d['topics'][0]==schema_id('C2PAReconciliationSelected(uint256,bytes32,bytes32,'+signature(c2pa.SELECTION)+')') and d['topics'][3]==r[6])
            q=positions[(host,tuple(selected['topics']),selected['data'])]
            s=decode((c2pa.SELECTION,),_raw(selected['data']))[0]
            divergent=s[6][26] and s[6][25]==2
            if divergent:
                divergence=next(d for d in lane_events if d['address']==host and d['topics'][0]==schema_id('C2PAAttributionDivergence(uint256,bytes32,bytes32,bytes32,bytes32)') and d['topics'][3]==r[6])
                require(positions[(host,tuple(divergence['topics']),divergence['data'])]==(q[0],q[1],q[2]+1), 'C2PA divergence adoption adjacency')
            require(p==(q[0],q[1],q[2]+(2 if divergent else 1)) and (previous is None or previous<p), 'C2PA conflict adoption event order')
            previous=p
            resolution=decode((conflicts.RESOLUTION,),_raw(row['resolution']))[0]
            if resolution[0]!=ZERO:
                cleared=next(d for d in expected if d['address']==host and d['topics'][0]==schema_id('C2PAConflictCleared(bytes32,bytes32,'+signature(conflicts.RESOLUTION)+')') and d['topics'][1]==r[0])
                require(positions[(host,tuple(cleared['topics']),cleared['data'])]>p, 'C2PA resolution event precedes conflict')
    return e['events']


def _condition(files,pin,state,observations):
    if files is None:
        require(pin is None,'condition pin without capture')
        return {'status':'source_missing','selections':None,'records':[],'claims':{'conditionSourceReplayed':False}},[]
    result=condition_capture.verify(files,pin);files=dict(result.files)
    anchor=loads(files['source/anchor.json'],canonical=True);_same(state,anchor)
    snap=loads(files['source/snapshot.json'],maximum=MAX_BYTES,canonical=True)
    observations.append(_observations({'anchor.json':files['source/anchor.json'],'transcript.json':files['source/transcript.json']},anchor,result.report['provenance']))
    references=[];rows=[]
    docs={(d['schemaRegistry'],d['documentId']):hex_bytes(d['payloadHex']) for d in snap['documents']}
    for row in snap['records']:
        owner=row['lane']=='OWNER';schema=row['record'][2 if owner else 4];raw=hex_bytes(row['payloadHex'])
        try:interpreted=condition_meaning.admit_document(raw,docs[(row['schemaRegistry'],schema)]) if raw else {'value':None,'reasonCode':'original_payload_empty'}
        except (MuseumError,ValueError):interpreted={'value':None,'reasonCode':'original_payload_uninterpretable','payloadHash':keccak256(raw)}
        if interpreted['value'] is not None:
            if row['matchesToken']:
                condition_meaning._source_subject(interpreted,anchor,row['record'][1],anchor['tokenId'])
            _references(interpreted['value'],{'lane':row['lane'],'host':row['host'],'recordHash':row['recordHash']},out=references)
        rows.append({'original':row,'interpretation':interpreted})
    return {'status':'source_replayed','source':snap,'records':rows,'selections':snap['selections'],
        'claims':{'conditionSourceReplayed':True,'completeBoundCatalogue':True,'actualExaminationProven':False},
        'missingJoins':condition_capture.MISSING_JOINS},references


def _derive(e,a,snapshot,condition,refs,observations,*,check_calls=True):
    _closed(e,('profileHash','sourceReviewCommit','sourceState','graph','runtimes','metadataPointer','identity','work','c2pa','sourceBindings','events'), 'work/condition evidence')
    require(e['profileHash']==PROFILE_HASH and e['sourceReviewCommit']==SOURCE_REVISION,'work/condition source profile')
    answers,codes=_seed(observations);calls=[];_bindings(e,a,calls,codes)
    work_result=_work(e,snapshot,calls);c2pa_result=_c2pa(e,snapshot,calls)
    bindings=e['sourceBindings'];_closed(bindings,('blockHash','provenance','calls'),'work/condition admitted native reads')
    require(bindings['blockHash']==e['sourceState']['blockHash'] and bindings['provenance'] in ('synthetic_fixture','externally_admitted_rpc'), 'work/condition observation anchor')
    expected_provenance='synthetic_fixture' if all(x['provenance']=='synthetic_fixture' for x in observations) else 'externally_admitted_rpc'
    require(len({x['provenance']=='synthetic_fixture' for x in observations})==1,'work/condition mixed synthetic and observed captures')
    require(bindings['provenance']==expected_provenance,'work/condition provenance cannot be promoted')
    if check_calls:require(bindings['calls']==calls,'work/condition exact native getter denominator')
    for row in calls:
        key=(bindings['blockHash'],row['target'],row['calldata']);require(answers.setdefault(key,row['result'])==row['result'],'work/condition shared getter conflict')
    events=_events(e)
    originals={r['recordHash']:r for r in snapshot['records']}
    selection_topic=schema_id('C2PAReconciliationSelected(uint256,bytes32,bytes32,'+signature(c2pa.SELECTION)+')')
    for row in events:
        if row['log']['topics'][0]==selection_topic:
            original=originals[row['log']['topics'][3]]
            require(uint(row['timestamp'])>=uint(original['receipt'][3]),'C2PA adoption precedes original publication')
    _references(work_result,'work',out=refs)
    report={'profileHash':PROFILE_HASH,'sourceReviewCommit':SOURCE_REVISION,'sourceState':e['sourceState'],
        'items':{'12':{'status':'native_selected_heads','collection':work_result['collection']['status'],'token':work_result['token']['status']},
            '14':{'status':c2pa_result['absence'],'applicableRecords':str(len(c2pa_result['applicableOccurrences']))},
            '15':{'status':condition['status'],'executionJoinsComplete':False}},
        'referenceCount':str(len(refs)),'claims':CLAIMS,'qualification':QUALIFICATION}
    files={'work-condition/work.json':dumps(work_result),'work-condition/c2pa.json':dumps(c2pa_result),
        'work-condition/condition.json':dumps(condition),'work-condition/reference-occurrences.json':dumps(refs),
        'work-condition/report.json':dumps(report),'work-condition/profile.json':PROFILE_BYTES}
    observed={'rpcSources':observations,'nativeSeam':{'context':e['sourceState'],'graph':e['graph'],
        'runtimePins':[e['graph'][k] for k in GRAPH_KEYS],'getterCalls':calls,'eventRows':events,
        'provenance':bindings['provenance'],'successfulReceiptJoinVerified':False}}
    return Result(files,report,observed)


def verify(evidence_raw,*,metadata_files,metadata_pins,condition_files=None,condition_manifest_hash=None):
    """Verify exact original captures and derive all three scoped packet contributions."""
    try:
        e=loads(evidence_raw,maximum=MAX_BYTES,canonical=True)
        a,snapshot=_metadata(metadata_files,metadata_pins)
        observations=[_observations(metadata_files,a,metadata_pins['provenance'])]
        condition,refs=_condition(condition_files,condition_manifest_hash,e['sourceState'],observations)
        return _derive(e,a,snapshot,condition,refs,observations)
    except MuseumError:raise
    except (KeyError,TypeError,ValueError,IndexError,OverflowError) as exc:
        raise MuseumError('malformed acquisition WORK/C2PA/condition evidence') from exc


def expected_calls(evidence,*,metadata_files,metadata_pins,condition_files=None,condition_manifest_hash=None):
    """Deterministic read descriptors for a fully validated supplied native seam.

    These descriptors are not RPC observations until independently collected.
    """
    a,snapshot=_metadata(metadata_files,metadata_pins)
    observed=[_observations(metadata_files,a,metadata_pins['provenance'])]
    condition,refs=_condition(condition_files,condition_manifest_hash,evidence['sourceState'],observed)
    return _derive(evidence,a,snapshot,condition,refs,observed,check_calls=False).observations['nativeSeam']['getterCalls']
