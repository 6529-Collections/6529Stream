"""Adversarial retained-source denominator and target correspondence controls."""
from copy import deepcopy
import unittest

from . import native_multiformat_ledger_v2 as ledger
from .canonical import MuseumError, dumps, keccak256, loads
from .test_native_multiformat_ledger_v1 import sample as native_sample

PINS = {'premis': '0x' + 'ab' * 32, 'iiif': '0x' + 'cd' * 32}
IDENTIFIER = '0x' + 'ef' * 32
PATH = 'premis/supplemental-source-inventory.json'


def sample():
    """Pure controls with manually enumerated original leaves, not V4 admission."""
    native, files = native_sample()
    original = {'title': 'Same declared title', 'acts': [{'use/name': 'denied', 'condition': None}],
        'empty': [], 'recordedAt': '1720000000'}
    raw = dumps({'unrelated': 'not in the selected original domain', 'payloadHex': '0x' + dumps(original).hex()})
    source_files = {'retained.json': raw}
    ref = {'path': 'source/retained.json', 'hash': keccak256(raw),
        'jsonPointer': '/payloadHex', 'encoding': 'hex'}
    fields = [{'occurrenceId': IDENTIFIER, 'domain': 'retained_source', 'pointer': pointer,
        'presence': 'present', 'exactHex': '0x' + dumps(value).hex()}
        for pointer, value in [('/title', original['title']), ('/acts/0/use~1name', 'denied'),
            ('/acts/0/condition', None), ('/empty', []), ('/recordedAt', '1720000000')]]
    occurrence = {'occurrenceId': IDENTIFIER, 'family': 'NATIVE_RIGHTS_NOTICE',
        'selector': {'record': 'original'}, 'domains': [{'name': 'retained_source', 'source': ref}]}
    files[PATH] = dumps({'profileHash': PINS['premis'], 'occurrences': [occurrence], 'fields': fields})
    files['iiif/supplemental-source-inventory.json'] = dumps({
        'profileHash': PINS['iiif'], 'occurrences': [], 'fields': []})
    path = 'premis/target.xml'
    raw = b'<premis:premis xmlns:premis="http://www.loc.gov/premis/v3"><premis:note>denied</premis:note></premis:premis>'
    files[path] = raw
    files['premis/provenance.json'] = dumps({'rows': [{'occurrenceId': IDENTIFIER,
        'target': {'path': path, 'hash': keccak256(raw), 'xpath': '/premis:premis/premis:note'},
        'targetValue': 'denied', 'rule': 'original-documentary-status',
        'sources': [{'domain': 'retained_source', 'sourceReference': ref,
            'pointer': '/acts/0/use~1name', 'exactHex': '0x' + dumps('denied').hex()}]}]})
    return native, files, source_files


def build(native, files, sources):
    return ledger.build(native, files, source_files=sources, supplemental_profiles=PINS)


class NativeMultiformatLedgerV2Tests(unittest.TestCase):
    def test_complete_original_domains_have_separate_field_and_family_denominators(self):
        native, files, sources = sample(); result = build(native, files, sources)
        self.assertEqual(len(loads(result[ledger.LEDGER_PATH])['rows']), len(loads(native)['fields']))
        native_families = loads(result[ledger.FAMILIES_PATH])
        self.assertEqual(native_families['denominators'], loads(native)['denominators'])
        self.assertEqual(sum(row['fieldCount'] for row in native_families['families']), len(loads(native)['fields']))
        separate = loads(result[ledger.SUPPLEMENTAL_FAMILIES_PATH])
        self.assertFalse(separate['originalNativeDenominatorExpanded'])
        self.assertEqual(len(separate['families']), 1)
        self.assertEqual(separate['families'][0]['fieldCount'], 5)
        self.assertEqual(separate['families'][0]['mappedFields']['premis'], 1)
        self.assertEqual(len(loads(result[ledger.SUPPLEMENTAL_LEDGER_PATH])['rows']), 5)

    def test_omitted_null_empty_unselected_or_added_source_leaf_is_refused(self):
        for index in range(5):
            native, files, sources = sample(); value = loads(files[PATH])
            del value['fields'][index]; files[PATH] = dumps(value)
            with self.subTest(index=index), self.assertRaisesRegex(MuseumError, 'complete original field denominator'):
                build(native, files, sources)
        native, files, sources = sample(); value = loads(files[PATH])
        value['fields'].append({**value['fields'][0], 'pointer': '/invented'})
        files[PATH] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'complete original field denominator'):
            build(native, files, sources)

    def test_coherent_field_and_proof_rewrite_cannot_replace_original_status(self):
        native, files, sources = sample(); value = loads(files[PATH])
        field = next(f for f in value['fields'] if f['pointer'] == '/acts/0/use~1name')
        field['exactHex'] = '0x' + dumps('granted').hex(); files[PATH] = dumps(value)
        proof = loads(files['premis/provenance.json'])
        proof['rows'][0]['sources'][0]['exactHex'] = field['exactHex']
        files['premis/provenance.json'] = dumps(proof)
        with self.assertRaisesRegex(MuseumError, 'complete original field denominator'):
            build(native, files, sources)

    def test_supplemental_source_hash_pointer_encoding_and_profile_are_checked(self):
        for change in ('hash', 'pointer', 'encoding', 'profile', 'outside_original'):
            native, files, sources = sample(); value = loads(files[PATH])
            ref = value['occurrences'][0]['domains'][0]['source']
            if change == 'hash': ref['hash'] = PINS['iiif']
            elif change == 'pointer': ref['jsonPointer'] = '/missing'
            elif change == 'encoding': ref['encoding'] = 'unsupported'
            elif change == 'profile': value['profileHash'] = PINS['iiif']
            else: ref['path'] = 'premis/target.xml'
            files[PATH] = dumps(value)
            with self.subTest(change=change), self.assertRaises(MuseumError): build(native, files, sources)

    def test_duplicate_domains_fields_and_occurrence_collisions_are_refused(self):
        for change in ('domain', 'field', 'occurrence', 'native_id'):
            native, files, sources = sample(); value = loads(files[PATH])
            if change == 'domain': value['occurrences'][0]['domains'] *= 2
            elif change == 'field': value['fields'].append(deepcopy(value['fields'][0]))
            elif change == 'occurrence': value['occurrences'] *= 2
            else:
                identifier = loads(native)['occurrences'][0]['occurrenceId']
                value['occurrences'][0]['occurrenceId'] = identifier
                for field in value['fields']: field['occurrenceId'] = identifier
            files[PATH] = dumps(value)
            with self.subTest(change=change), self.assertRaises(MuseumError): build(native, files, sources)

    def test_equal_supplemental_title_does_not_join_native_title(self):
        native, files, sources = sample(); result = build(native, files, sources)
        comparisons = loads(result[ledger.COMPARISONS_PATH])['rows']
        self.assertEqual(len(comparisons), 1)
        self.assertEqual(comparisons[0]['origin'], 'native')
        self.assertNotEqual(comparisons[0]['occurrenceId'], IDENTIFIER)

    def test_actual_target_and_original_reference_must_both_match(self):
        for change in ('target_hash', 'target_value', 'source_ref', 'source_value', 'source_pointer'):
            native, files, sources = sample(); value = loads(files['premis/provenance.json'])
            proof = value['rows'][0]; source = proof['sources'][0]
            if change == 'target_hash': proof['target']['hash'] = PINS['iiif']
            elif change == 'target_value': proof['targetValue'] = 'granted'
            elif change == 'source_ref': source['sourceReference']['jsonPointer'] = ''
            elif change == 'source_value': source['exactHex'] = '0x00'
            else: source['pointer'] = '/acts/00/use~1name'
            files['premis/provenance.json'] = dumps(value)
            with self.subTest(change=change), self.assertRaises(MuseumError): build(native, files, sources)

    def test_other_adapter_cannot_promote_a_foreign_supplemental_occurrence(self):
        native, files, sources = sample(); proof = loads(files['premis/provenance.json'])['rows'][0]
        path = 'iiif/supplement.json'; raw = dumps({'status': 'denied'}); files[path] = raw
        proof['target'] = {'path': path, 'hash': keccak256(raw), 'pointer': '/status'}
        files['iiif/provenance.json'] = dumps({'rows': [proof]})
        with self.assertRaisesRegex(MuseumError, 'foreign supplemental occurrence'): build(native, files, sources)

    def test_operator_and_derived_rows_do_not_inflate_supplemental_native_mapping(self):
        for domain in ledger.prior.SPECIAL_DOMAINS:
            native, files, sources = sample(); value = loads(files['premis/provenance.json'])
            value['rows'][0]['sources'][0]['domain'] = domain
            files['premis/provenance.json'] = dumps(value)
            result = build(native, files, sources)
            family = loads(result[ledger.SUPPLEMENTAL_FAMILIES_PATH])['families'][0]
            self.assertEqual(family['mappedFields']['premis'], 0)


if __name__ == '__main__':
    unittest.main()
