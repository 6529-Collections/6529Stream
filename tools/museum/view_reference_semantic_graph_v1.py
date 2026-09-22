"""Qualified file occurrences from an independently admitted VIEW reference inventory.

This renderer checks supplied inventory consistency. The package entry point
replays the original native evidence before rendering. File declarations and
received-byte correspondence never establish delivery, execution, or safety.
"""
from copy import deepcopy
from pathlib import Path

from . import view_reference_semantic_sources_v1 as sources
from .canonical import MuseumError, dumps, hex_bytes, keccak256, uint
from .independent_wire import require
from .owner_notice_dossier import DEFAULT_MODEL_ROOT
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator


PROFILE = 'STREAM_MUSEUM_VIEW_REFERENCE_SEMANTIC_GRAPH_V1'
OUTPUT_PREFIX = 'view-reference-semantic/'
RULE = 'urn:6529stream:museum:view-reference-semantic:v1:'
PROFILE_PATH = OUTPUT_PREFIX + 'profile.json'
CROSSWALK_PATH = OUTPUT_PREFIX + 'crosswalk.json'
INDEX_PATH = OUTPUT_PREFIX + 'index.json'
PROVENANCE_PATH = OUTPUT_PREFIX + 'provenance.json'
COVERAGE_PATH = OUTPUT_PREFIX + 'coverage.json'
SIDECAR_PATH = OUTPUT_PREFIX + 'file-roles.json'
REPORT_PATH = OUTPUT_PREFIX + 'report.json'
MAX_INPUT_BYTES, MAX_OUTPUT_BYTES = 64 * 1024 * 1024, 96 * 1024 * 1024
MAX_ROWS, MAX_LEAVES, MAX_RESOURCE_BYTES = 4092, 524288, 32768
ROLE_LABELS = {
    'environment_declaration': 'Native reference environment declaration',
    'runnable_environment_zip': 'Declared runnable environment ZIP',
    'package_member': 'Declared environment package member',
    'os_prerequisite': 'Declared operating system prerequisite',
    'reference_capture': 'Native reference capture',
    'capture_html': 'HTML referenced by native capture',
    'adopted_script': 'Original adopted VIEW script',
    'token_data': 'Original token data',
    'token_json': 'Original token JSON output',
    'token_html': 'Original token HTML output',
}
RELATION_ROLES = {
    'uses_declared_environment': ({'runnable_environment_zip', 'reference_capture'}, {'environment_declaration'}),
    'declared_package_member': ({'package_member'}, {'runnable_environment_zip'}),
    'declared_platform_prerequisite': ({'os_prerequisite'}, {'environment_declaration'}),
    'reference_capture_of': ({'reference_capture'}, {'capture_html'}),
    'output_uses_adopted_script': ({'token_json', 'token_html'}, {'adopted_script'}),
    'output_uses_token_data': ({'token_json', 'token_html'}, {'token_data'}),
    'html_output_of_token': ({'capture_html'}, {'token_html'}),
}
QUALIFICATION = (
    'Distinct native reference file occurrences from a separately verified source inventory. '
    'Received means exact supplied byte correspondence under that source consumer; described-only '
    'means original commitments and declarations without supplied file bytes. Recorded roles, '
    'subjects, selected history and authority remain qualified original evidence. Neither state '
    'establishes retrieval from a URI, archival delivery, current availability, browser performance, '
    'executability, format detection, scan safety, human identity, custody or legal title. '
    'Linked Art validation establishes the pinned export shape, not those facts.')
CLAIMS = {
    'sourceInventoryVerifiedHere': False,
    'allSuppliedInventoryOccurrencesRetained': True,
    'duplicateOccurrencesPreserved': True,
    'allSuppliedInventoryLeavesRetained': True,
    'sourceCompletenessEstablishedHere': False,
    'receivedAndDeclaredOnlySeparated': True,
    'linkedArtShapeValidatedOffline': True,
    'currentEligibilityInferred': False,
    'retrievalFromOriginalURIProven': False,
    'archiveDeliveryProven': False,
    'executionOrBrowserPerformanceProven': False,
    'fileFormatDetected': False,
    'scanSafetyProven': False,
    'personOrEventInferred': False,
    'custodyOrLegalTitleInferred': False,
    'derivationInferred': False,
    'linkedArtAPIConformanceClaimed': False,
    'profileRegistered': False,
}
CROSSWALK = {
    'name': 'STREAM_MUSEUM_VIEW_REFERENCE_FILE_CROSSWALK_V1', 'version': '1',
    'rules': [{
        'id': RULE + role,
        'sourceProfileHash': sources.PROFILE_HASH,
        'source': '/rows/*[role=' + role + ']',
        'target': 'DigitalObject classified_as original file role and evidence availability',
        'cardinality': 'one per original occurrence; identical bytes never merge occurrences',
        'authority': 'exact record selector and original authority in file-role sidecar',
        'transformation': 'Give each occurrence a derived identity and classify its recorded role. Retain all exact declarations and bytes evidence in the sidecar.',
        'uncertainty': QUALIFICATION,
        'reverseCorrespondence': 'Index and provenance retain occurrenceId, recordId, selector and exact original JSON pointer.',
        'positiveTest': 'test_every_role_has_distinct_validated_digital_object',
        'negativeTest': 'test_changed_occurrence_role_evidence_and_link_reject',
    } for role in ROLE_LABELS] + [{
        'id': RULE + 'role-relations', 'sourceProfileHash': sources.PROFILE_HASH,
        'source': '/rows/*/relations and exact token selectors',
        'target': 'typed file-role sidecar only',
        'cardinality': 'all original ordered links and token-bearing file occurrences',
        'authority': 'native source relationship or exact original subject selector',
        'transformation': 'Keep declared package membership, prerequisites, captures, environment use and output relationships as qualified sidecar predicates.',
        'uncertainty': 'No performed Activity, derivation, actual ZIP extraction, system installation or URI delivery is inferred.',
        'reverseCorrespondence': 'Each relation retains both occurrence identities and its original source pointer.',
        'positiveTest': 'test_role_links_subject_and_currentness_are_exact',
        'negativeTest': 'test_no_unconditional_execution_derivation_or_delivery_edges',
    }, {
        'id': RULE + 'complete-leaves', 'sourceProfileHash': sources.PROFILE_HASH,
        'source': '/leaves/*', 'target': 'ordered coverage ledger',
        'cardinality': 'every targeted original scalar, null, empty container and byte descriptor exactly once',
        'authority': 'original source bytes', 'transformation': 'Retain the exhaustive source ledger without normalization or omission.',
        'uncertainty': 'Coverage is limited to the separately admitted source profile denominator.',
        'reverseCorrespondence': 'Every ledger row retains the original source JSON pointer and exact value or byte descriptor.',
        'positiveTest': 'test_exact_leaf_coverage_and_per_resource_provenance',
        'negativeTest': 'test_missing_or_duplicate_inventory_entries_reject',
    }],
}
CROSSWALK_BYTES = dumps(CROSSWALK)
CROSSWALK_HASH = keccak256(CROSSWALK_BYTES)
PROFILE_BYTES = dumps({
    'name': PROFILE, 'version': '1', 'status': 'prospective_unregistered_projection',
    'sourceProfileHash': sources.PROFILE_HASH, 'crosswalkHash': CROSSWALK_HASH,
    'validationPolicyHash': VALIDATION_HASH, 'context': CONTEXT,
    'roles': list(ROLE_LABELS), 'relations': list(RELATION_ROLES),
    'bounds': {'inputBytes': MAX_INPUT_BYTES, 'outputBytes': MAX_OUTPUT_BYTES,
        'occurrences': MAX_ROWS, 'sourceLeaves': MAX_LEAVES},
    'sourcePathBase': 'package', 'sourcePath': 'source/envelope.json',
    'identityRule': 'Graph profile plus exact source occurrence ID; never byte-hash identity merging.',
    'claims': CLAIMS, 'qualification': QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _leaves(value, path=''):
    if type(value) is dict and value:
        for key in sorted(value):
            yield from _leaves(value[key], path + '/' + key.replace('~', '~0').replace('/', '~1'))
    elif type(value) is list and value:
        for index, child in enumerate(value):
            yield from _leaves(child, path + '/' + str(index))
    else:
        yield path, value


def _identifier(occurrence_id):
    return RULE + 'file:' + keccak256(dumps({'profileHash': PROFILE_HASH,
        'occurrenceId': occurrence_id}))[2:]


def _inventory(inventory):
    require(type(inventory) is dict and len(dumps(inventory)) <= MAX_INPUT_BYTES,
        'VIEW reference graph input bound')
    sources.validate_inventory(inventory)
    rows, records, leaves = inventory['rows'], inventory['records'], inventory['leaves']
    require(type(rows) is list and len(rows) <= MAX_ROWS and type(leaves) is list
        and len(leaves) <= MAX_LEAVES, 'VIEW reference graph occurrence/leaf bound')
    by_record = {record['recordId']: record for record in records}
    by_row = {row['occurrenceId']: row for row in rows}
    require(len(by_record) == len(records) and len(by_row) == len(rows),
        'VIEW reference graph duplicate original identity')
    for row in rows:
        require(row['role'] in ROLE_LABELS and row['recordId'] in by_record,
            'VIEW reference graph unknown role/record')
        require(row['availability'] in ('described_only', 'received')
            and (row['byteEvidence'] is not None) == (row['availability'] == 'received'),
            'VIEW reference graph byte availability differs')
        if row['byteEvidence'] is not None:
            evidence = row['byteEvidence']
            uint(evidence['byteLength']); hex_bytes(evidence['keccak256'], 32); hex_bytes(evidence['sha256'], 32)
        for relation in row['relations']:
            predicate = relation['predicate']; target = by_row.get(relation['targetOccurrenceId'])
            require(predicate in RELATION_ROLES and target is not None
                and row['role'] in RELATION_ROLES[predicate][0]
                and target['role'] in RELATION_ROLES[predicate][1]
                and target['recordId'] == row['recordId'], 'VIEW reference graph role relation differs')
            if predicate in ('reference_capture_of', 'html_output_of_token', 'output_uses_token_data'):
                require(row['selector']['tokenId'] is not None
                    and row['selector']['tokenId'] == target['selector']['tokenId']
                    and row['selector']['collectionSerial'] == target['selector']['collectionSerial'],
                    'VIEW reference graph related token subject differs')
    return rows, by_record, by_row


def render(inventory, *, model_root=DEFAULT_MODEL_ROOT):
    """Render supplied inventory consistency; only the outer package replays source admission."""
    try:
        rows, records, by_row = _inventory(inventory)
        model = validator(Path(model_root))
        files, index, provenance, relations, assertions = {}, [], [], [], []
        inventory_hash = keccak256(dumps(inventory))
        for row in rows:
            identifier = _identifier(row['occurrenceId']); record = records[row['recordId']]
            availability = row['availability']
            resource = {'@context': CONTEXT, 'id': identifier, 'type': 'DigitalObject',
                '_label': ROLE_LABELS[row['role']],
                'classified_as': [{'id': RULE + 'role:' + row['role'], 'type': 'Type',
                    '_label': ROLE_LABELS[row['role']]},
                    {'id': RULE + 'availability:' + availability, 'type': 'Type',
                    '_label': 'Exact supplied bytes' if availability == 'received' else 'Described file; bytes not supplied'}],
                'referred_to_by': [{'type': 'LinguisticObject', 'content': QUALIFICATION}]}
            raw = dumps(resource)
            expanded = model.validate_and_expand(raw, maximum=MAX_RESOURCE_BYTES)
            key = keccak256(identifier.encode('utf-8'))[2:]
            path = OUTPUT_PREFIX + 'resources/' + key + '.json'
            expanded_path = OUTPUT_PREFIX + 'expanded/' + key + '.json'
            files[path], files[expanded_path] = raw, expanded.expanded_bytes
            index.append({'id': identifier, 'type': 'DigitalObject', 'path': path,
                'expandedPath': expanded_path, 'occurrenceId': row['occurrenceId'],
                'recordId': row['recordId'], 'role': row['role'], 'availability': availability,
                'source': deepcopy(row['source']), 'sourcePathBase': 'package'})
            assertions.append({'resource': identifier, 'occurrence': deepcopy(row),
                'originalRecord': deepcopy(record), 'sourcePathBase': 'package'})
            for pointer, value in _leaves(resource):
                provenance.append({'resource': identifier, 'jsonPointer': pointer, 'value': deepcopy(value),
                    'occurrenceId': row['occurrenceId'], 'recordId': row['recordId'],
                    'selector': deepcopy(row['selector']), 'source': deepcopy(row['source']),
                    'byteEvidence': deepcopy(row['byteEvidence']), 'authority': deepcopy(record['authority']),
                    'selectedOriginalReference': record['selected'], 'rule': RULE + row['role'],
                    'qualification': QUALIFICATION, 'sourcePathBase': 'package'})
            for relation in row['relations']:
                target = by_row[relation['targetOccurrenceId']]
                relations.append({'subject': identifier, 'object': _identifier(target['occurrenceId']),
                    'subjectOccurrenceId': row['occurrenceId'], 'objectOccurrenceId': target['occurrenceId'],
                    'subjectSelector': deepcopy(row['selector']), 'objectSelector': deepcopy(target['selector']),
                    'original': deepcopy(relation), 'rule': RULE + 'role-relations',
                    'independentFactEstablished': False, 'sourcePathBase': 'package'})
            if row['selector']['tokenId'] is not None:
                relations.append({'subject': identifier, 'subjectOccurrenceId': row['occurrenceId'],
                    'predicate': 'reference_of_token' if row['role'] in ('reference_capture', 'capture_html')
                        else 'token_output', 'tokenSelector': deepcopy(row['selector']),
                    'source': deepcopy(row['source']), 'rule': RULE + 'role-relations',
                    'independentFactEstablished': False, 'qualification': 'Exact original token subject; no work, ownership or performance inference.',
                    'sourcePathBase': 'package'})
        files.update({PROFILE_PATH: PROFILE_BYTES, CROSSWALK_PATH: CROSSWALK_BYTES,
            INDEX_PATH: dumps({'profileHash': PROFILE_HASH, 'sourceHash': inventory['sourceHash'],
                'inventoryHash': inventory_hash, 'resources': index}),
            PROVENANCE_PATH: dumps(provenance),
            COVERAGE_PATH: dumps({'profileHash': PROFILE_HASH, 'inventoryHash': inventory_hash,
                'sourcePathBase': 'package', 'leaves': deepcopy(inventory['leaves']),
                'occurrences': [{'occurrenceId': row['occurrenceId'], 'resource': _identifier(row['occurrenceId']),
                    'disposition': 'mapped_recorded_file_role', 'rule': RULE + row['role']} for row in rows]}),
            SIDECAR_PATH: dumps({'profileHash': PROFILE_HASH, 'inventoryHash': inventory_hash,
                'sourceState': deepcopy(inventory['sourceState']), 'sourceProvenance': inventory['sourceProvenance'],
                'records': deepcopy(inventory['records']), 'occurrences': assertions, 'relations': relations,
                'retainedSources': deepcopy(inventory['retainedSources']), 'qualification': QUALIFICATION}),
            REPORT_PATH: dumps({'profile': PROFILE, 'profileHash': PROFILE_HASH,
                'sourceProfileHash': sources.PROFILE_HASH, 'sourceHash': inventory['sourceHash'],
                'inventoryHash': inventory_hash, 'recordCount': len(records), 'occurrenceCount': len(rows),
                'resourceCount': len(index), 'sourceLeafCount': len(inventory['leaves']),
                'receivedOccurrenceCount': sum(row['availability'] == 'received' for row in rows),
                'describedOnlyOccurrenceCount': sum(row['availability'] == 'described_only' for row in rows),
                'roleCounts': {role: sum(row['role'] == role for row in rows) for role in ROLE_LABELS},
                'validationPolicyHash': VALIDATION_HASH, 'claims': CLAIMS, 'qualification': QUALIFICATION}),
        })
        require(sum(map(len, files.values())) <= MAX_OUTPUT_BYTES, 'VIEW reference graph output bound')
        return files
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed VIEW reference semantic inventory') from exc
