"""Closed conservation JSON profiles; exact prospective bytes, no authority or registration."""
import argparse
import copy
import datetime
import json
import re
from pathlib import Path

import jsonschema
import rfc8785
from Crypto.Hash import keccak

from . import conservation_language as language

ROOT = Path(__file__).resolve().parents[2]
ZERO = '0x' + '0' * 64
RAW = '0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f'
INTENT = 'STREAM_ARTIST_INTENT_V1'
WAIVER = 'STREAM_ARTIST_INTENT_WAIVER_V1'
INTERVIEW = 'STREAM_ARTIST_INTERVIEW_V1'
CATALOG = 'STREAM_CONSERVATION_FORMAT_CATALOG_V1'
FAMILIES = (INTERVIEW, INTENT, WAIVER, CATALOG)
PROFILES = {f: f[:-3] + '_JSON_PROFILE_V1' for f in FAMILIES}
H = {'type': 'string', 'pattern': '^0x[0-9a-f]{64}$'}
NH = {**H, 'not': {'const': ZERO}}
UINT = {'type': 'string', 'pattern': '^[1-9][0-9]*$', 'x-stream-maximum': str((1 << 256) - 1)}
PUID = r'(?:fmt|x-fmt)/[1-9][0-9]*'


class ConservationError(ValueError):
    pass


def canonical(value):
    return rfc8785.dumps(value)


def digest(raw):
    return '0x' + keccak.new(digest_bits=256, data=raw).hexdigest()


def closed(props):
    return {'type': 'object', 'properties': props, 'required': list(props), 'additionalProperties': False}


def text(n):
    return {'type': 'string', 'minLength': 1, 'maxLength': n, 'x-stream-max-utf8-bytes': n}


def array(items, nonempty=False):
    return {'type': 'array', 'items': items, **({'minItems': 1} if nonempty else {})}


def reference():
    return closed({'hash': {**closed({'algorithm': {'type': 'integer', 'enum': [1, 2, 3, 4, 5, 6]},
         'canonicalizationId': NH, 'digest': {'type': 'string', 'pattern': '^0x(?:[0-9a-f]{2}){1,128}$'}}),
         'x-stream-hash-width': True}, 'uri': {**text(2048), 'x-stream-content-uri': True}})


def mapping_schema():
    return {'oneOf': [closed({'kind': {'const': 'pronom'}, 'puid': {**text(32), 'pattern': '^' + PUID + '$'}}),
        closed({'kind': {'const': 'specification'}, 'specification': reference()})]}


def format_schema():
    return {'oneOf': [closed({'kind': {'const': 'pronom'}, 'formatId': NH, 'puid': {**text(32), 'pattern': '^' + PUID + '$'}}),
        closed({'kind': {'const': 'catalog'}, 'formatId': NH, 'mapping': mapping_schema(),
            'catalog': closed({'documentId': NH, 'documentHash': NH,
                              'name': {**text(128), 'pattern': '^[A-Za-z0-9_.-]+$'}})})]}


def payload_schema():
    return closed({'content': reference(), 'format': format_schema()})


def interview_entry():
    return {'oneOf': [closed({'kind': {'const': 'interview_waived'}, 'statement': reference()}),
        closed({'kind': {'const': 'present'}, 'payload': reference(), 'record': closed({
            'chainId': UINT, 'core': {'type': 'string', 'pattern': '^0x[0-9a-f]{40}$', 'not': {'const': '0x'+'0'*40}},
            'host': {'type': 'string', 'pattern': '^0x[0-9a-f]{40}$', 'not': {'const': '0x'+'0'*40}},
            'recordHash': NH, 'schemaId': {'const': digest(INTERVIEW.encode())},
            'profileHash': {'const': digest(canonical(profile(INTERVIEW)))}})})]}


def schema(family):
    common = {'version': {'type': 'integer', 'const': 1}, 'subjectId': NH, 'profileHash': NH,
              'predecessor': {'oneOf': [{'type': 'null'}, NH]}}
    artist = closed({'artistId': NH, 'bindingGeneration': {**UINT, 'x-stream-maximum': str((1 << 64)-1)},
                     'bindingHash': NH, 'statementOrigin': {'enum': ['artist_intent', 'estate_statement']}})
    if family == INTERVIEW:
        fields = {**common, 'instrument': {'oneOf': [
            closed({'kind': {'const': 'variable_media_questionnaire'}, 'document': reference()}),
            closed({'kind': {'const': 'named_derivative'}, 'name': text(512), 'document': reference()})]},
            'participants': array({'oneOf': [closed({'role': {'enum': ['artist','interviewer']}, 'identity': reference()}),
                closed({'role': {'const': 'other'}, 'roleLabel': text(128), 'identity': reference()})]}, True),
            'interviewDate': {'type': 'string', 'pattern': '^[0-9]{4}-[0-9]{2}-[0-9]{2}$', 'x-stream-date': True},
            'languages': array({**text(8192), 'x-stream-language': True}, True),
            'transcript': payload_schema(), 'captures': array(closed({'kind': {'enum': ['audio','video']}, 'payload': payload_schema()}))}
    elif family == INTENT:
        fields = {**common, 'artist': artist, 'display': closed({x: reference() for x in ('scale','timing','color','interaction','motion','frameRate')}),
            'variabilityTolerances': reference(), 'dependencyAging': reference(), 'significantProperties': reference(), 'interview': interview_entry()}
    elif family == WAIVER:
        fields = {**common, 'artist': artist, 'waiverStatement': reference(), 'interview': interview_entry()}
    elif family == CATALOG:
        fields = {'version': {'type': 'integer', 'const': 1}, 'entries': array(closed({'entryId': NH, 'mapping': mapping_schema()}), True)}
    else:
        raise ConservationError('unknown family')
    return {'$schema': 'https://json-schema.org/draft/2020-12/schema', 'title': family, **closed(fields),
            'x-stream-constraints': [
                'Complete RFC8785 canonical payload1..8192bytes; every field required and every selected variant closed. No normalization, inferred absence or arbitrary array count cap.',
                'The supported validator enforces every x-stream annotation plus exact profile and full external catalog witness correspondence. Generic JSON Schema alone is insufficient.',
                'References commit exact bytes and URI; no identity, retrieval, fixity, registration, archive coverage or carrier authority is proved.']}


def profile(family):
    if family not in FAMILIES:
        raise ConservationError('unknown family')
    return {'name': PROFILES[family], 'version': 1, 'schemaName': family, 'schemaHash': digest(canonical(schema(family))),
        'canonicalization': 'RFC8785_JCS', 'maxPayloadBytes': 8192,
        'references': 'Algorithms1/2/3/6 exact32bytes;4/5 opaque1..128bytes. CanonicalizationId nonzero; all digest values of the correct width are preserved. URI exact nonempty https/ipfs/ar, at most2048UTF8bytes under StreamMetadataRenderer lexical predicate. No retrieval, codec or fixity computation.',
        'scalars': 'Fixed ASCII keys; positiveuint256 and generationuint64 encoded as exact decimal strings, version and algorithm as small integers; hashes lowercase exact bytes. Dates proleptic Gregorian0001..9999. ValidUTF8; no case conversion, trimming, normalization or date coercion.',
        'arrays': 'Preserve all entries, duplicates and original order except catalog entry IDs must be unique. Participants/languages/catalog entries nonempty; captures explicitly may be empty. Only total8192 and named field byte bounds; no separate item count cap.',
        'interviewEntry': 'PRESENT pins STREAM_ARTIST_INTERVIEW_V1 and its exact supported profileHash plus actual chain/Core/host/recordHash and separate payload Reference. Consumer proves same subject and original record/payload plus dual-family coverage. WAIVED is a mandatory explicit statement Reference, never absent/default. Intent waiver also requires this union.',
        'artistClaim': 'ArtistId, binding generation/hash and artist_intent versus estate_statement are untrusted claims. Actual historical carrier must corroborate them; estate additions never retroactive living artist intent or implicit supersession after lock/estate. Pure profile does not prove an artist-signed waiver.',
        'intentMeaning': 'All six display fields, variability tolerances, dependency aging preferences covering migration/emulation/reinterpretation, significant properties and interview entry are individually referenced. Presence does not prove the content of those referenced statements.',
        'interviewMeaning': 'Instrument is VMQ with no derivative name or a named derivative plus document Reference. Participant roles and identity references are source declarations. Transcript required; optional captures explicitly audio/video with independent content and format. No inferred participants or consent.',
        'formatMeaning': 'PRONOM PUID is a scheme-qualified declaration; formatId=keccak256 UTF8 PRONOM: plus exact PUID. Catalog formatId selects one unique entry from the entire exact canonical catalog document including unselected entries; documentId=keccak256 UTF8 exact registration name. This supported catalog interpretation is separately versioned and does not replace other catalogs. Actual consumer proves registered catalog schema/profile/content, no format detection.',
        'languageSyntax': 'Solidity enforces complete RFC5646 ABNF, all26 grandfathered forms and case-insensitive duplicate variant/singleton rejection, preserving original case/order. This is well-formed syntax, not dated registration validity.',
        'languageValidity': {'tooling': 'RFC5646 section2.2.9 validity against original pinned IANA registry, including private-use ranges. No extension-specific semantics, Prefix recommendations, Preferred-Value rewriting or language/participant identity inference.',
            'rfc5646Sha256': language.RFC_SHA, 'registrySha256': language.REGISTRY_SHA, 'registryDate': language.REGISTRY_DATE},
        'admission': 'Exact expected profileHash is checked by pure versioned serializers; actual schema/profile/JCS registration, original receipt, subject, authority, retained interview, archives, locks/current selection/finality remain authenticated consumer obligations. These documents are prospective.'}


def _pairs(rows):
    out = {}
    for key, value in rows:
        if key in out:
            raise ConservationError('duplicate JSON key')
        out[key] = value
    return out


def load(raw):
    if not isinstance(raw, bytes) or not 0 < len(raw) <= 8192:
        raise ConservationError('complete payload bytes')
    def reject(_):
        raise ConservationError('noninteger JSON number')
    try:
        value = json.loads(raw.decode('utf8'), object_pairs_hook=_pairs, parse_float=reject, parse_constant=reject)
        if canonical(value) != raw:
            raise ConservationError('noncanonical JSON')
        return value
    except (ValueError, TypeError, UnicodeError, RecursionError) as exc:
        raise ConservationError(str(exc)) from exc


def _annotations(value, s):
    if 'oneOf' in s:
        branches = [b for b in s['oneOf'] if jsonschema.Draft202012Validator(b).is_valid(value)]
        if len(branches) != 1:
            raise ConservationError('closed union')
        _annotations(value, branches[0])
    if isinstance(value, dict):
        if s.get('x-stream-hash-width') and value['algorithm'] in (1,2,3,6) and len(value['digest']) != 66:
            raise ConservationError('fixed hash width')
        for key, item in value.items():
            _annotations(item, s.get('properties', {}).get(key, {}))
    elif isinstance(value, list):
        for item in value:
            _annotations(item, s.get('items', {}))
    elif isinstance(value, str):
        if 'pattern' in s and re.fullmatch(s['pattern'],value) is None:
            raise ConservationError('full lexical consumption')
        if len(value.encode('utf8')) > s.get('x-stream-max-utf8-bytes',8192):
            raise ConservationError('decoded UTF8 byte bound')
        if 'x-stream-maximum' in s and int(value) > int(s['x-stream-maximum']):
            raise ConservationError('unsigned overflow')
        if s.get('x-stream-date'):
            datetime.date.fromisoformat(value)
        if s.get('x-stream-language'):
            language.require_valid(value)
        if s.get('x-stream-content-uri'):
            if not value.startswith(('https://','ipfs://','ar://')):
                raise ConservationError('content URI scheme')
            offset = value.index('://')+3
            if len(value) == offset or any(ord(c)<=32 or ord(c)==127 for c in value) or value.startswith('https://') and value[offset] in '/?#':
                raise ConservationError('content URI lexical rule')


def _shape(raw, family):
    value = load(raw)
    s = schema(family)
    jsonschema.Draft202012Validator(s).validate(value)
    _annotations(value,s)
    if family != CATALOG and value['profileHash'] != digest(canonical(profile(family))):
        raise ConservationError('exact supported profile')
    if family == CATALOG:
        ids = [e['entryId'] for e in value['entries']]
        if len(ids) != len(set(ids)):
            raise ConservationError('catalog entry duplicate')
    return value


def validate(raw, family, catalogs=None):
    catalogs = {} if catalogs is None else catalogs
    try:
        value = _shape(raw,family)
        used = set()
        if family == INTERVIEW:
            payloads = [value['transcript']] + [x['payload'] for x in value['captures']]
            for payload in payloads:
                f = payload['format']
                if f['kind'] == 'pronom':
                    if f['formatId'] != digest(('PRONOM:'+f['puid']).encode()):
                        raise ConservationError('PRONOM identifier')
                else:
                    c = f['catalog']; name = c['name']; used.add(name)
                    if name not in catalogs or c['documentId'] != digest(name.encode()) or c['documentHash'] != digest(catalogs[name]):
                        raise ConservationError('complete catalog commitment')
                    catalog = _shape(catalogs[name],CATALOG)
                    entries = [e for e in catalog['entries'] if e['entryId'] == f['formatId']]
                    if len(entries)!=1 or entries[0]['mapping'] != f['mapping']:
                        raise ConservationError('selected catalog correspondence')
        if set(catalogs) != used:
            raise ConservationError('unused catalog witness')
        return value
    except (jsonschema.ValidationError, ValueError, TypeError, KeyError, UnicodeError) as exc:
        raise ConservationError(str(exc)) from exc


def examples():
    h = lambda n: '0x'+format(n,'064x')
    ref = lambda a=2: {'hash': {'algorithm':a, 'canonicalizationId':RAW, 'digest':h(3)}, 'uri':'ipfs://conservation-reference'}
    common = lambda f: {'version':1,'subjectId':h(1),'profileHash':digest(canonical(profile(f))),'predecessor':None}
    interview = {**common(INTERVIEW), 'instrument':{'kind':'variable_media_questionnaire','document':ref()},
        'participants':[{'role':'artist','identity':ref()},{'role':'interviewer','identity':ref(1)}],
        'interviewDate':'2024-02-29','languages':['EN-latn-US','i-klingon','x-exact'],
        'transcript':{'content':ref(),'format':{'kind':'pronom','puid':'fmt/111','formatId':digest(b'PRONOM:fmt/111')}},'captures':[]}
    catalog = {'entries':[{'entryId':h(20),'mapping':{'kind':'pronom','puid':'fmt/111'}},
        {'entryId':h(21),'mapping':{'kind':'specification','specification':ref(5)}}], 'version':1}
    catalog['entries'][1]['mapping']['specification']['hash']['digest']='0x00ff'
    craw=canonical(catalog)
    av=copy.deepcopy(interview);av['predecessor']=h(9)
    av['instrument']={'kind':'named_derivative','name':'Exact " \\ /\r\n\u0001 🎨 e\u0301','document':ref(6)}
    av['participants'].append({'role':'other','roleLabel':'Conservator','identity':ref(3)})
    av['captures']=[{'kind':k,'payload':{'content':ref(4 if k=='audio' else 5),'format':{
        'kind':'catalog','formatId':h(21),'catalog':{'name':'CONSERVATION_EXAMPLE_FORMATS_V1','documentId':digest(b'CONSERVATION_EXAMPLE_FORMATS_V1'),'documentHash':digest(craw)},
        'mapping':catalog['entries'][1]['mapping']}}} for k in ('audio','video')]
    av['captures'][0]['payload']['content']['hash']['digest']='0x'+'00ff'*64
    av['captures'][1]['payload']['content']['hash']['digest']='0x00'
    present={'kind':'present','payload':ref(),'record':{'chainId':str((1<<256)-1),'core':'0x'+'ab'*20,'host':'0x'+'cd'*20,
        'recordHash':h(4),'schemaId':digest(INTERVIEW.encode()),'profileHash':digest(canonical(profile(INTERVIEW)))}}
    waived={'kind':'interview_waived','statement':ref()}
    artist={'artistId':h(6),'bindingGeneration':str((1<<64)-1),'bindingHash':h(7),'statementOrigin':'artist_intent'}
    intent={**common(INTENT),'artist':artist,'display':{key:ref(i+1) for i,key in enumerate(('scale','timing','color','interaction','motion','frameRate'))},
        'dependencyAging':ref(),'significantProperties':ref(),'variabilityTolerances':ref(),'interview':present}
    estate=copy.deepcopy(intent);estate['artist']['statementOrigin']='estate_statement';estate['predecessor']=h(9);estate['interview']=waived
    waiver={**common(WAIVER),'artist':artist,'waiverStatement':ref(),'interview':waived}
    waiver_present=copy.deepcopy(waiver);waiver_present['interview']=present
    return {'interview-vmq.json':interview,'interview-derivative-av.json':av,'format-catalog.json':catalog,
            'intent-present.json':intent,'intent-estate-waived.json':estate,'intent-waiver.json':waiver,'intent-waiver-present.json':waiver_present}


def documents():
    return {**{f:canonical(schema(f)) for f in FAMILIES}, **{PROFILES[f]:canonical(profile(f)) for f in FAMILIES}}


def definitions(docs):
    out=['// SPDX-License-Identifier: MIT','pragma solidity ^0.8.19;','','/// @notice Exact prospective conservation documents, with no registration claim.','library StreamConservationDefinitions {']
    for label,f in [('INTERVIEW',INTERVIEW),('INTENT',INTENT),('WAIVER',WAIVER),('CATALOG',CATALOG)]:
        for suffix,name in [('SCHEMA',f),('PROFILE',PROFILES[f])]:
            key=label+'_'+suffix;raw=docs[name]
            identity=f'    bytes32 internal constant {key}_ID = keccak256("{name}");'
            if len(identity)>100:
                identity=f'    bytes32 internal constant {key}_ID =\n        keccak256("{name}");'
            out += [identity,
                    f'    bytes32 internal constant {key}_HASH =',f'        {digest(raw)};',f'    uint256 internal constant {key}_BYTES = {len(raw)};']
    return ('\n'.join(out+['}',''])).encode()


def outputs():
    docs=documents(); out={'schemas/records/'+n+'.json':raw for n,raw in docs.items()}
    ex=examples();catalogs={'CONSERVATION_EXAMPLE_FORMATS_V1':canonical(ex['format-catalog.json'])}
    for name,v in ex.items():
        f=CATALOG if name=='format-catalog.json' else INTERVIEW if name.startswith('interview-') else WAIVER if name.startswith('intent-waiver') else INTENT
        raw=canonical(v);validate(raw,f,catalogs if name=='interview-derivative-av.json' else {})
        out['schemas/records/examples/conservation/'+name]=raw
    out['smart-contracts/domains/records/StreamConservationDefinitions.sol']=definitions(docs)
    return out


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    for path,raw in outputs().items():
        p=ROOT/path
        if args.check:
            if not p.exists() or p.read_bytes()!=raw: raise ConservationError('generated bytes differ: '+path)
        else:
            p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
    print('Conservation eight definitions and seven complete examples match.' if args.check else 'Generated conservation definitions and examples.')


if __name__=='__main__':
    main()
