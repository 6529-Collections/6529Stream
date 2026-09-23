"""Concrete all-family source joins, retained definitions and offline expansion."""
from contextlib import redirect_stderr, redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import canonical_semantic_export_v2 as export
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads


def repin(files):
    value = loads(files['manifest.json'], maximum=export.MAX_MANIFEST, canonical=True)
    value['files'] = [export.package._ref(path, raw) for path, raw in sorted(files.items())
        if path != 'manifest.json']
    files['manifest.json'] = dumps(value)
    return keccak256(files['manifest.json'])


class CompleteOwnerSemanticExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from .test_canonical_semantic_sources_v2 import complete_case
        cls.source = complete_case()
        cls.originals = dict(cls.source.files)
        cls.plan = export.owner_definitions.prepare()
        cls.plan_files = dict(cls.plan.files)
        cls.plan_args = {'plan_files': cls.plan_files, 'plan_hash': cls.plan.manifest_hash}
        cls.selection = export.prepare_selection(cls.originals, cls.source.manifest_hash,
            disclosure='public', **cls.plan_args)
        cls.result = export.build(cls.originals, cls.source.manifest_hash, cls.selection,
            keccak256(cls.selection), disclosure='public', **cls.plan_args)
        cls.files = dict(cls.result.files)

    def test_complete_catalogue_and_original_19_49_denominators_survive(self):
        for path, raw in self.originals.items():
            self.assertEqual(self.files['input/' + path], raw)
        inventory = loads(self.files[export.INVENTORY_PATH], maximum=export.MAX_BYTES)
        owner = [row for row in inventory['rows'] if row['ownerMeaning'] is not None
            and row['interpretation']['status'] == 'interpreted']
        self.assertEqual({row['family'] for row in owner}, {
            'ACCESSION', 'DEACCESSION', 'CONDITION_REPORT', 'EXHIBITION', 'LOAN',
            'CITATION', 'VALUATION', 'STEWARD_DESIGNATION', 'RECOVERY_RESPONSE',
            'REDEMPTION_CLAIM'})
        self.assertTrue(any(row['family'] == 'OWNER_UNKNOWN'
            and row['interpretation']['status'] == 'opaque' for row in inventory['rows']))
        original_report = loads(self.originals['report.json'], maximum=export.MAX_BYTES)
        self.assertEqual(len(original_report['packetRequirements']), 19)
        self.assertEqual(self.result.report['dossierRequirements'],
            loads(self.originals['dossier/requirements.json'], maximum=export.MAX_BYTES))
        self.assertEqual(self.result.report['dossierRequirements']['counts']['total'], 49)
        self.assertFalse(self.result.report['claims']['institutionalAcceptance'])
        self.assertFalse(self.result.report['claims']['specializedNoticeTransitionsInferred'])
        self.assertFalse(self.result.report['ownerDefinitionPlan']['registrationObserved'])
        self.assertEqual(self.result.report['ownerDefinitionPlan']['totalDocuments'], 51)

    def test_all_owner_families_can_be_explicitly_selected_without_current_promotion(self):
        inventory = loads(self.files[export.INVENTORY_PATH], maximum=export.MAX_BYTES)
        candidates = [r for r in inventory['rows'] if r['ownerMeaning'] is not None
            and r['interpretation']['status'] == 'interpreted']
        selection = export.projection.historical_selection(inventory,
            [r['occurrenceId'] for r in candidates], **self.plan_args)
        result = export.build(self.originals, self.source.manifest_hash, selection,
            keccak256(selection), disclosure='public', **self.plan_args)
        output = dict(result.files)
        self.assertEqual(output['inputs/source-inventory.json'], self.files['inputs/source-inventory.json'])
        self.assertTrue(any(path.startswith('semantic/expanded/') for path in output))
        self.assertEqual(result.report['dossierRequirements'], self.result.report['dossierRequirements'])

    def test_offline_verify_uses_retained_plan_and_model_without_repository_reads(self):
        real_open = io.open
        repository = Path(__file__).resolve().parents[2]
        forbidden = [repository / 'schemas', repository / 'tools/museum/fixtures/genesis-registry-plan-v1']

        def guarded(file, *args, **kwargs):
            if isinstance(file, (str, bytes, Path)):
                path = Path(file).resolve()
                if any(path.is_relative_to(root) for root in forbidden):
                    raise AssertionError('repository definition/model fallback attempted')
            return real_open(file, *args, **kwargs)

        with patch('socket.socket', side_effect=AssertionError('network used')), \
                patch('io.open', guarded), \
                patch.object(export.owner_definitions, 'prepare', side_effect=AssertionError('plan fallback')):
            selection = export.prepare_selection(self.originals, self.source.manifest_hash,
                disclosure='public', **self.plan_args)
            result = export.verify(self.files, self.result.manifest_hash)
        self.assertEqual(selection, self.selection)
        self.assertEqual(result.files, self.result.files)

    def test_rehashed_definition_or_meaning_cannot_override_reconstruction(self):
        files = dict(self.files)
        definition = next(p for p in sorted(files)
            if p.startswith(export.OWNER_PLAN_PREFIX + 'definitions/'))
        value = loads(files[definition], maximum=export.MAX_BYTES)
        value['inventedDefinitionField'] = True
        files[definition] = dumps(value)
        with self.assertRaises(MuseumError):
            export.verify(files, repin(files))

        files = dict(self.files)
        value = loads(files[export.INVENTORY_PATH], maximum=export.MAX_BYTES)
        selected = next(row for row in value['rows'] if row['ownerMeaning'] is not None)
        selected['ownerMeaning']['legalTitleProven'] = True
        files[export.INVENTORY_PATH] = dumps(value)
        with self.assertRaisesRegex(MuseumError, 'reconstruction differs'):
            export.verify(files, repin(files))

    def test_definition_pin_pair_and_public_guards_precede_source_reads(self):
        with patch.object(export.sources, 'admit', side_effect=AssertionError('source read')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                export.prepare_selection({}, self.source.manifest_hash, disclosure='restricted')
            with self.assertRaisesRegex(MuseumError, 'supplied together'):
                export.prepare_selection({}, self.source.manifest_hash, disclosure='public',
                    plan_files=self.plan_files)
            with self.assertRaisesRegex(MuseumError, 'selection commitment'):
                export.build({}, self.source.manifest_hash, self.selection, '0x' + '12' * 32,
                    disclosure='public')

    def test_cli_explicit_retained_plan_selection_and_atomic_failure(self):
        with TemporaryDirectory(prefix='stream-owner-semantic-cli-') as directory:
            root = Path(directory)
            source, plan = root / 'source', root / 'plan'
            write_tree(self.originals, source)
            write_tree(self.plan_files, plan)
            policy, refused = root / 'policy', root / 'refused'
            args = ['--dossier', str(source), '--dossier-hash', self.source.manifest_hash,
                '--owner-definitions', str(plan), '--owner-definitions-hash', self.plan.manifest_hash,
                '--disclosure', 'public']
            with redirect_stdout(io.StringIO()):
                export.main(['prepare-selection', *args, '--output', str(policy)])
            self.assertEqual((policy / 'selection.json').read_bytes(), self.selection)
            with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                export.main(['build', *args, '--selection', str(policy / 'selection.json'),
                    '--selection-hash', '0x' + '12' * 32, '--output', str(refused)])
            self.assertEqual(caught.exception.code, 2)
            self.assertFalse(refused.exists())
            self.assertEqual(read_tree(source), self.originals)


if __name__ == '__main__':
    unittest.main()
