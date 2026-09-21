"""Exact native source inventory for a replayed canonical object dossier V3.

Public admission replays the concrete dossier once.  Private extraction is not
an independent source admission API.  All original rows precede any semantic
selection, and every native authority retains its own vocabulary.
"""
from copy import deepcopy

from . import canonical_object_dossier_v3 as dossier
from . import acquisition_work_condition_v1 as work_consumer
from . import work_lido_source as work_schema
from . import metadata_catalog_source as metadata
from . import institutional
from . import condition as condition_schema
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CANONICAL_SEMANTIC_SOURCES_V1'


def definition_files():
    """Exact interpretation inputs; these are not new registered documents."""
    work = work_schema.work
    definitions = (
        ('STREAM_WORK_DESCRIPTION_V1', work.canonical(work.schema()), work_schema.WORK_SCHEMA_HASH),
        ('STREAM_WORK_JSON_PROFILE_V1', work.canonical(work.profile()), work_schema.WORK_PROFILE_HASH),
        ('STREAM_WORK_FORMAT_CATALOG_V1', work.canonical(work.catalog_schema()), work_schema.CATALOG_SCHEMA_HASH),
        ('STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1', work.canonical(work.catalog_profile()), work_schema.CATALOG_PROFILE_HASH),
        ('STREAM_ACCESSION_V1', institutional.SCHEMAS['ACCESSION'], keccak256(institutional.SCHEMAS['ACCESSION'])),
        ('STREAM_DEACCESSION_V1', institutional.SCHEMAS['DEACCESSION'], keccak256(institutional.SCHEMAS['DEACCESSION'])),
        ('STREAM_MUSEUM_INSTITUTIONAL_DOCUMENTATION_PROFILE_V1', institutional.PROFILE_BYTES, institutional.PROFILE_HASH),
        ('STREAM_CONDITION_REPORT_V1', condition_schema.SCHEMA_BYTES, condition_schema.SCHEMA_HASH),
        ('STREAM_MUSEUM_CONDITION_CONSERVATION_PROFILE_V1', condition_schema.PROFILE_BYTES, condition_schema.PROFILE_HASH),
        ('RFC8785_JCS', JCS_BYTES, keccak256(JCS_BYTES)),
    )
    require(all(keccak256(raw) == expected for _, raw, expected in definitions), 'semantic source definition drift')
    return {'definitions/native-source/' + name + '.json': raw for name, raw, _ in definitions}


WORK_PATH = 'acquisition/native-work-condition/work-condition/work.json'
CONDITION_PATH = 'acquisition/native-work-condition/work-condition/condition.json'
METADATA_PATH = 'acquisition/inputs/work/metadata/snapshot.json'
EVIDENCE_PATH = 'acquisition/inputs/work/evidence.json'
OWNER_PREFIX = 'acquisition/prior/acquisition-title/'
CURRENTNESS = ('current_native_head', 'historical_native_selection', 'unselected_original',
    'explicit_original_selection', 'historical_original', 'selected_condition',
    'selected_condition_unresolved', 'other_subject')
CLAIMS = {'allRetainedFamilyRowsInventoried': True, 'allInterpretedPayloadLeavesInventoried': True,
    'nativeAuthoritiesPreserved': True, 'nativeEligibilityReexecuted': False,
    'globalHostUniverseProven': False, 'actualExaminationProven': False,
    'legalTitleProven': False, 'institutionIdentityProven': False,
    'sourceAuthenticityProven': False, 'semanticSelectionPerformed': False,
    'profileRegistered': False, 'networkFetch': False}
QUALIFICATION = ('Inventory of the complete retained WORK, owner ACCESSION/DEACCESSION and condition '
    'source families after exact canonical V3 replay. Source-local denominators are not a global host '
    'inventory. Native selected heads, explicit original accession selection and receipt-ordered '
    'condition selection remain distinct. WORK eligibility is not reexecuted. Unsupported payloads '
    'remain opaque with their original bytes. Native receipt authority does not establish Artist '
    'permissions today, legal title, institutional identity or actual examination. Conservation '
    'semantics remain a separately verified original family.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'dossierProfileHash': dossier.PROFILE_HASH,
    'workConditionProfileHash': work_consumer.PROFILE_HASH,
    'interpretationDefinitions': [{'path': path, 'hash': keccak256(raw), 'byteLength': str(len(raw))}
        for path, raw in sorted(definition_files().items())],
    'families': ['WORK', 'ACCESSION', 'DEACCESSION', 'CONDITION'],
    'rowOrder': 'Metadata WORK catalogue order, owner publication order, condition source catalogue order.',
    'occurrenceIdentity': 'Keccak256 of exact JCS profileHash/sourceManifestHash/selector/originalPointer.',
    'leafOrder': 'Rows in inventory order; original then semantic then selected catalogue; sorted object keys and unchanged array indices.',
    'leafDenominator': 'Every original scalar/null/empty container, interpreted semantic leaf and full selected catalogue occurrence leaf.',
    'currentness': list(CURRENTNESS), 'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class _SourceFiles(dict):
    """Private per-extraction cache over one copied mapping of immutable bytes."""
    def __init__(self, files):
        super().__init__(files)
        require(all(type(raw) is bytes for raw in self.values()), 'semantic source immutable bytes required')
        self._hashes, self._parsed = {}, {}

    def digest(self, path):
        if path not in self._hashes:
            self._hashes[path] = keccak256(self[path])
        return self._hashes[path]

    def parsed(self, path):
        if path not in self._parsed:
            self._parsed[path] = loads(self[path], maximum=dossier.MAX_BYTES, canonical=True)
        return self._parsed[path]


def _load(files, path):
    return files.parsed(path) if type(files) is _SourceFiles else loads(files[path], maximum=dossier.MAX_BYTES, canonical=True)


def _ref(files, path, pointer='', encoding='json'):
    require(path in files, 'semantic source original path missing')
    result = {'path': path, 'hash': files.digest(path) if type(files) is _SourceFiles else keccak256(files[path]),
        'jsonPointer': pointer, 'encoding': encoding}
    if type(files) is _SourceFiles:
        if encoding == 'bytes':
            require(pointer == '', 'semantic source byte pointer must name whole file')
        else:
            _resolve_value(files.parsed(path), pointer, encoding)
    else:
        resolve_reference(files, result)
    return result


def resolve_reference(files, reference):
    """Check and resolve a retained-file pointer without changing its bytes."""
    require(type(reference) is dict and set(reference) == {'path', 'hash', 'jsonPointer', 'encoding'},
        'semantic source closed pointer')
    raw = files[reference['path']]
    require(keccak256(raw) == reference['hash'], 'semantic source pointer file hash differs')
    pointer, encoding = reference['jsonPointer'], reference['encoding']
    require(type(pointer) is str and encoding in ('json', 'hex', 'bytes'), 'semantic source pointer type')
    if encoding == 'bytes':
        require(pointer == '', 'semantic source byte pointer must name whole file')
        return raw
    return _resolve_value(loads(raw, maximum=dossier.MAX_BYTES, canonical=True), pointer, encoding)


def _resolve_value(value, pointer, encoding):
    if pointer:
        require(pointer.startswith('/'), 'semantic source JSON pointer root')
        for part in pointer[1:].split('/'):
            require('~' not in part.replace('~0', '').replace('~1', ''), 'semantic source JSON pointer escape')
            key = part.replace('~1', '/').replace('~0', '~')
            if type(value) is list:
                require(key == '0' or key.isascii() and key.isdigit() and not key.startswith('0'),
                    'semantic source array pointer')
                value = value[int(key)]
            else:
                require(type(value) is dict, 'semantic source pointer into scalar')
                value = value[key]
    return hex_bytes(value) if encoding == 'hex' else value


def _selector(state, kind, host, original, schema, canon, source_id=None):
    return {'kind': kind, 'chainId': state['chainId'], 'core': state['core'], 'host': host,
        'recordHash': original['recordHash'], 'recordType': original['record'][0],
        'subjectId': original['record'][1], 'schemaId': schema,
        'canonicalizationId': canon, 'sourceId': source_id}


def _current(status, selected=False, basis='none', selection=None, eligibility='not_asserted'):
    require(status in CURRENTNESS, 'semantic source currentness status')
    return {'status': status, 'selected': selected, 'selectionBasis': basis,
        'selection': deepcopy(selection), 'eligibility': eligibility}


def _row(source_hash, family, selector, original, semantic, reason, currentness, pointers):
    identity = {'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
        'selector': selector, 'originalPointer': pointers['original']}
    return {'occurrenceId': keccak256(dumps(identity)), 'family': family,
        'selector': deepcopy(selector), 'original': deepcopy(original),
        'semantic': deepcopy(semantic),
        'interpretation': {'status': 'interpreted' if semantic is not None else 'opaque',
            'reason': reason if semantic is None else None},
        'authority': deepcopy(original['authority']), 'currentness': currentness,
        'pointers': pointers, 'catalog': None}


def _work(files, state, source_hash):
    value = _load(files, WORK_PATH)
    snapshot = _load(files, METADATA_PATH)
    evidence = _load(files, EVIDENCE_PATH)
    host = evidence['graph']['metadata']['address']
    originals = [r for r in snapshot['records'] if r['record'][0] == metadata.WORK]
    original_indices = {row['recordHash']: index for index, row in enumerate(snapshot['records'])}
    require(originals == value['allOriginalWorkRecords'], 'semantic WORK original denominator differs')
    histories = {}
    for lane in ('collection', 'token'):
        scope = value[lane]
        for index, row in enumerate(scope['history']):
            digest = row['original']['recordHash']
            require(digest not in histories, 'semantic WORK selected original duplicated')
            histories[digest] = (lane, index, row, scope['current'][0] == digest)
    result = []
    for original in originals:
        all_index = original_indices[original['recordHash']]
        prefix = '/records/' + str(all_index)
        original_ref = _ref(files, METADATA_PATH, prefix)
        payload_ref = _ref(files, METADATA_PATH, prefix + '/payloadHex', 'hex')
        semantic, reason, projection_ref, current_ref = None, 'uninterpreted_original', None, None
        current = _current('unselected_original', eligibility='not_reexecuted')
        saved = histories.get(original['recordHash'])
        if saved is not None:
            lane, offset, projected, selected = saved
            require(projected['original'] == original, 'semantic WORK projection original differs')
            semantic = projected['semantic']
            require(dumps(semantic) == hex_bytes(original['payloadHex']), 'semantic WORK original payload differs')
            projection_ref = _ref(files, WORK_PATH, '/' + lane + '/history/' + str(offset))
            current_ref = _ref(files, WORK_PATH, '/' + lane)
            current = _current('current_native_head' if selected else 'historical_native_selection',
                selected, 'native_work_revision', projected['selection'], 'not_reexecuted')
        else:
            # Unselected originals are part of the denominator even when their
            # payload/schema/catalogue is unsupported.  Their failure cannot
            # veto the independently validated selected original.
            record, receipt = original['record'], original['receipt']
            raw = hex_bytes(original['payloadHex'])
            if (record[4] == schema_id('STREAM_WORK_DESCRIPTION_V1')
                    and record[2][2] == schema_id('RFC8785_JCS')
                    and receipt[6] == work_schema.WORK_SCHEMA_HASH
                    and receipt[7] == work_consumer.work_native.WORK_CANON_HASH):
                try:
                    work_schema.load_work_source(raw, expected_subject_id=original['subjectId'])
                    semantic = loads(raw, maximum=32768, canonical=True)
                except (MuseumError, ValueError, TypeError, KeyError):
                    reason = 'unselected_original_schema_payload_or_catalog_unsupported'
            else:
                reason = 'unselected_original_schema_or_canonicalization_unsupported'
        selector = _selector(state, 'native_metadata_work', host, original,
            original['record'][4], original['record'][2][2])
        output = _row(source_hash, 'WORK', selector, original, semantic, reason, current,
            {'original': original_ref, 'payload': payload_ref, 'projection': projection_ref,
                'authority': _ref(files, METADATA_PATH, prefix + '/authority'), 'currentness': current_ref})
        if saved is not None and projected['catalog'] is not None:
            require(dumps(projected['catalog']) == hex_bytes(projected['catalogBytes']), 'semantic WORK catalogue bytes differ')
            output['catalog'] = {'value': deepcopy(projected['catalog']), 'bytesHex': projected['catalogBytes'],
                'source': _ref(files, WORK_PATH, '/' + lane + '/history/' + str(offset) + '/catalog'),
                'bytesSource': _ref(files, EVIDENCE_PATH, '/work/' + lane + '/history/' + str(offset) + '/catalog', 'hex'),
                'registrationAuthenticated': False}
        result.append(output)
    denominator = {'status': 'source_replayed', 'recordCount': str(len(result)),
        'lanes': deepcopy([r for r in snapshot['lanes'] if r['recordType'] == metadata.WORK]),
        'selectionScopes': {lane: deepcopy(value[lane]) for lane in ('collection', 'token')},
        'source': _ref(files, METADATA_PATH), 'selectionSource': _ref(files, WORK_PATH),
        'scopePrecedenceInferred': False, 'globalHostsComplete': False}
    return result, denominator


def _owner(files, state, source_hash):
    root = OWNER_PREFIX
    snapshot_path = root + 'sources/owner/snapshot.json'
    snapshot = _load(files, snapshot_path)
    projected_path = root + 'accession/records.json'
    projected = _load(files, projected_path)
    selected = _load(files, root + 'accession/selected.json')
    supported_types = {schema_id(name) for name in ('ACCESSION', 'DEACCESSION')}
    originals = {r['recordHash']: r for r in snapshot['records'] if r['record'][0] in supported_types}
    require(len(projected) == len(originals) and {r['recordHash'] for r in projected} == set(originals),
        'semantic owner original denominator differs')
    result = []
    for index, row in enumerate(projected):
        original = originals[row['recordHash']]
        path = root + 'records/' + row['recordHash'][2:]
        require(_load(files, path + '/original.json') == original
            and files[path + '/payload.bin'] == hex_bytes(original['record'][5]),
            'semantic owner original bytes differ')
        interpretation = row['interpretation']
        semantic = interpretation.get('value') if interpretation['status'] == 'typed_historical' else None
        if semantic is not None:
            require(institutional.validate_payload(row['family'], files[path + '/payload.bin']) == semantic,
                'semantic owner interpreted payload differs')
        chosen = row['recordHash'] == selected['recordHash']
        selector = _selector(state, 'native_owner_title', snapshot['host'], original,
            original['record'][2], original['record'][3][2])
        result.append(_row(source_hash, row['family'], selector, original, semantic,
            interpretation.get('reason', 'unsupported_original_title_schema'),
            _current('explicit_original_selection' if chosen else 'historical_original', chosen,
                'explicit_accession_record' if chosen else 'none', selected if chosen else None),
            {'original': _ref(files, path + '/original.json'),
                'payload': _ref(files, path + '/payload.bin', encoding='bytes'),
                'projection': _ref(files, projected_path, '/' + str(index)),
                'authority': _ref(files, path + '/original.json', '/authority'),
                'currentness': _ref(files, root + 'accession/selected.json')}))
    return result, {'status': 'source_replayed', 'recordCount': str(len(result)),
        'lanes': deepcopy(snapshot['lanes']), 'catalogue': deepcopy(snapshot['catalogue']),
        'source': _ref(files, snapshot_path), 'projection': _ref(files, projected_path),
        'ownershipSource': _ref(files, root + 'sources/ownership/snapshot.json'),
        'selectedOriginal': deepcopy(selected), 'canonicalLatestAccessionProven': False,
        'globalHostsComplete': False}


def _condition(files, state, source_hash):
    value = _load(files, CONDITION_PATH)
    if value['status'] == 'source_missing':
        require(value['records'] == [] and value['selections'] is None,
            'semantic missing condition source differs')
        return [], {'status': 'source_missing', 'recordCount': '0', 'source': None,
            'catalogue': None, 'lanes': None, 'selections': None, 'globalHostsComplete': False}
    path = 'acquisition/inputs/work/condition/source/snapshot.json'
    snapshot = _load(files, path)
    require(snapshot == value['source'] and len(value['records']) == len(snapshot['records']),
        'semantic condition original denominator differs')
    result = []
    for index, row in enumerate(value['records']):
        original = snapshot['records'][index]
        require(row['original'] == original, 'semantic condition original order differs')
        prefix = '/records/' + str(index)
        interpreted = row['interpretation']
        semantic = interpreted['value']
        if semantic is not None:
            require(dumps(semantic) == hex_bytes(original['payloadHex']), 'semantic condition payload differs')
        owner = original['lane'] == 'OWNER'
        record = original['record']
        selected = value['selections']['owner' if owner else 'independent']
        chosen = selected['selected'] is not None and all(selected['selected'][k] == original[k]
            for k in ('sourceId', 'host', 'recordHash'))
        status = ('selected_condition' if selected['status'] == 'present' else 'selected_condition_unresolved') if chosen else (
            'historical_original' if original['matchesToken'] else 'other_subject')
        selector = _selector(state, 'native_owner_condition' if owner else 'native_independent_condition',
            original['host'], original, record[2 if owner else 4], record[3 if owner else 2][2], original['sourceId'])
        result.append(_row(source_hash, 'CONDITION', selector, original, semantic,
            interpreted.get('reasonCode', 'unsupported_original_condition'),
            _current(status, chosen, 'receipt_ordered_condition' if chosen else 'none',
                selected['selected'] if chosen else None),
            {'original': _ref(files, path, prefix), 'payload': _ref(files, path, prefix + '/payloadHex', 'hex'),
                'projection': _ref(files, CONDITION_PATH, prefix),
                'authority': _ref(files, path, prefix + '/authority'),
                'currentness': _ref(files, CONDITION_PATH, '/selections/' + ('owner' if owner else 'independent'))}))
    return result, {'status': 'source_replayed', 'recordCount': str(len(result)),
        'source': _ref(files, path), 'catalogue': deepcopy(snapshot['catalogue']),
        'lanes': deepcopy(snapshot['lanes']), 'selections': deepcopy(snapshot['selections']),
        'globalHostsComplete': False}


def _escape(value):
    return str(value).replace('~', '~0').replace('/', '~1')


def leaves(value, occurrence_id, section, pointer=''):
    """Lossless indexed JSON leaves, including null and empty containers."""
    if type(value) is dict and value:
        return [leaf for key in sorted(value) for leaf in leaves(value[key], occurrence_id, section, pointer + '/' + _escape(key))]
    if type(value) is list and value:
        return [leaf for index, child in enumerate(value) for leaf in leaves(child, occurrence_id, section, pointer + '/' + str(index))]
    kind = ('null' if value is None else 'empty_object' if type(value) is dict else
        'empty_array' if type(value) is list else 'boolean' if type(value) is bool else
        'integer' if type(value) is int else 'string' if type(value) is str else None)
    require(kind is not None, 'semantic source unsupported JSON scalar')
    return [{'occurrenceId': occurrence_id, 'section': section, 'jsonPointer': pointer,
        'valueType': kind, 'value': deepcopy(value)}]


def field_inventory(rows):
    result = []
    for row in rows:
        result += leaves(row['original'], row['occurrenceId'], 'original')
        if row['semantic'] is not None:
            result += leaves(row['semantic'], row['occurrenceId'], 'semantic')
        if row['catalog'] is not None:
            result += leaves(row['catalog']['value'], row['occurrenceId'], 'catalog')
    return result


def _extract(files, source_hash):
    """Internal only: files must be the concrete V3 verifier's exact result."""
    files = _SourceFiles(files)
    require(files.digest('manifest.json') == source_hash, 'semantic dossier manifest pin differs')
    manifest = _load(files, 'manifest.json')
    require(manifest['profileHash'] == dossier.PROFILE_HASH and manifest['disclosure'] == 'public',
        'semantic dossier profile/disclosure differs')
    source = _load(files, dossier.DOSSIER_PATH)
    state = source['sourceState']
    rows, denominators = [], {}
    for name, function in (('work', _work), ('owner', _owner), ('condition', _condition)):
        values, denominator = function(files, state, source_hash)
        rows.extend(values); denominators[name] = denominator
    require(len({row['occurrenceId'] for row in rows}) == len(rows), 'semantic source occurrence collision')
    conservation = None
    if source['conservationFamily'] is not None:
        conservation = {'manifest': _ref(files, 'conservation/manifest.json'),
            'dossier': _ref(files, 'conservation/source/conservation/dossier.json'),
            'files': [_ref(files, path, encoding='bytes') for path in sorted(files)
                if path.startswith('conservation/conservation-semantic/')],
            'separateOriginalFamily': True}
    definitions = [_ref(files, path, encoding='bytes') for path in sorted(files)
        if path.startswith('definitions/') or path.startswith(OWNER_PREFIX + 'definitions/')
        or path.startswith('acquisition/inputs/work/condition/definitions/')
        or path.endswith('/work-condition/profile.json')]
    condition_snapshot = 'acquisition/inputs/work/condition/source/snapshot.json'
    if condition_snapshot in files:
        definitions += [_ref(files, condition_snapshot, '/documents/' + str(index) + '/payloadHex', 'hex')
            for index, _ in enumerate(_load(files, condition_snapshot)['documents'])]
    return {'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
        'sourceState': deepcopy(state), 'sourceStateHash': keccak256(dumps(state)),
        'finality': deepcopy(source['acquisitionPacket']['finality']),
        'recordHeads': deepcopy(source['originalRecordChainHeads']),
        'sourceBindings': {'observations': _ref(files, 'acquisition/source-observations.json'),
            'reconciliation': _ref(files, 'report.json', '/sourceReconciliation'),
            'work': _ref(files, EVIDENCE_PATH, '/sourceBindings')},
        'disclosure': 'public', 'definitions': definitions, 'rows': rows, 'leaves': field_inventory(rows),
        'denominators': denominators, 'conservation': conservation,
        'claims': deepcopy(CLAIMS), 'qualification': QUALIFICATION}


def inventory_hash(inventory):
    return keccak256(dumps(inventory))


def admit(files, manifest_hash):
    """Replay once; return the verified dossier and its deterministic inventory."""
    try:
        checked = dossier.verify(files, manifest_hash)
        return checked, _extract(checked.files, manifest_hash)
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed canonical semantic source inventory') from exc


def extract(files, manifest_hash):
    return admit(files, manifest_hash)[1]
