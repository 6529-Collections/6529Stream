"""Concrete General/V4 source replay for a separate immutable authoring binding.

The unchanged authoring draft remains unbound. This adapter binds an original
token-subject occurrence, not a person, current authorization or publication.
"""
from copy import deepcopy
from dataclasses import dataclass

from . import canonical_field_inventory_v1 as inventory
from . import canonical_object_dossier_v4 as canonical_dossier
from . import canonical_semantic_sources_v1 as pointers
from . import general_semantic_dossier_v1 as general_dossier
from . import object_dossier as package
from .bagit import _paths
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from .citations import canonical_citation
from .independent_wire import require

NAME = 'STREAM_MUSEUM_SEMANTIC_AUTHORING_CURRENT_SOURCES_V2'
GENERAL = 'general_semantic_dossier'
CANONICAL = 'canonical_object_dossier_v4'
MAX_PLAN = 524288
MAX_BYTES, MAX_FILES = package.MAX_BYTES, package.MAX_FILES
CLAIMS = {'concreteSourcePackageReplayed': True, 'exactOriginalOccurrenceBound': True,
    'nativeTokenSubjectCorrespondenceChecked': True, 'originalAuthorityRetained': True,
    'sourceOriginAuthenticated': False, 'sourceAuthorCorrespondenceProven': False,
    'authorConfirmationProven': False, 'currentAuthorityProven': False,
    'tokenExistenceProven': False, 'coreTokenMembershipProven': False,
    'publicationAuthorized': False, 'networkFetch': False}
QUALIFICATION = ('This local unregistered adapter replays an exact retained General semantic dossier or '
    'canonical V4 package and selects one supported whole original token-subject occurrence. '
    'The collection remains source context and is not part of the token subject digest. '
    'Historical receipt authority, graph selection and observed currentness remain separate original facts. '
    'A record may be historical, unselected, disputed or withdrawn; this binding does not approve its claims. '
    'Other retained accounts and collection/media records are not token authority. No author identity, '
    'confirmation, current authorization, legal title, token existence or publication right is inferred. '
    'Source provenance remains caller admitted, including synthetic fixture provenance.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2', 'status': 'prospective_unregistered_local_adapter',
    'sources': {GENERAL: general_dossier.PROFILE_HASH, CANONICAL: canonical_dossier.PROFILE_HASH},
    'inventoryProfileHash': inventory.PROFILE_HASH,
    'plan': 'Exact version/kind/manifestHash/occurrenceId/selector/tokenId; General occurrenceId is null.',
    'selection': 'Whole original supported semantic row only. V4 occurrence ID and complete selector '
        'must both match the full preselection inventory. Opaque, schema-shape-only, documentary and '
        'conservation rows are retained inputs but unsupported binding targets in this version.',
    'canonicalSubject': 'Selected source chain/Core and token ID must match the original canonical '
        'token context. Each original native subject must independently match; no IRI/title join.',
    'references': 'All source/ paths are relative to the enclosing authoring package root.',
    'limits': {'planBytes': MAX_PLAN, 'files': MAX_FILES, 'aggregateBytes': MAX_BYTES},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Evidence:
    binding: dict
    report: dict


def _pin(raw, digest, maximum, label):
    require(type(raw) is bytes and 0 < len(raw) <= maximum and any(hex_bytes(digest, 32))
        and keccak256(raw) == digest, 'current authoring ' + label + ' pin/bound differs')


def _plan(raw, digest, source_hash):
    _pin(raw, digest, MAX_PLAN, 'plan')
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(type(value) is dict and set(value) == {
        'version', 'kind', 'manifestHash', 'occurrenceId', 'selector', 'tokenId'}
        and value['version'] == '2' and value['kind'] in (GENERAL, CANONICAL)
        and value['manifestHash'] == source_hash, 'current authoring closed plan differs')
    require(type(value['selector']) is dict and uint(value['tokenId']) > 0,
        'current authoring exact selector/positive canonical token required')
    if value['kind'] == GENERAL:
        require(value['occurrenceId'] is None and value['selector'].get('pointer') == '',
            'current authoring whole General record required')
    else:
        require(any(hex_bytes(value['occurrenceId'], 32)), 'current authoring occurrence ID required')
    return value


def _ref(files, path, pointer='', encoding='json'):
    return {'path': 'source/' + path, 'hash': keccak256(files[path]),
        'jsonPointer': pointer, 'encoding': encoding}


def _resolve(files, ref):
    require(ref['path'].startswith('source/'), 'current authoring reference base differs')
    return pointers.resolve_reference(files, {**ref, 'path': ref['path'][7:]})


def _general_token(original, value, state, token, expected):
    native = original['subject']
    require(type(native) is list and len(native) == 4 and native[0] == '1'
        and native[1] == state['collectionId'] and native[2] == token
        and native[3] == '0x' + '00' * 32 and original['value'][2] == expected
        and value['anchorSubject'] == {'kind': 'token', 'subjectId': expected},
        'current authoring General original is not the exact token subject')


def _general(files, plan):
    checked = general_dossier.verify(files, plan['manifestHash'])
    files = dict(checked.files)
    path = 'semantics/snapshot.json'; snapshot = loads(files[path], maximum=MAX_BYTES, canonical=True)
    found = [(i, row) for i, row in enumerate(snapshot['statements']) if row['source'] == plan['selector']]
    require(len(found) == 1, 'current authoring exact General selector absent/ambiguous')
    index, row = found[0]
    require(row['status'] == 'supported' and row['reasonCode'] is None and row['value'] is not None,
        'current authoring unsupported General original')
    state = snapshot['sourceState']; token = plan['tokenId']
    expected = subject_id('token', state['chainId'], state['core'], state['collectionId'], token_id=token)
    _general_token(row['original'], row['value'], state, token, expected)
    pointer = '/statements/' + str(index)
    record = {'family': 'GENERAL', 'selector': row['source'], 'original': row['original'],
        'payload': row['value'], 'payloadHex': row['original']['payloadHex'],
        'authority': row['authority'], 'currentness': None,
        'references': {'original': _ref(files, path, pointer + '/original'),
            'payload': _ref(files, path, pointer + '/original/payloadHex', 'hex'),
            'authority': _ref(files, path, pointer + '/authority'),
            'snapshot': _ref(files, path), 'selection': _ref(files, 'graph/selection.json')}}
    return files, state, record, loads(files['graph/selection.json'], maximum=MAX_BYTES), {
        'profileHash': None, 'hash': None, 'occurrenceCount': str(len(snapshot['statements'])),
        'source': _ref(files, path), 'completeInputRetainedByCaller': True,
        'selectedOccurrenceOnlyInBinding': True}, snapshot['provenance'], None


def _canonical(files, plan):
    checked = canonical_dossier.verify(files, plan['manifestHash'])
    files = dict(checked.files)
    result = inventory._extract(files, plan['manifestHash'])
    value = loads(result.inventory, maximum=MAX_BYTES, canonical=True)
    found = [r for r in value['occurrences'] if r['occurrenceId'] == plan['occurrenceId']]
    require(len(found) == 1 and found[0]['selector'] == plan['selector'],
        'current authoring exact canonical occurrence/selector differs')
    row = found[0]; selector = row['selector']; packet_state = value['sourceState']
    require(selector.get('chainId') == packet_state['chainId'] and selector.get('core') == packet_state['core']
        and plan['tokenId'] == packet_state['tokenId'], 'current authoring occurrence outside canonical token context')
    require(row.get('interpretation', {}).get('status') in ('interpreted', 'supported'),
        'current authoring unsupported canonical interpretation')
    domains = [d for d in row['domains'] if d['name'] == 'payload' and d['schema'] is not None]
    require(len(domains) == 1, 'current authoring exact interpreted payload missing')
    original = _resolve(files, row['original']); raw = _resolve(files, domains[0]['source'])
    require(type(raw) is bytes, 'current authoring original payload bytes required')
    payload = loads(raw, maximum=MAX_BYTES, canonical=True)
    state = packet_state; kind = selector.get('kind'); family = row['family']
    semantic_ref = None
    if family in ('GENERAL', 'ARTIST'):
        semantic_path = row['original']['path'][7:]
        snapshot = loads(files[semantic_path], maximum=MAX_BYTES, canonical=True)
        state = snapshot['sourceState']; semantic_ref = _ref(files, semantic_path)
    expected = subject_id('token', state['chainId'], state['core'], state['collectionId'], token_id=plan['tokenId'])
    require(selector['subjectId'] == expected, 'current authoring native token subject differs')
    if family == 'GENERAL':
        _general_token(original, payload, state, plan['tokenId'], expected)
    elif family == 'ARTIST' or kind == 'native_metadata_work':
        require(original['subjectKind'] == 'host_admitted_token_subject' and original['record'][1] == expected,
            'current authoring Metadata token subject required')
        if family == 'ARTIST':
            require(payload['anchorSubject'] == {'kind': 'token', 'subjectId': expected},
                'current authoring Artist semantic token subject differs')
    elif kind == 'native_owner_family':
        require(original['record'][1] == expected, 'current authoring Owner token subject differs')
    elif kind in ('native_owner_condition', 'native_independent_condition'):
        require(original['matchesToken'] is True and original['record'][1] == expected,
            'current authoring condition token subject differs')
    else:
        raise MuseumError('current authoring unsupported native occurrence family')
    record = {'family': family, 'selector': selector, 'original': original, 'payload': payload,
        'payloadHex': '0x' + raw.hex(), 'authority': row['authority'], 'currentness': row['currentness'],
        'references': {'original': row['original'], 'payload': domains[0]['source'],
            'schema': domains[0]['schema']['source'], 'semanticSnapshot': semantic_ref}}
    details = {'profileHash': inventory.PROFILE_HASH, 'hash': keccak256(result.inventory),
        'occurrenceCount': str(len(value['occurrences'])), 'fieldCount': str(len(value['fields'])),
        'source': _ref(files, 'canonical/inputs/source-inventory.json'),
        'completeInputRetainedByCaller': True, 'selectedOccurrenceOnlyInBinding': True}
    source_snapshot = loads(files[row['original']['path'][7:]], maximum=MAX_BYTES, canonical=True)
    provenance = source_snapshot.get('provenance', source_snapshot.get('mode'))
    return files, state, record, row['selection'], details, provenance, packet_state


def admit(source_files, source_hash, plan_raw, plan_hash, *, disclosure):
    """Replay the concrete original package once, then bind one token occurrence."""
    require(disclosure == 'public', 'current authoring public disclosure required before reads')
    try:
        plan = _plan(plan_raw, plan_hash, source_hash)
        require(type(source_files) is dict and 0 < len(source_files) <= MAX_FILES,
            'current authoring source file count/type bound')
        require(all(type(k) is str and type(v) is bytes for k, v in source_files.items())
            and sum(map(len, source_files.values())) <= MAX_BYTES, 'current authoring source byte bound')
        _paths(source_files)
        files = dict(source_files)
        _pin(files['manifest.json'], source_hash, package.MAX_MANIFEST, 'source manifest')
        files, state, record, selection, denominator, provenance, packet_state = (
            _general(files, plan) if plan['kind'] == GENERAL else _canonical(files, plan))
        token = plan['tokenId']; expected = subject_id('token', state['chainId'], state['core'],
            state['collectionId'], token_id=token)
        require(record['selector']['subjectId'] == expected, 'current authoring selected subject differs')
        subject = {'kind': 'token', 'subjectId': expected, 'chainId': state['chainId'], 'core': state['core'],
            'collectionId': state['collectionId'], 'tokenId': token,
            'workCitation': canonical_citation(state['chainId'], state['core'], token),
            'collectionContextInSubjectDigest': False, 'tokenExistenceProven': False, 'coreTokenMembershipProven': False}
        binding = {'profile': NAME, 'profileHash': PROFILE_HASH, 'version': '2',
            'kind': 'original_token_occurrence_binding', 'sourceKind': plan['kind'],
            'sourceManifestHash': source_hash, 'sourcePlanHash': plan_hash, 'sourcePlan': plan,
            'sourceState': state, 'sourceStateHash': keccak256(dumps(state)),
            'occurrenceId': plan['occurrenceId'], 'selector': plan['selector'], 'subject': subject,
            'originalEvidence': record, 'selection': selection, 'inventory': denominator,
            'claims': CLAIMS, 'qualification': QUALIFICATION}
        raw = dumps(binding); require(len(raw) <= MAX_BYTES, 'current authoring binding byte bound')
        report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'bindingHash': keccak256(raw),
            'sourceKind': plan['kind'], 'sourceManifestHash': source_hash, 'sourcePlanHash': plan_hash,
            'sourceState': state, 'canonicalPacketSourceState': packet_state, 'sourceProvenance': provenance,
            'subject': subject, 'workCitation': subject['workCitation'], 'family': record['family'],
            'occurrenceId': plan['occurrenceId'], 'selector': plan['selector'], 'inventory': denominator,
            'originalFiles': str(len(files)), 'originalBytes': str(sum(map(len, files.values()))),
            'claims': CLAIMS, 'qualification': QUALIFICATION}
        return Evidence(deepcopy(binding), deepcopy(report))
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed current authoring source input') from exc
