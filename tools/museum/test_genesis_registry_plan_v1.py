"""The required genesis denominator cannot be repinned into a smaller meaning."""
from copy import deepcopy
from io import BytesIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase, mock

from . import genesis_registry_plan_v1 as plan
from .canonical import MuseumError, dumps, keccak256, loads


def repin(files):
    manifest = loads(files['manifest.json'], maximum=1048576)
    manifest['files'] = [plan._ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class GenesisRegistryPlanTests(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = plan.prepare()

    def test_exact_frozen_denominator_and_offline_reconstruction(self):
        original = self.original
        self.assertEqual(len(original.documents), 51)
        self.assertEqual(len(original.canonical_names), 29)
        self.assertEqual(original.report['supportDocumentCount'], 22)
        with mock.patch.object(Path, 'read_bytes', side_effect=AssertionError('filesystem read')):
            self.assertEqual(plan.admit(dict(original.files), original.manifest_hash), original)

    def test_every_original_definition_matches_declared_chunk_order(self):
        original = dict(self.original.files)
        rows = loads(original['admission-plan.json'], maximum=1048576)['documents']
        for row, document in zip(rows, self.original.documents):
            self.assertEqual(keccak256(document.content), row['specification']['contentHash'])
            self.assertEqual([keccak256(raw) for raw in document.chunks], row['chunkHashes'])
        self.assertTrue(any(len(doc.chunks) > 1 for doc in self.original.documents))

    def test_later_catalog_regeneration_cannot_change_frozen_plan(self):
        files = dict(self.original.files)
        with TemporaryDirectory(prefix='genesis-frozen-plan-') as temporary:
            root = Path(temporary)
            frozen = root / 'tools/museum/fixtures/genesis-registry-plan-v1'
            frozen.mkdir(parents=True)
            for name in ('catalog.json', 'admission-plan.json'):
                (frozen / name).write_bytes(files[name])
            value = loads(files['admission-plan.json'], maximum=1048576)
            for row in value['documents']:
                target = root / row['sourcePath']
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(files['definitions/' + row['documentId'][2:] + '.json'])
            for name in ('catalog.json', 'admission-plan.json'):
                (root / 'schemas/museum/genesis' / name).write_bytes(b'{"laterProvenance":true}')
            self.assertEqual(plan.prepare(root), self.original)

    def test_wrong_external_pin_rejected(self):
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            plan.admit(dict(self.original.files), '0x' + '11' * 32)

    def test_prepare_read_is_bounded_before_parsing_or_hashing(self):
        class BoundedStream(BytesIO):
            def read(self, size=-1):
                self_requested.append(size)
                return super().read(size)
        self_requested = []
        with mock.patch.object(Path, 'open', return_value=BoundedStream(b'x' * (1048576 + 10))):
            with self.assertRaisesRegex(MuseumError, 'source file bound'):
                plan.prepare()
        self.assertEqual(self_requested, [1048577])

    def test_rehashed_shortened_or_redefined_plan_rejected(self):
        for change in ('remove_support', 'remove_schema', 'duplicate', 'alter_meaning'):
            with self.subTest(change=change):
                files = dict(self.original.files)
                value = loads(files['admission-plan.json'], maximum=1048576)
                if change == 'remove_support':
                    del value['documents'][-1]
                elif change == 'remove_schema':
                    del value['documents'][2]
                elif change == 'duplicate':
                    value['documents'][-1] = deepcopy(value['documents'][2])
                else:
                    value['documents'][2]['specification']['contentHash'] = '0x' + '11' * 32
                files['admission-plan.json'] = dumps(value)
                with self.assertRaisesRegex(MuseumError, 'frozen original'):
                    plan.admit(files, repin(files))

    def test_modified_missing_extra_and_case_alias_files_rejected(self):
        definition = next(p for p, _ in self.original.files if p.startswith('definitions/'))
        for change in ('alter', 'missing', 'extra', 'alias'):
            with self.subTest(change=change):
                files = dict(self.original.files)
                if change == 'alter':
                    files[definition] += b' '
                elif change == 'missing':
                    del files[definition]
                elif change == 'extra':
                    files['unobserved.json'] = b'{}'
                else:
                    files[definition.upper()] = files[definition]
                with self.assertRaises(MuseumError):
                    plan.admit(files, repin(files))

    def test_rehashed_report_authority_upgrade_rejected(self):
        files = dict(self.original.files)
        report = loads(files['report.json'], maximum=1048576)
        report['registrationObserved'] = True
        files['report.json'] = dumps(report)
        with self.assertRaisesRegex(MuseumError, 'deterministic'):
            plan.admit(files, repin(files))
