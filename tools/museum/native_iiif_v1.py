"""Finite IIIF Presentation 3 descriptions from verified native V4 WORK rows.

This adapter emits descriptive Manifests and, when an original WORK payload
declares usable pixel or exact finite-duration measurements, an unpainted
Canvas.  The retained collection media and prospective-render sources do not
establish that a resource paints the selected token WORK, so they are reported
as source scope and never converted into Annotation bodies.
"""
from copy import deepcopy
from dataclasses import dataclass
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

from jsonschema import Draft202012Validator, validators
from pyld import jsonld
from pyld.context_resolver import ContextResolver

from . import canonical_evidence_occurrences_v2 as source_occurrences
from . import canonical_field_inventory_v1 as inventory
from . import canonical_object_dossier_v4 as dossier
from . import canonical_semantic_sources_v1 as pointers
from . import iiif_model as iiif
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .iiif_numbers import ExactDecimal, target_dumps, target_loads
from .independent_wire import require


NAME = 'STREAM_MUSEUM_NATIVE_IIIF_V1'
PLAN_KIND = 'native_iiif'
OUTPUT_PREFIX = 'iiif/'
MAX_PLAN = 524288
MAX_SELECTED = 64
MAX_OUTPUT = 16 * 1024 * 1024
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
RULE = 'urn:6529stream:museum:native-iiif:v1:'


def plan_schema():
    digest = {'type': 'string', 'pattern': '^0x[0-9a-f]{64}$'}
    uri = {'type': 'string', 'minLength': 1, 'maxLength': 4096, 'format': 'uri'}
    text = {'type': 'string', 'minLength': 1, 'maxLength': 1024}
    context = {'type': 'object', 'additionalProperties': False,
        'required': ['manifestId', 'manifestRights', 'attributionLabel', 'canvasLabel', 'declaredBy'],
        'properties': {'manifestId': uri, 'manifestRights': {'oneOf': [
                {'type': 'null'}, {'enum': iiif.RIGHTS}]},
            'attributionLabel': text, 'canvasLabel': text, 'declaredBy': uri}}
    return {'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'title': 'STREAM_MUSEUM_NATIVE_IIIF_PLAN_V1', 'type': 'object',
        'additionalProperties': False,
        'required': ['version', 'kind', 'sourceManifestHash', 'selected'],
        'properties': {'version': {'const': '1'}, 'kind': {'const': PLAN_KIND},
            'sourceManifestHash': digest,
            'selected': {'type': 'array', 'maxItems': MAX_SELECTED,
                'items': {'type': 'object', 'additionalProperties': False,
                    'required': ['occurrenceId', 'selector', 'context'],
                    'properties': {'occurrenceId': digest,
                        'selector': {'type': 'object', 'minProperties': 1},
                        'context': context}}}}}


PLAN_SCHEMA_BYTES = dumps(plan_schema())
PLAN_SCHEMA_HASH = keccak256(PLAN_SCHEMA_BYTES)


def target_schema():
    """Pinned finite target with the IIIF-legal empty descriptive branches.

    The earlier media-correspondence profile deliberately required one painting
    body.  This source adapter cannot make that correspondence, so it retains
    the same bounded shape and contexts while allowing zero Manifest items and
    zero Canvas annotation pages.  Manifest rights is optional because absence
    must not be turned into a licence assertion.
    """
    schema = deepcopy(iiif.schema_document())
    schema['properties']['items']['minItems'] = 0
    schema['required'].remove('rights')
    schema['$defs']['canvas']['properties']['items']['minItems'] = 0
    return schema


TARGET_SCHEMA_BYTES = dumps(target_schema())
TARGET_SCHEMA_HASH = keccak256(TARGET_SCHEMA_BYTES)
CLAIMS = {'originalV4Replayed': True, 'completeRetainedOccurrenceDenominator': True,
    'exactFieldTargetCorrespondence': True,
    'pinnedIiifContextClosureValidatedWhenTargetsPresent': True,
    'emptyManifestAndCanvasItemsSupported': True, 'nativeWorkMeasurementPreserved': True,
    'manifestRightsInferred': False, 'paintableMediaCorrespondenceProven': False,
    'mediaMimeOrDimensionsInferred': False, 'collectionMediaPromotedToToken': False,
    'prospectiveRenderPromotedToPostMint': False, 'mediaRetrieved': False,
    'fixityVerified': False, 'currentAuthorityProven': False,
    'originalRequirementsPromoted': False, 'profileRegistered': False,
    'networkFetch': False}
QUALIFICATION = ('IIIF Manifests describe selected exact native WORK statement occurrences. '
    'Title, medium, credit line and usable measurement values remain attributed original '
    'declarations. Manifest identifiers, optional Manifest rights and display labels are '
    'unsigned operator context attributed to declaredBy. Pixel dimensions create only an '
    'unpainted Canvas; duration is emitted only when the original rational has an exact '
    'finite decimal representation, with no rounding. Collection-scoped media masters and '
    'pre-sale prospective captures remain separate retained source scope: they do not prove '
    'a token-WORK painting body, MIME/dimension/size tuple, post-mint render, retrieval or '
    'fixity. No original nineteen or forty-nine requirement is promoted.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1',
    'status': 'prospective_unregistered_adapter',
    'sourceProfileHash': dossier.PROFILE_HASH,
    'inventoryProfileHash': inventory.PROFILE_HASH,
    'sourceOccurrenceProfileHash': source_occurrences.PROFILE_HASH,
    'planSchemaHash': PLAN_SCHEMA_HASH,
    'baseIiifValidatorProfileHash': iiif.PROFILE_HASH,
    'targetSchemaHash': TARGET_SCHEMA_HASH,
    'contexts': iiif.CONTEXT_SEQUENCE,
    'selection': 'Zero through sixty-four exact derived inventory occurrence IDs and exact whole selectors. Only interpreted full WORK payloads are renderable.',
    'context': 'Manifest ID, nullable finite Manifest-rights identifier, attribution label, Canvas label and declaredBy are externally pinned unsigned operator context.',
    'manifest': 'Original title, medium and credit line become occurrence-qualified descriptive values. No title or creator truth is independently established.',
    'canvas': 'One unpainted full-work extent Canvas only when exact original pixels or a finite exact duration is usable. No media body is invented.',
    'numbers': 'Positive integer dimensions remain exact JSON integer lexicals. Rational duration is emitted only after exact terminating base-ten conversion; no binary float or rounding.',
    'sourceScope': 'Verified native media-master and prospective-reference occurrences are inventoried as unmapped scope with exact retained references.',
    'sourceReferenceBase': 'source/', 'planReferencePath': 'inputs/iiif-plan.json',
    'limits': {'planBytes': MAX_PLAN, 'selected': MAX_SELECTED,
        'outputBytes': MAX_OUTPUT, 'inputBytes': dossier.MAX_BYTES},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Evidence:
    files: dict
    report: dict


def _json(raw):
    return loads(raw, maximum=dossier.MAX_BYTES, canonical=True)


def _at(value, pointer):
    return pointers._resolve_value(value, pointer, 'json')


def _plan(raw, digest, source_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_PLAN
        and any(hex_bytes(digest, 32)) and keccak256(raw) == digest,
        'native IIIF plan pin/bound differs')
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(not list(Draft202012Validator(plan_schema()).iter_errors(value))
        and value['sourceManifestHash'] == source_hash,
        'native IIIF closed plan/source differs')
    occurrence_ids, manifest_ids = [], []
    for row in value['selected']:
        occurrence_ids.append(row['occurrenceId'])
        context = row['context']; manifest = iiif.http_id(context['manifestId'])
        declared = iiif.http_id(context['declaredBy'])
        require(not urlsplit(manifest).query and not manifest.endswith('/'),
            'native IIIF Manifest ID needs a stable appendable path')
        require(declared != manifest, 'native IIIF operator and Manifest identity collide')
        require(context['manifestRights'] is None or context['manifestRights'] in iiif.RIGHTS,
            'native IIIF unsupported explicit Manifest rights')
        for key in ('attributionLabel', 'canvasLabel'):
            iiif.plain_span(context[key])
        manifest_ids.append(manifest)
    require(len(occurrence_ids) == len(set(occurrence_ids)),
        'native IIIF duplicate selected occurrence')
    require(len(manifest_ids) == len(set(manifest_ids)),
        'native IIIF duplicate Manifest identity')
    return value


class _Sources:
    def __init__(self, files):
        self.files, self.parsed, self.hashes = files, {}, {}

    def resolve(self, ref):
        require(type(ref) is dict and set(ref) == {'path', 'hash', 'jsonPointer', 'encoding'}
            and ref['path'].startswith('source/'),
            'native IIIF source reference shape/base differs')
        path = ref['path'][7:]; raw = self.files[path]
        if path not in self.hashes: self.hashes[path] = keccak256(raw)
        require(ref['hash'] == self.hashes[path], 'native IIIF source reference hash differs')
        if ref['encoding'] == 'bytes':
            require(ref['jsonPointer'] == '', 'native IIIF byte source pointer differs')
            return raw
        if path not in self.parsed: self.parsed[path] = _json(raw)
        return pointers._resolve_value(self.parsed[path], ref['jsonPointer'], ref['encoding'])

    def domain(self, row, name):
        found = [domain for domain in row['domains'] if domain['name'] == name]
        require(len(found) == 1, 'native IIIF source domain missing/ambiguous')
        value = self.resolve(found[0]['source'])
        return found[0]['source'], _json(value) if type(value) is bytes else value

    def proof(self, row, name, pointer):
        ref, value = self.domain(row, name); scalar = _at(value, pointer)
        require(type(scalar) not in (dict, list), 'native IIIF scalar field required')
        return {'domain': name, 'sourceReference': ref, 'pointer': pointer,
            'exactHex': '0x' + dumps(scalar).hex(), 'selector': row['selector'],
            'authority': row['authority'], 'currentness': row['currentness'],
            'qualification': 'original_native_WORK_declaration'}


def _terminating_decimal(numerator, denominator):
    numerator, denominator = int(numerator), int(denominator)
    require(numerator > 0 and denominator > 0, 'native IIIF positive rational required')
    from math import gcd
    divisor = gcd(numerator, denominator)
    numerator //= divisor; denominator //= divisor
    reduced, twos, fives = denominator, 0, 0
    while reduced % 2 == 0:
        reduced //= 2; twos += 1
    while reduced % 5 == 0:
        reduced //= 5; fives += 1
    if reduced != 1: return None, 'duration_rational_has_no_finite_decimal_representation'
    scale = max(twos, fives)
    scaled = numerator * (2 ** (scale - twos)) * (5 ** (scale - fives))
    digits = str(scaled)
    if scale == 0: lexical = digits + '.0'
    elif len(digits) <= scale: lexical = '0.' + ('0' * (scale - len(digits))) + digits
    else: lexical = digits[:-scale] + '.' + digits[-scale:]
    try: return ExactDecimal(lexical), None
    except MuseumError: return None, 'duration_exact_decimal_exceeds_target_lexical_bound'


def _target_value(value):
    if isinstance(value, ExactDecimal): return {'kind': 'number', 'lexical': value.lexical}
    if type(value) is int: return {'kind': 'number', 'lexical': str(value)}
    return value


def _check_identities(rows):
    """Reject role collisions across the complete selected target set."""
    structural, operators = [], set()
    for manifest_id, has_canvas, declared_by in rows:
        structural.append(manifest_id)
        if has_canvas: structural.append(manifest_id + '/canvas/0')
        operators.add(declared_by)
    require(len(structural) == len(set(structural)),
        'native IIIF cross-selected structural identity collision')
    require(set(structural).isdisjoint(operators),
        'native IIIF operator and structural identity collision')


def _operator(plan_raw, plan_hash, index, context, key):
    value = context[key]
    return {'domain': 'operator_context',
        'sourceReference': {'path': 'inputs/iiif-plan.json', 'hash': plan_hash,
            'jsonPointer': '', 'encoding': 'json'},
        'pointer': '/selected/' + str(index) + '/context/' + key,
        'exactHex': '0x' + dumps(value).hex(), 'declaredBy': context['declaredBy'],
        'qualification': 'unsigned_operator_export_context'}


def _identity(row):
    return {'domain': 'original_identity', 'sourceReference': row['original'],
        'pointer': '', 'selector': row['selector'],
        'qualification': 'computed_occurrence_identifier_not_independent_fact'}


def _language(value):
    return {'none': [iiif.plain_span(value)]}


def _extent(payload):
    measurement = payload['measurements']
    if measurement['kind'] != 'measured': return {}, [], []
    result, pointers_used, diagnostics = {}, [], []
    pixels = measurement.get('pixels')
    if pixels is not None:
        width, height = int(pixels['width']), int(pixels['height'])
        if 0 < width <= (1 << 53) - 1 and 0 < height <= (1 << 53) - 1:
            result.update(width=width, height=height)
            pointers_used += ['/measurements/pixels/width', '/measurements/pixels/height']
        else:
            diagnostics.append('pixel_extent_exceeds_finite_IIIF_integer_profile')
    duration = measurement.get('durationSeconds')
    if duration is not None:
        exact, reason = _terminating_decimal(duration['numerator'], duration['denominator'])
        if exact is not None:
            result['duration'] = exact
            pointers_used += ['/measurements/durationSeconds/numerator',
                '/measurements/durationSeconds/denominator']
        else: diagnostics.append(reason)
    return result, pointers_used, diagnostics


def _validate_target(raw, root):
    """Validate the additive empty-item target over the pinned IIIF closure."""
    pinned = iiif.PinnedIIIF(Path(root), iiif.PROFILE_BYTES, profile_hash=iiif.PROFILE_HASH)
    value = target_loads(raw); schema = target_schema()
    checker = Draft202012Validator.TYPE_CHECKER.redefine(
        'number', lambda _, item: type(item) in (int, Decimal))
    validator = validators.extend(Draft202012Validator, type_checker=checker)(schema)
    require(validator.is_valid(value), 'native IIIF local target schema validation failed')
    ids = [iiif.http_id(value['id'])]
    for text in value['label']['none'] + value['summary']['none']:
        iiif.span_text(text)
    for text in value['requiredStatement']['label']['none'] + value['requiredStatement']['value']['none']:
        iiif.span_text(text)
    for canvas in value['items']:
        ids.append(iiif.http_id(canvas['id']))
        require(canvas['items'] == [], 'native IIIF Canvas must remain unpainted')
        for text in canvas['label']['none']: iiif.span_text(text)
        present = set(canvas) & {'width', 'height', 'duration'}
        require(present in ({'width', 'height'}, {'duration'}, {'width', 'height', 'duration'}),
            'native IIIF Canvas requires exact declared extent')
        if 'duration' in present:
            require(type(canvas['duration']) is Decimal,
                'native IIIF duration must preserve an explicit decimal lexical')
    require(len(ids) == len(set(ids)), 'native IIIF structural identifiers collide')
    try:
        expanded = jsonld.expand(value, {'documentLoader': pinned.loader, 'base': '',
            'processingMode': 'json-ld-1.1',
            'contextResolver': ContextResolver({}, pinned.loader, max_context_urls=16)})
    except Exception as exc:
        raise MuseumError('native IIIF offline JSON-LD expansion failed') from exc
    return value, expanded


def _proof(row, path, value, rule, sources):
    return {'occurrenceId': row['occurrenceId'],
        'target': {'path': path, 'hash': None, 'pointer': None},
        'targetValue': _target_value(value), 'rule': RULE + rule,
        'qualification': 'qualified_original_statement_or_unsigned_operator_context',
        'sources': sources}


def _render(row, payload, context, plan_raw, plan_hash, index, sources, model_root):
    manifest_id = context['manifestId']; path = OUTPUT_PREFIX + 'manifests/' + row['occurrenceId'][2:] + '.json'
    source_evidence = {'@type': '@json', '@value': {'profileHash': PROFILE_HASH,
        'occurrenceId': row['occurrenceId'], 'selector': row['selector'],
        'authority': row['authority'], 'currentness': row['currentness'],
        'qualification': QUALIFICATION}}
    manifest = {'@context': iiif.CONTEXT_SEQUENCE, 'id': manifest_id, 'type': 'Manifest',
        'label': _language(payload['title']), 'summary': _language(payload['medium']),
        'requiredStatement': {'label': _language(context['attributionLabel']),
            'value': _language(payload['creditLine'])},
        iiif.SOURCE: source_evidence, 'items': []}
    if context['manifestRights'] is not None: manifest['rights'] = context['manifestRights']
    extent, extent_pointers, diagnostics = _extent(payload)
    if extent:
        manifest['items'].append({'id': manifest_id + '/canvas/0', 'type': 'Canvas',
            'label': _language(context['canvasLabel']), **extent, 'items': []})
    raw = target_dumps(manifest); reparsed, expanded = _validate_target(raw, model_root)
    pending = [
        ('/id', manifest_id, 'operator-manifest-identifier', [_operator(plan_raw, plan_hash, index, context, 'manifestId')]),
        ('/label/none/0', iiif.plain_span(payload['title']), 'original-title-plain-span', [sources.proof(row, 'payload', '/title')]),
        ('/summary/none/0', iiif.plain_span(payload['medium']), 'original-medium-plain-span', [sources.proof(row, 'payload', '/medium')]),
        ('/requiredStatement/label/none/0', iiif.plain_span(context['attributionLabel']), 'operator-attribution-label', [_operator(plan_raw, plan_hash, index, context, 'attributionLabel')]),
        ('/requiredStatement/value/none/0', iiif.plain_span(payload['creditLine']), 'original-credit-plain-span', [sources.proof(row, 'payload', '/creditLine')])]
    if context['manifestRights'] is not None:
        pending.append(('/rights', context['manifestRights'], 'operator-manifest-rights',
            [_operator(plan_raw, plan_hash, index, context, 'manifestRights')]))
    if extent:
        pending += [('/items/0/id', manifest_id + '/canvas/0', 'occurrence-canvas-identifier', [_identity(row)]),
            ('/items/0/label/none/0', iiif.plain_span(context['canvasLabel']), 'operator-canvas-label',
                [_operator(plan_raw, plan_hash, index, context, 'canvasLabel')])]
        for key in ('width', 'height'):
            if key in extent:
                pointer = '/measurements/pixels/' + key
                pending.append(('/items/0/' + key, extent[key], 'original-pixel-' + key,
                    [sources.proof(row, 'payload', pointer)]))
        if 'duration' in extent:
            pending.append(('/items/0/duration', extent['duration'], 'exact-original-duration-rational',
                [sources.proof(row, 'payload', pointer) for pointer in extent_pointers if 'durationSeconds' in pointer]))
    proofs = []
    for pointer, target, rule, proof_sources in pending:
        actual = _at(reparsed, pointer)
        expected = target.value if isinstance(target, ExactDecimal) else target
        require(actual == expected and (not isinstance(expected, Decimal) or type(actual) is Decimal),
            'native IIIF final target pointer/value differs')
        proof = _proof(row, path, target, rule, proof_sources)
        proof['target'].update(hash=keccak256(raw), pointer=pointer); proofs.append(proof)
    return path, raw, proofs, {'manifestId': manifest_id,
        'canvasId': None if not extent else manifest_id + '/canvas/0',
        'extent': {key: (_target_value(value)) for key, value in extent.items()},
        'paintingBodyCount': '0', 'expandedRootCount': str(len(expanded)),
        'diagnostics': diagnostics}


def _rebase(value):
    if type(value) is dict:
        return {key: ('source/' + item.removeprefix('dossier/')
            if key == 'path' and type(item) is str and item.startswith('dossier/')
            else _rebase(item)) for key, item in value.items()}
    if type(value) is list: return [_rebase(item) for item in value]
    return value


def _source_scope(files):
    groups = source_occurrences.extract(files)
    result = {'profileHash': source_occurrences.PROFILE_HASH,
        'paintableCorrespondence': {'status': 'not_established',
            'reasons': ['native media source is collection-scoped and is not token-WORK applicability evidence',
                'display URI/MIME/hash does not supply one same-resource URI/MIME/fixity/size/extent tuple',
                'prospective captures are pre-sale simulations and retained PNG bytes are absent']}}
    for name in ('media', 'render'):
        group = groups[name]
        result[name] = {'status': group['status'],
            'occurrenceCount': str(len(group['occurrences'])),
            'kinds': sorted({row['kind'] for row in group['occurrences']}),
            'sourceReferences': _rebase(group['sourceReferences']),
            'occurrences': [{'occurrenceId': row['occurrenceId'], 'kind': row['kind'],
                'status': row['status'], 'sourceReferences': _rebase(row['sourceReferences'])}
                for row in group['occurrences']],
            'qualification': group['qualification']}
    return result


def _derive(files, source_hash, plan_raw, plan_hash, model_root=MODEL_ROOT, *, inventory_raw=None):
    """Private post-verification derivation used by the combined package."""
    plan = _plan(plan_raw, plan_hash, source_hash)
    inventory_raw = inventory._extract(files, source_hash).inventory if inventory_raw is None else inventory_raw
    value = loads(inventory_raw, maximum=dossier.MAX_BYTES, canonical=True)
    require(value['profileHash'] == inventory.PROFILE_HASH
        and value['sourceManifestHash'] == source_hash,
        'native IIIF inventory source/profile differs')
    rows = value['occurrences']; by_id = {row['occurrenceId']: row for row in rows}
    require(len(by_id) == len(rows), 'native IIIF duplicate original occurrence')
    selected = {}
    for index, choice in enumerate(plan['selected']):
        row = by_id.get(choice['occurrenceId'])
        require(row is not None and row['selector'] == choice['selector'],
            'native IIIF exact original occurrence/selector required')
        domains = {domain['name']: domain for domain in row['domains']}
        require(row['family'] == 'WORK' and row.get('interpretation', {}).get('status') == 'interpreted'
            and 'payload' in domains and domains['payload']['schema'] is not None,
            'native IIIF selected occurrence must be an interpreted WORK')
        selected[row['occurrenceId']] = (index, choice)
    sources = _Sources(files); output, proofs, index_rows, diagnostics = {}, [], [], []
    identity_rows = []
    for occurrence_id, (_, choice) in selected.items():
        _, payload = sources.domain(by_id[occurrence_id], 'payload')
        extent, _, _ = _extent(payload)
        identity_rows.append((choice['context']['manifestId'], bool(extent),
            choice['context']['declaredBy']))
    _check_identities(identity_rows)
    for row in rows:
        chosen = selected.get(row['occurrenceId']); manifest_path, rendering = None, None
        if chosen is not None:
            index, choice = chosen; _, payload = sources.domain(row, 'payload')
            require(payload.get('form') == 'full', 'native IIIF WORK description_absent is not renderable')
            manifest_path, raw, additions, rendering = _render(row, payload, choice['context'],
                plan_raw, plan_hash, index, sources, model_root)
            output[manifest_path] = raw; proofs.extend(additions)
            diagnostics.extend({'occurrenceId': row['occurrenceId'], 'reason': reason}
                for reason in rendering['diagnostics'])
        index_rows.append({'occurrenceId': row['occurrenceId'], 'family': row['family'],
            'selector': row['selector'], 'authority': row['authority'],
            'currentness': row['currentness'], 'sourceSelection': row['selection'],
            'planSelected': chosen is not None, 'manifestPath': manifest_path,
            'rendering': rendering, 'domains': deepcopy(row['domains'])})
    mapped = {(proof['occurrenceId'], source['domain'], source['pointer'])
        for proof in proofs for source in proof['sources']
        if source['domain'] not in ('operator_context', 'original_identity', 'derived_bytes')}
    coverage = []
    for field in value['fields']:
        key = (field['occurrenceId'], field['domain'], field['pointer'])
        coverage.append({**field,
            'disposition': 'mapped' if key in mapped else field['disposition'],
            'rule': RULE + 'resolved-original-field' if key in mapped else field['rule'],
            'reason': 'This exact original field contributes to a resolved IIIF target scalar.' if key in mapped else field['reason']})
    scope = _source_scope(files)
    output[OUTPUT_PREFIX + 'index.json'] = dumps({'profileHash': PROFILE_HASH,
        'sourceManifestHash': source_hash, 'fieldInventoryHash': keccak256(inventory_raw),
        'occurrences': index_rows, 'claims': CLAIMS, 'qualification': QUALIFICATION})
    output[OUTPUT_PREFIX + 'source-scope.json'] = dumps(scope)
    output[OUTPUT_PREFIX + 'target-schema.json'] = TARGET_SCHEMA_BYTES
    output[OUTPUT_PREFIX + 'coverage.json'] = dumps({'profileHash': PROFILE_HASH, 'fields': coverage})
    output[OUTPUT_PREFIX + 'provenance.json'] = dumps({'profileHash': PROFILE_HASH, 'rows': proofs})
    report = {'profile': NAME, 'profileHash': PROFILE_HASH,
        'sourceManifestHash': source_hash, 'planHash': plan_hash,
        'status': 'empty_selection' if not selected else 'descriptive_manifests',
        'originalOccurrenceCount': str(len(rows)), 'selectedOccurrenceCount': str(len(selected)),
        'manifestCount': str(len(selected)),
        'canvasCount': str(sum(row['rendering'] is not None and row['rendering']['canvasId'] is not None for row in index_rows)),
        'paintingBodyCount': '0', 'mappedNativeFieldCount': str(len(mapped)),
        'diagnosticCount': str(len(diagnostics)), 'diagnostics': diagnostics,
        'mediaSourceStatus': scope['media']['status'],
        'renderSourceStatus': scope['render']['status'],
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output[OUTPUT_PREFIX + 'report.json'] = dumps(report)
    require(sum(map(len, output.values())) <= MAX_OUTPUT, 'native IIIF output byte bound')
    return Evidence(output, report)


def build(files, source_hash, plan_raw, plan_hash, *, disclosure, model_root=MODEL_ROOT):
    require(disclosure == 'public', 'native IIIF public disclosure required before reads')
    try:
        checked = dossier.verify(dict(files), source_hash)
        return _derive(dict(checked.files), source_hash, plan_raw, plan_hash, model_root)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OSError, OverflowError,
            UnicodeError, RecursionError) as exc:
        raise MuseumError('malformed native IIIF source') from exc
