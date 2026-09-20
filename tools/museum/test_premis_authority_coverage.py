"""Focused synthetic tests for complete PREMIS authority-field accounting.

Synthetic N-Triples in this module are structural vectors only. They are not
publisher-authenticated vocabularies, semantic equivalence review, or current
authority observations. The tracked ``ing.nt`` case retains its caller-admitted
HTTP observation qualification.
"""

from collections import Counter
import copy
from hashlib import sha256
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from . import premis_authority_coverage as coverage
from . import premis_authority_snapshot as v1
from .canonical import MuseumError, dumps, keccak256, loads


ROOT = Path(__file__).resolve().parents[2]
V1_EXAMPLE = ROOT / "schemas/museum/premis-authority-snapshot/example/input"
ORIGINAL_PIN = "0x0c2e38613fc50d5b0a0a00e8303bfd9a9b9978531ab1bdd918bd2713d06c292c"
V1_PROFILE_PIN = "0xae85b708dd58cada2d131b8d4ee7ff3db94a89134c94ca5acd7765bffaafc256"
PREMIS_ACTION = "http://www.loc.gov/premis/rdf/v3/Action"


def iri(value):
    return "<" + value + ">"


def literal(value, suffix=""):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"' + suffix


def triple(subject, predicate, obj):
    return f"{iri(subject)} {iri(predicate)} {obj} ."


def slug(value):
    text = "".join(c.lower() if c.isalnum() else "-" for c in value).strip("-")
    return text[:48] or "term"


def raw_term(term, scheme, label, *, extra=(), include_scheme=True, code=None):
    code = term.rsplit("/", 1)[-1] if code is None else code
    lines = [
        triple(term, v1.RDF + "type", iri(v1.MADS + "Authority")),
        triple(term, v1.MADS + "authoritativeLabel", literal(label)),
        triple(term, v1.MADS + "code", literal(code)),
    ]
    if include_scheme:
        lines.append(triple(term, v1.MADS + "isMemberOfMADSScheme", iri(scheme)))
    lines.extend(extra)
    return ("\n".join(lines) + "\n").encode()


def descriptor(raw, term, scheme, *, provenance="synthetic_fixture",
               retrieved="2026-09-20T00:00:00Z", algorithm="1"):
    digest = keccak256(raw) if algorithm == "1" else "0x" + sha256(raw).hexdigest()
    value = {"version": "1", "termIri": term, "schemeIri": scheme,
        "sourceUri": term + ".nt", "retrievedAt": retrieved,
        "contentHash": {"algorithm": algorithm, "digest": digest,
            "canonicalizationId": v1.RAW_BYTES}, "byteLength": str(len(raw)),
        "mediaType": "application/n-triples", "attribution": "Synthetic fixture",
        "reuseTerms": "Synthetic fixture; no publisher claim", "provenance": provenance}
    encoded = dumps(value)
    return encoded, keccak256(encoded)


def candidate(key, term, label, *, relation="exact_label", version=None, effective=None):
    return {"snapshot": key, "termIri": term, "relation": relation, "label": label,
        "requiredVersion": version, "requiredEffectiveDate": effective}


def field_row(field, *, disposition=None, candidates=None, rationale=None):
    if disposition is None:
        disposition = "profile_local" if field["profileLocal"] else "unresolved"
    return {"sourcePointer": field["sourcePointer"], "disposition": disposition,
        "rationale": rationale or "Explicit synthetic accounting; no authority claim.",
        "candidates": [] if candidates is None else candidates}


def request(rows, *, as_of="2026-09-21T00:00:00Z", age="172800", **changes):
    value = {"version": "2", "mode": coverage.MODE, "profileHash": coverage.PROFILE_HASH,
        "originalProfileHash": coverage.ORIGINAL_PROFILE_HASH, "asOf": as_of,
        "maxSnapshotAgeSeconds": age, "fields": rows}
    value.update(changes)
    raw = dumps(value)
    return raw, keccak256(raw)


class Fixture:
    def __init__(self):
        self.snapshots = {}
        self.rows = []
        for index, field in enumerate(coverage.FIELDS):
            if field["profileLocal"]:
                self.rows.append(field_row(field, disposition="profile_local"))
                continue
            scheme = field["expectedScheme"] or (coverage.BASE +
                ("eventOutcome" if field["family"] == "outcomes" else "cryptographicHashFunction"))
            existing = field["original"].get("valueUri")
            term = existing or scheme + "/" + slug(field["targetLabel"])
            key = "field-" + str(index)
            raw = raw_term(term, scheme, field["targetLabel"])
            encoded, pin = descriptor(raw, term, scheme)
            self.snapshots[key] = (encoded, raw, pin, "synthetic_fixture", None)
            self.rows.append(field_row(field, disposition="authority",
                candidates=[candidate(key, term, field["targetLabel"])]))
        self.request, self.request_hash = request(self.rows)
        self.pins = {"original_profile_hash": coverage.ORIGINAL_PROFILE_HASH,
            "request_hash": self.request_hash, "profile_hash": coverage.PROFILE_HASH}

    def bind(self, rows=None, snapshots=None, **request_changes):
        raw, pin = request(self.rows if rows is None else rows, **request_changes)
        return coverage.bind(coverage.ORIGINAL_PROFILE_BYTES, raw,
            self.snapshots if snapshots is None else snapshots,
            original_profile_hash=coverage.ORIGINAL_PROFILE_HASH,
            request_hash=pin, profile_hash=coverage.PROFILE_HASH)

    def one(self, index, snapshot, candidate_row, *, disposition="authority"):
        rows = [field_row(field) for field in coverage.FIELDS]
        rows[index] = field_row(coverage.FIELDS[index], disposition=disposition,
                                candidates=[candidate_row])
        return self.bind(rows, snapshot)


class PremisAuthorityCoverageTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.f = Fixture()

    def test_closed_inventory_has_all_35_original_fields_in_original_order(self):
        self.assertEqual(coverage.definitions(check=True), coverage.PROFILE_HASH)
        self.assertEqual(len(coverage.FIELDS), 35)
        self.assertEqual(Counter(field["family"] for field in coverage.FIELDS),
            {"eventTypes": 13, "outcomes": 6, "agent/classes": 4,
             "rights/bases": 6, "fixityAlgorithms": 6})
        pointers = [field["sourcePointer"] for field in coverage.FIELDS]
        self.assertEqual(pointers, [row["sourcePointer"] for row in self.f.rows])
        self.assertEqual(len(set(pointers)), 35)
        self.assertEqual(coverage.ORIGINAL_PROFILE_HASH, ORIGINAL_PIN)
        self.assertEqual(v1.PROFILE_HASH, V1_PROFILE_PIN)
        profile = loads(coverage.PROFILE_BYTES, canonical=True)
        self.assertEqual(profile["parentSnapshotProfileHash"], V1_PROFILE_PIN)

    def test_complete_multifamily_synthetic_accounting_binds_only_nonlocal_fields(self):
        files = self.f.bind()
        report = loads(files["report.json"], maximum=coverage.MAX_PACKAGE, canonical=True)
        self.assertEqual(report["fieldCount"], "35")
        self.assertTrue(report["completeEnumeratedFieldAccounting"])
        self.assertFalse(report["allFieldsBound"])
        self.assertEqual(report["counts"], {"bound": "27", "profile_local": "8"})
        self.assertEqual(len([row for row in report["fields"] if row["status"] == "bound"]), 27)
        self.assertTrue(all(row["candidateValueUri"] is None for row in report["fields"]
                            if row["profileLocal"]))
        self.assertFalse(report["publisherAuthenticated"])
        self.assertFalse(report["fullCrosswalkConformance"])

    def test_tracked_v1_ing_snapshot_is_compatible_with_complete_v2_accounting(self):
        descriptor_raw = (V1_EXAMPLE / "ing.descriptor.json").read_bytes()
        raw = (V1_EXAMPLE / "ing.nt").read_bytes()
        retrieval = (V1_EXAMPLE / "retrieval.json").read_bytes()
        snapshots = {"ing": (descriptor_raw, raw, keccak256(descriptor_raw),
                              "retained_http_observation", retrieval)}
        rows = [field_row(field) for field in coverage.FIELDS]
        rows[0] = field_row(coverage.FIELDS[0], disposition="authority",
            candidates=[candidate("ing", coverage.BASE + "eventType/ing", "ingestion")])
        files = self.f.bind(rows, snapshots)
        report = loads(files["report.json"], maximum=coverage.MAX_PACKAGE, canonical=True)
        self.assertEqual(report["fields"][0]["status"], "bound")
        self.assertEqual(report["counts"], {"bound": "1", "profile_local": "8", "unresolved": "26"})
        snapshot = loads(files["snapshots/ing.json"], maximum=10485760, canonical=True)
        self.assertEqual(len(snapshot["opaqueReferences"]), 8)
        self.assertFalse(snapshot["validNTriples"])
        self.assertFalse(snapshot["publisherAuthenticated"])
        self.assertEqual(snapshot["retrieval"]["observationHash"], keccak256(retrieval))

    def test_field_omissions_duplicates_order_and_unknown_pointers_reject(self):
        variants = []
        variants.append(self.f.rows[:-1])
        duplicate = copy.deepcopy(self.f.rows); duplicate[1]["sourcePointer"] = duplicate[0]["sourcePointer"]
        variants.append(duplicate)
        reordered = copy.deepcopy(self.f.rows); reordered[0], reordered[1] = reordered[1], reordered[0]
        variants.append(reordered)
        unknown = copy.deepcopy(self.f.rows); unknown[0]["sourcePointer"] = "/events/0"
        variants.append(unknown)
        for rows in variants:
            with self.subTest(rows=len(rows)), self.assertRaises(MuseumError):
                self.f.bind(rows)

    def test_profile_local_exact_authority_escalation_rejects_and_close_match_stays_proposed(self):
        local_index = 10
        field = coverage.FIELDS[local_index]
        scheme = coverage.BASE + "eventType"
        term = scheme + "/con"
        raw = raw_term(term, scheme, "conservation treatment")
        descriptor_raw, pin = descriptor(raw, term, scheme)
        snapshots = {"close": (descriptor_raw, raw, pin, "synthetic_fixture", None)}
        exact = candidate("close", term, field["targetLabel"], relation="exact_label")
        with self.assertRaisesRegex(MuseumError, "profile-local field cannot"):
            self.f.one(local_index, snapshots, exact, disposition="profile_local")
        with self.assertRaisesRegex(MuseumError, "authority candidate required"):
            self.f.one(local_index, snapshots, exact, disposition="authority")
        close = candidate("close", term, "conservation treatment", relation="close_match")
        files = self.f.one(local_index, snapshots, close, disposition="profile_local")
        row = loads(files["report.json"], maximum=coverage.MAX_PACKAGE,
                    canonical=True)["fields"][local_index]
        self.assertEqual(row["status"], "proposed_close_match")
        self.assertIsNone(row["candidateValueUri"])
        self.assertFalse(row["reviewed"])
        self.assertFalse(row["semanticEquivalenceProven"])

    def test_unresolved_cannot_hide_candidates_and_nonlocal_cannot_be_profile_local(self):
        snapshots = {key: value for key, value in self.f.snapshots.items() if key == "field-0"}
        candidate_row = self.f.rows[0]["candidates"][0]
        rows = [field_row(field) for field in coverage.FIELDS]
        rows[0] = field_row(coverage.FIELDS[0], disposition="unresolved", candidates=[candidate_row])
        with self.assertRaisesRegex(MuseumError, "cannot hide"):
            self.f.bind(rows, snapshots)
        rows[0] = field_row(coverage.FIELDS[0], disposition="profile_local")
        with self.assertRaisesRegex(MuseumError, "not profile-local"):
            self.f.bind(rows, {})

    def test_multiple_candidates_are_ambiguous_even_when_identical(self):
        source = self.f.snapshots["field-0"]
        snapshots = {"one": source, "two": source}
        base = self.f.rows[0]["candidates"][0]
        rows = [field_row(field) for field in coverage.FIELDS]
        rows[0] = field_row(coverage.FIELDS[0], disposition="authority", candidates=[
            {**base, "snapshot": "one"}, {**base, "snapshot": "two"}])
        report = loads(self.f.bind(rows, snapshots)["report.json"],
                       maximum=coverage.MAX_PACKAGE, canonical=True)
        self.assertEqual(report["fields"][0]["status"], "ambiguous")
        self.assertIsNone(report["fields"][0]["candidateValueUri"])
        duplicate = copy.deepcopy(rows); duplicate[0]["candidates"][1]["snapshot"] = "one"
        with self.assertRaisesRegex(MuseumError, "absent/duplicate"):
            self.f.bind(duplicate, {"one": source})

    def test_candidate_conflicts_stale_deprecated_and_replaced_never_bind(self):
        field = coverage.FIELDS[0]
        scheme = field["expectedScheme"]
        cases = (
            ([triple(field["original"]["valueUri"], v1.MADS + "authoritativeLabel", literal("other"))],
             {}, "ambiguous_original_labels", "ambiguous"),
            ([triple(field["original"]["valueUri"], v1.MADS + "code", literal("other"))],
             {}, "ambiguous_original_codes", "ambiguous"),
            ([triple(field["original"]["valueUri"], v1.RDF + "type", iri("https://example.test/Type"))],
             {}, "ambiguous_original_types", "ambiguous"),
            ([triple(field["original"]["valueUri"], v1.MADS + "isMemberOfMADSScheme",
                     iri("http://id.loc.gov/vocabulary/preservation/foreign"))],
             {}, "ambiguous_scheme_membership", "ambiguous"),
            ([triple(field["original"]["valueUri"], v1.RDF + "type", iri(v1.MADS + "DeprecatedAuthority"))],
             {}, "original_term_deprecated", "unresolved"),
            ([triple(field["original"]["valueUri"], v1.DCT + "isReplacedBy",
                     iri(scheme + "/replacement"))], {}, "original_term_replaced", "unresolved"),
            ([], {"include_scheme": False}, "exact_scheme_membership_missing", "unresolved"),
            ([], {"retrieved": "2020-01-01T00:00:00Z"}, "snapshot_outside_freshness_window", "stale"),
        )
        for extra, options, reason, status in cases:
            with self.subTest(reason=reason):
                raw = raw_term(field["original"]["valueUri"], scheme, field["targetLabel"],
                    extra=extra, include_scheme=options.get("include_scheme", True))
                descriptor_raw, pin = descriptor(raw, field["original"]["valueUri"], scheme,
                    retrieved=options.get("retrieved", "2026-09-20T00:00:00Z"))
                snapshots = {"candidate": (descriptor_raw, raw, pin, "synthetic_fixture", None)}
                candidate_row = candidate("candidate", field["original"]["valueUri"], field["targetLabel"])
                report = loads(self.f.one(0, snapshots, candidate_row)["report.json"],
                               maximum=coverage.MAX_PACKAGE, canonical=True)
                row = report["fields"][0]
                self.assertEqual(row["status"], status)
                self.assertIn(reason, row["candidates"][0]["reasons"])
                self.assertIsNone(row["candidateValueUri"])

    def test_original_value_iri_guard_and_required_lexical_facts(self):
        field = coverage.FIELDS[0]; scheme = field["expectedScheme"]
        term = scheme + "/alternate"
        extra = [triple(term, v1.OWL + "versionInfo", literal("v1")),
                 triple(term, v1.DCT + "valid", literal("2026-01-01"))]
        raw = raw_term(term, scheme, field["targetLabel"], extra=extra)
        descriptor_raw, pin = descriptor(raw, term, scheme)
        snapshots = {"alternate": (descriptor_raw, raw, pin, "synthetic_fixture", None)}
        candidate_row = candidate("alternate", term, field["targetLabel"],
                                  version="v1", effective="2026-01-01")
        report = loads(self.f.one(0, snapshots, candidate_row)["report.json"],
                       maximum=coverage.MAX_PACKAGE, canonical=True)
        row = report["fields"][0]
        self.assertEqual(row["status"], "unresolved")
        self.assertIn("original_profile_value_uri_differs", row["candidates"][0]["reasons"])
        wrong = {**candidate_row, "requiredVersion": "V1"}
        report = loads(self.f.one(0, snapshots, wrong)["report.json"],
                       maximum=coverage.MAX_PACKAGE, canonical=True)
        self.assertIn("requiredVersion_not_supported", report["fields"][0]["candidates"][0]["reasons"])

    def test_wrong_authority_family_membership_cannot_support_an_exact_label(self):
        field = coverage.FIELDS[0]
        wrong_scheme = coverage.BASE + "agentType"
        term = wrong_scheme + "/ing"
        raw = raw_term(term, wrong_scheme, field["targetLabel"])
        descriptor_raw, pin = descriptor(raw, term, wrong_scheme)
        snapshots = {"wrong-family": (descriptor_raw, raw, pin, "synthetic_fixture", None)}
        candidate_row = candidate("wrong-family", term, field["targetLabel"])
        report = loads(self.f.one(0, snapshots, candidate_row)["report.json"],
                       maximum=coverage.MAX_PACKAGE, canonical=True)
        row = report["fields"][0]
        self.assertEqual(row["status"], "unresolved")
        self.assertIn("original_profile_scheme_differs", row["candidates"][0]["reasons"])
        self.assertIsNone(row["candidateValueUri"])

    def test_premis_action_type_is_supplemental_only_for_event_type_fields(self):
        event = coverage.FIELDS[0]
        event_term = event["original"]["valueUri"]
        event_raw = raw_term(event_term, event["expectedScheme"], event["targetLabel"],
            extra=[triple(event_term, v1.RDF + "type", iri(PREMIS_ACTION))])
        event_descriptor, event_pin = descriptor(event_raw, event_term, event["expectedScheme"])
        event_snapshots = {"event-action": (event_descriptor, event_raw, event_pin,
                                             "synthetic_fixture", None)}
        event_candidate = candidate("event-action", event_term, event["targetLabel"])
        report = loads(self.f.one(0, event_snapshots, event_candidate)["report.json"],
                       maximum=coverage.MAX_PACKAGE, canonical=True)
        self.assertEqual(report["fields"][0]["status"], "bound")

        action_only = ("\n".join([
            triple(event_term, v1.RDF + "type", iri(PREMIS_ACTION)),
            triple(event_term, v1.MADS + "authoritativeLabel", literal(event["targetLabel"])),
            triple(event_term, v1.MADS + "code", literal("ing")),
            triple(event_term, v1.MADS + "isMemberOfMADSScheme", iri(event["expectedScheme"])),
        ]) + "\n").encode()
        action_descriptor, action_pin = descriptor(action_only, event_term, event["expectedScheme"])
        action_snapshots = {"action-only": (action_descriptor, action_only, action_pin,
                                             "synthetic_fixture", None)}
        report = loads(self.f.one(0, action_snapshots,
            candidate("action-only", event_term, event["targetLabel"]))["report.json"],
            maximum=coverage.MAX_PACKAGE, canonical=True)
        self.assertEqual(report["fields"][0]["status"], "unresolved")
        self.assertIn("authority_concept_type_missing",
                      report["fields"][0]["candidates"][0]["reasons"])

        agent_index = 19
        agent = coverage.FIELDS[agent_index]
        agent_term = agent["expectedScheme"] + "/person"
        agent_raw = raw_term(agent_term, agent["expectedScheme"], agent["targetLabel"],
            extra=[triple(agent_term, v1.RDF + "type", iri(PREMIS_ACTION))])
        agent_descriptor, agent_pin = descriptor(agent_raw, agent_term, agent["expectedScheme"])
        agent_snapshots = {"agent-action": (agent_descriptor, agent_raw, agent_pin,
                                             "synthetic_fixture", None)}
        report = loads(self.f.one(agent_index, agent_snapshots,
            candidate("agent-action", agent_term, agent["targetLabel"]))["report.json"],
            maximum=coverage.MAX_PACKAGE, canonical=True)
        row = report["fields"][agent_index]
        self.assertEqual(row["status"], "ambiguous")
        self.assertIn("ambiguous_original_types", row["candidates"][0]["reasons"])

    def test_unused_unknown_and_bounded_snapshot_selection_rejects(self):
        with self.assertRaisesRegex(MuseumError, "unselected snapshot"):
            self.f.bind([field_row(field) for field in coverage.FIELDS],
                        {"unused": self.f.snapshots["field-0"]})
        rows = [field_row(field) for field in coverage.FIELDS]
        rows[0] = field_row(coverage.FIELDS[0], disposition="authority",
            candidates=[{**self.f.rows[0]["candidates"][0], "snapshot": "missing"}])
        with self.assertRaisesRegex(MuseumError, "absent/duplicate"):
            self.f.bind(rows, {})
        with patch.object(coverage, "MAX_TOTAL", 1), self.assertRaisesRegex(
                MuseumError, "aggregate source bound"):
            self.f.bind([field_row(field) for field in coverage.FIELDS], {})
        too_many = [field_row(field) for field in coverage.FIELDS]
        too_many[0] = field_row(coverage.FIELDS[0], disposition="authority",
                                candidates=[self.f.rows[0]["candidates"][0]] * 5)
        with self.assertRaisesRegex(MuseumError, "candidate count"):
            self.f.bind(too_many, {})
        with patch.object(coverage, "MAX_SNAPSHOTS", 0), self.assertRaisesRegex(
                MuseumError, "snapshot count"):
            self.f.bind([field_row(field) for field in coverage.FIELDS],
                        {"unused": self.f.snapshots["field-0"]})

    def test_retrieval_observation_and_provenance_are_exact_caller_admitted_inputs(self):
        field = coverage.FIELDS[0]; scheme = field["expectedScheme"]
        term = field["original"]["valueUri"]; raw = raw_term(term, scheme, field["targetLabel"])
        descriptor_raw, pin = descriptor(raw, term, scheme, provenance="retained_http_observation")
        d = loads(descriptor_raw, canonical=True)
        observation = {"uri": d["sourceUri"], "finalUri": d["sourceUri"], "status": 200,
            "contentType": d["mediaType"] + "; charset=UTF-8", "bytes": len(raw),
            "sha256": sha256(raw).hexdigest(), "retrievedAt": d["retrievedAt"]}
        retrieval = dumps(observation)
        parsed = coverage.parse_snapshot(descriptor_raw, raw, descriptor_hash=pin,
            provenance="retained_http_observation", retrieval=retrieval)
        self.assertEqual(parsed["retrieval"]["observationHash"], keccak256(retrieval))
        self.assertFalse(parsed["publisherAuthenticated"])
        for key, value in (("uri", "https://example.test/wrong"), ("finalUri", "https://example.test/wrong"),
                           ("status", 206), ("contentType", "text/turtle"), ("bytes", len(raw) + 1),
                           ("sha256", "00" * 32), ("retrievedAt", "2026-09-20T00:00:01Z")):
            changed = dict(observation); changed[key] = value
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "observation differs"):
                coverage.parse_snapshot(descriptor_raw, raw, descriptor_hash=pin,
                    provenance="retained_http_observation", retrieval=dumps(changed))
        with self.assertRaisesRegex(MuseumError, "observation required"):
            coverage.parse_snapshot(descriptor_raw, raw, descriptor_hash=pin,
                provenance="retained_http_observation")
        supplied_descriptor, supplied_pin = descriptor(raw, term, scheme, provenance="supplied_bytes")
        with self.assertRaisesRegex(MuseumError, "other provenance"):
            coverage.parse_snapshot(supplied_descriptor, raw, descriptor_hash=supplied_pin,
                provenance="supplied_bytes", retrieval=retrieval)

    def test_offline_package_reconstructs_and_rejects_tamper_even_when_rehashed(self):
        package = coverage.build(coverage.ORIGINAL_PROFILE_BYTES, self.f.request,
                                 self.f.snapshots, **self.f.pins)
        manifest_hash = keccak256(package["manifest.json"])
        report = coverage.verify(package, manifest_hash)
        self.assertEqual(report["fieldCount"], "35")
        changed = dict(package)
        value = loads(changed["report.json"], maximum=coverage.MAX_PACKAGE, canonical=True)
        value["completeEnumeratedFieldAccounting"] = False
        changed["report.json"] = dumps(value)
        manifest = loads(changed["manifest.json"], canonical=True)
        manifest["files"] = v1._inventory({path: raw for path, raw in changed.items()
                                            if path != "manifest.json"})
        changed["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            coverage.verify(changed, keccak256(changed["manifest.json"]))
        changed = dict(package); changed["report.json"] += b" "
        with self.assertRaisesRegex(MuseumError, "inventory differs"):
            coverage.verify(changed, manifest_hash)

    def test_retained_example_replays_all_fields_and_exact_package_pins(self):
        pins = coverage.example(check=True)
        package = coverage.example_package()
        report = coverage.verify(package, pins["manifestHash"])
        self.assertEqual((len(package), sum(map(len, package.values()))),
                         (int(pins["packageFiles"]), int(pins["packageBytes"])))
        self.assertEqual((pins["termSnapshots"], pins["discoveryObservations"]), ("17", "8"))
        self.assertEqual(report["fieldCount"], "35")
        self.assertEqual(report["counts"],
                         {"bound": "17", "profile_local": "8", "unresolved": "10"})
        self.assertEqual(keccak256(package["manifest.json"]), pins["manifestHash"])
        self.assertEqual(keccak256(package["report.json"]), pins["reportHash"])
        self.assertEqual((pins["profileHash"], pins["originalProfileHash"],
                          pins["parentSnapshotProfileHash"]),
                         (coverage.PROFILE_HASH, ORIGINAL_PIN, V1_PROFILE_PIN))
        discovery = loads((ROOT / "schemas/museum/premis-authority-coverage/example/expected/"
                           "discovery.json").read_bytes(), maximum=coverage.MAX_PACKAGE,
                          canonical=True)
        self.assertEqual(len(discovery["observations"]), 8)
        self.assertEqual(Counter(row["kind"] for row in discovery["observations"]),
                         {"scheme": 4, "unavailable": 4})
        self.assertTrue(all(not row["supportsTermBinding"] and not row["absenceProven"]
                            and not row["publisherAuthenticated"]
                            for row in discovery["observations"]))
        self.assertEqual(keccak256(dumps(discovery)), pins["discoveryHash"])

    def test_rehashed_discovery_source_and_derived_output_tamper_fail_replay(self):
        tracked = ROOT / "schemas/museum/premis-authority-coverage/example"
        with tempfile.TemporaryDirectory() as directory:
            alternate_root = Path(directory)
            example_root = alternate_root / "schemas/museum/premis-authority-coverage/example"
            shutil.copytree(tracked, example_root)
            input_root = example_root / "input"
            index_path = input_root / "index.json"
            index = loads(index_path.read_bytes(), maximum=coverage.MAX_INPUT, canonical=True)
            key = next(iter(index["discovery"]))
            retrieval_path = input_root / "discovery" / (key + ".retrieval.json")
            retrieval = loads(retrieval_path.read_bytes(), maximum=coverage.MAX_INPUT)
            retrieval["sha256"] = "00" * 32
            changed_retrieval = dumps(retrieval)
            retrieval_path.write_bytes(changed_retrieval)
            index["discovery"][key]["retrievalHash"] = keccak256(changed_retrieval)
            index_path.write_bytes(dumps(index))
            with self.assertRaisesRegex(MuseumError, "discovery retrieval differs"):
                coverage._discovery(input_root, index["discovery"])

            shutil.rmtree(example_root)
            shutil.copytree(tracked, example_root)
            discovery_path = example_root / "expected/discovery.json"
            changed = loads(discovery_path.read_bytes(), maximum=coverage.MAX_PACKAGE,
                            canonical=True)
            changed["observations"][0]["publisherAuthenticated"] = True
            changed_raw = dumps(changed); discovery_path.write_bytes(changed_raw)
            pins_path = example_root / "pins.json"
            pins = loads(pins_path.read_bytes(), canonical=True)
            pins["discoveryHash"] = keccak256(changed_raw)
            pins_path.write_bytes(dumps(pins))
            with patch.object(coverage, "ROOT", alternate_root), self.assertRaisesRegex(
                    MuseumError, "generated example differs"):
                coverage.example(check=True)


if __name__ == "__main__":
    unittest.main()
