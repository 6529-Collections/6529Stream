"""Exact review packet joins over an unchanged, replayed unified V4 dossier."""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import canonical_object_dossier_v4 as previous
from . import canonical_object_dossier_v5 as dossier
from . import general_review_selection as general_review
from . import native_artist_review_dossier_v1 as artist_review
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .canonical_object_dossier_fixture_v4 import canonical_case, complete_case_v4
from .general_review_fixture import GeneralReviewFixture
from .native_artist_review_test_fixture import NativeArtistReviewFixture
from .object_dossier import _ref
from .test_native_artist_review_source import payload, policy


def repin(files):
    manifest = loads(files['manifest.json'], maximum=dossier.MAX_MANIFEST)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class CanonicalObjectDossierV5Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with patch('socket.socket', side_effect=AssertionError('fixture used network')):
            canonical = canonical_case()
            cls.base = previous.compose(dict(canonical.files), canonical.manifest_hash, disclosure='public')
            fixture = NativeArtistReviewFixture([{'payload': payload},
                {'payload': lambda context: payload(context, review=True)}])
            source = fixture.semantic(); chosen = policy(source)
            cls.artist = artist_review.build(source, chosen, keccak256(chosen), disclosure='public')
            fixture = GeneralReviewFixture(); source = fixture.source(); chosen, policy_hash = fixture.policy(source)
            cls.general = general_review.build(source, chosen, policy_hash, disclosure='public')
            cls.general_hash = dossier._bundle_hash(cls.general)
            cls.general_policy_hash = policy_hash
            cls.result = dossier.compose(dict(cls.base.files), cls.base.manifest_hash,
                artist_files=dict(cls.artist.files), artist_hash=cls.artist.manifest_hash,
                general_review_files=cls.general, general_review_hash=cls.general_hash,
                general_review_policy_hash=policy_hash,
                general_review_provenance='synthetic_fixture', disclosure='public')

    def test_both_original_packets_replay_and_v4_denominator_stays_exact(self):
        with patch('socket.socket', side_effect=AssertionError('V5 verify used network')):
            checked = dossier.verify(dict(self.result.files), self.result.manifest_hash)
        self.assertEqual(checked.manifest_hash, self.result.manifest_hash)
        files = dict(self.result.files)
        for prefix, child in ((dossier.PREFIXES['base'], self.base),
                              (dossier.PREFIXES['artist'], self.artist)):
            for path, raw in child.files:
                self.assertEqual(files[prefix + path], raw)
        for path, raw in self.general.items():
            self.assertEqual(files[dossier.PREFIXES['general'] + path], raw)
        self.assertEqual(self.result.report['v4PacketRequirementCount'], '19')
        self.assertEqual(self.result.report['v4DossierRequirementCount'], '49')
        self.assertEqual(self.result.report['selectedArtistAssertionCount'], '1')
        self.assertEqual(self.result.report['selectedGeneralAssertionCount'], '1')
        self.assertEqual(self.result.report['requirementPromotions'], [])
        join = loads(files[dossier.JOIN_PATH], maximum=dossier.MAX_BYTES)
        self.assertEqual({row['reviewFamily'] for row in join['links']}, {'artist', 'general'})
        self.assertTrue(all(row['status'] == 'unjoined' and not row['tokenAuthorityEstablished']
            for row in join['links']))  # Canonical-only V4 is collection 1; reviews are collection 7.
        self.assertFalse(join['claims']['crossFamilyReviewerAuthorityGranted'])
        self.assertEqual(files['v4/canonical/input/dossier/requirements.json'],
            dict(self.base.files)['canonical/input/dossier/requirements.json'])

    def test_same_documentary_subject_is_linked_without_state_or_token_promotion(self):
        case = complete_case_v4(); files, digest, options = case.inputs()
        full = previous.compose(files, digest, **options)
        joined = dossier.compose(dict(full.files), full.manifest_hash,
            general_review_files=self.general, general_review_hash=self.general_hash,
            general_review_policy_hash=self.general_policy_hash,
            general_review_provenance='synthetic_fixture', disclosure='public')
        links = loads(dict(joined.files)[dossier.JOIN_PATH], maximum=dossier.MAX_BYTES)['links']
        self.assertEqual(len(links), 1)
        self.assertEqual(links[0]['status'], 'same_documentary_subject_different_source_state')
        self.assertEqual([row['role'] for row in links[0]['v4Candidates']], ['transfer'])
        self.assertFalse(links[0]['v4Candidates'][0]['sourceStateEqual'])
        self.assertFalse(links[0]['tokenAuthorityEstablished'])
        with self.assertRaisesRegex(MuseumError, 'conflicting same-block runtime'):
            dossier.compose(dict(full.files), full.manifest_hash,
                artist_files=dict(self.artist.files), artist_hash=self.artist.manifest_hash,
                disclosure='public')

    def test_exact_occurrence_match_requires_complete_selector_and_scope(self):
        review = dossier._review_rows(dict(self.artist.files), None)[0]
        subject = {'family': 'production', 'source': review['source'],
            'anchorSubject': review['anchorSubject'], 'selectionDisposition': 'selected'}
        state = {'role': 'production', 'status': 'retained', 'sourceState': review['sourceState']}
        shell = {previous.SUPPLEMENTAL_PATH: dumps({'subjects': [subject], 'families': [state]})}
        linked = dossier._links(shell, [review])[0]
        self.assertEqual(linked['status'], 'exact_original_occurrence')
        for field in ('source', 'anchorSubject', 'sourceState', 'blockHash'):
            state_field = field in ('sourceState', 'blockHash')
            changed = deepcopy(state if state_field else subject)
            if field == 'source': changed['source']['recordHash'] = '0x' + '55' * 32
            elif field == 'anchorSubject': changed[field]['subjectId'] = '0x' + '55' * 32
            elif field == 'sourceState': changed['sourceState']['collectionId'] = '999'
            else: changed['sourceState']['blockHash'] = '0x' + '55' * 32
            other = deepcopy(shell)
            other[previous.SUPPLEMENTAL_PATH] = dumps({'subjects': [subject if state_field else changed],
                'families': [changed if state_field else state]})
            result = dossier._links(other, [review])[0]
            self.assertNotEqual(result['status'], 'exact_original_occurrence')

    def test_mismatched_original_selector_revision_profile_subject_or_anchor_rejects(self):
        original = dict(self.artist.files)
        for part in ('selector', 'revision', 'profile', 'subject', 'anchor'):
            files = deepcopy(original)
            if part in ('selector', 'revision'):
                selection = loads(files['graph/selection.json'], maximum=dossier.MAX_BYTES)
                claim = selection['selected'][0]
                if part == 'selector': claim['source']['recordHash'] = '0x' + '11' * 32
                else: claim['assertion']['id'] = 'urn:forged:revision'
                files['graph/selection.json'] = dumps(selection)
            elif part in ('profile', 'subject'):
                snapshot = loads(files['semantics/snapshot.json'], maximum=dossier.MAX_BYTES)
                selection = loads(files['graph/selection.json'], maximum=dossier.MAX_BYTES)
                selected_hash = selection['selected'][0]['source']['recordHash']
                row = next(row for row in snapshot['statements']
                           if row['source']['recordHash'] == selected_hash)
                if part == 'profile': row['value']['profileHash'] = '0x' + '11' * 32
                else: row['value']['anchorSubject']['subjectId'] = '0x' + '11' * 32
                files['semantics/snapshot.json'] = dumps(snapshot)
            else:
                anchor = loads(files['sources/metadata/anchor.json'], maximum=dossier.MAX_BYTES)
                anchor['core'] = '0x' + '11' * 20
                files['sources/metadata/anchor.json'] = dumps(anchor)
            with self.subTest(part=part), self.assertRaises(MuseumError):
                dossier._review_rows(files, None)

    def test_general_original_revision_profile_and_anchor_mismatches_reject(self):
        original = dict(self.general)
        for part in ('selector', 'revision', 'profile', 'subject', 'anchor'):
            files = deepcopy(original)
            if part in ('selector', 'revision'):
                selection = loads(files['selection-result.json'], maximum=dossier.MAX_BYTES)
                claim = selection['selected'][0]
                if part == 'selector': claim['source']['recordHash'] = '0x' + '11' * 32
                else: claim['assertion']['id'] = 'urn:forged:revision'
                files['selection-result.json'] = dumps(selection)
            elif part in ('profile', 'subject'):
                snapshot = loads(files['semantic-source.json'], maximum=dossier.MAX_BYTES)
                row = next(row for row in snapshot['statements'] if row['status'] == 'supported')
                if part == 'profile': row['value']['profileHash'] = '0x' + '11' * 32
                else: row['value']['anchorSubject']['subjectId'] = '0x' + '11' * 32
                files['semantic-source.json'] = dumps(snapshot)
            else:
                anchor = loads(files['anchor.json'], maximum=dossier.MAX_BYTES)
                anchor['core'] = '0x' + '11' * 20
                files['anchor.json'] = dumps(anchor)
            with self.subTest(part=part), self.assertRaises(MuseumError):
                dossier._review_rows(None, files)

    def test_outer_and_child_tampering_fail_even_with_recomputed_outer_hash(self):
        for path in (dossier.JOIN_PATH, 'report.json', 'artist-review/graph/selection.json',
                     'general-review/selection-result.json'):
            files = dict(self.result.files)
            value = loads(files[path], maximum=dossier.MAX_BYTES)
            value['forged'] = True
            files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaises(MuseumError):
                dossier.verify(files, repin(files))
        files = dict(self.result.files)
        files['extra.json'] = b'{}'
        with self.assertRaises(MuseumError): dossier.verify(files, repin(files))

    def test_external_pins_public_preflight_and_completion_refusal(self):
        with patch.object(dossier.previous, 'verify', side_effect=AssertionError('source read')):
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                dossier.compose({}, '0x' + '11' * 32, disclosure='restricted')
            with self.assertRaisesRegex(MuseumError, 'required together'):
                dossier.compose({}, '0x' + '11' * 32, artist_files={}, disclosure='public')
        with self.assertRaisesRegex(MuseumError, 'external packet pin'):
            dossier.compose(dict(self.base.files), self.base.manifest_hash,
                general_review_files=self.general, general_review_hash='0x' + '11' * 32,
                general_review_policy_hash=self.general_policy_hash,
                general_review_provenance='synthetic_fixture', disclosure='public')
        with self.assertRaisesRegex(MuseumError, 'complete canonical dossier unavailable'):
            dossier.complete(dict(self.result.files), self.result.manifest_hash)

    def test_cli_assembles_verifies_and_refuses_overwrite(self):
        with TemporaryDirectory(prefix='museum-v5-cli-') as temporary:
            root = Path(temporary)
            for name, value in (('v4', dict(self.base.files)), ('artist', dict(self.artist.files)),
                                ('general', self.general)):
                write_tree(value, root / name)
            target = root / 'output'
            args = ['assemble', '--v4', str(root/'v4'), '--v4-hash', self.base.manifest_hash,
                '--artist', str(root/'artist'), '--artist-hash', self.artist.manifest_hash,
                '--general-review', str(root/'general'), '--general-review-hash', self.general_hash,
                '--general-review-policy-hash', self.general_policy_hash,
                '--general-review-provenance', 'synthetic_fixture', '--disclosure', 'public',
                '--output', str(target)]
            with patch('socket.socket', side_effect=AssertionError('CLI used network')):
                with redirect_stdout(StringIO()): dossier.main(args)
                self.assertEqual(read_tree(target), dict(self.result.files))
                with redirect_stdout(StringIO()):
                    dossier.main(['verify', str(target), '--manifest-hash', self.result.manifest_hash])
            with redirect_stderr(StringIO()), self.assertRaises(SystemExit): dossier.main(args)


if __name__ == '__main__': unittest.main()
