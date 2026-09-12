"""Foundation proof, not complete MSM conformance or authenticated onchain input."""

import copy
from dataclasses import FrozenInstanceError, replace
from hashlib import sha256
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chunk_documents import write_document
from .coverage import inventory, verify_coverage
from .dependencies import Limits, OfflineDocuments, chunk_carrier, safe_path
from .fixtures import documents
from .schemas import NAMES, obj, schemas
from .selection import select_fixture
from .source import FixtureSourceAdapter, RecordSelector, SourceRecord, public_records
from .validation import validate_document
from .identity import EntityDeclaration, entity_index, require_ordinary_revision_identity
from .preview import fixture_package, verify_fixture_package, write_package

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "schemas/museum/fixtures"
H = "0x" + "ab" * 32
CORE = "0x" + "12" * 20
AUTHOR = "0x" + "34" * 20


def record(payload, identity="record", agent="urn:example:artist", recorder=AUTHOR, disclosure="public"):
    schema = dumps({"type": "object"})
    selector = RecordSelector(CORE, schema_id(identity), H, schema_id("FIXTURE_ONLY"), keccak256(schema),
                              schema_id("FIXTURE_RECORD"), recorder, "ARTIST_SIGNER", "0", schema_id(identity + "-chain"))
    content = dumps(payload)
    return SourceRecord(selector, content, keccak256(content), schema,
                        dumps({"mode": "synthetic_fixture", "recorder": recorder, "agentIri": agent}), disclosure)


def source_row(record, pointer):
    s = record.selector
    return {"recordHash": s.record_hash, "pointer": pointer, "recorder": s.recorder,
            "subjectId": s.subject_id, "authorizationClass": s.authorization_class,
            "host": s.host, "schemaId": s.schema_id, "schemaHash": s.schema_hash,
            "recordType": s.record_type, "recordIndex": s.record_index, "recordChainHash": s.record_chain_hash}


def assertion(value="Milos", origin="direct_statement"):
    return {"id": "urn:example:assertion:1", "subject": "urn:example:place:1", "relation": "urn:example:name",
            "object": {"literal": value}, "assertingAgent": "urn:example:artist", "origin": origin,
            "reviewStatus": "unreviewed", "mappingRule": "urn:example:rule:name"}


def policy(state, rows, reviewers=()):
    return dumps({"sourceStateHash": state.commitment, "profileHash": H, "sources": rows,
                  "reviewers": list(reviewers), "singleValuedRelations": ["urn:example:name"],
                  "independentReviewRequired": False})


class ExactValues(unittest.TestCase):
    def test_uint_boundaries_never_round(self):
        for value in ((1 << 53) - 1, 1 << 53, (1 << 53) + 1, (1 << 256) - 1):
            self.assertEqual(uint(str(value)), value)
            self.assertEqual(loads(dumps({"tokenId": str(value)}))["tokenId"], str(value))
        for value in (str(1 << 256), "01", "-1", "1e2", " 1", 9007199254740993):
            with self.subTest(value=value), self.assertRaises(MuseumError):
                uint(value)

    def test_exact_bytes_and_unicode(self):
        self.assertEqual(hex_bytes("0x00ff", 2), b"\x00\xff")
        for value in ("0xFF", "0x0", "00", "0X00"):
            with self.assertRaises(MuseumError):
                hex_bytes(value)
        composed, decomposed = "\u00e9", "e\u0301"
        self.assertNotEqual(dumps(composed), dumps(decomposed))
        self.assertEqual(loads(dumps(decomposed)), decomposed)

    def test_invalid_json_rejected_before_canonicalization(self):
        for data in (b'{"x":1,"x":2}', b'{"x":NaN}', b'{"x":Infinity}', b'{"x":1.5}',
                     b'{"x":9007199254740993}', b'{"x":"\\ud800"}', b'\xef\xbb\xbf{}'):
            with self.subTest(data=data), self.assertRaises(MuseumError):
                loads(data)
        with self.assertRaises(MuseumError):
            loads(b'{ "x": "1" }', canonical=True)

    def test_jcs_order_and_schema_id_golden(self):
        self.assertEqual(dumps({"\ufb33": "last", "\U0001f600": "first"}),
                         '{"\U0001f600":"first","\ufb33":"last"}'.encode())
        expected = ("0x6d3c59c0ce8c9342f5afefeaa8f2a188b2c8fc73db5c6519ab7635fa4de26e5c",
                    "0x14686475452e99526427d2987e7c5fe928461cc015abaa5b3fc1f9ccc7298144",
                    "0x103fdeb9d387f235d864ab48ef87eb57ec93299ce53ade611b5c909f84170b07")
        self.assertEqual(tuple(map(schema_id, NAMES)), expected)
        self.assertEqual(schema_id("6529STREAM_SUBJECT_TOKEN_V1"),
                         "0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e")

    def test_subject_and_chain_use_exact_abi_words(self):
        # Independent named ABI words, with the canonical domain literal.
        raw = bytes.fromhex("1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e")
        raw += (1).to_bytes(32, "big") + bytes(12) + bytes.fromhex(CORE[2:]) + bytes.fromhex("ff" * 32)
        self.assertEqual(subject_id("token", "1", CORE, "99", token_id=str((1 << 256) - 1)), keccak256(raw))
        chain = bytes.fromhex("0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609")
        chain += (1).to_bytes(32, "big") + bytes(12) + bytes.fromhex(CORE[2:]) + (99).to_bytes(32, "big")
        chain += bytes.fromhex(H[2:]) + bytes(32) + bytes.fromhex(H[2:]) + (2).to_bytes(32, "big")
        self.assertEqual(record_chain("1", CORE, "99", H, "0x" + "00" * 32, H, "2"), keccak256(chain))

    def test_payload_limit_includes_json_overhead(self):
        data = dumps("x" * 24574)
        self.assertEqual(len(data), 24576)
        self.assertEqual(loads(data), "x" * 24574)
        with self.assertRaises(MuseumError):
            loads(dumps("x" * 24575))


class SchemaAndCoverage(unittest.TestCase):
    def test_three_candidate_documents_are_canonical_and_valid_schemas(self):
        from jsonschema import Draft202012Validator
        for name, schema in schemas().items():
            Draft202012Validator.check_schema(schema)
            self.assertEqual((ROOT / "schemas/museum" / (name + ".json")).read_bytes(), dumps(schema))
            self.assertLessEqual(len(dumps(schema)), 24576)

    def test_width_keyword_rejects_overflow(self):
        spec = dumps({"type": "string", "x-stream-unsigned-bits": 256})
        validate_document(spec, dumps(str((1 << 256) - 1)))
        with self.assertRaises(MuseumError):
            validate_document(spec, dumps(str(1 << 256)))

    def test_all_eight_scenarios_inventory_every_source_field(self):
        corpus = documents()
        spec = corpus.pop("source.schema.json")
        self.assertEqual(len(corpus), 8)
        for name, data in corpus.items():
            with self.subTest(name=name):
                self.assertEqual((FIXTURES / name).read_bytes(), dumps(data))
                fields = inventory(spec, data)
                rows = [{"pointer": f.pointer, "presence": f.presence, "exactHex": "0x" + f.exact.hex(),
                         "disposition": "retained_stream_only", "rule": "fixture-source-retention", "reason": "No projection claim"}
                        for f in fields]
                self.assertTrue(verify_coverage(fields, rows))
                with self.assertRaises(MuseumError):
                    verify_coverage(fields, rows[:-1])
                with self.assertRaises(MuseumError):
                    verify_coverage(fields, rows + rows[:1])

    def test_absence_null_order_and_exact_decimals_stay_distinct(self):
        corpus = documents()
        spec, data = corpus["source.schema.json"], corpus["photograph.json"]
        first = inventory(spec, data)
        self.assertEqual(next(f.presence for f in first if f.pointer == "/optionalNote"), "absent")
        data["optionalNote"] = None
        second = inventory(spec, data)
        self.assertEqual(next(f.exact for f in second if f.pointer == "/optionalNote"), b"null")
        self.assertIn(b'"40.00"', [f.exact for f in second])
        data["resources"].reverse()
        self.assertNotEqual(second, inventory(spec, data))

    def test_hostile_refs_fail_before_validator_network(self):
        with patch("urllib.request.urlopen", side_effect=AssertionError("network forbidden")):
            for action in (lambda: inventory({"$ref": "https://example.invalid/schema"}, {}),
                           lambda: validate_document(dumps({"$ref": "https://example.invalid/schema"}), b"{}")):
                with self.assertRaises(MuseumError):
                    action()


class SourceBoundary(unittest.TestCase):
    def test_source_is_immutable_and_rehashes_original_bytes(self):
        r = record({"words": "unchanged"})
        with self.assertRaises(FrozenInstanceError):
            r.payload = b"{}"
        with self.assertRaises(MuseumError):
            replace(r, payload=dumps({"words": "changed"}))
        with self.assertRaises(MuseumError):
            replace(r, payload=b'{ "words": "unchanged" }')
        self.assertEqual(FixtureSourceAdapter("test", (r,)).snapshot().mode, "synthetic_fixture")

    def test_restricted_values_do_not_enter_public_records(self):
        public, private = record({"x": "public"}), record({"SECRET": "restricted"}, "private", disclosure="restricted")
        state = FixtureSourceAdapter("test", (public, private)).snapshot()
        self.assertEqual(public_records(state), (public,))


class PolicySelection(unittest.TestCase):
    def test_every_selector_field_is_bound_even_with_rehashed_policy(self):
        r = record({"assertions": [assertion()]})
        state = FixtureSourceAdapter("selectors", (r,)).snapshot()
        row = source_row(r, "/assertions/0")
        p = policy(state, [row])
        self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), 1)
        mutations = {"host": AUTHOR, "schemaId": H, "schemaHash": H, "recordType": H,
                     "recordIndex": "1", "recordChainHash": H, "recordHash": H,
                     "recorder": CORE, "subjectId": "0x" + "00" * 32,
                     "authorizationClass": "CURATOR_SIGNER", "pointer": "/assertions/1"}
        for field, value in mutations.items():
            with self.subTest(field=field):
                changed = dict(row, **{field: value})
                changed_policy = policy(state, [changed])
                with self.assertRaises(MuseumError):
                    select_fixture(state, changed_policy, keccak256(changed_policy), H)
        for changed in ({k: v for k, v in row.items() if k != "host"}, dict(row, ignored="field")):
            changed_policy = policy(state, [changed])
            with self.assertRaises(MuseumError):
                select_fixture(state, changed_policy, keccak256(changed_policy), H)

    def test_review_cannot_move_to_identical_bytes_in_another_revision_or_pointer(self):
        a = assertion(origin="human_mapping")
        r = record({"assertions": [a, a]}, "original")
        later = record({"assertions": [a, a]}, "later")
        review = {"reviewer": "urn:example:curator", "assertionHash": keccak256(dumps(a)),
                  "assertionSelector": source_row(r, "/assertions/0"), "profileHash": H,
                  "mappingRule": a["mappingRule"], "disposition": "reviewed", "selfReview": False}
        rr = record({"review": review}, "original-review", "urn:example:curator", CORE)
        state = FixtureSourceAdapter("review-revisions", (r, later, rr)).snapshot()
        for target, pointer, count in ((r, "/assertions/0", 1), (r, "/assertions/1", 0), (later, "/assertions/0", 0)):
            p = policy(state, [source_row(target, pointer)], [source_row(rr, "/review")])
            self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), count)
        fresh = dict(review, assertionSelector=source_row(later, "/assertions/0"))
        fresh_review = record({"review": fresh}, "fresh-review", "urn:example:curator", CORE)
        state = FixtureSourceAdapter("review-revisions", (r, later, rr, fresh_review)).snapshot()
        p = policy(state, [source_row(later, "/assertions/0")], [source_row(fresh_review, "/review")])
        self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), 1)

    def test_direct_source_policy_and_state_tampering(self):
        r = record({"assertions": [assertion()]})
        state = FixtureSourceAdapter("selection", (r,)).snapshot()
        p = policy(state, [source_row(r, "/assertions/0")])
        self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), 1)
        changed = loads(p)
        changed["sources"][0]["recorder"] = CORE
        with self.assertRaises(MuseumError):
            select_fixture(state, dumps(changed), keccak256(p), H)
        with self.assertRaises(MuseumError):
            select_fixture(state, dumps(changed), keccak256(dumps(changed)), H)
        with self.assertRaises(MuseumError):
            select_fixture(replace(state, mode="recorded_state"), p, keccak256(p), H)

    def test_eligible_conflict_withholds_but_unselected_dispute_cannot_veto(self):
        first, other = assertion(), assertion("Other island")
        first_record, other_record = record({"assertions": [first]}), record({"assertions": [other]}, "other")
        state = FixtureSourceAdapter("conflict", (first_record, other_record)).snapshot()
        rows = [source_row(first_record, "/assertions/0")]
        p = policy(state, rows)
        self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), 1)
        rows.append(source_row(other_record, "/assertions/0"))
        p = policy(state, rows)
        result = select_fixture(state, p, keccak256(p), H)
        self.assertEqual((len(result.selected), len(result.withheld)), (0, 2))

    def test_mapping_requires_separate_exact_review_evidence(self):
        a = assertion(origin="human_mapping")
        a["reviewStatus"] = "reviewed"  # This self-asserted status cannot authorize.
        r = record({"assertions": [a]})
        state = FixtureSourceAdapter("mapping", (r,)).snapshot()
        p = policy(state, [source_row(r, "/assertions/0")])
        self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), 0)
        review = {"reviewer": "urn:example:curator", "assertionHash": keccak256(dumps(a)), "profileHash": H,
                  "assertionSelector": source_row(r, "/assertions/0"),
                  "mappingRule": a["mappingRule"], "disposition": "reviewed", "selfReview": False}
        rr = record({"review": review}, "review", "urn:example:curator", CORE)
        state = FixtureSourceAdapter("mapping", (r, rr)).snapshot()
        p = policy(state, [source_row(r, "/assertions/0")], [source_row(rr, "/review")])
        self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), 1)
        bad = replace(rr, authority_evidence=dumps({"mode": "synthetic_fixture", "recorder": CORE, "agentIri": "urn:example:someone-else"}))
        state = FixtureSourceAdapter("mapping", (r, bad)).snapshot()
        p = policy(state, [source_row(r, "/assertions/0")], [source_row(bad, "/review")])
        with self.assertRaises(MuseumError):
            select_fixture(state, p, keccak256(p), H)

    def test_self_review_is_explicit_and_not_independent(self):
        a = assertion(origin="human_mapping")
        r = record({"assertions": [a]})
        review = {"reviewer": a["assertingAgent"], "assertionHash": keccak256(dumps(a)), "profileHash": H,
                  "assertionSelector": source_row(r, "/assertions/0"),
                  "mappingRule": a["mappingRule"], "disposition": "reviewed", "selfReview": True}
        rr = record({"review": review}, "self-review")
        state = FixtureSourceAdapter("self-review", (r, rr)).snapshot()
        p = policy(state, [source_row(r, "/assertions/0")], [source_row(rr, "/review")])
        self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), 1)
        changed = loads(p)
        changed["independentReviewRequired"] = True
        p = dumps(changed)
        self.assertEqual(len(select_fixture(state, p, keccak256(p), H).selected), 0)


class Dependencies(unittest.TestCase):
    def test_jsonld_loader_rejects_nonfinite_unicode_and_depth_but_accepts_version(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            raw_values = (b'{"@context":{"@version":1.1}}', b'{"v":NaN}', b'{"v":Infinity}',
                          b'{"v":1e999}', b'{"v":"\\ud800"}', b'{"v":9007199254740993}',
                          b'[' * 65 + b'0' + b']' * 65)
            for index, raw in enumerate(raw_values):
                uri = "urn:jsonld:" + str(index)
                row = write_document(root, raw, {"sourceUri": uri, "revision": "synthetic-jsonld",
                    "retrievedAt": "2026-09-12T00:00:00Z", "mediaType": "application/ld+json", "dependencies": []})
                loader = OfflineDocuments(root, {"documents": [row]})
                if index == 0:
                    self.assertEqual(loader.jsonld_loader(uri)["document"]["@context"]["@version"], 1.1)
                else:
                    with self.subTest(index=index), self.assertRaises(MuseumError):
                        loader.jsonld_loader(uri)

    def test_official_context_exact_ten_chunks_offline_and_old_pin_survives(self):
        root = FIXTURES / "dependencies"
        index = loads((root / "index.json").read_bytes())
        with patch("urllib.request.urlopen", side_effect=AssertionError("network forbidden")):
            loader = OfflineDocuments(root, index)
            uri = "https://linked.art/ns/v1/linked-art.json"
            raw = loader.load(uri)
            self.assertEqual(len(raw), 79235)
            self.assertEqual(sha256(raw).hexdigest(), "3017421203aba8ea73f159aced1285e35b37cee49b5648cf19b01f237025f165")
            self.assertEqual(len(index["documents"][0]["chunks"]), 10)
            self.assertEqual(loader.jsonld_loader(uri)["document"]["@context"]["@version"], 1.1)
            with self.assertRaises(MuseumError):
                loader.load("https://linked.art/ns/v2/linked-art.json")
            # A changed external URI/data cannot affect the immutable old loader.
            self.assertEqual(loader.load(uri), raw)

    def test_complete_encoded_carrier_limit(self):
        payload = chunk_carrier(bytes(8192), H, "4095")
        self.assertLess(len(payload), 24576)
        self.assertEqual(chunk_carrier(bytes(8192), H, "4095", len(payload)), payload)
        with self.assertRaises(MuseumError):
            chunk_carrier(bytes(8192), H, "4095", len(payload) - 1)
        with self.assertRaises(MuseumError):
            chunk_carrier(bytes(24576), H, "0")

    def test_tamper_path_bounds_and_graph_reject(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            row = write_document(root, b"exact", {"sourceUri": "urn:one", "revision": "fixture1",
                      "retrievedAt": "2026-09-12T00:00:00Z", "mediaType": "text/plain", "dependencies": []})
            OfflineDocuments(root, {"documents": [row]})
            for limits in (Limits(documents=0), Limits(chunks=0), Limits(aggregate_bytes=4)):
                with self.assertRaises(MuseumError):
                    OfflineDocuments(root, {"documents": [row]}, limits)
            bad = copy.deepcopy(row)
            bad["dependencies"] = ["urn:one"]
            with self.assertRaises(MuseumError):
                OfflineDocuments(root, {"documents": [bad]})
            bad["dependencies"] = ["urn:missing"]
            with self.assertRaises(MuseumError):
                OfflineDocuments(root, {"documents": [bad]})
            (root / row["chunks"][0]["path"]).write_bytes(b"wrong")
            with self.assertRaises(MuseumError):
                OfflineDocuments(root, {"documents": [row]})
            for path in ("../out", "/tmp/out", "C:/out", "a\\b", "a/./b", "a./b", "a//b"):
                with self.subTest(path=path), self.assertRaises(MuseumError):
                    safe_path(root, path)

    def test_later_context_revision_and_exact_depth_boundary(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            def row(uri, content, dependencies):
                return write_document(root, content, {"sourceUri": uri, "revision": "synthetic-revision",
                    "retrievedAt": "2026-09-12T00:00:00Z", "mediaType": "application/json", "dependencies": dependencies})
            old = row("urn:context:old", b'{"value":"old"}', [])
            old_loader = OfflineDocuments(root, {"documents": [old]})
            new = row("urn:context:new", b'{"value":"new"}', [])
            new_loader = OfflineDocuments(root, {"documents": [new]})
            self.assertNotEqual(old_loader.load("urn:context:old"), new_loader.load("urn:context:new"))
            self.assertEqual(OfflineDocuments(root, {"documents": [old]}).load("urn:context:old"), b'{"value":"old"}')
            chain = [row("urn:chain:" + str(i), dumps({"node": str(i)}),
                         ["urn:chain:" + str(i + 1)] if i < 8 else []) for i in range(9)]
            OfflineDocuments(root, {"documents": chain})
            extra = row("urn:chain:9", b'{"node":"9"}', [])
            chain[8]["dependencies"] = ["urn:chain:9"]
            with self.assertRaises(MuseumError):
                OfflineDocuments(root, {"documents": chain + [extra]})


class IdentityAndPackages(unittest.TestCase):
    def test_malformed_unselected_identifier_remains_diagnostic_without_veto(self):
        selected = EntityDeclaration("urn:example:selected", "visual_content", H, "/entities/0", "urn:artist")
        hostile = EntityDeclaration("not an IRI", "unsupported", schema_id("hostile"), "/entities/0", "urn:other")
        admitted = {(selected.source_record_hash, selected.source_pointer): selected.declaring_agent}
        for order in ((selected, hostile), (hostile, selected)):
            self.assertEqual(entity_index(order, admitted, (selected.identifier,)), ((selected,), (hostile,)))
        with self.assertRaises(MuseumError):
            entity_index((selected, hostile), admitted | {
                (hostile.source_record_hash, hostile.source_pointer): hostile.declaring_agent}, ())

    def test_identity_agent_and_same_kind_collision_are_not_input_order_dependent(self):
        a = EntityDeclaration("urn:example:stable", "visual_content", H, "/entities/0", "urn:artist")
        b = replace(a, source_record_hash=schema_id("other"), declaring_agent="urn:other")
        selected = {(a.source_record_hash, a.source_pointer): "urn:artist",
                    (b.source_record_hash, b.source_pointer): "urn:other"}
        for order in ((a, b), (b, a)):
            with self.assertRaises(MuseumError):
                entity_index(order, selected, ())
        with self.assertRaises(MuseumError):
            entity_index((replace(a, declaring_agent="urn:impostor"),), selected, ())
        only_artist = {(a.source_record_hash, a.source_pointer): "urn:artist"}
        self.assertEqual(entity_index((a, b), only_artist, (a.identifier,)),
                         entity_index((b, a), only_artist, (a.identifier,)))

    def test_unselected_identity_reuse_cannot_replace_artist_declaration(self):
        a = EntityDeclaration("urn:example:stable", "visual_content", H, "/entities/0", "urn:artist")
        b = EntityDeclaration(a.identifier, "person", schema_id("hostile"), "/entities/0", "urn:other")
        selected = {(a.source_record_hash, a.source_pointer): a.declaring_agent}
        index, collisions = entity_index((a, b), selected, (a.identifier,))
        self.assertEqual(index, (a,))
        self.assertEqual(collisions, (b,))
        with self.assertRaises(MuseumError):
            entity_index((a, b), selected | {(b.source_record_hash, b.source_pointer): b.declaring_agent}, ())
        with self.assertRaises(MuseumError):
            entity_index((a,), selected, ("urn:missing",))
        require_ordinary_revision_identity(a, replace(a, source_record_hash=schema_id("new")))
        with self.assertRaises(MuseumError):
            require_ordinary_revision_identity(a, replace(a, identifier="urn:new"))

    def test_all_eight_packages_regenerate_without_network(self):
        corpus = documents()
        spec = dumps(corpus.pop("source.schema.json"))
        with tempfile.TemporaryDirectory() as temp, patch("urllib.request.urlopen", side_effect=AssertionError("network forbidden")):
            for filename, payload in corpus.items():
                destination = Path(temp) / filename
                package = fixture_package(spec, dumps(payload))
                write_package(destination, package)
                manifest = verify_fixture_package(destination)
                self.assertEqual(manifest["mode"], "synthetic_fixture")
                self.assertFalse(manifest["claims"]["recordedState"])
                self.assertEqual(package, fixture_package(spec, dumps(payload)))

    def test_tampered_coverage_extra_file_and_circular_manifest_fail(self):
        corpus = documents()
        package = fixture_package(dumps(corpus["source.schema.json"]), dumps(corpus["photograph.json"]))
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "package"
            write_package(root, package)
            path = root / "reports/coverage.json"
            path.write_bytes(b"[]")
            with self.assertRaises(MuseumError):
                verify_fixture_package(root)
            path.write_bytes(package["reports/coverage.json"])
            (root / "unexpected.txt").write_bytes(b"unexpected")
            with self.assertRaises(MuseumError):
                verify_fixture_package(root)
            manifest = loads(package["manifest.json"])
            manifest["components"][0]["path"] = "manifest.json"
            (root / "manifest.json").write_bytes(dumps(manifest))
            with self.assertRaises(MuseumError):
                verify_fixture_package(root)


if __name__ == "__main__":
    unittest.main()
