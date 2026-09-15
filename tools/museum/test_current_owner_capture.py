"""Prospective payloads and synthetic RPC controls. No actual OwnerRecords capture claim."""
import copy
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import encode, decode
from .chain_rpc import RpcTransport
from .review import _validate
from .current_owner_capture import (DATA, MARKERS, example_payloads, loan_payload, record_input,
    capture_owner_evidence, export_owner_dossier, LOAN_SCHEMA, VAL_SCHEMA, JCS_ID, CONDITION_SCHEMA)
from .owner_record_source import OWNER_RECORD
from .test_valuations import ValuationFixture, HistoryFixture
from .test_loans import load_source, H, ROOT
from .test_package_recorded import inputs, pins
from .package_recorded import build_recorded_package
from .package import write_package
from .valuation_history import ValuationHistory


class CurrentOwnerCapture(unittest.TestCase):
    def test_literal_public_examples_match_shared_solidity_inputs_and_registered_schemas(self):
        files = example_payloads()
        for name, raw in files.items():
            self.assertEqual((DATA / name).read_bytes(), raw)
            self.assertLessEqual(len(raw), 8192)
        insurance = _validate(VAL_SCHEMA, files['valuation.json'])
        book = _validate(VAL_SCHEMA, files['book-value.json'])
        _validate(LOAN_SCHEMA, files['loan-template.json'])
        for name in ('outbound.json', 'return.json'): _validate(CONDITION_SCHEMA, files[name])
        self.assertEqual((insurance['basis'], book['basis']), ('insurance', 'book_value'))
        self.assertEqual(insurance['amount'], '1000.004500')
        self.assertFalse(insurance['confidential']); self.assertIsNone(insurance['appraiser'])
        self.assertEqual(insurance['countersignatures'], [])
        self.assertEqual(book['supersedes'], [])

    def test_actual_hash_slots_are_distinct_from_payload_hashes_and_template_markers(self):
        files = example_payloads(); original = files['loan-template.json']
        payloads = [files[n] for n in ('valuation.json', 'outbound.json', 'return.json')]
        hashes = [H(91), H(92), H(93)]
        raw = loan_payload(hashes, payloads)
        # Independent byte replacement exactly matches the Solidity test's six substitutions.
        expected = original
        for old, value in zip(MARKERS, hashes + [keccak256(x) for x in payloads]):
            self.assertEqual(expected.count(old.encode()), 1); expected = expected.replace(old.encode(), value.encode())
        self.assertEqual(raw, expected)
        _validate(LOAN_SCHEMA, raw)
        self.assertEqual(files['loan-template.json'], original)
        for bad in (MARKERS[:3], [H(0), H(92), H(93)]):
            with self.assertRaises(MuseumError): loan_payload(bad, payloads)

    def test_original_record_codec_preserves_exact_date_payload_and_jcs(self):
        raw = example_payloads()['valuation.json']; r = record_input(H(9), 'VALUATION', 'STREAM_VALUATION_V1', raw, 7)
        self.assertEqual(decode((OWNER_RECORD,), encode((OWNER_RECORD,), (r,))), (r,))
        self.assertEqual(r[3], (1, hex_bytes(keccak256(raw)), JCS_ID)); self.assertEqual(r[-1], 7)
        for raw_, stamp in ((b'', 7), (raw, 0), (b'x'*8193, 7), (raw, 2**64)):
            with self.assertRaises(MuseumError): record_input(H(9), 'LOAN', 'STREAM_LOAN_V1', raw_, stamp)

    def _synthetic(self):
        # Existing source is real recorded account evidence; all owner responses below
        # are deliberately synthetic fixture bytes, not a positive local-chain claim.
        anchor = load_source().anchor; f = ValuationFixture(anchor=anchor); source, owner_inputs, _ = f.replay(); source.snapshot()
        history = HistoryFixture(f, source)
        plan = dumps({'version': '1', 'loans': [f.loan_hash], 'valuations': [f.valuation_hash], 'transactions': history.transactions})
        files = {'inputs/anchor.json': dumps({k: anchor[k] for k in ('chainId','core','blockHash','blockNumber','timestamp','stateRoot','environment')}), 'premis/premis.xml': b'synthetic format presence',
            'iiif/manifest.json': b'synthetic format presence', 'lido/lido.xml': b'synthetic format presence',
            'linked-art/entity-index.json': b'[]'}
        return f, history, plan, SimpleNamespace(files=tuple(files.items()))

    def test_synthetic_rpc_capture_replays_exact_owner_and_complete_receipt_history_without_network(self):
        f, history, plan, base = self._synthetic()
        with patch('socket.socket', side_effect=AssertionError('network forbidden')), \
            patch('tools.museum.current_owner_capture.verify_recorded_package', return_value=base), \
            patch.object(RpcTransport, 'request', side_effect=history.request):
            captured = capture_owner_evidence('unused', H(1), dumps(f.a), f.evidence, plan,
                plan_hash=keccak256(plan), transport=RpcTransport('http://127.0.0.1:1'), disclosure='public')
        owner_inputs, owner_pins, history_inputs, history_pins, _ = captured
        self.assertEqual(owner_inputs['deployment-evidence.json'], f.evidence)
        self.assertEqual(owner_pins['anchorHash'], keccak256(dumps(f.a)))
        self.assertEqual(history_pins['hintsHash'], keccak256(history_inputs['hints.json']))
        self.assertEqual(loads(history_inputs['hints.json'])['transactions'], history.transactions)

    def test_wrong_source_anchor_is_rejected_before_any_owner_rpc(self):
        f, _, plan, base = self._synthetic(); a = copy.deepcopy(f.a); a['blockHash'] = H(77)
        with patch('tools.museum.current_owner_capture.verify_recorded_package', return_value=base), \
            patch.object(RpcTransport, 'request', side_effect=AssertionError('must reject before RPC')):
            with self.assertRaisesRegex(MuseumError, 'anchor differs'):
                capture_owner_evidence('unused', H(1), dumps(a), f.evidence, plan,
                    plan_hash=keccak256(plan), transport=RpcTransport('http://127.0.0.1:1'), disclosure='public')

    def test_omitting_one_actual_shaped_receipt_never_yields_partial_history(self):
        f, history, raw, base = self._synthetic(); plan = loads(raw, canonical=True)
        plan['transactions'] = plan['transactions'][1:]; raw = dumps(plan)
        with patch('tools.museum.current_owner_capture.verify_recorded_package', return_value=base), \
            patch.object(RpcTransport, 'request', side_effect=history.request):
            with self.assertRaisesRegex(MuseumError, 'events missing'):
                capture_owner_evidence('unused', H(1), dumps(f.a), f.evidence, raw,
                    plan_hash=keccak256(raw), transport=RpcTransport('http://127.0.0.1:1'), disclosure='public')

    def test_original_deployment_bytes_cannot_be_replaced_by_an_institutional_claim(self):
        f, _, plan, base = self._synthetic()
        with patch('tools.museum.current_owner_capture.verify_recorded_package', return_value=base), \
            patch.object(RpcTransport, 'request', side_effect=AssertionError('must reject before RPC')):
            with self.assertRaisesRegex(MuseumError, 'deployment evidence differs'):
                capture_owner_evidence('unused', H(1), dumps(f.a), dumps({'institutionalConformance': True}), plan,
                    plan_hash=keccak256(plan), transport=RpcTransport('http://127.0.0.1:1'), disclosure='public')

    def test_no_remote_rpc_restricted_disclosure_or_unpinned_plan(self):
        for endpoint, disclosure, hash_ in (('https://example.org', 'public', H(1)),
            ('http://127.0.0.1:1', 'restricted', H(1)), ('http://127.0.0.1:1', 'public', H(1))):
            with patch.object(RpcTransport, 'request', side_effect=AssertionError('no RPC')):
                with self.assertRaises(MuseumError):
                    capture_owner_evidence('unused', H(1), b'{}', b'{}', b'{}', plan_hash=hash_,
                        transport=RpcTransport(endpoint), disclosure=disclosure)

    def test_real_retained_account_package_cannot_be_labelled_four_formats_when_inputs_are_missing(self):
        base = build_recorded_package(inputs(), root=ROOT, disclosure='public', **pins())
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); write_package(base, root/'base')
            captured = ({}, {}, {}, {}, {'loans': [], 'valuations': []})
            with patch('socket.socket', side_effect=AssertionError('offline')):
                with self.assertRaisesRegex(MuseumError, 'four-format base'):
                    export_owner_dossier(root/'base', base.manifest_hash, captured, root/'output', disclosure='public')
            self.assertFalse((root/'output').exists())

    def test_existing_destination_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root/'keep').write_bytes(b'unchanged')
            with self.assertRaisesRegex(MuseumError, 'output exists'):
                export_owner_dossier('unused', H(1), ({},{},{},{},{}), root, disclosure='public')
            self.assertEqual((root/'keep').read_bytes(), b'unchanged')


if __name__ == '__main__': unittest.main()
