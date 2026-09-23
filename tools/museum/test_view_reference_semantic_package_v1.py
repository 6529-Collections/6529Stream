"""Exact source replay and retained-dependency reconstruction at the package edge."""
from contextlib import redirect_stdout
from copy import deepcopy
from functools import lru_cache
import io
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase, mock

from . import view_reference_semantic_package_v1 as package
from . import view_reference_semantic_graph_v1 as graph
from . import view_reference_semantic_sources_v1 as sources
from .canonical import MuseumError, dumps, keccak256, loads
from .object_dossier import _ref
from .test_view_preservation_retrieval_v1 import complete_envelope


@lru_cache(maxsize=1)
def complete_case():
    raw = dumps(complete_envelope(count=3, burned=True))
    result = package.build(raw, keccak256(raw), disclosure='public')
    return raw, result


def repin(files, **changes):
    value = loads(files['manifest.json'], maximum=package.MAX_MANIFEST, canonical=True)
    value.update(changes)
    value['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(value)
    return keccak256(files['manifest.json'])


class ViewReferenceSemanticPackageTests(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw, cls.result = complete_case()

    def test_original_source_profiles_and_received_provenance_survive_offline_replay(self):
        files = dict(self.result.files)
        read_bytes = Path.read_bytes

        def retained_only(path):
            if path.resolve().is_relative_to(package.MODEL_ROOT.resolve()):
                raise AssertionError('verification used repository model instead of retained closure')
            return read_bytes(path)

        with mock.patch('socket.socket', side_effect=AssertionError('network used')), \
                mock.patch.object(Path, 'read_bytes', retained_only):
            rebuilt = package.verify(files, self.result.manifest_hash)
        self.assertEqual(rebuilt, self.result)
        self.assertEqual(files[package.SOURCE_PATH], self.raw)
        self.assertEqual(files['definitions/source-profile.json'], sources.PROFILE_BYTES)
        self.assertEqual(files['definitions/graph-profile.json'], graph.PROFILE_BYTES)
        self.assertEqual(files['definitions/crosswalk.json'], graph.CROSSWALK_BYTES)
        self.assertEqual(self.result.report['sourceProvenance'], 'synthetic_fixture')
        for claim in ('sourceOriginAuthenticated', 'currentLiveAuthorityProven',
                'browserExecutionProven', 'archiveDeliveryProven', 'fileSafetyScanned',
                'publicationSafetyEstablished', 'physicalCustodyProven',
                'fullMuseumConformance', 'completeCanonicalDossier', 'institutionalAcceptance'):
            self.assertFalse(self.result.report['claims'][claim])

    def test_wrong_external_source_or_manifest_pin_refuses(self):
        wrong = keccak256(b'wrong external commitment')
        with self.assertRaisesRegex(MuseumError, 'external source'):
            package.build(self.raw, wrong, disclosure='public')
        with self.assertRaisesRegex(MuseumError, 'external manifest'):
            package.verify(dict(self.result.files), wrong)

    def test_disclosure_rejects_before_model_or_source_file_reads(self):
        with mock.patch.object(Path, 'read_bytes', side_effect=AssertionError('private input read')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                package.build(b'not a source', keccak256(b'not a source'), disclosure='restricted')

    def test_rehashed_source_correspondence_forgery_still_refuses(self):
        files = dict(self.result.files)
        value = loads(self.raw, maximum=sources.MAX_INPUT, canonical=True)
        value['materials'][0]['mediaBytes'] = '0x00'
        files[package.SOURCE_PATH] = dumps(value)
        pin = repin(files, sourceHash=keccak256(files[package.SOURCE_PATH]))
        with self.assertRaises(MuseumError):
            package.verify(files, pin)

    def test_coherently_rehashed_inventory_cannot_omit_original_source_leaf(self):
        files = dict(self.result.files)
        value = loads(files[package.INVENTORY_PATH], maximum=sources.MAX_INPUT, canonical=True)
        value['leaves'].pop()
        files[package.INVENTORY_PATH] = dumps(value)
        # Supplied-inventory graph consistency is not source completeness. Even
        # rebuilding every graph/report commitment cannot replace source replay.
        files.update(graph.render(value, model_root=package.MODEL_ROOT))
        report = loads(files['report.json'], maximum=sources.MAX_INPUT, canonical=True)
        report['sourceInventory'] = _ref(package.INVENTORY_PATH, files[package.INVENTORY_PATH])
        report['graph'] = loads(files[graph.REPORT_PATH], maximum=sources.MAX_INPUT, canonical=True)
        files['report.json'] = dumps(report)
        with self.assertRaisesRegex(MuseumError, 'full reconstruction'):
            package.verify(files, repin(files))

    def test_rehashed_graph_or_crosswalk_does_not_override_source(self):
        for path in (graph.REPORT_PATH, 'definitions/crosswalk.json'):
            with self.subTest(path=path):
                files = dict(self.result.files)
                value = loads(files[path], maximum=sources.MAX_INPUT, canonical=True)
                value['unsupportedAssertion'] = 'source byte identity proves archival delivery'
                files[path] = dumps(value)
                with self.assertRaises(MuseumError):
                    package.verify(files, repin(files))

    def test_missing_retained_model_rejects_without_repository_fallback(self):
        files = dict(self.result.files)
        del files['dependencies/linked-art-v2/validation-policy.json']
        with self.assertRaises((MuseumError, OSError)):
            package.verify(files, repin(files))

    def test_extra_files_and_promoted_manifest_claims_refuse(self):
        files = dict(self.result.files)
        files['uncommitted-meaning.json'] = dumps({'received': True})
        with self.assertRaisesRegex(MuseumError, 'full reconstruction'):
            package.verify(files, repin(files))
        files = dict(self.result.files)
        claims = deepcopy(package.CLAIMS)
        claims['institutionalAcceptance'] = True
        with self.assertRaisesRegex(MuseumError, 'closed manifest'):
            package.verify(files, repin(files, claims=claims))

    def test_cli_build_and_verify_retain_exact_read_only_input(self):
        with TemporaryDirectory(prefix='stream-view-reference-cli-') as temporary:
            root = Path(temporary)
            source = root / 'envelope.json'
            output = root / 'export'
            source.write_bytes(self.raw)
            with mock.patch('socket.socket', side_effect=AssertionError('CLI network used')):
                with redirect_stdout(io.StringIO()) as stdout:
                    self.assertEqual(package.main(['build', str(source), str(output),
                        '--source-hash', keccak256(self.raw), '--disclosure', 'public']), 0)
                result = loads(stdout.getvalue().encode(), maximum=sources.MAX_INPUT)
                self.assertEqual(result['manifestHash'], self.result.manifest_hash)
                with redirect_stdout(io.StringIO()):
                    self.assertEqual(package.main(['verify', str(output),
                        '--manifest-hash', self.result.manifest_hash]), 0)
            self.assertEqual(source.read_bytes(), self.raw)
            self.assertEqual((output / package.SOURCE_PATH).read_bytes(), self.raw)
            with redirect_stdout(io.StringIO()) as profiles:
                self.assertEqual(package.main(['profiles']), 0)
            self.assertEqual(loads(profiles.getvalue().encode())['profileHash'], package.PROFILE_HASH)
