import copy
import unittest

from .canonical import MuseumError, dumps, keccak256, loads
from . import canonical_semantic_projection_v1 as projection
from . import canonical_semantic_sources_v1 as sources


def H(label):
    return keccak256(label.encode("utf-8"))


def _pointer(label):
    return {"path": "input/" + label + ".json", "hash": H(label),
        "jsonPointer": "/" + label, "encoding": "canonical_json"}


def _row(index, family, *, selected, status, semantic, payload=True,
         interpretation="interpreted"):
    occurrence = H("occurrence " + str(index))
    return {
        "occurrenceId": occurrence,
        "family": family,
        "selector": {"kind": family.lower(), "chainId": "31337",
            "core": "0x" + "11" * 20, "host": "0x" + f"{index + 32:02x}" * 20,
            "recordHash": H("record " + str(index)), "recordType": H("type " + family),
            "subjectId": H("subject"), "schemaId": H("schema " + family),
            "canonicalizationId": H("canon"), "sourceId": None},
        "original": {"record": str(index), "payloadHash": H("payload " + str(index))},
        "semantic": copy.deepcopy(semantic) if interpretation == "interpreted" else None,
        "interpretation": {"status": interpretation,
            "reason": None if interpretation == "interpreted" else "unsupported_schema"},
        "authority": {"mode": "native_record", "recorder": "0x" + "44" * 20},
        "currentness": {"status": status, "selected": selected,
            "selectionBasis": ("native_work_revision" if family == "WORK" else
                "explicit_accession_record" if family in ("ACCESSION", "DEACCESSION") else
                "receipt_ordered_condition"),
            "selection": {"recordHash": H("record " + str(index))} if selected else None,
            "eligibility": "not_reexecuted" if family == "WORK" else "not_asserted"},
        "pointers": {"original": _pointer("original-" + str(index)),
            "payload": _pointer("payload-" + str(index)) if payload else None,
            "projection": _pointer("projection-" + str(index)),
            "authority": _pointer("authority-" + str(index)),
            "currentness": _pointer("currentness-" + str(index))},
        "catalog": None,
    }


def inventory():
    rows = [
        _row(0, "WORK", selected=True, status="current_native_head",
            semantic={"title": {"value": "First title", "language": None},
                "creator": "0x" + "aa" * 20, "keywords": ["one", "one"],
                "note": None, "empty": []}),
        _row(1, "WORK", selected=False, status="historical_native_selection",
            semantic={"title": {"value": "Conflicting title", "language": "en"},
                "creator": "0x" + "bb" * 20}, payload=True),
        _row(2, "ACCESSION", selected=True, status="explicit_original_selection",
            semantic={"title": "Owner-declared accession", "owner": "0x" + "cc" * 20,
                "institution": "Museum name"}, payload=False),
        _row(3, "CONDITION", selected=True, status="selected_condition_unresolved",
            semantic={}, payload=True, interpretation="opaque"),
        _row(4, "DEACCESSION", selected=False, status="historical_original",
            semantic={}, payload=False, interpretation="opaque"),
    ]
    catalog_value = {"mediaType": "application/json", "formats": ["primary", "primary"]}
    rows[0]["catalog"] = {"value": catalog_value, "bytesHex": dumps(catalog_value).hex(),
        "source": _pointer("catalog-source"), "bytesSource": _pointer("catalog-bytes"),
        "registrationAuthenticated": False}
    leaves = []
    for row in rows:
        leaves.extend(sources.leaves(row["original"], row["occurrenceId"], "original"))
        if row["semantic"] is not None:
            leaves.extend(sources.leaves(row["semantic"], row["occurrenceId"], "semantic"))
        if row["catalog"] is not None:
            leaves.extend(sources.leaves(row["catalog"]["value"], row["occurrenceId"], "catalog"))
    state = {"chainId": "31337", "core": "0x" + "11" * 20,
        "collectionId": "7", "tokenId": "41", "blockNumber": "5",
        "blockHash": H("block")}
    return {"profileHash": sources.PROFILE_HASH, "sourceManifestHash": H("manifest"),
        "sourceState": state, "sourceStateHash": keccak256(dumps(state)),
        "rows": rows, "leaves": leaves,
        "denominators": {"rows": "5", "leaves": str(len(leaves))},
        "conservation": {"status": "retained_separately"},
        "claims": {"sourceVerified": True}, "qualification": "fixture",
        "finality": {"status": "preserved"}, "recordHeads": [],
        "sourceBindings": {"status": "preserved"},
        "disclosure": "public", "definitions": []}


def _walk(value, parts=()):
    pointer = "" if not parts else "/" + "/".join(str(part) for part in parts)
    if isinstance(value, dict) and value:
        for key, child in value.items():
            yield from _walk(child, parts + (key,))
    elif isinstance(value, list) and value:
        for index, child in enumerate(value):
            yield from _walk(child, parts + (index,))
    else:
        value_type = ("null" if value is None else "empty_array" if value == [] else
            "empty_object" if value == {} else "boolean" if type(value) is bool else
            "integer" if type(value) is int else "string")
        yield pointer, value_type, copy.deepcopy(value)


class CanonicalSemanticProjectionV1Tests(unittest.TestCase):
    def setUp(self):
        self.inventory = inventory()
        self.selection = projection.default_selection(self.inventory)
        self.files = projection.render(self.inventory, self.selection,
            keccak256(self.selection))

    def test_default_selection_emits_distinct_validated_statements_and_payloads(self):
        report = loads(self.files[projection.REPORT_PATH], canonical=True)
        self.assertEqual(report["selectedCount"], "2")
        self.assertEqual(report["resourceCount"], "3")
        index = loads(self.files[projection.INDEX_PATH], canonical=True)
        ids = [row["id"] for row in index["resources"]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual([row["role"] for row in index["resources"]].count("payload"), 1)
        for row in index["resources"]:
            raw = loads(self.files[row["path"]], canonical=True)
            self.assertIn(raw["type"], ("LinguisticObject", "DigitalObject"))

    def test_conflicting_candidates_never_flatten_into_work_or_agent_facts(self):
        assertions = loads(self.files[projection.ASSERTIONS_PATH], canonical=True)
        work_candidates = [row for row in assertions["candidateFields"] if row["family"] == "WORK"]
        self.assertEqual(len(work_candidates), 2)
        self.assertNotEqual(work_candidates[0]["candidates"], work_candidates[1]["candidates"])
        for path, raw in self.files.items():
            if "/resources/" in path:
                value = loads(raw, canonical=True)
                self.assertNotIn(value["type"], ("HumanMadeObject", "Person", "Group", "Activity"))
                self.assertNotIn("produced_by", value)
                self.assertNotIn("current_owner", value)

    def test_leaf_coverage_preserves_original_semantic_null_empty_and_duplicates(self):
        coverage = loads(self.files[projection.COVERAGE_PATH], canonical=True)
        self.assertEqual(coverage["leafCount"], str(len(self.inventory["leaves"])))
        self.assertEqual([row["value"] for row in coverage["leaves"]
            if row["jsonPointer"].startswith("/keywords/")], ["one", "one"])
        self.assertTrue(any(row["valueType"] == "null" for row in coverage["leaves"]))
        self.assertTrue(any(row["valueType"] == "empty_array" for row in coverage["leaves"]))
        self.assertTrue(all(row["disposition"] == "retained_stream_only"
            for row in coverage["leaves"] if row["section"] == "original"))

    def test_explicit_historical_selection_preserves_noncurrent_status(self):
        identifier = self.inventory["rows"][1]["occurrenceId"]
        raw = projection.historical_selection(self.inventory, [identifier])
        files = projection.render(self.inventory, raw, keccak256(raw))
        assertion = loads(files[projection.ASSERTIONS_PATH], canonical=True)["selected"][0]
        self.assertEqual(assertion["currentness"]["status"], "historical_native_selection")
        self.assertFalse(assertion["currentness"]["selected"])
        report = loads(files[projection.REPORT_PATH], canonical=True)
        self.assertEqual(report["selectionPolicy"], "explicit_historical")

    def test_selected_unresolved_condition_does_not_fallback_or_become_activity(self):
        index = loads(self.files[projection.INDEX_PATH], canonical=True)
        condition = next(row for row in index["occurrences"] if row["family"] == "CONDITION")
        self.assertEqual(condition["currentness"]["status"], "selected_condition_unresolved")
        self.assertEqual(condition["interpretation"]["status"], "opaque")
        self.assertEqual(condition["disposition"], "retained_alternative")
        assertions = loads(self.files[projection.ASSERTIONS_PATH], canonical=True)["selected"]
        self.assertFalse(any(row["family"] == "CONDITION" for row in assertions))

    def test_missing_unknown_reordered_or_rehashed_selection_rejects(self):
        value = loads(self.selection, canonical=True)
        cases = []
        changed = copy.deepcopy(value); changed["selectedOccurrenceIds"].reverse(); cases.append(changed)
        changed = copy.deepcopy(value); changed["selectedOccurrenceIds"].append(H("unknown")); cases.append(changed)
        changed = copy.deepcopy(value); changed["inventoryHash"] = H("wrong"); cases.append(changed)
        changed = copy.deepcopy(value); changed["reason"] = "artist_approved"; cases.append(changed)
        for changed in cases:
            raw = dumps(changed)
            with self.assertRaises(MuseumError):
                projection.render(self.inventory, raw, keccak256(raw))
        with self.assertRaises(MuseumError):
            projection.render(self.inventory, self.selection, H("wrong selection pin"))

    def test_unknown_opaque_or_duplicate_historical_selection_rejects(self):
        opaque = self.inventory["rows"][4]["occurrenceId"]
        for identifiers in ([opaque], [self.inventory["rows"][1]["occurrenceId"]] * 2, []):
            with self.assertRaises(MuseumError):
                projection.historical_selection(self.inventory, identifiers)

    def test_source_inventory_and_every_row_remain_bound(self):
        for mutate in (
            lambda value: value["rows"].reverse(),
            lambda value: value["leaves"].pop(),
            lambda value: value["sourceState"].update(blockNumber="6"),
        ):
            changed = copy.deepcopy(self.inventory); mutate(changed)
            with self.assertRaises(MuseumError):
                projection.render(changed, self.selection, keccak256(self.selection))

    def test_duplicate_record_occurrences_keep_distinct_resource_identities(self):
        changed = copy.deepcopy(self.inventory)
        duplicate = copy.deepcopy(changed["rows"][1])
        duplicate["occurrenceId"] = H("same record second occurrence")
        duplicate["pointers"]["original"] = _pointer("same-record-second-occurrence")
        changed["rows"].append(duplicate)
        changed["leaves"].extend(sources.leaves(
            duplicate["original"], duplicate["occurrenceId"], "original"))
        changed["leaves"].extend(sources.leaves(
            duplicate["semantic"], duplicate["occurrenceId"], "semantic"))
        raw = projection.historical_selection(changed,
            [changed["rows"][1]["occurrenceId"], duplicate["occurrenceId"]])
        files = projection.render(changed, raw, keccak256(raw))
        assertions = loads(files[projection.ASSERTIONS_PATH], canonical=True)["selected"]
        self.assertEqual(assertions[0]["recordIdentity"], assertions[1]["recordIdentity"])
        resources = loads(files[projection.INDEX_PATH], canonical=True)["resources"]
        self.assertEqual(len({row["id"] for row in resources}), len(resources))

    def test_crosswalk_named_vectors_resolve(self):
        names = {name for name in dir(type(self)) if name.startswith("test_")}
        crosswalk = loads(projection.CROSSWALK_BYTES, canonical=True)
        for row in crosswalk["rules"]:
            self.assertIn(row["positiveTest"], names)
            self.assertIn(row["negativeTest"], names)
        self.assertEqual(keccak256(projection.PROFILE_BYTES), projection.PROFILE_HASH)


if __name__ == "__main__":
    unittest.main()
