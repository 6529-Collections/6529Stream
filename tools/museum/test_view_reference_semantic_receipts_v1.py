"""End-to-end known-byte ZIP/PNG receipts through unchanged semantic consumers."""
from copy import deepcopy
from functools import lru_cache
from io import BytesIO
from unittest import TestCase, mock
from zipfile import ZipFile

from . import view_reference_semantic_sources_v1 as sources
from . import view_reference_semantic_graph_v1 as graph
from . import view_reference_semantic_package_v1 as package
from . import view_preservation_retrieval_types_v1 as retrieval_types
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode
from .object_dossier import _ref
from .view_reference_semantic_receipt_fixture_v1 import PACKAGE_CONTENTS, received_bytes, supplied_raw


@lru_cache(maxsize=2)
def source_case(role):
    raw = supplied_raw(role)
    checked, inventory = sources.admit(raw, keccak256(raw))
    return raw, checked, inventory


@lru_cache(maxsize=2)
def package_case(role):
    raw, _, _ = source_case(role)
    return package.build(raw, keccak256(raw), disclosure='public')


def _repin(files):
    manifest = loads(files['manifest.json'], maximum=package.MAX_MANIFEST, canonical=True)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class ViewReferenceSemanticReceiptTests(TestCase):
    def assert_receipt(self, role):
        raw, checked, inventory = source_case(role)
        value = loads(raw, maximum=sources.MAX_INPUT, canonical=True)
        target_role = 'runnable_environment_zip' if role == 'zip' else 'reference_capture'
        target = next(row for row in inventory['rows'] if row['role'] == target_role)
        self.assertEqual(target['availability'], 'received')
        evidence = target['byteEvidence']
        self.assertEqual(evidence['source'], {'path': sources.SOURCE_PATH,
            'hash': keccak256(raw), 'pointer': '/materials/0/mediaBytes'})
        media = hex_bytes(sources.resolve_reference(raw, evidence['source']))
        self.assertEqual(media, received_bytes(role))
        self.assertEqual({key: evidence[key] for key in ('byteLength', 'keccak256', 'sha256')}, sources._digest(media))
        original = value['inventory']['value']['reference']['history'][0]
        obj = next(row['identity'] for row in original['objects']
            if row['objectHash'] == target['values']['objectHash'])
        current = value['retrieval']['records'][0]['current']
        admission = current['admission']
        self.assertEqual(admission[0], ['1', target['values']['coverageHash'], target['values']['objectHash']])
        self.assertEqual(current['sourceEvidence']['object'], obj)
        self.assertEqual(current['sourceEvidence']['object'][3:5], [evidence['keccak256'], evidence['sha256']])
        self.assertEqual(len(current['sourceEvidence']['receipts']), 2)
        self.assertEqual(len(current['sourceEvidence']['fixities']), 2)
        self.assertNotEqual(admission[3][7], admission[3][8], 'two independent original Archive families')
        observation, signature = decode((retrieval_types.OBSERVATION, 'bytes'),
            hex_bytes(value['retrieval']['records'][0]['payloadHex']), maximum=retrieval_types.MAX_BYTES)
        self.assertTrue(signature, 'synthetic retained signature bytes are present, not authenticated')
        self.assertEqual(observation[1][3], evidence['keccak256'])
        self.assertEqual(observation[2][1], target['values']['objectHash'])
        self.assertEqual(checked['media'][0]['objectHash'], target['values']['objectHash'])
        self.assertEqual(inventory['sourceProvenance'], 'synthetic_fixture')
        self.assertEqual(inventory['records'][0]['authority']['authorizationClass'], original['receipt'][1][12])
        self.assertTrue(inventory['records'][0]['selected'])
        self.assertTrue(inventory['records'][0]['currentHead'])
        for claim in ('verifiedArchivalClaim', 'rpcProvenanceAuthenticated',
                'safetyScanPerformed', 'browserExecutionProven', 'physicalProductionProven'):
            self.assertFalse(inventory['claims'][claim])
        return raw, inventory, target

    def test_original_zip_receipts_correspond_to_received_complete_zip(self):
        raw, inventory, target = self.assert_receipt('zip')
        self.assertEqual(target['values']['formatId'], schema_id('IANA:application/zip'))
        with ZipFile(BytesIO(received_bytes('zip'))) as archive:
            self.assertEqual(archive.namelist(), [name for name, _ in PACKAGE_CONTENTS])
            self.assertEqual([(name, archive.read(name)) for name in archive.namelist()], list(PACKAGE_CONTENTS))
        self.assertEqual(next(row for row in inventory['rows'] if row['role'] == 'reference_capture')['availability'],
            'described_only', 'the other object is not promoted by receipt of this ZIP')

    def test_original_png_receipts_correspond_to_received_complete_png(self):
        raw, inventory, target = self.assert_receipt('png')
        self.assertEqual(target['values']['formatId'], schema_id('IANA:image/png'))
        self.assertTrue(received_bytes('png').startswith(b'\x89PNG\r\n\x1a\n'))
        self.assertEqual(target['values']['repeatCaptureSha256'], [target['values']['sha256']] * 2)
        self.assertEqual(next(row for row in inventory['rows'] if row['role'] == 'runnable_environment_zip')['availability'],
            'described_only', 'the other object is not promoted by receipt of this PNG')

    def test_package_members_and_platform_prerequisites_remain_declarations(self):
        for role in ('zip', 'png'):
            raw, checked, inventory = source_case(role)
            declarations = [row for row in inventory['rows'] if row['role'] in ('package_member', 'os_prerequisite')]
            self.assertEqual(len(declarations), 3)
            for row in declarations:
                with self.subTest(role=role, path=row['values']['path']):
                    self.assertEqual(row['availability'], 'described_only')
                    self.assertIsNone(row['byteEvidence'])
            self.assertFalse(inventory['claims']['zipMemberPossessionInferred'])

    def assert_package(self, role):
        original_raw, _, inventory = source_case(role)
        with mock.patch('socket.socket', side_effect=AssertionError('network attempted')):
            result = package_case(role)
            files = dict(result.files)
            rebuilt = package.verify(files, result.manifest_hash)
        self.assertEqual(rebuilt, result)
        self.assertEqual(files[package.SOURCE_PATH], original_raw)
        self.assertEqual(loads(files[package.INVENTORY_PATH], maximum=package.sources.MAX_INPUT), inventory)
        sidecar = loads(files[graph.SIDECAR_PATH], maximum=graph.MAX_OUTPUT_BYTES)
        self.assertEqual([row['occurrence'] for row in sidecar['occurrences']], inventory['rows'])
        target_role = 'runnable_environment_zip' if role == 'zip' else 'reference_capture'
        index = loads(files[graph.INDEX_PATH], maximum=graph.MAX_OUTPUT_BYTES)['resources']
        target = next(row for row in index if row['role'] == target_role)
        resource = loads(files[target['path']])
        self.assertEqual(resource['type'], 'DigitalObject')
        self.assertEqual(resource['classified_as'][1]['id'], graph.RULE + 'availability:received')
        self.assertEqual(target['availability'], 'received')
        for claim in ('sourceOriginAuthenticated', 'archiveDeliveryProven', 'fileSafetyScanned',
                'browserExecutionProven', 'physicalCustodyProven', 'fullMuseumConformance'):
            self.assertFalse(result.report['claims'][claim])

    def test_zip_source_graph_and_package_roundtrip_offline(self):
        self.assert_package('zip')

    def test_png_source_graph_and_package_roundtrip_offline(self):
        self.assert_package('png')

    def test_rehashed_changed_received_bytes_reject_for_each_original_object(self):
        for role in ('zip', 'png'):
            value = loads(supplied_raw(role), maximum=sources.MAX_INPUT)
            original = hex_bytes(value['materials'][0]['mediaBytes'])
            value['materials'][0]['mediaBytes'] = '0x' + (original[:-1] + bytes([original[-1] ^ 1])).hex()
            changed = dumps(value)
            with self.subTest(role=role), self.assertRaisesRegex(MuseumError, 'complete media bytes differ'):
                sources.admit(changed, keccak256(changed))

    def test_rehashed_wrong_original_object_schema_or_identity_cannot_alias_material(self):
        for role in ('zip', 'png'):
            raw, _, inventory = source_case(role)
            value = loads(raw, maximum=sources.MAX_INPUT)
            target = next(row for row in inventory['rows'] if row['role'] ==
                ('runnable_environment_zip' if role == 'zip' else 'reference_capture'))
            objects = value['inventory']['value']['reference']['history'][0]['objects']
            original = next(row for row in objects if row['objectHash'] == target['values']['objectHash'])
            original['identity'][1] = schema_id('unrelated original object schema')
            changed = dumps(value)
            with self.subTest(role=role), self.assertRaisesRegex(MuseumError, 'original Archive object/role'):
                sources.admit(changed, keccak256(changed))

    def test_rehashed_derived_graph_cannot_upgrade_member_possession(self):
        result = package_case('zip'); files = dict(result.files)
        sidecar = loads(files[graph.SIDECAR_PATH], maximum=graph.MAX_OUTPUT_BYTES)
        member = next(row['occurrence'] for row in sidecar['occurrences']
            if row['occurrence']['role'] == 'package_member')
        member['availability'] = 'received'
        files[graph.SIDECAR_PATH] = dumps(sidecar)
        with self.assertRaisesRegex(MuseumError, 'full reconstruction differs'):
            package.verify(files, _repin(files))
