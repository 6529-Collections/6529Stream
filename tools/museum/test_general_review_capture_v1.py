"""Retained local General signed and curator publication controls."""
import copy
import socket
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .general_attestation_source import ARTIST, CURATORIAL, ESTATE, INSTITUTIONAL
from .general_attestation_source import CURATOR_FAMILY
from .general_review_fixture_v1 import load_fixture, source_from, verify_capture
from .general_review_selection import select


class GeneralReviewCaptureV1(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = load_fixture()
        cls.cases = loads(cls.files['cases.json'])
        cls.evidence = loads(cls.files['deployment-evidence.json'], maximum=64 * 1024 * 1024)

    def test_original_capture_replays_without_a_network(self):
        with patch.object(socket, 'socket', side_effect=AssertionError('network during offline replay')):
            result = verify_capture(self.files)
        self.assertEqual(result['status'], 'PASS')
        self.assertTrue(result['originalSourcePublicationSelectionReplay'])

    def test_actual_authority_lanes_and_explicit_artist_boundary(self):
        originals = loads(self.files['general-source.json'], maximum=64 * 1024 * 1024)
        self.assertEqual({r['recordType']: int(r['count']) for r in originals['lanes']},
            {ARTIST: 0, INSTITUTIONAL: 3, ESTATE: 1, CURATORIAL: 2})
        signed = [r for r in originals['records'] if r['value'][3] in (INSTITUTIONAL, ESTATE)]
        curator = [r for r in originals['records'] if r['value'][3] == CURATORIAL]
        self.assertEqual(len(signed), 4)
        self.assertTrue(all(r['receipt'][1:3] == ['1', '1'] and int(r['receipt'][6], 16) != 0
            for r in signed))
        self.assertTrue(all(r['receipt'][1:3] == ['2', '2'] and r['receipt'][14:18] ==
            [CURATOR_FAMILY, '3', '1', '1']
            for r in curator))
        self.assertEqual(len(self.evidence['artifacts']), 30)
        self.assertEqual(self.evidence['boundaries'][0]['role'], 'unused Artist constructor binding only')
        self.assertFalse(self.cases['actualArtistLaneExecuted'])
        self.assertFalse(self.cases['actualWholeStack'])
        self.assertNotEqual(self.evidence['publisher'], self.evidence['reviewer'])
        self.assertNotEqual(self.evidence['publisher'], self.evidence['curator'])
        self.assertNotEqual(self.evidence['curator'], self.evidence['unsignedAttesterLabel'])

    def test_rejection_withholds_exact_mapping_and_self_review_needs_opt_in(self):
        source = source_from(self.files)
        base = loads(self.files['selection.json'])
        selected = select(source, self.files['selection.json'], keccak256(self.files['selection.json']))
        self.assertEqual(len(selected['selected']), 1)
        self.assertEqual({r['body']['disposition'] for r in selected['selected'][0]['qualifyingReviews']}, {'reviewed'})
        snapshot = loads(source.snapshot(), maximum=64 * 1024 * 1024)
        rows = {r['source']['recordHash']: r for r in snapshot['statements']}
        def admitted(label):
            ref = self.cases['selectors'][label]
            from .general_semantic_source_v2 import admission
            return {'source': ref, 'authority': admission(rows[ref['recordHash']], source.a)}
        rejected = copy.deepcopy(base)
        rejected['reviewerAuthoritySet'] = [admitted('curator_rejection')]
        result = select(source, dumps(rejected), keccak256(dumps(rejected)))
        self.assertEqual(len(result['selected']), 0)
        self.assertEqual(result['withheld'][0]['reasons'], ['selected_review_rejects_exact_revision',
            'mapping_requires_authenticated_admitted_review'])
        self_review = copy.deepcopy(base)
        self_review['reviewerAuthoritySet'] = [admitted('self_review')]
        result = select(source, dumps(self_review), keccak256(dumps(self_review)))
        self.assertEqual(len(result['selected']), 0)
        self_review['allowAuthorSelfReview'] = True
        result = select(source, dumps(self_review), keccak256(dumps(self_review)))
        self.assertEqual(len(result['selected']), 1)
        self.assertEqual(result['selected'][0]['reviewQualification'], 'author_confirmed_self_review')

    def test_changed_external_policy_pin_and_capture_bytes_fail(self):
        source = source_from(self.files)
        with self.assertRaisesRegex(MuseumError, 'external pin'):
            select(source, self.files['selection.json'], '0x' + 'ff' * 32)
        altered = dict(self.files)
        altered['general-source.json'] += b' '
        with self.assertRaises(MuseumError):
            verify_capture(altered)


if __name__ == '__main__':
    unittest.main()
