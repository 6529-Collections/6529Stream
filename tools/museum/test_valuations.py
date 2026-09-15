"""Synthetic original-wire controls; actual recorded absence remains separately labelled."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, encode
from .chain_rpc import ReplayTransport
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, ZERO
from .owner_record_source import OwnerRecordSource
from .test_loans import OwnerFixture, party, A, H, ROOT, load_source
from .test_exhibitions import reference, date
from .test_package_recorded import inputs, pins
from .package_recorded import build_recorded_package
from .package import write_package
from .package_v2 import verify_package
from .test_package import changed
from .loans import admit as admit_loans, render as render_loans, PROFILE_HASH as LOAN_PROFILE
from .loan_package import build_loan_package
from .valuations import (NAME, SCHEMA_BYTES, PROFILE_BYTES, PROFILE_HASH, JCS_ID, CLAIMS,
    admit, loan_joins, render, project_valuations, validator)
from .valuation_history import ValuationHistory, PROFILE as HISTORY_PROFILE, EVENT, event_bytes
from .valuation_package import build_valuation_package


def valuation():
    return {"version": "1", "valuationId": "urn:test:valuation", "tokenId": "41", "status": "asserted",
        "title": {"value": "Exact recorded insurance estimate", "language": "en"},
        "scope": {"kind": "object", "loanId": None}, "basis": "insurance", "basisReference": reference(8),
        "effectiveDate": date(), "amount": "12345678901234567890.004500", "currency": {"kind": "ISO4217", "code": "USD", "reference": reference(8)},
        "confidential": False, "instrument": reference(5), "issuer": party("Lender, as recorded", "lender"),
        "appraiser": party("Named appraiser", "appraiser", "Person"), "supersedes": [], "references": [reference(4)],
        "countersignatures": [{"role": "insurer", "attestor": {"kind": "address", "value": A(9)},
            "recordHash": H(82), "reference": reference(6)}]}


class ValuationFixture(OwnerFixture):
    def __init__(self, *, edit_valuation=None, **kwargs):
        self.edit_valuation = edit_valuation; self.typed_installed = False
        super().__init__(**kwargs)
        self.valuation_hash = self.lanes[(41, schema_id("VALUATION"))][0]

    def register_schema(self, name, raw, canon=JCS_ID):
        chunks = [self.chunk(raw[i:i+8192]) for i in range(0, len(raw), 8192)]
        spec = (name, 0, keccak256(raw), canon, ZERO, "", len(raw))
        document = (True, 0, keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, chunks))), spec, chunks)
        self.add(self.a["schemas"], "document(bytes32)", ("bytes32",), (schema_id(name),), (DOCUMENT,), (document,))
        self.documents[name] = raw

    def append(self, family, schema, value, relayed=None):
        if family == "VALUATION" and not self.typed_installed:
            self.register_schema(NAME, SCHEMA_BYTES); self.typed_installed = True
            value = valuation()
            if self.edit_valuation: self.edit_valuation(value)
        h = super().append(family, schema, value, relayed)
        if family == "VALUATION":
            lane = self.lanes[(int(value.get("tokenId", "41")), schema_id(family))]
            self.add(self.a["host"], "recordChainHash(uint256,bytes32)", ("uint256", "bytes32"),
                (int(value.get("tokenId", "41")), schema_id(family)), ("bytes32", "uint64"), (self.rows[h][1][4], len(lane)))
        return h


class HistoryFixture:
    """Explicit synthetic canonical-header/receipt responses, not mined evidence."""
    def __init__(self, fixture, source, *, order=None, single_transaction=False):
        self.f, self.source = fixture, source
        a = fixture.a; number = int(a["blockNumber"]) - 1; block_hash = H(187); self.tx = {}
        chosen = [h for h, (r, _, _) in fixture.rows.items() if r[0] in (schema_id("VALUATION"), schema_id("LOAN"))]
        order = chosen if order is None else order
        self.transactions = [H(200)] if single_transaction else [H(200+i) for i in range(len(order))]
        for i, h in enumerate(order):
            row = source.records[h]; t = row["receipt"]
            tx = self.transactions[0 if single_transaction else i]; index = 0 if single_transaction else i
            log = {"address": a["host"], "topics": [EVENT, "0x"+encode(("uint256",), (int(t[0]),)).hex(),
                row["record"][0], "0x"+encode(("address",), (t[1],)).hex()], "data": "0x"+event_bytes(row).hex(),
                "removed": False, "blockHash": block_hash, "blockNumber": hex(number), "transactionHash": tx,
                "transactionIndex": hex(index), "logIndex": hex(i)}
            if tx not in self.tx:
                self.tx[tx] = {"status": "0x1", "transactionHash": tx, "transactionIndex": hex(index),
                    "blockHash": block_hash, "blockNumber": hex(number), "logs": []}
            self.tx[tx]["logs"].append(log)
        self.blocks = {a["blockHash"]: {"hash": a["blockHash"], "number": a["blockNumber"] and hex(int(a["blockNumber"])),
            "timestamp": hex(int(a["timestamp"])), "stateRoot": a["stateRoot"], "parentHash": block_hash, "transactions": []},
            block_hash: {"hash": block_hash, "number": hex(number), "timestamp": hex(int(a["timestamp"])-1),
                "stateRoot": H(185), "parentHash": H(186), "transactions": self.transactions}}
        self.hints = dumps({"profile": HISTORY_PROFILE, "ownerSourceHash": keccak256(source.snapshot()),
            "loans": [fixture.loan_hash], "transactions": self.transactions})

    def request(self, method, params):
        if method == "eth_getTransactionReceipt": return self.tx[params[0]]
        if method == "eth_getBlockByHash": return self.blocks[params[0]]
        return self.f.request(method, params)

    def history(self): return ValuationHistory(self.source, self.hints, self, hints_hash=keccak256(self.hints))

    def replay(self):
        original = self.history(); original.capture(); transcript = original.reader.transcript()
        result = ValuationHistory(self.source, self.hints, ReplayTransport(transcript, keccak256(transcript)),
            hints_hash=keccak256(self.hints), provenance="trusted_rpc")
        snapshot = dumps(result.capture())
        return result, {"hints.json": self.hints, "transcript.json": transcript}, {
            "hintsHash": keccak256(self.hints), "transcriptHash": keccak256(transcript), "snapshotHash": keccak256(snapshot)}


class ValuationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.model = validator(ROOT)
    def setup_rows(self, **kwargs):
        f = ValuationFixture(**kwargs); source = f.adapter(); source.snapshot()
        return f, source, admit(source, [f.valuation_hash])

    def test_exact_original_typed_schema_amount_currency_date_and_basis(self):
        for basis in ("appraisal", "book_value", "insurance"):
            f, s, rows = self.setup_rows(edit_valuation=lambda v: v.update(basis=basis))
            files = render(rows, [], self.model); saved = loads(files["valuations/dossiers.json"], maximum=2097152)[0]
            self.assertEqual(saved["valuation"]["basis"], basis)
            self.assertEqual(saved["valuation"]["amount"], "12345678901234567890.004500")
            self.assertEqual(saved["valuation"]["effectiveDate"], date()); self.assertEqual(saved["nativeEffectiveAt"], "1")
            self.assertEqual(saved["authority"]["owner"], A(9))
        self.assertEqual((ROOT/"valuation"/(NAME+".json")).read_bytes(), SCHEMA_BYTES)
        self.assertEqual((ROOT/"valuation/profile.json").read_bytes(), PROFILE_BYTES)

    def test_confidential_figure_rejected_and_sealed_instrument_not_fetched(self):
        with self.assertRaisesRegex(MuseumError, "confidential figure"):
            self.setup_rows(edit_valuation=lambda v: v.update(confidential=True))
        f, s, rows = self.setup_rows(edit_valuation=lambda v: v.update(confidential=True, amount=None))
        with patch("socket.socket", side_effect=AssertionError("offline")):
            files = render(rows, [], self.model)
        saved = loads(files["valuations/dossiers.json"], maximum=2097152)[0]
        self.assertIsNone(saved["valuation"]["amount"]); self.assertEqual(saved["valuation"]["instrument"], reference(5))
        self.assertFalse(any(loads(files["valuations/report.json"])["claims"].values()))

    def test_literal_amount_shape_currency_and_no_financial_rounding(self):
        for value in (1.5, "1e3", "+1", "01", "0.1234567890123456789"):
            with self.assertRaises(MuseumError): self.setup_rows(edit_valuation=lambda v: v.update(amount=value))
        for mutate in (lambda v: v.update(currency=None), lambda v: v["currency"].update(code="usd")):
            with self.assertRaises(MuseumError): self.setup_rows(edit_valuation=mutate)
        _, _, rows = self.setup_rows(edit_valuation=lambda v: v.update(basis="book_value", amount="-0.0040"))
        self.assertEqual(rows[0]["value"]["amount"], "-0.0040")

    def test_named_roles_and_countersignature_references_never_prove_assent(self):
        f, s, rows = self.setup_rows(); files = render(rows, [], self.model)
        dossier = loads(files["valuations/dossiers.json"], maximum=2097152)[0]
        self.assertEqual(dossier["countersignatures"][0]["status"], "unverified_reference")
        self.assertFalse(any(r["countersigned"] for r in loads(files["valuations/named-roles.json"])))
        types = [r["type"] for r in loads(files["valuations/index.json"])["resources"]]
        self.assertEqual(sorted(types), ["Group", "LinguisticObject", "Person"])
        self.assertNotIn("Activity", types); self.assertNotIn("MonetaryAmount", types)

    def test_old_valuation_meaning_stays_unsupported_and_old_loan_projection_unchanged(self):
        f = OwnerFixture(); s = f.adapter(); s.snapshot()
        rows = admit(s, [f.lanes[(41, schema_id("VALUATION"))][0]])
        self.assertEqual(rows[0]["reasonCode"], "registered_valuation_definition_unsupported")
        original = render_loans(admit_loans(s, [f.loan_hash]), self.model)
        self.assertEqual(loads(original["loans/dossiers.json"], maximum=2097152)[0]["references"][0]["interpretation"], "opaque_original_registered_bytes")

    def test_missing_titles_named_parties_and_conflicting_identity_are_explicit(self):
        _, _, rows = self.setup_rows(edit_valuation=lambda v: v.update(title=None, appraiser=None))
        files = render(rows, [], self.model); self.assertIn("document_title_missing", loads(files["valuations/report.json"])["dispositions"][0]["missingFacts"])
        with self.assertRaisesRegex(MuseumError, "cross-kind"):
            self.setup_rows(edit_valuation=lambda v: v["issuer"].update(entityId=v["valuationId"]))

    def test_same_block_transaction_and_same_transaction_log_order_join(self):
        for single in (False, True):
            f, s, rows = self.setup_rows(); history = HistoryFixture(f, s, single_transaction=single).history().capture()
            join = loan_joins(s, admit_loans(s, [f.loan_hash]), rows, history)[0]
            self.assertEqual(join["status"], "ordered_selected_unsuperseded_reference")
            self.assertTrue(join["fullValuationLaneChecked"]); self.assertTrue(join["publicationOrderChecked"])
            self.assertFalse(join["legalOperativenessProven"]); self.assertFalse(join["countersigned"])

    def test_later_timestamp_or_reference_alone_cannot_establish_order(self):
        f, s, rows = self.setup_rows(); loans = admit_loans(s, [f.loan_hash])
        self.assertEqual(loan_joins(s, loans, rows)[0]["reasonCode"], "publication_order_evidence_missing")
        history = HistoryFixture(f, s, order=[f.loan_hash, f.valuation_hash]).history().capture()
        self.assertEqual(loan_joins(s, loans, rows, history)[0]["reasonCode"], "valuation_not_published_before_loan")

    def test_explicit_supersession_before_loan_vs_after_and_unlike_basis_no_latest_guess(self):
        f = ValuationFixture(); v = valuation(); v.update(valuationId="urn:test:new-valuation", supersedes=[f.valuation_hash])
        later = f.append("VALUATION", NAME, v); s = f.adapter(); s.snapshot(); rows = admit(s, [f.valuation_hash, later]); loans = admit_loans(s, [f.loan_hash])
        before = HistoryFixture(f, s, order=[f.valuation_hash, later, f.loan_hash]).history().capture()
        self.assertEqual(loan_joins(s, loans, rows, before)[0]["reasonCode"], "explicit_superseding_statement_before_loan")
        after = HistoryFixture(f, s).history().capture()
        self.assertEqual(loan_joins(s, loans, rows, after)[0]["status"], "ordered_selected_unsuperseded_reference")
        f = ValuationFixture(); v = valuation(); v.update(valuationId="urn:test:book", basis="book_value")
        book = f.append("VALUATION", NAME, v); s = f.adapter(); s.snapshot()
        e = HistoryFixture(f, s, order=[f.valuation_hash, book, f.loan_hash]).history().capture()
        result = loan_joins(s, admit_loans(s, [f.loan_hash]), admit(s, [book, f.valuation_hash]), e)[0]
        self.assertEqual(result["status"], "ordered_selected_unsuperseded_reference"); self.assertEqual(result["basis"], "insurance")

    def test_complete_lane_omission_head_drift_and_bounds_reject(self):
        f, s, _ = self.setup_rows(); h = HistoryFixture(f, s)
        for head, count in ((H(99), 1), (ZERO, 129)):
            f.add(f.a["host"], "recordChainHash(uint256,bytes32)", ("uint256", "bytes32"), (41, schema_id("VALUATION")), ("bytes32", "uint64"), (head, count))
            with self.assertRaises(MuseumError): h.history().capture()
        f = ValuationFixture(); f.a["records"] = [r for r in f.a["records"] if r["recordHash"] != f.valuation_hash]
        s = f.adapter(); s.snapshot(); h = HistoryFixture.__new__(HistoryFixture)
        hints = dumps({"profile": HISTORY_PROFILE, "ownerSourceHash": keccak256(s.snapshot()), "loans": [f.loan_hash], "transactions": [H(200)]})
        with self.assertRaisesRegex(MuseumError, "lane selection missing"):
            ValuationHistory(s, hints, f, hints_hash=keccak256(hints)).capture()

    def test_receipt_event_coordinates_status_ancestry_and_data_are_bound(self):
        for mutate in (lambda h: h.tx[h.transactions[0]].update(status="0x0"),
            lambda h: h.tx[h.transactions[0]].update(transactionIndex="0x1"),
            lambda h: h.tx[h.transactions[0]]["logs"][0].update(removed=True),
            lambda h: h.tx[h.transactions[0]]["logs"][0].update(data="0x"),
            lambda h: h.blocks[H(187)].update(parentHash=ZERO),
            lambda h: h.blocks[H(187)].update(timestamp="0x1")):
            f, s, _ = self.setup_rows(); h = HistoryFixture(f, s); mutate(h)
            with self.assertRaises(MuseumError): h.history().capture()

    def test_unknown_prior_valuation_schema_prevents_unsuperseded_conclusion(self):
        f = ValuationFixture(); f.register_schema("OTHER_VALUATION_V1", dumps({"type": "object"}))
        opaque = f.append("VALUATION", "OTHER_VALUATION_V1", {"uninterpreted": True})
        s = f.adapter(); s.snapshot(); rows = admit(s, [f.valuation_hash, opaque])
        e = HistoryFixture(f, s, order=[f.valuation_hash, opaque, f.loan_hash]).history().capture()
        self.assertEqual(loan_joins(s, admit_loans(s, [f.loan_hash]), rows, e)[0]["reasonCode"], "prior_valuation_semantics_unsupported")

    def test_history_event_order_must_match_lane_and_global_log_order(self):
        f = ValuationFixture(); v = valuation(); v.update(valuationId="urn:test:second-valuation")
        second = f.append("VALUATION", NAME, v); s = f.adapter(); s.snapshot()
        with self.assertRaisesRegex(MuseumError, "lane/event order"):
            HistoryFixture(f, s, order=[second, f.valuation_hash, f.loan_hash]).history().capture()
        h = HistoryFixture(f, s)
        h.tx[h.transactions[0]]["logs"][0]["logIndex"] = "0xa"
        with self.assertRaisesRegex(MuseumError, "block log order"): h.history().capture()

    def test_history_span_malformed_receipt_and_failed_capture_cannot_resume(self):
        f, s, _ = self.setup_rows(); h = HistoryFixture(f, s)
        del h.tx[h.transactions[0]]["blockHash"]
        history = h.history()
        with self.assertRaisesRegex(MuseumError, "malformed history"): history.capture()
        with self.assertRaisesRegex(MuseumError, "cannot resume"): history.capture()
        f, s, _ = self.setup_rows(anchor={"chainId":"31337","core":A(2),"blockHash":H(21),"blockNumber":"300","timestamp":"1790000000","stateRoot":H(22)})
        h = HistoryFixture(f, s)
        h.tx[h.transactions[0]]["blockNumber"] = "0x1"
        with self.assertRaisesRegex(MuseumError, "ancestor span unsupported"): h.history().capture()

    def test_coverage_and_exact_shared_named_declarations(self):
        from .exhibitions import fields
        f = ValuationFixture(); v = valuation(); v.update(valuationId="urn:test:second-valuation")
        second = f.append("VALUATION", NAME, v); s = f.adapter(); s.snapshot()
        rows = admit(s, [f.valuation_hash, second]); files = render(rows, [], self.model)
        self.assertEqual(len(loads(files["valuations/index.json"])["resources"]), 4)
        coverage = loads(files["valuations/coverage.json"], maximum=2097152)
        original = {r["sourcePath"]:r["value"] for r in coverage if r["source"]["recordHash"] == f.valuation_hash}
        self.assertEqual(original, dict(fields(valuation())))
        f = ValuationFixture(); v = valuation(); v.update(valuationId="urn:test:conflict")
        v["issuer"]["name"]["value"] = "Same IRI, different full declaration"
        other = f.append("VALUATION", NAME, v); s = f.adapter(); s.snapshot()
        with self.assertRaisesRegex(MuseumError, "conflicting/cross-kind"): admit(s, [f.valuation_hash, other])

    def test_exact_registered_schema_jcs_and_original_loan_reference_hash(self):
        f = ValuationFixture(); f.register_schema(NAME, SCHEMA_BYTES, RAW_BYTES)
        s = f.adapter(); s.snapshot()
        self.assertEqual(admit(s, [f.valuation_hash])[0]["reasonCode"], "registered_valuation_definition_unsupported")
        f = ValuationFixture(edit=lambda v: v["insuranceValuation"]["hash"].update(digest=H(95)))
        s = f.adapter(); s.snapshot()
        with self.assertRaisesRegex(MuseumError, "linked reference"): admit_loans(s, [f.loan_hash])

    def test_loan_scope_and_withdrawal_are_not_overridden_by_order(self):
        for mutate, reason in ((lambda v: v.update(scope={"kind": "loan", "loanId": "urn:another:loan"}), "valuation_declares_another_loan"),
            (lambda v: v.update(status="withdrawn"), "selected_valuation_withdrawn")):
            f, s, rows = self.setup_rows(edit_valuation=mutate); e = HistoryFixture(f, s).history().capture()
            self.assertEqual(loan_joins(s, admit_loans(s, [f.loan_hash]), rows, e)[0]["reasonCode"], reason)

    def test_recorded_entrypoint_refuses_synthetic_and_preserves_explicit_replay(self):
        f, s, rows = self.setup_rows(); plan = dumps({"version": "1", "ownerSourceHash": keccak256(s.snapshot()), "records": [f.valuation_hash], "loans": [f.loan_hash]})
        with self.assertRaisesRegex(MuseumError, "concrete recorded"):
            project_valuations(s, plan, plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, source_hash=keccak256(s.snapshot()), model=self.model)
        s, _, _ = f.replay(); s.snapshot(); h, _, _ = HistoryFixture(f, s).replay()
        plan = dumps({"version": "1", "ownerSourceHash": keccak256(s.snapshot()), "records": [f.valuation_hash], "loans": [f.loan_hash]})
        with patch("socket.socket", side_effect=AssertionError("offline")):
            files = project_valuations(s, plan, plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, source_hash=keccak256(s.snapshot()), model=self.model, history=h)
        self.assertEqual(loads(files["valuations/loan-insurance.json"])[0]["status"], "ordered_selected_unsuperseded_reference")

    def test_actual_recorded_package_absence_and_strict_offline_reconstruction(self):
        original = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins())
        loan_plan = dumps({"version": "1", "ownerSourceHash": None, "records": []})
        plan = dumps({"version": "1", "ownerSourceHash": None, "records": [], "loans": []})
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); write_package(original, root/"account")
            loan = build_loan_package(root/"account", original.manifest_hash, loan_plan, plan_hash=keccak256(loan_plan), profile_hash=LOAN_PROFILE, disclosure="public")
            write_package(loan, root/"loan")
            with patch("socket.socket", side_effect=AssertionError("offline")):
                result = build_valuation_package(root/"loan", loan.manifest_hash, plan, plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, disclosure="public")
                self.assertEqual(loads(dict(result.files)["valuations/report.json"])["reasonCode"], "owner_source_missing")
                write_package(result, root/"export"); self.assertEqual(verify_package(root/"export", result.manifest_hash), result)

    def test_synthetic_owner_history_package_replay_literal_source_and_tamper(self):
        actual = load_source(); f = ValuationFixture(anchor=actual.anchor); s, owner_inputs, _ = f.replay(); s.snapshot()
        _, history_inputs, history_pins = HistoryFixture(f, s).replay()
        owner_pins = {"anchorHash": keccak256(owner_inputs["anchor.json"]), "transcriptHash": keccak256(owner_inputs["transcript.json"]), "sourceHash": keccak256(s.snapshot())}
        loan_plan = dumps({"version": "1", "ownerSourceHash": owner_pins["sourceHash"], "records": [f.loan_hash]})
        plan = dumps({"version": "1", "ownerSourceHash": owner_pins["sourceHash"], "records": [f.valuation_hash], "loans": [f.loan_hash]})
        original = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins())
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); write_package(original, root/"account")
            loan = build_loan_package(root/"account", original.manifest_hash, loan_plan, plan_hash=keccak256(loan_plan), profile_hash=LOAN_PROFILE,
                owner_inputs=owner_inputs, owner_pins=owner_pins, disclosure="public")
            write_package(loan, root/"loan")
            with patch("socket.socket", side_effect=AssertionError("offline")):
                result = build_valuation_package(root/"loan", loan.manifest_hash, plan, plan_hash=keccak256(plan), profile_hash=PROFILE_HASH,
                    history_inputs=history_inputs, history_pins=history_pins, disclosure="public")
                for p, raw in loan.files: self.assertEqual(dict(result.files)["source/"+p], raw)
                write_package(result, root/"export"); self.assertEqual(verify_package(root/"export", result.manifest_hash), result)
            altered = changed(result, "valuations/loan-insurance.json", dumps([{"legalOperativenessProven": True}]))
            write_package(altered, root/"changed")
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction"): verify_package(root/"changed", altered.manifest_hash)
            for pin in history_pins:
                with self.assertRaises(MuseumError):
                    build_valuation_package(root/"loan", loan.manifest_hash, plan, plan_hash=keccak256(plan), profile_hash=PROFILE_HASH,
                        history_inputs=history_inputs, history_pins={**history_pins, pin: H(99)}, disclosure="public")

    def test_public_disclosure_and_external_plan_profile_pins(self):
        plan = dumps({"version": "1", "ownerSourceHash": None, "records": [], "loans": []})
        with self.assertRaisesRegex(MuseumError, "public classification"):
            build_valuation_package("unused", H(2), plan, plan_hash=keccak256(plan), profile_hash=PROFILE_HASH, disclosure="restricted")
        for plan_hash, profile_hash in ((H(1), PROFILE_HASH), (keccak256(plan), H(2))):
            with self.assertRaisesRegex(MuseumError, "profile/plan"):
                project_valuations(None, plan, plan_hash=plan_hash, profile_hash=profile_hash, source_hash=None, model=self.model)


if __name__ == "__main__": unittest.main()
