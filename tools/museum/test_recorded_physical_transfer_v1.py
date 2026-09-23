"""Focused offline controls for recorded physical-transfer projection."""

from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import physical_transfer_semantics_v1 as semantics
from . import recorded_physical_transfer_v1 as package
from .bagit import write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT
from .object_dossier import _ref
from .recorded_physical_transfer_fixture_v1 import _entity, _pin, build_case


class RecordedPhysicalTransferV1Tests(unittest.TestCase):
    def _build(self, **kwargs):
        case = build_case(**kwargs)
        with patch("socket.socket", side_effect=AssertionError("physical transfer used network")):
            built = package.build(case.source_files, case.source_hash, disclosure="public")
        return case, built

    @staticmethod
    def _resources(built):
        return [loads(body, maximum=MAX_TRANSCRIPT) for path, body in built.files
                if path.startswith("transfer/resources/")]

    def test_completed_acquisition_replays_source_and_full_package(self):
        case, built = self._build()
        with patch("socket.socket", side_effect=AssertionError("physical transfer verify used network")):
            checked = package.verify(dict(built.files), built.manifest_hash)
        resources = self._resources(built)
        physical = next(row for row in resources if row["type"] == "HumanMadeObject")
        activity = next(row for row in resources if row["type"] == "Activity")
        self.assertEqual(activity["part"][0]["type"], "Acquisition")
        self.assertEqual(activity["part"][0]["transferred_title_of"][0]["id"], physical["id"])
        self.assertEqual(built.report["resourceCount"], "2")
        self.assertEqual(built.report["embeddedEventCount"], "1")
        self.assertEqual(checked.manifest_hash, built.manifest_hash)
        self.assertEqual(built.report["sourceManifestHash"], case.source_hash)

    def test_completed_custody_transfer_is_distinct_from_title(self):
        _, built = self._build(kind="physical_custody_transfer")
        activity = next(row for row in self._resources(built) if row["type"] == "Activity")
        part = activity["part"][0]
        self.assertEqual(part["type"], "TransferOfCustody")
        self.assertIn("transferred_custody_of", part)
        self.assertNotIn("transferred_title_of", part)
        self.assertFalse(built.report["claims"]["physicalCustodyProven"])
        self.assertFalse(built.report["claims"]["legalTitleProven"])

    def test_all_general_authority_modes_remain_source_qualified(self):
        expected = {"institution": ("SIGNER_VERIFIED", "GENERAL_SIGNER_CLAIM"),
                    "estate": ("SIGNER_VERIFIED", "GENERAL_SIGNER_CLAIM"),
                    "curatorial": ("OPERATOR_ASSERTED", "CONFIGURED_OPERATOR_CLAIM")}
        for authority, labels in expected.items():
            _, built = self._build(authority=authority)
            sidecar = loads(dict(built.files)["transfer/sidecar.json"], maximum=MAX_TRANSCRIPT)
            row = next(row for row in sidecar["statements"]
                       if row["disposition"] == "completed_transfer")
            with self.subTest(authority=authority):
                self.assertEqual((row["authority"]["verificationClass"],
                                  row["authority"]["authorityQualification"]), labels)
                self.assertFalse(row["authority"]["namedInstitutionIdentityProven"])

    def test_statuses_never_infer_performance(self):
        expected = {"planned": "retained_planned", "cancelled": "retained_cancelled",
                    "unknown": "retained_unknown", "completed": "completed_transfer"}
        for status, disposition in expected.items():
            _, built = self._build(status=status)
            with self.subTest(status=status):
                self.assertEqual(built.report["statementDispositionCounts"][disposition], "1")
                self.assertEqual(built.report["resourceCount"], "2" if status == "completed" else "0")
                self.assertFalse(built.report["claims"]["historicalPerformanceProven"])

    def test_optional_parties_are_absent_without_account_conversion(self):
        _, built = self._build(parties=False)
        activity = next(row for row in self._resources(built) if row["type"] == "Activity")
        part = activity["part"][0]
        self.assertNotIn("transferred_title_from", part)
        self.assertNotIn("transferred_title_to", part)
        self.assertNotIn("carried_out_by", activity)
        self.assertNotIn("timespan", activity)

    def test_declared_person_and_group_are_only_role_references(self):
        _, built = self._build()
        resources = self._resources(built)
        activity = next(row for row in resources if row["type"] == "Activity")
        part = activity["part"][0]
        self.assertEqual(part["transferred_title_from"][0]["type"], "Person")
        self.assertEqual(part["transferred_title_to"][0]["type"], "Group")
        self.assertFalse(any(row["type"] in ("Person", "Group") for row in resources))
        self.assertTrue(all(not ref["id"].startswith("urn:6529stream:account:")
            for key in ("transferred_title_from", "transferred_title_to") for ref in part[key]))

    def test_instrument_binds_exact_original_occurrence_and_fragment_bytes(self):
        case, built = self._build()
        sidecar = loads(dict(built.files)["transfer/sidecar.json"], maximum=MAX_TRANSCRIPT)
        row = next(row for row in sidecar["statements"] if row["disposition"] == "completed_transfer")
        instrument = row["instrumentEvidence"]
        self.assertEqual(case.body["instrumentEvidence"]["sourceRecord"]["pointer"], "")
        self.assertEqual(instrument["evidence"]["selector"], "/statement")
        self.assertEqual(instrument["selectedEncoding"], "canonical_json_value")
        self.assertEqual(bytes.fromhex(instrument["selectedBytesHex"][2:]),
                         dumps("Exact original documentary evidence"))
        self.assertFalse(instrument["legalValidityProven"])
        self.assertFalse(instrument["externalReferenceTargetsReceived"])

    def test_instrument_can_bind_the_exact_whole_original_document(self):
        def mutate(value, body):
            value["sourceRecords"][0]["pointer"] = ""
            body["instrumentEvidence"]["sourceRecord"]["pointer"] = ""
            evidence = value["assertions"][0]["evidence"][0]
            evidence["selectorType"], evidence["selector"] = "whole_document", ""
        _, built = self._build(mutate=mutate)
        sidecar = loads(dict(built.files)["transfer/sidecar.json"], maximum=MAX_TRANSCRIPT)
        instrument = next(row for row in sidecar["statements"]
            if row["disposition"] == "completed_transfer")["instrumentEvidence"]
        original = instrument["original"]
        self.assertEqual(instrument["selectedEncoding"], "original_payload_bytes")
        self.assertEqual(instrument["selectedBytesHex"], original["payloadHex"])
        self.assertEqual(instrument["selectedBytesHash"], instrument["payloadHash"])

    def test_exact_object_event_activity_and_party_pins_are_mandatory(self):
        changes = {
            "object-hash": lambda _v, b: b["physicalObject"].__setitem__("hash", "0x" + "77" * 32),
            "event-pointer": lambda _v, b: b["transferEvent"].__setitem__("pointer", "/entities/0"),
            "activity-id": lambda _v, b: b["activity"].__setitem__("id", "urn:fixture:wrong"),
            "party-kind": lambda v, _b: v["entities"][3].__setitem__("kind", "place"),
        }
        for name, mutate in changes.items():
            case = build_case(mutate=mutate)
            with self.subTest(name=name), self.assertRaises(MuseumError):
                package.build(case.source_files, case.source_hash, disclosure="public")

    def test_instrument_index_and_source_occurrence_cannot_be_substituted(self):
        changes = {
            "index": lambda _v, b: b["instrumentEvidence"].__setitem__("evidenceIndex", "1"),
            "record": lambda _v, b: b["instrumentEvidence"]["sourceRecord"].__setitem__(
                "recordHash", "0x" + "88" * 32),
            "pointer": lambda _v, b: b["instrumentEvidence"]["sourceRecord"].__setitem__(
                "pointer", "/other"),
        }
        for name, mutate in changes.items():
            case = build_case(mutate=mutate)
            with self.subTest(name=name), self.assertRaises(MuseumError):
                package.build(case.source_files, case.source_hash, disclosure="public")

    def test_unselected_transfer_is_retained_without_graph_output(self):
        case, built = self._build(selection_indices=[])
        self.assertEqual(built.report["resourceCount"], "0")
        self.assertEqual(built.report["statementDispositionCounts"]["unselected"], "1")
        self.assertEqual(case.body["status"], "completed")

    def test_wrong_relation_rule_or_datatype_is_unsupported_not_reinterpreted(self):
        mutations = {
            "relation": lambda v, _b: v["assertions"][0].__setitem__("relation", "urn:fixture:other"),
            "rule": lambda v, _b: v["assertions"][0].__setitem__("mappingRule", "urn:fixture:other"),
            "datatype": lambda v, _b: v["assertions"][0]["object"]["literal"].__setitem__(
                "datatype", "urn:fixture:other"),
        }
        for name, mutate in mutations.items():
            _, built = self._build(mutate=mutate)
            with self.subTest(name=name):
                self.assertEqual(built.report["resourceCount"], "0")

    @staticmethod
    def _append_statement(value, body, *, suffix, status=None, same_event=False,
                          shared_activity=False):
        issuer = value["assertions"][0]["assertingAgent"]
        start = len(value["entities"])
        if same_event:
            event_pin, activity_pin = deepcopy(body["transferEvent"]), deepcopy(body["activity"])
        elif shared_activity:
            event = _entity("urn:fixture:acquisition:event:" + suffix, "event",
                "Another transfer event", issuer, value["sourceRecords"])
            value["entities"].append(event)
            event_pin, activity_pin = _pin(event, start), deepcopy(body["activity"])
        else:
            event = _entity("urn:fixture:acquisition:event:" + suffix, "event",
                "Another transfer event", issuer, value["sourceRecords"])
            activity = _entity("urn:fixture:acquisition:activity:" + suffix, "event",
                "Another enclosing activity", issuer, value["sourceRecords"])
            value["entities"].extend((event, activity))
            event_pin, activity_pin = _pin(event, start), _pin(activity, start + 1)
        other = deepcopy(body); other["transferEvent"] = event_pin; other["activity"] = activity_pin
        if status is not None: other["status"] = status
        assertion = deepcopy(value["assertions"][0]); assertion["id"] += ":" + suffix
        assertion["object"]["literal"]["lexicalValue"] = dumps(other).decode("utf-8")
        value["assertions"].append(assertion)

    @staticmethod
    def _append_reverse_containment(value, body, *, status):
        other = deepcopy(body)
        other["transferEvent"], other["activity"] = (
            deepcopy(body["activity"]), deepcopy(body["transferEvent"]))
        other["status"] = status
        assertion = deepcopy(value["assertions"][0])
        assertion["id"] += ":reverse-" + status
        assertion["object"]["literal"]["lexicalValue"] = dumps(other).decode("utf-8")
        value["assertions"].append(assertion)

    def test_conflicting_selected_claims_for_one_event_are_withheld(self):
        def mutate(value, body):
            self._append_statement(value, body, suffix="conflict", status="cancelled", same_event=True)
        _, built = self._build(mutate=mutate)
        self.assertEqual(built.report["resourceCount"], "0")
        self.assertEqual(built.report["statementDispositionCounts"]["conflict_withheld"], "2")

    def test_distinct_events_for_one_object_remain_distinct_and_valid(self):
        def mutate(value, body):
            self._append_statement(value, body, suffix="second")
        _, built = self._build(mutate=mutate)
        index = loads(dict(built.files)["transfer/index.json"], maximum=MAX_TRANSCRIPT)
        self.assertEqual(built.report["resourceCount"], "3")
        self.assertEqual(len(index["embeddedEvents"]), 2)
        self.assertEqual(len({row["originalSourceEntityId"] for row in index["embeddedEvents"]}), 2)

    def test_shared_activity_part_provenance_is_scoped_per_event(self):
        def mutate(value, body):
            self._append_statement(value, body, suffix="same-activity", shared_activity=True)
        _, built = self._build(mutate=mutate)
        provenance = loads(dict(built.files)["transfer/provenance.json"], maximum=MAX_TRANSCRIPT)
        activity = next(row for row in self._resources(built) if row["type"] == "Activity")
        activity_rows = [row for row in provenance if row["entity"] == activity["id"]]

        def assertion_pointers(rows):
            return {source["source"]["pointer"]
                    for row in rows for source in row["sources"]}

        first = [row for row in activity_rows if row["path"] == "/part/0"
                 or row["path"].startswith("/part/0/")]
        second = [row for row in activity_rows if row["path"] == "/part/1"
                  or row["path"].startswith("/part/1/")]
        common = next(row for row in activity_rows if row["path"] == "/id")
        self.assertEqual(assertion_pointers(first), {"/assertions/0"})
        self.assertEqual(assertion_pointers(second), {"/assertions/1"})
        self.assertEqual(assertion_pointers([common]), {"/assertions/0", "/assertions/1"})

    def test_completed_containment_cycle_is_withheld_but_planned_reverse_is_not_an_edge(self):
        def completed_cycle(value, body):
            self._append_reverse_containment(value, body, status="completed")
        _, cycled = self._build(mutate=completed_cycle)
        self.assertEqual(cycled.report["resourceCount"], "0")
        self.assertEqual(cycled.report["statementDispositionCounts"]["conflict_withheld"], "2")
        sidecar = loads(dict(cycled.files)["transfer/sidecar.json"], maximum=MAX_TRANSCRIPT)
        withheld = [row for row in sidecar["statements"]
                    if row["disposition"] == "conflict_withheld"]
        self.assertTrue(all("cyclic_selected_activity_containment" in row["reasons"]
                            for row in withheld))

        def planned_reverse(value, body):
            self._append_reverse_containment(value, body, status="planned")
        _, acyclic = self._build(mutate=planned_reverse)
        self.assertEqual(acyclic.report["resourceCount"], "2")
        self.assertEqual(acyclic.report["statementDispositionCounts"]["completed_transfer"], "1")
        self.assertEqual(acyclic.report["statementDispositionCounts"]["retained_planned"], "1")

    def test_same_iri_with_different_local_declaration_is_ambiguous(self):
        def mutate(value, _body):
            duplicate = deepcopy(value["entities"][0])
            duplicate["names"][0]["value"] = "Conflicting local declaration"
            value["entities"].append(duplicate)
        case = build_case(mutate=mutate)
        with self.assertRaisesRegex(MuseumError, "ambiguous local declaration"):
            package.build(case.source_files, case.source_hash, disclosure="public")

    def test_identical_selected_occurrences_aggregate_without_identity_collision(self):
        def mutate(value, body):
            self._append_statement(value, body, suffix="repeat", same_event=True)
        _, built = self._build(mutate=mutate)
        index = loads(dict(built.files)["transfer/index.json"], maximum=MAX_TRANSCRIPT)
        self.assertEqual(built.report["resourceCount"], "2")
        self.assertEqual(len(index["embeddedEvents"]), 1)
        activity = next(row for row in self._resources(built) if row["type"] == "Activity")
        self.assertEqual(len(activity["part"]), 1)

    def test_coherently_rehashed_derived_tamper_still_fails_full_rebuild(self):
        _, built = self._build(); files = dict(built.files)
        files["transfer/index.json"] = dumps({"resources": [], "embeddedEvents": []})
        manifest = loads(files["manifest.json"], maximum=MAX_TRANSCRIPT)
        manifest["files"] = [_ref(path, raw) for path, raw in sorted(files.items())
                             if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            package.verify(files, keccak256(files["manifest.json"]))

    def test_cli_build_verify_public_and_no_overwrite(self):
        case = build_case()
        with TemporaryDirectory(prefix="physical-transfer-cli-") as temporary:
            root = Path(temporary); source = root / "source"; output = root / "output"
            write_tree(case.source_files, source)
            stdout = io.StringIO()
            with redirect_stdout(stdout):
                package.main(["build", str(source), str(output), "--source-hash",
                    case.source_hash, "--disclosure", "public"])
            result = loads(stdout.getvalue().encode("utf-8"), maximum=MAX_TRANSCRIPT)
            stdout = io.StringIO()
            with redirect_stdout(stdout):
                package.main(["verify", str(output), "--manifest-hash", result["manifestHash"]])
            self.assertEqual(loads(stdout.getvalue().encode("utf-8"))["manifestHash"], result["manifestHash"])
            with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as raised:
                package.main(["build", str(source), str(output), "--source-hash",
                    case.source_hash, "--disclosure", "public"])
            self.assertEqual(raised.exception.code, 1)
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            package.build(case.source_files, case.source_hash, disclosure="restricted")


if __name__ == "__main__":
    unittest.main()
