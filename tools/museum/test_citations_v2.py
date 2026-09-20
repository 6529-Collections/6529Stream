"""Additive syntax/crosswalk checks; these vectors confer no native authority."""
import unittest

from jsonschema import Draft202012Validator
from . import citations, citations_v2 as v2
from .canonical import MuseumError, keccak256, loads

A = "0x" + "12" * 20
H = "0x" + "ab" * 32


class CitationV2Tests(unittest.TestCase):
    def test_three_original_namespaces_are_byte_identical_and_rec_is_additive(self):
        for kind in ("fin", "snap", "chain"):
            original = citations.canonical_citation("1", A, "123", {"kind": kind, "hash": H})
            self.assertEqual(v2.canonical_citation("1", A, "123", {"kind": kind, "hash": H}), original)
            self.assertEqual(v2.parse_citation(original), citations.parse_citation(original))
        recovered = v2.canonical_citation("1", A, "123", {"kind": "rec", "hash": H})
        self.assertEqual(v2.parse_citation(recovered, require_state=True)["qualifier"], {"kind": "rec", "hash": H})
        with self.assertRaises(MuseumError):
            citations.parse_citation(recovered)
        Draft202012Validator(loads(v2.SCHEMA_BYTES)).validate(recovered)

    def test_noncanonical_zero_overflow_unknown_and_untyped_forms_reject(self):
        good = v2.canonical_citation("1", A, "123", {"kind": "rec", "hash": H})
        bad = [good + "\n", good.replace("eip155:1", "eip155:01"), good.replace("/123", "/0123"),
            good.replace("@rec:", "@recovery:"), good.replace("@rec:", "@"),
            good.replace(H, "0x" + "00" * 32), good.replace(A, "0x" + "00" * 20),
            good.replace("/123", "/0"), good.replace("eip155:1", "eip155:0"),
            good.replace("/123", "/" + str(1 << 256)), good.replace(H, H.upper()), None, 42]
        for value in bad:
            with self.subTest(value=value), self.assertRaises(MuseumError):
                v2.parse_citation(value)
        max_uint = str((1 << 256) - 1)
        self.assertEqual(v2.parse_citation(v2.canonical_citation(max_uint, A, max_uint))["tokenId"], max_uint)
        with self.assertRaises(MuseumError):
            v2.parse_citation(good.split("@")[0], require_state=True)
        for qualifier in ({"kind": "rec", "hash": None}, {"kind": "rec", "hash": H, "executed": True}):
            with self.assertRaises(MuseumError):
                v2.canonical_citation("1", A, "123", qualifier)

    def test_profile_schema_pins_and_exact_pid_state_fragment(self):
        profile = loads(v2.PROFILE_BYTES, canonical=True)
        self.assertEqual(v2.PROFILE_HASH, keccak256(v2.PROFILE_BYTES))
        self.assertEqual(profile["schema"]["hash"], keccak256(v2.SCHEMA_BYTES))
        self.assertEqual(set(profile["qualifiers"]), {"fin", "snap", "chain", "rec"})
        for kind, identifier in (("DOI", "10.1234/example"), ("ARK", "ark:/12345/example")):
            cited = v2.canonical_citation("1", A, "123", {"kind": "rec", "hash": H})
            result = v2.persistent_identifier_crosswalk(cited, identifier=identifier, identifier_type=kind)
            self.assertEqual(result["citedState"], cited)
            self.assertEqual(result["originalWorkCitation"], cited.split("@")[0])
            self.assertEqual(result["dataCiteMetadataFragment"]["alternateIdentifiers"][0]["alternateIdentifier"], cited)
            self.assertTrue(all(value is False for value in result["claims"].values()))
        with self.assertRaises(MuseumError):
            v2.persistent_identifier_crosswalk(cited, identifier="bad\nvalue", identifier_type="DOI")


if __name__ == "__main__":
    unittest.main()
