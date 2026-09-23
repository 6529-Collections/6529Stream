"""Original publication events, recorder agents and documentary RIGHTS notices.

Public entry points replay the complete V4 package. Private derivation never
turns a record type, selected notice or named licensor into performed activity,
current authority, legal permission or artwork-media correspondence.
"""
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from pathlib import Path

from jsonschema import Draft202012Validator
from lxml import etree

from . import native_premis_v1 as v1
from . import public_rights_source as rights_source
from . import metadata_rights_source as rights
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .independent_wire import RECORD, ZERO, ZERO_ADDRESS, generic_hash, require
from .native_finality_wire import from_json
from .premis import NS, XSI, _element

NAME = 'STREAM_MUSEUM_NATIVE_PREMIS_V2'
PLAN_KIND = 'native_premis'
MODEL_ROOT = v1.MODEL_ROOT
OUTPUT_PREFIX = 'premis/'
MAX_PLAN = v1.MAX_PLAN
MAX_OUTPUT = v1.MAX_OUTPUT
MAX_RIGHTS = 128
MAX_FIELDS = 65536
PRIOR = 'canonical/input/acquisition/prior/'
RIGHTS_JOIN = PRIOR + 'packet/rights-join.json'
RULE = 'urn:6529stream:museum:native-premis:v2:'
FAMILY = 'NATIVE_RIGHTS_NOTICE'
SCOPE_FAMILY = 'NATIVE_RIGHTS_SELECTION_SCOPE'
USES = ('ai_training', 'derivative', 'exhibition', 'print', 'publication', 'reproduction')
SOURCE_INVENTORY_PROFILE_BYTES = dumps({'name': 'STREAM_MUSEUM_NATIVE_PREMIS_SOURCE_INVENTORY_V2',
    'version': '2', 'sourceProfileHash': rights_source.PROFILE_HASH,
    'source': 'Exact prior packet/rights-join.json selects the already replayed PublicRightsSource snapshot; no path scan or operator replacement.',
    'denominator': 'Both complete collection/token selected-history scopes and every original record in snapshot order, before export selection. Selection absence is not historical RIGHTS absence.',
    'domains': 'retained_source contains the exact original record or scope JSON subtree. source/ references are relative to the enclosing package.',
    'fields': 'Every scalar, null and empty array/object leaf, in sorted-key/array-index traversal order, presence present; exactHex is RFC8785 encoding of the actual value. Nonempty containers are traversal only.',
    'limits': {'rightsRecords': MAX_RIGHTS, 'fields': MAX_FIELDS, 'bytes': MAX_OUTPUT},
    'sourceOriginAuthenticated': False})
SOURCE_INVENTORY_PROFILE_HASH = keccak256(SOURCE_INVENTORY_PROFILE_BYTES)
CLAIMS = {**v1.CLAIMS, 'nativeRecordPublicationEvents': True,
    'supplementalRightsSourceDenominatorPreserved': True,
    'recorderAndNamedLicensorKeptDistinct': True, 'rightsGrantedElementsEmitted': False,
    'underlyingActivityPerformanceProven': False, 'namedLicensorIdentityProven': False,
    'copyrightOwnershipProven': False, 'effectiveDateApplicabilityAssessed': False,
    'originalFieldDenominatorExpanded': False}
QUALIFICATION = (v1.QUALIFICATION + ' Events describe original native record publication only, at the '
    'receipt recordedAt rather than payload effectiveAt, selection time, examination or check time. '
    'Receipt accounts preserve their original owner, attestor or recorder roles; a relayed principal '
    'is not identified as the transaction submitter. They are not verified people or institutions. Named licensors '
    'are separate documentary Agent occurrences. RIGHTS are original notices with separate scope, '
    'history, native selection, publisher class, dates and six act/status declarations. No rightsGranted, '
    'termOfGrant, copyrightInformation or licenseInformation is emitted; neither an affirmative notice '
    'nor a native selection proves legal permission. Original scope subjects do not become media objects. '
    'The additional RIGHTS leaf inventory is separate from the unchanged canonical field inventory.')


def plan_schema():
    schema = deepcopy(v1.plan_schema())
    schema['title'] = 'STREAM_MUSEUM_NATIVE_PREMIS_PLAN_V2'
    schema['properties']['version']['const'] = '2'
    schema['required'].append('selectedRights')
    schema['properties']['selectedRights'] = deepcopy(schema['properties']['selected'])
    schema['properties']['selectedRights']['maxItems'] = MAX_RIGHTS
    return schema


PLAN_SCHEMA_BYTES = dumps(plan_schema())
PLAN_SCHEMA_HASH = keccak256(PLAN_SCHEMA_BYTES)
PROFILE_BYTES = dumps({'name': NAME, 'version': '2', 'status': 'prospective_unregistered_adapter',
    'sourceProfileHash': v1.dossier.PROFILE_HASH, 'fileAdapterProfileHash': v1.PROFILE_HASH,
    'inventoryProfileHash': v1.inventory.PROFILE_HASH,
    'supplementalSourceInventoryProfileHash': SOURCE_INVENTORY_PROFILE_HASH,
    'planSchemaHash': PLAN_SCHEMA_HASH, 'xsdValidatorProfileHash': v1.XSD_PROFILE_HASH,
    'publication': 'Finite original Owner, Metadata, Independent and General receipt layouts only; unknown shapes stay diagnostics. Native publication Event links the retained original payload file. Recorder account and original effectiveAt are separate facts.',
    'rights': 'Exact original RIGHTS schema/profile/JCS and scope/predecessor/record/publication/selection bindings. Original basis is otherRightsBasis under documentary rightsBasis other. Original dates are otherRightsApplicableDates, never termOfGrant. Six act/status clauses and conditions remain documentary notes, not rightsGranted.',
    'agents': 'Occurrence-specific IDs. Original owner authorizing account, attestor and Metadata/General recorder roles remain distinct; none implies the transaction submitter. Receipt account and declared licensor never merge, even when addresses agree; personhood, legal standing and current authority are unproven.',
    'provenance': 'V1 native domains remain unchanged. New RIGHTS proofs use retained_source and the complete supplemental source inventory. Generated labels/IDs use original_identity; computed byte measurements use derived_bytes. All output scalar pointers are resolved after final XML serialization.',
    'limits': {'planBytes': MAX_PLAN, 'rightsRecords': MAX_RIGHTS, 'objects': v1.MAX_OBJECTS,
        'supplementalFields': MAX_FIELDS, 'outputBytes': MAX_OUTPUT},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)
Evidence = v1.Evidence


def _plan(raw, digest, source_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_PLAN and any(hex_bytes(digest, 32))
        and keccak256(raw) == digest, 'native PREMIS V2 plan pin/bound differs')
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(not list(Draft202012Validator(plan_schema()).iter_errors(value))
        and value['sourceManifestHash'] == source_hash, 'native PREMIS V2 closed plan/source differs')
    for key in ('selected', 'selectedRights'):
        require(len({r['occurrenceId'] for r in value[key]}) == len(value[key]),
            'native PREMIS V2 duplicate selected occurrence')
    return value


def _leaves(value, pointer='', depth=0):
    require(depth <= 64, 'native PREMIS V2 supplemental depth bound')
    if type(value) is dict and value:
        for key in sorted(value):
            yield from _leaves(value[key], pointer + '/' + v1.inventory._escape(key), depth + 1)
    elif type(value) is list and value:
        for i, item in enumerate(value): yield from _leaves(item, pointer + '/' + str(i), depth + 1)
    else:
        yield {'pointer': pointer, 'presence': 'present', 'kind': v1.inventory._kind(value),
            'exactHex': '0x' + dumps(value).hex(), 'disposition': 'retained_stream_only',
            'rule': RULE + 'complete-original-leaf', 'reason': 'Exact original retained source leaf before selection.'}


def _relative(path):
    require(type(path) is str and path and not path.startswith(('/', '\\')) and '\\' not in path
        and all(p not in ('', '.', '..') and ':' not in p for p in path.split('/')),
        'native PREMIS V2 source path differs')
    return path


def _rights_original(original, anchor, scopes):
    """Repeat finite original correspondence, never current-role or legal checks."""
    record = from_json(RECORD, original['record']); receipt = from_json(rights.RECEIPT, original['receipt'])
    raw = hex_bytes(original['payloadHex']); cid = uint(anchor['collectionId'])
    require(record[0] == rights.RECORD_TYPE and record[4] == schema_id(rights.SCHEMA_NAME)
        and record[2] == (1, hex_bytes(keccak256(raw)), rights.JCS_ID)
        and receipt[0] == cid and receipt[1] != ZERO_ADDRESS and receipt[2] in (7, 8)
        and 0 < receipt[3] <= uint(anchor['timestamp'])
        and receipt[6:] == (rights.SCHEMA_HASH, keccak256(JCS_BYTES), ZERO),
        'native PREMIS V2 RIGHTS original authority/schema/payload differs')
    require(generic_hash(uint(anchor['chainId']), anchor['host'], anchor['core'], cid, receipt[1], record)
        == original['recordHash'], 'native PREMIS V2 RIGHTS original record hash differs')
    parsed = rights.validate_rights(raw, record[1])
    require(parsed == original['value'], 'native PREMIS V2 RIGHTS exact original value differs')
    kinds = [kind for kind, scope in scopes.items() if scope['subjectId'] == record[1]]
    require(len(kinds) == 1, 'native PREMIS V2 RIGHTS subject scope differs')
    scope = scopes[kinds[0]]
    histories = [r for r in scope['history'] if r[0] == original['recordHash']]
    require(len(histories) == 1, 'native PREMIS V2 RIGHTS original selection occurrence differs')
    selected = histories[0]
    require(selected[2] == keccak256(raw) and selected[7] == str(receipt[4])
        and uint(selected[8]) >= receipt[3] and selected[10] == receipt[1]
        and selected[11] == str(receipt[2])
        and parsed['predecessor'] == (None if selected[1] == ZERO else selected[1]),
        'native PREMIS V2 RIGHTS selected original binding differs')
    publication = original['publication']
    require(type(publication) is dict and publication['log']['address'] == anchor['host']
        and publication['recordedBlock'] == str(int(publication['log']['blockNumber'], 16)),
        'native PREMIS V2 RIGHTS publication location differs')
    return kinds[0], histories


def _source_inventory(files, source_hash):
    """Private: original files must already pass concrete V4 verification."""
    sources = v1._Sources(files); rows, fields = [], []
    output = {'profileHash': SOURCE_INVENTORY_PROFILE_HASH, 'sourceManifestHash': source_hash,
        'occurrences': rows, 'fields': fields, 'sourceReferences': [], 'status': 'not_retained',
        'sourceQualification': None}
    if RIGHTS_JOIN not in files: return output
    join = sources.load(RIGHTS_JOIN)
    path = PRIOR + _relative(join['snapshotPath'])
    require(keccak256(files[path]) == join['snapshotHash'], 'native PREMIS V2 RIGHTS snapshot pin differs')
    snapshot = sources.load(path); a = snapshot['source']
    require(snapshot['profile'] == rights_source.PROFILE and snapshot['profileHash'] == rights_source.PROFILE_HASH
        and snapshot['mode'] in ('synthetic_fixture', 'caller_admitted_rpc'), 'native PREMIS V2 original RIGHTS profile differs')
    require(len(snapshot['records']) <= MAX_RIGHTS and set(snapshot['scopes']) == {'collection', 'token'},
        'native PREMIS V2 RIGHTS denominator bound')
    output.update(status='retained', sourceQualification=snapshot.get('qualification'),
        sourceProvenance=snapshot['mode'], sourceState=a,
        sourceReferences=[sources.ref(RIGHTS_JOIN), sources.ref(path)])

    def add(family, selector, pointer, original, authority=None, currentness=None):
        ref = sources.ref(path, pointer)
        oid = keccak256(dumps({'profileHash': SOURCE_INVENTORY_PROFILE_HASH, 'sourceManifestHash': source_hash,
            'family': family, 'selector': selector, 'source': ref}))
        row = {'occurrenceId': oid, 'family': family, 'selector': selector, 'original': ref,
            'order': str(len(rows)), 'sourceState': a, 'sourceProvenance': snapshot['mode'],
            'authority': authority, 'currentness': currentness, 'selection': None,
            'domains': [{'name': 'retained_source', 'source': ref}]}
        rows.append(row)
        for leaf in _leaves(original):
            require(len(fields) < MAX_FIELDS, 'native PREMIS V2 supplemental leaf bound')
            fields.append({'occurrenceId': oid, 'domain': 'retained_source', **leaf})
        return row

    for kind in ('collection', 'token'):
        scope = snapshot['scopes'][kind]
        expected = subject_id(kind, a['chainId'], a['core'], a['collectionId'],
            token_id=a['tokenId'] if kind == 'token' else '0')
        require(scope['subjectId'] == expected, 'native PREMIS V2 RIGHTS exact subject differs')
        require(scope['status'] in ('present', 'absent') and
            ((scope['status'] == 'absent' and not scope['history'] and scope['current'][0] == ZERO)
             or (scope['status'] == 'present' and scope['history'] and scope['history'][-1] == scope['current'])),
            'native PREMIS V2 RIGHTS scope history/head differs')
        add(SCOPE_FAMILY, {'kind': 'native_rights_selection_scope', 'chainId': a['chainId'],
            'core': a['core'], 'host': a['rightsSelector'], 'collectionId': a['collectionId'],
            'scope': kind, 'subjectId': expected}, '/scopes/' + kind, scope)
    seen = set()
    for i, original in enumerate(snapshot['records']):
        require(original['recordHash'] not in seen, 'native PREMIS V2 duplicate original RIGHTS record')
        seen.add(original['recordHash']); kind, history = _rights_original(original, a, snapshot['scopes'])
        record, receipt = original['record'], original['receipt']
        selector = {'kind': 'native_rights_record', 'chainId': a['chainId'], 'core': a['core'],
            'host': a['host'], 'collectionId': a['collectionId'], 'scope': kind,
            'subjectId': record[1], 'recordHash': original['recordHash'], 'recordType': record[0],
            'schemaId': record[4], 'canonicalizationId': record[2][2], 'recordIndex': receipt[4]}
        add(FAMILY, selector, '/records/' + str(i), original,
            {'mode': 'historical_native_metadata_receipt', 'recorder': receipt[1],
                'authorizationClass': receipt[2], 'currentAuthorityReexecutedHere': False},
            {'scope': kind, 'selectedAtSource': snapshot['scopes'][kind]['current'][0] == original['recordHash'],
                'history': history, 'legalOrDateApplicabilityProven': False})
    require(seen == {r[0] for scope in snapshot['scopes'].values() for r in scope['history']},
        'native PREMIS V2 complete selected RIGHTS records differ')
    require(len(dumps(output)) <= MAX_OUTPUT, 'native PREMIS V2 supplemental inventory byte bound')
    return output


def source_inventory(files, source_hash, *, disclosure):
    require(disclosure == 'public', 'native PREMIS V2 public disclosure required before reads')
    checked = v1.dossier.verify(dict(files), source_hash)
    return _source_inventory(dict(checked.files), source_hash)


class _Sources(v1._Sources):
    def proof(self, row, domain, pointer):
        result = super().proof(row, domain, pointer)
        if row['family'] == FAMILY: result['domain'] = 'retained_source'
        return result


def _publication(row, original):
    """Finite original receipt ABI. This is publication, never payload activity."""
    receipt = original.get('receipt')
    if type(receipt) is not list: return None
    if row['family'] in ('GENERAL', 'GENERAL_ORIGINAL') and 'value' in original:
        recorder, date, authority = '/receipt/0', '/receipt/3', '/receipt/1'
        role = 'original_general_recorder_account'
    elif len(receipt) == 13 and len(original.get('record', [])) == 7:
        recorder, date, authority = '/receipt/1', '/receipt/2', '/receipt/5'
        role = 'original_owner_authorizing_account'
    elif len(receipt) in (9, 11) and len(original.get('record', [])) == 8:
        recorder, date, authority = '/receipt/1', '/receipt/3', '/receipt/2'
        role = 'original_metadata_recorder_account' if len(receipt) == 9 else 'original_attestor_account'
    else: return None
    address = v1.pointers._resolve_value(original, recorder, 'json')
    require(any(hex_bytes(address, 20)), 'native PREMIS V2 zero recorder account')
    timestamp = uint(v1.pointers._resolve_value(original, date, 'json'), 64)
    try: lexical = (datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=timestamp)).isoformat().replace('+00:00', 'Z')
    except (OverflowError, ValueError): return {'status': 'publication_date_outside_xml_calendar'}
    return {'status': 'available', 'recorderPointer': recorder, 'datePointer': date,
        'authorityPointer': authority, 'recorder': address, 'date': lexical, 'agentRole': role}


def _identifier(kind, row, role):
    return 'urn:6529stream:native-premis-v2:' + kind + ':' + keccak256(dumps(
        {'profileHash': PROFILE_HASH, 'occurrenceId': row['occurrenceId'], 'role': role}))[2:]


def _extend_xml(sources, objects, rights_rows, model):
    raw, proofs, object_rows = v1._render(sources, objects, model)
    root = etree.fromstring(raw); pending, events, agents, statements, diagnostics = [], [], [], [], []
    payloads = {o['row']['occurrenceId']: o for o in objects if o['role'] == 'original_record_payload_file'}

    def identity(row):
        return {'domain': 'original_identity', 'sourceReference': row['original'], 'pointer': '',
            'selector': row['selector'], 'qualification': 'profile_defined_occurrence_identity_or_label'}

    def emit(parent, name, value, row, evidence, rule):
        element = _element(parent, name, value)
        pending.append((element, {'occurrenceId': row['occurrenceId'], 'targetValue': value,
            'rule': RULE + rule, 'sources': evidence}))
        return element

    def ident(parent, group, value, row, role=None):
        node = _element(parent, group)
        emit(node, group + 'Type', 'URI', row, [identity(row)], 'identifier-type')
        emit(node, group + 'Value', value, row, [identity(row)], 'occurrence-identifier')
        if role is not None: emit(node, group.removesuffix('Identifier') + 'Role', role, row, [identity(row)], 'qualified-link-role')
        return node

    def native(row, pointer): return sources.proof(row, 'original', pointer)

    # First construct events. Agents/rights are appended afterward in a stable
    # original occurrence order; no grouping by account, name, URI or licensor.
    for obj in payloads.values():
        row = obj['row']; original = sources.resolve(row['original']); pub = _publication(row, original)
        if pub is None or pub['status'] != 'available':
            diagnostics.append({'occurrenceId': row['occurrenceId'], 'status': 'unsupported_publication_receipt'
                if pub is None else pub['status']}); continue
        event_id = _identifier('event', row, 'record_publication')
        agent_id = _identifier('agent', row, pub['agentRole'])
        node = _element(root, 'event'); ident(node, 'eventIdentifier', event_id, row)
        emit(node, 'eventType', 'native_record_publication', row, [identity(row)], 'publication-type')
        emit(node, 'eventDateTime', pub['date'], row, [native(row, pub['datePointer'])], 'receipt-recorded-at-utc')
        detail = _element(node, 'eventDetailInformation')
        emit(detail, 'eventDetail', 'Original source record publication only; underlying activity performance and source consensus are not proven.',
            row, [identity(row)], 'publication-qualification')
        ident(node, 'linkingAgentIdentifier', agent_id, row, pub['agentRole'])
        ident(node, 'linkingObjectIdentifier', obj['id'], row, 'published_source_payload')
        events.append({'id': event_id, 'occurrenceId': row['occurrenceId'], 'kind': 'native_record_publication',
            'recordedAtSource': pub['datePointer'], 'payloadObjectId': obj['id'], 'receiptAccountAgentId': agent_id,
            'receiptAccountRole': pub['agentRole'], 'transactionSubmitterInferred': False,
            'source': row['original'], 'authority': row['authority'], 'underlyingActivityPerformanceProven': False})
        agents.append({'id': agent_id, 'row': row, 'role': pub['agentRole'], 'name': pub['recorder'],
            'namePointer': pub['recorderPointer'], 'kind': 'account', 'eventId': event_id, 'rightsId': None,
            'authorityPointer': pub['authorityPointer']})

    for row in rights_rows:
        original = sources.resolve(row['original']); value = original['value']
        rid = _identifier('rights', row, 'documentary_notice')
        aid = _identifier('agent', row, 'declared_licensor')
        named = value['licensor']['identity']; key = {'artist': 'artistId', 'estate': 'name', 'institution': 'name', 'address': 'address'}[named['kind']]
        agents.append({'id': aid, 'row': row, 'role': 'declared_licensor', 'name': named[key],
            'namePointer': '/value/licensor/identity/' + key, 'kind': named['kind'], 'eventId': None,
            'rightsId': rid, 'authorityPointer': None})
        statements.append({'id': rid, 'occurrenceId': row['occurrenceId'], 'row': row,
            'source': row['original'], 'scope': row['selector']['scope'], 'subjectId': row['selector']['subjectId'],
            'licensorAgentId': aid, 'selectedAtSource': row['currentness']['selectedAtSource'],
            'acts': deepcopy(value['grants']), 'effectiveDates': deepcopy(value['effectiveDates']),
            'legalPermissionProven': False, 'mediaObjectLinkEstablished': False})

    for agent in agents:
        row = agent['row']; node = _element(root, 'agent'); ident(node, 'agentIdentifier', agent['id'], row)
        emit(node, 'agentName', agent['name'], row, [native(row, agent['namePointer'])], 'original-account-or-declared-licensor-name')
        emit(node, 'agentType', 'other', row, [identity(row)], 'agent-type-no-personhood-inference')
        emit(node, 'agentNote', agent['role'] + '; ' + ('original named licensor; identity, standing and permission remain unproven.'
            if agent['role'] == 'declared_licensor' else 'original receipt role, not an inferred transaction submitter or verified person/institution.'),
            row, [identity(row)], 'agent-role-qualification')
        if agent['authorityPointer'] is not None:
            proof = native(row, agent['authorityPointer'])
            emit(node, 'agentNote', 'Original receipt field ' + agent['authorityPointer'] + ': ' + dumps(loads(hex_bytes(proof['exactHex']))).decode(),
                row, [proof], 'original-authority-field-not-current-role')
        if agent['eventId'] is not None: ident(node, 'linkingEventIdentifier', agent['eventId'], row)
        if agent['rightsId'] is not None: ident(node, 'linkingRightsStatementIdentifier', agent['rightsId'], row)

    for statement in statements:
        row = statement['row']; value = sources.resolve(row['original'])['value']
        node = _element(_element(root, 'rights'), 'rightsStatement')
        ident(node, 'rightsStatementIdentifier', statement['id'], row)
        emit(node, 'rightsBasis', 'other', row, [identity(row)], 'documentary-rights-basis')
        info = _element(node, 'otherRightsInformation')
        emit(info, 'otherRightsBasis', value['basis'], row, [native(row, '/value/basis')], 'original-declared-basis')
        dates = _element(info, 'otherRightsApplicableDates')
        emit(dates, 'startDate', value['effectiveDates']['start'], row, [native(row, '/value/effectiveDates/start')], 'declared-start-date-not-grant-term')
        if value['effectiveDates']['end'] is not None:
            emit(dates, 'endDate', value['effectiveDates']['end'], row, [native(row, '/value/effectiveDates/end')], 'declared-end-date-not-grant-term')
        emit(info, 'otherRightsNote', QUALIFICATION, row, [identity(row)], 'documentary-rights-qualification')
        emit(info, 'otherRightsNote', 'Original subject ID: ' + value['subjectId'], row,
            [native(row, '/value/subjectId')], 'original-scope-subject-not-media-link')
        for use in USES:
            clause = value['grants'][use]; base = '/value/grants/' + use
            emit(info, 'otherRightsNote', use + ' original status: ' + clause['status'], row,
                [native(row, base + '/status')], 'original-' + use + '-status-not-permission')
            conditions = clause['conditions']
            if conditions is not None:
                for leaf in _leaves(conditions):
                    pointer = base + '/conditions' + leaf['pointer']; actual = loads(hex_bytes(leaf['exactHex']))
                    emit(info, 'otherRightsNote', use + ' condition ' + leaf['pointer'] + ': ' + dumps(actual).decode(),
                        row, [native(row, pointer)], 'original-condition-field-documentary')
            if clause['extension']:
                emit(info, 'otherRightsNote', use + ' original extension: ' + clause['extension'], row,
                    [native(row, base + '/extension')], 'original-extension-documentary')
        if value['instrument'] is not None:
            for leaf in _leaves(value['instrument']):
                pointer = '/value/instrument' + leaf['pointer']; actual = loads(hex_bytes(leaf['exactHex']))
                emit(info, 'otherRightsNote', 'Original instrument ' + leaf['pointer'] + ': ' + dumps(actual).decode(),
                    row, [native(row, pointer)], 'original-instrument-reference-not-bytes')
        ident(node, 'linkingAgentIdentifier', statement['licensorAgentId'], row, 'declared_licensor_not_authenticated_rights_holder')

    final = etree.tostring(root, encoding='UTF-8', xml_declaration=True)
    parsed = model.validate(final); digest = keccak256(final)
    for proof in proofs:
        proof['target']['hash'] = digest
        actual = parsed.xpath(proof['target']['xpath'], namespaces={'premis': NS, 'xsi': XSI})
        require(len(actual) == 1 and actual[0].text == proof['targetValue'], 'native PREMIS V2 inherited final XPath differs')
    for node, proof in pending:
        xpath = node.getroottree().getpath(node)
        actual = parsed.xpath(xpath, namespaces={'premis': NS, 'xsi': XSI})
        require(len(actual) == 1 and actual[0].text == proof['targetValue'], 'native PREMIS V2 final XPath differs')
        proofs.append({**proof, 'target': {'path': OUTPUT_PREFIX + 'objects.xml', 'hash': digest, 'xpath': xpath}})
    return final, proofs, object_rows, events, [{k: v for k, v in a.items() if k != 'row'} for a in agents], \
        [{k: v for k, v in s.items() if k != 'row'} for s in statements], diagnostics


def _derive(files, source_hash, plan_raw, plan_hash, model_root=MODEL_ROOT, *, inventory_raw=None):
    """Private derivation from concrete verified V4 originals, no second replay."""
    plan = _plan(plan_raw, plan_hash, source_hash)
    if inventory_raw is None: inventory_raw = v1.inventory._extract(files, source_hash).inventory
    inventory = v1._json(inventory_raw)
    require(inventory['profileHash'] == v1.inventory.PROFILE_HASH and inventory['sourceManifestHash'] == source_hash,
        'native PREMIS V2 original field inventory differs')
    supplemental = _source_inventory(files, source_hash)
    rows = deepcopy(inventory['occurrences']); originals = {r['occurrenceId']: r for r in rows}
    notices = {r['occurrenceId']: r for r in supplemental['occurrences'] if r['family'] == FAMILY}
    require(len(originals) == len(rows), 'native PREMIS V2 duplicate original occurrence')
    for key, candidates in (('selected', originals), ('selectedRights', notices)):
        for choice in plan[key]:
            require(choice['occurrenceId'] in candidates and candidates[choice['occurrenceId']]['selector'] == choice['selector'],
                'native PREMIS V2 exact original occurrence/selector required')
    selected_rights = []
    wanted_rights = {r['occurrenceId'] for r in plan['selectedRights']}
    for original in notices.values():
        row = deepcopy(original)
        # Internal alias for the unchanged V1 file formatter; every resulting
        # native proof is converted back to the actual retained_source domain.
        row['domains'].append({'name': 'original', 'source': row['original']})
        rows.append(row)
        if row['occurrenceId'] in wanted_rights: selected_rights.append(row)
    selected = {r['occurrenceId'] for r in plan['selected']} | wanted_rights
    sources = _Sources(files); objects, diagnostics, occurrences = v1._objects(sources, rows, selected)
    output, proofs, object_rows, events, agents, statements = {}, [], [], [], [], []
    if objects:
        model = v1.PinnedPremis(Path(model_root), v1.XSD_PROFILE_BYTES, profile_hash=v1.XSD_PROFILE_HASH)
        raw, proofs, object_rows, events, agents, statements, extra = _extend_xml(sources, objects, selected_rights, model)
        output[OUTPUT_PREFIX + 'objects.xml'] = raw; diagnostics += extra
    mapped = {(p['occurrenceId'], s['domain'], s['pointer']) for p in proofs for s in p['sources']
        if s['domain'] not in ('original_identity', 'derived_bytes', 'operator_context')}

    def coverage(fields):
        return [{**f, 'disposition': 'mapped' if (f['occurrenceId'], f['domain'], f['pointer']) in mapped else f['disposition'],
            'rule': RULE + 'resolved-original-field' if (f['occurrenceId'], f['domain'], f['pointer']) in mapped else f['rule'],
            'reason': 'Exact original field contributes to a resolved PREMIS scalar.' if
                (f['occurrenceId'], f['domain'], f['pointer']) in mapped else f['reason']} for f in fields]

    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash, 'planHash': plan_hash,
        'status': 'empty_selection' if not selected else 'records_with_diagnostics' if diagnostics else 'records',
        'originalOccurrenceCount': str(len(inventory['occurrences'])), 'selectedOccurrenceCount': str(len(plan['selected'])),
        'rightsSourceStatus': supplemental['status'], 'rightsOriginalCount': str(len(notices)),
        'selectedRightsCount': str(len(selected_rights)), 'eventCount': str(len(events)), 'agentCount': str(len(agents)),
        'rightsStatementCount': str(len(statements)), 'objectCount': str(len(objects)),
        'diagnosticCount': str(len(diagnostics)), 'claims': CLAIMS, 'qualification': QUALIFICATION}
    output.update({OUTPUT_PREFIX + 'inventory.json': dumps({'profileHash': PROFILE_HASH,
        'sourceManifestHash': source_hash, 'fieldInventoryHash': keccak256(inventory_raw),
        'occurrences': occurrences, 'objects': object_rows, 'events': events, 'agents': agents,
        'rightsStatements': statements, 'diagnostics': diagnostics, 'claims': CLAIMS, 'qualification': QUALIFICATION}),
        OUTPUT_PREFIX + 'supplemental-source-inventory.json': dumps(supplemental),
        OUTPUT_PREFIX + 'supplemental-source-profile.json': SOURCE_INVENTORY_PROFILE_BYTES,
        OUTPUT_PREFIX + 'provenance.json': dumps({'profileHash': PROFILE_HASH, 'rows': proofs}),
        OUTPUT_PREFIX + 'coverage.json': dumps({'profileHash': PROFILE_HASH, 'fields': coverage(inventory['fields']),
            'supplementalFields': coverage(supplemental['fields'])}), OUTPUT_PREFIX + 'report.json': dumps(report)})
    require(sum(map(len, output.values())) <= MAX_OUTPUT, 'native PREMIS V2 output byte bound')
    return Evidence(output, report)


def build(files, source_hash, plan_raw, plan_hash, *, disclosure, model_root=MODEL_ROOT):
    require(disclosure == 'public', 'native PREMIS V2 public disclosure required before reads')
    try:
        checked = v1.dossier.verify(dict(files), source_hash)
        return _derive(dict(checked.files), source_hash, plan_raw, plan_hash, model_root)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, OSError, UnicodeError, etree.LxmlError) as exc:
        raise MuseumError('malformed native PREMIS V2 source') from exc
