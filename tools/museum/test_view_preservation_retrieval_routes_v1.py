"""Native route correspondence over concrete original Archive proof fixtures."""
import base64
import unittest
from unittest.mock import patch

from . import conservation_archive_v1 as conservation
from . import view_preservation_bundle_wire_v1 as archive
from . import view_preservation_retrieval_routes_v1 as routes
from . import view_preservation_retrieval_types_v1 as t
from .canonical import MuseumError, hex_bytes, keccak256 as K, schema_id as H
from .chain_abi import calldata
from .independent_wire import ZERO as Z
from .native_finality_wire import from_json
from .test_conservation_archive_v1 import _proof
from .test_view_preservation_bundle_wire_v1 import A, zero


def ar(transaction):
    return 'ar://' + base64.urlsafe_b64encode(hex_bytes(transaction, 32)).rstrip(b'=').decode('ascii')


class RouteFixture:
    def __init__(self):
        self.context = {'chainId': '31337', 'core': A(2), 'timestamp': '100',
            'blockHash': H('route source block'), 'codePins': []}
        self.graph = {'externalCoverage': {'address': A(61000), 'runtimeHash': H('external runtime')},
            'coverage': {'address': A(61001), 'runtimeHash': H('coverage runtime')}}
        self.configuration = (A(2), H('core'), A(3), H('router'), A(4), H('checkpoint'),
            A(61000), H('external runtime'), 31337, 100000, 100000, 100000, 100000)
        self.artist = H('route Artist')
        self.primary = self.proof(b'received image bytes')
        # The native route records an attributed interpretation of arbitrary admitted bytes.
        self.manifest = self.proof(b'\xff retained manifest bytes are not parsed by the native consumer')
        self.second_manifest = self.proof(b'another complete admitted manifest')
        self.reset()

    def reset(self):
        self.originals = conservation._Originals({'source': self.context}, {'calls': []}, self.graph)

    def proof(self, raw):
        proof = _proof(raw, archive.RAW, self.artist, self.graph, backend='external')
        return {'proof': proof, 'raw': raw, 'sourceEvidence': proof['sourceEvidence']}

    def admit(self, evidence, source):
        proof = evidence['proof']
        conservation._external(proof, evidence['raw'], archive.RAW, [source[10]], None,
            None, self.originals, self.graph)
        c = from_json(t.COVERAGE, proof['coverage'])
        return from_json(t.OBJECT, evidence['sourceEvidence']['object']), (
            (1, c[0], c[1]), proof['originalBundleHash'], Z, c, zero(t.ADMISSION[4]))

    def transaction_uri(self, evidence):
        return ar(H('transaction ' + K(evidence['raw'])))

    def observation(self, requested='https://origin.invalid', steps=(), resolved=None):
        source = ((4, 1, 0, H('VIEW')), A(2), A(3), H('adoption'), H('source'), A(7),
            H('declaration'), H('payload'), H('checkpoint context'), requested, self.artist, H('Artist tuple'))
        obj, admission = self.admit(self.primary, source)
        return (source, obj, admission[3], tuple(steps), resolved or requested, A(801), 70, 1, 200), admission

    def manifest_step(self, evidence, source, target):
        c = evidence['proof']['coverage']
        return (3, source, target, 0, c[1], c[0], evidence['raw'])

    def verify(self, observation, admission, manifests=None):
        return routes.validate(observation, self.configuration, admission, self.primary['sourceEvidence'],
            [] if manifests is None else manifests, self.originals, admit_manifest=self.admit)


class RetrievalRouteTests(unittest.TestCase):
    def setUp(self):
        self.fixture = RouteFixture()

    def test_direct_redirect_and_attributed_mirror_reuse_original_transaction(self):
        f = self.fixture
        target = f.transaction_uri(f.primary)
        cases = [(target, ()), ('https://origin.invalid', ((2, 'https://origin.invalid', target, 0, Z, Z, b''),))]
        cases += [('https://origin.invalid', ((1, 'https://origin.invalid', target, status, Z, Z, b''),))
            for status in (301, 302, 303, 307, 308)]
        for source, steps in cases:
            with self.subTest(source=source, steps=steps):
                f.reset(); observation, admission = f.observation(source, steps, target)
                with patch('socket.socket', side_effect=AssertionError('route attempted network')):
                    report = f.verify(observation, admission)
                self.assertEqual(report['resolvedURI'], target)
                self.assertEqual(report['finalTransactionId'], H('transaction ' + K(f.primary['raw'])))
                self.assertFalse(report['networkRetrievalPerformed'])
                self.assertFalse(report['manifestPathInterpretationProven'])

    def test_uri_matches_native_utf8_host_and_literal_path_rules(self):
        target = self.fixture.transaction_uri(self.fixture.primary)
        for value in ('https://a', 'https://EXAMPLE.invalid?x=%20#literal', 'https://例.invalid/資料',
                      target, target + '/a/../%2e?x#fragment'):
            with self.subTest(uri=value):
                self.assertIn(routes.uri(value)[0], (1, 2, 3))
        for value in ('https://', 'https:///x', 'https://?x', 'https://#x', 'http://x', 'ipfs://x',
                      'https://a b', 'https://a\x7f', 'https://\ud800', target + '/', target + '?x',
                      'https://' + 'a' * 2041):
            with self.subTest(uri=repr(value)), self.assertRaises(MuseumError):
                routes.uri(value)

    def test_order_status_manifest_fields_and_exact_final_uri_are_enforced(self):
        f = self.fixture
        valid = (1, 'https://origin.invalid', 'https://final.invalid', 302, Z, Z, b'')
        mutations = [(1, 'https://wrong.invalid', *valid[2:]),
            (*valid[:3], 200, *valid[4:]), (2, *valid[1:]), (9, *valid[1:]),
            (*valid[:4], H('invented manifest'), *valid[5:]),
            (*valid[:2], valid[1], *valid[3:])]
        for step in mutations:
            with self.subTest(step=step), self.assertRaises(MuseumError):
                o, a = f.observation(steps=(step,), resolved='https://final.invalid')
                f.verify(o, a)
        o, a = f.observation(steps=(valid,), resolved='https://different.invalid')
        with self.assertRaises(MuseumError):
            f.verify(o, a)
        o, a = f.observation(resolved='https://different.invalid')
        with self.assertRaises(MuseumError):
            f.verify(o, a)

    def test_multistep_manifest_chain_retains_bytes_and_each_own_transaction(self):
        f = self.fixture
        start = f.transaction_uri(f.manifest) + '/literal/path'
        middle = f.transaction_uri(f.second_manifest) + '/nested'
        final = f.transaction_uri(f.primary)
        steps = (f.manifest_step(f.manifest, start, middle), f.manifest_step(f.second_manifest, middle, final))
        o, a = f.observation(start, steps, final)
        report = f.verify(o, a, [f.manifest, f.second_manifest])
        self.assertEqual(len(report['manifestOccurrences']), 2)
        self.assertEqual(report['manifestOccurrences'][0]['byteLength'], len(f.manifest['raw']))
        self.assertFalse(report['manifestPathInterpretationProven'])
        for manifests in ([f.manifest], [f.second_manifest, f.manifest],
                          [f.manifest, f.second_manifest, f.manifest]):
            with self.subTest(count=len(manifests)), self.assertRaises(MuseumError):
                f.verify(o, a, manifests)

    def test_duplicate_manifest_occurrences_are_never_collapsed(self):
        f = self.fixture
        first, second, final = f.transaction_uri(f.manifest) + '/first', f.transaction_uri(f.manifest) + '/second', f.transaction_uri(f.primary)
        steps = (f.manifest_step(f.manifest, first, second), f.manifest_step(f.manifest, second, final))
        o, a = f.observation(first, steps, final)
        self.assertEqual(len(f.verify(o, a, [f.manifest, f.manifest])['manifestOccurrences']), 2)
        with self.assertRaises(MuseumError):
            f.verify(o, a, [f.manifest])

    def test_wrong_manifest_bytes_or_transaction_and_wrong_final_transaction_refuse(self):
        f = self.fixture
        start, final = f.transaction_uri(f.manifest) + '/image', f.transaction_uri(f.primary)
        step = f.manifest_step(f.manifest, start, final)
        bad_bytes = (*step[:6], b'different manifest bytes')
        for first, chosen, last in ((start, bad_bytes, final),
            (ar(H('different manifest transaction')) + '/image', step, final),
            (start, step, ar(H('different final transaction')))):
            chosen = (chosen[0], first, last, *chosen[3:])
            o, a = f.observation(first, (chosen,), last)
            with self.subTest(first=first, last=last), self.assertRaises(MuseumError):
                f.verify(o, a, [f.manifest])

    def test_primary_observation_and_shared_getter_conflicts_cannot_be_replaced(self):
        f = self.fixture
        target = f.transaction_uri(f.primary)
        o, a = f.observation(target)
        changed = list(o); obj = list(o[1]); obj[3] = H('unrelated content'); changed[1] = tuple(obj)
        with self.assertRaises(MuseumError):
            f.verify(tuple(changed), a)
        data = calldata('receipt(bytes32)', ('bytes32',), (o[2][9],))
        f.originals.answers[(f.configuration[6], data)] = '0x'
        with self.assertRaises(MuseumError):
            f.verify(o, a)


if __name__ == '__main__':
    unittest.main()
