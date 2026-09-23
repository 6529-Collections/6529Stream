"""Concrete exact-child tests for supplemental script requirement links."""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from functools import lru_cache
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import canonical_dossier_script_links_v1 as links
from . import canonical_dossier_script_links_fixture_v1 as fixtures
from . import package_v2
from . import script_dependency_rpc_v1 as script_rpc
from .canonical import MuseumError, dumps, keccak256, loads
from .canonical_dossier_script_links_fixture_v1 import complete_joined_case
from .object_dossier import _ref
from .bagit import read_tree, write_tree
from .test_collection_script_package_v1 import build as build_script
from .test_collection_script_source_v1 import CollectionScriptFixture


@lru_cache(maxsize=None)
def _script(mode, registry=False, unavailable=None, replaced=False):
    fixture = CollectionScriptFixture(mode=mode, registry=registry,
        unavailable=unavailable, replaced=replaced)
    return build_script(fixture)[0]


def _repin(files):
    manifest = loads(files['manifest.json'], maximum=links.MAX_MANIFEST, canonical=True)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items())
        if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class CanonicalDossierScriptLinksV1Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.case = complete_joined_case()
        cls.result = links.compose(*cls.case.inputs(), disclosure='public')
        cls.files = dict(cls.result.files)
        cls.ledger = loads(cls.files[links.LINKS_PATH], maximum=links.MAX_BYTES, canonical=True)
        cls.observations = loads(cls.files[links.OBSERVATIONS_PATH],
            maximum=links.MAX_BYTES, canonical=True)

    def compose_script(self, child):
        return links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
            dict(child.files), child.manifest_hash, disclosure='public')

    def test_genuine_shared_map_is_joined_and_every_child_byte_is_retained(self):
        self.assertEqual(self.observations['scriptSource']['status'], 'joined')
        self.assertEqual(self.observations['scriptSource']['reasons'], [])
        self.assertEqual(self.observations['scriptSource']['scope']['collectionId'], '1')
        self.assertNotIn('tokenId', self.observations['scriptSource']['originalSourceState'])
        for prefix, child in (('dossier/', self.case.dossier), ('scripts/', self.case.scripts)):
            for path, raw in child.files:
                self.assertEqual(self.files[prefix + path], raw)
        with patch('socket.socket', side_effect=AssertionError('network used')):
            self.assertEqual(links.verify(self.files, self.result.manifest_hash), self.result)

    def test_only_two_original_requirement_slots_receive_occurrence_links(self):
        rows = {row['requirementCode']: row for row in self.ledger['requirementLinks']}
        self.assertEqual(set(rows), set(links.CODES))
        self.assertEqual(self.ledger['packetRequirementCount'], '19')
        self.assertEqual(self.ledger['dossierRequirementCount'], '49')
        self.assertEqual(self.ledger['requirementPromotions'], [])
        script = rows['OD-SCRIPT-MANIFEST']['occurrences']
        dependency = rows['OD-DEPENDENCY-MANIFEST']['occurrences']
        self.assertEqual(len(script), 1); self.assertEqual(len(dependency), 1)
        self.assertEqual(script[0]['basis'], 'current_manifest')
        self.assertTrue(script[0]['wireBytesComplete'])
        self.assertIsNotNone(script[0]['payload'])
        self.assertEqual(dependency[0]['wireStatus'], 'authenticated_empty')
        self.assertTrue(dependency[0]['wireBytesComplete'])
        self.assertIsNone(dependency[0]['payload'])
        self.assertTrue(all(not row['requirementAccepted'] for row in script + dependency))

    def test_nineteen_and_fortynine_original_bytes_are_unchanged(self):
        dossier = dict(self.case.dossier.files)
        for path in ('canonical/input/report.json', 'canonical/input/dossier/requirements.json'):
            self.assertEqual(self.files['dossier/' + path], dossier[path])
        assessment = loads(dossier['canonical/input/dossier/requirements.json'])
        self.assertEqual(len(assessment['results']), 49)
        self.assertEqual(len(self.ledger['untouchedRequirementCodes']), 47)
        self.assertFalse(self.result.report['claims']['authoritativeRenderInventory'])

    def test_complete_chunked_library_is_retained_but_independent_state_is_unjoined(self):
        result = self.compose_script(_script('chunked', True))
        files = dict(result.files)
        observed = loads(files[links.OBSERVATIONS_PATH], maximum=links.MAX_BYTES)
        ledger = loads(files[links.LINKS_PATH], maximum=links.MAX_BYTES)
        self.assertEqual(observed['scriptSource']['status'], 'unjoined')
        self.assertIn('state_differs:collectionId', observed['scriptSource']['reasons'])
        self.assertEqual(observed['scriptSource']['scope']['collectionId'], '7')
        for row in ledger['requirementLinks']:
            self.assertTrue(row['occurrences'])
            self.assertTrue(all(item['payload'] is not None for item in row['occurrences']))
        self.assertEqual(ledger['requirementPromotions'], [])

    def test_unavailable_outcomes_keep_indices_and_do_not_become_absence(self):
        result = self.compose_script(_script('chunked', True, 'registry'))
        files = dict(result.files)
        observed = loads(files[links.OBSERVATIONS_PATH], maximum=links.MAX_BYTES)
        ledger = loads(files[links.LINKS_PATH], maximum=links.MAX_BYTES)
        self.assertTrue(observed['unavailable'])
        indices = [row['transcriptIndex'] for row in observed['unavailable']]
        self.assertEqual(indices, observed['transcriptProjection']['unavailableOriginalIndices'])
        transcript = loads(files['scripts/source/transcript.json'], maximum=script_rpc.MAX_TRANSCRIPT)
        self.assertTrue(all('unavailable' in transcript['calls'][index] for index in indices))
        dependency = ledger['requirementLinks'][1]['occurrences'][0]
        self.assertFalse(dependency['wireBytesComplete'])
        self.assertEqual(dependency['wireStatus'], 'partial_unavailable')
        self.assertFalse(result.report['claims']['completeSelectionHistoryProven'])

    def test_zero_selection_inline_and_empty_never_invent_manifest_occurrences(self):
        for mode in ('inline', 'empty'):
            with self.subTest(mode=mode):
                result = self.compose_script(_script(mode))
                ledger = loads(dict(result.files)[links.LINKS_PATH], maximum=links.MAX_BYTES)
                self.assertTrue(all(row['occurrences'] == [] for row in ledger['requirementLinks']))
                availability = ledger['requirementLinks'][0]['availability']
                self.assertEqual(availability['current_manifest'], 'zero_selection')
                self.assertEqual(availability['unmanifestedInlineScript'], mode == 'inline')

    def test_replaced_metadata_saved_bundle_is_never_relabelled_current(self):
        result = self.compose_script(_script('chunked', False, None, True))
        ledger = loads(dict(result.files)[links.LINKS_PATH], maximum=links.MAX_BYTES)
        for row in ledger['requirementLinks']:
            self.assertEqual({item['basis'] for item in row['occurrences']}, {'raw_saved_bundle'})
            self.assertEqual(row['availability']['current_manifest'], 'call_unavailable')
        self.assertEqual(result.report['sourceReconciliation']['scriptSource']['status'], 'unjoined')

    def test_rehashed_derived_tampering_and_external_child_pins_are_refused(self):
        for path in (links.LINKS_PATH, links.OBSERVATIONS_PATH, 'report.json'):
            with self.subTest(path=path):
                files = dict(self.files)
                value = loads(files[path], maximum=links.MAX_BYTES)
                value['inventedAcceptance'] = True
                files[path] = dumps(value)
                with self.assertRaises(MuseumError):
                    links.verify(files, _repin(files))
        files = dict(self.files); files['invented.bin'] = b'invented'
        with self.assertRaises(MuseumError): links.verify(files, _repin(files))
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            links.verify(self.files, keccak256(b'wrong outer pin'))

    def test_cli_public_assemble_verify_and_no_overwrite(self):
        with TemporaryDirectory(prefix='stream-script-links-cli-') as temporary:
            root = Path(temporary); dossier = root/'dossier'; scripts = root/'scripts'; output = root/'out'
            write_tree(dict(self.case.dossier.files), dossier)
            write_tree(dict(self.case.scripts.files), scripts)
            command = ['assemble', '--dossier', str(dossier), '--dossier-hash', self.case.dossier.manifest_hash,
                '--scripts', str(scripts), '--scripts-hash', self.case.scripts.manifest_hash,
                '--disclosure', 'public', '--output', str(output)]
            with patch('socket.socket', side_effect=AssertionError('network used')), redirect_stdout(StringIO()):
                links.main(command)
                self.assertEqual(read_tree(output), self.files)
                links.main(['verify', str(output), '--manifest-hash', self.result.manifest_hash])
            with redirect_stderr(StringIO()), self.assertRaises(SystemExit): links.main(command)
            self.assertEqual(read_tree(output), self.files)
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                links.compose({}, '0x' + '11'*32, {}, '0x' + '22'*32, disclosure='restricted')


class CanonicalDossierScriptLinksV1AdditionalControls(unittest.TestCase):
    """Narrow dispatch, child-boundary and same-anchor conflict controls."""

    @classmethod
    def setUpClass(cls):
        cls.case = complete_joined_case()
        cls.result = links.compose(*cls.case.inputs(), disclosure='public')
        cls.files = dict(cls.result.files)

    def test_generic_package_dispatch_replays_the_outer_package(self):
        with TemporaryDirectory(prefix='stream-script-links-dispatch-') as temporary, \
                patch('socket.socket', side_effect=AssertionError('network used')):
            directory = Path(temporary) / 'package'
            write_tree(self.files, directory)
            self.assertEqual(package_v2.verify_package(directory, self.result.manifest_hash), self.result)

    def test_script_child_pin_and_rehashed_outer_transcript_tamper_reject(self):
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
                dict(self.case.scripts.files), keccak256(b'wrong script child pin'), disclosure='public')
        files = dict(self.files)
        path = 'scripts/source/transcript.json'
        value = loads(files[path], maximum=script_rpc.MAX_TRANSCRIPT, canonical=True)
        value['calls'].append(deepcopy(value['calls'][-1]))
        files[path] = dumps(value)
        with self.assertRaises(MuseumError):
            links.verify(files, _repin(files))

    def test_fresh_same_anchor_runtime_contradiction_rejects_shared_join(self):
        changed = deepcopy(self.case.script_fixture)
        runtime = b'contradictory but internally admitted script Core runtime'
        digest = keccak256(runtime)
        changed.base.codes[changed.core] = runtime
        changed.base.pins[changed.core] = digest
        changed.anchor['coreRuntimeHash'] = digest
        next(row for row in changed.anchor['codePins'] if row['address'] == changed.core)[
            'runtimeHash'] = digest
        changed.anchor_raw = dumps(changed.anchor)
        fixtures._call(changed.base, changed.metadata, 'coreCodeHash()', 'bytes32', digest,
            replace=True)
        child, _, _ = changed.package()
        # Each concrete child remains independently valid. Their positive Core
        # observations cannot both describe this exact chain/block anchor.
        with self.assertRaisesRegex(MuseumError, 'runtime|conflict|contradict'):
            links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
                dict(child.files), child.manifest_hash, disclosure='public')


if __name__ == '__main__': unittest.main()
