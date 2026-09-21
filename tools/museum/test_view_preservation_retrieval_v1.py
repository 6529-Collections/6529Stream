"""Complete new-inventory/witness/media envelope and read-only CLI checks."""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import view_preservation_retrieval_fixture_v1 as fixture
from . import view_preservation_retrieval_v1 as consumer
from .canonical import MuseumError, dumps, keccak256, loads, schema_id


def complete_envelope(**options):
    source = fixture.supplied(**options)
    return {'profileHash': consumer.PROFILE_HASH,
        **{name: source[name] for name in ('context', 'graph', 'sourceProof', 'inventory', 'retrieval')},
        'materials': [{'recordHash': record, 'mediaBytes': raw}
            for record, raw in source['mediaBytesByRecord'].items()]}


class ViewRetrievalEnvelopeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.value = complete_envelope()
        cls.raw = dumps(cls.value)

    def test_complete_native_inventory_witness_and_received_bytes_offline(self):
        with patch('socket.socket', side_effect=AssertionError('retrieval attempted network')):
            report = consumer.verify(self.raw)
        self.assertEqual(report['inputHash'], keccak256(self.raw))
        self.assertEqual(report['sourceProvenance'], 'synthetic_fixture')
        self.assertGreater(int(report['retrieval']['inventorySummary']['itemCount']), 10)
        self.assertTrue(report['claims']['completeReceivedMediaBytesChecked'])
        for key in ('rpcProvenanceAuthenticated', 'historicalSignatureReauthorized',
                    'networkRetrievalPerformed', 'completeArchiveBundleChecked', 'finalityProven'):
            self.assertFalse(report['claims'][key])
        self.assertEqual(len(report['media']), 1)
        self.assertGreater(int(report['media'][0]['byteSize']), 0)
        self.assertNotIn('expectedCalls', report['retrieval'])
        self.assertTrue(all('calls' not in row for row in report['retrieval']['bindings']))
        self.assertEqual(dumps(self.value), self.raw, 'verification mutated retained input')

    def test_complete_three_member_inventory_preserves_burned_member_denominator(self):
        value = complete_envelope(count=3, burned=True)
        raw = dumps(value)
        report = consumer.verify(raw)
        self.assertEqual(report['retrieval']['inventorySummary']['segmentCount'],
            int(value['inventory']['value']['evidence'][1][8]))
        self.assertEqual(len(report['media']), 1)

    def test_missing_extra_duplicate_or_unrelated_material_record_refuses(self):
        for mode in ('missing', 'extra', 'duplicate', 'unrelated', 'unknown-field'):
            value = deepcopy(self.value)
            if mode == 'missing': value['materials'] = []
            elif mode == 'extra': value['materials'].append({'recordHash': schema_id('extra'), 'mediaBytes': '0x00'})
            elif mode == 'duplicate': value['materials'].append(deepcopy(value['materials'][0]))
            elif mode == 'unrelated': value['materials'][0]['recordHash'] = schema_id('unrelated')
            else: value['materials'][0]['byteHash'] = schema_id('asserted digest')
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                consumer.verify(dumps(value))

    def test_complete_media_hash_size_and_hex_bounds_are_enforced(self):
        for encoded in ('0x', '0x00', 'not-hex', self.value['materials'][0]['mediaBytes'][:-2]):
            value = deepcopy(self.value); value['materials'][0]['mediaBytes'] = encoded
            with self.subTest(value=encoded[:20]), self.assertRaises(MuseumError):
                consumer.verify(dumps(value))
        with patch.object(consumer, 'MAX_MEDIA', 1), self.assertRaises(MuseumError):
            consumer.verify(self.raw)

    def test_profile_graph_source_and_provenance_cannot_be_relabelled(self):
        for mode in ('profile', 'extra-key', 'graph-role', 'graph-code', 'source', 'provenance'):
            value = deepcopy(self.value)
            if mode == 'profile': value['profileHash'] = schema_id('old locator profile')
            elif mode == 'extra-key': value['assertedComplete'] = True
            elif mode == 'graph-role': value['graph'].pop('externalCoverage')
            elif mode == 'graph-code': value['graph']['inventory']['runtimeHash'] = schema_id('other inventory')
            elif mode == 'source': value['context']['blockHash'] = schema_id('other source block')
            else: value['retrieval']['sourceBindings']['provenance'] = 'externally_admitted_rpc'
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                consumer.verify(dumps(value))

    def test_cli_profiles_verify_and_refusal_are_read_only(self):
        with TemporaryDirectory(prefix='stream-retrieval-envelope-') as temporary:
            path = Path(temporary) / 'input.json'; path.write_bytes(self.raw)
            stdout = io.StringIO()
            with patch('socket.socket', side_effect=AssertionError('CLI attempted network')):
                with redirect_stdout(stdout):
                    self.assertEqual(consumer.main(['verify', str(path)]), 0)
            self.assertEqual(json.loads(stdout.getvalue())['inputHash'], keccak256(self.raw))
            self.assertEqual(path.read_bytes(), self.raw)
            with redirect_stdout(io.StringIO()) as profiles:
                self.assertEqual(consumer.main(['profiles']), 0)
            self.assertEqual(json.loads(profiles.getvalue())['profileHash'], consumer.PROFILE_HASH)
            value = loads(self.raw, maximum=consumer.MAX_INPUT, canonical=True); value['materials'] = []
            malformed = dumps(value); path.write_bytes(malformed)
            with redirect_stderr(io.StringIO()):
                self.assertEqual(consumer.main(['verify', str(path)]), 1)
            self.assertEqual(path.read_bytes(), malformed)


if __name__ == '__main__':
    unittest.main()
