"""IIIF Presentation 3 paintings from exact native WORK and VIEW evidence.

The VIEW source authenticates a token-scoped reference capture, an operative
Archive object and the complete retained bytes.  The plan separately records
an operator's decision that this captured image paints one selected WORK
description.  That decision is never recast as Artist or native authority.
"""
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit

from jsonschema import Draft202012Validator

from . import canonical_field_inventory_v1 as inventory
from . import canonical_object_dossier_v4 as dossier
from . import iiif_model as iiif
from . import native_iiif_v1 as descriptive
from . import object_dossier as package
from . import view_preservation_retrieval_v1 as retrieval
from . import view_reference_semantic_sources_v1 as view_sources
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id
from .iiif_numbers import target_dumps, target_loads
from .iiif_uri import content_uri_facts
from .independent_wire import require


NAME = 'STREAM_MUSEUM_NATIVE_IIIF_V2'
PLAN_KIND = 'native_iiif_painting'
OUTPUT_PREFIX = 'iiif/'
VIEW_PATH = 'canonical/input/acquisition/inputs/preservation/input.json'
MAX_PLAN = 1024 * 1024
MAX_SELECTED = 64
MAX_OCCURRENCES = 32768
MAX_FIELDS = 262144
MAX_DEPTH = 64
MAX_OUTPUT = 64 * 1024 * 1024
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
RULE = 'urn:6529stream:museum:native-iiif:v2:'
PNG_FORMAT = schema_id('IANA:image/png')


def plan_schema():
    digest = {'type': 'string', 'pattern': '^0x[0-9a-f]{64}$'}
    uri = {'type': 'string', 'minLength': 1, 'maxLength': 4096, 'format': 'uri'}
    text = {'type': 'string', 'minLength': 1, 'maxLength': 1024}
    context = {'type': 'object', 'additionalProperties': False,
        'required': ['manifestId', 'manifestRights', 'attributionLabel', 'canvasId',
            'canvasLabel', 'pageId', 'annotationId', 'bodyId', 'bodyLabel',
            'bodyRights', 'bodyAttribution', 'width', 'height', 'declaredBy', 'designation'],
        'properties': {'manifestId': uri, 'manifestRights': {'enum': iiif.RIGHTS},
            'attributionLabel': text, 'canvasId': uri, 'canvasLabel': text,
            'pageId': uri, 'annotationId': uri, 'bodyId': uri, 'bodyLabel': text,
            'bodyRights': {'enum': iiif.RIGHTS}, 'bodyAttribution': text,
            'width': {'type': 'integer', 'minimum': 1, 'maximum': (1 << 53) - 1},
            'height': {'type': 'integer', 'minimum': 1, 'maximum': (1 << 53) - 1},
            'declaredBy': uri,
            'designation': {'const': 'operator_asserted_painting_correspondence'}}}
    source = {'type': 'object', 'additionalProperties': False,
        'required': ['captureOccurrenceId', 'captureSelector', 'objectHash',
            'materialRecordHash'],
        'properties': {'captureOccurrenceId': digest,
            'captureSelector': {'type': 'object', 'minProperties': 1},
            'objectHash': digest, 'materialRecordHash': digest}}
    return {'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'title': 'STREAM_MUSEUM_NATIVE_IIIF_PAINTING_PLAN_V2', 'type': 'object',
        'additionalProperties': False,
        'required': ['version', 'kind', 'sourceManifestHash', 'selected'],
        'properties': {'version': {'const': '2'}, 'kind': {'const': PLAN_KIND},
            'sourceManifestHash': digest,
            'selected': {'type': 'array', 'maxItems': MAX_SELECTED,
                'items': {'type': 'object', 'additionalProperties': False,
                    'required': ['occurrenceId', 'selector', 'source', 'context'],
                    'properties': {'occurrenceId': digest,
                        'selector': {'type': 'object', 'minProperties': 1},
                        'source': source, 'context': context}}}}}


PLAN_SCHEMA_BYTES = dumps(plan_schema())
PLAN_SCHEMA_HASH = keccak256(PLAN_SCHEMA_BYTES)
TARGET_SCHEMA_BYTES = dumps(iiif.schema_document())
TARGET_SCHEMA_HASH = keccak256(TARGET_SCHEMA_BYTES)

SOURCE_INVENTORY_PROFILE_BYTES = dumps({'name':
    'STREAM_MUSEUM_NATIVE_IIIF_VIEW_SOURCE_INVENTORY_V1', 'version': '1',
    'viewSemanticProfileHash': view_sources.PROFILE_HASH,
    'source': VIEW_PATH + '#/evidence/retrievalEnvelope',
    'denominator': 'The complete retained VIEW envelope plus every derived original reference record and file-role occurrence before painting selection.',
    'domains': ['retained_source'],
    'fields': 'Every scalar, null and empty-container leaf of each exact domain; duplicate source occurrences remain distinct.',
    'limits': {'occurrences': MAX_OCCURRENCES, 'fields': MAX_FIELDS},
    'claims': {'viewRetrievalReplayedWhenEnvelopePresent': True, 'completeEnvelopeLeafDenominator': True,
        'paintingApplicabilityEstablishedHere': False, 'networkFetch': False}})
SOURCE_INVENTORY_PROFILE_HASH = keccak256(SOURCE_INVENTORY_PROFILE_BYTES)

CLAIMS = {'originalV4Replayed': True, 'completeOriginalFieldDenominator': True,
    'viewRetrievalReplayedWhenEnvelopePresent': True,
    'completeViewEnvelopeBytesRetainedWhenPresent': True,
    'tokenReferenceCaptureAndMaterialJoinedWhenPaintingsPresent': True,
    'sourcePngFormatDigestAndSizeCorrespondenceCheckedWhenPaintingsPresent': True,
    'paintingApplicabilityOperatorDeclaredWhenPaintingsPresent': True,
    'layoutDimensionsOperatorDeclaredWhenPaintingsPresent': True,
    'contentAddressedBodyIdentifierCheckedWhenPaintingsPresent': True,
    'paintingApplicabilityArtistApproved': False, 'intrinsicDimensionsProven': False,
    'nativeWorkTokenCorrespondenceProven': False,
    'manifestOrBodyRightsInferred': False, 'mediaRetrieved': False,
    'mimeDetectedFromBytes': False, 'currentNetworkLivenessProven': False,
    'institutionalAcceptance': False, 'originalRequirementsPromoted': False,
    'sourceOriginAuthenticated': False, 'profileRegistered': False, 'networkFetch': False}
QUALIFICATION = ('A verified V4 source and its retained VIEW retrieval envelope establish the exact token, '
    'reference-capture object, typed PNG identity, operative Archive correspondence and complete retained '
    'bytes with Keccak-256, SHA-256 and byte-size agreement. The plan separately attributes a painting '
    'designation, target identifiers, full-image layout dimensions, labels, attribution text and finite rights identifiers to declaredBy. '
    'That designation is not Artist approval or native selection. The route URI and operator body identifier '
    'remain distinct. No intrinsic raster dimensions, byte-detected MIME, network retrieval, current liveness, '
    'institutional acceptance or original requirement promotion is inferred.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2',
    'status': 'prospective_unregistered_adapter',
    'sourceProfileHash': dossier.PROFILE_HASH,
    'fieldInventoryProfileHash': inventory.PROFILE_HASH,
    'viewRetrievalProfileHash': retrieval.PROFILE_HASH,
    'viewSemanticProfileHash': view_sources.PROFILE_HASH,
    'sourceInventoryProfileHash': SOURCE_INVENTORY_PROFILE_HASH,
    'planSchemaHash': PLAN_SCHEMA_HASH, 'iiifValidatorProfileHash': iiif.PROFILE_HASH,
    'targetSchemaHash': TARGET_SCHEMA_HASH,
    'painting': 'One operator-designated Image painting body per selected exact WORK and same-token received VIEW reference capture.',
    'body': 'The source authenticates the IANA image/png format identifier, SHA-256, Keccak-256 and byte size. The body ID is a content-addressed operator identifier checked against the source SHA-256; label, attribution and rights are unsigned operator context.',
    'dimensions': 'Canvas and Image use equal positive layout dimensions declared by the operator. No viewport, WORK measurement or file-header value is promoted to intrinsic image dimensions.',
    'sourceReferenceBase': 'source/', 'planReferencePath': 'inputs/iiif-plan.json',
    'limits': {'planBytes': MAX_PLAN, 'selected': MAX_SELECTED,
        'occurrences': MAX_OCCURRENCES, 'fields': MAX_FIELDS, 'outputBytes': MAX_OUTPUT},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Evidence:
    files: dict
    report: dict


def _ref(files, path, pointer='', encoding='json'):
    require(path in files, 'native IIIF V2 retained source path missing')
    return {'path': 'source/' + path, 'hash': keccak256(files[path]),
        'jsonPointer': pointer, 'encoding': encoding}


def _pointer(value, pointer):
    return descriptive._at(value, pointer)


def _leaves(value, pointer='', *, depth=0, output=None):
    output = [] if output is None else output
    require(depth <= MAX_DEPTH and len(output) < MAX_FIELDS,
        'native IIIF V2 source leaf depth/count bound')
    if type(value) is dict and value:
        for key in sorted(value):
            _leaves(value[key], pointer + '/' + str(key).replace('~', '~0').replace('/', '~1'),
                depth=depth + 1, output=output)
        return output
    if type(value) is list and value:
        for index, item in enumerate(value):
            _leaves(item, pointer + '/' + str(index), depth=depth + 1, output=output)
        return output
    kind = ('null' if value is None else 'boolean' if type(value) is bool else
        'integer' if type(value) is int else 'string' if type(value) is str else
        'empty_array' if type(value) is list else 'empty_object')
    require(kind in ('null', 'boolean', 'integer', 'string', 'empty_array', 'empty_object'),
        'native IIIF V2 source leaf type')
    output.append({'pointer': pointer, 'presence': 'present', 'kind': kind,
        'exactHex': '0x' + dumps(value).hex(), 'disposition': 'retained_stream_only',
        'rule': RULE + 'retained-view-source-leaf'})
    return output


def _source_occurrence(family, selector, source, value, extra=None):
    identity = {'profileHash': SOURCE_INVENTORY_PROFILE_HASH, 'family': family,
        'selector': selector, 'source': source}
    row = {'occurrenceId': keccak256(dumps(identity)), 'family': family,
        'selector': deepcopy(selector), 'domains': [{'name': 'retained_source',
            'source': source}], 'qualification': view_sources.QUALIFICATION}
    if extra is not None: row.update(deepcopy(extra))
    fields = [dict(field, occurrenceId=row['occurrenceId'], domain='retained_source')
        for field in _leaves(value)]
    return row, fields


def _view(files):
    raw_input = files[VIEW_PATH]
    outer = loads(raw_input, maximum=dossier.MAX_BYTES, canonical=True)
    envelope = outer['evidence']['retrievalEnvelope']
    if envelope is None:
        result = {'profileHash': SOURCE_INVENTORY_PROFILE_HASH,
            'sourceStatus': 'source_unavailable', 'source': _ref(files, VIEW_PATH,
                '/evidence/retrievalEnvelope'), 'sourceHash': None,
            'occurrences': [], 'fields': [], 'records': [],
            'claims': {'viewRetrievalReplayed': False,
                'completeEnvelopeLeafDenominator': True,
                'paintingApplicabilityEstablishedHere': False, 'networkFetch': False}}
        return result, None, None
    envelope_raw = dumps(envelope)
    checked = retrieval.verify(envelope_raw)
    semantic = view_sources._extract(envelope_raw, checked)
    prefix = '/evidence/retrievalEnvelope'
    root_source = _ref(files, VIEW_PATH, prefix)
    occurrences, fields = [], []

    def append(row, found):
        occurrences.append(row); fields.extend(found)
        require(len(occurrences) <= MAX_OCCURRENCES and len(fields) <= MAX_FIELDS,
            'native IIIF V2 source inventory bound')

    root, found = _source_occurrence('VIEW_RETRIEVAL_ENVELOPE',
        {'sourceHash': keccak256(envelope_raw)}, root_source, envelope)
    append(root, found)
    records = {row['recordId']: row for row in semantic['records']}
    for record in semantic['records']:
        source = _ref(files, VIEW_PATH, prefix + record['source']['pointer'])
        value = _pointer(envelope, record['source']['pointer'])
        row, found = _source_occurrence('VIEW_REFERENCE_RECORD', record['selector'], source,
            value, {'recordId': record['recordId'], 'role': 'reference_record',
                'selection': {'selected': record['selected'], 'currentHead': record['currentHead']},
                'authority': record['authority']})
        append(row, found)
    semantic_to_local = {}
    for semantic_row in semantic['rows']:
        source = _ref(files, VIEW_PATH, prefix + semantic_row['source']['pointer'])
        value = _pointer(envelope, semantic_row['source']['pointer'])
        parent = records[semantic_row['recordId']]
        row, found = _source_occurrence('VIEW_' + semantic_row['role'].upper(),
            semantic_row['selector'], source, value,
            {'recordId': semantic_row['recordId'], 'role': semantic_row['role'],
                'selection': {'selected': parent['selected'], 'currentHead': parent['currentHead']},
                'authority': parent['authority'], 'availability': semantic_row['availability'],
                'semanticOccurrenceId': semantic_row['occurrenceId'],
                'semanticValues': semantic_row['values']})
        semantic_to_local[semantic_row['occurrenceId']] = row['occurrenceId']
        append(row, found)
    for index, material in enumerate(envelope['materials']):
        source = _ref(files, VIEW_PATH, prefix + '/materials/' + str(index))
        row, found = _source_occurrence('VIEW_RETRIEVED_MATERIAL',
            {'recordHash': material['recordHash'], 'index': str(index)}, source, material)
        append(row, found)
    for history_index, history in enumerate(envelope['inventory']['value']['reference']['history']):
        for object_index, obj in enumerate(history['objects']):
            pointer = (prefix + '/inventory/value/reference/history/' + str(history_index)
                + '/objects/' + str(object_index))
            source = _ref(files, VIEW_PATH, pointer)
            row, found = _source_occurrence('VIEW_EXTERNAL_OBJECT',
                {'historyIndex': str(history_index), 'objectHash': obj['objectHash']},
                source, obj)
            append(row, found)
    result = {'profileHash': SOURCE_INVENTORY_PROFILE_HASH,
        'sourceStatus': 'replayed', 'source': root_source,
        'sourceHash': keccak256(envelope_raw), 'occurrences': occurrences,
        'fields': fields, 'records': semantic['records'],
        'semanticOccurrenceMap': semantic_to_local,
        'claims': {'viewRetrievalReplayed': True,
            'completeEnvelopeLeafDenominator': True,
            'paintingApplicabilityEstablishedHere': False, 'networkFetch': False}}
    return result, semantic, checked


def _plan(raw, digest, source_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_PLAN
        and any(hex_bytes(digest, 32)) and keccak256(raw) == digest,
        'native IIIF V2 plan pin/bound differs')
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(not list(Draft202012Validator(plan_schema()).iter_errors(value))
        and value['sourceManifestHash'] == source_hash,
        'native IIIF V2 closed plan/source differs')
    occurrences, identities, operators = [], [], []
    for row in value['selected']:
        occurrences.append(row['occurrenceId'])
        context = row['context']
        ids = [iiif.http_id(context[key]) for key in ('manifestId', 'canvasId', 'pageId',
            'annotationId')]
        operator = iiif.http_id(context['declaredBy'])
        require(not any(urlsplit(item).query for item in ids),
            'native IIIF V2 target identity query unsupported')
        identities.extend(ids); operators.append(operator)
        for key in ('attributionLabel', 'canvasLabel', 'bodyLabel', 'bodyAttribution'):
            iiif.plain_span(context[key])
    require(len(occurrences) == len(set(occurrences)),
        'native IIIF V2 duplicate WORK occurrence')
    require(len(identities) == len(set(identities)),
        'native IIIF V2 cross-selected structural identity collision')
    require(not set(identities).intersection(operators),
        'native IIIF V2 operator/target identity collision')
    return value


def _operator(plan_hash, index, context, key):
    return {'domain': 'operator_context',
        'sourceReference': {'path': 'inputs/iiif-plan.json', 'hash': plan_hash,
            'jsonPointer': '', 'encoding': 'json'},
        'pointer': '/selected/' + str(index) + '/context/' + key,
        'exactHex': '0x' + dumps(context[key]).hex(),
        'declaredBy': context['declaredBy'],
        'qualification': 'unsigned_operator_export_context'}


def _source_proof(source_inventory, occurrence_id, pointer, target_value):
    occurrence = next(row for row in source_inventory['occurrences']
        if row['occurrenceId'] == occurrence_id)
    field = next(row for row in source_inventory['fields']
        if row['occurrenceId'] == occurrence_id and row['domain'] == 'retained_source'
        and row['pointer'] == pointer)
    return {'domain': 'retained_source', 'sourceReference': occurrence['domains'][0]['source'],
        'pointer': pointer, 'exactHex': field['exactHex'],
        'sourceOccurrenceId': occurrence_id,
        'qualification': 'exact_replayed_VIEW_original', 'targetValue': target_value}


def _work_scope(work, payload, state):
    token = subject_id('token', state['chainId'], state['core'], '0',
        token_id=state['tokenId'])
    collection = subject_id('collection', state['chainId'], state['core'],
        state['collectionId'])
    actual = payload.get('subjectId')
    require(work['selector'].get('subjectId') == actual and actual in (token, collection),
        'native IIIF V2 WORK source is outside target token or collection scope')
    return 'token' if actual == token else 'collection'


def _external_object_occurrence(source_inventory, capture_occurrence, object_hash):
    rows = [row for row in source_inventory['occurrences']
        if row['family'] == 'VIEW_EXTERNAL_OBJECT'
        and row['selector']['historyIndex'] == capture_occurrence['selector']['historyIndex']
        and row['selector']['objectHash'] == object_hash]
    require(len(rows) == 1, 'native IIIF V2 external object differs')
    return rows[0]


def _selected_capture(source_inventory, semantic, checked, choice, state):
    occurrences = {row['occurrenceId']: row for row in source_inventory['occurrences']}
    capture_id = choice['source']['captureOccurrenceId']
    occurrence = occurrences.get(capture_id)
    require(occurrence is not None and occurrence['family'] == 'VIEW_REFERENCE_CAPTURE'
        and occurrence['selector'] == choice['source']['captureSelector']
        and occurrence['selection']['selected']
        and occurrence['selector']['tokenId'] == state['tokenId']
        and all(occurrence['selector'][key] == state[key]
            for key in ('chainId', 'core', 'collectionId')),
        'native IIIF V2 WORK/VIEW token source differs')
    capture = next(row for row in semantic['rows']
        if row['occurrenceId'] == occurrence['semanticOccurrenceId'])
    require(capture['availability'] == 'received' and capture['byteEvidence'] is not None
        and capture['values']['objectHash'] == choice['source']['objectHash'],
        'native IIIF V2 selected capture bytes unavailable')
    media = [row for row in checked['media']
        if row['recordHash'] == choice['source']['materialRecordHash']
        and row['objectHash'] == choice['source']['objectHash']]
    require(len(media) == 1, 'native IIIF V2 operative material differs')
    return occurrence, capture, media[0]


def _body_identifier(uri, sha256_hex):
    result = content_uri_facts(uri, sha256_hex)
    require(result['rawDigestAgreement'] is True,
        'native IIIF V2 body identifier must bind exact source SHA-256 bytes')
    return result


def _proof(work, path, target, value, rule, sources):
    retained = {row['sourceOccurrenceId'] for row in sources
        if row['domain'] == 'retained_source'}
    require(len(retained) <= 1, 'native IIIF V2 proof crosses source occurrences')
    occurrence_id = next(iter(retained)) if retained else work['occurrenceId']
    return {'occurrenceId': occurrence_id,
        'target': {'path': path, 'hash': keccak256(target), 'pointer': value[0]},
        'targetValue': ({'kind': 'number', 'lexical': str(value[1])}
            if type(value[1]) is int else value[1]), 'rule': RULE + rule,
        'qualification': 'native_source_fact_or_explicit_unsigned_operator_designation',
        'sources': sources}


def _derive(files, source_hash, plan_raw, plan_hash, model_root=MODEL_ROOT, *, inventory_raw=None):
    plan = _plan(plan_raw, plan_hash, source_hash)
    inventory_raw = inventory._extract(files, source_hash).inventory if inventory_raw is None else inventory_raw
    inv = loads(inventory_raw, maximum=dossier.MAX_BYTES, canonical=True)
    require(inv['profileHash'] == inventory.PROFILE_HASH
        and inv['sourceManifestHash'] == source_hash,
        'native IIIF V2 inventory source/profile differs')
    source_inventory, semantic, checked = _view(files)
    if plan['selected']:
        require(semantic is not None and checked is not None,
            'native IIIF V2 selected painting requires retained VIEW source')
    by_work = {row['occurrenceId']: row for row in inv['occurrences']}
    require(len(by_work) == len(inv['occurrences']), 'native IIIF V2 duplicate WORK inventory occurrence')
    envelope = None if semantic is None else loads(files[VIEW_PATH], maximum=dossier.MAX_BYTES,
        canonical=True)['evidence']['retrievalEnvelope']
    manifests, proofs, index_rows = {}, [], []
    source_reader = descriptive._Sources(files)
    for index, choice in enumerate(plan['selected']):
        work = by_work.get(choice['occurrenceId'])
        require(work is not None and work['selector'] == choice['selector']
            and work['family'] == 'WORK'
            and work.get('interpretation', {}).get('status') == 'interpreted',
            'native IIIF V2 exact interpreted WORK occurrence required')
        _, payload = source_reader.domain(work, 'payload')
        require(payload.get('form') == 'full', 'native IIIF V2 full WORK description required')
        work_scope = _work_scope(work, payload, inv['sourceState'])
        capture_id = choice['source']['captureOccurrenceId']
        capture_occurrence, capture, media = _selected_capture(source_inventory,
            semantic, checked, choice, inv['sourceState'])
        object_occurrence = _external_object_occurrence(source_inventory,
            capture_occurrence, choice['source']['objectHash'])
        obj = _pointer(envelope, object_occurrence['domains'][0]['source']['jsonPointer']
            .removeprefix('/evidence/retrievalEnvelope'))
        identity = obj['identity']
        require(identity[3] == media['keccak256'] and identity[4] == media['sha256']
            and identity[6] == media['byteSize'] and identity[7] == PNG_FORMAT,
            'native IIIF V2 PNG object/material facts differ')
        material_occurrences = [row for row in source_inventory['occurrences']
            if row['family'] == 'VIEW_RETRIEVED_MATERIAL'
            and row['selector']['recordHash'] == choice['source']['materialRecordHash']]
        require(len(material_occurrences) == 1, 'native IIIF V2 retained material occurrence differs')
        context = choice['context']; path = OUTPUT_PREFIX + 'manifests/' + work['occurrenceId'][2:] + '.json'
        body_identifier = _body_identifier(context['bodyId'], media['sha256'][2:])
        body = {'id': context['bodyId'], 'type': 'Image', 'format': 'image/png',
            'width': context['width'], 'height': context['height'],
            'label': {'none': [iiif.plain_span(context['bodyLabel'])]},
            'requiredStatement': {'label': {'none': [iiif.plain_span(context['attributionLabel'])]},
                'value': {'none': [iiif.plain_span(context['bodyAttribution'])]}},
            'rights': context['bodyRights'],
            iiif.DIGEST: {'@type': iiif.XSD + 'string', '@value': media['sha256'][2:]},
            iiif.SIZE: {'@type': iiif.XSD + 'nonNegativeInteger', '@value': media['byteSize']},
            iiif.SOURCE: {'@type': '@json', '@value': {
                'profileHash': PROFILE_HASH, 'workOccurrenceId': work['occurrenceId'],
                'captureOccurrenceId': capture_id, 'objectHash': media['objectHash'],
                'materialRecordHash': media['recordHash'],
                'requestedURI': media['route']['requestedURI'],
                'resolvedURI': media['route']['resolvedURI'],
                'bodyIdentifierSource': 'unsigned_operator_context',
                'paintingDesignation': context['designation'],
                'declaredBy': context['declaredBy']}}}
        canvas = {'id': context['canvasId'], 'type': 'Canvas',
            'width': context['width'], 'height': context['height'],
            'label': {'none': [iiif.plain_span(context['canvasLabel'])]},
            'items': [{'id': context['pageId'], 'type': 'AnnotationPage',
                'items': [{'id': context['annotationId'], 'type': 'Annotation',
                    'motivation': 'painting', 'target': context['canvasId'], 'body': body}]}]}
        manifest = {'@context': iiif.CONTEXT_SEQUENCE, 'id': context['manifestId'],
            'type': 'Manifest', 'label': {'none': [iiif.plain_span(payload['title'])]},
            'summary': {'none': [iiif.plain_span(payload['medium'])]},
            'requiredStatement': {'label': {'none': [iiif.plain_span(context['attributionLabel'])]},
                'value': {'none': [iiif.plain_span(payload['creditLine'])]}},
            'rights': context['manifestRights'],
            iiif.SOURCE: {'@type': '@json', '@value': {'profileHash': PROFILE_HASH,
                'occurrenceId': work['occurrenceId'], 'selector': work['selector'],
                'authority': work['authority'], 'currentness': work['currentness'],
                'paintingApplicability': 'unsigned_operator_designation'}},
            'items': [canvas]}
        raw = target_dumps(manifest)
        pinned = iiif.PinnedIIIF(Path(model_root), iiif.PROFILE_BYTES,
            profile_hash=iiif.PROFILE_HASH)
        parsed, expanded = pinned.validate(raw)
        require(parsed == target_loads(raw), 'native IIIF V2 target parse differs')
        manifests[path] = raw
        pending = [
            ('/id', context['manifestId'], 'operator-manifest-id', [_operator(plan_hash, index, context, 'manifestId')]),
            ('/label/none/0', iiif.plain_span(payload['title']), 'original-title', [source_reader.proof(work, 'payload', '/title')]),
            ('/summary/none/0', iiif.plain_span(payload['medium']), 'original-medium', [source_reader.proof(work, 'payload', '/medium')]),
            ('/requiredStatement/value/none/0', iiif.plain_span(payload['creditLine']), 'original-credit', [source_reader.proof(work, 'payload', '/creditLine')]),
            ('/rights', context['manifestRights'], 'operator-manifest-rights', [_operator(plan_hash, index, context, 'manifestRights')]),
            ('/items/0/id', context['canvasId'], 'operator-canvas-id', [_operator(plan_hash, index, context, 'canvasId')]),
            ('/items/0/width', context['width'], 'operator-canvas-layout-width', [_operator(plan_hash, index, context, 'width')]),
            ('/items/0/height', context['height'], 'operator-canvas-layout-height', [_operator(plan_hash, index, context, 'height')]),
            ('/items/0/label/none/0', iiif.plain_span(context['canvasLabel']), 'operator-canvas-label', [_operator(plan_hash, index, context, 'canvasLabel')]),
            ('/items/0/items/0/id', context['pageId'], 'operator-page-id', [_operator(plan_hash, index, context, 'pageId')]),
            ('/items/0/items/0/items/0/id', context['annotationId'], 'operator-annotation-id', [_operator(plan_hash, index, context, 'annotationId')]),
            ('/items/0/items/0/items/0/motivation', 'painting', 'operator-painting-designation', [_operator(plan_hash, index, context, 'designation')]),
            ('/items/0/items/0/items/0/body/id', context['bodyId'], 'operator-body-id-bound-to-source-sha256',
                [_operator(plan_hash, index, context, 'bodyId'),
                    _source_proof(source_inventory, object_occurrence['occurrenceId'],
                        '/identity/4', context['bodyId'])]),
            ('/items/0/items/0/items/0/body/width', context['width'], 'operator-body-layout-width', [_operator(plan_hash, index, context, 'width')]),
            ('/items/0/items/0/items/0/body/height', context['height'], 'operator-body-layout-height', [_operator(plan_hash, index, context, 'height')]),
            ('/items/0/items/0/items/0/body/label/none/0', iiif.plain_span(context['bodyLabel']), 'operator-body-label', [_operator(plan_hash, index, context, 'bodyLabel')]),
            ('/items/0/items/0/items/0/body/requiredStatement/value/none/0', iiif.plain_span(context['bodyAttribution']), 'operator-body-attribution', [_operator(plan_hash, index, context, 'bodyAttribution')]),
            ('/items/0/items/0/items/0/body/rights', context['bodyRights'], 'operator-body-rights', [_operator(plan_hash, index, context, 'bodyRights')]),
            ('/items/0/items/0/items/0/body/type', 'Image', 'typed-png-image', [_source_proof(source_inventory, object_occurrence['occurrenceId'], '/identity/7', 'Image')]),
            ('/items/0/items/0/items/0/body/format', 'image/png', 'typed-png-format', [_source_proof(source_inventory, object_occurrence['occurrenceId'], '/identity/7', 'image/png')]),
            ('/items/0/items/0/items/0/body/' + iiif.DIGEST.replace('~', '~0').replace('/', '~1') + '/@value', media['sha256'][2:], 'source-sha256', [_source_proof(source_inventory, object_occurrence['occurrenceId'], '/identity/4', media['sha256'][2:])]),
            ('/items/0/items/0/items/0/body/' + iiif.SIZE.replace('~', '~0').replace('/', '~1') + '/@value', media['byteSize'], 'source-byte-size', [_source_proof(source_inventory, object_occurrence['occurrenceId'], '/identity/6', media['byteSize'])])]
        for pointer, target, rule, sources in pending:
            actual = _pointer(parsed, pointer)
            require(actual == target, 'native IIIF V2 final target scalar differs')
            proofs.append(_proof(work, path, raw, (pointer, target), rule, sources))
        index_rows.append({'occurrenceId': work['occurrenceId'], 'selector': work['selector'],
            'captureOccurrenceId': capture_id, 'captureSelector': capture['selector'],
            'captureSelection': deepcopy(capture_occurrence['selection']),
            'objectHash': media['objectHash'], 'materialRecordHash': media['recordHash'],
            'manifestPath': path, 'manifestId': context['manifestId'],
            'canvasId': context['canvasId'], 'bodyId': context['bodyId'],
            'workScope': work_scope, 'workSubjectId': payload['subjectId'],
            'sourceRoute': media['route'], 'expandedRootCount': str(len(expanded)),
            'bodyIdentifierFacts': body_identifier,
            'paintingAuthority': {'mode': 'unsigned_operator_designation',
                'declaredBy': context['declaredBy']},
            'operatorDeclaredLayout': {'width': str(context['width']),
                'height': str(context['height'])}, 'intrinsicDimensions': None})
    output = dict(manifests)
    output[OUTPUT_PREFIX + 'supplemental-source-inventory.json'] = dumps(source_inventory)
    output[OUTPUT_PREFIX + 'index.json'] = dumps({'profileHash': PROFILE_HASH,
        'sourceManifestHash': source_hash, 'fieldInventoryHash': keccak256(inventory_raw),
        'sourceInventoryHash': keccak256(output[OUTPUT_PREFIX + 'supplemental-source-inventory.json']),
        'rows': index_rows, 'claims': CLAIMS, 'qualification': QUALIFICATION})
    output[OUTPUT_PREFIX + 'target-schema.json'] = TARGET_SCHEMA_BYTES
    output[OUTPUT_PREFIX + 'provenance.json'] = dumps({'profileHash': PROFILE_HASH,
        'sourceInventoryProfileHash': SOURCE_INVENTORY_PROFILE_HASH, 'rows': proofs})
    report = {'profile': NAME, 'profileHash': PROFILE_HASH,
        'sourceManifestHash': source_hash, 'planHash': plan_hash,
        'status': 'source_unavailable' if source_inventory['sourceStatus'] == 'source_unavailable'
            else 'retained_view_no_selection' if not plan['selected'] else 'painting_manifests',
        'selectedCount': str(len(plan['selected'])), 'manifestCount': str(len(manifests)),
        'paintingBodyCount': str(len(manifests)),
        'viewOccurrenceCount': str(len(source_inventory['occurrences'])),
        'viewFieldCount': str(len(source_inventory['fields'])),
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output[OUTPUT_PREFIX + 'report.json'] = dumps(report)
    require(sum(map(len, output.values())) <= MAX_OUTPUT,
        'native IIIF V2 output byte bound')
    return Evidence(output, report)


def build(files, source_hash, plan_raw, plan_hash, *, disclosure, model_root=MODEL_ROOT):
    require(disclosure == 'public', 'native IIIF V2 public disclosure required before reads')
    try:
        checked = dossier.verify(dict(files), source_hash)
        return _derive(dict(checked.files), source_hash, plan_raw, plan_hash, model_root)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OSError, OverflowError,
            UnicodeError, RecursionError) as exc:
        raise MuseumError('malformed native IIIF V2 source') from exc
