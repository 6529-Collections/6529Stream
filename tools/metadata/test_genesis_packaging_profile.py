"""Profile definitions and actual offline fixture replay are distinct checks."""

import copy
from hashlib import sha256
import unittest
from unittest.mock import patch

import jsonschema

from . import genesis_packaging_profile as p
from tools.museum.canonical import MuseumError, dumps, keccak256, loads


class GenesisPackagingProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = {name: p.example_files(name) for name in p.NAMES}
        cls.values = {name: p.example(name, cls.files[name]) for name in p.NAMES}

    def raw(self, name):
        return dumps(self.values[name])

    def verify(self, name, value=None, files=None):
        raw = self.raw(name) if value is None else dumps(value)
        return p.verify_worked_example(name, raw, self.files[name] if files is None else files,
            expected_hash=keccak256(raw))

    def refreshed(self, name, files):
        value = copy.deepcopy(self.values[name])
        value["workedExample"]["files"] = [{"path": path, "bytes": str(len(raw)),
            "sha256": "0x" + sha256(raw).hexdigest(), "keccak256": keccak256(raw)}
            for path, raw in sorted(files.items())]
        if name == p.LIDO:
            value["workedExample"]["commitment"] = keccak256(files["report.json"])
        return value

    def test_canonical_schemas_examples_and_original_profiles_are_exact(self):
        with patch("socket.socket", side_effect=AssertionError("offline generator used network")):
            outputs = p.outputs()
        for path, raw in outputs.items():
            self.assertEqual((p.ROOT / path).read_bytes(), raw)
            self.assertEqual(dumps(loads(raw, maximum=p.MAX_PROFILE_BYTES)), raw)
        for name in p.NAMES:
            jsonschema.Draft202012Validator.check_schema(p.schema(name))
            self.assertEqual(p.validate_profile(name, self.raw(name)), self.values[name])
            self.assertEqual(p.SCHEMA_HASHES[name], keccak256(p.SCHEMA_BYTES[name]))
        self.assertEqual((p.ROOT / "schemas/museum/bagit/profile.json").read_bytes(), p.bagit.PROFILE_BYTES)
        self.assertEqual((p.ROOT / "schemas/museum/work-lido/profile.json").read_bytes(), p.LIDO_IMPLEMENTATION)
        # Existing same-name implementation objects cannot be mistaken for the canonical definition data.
        for name, raw in ((p.BAGIT, p.bagit.PROFILE_BYTES), (p.LIDO, p.LIDO_IMPLEMENTATION)):
            with self.assertRaises(MuseumError):
                p.validate_profile(name, raw)

    def test_complete_rules_are_committed_in_schema_not_arbitrary_example_annotations(self):
        for name in p.NAMES:
            required = p.schema(name)["properties"]["elementRules"]["const"]
            self.assertEqual(required, self.values[name]["elementRules"])
            self.assertGreaterEqual(len(required), 20)
            self.assertEqual(len({row["id"] for row in required}), len(required))
            for change in ("remove", "rewrite", "append", "reorder"):
                value = copy.deepcopy(self.values[name])
                rows = value["elementRules"]
                if change == "remove": rows.pop()
                elif change == "rewrite": rows[0]["requirement"] = "Optional; trust the caller"
                elif change == "append": rows.append(copy.deepcopy(rows[0]))
                else: rows.reverse()
                with self.subTest(name=name, change=change), self.assertRaises(MuseumError):
                    p.validate_profile(name, dumps(value))
        lido_ids = {row["id"] for row in p.lido_rules()}
        self.assertTrue({"description-absence", "creator-association", "format-witness",
            "language-variants", "complete-accounting", "aspect-ratio", "edition-open",
            "creator-authority-references", "medium-technique-authority-references"} <= lido_ids)

    def test_closed_definitions_and_no_authority_or_acceptance_promotion(self):
        for name in p.NAMES:
            for fault in ("extra", "missing", "registration", "ingest", "implementation"):
                value = copy.deepcopy(self.values[name])
                if fault == "extra": value["authority"] = True
                elif fault == "missing": del value["target"]
                elif fault == "registration": value["claims"]["registered"] = True
                elif fault == "ingest": value["claims"]["institutionalIngest"] = True
                else: value["implementation"]["profileHash"] = "0x" + "ab" * 32
                with self.subTest(name=name, fault=fault), self.assertRaises(MuseumError):
                    p.validate_profile(name, dumps(value))

    def test_actual_complete_tombstone_xml_and_actual_worked_bag_replay_offline(self):
        with patch("socket.socket", side_effect=AssertionError("fixture verification used network")):
            lido = self.verify(p.LIDO)
            bag = self.verify(p.BAGIT)
        self.assertIn("original_offline_LIDO_XSD", lido["checks"])
        self.assertIn("exact_XML_sidecar_coverage_provenance_and_report", lido["checks"])
        self.assertIn("BagIt_payload_and_tag_fixity", bag["checks"])
        self.assertIn("complete_bag_OCFL_transport", bag["checks"])
        self.assertFalse(any(lido["claims"].values()))
        self.assertFalse(any(bag["claims"].values()))

    def test_shape_validation_never_substitutes_for_actual_xml_source_mapping(self):
        files = dict(self.files[p.LIDO])
        files["record.xml"] = files["record.xml"].replace(b"Declared artist display name", b"Someone else")
        self.assertNotEqual(files["record.xml"], self.files[p.LIDO]["record.xml"])
        changed = self.refreshed(p.LIDO, files)
        # The definition and commitments are valid data; actual WORK-to-XML equality is not.
        p.validate_profile(p.LIDO, dumps(changed))
        with self.assertRaisesRegex(MuseumError, "source-to-output consistency"):
            self.verify(p.LIDO, changed, files)

    def test_every_original_lido_source_accounting_file_is_checked(self):
        for path in ("work.json", "context.json", "catalog.json", "sidecar.json", "coverage.json",
                     "provenance.json", "report.json", "profile.json"):
            files = dict(self.files[p.LIDO])
            files[path] += b" "
            changed = self.refreshed(p.LIDO, files)
            with self.subTest(path=path), self.assertRaises(MuseumError):
                self.verify(p.LIDO, changed, files)

    def test_actual_bag_fixity_and_profile_tags_are_not_hash_only_assertions(self):
        for path in self.files[p.BAGIT]:
            files = dict(self.files[p.BAGIT]); files[path] += b"!"
            changed = self.refreshed(p.BAGIT, files)
            p.validate_profile(p.BAGIT, dumps(changed))
            with self.subTest(path=path), self.assertRaises(MuseumError):
                self.verify(p.BAGIT, changed, files)

    def test_ocfl_heads_gap_remains_explicit_and_inventory_commitment_is_checked(self):
        gap = next(row for row in p.bagit_rules() if row["id"] == "ocfl-heads-supplement")
        self.assertEqual(gap["implementation"], "not_implemented")
        value = copy.deepcopy(self.values[p.BAGIT])
        value["workedExample"]["ocfl"]["inventoryHash"] = "0x" + "55" * 32
        p.validate_profile(p.BAGIT, dumps(value))
        with self.assertRaisesRegex(MuseumError, "OCFL inventory differs"):
            self.verify(p.BAGIT, value)

    def test_external_pin_file_set_hash_size_paths_and_aggregate_bounds(self):
        for name in p.NAMES:
            with self.assertRaisesRegex(MuseumError, "external"):
                p.verify_worked_example(name, self.raw(name), self.files[name], expected_hash="0x" + "55" * 32)
            for fault in ("hash", "size", "traversal", "duplicate", "extra-field", "overflow"):
                value = copy.deepcopy(self.values[name]); rows = value["workedExample"]["files"]
                if fault == "hash": rows[0]["keccak256"] = "0x" + "11" * 32
                elif fault == "size": rows[0]["bytes"] = "1"
                elif fault == "traversal": rows[0]["path"] = "../outside"
                elif fault == "duplicate": rows.append(copy.deepcopy(rows[-1]))
                elif fault == "extra-field": rows[0]["accepted"] = True
                else: rows[0]["bytes"] = str(2**64)
                with self.subTest(name=name, fault=fault), self.assertRaises(MuseumError):
                    self.verify(name, value)
            missing = dict(self.files[name]); missing.pop(next(iter(missing)))
            extra = dict(self.files[name]); extra["extra.bin"] = b"x"
            for files in (missing, extra):
                with self.assertRaises(MuseumError): self.verify(name, files=files)

    def test_noncanonical_duplicate_and_oversize_profile_inputs_reject(self):
        raw = self.raw(p.LIDO)
        for bad in (raw + b"\n", raw[:-1] + b',"version":"1"}', b"null", b" " * (p.MAX_PROFILE_BYTES + 1), "not bytes"):
            with self.subTest(kind=type(bad)), self.assertRaises(MuseumError):
                p.validate_profile(p.LIDO, bad)
        with self.assertRaises(MuseumError):
            p.validate_profile("UNDECLARED", raw)


if __name__ == "__main__":
    unittest.main()
