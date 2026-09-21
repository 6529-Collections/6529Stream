"""Synthetic full-inventory bundle construction before any evidence is sealed.

Original archive observations/signatures are explicitly synthetic. This fixture
exercises complete source derivation and byte commitments, not deployed archive
acceptance, actual possession, signature validation, or renderer execution.
"""
from copy import deepcopy
from hashlib import sha256
from unittest.mock import patch

from . import view_preservation_bundle_wire_v1 as w
from . import view_preservation_inventory_types_v1 as t
from . import view_preservation_inventory_wire_v1 as inventory_wire
from . import view_preservation_inventory_items_v1 as inventory_items
from . import view_preservation_output_wire_v1 as output_wire
from . import view_preservation_output_types_v1 as output_types
from . import view_preservation_reference_wire_v1 as reference_wire
from .canonical import hex_bytes, keccak256 as K, schema_id as D
from .chain_abi import decode, encode
from .independent_wire import ZERO as Z, json_values
from .test_view_preservation_bundle_wire_v1 import checkpoint, zero, binding_reads


def H(label):return D('full VIEW bundle synthetic '+label)
def A(n):return '0x'+n.to_bytes(20,'big').hex()
def digest(raw):return '0x'+sha256(raw).hexdigest()
def encoded(kinds,values):return '0x'+encode(kinds,values).hex()
def hash_(kinds,values):return K(encode(kinds,values))


def signed_originals(host,chain,object_key,families,sha_hash,content,size,arweave=Z,*,external):
    """Retained original preimages only; synthetic signatures are not verified."""
    receipts=[];fixities=[];rkeys=[];fkeys=[];hashes=[]
    native_key=H('checkpoint '+object_key)
    for index,family in enumerate(families):
        locator=hex_bytes(H('locator '+object_key)) if index==0 else ('https://synthetic.invalid/'+object_key[2:]).encode()
        record=(object_key,family,K(locator),D('CONTENT_ADDRESSED_INCLUSION' if index==0 else 'ATTESTED_POSSESSION'),
            H('proof profile'),native_key if index==0 else H('possession '+object_key),A(85000+index),100,index,200)
        domain='6529STREAM_EXTERNAL_RECEIPT_V1' if external else '6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1'
        key=w._domain(domain,('uint256','address',w.RECEIPT),(chain,host,record));rkeys.append(key)
        raw=encode((w.RECEIPT,'bytes','bytes'),(record,locator,b'synthetic unverified signature'))
        receipts.append('0x'+raw.hex());hashes.append(hash_(('bytes32','bytes'),(key,raw)))
        if external:
            fixity=(key,object_key,family,K(locator),H('fixity profile'),sha_hash,sha_hash,
                content,content,arweave,arweave,size,size,101,1,H('fixity report'),Z,Z,A(85100+index),index,200)
            kind=w.EXTERNAL_FIXITY;domain='6529STREAM_EXTERNAL_FIXITY_V1'
        else:
            fixity=(key,object_key,family,sha_hash,sha_hash,size,101,1,H('fixity report'),Z,Z,A(85100+index),index,200)
            kind=w.ARCHIVE_FIXITY;domain='6529STREAM_ARCHIVAL_FIXITY_RECORD_V1'
        key=w._domain(domain,('uint256','address',kind),(chain,host,fixity));fkeys.append(key)
        raw=encode((kind,'bytes'),(fixity,b'synthetic unverified fixity signature'));fixities.append('0x'+raw.hex())
    # The aggregate bundle orders both receipts before both fixities.
    for key,raw in zip(fkeys,fixities):hashes.append(hash_(('bytes32','bytes'),(key,hex_bytes(raw))))
    native,native_hash=checkpoint(native_key,external,transaction_id=H('locator '+object_key),
        data_root=arweave,data_size=size,payload_digest=sha_hash,content_hash=content)
    hashes.append(native_hash)
    return {'receipts':receipts,'fixities':fixities,'checkpoint':native},rkeys,fkeys,hashes


def external_original(obj,context,graph):
    obj=w._v(w.OBJECT,obj);chain=int(context['chainId']);host=graph['externalCoverage']['address']
    key=w.external_object_hash(obj,chain,host,context['core']);families=(H('endowed external family'),H('possession external family'))
    original,rkeys,fkeys,hashes=signed_originals(host,chain,key,families,obj[4],obj[3],obj[6],obj[5],external=True)
    checkpoint_key=decode((w.EXTERNAL_NATIVE,),hex_bytes(original['checkpoint']['record']),maximum=65536)[0][0]
    coverage=(Z,key,obj[0],*obj[3:7],*families,*rkeys,*fkeys,checkpoint_key,D('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1'))
    coverage=(w.external_coverage_hash(coverage,chain,host),*coverage[1:])
    original={'object':json_values(obj),**original}
    bundle=hash_(('address','bytes32',t.ADMISSION[3],('bytes32',)*5),
        (host,graph['externalCoverage']['runtimeHash'],coverage,tuple(hashes)))
    return coverage,original,bundle


def _repair_external_reference(value,context,graph,originals):
    ref=value['reference']
    for row in ref['history']:
        objects={x['objectHash']:w._v(w.OBJECT,x['identity']) for x in row['objects']}
        replacement={}
        for key,obj in objects.items():
            coverage,source,bundle=external_original(obj,context,graph)
            assert coverage[1]==key
            replacement[key]=coverage;originals[key]=(coverage,source,bundle)
        p=row['publication'][1];env=p[8]
        c=replacement[env[0]];env[1]=c[0];row['source'][6]=json_values(c)
        raw=reference_wire.environment_bytes(w._v(reference_wire.t.ENVIRONMENT,env))
        env[2:4]=[K(raw),str(len(raw))];row['environment']='0x'+raw.hex()
        for capture,sample in zip(p[7],row['source'][7]):
            c=replacement[capture[6]];capture[7]=c[0];capture[10]=env[2];sample[2]=json_values(c)
        # Environment file inventories remain exact and unchanged.
    from .test_view_preservation_reference_wire_v1 import reseal
    reseal(ref,context,graph)


def _repair_output_artifacts(value,context,graph):
    """Replace fixture-only artifact labels with actual native artifact hashes."""
    from .view_preservation_inventory_fixture_v1 import _source_events
    from .test_view_preservation_snapshot_wire_v1 import supplied as snapshot
    from .test_view_preservation_root_wire_v1 import supplied as root
    from . import view_preservation_adoption_wire_v1 as adoption
    from . import view_policy_membership_v2 as membership
    from .test_view_preservation_output_wire_v1 import carrier
    row=value['reference']['history'][0];bundle=row['sourceProof']['bundle'];output=bundle['output']
    cfg=output['configuration'];m=w._v(output_types.MANIFEST_CONFIG,cfg['manifest'])
    cp=output['checkpoint'];plan=w._v(output_types.CHECKPOINT_PLAN,cp['plan']);header=output_wire.header(cp['id'],plan)
    host=graph['outputManifest']['address'];chain=int(context['chainId']);descriptors=[]
    def repair(carrier_,evidence,schema,canon):
        raw=b''.join(hex_bytes(x['runtime'])[1:] for x in evidence['chunks'])
        chunks=[hex_bytes(x['runtime'])[1:] for x in evidence['chunks']]
        artifact=(carrier_[2],schema,canon,1,K(raw),len(raw),tuple(K(x) for x in chunks),tuple(map(len,chunks)))
        key=w.artifact_hash(artifact,chain,graph['coverage']['address'],context['core'])
        updated=(key,*carrier_[1:]);evidence['coverage'][1]=key
        return updated
    for part in output['manifest']['parts']:
        record=list(w._v(output_types.PART,part['record']))
        record[1]=repair(record[1],part,output_types.PART_SCHEMA,output_types.PART_CANON)
        key=output_wire.part_hash(chain,host,cfg['manifestHash'],tuple(record))
        descriptor=output_wire.descriptor(key,tuple(record))
        part.update(recordHash=key,record=json_values(record),descriptor=json_values(descriptor));descriptors.append(descriptor)
    artist=output['manifest']['coverage'][2]
    raw=output_wire.index_bytes(m,header,artist,descriptors)
    saved,evidence=carrier(raw,artist,output_types.INDEX_SCHEMA,output_types.INDEX_CANON,'full bundle index',106)
    saved=repair(saved,evidence,output_types.INDEX_SCHEMA,output_types.INDEX_CANON)
    key=output_wire.manifest_plan_hash(chain,host,cfg['manifestHash'],header,saved)
    chain_hash=output_wire.part_chain(key,header,descriptors)
    record=output_wire.manifest_record_hash(chain,host,cfg['manifestHash'],key,chain_hash)
    manifest=(header,saved,len(descriptors),len(descriptors),plan[5],cp['outputs'][-1][1],chain_hash,record)
    output['manifest'].update(planHash=key,recordHash=record,plan=json_values(manifest),**evidence)
    a=adoption.validate(bundle['adoption'],context,{k:graph[k] for k in adoption.t.GRAPH_KEYS})
    member=membership.validate(bundle['membership'],context,graph,a['policyBinding'])
    a.update(tokenIds=member['tokenIds'],policies=member['policies'])
    bundle['snapshot'],_,_=snapshot(context=context,graph=graph,output_value=output,adoption=a,membership=member,recorded_at=107)
    bundle['root'],*_=root(context=context,graph=graph,snapshot_value=bundle['snapshot'],output_value=output,published_at=109)
    snap=bundle['snapshot']['history'][0];root_=bundle['root']['history'][-1]
    row['publication'][1][4]=row['receipt'][1][9]=snap['receipt'][0]
    row['source'][1:6]=deepcopy([snap['receipt'],snap['source'],root_['recordHash'],root_['record'],root_['binding']])
    row['sourceProof']['events']=_source_events(bundle,context,graph)


def onchain_original(part,artist,context,graph):
    coverage=w._v(t.ADMISSION[4],part['coverage']);chunks=[];hashes=[];lengths=[]
    source_host=A(86000);source_hash=H('chunk archive runtime');chain=int(context['chainId'])
    parts=bundles=Z
    for index,entry in enumerate(part['chunks']):
        runtime=hex_bytes(entry['runtime']);raw=runtime[1:];hashes.append(K(raw));lengths.append(len(raw))
        env=(artist,K(raw),D('6529STREAM_FINALITY_ARTIFACT_CHUNK_V1'),D('BINARY_EXACT_V1'),2,digest(raw),len(raw),1,Z)
        env_key=w._domain('6529STREAM_ARCHIVAL_CHUNK_ENVELOPE_V1',
            ('uint256','address',w.ENVELOPE,'address','bytes32'),(chain,source_host,env,entry['pointer'],K(runtime)))
        original,rkeys,fkeys,original_hashes=signed_originals(source_host,chain,env_key,coverage[8:10],digest(raw),K(raw),len(raw),external=False)
        native_key=decode((w.ARCHIVE_NATIVE,),hex_bytes(original['checkpoint']['record']),maximum=65536)[0][0]
        ac=(Z,env_key,artist,K(raw),*coverage[8:10],*rkeys,*fkeys,native_key,D('6529STREAM_PUBLIC_DUAL_FAMILY_ARCHIVAL_V1'))
        ac=(w.archive_coverage_hash(ac,chain,source_host),*ac[1:])
        envelope=encode((w.ENVELOPE,'bytes'),(env,raw));original_hashes.append(K(envelope))
        archive_hash=hash_(('address','bytes32',w.ARCHIVE_COVERAGE,('bytes32',)*6),
            (source_host,source_hash,ac,tuple(original_hashes)))
        parts=hash_(('bytes32','uint32','address','bytes32','bytes32','uint32'),(parts,index,entry['pointer'],K(runtime),K(raw),len(raw)))
        bundles=hash_(('bytes32','uint32','bytes32'),(bundles,index,archive_hash))
        chunks.append({'pointer':entry['pointer'],'runtime':entry['runtime'],'archive':{
            'host':source_host,'runtimeHash':source_hash,'coverage':json_values(ac),**original,'envelope':'0x'+envelope.hex()}})
    artifact=(artist,coverage[3],coverage[4],1,coverage[5],coverage[6],tuple(hashes),tuple(lengths))
    assert w.artifact_hash(artifact,chain,graph['coverage']['address'],context['core'])==coverage[1]
    bundle=hash_(('address','bytes32',t.ADMISSION[4],w.ARTIFACT,'bytes32','bytes32'),
        (graph['coverage']['address'],graph['coverage']['runtimeHash'],coverage,artifact,parts,bundles))
    return ((2,coverage[0],coverage[1]),bundle,parts,zero(t.ADMISSION[3]),coverage),{'artifact':json_values(artifact),'chunks':chunks}


def _state_sources(value):
    result={}
    def walk(node):
        if type(node) is dict:
            if all(k in node for k in ('evidenceHex','evidenceMetadata','pointerRuntime')):
                result[K(hex_bytes(node['evidenceHex']))]=node
            for child in node.values():walk(child)
        elif type(node) in (list,tuple):
            for child in node:walk(child)
    walk(value);return result


def supplied(count=1,mode='disabled',burned=False):
    """Return full inventory evidence and its bundle, validated independently."""
    from .view_preservation_inventory_fixture_v1 import supplied as inventory_fixture
    external={}
    def mutate(value,context,graph):
        _repair_output_artifacts(value,context,graph)
        _repair_external_reference(value,context,graph,external)
    # Observe the exact neutral constructor inputs in this test process. Every
    # constructor and complete source validator still runs unchanged; this only
    # collects already-derived bytes for synthetic external SHA256 declarations.
    byte_preimages={};original_bytes_item=inventory_items.bytes_item
    def retain_bytes(kind,role,source,record,index,raw):
        result=original_bytes_item(kind,role,source,record,index,raw)
        assert byte_preimages.setdefault(K(raw),raw)==raw
        return result
    with patch.object(inventory_items,'bytes_item',side_effect=retain_bytes):
        inventory,context,graph=inventory_fixture(count,mode,burned,reference_mutator=mutate)
        verified=inventory_wire.validate(inventory,context,graph)
    dependencies=(tuple(graph[k]['address'] for k in w.DEPENDENCY_ROLES),
        tuple(graph[k]['runtimeHash'] for k in w.DEPENDENCY_ROLES),int(context['chainId']),100000,8000000)
    selected=inventory['reference']['history'][0]['sourceProof']['bundle']['output']['manifest']
    onchain={entry['coverage'][1]:entry for entry in [selected,*selected['parts']]}
    original_state=_state_sources(inventory);artist=verified['evidence'][1][3];admissions=[]
    for rawitem in verified['items']:
        item=w._v(t.ITEM,rawitem);source=None
        if item[0] in (7,8,9,11):
            admission=((0,Z,Z),w._domain('EXPLICIT_INVENTORY_APPLICABILITY',(t.ITEM,),(item,)),Z,
                zero(t.ADMISSION[3]),zero(t.ADMISSION[4]))
        elif item[0]==10:admission,source=onchain_original(onchain[item[14]],artist,context,graph)
        elif item[0]==6:
            state=original_state['0x'+item[7].hex()];payload=hex_bytes(state['evidenceHex'])
            metadata=w._v(w.STATE_METADATA,state['evidenceMetadata']);runtime=hex_bytes(state['pointerRuntime'])
            parts=hash_(('address','bytes32','bytes32','address','bytes32','bytes32','uint32','uint64'),
                (item[2],graph['artistArchive']['runtimeHash'],item[3],metadata[1],K(runtime),metadata[0],metadata[2],metadata[3]))
            admission=((0,Z,Z),w._domain('STATE_RETAINED_ORIGINAL_AUTHORIZATION',(t.ITEM,'bytes32'),(item,parts)),
                parts,zero(t.ADMISSION[3]),zero(t.ADMISSION[4]))
            source={'payload':state['evidenceHex'],'metadata':json_values(metadata),'runtime':state['pointerRuntime'],
                'sourceRuntimeHash':graph['artistArchive']['runtimeHash']}
        else:
            if item[14]!=Z:coverage,source,bundle=external[item[14]]
            else:
                key='0x'+item[7].hex();size=item[9] or 1
                raw=byte_preimages.get(key) if item[5]==1 else None
                assert raw is None or (len(raw)==size and K(raw)==key)
                assert item[5]!=1 or raw is not None or item[9]==0
                obj=(artist,item[10] if item[10]!=Z else H('generic byte schema'),item[6],
                    key if item[5]==1 else H('declared content '+key),
                    key if item[5]==2 else digest(raw) if raw is not None else H('declared sha256 '+key),
                    H('declared arweave '+key),size,
                    item[11] if item[11]!=Z else H('raw format'),H('format catalogue'),H('format catalogue bytes'))
                coverage,source,bundle=external_original(obj,context,graph)
            admission=((1,coverage[0],coverage[1]),bundle,Z,coverage,zero(t.ADMISSION[4]))
        admissions.append({'item':json_values(item),'admission':json_values(admission),'sourceEvidence':source})
    body=verified['evidence'][1];chain=Z
    for index,row in enumerate(admissions):chain=w.covered_item(chain,body[0],index,row['item'],row['admission'])
    evidence=(verified['scope'],(body[0],body[11],len(admissions),chain,Z))
    evidence=(evidence[0],(*evidence[1][:4],w.coverage_hash(evidence,verified['evidence'],dependencies,
        context['chainId'],graph['bundleCoverage']['address'])))
    bundle={'profile':w.PROFILE,'dependencies':json_values(dependencies),
        'dependencyHash':hash_((t.BUNDLE_DEPENDENCIES,),(dependencies,)),'evidence':json_values(evidence),
        'progress':json_values((len(verified['segments']),0,len(admissions),Z,body[10],chain,Z,True)),
        'admissions':admissions,'sourceBindings':{'blockHash':context['blockHash'],
            'provenance':'synthetic_fixture','calls':binding_reads(admissions,graph)}}
    w.validate(bundle,context,graph,verified)
    return inventory,bundle,context,graph
