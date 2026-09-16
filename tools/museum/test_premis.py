"""Same-source PREMIS file/fixity consistency and offline schema controls."""

import copy
from dataclasses import replace
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads
from .premis import (FIELDS, NS, PREFIX, PROFILE_BYTES, PROFILE_HASH, SCHEMA_SHA256, SCHEMA_URI,
                     PinnedPremis, project_premis_fixture, verify_premis_fixture)
from .projection_v2 import CROSSWALK_V2_BYTES, CROSSWALK_V2_HASH, ProjectionProfileV2
from .source import FixtureSourceAdapter
from .test_projection import entity
from .test_projection_v2 import assertion, fixture_v2, literal
from .test_review import H, record, row

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
DIGEST = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"


def facts(subject="master", **updates):
    values = {"category": "file", "size": "3", "digest": DIGEST, "puid": "fmt/1"} | updates
    return [assertion(subject + "-" + field, subject, relation,
        literal(values[field], datatype="http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
                if field == "size" else "http://www.w3.org/2001/XMLSchema#string"))
        for field, relation in FIELDS.items()]


def data_for(claims=None, *, entities=None, extra=()):
    data = fixture_v2(entities=entities, assertions=facts() if claims is None else claims, extra=extra)
    data[1]["singleValuedRelations"].extend(FIELDS.values())
    data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
    return data


def arguments(data, linked, premis, objects=("urn:fixture:master",)):
    state, policy, plan = data
    pp = {"mode": "synthetic_premis_file_projection", "version": "1", "sourceStateHash": state.commitment,
          "profileHash": H, "linkedArtPlanHash": keccak256(dumps(plan)), "premisProfileHash": PROFILE_HASH,
          "objects": list(objects)}
    return (state, dumps(policy), dumps(plan), dumps(pp)), {
        "selection_hash": keccak256(dumps(policy)), "plan_hash": keccak256(dumps(plan)),
        "premis_plan_hash": keccak256(dumps(pp)), "profile_hash": H,
        "linked_art_profile": linked, "premis_profile": premis}


class PremisFileProjection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.linked = ProjectionProfileV2(ROOT, CROSSWALK_V2_BYTES, crosswalk_hash=CROSSWALK_V2_HASH,
            validation_hash=keccak256((ROOT / "linked-art-v2/validation-policy.json").read_bytes()),
            vocabulary_hash=keccak256((ROOT / "standards/vocabulary-policy.json").read_bytes()))
        cls.premis = PinnedPremis(ROOT, PROFILE_BYTES, profile_hash=PROFILE_HASH)

    def run_projection(self, data=None, objects=("urn:fixture:master",)):
        args, kwargs = arguments(data_for() if data is None else data, self.linked, self.premis, objects)
        return project_premis_fixture(*args, **kwargs)

    def test_independent_xml_golden_shared_identity_and_original_attribution(self):
        data = data_for()
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            result = self.run_projection(data)
        expected = ('<?xml version=\'1.0\' encoding=\'UTF-8\'?>\n'
            '<premis:premis xmlns:premis="http://www.loc.gov/premis/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.0">'
            '<premis:object xsi:type="premis:file"><premis:objectIdentifier><premis:objectIdentifierType>URI</premis:objectIdentifierType>'
            '<premis:objectIdentifierValue>urn:fixture:master</premis:objectIdentifierValue></premis:objectIdentifier>'
            '<premis:objectCharacteristics><premis:fixity><premis:messageDigestAlgorithm>SHA-256</premis:messageDigestAlgorithm>'
            '<premis:messageDigest>' + DIGEST + '</premis:messageDigest></premis:fixity><premis:size>3</premis:size>'
            '<premis:format><premis:formatRegistry><premis:formatRegistryName>PRONOM</premis:formatRegistryName>'
            '<premis:formatRegistryKey>fmt/1</premis:formatRegistryKey></premis:formatRegistry></premis:format>'
            '</premis:objectCharacteristics></premis:object></premis:premis>').encode()
        self.assertEqual(result.xml, expected)
        self.premis.validate(expected)
        correspondence = loads(result.correspondence)[0]
        self.assertEqual(correspondence["supplementalEntityIri"], "urn:fixture:master")
        self.assertEqual(correspondence["linkedArtId"], "urn:fixture:master")
        self.assertEqual(correspondence["premisIdentifier"], {"type": "URI", "value": "urn:fixture:master"})
        self.assertEqual(correspondence["sourceAnchors"], [H])
        self.assertNotIn(H.encode(), result.xml)
        evidence = loads(result.provenance)
        self.assertEqual({p["issuer"] for p in evidence if "issuer" in p}, {"urn:fixture:artist"})
        self.assertEqual({p["source"]["recordHash"] for p in evidence}, {data[0].records[0].selector.record_hash})
        self.assertNotIn(b"<premis:agent", result.xml)
        self.assertNotIn(b"<premis:event", result.xml)
        self.assertFalse(loads(result.report)["claims"]["bytesFixityVerified"])

    def test_entire_source_inventory_and_exact_unsupported_values_remain(self):
        original = str((1 << 256) - 1) + "\r\ne\u0301 40.00"
        claims = facts() + [assertion("technical", "master", "urn:fixture:unsupported", literal(original, precision="verbatim"))]
        result = self.run_projection(data_for(claims))
        before = loads(result.linked_art.coverage, maximum=67108864)
        after = loads(result.coverage, maximum=67108864)
        self.assertEqual([(r["recordHash"], [(f["pointer"], f["presence"], f["exactHex"]) for f in r["fields"]]) for r in before],
                         [(r["recordHash"], [(f["pointer"], f["presence"], f["exactHex"]) for f in r["fields"]]) for r in after])
        fields = {f["pointer"]: f for f in after[0]["fields"]}
        for i in range(4):
            self.assertEqual(fields[f"/assertions/{i}/object/literal/lexicalValue"]["disposition"], "mapped")
        retained = fields["/assertions/4/object/literal/lexicalValue"]
        self.assertEqual(retained["disposition"], "retained_stream_only")
        self.assertEqual(retained["exactHex"], "0x" + dumps(original).hex())
        self.assertEqual(fields["/assertions/0/object/literal/unit"]["presence"], "present")
        self.assertEqual(fields["/assertions/0/object/literal/unit"]["exactHex"], "0x6e756c6c")
        source = loads(result.linked_art.sidecar, maximum=67108864)["publicSources"][0]
        self.assertEqual(bytes.fromhex(source["payloadHex"][2:]), data_for(claims)[0].records[0].payload)

    def test_size_boundary_and_full_uint256_never_truncate(self):
        for size in ("0", str((1 << 63) - 1)):
            result = self.run_projection(data_for(facts(size=size)))
            self.assertIn(("<premis:size>" + size + "</premis:size>").encode(), result.xml)
        for size in (str(1 << 63), str((1 << 256) - 1), str(1 << 256), "03", "-1"):
            with self.subTest(size=size), self.assertRaises(MuseumError):
                self.run_projection(data_for(facts(size=size)))
        self.assertIn(b"<premis:size>3</premis:size>", self.run_projection().xml)

    def test_invalid_or_qualified_selected_facts_fail_without_coercion(self):
        cases = [facts(category="representation"), facts(digest=DIGEST.upper()), facts(digest="0x" + DIGEST),
                 facts(digest=DIGEST + "\n"), facts(puid="fmt/1\n"), facts(puid="image/tiff"), facts(puid="fmt/0")]
        for field, value in (("language", "en"), ("unit", "bytes"), ("precision", "exact"),
                             ("datatype", "http://www.w3.org/2001/XMLSchema#string")):
            claims = facts(); claims[1]["object"]["literal"][field] = value; cases.append(claims)
        for claims in cases:
            with self.subTest(claims=claims), self.assertRaises(MuseumError):
                self.run_projection(data_for(claims))
        self.run_projection()

    def test_missing_and_conflicting_selected_facts_have_exact_source_diagnostics(self):
        with self.assertRaisesRegex(MuseumError, "missing admitted fact"):
            self.run_projection(data_for(facts()[:-1]))
        extra = assertion("different-size", "master", FIELDS["size"],
                          literal("4", datatype="http://www.w3.org/2001/XMLSchema#nonNegativeInteger"))
        data = data_for(facts() + [extra])
        with self.assertRaisesRegex(MuseumError, "conflicting selected facts") as failure:
            self.run_projection(data)
        self.assertIn(data[0].records[0].selector.record_hash, str(failure.exception))
        self.assertIn('"lexicalValue":"3"', str(failure.exception))
        self.assertIn('"lexicalValue":"4"', str(failure.exception))
        self.run_projection()

    def test_unselected_hostile_record_and_unrelated_selected_claim_cannot_veto(self):
        doc = loads(data_for()[0].records[0].payload)
        doc["assertions"] = facts(size="999")
        hostile = record(doc, "unselected-premis", "urn:fixture:artist", "artist", ["20", "0", "0"])
        baseline = self.run_projection()
        data = data_for(extra=(hostile,))
        self.assertEqual(self.run_projection(data).xml, baseline.xml)
        unrelated = assertion("foreign", "conception", FIELDS["size"], literal("bad"))
        self.assertEqual(self.run_projection(data_for(facts() + [unrelated])).xml, baseline.xml)

    def test_exact_authority_plan_and_review_admission_are_required(self):
        data = data_for()
        data[1]["sourceAuthoritySet"][0]["host"] = "0x" + "33" * 20
        data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
        with self.assertRaisesRegex(MuseumError, "selector"):
            self.run_projection(data)
        claims = facts(); claims[0]["origin"] = "human_mapping"
        with self.assertRaisesRegex(MuseumError, "missing admitted fact"):
            self.run_projection(data_for(claims))
        data = data_for(); data[1]["singleValuedRelations"].remove(FIELDS["size"])
        data[2]["selectionPolicyHash"] = keccak256(dumps(data[1]))
        with self.assertRaisesRegex(MuseumError, "single-valued"):
            self.run_projection(data)
        self.run_projection()

    def test_file_work_token_and_other_carrier_never_collapse(self):
        for target in ("urn:fixture:conception", "urn:fixture:print", H, "urn:fixture:missing"):
            with self.subTest(target=target), self.assertRaisesRegex(MuseumError, "selected Linked Art digital"):
                self.run_projection(objects=(target,))
        for targets in ((), ("urn:fixture:master", "urn:fixture:master")):
            with self.assertRaisesRegex(MuseumError, "object selection"):
                self.run_projection(objects=targets)

    def test_two_files_and_content_correspondence_preserve_separate_entities(self):
        from .projection_v2 import LA
        claims = facts() + facts("display", size="20", digest="ab" * 32, puid="x-fmt/111")
        claims += [assertion("depiction", "master", LA + "digitally_shows", {"entity": "urn:fixture:image"})]
        entities = [entity("urn:fixture:master", "digital_object"), entity("urn:fixture:display", "digital_object"),
                    entity("urn:fixture:image", "visual_content")]
        a = self.run_projection(data_for(claims, entities=entities), ("urn:fixture:master", "urn:fixture:display"))
        b = self.run_projection(data_for(list(reversed(claims)), entities=entities), ("urn:fixture:display", "urn:fixture:master"))
        self.assertEqual(a.xml, b.xml)
        rows = loads(a.correspondence)
        self.assertEqual([r["supplementalEntityIri"] for r in rows], ["urn:fixture:display", "urn:fixture:master"])
        self.assertEqual(rows[1]["contentRelations"]["digitally_shows"], [{"id": "urn:fixture:image", "type": "VisualItem"}])
        self.assertEqual(len(rows[1]["retainedRelations"]), 1)

    def test_equivalent_assertions_preserve_every_claimant_evidence_row(self):
        claims = facts(); duplicate = copy.deepcopy(claims[1]); duplicate["id"] = "urn:fixture:another-size"
        result = self.run_projection(data_for(claims + [duplicate]))
        rows = [p for p in loads(result.provenance) if p["rule"] == PREFIX + "size"]
        self.assertEqual({p["sourcePointer"] for p in rows}, {"/assertions/1/object/literal/lexicalValue", "/assertions/4/object/literal/lexicalValue"})
        self.assertEqual(result.xml, self.run_projection().xml)

    def test_xsd_valid_substitutions_fail_source_consistency_even_with_rehashed_report(self):
        data = data_for(); result = self.run_projection(data)
        mutations = [(b"urn:fixture:master", b"urn:fixture:conception"), (b">3<", b">4<"),
                     (DIGEST.encode(), b"ab" * 32), (b">fmt/1<", b">fmt/2<"),
                     (b">URI<", b">6529STREAM_SUBJECT<"), (b">SHA-256<", b">MD5<")]
        args, kwargs = arguments(data, self.linked, self.premis)
        for before, after in mutations:
            raw = result.xml.replace(before, after)
            self.premis.validate(raw)
            report = loads(result.report); report["xmlHash"] = keccak256(raw)
            with self.subTest(after=after), self.assertRaisesRegex(MuseumError, "source consistency"):
                verify_premis_fixture(replace(result, xml=raw, report=dumps(report)), *args, **kwargs)
        self.assertEqual(verify_premis_fixture(result, *args, **kwargs)["sourceStateHash"], data[0].commitment)

    def test_valid_xml_cannot_cover_mutated_attribution_coverage_or_source(self):
        data = data_for(); result = self.run_projection(data); args, kwargs = arguments(data, self.linked, self.premis)
        for field in ("correspondence", "coverage", "provenance", "report"):
            with self.subTest(field=field), self.assertRaisesRegex(MuseumError, "source consistency"):
                verify_premis_fixture(replace(result, **{field: b"[]"}), *args, **kwargs)
        other = data_for(facts(size="4")); other_args, other_kwargs = arguments(other, self.linked, self.premis)
        with self.assertRaisesRegex(MuseumError, "source consistency"):
            verify_premis_fixture(result, *other_args, **other_kwargs)

    def test_xml_dtd_entities_encoding_nodes_and_wrong_schema_reject_offline(self):
        good = self.run_projection().xml
        attacks = [good.replace(b"<premis:premis", b'<!DOCTYPE premis [<!ENTITY x SYSTEM "file:///C:/Windows/win.ini">]><premis:premis', 1),
                   good + b"<!--extra-->", good + b"<?evil load?>", good.replace(b"<premis:object ", b"<!--inside--><premis:object ", 1),
                   good.replace(b"encoding='UTF-8'", b"encoding='ISO-8859-1'"),
                   good.replace(b"version='1.0'", b"version='1.1'"),
                   good.replace(b"<premis:size>3</premis:size>", b"<premis:size>-99999999999999999999999999</premis:size>"),
                   b"<wrong/>", b"x" * (4 * 1024 * 1024 + 1)]
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            for attack in attacks:
                with self.subTest(attack=attack[:100]), self.assertRaises(MuseumError):
                    self.premis.validate(attack)
        self.premis.validate(good)

    def test_schema_original_hash_and_complete_closure_are_pinned(self):
        from .dependencies import OfflineDocuments
        from hashlib import sha256
        index = loads((ROOT / "premis/dependency-index.json").read_bytes())
        documents = OfflineDocuments(ROOT, index)
        original = documents.load(SCHEMA_URI)
        self.assertEqual(len(original), 52845)
        self.assertEqual(sha256(original).hexdigest(), SCHEMA_SHA256)
        schema = etree.fromstring(original)
        self.assertEqual(schema.xpath("//x:import | //x:include | //x:redefine",
                         namespaces={"x": "http://www.w3.org/2001/XMLSchema"}), [])
        with self.assertRaisesRegex(MuseumError, "profile mismatch"):
            PinnedPremis(ROOT, PROFILE_BYTES, profile_hash=H)
        with tempfile.TemporaryDirectory() as temp:
            import shutil
            root = Path(temp)
            shutil.copytree(ROOT / "premis", root / "premis")
            p = root / index["documents"][0]["chunks"][0]["path"]
            p.write_bytes(p.read_bytes().replace(b"VERSION 3.0", b"VERSION 3.1"))
            with self.assertRaisesRegex(MuseumError, "chunk hash"):
                PinnedPremis(root, PROFILE_BYTES, profile_hash=PROFILE_HASH)

    def test_recorded_state_and_tampered_plan_never_become_fixture_authority(self):
        data = data_for()
        with self.assertRaisesRegex(MuseumError, "recorded"):
            self.run_projection((replace(data[0], mode="recorded_state"), data[1], data[2]))
        args, kwargs = arguments(data, self.linked, self.premis)
        pp = loads(args[3]); pp["sourceStateHash"] = "0x" + "aa" * 32
        bad = dumps(pp); kwargs["premis_plan_hash"] = keccak256(bad)
        with self.assertRaisesRegex(MuseumError, "scope mismatch"):
            project_premis_fixture(*args[:3], bad, **kwargs)

    def test_static_public_example_recomputes_transcript_carrier_and_exact_source(self):
        from .package import fixture_state_from_bytes
        root = ROOT / "premis/example"
        state = fixture_state_from_bytes((root / "source-state.json").read_bytes())
        policy, plan, pp = [(root / name).read_bytes() for name in
            ("selection-policy.json", "linked-art-plan.json", "premis-plan.json")]
        kwargs = {"selection_hash": keccak256(policy), "plan_hash": keccak256(plan),
                  "premis_plan_hash": keccak256(pp), "profile_hash": H,
                  "linked_art_profile": self.linked, "premis_profile": self.premis}
        result = project_premis_fixture(state, policy, plan, pp, **kwargs)
        self.assertIn(b">urn:fixture:recording<", result.xml)
        self.assertNotIn(b">urn:fixture:transcript<", result.xml)
        rows = loads(result.correspondence)
        self.assertEqual(rows[0]["contentRelations"]["digitally_carries"],
                         [{"id": "urn:fixture:transcript", "type": "LinguisticObject"}])
        text = next(loads(r.content)["content"] for r in result.linked_art.resources if r.identifier == "urn:fixture:transcript")
        self.assertEqual(text, "Spoken words — e\u0301\r\n40.00")
        verify_premis_fixture(result, state, policy, plan, pp, **kwargs)

    def test_hardcoded_standard_datatype_iris_pass_and_missing_fragment_iris_reject(self):
        claims = facts()
        for i in (0, 2, 3):
            claims[i]["object"]["literal"]["datatype"] = "http://www.w3.org/2001/XMLSchema#string"
        claims[1]["object"]["literal"]["datatype"] = "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
        healthy = self.run_projection(data_for(claims))
        self.assertIn(b"<premis:size>3</premis:size>", healthy.xml)
        for i, invalid in ((0, "http://www.w3.org/2001/XMLSchemastring"),
                           (1, "http://www.w3.org/2001/XMLSchemanonNegativeInteger"),
                           (2, "http://www.w3.org/2001/XMLSchemastring"),
                           (3, "http://www.w3.org/2001/XMLSchemastring")):
            mutated = copy.deepcopy(claims)
            mutated[i]["object"]["literal"]["datatype"] = invalid
            with self.subTest(field=i), self.assertRaisesRegex(MuseumError, "exact unqualified literal"):
                self.run_projection(data_for(mutated))
        self.assertEqual(self.run_projection(data_for(claims)).xml, healthy.xml)


if __name__ == "__main__":
    unittest.main()
