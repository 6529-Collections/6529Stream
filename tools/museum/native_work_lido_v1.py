"""Native WORK occurrences to LIDO 1.1 with separately declared record context.

Public admission replays the complete original V4 dossier. XML describes the
selected original assertions; neither native publication nor operator metadata
establishes the truth of a creator, creation event, publisher, or rights claim.
"""
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path

from jsonschema import Draft202012Validator
from lxml import etree

from tools.metadata import work_profile as work
from . import canonical_field_inventory_v1 as field_inventory
from . import canonical_object_dossier_v4 as dossier
from . import canonical_semantic_sources_v1 as pointers
from . import work_lido_source
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .lido import _e
from .lido_model import NS, XML, PinnedLIDO, PROFILE_BYTES as XSD_PROFILE_BYTES, PROFILE_HASH as XSD_PROFILE_HASH
from .linked_art import format_checker
from .work_lido import _full, _variants

NAME = 'STREAM_MUSEUM_NATIVE_WORK_LIDO_V1'
PLAN_KIND = 'native_work_lido'
MAX_PLAN = 524288
MAX_OUTPUT = 8 * 1024 * 1024
MAX_SELECTED = 64
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
TYPE, LANG = '{' + NS + '}type', '{' + XML + '}lang'
INVENTORY_PATH = 'canonical/inputs/source-inventory.json'
SELECTION_PATH = 'canonical/inputs/selection.json'
OUTPUT_PREFIX = 'lido/'


def plan_schema():
    uri = {**work.text(2048), 'format': 'uri'}
    language = {**work.text(16), 'pattern': '^' + work.LANG + '$'}
    text = {'value': work.text(1024), 'language': language, 'declaredBy': uri}
    selector = work.closed({'kind': {'const': 'native_metadata_work'}, 'chainId': work.UINT,
        'core': {'type': 'string', 'pattern': '^0x[0-9a-f]{40}$'},
        'host': {'type': 'string', 'pattern': '^0x[0-9a-f]{40}$'},
        'recordHash': work.NH, 'recordType': work.NH, 'subjectId': work.NH,
        'schemaId': work.NH, 'canonicalizationId': work.NH, 'sourceId': {'type': 'null'}})
    context = work.closed({
        'documentLanguage': work.closed({'value': language, 'declaredBy': uri}),
        'objectWorkType': work.closed(text),
        'exportPublisher': work.closed({'id': uri, 'name': work.text(1024),
            'language': language, 'declaredBy': uri}),
        'artistName': work.closed({**text, 'artistId': work.NH,
            'association': work.closed({'bindingHash': work.NH, 'bindingGeneration': work.UINT})}),
        'workLabel': work.closed(text)}, required=['documentLanguage', 'objectWorkType', 'exportPublisher'])
    return {'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'title': 'STREAM_MUSEUM_NATIVE_WORK_LIDO_PLAN_V1', **work.closed({
            'version': {'const': '1'}, 'kind': {'const': PLAN_KIND},
            'sourceManifestHash': work.NH,
            'selected': work.array(work.closed({'occurrenceId': work.NH,
                'selector': selector, 'context': context}), MAX_SELECTED)})}


PLAN_SCHEMA_BYTES = dumps(plan_schema())
PLAN_SCHEMA_HASH = keccak256(PLAN_SCHEMA_BYTES)
CLAIMS = {'originalV4Replayed': True, 'allRetainedWorkOccurrencesAccounted': True,
    'originalLidoXsdValidated': True, 'fieldLevelOriginalCorrespondence': True,
    'operatorContextAuthenticated': False, 'nativePublicationAuthorityPromoted': False,
    'creatorTruthProven': False, 'currentEligibilityProven': False, 'rightsLicenseInferred': False,
    'mediaReceived': False, 'institutionalIngest': False, 'fullMuseumScope': False,
    'nineteenOrFortynineRequirementsPromoted': False}
QUALIFICATION = ('LIDO descriptions of exact selected native WORK assertions, with original authority, '
    'scope, currentness and canonical selection retained separately. Required LIDO record metadata is '
    'an explicitly attributed, unsigned operator declaration. Publisher identity, language and object '
    'classification are not inferred from native authority. Creator and creation facts remain original '
    'statements, not independently verified identities or events. Catalog identifiers are descriptive '
    'format assertions, not detected MIME, media retrieval, fixity or license evidence. No original '
    'nineteen or forty-nine assessment is changed.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'status': 'prospective_unregistered_adapter',
    'sourceProfileHash': dossier.PROFILE_HASH, 'workSchemaHash': work_lido_source.WORK_SCHEMA_HASH,
    'workProfileHash': work_lido_source.WORK_PROFILE_HASH, 'planSchemaHash': PLAN_SCHEMA_HASH,
    'xsdValidatorProfileHash': XSD_PROFILE_HASH,
    'references': 'Source references resolve under source/ to original V4 files; operator plan is inputs/plan.json. valuePointer is inside the decoded referenced value.',
    'denominator': 'All original WORK rows before explicit plan selection, including opaque and unselected originals. No global host completeness.',
    'identities': 'Occurrence-qualified LIDO record, stable native subject URI and native record URI are distinct. Equal descriptions do not merge records.',
    'reuse': 'Only neutral typed WORK XML formatting helpers and original pinned LIDO XSD validation are reused; no synthetic fixture admission or provenance is reused.',
    'fields': 'Every original node, interpreted WORK/catalog node and applicable absent property is accounted. Only exact resolved output provenance yields mapped; remaining present fields are retained_stream_only.',
    'context': 'Externally pinned closed operator plan, each contextual statement has declaredBy. No signatures or legal standing inferred; required original artist association must match exactly.',
    'limits': {'planBytes': str(MAX_PLAN), 'selected': str(MAX_SELECTED), 'outputBytes': str(MAX_OUTPUT)},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Evidence:
    files: dict
    report: dict


def _pointer(value, pointer):
    return pointers._resolve_value(value, pointer, 'json')


def _source_ref(files, old):
    path = 'canonical/input/' + old['path']
    raw = files[path]
    require(keccak256(raw) == old['hash'], 'native WORK source reference hash differs')
    ref = {'path': 'source/' + path, 'hash': old['hash'],
        'jsonPointer': old['jsonPointer'], 'encoding': old['encoding']}
    value = raw if old['encoding'] == 'bytes' else pointers._resolve_value(
        loads(raw, maximum=dossier.MAX_BYTES, canonical=True), old['jsonPointer'], old['encoding'])
    return ref, value


def _plan(raw, digest, source_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_PLAN and keccak256(raw) == digest,
        'native WORK plan pin/bound differs')
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    errors = list(Draft202012Validator(plan_schema(), format_checker=format_checker()).iter_errors(value))
    require(not errors, 'native WORK closed plan schema differs')
    work._pattern_checks(value, plan_schema())
    require(value['sourceManifestHash'] == source_hash, 'native WORK plan source differs')
    ids = [r['occurrenceId'] for r in value['selected']]
    require(len(ids) == len(set(ids)), 'native WORK duplicate selected occurrence')
    return value


class _Evidence:
    def __init__(self, row, payload, plan, plan_raw, context_index, references):
        self.row, self.references = row, references
        self.values = {'work': payload, 'context': plan}
        self.plan_raw, self.context_index = plan_raw, context_index
        self.pending, self.mapped = [], set()

    def value(self, name, path):
        return _pointer(self.values[name], path)

    def proof(self, name, path):
        value = self.value(name, path)
        if name == 'work':
            return {'domain': 'payload', 'sourceReference': self.references['payload'], 'pointer': path,
                'exactHex': '0x' + dumps(value).hex(), 'selector': self.row['selector'],
                'authority': self.row['authority'], 'qualification': 'original_native_WORK_statement'}
        prefix = '/'.join(path.split('/')[:5])
        statement = _pointer(self.values['context'], prefix)
        return {'domain': 'operator_context', 'sourceReference': {'path': 'inputs/plan.json',
            'hash': keccak256(self.plan_raw), 'jsonPointer': '', 'encoding': 'json'},
            'pointer': path, 'exactHex': '0x' + dumps(value).hex(),
            'declaredBy': statement['declaredBy'], 'qualification': 'unsigned_operator_record_metadata'}

    def bind(self, node, refs, rule='exact', attribute=None):
        self.pending.append((node, attribute, {'rule': rule,
            'targetValue': node.get(attribute) if attribute else node.text,
            'sources': [self.proof(*ref) for ref in refs]}))
        self.mapped.update((('payload' if name == 'work' else 'operator_plan'), path) for name, path in refs)

    def emit(self, parent, tag, name, path, *, language=None, **attrs):
        node = _e(parent, tag, self.value(name, path), **attrs)
        self.bind(node, [(name, path)])
        if language: self.language(node, *language)
        return node

    def language(self, node, name, path):
        node.set(LANG, self.value(name, path))
        self.bind(node, [(name, path)], attribute=LANG)

    def generated(self, parent, tag, value, rule, **attrs):
        node = _e(parent, tag, value, **attrs)
        self.pending.append((node, None, {'rule': rule, 'targetValue': value,
            'sources': [{'domain': 'original_identity', 'sourceReference': self.references['original'],
                'pointer': '', 'selector': self.row['selector'],
                'qualification': 'computed_identifier_not_independent_fact'}]}))
        return node

    def provenance(self, reparsed, output_path, raw):
        result = []
        for node, attribute, row in self.pending:
            suffix = '/@xml:lang' if attribute == LANG else '/@lido:' + etree.QName(attribute).localname if attribute else ''
            xpath = node.getroottree().getpath(node) + suffix
            found = reparsed.xpath(xpath, namespaces={'lido': NS, 'xml': XML})
            require([str(v) if attribute else v.text for v in found] == [row['targetValue']],
                'native WORK exact target XPath/value differs')
            result.append({'occurrenceId': self.row['occurrenceId'],
                'targetPath': output_path, 'targetXPath': xpath,
                'qualification': 'qualified_original_statement_or_separate_operator_record_context',
                'target': {'path': output_path,
                'hash': keccak256(raw), 'xpath': xpath}, **row})
        return result


def _xml(row, payload, plan, raw_plan, index, references, model):
    context = plan['selected'][index]['context']
    base = '/selected/' + str(index) + '/context/'
    if payload['form'] == 'full':
        require('workLabel' not in context, 'native WORK unused work label')
        creator = payload['creator']
        if creator['kind'] == 'artist':
            name = context.get('artistName')
            require(name is not None and name['artistId'] == creator['artistId']
                and name['association'] == creator['association'], 'native WORK exact artist context required')
        else: require('artistName' not in context, 'native WORK unused artist context')
    else:
        require('artistName' not in context and 'workLabel' in context,
            'native WORK absence needs explicit work label and cannot acquire a creator')
    selector = row['selector']
    record_id = 'urn:stream:native-work-lido:' + row['occurrenceId'][2:]
    work_id = 'urn:stream:subject:' + selector['chainId'] + ':' + selector['core'] + ':' + selector['subjectId']
    source_id = 'urn:stream:record:' + selector['chainId'] + ':' + selector['host'] + ':' + selector['recordHash']
    require(context['exportPublisher']['id'] not in (record_id, work_id, source_id)
        and all(v['declaredBy'] not in (record_id, work_id, source_id) for v in context.values()),
        'native WORK context identity collision')
    e = _Evidence(row, payload, plan, raw_plan, index, references)
    root = etree.Element('{' + NS + '}lido', nsmap={'lido': NS})
    e.generated(root, 'lidoRecID', record_id, 'occurrence-qualified-export-record', **{TYPE: 'URI'})
    e.generated(root, 'objectPublishedID', work_id, 'native-subject-identifier', **{TYPE: 'URI'})
    language = ('context', base + 'documentLanguage/value')
    descriptive = _e(root, 'descriptiveMetadata'); e.language(descriptive, *language)
    classification = _e(_e(descriptive, 'objectClassificationWrap'), 'objectWorkTypeWrap')
    e.emit(_e(classification, 'objectWorkType'), 'term', 'context', base + 'objectWorkType/value',
        language=('context', base + 'objectWorkType/language'))
    identification = _e(descriptive, 'objectIdentificationWrap')
    if payload['form'] == 'full':
        _full(e, descriptive, identification, language,
            {'artistName': (None, base + 'artistName')} if 'artistName' in context else {})
    else:
        group = _e(_e(identification, 'titleWrap'), 'titleSet', **{TYPE: 'catalogue-work-label'})
        e.emit(group, 'appellationValue', 'context', base + 'workLabel/value', language=('context', base + 'workLabel/language'))
        description = _e(identification, 'objectDescriptionWrap')
        for key in ('reason', 'date'):
            e.emit(_e(description, 'objectDescriptionSet', **{TYPE: 'description-absence-' + key}),
                'descriptiveNoteValue', 'work', '/absence/' + key, language=language)
    administrative = _e(root, 'administrativeMetadata'); e.language(administrative, *language)
    if payload['form'] == 'full':
        rights = _e(_e(administrative, 'rightsWorkWrap'), 'rightsWorkSet')
        e.emit(rights, 'creditLine', 'work', '/creditLine', language=language)
        for i, _ in _variants(payload, 'creditLine'):
            p = '/languageVariants/' + str(i)
            e.emit(rights, 'creditLine', 'work', p + '/value', language=('work', p + '/language'))
    records = _e(administrative, 'recordWrap')
    e.generated(records, 'recordID', record_id, 'occurrence-qualified-export-record', **{TYPE: 'URI'})
    _e(_e(records, 'recordType'), 'term', 'item', **{LANG: 'en'})
    publisher = _e(records, 'recordSource')
    e.emit(publisher, 'legalBodyID', 'context', base + 'exportPublisher/id', **{TYPE: 'URI'})
    e.emit(_e(publisher, 'legalBodyName'), 'appellationValue', 'context', base + 'exportPublisher/name',
        language=('context', base + 'exportPublisher/language'))
    e.generated(_e(records, 'recordInfoSet', **{TYPE: 'native-WORK-original-statement'}),
        'recordInfoID', source_id, 'native-record-identifier', **{TYPE: 'URI'})
    raw = etree.tostring(root, encoding='UTF-8', xml_declaration=True)
    path = OUTPUT_PREFIX + 'records/' + row['occurrenceId'][2:] + '.xml'
    return path, raw, e.provenance(model.validate(raw), path, raw), e.mapped, {
        'recordId': record_id, 'subjectId': work_id, 'nativeRecordId': source_id}


def _derive(files, source_hash, plan_raw, plan_hash, model_root):
    plan = _plan(plan_raw, plan_hash, source_hash)
    source = loads(files[INVENTORY_PATH], maximum=dossier.MAX_BYTES, canonical=True)
    selected = set(loads(files[SELECTION_PATH], maximum=dossier.MAX_BYTES, canonical=True)['selectedOccurrenceIds'])
    rows = [r for r in source['rows'] if r['family'] == 'WORK']
    by_id = {r['occurrenceId']: r for r in rows}
    require(len(by_id) == len(rows), 'native WORK duplicate original occurrence')
    for choice in plan['selected']:
        require(choice['occurrenceId'] in by_id and choice['selector'] == by_id[choice['occurrenceId']]['selector'],
            'native WORK exact original selector/occurrence required')
        require(by_id[choice['occurrenceId']]['semantic'] is not None,
            'native WORK opaque occurrence cannot be exported')
    choices = {r['occurrenceId']: i for i, r in enumerate(plan['selected'])}
    model = PinnedLIDO(Path(model_root), XSD_PROFILE_BYTES, profile_hash=XSD_PROFILE_HASH)
    output, inventory, coverage, provenance = {}, [], [], []
    mapped_all = set()
    for row in rows:
        references, domains = {}, []
        original_ref, original = _source_ref(files, row['pointers']['original'])
        require(original == row['original'], 'native WORK original occurrence differs')
        references['original'] = original_ref
        domains.append(('original', original, None, original_ref))
        if row['semantic'] is not None:
            payload_ref, payload_raw = _source_ref(files, row['pointers']['payload'])
            require(type(payload_raw) is bytes and dumps(row['semantic']) == payload_raw,
                'native WORK original payload differs')
            catalog_raw = None
            if row['catalog'] is not None:
                cat_ref, catalog_raw = _source_ref(files, row['catalog']['bytesSource'])
                require(dumps(row['catalog']['value']) == catalog_raw, 'native WORK original catalog differs')
                domains.append(('catalog', row['catalog']['value'], work.catalog_schema(), cat_ref))
            work_lido_source.load_work_source(payload_raw,
                expected_subject_id=row['selector']['subjectId'], catalog=catalog_raw)
            references['payload'] = payload_ref
            domains.append(('payload', row['semantic'], work.schema(), payload_ref))
        mapped, path, identities = set(), None, None
        if row['occurrenceId'] in choices:
            path, raw, proofs, mapped, identities = _xml(row, row['semantic'], plan, plan_raw,
                choices[row['occurrenceId']], references, model)
            output[path] = raw; provenance.extend(proofs); mapped_all.update(mapped)
        inventory.append({'occurrenceId': row['occurrenceId'], 'selector': row['selector'],
            'authority': row['authority'], 'currentness': row['currentness'],
            'interpretation': row['interpretation'], 'canonicalSelected': row['occurrenceId'] in selected,
            'planSelected': row['occurrenceId'] in choices, 'xmlPath': path, 'identities': identities,
            'domains': [{'name': name, 'source': ref, 'schemaHash': keccak256(dumps(schema)) if schema else None}
                for name, value, schema, ref in domains]})
        for name, value, schema, ref in domains:
            fields, branches = field_inventory.fields(value, schema)
            for field in fields:
                is_mapped = (name, field['pointer']) in mapped
                coverage.append({'occurrenceId': row['occurrenceId'], 'domain': name, **field,
                    'source': ref, 'disposition': 'mapped' if is_mapped else field['disposition'],
                    'rule': 'resolved-original-value-to-exact-LIDO-XPath' if is_mapped else field['rule'],
                    'reason': 'This exact original value contributes to a validated target scalar; authority remains qualified.' if is_mapped else field['reason']})
    plan_fields, _ = field_inventory.fields(plan, plan_schema())
    for field in plan_fields:
        mapped = ('operator_plan', field['pointer']) in mapped_all
        coverage.append({'occurrenceId': None, 'domain': 'operator_plan', **field,
            'source': {'path': 'inputs/plan.json', 'hash': plan_hash, 'jsonPointer': '', 'encoding': 'json'},
            'disposition': 'mapped' if mapped else field['disposition'],
            'rule': 'separately-declared-operator-context-to-LIDO' if mapped else field['rule'],
            'reason': 'Unsigned operator record context, never a native assertion.' if mapped else field['reason']})
    output[OUTPUT_PREFIX + 'inventory.json'] = dumps({'profileHash': PROFILE_HASH,
        'sourceManifestHash': source_hash, 'source': {'path': 'source/' + INVENTORY_PATH,
            'hash': keccak256(files[INVENTORY_PATH])}, 'occurrences': inventory,
        'denominator': source['denominators']['work'], 'claims': CLAIMS, 'qualification': QUALIFICATION})
    output[OUTPUT_PREFIX + 'coverage.json'] = dumps({'profileHash': PROFILE_HASH, 'fields': coverage})
    output[OUTPUT_PREFIX + 'provenance.json'] = dumps({'profileHash': PROFILE_HASH, 'rows': provenance})
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
        'planHash': plan_hash, 'originalWorkCount': str(len(rows)), 'selectedWorkCount': str(len(choices)),
        'xmlCount': str(len(choices)), 'mappedFieldCount': str(sum(f['disposition'] == 'mapped' for f in coverage)),
        'outputs': [{'path': p, 'hash': keccak256(raw), 'bytes': str(len(raw))} for p, raw in sorted(output.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output[OUTPUT_PREFIX + 'report.json'] = dumps(report)
    require(sum(map(len, output.values())) <= MAX_OUTPUT, 'native WORK aggregate output bound')
    return Evidence(output, report)


def build(files, manifest_hash, plan_raw, plan_hash, *, disclosure, model_root=MODEL_ROOT):
    """Verify the original V4 package, then map exact selected native WORK rows."""
    require(disclosure == 'public', 'native WORK public disclosure required before reads')
    try:
        checked = dossier.verify(dict(files), manifest_hash)
        return _derive(dict(checked.files), manifest_hash, plan_raw, plan_hash, model_root)
    except MuseumError:
        raise
    except (KeyError, ValueError, TypeError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed native WORK LIDO input') from exc
