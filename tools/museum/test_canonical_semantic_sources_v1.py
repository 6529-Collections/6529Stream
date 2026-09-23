"""Concrete source inventory; original authorities never become semantic proof."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import canonical_semantic_sources_v1 as s
from . import acquisition_canonical_v10 as packet
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id
from .test_acquisition_canonical_v10 import composed_inputs
from .test_acquisition_work_condition_v1 import supplied, append_work, w


def family_case(**kwargs):
    """Real standalone replays for extraction units; not a substitute V3."""
    evidence, inputs = supplied(**kwargs)
    if not kwargs.get('empty', False):
        append_work(evidence, inputs, tombstone=True)
    result = w.verify(dumps(evidence), **inputs)
    files = {s.WORK_PATH: result.files['work-condition/work.json'],
        s.CONDITION_PATH: result.files['work-condition/condition.json'],
        s.METADATA_PATH: inputs['metadata_files']['snapshot.json'], s.EVIDENCE_PATH: dumps(evidence)}
    files.update({'acquisition/inputs/work/condition/' + path: raw
        for path, raw in (inputs['condition_files'] or {}).items()})
    return files, evidence['sourceState']


def complete_case():
    prior, native, native_hash = composed_inputs()
    v10 = packet.compose(prior.files, prior.manifest_hash, native, native_hash, disclosure='public')
    return s.dossier.compose(v10.files, v10.manifest_hash, disclosure='public')


def repin(files):
    manifest = loads(files['manifest.json'], maximum=s.dossier.MAX_MANIFEST, canonical=True)
    manifest['files'] = [s.dossier.package._ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class SemanticSourcesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = complete_case()
        cls.files = dict(cls.result.files)
        # This admission is the one full concrete replay used by the cases.
        with patch('socket.socket', side_effect=AssertionError('network used')):
            cls.checked, cls.inventory = s.admit(cls.files, cls.result.manifest_hash)
        cls.family_files, cls.state = family_case()
        cls.source_hash = keccak256(b'explicit synthetic unit source')

    def test_concrete_v3_replay_and_native_family_denominators(self):
        value = self.inventory
        self.assertEqual(self.checked.files, self.result.files)
        self.assertEqual(value['sourceManifestHash'], self.result.manifest_hash)
        self.assertEqual(value['sourceStateHash'], keccak256(dumps(value['sourceState'])))
        for family, name in (('WORK', 'work'), ('CONDITION', 'condition')):
            self.assertEqual(sum(r['family'] == family for r in value['rows']), int(value['denominators'][name]['recordCount']))
        owner = [r for r in value['rows'] if r['family'] in ('ACCESSION', 'DEACCESSION')]
        self.assertEqual(len(owner), int(value['denominators']['owner']['recordCount']))
        self.assertTrue(any(r['interpretation']['status'] == 'opaque' for r in owner))
        self.assertFalse(value['claims']['sourceAuthenticityProven'])
        self.assertFalse(value['claims']['nativeEligibilityReexecuted'])

    def test_owner_originals_keep_native_authority_and_explicit_selection(self):
        rows = [r for r in self.inventory['rows'] if r['family'] in ('ACCESSION', 'DEACCESSION')]
        chosen = [r for r in rows if r['currentness']['selected']]
        self.assertEqual(len(chosen), 1)
        self.assertEqual(chosen[0]['currentness']['status'], 'explicit_original_selection')
        self.assertFalse(self.inventory['denominators']['owner']['canonicalLatestAccessionProven'])
        for row in rows:
            self.assertEqual(row['authority']['mode'], 'historical_native_owner_receipt')
            self.assertNotIn('authorityClass', row['authority'])
            self.assertTrue(row['pointers']['payload']['path'].startswith(s.OWNER_PREFIX))
            original = loads(self.files[row['pointers']['original']['path']], maximum=s.dossier.MAX_BYTES)
            self.assertEqual(original, row['original'])
            self.assertEqual(self.files[row['pointers']['payload']['path']], hex_bytes(original['record'][5]))

    def test_work_history_tombstone_and_unknown_eligibility_are_separate(self):
        rows, denominator = s._work(self.family_files, self.state, self.source_hash)
        self.assertEqual(len(rows), 2)
        self.assertEqual([r['currentness']['status'] for r in rows], ['historical_native_selection', 'current_native_head'])
        self.assertEqual(rows[-1]['semantic']['form'], 'description_absent')
        self.assertTrue(all(r['currentness']['eligibility'] == 'not_reexecuted' for r in rows))
        self.assertFalse(denominator['scopePrecedenceInferred'])

    def test_condition_all_hosts_foreign_subject_and_selection_preserved(self):
        rows, denominator = s._condition(self.family_files, self.state, self.source_hash)
        self.assertEqual(len(rows), 5)
        self.assertEqual(sum(r['currentness']['selected'] for r in rows), 2)
        self.assertEqual(sum(r['currentness']['status'] == 'other_subject' for r in rows), 1)
        self.assertEqual({r['selector']['kind'] for r in rows}, {'native_owner_condition', 'native_independent_condition'})
        self.assertEqual({r['authority']['mode'] for r in rows}, {'historical_native_owner_receipt', 'historical_native_independent_receipt'})
        self.assertEqual(sum(int(lane['count']) for lane in denominator['lanes']), len(rows))
        for row in rows:
            self.assertEqual(dumps(row['semantic']), hex_bytes(row['original']['payloadHex']))

    def test_unsupported_newest_condition_does_not_select_older_statement(self):
        files, state = family_case(unsupported=True)
        rows, denominator = s._condition(files, state, self.source_hash)
        owner = [r for r in rows if r['selector']['kind'] == 'native_owner_condition' and r['currentness']['selected']]
        self.assertEqual(len(owner), 1)
        self.assertEqual(owner[0]['currentness']['status'], 'selected_condition_unresolved')
        self.assertIsNone(owner[0]['semantic'])
        self.assertEqual(owner[0]['interpretation']['status'], 'opaque')
        self.assertEqual(denominator['selections']['owner']['status'], 'selected_unresolved')

    def test_missing_condition_is_not_authenticated_absence(self):
        denominator = self.inventory['denominators']['condition']
        self.assertEqual(denominator['status'], 'source_missing')
        self.assertIsNone(denominator['lanes'])
        self.assertIsNone(denominator['selections'])
        self.assertFalse(denominator['globalHostsComplete'])

    def test_fixed_leaf_inventory_preserves_null_empty_duplicate_order_and_pointer(self):
        value = {'x/y~': [None, {}, [], 'duplicate', 'duplicate'], 'false': False, 'zero': 0}
        leaves = s.leaves(value, 'record', 'semantic')
        self.assertEqual([r['jsonPointer'] for r in leaves], ['/false', '/x~1y~0/0', '/x~1y~0/1', '/x~1y~0/2', '/x~1y~0/3', '/x~1y~0/4', '/zero'])
        self.assertEqual([r['valueType'] for r in leaves], ['boolean', 'null', 'empty_object', 'empty_array', 'string', 'string', 'integer'])
        expected = []
        for row in self.inventory['rows']:
            expected += s.leaves(row['original'], row['occurrenceId'], 'original')
            if row['semantic'] is not None: expected += s.leaves(row['semantic'], row['occurrenceId'], 'semantic')
        self.assertEqual(expected, self.inventory['leaves'])

    def test_source_pointers_and_ids_bind_host_scope_original_bytes(self):
        for row in self.inventory['rows']:
            for ref in row['pointers'].values():
                if ref is not None:
                    self.assertEqual(ref['hash'], keccak256(self.files[ref['path']]))
                    s.resolve_reference(self.files, ref)
        original = self.inventory['rows'][0]
        altered = deepcopy(original['selector']); altered['host'] = '0x' + 'ab' * 20
        args = (self.result.manifest_hash, original['family'], altered, original['original'], original['semantic'],
            original['interpretation']['reason'], original['currentness'], original['pointers'])
        self.assertNotEqual(s._row(*args)['occurrenceId'], original['occurrenceId'])
        narrowed = deepcopy(self.inventory); narrowed['rows'].pop()
        self.assertNotEqual(s.inventory_hash(narrowed), s.inventory_hash(self.inventory))

    def test_exact_native_definitions_and_nonexistent_pointers(self):
        definitions = s.definition_files()
        self.assertEqual(len(definitions), 10)
        self.assertEqual(keccak256(definitions['definitions/native-source/STREAM_WORK_DESCRIPTION_V1.json']), s.work_schema.WORK_SCHEMA_HASH)
        self.assertEqual(keccak256(definitions['definitions/native-source/STREAM_WORK_FORMAT_CATALOG_V1.json']), s.work_schema.CATALOG_SCHEMA_HASH)
        pointer = deepcopy(self.inventory['rows'][0]['pointers']['original'])
        pointer['jsonPointer'] += '/nonexistent'
        with self.assertRaises((MuseumError, KeyError)): s.resolve_reference(self.files, pointer)

    def test_extraction_pointer_cache_parses_and_hashes_each_file_once(self):
        raw = dumps({'rows': [{'value': str(index)} for index in range(64)]})
        files = s._SourceFiles({'snapshot.json': raw})
        with patch.object(s, 'loads', wraps=s.loads) as parsed, patch.object(s, 'keccak256', wraps=s.keccak256) as hashed:
            refs = [s._ref(files, 'snapshot.json', '/rows/' + str(index) + '/value') for index in range(64)]
            self.assertEqual(parsed.call_count, 1)
            self.assertEqual(hashed.call_count, 1)
        self.assertEqual(s.resolve_reference(dict(files), refs[-1]), '63')
        with self.assertRaisesRegex(MuseumError, 'file hash differs'):
            s.resolve_reference({'snapshot.json': dumps({'rows': []})}, refs[-1])

    def test_complete_catalog_occurrence_fields_are_retained(self):
        evidence, inputs = supplied(condition=False)
        append_work(evidence, inputs, catalog=True)
        checked = w.verify(dumps(evidence), **inputs)
        files = {s.WORK_PATH: checked.files['work-condition/work.json'],
            s.METADATA_PATH: inputs['metadata_files']['snapshot.json'], s.EVIDENCE_PATH: dumps(evidence)}
        rows, _ = s._work(files, evidence['sourceState'], self.source_hash)
        catalog = rows[-1]['catalog']
        self.assertIsNotNone(catalog)
        self.assertFalse(catalog['registrationAuthenticated'])
        self.assertEqual(s.resolve_reference(files, catalog['bytesSource']), dumps(catalog['value']))
        self.assertEqual(s.resolve_reference(files, catalog['source']), catalog['value'])
        fields = s.leaves(catalog['value'], rows[-1]['occurrenceId'], 'catalog')
        self.assertTrue(fields)
        self.assertTrue(all(row['section'] == 'catalog' for row in fields))
        self.assertEqual([r for r in s.field_inventory(rows) if r['section'] == 'catalog'], fields)

    def test_public_admission_refuses_rehashed_projection_tamper(self):
        files = dict(self.files)
        value = loads(files[s.WORK_PATH], maximum=s.dossier.MAX_BYTES)
        value['token']['currentEligibility'] = 'eligible'
        files[s.WORK_PATH] = dumps(value)
        with self.assertRaises(MuseumError): s.admit(files, repin(files))

    def test_unselected_opaque_original_does_not_veto_valid_selected_semantics(self):
        # A genuinely reconstructed original Metadata record with opaque bytes
        # is admitted before the supported selection on the same source map.
        evidence = loads(self.family_files[s.EVIDENCE_PATH], maximum=s.dossier.MAX_BYTES)
        state, graph = evidence['sourceState'], evidence['graph']
        base = loads(self.family_files[s.METADATA_PATH], maximum=s.dossier.MAX_BYTES)['records'][0]
        native_record = list(w._typed(s.metadata.RECORD, base['record']))
        native_receipt = list(w._typed(s.metadata.RECEIPT, base['receipt']))
        raw = b'{not valid JSON'
        native_record[2] = (1, hex_bytes(keccak256(raw)), schema_id('RFC8785_JCS'))
        native_record[7] = int(state['timestamp']) - 10
        native_record = tuple(native_record)
        digest = s.metadata.generic_hash(int(state['chainId']), graph['metadata']['address'], state['core'],
            int(state['collectionId']), native_receipt[1], native_record)
        native_receipt[3:8] = [int(state['timestamp']) - 9, 0,
            record_chain(state['chainId'], graph['metadata']['address'], state['collectionId'],
                s.metadata.WORK, w.ZERO, digest, '0'), s.work_schema.WORK_SCHEMA_HASH, w.work_native.WORK_CANON_HASH]
        e, inputs = supplied(condition=False, original_metadata_rows=[(digest, native_record, tuple(native_receipt), raw)])
        checked = w.verify(dumps(e), **inputs)
        files = {s.WORK_PATH: checked.files['work-condition/work.json'],
            s.METADATA_PATH: inputs['metadata_files']['snapshot.json'], s.EVIDENCE_PATH: dumps(e)}
        rows, _ = s._work(files, e['sourceState'], self.source_hash)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]['interpretation']['status'], 'opaque')
        self.assertEqual(hex_bytes(rows[0]['original']['payloadHex']), raw)
        self.assertEqual(sum(r['currentness']['selected'] for r in rows), 1)

    def test_derived_denominator_cannot_drop_source_original(self):
        files = dict(self.family_files)
        value = loads(files[s.WORK_PATH], maximum=s.dossier.MAX_BYTES)
        value['allOriginalWorkRecords'].pop(); files[s.WORK_PATH] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'denominator differs'):
            s._work(files, self.state, self.source_hash)


class SemanticWorkSubjectBoundaryTests(unittest.TestCase):
    """Replay one collection catalogue with applicable and foreign WORK subjects."""
    @classmethod
    def setUpClass(cls):
        from . import canonical_semantic_projection_v1 as projection
        from .test_canonical_semantic_projection_v1 import inventory
        evidence, inputs = supplied(condition=False)
        state, graph = evidence['sourceState'], evidence['graph']
        original = loads(inputs['metadata_files']['snapshot.json'], maximum=s.dossier.MAX_BYTES)['records'][0]
        cls.applicable = {w._subject(state, lane) for lane in ('collection', 'token')}
        cls.foreign = {w._subject(state | {'tokenId': str(int(state['tokenId']) + 1)}, 'token'),
            keccak256(b'unknown subject without asserted preimage')}
        native_rows, previous = [], w.ZERO
        for index, subject in enumerate([*sorted(cls.foreign), w._subject(state, 'collection')]):
            semantic = loads(hex_bytes(original['payloadHex']), maximum=32768, canonical=True)
            semantic['subjectId'] = subject
            raw = dumps(semantic)
            record = list(w._typed(s.metadata.RECORD, original['record']))
            receipt = list(w._typed(s.metadata.RECEIPT, original['receipt']))
            record[1] = subject
            record[2] = (1, hex_bytes(keccak256(raw)), schema_id('RFC8785_JCS'))
            record[7] = int(state['timestamp']) - 10 + index
            record = tuple(record)
            digest = s.metadata.generic_hash(int(state['chainId']), graph['metadata']['address'], state['core'],
                int(state['collectionId']), receipt[1], record)
            previous = record_chain(state['chainId'], graph['metadata']['address'], state['collectionId'],
                s.metadata.WORK, previous, digest, str(index))
            receipt[3:8] = [int(state['timestamp']) - 9 + index, index, previous,
                s.work_schema.WORK_SCHEMA_HASH, w.work_native.WORK_CANON_HASH]
            native_rows.append((digest, record, tuple(receipt), raw))
        evidence, inputs = supplied(condition=False, original_metadata_rows=native_rows)
        append_work(evidence, inputs, tombstone=True)
        with patch('socket.socket', side_effect=AssertionError('network used')):
            checked = w.verify(dumps(evidence), **inputs)
        files = {s.WORK_PATH: checked.files['work-condition/work.json'],
            s.METADATA_PATH: inputs['metadata_files']['snapshot.json'], s.EVIDENCE_PATH: dumps(evidence)}
        cls.rows, cls.denominator = s._work(files, state, keccak256(b'replayed subject-boundary source'))
        cls.inventory = inventory()
        cls.inventory.update(rows=cls.rows, leaves=s.field_inventory(cls.rows), sourceState=state,
            sourceStateHash=keccak256(dumps(state)), denominators={'work': cls.denominator})
        cls.projection = projection

    def test_foreign_and_unknown_subjects_retained_but_not_applicable(self):
        self.assertEqual(len(self.rows), 5)
        self.assertEqual(self.denominator['recordCount'], '5')
        for row in self.rows:
            self.assertEqual(row['interpretation']['status'], 'interpreted')
            self.assertEqual(dumps(row['semantic']), hex_bytes(row['original']['payloadHex']))
            self.assertEqual(row['currentness']['eligibility'], 'not_reexecuted')
            if row['selector']['subjectId'] in self.foreign:
                self.assertEqual(row['currentness']['status'], 'other_subject')
                self.assertFalse(row['currentness']['selected'])
        self.assertEqual({row['currentness']['status'] for row in self.rows
            if row['selector']['subjectId'] in self.applicable},
            {'unselected_original', 'historical_native_selection', 'current_native_head'})

    def test_historical_helper_keeps_collection_and_token_history_only(self):
        ids = [row['occurrenceId'] for row in self.rows if row['selector']['subjectId'] in self.applicable]
        raw = self.projection.historical_selection(self.inventory, ids)
        selected, _ = self.projection._selection(self.inventory, self.rows, raw, keccak256(raw))
        self.assertEqual(selected['selectedOccurrenceIds'], ids)
        self.projection.render(self.inventory, raw, keccak256(raw))
        for row in self.rows:
            if row['selector']['subjectId'] in self.foreign:
                with self.assertRaisesRegex(MuseumError, 'unsupported occurrence'):
                    self.projection.historical_selection(self.inventory, [row['occurrenceId']])

    def test_manually_rehashed_selection_cannot_cross_subject(self):
        current = self.projection.default_selection(self.inventory)
        self.assertEqual(len(loads(current, canonical=True)['selectedOccurrenceIds']), 1)
        for row in self.rows:
            if row['selector']['subjectId'] not in self.foreign:
                continue
            value = loads(current, canonical=True)
            value.update(policy='explicit_historical', reason='retained_historical_occurrence_review',
                selectedOccurrenceIds=[row['occurrenceId']])
            raw = dumps(value)
            with self.assertRaisesRegex(MuseumError, 'cannot cross subject'):
                self.projection._selection(self.inventory, self.rows, raw, keccak256(raw))
            with self.assertRaisesRegex(MuseumError, 'cannot cross subject'):
                self.projection.render(self.inventory, raw, keccak256(raw))


if __name__ == '__main__':
    unittest.main()
