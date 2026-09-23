"""Pure original adopted VIEW output commitments; never STATIC finality or currentness."""
from . import view_policy_output_types_v2 as t
from . import native_finality_wire as neutral
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

PART_SCHEMA_BYTES = b'{"name":"STREAM_VIEW_POLICY_OUTPUT_PART_V2","version":2,"profile":"6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_MANIFEST_V2","rows":"Every complete 31-word StreamViewPolicyCheckpointTypesV2.Output in exact original order; 64 rows except the exact final remainder","scope":"Complete canonical VIEW scope, membership identity and original Router adoption record","entropy":"Full original policy and actual status/seed; terminal is not finalized","servingKind":"1 current completed live token; 2 retained historical burned token under the still-current adoption; never current burned output","preservation":"Exact row commitments only; original rendered JSON/HTML and browser execution require separate preserved artifacts","authority":"Permissionless byte verification grants no Artist, publication or finality authority"}'
PART_CANON_BYTES = b'{"name":"STREAM_ABI_VIEW_POLICY_OUTPUT_PART_V2","version":2,"encoding":"abi.encode(schemaId,chainId,core,checkpoint,checkpointConfigurationHash,Header,uint64 first,Output[] rows)","Header":"bytes32 checkpointId,bytes32 checkpointStateHash,StreamFinalityScope scope,bytes32 adoptionRecord,bytes32 sourceContextHash,bytes32 membershipHash,bytes32 policyChainHash,uint64 tokenCount,bytes32 outputRoot","scope":"uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId","arrayOffset":608,"headerBytesIncludingCount":640,"rowBytes":992,"length":"640+992*rows.length","first":"multiple of64 less than tokenCount","count":"min(64,tokenCount-first)","maximumTokenCount":16384,"words":"Canonical Solidity ABI including narrow widths and booleans; no alternate offset or trailing bytes","hash":"Keccak256 of complete bytes"}'
INDEX_SCHEMA_BYTES = b'{"name":"STREAM_VIEW_POLICY_OUTPUT_MANIFEST_V2","version":2,"profile":"6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_MANIFEST_V2","parts":"Complete ordered 64-row parts, maximum256; no omission, duplicate, overlap, truncation or sampling","identity":"Every part binds the same full Header and archive artist label; its record is derived by this actual host from verified bytes","current":"Full original checkpoint is independently current; all exact canonical part and index bytes retain current original ArtifactCoverage. Historical records remain readable after drift","capacity":"Bounded carriers do not prove the full checkpoint currentness call fits a transaction; no partial verification is current evidence","authority":"Archive artist identity is a byte-coverage label that downstream authority must join; it is not independent Artist consent"}'
INDEX_CANON_BYTES = b'{"name":"STREAM_ABI_VIEW_POLICY_OUTPUT_MANIFEST_V2","version":2,"encoding":"abi.encode(schemaId,chainId,core,checkpoint,checkpointConfigurationHash,Header,bytes32 artistId,Descriptor[] parts)","Header":"Exact twelve-word Header from STREAM_ABI_VIEW_POLICY_OUTPUT_PART_V2","Descriptor":"bytes32 recordHash,bytes32 artifactHash,bytes32 coverageHash,bytes32 contentHash,uint64 byteLength,uint64 first,uint16 count,uint256 firstToken,uint256 lastToken","arrayOffset":608,"headerBytesIncludingCount":640,"descriptorBytes":288,"length":"640+288*ceil(tokenCount/64)","order":"Exact consecutive parts, strictly increasing actual token identities across boundaries","maximumCarrierBytes":524288,"words":"Canonical Solidity ABI; no alternate offsets or trailing bytes","hash":"Keccak256 of complete bytes"}'

_DEFINITIONS = (
    ('STREAM_VIEW_POLICY_OUTPUT_PART_V2',0,PART_SCHEMA_BYTES),
    ('STREAM_ABI_VIEW_POLICY_OUTPUT_PART_V2',1,PART_CANON_BYTES),
    ('STREAM_VIEW_POLICY_OUTPUT_MANIFEST_V2',0,INDEX_SCHEMA_BYTES),
    ('STREAM_ABI_VIEW_POLICY_OUTPUT_MANIFEST_V2',1,INDEX_CANON_BYTES),
)
QUALIFICATION = {
    'completeOrderedOriginalHashRowsChecked': True,
    'renderedJSONHTMLBytesRetained': False,
    'historicalRendererExecutionReenacted': False,
    'currentCheckpointReevaluated': False,
    'currentAdoptionRequired': False,
    'perChunkArchivePreimagesReconstructed': False,
    'artistAuthorityGrantedByOutput': False,
    'finalityEvidence': False,
    'actualChainAcceptance': False,
}

def definitions():
    return tuple({'name':name,'id':schema_id(name),'kind':kind,'hash':keccak256(raw),'bytes':raw}
                 for name,kind,raw in _DEFINITIONS)


def _v(kind,value): return neutral._v(kind,value)
def _closed(value,keys,label): neutral._closed(value,keys,'VIEW '+label)
def _hash(domain,kinds,values): return keccak256(encode(('bytes32',*kinds),(domain,*values)))

def configuration_hash(profile,chain,host,kind,configuration,worker_pairs):
    require(len(worker_pairs)==2,'VIEW two actual linked workers required')
    return _hash(profile,('uint256','address',kind,'address','bytes32','address','bytes32'),
                 (chain,host,configuration,*worker_pairs[0],*worker_pairs[1]))

def source_context_hash(chain,host,configuration,scope,adoption_record,source_hash,binding):
    return _hash(t.SOURCE_DOMAIN,('bytes32','uint256','address',t.CHECKPOINT_CONFIG,t.SCOPE,'bytes32','bytes32',t.VIEW_BINDING),
                 (t.PROFILE,chain,host,configuration,scope,adoption_record,source_hash,binding))

def checkpoint_id(chain,host,config_hash,scope,source_hash,count,salt):
    return _hash(t.PLAN_DOMAIN,('uint256','address','bytes32',t.SCOPE,'bytes32','uint256','bytes32'),
                 (chain,host,config_hash,scope,source_hash,count,salt))

def row_hash(chain,host,key,row):
    return _hash(t.ROW_DOMAIN,('uint256','address','bytes32',t.OUTPUT),(chain,host,key,row))

def row_chain(chain,host,key,plan,outputs):
    value = _hash(t.CHAIN_DOMAIN,('bytes32',t.SCOPE,'bytes32','bytes32','uint64'),
                  (key,plan[0],plan[2],plan[3],plan[5]))
    for index,row in enumerate(outputs):
        value = _hash(t.CHAIN_DOMAIN,('bytes32','uint64','bytes32'),(value,index,row_hash(chain,host,key,row)))
    return value

def output_root(chain,host,config_hash,key,plan):
    return _hash(t.ROOT_DOMAIN,('uint256','address','bytes32','bytes32',t.SCOPE,'bytes32','bytes32','uint64','bytes32'),
                 (chain,host,config_hash,key,plan[0],plan[1],plan[2],plan[5],plan[7]))

def header(key,plan):
    return (key,keccak256(encode((t.CHECKPOINT_PLAN,),(plan,))),plan[0],plan[1],plan[2],plan[3],plan[4],plan[5],plan[8])

def part_bytes(configuration,h,first,outputs):
    return encode(t.PART_ENVELOPE,(t.PART_SCHEMA,configuration[9],configuration[0],configuration[2],configuration[4],h,first,outputs))

def index_bytes(configuration,h,artist,descriptors):
    return encode(t.INDEX_ENVELOPE,(t.INDEX_SCHEMA,configuration[9],configuration[0],configuration[2],configuration[4],h,artist,descriptors))

def part_hash(chain,host,configuration_hash,part):
    return _hash(t.PART_DOMAIN,('uint256','address','bytes32',t.PART),(chain,host,configuration_hash,part))

def descriptor(key,part): return (key,part[1][0],part[1][1],part[1][3],part[1][4],*part[2:])

def manifest_plan_hash(chain,host,configuration_hash,h,carrier):
    return _hash(t.MANIFEST_PLAN_DOMAIN,('uint256','address','bytes32',t.HEADER,t.CARRIER),
                 (chain,host,configuration_hash,h,carrier))

def part_chain(key,h,descriptors):
    value = _hash(t.PART_CHAIN_DOMAIN,('bytes32',t.HEADER),(key,h))
    for index,row in enumerate(descriptors):
        value = _hash(t.PART_CHAIN_DOMAIN,('bytes32','uint16',t.DESCRIPTOR),(value,index,row))
    return value

def manifest_record_hash(chain,host,configuration_hash,key,chain_hash):
    return _hash(t.RECORD_DOMAIN,('uint256','address','bytes32','bytes32','bytes32'),
                 (chain,host,configuration_hash,key,chain_hash))

def _rule(rule):
    require(rule[0]!=ZERO_ADDRESS and rule[1]!=ZERO and rule[3]
        and all(rule[i]!=ZERO for i in (4,5,6,7,8,12)),'VIEW incomplete frozen policy row')
    p = rule[14]
    if rule[13]:
        require(p[0:3]==(True,True,True) and p[3]<=2 and p[4]<=1 and p[5]<=1 and p[6]>0
            and p[8]==rule[8] and p[10]!=ZERO and p[11]!=ZERO
            and p[9]==keccak256(encode(('bytes32','bytes32','bool'),(t.POLICY_FAMILY,p[8],p[2])))
            and rule[9:12]==(ZERO_ADDRESS,0,ZERO),'VIEW explicit original policy')
    else:
        require(rule[9]!=ZERO_ADDRESS and rule[10]>0 and rule[11]!=ZERO
            and encode((t.POLICY,),(p,))==bytes(12*32),'VIEW legacy original policy')

def _carrier(row,carrier,schema,canon,expected,pin,stamp):
    coverage = _v(t.COVERAGE,row['coverage'])
    require(0<len(expected)<=t.MAX_BYTES and carrier[0]!=ZERO and carrier[1]!=ZERO and carrier[2]!=ZERO
        and carrier[3]==keccak256(expected) and carrier[4]==len(expected),'VIEW carrier identity/length')
    count = (len(expected)+t.CHUNK_BYTES-1)//t.CHUNK_BYTES
    require(coverage[:8]==(carrier[1],carrier[0],carrier[2],schema,canon,carrier[3],carrier[4],count)
        and coverage[8]!=ZERO and coverage[9]!=ZERO and coverage[8]!=coverage[9]
        and 0<coverage[10]<=stamp and coverage[11]!=ZERO,'VIEW original coverage receipt')
    require(type(row['chunks']) is list and len(row['chunks'])==count,'VIEW complete covered chunks')
    raw = []
    for index,chunk in enumerate(row['chunks']):
        _closed(chunk,('pointer','codeHash','runtime'),'chunk')
        body = neutral._bytes(chunk['runtime'],t.CHUNK_BYTES+1,'VIEW chunk')
        size = min(t.CHUNK_BYTES,len(expected)-index*t.CHUNK_BYTES)
        require(len(body)==size+1 and body[0]==0 and keccak256(body)==chunk['codeHash'],'VIEW STOP carrier size/hash')
        pin(chunk['pointer'],chunk['codeHash']);raw.append(body[1:])
    require(b''.join(raw)==expected,'VIEW exact covered canonical bytes')
    return coverage

def validate(value,context,graph,adoption):
    """Validate supplied original rows. The caller separately validates adoption and membership."""
    try:
        return _validate(value,context,graph,adoption)
    except MuseumError: raise
    except (ValueError,TypeError,KeyError,IndexError,OverflowError,RecursionError) as exc:
        raise MuseumError('invalid supplied VIEW output evidence') from exc

def _validate(value,context,graph,adoption):
    _closed(value,('configuration','checkpoint','manifest'),'output')
    chain,cid = uint(context['chainId']),uint(context['collectionId'])
    stamp = uint(context['timestamp'],64)
    require(chain>0 and cid>0 and stamp>0,'VIEW source domain')
    pins={}
    def pin(address,digest):
        encode(('address','bytes32'),(address,digest))
        require(address!=ZERO_ADDRESS and digest!=ZERO and pins.setdefault(address,digest)==digest,'VIEW runtime contradiction')
    require(type(graph) is dict and set(t.GRAPH_KEYS).issubset(graph),'VIEW required output graph')
    for row in graph.values():
        _closed(row,('address','runtimeHash'),'graph pin');pin(row['address'],row['runtimeHash'])
    address=lambda key:graph[key]['address']
    pair=lambda key:(address(key),graph[key]['runtimeHash'])
    require(context['core']==address('core'),'VIEW Core domain')
    cfg=value['configuration'];_closed(cfg,('checkpoint','checkpointHash','manifest','manifestHash'),'configurations')
    c,m=_v(t.CHECKPOINT_CONFIG,cfg['checkpoint']),_v(t.MANIFEST_CONFIG,cfg['manifest'])
    require(c[:8]==(*pair('core'),*pair('router'),*pair('authority'),*pair('serving'))
        and c[8]!=ZERO and c[9]==chain and 50000<=c[10]<=c[11]<=16777216,'VIEW checkpoint configuration')
    require(m[:9]==(*pair('core'),*pair('checkpoint'),cfg['checkpointHash'],*pair('coverage'),*pair('schemas'))
        and m[9]==chain and 50000<=m[10]<=m[11]<=16777216,'VIEW manifest configuration')
    require(cfg['checkpointHash']==configuration_hash(t.PROFILE,chain,address('checkpoint'),t.CHECKPOINT_CONFIG,c,
        (pair('checkpointSourceWorker'),pair('checkpointTokenWorker'))),'VIEW checkpoint linked configuration hash')
    require(cfg['manifestHash']==configuration_hash(t.OUTPUT_PROFILE,chain,address('outputManifest'),t.MANIFEST_CONFIG,m,
        (pair('manifestReadWorker'),pair('manifestEncodingWorker'))),'VIEW manifest linked configuration hash')
    cp=value['checkpoint'];_closed(cp,('id','salt','plan','outputs'),'checkpoint')
    p=_v(t.CHECKPOINT_PLAN,cp['plan']);scope=_v(t.SCOPE,adoption['scope'])
    require(scope[0]==4 and scope[1]==cid and scope[2]==0 and scope[3]!=ZERO and p[0]==scope,'VIEW exact adopted scope')
    binding=_v(t.VIEW_BINDING,adoption['policyBinding']);record=adoption['record']
    require(adoption['profile']==t.ADOPTION_PROFILE and record[0][0]==json_values(scope)
        and record[3]==p[1]!=ZERO and record[2]!=ZERO,'VIEW selected original adoption')
    require(binding[:2]==pair('core') and binding[6]==chain and binding[7]==scope
        and json_values(binding[8])==record[1][1] and binding[8][3]==p[5]
        and binding[8][5]==p[3]!=ZERO and binding[11]==p[4]!=ZERO,'VIEW original policy/membership binding')
    pin(binding[2],binding[3]);pin(binding[4],binding[5])
    require(p[2]==source_context_hash(chain,address('checkpoint'),c,scope,record[3],record[2],binding),'VIEW source context hash')
    require(0<p[5]<=t.MAX_ROWS and p[6]==p[5] and p[8]!=ZERO,'VIEW complete sealed checkpoint')
    require(cp['id']==checkpoint_id(chain,address('checkpoint'),cfg['checkpointHash'],scope,p[2],p[5],cp['salt']),'VIEW checkpoint ID')
    require(type(cp['outputs']) is list and len(cp['outputs'])==p[5],'VIEW full output denominator')
    outputs=tuple(_v(t.OUTPUT,row) for row in cp['outputs'])
    tokens=tuple(uint(token) for token in adoption['tokenIds'])
    require(tokens==tuple(row[1] for row in outputs) and list(tokens)==sorted(set(tokens)) and tokens[0]>0,'VIEW complete ordered membership')
    policies=tuple(_v(t.POLICY_ROW,row) for row in adoption['policies'])
    require(0<len(policies)==binding[12]<=len(outputs),'VIEW complete policy roster')
    rules={}
    for rule in policies:
        _rule(rule);pin(rule[0],rule[1]);require(rule[0] not in rules,'VIEW duplicate coordinator policy');rules[rule[0]]=rule
    serials=set()
    for index,row in enumerate(outputs):
        require(row[0]==index and row[2]>0 and row[2] not in serials and (row[3],row[4],row[5]) in ((2,False,1),(3,True,2)),
            'VIEW original index/identity/burn serving kind')
        serials.add(row[2]);e=row[7];rule=rules.get(e[0]);require(rule is not None,'VIEW output coordinator outside policy roster')
        require(e[:4]==(rule[0],rule[1],rule[8],rule[13]),'VIEW original entropy policy identity')
        if e[3]:
            require(e[4]==rule[14],'VIEW complete twelve-word policy differs')
            if e[5] in (1,2):
                require(e[6]==ZERO and not e[7] and e[8] and e[4][5]==1
                    and e[4][3]==(0 if e[5]==1 else 2),'VIEW terminal is not finalized')
            else:require(e[5]==5 and e[4][3]==2 and e[4][5]==0 and e[7] and not e[8],'VIEW explicit finalized output')
        else:
            require(encode((t.POLICY,),(e[4],))==bytes(384) and e[5]==5 and e[7] and not e[8],'VIEW legacy finalized output')
        require(0<row[10]<=262144 and 0<row[11]<=262144,'VIEW original output byte lengths')
    require(p[7]==row_chain(chain,address('checkpoint'),cp['id'],p,outputs)
        and p[8]==output_root(chain,address('checkpoint'),cfg['checkpointHash'],cp['id'],p),'VIEW ordered row chain/root')
    h=header(cp['id'],p);manifest=value['manifest']
    _closed(manifest,('planHash','recordHash','plan','parts','coverage','chunks'),'manifest')
    mp=_v(t.MANIFEST_PLAN,manifest['plan']);part_count=(p[5]+63)//64
    require(mp[0]==h and mp[2:5]==(part_count,part_count,p[5]) and mp[5]==tokens[-1]
        and mp[7]==manifest['recordHash']!=ZERO and type(manifest['parts']) is list
        and len(manifest['parts'])==part_count,'VIEW full manifest denominator/header')
    descriptors=[];parts=[]
    for index,row in enumerate(manifest['parts']):
        _closed(row,('recordHash','record','descriptor','coverage','chunks'),'part')
        part=_v(t.PART,row['record']);first=index*64;count=min(64,len(outputs)-first)
        require(part[0]==h and part[1][2]==mp[1][2] and part[2:]==(first,count,tokens[first],tokens[first+count-1]),'VIEW exact part partition')
        expected=part_bytes(m,h,first,outputs[first:first+count])
        require(len(expected)==640+992*count,'VIEW canonical part width')
        _carrier(row,part[1],t.PART_SCHEMA,t.PART_CANON,expected,pin,stamp)
        require(row['recordHash']==part_hash(chain,address('outputManifest'),cfg['manifestHash'],part),'VIEW original part hash')
        d=descriptor(row['recordHash'],part)
        require(_v(t.DESCRIPTOR,row['descriptor'])==d,'VIEW exact descriptor')
        descriptors.append(d);parts.append(expected)
    key=manifest_plan_hash(chain,address('outputManifest'),cfg['manifestHash'],h,mp[1])
    chain_hash=part_chain(key,h,descriptors)
    require(manifest['planHash']==key and mp[6]==chain_hash
        and mp[7]==manifest_record_hash(chain,address('outputManifest'),cfg['manifestHash'],key,chain_hash),'VIEW manifest plan/chain/record')
    index_raw=index_bytes(m,h,mp[1][2],descriptors)
    require(len(index_raw)==640+288*part_count,'VIEW canonical index width')
    _carrier(manifest,mp[1],t.INDEX_SCHEMA,t.INDEX_CANON,index_raw,pin,stamp)
    return {'checkpointId':cp['id'],'adoptionRecord':p[1],'scope':json_values(scope),'sourceContextHash':p[2],
        'membershipHash':p[3],'policyChainHash':p[4],'tokenIds':list(map(str,tokens)),
        'outputs':json_values(outputs),'outputRoot':p[8],'manifestRecordHash':mp[7],
        'header':json_values(h),'partDescriptors':json_values(descriptors),
        'partBytes':tuple(parts),'indexBytes':index_raw,'qualification':dict(QUALIFICATION)}

EVENT_SIGNATURES={
    'checkpoint_started':'ViewCheckpointStarted(bytes32,bytes32,bytes32)',
    'checkpoint_appended':'ViewCheckpointAppended(bytes32,uint64,uint256,bytes32)',
    'checkpoint_sealed':'ViewCheckpointSealed(bytes32,bytes32,uint64)',
    'part_prepared':'ViewOutputPartPrepared(bytes32,bytes32,uint64,uint16)',
    'manifest_started':'ViewOutputManifestStarted(bytes32,bytes32,uint16)',
    'manifest_advanced':'ViewOutputManifestAdvanced(bytes32,uint16,bytes32)',
    'manifest_verified':'ViewOutputManifestVerified(bytes32,bytes32)',
    'coverage_completed':neutral.EVENT_SIGNATURES['coverageCompleted'],
}
EVENTS={key:schema_id(value) for key,value in EVENT_SIGNATURES.items()}

def expected_events(value,context,graph):
    """Exact native originals; coverage-plan topic is retained externally as a nonzero wildcard."""
    cp=value['checkpoint'];p=_v(t.CHECKPOINT_PLAN,cp['plan']);m=value['manifest'];mp=_v(t.MANIFEST_PLAN,m['plan'])
    result=[]
    def add(role,kind,topics,kinds,values):
        result.append({'kind':'view_'+kind,'address':graph[role]['address'],
            'topics':(EVENTS[kind],*topics),'data':'0x'+encode(kinds,values).hex()})
    add('checkpoint','checkpoint_started',(cp['id'],p[1]),('bytes32',),(cp['salt'],))
    for row in cp['outputs']:
        o=_v(t.OUTPUT,row)
        add('checkpoint','checkpoint_appended',(cp['id'],neutral._topic('uint256',o[1])),('uint64','bytes32'),
            (o[0],row_hash(uint(context['chainId']),graph['checkpoint']['address'],cp['id'],o)))
    add('checkpoint','checkpoint_sealed',(cp['id'],),('bytes32','uint64'),(p[8],p[5]))
    for row in m['parts']:
        part=_v(t.PART,row['record'])
        add('outputManifest','part_prepared',(row['recordHash'],cp['id']),('uint64','uint16'),part[2:4])
    add('outputManifest','manifest_started',(m['planHash'],cp['id']),('uint16',),(mp[2],))
    for index,row in enumerate(m['parts']):
        add('outputManifest','manifest_advanced',(m['planHash'],),('uint16','bytes32'),(index,row['recordHash']))
    add('outputManifest','manifest_verified',(m['recordHash'],m['planHash']),(),())
    covers={}
    for row in (*m['parts'],m):
        cover=_v(t.COVERAGE,row['coverage'])
        require(covers.setdefault(cover[0],cover)==cover,'VIEW conflicting reused coverage receipt')
    for cover in covers.values():add('coverage','coverage_completed',(cover[0],None),('uint16',t.COVERAGE),(1,cover))
    return tuple(result)
