"""Concrete native fixture replay and bounded current-source binding controls."""
from copy import deepcopy
from functools import lru_cache
import unittest
from unittest.mock import patch

from . import semantic_authoring_current_sources_v2 as adapter
from .canonical import MuseumError, dumps, keccak256, loads, subject_id
from .citations import canonical_citation


@lru_cache(maxsize=4)
def general_case(*, token=True, authority='curatorial', review_status='disputed'):
    """Change original native fixture preimages before any source capture."""
    from .general_semantic_fixture_v1 import OfflineGeneralSemanticFixture
    from .general_attestation_source import chain_hash, domain, native_record_hash, signed_words
    from .chain_abi import decode, encode
    from .test_general_attestation_source import decode_words
    from .independent_wire import ZERO
    from . import general_semantic_dossier_v1 as dossier
    fixture = OfflineGeneralSemanticFixture(authority=authority, review_status=review_status)
    f = fixture.general_fixture; token_id = '41'
    if token:
        _, old, saved, _, old_bundle, evidence, _ = f.rows[fixture.row_index]
        value, receipt = list(old), list(saved)
        digest = subject_id('token', f.anchor['chainId'], f.anchor['core'], '7', token_id=token_id)
        semantic = deepcopy(fixture.semantic_value)
        semantic['anchorSubject'] = {'kind': 'token', 'subjectId': digest}
        payload = dumps(semantic); value[2], value[8] = digest, keccak256(payload)
        # This new token subject has no earlier same-subject/recorder record;
        # the old collection supersession cannot follow it into this lane key.
        value[9] = ZERO
        bundle = b''
        if receipt[1] == 1:
            _, _, signature = decode(('bytes32', ('bytes32',) * 15, 'bytes'), old_bundle, maximum=8192)
            receipt[6], receipt[10] = ZERO, ZERO
            body = signed_words(tuple(value), payload, receipt)
            bundle = encode(('bytes32', ('bytes32',) * 15, 'bytes'),
                (domain(31337, f.host), decode_words(body), signature))
            receipt[6] = keccak256(b'\x19\x01' + bytes.fromhex(domain(31337, f.host)[2:])
                + bytes.fromhex(keccak256(body)[2:]))
            receipt[10] = keccak256(bundle)
        lane = [r for i, r in enumerate(f.rows) if i < fixture.row_index and r[1][3] == value[3]]
        receipt[4], receipt[5] = len(lane), ZERO
        digest = native_record_hash(31337, f.host, tuple(value), tuple(receipt))
        receipt[5] = chain_hash(7, value[3], lane[-1][2][5] if lane else ZERO, digest, len(lane))
        f.rows[fixture.row_index] = (digest, tuple(value), tuple(receipt), payload, bundle,
            evidence, (1, 7, int(token_id), ZERO))
        fixture.record_hash, fixture.payload, fixture.semantic_value = digest, payload, semantic
        f.install_v2_state()
    source = fixture.source(); selection, selection_hash = fixture.selection(source)
    original = dossier.build(source, selection, selection_hash, disclosure='public')
    files = dict(original.files)
    snapshot = loads(files['semantics/snapshot.json'], maximum=adapter.MAX_BYTES)
    row = next(r for r in snapshot['statements'] if r['source']['recordHash'] == fixture.record_hash)
    plan = {'version': '2', 'kind': adapter.GENERAL, 'manifestHash': original.manifest_hash,
        'occurrenceId': None, 'selector': row['source'], 'tokenId': token_id}
    raw = dumps(plan)
    return {'files': files, 'source_hash': original.manifest_hash, 'plan_raw': raw,
        'plan_hash': keccak256(raw), 'citation': canonical_citation(f.anchor['chainId'], f.anchor['core'], token_id),
        'snapshot': snapshot, 'row': row}


@lru_cache(maxsize=1)
def owner_v4_case():
    from .canonical_object_dossier_fixture_v4 import canonical_case
    original = canonical_case()
    checked = adapter.canonical_dossier.compose(dict(original.files), original.manifest_hash, disclosure='public')
    files = dict(checked.files)
    inv = adapter.inventory._extract(files, checked.manifest_hash)
    value = loads(inv.inventory, maximum=adapter.MAX_BYTES)
    row = next(r for r in value['occurrences'] if r['family'] == 'LOAN'
        and r['selector']['kind'] == 'native_owner_family' and r['interpretation']['status'] == 'interpreted')
    state = value['sourceState']
    plan = {'version': '2', 'kind': adapter.CANONICAL, 'manifestHash': checked.manifest_hash,
        'occurrenceId': row['occurrenceId'], 'selector': row['selector'], 'tokenId': state['tokenId']}
    raw = dumps(plan)
    return {'files': files, 'source_hash': checked.manifest_hash, 'plan_raw': raw,
        'plan_hash': keccak256(raw), 'citation': canonical_citation(state['chainId'], state['core'], state['tokenId']),
        'inventory': value, 'row': row}


def admit(case, *, plan=None, files=None):
    raw = case['plan_raw'] if plan is None else dumps(plan)
    return adapter.admit(case['files'] if files is None else files, case['source_hash'], raw,
        case['plan_hash'] if plan is None else keccak256(raw), disclosure='public')


class CurrentAuthoringSourceTests(unittest.TestCase):
    def test_general_concrete_token_replay_keeps_operator_and_disputed_selection(self):
        case = general_case()
        with patch('socket.socket', side_effect=AssertionError('network disabled')):
            result = admit(case)
        binding = result.binding
        self.assertEqual(binding['subject']['workCitation'], case['citation'])
        self.assertEqual(binding['originalEvidence']['original'], case['row']['original'])
        self.assertEqual(binding['originalEvidence']['payload'], case['row']['value'])
        self.assertEqual(binding['originalEvidence']['authority']['verificationClass'], 'OPERATOR_ASSERTED')
        self.assertTrue(binding['selection']['withheld'])
        self.assertFalse(binding['claims']['currentAuthorityProven'])
        self.assertEqual(result.report['sourceProvenance'], 'synthetic_fixture')
        for ref in binding['originalEvidence']['references'].values():
            adapter._resolve(case['files'], ref)

    def test_general_signed_institution_retains_exact_authority_without_institution_standing(self):
        case = general_case(authority='institution', review_status='unreviewed')
        result = admit(case)
        authority = result.binding['originalEvidence']['authority']
        self.assertEqual(authority['verificationClass'], 'SIGNER_VERIFIED')
        self.assertFalse(authority['namedInstitutionIdentityProven'])
        self.assertFalse(result.binding['claims']['authorConfirmationProven'])

    def test_concrete_collection_original_cannot_be_cast_to_token(self):
        with self.assertRaisesRegex(MuseumError, 'exact token subject'):
            admit(general_case(token=False))

    def test_whole_general_selector_is_exact_not_record_hash_only(self):
        case = general_case(); plan = loads(case['plan_raw'])
        plan['selector']['recorder'] = '0x' + '99' * 20
        with self.assertRaisesRegex(MuseumError, 'selector absent'):
            admit(case, plan=plan)
        plan = loads(case['plan_raw']); plan['selector']['pointer'] = '/assertions/0'
        with self.assertRaisesRegex(MuseumError, 'whole General'):
            admit(case, plan=plan)

    def test_wrong_token_citation_subject_rejected(self):
        case = general_case(); plan = loads(case['plan_raw']); plan['tokenId'] = '42'
        with self.assertRaisesRegex(MuseumError, 'exact token subject'):
            admit(case, plan=plan)

    def test_full_v4_replay_selects_historical_loan_and_retains_all_family_denominator(self):
        case = owner_v4_case()
        with patch('socket.socket', side_effect=AssertionError('network disabled')):
            result = admit(case)
        b = result.binding
        self.assertEqual(b['subject']['workCitation'], case['citation'])
        self.assertEqual(b['originalEvidence']['family'], 'LOAN')
        self.assertEqual(b['originalEvidence']['currentness']['status'], 'historical_original')
        self.assertEqual(b['inventory']['occurrenceCount'], str(len(case['inventory']['occurrences'])))
        self.assertTrue(any(r['family'] == 'OWNER_UNKNOWN' for r in case['inventory']['occurrences']))
        self.assertFalse(b['claims']['coreTokenMembershipProven'])
        self.assertEqual(result.report['sourceProvenance'], 'synthetic_fixture')
        self.assertEqual(adapter._resolve(case['files'], b['originalEvidence']['references']['payload']),
            bytes.fromhex(b['originalEvidence']['payloadHex'][2:]))

    def test_v4_opaque_original_not_promoted_to_semantic_binding(self):
        case = owner_v4_case(); plan = loads(case['plan_raw'])
        row = next(r for r in case['inventory']['occurrences'] if r['family'] == 'OWNER_UNKNOWN')
        plan.update(occurrenceId=row['occurrenceId'], selector=row['selector'])
        with self.assertRaisesRegex(MuseumError, 'unsupported canonical interpretation'):
            admit(case, plan=plan)

    def test_v4_occurrence_id_and_exact_selector_both_required(self):
        case = owner_v4_case(); plan = loads(case['plan_raw']); plan['selector']['sourceId'] = 'changed'
        with self.assertRaisesRegex(MuseumError, 'occurrence/selector differs'):
            admit(case, plan=plan)

    def test_rehashed_source_snapshot_mutation_fails_concrete_reconstruction(self):
        case = general_case(); files = dict(case['files'])
        snapshot = loads(files['semantics/snapshot.json'], maximum=adapter.MAX_BYTES)
        snapshot['statements'][0]['authority']['currentAuthorityRevalidated'] = True
        files['semantics/snapshot.json'] = dumps(snapshot)
        manifest = loads(files['manifest.json'], maximum=adapter.package.MAX_MANIFEST)
        manifest['files'] = [adapter.package._ref(p, raw) for p, raw in sorted(files.items()) if p != 'manifest.json']
        files['manifest.json'] = dumps(manifest); digest = keccak256(files['manifest.json'])
        plan = loads(case['plan_raw']); plan['manifestHash'] = digest; raw = dumps(plan)
        with self.assertRaises(MuseumError):
            adapter.admit(files, digest, raw, keccak256(raw), disclosure='public')

    def test_public_preflight_precedes_all_input_reads(self):
        class Exploding(dict):
            def __len__(self): raise AssertionError('input read')
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            adapter.admit(Exploding(), None, None, None, disclosure='private')

    def test_external_pins_closed_plan_canonical_uint_and_paths(self):
        case = general_case()
        with self.assertRaises(MuseumError):
            adapter.admit(case['files'], case['source_hash'], case['plan_raw'], '0x' + '01' * 32, disclosure='public')
        for change in ({'tokenId': '041'}, {'tokenId': 41}, {'extra': None}, {'kind': 'owner_record_source'}):
            with self.subTest(change=change), self.assertRaises(MuseumError):
                admit(case, plan={**loads(case['plan_raw']), **change})
        files = dict(case['files']); files['../escape'] = b'x'
        with self.assertRaises(MuseumError): admit(case, files=files)


if __name__ == '__main__':
    unittest.main()
