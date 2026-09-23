"""Native source payload files and retained conservation material to PREMIS 3.

No artwork media, historical fixity event, agent or rights is inferred. The
public entry point replays V4; private helpers require its checked originals.
"""
from copy import deepcopy
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path

from jsonschema import Draft202012Validator
from lxml import etree

from . import canonical_field_inventory_v1 as inventory
from . import canonical_object_dossier_v4 as dossier
from . import canonical_semantic_sources_v1 as pointers
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .premis import NS, XSI, PinnedPremis, PROFILE_BYTES as XSD_PROFILE_BYTES, PROFILE_HASH as XSD_PROFILE_HASH, _element

NAME = 'STREAM_MUSEUM_NATIVE_PREMIS_V1'
PLAN_KIND = 'native_premis'
OUTPUT_PREFIX = 'premis/'
MAX_PLAN = 524288
MAX_SELECTED = 64
MAX_OBJECTS = 512
MAX_REFERENCES = 16384
MAX_OUTPUT = 32 * 1024 * 1024
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
CONSERVATION = 'canonical/input/conservation/'
RULE = 'urn:6529stream:museum:native-premis:v1:'
CLAIMS = {'originalV4Replayed': True, 'allRetainedInventoryOccurrencesAccounted': True,
    'retainedBytesMeasuredOffline': True, 'premisXsdValidatedWhenXmlPresent': True,
    'artworkMediaIdentityInferred': False, 'historicalFixityEventProven': False,
    'archiveDeliveryProven': False, 'formatDetected': False, 'rightsGranted': False,
    'agentIdentityInferred': False, 'currentAuthorityProven': False,
    'sourceOriginAuthenticated': False, 'fullPreservationInventory': False,
    'originalRequirementsPromoted': False, 'networkFetch': False}
QUALIFICATION = ('Native payload file objects describe the exact retained source-record payload bytes, '
    'not the artwork or its media. Documentary material objects describe exact received bytes for original '
    'conservation Reference occurrences with complete retained Archive correspondence. Repeated references '
    'remain separate objects. Computed byte size/SHA256/Keccak are present offline measurements, not '
    'historical check events. Original digest, URI, canonicalization, schema and format fields remain '
    'attributed declarations. A storage URI is the original declared locator, not proof of retrieval from '
    'that URI. Missing/incomplete references stay diagnostics. No agent, rights, custody, current '
    'availability, format detection, global preservation completeness or 19/49 promotion is inferred.')


def plan_schema():
    digest = {'type': 'string', 'pattern': '^0x[0-9a-f]{64}$'}
    return {'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'title': 'STREAM_MUSEUM_NATIVE_PREMIS_PLAN_V1', 'type': 'object', 'additionalProperties': False,
        'required': ['version', 'kind', 'sourceManifestHash', 'selected'], 'properties': {
            'version': {'const': '1'}, 'kind': {'const': PLAN_KIND}, 'sourceManifestHash': digest,
            'selected': {'type': 'array', 'maxItems': MAX_SELECTED, 'items': {
                'type': 'object', 'additionalProperties': False, 'required': ['occurrenceId', 'selector'],
                'properties': {'occurrenceId': digest, 'selector': {'type': 'object'}}}}}}


PLAN_SCHEMA_BYTES = dumps(plan_schema())
PLAN_SCHEMA_HASH = keccak256(PLAN_SCHEMA_BYTES)
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'status': 'prospective_unregistered_adapter',
    'sourceProfileHash': dossier.PROFILE_HASH, 'inventoryProfileHash': inventory.PROFILE_HASH,
    'planSchemaHash': PLAN_SCHEMA_HASH, 'xsdValidatorProfileHash': XSD_PROFILE_HASH,
    'objects': ['original_record_payload_file', 'retained_conservation_reference_material'],
    'selection': 'Exact complete inventory occurrence ID and original whole selector; all families '
        'remain visible before selection. No current/canonical eligibility gate is added.',
    'materialDenominator': 'Every Reference in a selected conservation payload and its retained catalog '
        'domains, in original order. Only complete Archive correspondence with retained matching bytes '
        'yields a material object. Duplicate original/domain/reference occurrences are not merged.',
    'references': 'source/ is relative to the enclosing package. Native sources use the exact inventory '
        'domain source reference plus a pointer inside that decoded domain. derived_bytes uses the '
        'exact raw or hex-decoded file pointer and computed measurement; it is not native field mapping. '
        'Generated namespace/type labels use original_identity, not native value fields. Digest algorithm '
        'labels cite the original algorithm field separately from digest values; General fixed-protocol '
        'Keccak uses original_identity because no original algorithm field exists.',
    'premis': 'File objects only. Source schema IDs are a named native schema declaration; format is '
        'not detected. Original PRONOM keys are emitted only from exact admitted FormatRef fields. '
        'Algorithm IDs 1/2/3 map to Keccak-256/SHA-256/BLAKE3 content digests only after byte correspondence; '
        'multihash/CID/transaction IDs are never reinterpreted as content digests.',
    'limits': {'planBytes': MAX_PLAN, 'selected': MAX_SELECTED, 'objects': MAX_OBJECTS, 'references': MAX_REFERENCES,
        'outputBytes': MAX_OUTPUT, 'inputBytes': dossier.MAX_BYTES},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Evidence:
    files: dict
    report: dict


def _json(raw):
    return loads(raw, maximum=dossier.MAX_BYTES, canonical=True)


def _plan(raw, digest, source_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_PLAN and any(hex_bytes(digest, 32))
        and keccak256(raw) == digest, 'native PREMIS plan pin/bound differs')
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(not list(Draft202012Validator(plan_schema()).iter_errors(value))
        and value['sourceManifestHash'] == source_hash, 'native PREMIS closed plan/source differs')
    require(len({r['occurrenceId'] for r in value['selected']}) == len(value['selected']),
        'native PREMIS duplicate selected occurrence')
    return value


class _Sources:
    def __init__(self, files):
        self.files, self.parsed, self.hashes = files, {}, {}

    def load(self, path):
        if path not in self.parsed: self.parsed[path] = _json(self.files[path])
        return self.parsed[path]

    def ref(self, path, pointer='', encoding='json'):
        if path not in self.hashes: self.hashes[path] = keccak256(self.files[path])
        result = {'path': 'source/' + path, 'hash': self.hashes[path], 'jsonPointer': pointer, 'encoding': encoding}
        self.resolve(result)
        return result

    def resolve(self, ref):
        require(ref['path'].startswith('source/'), 'native PREMIS source reference base differs')
        path = ref['path'][7:]
        if path not in self.hashes: self.hashes[path] = keccak256(self.files[path])
        require(ref['hash'] == self.hashes[path], 'native PREMIS original file hash differs')
        if ref['encoding'] == 'bytes':
            require(ref['jsonPointer'] == '', 'native PREMIS byte reference pointer differs')
            return self.files[path]
        return pointers._resolve_value(self.load(path), ref['jsonPointer'], ref['encoding'])

    def domain(self, row, name):
        found = [d for d in row['domains'] if d['name'] == name]
        require(len(found) == 1, 'native PREMIS domain missing/ambiguous')
        raw = self.resolve(found[0]['source'])
        return found[0]['source'], _json(raw) if type(raw) is bytes else raw

    def proof(self, row, domain, pointer):
        ref, value = self.domain(row, domain)
        scalar = pointers._resolve_value(value, pointer, 'json')
        require(type(scalar) not in (dict, list), 'native PREMIS only scalar native field mapping')
        return {'domain': domain, 'sourceReference': ref, 'pointer': pointer,
            'exactHex': '0x' + dumps(scalar).hex(), 'selector': row['selector'],
            'authority': row['authority'], 'qualification': 'original_native_declaration'}


def _payload(sources, row):
    """Locate actual original bytes; typed payload domains are not required."""
    domains = [d for d in row['domains'] if d['name'] == 'payload']
    if domains:
        ref = domains[0]['source']; raw = sources.resolve(ref)
        require(type(raw) is bytes, 'native PREMIS payload byte domain required')
        return ref, raw
    original = sources.resolve(row['original'])
    pointer = '/payloadHex' if type(original.get('payloadHex')) is str else (
        '/record/5' if row['selector'].get('kind') == 'native_owner_family' else None)
    if pointer is None: return None, None
    ref = {**row['original'], 'jsonPointer': row['original']['jsonPointer'] + pointer, 'encoding': 'hex'}
    return ref, sources.resolve(ref)


def _payload_declarations(row, original):
    """Finite original ABI layouts, never artwork-media facts."""
    if 'value' in original and row['family'] in ('GENERAL', 'GENERAL_ORIGINAL'):
        return (1, '/value/8', '/value/6', '/value/5', None)
    if 'record' not in original: return None
    owner = row['selector'].get('kind') in ('native_owner_family', 'native_owner_condition')
    index = 3 if owner else 2
    ref = original['record'][index]
    if type(ref) is not list or len(ref) != 3: return None
    return (int(ref[0]), '/record/' + str(index) + '/1', '/record/' + str(index) + '/2',
        '/record/2' if owner else '/record/4', '/record/' + str(index) + '/0')


def _reference_materials(sources, row):
    if not row['family'].startswith('CONSERVATION_'): return []
    path = CONSERVATION + 'archive/correspondence.json'
    refs_path = CONSERVATION + 'source/conservation/reference-occurrences.json'
    doc_path = CONSERVATION + 'source/conservation/dossier.json'
    if path not in sources.files:
        return [{'status': 'archive_source_not_retained', 'domain': None, 'referenceIndex': None}]
    correspondence = sources.load(path)['occurrences']; refs = sources.load(refs_path)['occurrences']
    require(len(correspondence) == len(refs) <= MAX_REFERENCES, 'native PREMIS reference denominator differs')
    result = []
    for domain in row['domains']:
        name = domain['name']
        if name != 'payload' and not name.startswith('catalog_'): continue
        ref, value = sources.domain(row, name)
        for index, (original_ref, saved) in enumerate(zip(refs, correspondence)):
            require(saved['occurrence'] == original_ref, 'native PREMIS Archive occurrence differs')
            pieces = original_ref['jsonPointer'].split('/')
            if name == 'payload':
                if original_ref['sourceKind'] != 'record' or original_ref['sourceRecord'] != row['selector']: continue
                require(pieces[1] == 'records' and pieces[3] == 'semantic', 'native PREMIS record reference pointer')
            else:
                if original_ref['sourceKind'] != 'catalog_document': continue
                document = sources.load(ref['path'][7:])['documents'][int(ref['jsonPointer'].split('/')[2])]
                if original_ref['catalogSelector'] != {'documentId': document['documentId'], 'documentHash': keccak256(sources.resolve(ref))}: continue
                require(pieces[1] == 'catalogDocuments' and pieces[3] == 'value', 'native PREMIS catalog reference pointer')
            inner = '/' + '/'.join(pieces[4:])
            declared = pointers._resolve_value(value, inner, 'json')
            require(declared == {'hash': original_ref['hash'], 'uri': original_ref['uri']},
                'native PREMIS exact original Reference differs')
            require(pointers._resolve_value(sources.load(doc_path), original_ref['jsonPointer'], 'json') == declared,
                'native PREMIS original documentary pointer differs')
            item = {'status': saved['status'], 'domain': name, 'referenceIndex': str(index),
                'pointer': inner, 'reference': original_ref, 'correspondence': saved,
                'correspondenceSource': sources.ref(path, '/occurrences/' + str(index)),
                'bytesSource': None, 'raw': None, 'formatPointer': None}
            if saved['materialPath'] is not None:
                material_path = CONSERVATION + 'materials/data/' + saved['materialPath']
                require(material_path in sources.files, 'native PREMIS retained material missing')
                raw = sources.files[material_path]
                require(saved['material'] == {'byteLength': str(len(raw)), 'keccak256': keccak256(raw),
                    'sha256': '0x' + sha256(raw).hexdigest()}, 'native PREMIS material bytes differ')
                item.update(raw=raw, bytesSource=sources.ref(material_path, encoding='bytes'))
            if saved['status'] == 'complete':
                require(item['raw'] is not None and saved['originalHashRefChecked'] is True and saved['archive'] is not None,
                    'native PREMIS complete material correspondence differs')
                parent_pointer = inner.rsplit('/', 1)[0]
                parent = pointers._resolve_value(value, parent_pointer, 'json')
                if inner.endswith('/content') and type(parent) is dict and 'format' in parent:
                    require(saved['declaredFormat'] == parent['format'], 'native PREMIS declared format differs')
                    item['formatPointer'] = parent_pointer + '/format'
            require(len(result) < MAX_REFERENCES, 'native PREMIS selected reference bound')
            result.append(item)
    return result


def _objects(sources, rows, selected):
    objects, diagnostics, occurrence_rows = [], [], []
    for row in rows:
        chosen = row['occurrenceId'] in selected
        item = {'occurrenceId': row['occurrenceId'], 'family': row['family'], 'selector': row['selector'],
            'authority': row['authority'], 'currentness': row['currentness'], 'selection': row['selection'],
            'planSelected': chosen, 'objects': [], 'status': 'unselected', 'source': row['original']}
        occurrence_rows.append(item)
        if not chosen: continue
        byte_ref, raw = _payload(sources, row)
        if raw is None:
            item['status'] = 'payload_bytes_not_available'
            diagnostics.append({'occurrenceId': row['occurrenceId'], 'status': item['status']})
        else:
            require(type(raw) is bytes, 'native PREMIS retained payload type')
            objects.append({'row': row, 'role': 'original_record_payload_file', 'raw': raw,
                'bytesSource': byte_ref, 'domain': 'original', 'referenceIndex': None,
                'declarations': _payload_declarations(row, sources.resolve(row['original'])), 'material': None})
            item['status'] = 'payload_file_available'
        for material in _reference_materials(sources, row):
            if material['status'] != 'complete':
                diagnostics.append({'occurrenceId': row['occurrenceId'], **{k: v for k, v in material.items() if k != 'raw'}})
                continue
            objects.append({'row': row, 'role': 'retained_conservation_reference_material', 'raw': material['raw'],
                'bytesSource': material['bytesSource'], 'domain': material['domain'],
                'referenceIndex': material['referenceIndex'], 'declarations': None, 'material': material})
        require(len(objects) <= MAX_OBJECTS, 'native PREMIS object bound')
    by_occurrence = {row['occurrenceId']: row for row in occurrence_rows}
    for obj in objects:
        obj['id'] = 'urn:6529stream:native-premis-file:' + keccak256(dumps({'profileHash': PROFILE_HASH,
            'occurrenceId': obj['row']['occurrenceId'], 'role': obj['role'], 'domain': obj['domain'],
            'referenceIndex': obj['referenceIndex'], 'bytesSource': obj['bytesSource']}))[2:]
        by_occurrence[obj['row']['occurrenceId']]['objects'].append(obj['id'])
    return objects, diagnostics, occurrence_rows


def _render(sources, objects, model):
    root = etree.Element('{' + NS + '}premis', nsmap={'premis': NS, 'xsi': XSI}, version='3.0')
    pending, object_rows = [], []
    for obj in objects:
        row, raw = obj['row'], obj['raw']
        measured = {'byteSize': str(len(raw)), 'sha256': '0x' + sha256(raw).hexdigest(), 'keccak256': keccak256(raw)}
        derived = {'domain': 'derived_bytes', 'sourceReference': obj['bytesSource'], 'pointer': '',
            'exactHex': None, 'measurement': measured, 'qualification': 'present_offline_byte_measurement_not_native_field'}
        identity = {'domain': 'original_identity', 'sourceReference': row['original'], 'pointer': '',
            'selector': row['selector'], 'qualification': 'computed_occurrence_and_byte_role_identifier'}

        def emit(parent, name, text, proofs, rule):
            node = _element(parent, name, text)
            pending.append((node, {'occurrenceId': row['occurrenceId'], 'objectId': obj['id'],
                'targetValue': text, 'rule': RULE + rule, 'sources': proofs}))
            return node

        def native(domain, pointer): return sources.proof(row, domain, pointer)
        def digest(parent, algorithm, value, proofs, rule, algorithm_proofs):
            fixity = _element(parent, 'fixity')
            emit(fixity, 'messageDigestAlgorithm', algorithm, algorithm_proofs, rule + '-algorithm')
            emit(fixity, 'messageDigest', value[2:], proofs, rule + '-hex-without-prefix')
        node = _element(root, 'object', **{'{' + XSI + '}type': 'premis:file'})
        identifier = _element(node, 'objectIdentifier')
        emit(identifier, 'objectIdentifierType', 'URI', [identity], 'occurrence-identifier-type')
        emit(identifier, 'objectIdentifierValue', obj['id'], [identity], 'occurrence-identifier')
        role = _element(node, 'significantProperties')
        emit(role, 'significantPropertiesType', 'retained_byte_role', [identity], 'byte-role-type')
        emit(role, 'significantPropertiesValue', obj['role'], [identity], 'byte-role')
        declaration = obj['declarations']; material = obj['material']
        if declaration is not None:
            algorithm, digest_pointer, canon_pointer, schema_pointer, algorithm_pointer = declaration
            canonical = native('original', canon_pointer)
            prop = _element(node, 'significantProperties')
            emit(prop, 'significantPropertiesType', 'native_payload_canonicalization_id', [identity], 'canonicalization-type')
            emit(prop, 'significantPropertiesValue', _json(hex_bytes(canonical['exactHex'])), [canonical], 'canonicalization-id')
        chars = _element(node, 'objectCharacteristics')
        digest(chars, 'SHA-256', measured['sha256'], [derived], 'computed-sha256', [derived])
        digest(chars, 'Keccak-256', measured['keccak256'], [derived], 'computed-keccak256', [derived])
        if declaration is not None and algorithm in (1, 2):
            proof = native('original', digest_pointer); declared = _json(hex_bytes(proof['exactHex']))
            require(declared == measured['keccak256' if algorithm == 1 else 'sha256'], 'native PREMIS original payload digest differs')
            algorithm_proof = native('original', algorithm_pointer) if algorithm_pointer is not None else identity
            digest(chars, 'Keccak-256' if algorithm == 1 else 'SHA-256', declared, [proof],
                'original-payload-digest', [algorithm_proof])
        if material is not None:
            ref = material['reference']; algorithm = ref['hash']['algorithm']
            if algorithm in (1, 2, 3):
                proof = native(obj['domain'], material['pointer'] + '/hash/digest')
                if algorithm in (1, 2): expected = measured['keccak256' if algorithm == 1 else 'sha256']
                else:
                    from blake3 import blake3
                    expected = '0x' + blake3(raw).hexdigest()
                require(ref['hash']['digest'] == expected, 'native PREMIS original material digest differs')
                digest(chars, {1: 'Keccak-256', 2: 'SHA-256', 3: 'BLAKE3'}[algorithm], expected,
                    [proof], 'original-material-digest', [native(obj['domain'], material['pointer'] + '/hash/algorithm')])
        emit(chars, 'size', measured['byteSize'], [derived], 'computed-byte-size')
        fmt = _element(chars, 'format')
        if declaration is not None:
            registry = _element(fmt, 'formatRegistry'); schema = native('original', schema_pointer)
            emit(registry, 'formatRegistryName', '6529STREAM_SCHEMA_ID', [identity], 'original-schema-namespace')
            emit(registry, 'formatRegistryKey', _json(hex_bytes(schema['exactHex'])), [schema], 'original-schema-id')
        elif material is not None and material['formatPointer'] is not None:
            form = material['correspondence']['declaredFormat']; pointer = material['formatPointer']
            if form['kind'] == 'pronom':
                proof = native(obj['domain'], pointer + '/puid'); puid = form['puid']
            elif form['kind'] == 'catalog' and form['mapping']['kind'] == 'pronom':
                proof = native(obj['domain'], pointer + '/mapping/puid'); puid = form['mapping']['puid']
            else: proof = None
            if proof is not None:
                registry = _element(fmt, 'formatRegistry')
                emit(registry, 'formatRegistryName', 'PRONOM', [identity], 'declared-format-namespace')
                emit(registry, 'formatRegistryKey', puid, [proof], 'declared-pronom-key')
        if not len(fmt):
            designation = _element(fmt, 'formatDesignation')
            emit(designation, 'formatName', 'unidentified', [identity], 'unidentified-format-no-detection')
        emit(fmt, 'formatNote', 'Original schema/format declaration only; format detection is not performed.',
            [identity], 'format-qualification')
        if material is not None:
            location = _element(_element(node, 'storage'), 'contentLocation')
            uri = native(obj['domain'], material['pointer'] + '/uri')
            emit(location, 'contentLocationType', 'declared original URI; retrieval from this URI not proven', [identity], 'declared-locator-type')
            emit(location, 'contentLocationValue', material['reference']['uri'], [uri], 'declared-locator')
        object_rows.append({'id': obj['id'], 'occurrenceId': row['occurrenceId'], 'role': obj['role'],
            'domain': obj['domain'], 'referenceIndex': obj['referenceIndex'], 'bytesSource': obj['bytesSource'],
            'measured': measured, 'correspondenceSource': None if material is None else material['correspondenceSource']})
    raw = etree.tostring(root, encoding='UTF-8', xml_declaration=True)
    parsed = model.validate(raw); provenance = []
    for node, proof in pending:
        xpath = node.getroottree().getpath(node)
        actual = parsed.xpath(xpath, namespaces={'premis': NS, 'xsi': XSI})
        require(len(actual) == 1 and actual[0].text == proof['targetValue'], 'native PREMIS final XPath/value differs')
        provenance.append({**proof, 'target': {'path': OUTPUT_PREFIX + 'objects.xml', 'hash': keccak256(raw), 'xpath': xpath}})
    return raw, provenance, object_rows


def _project(files, source_hash, plan_raw, plan_hash, model_root, inventory_raw):
    """Internal finite projection; concrete original admission belongs to caller."""
    plan = _plan(plan_raw, plan_hash, source_hash); value = _json(inventory_raw)
    require(value['profileHash'] == inventory.PROFILE_HASH and value['sourceManifestHash'] == source_hash,
        'native PREMIS inventory source/profile differs')
    rows = value['occurrences']; by_id = {row['occurrenceId']: row for row in rows}
    require(len(by_id) == len(rows), 'native PREMIS duplicate original occurrence')
    for choice in plan['selected']:
        require(choice['occurrenceId'] in by_id and choice['selector'] == by_id[choice['occurrenceId']]['selector'],
            'native PREMIS exact original occurrence/selector required')
    selected = {r['occurrenceId'] for r in plan['selected']}
    sources = _Sources(files); objects, diagnostics, occurrence_rows = _objects(sources, rows, selected)
    output, proofs, object_rows = {}, [], []
    if objects:
        model = PinnedPremis(Path(model_root), XSD_PROFILE_BYTES, profile_hash=XSD_PROFILE_HASH)
        raw, proofs, object_rows = _render(sources, objects, model); output[OUTPUT_PREFIX + 'objects.xml'] = raw
    mapped = {(p['occurrenceId'], s['domain'], s['pointer']) for p in proofs for s in p['sources']
        if s['domain'] in ('original', 'payload') or s['domain'].startswith('catalog_')}
    coverage = [{**field, 'disposition': 'mapped' if (field['occurrenceId'], field['domain'], field['pointer']) in mapped
        else field['disposition'], 'rule': RULE + 'resolved-original-field' if
        (field['occurrenceId'], field['domain'], field['pointer']) in mapped else field['rule'],
        'reason': 'This exact original field contributes to a resolved PREMIS scalar.' if
        (field['occurrenceId'], field['domain'], field['pointer']) in mapped else field['reason']} for field in value['fields']]
    output[OUTPUT_PREFIX + 'inventory.json'] = dumps({'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
        'fieldInventoryHash': keccak256(inventory_raw), 'occurrences': occurrence_rows, 'objects': object_rows,
        'diagnostics': diagnostics, 'claims': CLAIMS, 'qualification': QUALIFICATION})
    output[OUTPUT_PREFIX + 'provenance.json'] = dumps({'profileHash': PROFILE_HASH, 'rows': proofs})
    output[OUTPUT_PREFIX + 'coverage.json'] = dumps({'profileHash': PROFILE_HASH, 'fields': coverage})
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash, 'planHash': plan_hash,
        'status': 'empty_selection' if not selected else 'objects_with_diagnostics' if diagnostics else 'objects',
        'originalOccurrenceCount': str(len(rows)), 'selectedOccurrenceCount': str(len(selected)),
        'objectCount': str(len(objects)), 'payloadFileCount': str(sum(o['role'] == 'original_record_payload_file' for o in objects)),
        'materialFileCount': str(sum(o['role'] == 'retained_conservation_reference_material' for o in objects)),
        'mappedNativeFieldCount': str(len(mapped)), 'diagnosticCount': str(len(diagnostics)),
        'xmlHash': keccak256(output[OUTPUT_PREFIX + 'objects.xml']) if objects else None,
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output[OUTPUT_PREFIX + 'report.json'] = dumps(report)
    require(sum(map(len, output.values())) <= MAX_OUTPUT, 'native PREMIS output byte bound')
    return Evidence(output, report)


def _derive(files, source_hash, plan_raw, plan_hash, model_root=MODEL_ROOT, *, inventory_raw=None):
    """Private: exact V4 originals have already passed their concrete verifier."""
    if inventory_raw is None: inventory_raw = inventory._extract(files, source_hash).inventory
    return _project(files, source_hash, plan_raw, plan_hash, model_root, inventory_raw)


def build(files, source_hash, plan_raw, plan_hash, *, disclosure, model_root=MODEL_ROOT):
    require(disclosure == 'public', 'native PREMIS public disclosure required before reads')
    try:
        checked = dossier.verify(dict(files), source_hash)
        return _derive(dict(checked.files), source_hash, plan_raw, plan_hash, model_root)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, etree.LxmlError) as exc:
        raise MuseumError('malformed native PREMIS source') from exc
