"""Focused synthetic tests for bounded PREMIS authority snapshots.

The byte fixtures are local synthetic N-Triples unless a retained source-survey
file is already present.  They do not authenticate LoC, establish current
vocabulary state, or prove institutional acceptance.
"""

from hashlib import sha256
from pathlib import Path
import unittest
from unittest.mock import patch

from .authority_snapshot import RAW_BYTES
from .canonical import MuseumError, dumps, keccak256, loads
from . import premis_authority_snapshot as authority
from .premis_authority_snapshot import (
    CS, DCT, EVENT_AUTHORITY, MADS, MODE, ORIGINAL_PROFILE_BYTES,
    ORIGINAL_PROFILE_HASH, OWL, PROFILE_BYTES, PROFILE_HASH, RDF, RI, SKOS,
    XSD, bind, parse_snapshot,
    build, definitions, example, verify,
)


ROOT = Path(__file__).resolve().parents[2]
TRACKED_ING = ROOT / "schemas/museum/premis-authority-snapshot/example/input/ing.nt"
TERM = EVENT_AUTHORITY + "/ing"


def iri(value):
    return "<" + value + ">"


def triple(subject, predicate, obj):
    return f"{subject} {iri(predicate)} {obj} ."


def literal(value, suffix=""):
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + escaped + '"' + suffix


def source_lines(*extra, term=TERM, label="ingestion", code="ing"):
    subject = iri(term)
    return [
        triple(subject, RDF + "type", iri(MADS + "Authority")),
        triple(subject, MADS + "authoritativeLabel", literal(label)),
        triple(subject, MADS + "code", literal(code)),
        triple(subject, MADS + "isMemberOfMADSScheme", iri(EVENT_AUTHORITY)),
        *extra,
    ]


def source_bytes(*extra, term=TERM, label="ingestion", code="ing"):
    return ("\n".join(source_lines(*extra, term=term, label=label, code=code)) + "\n").encode()


def descriptor(raw, *, term=TERM, algorithm="1", provenance="synthetic_fixture",
               retrieved="2026-09-20T00:00:00Z", **changes):
    digest = keccak256(raw) if algorithm == "1" else "0x" + sha256(raw).hexdigest()
    value = {"version": "1", "termIri": term, "schemeIri": EVENT_AUTHORITY,
        "sourceUri": term + ".nt", "retrievedAt": retrieved,
        "contentHash": {"algorithm": algorithm, "digest": digest,
            "canonicalizationId": RAW_BYTES},
        "byteLength": str(len(raw)), "mediaType": "application/n-triples",
        "attribution": "Synthetic LoC-shaped test bytes",
        "reuseTerms": "Synthetic fixture; no publisher claim",
        "provenance": provenance}
    value.update(changes)
    encoded = dumps(value)
    return encoded, keccak256(encoded)


def parsed(raw=None, **changes):
    raw = source_bytes() if raw is None else raw
    encoded, pin = descriptor(raw, **changes)
    return parse_snapshot(encoded, raw, descriptor_hash=pin,
                          provenance=changes.get("provenance", "synthetic_fixture"))


def request(bindings, *, as_of="2026-09-21T00:00:00Z", age="172800", **changes):
    value = {"version": "1", "mode": MODE, "profileHash": PROFILE_HASH,
        "originalProfileHash": ORIGINAL_PROFILE_HASH, "asOf": as_of,
        "maxSnapshotAgeSeconds": age, "bindings": bindings}
    value.update(changes)
    raw = dumps(value)
    return raw, keccak256(raw)


def binding(snapshot="ing", *, pointer="/eventTypes/0", term=TERM,
            version=None, effective=None):
    return {"sourcePointer": pointer, "snapshot": snapshot, "termIri": term,
        "requiredVersion": version, "requiredEffectiveDate": effective}


def inputs(raw=None, *, name="ing", **descriptor_changes):
    raw = source_bytes() if raw is None else raw
    encoded, pin = descriptor(raw, **descriptor_changes)
    provenance = descriptor_changes.get("provenance", "synthetic_fixture")
    return {name: (encoded, raw, pin, provenance)}


def bound(bindings=None, snapshots=None, **request_changes):
    raw, pin = request([binding()] if bindings is None else bindings, **request_changes)
    files = bind(ORIGINAL_PROFILE_BYTES, raw, inputs() if snapshots is None else snapshots,
        original_profile_hash=ORIGINAL_PROFILE_HASH, request_hash=pin,
        profile_hash=PROFILE_HASH)
    return files, loads(files["report.json"], canonical=True)


class PremisAuthoritySnapshotTest(unittest.TestCase):
    def test_parse_preserves_occurrences_exact_source_selectors_and_history(self):
        admin = "_:admin"
        version = triple(iri(TERM), OWL + "versionInfo", literal("2026.1"))
        effective = triple(iri(TERM), DCT + "valid", literal("2026-01-01"))
        link = triple(iri(TERM), MADS + "adminMetadata", admin)
        history = triple(admin, RI + "recordStatus", literal("revised"))
        duplicate = triple(iri(TERM), SKOS + "prefLabel", literal("ingestion", "@en"))
        raw = source_bytes(version, effective, link, history, duplicate, duplicate)
        value = parsed(raw)
        self.assertEqual((value["version"]["status"], value["effectiveDates"]["status"]),
                         ("supplied", "supplied"))
        self.assertEqual(len(value["recordHistory"]["links"]), 1)
        self.assertEqual(len(value["recordHistory"]["facts"]), 1)
        duplicates = [row for row in value["facts"]
            if row["predicate"]["value"] == SKOS + "prefLabel"]
        self.assertEqual(len(duplicates), 2)
        self.assertNotEqual(duplicates[0]["source"]["line"], duplicates[1]["source"]["line"])
        for row in value["facts"]:
            selector = row["source"]
            start = int(selector["byteOffset"]); size = int(selector["byteLength"])
            self.assertEqual(keccak256(raw[start:start + size]), selector["rawHash"])
        self.assertTrue(value["validNTriples"])
        self.assertFalse(value["publisherAuthenticated"])

    def test_hash_size_descriptor_and_provenance_are_independent_guards(self):
        raw = source_bytes()
        for algorithm in ("1", "2"):
            with self.subTest(algorithm=algorithm):
                value = parsed(raw, algorithm=algorithm, provenance="supplied_bytes")
                self.assertEqual(value["descriptor"]["contentHash"]["algorithm"], algorithm)
                self.assertEqual(value["provenance"], "supplied_bytes")
        encoded, pin = descriptor(raw)
        changed = bytes([raw[0] ^ 1]) + raw[1:]
        with self.assertRaisesRegex(MuseumError, "digest differs"):
            parse_snapshot(encoded, changed, descriptor_hash=pin, provenance="synthetic_fixture")
        wrong_size = loads(encoded, canonical=True); wrong_size["byteLength"] = str(len(raw) + 1)
        wrong_size_raw = dumps(wrong_size)
        with self.assertRaisesRegex(MuseumError, "size differs"):
            parse_snapshot(wrong_size_raw, raw, descriptor_hash=keccak256(wrong_size_raw),
                           provenance="synthetic_fixture")
        with self.assertRaisesRegex(MuseumError, "external input hash"):
            parse_snapshot(encoded, raw, descriptor_hash="0x" + "00" * 32,
                           provenance="synthetic_fixture")
        with self.assertRaisesRegex(MuseumError, "provenance differs"):
            parse_snapshot(encoded, raw, descriptor_hash=pin,
                           provenance="retained_http_observation")

    def test_only_finite_relative_reference_exception_is_opaque(self):
        allowed = triple("_:record", RI + "recordContentSource", "<dlc>")
        also_allowed = triple("_:change", CS + "creatorName", "<dlc>")
        value = parsed(source_bytes(allowed, also_allowed))
        self.assertFalse(value["validNTriples"])
        self.assertEqual(len(value["opaqueReferences"]), 2)
        self.assertTrue(all(row["relativeLexicalValue"] == "dlc"
                            and row["reason"] == "unresolved_original_relative_reference"
                            for row in value["opaqueReferences"]))
        self.assertNotIn("dlc", {row["object"]["value"] for row in value["facts"]})
        for bad in (
            triple("_:record", MADS + "code", "<dlc>"),
            triple(iri(TERM), RI + "recordContentSource", "<dlc>"),
            triple("_:record", RI + "recordContentSource", "<other>"),
        ):
            with self.subTest(line=bad), self.assertRaisesRegex(MuseumError, "unsupported line"):
                parsed(source_bytes(bad))

    def test_literal_escapes_decode_once_and_invalid_unicode_rejects(self):
        predicate = MADS + "definitionNote"
        escaped_backslash_t = triple(iri(TERM), predicate, literal(r"\t"))
        value = parsed(source_bytes(escaped_backslash_t))
        fact = next(row for row in value["facts"] if row["predicate"]["value"] == predicate)
        self.assertEqual(fact["object"]["value"], r"\t")
        self.assertNotEqual(fact["object"]["value"], "\t")

        unicode_literal = '"' + "\\" + 'u0069ngestion"'
        value = parsed(source_bytes(triple(iri(TERM), predicate, unicode_literal)))
        fact = next(row for row in value["facts"] if row["predicate"]["value"] == predicate)
        self.assertEqual(fact["object"]["value"], "ingestion")

        supplementary_literal = '"face ' + "\\" + 'U0001F600"'
        value = parsed(source_bytes(triple(iri(TERM), predicate, supplementary_literal)))
        fact = next(row for row in value["facts"] if row["predicate"]["value"] == predicate)
        self.assertEqual(fact["object"]["value"], "face \U0001f600")

        invalid = (r'"bad\q"', r'"bad\u123"', r'"bad\u12xz"',
                   r'"bad\uD800"', r'"bad\U00110000"', '"bad' + "\\" + '"')
        for lexical in invalid:
            raw = source_bytes(triple(iri(TERM), predicate, lexical))
            with self.subTest(lexical=lexical), self.assertRaises(MuseumError):
                parsed(raw)

    def test_named_graph_and_malformed_ntriples_reject_without_normalization(self):
        graph = (triple(iri(TERM), RDF + "type", iri(MADS + "Authority"))[:-1]
                 + " " + iri("https://example.test/graph") + " .\n").encode()
        with self.assertRaisesRegex(MuseumError, "named graph"):
            parsed(graph)
        for raw in (b"not rdf\n", b"<relative> <urn:p> <urn:o> .\n", b"\xff\n"):
            with self.subTest(raw=raw), self.assertRaises(MuseumError):
                parsed(raw)
        bad_blank = source_bytes('_:invalid. ' + iri(MADS + "code") + ' "x" .')
        with self.assertRaises(MuseumError):
            parsed(bad_blank)

    def test_exact_binding_returns_retained_sources_and_no_authentication_claim(self):
        files, report = bound()
        self.assertEqual(set(files), {"source-profile.json", "request.json", "profile.json",
            "sources/ing.descriptor.json", "sources/ing.nt", "snapshots/ing.json", "report.json"})
        self.assertEqual((files["source-profile.json"], files["profile.json"]),
                         (ORIGINAL_PROFILE_BYTES, PROFILE_BYTES))
        row = report["bindings"][0]
        self.assertEqual((report["status"], row["status"], row["candidateValueUri"]),
                         ("bound", "bound", TERM))
        self.assertEqual(row["sourceProvenance"], "synthetic_fixture")
        self.assertFalse(report["publisherAuthenticated"])
        self.assertFalse(report["currentAuthorityProven"])
        self.assertFalse(report["semanticEquivalenceProven"])

    def test_language_labels_require_exact_language_shape_and_foreign_facts_are_retained(self):
        no_language = triple(iri(TERM), MADS + "authoritativeLabel",
            literal("ingestion", "^^" + iri(RDF + "langString")))
        raw = ("\n".join(source_lines(term=TERM, label="ignored", code="ing")[0:1]
              + [no_language,
                 triple(iri(TERM), MADS + "code", literal("ing")),
                 triple(iri(TERM), MADS + "isMemberOfMADSScheme", iri(EVENT_AUTHORITY))])
              + "\n").encode()
        _, report = bound(snapshots=inputs(raw))
        self.assertEqual(report["bindings"][0]["status"], "unresolved")
        self.assertIn("profile_label_not_supported", report["bindings"][0]["reasons"])

        english = triple(iri(TERM), MADS + "authoritativeLabel", literal("ingestion", "@en"))
        foreign = triple(iri(TERM), SKOS + "prefLabel", literal("ingestion étrangère", "@fr"))
        raw = ("\n".join([source_lines()[0], english, foreign,
            triple(iri(TERM), MADS + "code", literal("ing")),
            triple(iri(TERM), MADS + "isMemberOfMADSScheme", iri(EVENT_AUTHORITY))]) + "\n").encode()
        _, report = bound(snapshots=inputs(raw))
        row = report["bindings"][0]
        self.assertEqual(row["status"], "bound")
        self.assertTrue(any(fact["object"].get("language") == "fr"
                            for fact in row["supportingFacts"]))

    def test_foreign_term_label_code_scheme_and_deprecation_never_bind(self):
        cases = []
        cases.append((inputs(source_bytes(label="not ingestion")), "profile_label_not_supported", "unresolved"))
        cases.append((inputs(source_bytes(code="wrong")), "original_code_differs", "unresolved"))
        cases.append((inputs(source_bytes(
            triple(iri(TERM), MADS + "isMemberOfMADSScheme", iri("https://example.test/scheme")))),
            "ambiguous_scheme_membership", "ambiguous"))
        cases.append((inputs(source_bytes(
            triple(iri(TERM), RDF + "type", iri(MADS + "DeprecatedAuthority")))),
            "original_term_deprecated", "unresolved"))
        foreign = EVENT_AUTHORITY + "/mig"
        cases.append((inputs(source_bytes(term=foreign, label="migration", code="mig"), term=foreign),
            "selected_term_differs", "unresolved"))
        for snapshots, reason, status in cases:
            with self.subTest(reason=reason):
                _, report = bound(snapshots=snapshots)
                row = report["bindings"][0]
                self.assertEqual(row["status"], status)
                self.assertIn(reason, row["reasons"])
                self.assertIsNone(row["candidateValueUri"])

    def test_conflicting_label_code_type_and_scheme_are_ambiguous(self):
        conflicts = (
            triple(iri(TERM), SKOS + "prefLabel", literal("different")),
            triple(iri(TERM), SKOS + "notation", literal("other")),
            triple(iri(TERM), RDF + "type", iri("https://example.test/ForeignType")),
            triple(iri(TERM), SKOS + "inScheme", iri("https://example.test/foreign-scheme")),
        )
        expected = ("ambiguous_original_labels", "ambiguous_original_codes",
                    "ambiguous_original_types", "ambiguous_scheme_membership")
        for extra, reason in zip(conflicts, expected):
            with self.subTest(reason=reason):
                _, report = bound(snapshots=inputs(source_bytes(extra)))
                row = report["bindings"][0]
                self.assertEqual(row["status"], "ambiguous")
                self.assertIn(reason, row["reasons"])

    def test_required_version_and_effective_date_are_exact_lexical_facts(self):
        raw = source_bytes(
            triple(iri(TERM), OWL + "versionInfo", literal("2026.1")),
            triple(iri(TERM), DCT + "valid", literal("2026-01-01")))
        snapshots = inputs(raw)
        _, report = bound([binding(version="2026.1", effective="2026-01-01")], snapshots)
        self.assertEqual(report["bindings"][0]["status"], "bound")
        _, report = bound([binding(version="2026.01", effective="2026-01-01")], snapshots)
        self.assertEqual(report["bindings"][0]["status"], "unresolved")
        self.assertIn("requiredVersion_not_supported", report["bindings"][0]["reasons"])
        ambiguous = source_bytes(
            triple(iri(TERM), OWL + "versionInfo", literal("2026.1")),
            triple(iri(TERM), OWL + "versionInfo", literal("2026.2")))
        _, report = bound([binding(version="2026.1")], inputs(ambiguous))
        self.assertEqual(report["bindings"][0]["status"], "ambiguous")

    def test_freshness_policy_marks_old_and_future_retrieval_stale(self):
        for retrieved, reason in (("2026-09-01T00:00:00Z", "snapshot_outside_freshness_window"),
                                  ("2026-09-22T00:00:00Z", "retrieved_after_as_of")):
            with self.subTest(retrieved=retrieved):
                _, report = bound(snapshots=inputs(retrieved=retrieved),
                                  as_of="2026-09-21T00:00:00Z", age="86400")
                row = report["bindings"][0]
                self.assertEqual(row["status"], "stale")
                self.assertIn(reason, row["reasons"])
                self.assertIsNone(row["candidateValueUri"])

    def test_timestamp_precision_over_microseconds_rejects_in_descriptor_and_request(self):
        raw = source_bytes()
        encoded, pin = descriptor(raw, retrieved="2026-09-20T00:00:00.1234567Z")
        with self.assertRaisesRegex(MuseumError, "precision"):
            parse_snapshot(encoded, raw, descriptor_hash=pin, provenance="synthetic_fixture")
        request_raw, request_pin = request([binding()], as_of="2026-09-21T00:00:00.1234567Z")
        with self.assertRaisesRegex(MuseumError, "precision"):
            bind(ORIGINAL_PROFILE_BYTES, request_raw, inputs(),
                original_profile_hash=ORIGINAL_PROFILE_HASH, request_hash=request_pin,
                profile_hash=PROFILE_HASH)

    def test_multiple_snapshots_for_one_pointer_are_ambiguous_and_extras_reject(self):
        snapshots = inputs(name="first") | inputs(name="second")
        _, report = bound([binding("first"), binding("second")], snapshots)
        self.assertEqual([row["status"] for row in report["bindings"]],
                         ["ambiguous", "ambiguous"])
        self.assertTrue(all("multiple_explicit_snapshots_for_field" in row["reasons"]
                            for row in report["bindings"]))
        with self.assertRaisesRegex(MuseumError, "unselected snapshot"):
            bound([binding("first")], snapshots)
        with self.assertRaisesRegex(MuseumError, "duplicate binding selection"):
            bound([binding("first"), binding("first")], {"first": snapshots["first"]})

    def test_closed_inputs_profile_pins_and_schema_bounds_reject(self):
        raw = source_bytes(); encoded, pin = descriptor(raw)
        for change in (
            {"extra": "no"}, {"schemeIri": "https://example.test/scheme"},
            {"sourceUri": "https://example.test/redirect.nt"}, {"mediaType": "text/turtle"},
            {"retrievedAt": "2026-09-20T00:00:00+00:00"},
        ):
            value = loads(encoded, canonical=True); value.update(change); changed = dumps(value)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                parse_snapshot(changed, raw, descriptor_hash=keccak256(changed),
                               provenance="synthetic_fixture")
        request_raw, request_pin = request([binding()])
        with self.assertRaisesRegex(MuseumError, "original/adapter profile"):
            bind(ORIGINAL_PROFILE_BYTES, request_raw, inputs(),
                 original_profile_hash=ORIGINAL_PROFILE_HASH, request_hash=request_pin,
                 profile_hash="0x" + "00" * 32)
        request_value = loads(request_raw, canonical=True); request_value["extra"] = False
        changed = dumps(request_value)
        with self.assertRaisesRegex(MuseumError, "request fields"):
            bind(ORIGINAL_PROFILE_BYTES, changed, inputs(),
                 original_profile_hash=ORIGINAL_PROFILE_HASH, request_hash=keccak256(changed),
                 profile_hash=PROFILE_HASH)

        with patch("tools.museum.premis_authority_snapshot.MAX_RAW", len(raw) - 1):
            with self.assertRaisesRegex(MuseumError, "raw size"):
                parse_snapshot(encoded, raw, descriptor_hash=pin,
                               provenance="synthetic_fixture")
        with patch("tools.museum.premis_authority_snapshot.MAX_FACTS", 3):
            with self.assertRaisesRegex(MuseumError, "line bound"):
                parse_snapshot(encoded, raw, descriptor_hash=pin,
                               provenance="synthetic_fixture")

    def test_package_verify_reconstructs_and_rejects_rehashed_report_replacement(self):
        request_raw, request_pin = request([binding()])
        pins = {"original_profile_hash": ORIGINAL_PROFILE_HASH,
            "request_hash": request_pin, "profile_hash": PROFILE_HASH}
        package = build(ORIGINAL_PROFILE_BYTES, request_raw, inputs(), **pins)
        manifest_hash = keccak256(package["manifest.json"])
        report = verify(package, manifest_hash)
        self.assertEqual(report["status"], "bound")
        changed = dict(package)
        changed_report = loads(changed["report.json"], canonical=True)
        changed_report["status"] = "unresolved"
        changed["report.json"] = dumps(changed_report)
        manifest = loads(changed["manifest.json"], canonical=True)
        manifest["files"] = [{"path": path, "byteLength": str(len(raw)),
            "keccak256": keccak256(raw)} for path, raw in sorted(changed.items())
            if path != "manifest.json"]
        changed["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            verify(changed, keccak256(changed["manifest.json"]))

    def test_package_report_may_expand_beyond_aggregate_source_bound(self):
        duplicate = triple(iri(TERM), SKOS + "prefLabel", literal("ingestion", "@en"))
        raw = source_bytes(*([duplicate] * 96))
        snapshots = inputs(raw)
        request_raw, request_pin = request([binding()])
        aggregate = (len(ORIGINAL_PROFILE_BYTES) + len(request_raw)
                     + len(snapshots["ing"][0]) + len(raw))
        pins = {"original_profile_hash": ORIGINAL_PROFILE_HASH,
            "request_hash": request_pin, "profile_hash": PROFILE_HASH}
        with patch.object(authority, "MAX_TOTAL", aggregate):
            package = build(ORIGINAL_PROFILE_BYTES, request_raw, snapshots, **pins)
            self.assertGreater(len(package["report.json"]), aggregate)
            report = verify(package, keccak256(package["manifest.json"]))
        self.assertEqual(report["status"], "bound")

    def test_checked_in_profile_and_example_are_deterministic_and_replayable(self):
        self.assertEqual(definitions(check=True), PROFILE_HASH)
        pins = example(check=True)
        root = ROOT / "schemas/museum/premis-authority-snapshot/example"
        descriptor_raw = (root / "input/ing.descriptor.json").read_bytes()
        source_raw = (root / "input/ing.nt").read_bytes()
        request_raw = (root / "input/request.json").read_bytes()
        descriptor_value = loads(descriptor_raw, canonical=True)
        package = build(ORIGINAL_PROFILE_BYTES, request_raw,
            {"ing": (descriptor_raw, source_raw, pins["descriptorHash"],
                     descriptor_value["provenance"])},
            original_profile_hash=pins["originalProfileHash"],
            request_hash=pins["requestHash"], profile_hash=pins["profileHash"])
        report = verify(package, pins["manifestHash"])
        self.assertEqual(package["report.json"], (root / "expected/report.json").read_bytes())
        self.assertEqual(package["snapshots/ing.json"],
                         (root / "expected/snapshot.json").read_bytes())
        self.assertEqual(report["bindings"][0]["status"], "bound")
        self.assertFalse(report["publisherAuthenticated"])

    def test_retained_ing_source_preserves_known_relative_reference_diagnostics(self):
        raw = TRACKED_ING.read_bytes()
        self.assertEqual(len(raw), 13418)
        self.assertEqual("0x" + sha256(raw).hexdigest(),
                         "0xb8877ee1a5da2db67f920b91013166f1ffbf44a281ef4b675171a77d6d10dd0f")
        encoded, pin = descriptor(raw, algorithm="2", provenance="retained_http_observation")
        value = parse_snapshot(encoded, raw, descriptor_hash=pin,
                               provenance="retained_http_observation")
        self.assertFalse(value["validNTriples"])
        self.assertEqual(len(value["opaqueReferences"]), 8)
        self.assertEqual({predicate for predicate in
            (RI + "recordContentSource", CS + "creatorName")
            if any(iri(predicate) in row["originalLine"] for row in value["opaqueReferences"])},
            {RI + "recordContentSource", CS + "creatorName"})
        self.assertTrue(all(sum(iri(predicate) in row["originalLine"] for predicate in
            (RI + "recordContentSource", CS + "creatorName")) == 1
            for row in value["opaqueReferences"]))
        self.assertFalse(value["publisherAuthenticated"])


if __name__ == "__main__":
    unittest.main()
