"""fd861 typed original payload serialization and complete ordered reference walks.

Pure byte correspondence only. Original publication, registered catalogs and
selection authority are authenticated by the fixed-stage consumer separately.
"""
import datetime

from tools.metadata import work_profile as work
from tools.metadata import conservation_profile as conservation
from . import view_preservation_inventory_types_v1 as t
from . import view_preservation_inventory_items_v1 as items
from .canonical import dumps, hex_bytes, keccak256, schema_id
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS, require
from .metadata_rights_source import validate_rights
from .native_finality_wire import from_json

RAW, JCS = items.RAW, schema_id('RFC8785_JCS')
NAMES = {'work':'WORK_Description', 'rights':'RIGHTS_Statement',
    'intent':'CONSERVATION_Intent', 'waiver':'CONSERVATION_IntentWaiver',
    'interview':'CONSERVATION_Interview'}


def _object(name, value):
    if name.endswith('[]'):
        return [_object(name[:-2], row) for row in value]
    if name in t.WITNESS_LAYOUTS:
        fields = [field.split() for field in t.WITNESS_LAYOUTS[name].split(';')]
        return {key:_object(kind, row) for (kind,key),row in zip(fields,value)}
    return value


def _typed(family, value):
    name = NAMES[family]
    kind = t._witness_type(name)
    result = from_json(kind, value)
    encode((kind,), (result,))
    return result, _object(name, result)


def _zero(value):
    if isinstance(value, dict): return all(_zero(v) for v in value.values())
    if isinstance(value, (list,tuple)): return len(value)==0
    return value in (0, False, '', b'', ZERO, ZERO_ADDRESS)


def _enum(value, names):
    require(type(value) is int and 0 <= value < len(names), 'typed reference enum')
    return names[value]


def _date(value):
    year, month, day = value // 10000, value // 100 % 100, value % 100
    return datetime.date(year,month,day).isoformat()


def _common(v):
    require(v['subjectId'] != ZERO and v['profileHash'] != ZERO, 'typed payload subject/profile')
    return {'subjectId':v['subjectId'], 'profileHash':v['profileHash'],
        'predecessor':None if v['predecessor']==ZERO else v['predecessor'], 'version':1}


def _reference(v):
    return {'hash':{'algorithm':v['algorithm'], 'canonicalizationId':v['canonicalizationId'],
        'digest':'0x'+v['digest'].hex()}, 'uri':v['uri']}


def _spec(v):
    return {'hash':{'algorithm':1, 'canonicalizationId':RAW, 'digest':v['digest']}, 'uri':v['uri']}


def _catalog(c, *, is_work=False):
    rows=[]
    for entry in c['entries']:
        kind=_enum(entry['kind'],('pronom','specification'))
        if kind=='pronom':
            require(_zero(entry['specification']), 'inactive catalog specification')
            mapping={'kind':kind,'puid':entry['puid']}
        else:
            require(entry['puid']=='', 'inactive catalog PUID')
            mapping={'kind':kind,'specification':(_spec if is_work else _reference)(entry['specification'])}
        rows.append({'entryId':entry['entryId'],'mapping':mapping})
    raw=dumps({'entries':rows,'version':1})
    (work.validate_catalog if is_work else lambda b:conservation.validate(b,conservation.CATALOG))(raw)
    selected=[row['mapping'] for row in rows if row['entryId']==c['selectedEntryId']]
    require(len(selected)==1, 'catalog complete selected entry')
    return raw,selected[0]


def _format(f, catalogs, *, is_work=False):
    names=('nondigital','pronom','catalog') if is_work else ('pronom','catalog')
    kind=_enum(f['kind'],names)
    if kind=='catalog':
        require(f['puid']=='' and f['formatId']==f['catalog']['selectedEntryId'], 'catalog format selection')
        c=f['catalog']; raw,mapping=_catalog(c,is_work=is_work)
        require(c['name'] not in catalogs or catalogs[c['name']]==raw, 'conflicting catalog name bytes')
        catalogs[c['name']]=raw
        return {'kind':kind,'formatId':f['formatId'],'mapping':mapping,
            'catalog':{'name':c['name'],'documentId':schema_id(c['name']),'documentHash':keccak256(raw)}}
    require(_zero(f['catalog']), 'inactive format catalog')
    if kind=='nondigital':
        require(f['puid']=='' and f['formatId']==ZERO, 'inactive nondigital fields')
        return {'kind':kind}
    return {'kind':kind,'formatId':f['formatId'],'puid':f['puid']}


def _work(v):
    out=_common(v); catalogs={}
    form=_enum(v['form'],('full','description_absent'));out['form']=form
    if form=='description_absent':
        require(_zero(v['full']), 'inactive full description')
        out['absence']={'reason':v['absence']['reason'],'date':_date(v['absence']['date'])}
    else:
        require(_zero(v['absence']), 'inactive description absence')
        f=v['full']; c=f['creator']; ck=_enum(c['kind'],('artist','named'))
        if ck=='artist':
            require(c['name']=='', 'inactive creator name')
            creator={'kind':ck,'artistId':c['artistId'],'association':{
                'bindingGeneration':str(c['bindingGeneration']),'bindingHash':c['bindingHash']}}
        else:
            require(c['artistId']==ZERO and c['bindingGeneration']==0 and c['bindingHash']==ZERO, 'inactive creator binding')
            creator={'kind':ck,'name':c['name']}
        c=f['creation']; dk=_enum(c['kind'],('date','range'))
        if dk=='date':
            require(c['end']==0, 'inactive creation end')
            creation={'kind':dk,'date':_date(c['start'])}
        else: creation={'kind':dk,'start':_date(c['start']),'end':_date(c['end'])}
        m=f['measurements']; mk=_enum(m['kind'],('measured','dimensionless_generative'))
        require(m['hasPixels'] or m['width']==m['height']==0, 'inactive pixel measurements')
        require(m['hasAspectRatio'] or _zero(m['aspectRatio']), 'inactive aspect ratio')
        require(m['hasDuration'] or _zero(m['durationSeconds']), 'inactive duration')
        require((m['hasPixels'] or m['hasAspectRatio'] or m['hasDuration']) == (mk=='measured'), 'measurement variant')
        measurements={'kind':mk}
        if m['hasPixels']: measurements['pixels']={'width':str(m['width']),'height':str(m['height']),'unit':'pixels'}
        for flag,key in (('hasAspectRatio','aspectRatio'),('hasDuration','durationSeconds')):
            if m[flag]: measurements[key]={k:str(x) for k,x in m[key].items()}
        e=f['edition']; ek=_enum(e['kind'],('unique','serial','open_series'));edition={'kind':ek}
        if ek=='serial':
            require(e['statement']=='', 'inactive serial statement')
            edition.update(number=str(e['number']),total=str(e['total']))
        else:
            require(e['number']==e['total']==0, 'inactive edition count')
            if ek=='open_series':edition['statement']=e['statement']
            else:require(e['statement']=='', 'inactive unique statement')
        variants=[]
        for row in f['languageVariants']:
            field=_enum(row['field'],('title','medium','creditLine','inscription','creatorName','alternateTitle'))
            value={'field':field,'language':row['language'],'value':row['value']}
            if field=='alternateTitle':value['alternateTitleIndex']=str(row['alternateTitleIndex'])
            else:require(row['alternateTitleIndex']==0, 'inactive alternate title index')
            variants.append(value)
        authorities=[{'role':_enum(row['role'],('creator','medium','technique')),
            'authority':_enum(row['authority'],('ulan','viaf','wikidata','getty_aat')),
            'identifier':row['identifier']} for row in f['authorityReferences']]
        out.update(title=f['title'],creator=creator,creation=creation,medium=f['medium'],
            format=_format(f['format'],catalogs,is_work=True),measurements=measurements,edition=edition,
            creditLine=f['creditLine'],alternateTitles=f['alternateTitles'],languageVariants=variants,authorityReferences=authorities)
        if f['hasInscription']:out['inscription']=f['inscription']
        else:require(f['inscription']=='', 'inactive inscription')
    raw=dumps(out)
    work.validate_payload(raw,catalog_bytes=next(iter(catalogs.values()),None))
    return raw


def _document(v):
    if not v['exists']:
        require(v['uri']=='' and v['digest']==ZERO, 'inactive RIGHTS document')
        return None
    return _spec(v)


def _rights(v):
    # RIGHTS has predecessor last, but uses the same canonical common fields.
    out=_common(v); grants={}
    statuses=('unspecified','granted','granted_with_conditions','denied')
    for name,grant in zip(('ai_training','derivative','exhibition','print','publication','reproduction'),v['grants'].values()):
        c=grant['conditions'];kind=_enum(c['kind'],('none','text','document'))
        if kind=='document':
            require(c['text']=='' and c['document']['exists'], 'RIGHTS document condition')
            condition={'kind':kind,'document':_document(c['document'])}
        else:
            require(_zero(c['document']), 'inactive RIGHTS condition document')
            if kind=='none':
                require(c['text']=='', 'inactive RIGHTS condition text');condition=None
            else:condition={'kind':kind,'text':c['text']}
        grants[name]={'conditions':condition,'status':_enum(grant['status'],statuses),'extension':grant['extension']}
    c=v['licensor'];kind=_enum(c['kind'],('artist','estate','institution','address'))
    identity={'kind':kind}
    if kind=='artist':
        require(c['name']=='' and c['account']==ZERO_ADDRESS, 'inactive RIGHTS licensor fields')
        identity['artistId']=c['artistId']
    elif kind=='address':
        require(c['name']=='' and c['artistId']==ZERO, 'inactive RIGHTS licensor fields')
        identity['address']=c['account']
    else:
        require(c['artistId']==ZERO and c['account']==ZERO_ADDRESS, 'inactive RIGHTS licensor fields')
        identity['name']=c['name']
    if v['openEnd']:require(v['endDate']==0, 'inactive RIGHTS end date')
    out.update(basis=_enum(v['basis'],('unspecified','copyright','license','statute','public_domain','contract')),
        effectiveDates={'start':_date(v['startDate']),'end':None if v['openEnd'] else _date(v['endDate'])},
        grants=grants,instrument=_document(v['instrument']),licensor={'identity':identity,
        'instrumentDigest':None if c['instrumentDigest']==ZERO else c['instrumentDigest']})
    if v['hasAiTrainingPermission']:
        require(v['aiTrainingPermission']==v['grants']['aiTraining']['status'], 'RIGHTS AI permission differs')
        out['AI_TRAINING_PERMISSION']=_enum(v['aiTrainingPermission'],statuses)
    else:require(v['aiTrainingPermission']==0, 'inactive RIGHTS AI permission')
    raw=dumps(out);validate_rights(raw,v['subjectId']);return raw


def _artist(v):
    return {'artistId':v['artistId'],'bindingGeneration':str(v['bindingGeneration']),
        'bindingHash':v['bindingHash'],'statementOrigin':_enum(v['origin'],('artist_intent','estate_statement'))}


def _entry(v):
    kind=_enum(v['status'],('present','interview_waived'))
    if kind=='interview_waived':
        require(_zero(v['record']), 'inactive interview record')
        return {'kind':kind,'statement':_reference(v['waiverStatement'])}
    require(_zero(v['waiverStatement']), 'inactive interview waiver')
    r=v['record']
    require(r['chainId']>0 and r['core']!=ZERO_ADDRESS and r['host']!=ZERO_ADDRESS and
        r['recordHash']!=ZERO and r['schemaId']==schema_id(conservation.INTERVIEW) and
        r['profileHash']==keccak256(dumps(conservation.profile(conservation.INTERVIEW))), 'interview record definition')
    return {'kind':kind,'payload':_reference(r['payload']),'record':{
        **{key:r[key] for key in ('core','host','recordHash','schemaId','profileHash')},'chainId':str(r['chainId'])}}


def _conservation(family,v):
    out=_common(v);catalogs={}
    if family in ('intent','waiver'):
        out.update(artist=_artist(v['artist']),interview=_entry(v['interview']))
        if family=='intent':
            out['display']={key:_reference(ref) for key,ref in v['display'].items()}
            for key in ('variabilityTolerances','dependencyAging','significantProperties'):out[key]=_reference(v[key])
        else:out['waiverStatement']=_reference(v['waiverStatement'])
    else:
        instrument=v['instrument'];kind=_enum(instrument['kind'],('variable_media_questionnaire','named_derivative'))
        out['instrument']={'kind':kind,'document':_reference(instrument['document'])}
        if kind=='named_derivative':out['instrument']['name']=instrument['name']
        else:require(instrument['name']=='', 'inactive interview instrument name')
        out['participants']=[]
        for p in v['participants']:
            role=_enum(p['role'],('artist','interviewer','other'))
            row={'role':role,'identity':_reference(p['identity'])}
            if role=='other':row['roleLabel']=p['otherRole']
            else:require(p['otherRole']=='', 'inactive participant label')
            out['participants'].append(row)
        def payload(p):return {'content':_reference(p['content']),'format':_format(p['format'],catalogs)}
        out.update(interviewDate=_date(v['interviewDate']),languages=v['languages'],transcript=payload(v['transcript']),
            captures=[{'kind':_enum(c['kind'],('audio','video')),'payload':payload(c['payload'])} for c in v['captures']])
    raw=dumps(out)
    conservation.validate(raw,{'intent':conservation.INTENT,'waiver':conservation.WAIVER,'interview':conservation.INTERVIEW}[family],catalogs=catalogs)
    return raw


def _serialize(family, value):
    _,v=_typed(family,value)
    return _work(v) if family=='work' else _rights(v) if family=='rights' else _conservation(family,v)


def serialize_work(value):return _serialize('work',value)
def serialize_rights(value):return _serialize('rights',value)
def serialize_intent(value):return _serialize('intent',value)
def serialize_waiver(value):return _serialize('waiver',value)
def serialize_interview(value):return _serialize('interview',value)


def _row(source,record,index,role,ref):
    row=list(items.empty(4,role,source,record,index))
    row[5:9]=(ref['algorithm'],ref['canonicalizationId'],ref['digest'],ref['uri'])
    return tuple(row)


def _simple_ref(v):
    return {'algorithm':1,'canonicalizationId':RAW,'digest':hex_bytes(v['digest']),'uri':v['uri']}


def _catalog_rows(source,record,index,c,*,is_work=False):
    raw,_=_catalog(c,is_work=is_work)
    row=list(_row(source,record,index,'REGISTERED_FORMAT_CATALOG',
        {'algorithm':1,'canonicalizationId':JCS,'digest':hex_bytes(keccak256(raw)),'uri':''}))
    row[0]=3;row[9]=len(raw);row[12:14]=(schema_id(c['name']),keccak256(raw));rows=[tuple(row)]
    for i,entry in enumerate(c['entries']):
        if entry['kind']==1:
            role='WORK_FORMAT_SPECIFICATION' if is_work else 'INTERVIEW_FORMAT_SPECIFICATION'
            row=list(_row(source,record,i,role,_simple_ref(entry['specification']) if is_work else entry['specification']))
            if not is_work:row[16]=keccak256(encode(('uint256','bytes32'),(index,entry['entryId'])))
            rows.append(tuple(row))
    return rows


def _entry_row(source,record,v):
    present=v['status']==0;r=v['record']
    row=list(_row(source,record,0,'PRESENT_INTERVIEW_PAYLOAD' if present else 'INTERVIEW_WAIVER',r['payload'] if present else v['waiverStatement']))
    if present:
        row[10]=r['schemaId']
        row[16]=keccak256(encode(('uint256','address','address','bytes32','bytes32'),
            tuple(r[key] for key in ('chainId','core','host','recordHash','profileHash'))))
    return tuple(row)


def _derive(family, source, record, expected, value):
    typed,v=_typed(family,value);raw=_serialize(family,typed)
    require(expected!=ZERO and keccak256(raw)==expected, 'typed original payload hash')
    rows=[]
    if family=='work':
        if v['form']==0 and v['full']['format']['kind']==2:
            rows=_catalog_rows(source,record,0,v['full']['format']['catalog'],is_work=True)
    elif family=='rights':
        if v['instrument']['exists']:rows.append(_row(source,record,0,'RIGHTS_INSTRUMENT',_simple_ref(v['instrument'])))
        for i,g in enumerate(v['grants'].values()):
            if g['conditions']['kind']==2:rows.append(_row(source,record,i,'RIGHTS_USE_CONDITION',_simple_ref(g['conditions']['document'])))
    elif family in ('intent','waiver'):
        if family=='intent':
            refs=list(v['display'].values())+[v[k] for k in ('variabilityTolerances','dependencyAging','significantProperties')]
            roles=('DISPLAY_SCALE','DISPLAY_TIMING','DISPLAY_COLOR','DISPLAY_INTERACTION','DISPLAY_MOTION','DISPLAY_FRAME_RATE',
                'VARIABILITY_TOLERANCES','DEPENDENCY_AGING','SIGNIFICANT_PROPERTIES')
            rows=[_row(source,record,i,role,ref) for i,(role,ref) in enumerate(zip(roles,refs))]
        else:rows=[_row(source,record,0,'ARTIST_INTENT_WAIVER',v['waiverStatement'])]
        rows.append(_entry_row(source,record,v['interview']))
    else:
        rows=[_row(source,record,0,'INTERVIEW_INSTRUMENT',v['instrument']['document'])]
        for i,p in enumerate(v['participants']):
            row=list(_row(source,record,i,'INTERVIEW_PARTICIPANT',p['identity']))
            row[16]=keccak256(encode(('uint8','string'),(p['role'],p['otherRole'])));rows.append(tuple(row))
        for i,(p,capturekind) in enumerate([(v['transcript'],None)]+[(c['payload'],c['kind']) for c in v['captures']]):
            row=list(_row(source,record,0 if i==0 else i-1,'INTERVIEW_TRANSCRIPT' if i==0 else 'INTERVIEW_CAPTURE',p['content']))
            f=p['format'];row[11]=f['formatId']
            if f['kind']==1:
                doc,_=_catalog(f['catalog']);row[12:14]=(schema_id(f['catalog']['name']),keccak256(doc))
            if capturekind is not None:row[16]=keccak256(encode(('uint8',),(capturekind,)))
            rows.append(tuple(row))
            if f['kind']==1:rows.extend(_catalog_rows(source,record,i,f['catalog']))
    return typed,raw,tuple(rows)


def derive_work(source,record,payload_hash,value):return _derive('work',source,record,payload_hash,value)
def derive_rights(source,record,payload_hash,value):return _derive('rights',source,record,payload_hash,value)
def derive_intent(source,record,payload_hash,value):return _derive('intent',source,record,payload_hash,value)
def derive_waiver(source,record,payload_hash,value):return _derive('waiver',source,record,payload_hash,value)
def derive_interview(source,record,payload_hash,value):return _derive('interview',source,record,payload_hash,value)
