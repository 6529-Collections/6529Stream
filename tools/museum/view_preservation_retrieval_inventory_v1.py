"""Exact retrieval-enabled VIEW inventory; no legacy-profile projection.

The unchanged fd861 stage/checksum primitives are reused as functions. This
version owns its profile, artwork obligation, companion and item coordinates.
Getter bytes remain admitted observations, not proof of native execution.
"""
from . import view_preservation_inventory_types_v1 as it
from . import view_preservation_inventory_wire_v1 as old
from . import view_preservation_inventory_sources_v1 as sources
from . import view_preservation_inventory_items_v1 as items
from . import view_preservation_reference_types_v1 as rt
from . import view_preservation_reference_wire_v1 as reference
from . import view_policy_adoption_types_v2 as at
from . import view_preservation_output_types_v1 as ot
from . import view_preservation_retrieval_types_v1 as t
from . import view_preservation_bundle_wire_v1 as archive
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id, uint
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, json_values, require
from .native_finality_wire import _closed

SOURCE_REVISION=t.SOURCE_REVISION
PROFILE=t.INVENTORY_PROFILE
GRAPH_KEYS=old.GRAPH_KEYS
CLAIMS={**old.CLAIMS,'retrievalEnabledInventoryProfileChecked':True,
    'fullArtistPresentationBound':True,'immutableRetrievalCompanionBound':True,
    'networkRetrievalPerformed':False,'scopeEpochAuthenticityProven':False}
QUALIFICATION=('All twelve original stages, member bytes and the new retrieval obligation are checked. '
    'The immutable companion, sourceContext, dedicated item witness, admission and revocation epoch '
    'are bound to supplied native getter bytes. These observations do not authenticate themselves, '
    'prove signatures, current delivery, native execution or consensus.')


def _hash(kinds,values):return keccak256(encode(kinds,values))


def _call(host,signature,inputs=(),arguments=(),outputs=(),values=()):
    return {'target':host,'calldata':calldata(signature,inputs,arguments),
        'result':'0x'+encode(outputs,values).hex()}


def _observe(originals,calls):
    if originals is None:return
    for row in calls:
        key=(row['target'],row['calldata']);result=row['result']
        require(getattr(originals,'source_answers',{}).get(key,result)==result
            and originals.answers.setdefault(key,result)==result,
            'VIEW retrieval inventory conflicting original getter')
        originals.calls.append(dict(row))


def retrieval_source(value):
    """Exact ArtworkReads Source including retained full Artist presentation."""
    row,_,adopted,_=sources.selected(value['reference'])
    record=sources.typed(at.RECORD,adopted['record']);route=record[1][0]
    ss=sources.typed(rt.SOURCE,row['source'])[2]
    payload=decode((at.PAYLOAD,),hex_bytes(adopted['declaration']['viewPayload']),maximum=at.MAX_PAYLOAD)[0]
    return (ss[0],route[0],route[2],record[3],record[2],route[16][0],record[0][2],
        record[1][8],ss[3][4],payload[3],ss[2][3],_hash((t.ARTIST_PRESENTATION,),(ss[2],)))


def artwork_rows(value,c,d):
    # The six other rows and their exact ordering are unchanged. Construct
    # the changed image row directly from the new producer's full Source.
    from .view_preservation_retrieval_wire_v1 import obligation_item
    _,_,adopted,_=sources.selected(value['reference']);declaration=adopted['declaration']
    record=sources.typed(at.RECORD,adopted['record']);host=record[1][0][16][0];key=record[0][2]
    decl=(sources.typed(at.VIEW_MANIFEST,declaration['manifest']),sources.typed(at.VIEW_RECEIPT,declaration['receipt']),
        sources.typed(at.COLLECTION_RECORD,declaration['record']))
    raw=hex_bytes(declaration['viewPayload']);payload=decode((at.PAYLOAD,),raw,maximum=at.MAX_PAYLOAD)[0]
    rows=[items.bytes_item(0,'ORIGINAL_VIEW_DECLARATION_RECORD',host,key,0,encode(at.DECLARATION,decl)),
        items.bytes_item(2,'ORIGINAL_VIEW_DECLARATION_MANIFEST',host,key,0,hex_bytes(declaration['manifestPayload'])),
        items.bytes_item(2,'COMPLETE_ADOPTED_VIEW_PAYLOAD',host,key,0,raw),
        items.bytes_item(0,'COMPLETE_ADOPTED_VIEW_SCRIPT',host,key,0,payload[4]),
        items.bytes_item(0,'EXACT_ADOPTED_VIEW_IMAGE_URI',host,key,0,payload[3].encode()),
        obligation_item(retrieval_source(value)),items.absent('VIEW_EXTERNAL_LIBRARY_BUNDLE',host,key,0)]
    rows[2]=(*rows[2][:10],schema_id('STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2'),*rows[2][11:])
    return tuple(rows)


def stage_rows(value,c,d):
    ref=value['reference'];runtimes=value['runtimes'];documents=value['documents']
    return {0:sources.native_rows(c,d,ref,runtimes),1:sources.reference_rows(c,d,ref),
        8:artwork_rows(value,c,d),9:sources.renderer_rows(c,d,ref,value['rendererRegistration'],runtimes,documents),
        10:sources.admission_rows(c,d,ref,runtimes,documents),
        11:sources.token_rows(c,d,ref,value['members'],runtimes)}


def expected_reads(value,context,graph,c,d,p,e,segments):
    host=graph['inventory']['address'];identifier=e[1][0];calls=[]
    def call(name,args,result):
        inputs,outputs=it.FUNCTIONS[name]
        calls.append(_call(host,it.SIGNATURES[name],inputs,args,outputs,result))
    call('inventoryProfile',(),(PROFILE,));call('dependencies',(),(d,));call('dependencyHash',(),(value['dependencyHash'],))
    call('sourceContext',(identifier,),(c,));call('plan',(identifier,),(p,));call('tokenProgress',(identifier,),((0,0,0),))
    call('inventoryEvidence',(identifier,),(e,));call('requireCurrent',(c[0],),(e,))
    call('requireFullDefinitionBytes',(identifier,),())
    for index,segment in enumerate(segments):call('inventorySegment',(identifier,index),(segment,))
    call('requireCurrent',(c[0],),(e,))
    return calls


def _recorded(record,context,calls,provenance=None):
    _closed(record,('blockHash','provenance','calls'),'VIEW retrieval inventory observations')
    require(record['blockHash']==context['blockHash'] and record['provenance'] in
        ('synthetic_fixture','externally_admitted_rpc') and (provenance is None or record['provenance']==provenance)
        and record['calls']==calls,'VIEW retrieval inventory exact admitted reads')
    return record['provenance']


# Original IStreamExternalArtifactCoverage interface, including its explicit
# supportsInterface declaration; no inherited-selector approximation.
_family=it.signature((*('bytes32',)*8,'uint8','address','bytes32'))
_receipt=it.signature(archive.RECEIPT);_fixity=it.signature(archive.EXTERNAL_FIXITY)
EXTERNAL_INTERFACE=ot._interface(('supportsInterface(bytes4)','core()','roleRegistry()','checkpointVerifier()',
    'profileHash()','recordObject('+it.signature(archive.OBJECT)+')','objectIdentity(bytes32)',
    'familyRegistrationContext(string,'+_family+')','admitFamily(string,'+_family+')',
    'familyStatusContext(bytes32,uint8)','setFamilyStatus(bytes32,uint8)','family(bytes32)',
    'possessionHash('+_receipt+')','receiptDigest('+_receipt+')','recordReceipt('+_receipt+',bytes,bytes)',
    'receipt(bytes32)','fixityDigest('+_fixity+')','recordFixity('+_fixity+',bytes)','fixity(bytes32)',
    'latestFixity(bytes32)','recordCoverage(bytes32,bytes32)','coverage(bytes32)',
    'requireCoverage(bytes32,bytes32,bytes32)','nonceUsed(bytes32)'))


def binding_reads(binding,context,graph,witness,configuration,checkpoint_configuration):
    c=sources.typed(t.CONFIGURATION,configuration);d=sources.typed(it.DEPENDENCIES,binding['dependencies'])
    snap=sources.typed(t.SNAPSHOT_DEPENDENCIES,binding['snapshotDependencies']);host=graph['inventory']['address']
    wh=witness['address'];cp=graph['checkpoint']['address'];external=graph['externalCoverage']['address']
    return [_call(host,'supportsInterface(bytes4)',('bytes4',),(t.INVENTORY_BINDING_INTERFACE_ID,),('bool',),(True,)),
        _call(host,'dependencies()',outputs=(it.DEPENDENCIES,),values=(d,)),
        _call(host,'dependencyHash()',outputs=('bytes32',),values=(binding['dependencyHash'],)),
        _call(host,'retrievalWitnessBinding()',outputs=('address','bytes32'),values=(wh,witness['runtimeHash'])),
        _call(d[0][5],'dependencies()',outputs=(t.SNAPSHOT_DEPENDENCIES,),values=(snap,)),
        _call(wh,'supportsInterface(bytes4)',('bytes4',),(t.WITNESS_INTERFACE_ID,),('bool',),(True,)),
        _call(wh,'configuration()',outputs=(t.CONFIGURATION,),values=(c,)),
        _call(wh,'configurationHash()',outputs=('bytes32',),values=(_hash(('bytes32',t.CONFIGURATION),(t.PROFILE,c)),)),
        _call(wh,'retrievalProfile()',outputs=('bytes32',),values=(t.PROFILE,)),
        _call(cp,'configuration()',outputs=(ot.CHECKPOINT_CONFIG,),values=(checkpoint_configuration,)),
        _call(cp,'checkpointProfile()',outputs=('bytes32',),values=(ot.PROFILE,)),
        _call(cp,'supportsInterface(bytes4)',('bytes4',),(ot.CHECKPOINT_INTERFACE,),('bool',),(True,)),
        _call(external,'core()',outputs=('address',),values=(c[0],)),
        _call(external,'profileHash()',outputs=('bytes32',),values=(archive.EXTERNAL_PROFILE,)),
        _call(external,'supportsInterface(bytes4)',('bytes4',),(EXTERNAL_INTERFACE,),('bool',),(True,)),
        _call(c[2],'core()',outputs=('address',),values=(c[0],))]


def _binding(binding,value,context,graph,witness,configuration,provenance,originals):
    _closed(binding,('address','runtimeHash','profile','dependencies','dependencyHash',
        'retrievalWitnessBinding','snapshotDependencies','sourceBindings'),'VIEW retrieval inventory binding')
    d=sources.typed(it.DEPENDENCIES,binding['dependencies']);c=sources.typed(t.CONFIGURATION,configuration)
    _closed(witness,('address','runtimeHash','interfaceId'),'VIEW retrieval companion identity')
    require(any(hex_bytes(witness['address'],20)) and any(hex_bytes(witness['runtimeHash'],32))
        and witness['interfaceId']==t.WITNESS_INTERFACE_ID,'VIEW retrieval original companion interface/runtime')
    snap=sources.typed(t.SNAPSHOT_DEPENDENCIES,binding['snapshotDependencies'])
    _,bundle,_,_=sources.selected(value['reference'])
    require(binding['address']==graph['inventory']['address'] and binding['runtimeHash']==graph['inventory']['runtimeHash']
        and binding['profile']==PROFILE and binding['dependencies']==value['dependencies']
        and binding['dependencyHash']==value['dependencyHash']
        and tuple(binding['retrievalWitnessBinding'])==(witness['address'],witness['runtimeHash'])
        and binding['snapshotDependencies']==bundle['snapshot']['dependencies'],'VIEW retrieval immutable companion/source binding')
    require(c[:8]==(d[0][0],d[1][0],d[0][4],d[1][4],graph['checkpoint']['address'],graph['checkpoint']['runtimeHash'],d[0][11],d[1][11])
        and c[8]==d[6]==uint(context['chainId']) and c[9]>=50000 and c[10]>=c[9]
        and c[11]>=c[9] and c[12]>=90000 and max(c[10:])<=16777216,
        'VIEW retrieval companion configuration')
    require(snap[0][0]==c[0] and snap[1][0]==c[1] and snap[0][4]==c[2] and snap[1][4]==c[3]
        and snap[0][6]==c[4] and snap[1][6]==c[5] and snap[2]==c[8],
        'VIEW retrieval snapshot/checkpoint configuration')
    checkpoint=sources.typed(ot.CHECKPOINT_CONFIG,bundle['output']['configuration']['checkpoint'])
    require(checkpoint[:4]==c[:4] and checkpoint[9]==c[8],'VIEW retrieval checkpoint immutable source')
    raw=hex_bytes(value['runtimes'][witness['address']]);require(raw and keccak256(raw)==witness['runtimeHash'],
        'VIEW retrieval companion runtime bytes')
    pins={row['address']:row['runtimeHash'] for row in graph.values()}
    require(pins.get(witness['address'],witness['runtimeHash'])==witness['runtimeHash'],
        'VIEW retrieval companion runtime conflict')
    if originals is not None:originals.pin(witness['address'],witness['runtimeHash'])
    calls=binding_reads(binding,context,graph,witness,c,checkpoint)
    _recorded(binding['sourceBindings'],context,calls,provenance);_observe(originals,calls)
    return calls


def validate(inventory,context,graph,witness,configuration,*,originals=None):
    try:return _validate(inventory,context,graph,witness,configuration,originals)
    except MuseumError:raise
    except (KeyError,ValueError,TypeError,IndexError,OverflowError,StopIteration) as exc:
        raise MuseumError('malformed retrieval-enabled VIEW inventory') from exc


def _validate(inventory,context,graph,witness,configuration,originals):
    _closed(inventory,('value','binding'),'VIEW retrieval inventory envelope');value=inventory['value']
    _closed(value,('sourceRevision','profile','dependencies','dependencyHash','context','plan','evidence',
        'segments','recordedSource','reference','members','rendererRegistration','runtimes','documents','events'),
        'VIEW retrieval inventory value')
    require(len(dumps(value))<=old.MAX_EVIDENCE and value['sourceRevision']==SOURCE_REVISION
        and value['profile']==PROFILE,'VIEW retrieval inventory distinct native profile')
    native_graph={key:graph[key] for key in GRAPH_KEYS}
    d=old._dependencies(value,context,native_graph);c=sources.typed(it.CONTEXT,value['context'])
    reference.validate(value['reference'],context,{key:graph[key] for key in reference.GRAPH_KEYS})
    old._context(c,d,value['reference'],context)
    identifier=old.plan_id(d[6],graph['inventory']['address'],value['dependencyHash'],c)
    rows=stage_rows(value,c,d)
    segments,flat,chain=old._segments(value,c,d,identifier,rows,native_graph)
    p=sources.typed(it.PLAN,value['plan']);e=sources.typed(it.EVIDENCE,value['evidence'])
    original=(c[9],c[3][0],c[4][1][0],c[6][0][0] if c[6][0][1]==0 else ZERO,
        c[6][0][0] if c[6][0][1]==1 else ZERO,c[7],c[5][2],c[5][1])
    context_hash=_hash((it.CONTEXT,),(c,))
    body=(identifier,c[0][1],c[1],c[2],original,context_hash,c[10],c[20],len(segments),len(flat),chain,ZERO)
    digest=old.evidence_hash(d[6],graph['inventory']['address'],value['dependencyHash'],(c[0],body))
    require(e==(c[0],(*body[:-1],digest)),'VIEW retrieval inventory exact scoped evidence')
    progress=(c[0][1],c[1],c[2],context_hash,c[20],c[20],len(segments),len(flat),chain,11,digest)
    require(p==(c[0],progress,len(rows[0]),len(rows[0]),len(rows[1]),len(rows[1])),
        'VIEW retrieval inventory sealed progress')
    calls=expected_reads(value,context,native_graph,c,d,p,e,segments)
    provenance=_recorded(value['recordedSource'],context,calls);_observe(originals,calls)
    calls+=_binding(inventory['binding'],value,context,graph,witness,configuration,provenance,originals)
    old._events(value,context,native_graph)
    return d,{'sourceRevision':SOURCE_REVISION,'profile':PROFILE,'scope':c[0],'context':c,'evidence':e,
        'items':list(flat),'segments':list(segments),'dependencyHash':value['dependencyHash'],'planId':identifier,
        'provenance':provenance,'retrievalSource':retrieval_source(value),'recordedCalls':calls,
        'claims':dict(CLAIMS),'qualification':QUALIFICATION}


def item_binding_reads(row,result,context,graph,witness,epoch):
    item=sources.typed(it.ITEM,row['item']);saved=sources.typed(it.ADMISSION,row['savedAdmission'])
    index=uint(row['index'],64);plan=row['planId'];host=graph['bundleCoverage']['address']
    d=sources.typed(it.BUNDLE_DEPENDENCIES,row['environment']['dependencies'])
    onchain=sources.typed(('bytes32','uint64'),row['environment']['artifact'])
    external=sources.typed(('bytes32','uint64'),row['environment']['external'])
    return [_call(host,'dependencies()',outputs=(it.BUNDLE_DEPENDENCIES,),values=(d,)),
        *(_call(d[0][2],signature,outputs=('address',),values=(d[0][index],))
            for signature,index in (('core()',0),('metadataHost()',1),('artifactCoverage()',3),('externalCoverage()',4))),
        _call(d[0][3],'currentArtifactEnvironment()',outputs=('bytes32','uint64'),values=onchain),
        _call(d[0][4],'currentExternalArtifactEnvironment()',outputs=('bytes32','uint64'),values=external),
        _call(host,'retrievalWitnessForItem(bytes32,uint64)',('bytes32','uint64'),(plan,index),
            ('bytes32',),(row['witnessRecordHash'],)),
        _call(host,'admittedItem(bytes32,uint64)',('bytes32','uint64'),(plan,index),(it.ITEM,it.ADMISSION),(item,saved)),
        _call(witness['address'],'revocationEpoch('+it.signature(t.SCOPE)+')',(t.SCOPE,),(result['scope'],),('uint64',),(sources.typed('uint64',epoch),))]


def validate_item_binding(row,result,context,graph,witness,configuration,operative,epoch,*,originals=None):
    try:
        from .view_preservation_retrieval_wire_v1 import environment_hash,configuration_hash,source_key,obligation_item
        from .view_preservation_locator_wire_v1 import LOCATOR_ROLE
        _closed(row,('planId','index','item','witnessRecordHash','savedAdmission','originalEnvironment',
            'environmentHash','currentObservation','sourceBindings','environment'),'VIEW retrieval exact item coordinate')
        source=sources.typed(t.SOURCE,operative['source']);receipt=sources.typed(t.RECEIPT,operative['receipt'])
        admission=sources.typed(it.ADMISSION,operative['admission']);saved=sources.typed(it.ADMISSION,row['savedAdmission'])
        item=sources.typed(it.ITEM,row['item']);index=uint(row['index'],64)
        config=sources.typed(t.CONFIGURATION,configuration);c=result['context']
        require(row['planId']==result['planId'] and index<len(result['items']) and item==result['items'][index]
            and item==obligation_item(source) and source[0]==result['scope'] and source[1]==context['core']
            and source[2]==config[2] and (source[3],source[7],source[8],source[10])==(c[13],c[15],c[16],c[2])
            and row['witnessRecordHash']==receipt[0]!=ZERO,'VIEW retrieval actual plan/item/source coordinate')
        require(item[1] in (t.ROLE,LOCATOR_ROLE) and receipt[1]==source_key(source) and receipt[7]!=ZERO
            and admission[0][0]==1 and receipt[3:5]==(admission[0][2],admission[0][1])
            and admission[3][2]==source[10],'VIEW retrieval dedicated external correspondence')
        transformed=_hash(('bytes32','bytes32','address','bytes32','bytes32','bytes32','bytes32'),
            (t.ADMITTED_BUNDLE_DOMAIN,admission[1],witness['address'],witness['runtimeHash'],
                configuration_hash(configuration),receipt[0],receipt[7]))
        require(saved==(admission[0],transformed,*admission[2:]) and row['currentObservation']==operative['currentObservation'],
            'VIEW retrieval exact saved admission')
        environment=row['environment'];_closed(environment,('dependencies','artifact','external'),'VIEW retrieval original environment')
        d=sources.typed(it.BUNDLE_DEPENDENCIES,environment['dependencies'])
        require(d[0]==tuple(graph[k]['address'] for k in archive.DEPENDENCY_ROLES)
            and d[1]==tuple(graph[k]['runtimeHash'] for k in archive.DEPENDENCY_ROLES)
            and d[2]==uint(context['chainId']) and 50000<=d[3]<=d[4]<=old.MAX_GAS,
            'VIEW retrieval original bundle dependencies')
        onchain=sources.typed(('bytes32','uint64'),environment['artifact'])
        external=sources.typed(('bytes32','uint64'),environment['external'])
        require(row['originalEnvironment']==archive.environment_hash(d,*onchain,*external),
            'VIEW retrieval original environment preimage')
        require(row['environmentHash']==environment_hash(
            row['originalEnvironment'],witness['address'],witness['runtimeHash'],source[0],epoch),
            'VIEW retrieval exact scope epoch environment')
        calls=item_binding_reads(row,result,context,graph,witness,epoch)
        _recorded(row['sourceBindings'],context,calls,result['provenance']);_observe(originals,calls)
        return {'planId':row['planId'],'index':str(index),'recordHash':receipt[0],
            'environmentHash':row['environmentHash'],'calls':calls}
    except MuseumError:raise
    except (KeyError,ValueError,TypeError,IndexError,OverflowError) as exc:
        raise MuseumError('malformed VIEW retrieval item binding') from exc
