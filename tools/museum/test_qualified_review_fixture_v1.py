"""Retained actual originals: account distinction, original review scope and replay."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .account_profile import account_iri
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .chain_abi import decode
from .independent_wire import DOCUMENT
from .qualified_review_capture_v1 import FILES, QUALIFICATION, profile_for_hash
from .qualified_review_fixture_v1 import read, retain, verify_capture, verify_deployment
from .review import BODY_SCHEMA_BYTES, _validate

ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
FIXTURE = ROOT / 'qualified-account-review-profile/local-fixture'
MANIFEST_HASH = '0x618ade1b0c337fef6f4cfb5d85d4a6fb0191f6e323db30087d4b57f57202f88a'


class ActualQualifiedReviewFixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, cls.manifest = read(FIXTURE, MANIFEST_HASH)
        cls.profile = profile_for_hash(cls.manifest['profileHash'])
        with patch('socket.socket', side_effect=AssertionError('offline replay used a network')):
            cls.source = verify_capture(cls.files, cls.profile)
        cls.cases = loads(cls.files['qualified-cases.json'], canonical=True)
        cls.anchor = loads(cls.files['anchor.json'], maximum=67108864, canonical=True)
        cls.evidence = loads(cls.files['deployment-evidence.json'], maximum=67108864, canonical=True)
        cls.audit = loads(cls.files['native-reuse-audit.json'], maximum=67108864, canonical=True)

    def test_original_and_distinct_later_reviews_remain_separate(self):
        self.assertNotEqual(self.cases['publisher'], self.cases['reviewer'])
        mapping, issuer, first = self.source.assertion(self.cases['selectors']['mapping'])
        self.assertEqual(issuer, account_iri('31337', self.cases['publisher']))
        self.assertEqual(mapping['origin'], 'human_mapping')
        self.assertEqual(mapping['reviewStatus'], 'unreviewed')
        self.assertEqual(mapping['reviewEvidence'], [])
        last = first
        for name, disposition in (('approved', 'reviewed'), ('rejected', 'rejected'), ('self_review', 'reviewed')):
            review, agent, position = self.source.assertion(self.cases['selectors'][name])
            self.assertEqual(agent, account_iri('31337', self.cases['publisher' if name == 'self_review' else 'reviewer']))
            self.assertLess(last, position); last = position
            self.assertEqual(review['createdAt'], mapping['createdAt'])
            body = _validate(BODY_SCHEMA_BYTES, review['object']['literal']['lexicalValue'].encode('utf-8'))
            self.assertEqual(body['assertionRecord'], self.cases['selectors']['mapping'])
            self.assertEqual(body['assertionRevisionHash'], keccak256(dumps(mapping)))
            self.assertEqual(body['disposition'], disposition)
        self.assertEqual(len(self.source.records), 5)

    def test_registered_profile_bytes_canonicalizations_and_predecessors_are_exact(self):
        captured = loads(self.source.interpretation_bytes, maximum=67108864, canonical=True)
        documents = {row['documentId']: row for row in captured['documents']}
        for name, (_, original) in self.profile.documents.items():
            row = documents[schema_id(name)]
            self.assertEqual(row['originalHex'], '0x' + original.hex())
            view, = decode((DOCUMENT,), bytes.fromhex(row['rawViewHex'][2:]))
            if name in self.profile.document_predecessors:
                self.assertEqual(view[3][4], self.profile.document_predecessors[name])
            if name in self.profile.document_canonicalizations:
                self.assertEqual(view[3][3], self.profile.document_canonicalizations[name])
        payload = self.source.payload(self.source.record(self.cases['selectors']['mapping']))
        self.assertTrue(all(entity['continuation'] is None for entity in payload['entities']))

    def test_historical_native_foundation_and_account_only_limits_are_preserved(self):
        self.assertEqual(self.manifest['qualification'], QUALIFICATION)
        self.assertTrue(self.manifest['accountDistinctionOnly'])
        self.assertFalse(self.manifest['humanIndependenceEstablished'])
        self.assertFalse(self.manifest['selectionPolicyExecuted'])
        self.assertEqual(len(self.audit['products']), 19)
        self.assertEqual(self.audit['sourceMetadataBindings']['uniqueCount'], 185)
        self.assertEqual({r['name'] for r in self.audit['currentMainSourceMismatches']},
            {'StreamCore', 'StreamCoreExternalReads', 'StreamMetadataRenderer'})
        self.assertEqual(self.audit['checkoutCommit'], '32c9afc9fbb39260293a586757c0462f1721b8f2')

    def test_wrong_external_manifest_pin_rejects_before_replay(self):
        with self.assertRaisesRegex(MuseumError, 'external manifest pin'):
            read(FIXTURE, '0x' + 'ff' * 32)

    def test_changed_original_file_rejects_before_replay(self):
        files = dict(self.files); files['qualified-cases.json'] += b' '
        with self.assertRaisesRegex(MuseumError, 'file/profile pins'):
            verify_capture(files, self.profile)

    def test_missing_or_extra_original_file_rejects_before_replay(self):
        for files in ({k: v for k, v in self.files.items() if k != FILES[0]},
                self.files | {'unexpected.json': b'{}'}):
            with self.assertRaisesRegex(MuseumError, 'closed files'):
                verify_capture(files, self.profile)

    def test_altered_product_identity_runtime_or_creation_rejects(self):
        for field in ('sha256', 'source', 'address', 'runtimeHash', 'creationHash'):
            evidence = copy.deepcopy(self.evidence)
            evidence['artifacts']['StreamCore'][field] = 'altered'
            with self.subTest(field=field), self.assertRaises(MuseumError):
                verify_deployment(self.files, self.anchor, evidence, self.audit)

    def test_omitted_product_or_rebound_safe_component_rejects(self):
        evidence = copy.deepcopy(self.evidence); del evidence['artifacts']['StreamCore']
        with self.assertRaisesRegex(MuseumError, 'product set'):
            verify_deployment(self.files, self.anchor, evidence, self.audit)
        evidence = copy.deepcopy(self.evidence)
        evidence['safeComponents']['singleton'] = self.anchor['host']
        with self.assertRaisesRegex(MuseumError, 'Safe deployment/runtime'):
            verify_deployment(self.files, self.anchor, evidence, self.audit)

    def test_original_publication_receipt_cannot_be_replaced_in_journal(self):
        evidence = copy.deepcopy(self.evidence)
        publications = loads(self.files['publications.json'], maximum=67108864, canonical=True)
        target = publications['receipts'][0]['transactionHash']
        next(row for row in evidence['transactions'] if row['transactionHash'] == target)['receipt']['gasUsed'] = '0x0'
        with self.assertRaisesRegex(MuseumError, 'publication/journal'):
            verify_deployment(self.files, self.anchor, evidence, self.audit)

    def test_nonpublication_call_target_cannot_be_rewritten_in_journal(self):
        evidence = copy.deepcopy(self.evidence)
        row = next(row for row in evidence['transactions'] if row['receipt']['contractAddress'] is None)
        row['transaction']['to'] = '0x' + 'ff' * 20
        with self.assertRaisesRegex(MuseumError, 'journal call target'):
            verify_deployment(self.files, self.anchor, evidence, self.audit)

    def test_rehashed_case_labels_cannot_swap_original_approval_and_rejection(self):
        cases = copy.deepcopy(self.cases); choices = cases['selectors']
        choices['approved'], choices['rejected'] = choices['rejected'], choices['approved']
        files = self.files | {'qualified-cases.json': dumps(cases)}
        files['capture-pins.json'] = dumps({'profileHash': self.profile.profile_hash,
            'files': {name: keccak256(files[name]) for name in FILES if name != 'capture-pins.json'}})
        with self.assertRaisesRegex(MuseumError, 'exact review target differs'):
            verify_capture(files, self.profile)

    def test_non_json_native_manifest_is_not_admitted(self):
        with self.assertRaisesRegex(MuseumError, 'invalid JSON'):
            verify_deployment(self.files | {'native-inputs.json': b'not JSON'}, self.anchor, self.evidence, self.audit)

    def test_wrong_capture_pin_cannot_be_retained(self):
        with tempfile.TemporaryDirectory() as temporary:
            capture = Path(temporary) / 'capture'; capture.mkdir()
            for name, raw in self.files.items(): (capture / name).write_bytes(raw)
            destination = Path(temporary) / 'retained'
            with self.assertRaisesRegex(MuseumError, 'external pins hash'):
                retain(capture, destination, '0x' + 'ff' * 32)
            self.assertFalse(destination.exists())


if __name__ == '__main__': unittest.main()
