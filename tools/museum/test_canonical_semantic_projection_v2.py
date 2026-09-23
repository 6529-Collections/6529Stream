"""All-family projection over real source replay and qualified original statements."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import canonical_semantic_projection_v2 as projection
from . import canonical_semantic_sources_v2 as sources
from .canonical import MuseumError, dumps, keccak256, loads as load_json


def loads(raw, **kwargs):
    kwargs.setdefault("maximum", projection.MAX_OUTPUT_BYTES)
    return load_json(raw, **kwargs)


def H(label):
    return keccak256(label.encode('utf-8'))


def rekey(value):
    """Rebuild supplied-data IDs/leaves, never assert source admission."""
    for row in value['rows']:
        row['occurrenceId'] = keccak256(dumps({'profileHash': sources.PROFILE_HASH,
            'sourceManifestHash': value['sourceManifestHash'], 'selector': row['selector'],
            'originalPointer': row['pointers']['original']}))
    value['leaves'] = sources.field_inventory(value['rows'])
    return value


class CanonicalSemanticProjectionV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from .test_canonical_semantic_sources_v2 import complete_case
        cls.source = complete_case()
        cls.plan = sources.plans.prepare()
        cls.plan_args = {'plan_files': dict(cls.plan.files), 'plan_hash': cls.plan.manifest_hash}
        _, cls.inventory = sources.admit(cls.source.files, cls.source.manifest_hash, **cls.plan_args)
        cls.selection = projection.default_selection(cls.inventory, **cls.plan_args)
        cls.files = projection.render(cls.inventory, cls.selection, keccak256(cls.selection), **cls.plan_args)
        cls.owner_ids = [r['occurrenceId'] for r in cls.inventory['rows']
            if r['ownerMeaning'] is not None and r['interpretation']['status'] == 'interpreted']
        cls.history_selection = projection.historical_selection(cls.inventory, cls.owner_ids, **cls.plan_args)
        cls.history_files = projection.render(cls.inventory, cls.history_selection,
            keccak256(cls.history_selection), **cls.plan_args)

    def render(self, inventory, ids=None):
        raw = (projection.default_selection(inventory, **self.plan_args) if ids is None else
            projection.historical_selection(inventory, ids, **self.plan_args))
        return projection.render(inventory, raw, keccak256(raw), **self.plan_args)

    def test_all_ten_owner_families_emit_typed_field_statements(self):
        assertions = loads(self.history_files[projection.ASSERTIONS_PATH])['selected']
        self.assertEqual({r['family'] for r in assertions}, set(projection.OWNER_FAMILIES))
        relations = loads(self.history_files[projection.OWNER_RELATIONS_PATH])['relations']
        self.assertEqual({r['family'] for r in relations}, set(projection.OWNER_FAMILIES))
        self.assertGreater(len(relations), len(assertions) * 3)
        index = loads(self.history_files[projection.INDEX_PATH])['resources']
        by_id = {r['id']: loads(self.history_files[r['path']]) for r in index}
        originals = {r['occurrenceId']: r for r in self.inventory['rows']}
        for assertion in assertions:
            row = originals[assertion['occurrenceId']]
            fields = assertion['ownerRelations']
            self.assertEqual(len(fields), len(row['ownerMeaning']['relations']))
            for field, expected in zip(fields, row['ownerMeaning']['relations']):
                self.assertEqual(field['predicate'], expected['predicate'])
                self.assertEqual(field['value'], expected['value'])
                self.assertEqual(field['payloadJsonPointer'], expected['sourcePointer'])
                self.assertEqual(field['selector'], row['selector'])
                self.assertEqual(field['authority'], row['original']['authority'])
                self.assertFalse(field['independentFactEstablished'])
                resource = by_id[field['id']]
                self.assertEqual(resource['type'], 'LinguisticObject')
                self.assertEqual(resource['part_of'][0]['id'], field['recordStatement'])
                self.assertEqual(resource['classified_as'][1], {
                    'id': projection.RULE + 'owner-predicate:'
                        + keccak256(expected['predicate'].encode('utf-8'))[2:],
                    'type': 'Type', '_label': expected['predicate']})
                self.assertIn(dumps(expected['value']).decode('utf-8'), resource['content'])
                self.assertIn(expected['qualification'], resource['content'])

    def test_distinct_title_loan_and_valuation_predicates_keep_qualifiers(self):
        rows = loads(self.history_files[projection.OWNER_RELATIONS_PATH])['relations']
        for family in ('ACCESSION', 'DEACCESSION'):
            fields = {r['payloadJsonPointer']: r for r in rows if r['family'] == family}
            self.assertEqual({fields[p]['predicate'] for p in
                ('/titleBinding/instrument', '/titleBinding/custodian', '/titleBinding/transfer')},
                {'references-title-instrument', 'names-title-custodian', 'documents-token-transfer'})
            self.assertEqual(fields['/titleBinding/transfer']['qualification'], 'transfer_not_independently_verified')
        loan = {r['payloadJsonPointer']: r for r in rows if r['family'] == 'LOAN'}
        self.assertEqual({loan[p]['predicate'] for p in
            ('/insuranceValuation', '/outboundConditionReport', '/returnConditionReport')},
            {'references-insurance-valuation', 'references-outbound-condition', 'references-return-condition'})
        amount = next(r for r in rows if r['family'] == 'VALUATION' and r['payloadJsonPointer'] == '/amount')
        self.assertEqual(amount['value'], '12345678901234567890.004500')
        self.assertEqual(amount['qualification'], 'literal_owner_statement_no_financial_truth')
        self.assertFalse(amount['independentFactEstablished'])
        coverage = loads(self.history_files[projection.COVERAGE_PATH])['leaves']
        self.assertTrue(any(r['section'] == 'semantic' and r['jsonPointer'] == '/version'
            and r['occurrenceId'] in self.owner_ids and r['disposition'] == 'retained_stream_only'
            for r in coverage))

    def test_default_selection_emits_distinct_validated_statements_and_payloads(self):
        index = loads(self.files[projection.INDEX_PATH])
        resources = index['resources']
        self.assertEqual(len(resources), len({r['id'] for r in resources}))
        self.assertTrue(any(r['role'].startswith('owner_field:') for r in resources))
        self.assertTrue(any(r['role'] == 'payload' for r in resources))
        for row in resources:
            self.assertIn(row['expandedPath'], self.files)
            self.assertIn(loads(self.files[row['path']])['type'], ('LinguisticObject', 'DigitalObject'))
        selected = loads(self.files[projection.ASSERTIONS_PATH])['selected']
        owner = [r for r in selected if r['ownerMeaning'] is not None]
        self.assertEqual([r['family'] for r in owner], ['ACCESSION'])
        self.assertEqual(owner[0]['currentness']['selectionBasis'], 'explicit_accession_record')

    def test_conflicting_candidates_never_flatten_into_work_or_agent_facts(self):
        for path, raw in self.history_files.items():
            if '/resources/' in path:
                row = loads(raw)
                self.assertNotIn(row['type'], ('Person', 'Group', 'Activity', 'HumanMadeObject'))
                for key in ('produced_by', 'current_owner', 'carried_out_by'):
                    self.assertNotIn(key, row)
        report = loads(self.history_files[projection.REPORT_PATH])
        for key in ('personOrGroupInferred', 'legalTitleInferred', 'activityOrPerformanceInferred',
                    'ownerStatementsBecomeSpecializedState', 'redemptionFulfillmentInferred'):
            self.assertFalse(report['claims'][key])

    def test_leaf_coverage_preserves_original_semantic_null_empty_and_duplicates(self):
        value = loads(self.history_files[projection.COVERAGE_PATH], maximum=16 * 1024 * 1024)
        stripped = [{k: r[k] for k in ('occurrenceId', 'section', 'jsonPointer', 'valueType', 'value')}
            for r in value['leaves']]
        self.assertEqual(stripped, self.inventory['leaves'])
        selected = set(self.owner_ids)
        for row in value['leaves']:
            if row['occurrenceId'] in selected and row['section'] == 'semantic':
                self.assertIn(row['disposition'], ('mapped_attributed_owner_declaration', 'retained_stream_only'))
                self.assertTrue(row['statements'])
            elif row['section'] == 'original':
                self.assertEqual(row['disposition'], 'retained_stream_only')
        self.assertTrue(any(r['valueType'] == 'null' for r in value['leaves']))
        self.assertTrue(any(r['valueType'] == 'empty_array' for r in value['leaves']))

    def test_rehashed_typed_meaning_authority_and_subject_tampering_rejects(self):
        owner_index = next(i for i, r in enumerate(self.inventory['rows'])
            if r['ownerMeaning'] is not None and r['ownerMeaning']['status'] == 'typed')
        changes = (
            lambda r: r['ownerMeaning']['relations'][0].update(value='forged declared value'),
            lambda r: r['ownerMeaning']['relations'][0].update(qualification='authenticated institution'),
            lambda r: r['ownerMeaning']['relations'][0].update(sourcePointer='/not-original'),
            lambda r: r['authority'].update(owner='0x' + 'ff' * 20),
            lambda r: r['selector'].update(subjectId=H('foreign subject')),
            lambda r: r['semantic'].update(version='999'),
        )
        for mutate in changes:
            value = deepcopy(self.inventory); mutate(value['rows'][owner_index]); rekey(value)
            with self.subTest(change=str(mutate)), self.assertRaises(MuseumError):
                self.render(value)

    def test_missing_unknown_reordered_or_rehashed_selection_rejects(self):
        value = loads(self.history_selection)
        cases = []
        for key, change in (('inventoryHash', H('wrong')), ('version', '1'),
                ('reason', 'institution-approved'), ('sourceManifestHash', H('different source'))):
            row = deepcopy(value); row[key] = change; cases.append(row)
        row = deepcopy(value); row['selectedOccurrenceIds'].append(H('unknown')); cases.append(row)
        for changed in cases:
            raw = dumps(changed)
            with self.assertRaises(MuseumError):
                projection.render(self.inventory, raw, keccak256(raw), **self.plan_args)
        with self.assertRaises(MuseumError):
            projection.render(self.inventory, self.selection, H('wrong external pin'), **self.plan_args)

    def test_unknown_and_opaque_rows_remain_alternatives_never_fallback(self):
        index = loads(self.history_files[projection.INDEX_PATH])
        opaque = [r for r in self.inventory['rows'] if r['interpretation']['status'] == 'opaque']
        self.assertTrue(any(r['family'] == 'OWNER_UNKNOWN' for r in opaque))
        by_id = {r['occurrenceId']: r for r in index['occurrences']}
        for row in opaque:
            self.assertEqual(by_id[row['occurrenceId']]['disposition'], 'retained_alternative')
            self.assertEqual(by_id[row['occurrenceId']]['ownerMeaning'], row['ownerMeaning'])
            with self.assertRaises(MuseumError):
                projection.historical_selection(self.inventory, [row['occurrenceId']], **self.plan_args)

    def test_historical_selection_keeps_notice_and_recovery_state_unknown(self):
        rows = loads(self.history_files[projection.ASSERTIONS_PATH])['selected']
        for row in rows:
            if row['family'] in ('STEWARD_DESIGNATION', 'RECOVERY_RESPONSE'):
                self.assertIn('unknown_without_notice_evidence', dumps(row['ownerMeaning']).decode())
                self.assertFalse(row['currentness']['selected'])
                self.assertEqual(row['currentness']['status'], 'historical_original')

    def test_owner_definition_plan_is_pinned_and_offline(self):
        with patch.object(sources.plans, 'prepare', side_effect=AssertionError('current definition tree read')):
            files = projection.render(self.inventory, self.selection, keccak256(self.selection), **self.plan_args)
        self.assertEqual(files, self.files)
        value = deepcopy(self.inventory); value['ownerDefinitions']['documents'].pop()
        with self.assertRaises(MuseumError): self.render(value)
        with self.assertRaises(MuseumError):
            projection.render(self.inventory, self.selection, keccak256(self.selection),
                plan_files=self.plan_args['plan_files'], plan_hash=H('wrong plan'))

    def test_owner_selection_cannot_promote_historical_or_cross_subject(self):
        value = deepcopy(self.inventory)
        row = next(r for r in value['rows'] if r['family'] == 'LOAN' and r['semantic'] is not None)
        row['currentness'].update(selected=True, status='explicit_original_selection')
        with self.assertRaisesRegex(MuseumError, 'selection/currentness'):
            self.render(value)
        value = deepcopy(self.inventory)
        row = next(r for r in value['rows'] if r['family'] == 'WORK')
        row['currentness']['status'] = 'other_subject'
        with self.assertRaises(MuseumError):
            projection.historical_selection(value, [row['occurrenceId']], **self.plan_args)

    def test_source_inventory_and_every_row_remain_bound(self):
        for mutate in (lambda v: v['leaves'].pop(),
                       lambda v: v['sourceState'].update(blockNumber='999'),
                       lambda v: v['rows'][0].update(occurrenceId=H('forged occurrence'))):
            value = deepcopy(self.inventory); mutate(value)
            with self.assertRaises(MuseumError):
                projection.render(value, self.selection, keccak256(self.selection), **self.plan_args)
        value = deepcopy(self.inventory); value['leaves'][0]['value'] = 'forged leaf'
        with self.assertRaisesRegex(MuseumError, 'leaf denominator'):
            self.render(value)

    def test_same_native_owner_condition_keeps_distinct_occurrences(self):
        value = deepcopy(self.inventory)
        original = next(r for r in value['rows'] if r['family'] == 'CONDITION_REPORT' and r['semantic'] is not None)
        duplicate = deepcopy(original)
        duplicate['family'] = 'CONDITION'; duplicate['ownerMeaning'] = None
        duplicate['selector']['kind'] = 'native_owner_condition'
        duplicate['selector']['sourceId'] = H('condition source occurrence')
        duplicate['currentness'] = {'status': 'selected_condition', 'selected': True,
            'selectionBasis': 'receipt_ordered_condition', 'selection': None, 'eligibility': 'not_asserted'}
        value['rows'].append(duplicate); rekey(value)
        files = self.render(value, [original['occurrenceId'], duplicate['occurrenceId']])
        assertions = loads(files[projection.ASSERTIONS_PATH])['selected']
        self.assertEqual(assertions[0]['recordIdentity'], assertions[1]['recordIdentity'])
        self.assertNotEqual(assertions[0]['occurrenceId'], assertions[1]['occurrenceId'])
        ids = [r['id'] for r in loads(files[projection.INDEX_PATH])['resources']]
        self.assertEqual(len(ids), len(set(ids)))

    def test_earlier_opaque_redemption_remains_in_complete_lane_before_selection(self):
        from .test_canonical_semantic_sources_v2 import AllFamilyOwnerFixture

        class EarlierOpaque(AllFamilyOwnerFixture):
            def append_family(inner, family, value, **kwargs):
                if family == 'REDEMPTION_CLAIM' and not getattr(inner, '_opaque_first', False):
                    inner._opaque_first = True
                    super().append_family(family, b'unknown earlier program',
                        schema_name='STREAM_UNKNOWN_REDEMPTION_V1', schema_hash=H('unknown program schema'))
                return super().append_family(family, value, **kwargs)

        fixture = EarlierOpaque()
        accession = fixture.accession_assembly()
        # This projection control replays the actual original owner capture;
        # it does not present a modified complete dossier as verified.
        files = {sources.OWNER_PREFIX + path: raw for path, raw in accession.files}
        owners, denominator = sources._owner(sources.previous._SourceFiles(files),
            self.inventory['sourceState'], self.inventory['sourceManifestHash'], self.plan)
        value = deepcopy(self.inventory)
        work = [r for r in value['rows'] if r['family'] == 'WORK']
        conditions = [r for r in value['rows'] if r['family'] == 'CONDITION']
        value['rows'] = work + owners + conditions
        value['denominators']['owner'] = denominator
        rekey(value)
        claims = [r for r in owners if r['family'] == 'REDEMPTION_CLAIM']
        first = next(r for r in claims if r['original']['receipt'][3] == '0')
        self.assertEqual(first['interpretation']['status'], 'opaque')
        typed = next(r for r in claims if r['semantic'] is not None)
        self.assertEqual(typed['ownerMeaning']['ownerMeaning']['programPrimacy'],
            'unresolved_due_to_earlier_opaque')
        files = self.render(value, [typed['occurrenceId']])
        selected = loads(files[projection.ASSERTIONS_PATH])['selected'][0]
        self.assertEqual(selected['ownerMeaning']['ownerMeaning']['programPrimacy'],
            'unresolved_due_to_earlier_opaque')
        self.assertFalse(loads(files[projection.REPORT_PATH])['claims']['redemptionFulfillmentInferred'])
        altered = deepcopy(value)
        altered['denominators']['owner']['lanes'] = [deepcopy(lane) for lane in denominator['lanes']]
        lane = next(lane for lane in altered['denominators']['owner']['lanes']
            if typed['selector']['recordHash'] in lane['records'])
        lane['records'].pop(0); lane['count'] = str(int(lane['count']) - 1)
        with self.assertRaises(MuseumError):
            self.render(altered, [typed['occurrenceId']])

        # The attacker retains every original but reorders the purported lane,
        # then recomputes every interpretation, annotation and selection pin.
        # The original native receipt indices and chain remain authoritative.
        altered = deepcopy(value)
        owner_rows = [row for row in altered['rows'] if row['ownerMeaning'] is not None]
        by_hash = {row['selector']['recordHash']: row for row in owner_rows}
        lane = next(lane for lane in altered['denominators']['owner']['lanes']
            if typed['selector']['recordHash'] in lane['records'])
        lane['records'].reverse()
        lane['head'] = by_hash[lane['records'][-1]]['original']['receipt'][4]
        latest = {by_hash[digest]['original']['receipt'][1]: digest for digest in lane['records']}
        lane['latestByAuthor'] = [{'owner': owner, 'recordHash': digest}
            for owner, digest in sorted(latest.items())]
        context = dict(altered['sourceState'], host=typed['selector']['host'],
            subjectId=typed['selector']['subjectId'])
        meaning = projection.owner_meaning
        definitions = meaning.definitions(self.plan_args['plan_files'], self.plan_args['plan_hash'])
        rebuilt = meaning.annotate(meaning.interpret_all(
            [row['original'] for row in owner_rows], context, definitions),
            altered['denominators']['owner']['lanes'])
        for row, result in zip(owner_rows, rebuilt['rows']):
            row['ownerMeaning'] = result
        altered['denominators']['owner']['laneAnalysis'] = rebuilt['laneAnalysis']
        changed_claim = by_hash[typed['selector']['recordHash']]
        self.assertEqual(changed_claim['ownerMeaning']['ownerMeaning']['programPrimacy'],
            'first_supported_candidate')
        selection = loads(projection.historical_selection(value, [typed['occurrenceId']], **self.plan_args))
        selection['inventoryHash'] = projection._inventory_hash(altered)
        raw = dumps(selection)
        with self.assertRaisesRegex(MuseumError, 'lane original index/chain'):
            projection.render(altered, raw, keccak256(raw), **self.plan_args)

    def test_crosswalk_named_vectors_resolve(self):
        names = {name for name in dir(type(self)) if name.startswith('test_')}
        for rule in loads(projection.CROSSWALK_BYTES)['rules']:
            self.assertIn(rule['positiveTest'], names)
            self.assertIn(rule['negativeTest'], names)
        self.assertEqual(keccak256(projection.PROFILE_BYTES), projection.PROFILE_HASH)
        self.assertNotEqual(projection.PROFILE_HASH,
            __import__('tools.museum.canonical_semantic_projection_v1', fromlist=['PROFILE_HASH']).PROFILE_HASH)


if __name__ == '__main__':
    unittest.main()
