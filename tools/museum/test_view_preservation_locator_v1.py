"""Full retained-source locator positives and coherently rehashed negatives."""
import base64
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from hashlib import sha256
from io import StringIO
import json
from pathlib import Path
import socket
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import view_preservation_locator_v1 as consumer
from . import view_preservation_locator_wire_v1 as wire
from . import view_preservation_bundle_wire_v1 as archive
from . import view_preservation_inventory_types_v1 as types
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id
from .chain_abi import decode, encode
from .independent_wire import ZERO, json_values
from .native_finality_wire import from_json
from .test_view_preservation_bundle_wire_v1 import recommit_original, binding_reads
from .view_preservation_locator_fixture_v1 import (
    supplied, bind_archive, source_proof, HTTPS_URI, AR_URI, AR_TRANSACTION, MEDIA_BYTES, H,
)


def _recommit(value):
    recommit_original(value, value['context'], value['graph'])
    value['sourceBindings']['calls'] = binding_reads([value], value['graph'])


def _replace_receipt(value, index, mutate, *, fixity=None):
    evidence = value['sourceEvidence']
    row, locator, signature = decode((archive.RECEIPT, 'bytes', 'bytes'), hex_bytes(evidence['receipts'][index]))
    row = list(row); mutate(row)
    evidence['receipts'][index] = '0x' + encode((archive.RECEIPT, 'bytes', 'bytes'), (tuple(row), locator, signature)).hex()
    if fixity:
        record, signature = decode((archive.EXTERNAL_FIXITY, 'bytes'), hex_bytes(evidence['fixities'][index]))
        record = list(record); fixity(record)
        evidence['fixities'][index] = '0x' + encode((archive.EXTERNAL_FIXITY, 'bytes'), (tuple(record), signature)).hex()
    _recommit(value)


class LocatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.https = supplied()
        cls.ar = supplied(AR_URI)

    def verify(self, value):
        return consumer.verify(dumps(value))

    def test_https_and_ar_original_obligations_stay_unmaterialized(self):
        for original, kind in ((self.https, 'institutional_https'), (self.ar, 'arweave_transaction')):
            value = deepcopy(original); before = deepcopy(value)
            with patch.object(socket, 'socket', side_effect=AssertionError('network disabled')):
                result = self.verify(value)
            self.assertEqual(value, before)
            self.assertEqual(result['locator']['kind'], kind)
            self.assertEqual(result['media'], {'keccak256': keccak256(MEDIA_BYTES),
                'sha256': '0x' + sha256(MEDIA_BYTES).hexdigest(), 'byteSize': str(len(MEDIA_BYTES))})
            item = from_json(types.ITEM, value['item'])
            self.assertEqual((item[5], item[7], item[9]), (0, b'', 0))
            self.assertEqual(item[1], wire.LOCATOR_ROLE)
            selected = 1 if kind == 'institutional_https' else 0
            self.assertEqual(result['locator']['receiptHash'], value['admission'][3][9 + selected])
            self.assertTrue(result['claims']['exactSamePairLocatorChecked'])
            for key in ('rpcProvenanceAuthenticated', 'historicalSignaturesVerified',
                    'historicalAuthorityReauthorized', 'archiveConsensusVerified', 'currentLivenessVerified',
                    'nativeExecutionProven', 'completeRenderCriticalInventoryChecked', 'browserExecutionProven', 'finalityProven'):
                self.assertFalse(result['claims'][key], key)

    def test_three_members_burned_finalized_original_source(self):
        value = supplied(AR_URI, count=3, mode='finalized', burned=True)
        result = self.verify(value)
        self.assertEqual(result['scope'][0], '4')
        outputs = value['sourceProof']['bundle']['output']['checkpoint']['outputs']
        self.assertEqual(len(outputs), 3)
        self.assertTrue(outputs[0][4])

    def test_exact_locator_grammar_and_neutral_empty_cid_rules(self):
        self.assertEqual(wire.locator(HTTPS_URI), (1, ZERO))
        self.assertEqual(wire.locator(AR_URI), (2, AR_TRANSACTION))
        self.assertEqual(wire.locator('https://a/b?x=1&y=2'), (1, ZERO))
        invalid = ('http://a/b', 'https://a', 'https://a/', 'https://A/b', 'https://a:443/b',
            'https://a@b/c', 'https://a/b#fragment', 'https://a/b%20c', 'https://a/b\\c',
            'https://a/b\x00', 'https://a/bé', 'https://-a/b', 'https://a-/b', 'https://a..b/c',
            'https://' + 'a' * 64 + '/b', 'https://a/' + 'b' * 2040,
            AR_URI + '/', AR_URI + '?x', AR_URI + '=', 'ar://' + 'A' * 43)
        alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
        invalid += (AR_URI[:-1] + alphabet[alphabet.index(AR_URI[-1]) + 1],)
        for uri in invalid:
            with self.subTest(uri=uri[:80]):
                with self.assertRaises(MuseumError): wire.locator(uri)
        source = self.https['graph']['views']['address']; record = H('record')
        self.assertEqual(wire.media(source, record, '')[0], 7)
        digest = sha256(MEDIA_BYTES).digest()
        cid = 'ipfs://b' + base64.b32encode(b'\x01\x55\x12\x20' + digest).decode().lower().rstrip('=')
        row = wire.media(source, record, cid)
        self.assertEqual((row[5], row[7], row[9]), (2, digest, 0))
        self.assertNotEqual(row[1], wire.LOCATOR_ROLE)
        for uri in ('data:image/png;base64,AA==', cid + '/path'):
            with self.assertRaises(MuseumError): wire.media(source, record, uri)

    def test_same_pair_coherent_other_locator_not_a_mirror_witness(self):
        value = deepcopy(self.https)
        bind_archive(value, receipt_uri='https://other.invalid/replica.png')
        # bind_archive already passed the unchanged full original Archive reader.
        with self.assertRaises(MuseumError): self.verify(value)
        value = deepcopy(self.ar)
        bind_archive(value, transaction_id=H('another coherent original transaction'))
        with self.assertRaises(MuseumError): self.verify(value)

    def test_same_pair_receipt_family_object_writer_and_checkpoint_must_match(self):
        cases = ((self.https, 1, lambda row: row.__setitem__(1, H('wrong family'))),
            (self.https, 1, lambda row: row.__setitem__(0, H('wrong object'))),
            (self.https, 1, lambda row: row.__setitem__(6, '0x' + '00' * 20)),
            (self.ar, 0, lambda row: row.__setitem__(5, H('wrong checkpoint'))))
        for original, index, mutate in cases:
            with self.subTest(index=index, original=original['item'][8]):
                value = deepcopy(original); _replace_receipt(value, index, mutate)
                with self.assertRaises(MuseumError): self.verify(value)
        value = deepcopy(self.ar)
        native = json_values(decode((archive.EXTERNAL_NATIVE,), hex_bytes(value['sourceEvidence']['checkpoint']['record']))[0])
        native[1][5] = H('wrong actual checkpoint transaction')
        value['sourceEvidence']['checkpoint']['record'] = '0x' + encode((archive.EXTERNAL_NATIVE,),
            (from_json(archive.EXTERNAL_NATIVE, native),)).hex()
        _recommit(value)
        with self.assertRaises(MuseumError): self.verify(value)

    def test_item_source_record_uri_and_digest_cannot_be_substituted(self):
        for index, replacement in ((2, self.https['graph']['metadata']['address']), (3, H('other original')),
                (8, 'https://example.invalid/other.png'), (5, '1'), (7, keccak256(MEDIA_BYTES)), (9, str(len(MEDIA_BYTES)))):
            value = deepcopy(self.https); value['item'][index] = replacement
            with self.subTest(index=index):
                with self.assertRaises(MuseumError): self.verify(value)

    def test_selected_original_payload_and_events_are_required(self):
        for what in ('payload', 'record', 'event', 'head'):
            value = deepcopy(self.https); bundle = value['sourceProof']['bundle']
            selected = next(row for row in bundle['adoption']['history'] if row['record'][3] == bundle['adoption']['selectedRecordHash'])
            if what == 'payload': selected['declaration']['viewPayload'] += '00'
            elif what == 'record': selected['record'][0][2] = H('different declaration record')
            elif what == 'event': value['sourceProof']['events'].pop()
            else: bundle['adoption']['head'] = H('unretained head')
            with self.subTest(what=what):
                with self.assertRaises(MuseumError): self.verify(value)

    def test_complete_media_bytes_and_size_are_checked(self):
        for raw in (b'', MEDIA_BYTES + b'!', b'x' * len(MEDIA_BYTES)):
            value = deepcopy(self.https); value['mediaBytes'] = '0x' + raw.hex()
            with self.subTest(length=len(raw)):
                with self.assertRaisesRegex(MuseumError, 'media bytes'): self.verify(value)
        with patch.object(consumer, 'MAX_MEDIA', len(MEDIA_BYTES) - 1):
            with self.assertRaisesRegex(MuseumError, 'media byte bound'): self.verify(self.https)
        with patch.object(consumer, 'MAX_SOURCE', 1):
            with self.assertRaisesRegex(MuseumError, 'source byte bound'): self.verify(self.https)

    def test_dependency_calls_provenance_and_closed_claims(self):
        value = deepcopy(self.https); value['sourceBindings']['provenance'] = 'externally_admitted_rpc'
        report = self.verify(value)
        self.assertEqual(report['sourceProvenance'], 'externally_admitted_rpc')
        self.assertFalse(report['claims']['rpcProvenanceAuthenticated'])
        for mutate in (lambda v: v['sourceBindings']['calls'].clear(),
                lambda v: v['sourceBindings'].__setitem__('blockHash', H('different source block')),
                lambda v: v['sourceBindings'].__setitem__('provenance', 'verified'),
                lambda v: v.__setitem__('sourceAuthorityVerified', True),
                lambda v: v['dependencies'][1].__setitem__(4, H('different archive runtime')),
                lambda v: v.__setitem__('profileHash', H('different consumer'))):
            value = deepcopy(self.https); mutate(value)
            with self.assertRaises(MuseumError): self.verify(value)
        with self.assertRaises(MuseumError): consumer.verify(dumps(self.https) + b'\n')

    def test_shared_carrier_and_archive_runtime_observations_are_consistent(self):
        value = deepcopy(self.https)
        carrier = value['sourceProof']['bundle']['output']['manifest']['chunks'][0]
        value['sourceEvidence']['checkpoint']['verifier'] = carrier['pointer']
        _recommit(value)
        with self.assertRaisesRegex(MuseumError, 'runtime'): self.verify(value)
        # An address alias with the exact same supplied runtime is consistent.
        value['sourceEvidence']['checkpoint']['runtimeHash'] = carrier['codeHash']
        _recommit(value)
        self.verify(value)

    def test_cli_offline_readonly_and_bounded_error(self):
        with TemporaryDirectory() as temporary:
            path = Path(temporary) / 'locator.json'; raw = dumps(self.https); path.write_bytes(raw)
            for args in (['profiles'], ['verify', str(path)]):
                stdout, stderr = StringIO(), StringIO()
                with patch.object(socket, 'socket', side_effect=AssertionError('network disabled')):
                    with redirect_stdout(stdout), redirect_stderr(stderr): code = consumer.main(args)
                self.assertEqual(code, 0, stderr.getvalue())
                self.assertEqual(json.loads(stdout.getvalue())['profileHash'], consumer.PROFILE_HASH)
            self.assertEqual(path.read_bytes(), raw)
            bad = deepcopy(self.https); bad['mediaBytes'] = '0x'
            path.write_bytes(dumps(bad)); before = path.read_bytes()
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(consumer.main(['verify', str(path)]), 1)
            self.assertEqual(path.read_bytes(), before)


if __name__ == '__main__': unittest.main()
