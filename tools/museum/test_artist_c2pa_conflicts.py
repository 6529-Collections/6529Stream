"""Synthetic exact-wire tests for supplied ART38 V2 conflict histories.

These fixtures are internally consistent ABI and hash vectors.  They are not
RPC observations, authenticated op46 receipts, C2PA validation, governance or
archive evidence, or frozen presentation proof.
"""

from dataclasses import replace
import unittest
from unittest.mock import patch

from . import artist_c2pa as v1
from . import artist_c2pa_conflicts as c
from .canonical import MuseumError, keccak256, loads, subject_id
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .test_artist_c2pa import A, Fixture as V1Fixture, H


V1_PROFILE_HASH = "0xb4386628b712c4d4ee084148c817681eb5c6b61820aa7cb9635caa166cf3c820"


class Fixture:
    """Construct exact V1 selections plus the complete native conflict prefix."""

    def __init__(self, *, subject=None, recorded_base=30, constant_recorded_at=None):
        self.base = V1Fixture()
        self.recorded_base = recorded_base
        self.constant_recorded_at = constant_recorded_at
        if subject is not None:
            self.base.subject = subject
            self.base.context = replace(self.base.context, subject_id=subject)

    def selection_chain(self, adverse=(True,), *, stale=False):
        raws, reports, selected, previous = [], [], [], ZERO
        for revision, is_adverse in enumerate(adverse, 1):
            report = self.base.report(H("credential record 1"), H("credential enumeration"),
                claimHash=H("conflict claim " + str(revision)),
                validation=1, authorship=2 if is_adverse else 1,
                assertsAuthorship=True)
            raw, evidence, row = self.base.selection(report, previous=previous,
                revision=revision, index=4 + revision, authorization=4)
            raws.append(raw); reports.append(evidence); selected.append(row); previous = row[2]
        display = self.base.display(selected[-1], current=not stale,
            validation=0 if stale else None, authorship=0 if stale else None)
        return tuple(raws), tuple(reports), tuple(selected), display

    def conflict(self, selection, revision, previous, previous_chain):
        report = selection[6]
        blank = (ZERO, *report[2:7], selection[0], selection[2], previous, ZERO,
                 revision, self.recorded_base + revision if self.constant_recorded_at is None
                 else self.constant_recorded_at)
        identifier = self.conflict_hash(blank)
        chain = self.chain_hash(previous_chain, identifier, revision)
        return (identifier, *blank[1:9], chain, *blank[10:])

    def conflict_hash(self, conflict):
        blank = (ZERO, *conflict[1:9], ZERO, *conflict[10:])
        return keccak256(encode(("bytes32", "uint256", "address", "address", "address", c.CONFLICT),
            (c.DOMAIN, self.base.context.chain_id, self.base.context.companion,
             self.base.context.core, self.base.context.artist, blank)))

    @staticmethod
    def chain_hash(previous, identifier, revision):
        return keccak256(encode(("bytes32", "bytes32", "bytes32", "uint64"),
                                (c.CHAIN, previous, identifier, revision)))

    def narrative(self, conflict):
        context = self.base.context
        return encode(("bytes32", "uint256", "address", "address", "address", "uint256",
            "bytes32", "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bytes32",
            "bytes32", "uint8"),
            (c.DISPOSITION, context.chain_id, context.companion, context.core, context.artist,
             *conflict[1:6], conflict[0], conflict[9], conflict[6], conflict[7], 1))

    def acknowledgement(self, conflict, *, current_head=None, same_block=False):
        intended = self.narrative(conflict)
        dispute = H("dispute " + conflict[0])
        raw_evidence = encode(c.EVIDENCE, (1, conflict[1], conflict[5], conflict[4],
                                          dispute, keccak256(intended)))
        evidence_hash = keccak256(raw_evidence)
        narrative_hash = keccak256(intended)
        action = H("action " + conflict[0])
        acknowledged = conflict[11] + 10
        stored = (action, dispute, evidence_hash, narrative_hash, acknowledged)
        terms = (conflict[1], conflict[5], dispute, 1, evidence_hash,
                 narrative_hash, H("terms tail"))
        original = (terms, action, A(701), A(702), 1, 1, acknowledged,
                    H("resolution decision"), H("resolution receipt"))
        closed_head = (dispute, H("prior dispute"), action, 1, 1, False, False)
        filing = (conflict[1], conflict[5], 1, H("filing reason"), H("filing evidence"))
        opening = (dispute, filing, A(703), 1, 1, conflict[11], conflict[3], conflict[4],
            H("filing narrative"), H("filing chain"),
            (H("standing record"), conflict[5], 1, H("standing chain")), H("opening tail"))
        coverage_code = b"synthetic archival coverage runtime"
        coverage = (H("coverage root"), H("coverage family"), ZERO, evidence_hash,
                    *[H("coverage " + str(i)) for i in range(8)])
        block_number = (self.base.context.block_number if same_block else
                        self.base.context.block_number - 10 + conflict[10])
        block_hash = self.base.context.block_hash if same_block else H("ack block " + str(block_number))
        item = c.Acknowledgement(conflict[0], block_number, block_hash, acknowledged,
            encode((c.ARTIST_RESOLUTION,), (original,)),
            encode((c.ARTIST_HEAD,), (closed_head,)), encode((c.ARTIST_RECORD,), (opening,)),
            encode(("bytes",), (raw_evidence,)), encode(("bytes",), (intended,)),
            encode(("address",), (A(704),)), encode(("bytes32",), (keccak256(coverage_code),)),
            coverage_code, encode(c.COVERAGE, coverage), current_head)
        return stored, item

    def scope(self, adverse=(True,), *, cleared=(), stale=False, current_heads=None):
        raw, reports, selections, display = self.selection_chain(adverse, stale=stale)
        conflicts, previous, previous_chain = [], ZERO, ZERO
        for selection in (row for row in selections if row[6][26] and row[6][25] == 2):
            conflict = self.conflict(selection, len(conflicts) + 1, previous, previous_chain)
            conflicts.append(conflict); previous, previous_chain = conflict[0], conflict[9]
        history, acknowledgements, unresolved = [], [], []
        current_heads = current_heads or {}
        for index, conflict in enumerate(conflicts):
            if index in cleared:
                resolution, ack = self.acknowledgement(conflict,
                    current_head=current_heads.get(index))
                acknowledgements.append(ack)
            else:
                resolution = c.EMPTY_RESOLUTION; unresolved.append(conflict)
            history.append(c.ConflictEvidence(encode(("bytes32",), (conflict[0],)),
                encode((c.CONFLICT,), (conflict,)), encode((c.RESOLUTION,), (resolution,)),
                encode(("bytes",), (self.narrative(conflict),))))
        tail = unresolved[-1] if unresolved else None
        standing = (ZERO if tail is None else tail[0], previous_chain,
            ZERO if tail is None else tail[6], ZERO if tail is None else tail[7],
            len(conflicts), len(unresolved))
        scope = c.ScopeEvidence(self.base.context, self.base.definition, raw[-1], raw, display,
            reports, encode((c.STANDING,), (standing,)), tuple(history), tuple(acknowledgements),
            A(705), A(706))
        return scope, conflicts, selections

    def empty_scope(self):
        empty_report = tuple(False if kind == "bool" else "" if kind == "string" else
            ZERO if kind == "bytes32" else 0 for kind in v1.REPORT)
        empty_selection = (ZERO, ZERO, ZERO, 0, 0, 0, empty_report)
        current = encode((v1.SELECTION,), (empty_selection,))
        display = encode((v1.DISPLAY,), ((ZERO, ZERO, 0, 0, False, False),))
        return c.ScopeEvidence(self.base.context, self.base.definition, current, (), display, (),
            encode((c.STANDING,), (c.EMPTY_STANDING,)), (), (), A(705), A(706))


class ArtistC2PAConflictsTest(unittest.TestCase):
    def setUp(self):
        self.f = Fixture()

    def reject(self, scope):
        with self.assertRaises(MuseumError):
            c.consume(scope)

    def test_active_stale_and_superseded_selection_retain_conflict_history(self):
        active, conflicts, _ = self.f.scope()
        result = c.consume(active)
        self.assertEqual(result["standing"]["unresolvedCount"], "1")
        self.assertEqual(result["conflictHistory"][0]["conflictId"], conflicts[0][0])
        self.assertIsNone(result["conflictHistory"][0]["acknowledgement"])
        self.assertFalse(result["claims"]["laterDisputesAutomaticallyRevive"])

        stale, _, _ = self.f.scope(stale=True)
        stale_result = c.consume(stale)
        self.assertFalse(stale_result["reconciliation"]["displayObservation"]["current"])
        self.assertEqual(len(stale_result["conflictHistory"]), 1)

        superseded, _, selections = self.f.scope((True, False))
        superseded_result = c.consume(superseded)
        self.assertEqual(len(superseded_result["conflictHistory"]), 1)
        self.assertEqual(superseded_result["conflictHistory"][0]["selectionHash"], selections[0][2])
        self.assertEqual(superseded_result["reconciliation"]["selectionHistory"][-1]["report"]["authorshipLabel"],
                         "consistent")

    def test_fixture_preimages_independently_match_consumer_hashes_and_narrative(self):
        scope, conflicts, _ = self.f.scope((True, True))
        previous, previous_chain = ZERO, ZERO
        for revision, conflict in enumerate(conflicts, 1):
            self.assertEqual(self.f.conflict_hash(conflict), c.conflict_hash(scope.context, conflict))
            self.assertEqual(self.f.chain_hash(previous_chain, conflict[0], revision), conflict[9])
            self.assertEqual(self.f.narrative(conflict), c.narrative(scope.context, conflict))
            previous, previous_chain = conflict[0], conflict[9]

    def test_fully_cleared_prefix_retains_every_revision_and_original_guard(self):
        scope, conflicts, _ = self.f.scope((True, True), cleared=(0, 1))
        result = c.consume(scope)
        self.assertEqual(result["standing"]["revision"], "2")
        self.assertEqual(result["standing"]["unresolvedCount"], "0")
        self.assertEqual(result["standing"]["conflictId"], ZERO)
        self.assertNotEqual(result["standing"]["chainHash"], ZERO)
        self.assertEqual(result["checkedAcknowledgements"], "2")
        self.assertEqual([row["revision"] for row in result["conflictHistory"]], ["1", "2"])
        self.assertTrue(all(row["acknowledgement"]["basis"] ==
            "supplied_historical_original_guard_correspondence" for row in result["conflictHistory"]))
        self.assertEqual([row["conflictId"] for row in result["conflictHistory"]],
                         [row[0] for row in conflicts])
        self.assertFalse(result["claims"]["op46GovernanceAuthenticated"])
        self.assertFalse(result["claims"]["originalArtistNativeReceiptInvented"])

    def test_out_of_order_clear_preserves_new_unresolved_tail(self):
        scope, conflicts, _ = self.f.scope((True, True), cleared=(0,))
        result = c.consume(scope)
        self.assertEqual((result["standing"]["revision"], result["standing"]["unresolvedCount"]),
                         ("2", "1"))
        self.assertEqual(result["standing"]["conflictId"], conflicts[1][0])
        self.assertIsNotNone(result["conflictHistory"][0]["acknowledgement"])
        self.assertIsNone(result["conflictHistory"][1]["acknowledgement"])

        newer_cleared, conflicts, _ = self.f.scope((True, True), cleared=(1,))
        result = c.consume(newer_cleared)
        self.assertEqual(result["standing"]["conflictId"], conflicts[0][0])
        self.assertEqual(result["standing"]["unresolvedCount"], "1")
        self.assertIsNone(result["conflictHistory"][0]["acknowledgement"])
        self.assertIsNotNone(result["conflictHistory"][1]["acknowledgement"])

    def test_conflict_hash_record_selection_prefix_and_abi_mismatches_reject(self):
        scope, _, _ = self.f.scope((True, True))
        first, second = scope.history
        changes = (
            replace(first, at=encode(("bytes32",), (H("wrong at"),))),
            replace(first, record=first.record + bytes(32)),
            replace(first, narrative=encode(("bytes",), (b"wrong narrative",))),
            replace(first, resolution=encode((c.RESOLUTION,), ((H("partial"), ZERO, ZERO, ZERO, 0),))),
        )
        for changed in changes:
            with self.subTest(field=changed):
                self.reject(replace(scope, history=(changed, second)))
        self.reject(replace(scope, history=(second, first)))
        self.reject(replace(scope, history=(first,)))
        self.reject(replace(scope, selections=tuple(reversed(scope.selections)),
                            reports=tuple(reversed(scope.reports)), current=scope.selections[0]))
        overflow = bytearray(first.record); overflow[10 * 32:11 * 32] = (1 << 64).to_bytes(32, "big")
        self.reject(replace(scope, history=(replace(first, record=bytes(overflow)), second)))

        one, _, _ = self.f.scope()
        original, = decode((c.CONFLICT,), one.history[0].record)
        changed = list(original); changed[7] = H("self-consistent foreign selection")
        changed[0] = ZERO; changed[9] = ZERO
        changed[0] = self.f.conflict_hash(tuple(changed))
        changed[9] = self.f.chain_hash(ZERO, changed[0], 1)
        changed = tuple(changed)
        evidence = c.ConflictEvidence(encode(("bytes32",), (changed[0],)),
            encode((c.CONFLICT,), (changed,)), one.history[0].resolution,
            encode(("bytes",), (self.f.narrative(changed),)))
        standing = (changed[0], changed[9], changed[6], changed[7], 1, 1)
        self.reject(replace(one, history=(evidence,),
                            standing=encode((c.STANDING,), (standing,))))

    def test_missing_unknown_and_duplicate_acknowledgements_reject(self):
        cleared, _, _ = self.f.scope(cleared=(0,))
        self.reject(replace(cleared, acknowledgements=()))
        unresolved, conflicts, _ = self.f.scope()
        _, unrelated = self.f.acknowledgement(conflicts[0])
        unrelated = replace(unrelated, conflict_id=H("unrelated conflict"))
        self.reject(replace(unresolved, acknowledgements=(unrelated,)))
        self.reject(replace(cleared, acknowledgements=cleared.acknowledgements * 2))

    def test_every_native_clear_guard_input_is_required(self):
        scope, _, _ = self.f.scope(cleared=(0,))
        ack = scope.acknowledgements[0]
        original, = decode((c.ARTIST_RESOLUTION,), ack.original_resolution)
        wrong_terms = list(original[0]); wrong_terms[1] += 1
        wrong_original = (tuple(wrong_terms), *original[1:])
        opening, = decode((c.ARTIST_RECORD,), ack.opening)
        wrong_opening = list(opening); wrong_opening[7] = H("wrong opening binding")
        bad_head = encode((c.ARTIST_HEAD,), ((H("other dispute"), ZERO, H("other action"),
                                             1, 1, False, False),))
        mutations = (
            replace(ack, original_resolution=ack.original_resolution + bytes(32)),
            replace(ack, original_resolution=encode((c.ARTIST_RESOLUTION,), (wrong_original,))),
            replace(ack, closed_head=bad_head),
            replace(ack, opening=ack.opening + bytes(32)),
            replace(ack, opening=encode((c.ARTIST_RECORD,), (tuple(wrong_opening),))),
            replace(ack, evidence_chunk=encode(("bytes",), (b"wrong",))),
            replace(ack, narrative_chunk=encode(("bytes",), (b"wrong",))),
            replace(ack, coverage_address=encode(("address",), (ZERO_ADDRESS,))),
            replace(ack, coverage_code_hash=encode(("bytes32",), (H("wrong code"),))),
            replace(ack, coverage_code=ack.coverage_code + b"changed"),
            replace(ack, coverage_facts=encode(c.COVERAGE, (ZERO,) * 12)),
        )
        for changed in mutations:
            with self.subTest(changed=changed):
                self.reject(replace(scope, acknowledgements=(changed,)))

    def test_original_resolution_class_enum_participants_time_and_coverage_guards(self):
        scope, conflicts, _ = self.f.scope(cleared=(0,))
        ack = scope.acknowledgements[0]
        original, = decode((c.ARTIST_RESOLUTION,), ack.original_resolution)

        terms = list(original[0]); terms[3] = 2
        class_two = list(original); class_two[0] = tuple(terms); class_two[4] = 2
        class_two_ack = replace(ack,
            original_resolution=encode((c.ARTIST_RESOLUTION,), (tuple(class_two),)))
        result = c.consume(replace(scope, acknowledgements=(class_two_ack,)))
        self.assertEqual(result["checkedAcknowledgements"], "1")

        def changed_original(*, term_kind=None, **fields):
            value = list(original); changed_terms = list(value[0])
            if term_kind is not None:
                changed_terms[3] = term_kind
            value[0] = tuple(changed_terms)
            for index, replacement in fields.items():
                value[int(index)] = replacement
            return replace(ack,
                original_resolution=encode((c.ARTIST_RESOLUTION,), (tuple(value),)))

        invalid = (
            changed_original(term_kind=2, **{"4": 1}),
            changed_original(term_kind=0),
            changed_original(term_kind=3),
            changed_original(**{"2": ZERO_ADDRESS}),
            changed_original(**{"3": ZERO_ADDRESS}),
            changed_original(**{"8": ZERO}),
            changed_original(**{"6": conflicts[0][11] - 1}),
            changed_original(**{"6": ack.block_timestamp + 1}),
        )
        for changed in invalid:
            with self.subTest(changed=changed):
                self.reject(replace(scope, acknowledgements=(changed,)))

        coverage, = decode((c.COVERAGE,), ack.coverage_facts)
        for index, replacement in ((2, H("forbidden coverage artist")),
                                   (3, H("mismatched coverage evidence"))):
            changed = list(coverage); changed[index] = replacement
            changed_ack = replace(ack, coverage_facts=encode(c.COVERAGE, tuple(changed)))
            self.reject(replace(scope, acknowledgements=(changed_ack,)))

    def test_historical_original_generation_is_not_rewritten_by_later_current_head(self):
        reopened = encode((c.ARTIST_HEAD,), ((H("later record"), H("prior"), H("later action"),
                                              1, 1, True, False),))
        scope, _, _ = self.f.scope(cleared=(0,), current_heads={0: reopened})
        result = c.consume(scope)
        acknowledgement = result["conflictHistory"][0]["acknowledgement"]
        self.assertFalse(acknowledgement["currentArtistHead"]["affectsHistoricalAcknowledgement"])
        self.assertEqual(acknowledgement["originalQuery"]["generation"], "1")
        ack = scope.acknowledgements[0]
        self.reject(replace(scope, acknowledgements=(replace(ack, closed_head=reopened),)))

    def test_same_block_acknowledgement_requires_exact_source_hash(self):
        scope, _, _ = self.f.scope(cleared=(0,))
        ack = scope.acknowledgements[0]
        same = replace(ack, block_number=scope.context.block_number,
                       block_hash=scope.context.block_hash)
        result = c.consume(replace(scope, acknowledgements=(same,)))
        self.assertEqual(result["conflictHistory"][0]["acknowledgement"]["observation"]["blockHash"],
                         scope.context.block_hash)
        wrong = replace(same, block_hash=H("wrong same block"))
        self.reject(replace(scope, acknowledgements=(wrong,)))
        for changed in (replace(ack, block_number=scope.context.block_number + 1),
                        replace(ack, block_number=-1),
                        replace(ack, block_hash=ZERO),
                        replace(ack, block_timestamp=ack.block_timestamp + 1)):
            with self.subTest(changed=changed):
                self.reject(replace(scope, acknowledgements=(changed,)))

    def test_reused_historical_block_observations_must_agree(self):
        same_time_scope, _, _ = Fixture(constant_recorded_at=31).scope(
            (True, True), cleared=(0, 1))
        first, second = same_time_scope.acknowledgements
        same_block_wrong_hash = replace(second, block_number=first.block_number,
            block_hash=H("conflicting block hash"))
        with self.assertRaisesRegex(MuseumError, "conflicting acknowledgement block observations"):
            c.consume(replace(same_time_scope,
                              acknowledgements=(first, same_block_wrong_hash)))

        scope, _, _ = self.f.scope((True, True), cleared=(0, 1))
        first, second = scope.acknowledgements
        same_block_wrong_time = replace(second, block_number=first.block_number,
            block_hash=first.block_hash)
        with self.assertRaisesRegex(MuseumError, "conflicting acknowledgement block observations"):
            c.consume(replace(scope, acknowledgements=(first, same_block_wrong_time)))

    def test_empty_scope_is_complete_and_has_no_conflict_tail(self):
        result = c.consume(self.f.empty_scope())
        self.assertEqual(result["conflictHistory"], [])
        self.assertEqual(result["standing"]["revision"], "0")
        self.assertEqual(result["checkedAcknowledgements"], "0")

    def test_static_collection_and_token_scopes_are_independent_without_fallback(self):
        prototype = V1Fixture().context
        collection_subject = subject_id("collection", str(prototype.chain_id), prototype.core,
                                        str(prototype.collection_id))
        token_subject = subject_id("token", str(prototype.chain_id), prototype.core,
            str(prototype.collection_id), token_id="9")
        collection, _, _ = Fixture(subject=collection_subject).scope()
        token, _, _ = Fixture(subject=token_subject).scope(cleared=(0,))
        collection_standing, = decode((c.STANDING,), collection.standing)
        token_standing, = decode((c.STANDING,), token.standing)
        raw = encode((c.STANDING, c.STANDING), (token_standing, collection_standing))
        result = c.consume_static(9, raw, collection, token)
        self.assertEqual(result["tokenId"], "9")
        self.assertTrue(result["bothScopesRetainedIndependently"])
        self.assertEqual(result["collection"]["sourceContext"]["subjectId"], collection_subject)
        self.assertEqual(result["token"]["sourceContext"]["subjectId"], token_subject)
        with self.assertRaises(MuseumError):
            c.consume_static(9, raw, collection, None)
        with self.assertRaises(MuseumError):
            c.consume_static(9, raw, collection, "not a token scope")
        with self.assertRaises(MuseumError):
            c.consume_static(9, encode((c.STANDING, c.STANDING),
                (collection_standing, token_standing)), collection, token)

        empty = c.EMPTY_STANDING
        collection_only = encode((c.STANDING, c.STANDING), (empty, collection_standing))
        result = c.consume_static(0, collection_only, collection)
        self.assertIsNone(result["token"])
        with self.assertRaises(MuseumError):
            c.consume_static(0, raw, collection)
        with self.assertRaises(MuseumError):
            c.consume_static(0, collection_only, "not a scope")
        malformed_context = replace(collection,
            context=replace(collection.context, subject_id=H("wrong collection subject")))
        with self.assertRaises(MuseumError):
            c.consume_static(0, collection_only, malformed_context)

        cleared_collection, _, _ = Fixture(subject=collection_subject).scope(cleared=(0,))
        cleared_token, _, _ = Fixture(subject=token_subject).scope(cleared=(0,))
        collection_value, = decode((c.STANDING,), cleared_collection.standing)
        token_value, = decode((c.STANDING,), cleared_token.standing)
        pair = encode((c.STANDING, c.STANDING), (token_value, collection_value))
        shared = c.consume_static(9, pair, cleared_collection, cleared_token)
        self.assertEqual(shared["collection"]["checkedAcknowledgements"], "1")
        self.assertEqual(shared["token"]["checkedAcknowledgements"], "1")
        token_ack = cleared_token.acknowledgements[0]
        conflicting_token = replace(cleared_token, acknowledgements=(replace(token_ack,
            block_hash=H("cross-scope conflicting hash")),))
        with self.assertRaises(MuseumError):
            c.consume_static(9, pair, cleared_collection, conflicting_token)
        later_token, _, _ = Fixture(subject=token_subject, recorded_base=31).scope(cleared=(0,))
        later_value, = decode((c.STANDING,), later_token.standing)
        later_pair = encode((c.STANDING, c.STANDING), (later_value, collection_value))
        with self.assertRaises(MuseumError):
            c.consume_static(9, later_pair, cleared_collection, later_token)

    def test_aggregate_bound_precedes_decode_and_v1_profile_is_unchanged(self):
        scope, _, _ = self.f.scope()
        malformed = replace(scope, standing=b"not ABI")
        with patch.object(v1, "MAX_INPUT_BYTES", 1), self.assertRaisesRegex(
                MuseumError, "aggregate offchain input bound"):
            c.consume(malformed)
        self.assertEqual(keccak256(v1.profile_bytes()), V1_PROFILE_HASH)
        self.assertEqual(loads(c.profile_bytes(), canonical=True)["parentProfileHash"],
                         V1_PROFILE_HASH)


if __name__ == "__main__":
    unittest.main()
