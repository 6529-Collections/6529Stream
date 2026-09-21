"""Definition and ABI checks against the retained df6363 native schema bytes."""
import json
import re
import unittest

from . import view_preservation_reference_types_v1 as t
from . import policy_preservation_types_v2 as old
from .canonical import MuseumError, keccak256, schema_id
from .chain_abi import Array, decode, encode, width


def schema_kind(node):
    """Independent descriptor translation of the original compiler-style schema."""
    value = node['type']
    if value.endswith('[]'):
        limits = {'captures': 2, 'samples': 2, 'packageFiles': 4096,
                  'platformPrerequisites': 4096, 'policies': 630}
        return Array(schema_kind({**node, 'type': value[:-2]}), limits[node['name']])
    fixed = re.fullmatch(r'(.+)\[([1-9][0-9]*)\]', value)
    if fixed:
        return (schema_kind({**node, 'type': fixed[1]}),) * int(fixed[2])
    if value == 'tuple':
        return tuple(schema_kind(child) for child in node['components'])
    return 'uint8' if value == 'StreamFinalityScopeType' else value


def schema_signature(node):
    value = node['type']
    if value.startswith('tuple'):
        return '(' + ','.join(schema_signature(c) for c in node['components']) + ')' + value[5:]
    return 'uint8' if value == 'StreamFinalityScopeType' else value


def sample(kind):
    """Non-semantic ABI vector; publication/source authenticity is not asserted."""
    if isinstance(kind, Array):
        return (sample(kind.item),)
    if isinstance(kind, tuple):
        return tuple(sample(k) for k in kind)
    if kind == 'address':
        return '0x' + '12' * 20
    if kind == 'bool':
        return True
    if kind == 'string':
        return 'original UTF-8: \u03b1'
    if kind == 'bytes':
        return b'exact original bytes\x00\xff'
    if kind.startswith('bytes'):
        return '0x' + '34' * int(kind[5:])
    return 7


class ReferenceTypesTests(unittest.TestCase):
    def test_exact_native_definition_bytes_and_kinds(self):
        expected = (
            (20629, '0x02f129343fa85335c68732f44a41361ac0891401de7fb6a2037c42c2bba212a2', 0),
            (1553, '0x7d57b0f7d128ad476120e43445c6361a80089baa1205b75d776bdcadad5ed684', 2),
            (870, '0x63cdb25fc76dd8d9cbbdd8be7f1444c092b0bf96f6a0199a7bee20abe2107491', 1),
            (2236, '0xe09ea65b22dccf9a9528b0ec4c940a831be48a060f0a095157a65aff5b290b90', 0),
            (286, '0x06dacccbad9218d04f77cbfdd597dfa61e2cab5b58c0fb8f5a1344ce301cb489', 0),
            (351, '0xb3cedd289be34a31fcd20d1941c86e28f31723e4c61f11ddf87894cda4903cac', 0),
            (422, '0x91a426d25d6e00c056cea336611731171bfe84e1b90bf10f7e2e0d0edc6d8c03', 2),
        )
        rows = t.definitions()
        self.assertEqual(len(rows), 7)
        self.assertEqual(len({r['id'] for r in rows}), 7)
        for row, (size, digest, kind) in zip(rows, expected):
            self.assertEqual(set(row), {'name', 'id', 'kind', 'hash', 'bytes'})
            self.assertEqual((len(row['bytes']), row['hash'], row['kind']), (size, digest, kind))
            self.assertEqual(row['hash'], keccak256(row['bytes']))
            self.assertEqual(row['id'], schema_id(row['name']))
        self.assertNotIn(schema_id('RFC8785_JCS'), {r['id'] for r in rows})
        self.assertEqual(t.SOURCE_REVISION, 'df6363e571dbff8fb61c192b2282733ccb3f1af8')

    def test_all_nested_descriptors_match_original_schema(self):
        native = json.loads(t.SCHEMA_BYTES)['types']
        for name, descriptor in (('Publication', t.PUBLICATION), ('Receipt', t.RECEIPT),
                                 ('SourceFacts', t.SOURCE), ('Dependencies', t.DEPENDENCIES)):
            with self.subTest(name=name):
                self.assertEqual(schema_kind(native[name]), descriptor)

    def test_view_source_and_sample_are_distinct_from_collection_reference(self):
        self.assertEqual(t.OBSERVATION, old.REFERENCE_OBSERVATION)
        self.assertEqual(t.OBSERVATION_RECEIPT, old.REFERENCE_RECORD)
        self.assertNotEqual(t.SOURCE, old.REFERENCE_SOURCE)
        self.assertEqual(t.SAMPLE[1], t.OUTPUT)
        self.assertEqual(t.SOURCE[-1], Array(t.SAMPLE, 2))
        self.assertEqual(len(t.ROOT_BINDING), 28)

    def test_native_static_return_widths(self):
        for value, expected in ((t.DEPENDENCIES, 608), (t.RECEIPT, 672),
                                (t.LOCK, 128), (t.OUTPUT, 992), (t.SAMPLE, 1504),
                                (t.COVERAGE, 480), (t.OBJECT, 320)):
            self.assertEqual(width(value), expected)
            self.assertEqual(len(encode((value,), (sample(value),))), expected)

    def test_full_nested_payload_roundtrip_preserves_original_bytes(self):
        values = tuple(sample(kind) for kind in t.PAYLOAD)
        raw = encode(t.PAYLOAD, values)
        self.assertLess(len(raw), t.MAX_PAYLOAD)
        self.assertEqual(decode(t.PAYLOAD, raw, maximum=t.MAX_PAYLOAD), values)
        self.assertEqual(encode(t.PAYLOAD, decode(t.PAYLOAD, raw, maximum=t.MAX_PAYLOAD)), raw)
        with self.assertRaisesRegex(MuseumError, 'noncanonical'):
            decode(t.PAYLOAD, raw + bytes(32), maximum=t.MAX_PAYLOAD)

    def test_receipt_class_and_bool_padding_reject(self):
        raw = bytearray(encode((t.RECEIPT,), (sample(t.RECEIPT),)))
        raw[13 * 32:14 * 32] = (256).to_bytes(32, 'big')
        with self.assertRaisesRegex(MuseumError, 'overflow'):
            decode((t.RECEIPT,), bytes(raw))
        output = list(sample(t.OUTPUT))
        raw = bytearray(encode((t.OUTPUT,), (tuple(output),)))
        raw[4 * 32:5 * 32] = (2).to_bytes(32, 'big')
        with self.assertRaisesRegex(MuseumError, 'bool'):
            decode((t.OUTPUT,), bytes(raw))

    def test_capture_sample_policy_and_file_arrays_are_bounded(self):
        for descriptor in (t.OBSERVATION[7], t.SOURCE[-1],
                           t.SNAPSHOT_SOURCE[6][-1], t.ENVIRONMENT[12], t.ENVIRONMENT[13]):
            with self.subTest(maximum=descriptor.maximum):
                item = sample(descriptor.item)
                with self.assertRaisesRegex(MuseumError, 'array bound'):
                    encode((descriptor,), ((item,) * (descriptor.maximum + 1),))
                # The length guard fires before attempting to allocate/decode rows.
                oversized = (32).to_bytes(32, 'big') + (descriptor.maximum + 1).to_bytes(32, 'big')
                with self.assertRaisesRegex(MuseumError, 'array bound'):
                    decode((descriptor,), oversized)

    def test_signatures_match_schema_including_fixed_capture_array(self):
        native = json.loads(t.SCHEMA_BYTES)['types']
        self.assertEqual(t.PUBLICATION_SIGNATURE, schema_signature(native['Publication']))
        self.assertEqual(t.RECEIPT_SIGNATURE, schema_signature(native['Receipt']))
        observation = native['Publication']['components'][1]
        self.assertEqual(t.OBSERVATION_SIGNATURE, schema_signature(observation))
        self.assertEqual(t.ENVIRONMENT_SIGNATURE, schema_signature(observation['components'][8]))
        self.assertIn('bytes32[2]', t.CAPTURE_SIGNATURE)
        self.assertEqual(set(t.FUNCTIONS), set(t.SIGNATURES))
        self.assertEqual(len(t.FUNCTIONS), 20)
        self.assertEqual(t.INTERFACE_ID, '0x6a86e409')
        self.assertEqual(t.SELECTORS['publishReference'], '0x3d620828')
        self.assertEqual(t.SELECTORS['previewReference'], '0xc3b2c07f')
        self.assertEqual(t.INVENTORY_PREPARATION_INTERFACE_ID, '0x08e1f36a')
        self.assertEqual(t.ENVIRONMENT_PREPARATION_INTERFACE_ID, '0xe5dc1cfc')

    def test_event_signature_includes_whole_outer_receipt(self):
        native = json.loads(t.SCHEMA_BYTES)['types']
        signature = ('ViewPreservationReferencePublished(uint16,bytes32,bytes32,bytes32,' +
                     schema_signature(native['Receipt']) + ',string)')
        self.assertEqual(t.EVENTS['published'], schema_id(signature))
        self.assertEqual(t.EVENTS['published'],
                         '0x70343cf06406552e60b39497d31723f1755826758d6765f614f8135dd7f2a4c8')
        self.assertEqual(t.EVENT_INDEXED['published'], ('scopeSubject', 'referenceId', 'recordHash'))
        data = (1, sample(t.RECEIPT), 'ipfs://original')
        self.assertEqual(decode(t.EVENT_DATA['published'], encode(t.EVENT_DATA['published'], data)), data)

    def test_distinct_domains_match_exact_canonicalization_document(self):
        canon = json.loads(t.CANON_BYTES)
        for key in ('payload', 'source', 'record', 'chain'):
            self.assertEqual(t.DOMAIN_NAMES[key], canon[key + 'Domain'])
            self.assertEqual(t.DOMAIN[key], schema_id(canon[key + 'Domain']))
        self.assertEqual(len(set(t.DOMAIN.values())), 6)
        self.assertNotEqual(t.PAYLOAD_DOMAIN, schema_id('6529STREAM_POLICY_REFERENCE_PAYLOAD_V2'))
        self.assertNotEqual(t.SOURCE_DOMAIN, schema_id('6529STREAM_SCOPED_REFERENCE_SOURCES_V1'))


if __name__ == '__main__':
    unittest.main()
