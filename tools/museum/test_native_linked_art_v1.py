"""Concrete V4 native admission and independent exact Linked Art field controls."""
from copy import deepcopy
from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import canonical_object_dossier_v4 as dossier
from . import native_linked_art_v1 as native
from .bagit import write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .object_dossier import _ref
from .package_v2 import _dependencies


@lru_cache(maxsize=1)
def supplied():
    from .canonical_object_dossier_fixture_v4 import complete_case_v4
    case = complete_case_v4(); files, digest, options = case.inputs()
    original = dossier.compose(files, digest, **options)
    inventory_raw = native.inventory._extract(dict(original.files), original.manifest_hash).inventory
    inv = loads(inventory_raw, maximum=dossier.MAX_BYTES)
    chosen = [r for r in inv['occurrences'] if native._supported(r)]
    plan = dumps({'version': '1', 'kind': native.PLAN_KIND, 'sourceManifestHash': original.manifest_hash,
        'selected': [{'occurrenceId': r['occurrenceId'], 'selector': r['selector']} for r in chosen]})
    return original, plan, inventory_raw


@lru_cache(maxsize=1)
def complete():
    original, plan, inventory_raw = supplied()
    with patch('socket.socket', side_effect=AssertionError('network forbidden')):
        result = native.build(dict(original.files), original.manifest_hash, plan, keccak256(plan), disclosure='public')
    return original, plan, inventory_raw, result


def at(value, pointer):
    for part in pointer[1:].split('/') if pointer else ():
        key = part.replace('~1', '/').replace('~0', '~')
        value = value[int(key)] if type(value) is list else value[key]
    return value


class NativeLinkedArtTests(unittest.TestCase):
    def test_genuine_v4_replay_all_ten_owner_work_general_artist_and_complete_denominator(self):
        original, _, raw, result = complete()
        inv = loads(raw, maximum=dossier.MAX_BYTES)
        exported = loads(result.files['linked-art/inventory.json'], maximum=native.MAX_OUTPUT)
        self.assertEqual([r['occurrenceId'] for r in exported['occurrences']], [r['occurrenceId'] for r in inv['occurrences']])
        selected = [r for r in exported['occurrences'] if r['planSelected']]
        self.assertTrue(set(native.owner.FAMILIES) <= {r['family'] for r in selected})
        self.assertTrue({'WORK', 'ARTIST', 'GENERAL'} <= {r['family'] for r in selected})
        self.assertEqual(int(result.report['resourceCount']), 2 * len(selected))
        self.assertEqual(original.report['packetRequirementCount'], '19')
        self.assertEqual(original.report['dossierRequirementCount'], '49')
        self.assertFalse(result.report['claims']['originalRequirementsPromoted'])

    def test_every_mapped_value_has_exact_original_type_bytes_scope_and_resolved_target(self):
        original, _, inventory_raw, result = complete(); files = dict(original.files)
        inv = loads(inventory_raw, maximum=dossier.MAX_BYTES)
        occurrences = {r['occurrenceId']: r for r in inv['occurrences']}
        fields = {(f['occurrenceId'], f['domain'], f['pointer']): f for f in inv['fields']}
        proofs = loads(result.files['linked-art/provenance.json'], maximum=native.MAX_OUTPUT)['rows']
        parsed, hashes = {}, {}
        for proof in proofs:
            target = proof['target']; raw = result.files[target['path']]
            self.assertEqual(keccak256(raw), target['hash'])
            value = at(loads(raw, maximum=native.MAX_RESOURCE), target['pointer'])
            self.assertEqual(value, proof['targetValue'])
            for source in proof['sources']:
                if source['domain'] == 'original_identity': continue
                self.assertIs(type(value), str)
                key = (proof['occurrenceId'], source['domain'], source['pointer'])
                field = fields[key]; self.assertEqual(field['exactHex'], source['exactHex'])
                row = occurrences[proof['occurrenceId']]
                domain = next(d for d in row['domains'] if d['name'] == source['domain'])
                self.assertEqual(source['sourceReference'], domain['source'])
                ref = source['sourceReference']; path = ref['path'][7:]
                if path not in hashes: hashes[path] = keccak256(files[path])
                self.assertEqual(ref['hash'], hashes[path])
                if path not in parsed: parsed[path] = loads(files[path], maximum=dossier.MAX_BYTES)
                source_value = at(parsed[path], ref['jsonPointer'])
                if ref['encoding'] == 'hex': source_value = loads(hex_bytes(source_value), maximum=dossier.MAX_BYTES)
                elif ref['encoding'] == 'bytes': source_value = loads(files[path], maximum=dossier.MAX_BYTES)
                actual = at(source_value, source['pointer'])
                self.assertEqual(value, actual); self.assertIs(type(actual), type(value))
                self.assertEqual(source['exactHex'], '0x' + dumps(actual).hex())
                self.assertEqual(source['selector'], row['selector'])
                self.assertEqual(source['authority'], row['authority'])

    def test_title_names_and_payload_carriers_remain_qualified_without_inferred_entities(self):
        _, _, _, result = complete()
        inv = loads(result.files['linked-art/inventory.json'], maximum=native.MAX_OUTPUT)
        selected = [r for r in inv['occurrences'] if r['planSelected']]
        for row in selected:
            statement, carrier = [loads(result.files[r['path']], maximum=native.MAX_RESOURCE) for r in row['resources']]
            self.assertEqual(statement['type'], 'LinguisticObject'); self.assertEqual(carrier['type'], 'DigitalObject')
            self.assertEqual(carrier['digitally_carries'], [{'id': statement['id'], 'type': 'LinguisticObject'}])
            self.assertNotEqual(statement['id'], carrier['id'])
            self.assertIn(native.QUALIFICATION, [r['content'] for r in statement['referred_to_by']])
            if row['family'] == 'WORK':
                self.assertTrue(statement.get('identified_by'))
                self.assertTrue(all(n['classified_as'][0]['_label'] == 'original WORK-title declaration' for n in statement['identified_by']))
            def walk(value):
                if type(value) is dict:
                    self.assertNotIn(value.get('type'), ('Person', 'Group', 'Activity', 'Creation', 'Acquisition'))
                    for child in value.values(): walk(child)
                elif type(value) is list:
                    for child in value: walk(child)
            walk(statement); walk(carrier)

    def test_owner_predicates_distinguish_loan_references_title_roles_and_unverified_notice(self):
        _, _, _, result = complete()
        inv = loads(result.files['linked-art/inventory.json'], maximum=native.MAX_OUTPUT)
        by_id = {r['occurrenceId']: r for r in inv['occurrences']}
        proofs = loads(result.files['linked-art/provenance.json'], maximum=native.MAX_OUTPUT)['rows']
        rules = {}
        for row in proofs: rules.setdefault(by_id[row['occurrenceId']]['family'], []).append(row)
        loan = {row['rule'].removeprefix(native.RULE) for row in rules['LOAN']}
        self.assertTrue({'names-lender', 'names-borrower', 'declares-activity-status'} <= loan)
        # This actual original fixture declares the three linked records null.
        # Their roles must not acquire invented target values.
        fields = loads(result.files['linked-art/coverage.json'], maximum=native.MAX_OUTPUT)['fields']
        missing = [f for f in fields if by_id[f['occurrenceId']]['family'] == 'LOAN' and f['domain'] == 'payload'
            and f['pointer'] in ('/insuranceValuation', '/outboundConditionReport', '/returnConditionReport')]
        self.assertEqual(len(missing), 3)
        self.assertTrue(all(f['kind'] == 'null' and f['disposition'] == 'retained_stream_only' for f in missing))
        accession = {row['rule'].removeprefix(native.RULE) for row in rules['ACCESSION']}
        self.assertTrue({'references-title-instrument', 'names-title-custodian', 'documents-token-transfer'} <= accession)
        response = [r for r in rules['RECOVERY_RESPONSE'] if r['rule'].endswith('declares-response')]
        self.assertTrue(response); self.assertEqual(response[0]['qualification'], 'statement_never_veto_or_execution')
        self.assertFalse(any('retains-payload-field:' in r['rule'] for r in proofs))

    def test_fields_unselected_residual_nonstrings_and_opaque_rows_never_inherit_mapping(self):
        _, _, raw, result = complete()
        inv = loads(raw, maximum=dossier.MAX_BYTES)
        proofs = loads(result.files['linked-art/provenance.json'], maximum=native.MAX_OUTPUT)['rows']
        mapped = {(p['occurrenceId'], s['domain'], s['pointer']) for p in proofs for s in p['sources'] if s['domain'] != 'original_identity'}
        fields = loads(result.files['linked-art/coverage.json'], maximum=native.MAX_OUTPUT)['fields']
        self.assertEqual([(f['occurrenceId'], f['domain'], f['pointer'], f['exactHex']) for f in fields],
            [(f['occurrenceId'], f['domain'], f['pointer'], f['exactHex']) for f in inv['fields']])
        for field in fields:
            self.assertEqual(field['disposition'] == 'mapped', (field['occurrenceId'], field['domain'], field['pointer']) in mapped)
            if field['kind'] != 'string': self.assertNotEqual(field['disposition'], 'mapped')
        self.assertTrue(any(f['presence'] == 'absent' for f in fields))

    def test_empty_selection_retains_every_family_and_original_scope_without_targets(self):
        original, plan, raw, _ = complete(); chosen = loads(plan); chosen['selected'] = []; plan = dumps(chosen)
        result = native._derive(dict(original.files), original.manifest_hash, plan, keccak256(plan), inventory_raw=raw)
        self.assertEqual(result.report['resourceCount'], '0')
        self.assertEqual(result.report['occurrenceCount'], complete()[3].report['occurrenceCount'])
        self.assertFalse(any('/resources/' in p for p in result.files))
        self.assertFalse(any(f['disposition'] == 'mapped' for f in loads(result.files['linked-art/coverage.json'], maximum=native.MAX_OUTPUT)['fields']))

    def test_wrong_selector_cross_subject_opaque_and_duplicate_selection_refuse(self):
        original, plan, raw, _ = complete(); inv = loads(raw, maximum=dossier.MAX_BYTES)
        for change in ('selector', 'subject', 'opaque', 'duplicate'):
            value = loads(plan); chosen = value['selected'][0]
            if change == 'selector': chosen['selector']['recordHash'] = '0x' + 'ab' * 32
            elif change == 'subject': chosen['selector']['subjectId'] = '0x' + 'ab' * 32
            elif change == 'opaque':
                row = next(r for r in inv['occurrences'] if not native._supported(r))
                value['selected'] = [{'occurrenceId': row['occurrenceId'], 'selector': row['selector']}]
            else: value['selected'].append(deepcopy(chosen))
            altered = dumps(value)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                native._derive(dict(original.files), original.manifest_hash, altered, keccak256(altered), inventory_raw=raw)

    def test_model_closure_is_retained_only_and_dependency_substitution_rejects(self):
        original, plan, inv, expected = complete()
        deps = {p.removeprefix('dependencies/'): raw for p, raw in _dependencies(native.MODEL_ROOT, recorded=True).items()}
        with TemporaryDirectory() as temporary:
            root = Path(temporary) / 'model'; write_tree(deps, root); reader = Path.read_bytes
            def retained_only(path):
                if path.resolve().is_relative_to(native.MODEL_ROOT.resolve()): raise AssertionError('repo model read')
                return reader(path)
            with patch.object(Path, 'read_bytes', retained_only), patch('socket.socket', side_effect=AssertionError('network')):
                self.assertEqual(native._derive(dict(original.files), original.manifest_hash, plan, keccak256(plan), root, inventory_raw=inv), expected)
            target = root / 'linked-art-v2/validation-policy.json'; changed = loads(target.read_bytes(), maximum=524288)
            changed['invented'] = True; target.write_bytes(dumps(changed))
            with self.assertRaises(MuseumError):
                native._derive(dict(original.files), original.manifest_hash, plan, keccak256(plan), root, inventory_raw=inv)

    def test_public_original_replay_refuses_rehashed_semantic_authority_and_meaning(self):
        original, plan, _, _ = complete(); files = dict(original.files)
        path = 'canonical/inputs/source-inventory.json'; raw = loads(files[path], maximum=dossier.MAX_BYTES)
        row = next(r for r in raw['rows'] if r['family'] == 'ACCESSION' and r['semantic'] is not None)
        row['authority']['inventedInstitutionStanding'] = True
        row['semantic']['accessionIdentifier'] = 'forged descriptor'; files[path] = dumps(raw)
        manifest = loads(files['manifest.json'], maximum=dossier.MAX_MANIFEST)
        manifest['files'] = [_ref(p, body) for p, body in sorted(files.items()) if p != 'manifest.json']
        files['manifest.json'] = dumps(manifest); digest = keccak256(files['manifest.json'])
        value = loads(plan); value['sourceManifestHash'] = digest; altered = dumps(value)
        with self.assertRaises(MuseumError):
            native.build(files, digest, altered, keccak256(altered), disclosure='public')

    def test_plan_bounds_public_guard_and_wrong_external_pins(self):
        class Trap:
            def __iter__(self): raise AssertionError('private input read')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            native.build(Trap(), 'bad', b'bad', 'bad', disclosure='restricted')
        original, plan, raw, _ = complete()
        with self.assertRaisesRegex(MuseumError, 'plan pin'):
            native._derive(dict(original.files), original.manifest_hash, plan, '0x' + '11' * 32, inventory_raw=raw)
        value = loads(plan); value['selected'] = [value['selected'][0]] * (native.MAX_SELECTED + 1); altered = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'count bound'):
            native._derive(dict(original.files), original.manifest_hash, altered, keccak256(altered), inventory_raw=raw)

    def test_pure_work_formatter_preserves_repeated_titles_and_never_promotes_numeric_controls(self):
        # Pure formatter vector, not a native source admission substitute.
        from tools.metadata import work_profile
        payload = deepcopy(work_profile.examples()[0]); payload['alternateTitles'] = ['Repeat', 'Repeat']
        row = {'occurrenceId': '0x' + '31' * 32, 'originalOccurrenceId': None, 'family': 'WORK',
            'selector': {'subjectId': payload['subjectId']}, 'authority': {'mode': 'pure_formatter_vector'},
            'original': {'path': 'unit/original.json', 'hash': keccak256(dumps(payload)), 'jsonPointer': '', 'encoding': 'bytes'}}
        ref = row['original']; fields, _ = native.inventory.fields(payload, work_profile.schema())
        fields = [{'domain': 'payload', **f} for f in fields]
        output, resources, proofs = native._render(row, {'payload': (payload, ref)}, fields, {}, native.validator(native.MODEL_ROOT))
        root = loads(output[resources[0]['path']], maximum=native.MAX_RESOURCE)
        self.assertEqual([n['content'] for n in root['identified_by']], ['Repeat', 'Repeat', payload['title']])
        repetitions = [p for p in proofs if p['targetValue'] == 'Repeat']
        self.assertEqual([p['sources'][0]['pointer'] for p in repetitions], ['/alternateTitles/0', '/alternateTitles/1'])
        self.assertEqual(len({p['target']['pointer'] for p in repetitions}), 2)
        self.assertFalse(any(s['pointer'] == '/version' for p in proofs for s in p['sources']))

    def test_pure_condition_formatter_quotes_examiner_and_observations_without_person_or_event(self):
        from .test_condition import condition
        from .condition import SCHEMA_BYTES
        payload = condition(); row = {'occurrenceId': '0x' + '41' * 32, 'originalOccurrenceId': None,
            'family': 'CONDITION', 'selector': {'recordHash': '0x' + '42' * 32},
            'authority': {'mode': 'pure_formatter_vector'}, 'original': {'path': 'unit/condition.json',
                'hash': keccak256(dumps(payload)), 'jsonPointer': '', 'encoding': 'bytes'}}
        fields, _ = native.inventory.fields(payload, loads(SCHEMA_BYTES, maximum=524288))
        output, resources, proofs = native._render(row, {'payload': (payload, row['original'])},
            [{'domain': 'payload', **f} for f in fields], {}, native.validator(native.MODEL_ROOT))
        root = loads(output[resources[0]['path']], maximum=native.MAX_RESOURCE)
        self.assertEqual(root['type'], 'LinguisticObject')
        mapped = {s['pointer'] for p in proofs for s in p['sources'] if s['domain'] == 'payload'}
        self.assertTrue({'/examiner/name/value', '/examinationDate/expression', '/fixity/status', '/render/outcome'} <= mapped)
        self.assertFalse(any('carried_out_by' in d or 'timespan' in d for d in root['referred_to_by']))
        self.assertTrue(all(p.get('qualification') == 'reported_condition_not_independent_performance_or_fixity'
            for p in proofs if p['sources'][0]['domain'] == 'payload'))

    def test_pure_owner_linked_reference_roles_are_distinct_and_residual_fields_stay_unmapped(self):
        from .test_loans import loan
        from .test_condition import reference
        payload = loan()
        for i, key in enumerate(('insuranceValuation', 'outboundConditionReport', 'returnConditionReport')):
            payload[key] = reference(10 + i)
        original = {'recordHash': '0x' + '51' * 32, 'receipt': ['41', '0x' + '52' * 20]}
        _, relations = native.owner._meaning('LOAN', payload, original, {})
        row = {'occurrenceId': '0x' + '53' * 32, 'originalOccurrenceId': '0x' + '54' * 32,
            'family': 'LOAN', 'selector': {'recordHash': original['recordHash']}}
        originals = {row['originalOccurrenceId']: {'family': 'LOAN', 'selector': row['selector'], 'semantic': payload,
            'ownerMeaning': {'status': 'typed', 'semantic': payload, 'relations': relations}}}
        expected = {'insuranceValuation': 'references-insurance-valuation',
            'outboundConditionReport': 'references-outbound-condition', 'returnConditionReport': 'references-return-condition'}
        for key, predicate in expected.items():
            self.assertEqual(native._meaning(row, 'payload', '/' + key + '/uri', payload, originals)[0], predicate)
        self.assertIsNone(native._meaning(row, 'payload', '/loanId', payload, originals))


if __name__ == '__main__':
    unittest.main()
