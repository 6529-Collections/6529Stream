"""Fresh, field-provenanced Linked Art from exact verified native V4 originals.

The targets are statements about original declarations, not inferred people,
institutions, activities, or unconditional facts about the described work.
"""
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path

from . import canonical_field_inventory_v1 as inventory
from . import canonical_object_dossier_v4 as dossier
from . import canonical_semantic_sources_v1 as pointers
from . import owner_family_semantics_v1 as owner
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator

NAME = 'STREAM_MUSEUM_NATIVE_LINKED_ART_V1'
PLAN_KIND = 'native_linked_art'
MAX_PLAN = 524288
MAX_SELECTED = 64
MAX_RESOURCE = 262144
MAX_OUTPUT = 32 * 1024 * 1024
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
PREFIX = 'linked-art/'
RULE = 'urn:6529stream:museum:native-linked-art:v1:'
FAMILIES = ('WORK', 'CONDITION', *owner.FAMILIES, 'GENERAL', 'ARTIST')
CLAIMS = {'originalV4Replayed': True, 'completeRetainedOccurrenceDenominator': True,
    'exactFieldTargetCorrespondence': True, 'linkedArtValidatedAndExpanded': True,
    'originalAuthorityAndCurrentnessRetained': True, 'personOrInstitutionInferred': False,
    'activityOrPerformanceInferred': False, 'legalTitleInferred': False,
    'nativeSpecializedStateInferred': False, 'currentAuthorityProven': False,
    'fileRetrievalOrArchiveProven': False, 'globalSourceCompletenessProven': False,
    'originalRequirementsPromoted': False, 'profileRegistered': False}
QUALIFICATION = ('Qualified descriptions of selected original native statements and their retained '
    'payload occurrences. Names denote declared WORK titles within record statements. Creator, owner, '
    'institution, examination, custody, loan, valuation, notice, recovery and redemption values remain '
    'attributed declarations, not independent identities, performed acts or specialized native state. '
    'General account and native Artist authority remain distinct. Original selection and currentness '
    'are preserved, not replaced by export selection. Exact strings map without lexical or datatype '
    'conversion; unsupported numeric, boolean, null, structural and residual fields stay retained. '
    'No nineteen or forty-nine requirement is promoted.')
PLAN_SCHEMA_BYTES = dumps({'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'title': 'STREAM_MUSEUM_NATIVE_LINKED_ART_PLAN_V1', 'type': 'object',
    'additionalProperties': False, 'required': ['version', 'kind', 'sourceManifestHash', 'selected'],
    'properties': {'version': {'const': '1'}, 'kind': {'const': PLAN_KIND},
        'sourceManifestHash': {'type': 'string', 'pattern': '^0x[0-9a-f]{64}$'},
        'selected': {'type': 'array', 'maxItems': MAX_SELECTED, 'items': {'type': 'object',
            'additionalProperties': False, 'required': ['occurrenceId', 'selector'],
            'properties': {'occurrenceId': {'type': 'string', 'pattern': '^0x[0-9a-f]{64}$'},
                'selector': {'type': 'object', 'minProperties': 1}}}}}})
PLAN_SCHEMA_HASH = keccak256(PLAN_SCHEMA_BYTES)
CROSSWALK_BYTES = dumps({'profile': NAME, 'version': '1', 'rules': [
    {'family': 'WORK', 'source': 'title and ordered alternateTitles', 'target': 'record LinguisticObject identified_by Name.content',
        'meaning': 'Explicitly classified declared WORK title, not an independent title attribution.'},
    {'family': 'WORK', 'source': 'creator, creation, medium, credit, inscription, format, measurements, edition, authorityReferences and languageVariants',
        'target': 'classified exact-string declaration content', 'meaning': 'Original declared descriptive fields; no performed Creation, identified Person or measured Dimension invented.'},
    {'family': 'OWNER', 'source': 'longest matching substantive original typed owner predicate; residual retains-payload-field excluded',
        'target': 'classified exact-string declaration content', 'meaning': 'Family-specific documentary meaning and original qualifier; no title, custody, financial truth, notice standing or redemption fulfillment inferred.'},
    {'family': 'CONDITION', 'source': 'examination, examiner, finality/fixity/render reports, recovery, captures and narrative',
        'target': 'classified exact-string reported condition content', 'meaning': 'Report of examination or condition, not independent performance/fixity.'},
    {'family': 'GENERAL/ARTIST', 'source': 'each original assertion object value with its original predicate',
        'target': 'classified exact-string assertion-value content', 'meaning': 'Quoted original assertion object; original entities do not become authenticated people/institutions or subject equivalences.'},
    {'family': 'WORK_CATALOG', 'source': 'complete original ordered catalog entry IDs and format mapping strings',
        'target': 'classified catalog-declaration content', 'meaning': 'Catalog bytes retain their own provenance; no format detection or catalogue-author authentication.'},
    {'family': 'ALL_SUPPORTED', 'source': 'exact retained payload byte identity',
        'target': 'DigitalObject digitally_carries record LinguisticObject', 'meaning': 'Retained payload occurrence only; no URI retrieval or Archive claim.'}]})
CROSSWALK_HASH = keccak256(CROSSWALK_BYTES)
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'sourceProfileHash': dossier.PROFILE_HASH,
    'inventoryProfileHash': inventory.PROFILE_HASH, 'planSchemaHash': PLAN_SCHEMA_HASH,
    'ownerInterpretationProfileHash': owner.PROFILE_HASH, 'crosswalkHash': CROSSWALK_HASH,
    'validationPolicyHash': VALIDATION_HASH, 'context': CONTEXT, 'supportedFamilies': FAMILIES,
    'sourceReferenceBase': 'source/', 'planReferencePath': 'inputs/linked-art-plan.json',
    'identity': 'Occurrence-qualified statement and payload carrier IDs. Field locations remain ordered and duplicate-safe; no cross-record name/IRI merge.',
    'coverage': 'Only resolved exact original string fields copied to model-validated target scalars become mapped. All source fields remain in the preselection inventory; unsupported and residual fields stay retained.',
    'limits': {'planBytes': MAX_PLAN, 'selected': MAX_SELECTED, 'resourceBytes': MAX_RESOURCE, 'outputBytes': MAX_OUTPUT},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Evidence:
    files: dict
    report: dict


def _at(value, pointer):
    return pointers._resolve_value(value, pointer, 'json')


def _plan(raw, digest, source_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_PLAN and keccak256(raw) == digest,
        'native Linked Art plan pin/bound differs')
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(type(value) is dict and set(value) == {'version', 'kind', 'sourceManifestHash', 'selected'}
        and value['version'] == '1' and value['kind'] == PLAN_KIND and value['sourceManifestHash'] == source_hash,
        'native Linked Art closed plan/source differs')
    require(type(value['selected']) is list and len(value['selected']) <= MAX_SELECTED,
        'native Linked Art selected count bound')
    ids = []
    for row in value['selected']:
        require(type(row) is dict and set(row) == {'occurrenceId', 'selector'}
            and type(row['selector']) is dict and row['selector'] and any(hex_bytes(row['occurrenceId'], 32)),
            'native Linked Art exact whole selector/occurrence required')
        ids.append(row['occurrenceId'])
    require(len(ids) == len(set(ids)), 'native Linked Art duplicate selected occurrence')
    return value


class _Sources:
    def __init__(self, files):
        self.files, self.hashes, self.parsed, self.resolved = files, {}, {}, {}

    def resolve(self, ref):
        key = dumps(ref)
        if key in self.resolved: return self.resolved[key]
        require(type(ref) is dict and set(ref) == {'path', 'hash', 'jsonPointer', 'encoding'}
            and ref['path'].startswith('source/'), 'native Linked Art original reference shape/base differs')
        path = ref['path'][7:]; raw = self.files[path]
        if path not in self.hashes: self.hashes[path] = keccak256(raw)
        require(self.hashes[path] == ref['hash'], 'native Linked Art original reference hash differs')
        if ref['encoding'] == 'bytes':
            require(ref['jsonPointer'] == '', 'native Linked Art whole byte reference required')
            value = raw
        else:
            if path not in self.parsed: self.parsed[path] = loads(raw, maximum=dossier.MAX_BYTES, canonical=True)
            value = pointers._resolve_value(self.parsed[path], ref['jsonPointer'], ref['encoding'])
        self.resolved[key] = value
        return value

    def json(self, ref):
        value = self.resolve(ref)
        return loads(value, maximum=dossier.MAX_BYTES, canonical=True) if type(value) is bytes else value


def _schema_domain(row, name='payload'):
    found = [d for d in row['domains'] if d['name'] == name and d['schema'] is not None]
    return found[0] if len(found) == 1 else None


def _supported(row):
    return (row['family'] in FAMILIES and _schema_domain(row) is not None
        and row.get('interpretation', {}).get('status') in ('interpreted', 'supported'))


WORK_FIELDS = {'creator': 'declares-work-creator', 'creation': 'declares-work-creation-date',
    'medium': 'declares-work-medium', 'creditLine': 'declares-work-credit', 'inscription': 'describes-work-inscription',
    'edition': 'declares-work-edition', 'measurements': 'declares-work-measurement',
    'format': 'declares-work-format', 'authorityReferences': 'references-declared-authority-identifier',
    'languageVariants': 'declares-work-language-variant', 'absence': 'records-authored-description-absence'}
CONDITION_FIELDS = {'examinationDate': 'reports-examination-date', 'examiner': 'names-reported-examiner',
    'workCitation': 'reports-condition-of', 'finality': 'reports-finality-observation', 'fixity': 'reports-fixity-observation',
    'render': 'reports-render-observation', 'recoveryLineage': 'reports-recovery-lineage',
    'captures': 'declares-condition-capture', 'narrative': 'declares-condition-narrative'}


def _meaning(row, domain, pointer, payload, original_rows):
    """Return only a substantive schema-supported declared predicate."""
    family = row['family']; top = pointer.split('/')[1] if pointer else ''
    if domain == 'catalog' and family == 'WORK' and pointer.startswith('/entries/'):
        return 'declares-work-catalog-entry', 'catalog_content_only_no_authority_or_detection', False
    if domain != 'payload': return None
    if family == 'WORK':
        if pointer == '/title' or pointer.startswith('/alternateTitles/'):
            return 'declares-work-title', 'original_WORK_title_declaration_not_independent_fact', True
        if top in WORK_FIELDS:
            return WORK_FIELDS[top], 'original_WORK_declaration_only', False
    elif family in owner.FAMILIES:
        original = original_rows.get(row['originalOccurrenceId'])
        require(original is not None and original['family'] == family and original['selector'] == row['selector']
            and original['semantic'] == payload, 'native Linked Art owner original correspondence differs')
        meaning = original['ownerMeaning']
        require(meaning is not None and meaning['status'] == 'typed' and meaning['semantic'] == payload,
            'native Linked Art typed owner meaning differs')
        relations = [r for r in meaning['relations'] if pointer == r['sourcePointer'] or pointer.startswith(r['sourcePointer'] + '/')]
        require(relations, 'native Linked Art owner field missing declared relation')
        maximum = max(len(r['sourcePointer']) for r in relations)
        relation = [r for r in relations if len(r['sourcePointer']) == maximum]
        require(len(relation) == 1 and _at(payload, relation[0]['sourcePointer']) == relation[0]['value'],
            'native Linked Art owner relation original value differs')
        relation = relation[0]
        if not relation['predicate'].startswith('retains-payload-field:'):
            return relation['predicate'], relation['qualification'], False
    elif family == 'CONDITION' and top in CONDITION_FIELDS:
        return CONDITION_FIELDS[top], 'reported_condition_not_independent_performance_or_fixity', False
    elif family in ('GENERAL', 'ARTIST') and pointer.startswith('/assertions/'):
        parts = pointer.split('/')
        if len(parts) >= 5 and parts[3] == 'object':
            assertion = payload['assertions'][int(parts[2])]
            # The original predicate describes the quoted object, never an
            # automatically instantiated CRM relation or authenticated entity.
            return ('declares-assertion-object:' + assertion['relation'],
                'original_' + family + '_assertion_only; declaredReviewStatus=' + assertion['reviewStatus'], False)
    return None


def _type(label):
    return {'id': RULE + 'predicate:' + keccak256(label.encode('utf-8'))[2:], 'type': 'Type', '_label': label}


def _render(row, domains, fields, original_rows, model):
    identity = row['occurrenceId'][2:]
    statement_id, carrier_id = RULE + 'statement:' + identity, RULE + 'payload-occurrence:' + identity
    statement = {'@context': CONTEXT, 'id': statement_id, 'type': 'LinguisticObject',
        '_label': row['family'] + ' original attributed declaration',
        'content': 'Field-level description of the original ' + row['family'] + ' declaration.',
        'classified_as': [_type(row['family'] + ' attributed record')],
        'referred_to_by': [{'type': 'LinguisticObject', 'content': QUALIFICATION}]}
    carrier = {'@context': CONTEXT, 'id': carrier_id, 'type': 'DigitalObject',
        '_label': row['family'] + ' retained payload occurrence',
        'classified_as': [_type('retained original payload occurrence')],
        'digitally_carries': [{'id': statement_id, 'type': 'LinguisticObject'}],
        'referred_to_by': [{'type': 'LinguisticObject', 'content': 'Exact retained payload bytes; no URI retrieval, fixity or Archive claim.'}]}
    pending = []
    for field in fields:
        name, pointer = field['domain'], field['pointer']
        if name not in domains or field['presence'] != 'present' or field['kind'] != 'string': continue
        payload, ref = domains[name]; value = _at(payload, pointer)
        require(type(value) is str and '0x' + dumps(value).hex() == field['exactHex'],
            'native Linked Art original field type/bytes differ')
        meaning = _meaning(row, name, pointer, payload, original_rows)
        if meaning is None: continue
        predicate, qualification, title = meaning
        label = predicate + ('' if title else ' [' + pointer + ']')
        if title:
            names = statement.setdefault('identified_by', [])
            target_pointer = '/identified_by/' + str(len(names)) + '/content'
            names.append({'type': 'Name', 'content': value, 'classified_as': [_type('original WORK-title declaration')]})
        else:
            notes = statement['referred_to_by']; target_pointer = '/referred_to_by/' + str(len(notes)) + '/content'
            notes.append({'type': 'LinguisticObject', 'content': value,
                'classified_as': [_type(label)],
                'referred_to_by': [{'type': 'LinguisticObject', 'content': qualification}]})
        pending.append({'pointer': target_pointer, 'targetValue': value,
            'rule': RULE + predicate, 'qualification': qualification,
            'sources': [{'domain': name, 'sourceReference': ref, 'pointer': pointer,
                'exactHex': field['exactHex'], 'selector': row['selector'], 'authority': row['authority'],
                'qualification': qualification}]})
    files, index, proofs = {}, [], []
    for role, value in (('statement', statement), ('payload', carrier)):
        raw = dumps(value)
        checked = model.validate_and_expand(raw, maximum=MAX_RESOURCE)
        stem = identity + '-' + role
        path, expanded_path = PREFIX + 'resources/' + stem + '.json', PREFIX + 'expanded/' + stem + '.json'
        files[path], files[expanded_path] = raw, checked.expanded_bytes
        index.append({'role': role, 'id': value['id'], 'path': path, 'expandedPath': expanded_path})
        if role == 'statement':
            reparsed = loads(raw, maximum=MAX_RESOURCE, canonical=True)
            for proof in pending:
                target = proof.pop('pointer')
                require(_at(reparsed, target) == proof['targetValue']
                    and type(_at(reparsed, target)) is type(proof['targetValue']),
                    'native Linked Art final target scalar differs')
                proofs.append({'occurrenceId': row['occurrenceId'],
                    'target': {'path': path, 'hash': keccak256(raw), 'pointer': target}, **proof})
        proofs.append({'occurrenceId': row['occurrenceId'], 'target': {'path': path, 'hash': keccak256(raw), 'pointer': '/id'},
            'targetValue': value['id'], 'rule': RULE + 'occurrence-qualified-' + role,
            'sources': [{'domain': 'original_identity', 'sourceReference': row['original'], 'pointer': '',
                'selector': row['selector'], 'qualification': 'computed_occurrence_identifier_only'}]})
    return files, index, proofs


def _derive(files, source_hash, plan_raw, plan_hash, model_root=MODEL_ROOT, *, inventory_raw=None):
    """Internal post-verification derivation; callers must replay exact V4 first."""
    plan = _plan(plan_raw, plan_hash, source_hash)
    inventory_raw = inventory._extract(files, source_hash).inventory if inventory_raw is None else inventory_raw
    value = loads(inventory_raw, maximum=dossier.MAX_BYTES, canonical=True)
    require(value['profileHash'] == inventory.PROFILE_HASH and value['sourceManifestHash'] == source_hash,
        'native Linked Art original inventory pin differs')
    by_id = {row['occurrenceId']: row for row in value['occurrences']}
    require(len(by_id) == len(value['occurrences']), 'native Linked Art occurrence denominator duplicate')
    for chosen in plan['selected']:
        row = by_id.get(chosen['occurrenceId'])
        require(row is not None and row['selector'] == chosen['selector'], 'native Linked Art exact original selector differs')
        require(_supported(row), 'native Linked Art unsupported or opaque occurrence')
    chosen_ids = {r['occurrenceId'] for r in plan['selected']}
    source = loads(files['canonical/inputs/source-inventory.json'], maximum=dossier.MAX_BYTES, canonical=True)
    original_rows = {row['occurrenceId']: row for row in source['rows']}
    model, resolver = validator(Path(model_root)), _Sources(files)
    per_row = {}
    for field in value['fields']: per_row.setdefault(field['occurrenceId'], []).append(field)
    output, report_rows, proofs = {}, [], []
    total = 0
    for row in value['occurrences']:
        selected = row['occurrenceId'] in chosen_ids; resources = []
        if selected:
            domains = {}
            for domain in row['domains']:
                if domain['name'] not in ('payload', 'catalog') or domain['schema'] is None: continue
                schema_raw = resolver.resolve(domain['schema']['source'])
                require(type(schema_raw) is bytes and keccak256(schema_raw) == domain['schema']['hash'],
                    'native Linked Art retained schema bytes differ')
                domains[domain['name']] = (resolver.json(domain['source']), domain['source'])
            files_out, resources, emissions = _render(row, domains, per_row[row['occurrenceId']], original_rows, model)
            require(not set(output).intersection(files_out), 'native Linked Art target path collision')
            total += sum(map(len, files_out.values()))
            require(total <= MAX_OUTPUT, 'native Linked Art aggregate output bound')
            output.update(files_out); proofs.extend(emissions)
        report_rows.append({'occurrenceId': row['occurrenceId'], 'originalOccurrenceId': row['originalOccurrenceId'],
            'family': row['family'], 'selector': row['selector'], 'original': row['original'],
            'authority': row['authority'], 'currentness': row['currentness'], 'originalSelection': row['selection'],
            'support': 'supported' if _supported(row) else 'unsupported_or_opaque',
            'planSelected': selected, 'resources': resources})
    mapped = {(p['occurrenceId'], s['domain'], s['pointer']) for p in proofs for s in p['sources']
        if s['domain'] not in ('original_identity', 'operator_context', 'derived_bytes')}
    coverage = []
    for field in value['fields']:
        key = (field['occurrenceId'], field['domain'], field['pointer']); is_mapped = key in mapped
        coverage.append({**field, 'disposition': 'mapped' if is_mapped else 'not_applicable' if field['presence'] == 'absent' else 'retained_stream_only',
            'rule': RULE + 'exact-qualified-field-target' if is_mapped else field['rule'],
            'reason': 'Exact original string in a qualified, validated Linked Art field target.' if is_mapped else field['reason']})
    output[PREFIX + 'inventory.json'] = dumps({'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
        'fieldInventoryHash': keccak256(inventory_raw), 'occurrences': report_rows,
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    output[PREFIX + 'coverage.json'] = dumps({'profileHash': PROFILE_HASH, 'fieldInventoryHash': keccak256(inventory_raw), 'fields': coverage})
    output[PREFIX + 'provenance.json'] = dumps({'profileHash': PROFILE_HASH, 'rows': proofs})
    output[PREFIX + 'crosswalk.json'] = CROSSWALK_BYTES
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
        'planHash': plan_hash, 'fieldInventoryHash': keccak256(inventory_raw),
        'occurrenceCount': str(len(report_rows)), 'selectedCount': str(len(chosen_ids)),
        'resourceCount': str(sum(len(r['resources']) for r in report_rows)), 'mappedFieldCount': str(len(mapped)),
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output[PREFIX + 'report.json'] = dumps(report)
    require(sum(map(len, output.values())) <= MAX_OUTPUT, 'native Linked Art aggregate output bound')
    return Evidence(output, report)


def build(files, source_hash, plan_raw, plan_hash, *, disclosure, model_root=MODEL_ROOT):
    require(disclosure == 'public', 'native Linked Art public disclosure required before reads')
    try:
        checked = dossier.verify(dict(files), source_hash)
        return _derive(dict(checked.files), source_hash, plan_raw, plan_hash, model_root)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed native Linked Art input') from exc
