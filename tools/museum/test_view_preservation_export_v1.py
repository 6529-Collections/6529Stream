"""Exact local exporter bytes joined to complete original inventory evidence."""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from hashlib import sha256
from io import StringIO
import json
from pathlib import Path
import socket
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import view_preservation_export_v1 as adapter
from . import view_preservation_inventory_v1 as consumer
from . import view_preservation_snapshot_types_v1 as snapshot_types
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode, encode
from .independent_wire import json_values
from .native_finality_wire import from_json
from .view_preservation_export_fixture_v1 import (
    BASIC_RECEIPT, COMPLETE_RECEIPT, supplied, write_export, reseal_source,
)


def _binding_rows(source):
    publication = source['publication']
    return [json_values(decode((kind,), hex_bytes(publication[key]))[0]) for kind, key in
        ((BASIC_RECEIPT, 'basicBindingABI'), (COMPLETE_RECEIPT, 'completeBindingABI'))]


def _seal_bindings(source, basic, complete, *, relink=True):
    """Coherently hash altered original fields so correspondence is tested."""
    basic = list(from_json(BASIC_RECEIPT, basic))
    proposal = keccak256(encode(('bytes32',) + BASIC_RECEIPT[:6],
        (schema_id('6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1'), *basic[:6])))
    basic[-1] = keccak256(encode(('bytes32', 'bytes32', 'bytes32', 'uint64'),
        (schema_id('6529STREAM_FINALITY_VIEW_PRESERVATION_RECEIPT_V1'), proposal, basic[6], basic[7])))
    complete = list(from_json(COMPLETE_RECEIPT, complete))
    if relink: complete[4] = basic[-1]
    provider = next(row['target'] for row in source['graph'] if row['role'] == 'PROVIDER')
    complete[-1] = keccak256(encode(('bytes32', 'uint256', 'address') + COMPLETE_RECEIPT[:-1],
        (schema_id('6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1'),
         int(source['fixture']['chainId']), provider, *complete[:-1])))
    publication = source['publication']
    publication.update(basicBindingRecord=basic[-1], completeBindingRecord=complete[-1],
        basicBindingABI='0x' + encode((BASIC_RECEIPT,), (tuple(basic),)).hex(),
        completeBindingABI='0x' + encode((COMPLETE_RECEIPT,), (tuple(complete),)).hex())


class ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # This calls every original inventory and bundle validator, and never
        # bypasses the production loader when exercising the new adapter.
        cls.original = supplied()

    def setUp(self):
        self.value = deepcopy(self.original)
        self.temporary = TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = write_export(Path(self.temporary.name) / 'export', self.value)

    def source(self):
        return json.loads(self.value['files']['source.json'])

    def replace_source(self, source):
        raw = reseal_source(source)
        self.value['files']['source.json'] = raw
        self.value['sourceSHA256'] = sha256(raw).hexdigest()
        (self.directory / 'source.json').write_bytes(raw)

    def replace_inventory(self, value):
        self.value['inventoryRaw'] = dumps(value)
        self.value['inventorySHA256'] = sha256(self.value['inventoryRaw']).hexdigest()

    def envelope(self):
        return loads(self.value['inventoryRaw'], maximum=consumer.MAX_INPUT)

    def verify(self):
        return adapter.verify(self.directory, self.value['sourceSHA256'], self.value['sourceRevision'],
            self.value['inventoryRaw'], self.value['inventorySHA256'])

    def test_exact_loader_and_full_consumer_without_network(self):
        before = {path.name: path.read_bytes() for path in self.directory.iterdir()}
        with patch.object(socket, 'socket', side_effect=AssertionError('network disabled')):
            loaded = adapter._loader()(self.directory, self.value['sourceSHA256'], self.value['sourceRevision'])
            result = self.verify()
        self.assertEqual(loaded, self.source())
        self.assertEqual(result['joined']['memberCount'], '1')
        self.assertEqual(result['sourceExport']['kind'], 'local_fixture_export')
        self.assertEqual(result['retainedInventory']['provenance'], 'synthetic_fixture')
        self.assertTrue(result['claims']['completeInventoryConsumerPassed'])
        self.assertFalse(result['claims']['fixtureExecutionProven'])
        self.assertFalse(result['claims']['rpcProvenanceAuthenticated'])
        self.assertFalse(result['claims']['finalityProven'])
        self.assertEqual(before, {path.name: path.read_bytes() for path in self.directory.iterdir()})
        self.assertEqual(self.original['inventoryRaw'], self.value['inventoryRaw'])

    def test_all_members_burn_and_finalized_entropy(self):
        self.value = supplied(3, 'finalized', True)
        self.directory = write_export(Path(self.temporary.name) / 'three', self.value)
        self.assertEqual(len(self.value['files']), 13)
        self.assertEqual(self.verify()['joined']['memberCount'], '3')
        for row in self.source()['members']:
            raw = (self.directory / row['outputReturn']['path']).read_bytes()
            self.assertEqual(len(raw), 992)
        last = self.source()['members'][-1]['html']['path']
        (self.directory / last).write_bytes(b'changed last member')
        with self.assertRaises(MuseumError): self.verify()

    def test_both_external_pins_are_required_before_consumer(self):
        for key in ('sourceSHA256', 'inventorySHA256'):
            for invalid in ('0' * 64, '0x' + self.value[key], self.value[key].upper()):
                with self.subTest(key=key, invalid=invalid[:8]):
                    old = self.value[key]; self.value[key] = invalid
                    with patch.object(consumer, 'verify', side_effect=AssertionError('must not replay')):
                        with self.assertRaises(MuseumError): self.verify()
                    self.value[key] = old

    def test_expected_revision_is_independent(self):
        self.value['sourceRevision'] = '0x' + 'cc' * 20
        with self.assertRaises(MuseumError): self.verify()

    def test_emitted_order_and_source_keccak_not_sorted_json(self):
        source = self.source()
        # Same object, a new valid external SHA, but a forbidden property order.
        raw = dumps(source)
        self.assertNotEqual(raw, self.value['files']['source.json'])
        (self.directory / 'source.json').write_bytes(raw)
        self.value['sourceSHA256'] = sha256(raw).hexdigest()
        with self.assertRaises(MuseumError): self.verify()
        self.replace_source(source)
        source['sourceHash'] = '0x' + '01' * 32
        raw = json.dumps(source, separators=(',', ':')).encode()
        (self.directory / 'source.json').write_bytes(raw)
        self.value['sourceSHA256'] = sha256(raw).hexdigest()
        with self.assertRaises(MuseumError): self.verify()

    def test_repinned_graph_and_publication_identity_mismatch(self):
        source = self.source()
        source['graph'][0]['runtimeHash'] = '0x' + '77' * 32
        self.replace_source(source)
        with self.assertRaisesRegex(MuseumError, 'graph differs'): self.verify()
        source = json.loads(self.original['files']['source.json'])
        source['publication']['adoptionRecord'] = '0x' + '78' * 32
        self.replace_source(source)
        with self.assertRaisesRegex(MuseumError, 'publication identity'): self.verify()

    def test_auxiliary_archive_executor_and_snapshot_authority_joins(self):
        for role in ('ARCHIVE', 'GOVERNANCE_EXECUTOR', 'SNAPSHOT_AUTHORITY'):
            with self.subTest(role=role):
                source = json.loads(self.original['files']['source.json'])
                row = next(row for row in source['graph'] if row['role'] == role)
                row['runtimeHash'] = '0x' + '79' * 32
                self.replace_source(source)
                with self.assertRaisesRegex(MuseumError, 'graph differs'): self.verify()

    def test_retained_rpc_admission_does_not_relabel_local_export(self):
        value = self.envelope()
        # This is an explicit caller admission in a synthetic test. It cannot
        # establish that either set of local bytes came from an actual node.
        value['inventory']['recordedSource']['provenance'] = 'externally_admitted_rpc'
        value['bundle']['sourceBindings']['provenance'] = 'externally_admitted_rpc'
        self.replace_inventory(value)
        result = self.verify()
        self.assertEqual(result['sourceExport']['kind'], 'local_fixture_export')
        self.assertEqual(result['retainedInventory']['provenance'], 'externally_admitted_rpc')
        self.assertEqual(result['retainedInventory']['environment'], 'local_evm_fixture')
        self.assertFalse(result['claims']['rpcProvenanceAuthenticated'])
        self.assertFalse(result['claims']['fixturePromotedToRpcEvidence'])
        self.assertFalse(result['claims']['fixtureExecutionProven'])

    def test_missing_bundle_keeps_coverage_and_original_dependencies_unproved(self):
        value = self.envelope(); value['bundle'] = None
        self.replace_inventory(value)
        result = self.verify()
        self.assertIsNone(result['retainedInventory']['report']['bundle'])
        self.assertFalse(result['joined']['bindings']['claims']['bundleDependenciesRetained'])
        self.assertEqual([row['role'] for row in result['exportOnlyGraphPins']],
            ['DISCOVERY','ROLE_REGISTRY','ROOT_SAFE','ARTIST_SAFE'])

    def test_rehashed_binding_correspondence_mismatches(self):
        bad_hash = '0x' + '67' * 32
        mutations = (
            lambda basic, complete: basic[1].__setitem__(1, bad_hash),
            lambda basic, complete: basic[3][1].__setitem__(0, bad_hash),
            lambda basic, complete: basic.__setitem__(4, bad_hash),
            lambda basic, complete: complete[0].__setitem__(1, bad_hash),
            lambda basic, complete: complete.__setitem__(1, bad_hash),
            lambda basic, complete: complete.__setitem__(2, bad_hash),
            lambda basic, complete: complete.__setitem__(3, bad_hash),
            lambda basic, complete: complete.__setitem__(4, bad_hash),
        )
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                source = json.loads(self.original['files']['source.json'])
                basic, complete = _binding_rows(source); mutate(basic, complete)
                _seal_bindings(source, basic, complete, relink=index != len(mutations)-1)
                self.replace_source(source)
                adapter._loader()(self.directory, self.value['sourceSHA256'], self.value['sourceRevision'])
                with self.assertRaises(MuseumError): self.verify()

    def test_rehashed_declaration_gas_and_original_validation_headroom(self):
        for mutation in ('declaration','headroom','cap'):
            source = json.loads(self.original['files']['source.json'])
            basic, complete = _binding_rows(source)
            if mutation == 'declaration': basic[2][4] = str(int(basic[2][4])+1)
            elif mutation == 'cap': basic[1][2] = str(16777217)
            else:
                maximum = max(int(gas) for gas in basic[3][3:])
                basic[1][2] = str(maximum+maximum//63+10000)
            _seal_bindings(source,basic,complete); self.replace_source(source)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): self.verify()

    def test_later_governed_gas_preserves_original_receipt_hashes(self):
        source = self.source(); basic, complete = _binding_rows(source)
        # The retained tuple is a current getter. Its saved predecessor can
        # legitimately have lower gas without changing any address or runtime.
        basic[3][4] = str(int(basic[3][4])-1)
        basic[4] = keccak256(encode((snapshot_types.DEPENDENCIES,),
            (from_json(snapshot_types.DEPENDENCIES,basic[3]),)))
        _seal_bindings(source,basic,complete); self.replace_source(source)
        result = self.verify()['joined']['bindings']
        self.assertEqual(result['complete']['initialReferenceDependenciesHash'],
            result['complete']['currentReferenceDependenciesHash'])
        self.assertTrue(result['claims']['initialReferenceDependenciesPreimageVerified'])
        self.assertNotEqual(result['basic']['dependenciesHash'],
            result['basic']['currentSnapshotDependenciesHash'])
        self.assertFalse(result['claims']['historicalExecutionVerified'])

    def test_current_snapshot_gas_cannot_be_lower_than_original_admission(self):
        source = self.source(); basic, complete = _binding_rows(source)
        basic[3][3] = str(int(basic[3][3])+1)
        basic[4] = keccak256(encode((snapshot_types.DEPENDENCIES,),
            (from_json(snapshot_types.DEPENDENCIES,basic[3]),)))
        _seal_bindings(source,basic,complete); self.replace_source(source)
        with self.assertRaises(MuseumError): self.verify()

    def test_rehashed_binding_timestamp_stays_inside_observed_fixture_window(self):
        for timestamp in ('99','141'):
            source = json.loads(self.original['files']['source.json'])
            basic, complete = _binding_rows(source)
            basic[7] = complete[6] = timestamp
            _seal_bindings(source,basic,complete); self.replace_source(source)
            with self.subTest(timestamp=timestamp), self.assertRaises(MuseumError): self.verify()

    def test_binding_ids_and_opaque_worker_commitment_are_hashed(self):
        for field in ('basicBindingRecord', 'completeBindingRecord', 'basicBindingABI'):
            with self.subTest(field=field):
                source = json.loads(self.original['files']['source.json'])
                if field.endswith('ABI'):
                    basic, _ = _binding_rows(source); basic[5] = '0x' + '66' * 32
                    source['publication'][field] = '0x' + encode((BASIC_RECEIPT,),
                        (from_json(BASIC_RECEIPT, basic),)).hex()
                else: source['publication'][field] = '0x' + '66' * 32
                self.replace_source(source)
                with self.assertRaises(MuseumError): self.verify()

    def test_each_retained_publication_abi_is_exact(self):
        names = ('adoptionABI', 'checkpointABI', 'outputManifestABI', 'snapshotReceiptABI',
            'referenceDependenciesABI', 'inventoryDependenciesABI', 'bundleDependenciesABI',
            'rootRecordABI', 'rootBindingABI')
        for name in names:
            with self.subTest(name=name):
                source = json.loads(self.original['files']['source.json'])
                raw = bytearray(hex_bytes(source['publication'][name])); raw[-1] ^= 1
                source['publication'][name] = '0x' + raw.hex()
                self.replace_source(source)
                with self.assertRaises(MuseumError): self.verify()

    def test_source_chain_scope_and_initial_coordinates_join(self):
        changes = (('fixture', 'chainId', '1'), ('scope', 'scopeId', '0x' + '88' * 32),
            ('fixture', 'initialBlockNumber', '41'), ('fixture', 'initialTimestamp', '141'))
        for section, key, value in changes:
            with self.subTest(key=key):
                source = json.loads(self.original['files']['source.json'])
                source[section][key] = value; self.replace_source(source)
                with self.assertRaises(MuseumError): self.verify()

    def test_valid_export_byte_change_does_not_replace_retained_member(self):
        source = self.source(); member = source['members'][0]
        new_data = b'coherent different original token bytes'
        output = bytearray((self.directory / member['outputReturn']['path']).read_bytes())
        output[6 * 32:7 * 32] = hex_bytes(keccak256(new_data))
        for key, raw in (('tokenData', new_data), ('outputReturn', bytes(output))):
            descriptor = member[key]
            (self.directory / descriptor['path']).write_bytes(raw)
            descriptor.update(keccak256=keccak256(raw), sha256='0x' + sha256(raw).hexdigest(), byteLength=str(len(raw)))
        self.replace_source(source)
        # The original strict source loader accepts this coherent before-image.
        adapter._loader()(self.directory, self.value['sourceSHA256'], self.value['sourceRevision'])
        with self.assertRaisesRegex(MuseumError, 'retained member bytes'): self.verify()

    def test_members_are_not_sampled_or_path_substituted(self):
        for mutate in (lambda source: source['members'].clear(),
                lambda source: source['members'][0]['json'].update(path='../outside.json')):
            source = json.loads(self.original['files']['source.json']); mutate(source); self.replace_source(source)
            with self.assertRaises(MuseumError): self.verify()

    def test_rehashed_missing_history_or_native_event_still_fails(self):
        original = self.envelope()
        for field in ('events', 'segments'):
            value = deepcopy(original); value['inventory'][field].pop()
            self.replace_inventory(value)
            with self.subTest(field=field):
                with self.assertRaises(MuseumError): self.verify()
        value = deepcopy(original)
        value['inventory']['reference']['history'].clear()
        self.replace_inventory(value)
        with self.assertRaises(MuseumError): self.verify()

    def test_inventory_stays_canonical_and_profile_pinned(self):
        raw = self.value['inventoryRaw'] + b'\n'
        self.value['inventoryRaw'] = raw; self.value['inventorySHA256'] = sha256(raw).hexdigest()
        with self.assertRaises(MuseumError): self.verify()
        value = loads(self.original['inventoryRaw'], maximum=consumer.MAX_INPUT)
        value['profileHash'] = '0x' + '99' * 32
        self.replace_inventory(value)
        with self.assertRaises(MuseumError): self.verify()

    def test_cli_offline_and_no_input_mutation(self):
        packet = Path(self.temporary.name) / 'inventory.json'
        packet.write_bytes(self.value['inventoryRaw'])
        stdout = StringIO(); stderr = StringIO()
        args = ['verify', str(self.directory), str(packet), '--source-sha256', self.value['sourceSHA256'],
            '--source-revision', self.value['sourceRevision'], '--inventory-sha256', self.value['inventorySHA256']]
        with patch.object(socket, 'socket', side_effect=AssertionError('network disabled')):
            with redirect_stdout(stdout), redirect_stderr(stderr): result = adapter.main(args)
        self.assertEqual(result, 0, stderr.getvalue())
        self.assertEqual(json.loads(stdout.getvalue())['joined']['memberCount'], '1')
        self.assertEqual(packet.read_bytes(), self.value['inventoryRaw'])

    def test_fixture_directory_never_overwrites(self):
        before = (self.directory / 'source.json').read_bytes()
        with self.assertRaises(FileExistsError): write_export(self.directory, self.value)
        self.assertEqual(before, (self.directory / 'source.json').read_bytes())


if __name__ == '__main__': unittest.main()
