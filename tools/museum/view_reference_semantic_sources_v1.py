"""Source-derived file occurrences from a fully verified native VIEW envelope.

The source envelope is retained externally and addressed by exact JSON pointers.
This module never executes files, reads a ZIP member, or promotes Archive
correspondence into an ingest, preservation-performance, or scanner assertion.
"""
from copy import deepcopy
from hashlib import sha256
import re

from . import view_preservation_retrieval_v1 as retrieval
from . import view_preservation_reference_types_v1 as reference
from . import view_policy_adoption_types_v2 as adoption
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import decode
from .independent_wire import require

MAX_INPUT = retrieval.MAX_INPUT
MAX_LEAVES = 250000
SOURCE_PATH = 'source/envelope.json'
NAME = 'STREAM_MUSEUM_VIEW_REFERENCE_SEMANTIC_SOURCES_V1'
ROLES = ('environment_declaration', 'runnable_environment_zip', 'package_member',
    'os_prerequisite', 'reference_capture', 'capture_html', 'adopted_script',
    'token_data', 'token_json', 'token_html')
RELATIONS = {
    'uses_declared_environment': (('runnable_environment_zip', 'reference_capture'), ('environment_declaration',)),
    'declared_package_member': (('package_member',), ('runnable_environment_zip',)),
    'declared_platform_prerequisite': (('os_prerequisite',), ('environment_declaration',)),
    'reference_capture_of': (('reference_capture',), ('capture_html',)),
    'output_uses_adopted_script': (('token_json', 'token_html'), ('adopted_script',)),
    'output_uses_token_data': (('token_json', 'token_html'), ('token_data',)),
    'html_output_of_token': (('capture_html',), ('token_html',)),
}
CLAIMS = {'originalRetrievalEnvelopeReplayed': True, 'allRetainedReferenceOccurrencesAccounted': True,
    'completeOriginalSourceLeafInventory': True, 'receivedBytesCorrespondenceChecked': True,
    'rpcProvenanceAuthenticated': False, 'globalReferenceHistoryAuthenticated': False,
    'zipMemberPossessionInferred': False, 'verifiedArchivalClaim': False,
    'safetyScanPerformed': False, 'browserExecutionProven': False,
    'physicalProductionProven': False, 'rightsGranted': False, 'profileRegistered': False}
QUALIFICATION = ('Native originals and exact retained byte correspondence only. Received means bytes '
    'are present in this supplied envelope; it is not network delivery, verified archival status, '
    'format detection, browser performance or website safety scanning. Package and operating-system '
    'file declarations do not prove member possession. Selected, historical and capture-time source '
    'facts retain their original scopes and admitted observation provenance.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'retrievalProfileHash': retrieval.PROFILE_HASH,
    'referenceSourceRevision': reference.SOURCE_REVISION, 'sourcePath': SOURCE_PATH,
    'roles': list(ROLES), 'relations': {k: [list(x) for x in v] for k, v in RELATIONS.items()},
    'denominator': 'Every retained reference history in native order before projection; every original envelope leaf. '
        'Every saved output has separate tokenData/JSON/HTML occurrences; selected members and exact original HTML captures provide bytes.',
    'identity': 'Occurrence IDs bind source pin, native reference selector, role and exact source pointer. '
        'Shared file hashes never merge occurrences or establish derivation.',
    'bytes': 'Direct hex, canonical retained environment JSON and ABI-decoded original adopted script. '
        'External object bytes require exact object/hash/size correspondence. No ZIP extraction.',
    'limits': {'inputBytes': str(MAX_INPUT), 'leaves': str(MAX_LEAVES)},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), 'VIEW reference semantic ' + label)


def _ref(digest, pointer):
    return {'path': SOURCE_PATH, 'hash': digest, 'pointer': pointer}


def _escape(value):
    return str(value).replace('~', '~0').replace('/', '~1')


def _digest(raw):
    return {'byteLength': str(len(raw)), 'keccak256': keccak256(raw),
        'sha256': '0x' + sha256(raw).hexdigest()}


def resolve_reference(source_bytes, source):
    """Resolve against original bytes; never treat a derived report as input."""
    _closed(source, ('path', 'hash', 'pointer'), 'source reference')
    require(type(source_bytes) is bytes and len(source_bytes) <= MAX_INPUT
        and source['path'] == SOURCE_PATH and keccak256(source_bytes) == source['hash'],
        'VIEW reference semantic original source pin')
    value = loads(source_bytes, maximum=MAX_INPUT, canonical=True)
    pointer = source['pointer']
    require(type(pointer) is str and (pointer == '' or pointer.startswith('/')),
        'VIEW reference semantic JSON pointer')
    try:
        for key in pointer.split('/')[1:]:
            require(re.search(r'~(?![01])', key) is None, 'VIEW reference semantic noncanonical pointer escape')
            decoded = key.replace('~1', '/').replace('~0', '~')
            if type(value) is list:
                require(re.fullmatch(r'0|[1-9][0-9]*', decoded) is not None,
                    'VIEW reference semantic noncanonical array index')
                value = value[int(decoded)]
            else:
                value = value[decoded]
    except (KeyError, IndexError, ValueError, TypeError) as exc:
        raise MuseumError('VIEW reference semantic unresolved original pointer') from exc
    return deepcopy(value)


def _leaf_value(value):
    # Long strings remain byte-addressed; their exact original value is never
    # replaced or normalized. Short hashes/identities remain readable literals.
    if isinstance(value, str) and len(value) > 128:
        return {'retainedUtf8': _digest(value.encode('utf-8'))}
    return deepcopy(value)


def _leaves(value, digest, pointer=''):
    if type(value) is dict and value:
        return [leaf for key in sorted(value) for leaf in _leaves(value[key], digest, pointer + '/' + _escape(key))]
    if type(value) is list and value:
        return [leaf for index, item in enumerate(value) for leaf in _leaves(item, digest, pointer + '/' + str(index))]
    kind = ('null' if value is None else 'boolean' if type(value) is bool else 'integer' if type(value) is int
        else 'string' if type(value) is str else 'empty_array' if type(value) is list else 'empty_object')
    return [{'source': _ref(digest, pointer), 'valueType': kind, 'value': _leaf_value(value),
        'disposition': 'retained_stream_only'}]


def occurrence_id(selector, role, source):
    return keccak256(dumps({'profileHash': PROFILE_HASH, 'selector': selector, 'role': role, 'source': source}))


def _byte_evidence(digest, pointer, raw, derivation='hex_decode'):
    return {'source': _ref(digest, pointer), 'encoding': 'hex', 'derivation': derivation, **_digest(raw)}


def _extract(source_bytes, checked):
    """Private: the public entrypoint has already replayed this exact envelope."""
    digest = keccak256(source_bytes)
    require(checked['inputHash'] == digest, 'VIEW reference semantic checked envelope differs')
    value = loads(source_bytes, maximum=MAX_INPUT, canonical=True)
    native = value['inventory']['value']; references = native['reference']
    state, graph = value['context'], value['graph']
    material = {row['recordHash']: (index, hex_bytes(row['mediaBytes']))
        for index, row in enumerate(value['materials'])}
    received = {}
    for row in checked['media']:
        index, raw = material[row['recordHash']]
        received.setdefault(row['objectHash'], []).append((index, raw, row))
    rows, records = [], []
    for history_index, original in enumerate(references['history']):
        base = '/inventory/value/reference/history/' + str(history_index)
        publication, receipt, saved = original['publication'], original['receipt'][1], original['source']
        observation, environment = publication[1], publication[1][8]
        selected = receipt[0] == references['selectedRecordHash']
        selector = {'chainId': state['chainId'], 'core': state['core'], 'collectionId': state['collectionId'],
            'scope': deepcopy(publication[0]), 'referenceHost': graph['viewReference']['address'],
            'referenceRecordHash': receipt[0], 'historyIndex': str(history_index), 'tokenId': None, 'collectionSerial': None}
        record_id = occurrence_id(selector, 'reference_record', _ref(digest, base))
        records.append({'recordId': record_id, 'selector': deepcopy(selector), 'source': _ref(digest, base),
            'selected': selected, 'currentHead': receipt[0] == references['current'][1][0],
            'status': 'validated_original', 'authority': {'recorder': receipt[11], 'authorizationClass': receipt[12],
                'grantRevision': receipt[13], 'effectiveAt': receipt[14], 'recordedAt': receipt[15],
                'source': _ref(digest, base + '/receipt/1')},
            'recordChainHash': receipt[1], 'revision': receipt[5]})

        def add(role, pointer, values, evidence=None, token=None, serial=None):
            chosen = {**selector, 'tokenId': token, 'collectionSerial': serial}
            source = _ref(digest, pointer)
            row = {'occurrenceId': occurrence_id(chosen, role, source), 'recordId': record_id,
                'role': role, 'selector': deepcopy(chosen), 'source': source, 'values': deepcopy(values),
                'availability': 'received' if evidence is not None else 'described_only',
                'byteEvidence': evidence, 'relations': [], 'qualification': QUALIFICATION}
            rows.append(row)
            return row

        def relation(row, predicate, target, pointer):
            row['relations'].append({'predicate': predicate, 'targetOccurrenceId': target['occurrenceId'],
                'source': _ref(digest, pointer), 'qualification': 'native_declared_relationship_not_execution_or_possession'})

        def external(key, coverage):
            obj = next(row['identity'] for row in original['objects'] if row['objectHash'] == key)
            facts = {'objectHash': key, 'coverageHash': coverage[0], 'artistId': obj[0],
                'schemaId': obj[1], 'canonicalizationId': obj[2], 'keccak256': obj[3],
                'sha256': obj[4], 'byteLength': obj[6], 'formatId': obj[7],
                'formatCatalogueId': obj[8], 'formatCatalogueHash': obj[9]}
            evidence = None
            for index, raw, observed in received.get(key, []):
                if (keccak256(raw), '0x' + sha256(raw).hexdigest(), str(len(raw))) == (obj[3], obj[4], obj[6]):
                    evidence = _byte_evidence(digest, '/materials/' + str(index) + '/mediaBytes', raw)
                    break
            return facts, evidence

        env_raw = hex_bytes(original['environment'])
        env_values = loads(env_raw, maximum=reference.MAX_PAYLOAD)
        env_row = add('environment_declaration', base + '/publication/1/8', env_values,
            _byte_evidence(digest, base + '/environment', env_raw))
        facts, evidence = external(environment[0], saved[6])
        zip_row = add('runnable_environment_zip', base + '/publication/1/8/0', facts, evidence)
        relation(zip_row, 'uses_declared_environment', env_row, base + '/publication/1/8')
        for platform, index in ((False, 12), (True, 13)):
            for file_index, entry in enumerate(environment[index]):
                ptr = base + '/publication/1/8/' + str(index) + '/' + str(file_index)
                row = add('os_prerequisite' if platform else 'package_member', ptr,
                    {'path': entry[0], 'byteLength': entry[1], 'sha256': entry[2], 'index': str(file_index)})
                relation(row, 'declared_platform_prerequisite' if platform else 'declared_package_member',
                    env_row if platform else zip_row, ptr)

        bundle = original['sourceProof']['bundle']; adoption_history = bundle['adoption']
        adoption_index, adopted = next((i, row) for i, row in enumerate(adoption_history['history'])
            if row['record'][3] == adoption_history['selectedRecordHash'])
        payload_path = base + '/sourceProof/bundle/adoption/history/' + str(adoption_index) + '/declaration/viewPayload'
        payload = decode((adoption.PAYLOAD,), hex_bytes(adopted['declaration']['viewPayload']),
            maximum=adoption.MAX_PAYLOAD)[0]
        script = add('adopted_script', payload_path, {'adoptionRecordHash': adopted['record'][3],
            'viewRecordHash': adopted['record'][0][2], 'keccak256': keccak256(payload[4]),
            'byteLength': str(len(payload[4])), 'payloadField': '4'},
            _byte_evidence(digest, payload_path, payload[4], 'abi_view_payload_script_field_4'))
        outputs = bundle['output']['checkpoint']['outputs']; output_rows = {}
        for output_index, output in enumerate(outputs):
            token, serial = output[1:3]
            output_path = base + '/sourceProof/bundle/output/checkpoint/outputs/' + str(output_index)
            evidence_by_role = {name: None for name in ('token_data', 'token_json', 'token_html')}
            if selected:
                member = native['members'][output_index]
                for role, field in (('token_data', 'tokenData'), ('token_json', 'json'), ('token_html', 'html')):
                    raw = hex_bytes(member[field])
                    expected = output[6 if role == 'token_data' else 8 if role == 'token_json' else 9]
                    require(keccak256(raw) == expected, 'VIEW reference semantic member byte hash')
                    evidence_by_role[role] = _byte_evidence(digest,
                        '/inventory/value/members/' + str(output_index) + '/' + field, raw)
            else:
                for capture_index, capture in enumerate(observation[7]):
                    if capture[:2] != [token, serial]: continue
                    raw = hex_bytes(capture[5])
                    require((keccak256(raw), str(len(raw))) == (output[9], output[11]),
                        'VIEW reference semantic historical capture/output bytes')
                    evidence_by_role['token_html'] = _byte_evidence(digest,
                        base + '/publication/1/7/' + str(capture_index) + '/5', raw)
                    break
            common = {'tokenId': token, 'collectionSerial': serial, 'outputIndex': str(output_index),
                'originalLifecycle': output[3], 'originalBurned': output[4], 'outputKind': output[5]}
            data = add('token_data', output_path + '/6', {**common, 'keccak256': output[6]},
                evidence_by_role['token_data'], token, serial)
            for role, hash_index, size_index in (('token_json', 8, 10), ('token_html', 9, 11)):
                row = add(role, output_path + '/' + str(hash_index),
                    {**common, 'keccak256': output[hash_index], 'byteLength': output[size_index]},
                    evidence_by_role[role], token, serial)
                relation(row, 'output_uses_adopted_script', script, output_path)
                relation(row, 'output_uses_token_data', data, output_path)
                output_rows[(token, role)] = row
        for capture_index, capture in enumerate(observation[7]):
            ptr = base + '/publication/1/7/' + str(capture_index)
            facts, evidence = external(capture[6], saved[7][capture_index][2])
            cap = add('reference_capture', ptr, {**facts, 'tokenId': capture[0], 'collectionSerial': capture[1],
                'metadataJSONHash': capture[2], 'htmlHash': capture[3], 'htmlBytes': capture[4],
                'sourceSha256': capture[8], 'repeatCaptureSha256': deepcopy(capture[9]),
                'environmentManifestHash': capture[10], 'capturedAt': capture[11]}, evidence, capture[0], capture[1])
            html = add('capture_html', ptr + '/5', {'keccak256': capture[3], 'byteLength': capture[4],
                'tokenId': capture[0], 'collectionSerial': capture[1]},
                _byte_evidence(digest, ptr + '/5', hex_bytes(capture[5])), capture[0], capture[1])
            relation(cap, 'uses_declared_environment', env_row, ptr + '/10')
            relation(cap, 'reference_capture_of', html, ptr)
            relation(html, 'html_output_of_token', output_rows[(capture[0], 'token_html')], ptr)
    leaves = _leaves(value, digest)
    require(len(leaves) <= MAX_LEAVES, 'VIEW reference semantic leaf bound')
    result = {'profileHash': PROFILE_HASH, 'sourceHash': digest, 'sourceState': deepcopy(state),
        'sourceProvenance': checked['sourceProvenance'], 'records': records, 'rows': rows, 'leaves': leaves,
        'retainedSources': [_ref(digest, '/' + key) for key in sorted(value)],
        'claims': dict(CLAIMS), 'qualification': QUALIFICATION}
    validate_inventory(result)
    return result


def validate_inventory(value):
    """Check internal derived consistency; this does not authenticate the source."""
    _closed(value, ('profileHash', 'sourceHash', 'sourceState', 'sourceProvenance', 'records', 'rows',
        'leaves', 'retainedSources', 'claims', 'qualification'), 'inventory shape')
    require(value['profileHash'] == PROFILE_HASH and value['claims'] == CLAIMS
        and value['qualification'] == QUALIFICATION, 'VIEW reference semantic profile')
    hex_bytes(value['sourceHash'], 32)
    def ref(source):
        _closed(source, ('path', 'hash', 'pointer'), 'source pointer shape')
        require(source['path'] == SOURCE_PATH and source['hash'] == value['sourceHash']
            and type(source['pointer']) is str and source['pointer'].startswith('/'),
            'VIEW reference semantic source pointer differs')
    records = {}
    for index, row in enumerate(value['records']):
        _closed(row, ('recordId', 'selector', 'source', 'selected', 'currentHead', 'status', 'authority',
            'recordChainHash', 'revision'), 'record shape')
        ref(row['source']); selector = row['selector']
        require(selector['historyIndex'] == str(index) and row['revision'] == str(index + 1)
            and row['source']['pointer'] == '/inventory/value/reference/history/' + str(index)
            and row['recordId'] == occurrence_id(selector, 'reference_record', row['source'])
            and row['recordId'] not in records and row['status'] == 'validated_original'
            and type(row['selected']) is bool and type(row['currentHead']) is bool,
            'VIEW reference semantic record identity/order')
        records[row['recordId']] = row
    require(records and sum(row['selected'] for row in records.values()) == 1
        and sum(row['currentHead'] for row in records.values()) == 1
        and value['records'][-1]['currentHead'], 'VIEW reference semantic selected/head denominator')
    rows = {}
    for row in value['rows']:
        _closed(row, ('occurrenceId', 'recordId', 'role', 'selector', 'source', 'values', 'availability',
            'byteEvidence', 'relations', 'qualification'), 'row shape')
        ref(row['source']); require(row['recordId'] in records and row['role'] in ROLES,
            'VIEW reference semantic row role/record')
        parent = records[row['recordId']]['selector']; selector = row['selector']
        require(set(selector) == set(parent) and all(selector[k] == parent[k] for k in parent
            if k not in ('tokenId', 'collectionSerial')) and row['qualification'] == QUALIFICATION,
            'VIEW reference semantic row native scope')
        for key in ('tokenId', 'collectionSerial'):
            if selector[key] is not None: require(uint(selector[key]) > 0, 'VIEW reference semantic token identity')
        require(row['occurrenceId'] == occurrence_id(selector, row['role'], row['source'])
            and row['occurrenceId'] not in rows, 'VIEW reference semantic occurrence identity')
        evidence = row['byteEvidence']
        require(row['availability'] == ('described_only' if evidence is None else 'received'),
            'VIEW reference semantic byte state')
        if evidence is not None:
            _closed(evidence, ('source', 'encoding', 'derivation', 'byteLength', 'keccak256', 'sha256'), 'byte evidence')
            ref(evidence['source']); uint(evidence['byteLength'])
            hex_bytes(evidence['keccak256'], 32); hex_bytes(evidence['sha256'], 32)
            require(evidence['encoding'] == 'hex' and evidence['derivation'] in
                ('hex_decode', 'abi_view_payload_script_field_4'), 'VIEW reference semantic byte derivation')
            require(row['role'] not in ('package_member', 'os_prerequisite'),
                'VIEW reference semantic package membership is not byte possession')
            for field in ('byteLength', 'keccak256', 'sha256'):
                require(field not in row['values'] or row['values'][field] == evidence[field],
                    'VIEW reference semantic byte facts differ')
        rows[row['occurrenceId']] = row
    require(rows, 'VIEW reference semantic empty rows')
    for row in rows.values():
        for relation in row['relations']:
            _closed(relation, ('predicate', 'targetOccurrenceId', 'source', 'qualification'), 'relation shape')
            ref(relation['source']); target = rows.get(relation['targetOccurrenceId'])
            require(relation['predicate'] in RELATIONS and target is not None
                and target['recordId'] == row['recordId'], 'VIEW reference semantic relation target')
            origins, targets = RELATIONS[relation['predicate']]
            require(row['role'] in origins and target['role'] in targets
                and relation['qualification'] == 'native_declared_relationship_not_execution_or_possession',
                'VIEW reference semantic relation roles')
            if relation['predicate'] in ('reference_capture_of', 'output_uses_token_data', 'html_output_of_token'):
                require(row['selector']['tokenId'] == target['selector']['tokenId']
                    and row['selector']['collectionSerial'] == target['selector']['collectionSerial'],
                    'VIEW reference semantic relation token scope')
    require(type(value['leaves']) is list and 0 < len(value['leaves']) <= MAX_LEAVES,
        'VIEW reference semantic leaves bound')
    pointers = set()
    for leaf in value['leaves']:
        _closed(leaf, ('source', 'valueType', 'value', 'disposition'), 'leaf shape'); ref(leaf['source'])
        pointer = leaf['source']['pointer']
        require(pointer not in pointers and leaf['disposition'] == 'retained_stream_only'
            and leaf['valueType'] in ('null', 'boolean', 'integer', 'string', 'empty_array', 'empty_object'),
            'VIEW reference semantic leaf identity/type')
        pointers.add(pointer)
    for source in value['retainedSources']: ref(source)
    return value


def admit(source_bytes, expected_hash):
    """Pin original canonical bytes, replay the actual reader, then derive once."""
    require(type(source_bytes) is bytes and 0 < len(source_bytes) <= MAX_INPUT,
        'VIEW reference semantic input byte bound')
    require(keccak256(source_bytes) == expected_hash, 'VIEW reference semantic external input pin')
    try:
        checked = retrieval.verify(source_bytes)
        return checked, _extract(source_bytes, checked)
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed VIEW reference semantic source') from exc


def extract(source_bytes, expected_hash):
    return admit(source_bytes, expected_hash)[1]


def inventory_hash(inventory):
    validate_inventory(inventory)
    return keccak256(dumps(inventory))
