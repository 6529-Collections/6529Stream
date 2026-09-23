"""Source-field correspondence from one concretely replayed format package.

This is a finite export ledger, not an admission route for canonical native
families. Cumulative coverage reports never establish a format-local mapping.
"""
from dataclasses import asdict, dataclass
from decimal import Decimal
from pathlib import Path
import re
import tempfile

from lxml import etree

from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .iiif_numbers import target_loads
from .independent_wire import require
from .schema_inventory import EVALUATION_PROFILE_HASH, inventory_exact

NAME = 'STREAM_MUSEUM_SAME_SOURCE_FORMAT_LEDGER_V1'
FORMATS = ('linked-art', 'premis', 'iiif', 'lido')
MODES = ('synthetic_candidate_resource_package', 'recorded_account_resource_package',
    'recorded_account_premis_resource_package', 'recorded_account_iiif_resource_package',
    'recorded_account_lido_resource_package')
MAX_FIELDS = 65536
MAX_EMISSIONS = 131072
MAX_JSON = 64 * 1024 * 1024
CLAIMS = {'sourcePackageReplayed': True, 'allPublicSourceRecordsAccounted': True,
    'localMappingsRequireResolvedOwnTargets': True, 'cumulativeCoverageIsLocalMapping': False,
    'allFieldsMappedInEveryFormat': False, 'nativeCanonicalFamiliesJoined': False,
    'sourceOriginAuthenticated': False, 'mediaRetrieved': False, 'fixityVerified': False,
    'institutionalAcceptance': False, 'formatConformanceBeyondOriginalVerifier': False}
QUALIFICATION = ('One exact original package and source state only. Every public source record '
    'precedes selection in the inventory; unsupported schema evaluation retains an explicit '
    'opaque record. Own-format provenance and resolved target bytes establish local cells, '
    'not inherited coverage or sidecar retention. Comparisons preserve original occurrences '
    'and distinguish exact text, supported encodings, and non-comparable rule outputs. '
    'A missing mapping or format establishes neither irrelevance nor absence of source facts. '
    'Work, token, file, content locator, Canvas, Manifest, creator and issuer stay distinct. '
    'Synthetic and externally admitted recorded provenance remain their original kinds.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'status': 'prospective_unregistered',
    'sourceModes': list(MODES), 'formats': list(FORMATS),
    'inventoryEvaluationHash': EVALUATION_PROFILE_HASH,
    'limits': {'packageBytes': MAX_BYTES, 'fields': MAX_FIELDS, 'emissions': MAX_EMISSIONS,
        'outputBytes': MAX_BYTES},
    'sourceReferences': 'Paths relative to the enclosing package, under source/.',
    'jsonTargets': 'Exact JSON Pointer; legacy producer paths containing unescaped IRI keys '
        'are resolved uniquely against actual keys and also retain the normalized pointer.',
    'xmlTargets': 'Absolute bounded child/attribute XPath only, with original namespaces; '
        'no DTD, entities, network, XPath functions or descendant search.',
    'dispositions': 'mapped requires an own-format witness; schema-proven absent optional '
        'properties are not_applicable; all other unmapped facts stay retained_stream_only.',
    'comparisons': 'Only identity, title, creator, date, rights, media and scoped measurement '
        'values. Exact strings, exact numeric value and the original IIIF plain-span encoding '
        'are compared; structural/profile class transforms remain non-comparable.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Evidence:
    inventory: bytes
    ledger: bytes
    identities: bytes
    comparisons: bytes
    report: dict


def _ref(path, raw, **extra):
    return package._ref('source/' + path, raw) | extra


def _json(raw):
    return loads(raw, maximum=MAX_JSON, canonical=True)


def _pointer(value, pointer):
    require(type(pointer) is str and (pointer == '' or pointer.startswith('/')),
        'format ledger source pointer')
    for part in pointer.split('/')[1:]:
        require(re.search(r'~(?![01])', part) is None, 'format ledger pointer escape')
        part = part.replace('~1', '/').replace('~0', '~')
        if type(value) is list:
            require(re.fullmatch(r'0|[1-9][0-9]*', part) is not None,
                'format ledger pointer index')
            value = value[int(part)]
        else:
            value = value[part]
    return value


def _escape(value):
    return value.replace('~', '~0').replace('/', '~1')


def _target_pointer(value, pointer):
    """Resolve exact producer paths, including their finite legacy IRI-key form."""
    require(type(pointer) is str and len(pointer) <= 4096 and pointer.startswith('/'),
        'format ledger target pointer')
    steps = 0

    def walk(node, remaining, path):
        nonlocal steps
        steps += 1
        require(steps <= 4096, 'format ledger target pointer work bound')
        if not remaining:
            return [(node, path)]
        require(remaining.startswith('/'), 'format ledger target path boundary')
        tail = remaining[1:]
        if isinstance(node, dict):
            found = []
            for key in node:
                for spelling in {_escape(key), key}:
                    if tail == spelling or tail.startswith(spelling + '/'):
                        found.extend(walk(node[key], tail[len(spelling):], path + '/' + _escape(key)))
            # Escaped and literal spelling may reach the same exact location.
            return list({path: (item, path) for item, path in found}.values())
        if isinstance(node, list):
            part, separator, rest = tail.partition('/')
            if re.fullmatch(r'0|[1-9][0-9]*', part) and int(part) < len(node):
                return walk(node[int(part)], '/' + rest if separator else '', path + '/' + part)
        return []

    found = walk(value, pointer, '')
    require(len(found) == 1, 'format ledger unresolved or ambiguous target pointer')
    return found[0]


def _value(value):
    if isinstance(value, Decimal):
        return {'kind': 'number', 'lexical': str(value)}
    if type(value) is int:
        return {'kind': 'number', 'lexical': str(value)}
    if value is None or type(value) in (bool, str):
        return {'kind': 'null' if value is None else 'boolean' if type(value) is bool else 'string',
            'value': value}
    require(type(value) in (list, dict), 'format ledger target value kind')
    return {'kind': 'array' if type(value) is list else 'object', 'length': str(len(value))}


_XPATH = re.compile(r'(?:/(?:[A-Za-z_][A-Za-z0-9_.-]*(?::[A-Za-z_][A-Za-z0-9_.-]*)?|\*)'
    r'(?:\[[1-9][0-9]*\])?)+(?:/@[A-Za-z_][A-Za-z0-9_.-]*(?::[A-Za-z_][A-Za-z0-9_.-]*)?)?\Z')


class _Targets:
    def __init__(self, files, reference):
        self.files, self.cache, self.reference = files, {}, reference
        self.entities = {row['id']: row['path'] for row in _json(files['linked-art/entity-index.json'])
            if row['kind'] == 'linked_art'}

    def resolve(self, format_name, proof):
        path = (self.entities.get(proof['entity']) if format_name == 'linked-art' else
            {'premis': 'premis/premis.xml', 'iiif': 'iiif/manifest.json', 'lido': 'lido/lido.xml'}[format_name])
        require(path in self.files, 'format ledger own target file absent')
        raw = self.files[path]
        if path not in self.cache:
            if path.endswith('.xml'):
                require(b'<!DOCTYPE' not in raw and b'<!ENTITY' not in raw,
                    'format ledger XML declarations forbidden')
                parser = etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True,
                    huge_tree=False, remove_blank_text=False)
                self.cache[path] = etree.fromstring(raw, parser)
            else:
                self.cache[path] = target_loads(raw) if format_name == 'iiif' else _json(raw)
        parsed = self.cache[path]
        if path.endswith('.xml'):
            xpath = proof['targetXPath']
            require(type(xpath) is str and len(xpath) <= 4096 and _XPATH.fullmatch(xpath),
                'format ledger XPath outside bounded profile')
            namespaces = {'premis': 'http://www.loc.gov/premis/v3',
                'xsi': 'http://www.w3.org/2001/XMLSchema-instance',
                'lido': 'http://www.lido-schema.org', 'xml': 'http://www.w3.org/XML/1998/namespace'}
            namespaces.update({k: v for k, v in parsed.nsmap.items() if k})
            matches = parsed.xpath(xpath, namespaces=namespaces)
            require(len(matches) == 1, 'format ledger XPath must resolve one target')
            node = matches[0]
            value = ({'kind': 'string', 'value': node.text or ''} if isinstance(node, etree._Element) and len(node) == 0
                else {'kind': 'xml_element', 'subtreeHash': keccak256(etree.tostring(node))}
                if isinstance(node, etree._Element) else {'kind': 'string', 'value': str(node)})
            location = {'xpath': xpath}
            role = etree.QName(node).localname if isinstance(node, etree._Element) else 'attribute'
        else:
            actual, pointer = _target_pointer(parsed, proof['targetPointer'])
            value = _value(actual)
            location = {'pointer': pointer, 'producerPointer': proof['targetPointer']}
            role = ('declared_' + str(parsed.get('type', 'resource')) + '_identifier'
                if format_name == 'linked-art' else 'source_file_entity_link'
                if pointer.endswith('/fileEntity') else 'source_work_entity_link'
                if pointer.endswith('/workEntity') else 'presentation_value')
        return {'source': self.reference(path) | location, 'value': value,
            'role': format_name + ':' + role}


def _category(payload, pointer):
    if re.fullmatch(r'/entities/[0-9]+/id', pointer):
        entity = _pointer(payload, pointer.rsplit('/', 1)[0])
        return 'identity', entity['kind'], entity['id']
    if re.fullmatch(r'/entities/[0-9]+/names/[0-9]+/value', pointer):
        entity = _pointer(payload, '/'.join(pointer.split('/')[:3]))
        return 'title', entity['kind'] + '_name', entity['id']
    if re.fullmatch(r'/assertions/[0-9]+/object/(?:entity|literal/lexicalValue)', pointer):
        assertion = _pointer(payload, '/'.join(pointer.split('/')[:3]))
        from .lido_model import FIELDS as lf
        from .premis import FIELDS as pf
        from .iiif import FIELDS as it
        relation = assertion['relation']
        if relation == lf['creator']:
            category = 'creator'
        elif relation == lf['creation-display']:
            category = 'date'
        elif relation in (it['rights'], it['manifest-rights']):
            category = 'rights'
        elif relation in (it[k] for k in ('width', 'height', 'duration', 'text-canvas-width', 'text-canvas-height')):
            category = 'measurement'
        elif relation in set(pf.values()) | {it[k] for k in ('content-uri', 'mime', 'presentation-type')}:
            category = 'media'
        else:
            return None, None, None
        return category, relation, assertion['subject']
    return None, None, None


def _comparison_value(source, target, rule, format_name):
    """Compare actual target values; retain transformations instead of echoing source."""
    if target['kind'] == 'string' and type(source) is str:
        actual = target['value']
        if actual == source:
            return 'exact_lexical', actual
        from .iiif_model import plain_span
        from .iiif import FIELDS as iiif_fields
        if (format_name == 'iiif' and rule in (iiif_fields['summary'], iiif_fields['attribution'])
                and actual == plain_span(source)):
            return 'exact_plain_span_encoding', source
        # Class/category terms are finite crosswalk transforms, not literal identity.
        from .premis import FIELDS as premis_fields
        if (format_name == 'premis' and rule == premis_fields['category']
                and source == 'file' and actual == 'premis:file'):
            return 'exact_premis_file_category', source
        return 'different_lexical', actual
    if target['kind'] == 'number' and type(source) in (str, int):
        try:
            if Decimal(str(source)) == Decimal(target['lexical']):
                return 'exact_numeric_value', str(source)
            return 'different_numeric_value', target['lexical']
        except ArithmeticError:
            pass
    return 'non_comparable_rule_output', None


def _derive(files, manifest, manifest_hash):
    """Internal post-verification analysis; public build owns concrete admission."""
    state_hash = manifest['sourceStateHash']
    references = {}

    def reference(path, **extra):
        if path not in references:
            references[path] = _ref(path, files[path])
        return references[path] | extra

    sidecar_path = 'linked-art/sidecar.json'
    sidecar_raw = files[sidecar_path]
    sidecar = _json(sidecar_raw)
    originals = sidecar['publicSources']
    require(type(originals) is list and len(originals) <= 512, 'format ledger original record bound')
    records, fields, field_map, records_by_selector = [], [], {}, {}
    for index, original in enumerate(originals):
        selector = original['selector']
        key = dumps(selector | {'pointer': ''})
        require(key not in records_by_selector, 'format ledger duplicate original selector')
        schema, payload = hex_bytes(original['schemaHex']), hex_bytes(original['payloadHex'])
        require(keccak256(schema) == selector['schemaHash'], 'format ledger original schema pin')
        record_id = keccak256(dumps({'state': state_hash, 'selector': selector}))
        base = '/publicSources/' + str(index)
        record = {'recordId': record_id, 'selector': selector, 'schemaHash': keccak256(schema),
            'payloadHash': keccak256(payload), 'inventoryScopeInOriginalProjection': original['inventoryScope'],
            'original': reference(sidecar_path, pointer=base),
            'payload': reference(sidecar_path, pointer=base + '/payloadHex', derivation='hex_decode'),
            'schema': reference(sidecar_path, pointer=base + '/schemaHex', derivation='hex_decode'),
            'status': 'schema_inventoried', 'fieldIds': [], 'branches': []}
        parsed = None
        try:
            evaluated = inventory_exact(schema, payload, schema_hash=selector['schemaHash'],
                payload_hash=keccak256(payload), evaluation_hash=EVALUATION_PROFILE_HASH)
            parsed = loads(payload, canonical=True)
        except MuseumError:
            require(not original['inventoryScope'], 'format ledger selected source schema inventory unavailable')
            record.update(status='opaque_retained', reasonCode='unsupported_schema_or_payload_evaluation')
        else:
            record['branches'] = [asdict(row) for row in evaluated.branches]
            for field in evaluated.fields:
                field_id = keccak256(dumps({'recordId': record_id, 'schemaHash': selector['schemaHash'],
                    'pointer': field.pointer}))
                category, role, entity = _category(parsed, field.pointer)
                row = {'fieldId': field_id, 'recordId': record_id, 'pointer': field.pointer,
                    'presence': field.presence, 'kind': field.kind, 'exactHex': '0x' + field.exact.hex(),
                    'category': category, 'sourceRole': role, 'sourceEntity': entity}
                fields.append(row); field_map[(key, field.pointer)] = row
                record['fieldIds'].append(field_id)
                require(len(fields) <= MAX_FIELDS, 'format ledger field bound')
        records.append(record)
        records_by_selector[key] = (record, parsed)
    targets = _Targets(files, reference)
    coverage, emissions, local, identity_rows = {}, [], {}, []
    support = {}
    for format_name in FORMATS:
        provenance_path = format_name + '/provenance.json'
        support[format_name] = {'status': 'present' if provenance_path in files else 'absent',
            'originalReport': reference(format_name + '/report.json')
                if format_name + '/report.json' in files else None}
        coverage_path = format_name + '/coverage.json'
        coverage[format_name] = {(row['recordHash'], field['pointer']): field
            for row in _json(files[coverage_path]) for field in row['fields']} if coverage_path in files else {}
        proofs = _json(files[provenance_path]) if provenance_path in files else []
        require(type(proofs) is list and len(emissions) + len(proofs) <= MAX_EMISSIONS,
            'format ledger provenance bound')
        for index, proof in enumerate(proofs):
            key = dumps(proof['source'] | {'pointer': ''})
            require(key in records_by_selector, 'format ledger provenance original selector differs')
            field = field_map.get((key, proof['sourcePointer']))
            require(field is not None and field['presence'] == 'present',
                'format ledger provenance source field missing')
            record, payload = records_by_selector[key]
            require(type(proof['rule']) is str and proof['rule'], 'format ledger mapping rule missing')
            target = targets.resolve(format_name, proof)
            emission_id = keccak256(dumps({'format': format_name, 'provenanceIndex': str(index),
                'fieldId': field['fieldId'], 'target': target['source']}))
            source_value = _pointer(payload, field['pointer'])
            comparison, compared = (_comparison_value(source_value, target['value'], proof['rule'], format_name)
                if field['category'] is not None else ('not_in_finite_comparison_profile', None))
            emission = {'emissionId': emission_id, 'fieldId': field['fieldId'], 'format': format_name,
                'rule': proof['rule'], 'entity': proof['entity'], 'target': target,
                'provenance': reference(provenance_path, pointer='/' + str(index)),
                'comparison': comparison, 'comparisonValue': compared}
            emissions.append(emission)
            local.setdefault((field['fieldId'], format_name), []).append(emission)
            if field['category'] == 'identity':
                identity_rows.append({'fieldId': field['fieldId'], 'recordId': record['recordId'],
                    'sourceEntity': field['sourceEntity'], 'sourceRole': field['sourceRole'],
                    'format': format_name, 'targetRole': target['role'],
                    'emissionId': emission_id, 'target': target, 'comparison': comparison})
    ledger, comparisons = [], []
    selectors = {row['recordId']: row['selector'] for row in records}
    for field in fields:
        cells, checks = {}, []
        for format_name in FORMATS:
            own = local.get((field['fieldId'], format_name), [])
            inherited = coverage[format_name].get((selectors[field['recordId']]['recordHash'], field['pointer']))
            if inherited is not None:
                require(inherited['exactHex'] == field['exactHex'] and inherited['presence'] == field['presence'],
                    'format ledger coverage disagrees with original source inventory')
            cells[format_name] = {'status': 'mapped_local' if own else 'format_absent'
                if support[format_name]['status'] == 'absent' else 'retained_no_local_mapping',
                'disposition': 'mapped' if own else 'not_applicable'
                    if field['presence'] == 'absent' else 'retained_stream_only',
                'rule': NAME + (':resolved-own-provenance' if own else ':absent-source-property'
                    if field['presence'] == 'absent' else ':retain-source-without-local-mapping'),
                'reason': ('Own-format rule and actual target location retained.' if own else
                    'Applicable optional property is absent in this exact original payload; no value to map.'
                    if field['presence'] == 'absent' else
                    'Source remains retained; this finite profile establishes no local mapping or irrelevance.'),
                'emissionIds': [row['emissionId'] for row in own],
                'originalCumulativeDisposition': None if inherited is None else inherited['disposition'],
                'applicability': 'witnessed_local_mapping' if own else 'not_established_by_this_profile'}
            checks.extend({'format': format_name, 'emissionId': row['emissionId'],
                'outcome': row['comparison'], 'value': row['comparisonValue']} for row in own)
        ledger.append({'fieldId': field['fieldId'], 'cells': cells})
        if field['category'] is not None:
            values = [row for row in checks if row['value'] is not None]
            local_formats = sorted({row['format'] for row in checks})
            value_formats = sorted({row['format'] for row in values})
            mismatch = any(row['outcome'].startswith('different_') for row in checks)
            outcome = ('value_mismatch' if mismatch else 'exact_same_source_agreement'
                if len(value_formats) >= 2 and len({dumps(row['value']) for row in values}) == 1
                else 'single_format_only' if len(local_formats) == 1
                else 'not_locally_mapped' if not local_formats else 'unsupported_comparison')
            comparisons.append({'fieldId': field['fieldId'], 'category': field['category'],
                'sourceRole': field['sourceRole'], 'sourceEntity': field['sourceEntity'],
                'outcome': outcome, 'localFormats': local_formats,
                'unmappedFormats': [name for name in FORMATS if name not in local_formats], 'checks': checks})
    # Exact plan/layout identities are separate from source declaration identities.
    layouts = []
    for name in ('premis', 'iiif', 'lido'):
        path = name + '/correspondence.json'
        if path in files:
            layouts.append({'format': name, 'source': reference(path),
                'value': _json(files[path]), 'qualification': 'Original explicit role associations; no identity equivalence inferred.'})
    layout_ids = []
    if 'iiif/manifest.json' in files:
        presentation = target_loads(files['iiif/manifest.json'])
        pointers = [('/id', 'presentation_manifest')]
        for index, canvas in enumerate(presentation['items']):
            prefix = '/items/' + str(index)
            pointers.extend(((prefix + '/id', 'presentation_canvas'),
                (prefix + '/items/0/id', 'annotation_page'),
                (prefix + '/items/0/items/0/id', 'painting_annotation'),
                (prefix + '/items/0/items/0/body/id', 'content_locator')))
        for pointer, role in pointers:
            value, normalized = _target_pointer(presentation, pointer)
            layout_ids.append({'format': 'iiif', 'role': role, 'value': value,
                'target': reference('iiif/manifest.json', pointer=normalized),
                'qualification': 'Exact output identity in its stated role; no equality with a work or token inferred.'})
    inventory_raw = dumps({'profileHash': PROFILE_HASH, 'sourceManifestHash': manifest_hash,
        'sourceStateHash': state_hash, 'records': records, 'fields': fields})
    ledger_raw = dumps({'profileHash': PROFILE_HASH, 'formats': support, 'rows': ledger, 'emissions': emissions})
    identities_raw = dumps({'profileHash': PROFILE_HASH, 'occurrences': identity_rows,
        'layoutIdentities': layout_ids, 'originalRoleCorrespondence': layouts})
    comparisons_raw = dumps({'profileHash': PROFILE_HASH, 'rows': comparisons})
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': manifest_hash,
        'sourceMode': manifest['mode'], 'sourceStateHash': state_hash,
        'environment': manifest.get('environment'), 'recordCount': str(len(records)),
        'opaqueRecordCount': str(sum(row['status'] == 'opaque_retained' for row in records)),
        'fieldCount': str(len(fields)), 'emissionCount': str(len(emissions)), 'formats': support,
        'localMappingCounts': {name: str(sum(bool(local.get((field['fieldId'], name))) for field in fields)) for name in FORMATS},
        'comparisonOutcomes': {outcome: str(sum(row['outcome'] == outcome for row in comparisons))
            for outcome in sorted({row['outcome'] for row in comparisons})},
        'outputHashes': {'inventory': keccak256(inventory_raw), 'ledger': keccak256(ledger_raw),
            'identities': keccak256(identities_raw), 'comparisons': keccak256(comparisons_raw)},
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    require(sum(map(len, (inventory_raw, ledger_raw, identities_raw, comparisons_raw, dumps(report)))) <= MAX_BYTES,
        'format ledger aggregate output bound')
    return Evidence(inventory_raw, ledger_raw, identities_raw, comparisons_raw, report)


def build(files, manifest_hash, *, disclosure):
    """Admit one original package, then derive its complete bounded local ledger."""
    require(disclosure == 'public', 'format ledger public disclosure required before reads')
    try:
        files = dict(files); package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(manifest_hash, 32)) and keccak256(raw) == manifest_hash,
            'format ledger external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(manifest.get('mode') in MODES and manifest.get('version') == '2',
            'format ledger original package mode unsupported')
        with tempfile.TemporaryDirectory(prefix='stream-format-ledger-') as temp:
            root = Path(temp) / 'original'
            write_tree(files, root)
            if manifest['mode'] == MODES[0]:
                from .package_v2 import verify_fixture_package
                checked = verify_fixture_package(root, manifest_hash)
            else:
                from .package_recorded import verify_recorded_package
                checked = verify_recorded_package(root, manifest_hash)
            require(dict(checked.files) | {'manifest.json': checked.manifest} == files,
                'format ledger original reconstruction differs')
        return _derive(files, manifest, manifest_hash)
    except MuseumError:
        raise
    except (KeyError, ValueError, TypeError, IndexError, OSError, RecursionError, etree.LxmlError) as exc:
        raise MuseumError('malformed same-source format ledger input') from exc
