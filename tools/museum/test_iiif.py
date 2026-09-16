"""Independent source, target and exact-value oracles for the bounded IIIF profile."""

import base64
import copy
from dataclasses import replace
from decimal import Decimal
from hashlib import sha256
from pathlib import Path
import unittest
from unittest.mock import patch

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads
from .iiif import FIELDS, project_iiif_fixture, verify_iiif_fixture
from .iiif_model import (PinnedIIIF, PROFILE_BYTES, PROFILE_HASH, SOURCE, DIGEST, SIZE, XSD,
                        plain_span, span_text, http_id, CONTEXT, ANNO_CONTEXT, SOUND_CONTEXT, check_original_context)
from .iiif_numbers import ExactDecimal, target_dumps, target_loads
from .premis import PinnedPremis, PROFILE_BYTES as PREMIS_BYTES, PROFILE_HASH as PREMIS_HASH
from .projection_v2 import ProjectionProfileV2, CROSSWALK_V2_BYTES, CROSSWALK_V2_HASH, LA, CONTENT, CONTENT_KIND
from .test_premis import facts, arguments as premis_arguments
from .test_projection import entity
from .test_projection_v2 import fixture_v2, literal, assertion
from .test_review import H, record, row

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
FILES = ("photo", "text", "audio", "video")
EXACT = 'Credited to <name> & literal &lt; "quotes" \'apostrophe\'\r\nline\rbreak\n𝄞 e\u0301'


def cid(digest):
    return "ipfs://b" + base64.b32encode(bytes.fromhex("01551220" + digest)).decode().lower().rstrip("=")


def source_data(claims=None, entities=None, extra=()):
    if entities is None:
        entities = [entity("urn:fixture:work", "abstract_work", [{"value": "Four forms — e\u0301", "kind": "preferred", "language": None}])]
        entities += [entity("urn:fixture:" + f, "digital_object", [{"value": f + " exact title", "kind": "preferred", "language": None}]) for f in FILES]
        entities += [entity("urn:fixture:visual", "visual_content"), entity("urn:fixture:transcript", "statement"),
                     entity("urn:fixture:sound-content", "information_object"), entity("urn:fixture:av-content", "information_object")]
    if claims is None:
        def f(subject, name, value, **kwargs):
            return assertion(subject + "-" + name, subject, FIELDS[name], literal(value, **kwargs))
        claims = [f("work", "summary", EXACT), f("work", "attribution", "Work attribution only"),
                  f("work", "manifest-rights", "http://creativecommons.org/licenses/by/4.0/", datatype=XSD + "anyURI")]
        for i, (name, kind, mime, puid) in enumerate(zip(FILES, ("Image", "Text", "Sound", "Video"),
                ("image/jpeg", "text/plain", "audio/wav", "video/mp4"), ("fmt/44", "x-fmt/111", "fmt/6", "fmt/199"))):
            digest = sha256(("synthetic declared media " + name).encode()).hexdigest()
            claims += facts(name, size=str(i + 100), digest=digest, puid=puid)
            claims += [f(name, "presentation-type", kind), f(name, "mime", mime),
                f(name, "content-uri", cid(digest), datatype=XSD + "anyURI"), f(name, "attribution", name + ": " + EXACT),
                f(name, "rights", "http://rightsstatements.org/vocab/InC/1.0/", datatype=XSD + "anyURI"),
                assertion(name + "-work", name, FIELDS["presentation-of"], {"entity": "urn:fixture:work"})]
            if kind in ("Image", "Video", "Text"):
                for dim, value in (("width", "6000"), ("height", "4000")):
                    claims.append(f(name, "text-canvas-" + dim if kind == "Text" else dim, value,
                        datatype=XSD + "positiveInteger", unit="canvas-unit" if kind == "Text" else "px"))
            if kind in ("Sound", "Video"):
                claims.append(f(name, "duration", "0.10000000000000001" if kind == "Sound" else "220.000", datatype=XSD + "decimal", unit="s"))
        claims += [assertion("visual", "photo", LA + "digitally_shows", {"entity": "urn:fixture:visual"}),
            assertion("text-kind", "transcript", CONTENT_KIND, literal("linguistic")),
            assertion("exact-text", "transcript", CONTENT, literal(EXACT)),
            assertion("text-carrier", "text", LA + "digitally_carries", {"entity": "urn:fixture:transcript"}),
            assertion("audio-kind", "sound-content", CONTENT_KIND, literal("nonlinguistic_sound")),
            assertion("audio-carrier", "audio", LA + "digitally_carries", {"entity": "urn:fixture:sound-content"}),
            assertion("video-kind", "av-content", CONTENT_KIND, literal("structured_multimedia")),
            assertion("video-carrier", "video", LA + "digitally_carries", {"entity": "urn:fixture:av-content"}),
            assertion("unmapped", "work", "urn:fixture:historical-value", literal(str((1 << 256) - 1) + "\r\n40.00", precision="verbatim"))]
    from .source import FixtureSourceAdapter
    from .test_schema_inventory import assertion_document
    # Each independently selected record remains within the original24KiB source bound.
    data = fixture_v2(entities=entities, assertions=claims[:16])
    records = [data[0].records[0]]
    for i in range(16, len(claims), 16):
        doc = assertion_document(); doc.update(entities=[], assertions=claims[i:i+16])
        r = record(doc, "iiif-claims-" + str(i), "urn:fixture:artist", "artist", [str(i), "0", "0"])
        records.append(r)
        data[1]["sourceAuthoritySet"].extend(row(r) | {"pointer": "/assertions/" + str(j)} for j in range(len(doc["assertions"])))
    state = FixtureSourceAdapter("iiif-projection", tuple(records) + tuple(extra)).snapshot()
    data = state, data[1], data[2]
    data[1]["sourceStateHash"] = state.commitment
    data[2]["sourceStateHash"] = state.commitment
    from .premis import FIELDS as PF
    data[1]["singleValuedRelations"].extend(list(PF.values()) + list(FIELDS.values()))
    data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
    return data


def arguments(data, linked, premis, iiif, order=FILES):
    args, kwargs = premis_arguments(data, linked, premis, ["urn:fixture:" + f for f in FILES])
    plan = {"mode": "synthetic_iiif_projection", "version": "1", "sourceStateHash": data[0].commitment,
        "profileHash": H, "linkedArtPlanHash": kwargs["plan_hash"], "premisPlanHash": kwargs["premis_plan_hash"],
        "iiifProfileHash": PROFILE_HASH, "work": "urn:fixture:work", "manifestId": "https://example.org/iiif/fixture/manifest",
        "canvases": [{"file": "urn:fixture:" + f, "canvasId": "https://example.org/iiif/fixture/canvas/" + f,
                      "pageId": "https://example.org/iiif/fixture/page/" + f,
                      "annotationId": "https://example.org/iiif/fixture/annotation/" + f} for f in order]}
    raw = dumps(plan)
    return (*args, raw), kwargs | {"iiif_plan_hash": keccak256(raw), "iiif_profile": iiif}


def updated(data, subject, relation, value=None, *, remove=False, **qualifiers):
    doc = source_document(data)
    target = next(c for c in doc["assertions"] if c["subject"] == "urn:fixture:" + subject and c["relation"] == FIELDS[relation])
    if remove:
        doc["assertions"].remove(target)
    else:
        target["object"]["literal"].update(lexicalValue=value, **qualifiers)
    return source_data(doc["assertions"], doc["entities"])


def source_document(data):
    doc = loads(data[0].records[0].payload)
    doc["assertions"] = [a for r in data[0].records for a in loads(r.payload)["assertions"]]
    return doc


class IIIFCorrespondence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.linked = ProjectionProfileV2(ROOT, CROSSWALK_V2_BYTES, crosswalk_hash=CROSSWALK_V2_HASH,
            validation_hash=keccak256((ROOT / "linked-art-v2/validation-policy.json").read_bytes()),
            vocabulary_hash=keccak256((ROOT / "standards/vocabulary-policy.json").read_bytes()))
        cls.premis = PinnedPremis(ROOT, PREMIS_BYTES, profile_hash=PREMIS_HASH)
        cls.iiif = PinnedIIIF(ROOT, PROFILE_BYTES, profile_hash=PROFILE_HASH)

    def run_projection(self, data=None, order=FILES):
        args, kwargs = arguments(source_data() if data is None else data, self.linked, self.premis, self.iiif, order)
        return project_iiif_fixture(*args, **kwargs)

    def test_four_media_exact_shared_identity_attribution_fixity_and_extent(self):
        data = source_data()
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            result = self.run_projection(data)
        m, expanded = self.iiif.validate(result.manifest)
        self.assertEqual(m["label"], {"none": ["Four forms — e\u0301"]})
        self.assertEqual(span_text(m["summary"]["none"][0]), EXACT)
        self.assertEqual(span_text(m["requiredStatement"]["value"]["none"][0]), "Work attribution only")
        for i, (f, typ) in enumerate(zip(FILES, ("Image", "Text", "Sound", "Video"))):
            c = m["items"][i]; a = c["items"][0]["items"][0]; body = a["body"]
            self.assertEqual(a["target"], c["id"])
            self.assertEqual((a["motivation"], body["type"]), ("painting", typ))
            self.assertEqual(body["id"], cid(sha256(("synthetic declared media " + f).encode()).hexdigest()))
            self.assertEqual(body[SIZE]["@value"], str(100 + i))
            self.assertEqual(span_text(body["requiredStatement"]["value"]["none"][0]), f + ": " + EXACT)
            self.assertNotEqual(body["rights"], m["rights"])
            self.assertEqual(body[SOURCE]["@value"]["fileEntity"], "urn:fixture:" + f)
            self.assertTrue(body[SOURCE]["@value"]["selectors"])
            self.assertTrue(all(s["recordHash"] in {r.selector.record_hash for r in data[0].records} for s in body[SOURCE]["@value"]["selectors"]))
        self.assertEqual(m["items"][2]["duration"], Decimal("0.10000000000000001"))
        self.assertIn(b'"duration":220.000', result.manifest)
        self.assertNotIn("width", m["items"][2])
        self.assertNotIn("width", m["items"][1]["items"][0]["items"][0]["body"])
        self.assertEqual(m["items"][1]["width"], 6000)
        rows = loads(result.correspondence)
        self.assertEqual([r["linkedArtId"] for r in rows], ["urn:fixture:" + f for f in FILES])
        self.assertTrue(all(r["sourceAnchors"] == [H] and r["workEntity"] == "urn:fixture:work" for r in rows))
        self.assertEqual(len(result.premis.linked_art.resources), 7)
        self.assertFalse(any(loads(result.report)["claims"].values()))

    def test_offline_expansion_keeps_sound_decimal_and_json_selector_types(self):
        result = self.run_projection()
        value, expanded = self.iiif.validate(result.manifest)
        # Navigate the actual RDF predicates, independently of implementation constants.
        canvases = expanded[0]["http://www.w3.org/ns/activitystreams#items"][0]["@list"]
        a = canvases[2]["http://www.w3.org/ns/activitystreams#items"][0]["@list"][0]["http://www.w3.org/ns/activitystreams#items"][0]["@list"][0]
        body = a["http://www.w3.org/ns/oa#hasBody"][0]
        self.assertEqual(body["@type"], ["http://purl.org/dc/dcmitype/Sound"])
        self.assertEqual(body["http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#duration"], [{"@value": Decimal("0.10000000000000001")}])
        self.assertEqual(body[SOURCE], [{"@type": "@json", "@value": value["items"][2]["items"][0]["items"][0]["body"][SOURCE]["@value"]}])
        self.assertNotIn("@id", body[SOURCE][0])

    def test_independent_plaintext_xml_round_trip_and_controls(self):
        text = '<&> &lt; &amp; "double" \'single\'\r\nA\rB\nC\t𝄞 e\u0301'
        raw = plain_span(text)
        self.assertEqual(raw, '<span>&lt;&amp;&gt; &amp;lt; &amp;amp; "double" \'single\'&#13;\nA&#13;B\nC\t𝄞 e\u0301</span>')
        self.assertEqual(etree.fromstring(raw.encode()).text, text)
        self.assertEqual(span_text(raw), text)
        for invalid in ("\x00", "\x01", "\x0b", "\ufffe", "\ud800"):
            with self.subTest(invalid=repr(invalid)), self.assertRaisesRegex(MuseumError, "XML 1.0"):
                plain_span("valid" + invalid)
        for unsafe in ("<span><script>x</script></span>", "<span a='b'>x</span>", "<span>&lt;</span> ", "<span>&#xD;</span>"):
            with self.assertRaises(MuseumError): span_text(unsafe)

    def test_missing_file_attribution_or_rights_never_inherit_work_claims(self):
        good = source_data()
        for subject, field in (("photo", "attribution"), ("text", "rights"), ("work", "summary"), ("audio", "content-uri")):
            with self.subTest(subject=subject, field=field), self.assertRaisesRegex(MuseumError, "missing admitted fact"):
                self.run_projection(updated(good, subject, field, remove=True))
        self.run_projection(good)

    def test_selected_conflicts_withhold_and_preserve_original_evidence(self):
        data = source_data(); doc = source_document(data)
        conflicting = assertion("foreign-attribution", "audio", FIELDS["attribution"], literal("Another claimant"))
        doc["assertions"].append(conflicting)
        with self.assertRaisesRegex(MuseumError, "conflicting selected facts") as error:
            self.run_projection(source_data(doc["assertions"], doc["entities"]))
        self.assertIn("Another claimant", str(error.exception))
        self.assertIn("recordHash", str(error.exception))
        self.assertIn("audio: ", str(error.exception))

    def test_wrong_units_types_unsafe_mime_lexicals_and_rights_fail_without_coercion(self):
        good = source_data()
        cases = [("photo", "mime", "image/svg+xml", {}), ("text", "mime", "text/html", {}),
            ("audio", "presentation-type", "Audio", {}), ("photo", "width", "6000", {"unit": "cm"}),
            ("text", "text-canvas-width", "06000", {}), ("photo", "width", str(1 << 53), {}),
            ("audio", "duration", "1", {}), ("audio", "duration", "0.0", {}), ("audio", "duration", "1e-3", {}),
            ("audio", "duration", "0.10", {"precision": "approximate"}),
            ("photo", "rights", "https://creativecommons.org/licenses/by/4.0/", {}),
            ("photo", "attribution", "bad\x01", {}), ("photo", "mime", "image/jpeg\n", {})]
        for subject, field, value, extra in cases:
            with self.subTest(subject=subject, field=field, value=value), self.assertRaises(MuseumError):
                self.run_projection(updated(good, subject, field, value, **extra))
        self.run_projection(good)

    def test_extent_absence_extra_dimensions_and_unrelated_claims(self):
        good = source_data(); doc = source_document(good)
        for field in ("width", "height"):
            with self.assertRaisesRegex(MuseumError, "missing admitted fact"):
                self.run_projection(updated(good, "photo", field, remove=True))
        extra = assertion("audio-width", "audio", FIELDS["width"], literal("6000", datatype=XSD + "positiveInteger", unit="px"))
        with self.assertRaisesRegex(MuseumError, "layout dimensions"):
            self.run_projection(source_data(doc["assertions"] + [extra], doc["entities"]))
        extra["subject"] = "urn:fixture:work"
        self.assertEqual(loads(self.run_projection(source_data(doc["assertions"] + [extra], doc["entities"])).report)["mode"], "synthetic_iiif_projection")

    def test_complete_source_inventory_and_content_carriers_remain_distinct(self):
        result = self.run_projection()
        prior = loads(result.premis.coverage, maximum=67108864); current = loads(result.coverage, maximum=67108864)
        def extent(rows): return [(r["recordHash"], [(f["pointer"], f["presence"], f["exactHex"]) for f in r["fields"]]) for r in rows]
        self.assertEqual(extent(prior), extent(current))
        fields = [f for record in current for f in record["fields"]]
        exact = dumps(str((1 << 256) - 1) + "\r\n40.00")
        row = next(f for f in fields if f["exactHex"] == "0x" + exact.hex())
        self.assertEqual(row["disposition"], "retained_stream_only")
        resources = {r.identifier: loads(r.content) for r in result.premis.linked_art.resources}
        self.assertEqual(resources["urn:fixture:text"]["digitally_carries"], [{"id": "urn:fixture:transcript", "type": "LinguisticObject"}])
        self.assertEqual(resources["urn:fixture:transcript"]["content"], EXACT)
        sidecar = loads(result.premis.linked_art.sidecar, maximum=67108864)
        self.assertEqual({e["id"] for e in sidecar["extensionEntities"]}, {"urn:fixture:sound-content", "urn:fixture:av-content"})
        self.assertEqual({s["selector"]["recordHash"]: s["payloadHex"] for s in sidecar["publicSources"]},
                         {r.selector.record_hash: "0x" + r.payload.hex() for r in source_data()[0].records})

    def test_plan_target_collision_wrong_work_or_file_and_order_controls(self):
        data = source_data(); args, kwargs = arguments(data, self.linked, self.premis, self.iiif)
        for mutate in (lambda p: p.update(work="urn:fixture:photo"), lambda p: p["canvases"][0].update(file="urn:fixture:transcript"),
                       lambda p: p["canvases"][0].update(pageId=p["canvases"][0]["canvasId"]),
                       lambda p: p["canvases"][0].update(canvasId="https://example.org/c#xywh=0,0,1,1"),
                       lambda p: p.update(sourceStateHash="0x" + "ff" * 32)):
            plan = loads(args[-1]); mutate(plan); raw = dumps(plan)
            with self.assertRaises(MuseumError): project_iiif_fixture(*args[:-1], raw, **(kwargs | {"iiif_plan_hash": keccak256(raw)}))
        reversed_result = self.run_projection(data, tuple(reversed(FILES)))
        self.assertEqual([c["supplementalEntityIri"] for c in loads(reversed_result.correspondence)], ["urn:fixture:" + f for f in reversed(FILES)])
        self.assertEqual(reversed_result.premis.xml, self.run_projection(data).premis.xml)

    def test_structurally_valid_substitution_and_rehashed_report_cannot_hide_source_drift(self):
        data = source_data(); result = self.run_projection(data); args, kwargs = arguments(data, self.linked, self.premis, self.iiif)
        for before, after in ((b"photo exact title", b"Different title"), (b"photo: ", b"Other: "),
                               (b'"@value":"100"', b'"@value":"999"'), (b'"duration":220.000', b'"duration":220.001')):
            raw = result.manifest.replace(before, after)
            self.assertNotEqual(raw, result.manifest)
            self.iiif.validate(raw)
            report = loads(result.report); report["manifestHash"] = keccak256(raw)
            with self.subTest(after=after), self.assertRaisesRegex(MuseumError, "shared-source consistency"):
                verify_iiif_fixture(replace(result, manifest=raw, report=dumps(report)), *args, **kwargs)
        self.assertEqual(verify_iiif_fixture(result, *args, **kwargs)["sourceStateHash"], data[0].commitment)

    def test_renderer_target_schema_rejects_trim_ids_structures_and_nonfinite(self):
        raw = self.run_projection().manifest
        attacks = [raw.replace(b'"motivation":"painting"', b'"motivation":"supplementing"', 1),
                   raw.replace(b'"type":"Canvas"', b'"type":"Timeline"', 1),
                   raw.replace(b'"duration":220.000', b'"duration":NaN', 1),
                   raw.replace(b'"duration":220.000', b'"duration":220', 1),
                   raw.replace(b'"duration":220.000', b'"duration":221.000', 1),
                   raw.replace(b'"format":"text/plain"', b'"format":"text/html"', 1),
                   raw.replace(b'"type":"Manifest"', b'"type":"Manifest","service":[]', 1),
                   raw.replace(b'"type":"Manifest"', b'"type":"Manifest","type":"Manifest"', 1)]
        for attack in attacks:
            with self.assertRaises(MuseumError): self.iiif.validate(attack)
        self.iiif.validate(raw)

    def test_every_selector_and_review_admission_stays_bound(self):
        data = source_data(); data[1]["sourceAuthoritySet"][0]["host"] = "0x" + "77" * 20
        data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
        with self.assertRaisesRegex(MuseumError, "selector"): self.run_projection(data)
        data = source_data(); doc = source_document(data)
        next(c for c in doc["assertions"] if c["relation"] == FIELDS["attribution"])["origin"] = "human_mapping"
        with self.assertRaisesRegex(MuseumError, "missing admitted fact"): self.run_projection(source_data(doc["assertions"], doc["entities"]))
        data = source_data(); data[1]["singleValuedRelations"].remove(FIELDS["rights"])
        data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
        with self.assertRaisesRegex(MuseumError, "single-valued"): self.run_projection(data)

    def test_unselected_hostile_record_stays_nonveto_and_equivalent_claims_keep_all_evidence(self):
        data = source_data(); doc = source_document(data)
        hostile_doc = copy.deepcopy(doc); hostile_doc["assertions"] = [{"not": "admitted"}]
        hostile = record(hostile_doc, "hostile-iiif", "urn:fixture:hostile", "curator", ["20", "0", "0"])
        result = self.run_projection(source_data(doc["assertions"], doc["entities"], (hostile,)))
        self.assertEqual(len(loads(result.correspondence)), 4)
        claim = copy.deepcopy(next(c for c in doc["assertions"] if c["subject"] == "urn:fixture:photo" and c["relation"] == FIELDS["attribution"]))
        claim["id"] += ":equivalent"
        result = self.run_projection(source_data(doc["assertions"] + [claim], doc["entities"]))
        rows = [p for p in loads(result.provenance, maximum=67108864) if p["entity"] == "urn:fixture:photo" and p["rule"] == FIELDS["attribution"]]
        self.assertEqual(len(rows), 2)
        self.assertNotEqual(rows[0]["sourcePointer"], rows[1]["sourcePointer"])

    def test_pinned_original_contexts_and_guarded_sound_interpretation(self):
        from .iiif_pins import CONTEXT_REFERENCES
        self.assertEqual(len(CONTEXT_REFERENCES), 8)
        self.assertIn(CONTEXT, CONTEXT_REFERENCES["http://iiif.io/api/image/3/context.json"])
        for uri in (CONTEXT, ANNO_CONTEXT):
            raw = self.iiif.documents.load(uri); original = self.iiif.documents.jsonld_loader(uri)["document"]
            self.assertNotIn("Sound", original["@context"])
            checked = check_original_context(uri, raw, original)
            self.assertEqual(checked, original)
            self.assertEqual(self.iiif.contexts[SOUND_CONTEXT]["@context"]["Sound"], "http://purl.org/dc/dcmitype/Sound")
            self.assertNotIn("Sound", original["@context"])
            for mutation in (lambda d: d["@context"].update(Sound="dctypes:Sound"), lambda d: d["@context"].update(Audio="wrong")):
                d = copy.deepcopy(original); mutation(d)
                with self.assertRaisesRegex(MuseumError, "differs"): check_original_context(uri, raw, d)
            with self.assertRaisesRegex(MuseumError, "hash"): check_original_context(uri, raw + b" ", original)
        with self.assertRaisesRegex(MuseumError, "unavailable"): self.iiif.loader("https://evil.example/context")

    def test_http_identifier_full_consumption_and_fragment_policy(self):
        for good in ("http://example.org/c", "https://example.org/c?a=1"):
            self.assertEqual(http_id(good), good)
        for bad in ("https://example.org/c\n", "https://example.org/c#x", "urn:canvas", "https://u:p@example.org/c",
                    "https://example.org:bad/c", "https://example.org/é", "https://example.org/%zz"):
            with self.subTest(bad=bad), self.assertRaises(MuseumError): http_id(bad)

    def test_policy_42k_positive_and_separate_policy_record_bounds(self):
        from .semantic_selection import select_canonical_fixture
        data = source_data(); raw = dumps(data[1])
        self.assertGreater(len(raw), 24576)
        self.assertLessEqual(len(raw), 524288)
        self.assertTrue(all(len(r.payload) <= 24576 for r in data[0].records))
        self.assertEqual(len(loads(self.run_projection(data).correspondence)), 4)
        too_large = dumps({"padding": "x" * 524288})
        with self.assertRaisesRegex(MuseumError, "byte limit"):
            select_canonical_fixture(data[0], too_large, policy_hash=keccak256(too_large), profile_hash=H)
        record0 = data[0].records[0]; payload = dumps(loads(record0.payload) | {"extra": "x" * 24576})
        with self.assertRaisesRegex(MuseumError, "byte limit"):
            replace(record0, payload=payload, payload_hash=keccak256(payload))

    def test_label_language_and_work_relationship_are_read_from_original_evidence(self):
        data = source_data(); doc = source_document(data)
        doc["entities"][1]["names"][0]["language"] = "en"
        with self.assertRaisesRegex(MuseumError, "specified-language"):
            self.run_projection(source_data(doc["assertions"], doc["entities"]))
        doc["entities"][1]["names"][0]["language"] = None
        result = self.run_projection(source_data(doc["assertions"], doc["entities"]))
        self.assertEqual(target_loads(result.manifest)["items"][0]["label"], {"none": ["photo exact title"]})
        claim = next(c for c in doc["assertions"] if c["subject"] == "urn:fixture:photo" and c["relation"] == FIELDS["presentation-of"])
        claim["object"]["entity"] = "urn:fixture:transcript"
        with self.assertRaisesRegex(MuseumError, "selected presentation work"):
            self.run_projection(source_data(doc["assertions"], doc["entities"]))

    def test_dependency_tamper_named_supplement_and_fresh_context_cache(self):
        import tempfile
        import shutil
        from pyld import jsonld
        raw = self.run_projection().manifest
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); shutil.copytree(ROOT / "iiif", root / "iiif")
            file = root / "iiif/sound-context.json"; original = file.read_bytes()
            file.write_bytes(original.replace(b"dcmitype/Sound", b"dcmitype/Text"))
            with self.assertRaisesRegex(MuseumError, "supplement mismatch"): PinnedIIIF(root, PROFILE_BYTES, profile_hash=PROFILE_HASH)
            file.write_bytes(original)
            index = loads((root / "iiif/dependency-index.json").read_bytes())
            path = root / index["documents"][0]["chunks"][0]["path"]
            path.write_bytes(path.read_bytes() + b" ")
            with self.assertRaises(MuseumError): PinnedIIIF(root, PROFILE_BYTES, profile_hash=PROFILE_HASH)
        # A prior processor can see a hostile document at the same URI. This
        # operation still loads the exact pinned bytes in its own resolver.
        def hostile(uri, options=None):
            value = self.iiif.loader(uri, options)
            if uri == SOUND_CONTEXT: value["document"]["@context"]["Sound"] = "http://example.org/FalseSound"
            return value
        candidate = target_loads(raw)
        bad = jsonld.expand(candidate, {"documentLoader": hostile, "base": ""})
        self.assertIn("http://example.org/FalseSound", repr(bad))
        _, good = self.iiif.validate(raw)
        self.assertNotIn("http://example.org/FalseSound", repr(good))
        self.assertIn("http://purl.org/dc/dcmitype/Sound", repr(good))

    def test_arweave_claim_and_premis_fixity_provenance_are_distinct(self):
        data = source_data(); uri = "ar://" + base64.urlsafe_b64encode(bytes(range(32))).decode().rstrip("=")
        data = updated(data, "photo", "content-uri", uri)
        result = self.run_projection(data); row0 = loads(result.correspondence)[0]
        self.assertIsNone(row0["contentUriEvidence"]["rawDigestAgreement"])
        self.assertFalse(row0["contentUriEvidence"]["bytesRetrieved"])
        m = target_loads(result.manifest)
        body = m["items"][0]["items"][0]["items"][0]["body"]
        self.assertEqual(body["id"], uri)
        proof = loads(result.provenance, maximum=67108864)
        digest_rows = [p for p in proof if p["entity"] == "urn:fixture:photo" and p["targetPointer"].endswith(DIGEST + "/@value")]
        self.assertEqual(len(digest_rows), 1)
        source = next(r for r in data[0].records if r.selector.record_hash == digest_rows[0]["source"]["recordHash"])
        value = loads(source.payload)
        for segment in digest_rows[0]["sourcePointer"].strip("/").split("/"):
            value = value[int(segment)] if isinstance(value, list) else value[segment]
        self.assertEqual(value, body[DIGEST]["@value"])
        self.assertEqual(digest_rows[0]["issuer"], "urn:fixture:artist")

    def test_static_four_media_example_has_readable_originals_and_exact_recompute(self):
        from .package import fixture_state_from_bytes
        path = ROOT / "iiif/example"
        state = fixture_state_from_bytes((path / "source-state.json").read_bytes())
        for i, r in enumerate(state.records): self.assertEqual(r.payload, (path / ("assertion-" + str(i) + ".json")).read_bytes())
        p, plan, pp, ip = [(path / name).read_bytes() for name in
            ("selection-policy.json", "linked-art-plan.json", "premis-plan.json", "iiif-plan.json")]
        kwargs = {"selection_hash": keccak256(p), "plan_hash": keccak256(plan), "premis_plan_hash": keccak256(pp),
            "iiif_plan_hash": keccak256(ip), "profile_hash": H, "linked_art_profile": self.linked,
            "premis_profile": self.premis, "iiif_profile": self.iiif}
        result = project_iiif_fixture(state, p, plan, pp, ip, **kwargs)
        self.assertEqual(len(loads(result.correspondence)), 4)
        self.assertEqual(verify_iiif_fixture(result, state, p, plan, pp, ip, **kwargs)["iiifProfileHash"], PROFILE_HASH)

    def test_manifest_json_license_requires_its_own_fact_and_work_conflicts_do_not_veto(self):
        data = source_data(); doc = source_document(data)
        # Literal relation and datatype IRIs intentionally do not come from the implementation catalog.
        manifest_rights = next(c for c in doc["assertions"] if c["relation"] == "urn:6529stream:museum:iiif-p3:v1:manifest-rights")
        underlying = copy.deepcopy(manifest_rights)
        underlying.update(id="urn:fixture:underlying-work-rights", relation="urn:6529stream:museum:iiif-p3:v1:rights")
        underlying["object"]["literal"] = {"lexicalValue": "http://rightsstatements.org/vocab/InC/1.0/",
            "datatype": "http://www.w3.org/2001/XMLSchema#anyURI", "language": None, "unit": None, "precision": None}
        claims = [c for c in doc["assertions"] if c is not manifest_rights] + [underlying]
        with self.assertRaisesRegex(MuseumError, "missing admitted fact.*manifest-rights"):
            self.run_projection(source_data(claims, doc["entities"]))
        claims.append(manifest_rights)
        disputed = copy.deepcopy(underlying); disputed["id"] += ":other"
        disputed["object"]["literal"]["lexicalValue"] = "http://creativecommons.org/publicdomain/zero/1.0/"
        claims.append(disputed)
        for number in ("1", "2"):
            claims.append(assertion("unused-work-width-" + number, "work", "urn:6529stream:museum:iiif-p3:v1:width",
                literal(number, datatype="http://www.w3.org/2001/XMLSchema#positiveInteger", unit="px")))
        result = self.run_projection(source_data(claims, doc["entities"]))
        m = target_loads(result.manifest)
        self.assertEqual(m["rights"], "http://creativecommons.org/licenses/by/4.0/")
        self.assertTrue(all(c["items"][0]["items"][0]["body"]["rights"] == "http://rightsstatements.org/vocab/InC/1.0/" for c in m["items"]))
        sidecar = loads(result.premis.linked_art.sidecar, maximum=67108864)
        self.assertEqual(len(sidecar["withheldClaims"]), 4)
        # The corresponding file-level conflict affects a used field and must reject.
        file_conflict = copy.deepcopy(underlying); file_conflict["id"] += ":file"; file_conflict["subject"] = "urn:fixture:photo"
        file_conflict["object"]["literal"]["lexicalValue"] = "http://creativecommons.org/publicdomain/zero/1.0/"
        with self.assertRaisesRegex(MuseumError, "conflicting selected facts"):
            self.run_projection(source_data(claims + [file_conflict], doc["entities"]))

    def test_thirteen_long_identity_files_preserve_large_plan_and_generated_report_bounds(self):
        from .source import FixtureSourceAdapter
        from .test_schema_inventory import assertion_document
        from .premis import FIELDS as PF
        doc = source_document(source_data())
        work_claims = [c for c in doc["assertions"] if c["subject"] == "urn:fixture:work" and c["relation"] in FIELDS.values()]
        data = fixture_v2(entities=[doc["entities"][0]], assertions=work_claims)
        records = [data[0].records[0]]
        ids = []
        for i in range(13):
            prefix = "urn:fixture:long-file:" + str(i).zfill(2) + ":"
            identifier = prefix + "x" * (2048 - len(prefix))
            self.assertEqual(len(identifier), 2048)
            ids.append(identifier)
            # All long identifiers occur in actual source facts, not padding.
            claims = [copy.deepcopy(c) for c in doc["assertions"] if c["subject"] == "urn:fixture:audio" and c["relation"] in set(FIELDS.values()) | set(PF.values())]
            for j, c in enumerate(claims):
                c.update(subject=identifier, id=f"urn:fixture:long-claim:{i}:{j}")
            for offset in range(0, len(claims), 4):
                raw_doc = assertion_document()
                raw_doc.update(entities=[entity(identifier, "digital_object", [{"value": "Long file " + str(i), "kind": "preferred", "language": None}])] if offset == 0 else [],
                               assertions=claims[offset:offset+4])
                r = record(raw_doc, f"long-file-{i}-{offset}", "urn:fixture:artist", "artist", [str(2 + i * 4 + offset), "0", "0"])
                records.append(r)
                data[1]["sourceAuthoritySet"].extend(row(r) | {"pointer": f"/assertions/{j}"} for j in range(len(raw_doc["assertions"])))
                if offset == 0: data[2]["entityAuthoritySet"].append(row(r) | {"pointer": "/entities/0"})
        state = FixtureSourceAdapter("iiif-large-output", tuple(records)).snapshot()
        policy, plan = data[1], data[2]
        policy["sourceStateHash"] = state.commitment
        policy["singleValuedRelations"].extend(list(PF.values()) + list(FIELDS.values()))
        plan.update(sourceStateHash=state.commitment, selectionPolicyHash=keccak256(dumps(policy)))
        args, kwargs = premis_arguments((state, policy, plan), self.linked, self.premis, ids)
        self.assertGreater(len(args[-1]), 24576)
        self.assertTrue(all(len(r.payload) <= 24576 for r in records))
        ip = {"mode": "synthetic_iiif_projection", "version": "1", "sourceStateHash": state.commitment,
            "profileHash": H, "linkedArtPlanHash": kwargs["plan_hash"], "premisPlanHash": kwargs["premis_plan_hash"],
            "iiifProfileHash": PROFILE_HASH, "work": "urn:fixture:work", "manifestId": "https://example.org/large/manifest",
            "canvases": [{"file": file, "canvasId": f"https://example.org/large/c/{i}", "pageId": f"https://example.org/large/p/{i}",
                          "annotationId": f"https://example.org/large/a/{i}"} for i, file in enumerate(ids)]}
        ip_raw = dumps(ip)
        result = project_iiif_fixture(*args, ip_raw, **(kwargs | {"iiif_plan_hash": keccak256(ip_raw), "iiif_profile": self.iiif}))
        self.assertGreater(len(result.premis.correspondence), 24576)
        self.assertGreater(len(result.premis.provenance), 24576)
        self.assertEqual([r["linkedArtId"] for r in loads(result.correspondence, maximum=67108864)], ids)
        self.assertEqual(len(target_loads(result.manifest)["items"]), 13)

    def test_valid_content_address_cannot_alias_work_or_conflicting_file_interpretations(self):
        data = source_data(); doc = source_document(data)
        uri = next(c["object"]["literal"]["lexicalValue"] for c in doc["assertions"] if c["subject"] == "urn:fixture:photo" and c["relation"] == FIELDS["content-uri"])
        for e in doc["entities"]:
            if e["id"] == "urn:fixture:work": e["id"] = uri
        for c in doc["assertions"]:
            if c["subject"] == "urn:fixture:work": c["subject"] = uri
            if c["object"].get("entity") == "urn:fixture:work": c["object"]["entity"] = uri
        changed = source_data(doc["assertions"], doc["entities"])
        args, kwargs = arguments(changed, self.linked, self.premis, self.iiif)
        plan = loads(args[-1]); plan["work"] = uri; ip = dumps(plan)
        with self.assertRaisesRegex(MuseumError, "content URI collides"):
            project_iiif_fixture(*args[:-1], ip, **(kwargs | {"iiif_plan_hash": keccak256(ip)}))
        # Both URI/digest claims are individually valid, but one URI cannot be
        # presented as two contradictory resources in the same expanded graph.
        doc = source_document(source_data())
        from .premis import FIELDS as PF
        for field in (FIELDS["content-uri"], PF["digest"]):
            audio_value = next(c["object"] for c in doc["assertions"] if c["subject"] == "urn:fixture:audio" and c["relation"] == field)
            next(c for c in doc["assertions"] if c["subject"] == "urn:fixture:photo" and c["relation"] == field)["object"] = copy.deepcopy(audio_value)
        with self.assertRaisesRegex(MuseumError, "repeated content URI"):
            self.run_projection(source_data(doc["assertions"], doc["entities"]))


    def test_structural_ids_cannot_alias_external_or_extension_entities(self):
        external_id = "https://example.org/source/external-person"
        extension_id = "https://example.org/source/nonlinguistic-content"
        doc = source_document(source_data())
        for e in doc["entities"]:
            if e["id"] == "urn:fixture:sound-content": e["id"] = extension_id
        for claim in doc["assertions"]:
            if claim["subject"] == "urn:fixture:sound-content": claim["subject"] = extension_id
            if claim["object"].get("entity") == "urn:fixture:sound-content": claim["object"]["entity"] = extension_id
        data = source_data(doc["assertions"], doc["entities"])
        data[2]["externalEntities"].append({"id": external_id, "kind": "person"})
        args, kwargs = arguments(data, self.linked, self.premis, self.iiif)
        healthy = project_iiif_fixture(*args, **kwargs)
        sidecar = loads(healthy.premis.linked_art.sidecar, maximum=67108864)
        self.assertIn(external_id, {e["id"] for e in sidecar["externalEntities"]})
        self.assertIn(extension_id, {e["id"] for e in sidecar["extensionEntities"]})
        self.assertNotIn(extension_id, {r.identifier for r in healthy.premis.linked_art.resources})
        for field, identifier in (("manifestId", external_id), ("canvasId", extension_id),
                                  ("pageId", external_id), ("annotationId", extension_id)):
            plan = loads(args[-1])
            if field == "manifestId": plan[field] = identifier
            else: plan["canvases"][0][field] = identifier
            raw = dumps(plan)
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "target identities must remain distinct"):
                project_iiif_fixture(*args[:-1], raw, **(kwargs | {"iiif_plan_hash": keccak256(raw)}))

if __name__ == "__main__":
    unittest.main()
