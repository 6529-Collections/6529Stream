"""Finite original-field inventory after concrete canonical V4 reconstruction.

Schema applicability is independent of selection and of any target-format map.
Original native envelopes and opaque payloads remain lossless retention rows.
"""
from copy import deepcopy
from dataclasses import dataclass
import re

from jsonschema import Draft202012Validator

from . import canonical_object_dossier_v4 as dossier
from . import canonical_semantic_sources_v1 as pointers
from . import owner_family_semantics_v1 as owners
from . import object_dossier as package
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CANONICAL_FIELD_INVENTORY_V1'
MAX_OCCURRENCES = 16384
MAX_FIELDS = 262144
MAX_DEPTH = 64
MAX_BYTES = package.MAX_BYTES
CLAIMS = {'canonicalV4Replayed': True, 'retainedSemanticFamilyDenominatorsInventoried': True,
    'schemaApplicabilityIndependentOfSelection': True, 'originalArrayOrderPreserved': True,
    'globalSourceCompletenessProven': False, 'targetFormatMappingProven': False,
    'sourceOriginAuthenticated': False, 'schemaRegistrationInferred': False,
    'currentAuthorityProven': False, 'completeCanonicalDossier': False, 'networkFetch': False}
QUALIFICATION = ('Complete finite inventory of the retained V4 WORK/catalog, Owner, condition, '
    'Artist/General semantic, documentary Metadata and conservation occurrences before selection. '
    'Pinned supported schemas determine present, null and applicable absent fields. Unsupported '
    'originals retain exact structure and payload bytes without an invented schema. Physical literal '
    'bodies have an explicit retained convention, not a registered JSON Schema. Selection and native '
    'authority remain separate original evidence. All present fields are retention-only here; no '
    'target-format mapping, external receipt, current authority or global completeness is inferred.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'sourceProfileHash': dossier.PROFILE_HASH,
    'scope': ['WORK', 'WORK_CATALOG', 'OWNER_ALL_RETAINED_TYPES', 'CONDITION',
        'ARTIST_SEMANTIC', 'GENERAL_SEMANTIC', 'DOCUMENTARY_METADATA', 'CONSERVATION'],
    'denominator': 'Original occurrence order before selection; duplicate source occurrences remain separate.',
    'references': 'Paths use source/ relative to the enclosing correspondence package. Field pointer addresses '
        'the decoded domain source value; literal domains first apply decodePointer and parse the exact JCS string.',
    'fieldEncoding': 'Scalar exactHex is RFC8785 JSON; object exactHex lists sorted keys; array exactHex '
        'is its decimal length as a JSON string. Absent exactHex is 0x. Array indices retain source order.',
    'dispositions': ['retained_stream_only', 'not_applicable'],
    'schemaPolicy': 'Only exact retained supported definitions; local refs and instance-applicable '
        'oneOf/anyOf/allOf/if/dependentSchemas branches. Inactive tagged alternatives are not invented absent fields.',
    'limits': {'occurrences': MAX_OCCURRENCES, 'fields': MAX_FIELDS, 'depth': MAX_DEPTH, 'bytes': MAX_BYTES},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)
RULE = 'urn:6529stream:museum:canonical-field-inventory:v1:'


@dataclass(frozen=True)
class Evidence:
    inventory: bytes
    report: dict


def _escape(value):
    return str(value).replace('~', '~0').replace('/', '~1')


def _kind(value):
    result = {dict: 'object', list: 'array', str: 'string', bool: 'boolean', int: 'integer',
        type(None): 'null'}.get(type(value))
    require(result is not None, 'field inventory unsupported JSON scalar')
    return result


def _exact(value):
    return '0x' + dumps(sorted(value) if type(value) is dict else
        str(len(value)) if type(value) is list else value).hex()


def fields(value, definition=None):
    """Pure finite schema inventory; no source admission or mapping assertion.

    This extends the existing WORK inventory traversal for local schema refs,
    boolean schemas and applicable conditional branches. No remote resolution.
    """
    rows, decisions = [], []
    root = {} if definition is None else definition

    def schema_safe(spec, depth=0):
        require(depth <= MAX_DEPTH, 'field inventory schema depth bound')
        if type(spec) is dict:
            require(not set(spec).intersection(('$dynamicRef', '$recursiveRef', '$recursiveAnchor', '$dynamicAnchor')),
                'field inventory dynamic schema reference unsupported')
            if '$ref' in spec:
                require(type(spec['$ref']) is str and spec['$ref'].startswith('#/'),
                    'field inventory external schema reference unsupported')
            for child in spec.values(): schema_safe(child, depth + 1)
        elif type(spec) is list:
            for child in spec: schema_safe(child, depth + 1)

    schema_safe(root)
    validator = Draft202012Validator(root)
    require(definition is None or validator.is_valid(value), 'field inventory payload/schema disagreement')

    def active(spec, location, item, pointer, depth):
        require(depth <= MAX_DEPTH, 'field inventory recursive schema bound')
        if type(spec) is bool:
            require(spec, 'field inventory impossible false schema')
            return [({}, location)]
        result = [(spec, location)]
        if '$ref' in spec:
            ref = spec['$ref']
            target = pointers._resolve_value(root, ref[1:], 'json')
            result += active(target, ref, item, pointer, depth + 1)
        for keyword in ('oneOf', 'anyOf', 'allOf'):
            if keyword not in spec: continue
            valid = [i for i, branch in enumerate(spec[keyword]) if validator.evolve(schema=branch).is_valid(item)]
            require(valid and (keyword != 'oneOf' or len(valid) == 1)
                and (keyword != 'allOf' or len(valid) == len(spec[keyword])), 'field inventory branch disagreement')
            selected = [location + '/' + keyword + '/' + str(i) for i in valid]
            decisions.append({'pointer': pointer, 'schemaLocation': location, 'keyword': keyword, 'applicable': selected})
            for i, loc in zip(valid, selected): result += active(spec[keyword][i], loc, item, pointer, depth + 1)
        if 'if' in spec:
            selected = 'then' if validator.evolve(schema=spec['if']).is_valid(item) else 'else'
            decisions.append({'pointer': pointer, 'schemaLocation': location, 'keyword': 'if',
                'applicable': [location + '/' + selected] if selected in spec else []})
            if selected in spec: result += active(spec[selected], location + '/' + selected, item, pointer, depth + 1)
        if type(item) is dict:
            for key, branch in spec.get('dependentSchemas', {}).items():
                if key in item:
                    result += active(branch, location + '/dependentSchemas/' + _escape(key), item, pointer, depth + 1)
        return result

    def walk(specs, item, pointer, depth):
        require(depth <= MAX_DEPTH and len(rows) < MAX_FIELDS, 'field inventory depth/count bound')
        applicable = [pair for spec, loc in specs for pair in active(spec, loc, item, pointer, 0)]
        rows.append({'pointer': pointer, 'presence': 'present', 'kind': _kind(item), 'exactHex': _exact(item),
            'order': str(len(rows)), 'schemaLocations': sorted({loc for _, loc in applicable}) if definition is not None else [],
            'disposition': 'retained_stream_only', 'rule': RULE + 'exact-original-field',
            'reason': 'Original structural or value field retained; no target-format mapping asserted.'})
        if type(item) is dict:
            props = {}
            for spec, loc in applicable:
                for key, child in spec.get('properties', {}).items():
                    props.setdefault(key, []).append((child, loc + '/properties/' + _escape(key)))
            for key in sorted(set(item) | set(props)):
                child_pointer = pointer + '/' + _escape(key)
                children = list(props.get(key, []))
                if key not in item:
                    require(len(rows) < MAX_FIELDS, 'field inventory field count bound')
                    rows.append({'pointer': child_pointer, 'presence': 'absent', 'kind': 'absent', 'exactHex': '0x',
                        'order': str(len(rows)), 'schemaLocations': sorted(loc for _, loc in children),
                        'disposition': 'not_applicable', 'rule': RULE + 'applicable-property-absent',
                        'reason': 'Optional property from the instance-applicable schema is absent; no value is invented.'})
                    continue
                for spec, loc in applicable:
                    for pattern, child in spec.get('patternProperties', {}).items():
                        if re.search(pattern, key): children.append((child, loc + '/patternProperties/' + _escape(pattern)))
                if not children:
                    children = [(spec['additionalProperties'], loc + '/additionalProperties') for spec, loc in applicable
                        if type(spec.get('additionalProperties')) is dict]
                walk(children or [({}, '#')], item[key], child_pointer, depth + 1)
        elif type(item) is list:
            for i, child in enumerate(item):
                children = []
                for spec, loc in applicable:
                    if i < len(spec.get('prefixItems', [])): children.append((spec['prefixItems'][i], loc + '/prefixItems/' + str(i)))
                    elif 'items' in spec: children.append((spec['items'], loc + '/items'))
                walk(children or [({}, '#')], child, pointer + '/' + str(i), depth + 1)

    walk([(root, '#')], value, '', 0)
    require(len(rows) <= MAX_FIELDS, 'field inventory field count bound')
    return rows, decisions


class _Builder:
    def __init__(self, files, manifest_hash):
        self.files, self.manifest_hash = files, manifest_hash
        self.parsed, self.hashes = {}, {}
        self.rows, self.fields, self.branches, self.groups = [], [], [], []

    def load(self, path):
        if path not in self.parsed: self.parsed[path] = loads(self.files[path], maximum=MAX_BYTES, canonical=True)
        return self.parsed[path]

    def ref(self, path, pointer='', encoding='json'):
        if path not in self.hashes: self.hashes[path] = keccak256(self.files[path])
        ref = {'path': 'source/' + path, 'hash': self.hashes[path], 'jsonPointer': pointer, 'encoding': encoding}
        self.resolve(ref)
        return ref

    def resolve(self, ref):
        require(ref['path'].startswith('source/'), 'field inventory original reference base differs')
        path = ref['path'].removeprefix('source/')
        if path not in self.hashes: self.hashes[path] = keccak256(self.files[path])
        require(self.hashes[path] == ref['hash'], 'field inventory original reference hash differs')
        if ref['encoding'] == 'bytes':
            require(ref['jsonPointer'] == '', 'field inventory whole byte reference')
            return self.files[path]
        return pointers._resolve_value(self.load(path), ref['jsonPointer'], ref['encoding'])

    def relocate(self, ref, prefix):
        return self.ref(prefix + ref['path'], ref['jsonPointer'], ref['encoding'])

    def schema(self, path, expected=None, *, pointer='', encoding='bytes'):
        ref = self.ref(path, pointer, encoding)
        raw = self.resolve(ref)
        require(type(raw) is bytes and (expected is None or keccak256(raw) == expected), 'field inventory retained schema pin differs')
        parsed = loads(raw, maximum=524288)
        require(type(parsed) is dict and '$schema' in parsed, 'field inventory definition is not JSON Schema')
        return {'source': ref, 'hash': keccak256(raw), 'schemaId': schema_id(parsed.get('title', '')),
            'name': parsed.get('title')}, parsed

    def domain(self, occurrence, name, source, value, schema=None, *, convention=None):
        actual = self.resolve(source)
        if type(actual) is bytes:
            require(dumps(value) == actual, 'field inventory decoded source bytes differ')
        else: require(value == actual, 'field inventory original value differs')
        metadata, definition = (None, None) if schema is None else schema
        occurrence['domains'].append({'name': name, 'source': source, 'schema': metadata,
            'applicability': 'exact_retained_schema' if schema is not None else 'no_interpretation_schema',
            'convention': convention})
        fields_out, branches = fields(value, definition)
        require(len(self.fields) + len(fields_out) <= MAX_FIELDS, 'field inventory aggregate field bound')
        for row in fields_out:
            self.fields.append({'occurrenceId': occurrence['occurrenceId'], 'domain': name, **row})
        self.branches.extend({'occurrenceId': occurrence['occurrenceId'], 'domain': name, **row} for row in branches)

    def occurrence(self, family, selector, original_ref, original, *, identity=None, authority=None, currentness=None, selection=None):
        require(len(self.rows) < MAX_OCCURRENCES, 'field inventory occurrence bound')
        identifier = keccak256(dumps({'profileHash': PROFILE_HASH, 'sourceManifestHash': self.manifest_hash,
            'family': family, 'selector': selector, 'original': original_ref}))
        row = {'occurrenceId': identifier, 'originalOccurrenceId': identity, 'family': family,
            'selector': deepcopy(selector), 'original': original_ref, 'order': str(len(self.rows)),
            'authority': deepcopy(authority), 'currentness': deepcopy(currentness),
            'selection': deepcopy(selection), 'domains': []}
        self.rows.append(row)
        self.domain(row, 'original', original_ref, original)
        return row

    def canonical(self):
        path = 'canonical/inputs/source-inventory.json'; inventory = self.load(path)
        selection_path = 'canonical/inputs/selection.json'; selection = self.load(selection_path)
        selected = set(selection['selectedOccurrenceIds'])
        for old in inventory['rows']:
            original = self.relocate(old['pointers']['original'], 'canonical/input/')
            row = self.occurrence(old['family'], old['selector'], original, old['original'], identity=old['occurrenceId'],
                authority=old['authority'], currentness=old['currentness'], selection={
                    'selected': old['occurrenceId'] in selected, 'source': self.ref(selection_path)})
            if old['semantic'] is not None:
                family = old['family']
                if old['ownerMeaning'] is not None:
                    name = owners.SCHEMA_NAMES[family]
                    schema_path = 'canonical/definitions/owner-genesis-plan/definitions/' + schema_id(name)[2:] + '.json'
                    schema = self.schema(schema_path, owners.SCHEMA_HASHES[family])
                else:
                    from . import condition, work_lido_source
                    name = 'STREAM_WORK_DESCRIPTION_V1' if family == 'WORK' else 'STREAM_CONDITION_REPORT_V1'
                    expected = work_lido_source.WORK_SCHEMA_HASH if family == 'WORK' else condition.SCHEMA_HASH
                    schema = self.schema('canonical/definitions/native-source/' + name + '.json', expected)
                self.domain(row, 'payload', self.relocate(old['pointers']['payload'], 'canonical/input/'), old['semantic'], schema)
            if old['catalog'] is not None:
                cat = old['catalog']
                self.domain(row, 'catalog', self.relocate(cat['bytesSource'], 'canonical/input/'), cat['value'],
                    self.schema('canonical/definitions/native-source/STREAM_WORK_FORMAT_CATALOG_V1.json'))
            row['interpretation'] = deepcopy(old['interpretation'])
        self.groups.append({'family': 'canonical', 'source': self.ref(path), 'originalCount': str(len(inventory['rows'])),
            'denominators': deepcopy(inventory['denominators'])})

    def supplemental(self, prefix, family):
        semantic_path = prefix + 'semantics/snapshot.json'; semantic = self.load(semantic_path)
        state = self.load(prefix + ('sources/general/anchor.json' if family == 'GENERAL' else 'sources/metadata/anchor.json'))
        schema_path = prefix + 'semantics/documents/STREAM_SEMANTIC_ASSERTION_V1.json'
        selection_path = prefix + ('graph/selection.json' if family == 'GENERAL' else 'dossier.json')
        selection = self.load(selection_path)
        if family != 'GENERAL': selection = selection['selection']
        rows = semantic['statements']; seen = set()
        for i, old in enumerate(rows):
            source = {**old['source'], 'chainId': state['chainId'], 'core': state['core']}
            original = old['original']; seen.add(original['recordHash'])
            p = '/statements/' + str(i) + '/original'
            row = self.occurrence(family, source, self.ref(semantic_path, p), original,
                authority=old.get('authority', old.get('historicalAuthority')),
                currentness=old.get('currentQualification'), selection={'source': self.ref(selection_path),
                    'selectedAssertions': [r['source'] for r in selection['selected'] if r['source']['recordHash'] == original['recordHash']],
                    'withheldAssertions': [r['source'] for r in selection['withheld'] if r['source']['recordHash'] == original['recordHash']]})
            if old['status'] == 'supported':
                from .account_profile import ASSERTION_SCHEMA_BYTES
                schema = self.schema(schema_path, keccak256(ASSERTION_SCHEMA_BYTES))
                self.domain(row, 'payload', self.ref(semantic_path, p + '/payloadHex', 'hex'), old['value'], schema)
                self.literal_bodies(row, self.ref(semantic_path, p + '/payloadHex', 'hex'), old['value'])
            row['interpretation'] = {'status': old['status'], 'reason': old['reasonCode']}
        self.groups.append({'family': family, 'source': self.ref(semantic_path), 'originalCount': str(len(rows))})
        # The complete documentary catalogue is retained independently of which
        # references a selected assertion happened to use.
        path = prefix + 'sources/metadata/snapshot.json'; snapshot = self.load(path)
        for i, original in enumerate(snapshot['records']):
            if original['recordHash'] in seen and family == 'ARTIST': continue
            record = original['record']
            self.occurrence('DOCUMENTARY_METADATA', {'chainId': state['chainId'], 'core': state['core'],
                'host': state['metadata'] if family == 'GENERAL' else state['host'], 'recordHash': original['recordHash'],
                'subjectId': record[1], 'schemaId': record[4], 'canonicalizationId': record[2][2]},
                self.ref(path, '/records/' + str(i)), original, authority=original['authority'])
        self.groups.append({'family': family + '_METADATA', 'source': self.ref(path),
            'originalCount': str(len(snapshot['records'])), 'sameArtistRecordsAlreadyInventoried': str(len(seen) if family == 'ARTIST' else 0)})
        if family == 'ARTIST' and prefix + 'sources/general/snapshot.json' in self.files:
            self.general_originals(prefix + 'sources/general/')

    def general_originals(self, prefix):
        """Optional General catalogue retained by an Artist attribution child.

        The original General account receipt never borrows Artist authority.
        Only frozen known schema bytes permit a shape inventory; this is not
        admission into the distinct General semantic interpretation profile.
        """
        from .account_profile import ASSERTION_SCHEMA_BYTES
        from tools.metadata import identity_notarization_profile as notarization
        path = prefix + 'snapshot.json'; snapshot = self.load(path)
        state = snapshot['sourceState']
        known = {keccak256(raw): raw for raw in (ASSERTION_SCHEMA_BYTES, notarization.canonical(notarization.schema()))}
        documents = {row['documentId']: (i, row) for i, row in enumerate(snapshot['documents'])}
        for i, original in enumerate(snapshot['records']):
            value, receipt = original['value'], original['receipt']
            row = self.occurrence('GENERAL_ORIGINAL', {'chainId': state['chainId'], 'core': state['core'],
                'host': snapshot['host'], 'recordHash': original['recordHash'], 'subjectId': value[2],
                'recordType': value[3], 'schemaId': value[5], 'canonicalizationId': value[6]},
                self.ref(path, '/records/' + str(i)), original, authority=original['interpretation'],
                selection={'selected': False, 'reason': 'Retained original General catalogue; no semantic selection in this child.'})
            row['interpretation'] = {'status': 'opaque', 'reason': 'no_supported_exact_schema_payload'}
            match = documents.get(value[5])
            if match is None or receipt[11] not in known or value[6] != schema_id('RFC8785_JCS'): continue
            index, document = match; schema_raw = hex_bytes(document['payloadHex'])
            if schema_raw != known[receipt[11]]: continue
            raw = hex_bytes(original['payloadHex'])
            try: parsed = loads(raw, maximum=524288, canonical=True)
            except MuseumError: continue
            definition = loads(schema_raw, maximum=524288)
            if value[5] != schema_id(definition.get('title', '')): continue
            if not Draft202012Validator(definition).is_valid(parsed): continue
            self.domain(row, 'payload', self.ref(path, '/records/' + str(i) + '/payloadHex', 'hex'), parsed,
                self.schema(path, receipt[11], pointer='/documents/' + str(index) + '/payloadHex', encoding='hex'))
            row['interpretation'] = {'status': 'schema_shape_only', 'reason': 'No General semantic profile or Artist authority inferred.'}
        self.groups.append({'family': 'ARTIST_CHILD_GENERAL_ORIGINALS', 'source': self.ref(path),
            'originalCount': str(len(snapshot['records'])), 'catalogue': deepcopy(snapshot['catalogue']),
            'lanes': deepcopy(snapshot['lanes'])})

    def literal_bodies(self, occurrence, source, value):
        from . import recorded_physical_production_v1 as production
        from . import physical_transfer_semantics_v1 as transfer
        for i, assertion in enumerate(value['assertions']):
            literal = assertion['object'].get('literal')
            if literal is None: continue
            name = None
            if (assertion['relation'], assertion['mappingRule'], literal['datatype']) == (
                    production.RELATION, production.RULE, production.DATATYPE): name = 'physical_production'
            elif (assertion['relation'], assertion['mappingRule'], literal['datatype']) == (
                    transfer.RELATION, transfer.RULE, transfer.DATATYPE): name = 'physical_transfer'
            if name is None: continue
            try: body = loads(literal['lexicalValue'].encode('utf-8'), maximum=16384, canonical=True)
            except MuseumError: continue  # still losslessly retained as the original literal field
            fields_out, branches = fields(body)
            domain = 'literal_body_' + str(i)
            occurrence['domains'].append({'name': domain, 'source': source, 'schema': None,
                'applicability': 'original_literal_convention_no_schema', 'convention': name,
                'decodePointer': '/assertions/' + str(i) + '/object/literal/lexicalValue'})
            require(len(self.fields) + len(fields_out) <= MAX_FIELDS, 'field inventory aggregate field bound')
            self.fields.extend({'occurrenceId': occurrence['occurrenceId'], 'domain': domain, **row} for row in fields_out)

    def conservation(self):
        from tools.metadata import conservation_profile as definitions
        prefix = 'canonical/input/conservation/source/'
        path = prefix + 'conservation/dossier.json'
        if path not in self.files:
            self.groups.append({'family': 'CONSERVATION', 'source': None, 'originalCount': '0', 'status': 'not_retained'})
            return
        value = self.load(path)
        original_path = prefix + 'input/source/snapshot.json'; snapshot = self.load(original_path)
        require(len(value['records']) == len(snapshot['records']), 'field inventory conservation denominator differs')
        by_id = {d['documentId']: (i, d) for i, d in enumerate(snapshot['documents'])}
        for i, row in enumerate(value['records']):
            original = snapshot['records'][i]
            occurrence = self.occurrence('CONSERVATION_' + row['family'].upper(), row['selector'],
                self.ref(original_path, '/records/' + str(i)), original,
                authority={'origin': row['originalPublicationOrigin'], 'class': row['originalPublicationClass']},
                selection={'source': self.ref(path, '/scopes')})
            name = row['schemaName']; document_index, doc = by_id[schema_id(name)]
            expected = keccak256(definitions.canonical(definitions.schema(name)))
            schema = self.schema(original_path, expected,
                pointer='/documents/' + str(document_index) + '/payloadHex', encoding='hex')
            self.domain(occurrence, 'payload', self.ref(original_path, '/records/' + str(i) + '/payloadHex', 'hex'),
                row['semantic'], schema)
            for j, cat in enumerate(row['catalogOccurrences']):
                index, doc = by_id[cat['documentId']]
                raw = hex_bytes(doc['payloadHex']); parsed = loads(raw, maximum=524288, canonical=True)
                expected = keccak256(definitions.canonical(definitions.schema(definitions.CATALOG)))
                schema_index, _ = by_id[schema_id(definitions.CATALOG)]
                self.domain(occurrence, 'catalog_' + str(j), self.ref(original_path, '/documents/' + str(index) + '/payloadHex', 'hex'), parsed,
                    self.schema(original_path, expected, pointer='/documents/' + str(schema_index) + '/payloadHex', encoding='hex'))
        self.groups.append({'family': 'CONSERVATION', 'source': self.ref(original_path), 'originalCount': str(len(value['records']))})


def _extract(files, manifest_hash):
    """Private: input must be the complete result of concrete V4 verification."""
    builder = _Builder(files, manifest_hash)
    builder.canonical()
    if 'production/manifest.json' in files: builder.supplemental('production/sources/attribution/', 'ARTIST')
    else: builder.groups.append({'family': 'ARTIST', 'source': None, 'originalCount': '0', 'status': 'not_retained'})
    if 'transfer/manifest.json' in files:
        builder.supplemental('transfer/sources/general-dossier/', 'GENERAL')
    elif 'general/manifest.json' in files: builder.supplemental('general/', 'GENERAL')
    else: builder.groups.append({'family': 'GENERAL', 'source': None, 'originalCount': '0', 'status': 'not_retained'})
    builder.conservation()
    require(len({row['occurrenceId'] for row in builder.rows}) == len(builder.rows), 'field inventory duplicate occurrence')
    state = builder.load('report.json')['sourceState']
    value = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': manifest_hash,
        'sourceState': state, 'sourceReferenceBase': 'source/', 'occurrences': builder.rows,
        'fields': builder.fields, 'branches': builder.branches, 'denominators': builder.groups,
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    raw = dumps(value); require(len(raw) <= MAX_BYTES, 'field inventory serialized byte bound')
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': manifest_hash,
        'sourceState': state, 'inventoryHash': keccak256(raw), 'inventoryBytes': str(len(raw)),
        'occurrenceCount': str(len(builder.rows)), 'fieldCount': str(len(builder.fields)),
        'schemaDomainCount': str(sum(d['schema'] is not None for r in builder.rows for d in r['domains'])),
        'absentFieldCount': str(sum(r['presence'] == 'absent' for r in builder.fields)),
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    return Evidence(raw, report)


def build(files, manifest_hash, *, disclosure):
    """Replay the complete original V4 package before enumerating any fields."""
    require(disclosure == 'public', 'field inventory public disclosure required before inputs')
    try:
        checked = dossier.verify(dict(files), manifest_hash)
        return _extract(dict(checked.files), manifest_hash)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed canonical field inventory source') from exc
