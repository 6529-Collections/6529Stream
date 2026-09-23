"""Pure native-preimage vectors; no Store, archive, ZIP, or EVM assertions."""
from copy import deepcopy
import unittest

from . import view_preservation_reference_inventory_v1 as inventory
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id
from .chain_abi import Array, encode

HOST = '0x'+'12'*20
CONTEXT = {'chainId': '31337'}
DIGEST = '0x'+'ab'*32


def supplied(count=65, *, relative=True, rows=None, parts=True):
    rows = ([[f'file-{index:05d}.bin', str(index), DIGEST] for index in range(count)]
            if rows is None else deepcopy(rows))
    raw = inventory.files_bytes(rows, relative)
    result = {'relative': relative, 'rows': rows,
        'inventoryId': inventory.inventory_id(rows, relative, CONTEXT['chainId'], HOST),
        'contentHash': keccak256(raw), 'byteLength': str(len(raw)), 'payload': '0x'+raw.hex(),
        'parts': None}
    if parts:
        result['parts'] = []
        for start in range(0, len(rows), 64):
            group = rows[start:start+64]; body = inventory.files_bytes(group, relative)
            result['parts'].append({'partId': inventory.part_id(group, relative, CONTEXT['chainId'], HOST),
                'contentHash': keccak256(body), 'byteLength': str(len(body)), 'payload': '0x'+body.hex()})
    return result


class ViewPreservationReferenceInventoryTests(unittest.TestCase):
    def test_exact_canonical_row_vector_and_typed_id_domains(self):
        rows = [['a', '0', DIGEST]]
        raw = b'[{"byteSize":"0","path":"a","sha256Digest":"'+DIGEST.encode()+b'"}]'
        self.assertEqual(inventory.files_bytes(rows, True), raw)
        kinds = ('bytes32', 'uint256', 'address', 'bool', Array(('string', 'uint64', 'bytes32'), 1))
        for label, function in (('6529STREAM_REFERENCE_FILE_INVENTORY_V1', inventory.inventory_id),
                                ('6529STREAM_REFERENCE_FILE_INVENTORY_PART_V1', inventory.part_id)):
            expected = keccak256(encode(kinds, (schema_id(label), 31337, HOST, True, [('a', 0, DIGEST)])))
            self.assertEqual(function(rows, True, '31337', HOST), expected)
        self.assertNotEqual(inventory.inventory_id(rows, True, '31337', HOST),
                            inventory.part_id(rows, True, '31337', HOST))

    def test_uint64_decimal_exact_and_zero_size_accepted(self):
        value = supplied(rows=[['a', '0', DIGEST], ['b', str(2**64-1), DIGEST]])
        self.assertIn(b'"18446744073709551615"', inventory.validate(value, CONTEXT, HOST)['bytes'])
        for bad in ('18446744073709551616', '-1', '00', '1\n', True, 1.0):
            with self.subTest(bad=bad), self.assertRaises(MuseumError):
                inventory.files_bytes([['a', bad, DIGEST]], True)

    def test_full_fixed64_boundaries_and_empty_inventory(self):
        for count in (0, 1, 63, 64, 65, 128, 129):
            with self.subTest(count=count):
                value = supplied(count)
                result = inventory.validate(value, CONTEXT, HOST)
                self.assertEqual(result['bytes'], hex_bytes(value['payload']))
                self.assertEqual(len(result['derivedPartIds']), (count+63)//64)
                self.assertTrue(result['suppliedPartsChecked'])
        self.assertEqual(inventory.files_bytes([], True), b'[]')
        for rows in ([], supplied(65)['rows']):
            with self.assertRaises(MuseumError): inventory.part_id(rows, True, '31337', HOST)

    def test_whole_only_preparation_does_not_claim_published_parts(self):
        value = supplied(parts=False)
        result = inventory.validate(value, CONTEXT, HOST)
        self.assertFalse(result['suppliedPartsChecked'])
        self.assertEqual(len(result['derivedPartIds']), 2)
        for key in ('nativePreparationExecutionProven', 'publicationAuthorityVerified',
                'storeCarrierBytesVerified', 'archiveCoverageVerified', 'zipMembershipVerified',
                'actualFileDigestsMeasured'):
            self.assertFalse(result['claims'][key])

    def test_exact_json_escaping_and_utf8_byte_order(self):
        paths = ['C:\\bin\\a\t\n\r\b\f"\x00\x1f', 'é', '\ue000', '\U00010000']
        rows = [[path, '0', DIGEST] for path in paths]
        raw = inventory.files_bytes(rows, False)
        self.assertIn(b'C:\\\\bin\\\\a\\t\\n\\r\\b\\f\\"\\u0000\\u001f', raw)
        self.assertIn('é'.encode(), raw)
        self.assertLess(raw.index('\ue000'.encode()), raw.index('\U00010000'.encode()))
        self.assertEqual(raw, dumps([{'byteSize': '0', 'path': path, 'sha256Digest': DIGEST} for path in paths]))
        with self.assertRaises(MuseumError): inventory.files_bytes(list(reversed(rows)), False)

    def test_relative_path_rules_match_native_not_general_os_rules(self):
        for good in ('CON', ' leading/file', 'folder/a.b', 'a..b', 'name#[]'):
            with self.subTest(path=good): inventory.files_bytes([[good, 0, DIGEST]], True)
        for bad in ('', '/a', 'a/', 'a//b', '.', '..', 'a./b', 'a /b', 'a.', 'a ',
                    'a\\b', 'a:b', 'a<b', 'a>b', 'a"b', 'a|b', 'a?b', 'a*b', 'é', 'a\n'):
            with self.subTest(path=bad), self.assertRaises(MuseumError):
                inventory.files_bytes([[bad, 0, DIGEST]], True)
        # Non-relative means native UTF-8 quoting, not a requirement for an absolute prefix.
        inventory.files_bytes([['relative/is/allowed', 0, DIGEST]], False)

    def test_path_byte_bounds_and_surrogates(self):
        for relative, path in ((True, 'a'*1024), (False, 'é'*1024)):
            inventory.files_bytes([[path, 0, DIGEST]], relative)
            with self.assertRaises(MuseumError): inventory.files_bytes([[path+'x', 0, DIGEST]], relative)
        with self.assertRaises(MuseumError): inventory.files_bytes([['\ud800', 0, DIGEST]], False)

    def test_duplicate_and_cross_part_boundary_order(self):
        value = supplied(65)
        for mode in ('duplicate', 'reversed_boundary'):
            rows = deepcopy(value['rows'])
            rows[64][0] = rows[63][0] if mode == 'duplicate' else 'file-00000-a.bin'
            with self.subTest(mode=mode):
                # Each part alone remains canonical in the reversed-boundary case.
                inventory.files_bytes(rows[:64], True)
                inventory.files_bytes(rows[64:], True)
                with self.assertRaises(MuseumError): inventory.files_bytes(rows, True)

    def test_digest_required_and_closed_typed_rows(self):
        for row in (['a', 0, '0x'+'00'*32], ['a', 0, DIGEST.upper()], ['a', 0, DIGEST, 'extra'],
                    {'path': 'a', 'byteSize': '0', 'sha256Digest': DIGEST}):
            with self.subTest(row=row), self.assertRaises(MuseumError): inventory.files_bytes([row], True)
        with self.assertRaises(MuseumError): inventory.files_bytes([['a', 0, DIGEST]], 1)

    def test_whole_and_part_original_commitment_tampering(self):
        for field in ('inventoryId', 'contentHash', 'byteLength', 'payload'):
            value = supplied()
            value[field] = '1' if field == 'byteLength' else ('0x00' if field == 'payload' else schema_id('wrong'))
            with self.subTest(field=field), self.assertRaises(MuseumError): inventory.validate(value, CONTEXT, HOST)
        for field in ('partId', 'contentHash', 'byteLength', 'payload'):
            value = supplied()
            value['parts'][1][field] = '1' if field == 'byteLength' else ('0x00' if field == 'payload' else schema_id('wrong'))
            with self.subTest(field=field), self.assertRaises(MuseumError): inventory.validate(value, CONTEXT, HOST)

    def test_complete_part_denominator_order_and_partition(self):
        for mode in ('missing', 'extra', 'reordered', 'wrong_partition'):
            value = supplied(65)
            if mode == 'missing': value['parts'].pop()
            elif mode == 'extra': value['parts'].append(deepcopy(value['parts'][-1]))
            elif mode == 'reordered': value['parts'].reverse()
            else:
                # Honest 63-row part still does not identify the required first64 rows.
                value['parts'][0] = supplied(rows=value['rows'][:63])['parts'][0]
            with self.subTest(mode=mode), self.assertRaises(MuseumError): inventory.validate(value, CONTEXT, HOST)

    def test_domain_chain_host_and_relative_flag_are_not_interchangeable(self):
        value = supplied()
        for context, host in (({'chainId': '1'}, HOST), (CONTEXT, '0x'+'34'*20)):
            with self.assertRaises(MuseumError): inventory.validate(value, context, host)
        value['relative'] = False
        with self.assertRaises(MuseumError): inventory.validate(value, CONTEXT, HOST)
        for chain, host in (('0', HOST), ('31337', '0x'+'00'*20)):
            with self.assertRaises(MuseumError): inventory.inventory_id([], True, chain, host)

    def test_exact_retained_byte_ceiling_and_native_prefix_off_by_one(self):
        # Absolute paths may contain controls, whose native quote expansion is six bytes.
        rows = [[f'{i:04d}/'+'x'*1000, '0', DIGEST] for i in range(468)]
        baseline = len(inventory.files_bytes(rows, False))
        remaining = inventory.MAX_BYTES-baseline
        for index in range(len(rows)):
            add = min(2048-len(rows[index][0].encode()), remaining)
            rows[index][0] += 'y'*add
            remaining -= add
            if not remaining: break
        self.assertEqual(remaining, 0)
        self.assertEqual(len(inventory.files_bytes(rows, False)), inventory.MAX_BYTES)
        # Native files() alone permits its final bracket at MAX+1, but retain() rejects it.
        rows[-1][0] += 'z'
        with self.assertRaisesRegex(MuseumError, 'retained byte bound'): inventory.files_bytes(rows, False)

    def test_closed_inventory_and_descriptor_shapes(self):
        for target in ('whole', 'part'):
            value = supplied()
            (value if target == 'whole' else value['parts'][0])['unreviewed'] = True
            with self.assertRaises(MuseumError): inventory.validate(value, CONTEXT, HOST)
        value = supplied(); value['parts'] = ()
        with self.assertRaises(MuseumError): inventory.validate(value, CONTEXT, HOST)


if __name__ == '__main__': unittest.main()
