"""Pure ledger adversarial controls; concrete admission is tested by the package."""
from copy import deepcopy
import unittest

from . import native_multiformat_ledger_v1 as ledger
from . import canonical_field_inventory_v1 as inventory
from .canonical import MuseumError, dumps, keccak256, loads


def sample():
    """Small synthetic field/target vectors, not an admitted native package."""
    occurrences, fields = [], []
    for index, family in enumerate(('WORK', 'LOAN')):
        occurrence_id = '0x' + str(index + 1) * 64
        ref = {'path': 'source/record-' + str(index) + '.json',
            'hash': '0x' + str(index + 3) * 64, 'jsonPointer': '', 'encoding': 'json'}
        occurrences.append({'occurrenceId': occurrence_id,
            'originalOccurrenceId': '0x' + str(index + 5) * 64, 'family': family,
            'domains': [{'name': 'payload', 'source': ref}]})
        rows, _ = inventory.fields({'title': 'Same declared title', 'amount': '9007199254740993'},
            {'type': 'object', 'properties': {'title': {'type': 'string'},
                'amount': {'type': 'string'}, 'optional': {'type': 'string'}},
                'required': ['title', 'amount'], 'additionalProperties': False})
        fields.extend({'occurrenceId': occurrence_id, 'domain': 'payload', **row} for row in rows)
    source = dumps({'profileHash': inventory.PROFILE_HASH, 'occurrences': occurrences,
        'fields': fields, 'denominators': [{'family': name, 'originalCount': '1'} for name in ('WORK', 'LOAN')]})
    files = {name + '/provenance.json': dumps({'rows': []}) for name in ledger.FORMATS}
    for name, value in (('linked-art', 'Same declared title'), ('iiif', 'Same declared title')):
        path = name + '/target.json'; raw = dumps({'title': value}); files[path] = raw
        files[name + '/provenance.json'] = dumps({'rows': [{
            'occurrenceId': occurrences[0]['occurrenceId'],
            'target': {'path': path, 'hash': keccak256(raw), 'pointer': '/title'},
            'targetValue': value, 'rule': 'exact-title', 'sources': [{
                'domain': 'payload', 'sourceReference': occurrences[0]['domains'][0]['source'],
                'pointer': '/title', 'exactHex': '0x' + dumps(value).hex()}]}]})
    return source, files


def mutate_proof(files, name, change):
    value = loads(files[name + '/provenance.json']); change(value['rows'][0])
    files[name + '/provenance.json'] = dumps(value)


class NativeMultiformatLedgerTests(unittest.TestCase):
    def test_same_exact_field_compares_without_collapsing_equal_other_occurrence(self):
        source, files = sample(); result = ledger.build(source, files)
        value = loads(source); rows = loads(result[ledger.LEDGER_PATH], maximum=ledger.package.MAX_BYTES)['rows']
        self.assertEqual(len(rows), len(value['fields']))
        comparisons = loads(result[ledger.COMPARISONS_PATH])['rows']
        self.assertEqual(len(comparisons), 1)
        self.assertEqual(comparisons[0]['occurrenceId'], value['occurrences'][0]['occurrenceId'])
        pair = next(p for p in comparisons[0]['pairs'] if p['formats'] == ['linked-art', 'iiif'])
        self.assertEqual(pair['status'], 'equal_target_representations')
        families = loads(result[ledger.FAMILIES_PATH])['families']
        loan = next(f for f in families if f['family'] == 'LOAN')
        self.assertTrue(all(n == 0 for n in loan['mappedFields'].values()))
        for field, row in zip(value['fields'], rows):
            if field['presence'] == 'absent':
                self.assertTrue(all(f['disposition'] == 'not_applicable' for f in row['formats'].values()))

    def test_target_difference_is_retained_and_never_rewritten(self):
        source, files = sample(); path = 'iiif/target.json'
        files[path] = dumps({'title': 'Explicitly different representation'})
        mutate_proof(files, 'iiif', lambda p: p.update(targetValue='Explicitly different representation',
            rule='declared-transformation', target={'path': path, 'hash': keccak256(files[path]), 'pointer': '/title'}))
        result = ledger.build(source, files)
        row = loads(result[ledger.COMPARISONS_PATH])['rows'][0]
        pair = next(p for p in row['pairs'] if p['formats'] == ['linked-art', 'iiif'])
        self.assertEqual(pair['status'], 'different_target_representations')
        self.assertEqual(pair['targets']['iiif'][0]['value']['value'], 'Explicitly different representation')

    def test_wrong_reference_pointer_exact_value_and_target_hash_reject(self):
        for kind in ('reference', 'pointer', 'value', 'target_hash', 'target_value', 'wrong_format'):
            source, files = sample()
            def change(proof):
                item = proof['sources'][0]
                if kind == 'reference': item['sourceReference']['hash'] = '0x' + '11' * 32
                elif kind == 'pointer': item['pointer'] = '/not-present'
                elif kind == 'value': item['exactHex'] = '0x00'
                elif kind == 'target_hash': proof['target']['hash'] = '0x' + '11' * 32
                elif kind == 'target_value': proof['targetValue'] = 'invented'
                else: proof['target']['path'] = 'iiif/target.json'
            mutate_proof(files, 'linked-art', change)
            with self.subTest(kind=kind), self.assertRaises(MuseumError): ledger.build(source, files)

    def test_equal_value_from_different_occurrence_is_not_comparable(self):
        source, files = sample(); value = loads(source); second = value['occurrences'][1]
        mutate_proof(files, 'iiif', lambda p: (p.update(occurrenceId=second['occurrenceId']),
            p['sources'][0].update(sourceReference=second['domains'][0]['source'])))
        result = ledger.build(source, files)
        self.assertEqual(loads(result[ledger.COMPARISONS_PATH])['rows'], [])

    def test_operator_and_computed_byte_evidence_never_promote_native_field_count(self):
        for domain in ('operator_context', 'derived_bytes', 'original_identity'):
            source, files = sample()
            mutate_proof(files, 'linked-art', lambda p: p['sources'][0].update(domain=domain))
            result = ledger.build(source, files)
            families = loads(result[ledger.FAMILIES_PATH])['families']
            self.assertTrue(all(f['mappedFields']['linked-art'] == 0 for f in families))
            self.assertEqual(loads(result[ledger.COMPARISONS_PATH])['rows'], [])

    def test_large_exact_json_number_and_decimal_are_not_float_rounded(self):
        source, files = sample(); path = 'iiif/target.json'
        for raw, expected in ((b'{"title":9007199254740993}', {'kind': 'number', 'lexical': '9007199254740993'}),
                (b'{"title":9007199254740993.125}', {'kind': 'number', 'lexical': '9007199254740993.125'}),
                (b'{"title":0.00000000000000000000000000000100}',
                    {'kind': 'number', 'lexical': '0.00000000000000000000000000000100'})):
            files[path] = raw
            mutate_proof(files, 'iiif', lambda p: p.update(target={'path': path, 'hash': keccak256(raw),
                'pointer': '/title'}, targetValue=expected, rule='explicit-numeric-representation'))
            result = ledger.build(source, files)
            row = loads(result[ledger.COMPARISONS_PATH])['rows'][0]
            pair = next(p for p in row['pairs'] if p['formats'] == ['linked-art', 'iiif'])
            self.assertEqual(pair['targets']['iiif'][0]['value']['lexical'], str(expected) if type(expected) is int else expected['lexical'])

    def test_original_lido_occurrence_resolves_only_its_derived_native_id(self):
        source, files = sample(); value = loads(source); occurrence = value['occurrences'][0]
        path = 'lido/target.xml'; raw = b'<lido:lido xmlns:lido="http://www.lido-schema.org"><lido:title>Same declared title</lido:title></lido:lido>'
        files[path] = raw
        proof = loads(files['linked-art/provenance.json'])['rows'][0]
        proof.update(occurrenceId=occurrence['originalOccurrenceId'],
            target={'path': path, 'hash': keccak256(raw), 'xpath': '/lido:lido/lido:title'})
        files['lido/provenance.json'] = dumps({'rows': [proof]})
        result = ledger.build(source, files)
        self.assertEqual(loads(result[ledger.COMPARISONS_PATH])['rows'][0]['occurrenceId'], occurrence['occurrenceId'])
        proof['occurrenceId'] = occurrence['occurrenceId']; files['lido/provenance.json'] = dumps({'rows': [proof]})
        with self.assertRaises(MuseumError): ledger.build(source, files)

    def test_xml_xpath_expression_or_non_scalar_is_refused(self):
        source, files = sample(); value = loads(source)
        path = 'premis/target.xml'; raw = b'<premis:premis xmlns:premis="http://www.loc.gov/premis/v3"><premis:object><premis:value>x</premis:value></premis:object></premis:premis>'
        files[path] = raw
        for xpath in ('//premis:value', 'string(/premis:premis)', '/premis:premis/premis:object'):
            proof = loads(files['linked-art/provenance.json'])['rows'][0]
            proof.update(target={'path': path, 'hash': keccak256(raw), 'xpath': xpath}, targetValue='x')
            files['premis/provenance.json'] = dumps({'rows': [proof]})
            with self.subTest(xpath=xpath), self.assertRaises(MuseumError): ledger.build(source, files)


if __name__ == '__main__':
    unittest.main()
