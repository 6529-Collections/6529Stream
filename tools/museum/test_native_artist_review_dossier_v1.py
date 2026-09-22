"""Portable Artist review dossier reconstruction from concrete native originals."""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import native_artist_review_dossier_v1 as dossier
from .bagit import write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT
from .native_artist_review_test_fixture import NativeArtistReviewFixture
from .object_dossier import _ref
from .test_native_artist_review_source import payload, policy


def fixture(*, publications=None, mode='distinct_artist'):
    return NativeArtistReviewFixture(publications or [
        {'payload': payload}, {'payload': lambda context: payload(context, review=True)}], mode=mode)


def package(source, **selection):
    raw = policy(source, **selection)
    return dossier.build(source, raw, keccak256(raw), disclosure='public')


def rehash(files):
    """Keep outer commitments internally consistent to test source reconstruction."""
    manifest = loads(files['manifest.json'])
    manifest['files'] = [_ref(path, body) for path, body in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class NativeArtistReviewDossierTests(unittest.TestCase):
    def test_distinct_selected_review_builds_and_replays_offline(self):
        f = fixture(); source = f.semantic()
        with patch('socket.socket', side_effect=AssertionError('Artist dossier used network')):
            built = package(source)
            checked = dossier.verify(dict(built.files), built.manifest_hash)
        self.assertEqual(checked.manifest_hash, built.manifest_hash)
        self.assertEqual(built.report['originalCount'], '2')
        self.assertEqual(built.report['supportedAssertionCount'], '2')
        self.assertEqual(built.report['selectedReviewCount'], '1')
        self.assertEqual(built.report['resourceCount'], '1')
        self.assertEqual(built.report['sourceMode'], 'synthetic_fixture')
        self.assertFalse(built.report['claims']['actualChainAcceptance'])
        files = dict(built.files)
        selection = loads(files['graph/selection.json'], maximum=MAX_TRANSCRIPT)
        resource = loads(next(body for path, body in built.files
            if path.startswith('graph/resources/')), maximum=MAX_TRANSCRIPT)
        self.assertEqual(resource['type'], 'LinguisticObject')
        self.assertEqual(loads(resource['content'].encode()), selection['selected'][0]['assertion'])
        self.assertEqual(selection['reviews'][0]['assertionAuthority'], f.publications[0]['nativeAuthority'])
        self.assertEqual(selection['reviews'][0]['reviewerAuthority'], f.publications[1]['nativeAuthority'])
        self.assertEqual(files['sources/artist/snapshot.json'], source.artist.snapshot())
        self.assertEqual(files['semantics/snapshot.json'], source.snapshot())

    def test_same_original_bad_sibling_remains_visible_without_veto(self):
        def sibling(value):
            invalid = deepcopy(value['assertions'][0]); invalid['origin'] = 'invalid'
            value['assertions'].append(invalid)
        f = fixture(publications=[{'payload': lambda c: payload(c, mutate=sibling)},
            {'payload': lambda c: payload(c, review=True)}])
        built = package(f.semantic())
        self.assertEqual(dossier.verify(dict(built.files), built.manifest_hash).manifest_hash,
            built.manifest_hash)
        files = dict(built.files)
        snapshot = loads(files['semantics/snapshot.json'], maximum=MAX_TRANSCRIPT)
        selection = loads(files['graph/selection.json'], maximum=MAX_TRANSCRIPT)
        self.assertEqual([item['status'] for item in snapshot['statements'][0]['assertionInterpretations']],
            ['supported', 'invalid'])
        self.assertEqual(len(selection['selected']), 1)
        self.assertEqual(selection['interpretationDiagnostics'][0]['source']['pointer'], '/assertions/1')
        self.assertEqual(loads(files['graph/coverage.json'])['originals'][0]['assertionInterpretations'],
            snapshot['statements'][0]['assertionInterpretations'])

    def test_selected_rejection_withholds_resource_and_self_review_requires_opt_in(self):
        rejected = fixture(publications=[{'payload': payload},
            {'payload': lambda c: payload(c, review=True, disposition='rejected')}])
        built = package(rejected.semantic())
        self.assertEqual(built.report['selectedAssertionCount'], '0')
        self.assertEqual(built.report['withheldAssertionCount'], '1')
        self.assertEqual(built.report['resourceCount'], '0')
        self.assertEqual(dossier.verify(dict(built.files), built.manifest_hash).manifest_hash,
            built.manifest_hash)
        same = fixture(mode='same_artist')
        source = same.semantic()
        self.assertEqual(package(source).report['resourceCount'], '0')
        self.assertEqual(package(source, allow_self=True).report['resourceCount'], '1')

    def test_public_policy_and_exact_concrete_source_are_required(self):
        source = fixture().semantic(); raw = policy(source)
        with self.assertRaisesRegex(MuseumError, 'public disclosure'):
            dossier.build(source, raw, keccak256(raw), disclosure='restricted')
        with self.assertRaisesRegex(MuseumError, 'concrete Artist review source'):
            dossier.build(loads(source.snapshot(), maximum=MAX_TRANSCRIPT), raw,
                keccak256(raw), disclosure='public')
        with self.assertRaisesRegex(MuseumError, 'external policy pin'):
            dossier.build(source, raw, '0x' + '11' * 32, disclosure='public')

    def test_rehashed_graph_and_report_tampering_fail_reconstruction(self):
        built = package(fixture().semantic())
        for path in ('report.json', 'graph/selection.json', 'graph/index.json',
                'semantics/documents/STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_POLICY_V1.json'):
            files = dict(built.files)
            value = loads(files[path], maximum=MAX_TRANSCRIPT)
            value['forged'] = True
            files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaises(MuseumError):
                dossier.verify(files, rehash(files))

    def test_missing_extra_and_wrong_native_transcript_fail_closed(self):
        built = package(fixture().semantic())
        for mode in ('missing', 'extra', 'transcript'):
            files = dict(built.files)
            if mode == 'missing': del files['sources/artist/transcript.json']
            elif mode == 'extra': files['unexpected.json'] = b'{}'
            else: files['sources/artist/transcript.json'] = b'[]'
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                dossier.verify(files, rehash(files))

    def test_disk_verify_uses_retained_bytes_and_external_manifest_hash(self):
        built = package(fixture().semantic())
        with TemporaryDirectory(prefix='artist-review-dossier-') as temporary:
            path = Path(temporary) / 'package'
            write_tree(dict(built.files), path)
            with patch('socket.socket', side_effect=AssertionError('disk verify used network')):
                output = io.StringIO()
                with redirect_stdout(output):
                    dossier.main(['verify', str(path), '--manifest-hash', built.manifest_hash])
            self.assertEqual(loads(output.getvalue().encode())['manifestHash'], built.manifest_hash)
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
                dossier.main(['verify', str(path), '--manifest-hash', '0x' + '44' * 32])
            self.assertEqual(raised.exception.code, 1)

    def test_pinned_local_replay_plan_builds_exact_package_and_rejects_path_escape(self):
        source = fixture().semantic(); selection = policy(source); source.snapshot()
        inputs = {'metadataAnchor': source.catalogue.anchor_bytes,
            'metadataTranscript': source.catalogue.transcript(),
            'artistTranscript': source.artist.transcript(),
            'semanticTranscript': source.transcript(), 'selection': selection}
        expected = package(source)
        with TemporaryDirectory(prefix='artist-review-replay-') as temporary:
            root = Path(temporary); capture = root / 'capture'; capture.mkdir()
            refs = {}
            for key, body in inputs.items():
                filename = key + '.json'; (capture / filename).write_bytes(body)
                refs[key] = {'path': filename, 'hash': keccak256(body)}
            plan = {'profile': dossier.NAME, 'provenance': 'synthetic_fixture', **refs}
            raw = dumps(plan); plan_path = capture / 'plan.json'; plan_path.write_bytes(raw)
            output = root / 'output'
            with patch('socket.socket', side_effect=AssertionError('replay plan used network')):
                stdout = io.StringIO()
                with redirect_stdout(stdout):
                    dossier.main(['replay', str(plan_path), str(output), '--plan-hash', keccak256(raw),
                        '--disclosure', 'public'])
            self.assertEqual(loads(stdout.getvalue().encode())['manifestHash'], expected.manifest_hash)
            self.assertEqual(dossier.verify(dict(expected.files), expected.manifest_hash).manifest_hash,
                expected.manifest_hash)
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                dossier.main(['replay', str(plan_path), str(output), '--plan-hash', keccak256(raw),
                    '--disclosure', 'public'])
            plan['selection']['path'] = '../escape.json'
            changed = dumps(plan); plan_path.write_bytes(changed)
            with self.assertRaises(MuseumError):
                dossier.replay_plan(plan_path, keccak256(changed), disclosure='public')


if __name__ == '__main__': unittest.main()
