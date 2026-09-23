"""Original synthetic current-source bytes cross the complete composer path."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import current_token_composition as composer
from . import token_fixture
from . import native_iiif_v2 as iiif
from . import native_linked_art_v1 as linked_art
from . import native_premis_v2 as premis
from . import native_work_lido_v1 as lido
from .canonical import MuseumError, dumps, keccak256
from .test_native_work_lido_v1 import supplied


class CurrentCompositionPublicationTests(unittest.TestCase):
    def test_staged_output_publishes_once_without_partial_replacement(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'source'; source.mkdir()
            output = root / 'result'
            stages = {'native-inputs': {'manifest.json': b'original'},
                'v4': {'manifest.json': b'dossier'}}
            composer._publish(stages, {'verified': True}, output, [source])
            self.assertEqual((output / 'native-inputs/manifest.json').read_bytes(),
                b'original')
            with self.assertRaises(MuseumError):
                composer._publish(stages, {'verified': True}, output, [source])
            self.assertEqual((output / 'v4/manifest.json').read_bytes(), b'dossier')


class CurrentCaptureAdmissionPreflightTests(unittest.TestCase):
    """Tracked captured-token originals; native recipe output is unavailable."""

    def test_altered_original_capture_is_refused_before_missing_native_package(self):
        fixture = (Path(__file__).resolve().parents[2] /
            'schemas/museum/dossier/token-local-fixture')
        pin = '0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425'
        originals, _ = token_fixture.read(fixture, pin)
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            retained = root / 'retained-token'; retained.mkdir()
            for name in ('manifest.json', 'inputs.json.gz'):
                (retained / name).write_bytes((fixture / name).read_bytes())
            capture = root / 'original-token-capture'; capture.mkdir()
            for name, raw in originals.items():
                target = capture / name; target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            result = dumps({'recipe': composer.recipe.RECIPE, 'version': '1',
                'retainedTokenManifestHash': pin,
                'actualNativeCaptureAcceptance': False,
                'fullObjectDossierConformance': False})
            (root / 'recipe-result.json').write_bytes(result)
            (capture / 'anchor.json').write_bytes(originals['anchor.json'] + b'\n')
            with self.assertRaisesRegex(MuseumError, 'original captured token bytes differ'):
                composer.admit_capture(root, keccak256(result))


class CurrentTokenCompositionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original, _ = supplied()
        files = dict(cls.original.files)
        def below(prefix):
            return {path.removeprefix(prefix): raw for path, raw in files.items()
                if path.startswith(prefix)}
        cls.prior = below('canonical/input/acquisition/prior/')
        native = below('canonical/input/acquisition/inputs/')
        cls.native_hash = keccak256(native.pop('manifest.json'))
        cls.native = native
        cls.selection = files['canonical/inputs/selection.json']
        pin = cls.original.manifest_hash
        def plan(version, kind, **extra):
            return {'version': version, 'kind': kind, 'sourceManifestHash': pin,
                'selected': [], **extra}
        cls.format_plan = dumps({'version': '2', 'sourceManifestHash': pin,
            'adapters': {'linked-art': plan('1', linked_art.PLAN_KIND),
                'premis': plan('2', premis.PLAN_KIND, selectedRights=[]),
                'iiif': plan('2', iiif.PLAN_KIND),
                'lido': plan('1', lido.PLAN_KIND)}})
        state = cls.original.report['sourceState']
        cls.legacy_state = {key: state[key] for key in composer.IDENTITY_KEYS} | {
            'collectionSerial': '1', 'subjectId': 'legacy-token-subject',
            'canonicalCitation': 'legacy-state-citation'}
        cls.anchor = {key: state[key] for key in composer.ANCHOR_KEYS}
        cls.plan = {'sources': [
            {'id': 'hosts', 'kind': 'hosts', 'anchor': cls.anchor | {
                'collectionId': state['collectionId'], 'tokenId': state['tokenId']}},
            {'id': 'metadata', 'kind': 'metadata', 'anchor': cls.anchor}]}
        cls.bridged_state = composer._current_capture_state(
            cls.legacy_state, cls.anchor, cls.plan)

    def test_originals_compose_through_all_current_packages(self):
        with patch('socket.socket', side_effect=AssertionError('network forbidden')):
            stages, report = composer.compose(self.prior,
                keccak256(self.prior['manifest.json']), self.native,
                self.native_hash, self.selection, keccak256(self.selection),
                self.format_plan, keccak256(self.format_plan),
                capture_state=self.bridged_state)
        self.assertEqual(dict(stages['v4'].files), dict(self.original.files))
        self.assertEqual(report['offlineJoin']['originalRequirementRows'], '49')
        self.assertEqual(report['offlineJoin']['currentRequirementRows'], '49')
        self.assertEqual(report['offlineJoin']['fourFormatFieldRows'],
            report['offlineJoin']['originalFieldRows'])
        self.assertFalse(report['actualCurrentCaptureAcceptance'])
        self.assertTrue(report['recipeSourceStateMatched'])

    def test_legacy_state_bridge_keeps_all_nine_current_keys_and_rejects_mismatch(self):
        self.assertEqual(len(self.legacy_state), 9)
        self.assertEqual(set(self.bridged_state), set(composer.STATE_KEYS))
        self.assertEqual(self.bridged_state,
            {key: self.original.report['sourceState'][key]
                for key in composer.STATE_KEYS})
        for key in composer.STATE_KEYS:
            altered = dict(self.bridged_state); altered[key] = 'different'
            with self.subTest(key=key), self.assertRaisesRegex(
                    MuseumError, 'canonical final source state differ'):
                composer._same_capture_state(altered, self.original.report['sourceState'])
        changed = dict(self.anchor); changed['stateRoot'] = 'different'
        with self.assertRaisesRegex(MuseumError, 'original/native final anchor differs'):
            composer._current_capture_state(self.legacy_state, changed, self.plan)

    def test_native_transport_rejects_unpinned_or_extra_source(self):
        with self.assertRaisesRegex(MuseumError, 'external native-input transport pin'):
            composer.native_transport(self.native, '0x' + '11' * 32)
        with self.assertRaisesRegex(MuseumError, 'original native-source inventory'):
            composer.native_transport(self.native | {'unlisted.json': b'{}'},
                self.native_hash)


if __name__ == '__main__':
    unittest.main()
