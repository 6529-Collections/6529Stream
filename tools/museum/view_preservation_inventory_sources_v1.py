"""fd861 VIEW stage projections from complete retained source bytes.

These functions do not execute the native getters. The outer reader requires
recorded source reads and explicitly identifies their external trust boundary.
"""
from . import view_preservation_inventory_items_v1 as items
from . import view_preservation_reference_types_v1 as r
from . import view_preservation_snapshot_types_v1 as s
from . import view_preservation_output_types_v1 as o
from . import view_preservation_adoption_types_v1 as a
from . import view_policy_adoption_types_v2 as v
from .canonical import hex_bytes, keccak256, schema_id
from .chain_abi import encode, decode
from .independent_wire import ZERO, require
from .native_finality_wire import from_json, _bytes, _closed


def typed(kind,value):
    result=from_json(kind,value);encode((kind,),(result,));return result


def selected(reference):
    row=next(x for x in reference['history'] if x['receipt'][1][0]==reference['selectedRecordHash'])
    bundle=row['sourceProof']['bundle']
    adopted=next(x for x in bundle['adoption']['history']
        if x['record'][3]==bundle['adoption']['selectedRecordHash'])
    snap=next(x for x in bundle['snapshot']['history'] if x['receipt'][0]==row['source'][1][0])
    return row,bundle,adopted,snap


def object_item(source, record, index, carrier, part=False):
    row=list(items.empty(10,'COMPLETE_VIEW_OUTPUT_PART' if part else 'COMPLETE_VIEW_OUTPUT_INDEX',source,record,index))
    row[5:11]=(1,o.PART_CANON if part else o.INDEX_CANON,hex_bytes(carrier[3]),'',carrier[4],
        o.PART_SCHEMA if part else o.INDEX_SCHEMA)
    row[14:16]=carrier[:2]
    return tuple(row)


def native_rows(c,d,reference,runtimes):
    row,bundle,adopted,snap=selected(reference)
    f=typed(r.SOURCE,row['source']);ss=f[2];source=ss[3]
    sd=typed(s.DEPENDENCIES,bundle['snapshot']['dependencies'])
    require(sd[:2]==(tuple(d[0][i] for i in (0,1,2,3,4))+sd[0][5:8]+(d[0][10],sd[0][9]),
        tuple(d[1][i] for i in (0,1,2,3,4))+sd[1][5:8]+(d[1][10],sd[1][9])),
        'VIEW inventory snapshot dependency binding')
    original=c[3][0];rows=[]
    def b(role,host,key,raw,kind=0,index=0):
        rows.append(items.bytes_item(kind,role,host,key,index,raw))
    b('ORIGINAL_VIEW_PRESERVATION_SNAPSHOT_RECORD',d[0][5],original,
        encode((s.PUBLICATION,s.RECEIPT),(typed(s.PUBLICATION,snap['publication']),f[1])))
    b('VIEW_PRESERVATION_SNAPSHOT_MANIFEST',d[0][5],original,hex_bytes(snap['payload']),2)
    rows[-1]=(*rows[-1][:10],schema_id('STREAM_VIEW_PRESERVATION_SNAPSHOT_ABI_V1'),*rows[-1][11:])
    b('VIEW_PRESERVATION_NATIVE_SOURCE_FACTS',d[0][5],original,encode((s.SOURCE,),(ss,)))
    b('ORIGINAL_VIEW_CONTENT_ROOT',d[0][4],c[9],encode((s.ROOT_RECORD,),(f[4],)))
    b('ORIGINAL_VIEW_CONTENT_BINDING',d[0][4],c[9],encode((s.ROOT_BINDING,),(f[5],)))
    b('ORIGINAL_POLICY_VIEW_ADOPTION',d[0][4],c[13],encode((v.RECORD,),(source[0],)))
    b('ORIGINAL_VIEW_POLICY_BINDING',d[0][4],c[13],encode((o.VIEW_BINDING,),(source[1],)))
    b('VIEW_PRESERVATION_PRODUCER_BINDING',f[5][20],c[13],encode((o.PRESERVATION_BINDING,),(source[2],)))
    b('VIEW_PRESERVATION_GOVERNED_ADMISSION',source[3][0],c[13],encode((o.ADMISSION,),(source[3],)))
    b('VIEW_PRESERVATION_CONTENT_PLAN',sd[0][6],c[11],encode((o.CHECKPOINT_PLAN,),(ss[4],)))
    b('VIEW_PRESERVATION_OUTPUT_MANIFEST',sd[0][7],c[12],encode((o.MANIFEST_PLAN,),(ss[5],)))
    rows.append(object_item(sd[0][7],c[12],0,ss[5][1]))
    b('ORIGINAL_VIEW_COORDINATOR_POLICIES',source[1][4],original,encode((s.EVIDENCE,),(ss[6],)))
    for role,addresses,pins in (('VIEW_INVENTORY_DEPENDENCY_RUNTIME',d[0],d[1]),
            ('VIEW_SNAPSHOT_DEPENDENCY_RUNTIME',sd[0],sd[1]),
            ('ORIGINAL_ARTIST_DEPENDENCY_RUNTIME',d[2],d[3])):
        rows.extend(items.runtime(role,host,original,i,runtimes,pin) for i,(host,pin) in enumerate(zip(addresses,pins)))
    rows.append(items.runtime('ORIGINAL_ARTIST_CONTENT_OWNER_RUNTIME',d[4],original,0,runtimes,d[5]))
    require(ss[6][4] and ss[6][3]==len(ss[6][5]),'VIEW inventory complete frozen policy denominator')
    for i,policy in enumerate(ss[6][5]):
        rows.append(items.runtime('ORIGINAL_COORDINATOR_RUNTIME',policy[0],original,i,runtimes,policy[1]))
        b('ORIGINAL_COORDINATOR_FULL_POLICY',policy[0],original,encode((s.POLICY_ROW,),(policy,)),index=i)
    parts=bundle['output']['manifest']['parts']
    require(len(parts)==(c[20]+63)//64 and ss[5][2]==ss[5][3]==len(parts)
        and ss[5][4]==c[20], 'VIEW inventory complete manifest part denominator')
    for i,part in enumerate(parts):
        descriptor=typed(o.DESCRIPTOR,part['descriptor'])
        b('VIEW_PRESERVATION_COMPLETE_PART_DESCRIPTOR',sd[0][7],c[12],encode((o.DESCRIPTOR,),(descriptor,)),index=i)
        carrier=typed(o.PART,part['record'])[1]
        rows.append(object_item(sd[0][7],descriptor[0],i,carrier,True))
    return tuple(rows)


def reference_rows(c,d,reference):
    row,_,_,_=selected(reference)
    p=typed(r.PUBLICATION,row['publication'])[1];f=typed(r.SOURCE,row['source'])
    record=c[4][1][0];host=d[0][6]
    first=list(items.bytes_item(2,'VIEW_PRESERVATION_REFERENCE_MANIFEST',host,record,0,hex_bytes(row['payload'])))
    first[10]=schema_id(r.SCHEMA_NAME)
    rows=[tuple(first),items.bytes_item(0,'REFERENCE_ENVIRONMENT_DECLARATION',host,record,0,encode((r.ENVIRONMENT,),(p[8],)))]
    objects={x['objectHash']:typed(r.OBJECT,x['identity']) for x in row['objects']}
    def external(role,index,key,cov):
        obj=objects[key];result=list(items.empty(5,role,host,record,index))
        require(obj[0]==c[2] and obj[3]!=ZERO and obj[6]>0 and cov[1]==key,
            'VIEW inventory original external object')
        result[5:17]=(1,obj[2],hex_bytes(obj[3]),'',obj[6],obj[1],obj[7],obj[8],obj[9],key,cov[0],
            keccak256(encode((r.COVERAGE,),(cov,))))
        return tuple(result)
    rows.append(external('RUNNABLE_ENGINE_TOOLCHAIN_ZIP',0,p[8][0],f[6]))
    for platform,files in ((False,p[8][12]),(True,p[8][13])):
        for i,file in enumerate(files):
            result=list(items.empty(8 if platform else 11 if file[1]==0 else 4,
                'NATIVE_OS_PREREQUISITE' if platform else 'RUNNABLE_PACKAGE_MEMBER',host,record,i))
            if file[1]==0:
                require(file[2]=='0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
                    'VIEW inventory empty member digest')
            result[5:10]=(2,items.RAW,hex_bytes(file[2]),file[0],file[1]);rows.append(tuple(result))
    for i,(capture,sample) in enumerate(zip(p[7],f[7])):
        rows.append(external('REFERENCE_CAPTURE',i,capture[6],sample[2]))
        rows.append(items.bytes_item(0,'REFERENCE_CAPTURE_DECLARATION',host,record,i,encode((r.CAPTURE,),(capture,))))
    return tuple(rows)


def artwork_rows(c,d,reference):
    _,_,adopted,_=selected(reference);declaration=adopted['declaration']
    record=typed(v.RECORD,adopted['record']);host=record[1][0][16][0];key=record[0][2]
    decl=(typed(v.VIEW_MANIFEST,declaration['manifest']),typed(v.VIEW_RECEIPT,declaration['receipt']),
        typed(v.COLLECTION_RECORD,declaration['record']))
    raw=hex_bytes(declaration['viewPayload']);payload=decode((v.PAYLOAD,),raw,maximum=v.MAX_PAYLOAD)[0]
    rows=[items.bytes_item(0,'ORIGINAL_VIEW_DECLARATION_RECORD',host,key,0,encode(v.DECLARATION,decl)),
        items.bytes_item(2,'ORIGINAL_VIEW_DECLARATION_MANIFEST',host,key,0,hex_bytes(declaration['manifestPayload'])),
        items.bytes_item(2,'COMPLETE_ADOPTED_VIEW_PAYLOAD',host,key,0,raw),
        items.bytes_item(0,'COMPLETE_ADOPTED_VIEW_SCRIPT',host,key,0,payload[4]),
        items.bytes_item(0,'EXACT_ADOPTED_VIEW_IMAGE_URI',host,key,0,payload[3].encode()),
        items.media(host,key,payload[3]),items.absent('VIEW_EXTERNAL_LIBRARY_BUNDLE',host,key,0)]
    rows[2]=(*rows[2][:10],schema_id('STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2'),*rows[2][11:])
    return tuple(rows)


def admission_rows(c,d,reference,runtimes,documents):
    _,bundle,_,_=selected(reference);p=bundle['adoption']['preservation'];registry=p['registry']
    source=typed(r.SOURCE,selected(reference)[0]['source'])[2][3]
    reg=typed(a.PRESERVATION_RECORD,registry['record']);host=source[3][0]
    from .view_preservation_adoption_wire_v1 import preservation_key
    key=preservation_key(source[3][2],p['producerBinding'][0]);producer=reg[0][1][0]
    rows=[]
    def b(role,address,record,raw):rows.append(items.bytes_item(0,role,address,record,0,raw))
    b('VIEW_PRESERVATION_REGISTRATION',host,key,encode((a.PRESERVATION_RECORD,),(reg,)))
    reads=typed(a.READS,registry['reads']);targets=typed(a.TARGETS,registry['targets'])
    b('VIEW_PRESERVATION_DECLARED_READS',host,key,encode((a.READS,),(reads,)))
    b('VIEW_PRESERVATION_COMPLETE_TARGETS',host,key,encode((a.TARGETS,),(targets,)))
    b('VIEW_PRESERVATION_CONFIGURATION',producer,key,encode((a.CONFIGURATION,),(typed(a.CONFIGURATION,p['configuration']),)))
    b('VIEW_PRESERVATION_ACTUAL_ADOPTION_BINDING',producer,c[13],encode((a.BINDING,),(source[2],)))
    for role,address,pin in (('VIEW_PRESERVATION_PRODUCER_RUNTIME',producer,reg[0][1][1]),
            ('VIEW_PRESERVATION_ATTRIBUTION_RUNTIME',reg[0][1][7],reg[0][1][8]),
            ('VIEW_PRESERVATION_FIXED_WORKER_RUNTIME',p['worker'],p['workerRuntimeHash']),
            ('VIEW_PRESERVATION_ENCODING_RUNTIME',p['encoding'],p['encodingRuntimeHash'])):
        rows.append(items.runtime(role,address,key,0,runtimes,pin))
    for role,address,pin in (('VIEW_PRESERVATION_WORKER_BINDING',p['worker'],p['workerRuntimeHash']),
            ('VIEW_PRESERVATION_ENCODING_BINDING',p['encoding'],p['encodingRuntimeHash'])):
        b(role,producer,key,encode(('address','bytes32'),(address,pin)))
    rows.extend(items.document(identifier,digest,d[0][2],documents)
        for identifier,digest in zip(reg[0][2:5],(ZERO,reg[3],reg[4])))
    for i,target in enumerate(targets):
        row=list(items.runtime(target[2],target[0],key,i,runtimes,target[1]))
        row[16]=keccak256(encode(('address','bytes32',a.TARGET),(host,key,target)));rows.append(tuple(row))
    return tuple(rows)


def token_rows(c,d,reference,observations,runtimes):
    _,bundle,_,_=selected(reference);output=bundle['output'];saved=output['checkpoint']['outputs']
    require(type(observations) is list and len(observations)==len(saved)==c[20],
        'VIEW inventory every member output required')
    config=typed(o.CHECKPOINT_CONFIG,output['configuration']['checkpoint']);result=[]
    for i,(raw,supplied) in enumerate(zip(saved,observations)):
        _closed(supplied,('outputReturn','tokenData','json','html'),'VIEW inventory member bytes')
        row=typed(o.OUTPUT,raw)
        require(decode((o.OUTPUT,),_bytes(supplied['outputReturn'],992,'VIEW output return'))[0]==row,
            'VIEW inventory saved/full observed output differs')
        data=_bytes(supplied['tokenData'],16384,'VIEW tokenData')
        js=_bytes(supplied['json'],262144,'VIEW full JSON');html=_bytes(supplied['html'],262144,'VIEW full HTML')
        require(row[0]==i and keccak256(data)==row[6] and (keccak256(js),keccak256(html),len(js),len(html))==row[8:12],
            'VIEW inventory complete member bytes/hash/length')
        token=row[1];host=config[6]
        identity=encode(('uint256','uint256','uint256','bool','uint8','uint64'),(token,c[0][1],row[2],row[4],row[3],i))
        result.append((items.bytes_item(0,'VIEW_MEMBER_PERMANENT_IDENTITY',d[0][0],c[13],i,identity),
            items.bytes_item(0,'VIEW_TOKEN_DATA',d[0][0],c[13],token,data),
            items.bytes_item(0,'VIEW_FULL_POLICY_OUTPUT_ROW',host,c[11],i,encode((o.OUTPUT,),(row,))),
            items.bytes_item(0,'VIEW_FULL_PRESERVATION_JSON',host,c[13],token,js),
            items.bytes_item(0,'VIEW_FULL_PRESERVATION_HTML',host,c[13],token,html),
            items.runtime('VIEW_ORIGINAL_AT_MINT_COORDINATOR',row[7][0],c[13],token,runtimes,row[7][1])))
    return tuple(result)


RENDERER_REGISTRATION=('address',v.RENDERER_MANIFEST,*('bytes32',)*5)


def renderer_rows(c,d,reference,registration,runtimes,documents):
    _,bundle,adopted,_=selected(reference);saved=bundle['adoption']['preservation']['registry']
    declaration=adopted['declaration'];observed=declaration['renderer']
    source=typed(v.RECORD,adopted['record'])[1];selection=source[2];host=selection[0];key=selection[2]
    version=typed(a.VERSION,saved['version']);reg=typed(RENDERER_REGISTRATION,registration)
    targets=typed(a.TARGETS,saved['targets']);reads=typed(a.READS,saved['originalReads'])
    manifest=typed(v.RENDERER_MANIFEST,observed['manifest'])
    target_hash=keccak256(encode((a.TARGETS,),(targets,)))
    require(reg[:2]==(selection[3],manifest) and version[4]==selection[10]
        and version[5]==selection[9] and version[2:4]==selection[3:5]
        and keccak256(encode(('bytes32','uint256','address','address','bytes32','bytes32',RENDERER_REGISTRATION,a.READS),
            (schema_id('6529STREAM_RENDERER_REGISTRATION_V1'),d[6],host,d[0][2],d[1][2],target_hash,reg,reads)))==selection[10],
        'VIEW inventory original full renderer registration preimage')
    # Existing original preservation proof checks the complete sorted targets,
    # exact read set hash, target pins, and every nonzero selector.
    require(all(read[0]<len(targets) for read in reads),'VIEW inventory original renderer target index')
    rows=[]
    def b(role,address,record,raw):rows.append(items.bytes_item(0,role,address,record,0,raw))
    b('RENDERER_RETAINED_VERSION',host,key,encode((a.VERSION,),(version,)))
    b('RENDERER_REGISTRATION',host,key,encode((RENDERER_REGISTRATION,),(reg,)))
    b('RENDERER_DECLARED_READS',host,key,encode((a.READS,),(reads,)))
    b('RENDERER_COMPLETE_TARGETS',host,key,encode((a.TARGETS,),(targets,)))
    rows.append(items.runtime('RENDERER_REGISTRY_RUNTIME',host,key,0,runtimes,selection[1]))
    rows.append(items.runtime('SELECTED_RENDERER_RUNTIME',selection[3],key,0,runtimes,selection[4]))
    bindings=(typed(('address',)*4,observed['sourceTargets']),typed(('bytes32',)*4,observed['sourcePins']))
    b('RENDERER_SOURCE_BINDINGS',selection[3],key,encode((('address',)*4,('bytes32',)*4),bindings))
    rows.append(items.runtime('RENDERER_ENCODING_RUNTIME',observed['encoding'],key,0,runtimes,observed['encodingRuntimeHash']))
    policy=typed(o.VIEW_BINDING,adopted['policyBinding'])
    b('VIEW_RENDERER_FULL_POLICY_BINDING',selection[3],c[13],encode((o.VIEW_BINDING,),(policy,)))
    rows.extend(items.document(identifier,digest,d[0][2],documents)
        for identifier,digest in zip(reg[2:7],(manifest[4],ZERO,manifest[7],version[6],version[7])))
    for i,(address,pin) in enumerate(zip(*bindings)):
        row=list(items.runtime('VIEW_RENDERER_SOURCE_RUNTIME',address,c[13],i,runtimes,pin))
        row[16]=keccak256(encode(('address','bytes32'),(address,pin)));rows.append(tuple(row))
    for i,target in enumerate(targets):
        row=list(items.runtime(target[2],target[0],key,i,runtimes,target[1]))
        row[16]=keccak256(encode(('address','bytes32',a.TARGET),(host,key,target)));rows.append(tuple(row))
    return tuple(rows)
