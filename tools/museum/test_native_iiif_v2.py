"""Focused exact-source and target controls for native IIIF paintings V2."""
import base64
from copy import deepcopy
from functools import lru_cache
from hashlib import sha256
import unittest
from unittest.mock import patch

from . import canonical_field_inventory_v1 as field_inventory
from . import native_media_dossier_fixture_v1 as media_fixture
from . import native_iiif_v2 as native
from . import test_native_work_lido_v1 as work_fixture
from . import view_reference_semantic_receipt_fixture_v1 as view_fixture
from . import view_preservation_reference_types_v1 as reference_types
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id
from .native_finality_wire import from_json


def raw_cid(sha256_hex):
    """Canonical CIDv1/raw/sha2-256 for exact retained bytes; no fetch claim."""
    raw = bytes((1, 0x55, 0x12, 0x20)) + hex_bytes(sha256_hex, 32)
    return 'ipfs://b' + base64.b32encode(raw).decode('ascii').lower().rstrip('=')


def independent_leaves(value):
    """Independent complete scalar/null/empty-container denominator oracle."""
    result = set(); stack = [('', value)]
    while stack:
        pointer, item = stack.pop()
        if type(item) is dict and item:
            for key, child in item.items():
                escaped = str(key).replace('~', '~0').replace('/', '~1')
                stack.append((pointer + '/' + escaped, child))
        elif type(item) is list and item:
            for index, child in enumerate(item):
                stack.append((pointer + '/' + str(index), child))
        else:
            result.add((pointer, '0x' + dumps(item).hex()))
    return result


def context_for(sha256_hex, occurrence_id, *, width=640, height=480):
    stem = 'https://example.test/native-iiif-v2/' + occurrence_id[2:]
    return {'manifestId': stem + '/manifest',
        'manifestRights': 'http://rightsstatements.org/vocab/InC/1.0/',
        'attributionLabel': 'Attribution', 'canvasId': stem + '/canvas/0',
        'canvasLabel': 'Operator declared full-image layout',
        'pageId': stem + '/page/0', 'annotationId': stem + '/annotation/0',
        'bodyId': raw_cid(sha256_hex), 'bodyLabel': 'Retained VIEW PNG',
        'bodyRights': 'http://rightsstatements.org/vocab/InC/1.0/',
        'bodyAttribution': 'Unsigned export context; see exact native source evidence.',
        'width': width, 'height': height,
        'declaredBy': 'https://example.test/export-operator',
        'designation': 'operator_asserted_painting_correspondence'}


def plan_for(files, source_hash):
    """Plan one exact compatible WORK and selected received VIEW capture."""
    inventory_raw = field_inventory._extract(files, source_hash).inventory
    inventory = loads(inventory_raw, maximum=native.dossier.MAX_BYTES, canonical=True)
    source_inventory, semantic, checked = native._view(files)
    if semantic is None:
        raise MuseumError('native IIIF V2 fixture has no retained VIEW envelope')
    captures = [row for row in source_inventory['occurrences']
        if row['family'] == 'VIEW_REFERENCE_CAPTURE'
        and row['selection']['selected'] and row['availability'] == 'received'
        and row['selector']['tokenId'] == inventory['sourceState']['tokenId']
        and all(row['selector'][key] == inventory['sourceState'][key]
            for key in ('chainId', 'core', 'collectionId'))]
    if len(captures) != 1:
        raise MuseumError('native IIIF V2 fixture requires one selected received capture')
    capture = captures[0]
    semantic_capture = next(row for row in semantic['rows']
        if row['occurrenceId'] == capture['semanticOccurrenceId'])
    media = [row for row in checked['media']
        if row['objectHash'] == semantic_capture['values']['objectHash']]
    if len(media) != 1:
        raise MuseumError('native IIIF V2 fixture requires one operative material')
    reader = native.descriptive._Sources(files)
    works = []
    for row in inventory['occurrences']:
        if row['family'] != 'WORK' or row.get('interpretation', {}).get('status') != 'interpreted':
            continue
        _, payload = reader.domain(row, 'payload')
        if payload.get('form') != 'full':
            continue
        try: native._work_scope(row, payload, inventory['sourceState'])
        except MuseumError: continue
        works.append(row)
    if not works:
        raise MuseumError('native IIIF V2 fixture requires one scoped full WORK')
    work = sorted(works, key=lambda row: (not row['currentness']['selected'], row['occurrenceId']))[0]
    choice = {'occurrenceId': work['occurrenceId'], 'selector': deepcopy(work['selector']),
        'source': {'captureOccurrenceId': capture['occurrenceId'],
            'captureSelector': deepcopy(capture['selector']),
            'objectHash': media[0]['objectHash'],
            'materialRecordHash': media[0]['recordHash']},
        'context': context_for(media[0]['sha256'], work['occurrenceId'])}
    return dumps({'version': '2', 'kind': native.PLAN_KIND,
        'sourceManifestHash': source_hash, 'selected': [choice]})


@lru_cache(maxsize=1)
def png_source():
    envelope_raw = view_fixture.supplied_raw('png')
    envelope = loads(envelope_raw, maximum=native.dossier.MAX_BYTES, canonical=True)
    files = {native.VIEW_PATH: dumps({'evidence': {'retrievalEnvelope': envelope}})}
    return files, native._view(files)


@lru_cache(maxsize=1)
def no_view_case():
    original, _ = work_fixture.supplied()
    plan = dumps({'version': '2', 'kind': native.PLAN_KIND,
        'sourceManifestHash': original.manifest_hash, 'selected': []})
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = native.build(dict(original.files), original.manifest_hash, plan,
            keccak256(plan), disclosure='public')
    return original, plan, result


@lru_cache(maxsize=1)
def retained_foreign_work():
    """A real Metadata/WORK replay with interpreted foreign token originals."""
    from .test_canonical_semantic_sources_v1 import SemanticWorkSubjectBoundaryTests
    SemanticWorkSubjectBoundaryTests.setUpClass()
    return next(row for row in SemanticWorkSubjectBoundaryTests.rows
        if row['currentness']['status'] == 'other_subject'), \
        SemanticWorkSubjectBoundaryTests.inventory['sourceState']


@lru_cache(maxsize=1)
def painting_case():
    original, _ = media_fixture.supplied()
    plan = plan_for(dict(original.files), original.manifest_hash)
    inventory_raw = field_inventory._extract(dict(original.files), original.manifest_hash).inventory
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = native.build(dict(original.files), original.manifest_hash, plan,
            keccak256(plan), disclosure='public')
    return original, plan, inventory_raw, result


class NativeIiifV2Tests(unittest.TestCase):
    def test_real_retrieval_replay_inventories_received_png_and_every_original_leaf(self):
        files, (source, semantic, checked) = png_source()
        self.assertEqual(source['sourceStatus'], 'replayed')
        captures = [row for row in source['occurrences']
            if row['family'] == 'VIEW_REFERENCE_CAPTURE']
        self.assertEqual(len([row for row in captures if row['availability'] == 'received']), 1)
        self.assertEqual(len(checked['media']), 1)
        self.assertEqual(next(row for row in semantic['rows']
            if row['role'] == 'reference_capture')['values']['formatId'], native.PNG_FORMAT)
        outer = loads(files[native.VIEW_PATH], maximum=native.dossier.MAX_BYTES, canonical=True)
        by_id = {row['occurrenceId']: row for row in source['occurrences']}
        for field in source['fields']:
            domain = by_id[field['occurrenceId']]['domains'][0]['source']
            value = native._pointer(outer, domain['jsonPointer'])
            value = native._pointer(value, field['pointer'])
            self.assertEqual(field['exactHex'], '0x' + dumps(value).hex())
        envelope_occurrence = next(row for row in source['occurrences']
            if row['family'] == 'VIEW_RETRIEVAL_ENVELOPE')
        emitted = {(row['pointer'], row['exactHex']) for row in source['fields']
            if row['occurrenceId'] == envelope_occurrence['occurrenceId']}
        envelope = outer['evidence']['retrievalEnvelope']
        expected = independent_leaves(envelope)
        self.assertEqual(emitted, expected)

    def test_genuine_v4_view_work_and_received_png_build_one_valid_painting(self):
        original, plan, _, result = painting_case()
        self.assertEqual(result.report['status'], 'painting_manifests')
        self.assertEqual(result.report['selectedCount'], '1')
        index = loads(result.files['iiif/index.json'], maximum=native.MAX_OUTPUT, canonical=True)
        self.assertEqual(len(index['rows']), 1)
        row = index['rows'][0]
        manifest = loads(result.files[row['manifestPath']], maximum=native.MAX_OUTPUT,
            canonical=True)
        canvas = manifest['items'][0]; body = canvas['items'][0]['items'][0]['body']
        self.assertEqual((canvas['width'], canvas['height']), (body['width'], body['height']))
        self.assertTrue(row['bodyIdentifierFacts']['rawDigestAgreement'])
        self.assertIsNone(row['intrinsicDimensions'])
        self.assertIn(row['workScope'], ('token', 'collection'))
        self.assertFalse(result.report['claims']['nativeWorkTokenCorrespondenceProven'])
        outer = loads(dict(original.files)[native.VIEW_PATH], maximum=native.dossier.MAX_BYTES,
            canonical=True)
        envelope = outer['evidence']['retrievalEnvelope']; references = envelope['inventory']['value']['reference']
        selected = next(item for item in references['history']
            if item['receipt'][1][0] == references['selectedRecordHash'])
        publication = from_json(reference_types.PUBLICATION, selected['publication'])
        capture = next(item for item in publication[1][7]
            if item[0] == 41 and item[1] == 3)
        selected_plan = loads(plan, maximum=native.MAX_PLAN, canonical=True)['selected'][0]
        self.assertEqual(capture[6], selected_plan['source']['objectHash'])
        self.assertEqual(selected['receipt'][1][0],
            selected_plan['source']['captureSelector']['referenceRecordHash'])
        retained_material = next(item for item in envelope['materials']
            if item['recordHash'] == selected_plan['source']['materialRecordHash'])
        media_bytes = hex_bytes(retained_material['mediaBytes'])
        self.assertEqual(body[native.iiif.DIGEST]['@value'], sha256(media_bytes).hexdigest())
        self.assertEqual(body[native.iiif.SIZE]['@value'], str(len(media_bytes)))
        proofs = loads(result.files['iiif/provenance.json'], maximum=native.MAX_OUTPUT,
            canonical=True)['rows']
        retained = [proof for proof in proofs
            if any(source['domain'] == 'retained_source' for source in proof['sources'])]
        self.assertTrue(retained)
        body_id_proof = next(proof for proof in retained
            if proof['target']['pointer'] == '/items/0/items/0/items/0/body/id')
        self.assertEqual(body_id_proof['targetValue'], body['id'])
        body_id_source = next(source for source in body_id_proof['sources']
            if source['domain'] == 'retained_source')
        self.assertEqual(body_id_source['targetValue'], body['id'])
        self.assertEqual(body_id_source['exactHex'],
            '0x' + dumps('0x' + sha256(media_bytes).hexdigest()).hex())
        source_inventory = loads(result.files['iiif/supplemental-source-inventory.json'],
            maximum=native.MAX_OUTPUT, canonical=True)
        occurrences = {item['occurrenceId']: item for item in source_inventory['occurrences']}
        for proof in retained:
            raw = result.files[proof['target']['path']]
            target = native._pointer(loads(raw, maximum=native.MAX_OUTPUT, canonical=True),
                proof['target']['pointer'])
            expected_target = proof['targetValue']
            if type(expected_target) is dict and expected_target.get('kind') == 'number':
                expected_target = int(expected_target['lexical'])
            self.assertEqual(target, expected_target)
            for source in proof['sources']:
                if source['domain'] != 'retained_source': continue
                self.assertEqual(proof['occurrenceId'], source['sourceOccurrenceId'])
                occurrence = occurrences[source['sourceOccurrenceId']]
                reference = occurrence['domains'][0]['source']
                original_raw = dict(original.files)[reference['path'].removeprefix('source/')]
                value = native._pointer(loads(original_raw, maximum=native.dossier.MAX_BYTES,
                    canonical=True), reference['jsonPointer'])
                value = native._pointer(value, source['pointer'])
                self.assertEqual(source['exactHex'], '0x' + dumps(value).hex())
        self.assertEqual(loads(plan, maximum=native.MAX_PLAN, canonical=True)
            ['sourceManifestHash'], original.manifest_hash)

    def test_genuine_v4_selection_refuses_wrong_token_object_material_and_content_id(self):
        original, plan_raw, inventory_raw, _ = painting_case()
        for mode in ('token', 'object', 'material', 'body'):
            plan = loads(plan_raw, maximum=native.MAX_PLAN, canonical=True)
            if mode == 'token':
                plan['selected'][0]['source']['captureSelector']['tokenId'] = '999'
            elif mode == 'object':
                plan['selected'][0]['source']['objectHash'] = '0x' + 'aa' * 32
            elif mode == 'material':
                plan['selected'][0]['source']['materialRecordHash'] = '0x' + 'bb' * 32
            else:
                plan['selected'][0]['context']['bodyId'] = raw_cid('0x' + 'cc' * 32)
            raw = dumps(plan)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                native._derive(dict(original.files), original.manifest_hash, raw,
                    keccak256(raw), inventory_raw=inventory_raw)

    def test_actual_v4_without_view_retains_explicit_unavailable_state(self):
        original, _, result = no_view_case()
        self.assertEqual(result.report['status'], 'source_unavailable')
        self.assertEqual(result.report['selectedCount'], '0')
        source = loads(result.files['iiif/supplemental-source-inventory.json'],
            maximum=native.MAX_OUTPUT, canonical=True)
        self.assertEqual(source['sourceStatus'], 'source_unavailable')
        self.assertFalse(source['claims']['viewRetrievalReplayed'])
        self.assertFalse(result.report['claims']['sourceOriginAuthenticated'])
        self.assertEqual(result.report['sourceManifestHash'], original.manifest_hash)

    def test_selected_painting_cannot_use_absent_view_source(self):
        original, _, _ = no_view_case()
        _, lido_plan = work_fixture.supplied()
        selected = loads(lido_plan, maximum=native.MAX_PLAN, canonical=True)['selected'][0]
        choice = {'occurrenceId': selected['occurrenceId'], 'selector': selected['selector'],
            'source': {'captureOccurrenceId': '0x' + '11' * 32,
                'captureSelector': {'historyIndex': '0'}, 'objectHash': '0x' + '22' * 32,
                'materialRecordHash': '0x' + '33' * 32},
            'context': context_for('0x' + '44' * 32, selected['occurrenceId'])}
        plan = dumps({'version': '2', 'kind': native.PLAN_KIND,
            'sourceManifestHash': original.manifest_hash, 'selected': [choice]})
        with self.assertRaisesRegex(MuseumError, 'requires retained VIEW source'):
            native.build(dict(original.files), original.manifest_hash, plan,
                keccak256(plan), disclosure='public')

    def test_plan_dimensions_content_identifier_and_cross_selected_identities_are_closed(self):
        source_hash = '0x' + 'a1' * 32
        first = {'occurrenceId': '0x' + '01' * 32, 'selector': {'row': '1'},
            'source': {'captureOccurrenceId': '0x' + '11' * 32,
                'captureSelector': {'historyIndex': '0'}, 'objectHash': '0x' + '21' * 32,
                'materialRecordHash': '0x' + '31' * 32},
            'context': context_for('0x' + '41' * 32, '0x' + '01' * 32)}
        raw = dumps({'version': '2', 'kind': native.PLAN_KIND,
            'sourceManifestHash': source_hash, 'selected': [first]})
        self.assertEqual(native._plan(raw, keccak256(raw), source_hash)['selected'][0]
            ['context']['width'], 640)
        malformed = loads(raw, maximum=native.MAX_PLAN, canonical=True)
        malformed['selected'][0]['context']['width'] = 0
        bad = dumps(malformed)
        with self.assertRaises(MuseumError): native._plan(bad, keccak256(bad), source_hash)
        second = deepcopy(first); second['occurrenceId'] = '0x' + '02' * 32
        second['context'] = context_for('0x' + '42' * 32, second['occurrenceId'])
        second['context']['declaredBy'] = first['context']['canvasId']
        conflict = dumps({'version': '2', 'kind': native.PLAN_KIND,
            'sourceManifestHash': source_hash, 'selected': [first, second]})
        with self.assertRaisesRegex(MuseumError, 'operator/target identity collision'):
            native._plan(conflict, keccak256(conflict), source_hash)
        self.assertTrue(native._body_identifier(first['context']['bodyId'],
            ('41' * 32))['rawDigestAgreement'])
        unrelated_ar = 'ar://' + base64.urlsafe_b64encode(bytes(range(32))).decode(
            'ascii').rstrip('=')
        self.assertEqual(len(unrelated_ar.removeprefix('ar://')), 43)
        with self.assertRaisesRegex(MuseumError, 'bind exact source SHA-256'):
            native._body_identifier(unrelated_ar, '41' * 32)

    def test_work_scope_is_exact_token_or_collection_and_never_foreign(self):
        state = {'chainId': '31337', 'core': '0x' + '12' * 20,
            'collectionId': '7', 'tokenId': '41'}
        token = subject_id('token', state['chainId'], state['core'], '0', token_id='41')
        collection = subject_id('collection', state['chainId'], state['core'], '7')
        for expected, actual in (('token', token), ('collection', collection)):
            self.assertEqual(native._work_scope({'selector': {'subjectId': actual}},
                {'subjectId': actual}, state), expected)
        foreign = subject_id('token', state['chainId'], state['core'], '0', token_id='42')
        with self.assertRaisesRegex(MuseumError, 'outside target token or collection scope'):
            native._work_scope({'selector': {'subjectId': foreign}},
                {'subjectId': foreign}, state)

    def test_genuine_retained_foreign_work_original_cannot_be_designated(self):
        row, state = retained_foreign_work()
        self.assertEqual(row['interpretation']['status'], 'interpreted')
        self.assertEqual(row['currentness']['status'], 'other_subject')
        with self.assertRaisesRegex(MuseumError, 'outside target token or collection scope'):
            native._work_scope(row, row['semantic'], state)

    def test_same_object_in_other_history_does_not_make_selected_original_ambiguous(self):
        object_hash = '0x' + '55' * 32
        rows = [{'occurrenceId': '0x' + digit * 64, 'family': 'VIEW_EXTERNAL_OBJECT',
            'selector': {'historyIndex': index, 'objectHash': object_hash}}
            for digit, index in (('1', '0'), ('2', '1'))]
        source = {'occurrences': rows}
        capture = {'selector': {'historyIndex': '1'}}
        self.assertEqual(native._external_object_occurrence(source, capture,
            object_hash)['occurrenceId'], rows[1]['occurrenceId'])
        source['occurrences'].append(deepcopy(rows[1]))
        with self.assertRaisesRegex(MuseumError, 'external object differs'):
            native._external_object_occurrence(source, capture, object_hash)

    def test_exact_replayed_capture_refuses_wrong_selector_token_object_or_material(self):
        files, (source, semantic, checked) = png_source()
        occurrence = next(row for row in source['occurrences']
            if row['family'] == 'VIEW_REFERENCE_CAPTURE'
            and row['selection']['selected'] and row['availability'] == 'received')
        capture = next(row for row in semantic['rows']
            if row['occurrenceId'] == occurrence['semanticOccurrenceId'])
        material = next(row for row in checked['media']
            if row['objectHash'] == capture['values']['objectHash'])
        envelope = loads(files[native.VIEW_PATH], maximum=native.dossier.MAX_BYTES,
            canonical=True)['evidence']['retrievalEnvelope']
        choice = {'source': {'captureOccurrenceId': occurrence['occurrenceId'],
            'captureSelector': deepcopy(occurrence['selector']),
            'objectHash': material['objectHash'], 'materialRecordHash': material['recordHash']}}
        actual = native._selected_capture(source, semantic, checked, choice, envelope['context'])
        self.assertEqual(actual[0], occurrence); self.assertEqual(actual[2], material)
        for mode in ('selector', 'token', 'object', 'material'):
            bad = deepcopy(choice); state = deepcopy(envelope['context'])
            if mode == 'selector': bad['source']['captureSelector']['historyIndex'] = '999'
            elif mode == 'token': state['tokenId'] = str(int(state['tokenId']) + 1)
            elif mode == 'object': bad['source']['objectHash'] = '0x' + 'ab' * 32
            else: bad['source']['materialRecordHash'] = '0x' + 'cd' * 32
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                native._selected_capture(source, semantic, checked, bad, state)

    def test_source_proofs_use_source_occurrence_and_numbers_use_exact_lexicals(self):
        work = {'occurrenceId': '0x' + '11' * 32}
        source_id = '0x' + '22' * 32
        proof = native._proof(work, 'iiif/a.json', b'{}', ('/width', 9007199254740991),
            'source-size', [{'domain': 'retained_source', 'sourceOccurrenceId': source_id}])
        self.assertEqual(proof['occurrenceId'], source_id)
        self.assertEqual(proof['targetValue'],
            {'kind': 'number', 'lexical': '9007199254740991'})

    def test_public_gate_precedes_all_source_reads(self):
        with self.assertRaisesRegex(MuseumError, 'public disclosure required before reads'):
            native.build({}, '0x' + '11' * 32, b'{}', '0x' + '22' * 32,
                disclosure='restricted')


if __name__ == '__main__':
    unittest.main()
