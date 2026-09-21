"""Complete fd861 VIEW inventory from retained bytes and recorded source reads.

Recorded calls are caller-admitted observations, not execution/consensus proofs.
The entire twelve-stage occurrence inventory is reconstructed independently;
the producer's requireCurrent result retains the external currentness boundary.
"""
from . import view_preservation_inventory_types_v1 as t
from . import view_preservation_inventory_sources_v1 as source
from . import view_preservation_reference_wire_v1 as reference
from . import view_preservation_reference_types_v1 as rt
from . import view_preservation_inventory_items_v1 as constructors
from .canonical import MuseumError, dumps, hex_bytes, keccak256, uint
from .chain_abi import encode, decode, calldata
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import _bytes, _closed, event_matches
from .object_inventory_source import reconstruct_segment, append_segment
from .view_policy_membership_v2 import scope_subject

DEPENDENCY_ROLES=('core','metadata','schemas','store','router','viewSnapshot','viewReference',
    'work','rights','conservation','coverage','externalCoverage')
ARTIST_ROLES=('artist','artistCoordinator','artistIdentity','artistAttribution','artistArchive')
GRAPH_KEYS=tuple(dict.fromkeys((*reference.GRAPH_KEYS,*DEPENDENCY_ROLES,*ARTIST_ROLES,'artistContentOwner','inventory','bundleCoverage')))
MAX_EVIDENCE=192*1024*1024
MAX_SEGMENTS=32768
MAX_ITEMS=131072
MAX_GAS=64000000
CLAIMS={'completeTwelveStageInventoryChecked':True,'completeMemberOutputBytesChecked':True,
    'originalReferenceAndPreservationProofRequired':True,'recordedSourceReadsRequired':True,
    'rpcProvenanceAuthenticated':False,'nativeExecutionProven':False,'freshNativeObservationProven':False,
    'historicalAuthorityReauthorized':False,'archiveCurrentPairProven':False,'finalityProven':False,
    'browserExecutionProven':False,'zipMembershipVerified':False,'consensusProof':False}


def _hash(kinds,values):return keccak256(encode(kinds,values))


def plan_id(chain,host,dependency_hash,c):
    return _hash(('bytes32','uint256','address','bytes32',t.CONTEXT),(t.PLAN_DOMAIN,chain,host,dependency_hash,c))


def segment_key(plan,index):
    return _hash(('bytes32','bytes32','uint64'),(t.KEY_DOMAIN,plan,index))


def evidence_hash(chain,host,dependency_hash,e):
    return _hash(('bytes32','uint256','address','bytes32',t.EVIDENCE),
        (t.EVIDENCE_DOMAIN,chain,host,dependency_hash,(e[0],(*e[1][:-1],ZERO))))


def output_witness(c,stage,index,count):
    return _hash(('bytes32','bytes32','bytes32','bytes32','uint16','uint64','uint64'),
        (t.DOMAIN['outputWitness'],c[13],c[11],c[16],stage,index,count))


def _dependencies(value,context,graph):
    require(type(graph) is dict and set(graph)==set(GRAPH_KEYS),'VIEW inventory exact graph')
    pins={}
    for pair in graph.values():
        _closed(pair,('address','runtimeHash'),'VIEW inventory graph pin')
        require(any(hex_bytes(pair['address'],20)) and any(hex_bytes(pair['runtimeHash'],32))
            and pins.setdefault(pair['address'],pair['runtimeHash'])==pair['runtimeHash'],
            'VIEW inventory nonzero consistent graph pin')
    d=source.typed(t.DEPENDENCIES,value['dependencies'])
    require(d[0]==tuple(graph[k]['address'] for k in DEPENDENCY_ROLES)
        and d[1]==tuple(graph[k]['runtimeHash'] for k in DEPENDENCY_ROLES)
        and d[2]==tuple(graph[k]['address'] for k in ARTIST_ROLES)
        and d[3]==tuple(graph[k]['runtimeHash'] for k in ARTIST_ROLES)
        and d[4:6]==(graph['artistContentOwner']['address'],graph['artistContentOwner']['runtimeHash'])
        and d[6]==uint(context['chainId']) and d[7]>=50000 and all(d[7]<=v<=MAX_GAS for v in d[8:])
        and d[7]<=MAX_GAS,'VIEW inventory exact dependency/gas bounds')
    require(value['dependencyHash']==_hash((t.DEPENDENCIES,),(d,)),'VIEW inventory dependency hash')
    require(type(value['runtimes']) is dict and 0<len(value['runtimes'])<=1024,'VIEW inventory runtime evidence bound')
    for address,pin in pins.items():
        raw=_bytes(value['runtimes'][address],131072,'VIEW inventory runtime')
        require(raw and keccak256(raw)==pin,
            'VIEW inventory graph runtime bytes')
    require(type(value['documents']) is dict and 36<=len(value['documents'])<=128,'VIEW inventory document denominator')
    return d


def _context(c,d,ref,context):
    row,bundle,adopted,snap=source.selected(ref)
    f=source.typed(rt.SOURCE,row['source']);ss=f[2]
    require(c[0][0]==4 and c[0][1]==uint(context['collectionId']) and c[0][2]==0 and c[0][3]!=ZERO
        and c[0]==ss[0] and c[1]==f[0]==scope_subject(c[0],context),'VIEW inventory full scope/subject')
    expected=(f[1],source.typed(rt.RECEIPT,row['receipt']))
    require(c[3:5]==expected and ref['selectedRecordHash']==ref['current'][1][0]
        and bundle['snapshot']['selectedRecordHash']==bundle['snapshot']['current'][0]
        and bundle['adoption']['selectedRecordHash']==bundle['adoption']['head']
        and bundle['root']['selectedRecordHash']==bundle['root']['head'],
        'VIEW inventory selected originals must be recorded current heads')
    require(c[2]==ss[2][3]==c[6][1][0] and c[5][0]==c[1]
        and ss[2][1:3]==(d[2][0],d[3][0])
        and (ss[2][3],ss[2][5],ss[2][4],ss[2][7])==c[6][1],
        'VIEW inventory original Artist association/description joins')
    require(c[6][0][1] in (0,1) and c[6][2]==0 and c[6][3] in (0,1) and c[6][6] in (0,1,2),
        'VIEW inventory conservation profile')
    expected_tail=(_hash((rt.SNAPSHOT_SOURCE,),(ss,)),f[3],ss[1][5],ss[5][0][0],ss[5][7],ss[3][0][3],
        ss[3][0][0][1],ss[3][0][1][8],ss[3][4],ss[6][2],ss[4][8],ss[5][1][3],ss[1][3])
    require(c[8:]==expected_tail and 0<c[20]<=t.MAX_MEMBERS and c[7]!=ZERO
        and all(v!=ZERO for v in c[8:20]), 'VIEW inventory original source context commitments')
    # The native currentness gate is a recorded call. Historical bytes alone
    # cannot authenticate a current Artist/curator/archive decision.
    return row,bundle


def _stage_rows(value,c,d):
    ref=value['reference'];runtimes=value['runtimes'];documents=value['documents']
    return {0:source.native_rows(c,d,ref,runtimes),1:source.reference_rows(c,d,ref),
        8:source.artwork_rows(c,d,ref),9:source.renderer_rows(c,d,ref,value['rendererRegistration'],runtimes,documents),
        10:source.admission_rows(c,d,ref,runtimes,documents),
        11:source.token_rows(c,d,ref,value['members'],runtimes)}


def _segments(value,c,d,identifier,rows,graph):
    from .view_preservation_inventory_stages_v1 import validate_fixed_stage
    supplied=value['segments']
    require(type(supplied) is list and 0<len(supplied)<=MAX_SEGMENTS,'VIEW inventory segment allocation bound')
    stage=cursor=total=0;chain=ZERO;segments=[];all_items=[]
    for index,entry in enumerate(supplied):
        _closed(entry,('stage','index','segment','items','source'),'VIEW inventory segment evidence')
        require(uint(entry['stage'],16)==stage and uint(entry['index'],64)==cursor,
            'VIEW inventory ordered twelve-stage cursor')
        segment=source.typed(t.SEGMENT,entry['segment'])
        require(type(entry['items']) is list and len(entry['items'])<=1024,'VIEW inventory segment row bound')
        actual=tuple(source.typed(t.ITEM,x) for x in entry['items'])
        if stage in (0,1):
            length=len(actual);require(0<length<=64 and cursor+length<=len(rows[stage]),'VIEW inventory native/reference chunk')
            expected=rows[stage][cursor:cursor+length]
            witness=_hash(('bytes32','uint64','uint64'),
                (_hash((t.CONTEXT,),(c,)) if stage==0 else c[4][1][6],cursor,len(rows[stage])))
            cursor+=length
            if cursor==len(rows[stage]):stage+=1;cursor=0
            require(entry['source'] is None,'VIEW inventory unexpected chunk source')
        elif stage==7:
            require(entry['source'] is None,'VIEW inventory definition uses global document evidence')
            definition=t.definitions()[cursor]
            expected=(constructors.document(definition['id'],definition['hash'],d[0][2],value['documents']),)
            witness=_hash(('bytes32',t.ITEM),(definition['id'],expected[0]))
            if cursor<35:cursor+=1
            else:stage+=1;cursor=0
        elif stage in (2,3,4,5,6):
            validate_fixed_stage(stage,cursor,actual,segment[3],c,d,entry['source'],graph,
                documents=value['documents'])
            expected=actual;witness=segment[3]
            stage+=1;cursor=0
        else:
            require(stage in (8,9,10,11) and entry['source'] is None,'VIEW inventory output stage/source')
            if stage==8:expected=rows[8];count=len(expected)
            elif stage in (9,10):expected=(rows[stage][cursor],);count=len(rows[stage])
            else:expected=rows[11][cursor];count=len(expected)
            witness=output_witness(c,stage,cursor,count)
            if stage==8 or (stage in (9,10) and cursor+1==len(rows[stage])):stage+=1;cursor=0
            else:cursor+=1
        require(actual==expected and segment[3]==witness,'VIEW inventory exact source rows/witness')
        key=segment_key(identifier,index)
        require(segment==reconstruct_segment(key,witness,actual),'VIEW inventory complete item link chain')
        chain=append_segment(chain,index,segment);total+=len(actual)
        require(total<=MAX_ITEMS,'VIEW inventory complete occurrence bound')
        segments.append(segment);all_items.extend(actual)
    require(stage==11 and cursor==c[20],'VIEW inventory incomplete twelve-stage/all-member inventory')
    return tuple(segments),tuple(all_items),chain


def expected_reads(value,context,graph,c,d,p,e,segments):
    """Canonical recorded getter descriptors; constructing them proves no execution."""
    host=graph['inventory']['address'];identifier=e[1][0]
    expected=[]
    def call(name,args,result):
        inputs,outputs=t.FUNCTIONS[name]
        expected.append({'target':host,'calldata':calldata(t.SIGNATURES[name],inputs,args),
            'result':'0x'+encode(outputs,result).hex()})
    call('inventoryProfile',(),(t.PROFILE,));call('dependencies',(),(d,));call('dependencyHash',(),(value['dependencyHash'],))
    call('sourceContext',(identifier,),(c,));call('plan',(identifier,),(p,));call('tokenProgress',(identifier,),((0,0,0),))
    call('inventoryEvidence',(identifier,),(e,));call('requireCurrent',(c[0],),(e,))
    call('requireFullDefinitionBytes',(identifier,),())
    for index,segment in enumerate(segments):call('inventorySegment',(identifier,index),(segment,))
    # Both observations must be retained, including repeated identical call
    # inputs; a recorded transcript is ordered, never a lossy method map.
    call('requireCurrent',(c[0],),(e,))
    return expected


def recorded_reads(value,context,graph,c,d,p,e,segments):
    """Closed exact call records at the supplied anchor; origin is not self-proved."""
    record=value['recordedSource']
    _closed(record,('blockHash','provenance','calls'),'VIEW inventory recorded source')
    require(record['blockHash']==context['blockHash'] and record['provenance'] in
        ('synthetic_fixture','externally_admitted_rpc'),'VIEW inventory recorded source anchor/trust')
    expected=expected_reads(value,context,graph,c,d,p,e,segments)
    require(record['calls']==expected,'VIEW inventory exact recorded getter denominator/bytes')
    return record['provenance']


def expected_events(value,context,graph):
    c=source.typed(t.CONTEXT,value['context']);e=source.typed(t.EVIDENCE,value['evidence']);identifier=e[1][0]
    host=graph['inventory']['address'];events=[]
    def event(name,topics,values):events.append({'address':host,'topics':(t.EVENTS[name],*topics),
        'data':'0x'+encode(t.EVENT_DATA[name],values).hex()})
    event('started',(identifier,),(1,c[0],_hash((t.CONTEXT,),(c,))))
    for index,row in enumerate(value['segments']):
        event('segment',(identifier,'0x'+index.to_bytes(32,'big').hex()),
            (1,source.typed(t.SEGMENT,row['segment']),tuple(source.typed(t.ITEM,x) for x in row['items'])))
    event('completed',(identifier,e[1][-1]),(1,e))
    return events


def _events(value,context,graph):
    expected=expected_events(value,context,graph);events=value['events']
    require(type(events) is list and len(events)==len(expected),'VIEW inventory event denominator')
    previous=None;reference_events=value['reference']['events']
    after=reference._position(reference_events[-1])
    for item,descriptor in zip(events,expected):
        _closed(item,('log','timestamp'),'VIEW inventory event')
        position=reference._position(item)
        require(position>after and (previous is None or position>previous)
            and position[0]<=uint(context['blockNumber'],64) and item['log']['removed'] is False
            and 0<uint(item['timestamp'],64)<=uint(context['timestamp'],64)
            and any(hex_bytes(item['log']['blockHash'],32)) and any(hex_bytes(item['log']['transactionHash'],32))
            and event_matches((descriptor['address'],descriptor['topics'],descriptor['data']),item['log']),
            'VIEW inventory exact ordered source event')
        previous=position
    original_events=[event for row in value['reference']['history'] for event in row['sourceProof']['events']]
    reference._event_coherence([*original_events,*reference_events,*events],context)


def validate(value,context,graph):
    try:
        require(len(dumps(value))<=MAX_EVIDENCE,'VIEW inventory total byte bound')
        return _validate(value,context,graph)
    except MuseumError:raise
    except (KeyError,ValueError,TypeError,IndexError,OverflowError,StopIteration) as exc:
        raise MuseumError('malformed complete VIEW inventory evidence') from exc


def _validate(value,context,graph):
    _closed(value,('sourceRevision','profile','dependencies','dependencyHash','context','plan','evidence',
        'segments','recordedSource','reference','members','rendererRegistration','runtimes','documents','events'),
        'VIEW inventory evidence')
    require(value['sourceRevision']==t.SOURCE_REVISION and value['profile']==t.PROFILE,'VIEW inventory closed native profile')
    d=_dependencies(value,context,graph);c=source.typed(t.CONTEXT,value['context'])
    reference.validate(value['reference'],context,{k:graph[k] for k in reference.GRAPH_KEYS})
    _context(c,d,value['reference'],context)
    identifier=plan_id(d[6],graph['inventory']['address'],value['dependencyHash'],c)
    rows=_stage_rows(value,c,d)
    segments,flat,chain=_segments(value,c,d,identifier,rows,graph)
    p=source.typed(t.PLAN,value['plan']);e=source.typed(t.EVIDENCE,value['evidence'])
    original=(c[9],c[3][0],c[4][1][0],c[6][0][0] if c[6][0][1]==0 else ZERO,
        c[6][0][0] if c[6][0][1]==1 else ZERO,c[7],c[5][2],c[5][1])
    context_hash=_hash((t.CONTEXT,),(c,))
    body=(identifier,c[0][1],c[1],c[2],original,context_hash,c[10],c[20],len(segments),len(flat),chain,ZERO)
    digest=evidence_hash(d[6],graph['inventory']['address'],value['dependencyHash'],(c[0],body))
    require(e==(c[0],(*body[:-1],digest)),'VIEW inventory scoped evidence/source preimage')
    progress=(c[0][1],c[1],c[2],context_hash,c[20],c[20],len(segments),len(flat),chain,11,digest)
    require(p==(c[0],progress,len(rows[0]),len(rows[0]),len(rows[1]),len(rows[1])),
        'VIEW inventory sealed plan/cursors/counts')
    provenance=recorded_reads(value,context,graph,c,d,p,e,segments)
    _events(value,context,graph)
    return {'sourceRevision':t.SOURCE_REVISION,'scope':c[0],'evidence':e,'dependencyHash':value['dependencyHash'],
        'items':list(flat),'segments':list(segments),'context':c,'planId':identifier,'provenance':provenance,
        'claims':dict(CLAIMS),'qualification':'All twelve ordered stages and complete member bytes are checked offline. '
            'Recorded requireCurrent calls, runtime identities and source authority are externally admitted observations; '
            'the bytes cannot prove their own RPC origin or native execution. Archive signature authority/current pairs, '
            'browser execution, ZIP membership, governance, finality and consensus remain unproven.'}
