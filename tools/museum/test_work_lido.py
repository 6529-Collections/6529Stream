"""Independent lexical/XML/source-accounting controls for the bounded WORK mapper."""

import copy
import dataclasses
import unittest
from pathlib import Path

from lxml import etree

from tools.metadata import work_profile as work
from .canonical import MuseumError, dumps, keccak256, loads
from .lido_model import PinnedLIDO, PROFILE_BYTES as OLD_PROFILE, PROFILE_HASH as OLD_HASH
from .work_lido import project_work_lido_fixture, verify_work_lido_fixture
from .work_lido_context import PROFILE_BYTES, PROFILE_HASH
from .work_lido_fixture import examples, fixture_context, outputs

ROOT = Path(__file__).resolve().parents[2]
NS = {"lido": "http://www.lido-schema.org", "xml": "http://www.w3.org/XML/1998/namespace"}


class WorkLidoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = PinnedLIDO(ROOT / "schemas/museum", OLD_PROFILE, profile_hash=OLD_HASH)

    def setUp(self):
        self.fixtures = examples()

    def args(self, name="complete", *, value=None, context=None, catalog=None):
        original, ctx, cat = copy.deepcopy(self.fixtures[name])
        value = original if value is None else value
        if context is None:
            context = ctx if value == original else fixture_context(value)
        if catalog is None:
            catalog = cat
        raw, supplement = dumps(value), dumps(context)
        return (raw, supplement), {"expected_subject_id": value["subjectId"], "context_hash": keccak256(supplement),
            "catalog_bytes": None if catalog is None else dumps(catalog), "lido_schema": self.model,
            "profile_bytes": PROFILE_BYTES, "profile_hash": PROFILE_HASH}

    def project(self, name="complete", **kw):
        args, kwargs = self.args(name, **kw)
        return project_work_lido_fixture(*args, **kwargs)

    def xml(self, result):
        return etree.fromstring(result.xml)

    def texts(self, root, path):
        return root.xpath(path + "/text()", namespaces=NS)

    def reject(self, name="complete", **kw):
        with self.assertRaises(MuseumError):
            self.project(name, **kw)

    def test_simple_has_exact_title_creator_date_medium_edition_credit_without_resources(self):
        result = self.project("simple"); root = self.xml(result)
        for tag, expected in (("appellationValue", "Exact work title"), ("earliestDate", "2024-02-29"),
                              ("latestDate", "2024-02-29"), ("displayMaterialsTech", "Generative instructions"),
                              ("displayEdition", "unique"), ("creditLine", "Authored credit")):
            self.assertIn(expected, self.texts(root, "//lido:" + tag))
        self.assertIn("Declared creator", self.texts(root, "//lido:actor/lido:nameActorSet/lido:appellationValue"))
        self.assertFalse(root.xpath("//lido:resourceWrap | //lido:rightsType", namespaces=NS))
        self.assertFalse(any(loads(result.report)["claims"].values()))

    def test_complete_preserves_exact_large_serial_dates_and_fraction_displays(self):
        result = self.project(); root = self.xml(result)
        maximum = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        prior = "115792089237316195423570985008687907853269984665640564039457584007913129639934"
        self.assertEqual(self.texts(root, "//lido:displayEdition"), [prior + " / " + maximum])
        self.assertEqual(self.texts(root, "//lido:earliestDate"), ["0001-01-01"])
        self.assertEqual(self.texts(root, "//lido:latestDate"), ["2026-09-12"])
        self.assertEqual(self.texts(root, "//lido:displayObjectMeasurements"), ["aspect ratio: 2/4", "duration in seconds: " + prior + "/" + maximum])
        self.assertEqual(self.texts(root, "//lido:measurementValue"), ["3840", "2160"])
        self.assertEqual(self.texts(root, "//lido:measurementUnit"), ["pixels", "pixels"])

    def test_every_final_xpath_matches_original_source_pointer_and_exact_serialized_value(self):
        result = self.project(); root = self.xml(result)
        source = {r["name"]: bytes.fromhex(r["originalHex"][2:]) for r in loads(result.sidecar, maximum=4194304)["sources"]}
        paths = set()
        for row in loads(result.provenance, maximum=4194304):
            found = root.xpath(row["targetXPath"], namespaces=NS)
            self.assertEqual(len(found), 1)
            self.assertEqual(found[0].text if isinstance(found[0], etree._Element) else str(found[0]), row["targetValue"])
            paths.add(row["targetXPath"])
            for ref in row["sources"]:
                raw = source[ref["source"]]
                self.assertEqual(keccak256(raw), ref["sourceHash"])
                value = loads(raw, maximum=32768)
                for key in ref["pointer"][1:].split("/"):
                    key = key.replace("~1", "/").replace("~0", "~")
                    value = value[int(key)] if isinstance(value, list) else value[key]
                self.assertEqual("0x" + dumps(value).hex(), ref["exactHex"])
                if row["rule"] == "exact": self.assertEqual(value, row["targetValue"])
        self.assertGreater(len(paths), 50)
        self.assertTrue(any("titleSet[3]" in p for p in paths))
        self.assertTrue(any("actorID[4]" in p for p in paths))

    def test_all_work_catalog_context_nodes_and_absent_optionals_remain_accounted(self):
        result = self.project(); rows = loads(result.coverage, maximum=4194304)["fields"]
        by = {(r["source"], r["pointer"]): r for r in rows}
        self.assertEqual(len(by), len(rows))
        def visit(value, source, path=""):
            self.assertIn((source, path), by)
            if isinstance(value, dict):
                for k, v in value.items(): visit(v, source, path + "/" + k)
            elif isinstance(value, list):
                for i, v in enumerate(value): visit(v, source, path + "/" + str(i))
            else: self.assertEqual(by[source, path]["exactHex"], "0x" + dumps(value).hex())
        for r in loads(result.sidecar, maximum=4194304)["sources"]:
            visit(loads(bytes.fromhex(r["originalHex"][2:]), maximum=32768), r["name"])
        self.assertEqual(by["catalog", "/entries/0/mapping/puid"]["disposition"], "retained")
        self.assertEqual(by["work", "/creator/association/bindingHash"]["disposition"], "retained")
        simple = loads(self.project("simple").coverage, maximum=4194304)["fields"]
        self.assertEqual([r["presence"] for r in simple if r["source"] == "work" and r["pointer"] == "/inscription"], ["absent"])

    def test_absence_with_independent_work_label_type_is_still_absence(self):
        result = self.project("absent"); root = self.xml(result)
        self.assertEqual(loads(result.report)["sourceForm"], "description_absent")
        self.assertEqual(self.texts(root, "//lido:titleSet[@lido:type='catalogue-work-label']/lido:appellationValue"), ["Catalogue label for this work"])
        self.assertEqual(self.texts(root, "//lido:objectDescriptionSet[@lido:type='description-absence-reason']/lido:descriptiveNoteValue"), ["An explicit authored absence."])
        self.assertEqual(self.texts(root, "//lido:objectDescriptionSet[@lido:type='description-absence-date']/lido:descriptiveNoteValue"), ["2026-09-12"])
        self.assertFalse(root.xpath("//lido:eventWrap | //lido:creditLine | //lido:displayEdition | //lido:objectMaterialsTechWrap", namespaces=NS))

    def test_each_missing_absence_context_returns_no_xml_with_complete_original_bytes(self):
        value, ctx, _ = self.fixtures["absent"]
        for kind in ("workLabel", "objectWorkType", "documentLanguage", "exportPublisher"):
            missing = copy.deepcopy(ctx); missing["statements"] = [r for r in missing["statements"] if r["kind"] != kind]
            result = self.project("absent", context=missing)
            self.assertIsNone(result.xml)
            self.assertEqual(loads(result.report)["missingContext"], [kind])
            self.assertEqual(loads(result.provenance), [])
            self.assertTrue(all(r["disposition"] == "retained" for r in loads(result.coverage, maximum=4194304)["fields"]))
        self.assertIsNone(self.project("absent-no-xml").xml)

    def test_full_never_falls_back_to_absence_when_context_is_missing(self):
        _, ctx, _ = self.fixtures["complete"]
        for kind in ("objectWorkType", "documentLanguage", "exportPublisher", "artistName"):
            missing = copy.deepcopy(ctx); missing["statements"] = [r for r in missing["statements"] if r["kind"] != kind]
            self.reject(context=missing)

    def test_artist_name_binds_all_three_original_association_words(self):
        _, ctx, _ = self.fixtures["complete"]
        for field in ("artistId", "bindingGeneration", "bindingHash"):
            wrong = copy.deepcopy(ctx); name = next(r for r in wrong["statements"] if r["kind"] == "artistName")
            if field == "artistId": name[field] = "0x" + "9" * 64
            else: name["association"][field] = "1" if field == "bindingGeneration" else "0x" + "9" * 64
            self.reject(context=wrong)
        self.assertIn(b"Declared artist display name", self.project().xml)

    def test_unused_creator_label_and_absent_artist_statements_reject(self):
        _, ctx, _ = self.fixtures["complete"]
        artist = copy.deepcopy(next(r for r in ctx["statements"] if r["kind"] == "artistName"))
        for name in ("simple", "absent"):
            context = copy.deepcopy(self.fixtures[name][1]); context["statements"].append(artist)
            self.reject(name, context=context)
        context = copy.deepcopy(self.fixtures["simple"][1])
        context["statements"].append(copy.deepcopy(self.fixtures["absent"][1]["statements"][-1]))
        self.reject("simple", context=context)

    def test_duplicate_conflicting_unknown_and_inactive_context_fields_reject(self):
        for mutation in ("duplicate", "conflict", "unknown", "inactive", "record-label"):
            ctx = copy.deepcopy(self.fixtures["absent"][1])
            if mutation in ("duplicate", "conflict"):
                row = copy.deepcopy(ctx["statements"][0]); row["value"] = "fr" if mutation == "conflict" else row["value"]
                ctx["statements"].append(row)
            elif mutation == "unknown": ctx["authorityVerified"] = True
            elif mutation == "inactive": ctx["statements"][0]["language"] = "en"
            else: ctx["statements"][-1]["target"] = "export-record"
            self.reject("absent", context=ctx)

    def test_hash_subject_profile_and_rehashed_wrong_source_bindings_reject(self):
        args, kwargs = self.args()
        for field in ("context_hash", "profile_hash", "expected_subject_id"):
            bad = {**kwargs, field: "0x" + "9" * 64}
            with self.assertRaises(MuseumError): project_work_lido_fixture(*args, **bad)
        for field in ("workPayloadHash", "subjectId"):
            ctx = copy.deepcopy(self.fixtures["complete"][1]); ctx[field] = "0x" + "9" * 64
            self.reject(context=ctx)
        with self.assertRaises(MuseumError): project_work_lido_fixture(*args, **{**kwargs, "profile_bytes": PROFILE_BYTES + b" "})

    def test_work_record_source_author_and_export_publisher_identities_cannot_merge(self):
        _, context, _ = self.fixtures["simple"]
        for field in ("workId", "recordId"):
            ctx = copy.deepcopy(context); ctx[field] = ctx["sourceDeclaration"]["id"]
            self.reject("simple", context=ctx)
        for field in ("authorId", "id"):
            ctx = copy.deepcopy(context); ctx["statements"][2][field] = ctx["workId"]
            self.reject("simple", context=ctx)

    def test_explicit_language_and_each_variant_keep_exact_case_and_target(self):
        result = self.project(); root = self.xml(result)
        expected = [("Titre", "fr"), ("Medij", "sr-Latn-RS"), ("Credit", "und"), ("Inscripción", "es-419"), ("Autre", "FR")]
        for value, language in expected:
            self.assertTrue(root.xpath("//*[@xml:lang=$language and text()=$value]", namespaces=NS, language=language, value=value))
        self.assertEqual(self.texts(root, "//lido:titleSet[3]/lido:appellationValue"), ["Titre", "Autre"])
        ctx = copy.deepcopy(self.fixtures["simple"][1])
        for invalid in ("", "und\n", "en-US-extra", None):
            ctx["statements"][0]["value"] = invalid
            self.reject("simple", context=ctx)

    def test_named_creator_language_variant_is_not_a_second_creator(self):
        value = copy.deepcopy(self.fixtures["simple"][0])
        value["languageVariants"] = [{"field": "creatorName", "language": "fr", "value": "Créateur déclaré"}]
        root = self.xml(self.project("simple", value=value))
        self.assertEqual(len(root.xpath("//lido:actor", namespaces=NS)), 1)
        self.assertEqual(self.texts(root, "//lido:nameActorSet/lido:appellationValue"), ["Declared creator", "Créateur déclaré"])

    def test_ordered_repeated_titles_authorities_and_variants_remain_distinct(self):
        value = copy.deepcopy(self.fixtures["complete"][0])
        value["authorityReferences"] = list(reversed(value["authorityReferences"]))
        value["alternateTitles"] = ["Second", "First", "Second"]
        result = self.project(value=value); root = self.xml(result)
        self.assertEqual(self.texts(root, "//lido:titleSet/lido:appellationValue[1]")[1:], value["alternateTitles"])
        ids = self.texts(root, "//lido:actorID")
        self.assertEqual(ids[1:], [r["identifier"] for r in value["authorityReferences"] if r["role"] == "creator"])
        refs = loads(result.provenance, maximum=4194304)
        self.assertTrue(any(s["pointer"] == "/alternateTitles/2" for r in refs for s in r["sources"]))

    def test_all_seven_nonempty_measurement_combinations_preserve_exact_quantities(self):
        for mask in range(1, 8):
            value = copy.deepcopy(self.fixtures["simple"][0]); full = self.fixtures["complete"][0]["measurements"]
            value["measurements"] = {"kind": "measured", **{k: copy.deepcopy(full[k]) for i, k in enumerate(("pixels", "aspectRatio", "durationSeconds")) if mask & (1 << i)}}
            root = self.xml(self.project("simple", value=value))
            self.assertEqual(len(root.xpath("//lido:measurementValue", namespaces=NS)), 2 if mask & 1 else 0)
            self.assertEqual(len(root.xpath("//lido:displayObjectMeasurements", namespaces=NS)), bool(mask & 2) + bool(mask & 4))

    def test_open_edition_and_direct_pronom_are_authored_not_inferred_license_or_media(self):
        value = copy.deepcopy(self.fixtures["simple"][0])
        value["edition"] = {"kind": "open_series", "statement": "Open under the author's stated terms\r\n"}
        value["format"] = {"kind": "pronom", "puid": "x-fmt/42", "formatId": keccak256(b"PRONOM:x-fmt/42")}
        root = self.xml(self.project("simple", value=value))
        self.assertEqual(self.texts(root, "//lido:displayEdition"), [value["edition"]["statement"]])
        self.assertEqual(self.texts(root, "//lido:objectDescriptionSet[@lido:type='PRONOM-PUID']/lido:descriptiveNoteValue"), ["x-fmt/42"])
        self.assertFalse(root.xpath("//lido:resourceWrap | //lido:rightsType", namespaces=NS))

    def test_catalog_selected_mapping_and_all_unselected_entries_are_retained(self):
        value, _, catalog = copy.deepcopy(self.fixtures["complete"])
        value["format"]["formatId"] = catalog["entries"][0]["entryId"]
        value["format"]["mapping"] = copy.deepcopy(catalog["entries"][0]["mapping"])
        result = self.project(value=value)
        self.assertIn(b"fmt/199", result.xml)
        self.assertNotIn(b"ipfs://format-specification", result.xml)
        sources = {r["name"]: bytes.fromhex(r["originalHex"][2:]) for r in loads(result.sidecar, maximum=4194304)["sources"]}
        self.assertEqual(sources["catalog"], dumps(catalog))
        bad = copy.deepcopy(catalog); bad["entries"][1]["mapping"]["specification"]["uri"] = "ipfs://changed"
        self.reject(value=value, catalog=bad)

    def test_xml_roundtrip_preserves_cr_lf_entities_quotes_astral_and_combining_text(self):
        value = copy.deepcopy(self.fixtures["simple"][0])
        exact = 'CR\rLF\nCRLF\r\n<>& literal &amp; " \' 🎨 é'
        for field in ("title", "medium", "creditLine", "inscription"):
            value[field] = exact
        root = self.xml(self.project("simple", value=value))
        for path in ("//lido:titleSet/lido:appellationValue", "//lido:displayMaterialsTech", "//lido:creditLine", "//lido:inscriptionDescription/lido:descriptiveNoteValue"):
            self.assertEqual(self.texts(root, path), [exact])

    def test_valid_work_json_with_illegal_xml_characters_rejects_without_sanitizing(self):
        for char in ("\x00", "\x01", "\x0b", "\ufffe"):
            value = copy.deepcopy(self.fixtures["simple"][0]); value["title"] = "original" + char
            work.validate_payload(dumps(value))
            self.reject("simple", value=value)
        value, _, _ = self.fixtures["complete"]
        value["title"] = work.examples()[2]["title"]
        self.reject(value=value)

    def test_full_payload_and_whole_catalog_validation_precede_mapping(self):
        for mutate in ("unknown", "date", "inactive", "edition", "variant"):
            v = copy.deepcopy(self.fixtures["simple"][0])
            if mutate == "unknown": v["silentlyIgnore"] = "no"
            elif mutate == "date": v["creation"]["date"] = "2023-02-29"
            elif mutate == "inactive": v["edition"]["total"] = "9"
            elif mutate == "edition": v["edition"] = {"kind": "serial", "number": "2", "total": "1"}
            else: v["languageVariants"] = [{"field": "inscription", "language": "en", "value": "missing"}]
            self.reject("simple", value=v)

    def test_source_and_context_canonical_json_bounds_and_exact_scalar_types(self):
        args, kwargs = self.args("simple")
        for raw in (args[1] + b" ", args[1].replace(b'"version":"1"', b'"version":true'), b"{" + args[1][1:-1] + b',"mode":"public_fixture_work_lido"}'):
            with self.assertRaises(MuseumError):
                project_work_lido_fixture(args[0], raw, **{**kwargs, "context_hash": keccak256(raw)})
        ctx = copy.deepcopy(self.fixtures["simple"][1]); ctx["statements"][1]["value"] = "🎨" * 1024
        self.reject("simple", context=ctx)
        with self.assertRaises(MuseumError): project_work_lido_fixture(args[0], b" " * 32769, **{**kwargs, "context_hash": keccak256(b" " * 32769)})

    def test_original_xsd_rejects_missing_mandatory_work_type_and_invalid_reordered_record(self):
        root = self.xml(self.project("simple"))
        node = root.xpath("//lido:objectWorkTypeWrap", namespaces=NS)[0]; node.getparent().remove(node)
        with self.assertRaises(MuseumError): self.model.validate(etree.tostring(root))
        root = self.xml(self.project("simple")); wrap = root.xpath("//lido:recordWrap", namespaces=NS)[0]
        wrap.insert(0, wrap[-1])
        with self.assertRaises(MuseumError): self.model.validate(etree.tostring(root))

    def test_output_verifier_recomputes_every_component_and_rejects_mutated_xml_or_sidecars(self):
        args, kwargs = self.args("simple"); good = project_work_lido_fixture(*args, **kwargs)
        self.assertEqual(verify_work_lido_fixture(good, *args, **kwargs)["outcome"], "lido_xml")
        for field in ("xml", "sidecar", "coverage", "provenance", "report"):
            altered = dataclasses.replace(good, **{field: getattr(good, field) + b" "})
            with self.assertRaises(MuseumError): verify_work_lido_fixture(altered, *args, **kwargs)

    def test_generated_profile_and_all_public_example_bytes_are_exact(self):
        expected = outputs()
        for path, raw in expected.items():
            self.assertEqual((ROOT / "schemas/museum/work-lido" / path).read_bytes(), raw, path)
        self.assertEqual(len(expected), 30)


if __name__ == "__main__":
    unittest.main()
