"""Qualified physical-transfer meanings from an already replayed General dossier.

The package caller authenticates neither institutions nor physical events: it
replays the frozen source before calling these pure interpretation functions.
"""
import re

from . import general_semantic_dossier_v1 as general_dossier
from .attribution_dossier import MAX_GENERAL_V2_RESOURCE
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .general_semantic_source_v1 import PROFILE_HASH as SOURCE_PROFILE_HASH
from .independent_wire import require
from .metadata_catalog_source import PROFILE_HASH as METADATA_PROFILE_HASH
from .native_attribution_semantics import selector as metadata_selector
from .owner_notice_dossier import leaves
from .preservation_graph import CONTEXT, VALIDATION_HASH
from .recorded_semantic import resolve_pointer

NAME = 'STREAM_MUSEUM_RECORDED_PHYSICAL_TRANSFER_V1'
MODE = 'recorded_physical_transfer'
RELATION = 'urn:6529stream:museum:physical-transfer:v1'
RULE = RELATION + ':original-general-statement'
DATATYPE = RELATION + ':body'
MAX_BODY = 16384
STATUSES = ('planned', 'completed', 'cancelled', 'unknown')
KINDS = {'physical_acquisition': 'Acquisition',
         'physical_custody_transfer': 'TransferOfCustody'}
BODY_KEYS = {'version', 'kind', 'status', 'physicalObject', 'transferEvent',
             'activity', 'fromParty', 'toParty', 'instrumentEvidence'}
CLAIMS = {
    'exactOriginalDeclarationBindingsChecked': True,
    'exactOriginalDocumentaryOccurrenceChecked': True,
    'exactReceivedDocumentaryBytesChecked': True,
    'historicalGeneralAuthorityRetained': True,
    'sourceReplayPerformedByPureInterpreter': False,
    'sourceOriginAuthenticated': False, 'consensusProof': False,
    'currentAuthorityGranted': False, 'signatureCurrentlyRevalidated': False,
    'namedInstitutionIdentityProven': False, 'institutionalStandingProven': False,
    'independentHumanReviewProven': False, 'instrumentValidityProven': False,
    'physicalExistenceProven': False, 'historicalPerformanceProven': False,
    'historicalEventTimeProven': False, 'physicalCustodyProven': False,
    'legalTitleProven': False, 'currentHolderProven': False,
    'museumAccessionProven': False, 'institutionalAcceptance': False,
    'rightsGranted': False, 'exportProfileRegistered': False,
    'networkFetch': False, 'fullMuseumConformance': False,
}
QUALIFICATION = (
    'Explicit original General account statement about a physical acquisition '
    'or custody transfer, with exact original declaration occurrences and '
    'earlier received Metadata documentary bytes. SIGNER_VERIFIED retains the '
    'historical account claim; OPERATOR_ASSERTED retains the configured writer '
    'and grant, not the separately asserted attester or DID. Declared parties '
    'are source descriptions, never identities inferred from the recorder, '
    'token owner, institution name or account address. A completed statement '
    'permits a qualified event projection, not proof of physical performance, '
    'legal title, current custody, institutional standing, instrument validity '
    'or museum accession. Documentary bytes may contain further references; '
    'their external targets are not thereby received or verified. Receipt time '
    'and statement dates are not event time. Source replay is the containing '
    'package verifier\'s responsibility; these pure functions do not '
    'authenticate a supplied inventory or its provider.')
PROFILE_BYTES = dumps({
    'name': NAME, 'version': '1', 'mode': MODE,
    'status': 'prospective_unregistered_export_profile',
    'sourceDossierProfileHash': general_dossier.PROFILE_HASH,
    'sourceProfileHash': SOURCE_PROFILE_HASH,
    'validationPolicyHash': VALIDATION_HASH,
    'body': {'relation': RELATION, 'mappingRule': RULE, 'datatype': DATATYPE,
        'keys': sorted(BODY_KEYS), 'version': '1', 'kinds': sorted(KINDS),
        'statuses': list(STATUSES), 'maximumBytes': str(MAX_BODY),
        'declarationKeys': ['id', 'pointer', 'hash'],
        'instrumentEvidenceKeys': ['evidenceIndex', 'sourceRecord']},
    'resourceBytes': str(MAX_GENERAL_V2_RESOURCE),
    'selection': 'Only the original General dossier selected direct statements '
        'are candidates. Disputed, withdrawn, mapping, unsupported and unselected '
        'occurrences remain retained with their original selection dispositions.',
    'declarations': 'Physical object, transfer event and enclosing Activity '
        'are distinct explicit entities in the same original General payload. '
        'Each pin checks original IRI, exact /entities/N pointer, declared kind '
        'and Keccak256 of the canonical original entity. Parties are null or '
        'explicit person/group declarations; no inferred counterparties.',
    'instrument': 'A canonical evidence index selects this assertion\'s '
        'documentary evidence, and an exact top-level Metadata source selector '
        'selects one original occurrence. Its pointer is empty or equals the '
        'evidence pointer. Original complete payload hash/canonicalization and '
        'selected bytes are checked separately from entity hashes. Whole '
        'document selectors are empty; JSON pointers resolve the exact '
        'received payload. No URI fetching or reference-target substitution.',
    'chronology': 'The original Metadata receipt timestamp must strictly '
        'precede the original General receipt timestamp. No cross-host '
        'transaction order or event-time inference.',
    'identityAndConflicts': 'Different selected declaration occurrences cannot '
        'merge through an IRI. Conflicting selected statements about one '
        'transfer event are withheld. Multiple distinct transfer events for '
        'one physical object remain valid. Identical statements using the same '
        'original declarations may aggregate their evidence and source occurrences. '
        'Among otherwise projected completed statements, edges inside a directed '
        'Activity-to-transfer-event containment cycle are withheld with their '
        'originals retained. Acyclic nesting is allowed. Noncompleted or already '
        'withheld statements do not introduce containment-cycle vetoes.',
    'projection': 'Separate HumanMadeObject and explicit Activity roots with '
        'embedded Acquisition or TransferOfCustody in part. The original body '
        'expressly supplies this containment. The pinned model forbids id on '
        'the embedded specialized event, so its exact original source IRI and '
        'declaration pin remain in embeddedEvents at /part/N. Optional parties '
        'are exact declared Person/Group references, never separate inferred '
        'agents. Required Activity classification is a qualified profile-local '
        'Type from body.kind. No duplicated HMO ownership property, generated '
        'Activity identity, instrument-as-used-object, token-transfer inference, '
        'dates, institutional acceptance or current holder. Part order follows '
        'first retained statement occurrence, not inferred event chronology.',
    'coverage': 'Every supplied original semantic statement leaf and interpreted '
        'literal body leaf is retained. The containing package replays the '
        'complete original General and Metadata denominator and every derived byte.',
    'claims': CLAIMS, 'qualification': QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _declaration(pin, original, source, kinds):
    require(type(pin) is dict and set(pin) == {'id', 'pointer', 'hash'}
        and type(pin['pointer']) is str
        and re.fullmatch(r'/entities/(0|[1-9][0-9]*)', pin['pointer']),
        'physical transfer exact local declaration pin required')
    index = uint(pin['pointer'].rsplit('/', 1)[1], 64)
    entities = original['value']['entities']
    require(index < len(entities), 'physical transfer declaration absent')
    entity = entities[index]
    require(entity['id'] == pin['id'] and entity['kind'] in kinds
        and any(hex_bytes(pin['hash'], 32))
        and keccak256(dumps(entity)) == pin['hash'],
        'physical transfer declaration identity/kind/hash differs')
    require(sum(row['id'] == entity['id'] for row in entities) == 1,
        'physical transfer ambiguous local declaration IRI')
    return {'source': {**source, 'pointer': pin['pointer']},
            'hash': pin['hash'], 'value': entity}


def _instrument(pin, assertion, original, metadata, originals):
    require(type(pin) is dict and set(pin) == {'evidenceIndex', 'sourceRecord'}
        and type(pin['evidenceIndex']) is str,
        'physical transfer closed instrument evidence pin differs')
    index = uint(pin['evidenceIndex'], 64)
    require(index < len(assertion['evidence']), 'physical transfer evidence index absent')
    evidence = assertion['evidence'][index]
    source = pin['sourceRecord']
    require(source in original['value']['sourceRecords'],
        'physical transfer instrument is not a top-level original source record')
    previous = originals.get(source['recordHash'])
    require(previous is not None and source == metadata_selector(
        previous, metadata['host'], source['pointer']),
        'physical transfer instrument original selector differs')
    payload = hex_bytes(previous['payloadHex'])
    require(0 < len(payload) <= 8192, 'physical transfer documentary payload bound')
    digest = keccak256(payload)
    require(evidence['basis'] == 'documentary_evidence'
        and evidence['source'] == {'algorithm': '1', 'digest': digest,
            'canonicalizationId': previous['record'][2][2]},
        'physical transfer instrument original payload commitment differs')
    require(evidence['selectorType'] in ('whole_document', 'json_pointer')
        and (evidence['selectorType'] != 'whole_document' or evidence['selector'] == '')
        and source['pointer'] in ('', evidence['selector']),
        'physical transfer documentary scope differs')
    # The two pointers are independent original values; neither is rewritten.
    resolve_pointer(payload, source['pointer'])
    selected = resolve_pointer(payload, evidence['selector'])
    require(uint(previous['receipt'][3], 64)
        < uint(original['original']['receipt'][3], 64),
        'physical transfer instrument must strictly precede General publication')
    return {'source': source, 'evidenceIndex': pin['evidenceIndex'], 'evidence': evidence,
        'original': previous, 'payloadHash': digest, 'payloadByteLength': str(len(payload)),
        'selectedBytesHex': '0x' + selected.hex(), 'selectedBytesHash': keccak256(selected),
        'selectedByteLength': str(len(selected)),
        'selectedEncoding': 'original_payload_bytes' if evidence['selector'] == '' else 'canonical_json_value',
        'legalValidityProven': False, 'externalReferenceTargetsReceived': False}


def _body(assertion, original, source, metadata, originals):
    literal = assertion['object'].get('literal')
    if (assertion['mappingRule'] != RULE or type(literal) is not dict
            or literal['datatype'] != DATATYPE
            or any(literal[key] is not None for key in ('language', 'unit', 'precision'))):
        return None
    body = loads(literal['lexicalValue'].encode('utf-8'), maximum=MAX_BODY, canonical=True)
    require(type(body) is dict and set(body) == BODY_KEYS
        and body['version'] == '1' and body['kind'] in KINDS
        and body['status'] in STATUSES, 'physical transfer closed literal body differs')
    declarations = {key: _declaration(body[key], original, source, (kind,))
        for key, kind in (('physicalObject', 'physical_object'),
            ('transferEvent', 'event'), ('activity', 'event'))}
    for role in ('fromParty', 'toParty'):
        declarations[role] = (None if body[role] is None else
            _declaration(body[role], original, source, ('person', 'group')))
    ids = [body[key]['id'] for key in ('physicalObject', 'transferEvent', 'activity')]
    require(len(set(ids)) == 3 and assertion['subject'] == ids[0],
        'physical transfer object/event/activity identity differs')
    for role in ('fromParty', 'toParty'):
        if declarations[role] is not None:
            require(body[role]['id'] not in ids, 'physical transfer party kind identity collision')
    return body, declarations, _instrument(body['instrumentEvidence'], assertion,
        original, metadata, originals)


def _derive(snapshot, selection, metadata):
    require(snapshot['profileHash'] == SOURCE_PROFILE_HASH
        and metadata['profileHash'] == METADATA_PROFILE_HASH
        and snapshot['metadataHost'] == metadata['host']
        and snapshot['metadataSourceHash'] == keccak256(dumps(metadata))
        and all(snapshot['sourceState'][key] == value for key, value in metadata['sourceState'].items()),
        'physical transfer original Metadata source binding differs')
    require(general_dossier.select(snapshot, dumps(selection['policy']),
        selection['selectionHash']) == selection,
        'physical transfer original General selection differs')
    originals = {row['recordHash']: row for row in metadata['records']}
    require(len(originals) == len(metadata['records']), 'physical transfer duplicate Metadata occurrence')
    chosen = {dumps(row['source']): row for row in selection['selected']}
    withheld = {dumps(row['source']): row for row in selection['withheld']}
    rows, coverage = [], []
    for original in snapshot['statements']:
        coverage.extend({'source': original['source'], 'pointer': pointer, 'value': value,
            'pointerBase': 'semantics/snapshot.json statement', 'disposition': 'retained_original'}
            for pointer, value in leaves(original))
        if original['status'] != 'supported':
            rows.append({'source': original['source'], 'original': original,
                'disposition': 'unsupported_original', 'body': None, 'declarations': None,
                'instrumentEvidence': None, 'reasons': []})
            continue
        for index, assertion in enumerate(original['value']['assertions']):
            source = {**original['source'], 'pointer': '/assertions/' + str(index)}
            key = dumps(source); selected = chosen.get(key)
            row = {'source': source, 'assertion': assertion,
                'anchorSubject': original['value']['anchorSubject'],
                'originalProfileHash': original['value']['profileHash'],
                'authority': original['authority'], 'evidence': assertion['evidence'],
                'selection': selected or withheld.get(key), 'disposition': 'unselected',
                'reasons': [], 'body': None, 'declarations': None, 'instrumentEvidence': None}
            rows.append(row)
            if selected is None:
                if key in withheld:
                    row.update(disposition='source_selection_withheld', reasons=withheld[key]['reasons'])
                continue
            if assertion['relation'] != RELATION:
                row['disposition'] = 'unsupported_relation'
                continue
            parsed = _body(assertion, original, source, metadata, originals)
            if parsed is None:
                row['disposition'] = 'unsupported_literal_convention'
                continue
            body, declarations, instrument = parsed
            row.update(body=body, bodyHash=keccak256(dumps(body)), declarations=declarations,
                instrumentEvidence=instrument, disposition='candidate')
            coverage.extend({'source': source, 'pointer': pointer, 'value': value,
                'pointerBase': 'original assertion object.literal.lexicalValue parsed as JCS',
                'disposition': 'retained_original_literal_body'} for pointer, value in leaves(body))
    candidates = [row for row in rows if row['disposition'] == 'candidate']
    identities, events = {}, {}
    for row in candidates:
        for declaration in row['declarations'].values():
            if declaration is None:
                continue
            identity = declaration['value']['id']
            signature = dumps({'source': declaration['source'], 'hash': declaration['hash'],
                'kind': declaration['value']['kind']})
            identities.setdefault(identity, set()).add(signature)
        # Documentary corroboration may differ without changing the event claim.
        event_claim = dumps({'kind': row['body']['kind'], 'status': row['body']['status'],
            'declarations': row['declarations']})
        events.setdefault(row['body']['transferEvent']['id'], set()).add(event_claim)
    for row in candidates:
        if any(len(identities[declaration['value']['id']]) != 1
               for declaration in row['declarations'].values() if declaration is not None):
            row['reasons'].append('selected_declaration_identity_collision')
        if len(events[row['body']['transferEvent']['id']]) != 1:
            row['reasons'].append('conflicting_selected_transfer_statements')
        row['disposition'] = ('conflict_withheld' if row['reasons'] else
            'completed_transfer' if row['body']['status'] == 'completed'
            else 'retained_' + row['body']['status'])
    _withhold_cycles(candidates)
    return rows, coverage


def _withhold_cycles(rows):
    """Withhold exactly projected edges inside a strongly connected component.

    Iterative traversal keeps stack use bounded by the admitted selection; it
    does not forbid one original event declaration from taking nested roles.
    """
    completed = [row for row in rows if row['disposition'] == 'completed_transfer']
    edges, reverse = {}, {}
    for row in completed:
        parent, child = (row['body'][key]['id'] for key in ('activity', 'transferEvent'))
        edges.setdefault(parent, set()).add(child)
        edges.setdefault(child, set())
        reverse.setdefault(child, set()).add(parent)
        reverse.setdefault(parent, set())
    visited, order = set(), []
    for start in sorted(edges):
        stack = [(start, False)]
        while stack:
            node, expanded = stack.pop()
            if expanded:
                order.append(node)
            elif node not in visited:
                visited.add(node)
                stack.append((node, True))
                stack.extend((child, False) for child in sorted(edges[node], reverse=True)
                    if child not in visited)
    components, sizes = {}, {}
    for start in reversed(order):
        if start in components:
            continue
        identity = len(sizes)
        sizes[identity] = 0
        stack = [start]
        while stack:
            node = stack.pop()
            if node in components:
                continue
            components[node] = identity
            sizes[identity] += 1
            stack.extend(reverse[node])
    for row in completed:
        parent, child = (row['body'][key]['id'] for key in ('activity', 'transferEvent'))
        if components[parent] == components[child] and (sizes[components[parent]] > 1 or parent == child):
            row['reasons'].append('cyclic_selected_activity_containment')
            row['disposition'] = 'conflict_withheld'


def derive(snapshot, selection, metadata_snapshot):
    """Pure derivation; caller must first replay the complete General dossier."""
    try:
        return _derive(snapshot, selection, metadata_snapshot)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed physical transfer semantic input') from exc


def _label(declaration, fallback):
    names = declaration['value']['names']
    preferred = [name for name in names if name['kind'] == 'preferred' and name['value']]
    nonempty = [name for name in names if name['value']]
    return (preferred or nonempty)[0]['value'] if preferred or nonempty else fallback


def _provenance(row):
    instrument = row['instrumentEvidence']
    return {'source': row['source'], 'assertionHash': keccak256(dumps(row['assertion'])),
        'bodyHash': row['bodyHash'], 'authority': row['authority'],
        'declarations': {key: None if declaration is None else {
            'source': declaration['source'], 'hash': declaration['hash']}
            for key, declaration in row['declarations'].items()},
        'instrumentEvidence': {key: instrument[key] for key in (
            'source', 'evidenceIndex', 'evidence', 'payloadHash', 'payloadByteLength',
            'selectedBytesHash', 'selectedByteLength', 'selectedEncoding')},
        'qualification': QUALIFICATION}


def _graph(rows, model):
    completed = [row for row in rows if row['disposition'] == 'completed_transfer']
    objects, activities = {}, {}
    for row in completed:
        body = row['body']
        objects.setdefault(body['physicalObject']['id'], []).append(row)
        activities.setdefault(body['activity']['id'], {}).setdefault(
            body['transferEvent']['id'], []).append(row)
    files, index, embedded, provenance = {}, [], [], []

    def emit(resource, statements, scoped=None):
        identity = resource['id']; stem = keccak256(identity.encode('utf-8'))[2:]
        path = 'transfer/resources/' + stem + '.json'
        require(path not in files, 'physical transfer duplicate projected identity')
        raw = dumps(resource)
        files[path] = raw
        files['transfer/expanded/' + stem + '.json'] = model.validate_and_expand(
            raw, maximum=MAX_GENERAL_V2_RESOURCE).expanded_bytes
        index.append({'id': identity, 'type': resource['type'], 'path': path,
            'sources': [row['source'] for row in statements], 'qualification': QUALIFICATION})
        sources = [_provenance(row) for row in statements]
        scopes = {prefix: [_provenance(row) for row in group]
            for prefix, group in (scoped or {}).items()}
        for pointer, value in leaves(resource):
            matching = [prefix for prefix in scopes
                if pointer == prefix or pointer.startswith(prefix + '/')]
            selected_sources = scopes[max(matching, key=len)] if matching else sources
            provenance.append({'entity': identity, 'path': pointer, 'value': value,
                'sources': selected_sources, 'rule': RULE, 'qualification': QUALIFICATION})
        return path

    qualifier = [{'type': 'LinguisticObject', 'content': QUALIFICATION}]
    for identity, statements in sorted(objects.items()):
        emit({'@context': CONTEXT, 'id': identity, 'type': 'HumanMadeObject',
            '_label': _label(statements[0]['declarations']['physicalObject'],
                'General-described physical object'), 'referred_to_by': qualifier}, statements)
    for activity_id, events in sorted(activities.items()):
        parts, statements, classes, scopes = [], [], [], {}
        for event_id, event_rows in events.items():
            row = event_rows[0]; body = row['body']; declarations = row['declarations']
            prefix = 'transferred_title_' if body['kind'] == 'physical_acquisition' else 'transferred_custody_'
            part = {'type': KINDS[body['kind']],
                '_label': _label(declarations['transferEvent'], 'General-described physical transfer'),
                prefix + 'of': [{'id': body['physicalObject']['id'], 'type': 'HumanMadeObject',
                    '_label': _label(declarations['physicalObject'], 'General-described physical object')}],
                'referred_to_by': qualifier}
            for body_key, property_suffix in (('fromParty', 'from'), ('toParty', 'to')):
                declaration = declarations[body_key]
                if declaration is not None:
                    part[prefix + property_suffix] = [{'id': declaration['value']['id'],
                        'type': 'Person' if declaration['value']['kind'] == 'person' else 'Group',
                        '_label': _label(declaration, 'General-declared party')}]
            parts.append(part); statements.extend(event_rows)
            scopes['/part/' + str(len(parts) - 1)] = event_rows
            if body['kind'] not in classes:
                classes.append(body['kind'])
            embedded.append({'originalSourceEntityId': event_id, 'type': part['type'],
                'parentId': activity_id, 'pointer': '/part/' + str(len(parts) - 1),
                'declaration': declarations['transferEvent'],
                'sources': [item['source'] for item in event_rows], 'qualification': QUALIFICATION})
        first = statements[0]
        scopes.update({'/classified_as/' + str(index):
            [row for row in statements if row['body']['kind'] == kind]
            for index, kind in enumerate(classes)})
        resource = {'@context': CONTEXT, 'id': activity_id, 'type': 'Activity',
            '_label': _label(first['declarations']['activity'], 'General-described physical-transfer activity'),
            'classified_as': [{'id': RELATION + ':activity:' + kind, 'type': 'Type',
                '_label': 'General-described physical acquisition' if kind == 'physical_acquisition'
                    else 'General-described physical custody transfer'} for kind in classes],
            'part': parts, 'referred_to_by': qualifier}
        path = emit(resource, statements, scopes)
        for item in embedded:
            if item['parentId'] == activity_id:
                item['path'] = path
    files['transfer/index.json'] = dumps({'resources': sorted(index, key=lambda row: row['id']),
        'embeddedEvents': embedded})
    files['transfer/provenance.json'] = dumps(provenance)
    return files, len(index)


def graph(rows, model):
    """Project derived completed statements using the unchanged pinned model."""
    try:
        return _graph(rows, model)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed physical transfer graph input') from exc
