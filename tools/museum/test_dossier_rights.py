"""Canonical RIGHTS composition, exact package replay and explicit synthetic joins."""
from contextlib import ExitStack
from copy import deepcopy
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import dossier_rights as package
from . import test_dossier_gather as gathered
from .bagit import write_tree
from .canonical import MuseumError, dumps, keccak256, loads, schema_id, subject_id
from .independent_wire import ZERO
from .metadata_rights_source import PROFILE_HASH as RIGHTS_PROFILE_HASH, RECORD_TYPE, SCHEMA_NAME
from ..metadata import rights_profile
from ..metadata.genesis_dossier_profile import USES

A = lambda n: "0x" + format(n, "040x")
H = lambda n: "0x" + format(n, "064x")


def source_result(anchor, *, collection=True, token=True):
    """Supplied decoded source stub, never a claimed native capture."""
    result = {"identity": {"tokenId": anchor["tokenId"], "collectionId": anchor["collectionId"],
        "collectionSerial": "1", "burned": False, "lifecycle": "2"}, "records": [], "documents": [], "scopes": {}}
    for scope, present, ordinal in (("collection", collection, 1), ("token", token, 2)):
        sid = subject_id(scope, anchor["chainId"], anchor["core"], anchor["collectionId"],
            token_id=anchor["tokenId"] if scope == "token" else "0")
        result["scopes"][scope] = {"status": "present" if present else "absent", "subjectId": sid,
            "current": [H(ordinal)] if present else [ZERO] * 14, "history": []}
        if not present:
            continue
        value = rights_profile.examples()[0]
        value.update(subjectId=sid, profileHash=RIGHTS_PROFILE_HASH)
        if scope == "collection":
            for use in USES: value["grants"][use]["status"] = "granted"
        else:
            value["grants"]["ai_training"]["status"] = "denied"
        raw = dumps(value)
        record = [RECORD_TYPE, sid, ["1", keccak256(raw), schema_id("RFC8785_JCS")], "ipfs://notice",
            schema_id(SCHEMA_NAME), ZERO, ["0", "0x", ZERO], "1770000000"]
        receipt = [anchor["collectionId"], A(ordinal), str(6 + ordinal), "1780000000", str(ordinal - 1),
            H(800), H(801), H(802), ZERO]
        result["records"].append({"recordHash": H(ordinal), "record": record, "receipt": receipt,
            "payloadHex": "0x" + raw.hex(), "value": value,
            "publication": {"recordedBlock": "1", "log": {"transactionHash": H(901)}}})
    selected = next((r for r in reversed(result["records"])), None)
    effective = {use: selected["value"]["grants"][use]["status"] if selected else "unspecified" for use in USES}
    count = sum(v != "unspecified" for v in effective.values())
    result.update(effectiveGrants=effective, completeness="absent" if selected is None else
        "specified" if count == 6 else "unspecified" if count == 0 else "partially_specified")
    return result


class RightsFragmentTests(unittest.TestCase):
    def setUp(self):
        self.a = {"chainId": "31337", "core": A(10), "collectionId": "1", "tokenId": "71",
            "host": A(11), "blockNumber": "9"}

    def fragment(self, result):
        return package._fragment(result, self.a, dumps(result))

    def test_token_unspecified_overrides_collection_granted_for_every_explicit_use(self):
        result = source_result(self.a)
        fragment = self.fragment(result)
        self.assertEqual(fragment["collection"]["grants"]["reproduction"], "granted")
        self.assertEqual(fragment["effectiveGrants"]["reproduction"], "unspecified")
        self.assertEqual(fragment["effectiveGrants"]["ai_training"], "denied")
        self.assertEqual(fragment["completeness"], "partially_specified")
        self.assertEqual(fragment["token"]["record"]["signer"], A(2))
        self.assertEqual(fragment["token"]["record"]["authorityClass"], "8")
        self.assertEqual(fragment["token"]["record"]["recordedBlock"], "1")
        self.assertEqual(fragment["selectionEvidence"]["hash"]["digest"], keccak256(dumps(result)))

    def test_collection_only_both_absent_and_present_unspecified_are_distinct(self):
        collection = self.fragment(source_result(self.a, token=False))
        self.assertIsNone(collection["token"])
        self.assertEqual(collection["completeness"], "specified")
        empty = self.fragment(source_result(self.a, collection=False, token=False))
        self.assertIsNone(empty["collection"])
        self.assertEqual(empty["completeness"], "absent")
        unspecified = source_result(self.a, collection=False)
        unspecified["records"][0]["value"]["grants"]["ai_training"]["status"] = "unspecified"
        unspecified.update(effectiveGrants={use: "unspecified" for use in USES}, completeness="unspecified")
        self.assertEqual(self.fragment(unspecified)["completeness"], "unspecified")
        self.assertIsNotNone(self.fragment(unspecified)["token"])

    def test_publisher_authority_scope_family_schema_and_publication_block_must_remain_original(self):
        changes = [lambda r: r["scopes"]["token"].update(subjectId=H(99)),
            lambda r: r["scopes"]["token"].update(status="unknown"),
            lambda r: r["records"][1]["record"].__setitem__(0, H(99)),
            lambda r: r["records"][1]["record"].__setitem__(4, H(99)),
            lambda r: r["records"][1]["receipt"].__setitem__(2, "1"),
            lambda r: r["records"][1]["publication"].update(recordedBlock="10"),
            lambda r: r["records"][1]["publication"].update(recordedBlock="1780000000"),
            lambda r: r.update(completeness="specified"),
            lambda r: r["effectiveGrants"].update(reproduction="granted")]
        for change in changes:
            result = source_result(self.a); change(result)
            with self.subTest(change=change), self.assertRaises(MuseumError): self.fragment(result)

    def test_original_dates_raw_payload_and_receipt_are_retained(self):
        result = source_result(self.a)
        before = deepcopy(result)
        files = package._extract(result)
        self.assertEqual(result, before)
        row = result["records"][0]
        prefix = "rights/records/" + row["recordHash"][2:]
        self.assertEqual(files[prefix + "/payload.json"], bytes.fromhex(row["payloadHex"][2:]))
        self.assertEqual(loads(files[prefix + "/original.json"]), row)
        index = loads(files["rights/records.json"])
        self.assertEqual(index["records"][0]["effectiveDates"], row["value"]["effectiveDates"])
        changed = deepcopy(result); changed["records"][0]["payloadHex"] = "0x00"
        with self.assertRaisesRegex(MuseumError, "payload differs"): package._extract(changed)


class RightsPackageTests(unittest.TestCase):
    def setUp(self):
        self.base = gathered.GatherWrapperTests(); self.base.setUp()
        self.a = self.base.ref["sourceState"] | {"host": A(88)}
        self.result = source_result(self.a)
        self.capture = {"anchor.json": dumps(self.a), "transcript.json": dumps({"calls": []}),
            "snapshot.json": dumps(self.result)}
        self.pins = {name + "Hash": keccak256(self.capture[name + ".json"]) for name in ("anchor", "transcript", "snapshot")}
        self.pins["provenance"] = "synthetic_fixture"
        self.tools = {"tool/" + p + ".txt": b"raise RuntimeError('must remain inert')\n" for p in package.TOOL_NAMES}

    def context(self):
        stack = ExitStack()
        stack.enter_context(self.base.context())
        stack.enter_context(patch.object(package.mint, "_originals", return_value=self.base.originals))
        stack.enter_context(patch.object(package, "_capture", return_value=self.result))
        return stack

    def build(self, original=None):
        original = self.base.build() if original is None else original
        return package.compose(dict(original.files), original.manifest_hash, disclosure="public",
            rights_files=self.capture, rights_pins=self.pins, tool_snapshot=self.tools)

    def test_round_trip_preserves_entire_base_and_closes_only_item7(self):
        with self.context():
            original = self.base.build(); result = self.build(original)
            rebuilt = package.verify(dict(result.files), result.manifest_hash)
        self.assertEqual(result.files, rebuilt.files)
        files = dict(result.files)
        self.assertEqual({p[len("examination/"):]: b for p, b in files.items() if p.startswith("examination/")}, dict(original.files))
        self.assertNotIn("7", result.report["unresolvedItems"])
        self.assertIn("6", result.report["unresolvedItems"])
        self.assertFalse(result.report["canonicalPacketReady"])
        self.assertEqual(result.report["rights"]["provenance"], "synthetic_fixture")
        self.assertEqual(len(result.report["items"]), 19)
        self.assertEqual(result.report["rights"]["status"], "complete_within_source_profile")
        self.assertEqual(files["rights/source/snapshot.json"], self.capture["snapshot.json"])
        self.assertEqual(loads(files["rights/packet-fragment.json"])["completeness"], "partially_specified")

    def test_required_capture_cannot_turn_missing_source_into_absent(self):
        with patch.object(package, "_base", side_effect=AssertionError("fail before replay")):
            for capture, pins in (({}, self.pins), (None, None), (self.capture, None),
                    (self.capture | {"extra": b"x"}, self.pins),
                    (self.capture, self.pins | {"snapshotHash": H(999)})):
                with self.subTest(capture=capture), self.assertRaises(MuseumError):
                    package.compose({}, "", disclosure="public", rights_files=capture, rights_pins=pins)

    def test_public_disclosure_precedes_all_reads(self):
        with patch.object(package, "_base", side_effect=AssertionError("no reads")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                package.compose({}, "", disclosure="restricted", rights_files={}, rights_pins={})
        args = ["dossier_rights", "build", "--examination", "missing", "--examination-hash", H(1),
            "--rights", "missing", "--rights-anchor-hash", H(2), "--rights-transcript-hash", H(3),
            "--rights-snapshot-hash", H(4), "--provenance", "synthetic_fixture", "--disclosure", "restricted",
            "--output", "missing"]
        with patch("sys.argv", args), patch.object(package, "read_tree", side_effect=AssertionError("no reads")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"): package.main()

    def test_rehashed_derived_or_original_output_cannot_bypass_reconstruction(self):
        with self.context():
            result = self.build()
            for path in ("rights/packet-fragment.json", "rights/records.json", "packet/fields.json"):
                files = dict(result.files); files[path] = dumps({"tampered": True})
                manifest = loads(result.manifest)
                manifest["files"] = [package.base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"]
                raw = dumps(manifest); files["manifest.json"] = raw
                with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "source reconstruction"):
                    package.verify(files, keccak256(raw))

    def test_manifest_pin_closed_claims_and_inventory_reject_before_source_replay(self):
        with self.context(): result = self.build()
        with patch.object(package, "compose", side_effect=AssertionError("must reject first")):
            with self.assertRaisesRegex(MuseumError, "external manifest"):
                package.verify(dict(result.files), H(999))
            with self.assertRaisesRegex(MuseumError, "file commitments"):
                package.verify(dict(result.files) | {"unlisted": b"data"}, result.manifest_hash)
            value = loads(result.manifest); value["claims"]["sourceConsensusVerified"] = True
            raw = dumps(value)
            with self.assertRaisesRegex(MuseumError, "closed manifest"):
                package.verify(dict(result.files) | {"manifest.json": raw}, keccak256(raw))

    def test_closed_dispatch_and_full_packet_refusal(self):
        from .package_v2 import verify_package
        with self.context(), TemporaryDirectory(prefix="rights-examination-") as temporary:
            result = self.build()
            with self.assertRaisesRegex(MuseumError, "unresolved items: 3, 4, 5, 6, 8"):
                package.complete_packet(dict(result.files), result.manifest_hash)
            directory = Path(temporary) / "package"; write_tree(dict(result.files), directory)
            self.assertEqual(verify_package(directory, result.manifest_hash).files, result.files)

    def test_mint_entropy_base_is_preserved_and_recursive_rights_base_is_rejected(self):
        from .test_dossier_mint_entropy import MintEntropyPackageTests
        prior = MintEntropyPackageTests(); prior.setUp()
        with prior.context(), patch.object(package, "_capture", return_value=self.result):
            original = prior.build()
            result = self.build(original)
            self.assertEqual(package.verify(dict(result.files), result.manifest_hash).files, result.files)
            self.assertEqual(dict(result.files)["examination/mint/report.json"], dict(original.files)["mint/report.json"])
            self.assertEqual(result.report["items"][3]["status"], original.report["items"][3]["status"])
            self.assertEqual(result.report["items"][3]["evidence"], ["examination/" + p for p in original.report["items"][3]["evidence"]])
            with self.assertRaisesRegex(MuseumError, "base examination mode unsupported"):
                self.build(result)


class RightsConcreteReplayTests(unittest.TestCase):
    """Concrete reader replay; original-reference inputs are explicitly synthetic."""

    def case(self, *, partial=False, **options):
        from .test_current_rights_source import CurrentRightsFixture
        from .test_object_dossier_native import reference
        f = CurrentRightsFixture(**options)
        if partial:
            f.append("token", "unspecified", block=2, edit=lambda v: v["grants"]["print"].update(status="denied"))
        # A retained receipt supplies an independently compared observation.
        # This fixture does not claim to be an actual paid-mint dossier.
        transaction, receipt = next(iter(f.receipts.items()))
        evidence = dumps({"tokenMint": {"transactionHash": transaction, "receipt": deepcopy(receipt)},
            "tokenSourceBlockViews": {}})
        f.a["deploymentEvidenceHash"] = keccak256(evidence)
        source = f.source(); snapshot = source.snapshot()
        result = loads(snapshot, maximum=package.MAX_BYTES)
        ref = reference(f.a, serial=result["identity"]["collectionSerial"])
        ref["coreFacts"].update({k: result["identity"][k] for k in ("lifecycle", "burned")})
        originals = {"deployment-evidence.json": evidence}
        examination = {"inputs/sources.json": dumps({"sources": []})}
        capture = {"anchor.json": source.anchor_bytes, "transcript.json": source.transcript(), "snapshot.json": snapshot}
        pins = {name + "Hash": keccak256(capture[name + ".json"]) for name in ("anchor", "transcript", "snapshot")}
        pins["provenance"] = "synthetic_fixture"
        return f, source, ref, originals, examination, capture, pins

    def replay(self, ref, originals, examination, capture, pins, *, outer=None):
        with patch("socket.socket", side_effect=AssertionError("concrete replay must stay offline")):
            return package._capture(examination if outer is None else outer, examination, originals, ref, capture, pins)

    def test_concrete_source_closes_both_scopes_and_all_four_completeness_states(self):
        cases = (({"collection": False}, "absent"), ({}, "specified"), ({"token": True}, "unspecified"),
            ({"partial": True}, "partially_specified"))
        for options, status in cases:
            f, source, ref, originals, examination, capture, pins = self.case(**options)
            result = self.replay(ref, originals, examination, capture, pins)
            fragment = package._fragment(result, f.a, capture["snapshot.json"])
            self.assertEqual(fragment["completeness"], status)
            self.assertEqual(result["mode"], "synthetic_fixture")
            self.assertEqual(set(package._extract(result)), set(package._extract(loads(source.snapshot(), maximum=package.MAX_BYTES))))

    def test_burned_token_keeps_original_rights_and_publication_authority(self):
        f, source, ref, originals, examination, capture, pins = self.case(token=True, burned=True, locked=True)
        result = self.replay(ref, originals, examination, capture, pins)
        self.assertTrue(result["identity"]["burned"])
        fragment = package._fragment(result, f.a, capture["snapshot.json"])
        self.assertEqual(fragment["token"]["record"]["recordedBlock"], "2")
        self.assertEqual(fragment["token"]["record"]["authorityClass"], "7")
        self.assertNotEqual(fragment["token"]["record"]["authorityClass"], result["scopes"]["token"]["current"][9])

    def test_independently_pinned_original_identity_and_shared_code_conflicts_reject(self):
        f, source, ref, originals, examination, capture, pins = self.case(token=True)
        for field, value in (("collectionSerial", "999"), ("tokenId", "999"), ("collectionId", "999")):
            changed = deepcopy(ref); changed["sourceState"][field] = value
            with self.subTest(field=field), self.assertRaises(MuseumError):
                self.replay(changed, originals, examination, capture, pins)
        changed = deepcopy(ref); changed["coreFacts"].update(lifecycle="3", burned=True)
        with self.assertRaisesRegex(MuseumError, "Core identity differs"):
            self.replay(changed, originals, examination, capture, pins)
        changed = deepcopy(ref)
        next(p for p in changed["sourceAnchor"]["runtimePins"] if p["address"] == f.a["rightsSelector"])["runtimeHash"] = H(999)
        with self.assertRaisesRegex(MuseumError, "runtime conflict"):
            self.replay(changed, originals, examination, capture, pins)

    def test_independently_hashed_shared_rpc_and_entropy_observations_must_agree(self):
        f, source, ref, originals, examination, capture, pins = self.case()
        query = next(r for r in source.reader.rows if r["method"] == "eth_chainId")
        changed = deepcopy(ref)
        changed["rpcReadPins"] = [{"requestHash": keccak256(dumps([query["method"], query["params"]])),
            "resultHash": keccak256(dumps("0x999"))}]
        with self.assertRaisesRegex(MuseumError, "conflicting results"):
            self.replay(changed, originals, examination, capture, pins)
        outer = {"entropy/source/transcript.json": dumps({"calls": [query | {"result": "0x999"}]})}
        with self.assertRaisesRegex(MuseumError, "conflicting results"):
            self.replay(ref, originals, examination, capture, pins, outer=outer)

    def test_rehashed_snapshot_and_provenance_cannot_bypass_concrete_replay(self):
        f, source, ref, originals, examination, capture, pins = self.case()
        changed = loads(capture["snapshot.json"], maximum=package.MAX_BYTES)
        changed["scopes"]["collection"]["status"] = "absent"
        raw = dumps(changed)
        with self.assertRaisesRegex(MuseumError, "source replay differs"):
            self.replay(ref, originals, examination, capture | {"snapshot.json": raw}, pins | {"snapshotHash": keccak256(raw)})
        with self.assertRaisesRegex(MuseumError, "source replay differs"):
            self.replay(ref, originals, examination, capture, pins | {"provenance": "trusted_rpc"})

    def test_full_original_receipt_conflict_rejects_even_with_unchanged_anchor_labels(self):
        f, source, ref, originals, examination, capture, pins = self.case()
        evidence = loads(originals["deployment-evidence.json"])
        evidence["tokenMint"]["receipt"]["status"] = "0x0"
        changed = originals | {"deployment-evidence.json": dumps(evidence)}
        with self.assertRaisesRegex(MuseumError, "conflicting results"):
            self.replay(ref, changed, examination, capture, pins)


if __name__ == "__main__":
    unittest.main()
