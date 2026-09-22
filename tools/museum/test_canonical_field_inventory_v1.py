"""Concrete V4 source replay plus independent structural/schema field controls."""
from copy import deepcopy
from decimal import Decimal
from functools import lru_cache
import unittest
from unittest.mock import patch

from . import canonical_field_inventory_v1 as inventory
from . import canonical_object_dossier_v4 as dossier
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id


@lru_cache(maxsize=1)
def complete():
    from .canonical_object_dossier_fixture_v4 import complete_case_v4
    case = complete_case_v4(); files, digest, options = case.inputs()
    original = dossier.compose(files, digest, **options)
    with patch('socket.socket', side_effect=AssertionError('network disabled')):
        evidence = inventory.build(dict(original.files), original.manifest_hash, disclosure='public')
    return original, evidence, loads(evidence.inventory, maximum=inventory.MAX_BYTES, canonical=True)


def resolve(value, pointer):
    for part in pointer[1:].split('/') if pointer else ():
        key = part.replace('~1', '/').replace('~0', '~')
        value = value[int(key)] if type(value) is list else value[key]
    return value


def structural(value):
    """Independent complete node set, including all nonempty containers."""
    todo = [('', value)]; result = {}
    while todo:
        pointer, node = todo.pop(); result[pointer] = node
        if type(node) is dict:
            todo.extend((pointer + '/' + key.replace('~', '~0').replace('/', '~1'), child)
                for key, child in node.items())
        elif type(node) is list:
            todo.extend((pointer + '/' + str(i), child) for i, child in enumerate(node))
    return result


class CanonicalFieldInventoryTests(unittest.TestCase):
    def test_full_original_v4_replay_all_ten_owner_and_supplemental_denominators(self):
        original, evidence, value = complete(); files = dict(original.files)
        old = loads(files['canonical/inputs/source-inventory.json'], maximum=inventory.MAX_BYTES)
        canonical_rows = [row for row in value['occurrences'] if row['originalOccurrenceId'] is not None]
        self.assertEqual([row['originalOccurrenceId'] for row in canonical_rows], [row['occurrenceId'] for row in old['rows']])
        self.assertEqual([row['selector'] for row in canonical_rows], [row['selector'] for row in old['rows']])
        typed_owners = {row['family'] for row in canonical_rows if row['selector']['kind'] == 'native_owner_family'
            and any(domain['name'] == 'payload' and domain['schema'] is not None for domain in row['domains'])}
        self.assertEqual(typed_owners, set(inventory.owners.FAMILIES))
        self.assertIn('ARTIST', {row['family'] for row in value['occurrences']})
        self.assertIn('GENERAL', {row['family'] for row in value['occurrences']})
        self.assertIn('DOCUMENTARY_METADATA', {row['family'] for row in value['occurrences']})
        general = loads(files['transfer/sources/general-dossier/semantics/snapshot.json'], maximum=inventory.MAX_BYTES)
        self.assertEqual(len([row for row in value['occurrences'] if row['family'] == 'GENERAL']), len(general['statements']))
        self.assertEqual(evidence.report['inventoryHash'], keccak256(evidence.inventory))
        self.assertFalse(value['claims']['targetFormatMappingProven'])
        self.assertFalse(value['claims']['globalSourceCompletenessProven'])

    def test_every_received_original_node_has_exact_path_hash_pointer_and_order(self):
        original, _, value = complete(); files = dict(original.files)
        parsed = {}; hashed = {}
        by_domain = {}
        for field in value['fields']: by_domain.setdefault((field['occurrenceId'], field['domain']), []).append(field)
        for occurrence in value['occurrences']:
            for domain in occurrence['domains']:
                ref = domain['source']; self.assertTrue(ref['path'].startswith('source/'))
                path = ref['path'].removeprefix('source/'); raw = files[path]
                if path not in hashed: hashed[path] = keccak256(raw)
                self.assertEqual(ref['hash'], hashed[path])
                if ref['encoding'] == 'bytes': node = loads(raw, maximum=inventory.MAX_BYTES)
                else:
                    if path not in parsed: parsed[path] = loads(raw, maximum=inventory.MAX_BYTES)
                    node = resolve(parsed[path], ref['jsonPointer'])
                    if ref['encoding'] == 'hex': node = loads(hex_bytes(node), maximum=inventory.MAX_BYTES)
                if 'decodePointer' in domain:
                    node = loads(resolve(node, domain['decodePointer']).encode('utf-8'), maximum=inventory.MAX_BYTES, canonical=True)
                actual = by_domain[(occurrence['occurrenceId'], domain['name'])]
                self.assertEqual([r['order'] for r in actual], list(map(str, range(len(actual)))))
                present = {r['pointer']: r for r in actual if r['presence'] == 'present'}
                expected = structural(node)
                self.assertEqual(set(present), set(expected))
                for pointer, child in expected.items():
                    exact = dumps(sorted(child) if type(child) is dict else str(len(child)) if type(child) is list else child)
                    self.assertEqual(present[pointer]['exactHex'], '0x' + exact.hex())
                    self.assertEqual(present[pointer]['disposition'], 'retained_stream_only')
                    self.assertTrue(present[pointer]['rule'] and present[pointer]['reason'])

    def test_selection_does_not_truncate_opaque_future_or_historical_occurrences(self):
        original, _, value = complete(); files = dict(original.files)
        selected = loads(files['canonical/inputs/selection.json'])['selectedOccurrenceIds']
        rows = [row for row in value['occurrences'] if row['originalOccurrenceId'] is not None]
        self.assertTrue(any(row['family'] == 'OWNER_UNKNOWN' for row in rows))
        self.assertTrue(any(row['interpretation']['status'] == 'opaque' for row in rows))
        self.assertTrue(any(not row['selection']['selected'] for row in rows))
        for row in rows:
            self.assertEqual(row['selection']['selected'], row['originalOccurrenceId'] in selected)
            if row['interpretation']['status'] == 'opaque':
                self.assertFalse(any(domain['name'] == 'payload' for domain in row['domains']))
                self.assertTrue(any(field['occurrenceId'] == row['occurrenceId'] for field in value['fields']))
        self.assertTrue(all(field['disposition'] in ('retained_stream_only', 'not_applicable') for field in value['fields']))

    def test_literal_bodies_are_exact_conventions_not_registered_schema_or_format_mapping(self):
        _, _, value = complete()
        domains = [domain for row in value['occurrences'] for domain in row['domains'] if domain['name'].startswith('literal_body_')]
        self.assertEqual({domain['convention'] for domain in domains}, {'physical_production', 'physical_transfer'})
        for domain in domains:
            self.assertIsNone(domain['schema'])
            self.assertEqual(domain['applicability'], 'original_literal_convention_no_schema')
            self.assertTrue(domain['decodePointer'].endswith('/object/literal/lexicalValue'))

    def test_applicable_absent_null_empty_and_ordered_duplicate_values(self):
        schema = {'type': 'object', 'properties': {'nullable': {'type': ['string', 'null']},
            'optional': {'type': 'string'}, 'ordered': {'type': 'array', 'items': {'type': 'string'}},
            'empty': {'type': 'object', 'properties': {}, 'additionalProperties': False}},
            'required': ['nullable', 'ordered', 'empty'], 'additionalProperties': False}
        rows, _ = inventory.fields({'nullable': None, 'ordered': ['x', 'x', 'y'], 'empty': {}}, schema)
        by_pointer = {row['pointer']: row for row in rows}
        self.assertEqual(by_pointer['/optional']['presence'], 'absent')
        self.assertEqual(by_pointer['/optional']['disposition'], 'not_applicable')
        self.assertEqual(by_pointer['/optional']['exactHex'], '0x')
        self.assertEqual(by_pointer['/nullable']['kind'], 'null')
        self.assertEqual(by_pointer['/empty']['exactHex'], '0x' + dumps([]).hex())
        self.assertEqual([by_pointer['/ordered/' + str(i)]['exactHex'] for i in range(3)],
            ['0x' + dumps(v).hex() for v in ('x', 'x', 'y')])

    def test_tagged_branch_local_refs_and_typed_decimal_do_not_create_inactive_absence(self):
        schema = {'$defs': {'text': {'type': 'string'}}, 'oneOf': [
            {'type': 'object', 'properties': {'kind': {'const': 'a'}, 'a': {'$ref': '#/$defs/text'},
                'optional': {'type': 'string'}}, 'required': ['kind', 'a'], 'additionalProperties': False},
            {'type': 'object', 'properties': {'kind': {'const': 'b'}, 'b': {'type': 'string'}},
                'required': ['kind', 'b'], 'additionalProperties': False}]}
        rows, branches = inventory.fields({'kind': 'a', 'a': 'e\u0301', 'optional': '1.250'}, schema)
        by_pointer = {row['pointer']: row for row in rows}
        self.assertNotIn('/b', by_pointer)
        self.assertIn('#/$defs/text', by_pointer['/a']['schemaLocations'])
        self.assertEqual(by_pointer['/optional']['kind'], 'string')
        self.assertEqual(by_pointer['/optional']['exactHex'], '0x' + dumps('1.250').hex())
        self.assertEqual(branches[0]['applicable'], ['#/oneOf/0'])
        # Frozen source admission itself forbids fractional JSON numbers.
        with self.assertRaises(MuseumError): inventory.fields(Decimal('1.25'), {'type': 'number'})

    def test_bad_schema_values_external_dynamic_and_depth_fail_closed_without_network(self):
        with patch('socket.socket', side_effect=AssertionError('schema attempted network')):
            for schema in ({'$ref': 'https://example.test/schema'}, {'$dynamicRef': '#meta'},
                    {'type': 'string'}, {'type': 'object', 'properties': {}, 'additionalProperties': False}):
                with self.subTest(schema=schema), self.assertRaises(MuseumError): inventory.fields({'a': 1}, schema)
        value = None
        for _ in range(inventory.MAX_DEPTH + 2): value = {'a': value}
        with self.assertRaisesRegex(MuseumError, 'bound'): inventory.fields(value)

    def test_public_preflight_and_wrong_external_manifest_refuse(self):
        class Unreadable:
            def keys(self): raise AssertionError('read before public guard')
        with self.assertRaisesRegex(MuseumError, 'public'):
            inventory.build(Unreadable(), schema_id('absent'), disclosure='restricted')
        with self.assertRaises(MuseumError):
            inventory.build({'manifest.json': b'{}'}, schema_id('wrong'), disclosure='public')

    def test_rehashed_original_schema_cannot_override_nested_concrete_replay(self):
        original, _, _ = complete(); files = dict(original.files)
        path = 'canonical/definitions/native-source/STREAM_WORK_DESCRIPTION_V1.json'
        files[path] = dumps({'$schema': 'https://json-schema.org/draft/2020-12/schema', 'type': 'object'})
        manifest = loads(files['manifest.json'], maximum=inventory.MAX_BYTES)
        manifest['files'] = [inventory.package._ref(p, raw) for p, raw in sorted(files.items()) if p != 'manifest.json']
        files['manifest.json'] = dumps(manifest)
        with self.assertRaises(MuseumError): inventory.build(files, keccak256(files['manifest.json']), disclosure='public')

    def test_original_conservation_records_and_catalogs_use_actual_retained_schema_bytes(self):
        from . import conservation_dossier_v1 as conservation
        from .test_conservation_dossier_v1 import captured, fixtures
        capture, _ = captured(fixtures()['av'])
        checked = conservation.build(dict(capture.files), capture.manifest_hash, disclosure='public')
        # Exercise only the internal family extractor on a real independently
        # replayed conservation family. This does not pretend it is a V4 source.
        files = {'canonical/input/conservation/source/' + path: raw for path, raw in checked.files}
        builder = inventory._Builder(files, checked.manifest_hash); builder.conservation()
        snapshot = loads(files['canonical/input/conservation/source/input/source/snapshot.json'], maximum=inventory.MAX_BYTES)
        self.assertEqual(len(builder.rows), len(snapshot['records']))
        self.assertTrue(any(domain['name'].startswith('catalog_') for row in builder.rows for domain in row['domains']))
        self.assertTrue(all(any(domain['name'] == 'payload' and domain['schema'] is not None
            for domain in row['domains']) for row in builder.rows))

    def test_optional_artist_child_general_originals_keep_their_own_account_authority(self):
        from .chain_rpc import ReplayTransport
        from .test_general_attestation_source import Fixture as V1
        from .test_general_attestation_source_v2 import Fixture as V2
        for fixture in (V1(), V2()):
            source = fixture.reader(); raw = source.snapshot(); transcript = source.transcript()
            replay = type(source)(source.anchor_bytes, ReplayTransport(transcript, keccak256(transcript)), provenance='synthetic_fixture')
            self.assertEqual(replay.snapshot(), raw)
            prefix = 'production/sources/attribution/sources/general/'
            files = {prefix + 'snapshot.json': raw}
            builder = inventory._Builder(files, schema_id('internal validated General extraction'))
            builder.general_originals(prefix)
            snapshot = loads(raw, maximum=inventory.MAX_BYTES)
            self.assertEqual(len(builder.rows), len(snapshot['records']))
            for row, original in zip(builder.rows, snapshot['records']):
                self.assertEqual(row['family'], 'GENERAL_ORIGINAL')
                self.assertEqual(row['authority'], original['interpretation'])
                self.assertEqual(row['selector']['recordHash'], original['recordHash'])
                self.assertEqual(row['selector']['host'], snapshot['host'])
                self.assertFalse(row['selection']['selected'])
            self.assertTrue(any(row['interpretation']['status'] == 'schema_shape_only' for row in builder.rows))

    def test_internal_schema_alias_cannot_be_labeled_as_the_named_definition(self):
        from .test_general_attestation_source import Fixture
        source = Fixture().reader(); snapshot = loads(source.snapshot(), maximum=inventory.MAX_BYTES)
        prefix = 'production/sources/attribution/sources/general/'
        original = inventory._Builder({prefix + 'snapshot.json': dumps(snapshot)}, schema_id('internal schema gate'))
        original.general_originals(prefix)
        chosen = next(i for i, row in enumerate(original.rows) if row['interpretation']['status'] == 'schema_shape_only')
        schema_id_original = snapshot['records'][chosen]['value'][5]
        alias = schema_id('ALIAS_SAME_SCHEMA_BYTES')
        # This tests the private post-admission shape policy only. It does not
        # assert this modified ledger is a verified native source or receipt.
        changed = deepcopy(snapshot)
        changed['records'][chosen]['value'][5] = alias
        for document in changed['documents']:
            if document['documentId'] == schema_id_original: document['documentId'] = alias
        candidate = inventory._Builder({prefix + 'snapshot.json': dumps(changed)}, schema_id('internal schema gate'))
        candidate.general_originals(prefix)
        row = candidate.rows[chosen]
        self.assertEqual(row['selector']['schemaId'], alias)
        self.assertEqual(row['interpretation']['status'], 'opaque')
        self.assertEqual([domain['name'] for domain in row['domains']], ['original'])


if __name__ == '__main__': unittest.main()
