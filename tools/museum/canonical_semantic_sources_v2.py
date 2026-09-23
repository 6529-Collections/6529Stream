"""All retained OwnerRecords families beside unchanged WORK/condition sources.

Public admission replays a concrete canonical V3 dossier once. Every owner lane
and original occurrence precedes semantic selection; unsupported meanings stay
opaque. A retained fixed genesis plan supplies interpretation definitions, never
a claim of current Registry eligibility or registration execution.
"""
from copy import deepcopy

from . import canonical_semantic_sources_v1 as previous
from . import genesis_registry_plan_v1 as plans
from . import owner_catalog_source as owner_wire
from . import owner_family_semantics_v1 as meaning
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import encode
from .independent_wire import ZERO, json_values, require


NAME = 'STREAM_MUSEUM_CANONICAL_SEMANTIC_SOURCES_V2'
OWNER_PREFIX = previous.OWNER_PREFIX
CURRENTNESS = previous.CURRENTNESS
dossier = previous.dossier
CLAIMS = dict(previous.CLAIMS, completeRetainedOwnerCatalogueInventoried=True,
    nativeOwnerSpecializedStateProven=False, currentRegistryEligibilityProven=False,
    originalDefinitionCommitmentsCheckedForInterpretation=True)
QUALIFICATION = ('Complete retained WORK, OwnerRecords fixed-plus-observed-admitted type catalogue '
    'and condition occurrences from one verified canonical V3 dossier. Opaque, unsupported, future '
    'and malformed semantic payloads remain original rows. Exact receipt definition commitments '
    'select interpreted schemas from a retained fixed genesis plan. Native publication authority, '
    'per-author latest and explicit original accession selection remain distinct from current '
    'eligibility, canonical latest statement, specialized native state, statement truth, legal title '
    'and institutional authority. Provider log completeness and omitted empty admitted types retain '
    'the original source qualification. No old nineteen or forty-nine requirement is rewritten.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2', 'previousSourceProfileHash': previous.PROFILE_HASH,
    'dossierProfileHash': dossier.PROFILE_HASH, 'ownerInterpretationProfileHash': meaning.PROFILE_HASH,
    'ownerDefinitionPlanProfileHash': plans.PROFILE_HASH,
    'rowOrder': 'WORK source order, full owner snapshot record order, condition source order.',
    'occurrenceIdentity': 'Keccak256 of exact JCS profileHash/sourceManifestHash/selector/originalPointer.',
    'leafOrder': 'Every original, semantic and selected WORK catalog leaf; source order and array indices retained.',
    'ownerSelection': 'Only the unchanged explicit original ACCESSION is selected. Per-author latest is retained, not promoted.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _plan(plan_files=None, plan_hash=None):
    require((plan_files is None) == (plan_hash is None), 'semantic V2 definition plan presence/pin differs')
    if plan_files is None:
        prepared = plans.prepare()
        plan_files, plan_hash = dict(prepared.files), prepared.manifest_hash
    return plans.admit(dict(plan_files), plan_hash)


def definition_files(*, plan_files=None, plan_hash=None):
    plan = _plan(plan_files, plan_hash)
    return previous.definition_files() | {'definitions/owner-family-profile.json': meaning.PROFILE_BYTES} | {
        'definitions/owner-genesis-plan/' + path: raw for path, raw in plan.files}


def _definition_summary(plan):
    return {'profileHash': plans.PROFILE_HASH, 'manifestHash': plan.manifest_hash,
        'registrationObserved': False, 'pathBase': 'export', 'documents': [{
            'name': document.name, 'documentId': document.metadata()['documentId'],
            'hash': keccak256(document.content), 'byteLength': str(len(document.content)),
            'path': 'definitions/owner-genesis-plan/definitions/' + document.metadata()['documentId'][2:] + '.json'
        } for document in plan.documents]}


def _native(kind, value):
    if type(kind) is tuple:
        require(type(value) is list and len(value) == len(kind), 'semantic V2 owner tuple shape')
        return tuple(_native(t, v) for t, v in zip(kind, value))
    if kind == 'bytes': return hex_bytes(value)
    if kind.startswith('uint'): return uint(value, int(kind[4:]))
    if kind == 'bool': require(type(value) is bool, 'semantic V2 owner boolean shape')
    return value


def _rekey(row, source_hash):
    row = deepcopy(row)
    row['occurrenceId'] = keccak256(dumps({'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
        'selector': row['selector'], 'originalPointer': row['pointers']['original']}))
    row['ownerMeaning'] = None
    return row


def _owner(files, state, source_hash, plan):
    path = OWNER_PREFIX + 'sources/owner/snapshot.json'
    snapshot = previous._load(files, path)
    anchor_path = OWNER_PREFIX + 'sources/owner/anchor.json'
    anchor = previous._load(files, anchor_path)
    selected_path = OWNER_PREFIX + 'accession/selected.json'
    selected = previous._load(files, selected_path)
    projected = previous._load(files, OWNER_PREFIX + 'accession/records.json')
    require(all(anchor[k] == state[k] for k in ('chainId', 'core', 'tokenId', 'blockNumber', 'blockHash'))
        and snapshot['host'] == anchor['host'], 'semantic V2 owner original state differs')
    subject = subject_id('token', state['chainId'], state['core'], '0', token_id=state['tokenId'])
    require(snapshot['subjectId'] == subject, 'semantic V2 owner subject differs')
    catalogue = snapshot['catalogue']; lanes = snapshot['lanes']; originals = snapshot['records']
    require(type(catalogue) is list and len(owner_wire.FIXED_TYPES) <= len(catalogue) <= owner_wire.MAX_TYPES
        and len(lanes) == len(catalogue) and len(originals) <= owner_wire.MAX_RECORDS,
        'semantic V2 owner catalogue bound')
    types = [row['recordType'] for row in catalogue]
    require(len(set(types)) == len(types) and set(owner_wire.FIXED) <= set(types)
        and [row['recordType'] for row in lanes] == types, 'semantic V2 complete owner type denominator differs')
    by_hash, native = {}, {}
    for original in originals:
        digest = original['recordHash']
        require(digest not in by_hash and original['record'][0] in types, 'semantic V2 duplicate/uncatalogued owner original')
        record = _native(owner_wire.OWNER_RECORD, original['record'])
        receipt = _native(owner_wire.RECEIPT, original['receipt'])
        encode((owner_wire.OWNER_RECORD, owner_wire.RECEIPT), (record, receipt))
        require(json_values(record) == original['record'] and json_values(receipt) == original['receipt'],
            'semantic V2 noncanonical owner tuple')
        status = owner_wire.verify_native_wire(uint(state['chainId']), anchor['host'], state['core'],
            uint(anchor['timestamp']), digest, uint(state['tokenId']), record, receipt,
            hex_bytes(original['signatureBundleHex']))
        require(status == original['payloadCorrespondence'] and original['authority'] == {
            'mode': 'historical_native_owner_receipt', 'owner': receipt[1],
            'currentOwnerProven': False, 'legalTitleProven': False}, 'semantic V2 owner authority/correspondence differs')
        by_hash[digest] = original; native[digest] = (record, receipt)
    used = set()
    for lane in lanes:
        hashes = lane['records']; count = uint(lane['count'], 64); previous_hash = ZERO; authors = {}
        require(len(hashes) == count and len(set(hashes)) == count, 'semantic V2 owner lane count differs')
        for index, digest in enumerate(hashes):
            require(digest in native and digest not in used, 'semantic V2 missing/duplicate lane occurrence')
            record, receipt = native[digest]
            require(record[0] == lane['recordType'] and receipt[3] == index and receipt[4] == record_chain(
                state['chainId'], anchor['host'], state['tokenId'], lane['recordType'], previous_hash, digest, str(index)),
                'semantic V2 owner lane chain/index differs')
            previous_hash = receipt[4]; authors[receipt[1]] = digest; used.add(digest)
        require(lane['head'] == previous_hash and lane['state'] == ('authenticated_empty' if count == 0 else 'complete_history')
            and lane['latestByAuthor'] == [{'owner': author, 'recordHash': digest} for author, digest in sorted(authors.items())],
            'semantic V2 owner lane head/author latest differs')
    require(used == set(by_hash), 'semantic V2 owner record denominator differs')
    title = {row['recordHash']: row for row in projected}
    require(set(title) == {h for h, r in by_hash.items() if r['record'][0] in
        (schema_id('ACCESSION'), schema_id('DEACCESSION'))}, 'semantic V2 retained title denominator differs')
    definitions = meaning.definitions(dict(plan.files), plan.manifest_hash)
    meaning_state = dict(state)
    meaning_state.update(host=anchor['host'], subjectId=subject)
    annotated = meaning.annotate(meaning.interpret_all(originals, meaning_state, definitions), lanes)
    result = []
    for index, original in enumerate(originals):
        digest, record = original['recordHash'], original['record']
        interpreted = annotated['rows'][index]
        family = owner_wire.FIXED.get(record[0], 'OWNER_UNKNOWN')
        semantic = interpreted['semantic']
        if digest in title:
            prior = title[digest]['interpretation']
            if prior['status'] == 'typed_historical':
                require(semantic == prior['value'], 'semantic V2 original title interpretation differs')
        chosen = digest == selected['recordHash']
        require(not chosen or (family == 'ACCESSION' and semantic is not None), 'semantic V2 selected accession unsupported')
        prefix = '/records/' + str(index)
        selector = previous._selector(state, 'native_owner_family', anchor['host'], original, record[2], record[3][2])
        row = previous._row(source_hash, family, selector, original, semantic, interpreted['reason'],
            previous._current('explicit_original_selection' if chosen else 'historical_original', chosen,
                'explicit_accession_record' if chosen else 'none', selected if chosen else None), {
                'original': previous._ref(files, path, prefix),
                'payload': previous._ref(files, path, prefix + '/record/5', 'hex'),
                'projection': previous._ref(files, OWNER_PREFIX + 'accession/records.json', '/' + str(projected.index(title[digest])))
                    if digest in title else None,
                'authority': previous._ref(files, path, prefix + '/authority'),
                'currentness': previous._ref(files, selected_path)})
        row = _rekey(row, source_hash); row['ownerMeaning'] = interpreted
        result.append(row)
    require(sum(row['currentness']['selected'] for row in result) == 1, 'semantic V2 selected original absent')
    return result, {'status': 'source_replayed', 'recordCount': str(len(result)),
        'lanes': deepcopy(lanes), 'catalogue': deepcopy(catalogue), 'historyCoverage': deepcopy(snapshot['historyCoverage']),
        'source': previous._ref(files, path), 'anchor': previous._ref(files, anchor_path),
        'transcript': previous._ref(files, OWNER_PREFIX + 'sources/owner/transcript.json'),
        'ownershipSource': previous._ref(files, OWNER_PREFIX + 'sources/ownership/snapshot.json'),
        'selectedOriginal': deepcopy(selected), 'canonicalLatestAccessionProven': False,
        'laneAnalysis': annotated['laneAnalysis'],
        'globalHostsComplete': False}


def _extract(files, source_hash, *, plan_files=None, plan_hash=None):
    """Internal extraction only from the concrete V3 verifier's exact result."""
    plan = _plan(plan_files, plan_hash)
    result = previous._extract(files, source_hash)
    cached = previous._SourceFiles(dict(files))
    rows, owner = _owner(cached, result['sourceState'], source_hash, plan)
    old_rows = result['rows']
    # Source kind, rather than family name, keeps a second CONDITION occurrence
    # distinct when the same OwnerRecord is also in the condition source set.
    work = [_rekey(row, source_hash) for row in old_rows if row['family'] == 'WORK']
    conditions = [_rekey(row, source_hash) for row in old_rows if row['family'] == 'CONDITION']
    for condition in conditions:
        if condition['selector']['kind'] != 'native_owner_condition': continue
        aliases = [row for row in rows if all(row['selector'][key] == condition['selector'][key]
            for key in ('chainId', 'core', 'host', 'recordHash'))]
        for alias in aliases:
            require(all(alias['original'][key] == condition['original'][key]
                for key in ('record', 'receipt', 'signatureBundleHex')) and
                alias['authority']['owner'] == condition['authority']['owner'],
                'semantic V2 owner/condition native identity alias differs')
    result.update(profileHash=PROFILE_HASH, rows=work + rows + conditions,
        ownerDefinitions=_definition_summary(plan), claims=deepcopy(CLAIMS), qualification=QUALIFICATION)
    result['denominators']['owner'] = owner
    result['leaves'] = previous.field_inventory(result['rows'])
    require(len({row['occurrenceId'] for row in result['rows']}) == len(result['rows']), 'semantic V2 occurrence collision')
    return result


def admit(files, manifest_hash, *, plan_files=None, plan_hash=None):
    """One real dossier replay followed by fixed-definition deterministic extraction."""
    try:
        checked = dossier.verify(files, manifest_hash)
        return checked, _extract(checked.files, manifest_hash, plan_files=plan_files, plan_hash=plan_hash)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed canonical semantic V2 source inventory') from exc


def extract(files, manifest_hash, *, plan_files=None, plan_hash=None):
    return admit(files, manifest_hash, plan_files=plan_files, plan_hash=plan_hash)[1]


inventory_hash = previous.inventory_hash
field_inventory = previous.field_inventory
leaves = previous.leaves
resolve_reference = previous.resolve_reference
